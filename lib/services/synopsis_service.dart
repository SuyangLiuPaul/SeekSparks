import 'dart:convert';
import 'package:flutter/services.dart';

import 'package:seeksparks/utils/reference_parser.dart';

/// One harmony entry from `assets/gospel_synopsis.json`. Each entry
/// maps a single Gospel event to its parallel passage in each Gospel
/// that records it.
class SynopsisEvent {
  final String id;
  final Map<String, String> title; // locale -> localized title
  /// Gospel name ("matthew" / "mark" / "luke" / "john") -> raw
  /// reference string ("Matthew 5:1-12"). Reference parser handles
  /// resolution to canonical English book name when navigating.
  final Map<String, String> refs;

  const SynopsisEvent({
    required this.id,
    required this.title,
    required this.refs,
  });

  String localizedTitle(String locale) =>
      title[locale] ?? title['en'] ?? id;

  /// Returns the parsed [BibleReference] for [gospel] (case-insensitive
  /// "matthew"/"mark"/"luke"/"john"), or null if this event doesn't
  /// cover that Gospel.
  BibleReference? referenceFor(String gospel) {
    final raw = refs[gospel.toLowerCase()];
    if (raw == null) return null;
    // Parser may not handle the multi-segment "Luke 8:16, 11:33" form
    // — split on comma and take the first segment.
    final first = raw.split(',').first.trim();
    return parseReference(first);
  }

  /// Returns the raw reference string for display, e.g. "Mt 5:1-12".
  /// Caller is responsible for any localization of the book name.
  String? rawRef(String gospel) => refs[gospel.toLowerCase()];
}

/// Loads + indexes the bundled Gospel synopsis. Two query shapes are
/// supported:
///   - `byChapter(book, chapter)` — every event whose entry for that
///     Gospel falls inside the given chapter
///   - `byVerse(book, chapter, verse)` — events that include the
///     specific verse (verse range in the harmony entry includes it)
class SynopsisService {
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
  static bool _otLoaded = false;

  /// Where the OT synopsis groups came from, for the credit line.
  static String otAttribution = '';

  static Future<void> _ensureOtLoaded() async {
    if (_otLoaded) return;
    _otLoaded = true;
    try {
      final raw = await rootBundle.loadString('assets/ot_synopsis.json');
      final j = jsonDecode(raw) as Map<String, dynamic>;
      otAttribution = (j['attribution'] ?? '') as String;
      for (final g in (j['groups'] as List? ?? const [])) {
        final m = g as Map<String, dynamic>;
        final passages = (m['refs'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
        // Render each passage as the raw string the existing
        // SynopsisEvent contract expects, keyed by lowercase book so
        // `rawRef`/`referenceFor` keep working unchanged.
        final refs = <String, String>{
          for (final r in passages)
            (r['book'] as String).toLowerCase():
                '${r['book']} ${r['chapter']}:${r['start']}'
                '${r['end'] != r['start'] ? '-${r['end']}' : ''}',
        };
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
          refs: refs,
        );
        for (final r in passages) {
          _byOtBook.putIfAbsent(r['book'] as String, () => []).add(
                _IndexedEntry(
                  event: event,
                  chapter: r['chapter'] as int,
                  verseStart: r['start'] as int,
                  verseEnd: r['end'] as int,
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
      final ev = SynopsisEvent(
        id: m['id'] as String,
        title: Map<String, String>.from(m['title'] as Map),
        refs: Map<String, String>.from(m['refs'] as Map),
      );
      events.add(ev);
    }
    _events = events;

    // Index. For each Gospel ref, parse it and stash the chapter +
    // verse range so chapter/verse queries are O(1) per event.
    for (final ev in events) {
      ev.refs.forEach((gospel, raw) {
        final canonicalGospel = _gospelKey(gospel);
        if (canonicalGospel == null) return;
        // Take only the first segment if comma-separated.
        final first = raw.split(',').first.trim();
        final parsed = parseReference(first);
        if (parsed == null) return;
        // Whole-chapter entries (no verse part) cover the entire
        // chapter; mark with verse range 1..big.
        final start = parsed.verseStart ?? 1;
        final end = parsed.verseEnd ?? (parsed.verseStart ?? 9999);
        _byGospel[canonicalGospel]!.add(_IndexedEntry(
          chapter: parsed.chapter,
          verseStart: start,
          verseEnd: end,
          event: ev,
        ));
      });
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

  /// All events touching [book] [chapter]. Returns empty list when
  /// [book] is not a Gospel or no harmony entries fall in that
  /// chapter.
  static Future<List<SynopsisEvent>> byChapter(
      String book, int chapter) async {
    await _ensureLoaded();
    final key = _gospelKey(book);
    if (key == null) {
      await _ensureOtLoaded();
      return (_byOtBook[book] ?? const <_IndexedEntry>[])
          .where((e) => e.chapter == chapter)
          .map((e) => e.event)
          .toList();
    }
    final list = _byGospel[key] ?? const [];
    return list
        .where((e) => e.chapter == chapter)
        .map((e) => e.event)
        .toList();
  }

  /// Events whose entry for [book] covers [verse]. Empty list when
  /// not applicable.
  static Future<List<SynopsisEvent>> byVerse(
      String book, int chapter, int verse) async {
    await _ensureLoaded();
    final key = _gospelKey(book);
    if (key == null) {
      await _ensureOtLoaded();
      return (_byOtBook[book] ?? const <_IndexedEntry>[])
          .where((e) =>
              e.chapter == chapter &&
              verse >= e.verseStart &&
              verse <= e.verseEnd)
          .map((e) => e.event)
          .toList();
    }
    final list = _byGospel[key] ?? const [];
    return list
        .where((e) =>
            e.chapter == chapter &&
            verse >= e.verseStart &&
            verse <= e.verseEnd)
        .map((e) => e.event)
        .toList();
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
    return (_byOtBook[englishBook] ?? const []).isNotEmpty;
  }

  /// Total entry count for callers that want to surface coverage.
  static Future<int> count() async {
    await _ensureLoaded();
    return _events?.length ?? 0;
  }
}

class _IndexedEntry {
  final int chapter;
  final int verseStart;
  final int verseEnd;
  final SynopsisEvent event;
  const _IndexedEntry({
    required this.chapter,
    required this.verseStart,
    required this.verseEnd,
    required this.event,
  });
}
