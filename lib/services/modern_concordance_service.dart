/// 2026-08-07 (SeekSparks): Eagle's View's Modern Concordance.
///
/// Eagle's View calls itself an *electronic statistical concordance*, and
/// this is the part that earns the phrase. 341 bilingual topics resolve
/// to 1,645 Greek-word sections, those to 7,758 subsections each keyed to
/// a Strong's Greek number, and each of those carries its own reference
/// list and its own corpus statistics — how often the word appears in the
/// New Testament, and how that total splits across the Gospels & Acts,
/// Paul, John, and the other authors.
///
/// It answers a question the app could not answer before. `StrongsService`
/// says what G946 means; the concordance says that G946 is where the
/// Modern Concordance files 亵渎 / Abomination, which other Greek words
/// belong to that family, and where each of them occurs.
///
/// Distinct from `ConcordanceService`, which counts word occurrences
/// across the whole bundled text. That one is arithmetic over the corpus;
/// this one is an editorial scheme, and the difference matters — the
/// topic groupings are a person's judgement about meaning, not a count.
///
/// Loading mirrors `TaggedTextService`: a 24 KB index held from first use,
/// everything else pulled per topic or per book and cached. The whole set
/// is 4.3 MB across 370 files and must never be loaded eagerly.
///
/// Rights: the topic scheme, verse links and statistics are Eagle's View's
/// editorial work following *Modern Concordance to the New Testament*
/// (Darton, Longman & Todd, 1976), used by the permission the ministry
/// granted. `attribution` carries that statement out of the asset so a UI
/// showing this data can show its source with it.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// One topic in the concordance — "Abomination" / 亵渎.
@immutable
class ConcordanceTopic {
  const ConcordanceTopic({
    required this.id,
    required this.en,
    required this.zh,
    required this.sectionCount,
  });

  final int id;
  final String en;
  final String zh;
  final int sectionCount;

  /// The reading-language name. Chinese covers both scripts: the source
  /// is Simplified, and the app's 繁體 readers get the Simplified form
  /// rather than an English fallback, which is the lesser of the two
  /// wrongs until a converted column exists.
  String label(String locale) =>
      locale.startsWith('zh') && zh.isNotEmpty ? zh : en;
}

/// One Greek word under a topic, with its references and statistics.
@immutable
class ConcordanceEntry {
  const ConcordanceEntry({
    required this.strongs,
    required this.en,
    required this.zh,
    required this.refs,
    required this.totals,
    required this.books,
  });

  /// Strong's Greek number, e.g. `G946`.
  final String strongs;
  final String en;
  final String zh;

  /// Where this word occurs, as (englishBook, chapter, verse).
  final List<(String, int, int)> refs;

  /// Corpus totals — `nt`, `gospelsActs`, `paul`, `john`, `otherAuthors`.
  /// Absent keys mean zero; the builder drops them to halve the payload.
  final Map<String, int> totals;

  /// Per-book counts keyed by the concordance's own three-letter
  /// abbreviations (`Mat`, `Rom`, `Rev`). Absent means zero.
  final Map<String, int> books;

  String label(String locale) =>
      locale.startsWith('zh') && zh.isNotEmpty ? zh : en;

  factory ConcordanceEntry.fromJson(Map<String, dynamic> j) => ConcordanceEntry(
        strongs: (j['g'] ?? '') as String,
        en: (j['en'] ?? '') as String,
        zh: (j['zh'] ?? '') as String,
        refs: [
          for (final r in (j['refs'] as List?) ?? const [])
            ((r as List)[0] as String, r[1] as int, r[2] as int),
        ],
        totals: {
          for (final e in ((j['stats']?['totals'] ?? const {}) as Map).entries)
            e.key as String: e.value as int,
        },
        books: {
          for (final e in ((j['stats']?['books'] ?? const {}) as Map).entries)
            e.key as String: e.value as int,
        },
      );
}

/// A section groups the Greek words that share one sense of a topic —
/// "Abomination: BDELUGMA" holds G946, G947 and G948.
@immutable
class ConcordanceSection {
  const ConcordanceSection({
    required this.en,
    required this.zh,
    required this.entries,
  });

  final String en;
  final String zh;
  final List<ConcordanceEntry> entries;

  String label(String locale) =>
      locale.startsWith('zh') && zh.isNotEmpty ? zh : en;
}

/// One concordance entry that cites a particular verse, resolved far
/// enough to render a line without loading the whole topic.
@immutable
class ConcordanceCitation {
  const ConcordanceCitation({
    required this.topicId,
    required this.topic,
    required this.strongs,
  });

  final int topicId;
  final ConcordanceTopic topic;
  final String strongs;
}

class ModernConcordanceService {
  static const _base = 'assets/concordance';

