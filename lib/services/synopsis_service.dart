import 'dart:convert';
import 'package:flutter/services.dart';

import 'package:seeksparks/utils/reference_parser.dart';

/// One passage of a synopsis entry: a book, the string a reader sees,
/// and where tapping it goes.
class SynopsisPassage {
  /// Canonical English book name ("Matthew", "2 Chronicles").
  final String book;

  /// The reference as it is displayed, e.g. "2 Kings 23:35-24:7".
  final String raw;

  /// Parsed target, or null when [raw] does not resolve.
  final BibleReference? reference;

  const SynopsisPassage({
    required this.book,
    required this.raw,
    required this.reference,
  });
}

/// One harmony entry — a Gospel event with its parallel in each Gospel
/// that records it, or an Old Testament group with its parallels
/// anywhere in the canon.
class SynopsisEvent {
  final String id;
  final Map<String, String> title; // locale -> localized title

  /// Every passage in the entry, in the order the source lists them.
  ///
  /// A list, not a map keyed by book, because an entry may name the
  /// same book twice: "Benjamin's Descendants" is 1 Chronicles 8:1-9:1
  /// AND 1 Chronicles 9:34-44. Keying by book silently kept the last
  /// one, which dropped 37 of the 313 Old Testament passages.
  final List<SynopsisPassage> passages;

  /// True for entries from the Gospel harmony. Only these can be
  /// "found in one Gospel only" — an OT group with a single passage is
  /// not a parallel at all and never reaches the reader.
  final bool isGospelHarmony;

  const SynopsisEvent({
    required this.id,
    required this.title,
    required this.passages,
    required this.isGospelHarmony,
  });

  String localizedTitle(String locale) =>
      title[locale] ?? title['en'] ?? id;

  SynopsisPassage? _passageFor(String book) {
    final want = book.toLowerCase();
    for (final p in passages) {
      if (p.book.toLowerCase() == want) return p;
    }
    return null;
  }

  /// Parsed [BibleReference] for [book], or null when this entry does
  /// not cover it. When an entry names [book] more than once this is
  /// the first passage; callers wanting all of them read [passages].
  BibleReference? referenceFor(String book) => _passageFor(book)?.reference;

  /// Raw reference string for display, e.g. "Matthew 5:1-12". Caller is
  /// responsible for any localization of the book name.
  String? rawRef(String book) => _passageFor(book)?.raw;
}

/// Loads + indexes the bundled Gospel synopsis. Two query shapes are
/// supported:
///   - `byChapter(book, chapter)` — every event whose entry for that
///     Gospel falls inside the given chapter
///   - `byVerse(book, chapter, verse)` — events that include the
///     specific verse (verse range in the harmony entry includes it)
class SynopsisService {
  static const _gospelOrder = ['Matthew', 'Mark', 'Luke', 'John'];

  static List<SynopsisEvent>? _events;
  static Future<void>? _loading;

  /// Map of canonical English Gospel name → ordered list of entries
  /// touching that Gospel. Sorted by chapter+verse for deterministic
  /// rendering.
  static final Map<String, List<_IndexedEntry>> _byGospel = {
    'Matthew': [],
    'Mark': [],
    'Luke': [],
    'John': [],
  };

  /// 2026-08-07: the Old Testament half, from Eagle's View's OT Synopsis
  /// (139 groups, 313 passages). Kept in its own index rather than merged
  /// into `_byGospel` because the two have different shapes — a gospel
  /// event names at most four books by fixed key, an OT group names any
  /// number of books anywhere in the canon.
  ///
  /// Deliberately NOT a separate page or tab. It is the same idea as the
  /// gospel harmony applied to the other testament, so it belongs on the
  /// same surface; a reader in 2 Chronicles 26 should be told about
  /// 2 Kings 15 exactly the way a reader in Matthew 5 is told about
  /// Luke 6.
  static final Map<String, List<_IndexedEntry>> _byOtBook = {};
  static Future<void>? _otLoading;

  /// Where the OT synopsis groups came from, for the credit line.
  static String otAttribution = '';

  static Future<void> _ensureOtLoaded() => _otLoading ??= _loadOt();

