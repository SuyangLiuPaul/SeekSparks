import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/services/concordance_service.dart';
import 'package:seeksparks/services/fetch_books.dart' show standardBookOrder;
import 'package:seeksparks/services/originals_service.dart';
import 'package:seeksparks/utils/diacritics.dart' show foldDiacritics;
import 'package:seeksparks/utils/ketiv_qere.dart'
    show KetivQereSearchScope;
import 'package:seeksparks/utils/plain_search.dart';
import 'package:seeksparks/utils/strongs_boolean_search.dart';
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

  /// The plain scan — a command line with no control character — over
  /// the parallel `verses` / `searchKeys` arrays (`searchKeys[i]` is the
  /// sanitized lowercase form of `verses[i].text`, precomputed once per
  /// `setVerses` by MainProvider — collapsing each search from O(n ×
  /// regex chain) to O(n × String.contains)).
  ///
  /// A substring scan, but not one that may step over a word gap the
  /// reader did not type: the rule and the reason are in
  /// `plain_search.dart`. In Chinese it is still the plain substring
  /// scan it always was, which is what that script needs.
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
    // Both sides folded, or `ὁ θεός` finds nothing in a corpus that
    // spells it `ο θεος` — #321. `searchKeys` is folded where it is
    // built; this is the other half of the same comparison.
    //
    // 2026-09-05: and both sides whitespace-normalized the same way, by
    // `plain_search.dart`, which is what stops `forth` from listing the
    // 2,542 KJV verses that say "for the". The segments are the runs the
    // reader typed with no space between them; each must sit next to the
    // last in the verse, separated by nothing but whitespace they did
    // type. See [plainSearchMatches].
    final segments = plainSearchSegments(
        foldDiacritics(query).toLowerCase());
    // A blank query listed every verse before this change, because the
    // empty string is a substring of everything, and it keeps doing so:
    // the callers guard it, and quietly turning "everything" into
    // "nothing" is not this fix's business.
    final matchAll = segments.isEmpty;
    // Every segment is a necessary condition; the longest is the
    // cheapest way to reject a verse before the walk.
    final prefilter = plainSearchPrefilter(segments);
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
      final key = searchKeys[i];
      if (matchAll ||
          (key.contains(prefilter) && plainSearchMatches(key, segments))) {
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
  /// [ketivQere] is bwh29's pair of search switches, applied to the
  /// per-verse word order the proximity pass reads.
  ///
  /// This is the one place in the Strong's path where the setting CAN be
  /// applied, and saying why matters. The set algebra above it runs on
  /// `ConcordanceService`, which is a verse-level occurrence index and
  /// carries no Masoretic role per word — so a Ketiv-only occurrence
  /// still puts its verse in the candidate set. The proximity narrowing
  /// reads `assets/originals/<book>.json`, which does carry the role,
  /// and an excluded word is dropped from the word order before any
  /// distance is measured. A reader who excludes the Ketiv therefore
  /// gets an honest answer from `G25 NEAR5 G26` and an unfiltered one
  /// from `G25 AND G26`; closing that needs a role-aware concordance
  /// index, which is a data change, not a parameter.
  static Future<StrongsBooleanResult> runStrongsBoolean(
    StrongsBooleanQuery query, {
    KetivQereSearchScope ketivQere = KetivQereSearchScope.both,
  }) async {
    // Resolve each term to its occurrence label-set (expanding wildcards),
    // then apply the AND/OR set algebra.
    final termRefs = <StrongsTerm, Set<String>>{};
    // Whether any term stands for less than it names. Since v1.6.96 the
    // per-entry verse lists are complete, so the one way this can still
    // happen is a wildcard whose expansion was stopped — `G1✶` matches
    // 1,067 numbers and only the first 300 are unioned. The set algebra
    // below then ran over part of the term, so the answer may be missing
    // verses — see [StrongsBooleanResult.truncatedTerms].
    var truncated = false;
    for (final t in query.terms) {
      if (termRefs.containsKey(t)) continue;
      final labels = <String>{};
      if (t.wildcard) {
        final expansion =
            await ConcordanceService.numbersMatchingPrefix(t.number);
        if (expansion.cut) truncated = true;
        for (final n in expansion.numbers) {
          final r = await ConcordanceService.lookup(n);
          if (r == null) continue;
          labels.addAll(r.refs.map((e) => e.label));
        }
      } else {
        final r = await ConcordanceService.lookup(t.number);
        if (r != null) labels.addAll(r.refs.map((e) => e.label));
      }
      termRefs[t] = labels;
    }
    var resultLabels = evaluateStrongsBoolean(
        query, (t) => termRefs[t] ?? const <String>{});
    // SeekSparks addition: a proximity operator needs actual word order,
    // which the set algebra above can't see — narrow the AND-style
    // candidate set with a per-verse word-position check
    // (assets/originals/<book>.json via OriginalsService), one pair at a
    // time. `pair.ordered` is `BEFOREn` rather than `NEARn`: it must be
    // passed through, or a directional query is answered with the
    // unordered result set and nothing on screen says so.
    if (query.hasProximity && resultLabels.isNotEmpty) {
      for (final pair in proximityPairs(query)) {
        final (i, j, maxWords) = (pair.a, pair.b, pair.maxWords);
        final termA = query.terms[i];
        final termB = query.terms[j];
        final keep = <String>{};
        for (final label in resultLabels) {
          final parsed = ConcordanceRef.tryParse(label);
          if (parsed == null) continue;
          final words = await OriginalsService.forVerse(
              parsed.englishBook, parsed.chapter, parsed.verse);
          if (words == null) continue;
          // Dropped, not blanked: a placeholder would still occupy a
          // word position and push the two terms apart, so excluding a
          // reading would silently narrow every window it sits inside.
          final numsInOrder = [
            for (final w in words)
              if (ketivQere.admits(w.ketivQere)) w.strongs
          ];
          if (verseSatisfiesProximity(
              strongsNumbersInOrder: numsInOrder,
              termA: termA,
              termB: termB,
              maxWords: maxWords,
              ordered: pair.ordered)) {
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
}

/// A composed Strong's expression's verses, and whether they are all of
/// them.
///
/// Until v1.6.96 this was answered by the concordance's own 500-verse
/// cap: `G3588 AND G2532` intersected two prefixes that both ended
/// inside Matthew and returned a confident answer about the whole New
/// Testament from data that never left one Gospel. The verse lists are
/// complete now, so the only remaining source is a wildcard expansion
/// stopped at its own limit. The flag is what lets a caller refuse to
/// draw a distribution from a term that stands for less than it names.
class StrongsBooleanResult {
  const StrongsBooleanResult({required this.refs, this.truncatedTerms = false});

  final List<ConcordanceRef> refs;
  final bool truncatedTerms;
}