  static List<ConcordanceTopic>? _topics;
  static Map<int, ConcordanceTopic> _byId = const {};
  static String _attribution = '';
  static Map<String, List<String>> _greek = const {};

  static final Map<int, List<ConcordanceSection>> _topicCache = {};
  static final Map<String, Map<String, List<List<dynamic>>>> _verseCache = {};

  /// The source statement to show wherever this data is displayed.
  static String get attribution => _attribution;

  /// All 341 topics, sorted by their English name. Loads the 24 KB index
  /// on first call and holds it — everything else keys off topic ids.
  static Future<List<ConcordanceTopic>> topics() async {
    final cached = _topics;
    if (cached != null) return cached;
    try {
      final j = json.decode(await rootBundle.loadString('$_base/index.json'))
          as Map<String, dynamic>;
      _attribution = (j['attribution'] ?? '') as String;
      final list = [
        for (final t in (j['topics'] as List? ?? const []))
          ConcordanceTopic(
            id: t['id'] as int,
            en: (t['en'] ?? '') as String,
            zh: (t['zh'] ?? '') as String,
            sectionCount: (t['sections'] ?? 0) as int,
          ),
      ];
      _byId = {for (final t in list) t.id: t};
      return _topics = list;
    } catch (_) {
      // The concordance is an optional asset set. A build without it
      // should render an empty tab, not throw into the pane.
      return _topics = const [];
    }
  }

  /// Transliteration for a Strong's Greek number ("G946" -> "BDELUGMA"),
  /// or null when the concordance does not carry one.
  static Future<String?> transliteration(String strongs) async {
    if (_greek.isEmpty) {
      try {
        final j = json.decode(await rootBundle.loadString('$_base/greek.json'))
            as Map<String, dynamic>;
        _greek = {
          for (final e in j.entries)
            e.key: [for (final v in e.value as List) (v ?? '').toString()],
        };
      } catch (_) {
        _greek = const {};
      }
    }
    final hit = _greek[strongs];
    return (hit == null || hit.isEmpty || hit.first.isEmpty) ? null : hit.first;
  }

  /// One topic, fully joined.
  static Future<List<ConcordanceSection>> sections(int topicId) async {
    final hit = _topicCache[topicId];
    if (hit != null) return hit;
    try {
      final j = json.decode(await rootBundle.loadString('$_base/t/$topicId.json'))
          as Map<String, dynamic>;
      return _topicCache[topicId] = [
        for (final s in (j['sections'] as List? ?? const []))
          ConcordanceSection(
            en: (s['en'] ?? '') as String,
            zh: (s['zh'] ?? '') as String,
            entries: [
              for (final e in (s['subsections'] as List? ?? const []))
                ConcordanceEntry.fromJson(e as Map<String, dynamic>),
            ],
          ),
      ];
    } catch (_) {
      return _topicCache[topicId] = const [];
    }
  }

  /// The topics that cite a given verse — the verse-aware entry point.
  ///
  /// Returns empty for anything outside Matthew–Revelation: the Modern
  /// Concordance is a New Testament Greek concordance, so an Old
  /// Testament verse has no entry and that is not a failure.
  static Future<List<ConcordanceCitation>> forVerse({
    required String englishBook,
    required int chapter,
    required int verse,
  }) async {
    await topics();
    if (_byId.isEmpty) return const [];
    final file = englishBook.toLowerCase().replaceAll(' ', '_');
    var book = _verseCache[file];
    if (book == null) {
      try {
        final j = json.decode(await rootBundle.loadString('$_base/v/$file.json'))
            as Map<String, dynamic>;
        book = {
          for (final e in j.entries)
            e.key: [for (final r in e.value as List) r as List<dynamic>],
        };
      } catch (_) {
        book = const {};
      }
      _verseCache[file] = book;
    }
    final rows = book['$chapter:$verse'];
    if (rows == null) return const [];
    final out = <ConcordanceCitation>[];
    final seen = <String>{};
    for (final r in rows) {
      final topicId = r[0] as int;
      final strongs = (r[4] ?? '').toString();
      // One topic can cite a verse through several of its Greek words —
      // Matthew 24:15 reaches "Prophet" via both G1158 and G4396. Showing
      // the topic once per word would read as duplication, so dedupe on
      // the pair and let the topic line carry whichever came first.
      if (!seen.add('$topicId/$strongs')) continue;
      final topic = _byId[topicId];
      if (topic == null) continue;
      out.add(ConcordanceCitation(
          topicId: topicId, topic: topic, strongs: strongs));
    }
    out.sort((a, b) => a.topic.en.compareTo(b.topic.en));
    return out;
  }

  @visibleForTesting
  static void resetForTest() {
    _topics = null;
    _byId = const {};
    _greek = const {};
    _attribution = '';
    _topicCache.clear();
    _verseCache.clear();
  }
}