  static Future<void> _loadOt() async {
    try {
      final raw = await rootBundle.loadString('assets/ot_synopsis.json');
      final j = jsonDecode(raw) as Map<String, dynamic>;
      otAttribution = (j['attribution'] ?? '') as String;
      for (final g in (j['groups'] as List? ?? const [])) {
        final m = g as Map<String, dynamic>;
        final rows = (m['refs'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
        final passages = [for (final r in rows) _otPassage(r)];
        final event = SynopsisEvent(
          id: 'ot-${m['id']}',
          title: {
            'en': (m['en'] ?? '') as String,
            'zh-Hans': (m['zh'] ?? m['en'] ?? '') as String,
            // The source is Simplified only; 繁體 readers get it rather
            // than an English fallback, which is the lesser wrong until
            // a converted column exists.
            'zh-Hant': (m['zh'] ?? m['en'] ?? '') as String,
          },
          passages: passages,
          isGospelHarmony: false,
        );
        for (final r in rows) {
          final chapter = r['chapter'] as int;
          _byOtBook.putIfAbsent(r['book'] as String, () => []).add(
                _IndexedEntry(
                  event: event,
                  chapter: chapter,
                  verseStart: r['start'] as int,
                  // `end` is a verse of `endChapter`, which is the
                  // start chapter unless the range crosses one.
                  verseEnd: r['end'] as int,
                  endChapter: (r['endChapter'] as int?) ?? chapter,
                ),
              );
        }
      }
      for (final l in _byOtBook.values) {
        l.sort((a, b) => a.chapter != b.chapter
            ? a.chapter.compareTo(b.chapter)
            : a.verseStart.compareTo(b.verseStart));
      }
    } catch (_) {
      // Optional asset: a build without it simply has no OT synopsis.
    }
  }

  /// One `{book, chapter, start, end, endChapter?}` row of
  /// `ot_synopsis.json` as a passage. Built from the structured fields
  /// rather than re-parsed from a formatted string, so a span survives.
  static SynopsisPassage _otPassage(Map<String, dynamic> r) {
    final book = r['book'] as String;
    final chapter = r['chapter'] as int;
    final start = r['start'] as int;
    final end = r['end'] as int;
    final endChapter = r['endChapter'] as int?;
    final tail = endChapter != null
        ? '-$endChapter:$end'
        : (end != start ? '-$end' : '');
    return SynopsisPassage(
      book: book,
      raw: '$book $chapter:$start$tail',
      reference: BibleReference(
        englishBook: book,
        chapter: chapter,
        verseStart: start,
        // The far end belongs to the end chapter when the range spans
        // one, so it must not be reported as a verse of the first.
        verseEnd: endChapter != null ? null : end,
        endChapter: endChapter,
        endVerse: endChapter != null ? end : null,
      ),
    );
  }

  static Future<void> _ensureLoaded() async {
    if (_events != null) return;
    _loading ??= _load();
    await _loading;
  }

  static Future<void> _load() async {
    final raw =
        await rootBundle.loadString('assets/gospel_synopsis.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final list = json['events'] as List;
    final events = <SynopsisEvent>[];
    for (final e in list) {
      final m = e as Map<String, dynamic>;
      final refs = Map<String, String>.from(m['refs'] as Map);
      final ev = SynopsisEvent(
        id: m['id'] as String,
        title: Map<String, String>.from(m['title'] as Map),
        // Gospel order, not the JSON's key order, so the chips read
        // Matthew-Mark-Luke-John in every entry.
        passages: [
          for (final g in _gospelOrder)
            if (refs[g.toLowerCase()] != null)
              SynopsisPassage(
                book: g,
                raw: refs[g.toLowerCase()]!,
                // `parseReference` already trims a multi-segment ref
                // like "Luke 8:16, 11:33" down to its first segment.
                reference: parseReference(refs[g.toLowerCase()]!),
              ),
        ],
        isGospelHarmony: true,
      );
      events.add(ev);
    }
    _events = events;

    // Index. For each Gospel ref, parse it and stash the chapter +
    // verse range so chapter/verse queries are O(1) per event.
    for (final ev in events) {
      for (final p in ev.passages) {
        final parsed = p.reference;
        if (parsed == null) continue;
        // Whole-chapter entries (no verse part) cover the entire
        // chapter; mark with verse range 1..big.
        final start = parsed.verseStart ?? 1;
        final endChapter = parsed.endChapter ?? parsed.chapter;
        final end = parsed.endVerse ??
            parsed.verseEnd ??
            (parsed.verseStart ?? 9999);
        _byGospel[p.book]!.add(_IndexedEntry(
          chapter: parsed.chapter,
          verseStart: start,
          endChapter: endChapter,
          verseEnd: end,
          event: ev,
        ));
      }
    }
    for (final list in _byGospel.values) {
      list.sort((a, b) {
        if (a.chapter != b.chapter) return a.chapter.compareTo(b.chapter);
        return a.verseStart.compareTo(b.verseStart);
      });
    }
  }

  static String? _gospelKey(String s) {
    final t = s.toLowerCase();
    switch (t) {
      case 'matthew':
      case 'mt':
        return 'Matthew';
      case 'mark':
      case 'mk':
        return 'Mark';
      case 'luke':
      case 'lk':
        return 'Luke';
      case 'john':
      case 'jn':
        return 'John';
    }
    return null;
  }

  /// An entry may name the same book twice ("Benjamin's Descendants" is
  /// 1 Chronicles 8:1-9:1 and 9:34-44, both covering chapter 9), so the
  /// same event can match more than once. First match wins, order kept.
  static List<SynopsisEvent> _distinct(Iterable<_IndexedEntry> matches) {
    final seen = <String>{};
    return [
      for (final e in matches)
        if (seen.add(e.event.id)) e.event,
    ];
  }

  static Future<List<_IndexedEntry>> _index(String book) async {
    await _ensureLoaded();
    final key = _gospelKey(book);
    if (key != null) return _byGospel[key] ?? const [];
    await _ensureOtLoaded();
    return _byOtBook[book] ?? const <_IndexedEntry>[];
  }

  /// All events touching [book] [chapter]. Empty when no synopsis entry
  /// falls in that chapter.
  static Future<List<SynopsisEvent>> byChapter(
      String book, int chapter) async {
    final list = await _index(book);
    return _distinct(list.where((e) => e.coversChapter(chapter)));
  }

  /// Events whose entry for [book] covers [verse]. Empty list when
  /// not applicable.
  static Future<List<SynopsisEvent>> byVerse(
      String book, int chapter, int verse) async {
    final list = await _index(book);
    return _distinct(list.where((e) => e.coversVerse(chapter, verse)));
  }

  /// Returns true if [book] is one of the four Gospels — used by the
  /// reading-pane menu to decide whether to show the "Synopsis"
  /// option.
  static bool isGospel(String englishBook) {
    return _gospelKey(englishBook) != null &&
        ['Matthew', 'Mark', 'Luke', 'John'].contains(englishBook);
  }

  /// Whether ANY synopsis covers [englishBook] — the four Gospels, or an
  /// Old Testament book that Eagle's View files a parallel for. This is
  /// what the reading-pane menu should gate on; `isGospel` remains for
  /// callers that specifically mean the gospel harmony.
  static Future<bool> hasSynopsis(String englishBook) async {
    if (isGospel(englishBook)) return true;
    await _ensureOtLoaded();
    return hasSynopsisSync(englishBook);
  }

  /// [hasSynopsis] without the await, for the reading-pane menu, which
  /// is built synchronously. Answers false for an OT book until
  /// [preload] has completed — call it once when the reader opens.
  static bool hasSynopsisSync(String englishBook) =>
      isGospel(englishBook) ||
      (_byOtBook[englishBook] ?? const []).isNotEmpty;

  /// Load the indexes so [hasSynopsisSync] can answer. Safe to call
  /// repeatedly; the work happens once.
  static Future<void> preload() => _ensureOtLoaded();

  /// Total entry count for callers that want to surface coverage.
  static Future<int> count() async {
    await _ensureLoaded();
    return _events?.length ?? 0;
  }
}

/// One passage, flattened for lookup. [endChapter] equals [chapter] for
/// the common case; when it does not, [verseEnd] is a verse of
/// [endChapter], not of [chapter].
class _IndexedEntry {
  final int chapter;
  final int verseStart;
  final int endChapter;
  final int verseEnd;
  final SynopsisEvent event;
  const _IndexedEntry({
    required this.chapter,
    required this.verseStart,
    required this.verseEnd,
    required this.event,
    required this.endChapter,
  });

  bool coversChapter(int c) => c >= chapter && c <= endChapter;

  bool coversVerse(int c, int v) {
    if (!coversChapter(c)) return false;
    if (c > chapter && c < endChapter) return true;
    if (c == chapter && v < verseStart) return false;
    if (c == endChapter && v > verseEnd) return false;
    return true;
  }
}
