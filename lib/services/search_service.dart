import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/services/concordance_service.dart';
import 'package:seeksparks/services/fetch_books.dart' show standardBookOrder;
import 'package:seeksparks/services/originals_service.dart';
import 'package:seeksparks/utils/strongs_boolean_search.dart';
import 'package:seeksparks/utils/strongs_result_counts.dart'
    show kConcordanceRefCap;
import 'package:seeksparks/utils/strongs_proximity.dart';

/// Immutable result of a plain-text corpus scan — see
/// [SearchService.scanText].
class TextSearchResult {
  /// Matching verses in canonical (book/chapter/verse) order.
  final List<Verse> matches;

  /// Book → hit count, ordered canonically (Genesis … Revelation).
  final Map<String, int> bookCounts;

  /// How many verses were actually scanned (after book scoping).
  final int scannedCount;

  const TextSearchResult({
    required this.matches,
    required this.bookCounts,
    required this.scannedCount,
  });
}

/// Shared search computation for both the standalone SearchPage and
/// the Workbench command pane.
///
/// 2026-08-04: extracted VERBATIM from `search_page.dart`
/// (`_searchImpl`'s scan block + `_runBooleanSearch`) so the two UIs
/// share one implementation and can never drift apart. Behavior must
/// stay identical — if you change the algorithm here, both callers
/// change.
class SearchService {
  SearchService._();

  /// Pure substring scan over the parallel `verses` / `searchKeys`
  /// arrays (`searchKeys[i]` is the sanitized lowercase form of
  /// `verses[i].text`, precomputed once per `setVerses` by
  /// MainProvider — collapsing each search from O(n × regex chain) to
  /// O(n × String.contains)).
  ///
  /// Scoping mirrors SearchPage: [filterBook] wins; otherwise the
  /// current book is used unless [searchAll] is true.
  static TextSearchResult scanText({
    required List<Verse> verses,
    required List<String> searchKeys,
    required String query,
    required Map<String, int> bookOrder,
    String? filterBook,
    bool searchAll = false,
    String? currentBook,
  }) {
    final queryNorm = query.replaceAll(' ', '').toLowerCase();
    final matches = <Verse>[];
    final localCounts = <String, int>{};
    final useFilter = filterBook != null;
    final useCurBook = !useFilter && !searchAll && currentBook != null;
    final filterTarget = filterBook ?? currentBook;
    var scanCount = 0;
    for (int i = 0; i < verses.length; i++) {
      final verse = verses[i];
      if (useFilter && verse.book != filterTarget) continue;
      if (useCurBook && verse.book != filterTarget) continue;
      scanCount++;
      if (searchKeys[i].contains(queryNorm)) {
        matches.add(verse);
        localCounts[verse.book] = (localCounts[verse.book] ?? 0) + 1;
      }
    }
    matches.sort((a, b) {
      final orderA = bookOrder[a.book] ?? 9999;
      final orderB = bookOrder[b.book] ?? 9999;
      if (orderA != orderB) return orderA.compareTo(orderB);
      if (a.chapter != b.chapter) return a.chapter.compareTo(b.chapter);
      return a.verse.compareTo(b.verse);
    });
    final sortedEntries = localCounts.entries.toList()
      ..sort((a, b) {
        final orderA = bookOrder[a.key] ?? 9999;
        final orderB = bookOrder[b.key] ?? 9999;
        return orderA.compareTo(orderB);
      });
    final orderedCounts = {for (final e in sortedEntries) e.key: e.value};
    return TextSearchResult(
      matches: matches,
      bookCounts: orderedCounts,
      scannedCount: scanCount,
    );
  }

