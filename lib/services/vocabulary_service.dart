import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:seeksparks/services/originals_service.dart';
import 'package:seeksparks/services/originals_stats_service.dart'
    show kStopwordStrongs;
import 'package:seeksparks/utils/vocabulary.dart';

/// Asset loading for the Vocabulary tab (bwh40). All the decisions live
/// in `utils/vocabulary.dart`; this only fetches and caches.
///
/// ── Why the scope is a three-way choice and not a verse range ──
///
/// bwh40's verse-range filter takes arbitrary ranges, semicolon
/// separated. We take chapter / book / corpus instead, because the cost
/// model is completely different: BibleWorks holds the whole tagged text
/// in memory, whereas here each book is a separate JSON asset and the
/// whole corpus is ~47 MB. Chapter and book are one asset load; corpus
/// is served from the precomputed concordance, which stores per-BOOK
/// totals and so cannot answer anything narrower.
///
/// The three cover what the filter is actually for — scoping a deck to
/// what you are about to read — without ever loading 66 files to answer
/// a question about one chapter.
enum VocabScope { chapter, book, corpus }

class VocabularyService {
  VocabularyService._();

  static List<VocabWord>? _corpusCache;
  static String? _corpusLocale;

  /// Reset caches. For tests.
  static void clearCache() {
    _corpusCache = null;
    _corpusLocale = null;
  }

  /// One [VocabWord] per Strong's number in the whole Bible, glossed for
  /// [locale]. Cached; re-parsed only when the locale changes.
  static Future<List<VocabWord>> corpusVocabulary(String locale) async {
    if (_corpusCache != null && _corpusLocale == locale) return _corpusCache!;
    try {
      final concordance =
          await rootBundle.loadString('assets/strongs/concordance.json');
      // Yield between the three heavy parses so the pane can paint its
      // spinner — together they are several MB.
      final decodedConcordance =
          jsonDecode(concordance) as Map<String, dynamic>;
      await Future<void>.delayed(Duration.zero);
      final hebrew = jsonDecode(
              await rootBundle.loadString('assets/strongs/hebrew.json'))
          as Map<String, dynamic>;
      await Future<void>.delayed(Duration.zero);
      final greek = jsonDecode(
              await rootBundle.loadString('assets/strongs/greek.json'))
          as Map<String, dynamic>;

      _corpusCache = vocabularyFromAssets(
        concordance: decodedConcordance,
        hebrewLexicon: hebrew,
        greekLexicon: greek,
        locale: locale,
        functionWords: kStopwordStrongs,
      );
      _corpusLocale = locale;
    } catch (_) {
      // Asset missing or malformed — an empty vocabulary shows the
      // pane's empty state rather than taking the workbench down.
      _corpusCache = const <VocabWord>[];
      _corpusLocale = locale;
    }
    return _corpusCache!;
  }

  /// The tagged text of [englishBook] as `"chapter:verse"` → Strong's
  /// numbers, which is the shape both [tallyStrongs] and
  /// [findExampleVerses] take.
  static Future<Map<String, List<String>>> versesOfBook(
      String englishBook) async {
    final raw = await OriginalsService.versesOfBook(englishBook);
    return <String, List<String>>{
      for (final e in raw.entries)
        e.key: <String>[
          for (final w in e.value)
            if (w.strongs.isNotEmpty) w.strongs,
        ],
    };
  }

  /// The deck's raw word list for [scope], before filtering.
  ///
  /// For [VocabScope.corpus] the scope count IS the corpus count, and
  /// the list is narrowed to the testament [englishBook] belongs to —
  /// nobody preparing to read Mark wants 8,640 Hebrew lemmas in the
  /// deck, and which alphabet you are working in is not a choice worth
  /// asking about when the book already answers it.
  static Future<List<VocabWord>> wordsForScope({
    required VocabScope scope,
    required String englishBook,
    required int chapter,
    required String locale,
  }) async {
    final all = await corpusVocabulary(locale);
    if (scope == VocabScope.corpus) {
      final hebrew = await _isHebrewBook(englishBook);
      return <VocabWord>[
        for (final w in all)
          if (w.isHebrew == hebrew) w,
      ];
    }

    final verses = await versesOfBook(englishBook);
    if (verses.isEmpty) return const <VocabWord>[];
    final scoped = scope == VocabScope.chapter
        ? versesInChapter(verses, chapter)
        : verses;
    final tally = tallyStrongs(scoped);
    return <VocabWord>[
      for (final w in all)
        if (tally.containsKey(w.strongs)) w.withScopeCount(tally[w.strongs]!),
    ];
  }

  /// Which alphabet a book is in, decided by the tagged text itself
  /// rather than by a canon list — the data is the authority on what it
  /// contains, and a hardcoded 39/27 split would be one more table to
  /// keep in step.
  static Future<bool> _isHebrewBook(String englishBook) async {
    final verses = await OriginalsService.versesOfBook(englishBook);
    for (final words in verses.values) {
      for (final w in words) {
        if (w.strongs.isNotEmpty) return w.strongs.startsWith('H');
      }
    }
    return false;
  }
}
