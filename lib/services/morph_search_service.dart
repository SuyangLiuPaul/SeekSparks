/// 2026-08 (SeekSparks): runs a [MorphQuery] over the bundled originals.
///
/// Scope is chapter / book / testament. Testament is the widest useful
/// one because the query's scheme already picks a testament: a Greek
/// parse cannot occur in the Hebrew Bible, so "whole Bible" would be the
/// same scan with half of it guaranteed to miss.
///
/// Measured on the Dart VM over the whole corpus (438,821 words): the
/// asset load and JSON decode is 874 ms for the OT and 681 ms for the
/// NT, and both are already cached by [OriginalsService] after the first
/// use. The scan itself is ~120 ms. The web build will be slower, hence
/// the yield between books so the pane can paint a spinner rather than
/// freeze.
library;

import 'package:seeksparks/constants/book_groups.dart';
import 'package:seeksparks/models/original_word.dart';
import 'package:seeksparks/services/originals_service.dart';
import 'package:seeksparks/utils/morph_query.dart';
import 'package:seeksparks/utils/morphology.dart';

enum MorphScope { chapter, book, testament }

class MorphHit {
  const MorphHit({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.wordIndex,
    required this.word,
    required this.parsed,
    required this.morphemeIndex,
  });

  final String book;
  final int chapter;
  final int verse;

  /// Position in the verse, so the reader can be scrolled to the word
  /// and not merely to the verse.
  final int wordIndex;

  final OriginalWord word;
  final MorphWord parsed;

  /// Which morpheme answered the query. On a stacked Hebrew word this is
  /// the difference between an explained hit and an inexplicable one.
  final int morphemeIndex;

  MorphMorpheme get morpheme => parsed.morphemes[morphemeIndex];
}

class MorphSearchResult {
  const MorphSearchResult({
    required this.hits,
    required this.total,
    required this.scanned,
    required this.facets,
  });

  /// Capped at the limit passed to [MorphSearchService.run].
  final List<MorphHit> hits;

  /// Every match, including those past the cap.
  final int total;

  /// Words carrying a code in this scheme — the denominator a frequency
  /// claim needs.
  final int scanned;

  final MorphFacets facets;

  bool get truncated => total > hits.length;
}

class MorphSearchService {
  /// 4,037 distinct codes cover all 438,821 words, and parsing every one
  /// of them takes 18 ms — so memoising by code string makes re-running a
  /// query after every click essentially free, at a cost of one small map.
  static final Map<String, MorphWord?> _parsed = <String, MorphWord?>{};

  static MorphWord? parse(String? code) {
    if (code == null || code.isEmpty) return null;
    if (_parsed.containsKey(code)) return _parsed[code];
    return _parsed[code] = parseMorphology(code);
  }

  static void clearCache() => _parsed.clear();

  /// The books a scope covers. [book] is the reader's current book and is
  /// only consulted for the chapter and book scopes.
  static List<String> booksFor(
    MorphScope scope,
    String book,
    MorphScheme scheme,
  ) =>
      switch (scope) {
        MorphScope.chapter || MorphScope.book => [book],
        MorphScope.testament => scheme == MorphScheme.greek
            ? canonicalNtBooks
            : canonicalOtBooks,
      };

  static Future<MorphSearchResult> run(
    MorphQuery query, {
    required List<String> books,
    int? chapter,
    int limit = 300,
  }) async {
    final hits = <MorphHit>[];
    final facets = MorphFacets(query);
    var total = 0;
    var scanned = 0;

    for (final book in books) {
      final verses = await OriginalsService.versesOfBook(book);
      final refs = verses.keys.toList()..sort(_byReference);
      for (final ref in refs) {
        final split = ref.indexOf(':');
        if (split < 0) continue;
        final c = int.tryParse(ref.substring(0, split));
        final v = int.tryParse(ref.substring(split + 1));
        if (c == null || v == null) continue;
        if (chapter != null && c != chapter) continue;

        final words = verses[ref]!;
        for (var i = 0; i < words.length; i++) {
          final parsedWord = parse(words[i].morph);
          if (parsedWord == null || parsedWord.scheme != query.scheme) {
            continue;
          }
          scanned++;
          facets.add(parsedWord);
          final m = query.match(parsedWord);
          if (m < 0) continue;
          total++;
          if (hits.length < limit) {
            hits.add(MorphHit(
              book: book,
              chapter: c,
              verse: v,
              wordIndex: i,
              word: words[i],
              parsed: parsedWord,
              morphemeIndex: m,
            ));
          }
        }
      }
      // Let the pane paint between books; a testament is 39 of these.
      await Future<void>.delayed(Duration.zero);
    }

    return MorphSearchResult(
      hits: hits,
      total: total,
      scanned: scanned,
      facets: facets,
    );
  }

  /// "10:2" must sort after "9:30", which a string compare gets wrong.
  static int _byReference(String a, String b) {
    final ai = a.indexOf(':');
    final bi = b.indexOf(':');
    if (ai < 0 || bi < 0) return a.compareTo(b);
    final ac = int.tryParse(a.substring(0, ai)) ?? 0;
    final bc = int.tryParse(b.substring(0, bi)) ?? 0;
    if (ac != bc) return ac - bc;
    final av = int.tryParse(a.substring(ai + 1)) ?? 0;
    final bv = int.tryParse(b.substring(bi + 1)) ?? 0;
    return av - bv;
  }
}