  /// Evaluate a structured Strong's query (AND / OR / NOT / NEAR*n*)
  /// against the bundled concordance, narrowing NEAR candidates with
  /// the real per-verse original-language word order. Returns matching
  /// verse refs in canonical order.
  static Future<StrongsBooleanResult> runStrongsBoolean(
      StrongsBooleanQuery query) async {
    // Resolve each term to its occurrence label-set (expanding wildcards),
    // then apply the AND/OR set algebra.
    final termRefs = <StrongsTerm, Set<String>>{};
    // Whether any term's bundled verse list stopped at the cap. The set
    // algebra below then ran over a PREFIX of that term, so the answer
    // may be missing verses and any distribution drawn from it is a
    // sample — see [StrongsBooleanResult.truncatedTerms].
    var truncated = false;
    for (final t in query.terms) {
      if (termRefs.containsKey(t)) continue;
      final labels = <String>{};
      if (t.wildcard) {
        final nums = await ConcordanceService.numbersMatchingPrefix(t.number);
        for (final n in nums) {
          final r = await ConcordanceService.lookup(n);
          if (r == null) continue;
          labels.addAll(r.refs.map((e) => e.label));
          if (_entryTruncated(r)) truncated = true;
        }
      } else {
        final r = await ConcordanceService.lookup(t.number);
        if (r != null) {
          labels.addAll(r.refs.map((e) => e.label));
          if (_entryTruncated(r)) truncated = true;
        }
      }
      termRefs[t] = labels;
    }
    var resultLabels = evaluateStrongsBoolean(
        query, (t) => termRefs[t] ?? const <String>{});
    // SeekSparks addition: a NEARn operator needs actual word order, which
    // the set algebra above can't see — narrow the AND-style candidate set
    // with a per-verse word-position check (assets/originals/<book>.json
    // via OriginalsService), one NEAR pair at a time.
    if (query.hasProximity && resultLabels.isNotEmpty) {
      for (final (i, j, maxWords) in nearPairs(query)) {
        final termA = query.terms[i];
        final termB = query.terms[j];
        final keep = <String>{};
        for (final label in resultLabels) {
          final parsed = ConcordanceRef.tryParse(label);
          if (parsed == null) continue;
          final words = await OriginalsService.forVerse(
              parsed.englishBook, parsed.chapter, parsed.verse);
          if (words == null) continue;
          final numsInOrder = words.map((w) => w.strongs).toList();
          if (verseSatisfiesProximity(
              strongsNumbersInOrder: numsInOrder,
              termA: termA,
              termB: termB,
              maxWords: maxWords)) {
            keep.add(label);
          }
        }
        resultLabels = keep;
      }
    }
    final refs = <ConcordanceRef>[];
    for (final label in resultLabels) {
      final parsed = ConcordanceRef.tryParse(label);
      if (parsed != null) refs.add(parsed);
    }
    refs.sort((a, b) {
      final ai = standardBookOrder.indexOf(a.englishBook);
      final bi = standardBookOrder.indexOf(b.englishBook);
      if (ai != bi) return ai.compareTo(bi);
      if (a.chapter != b.chapter) return a.chapter.compareTo(b.chapter);
      return a.verse.compareTo(b.verse);
    });
    return StrongsBooleanResult(refs: refs, truncatedTerms: truncated);
  }

  /// Whether [r]'s bundled verse list stopped at the cap.
  ///
  /// A full 500 is not truncation on its own: an entry with 500
  /// occurrences in 500 verses is complete at exactly one hit per verse.
  /// The same test [strongsResultCounts] makes for the header.
  static bool _entryTruncated(ConcordanceResult r) =>
      r.refs.length >= kConcordanceRefCap && r.total > kConcordanceRefCap;
}

/// A composed Strong's expression's verses, and whether they are all of
/// them.
///
/// The set algebra runs over each term's BUNDLED verse list, which stops
/// at [kConcordanceRefCap]. `G3588 AND G2532` therefore intersects two
/// prefixes that both end inside Matthew, and returns a confident answer
/// about the whole New Testament from data that never left one Gospel.
/// The flag is what lets a caller refuse to draw that.
class StrongsBooleanResult {
  const StrongsBooleanResult({required this.refs, this.truncatedTerms = false});

  final List<ConcordanceRef> refs;
  final bool truncatedTerms;
}
