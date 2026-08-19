/// 2026-08-19 (SeekSparks): comparing two word lists — BibleWorks bwh26.
///
/// bwh26's own headline for the Word List Manager is not the list, it is
/// the comparison: *"find all words that occur in John that do not occur
/// anywhere else in the New Testament"*. We had the lists and no compare.
///
/// Three things a naive diff of two lists gets wrong, all of them fixed
/// here rather than in the widget:
///
/// 1. **The identity of a shared word is its LEMMA, not its form.** The
///    single-list view heads each row with the commonest surface form,
///    because that is what the reader meets on the page. Across two books
///    there is no one page: ἀγαπάω is ἠγάπησεν in one and ἀγαπῶντες in
///    the other, and heading the row with either would print one book's
///    inflection as if it were the thing the two share. So the compare
///    view heads with the lexicon lemma and keeps both forms beside it.
///
/// 2. **Two counts side by side invite a comparison the corpora do not
///    support.** Jude is 458 words and 2 Peter 1,099, so "3 · 4" is not
///    the tie it looks like. [WordComparison] therefore carries both
///    totals and the caller is expected to print them; nothing here
///    silently normalises, because a rate is a different number and
///    hiding which one is on screen is the defect (#308).
///
/// 3. **Two passages in different languages share nothing by
///    construction.** Genesis is tagged with H-numbers and John with
///    G-numbers, so "0 words in common" is arithmetically true and reads
///    as a finding. [WordComparison.sharesLanguage] is false there, and
///    the caller says so instead of printing the zero.
///
/// The instrument the whole thing is for is [WordComparisonRow.nowhereElse]:
/// a word whose occurrences in these two scopes account for **every**
/// occurrence in the Bible. Measured on the real corpus, Jude and 2 Peter
/// have exactly three — συνευωχέομαι, ὑπέρογκος, ἐμπαίκτης — which are
/// the three words the commentaries cite for the literary relationship
/// between them. It costs nothing extra: `assets/strongs/concordance.json`
/// already holds the corpus total, and its `n` agrees with a tally of
/// `assets/originals/` over all 66 books for all 14,040 numbers, with
/// zero disagreements (`docs/DATA-INTEGRITY.md` check 3b, re-measured
/// 2026-08-19). That exactness is what lets the claim be stated flatly
/// rather than hedged.
///
/// **The claim needs the two scopes to be DISJOINT**, or the sum
/// double-counts and the test silently fails open. Two different books
/// always are; two verse ranges need not be, which is why the page above
/// compares books.
library;

import 'package:seeksparks/utils/word_list.dart';

/// Which of the two lists a word appeared in.
enum WordCompareBucket { both, onlyA, onlyB }

/// How a comparison is ordered.
enum WordCompareSort {
  /// Rarest in the whole Bible first. The default, and the reason the
  /// corpus total is fetched at all: a shared common word says nothing
  /// about two books, a shared rare one is an argument.
  corpusRarity,

  /// Commonest across the two scopes first — the pair's skeleton.
  combined,

  /// By Strong's number. Hebrew before Greek, then numerically.
  number,

  /// By the lemma, for looking something up.
  alphabetical,
}

/// One word across both scopes.
class WordComparisonRow {
  const WordComparisonRow({
    required this.strongs,
    required this.headword,
    required this.countA,
    required this.countB,
    this.formA,
    this.formB,
    this.lemma,
    this.lemmaTranslit,
    this.corpusTotal,
  });

  /// e.g. `G4910`.
  final String strongs;

  /// What to print as the row's title: the lexicon lemma when there is
  /// one, otherwise whichever surface form we have. Never empty.
  final String headword;

  /// Occurrences in scope A. Zero means the word is absent there.
  final int countA;

  /// Occurrences in scope B. Zero means absent.
  final int countB;

  /// The commonest surface form in each scope, where the scope has the
  /// word at all. Kept because the two are often different and the
  /// difference is itself informative.
  final String? formA;
  final String? formB;

  /// The lexicon headword, when the number has an entry. Null for the
  /// extended MorphGNT numbers that have none.
  final String? lemma;
  final String? lemmaTranslit;

  /// Occurrences in the WHOLE Bible, from the concordance. Null when the
  /// caller supplied no totals, or the number is not in the index.
  final int? corpusTotal;

  WordCompareBucket get bucket => countA == 0
      ? WordCompareBucket.onlyB
      : countB == 0
          ? WordCompareBucket.onlyA
          : WordCompareBucket.both;

  int get combined => countA + countB;

  /// Every occurrence of this word in the Bible is inside these two
  /// scopes. See the library comment: exact, not an estimate, and only
  /// sound because the two scopes cannot overlap.
  bool get nowhereElse => corpusTotal != null && combined == corpusTotal;
}

/// The result of comparing two word lists.
class WordComparison {
  const WordComparison({
    required this.rows,
    required this.totalA,
    required this.totalB,
    required this.distinctA,
    required this.distinctB,
    required this.sharesLanguage,
  });

  final List<WordComparisonRow> rows;

  /// Word counts (tokens) in each scope. Printed by the caller so that
  /// two counts on a row are never read as comparable when the scopes
  /// are not the same size.
  final int totalA;
  final int totalB;

  /// Distinct Strong's numbers in each scope.
  final int distinctA;
  final int distinctB;

  /// Whether the two scopes use any Strong's prefix in common. False for
  /// a Hebrew book against a Greek one, where an empty intersection is a
  /// property of the numbering rather than a result.
  final bool sharesLanguage;

  int get bothCount => rows.where((r) => r.bucket == WordCompareBucket.both).length;
  int get onlyACount =>
      rows.where((r) => r.bucket == WordCompareBucket.onlyA).length;
  int get onlyBCount =>
      rows.where((r) => r.bucket == WordCompareBucket.onlyB).length;
  int get nowhereElseCount => rows.where((r) => r.nowhereElse).length;
}

/// The Strong's prefixes a list uses — `{'G'}`, `{'H'}`, or both.
Set<String> strongsPrefixes(Iterable<WordListEntry> list) {
  final out = <String>{};
  for (final e in list) {
    if (e.strongs.isNotEmpty) out.add(e.strongs[0].toUpperCase());
  }
  return out;
}

/// Compare two word lists built by [buildWordList].
///
/// [corpusTotals] maps a Strong's number to its occurrence count in the
/// whole Bible. Pass an empty map and [WordComparisonRow.nowhereElse] is
/// false everywhere and the rarity sort degrades to the combined one —
/// nothing is invented to fill the gap.
WordComparison compareWordLists(
  List<WordListEntry> a,
  List<WordListEntry> b, {
  WordCompareSort sort = WordCompareSort.corpusRarity,
  Map<String, int> corpusTotals = const {},
}) {
  final byA = {for (final e in a) e.strongs: e};
  final byB = {for (final e in b) e.strongs: e};

  final rows = <WordComparisonRow>[];
  for (final key in <String>{...byA.keys, ...byB.keys}) {
    final ea = byA[key];
    final eb = byB[key];
    // Either side's lexicon fields describe the same number, so take
    // whichever is present; they cannot disagree.
    final lemma = ea?.lemma ?? eb?.lemma;
    rows.add(WordComparisonRow(
      strongs: key,
      headword: [lemma, ea?.form, eb?.form].firstWhere(
            (s) => s != null && s.isNotEmpty,
            orElse: () => key,
          ) ??
          key,
      countA: ea?.count ?? 0,
      countB: eb?.count ?? 0,
      formA: ea?.form,
      formB: eb?.form,
      lemma: lemma,
      lemmaTranslit: ea?.lemmaTranslit ?? eb?.lemmaTranslit,
      corpusTotal: corpusTotals[key],
    ));
  }

  sortComparison(rows, sort);

  final sa = wordListSummary(a);
  final sb = wordListSummary(b);
  final pa = strongsPrefixes(a);
  final pb = strongsPrefixes(b);
  return WordComparison(
    rows: rows,
    totalA: sa.total,
    totalB: sb.total,
    distinctA: sa.distinct,
    distinctB: sb.distinct,
    // Two empty lists share nothing to disagree about; treat that as
    // compatible so an empty scope reads as empty rather than foreign.
    sharesLanguage:
        pa.isEmpty || pb.isEmpty || pa.intersection(pb).isNotEmpty,
  );
}

/// Sort in place. Every comparator falls through to the Strong's number
/// so a rebuild never reshuffles equal rows.
void sortComparison(List<WordComparisonRow> rows, WordCompareSort sort) {
  int byNumber(WordComparisonRow x, WordComparisonRow y) {
    final lx = x.strongs.isEmpty ? '' : x.strongs[0];
    final ly = y.strongs.isEmpty ? '' : y.strongs[0];
    final c = lx.compareTo(ly);
    if (c != 0) return c;
    return strongsNumericPart(x.strongs)
        .compareTo(strongsNumericPart(y.strongs));
  }

  switch (sort) {
    case WordCompareSort.corpusRarity:
      rows.sort((x, y) {
        // A number with no corpus total sorts last rather than first:
        // "unknown" is not "rare", and putting it at the top would head
        // the list with the rows we know least about.
        final cx = x.corpusTotal;
        final cy = y.corpusTotal;
        if (cx == null && cy == null) return byNumber(x, y);
        if (cx == null) return 1;
        if (cy == null) return -1;
        final c = cx.compareTo(cy);
        if (c != 0) return c;
        final d = y.combined.compareTo(x.combined);
        return d != 0 ? d : byNumber(x, y);
      });
    case WordCompareSort.combined:
      rows.sort((x, y) {
        final c = y.combined.compareTo(x.combined);
        return c != 0 ? c : byNumber(x, y);
      });
    case WordCompareSort.number:
      rows.sort(byNumber);
    case WordCompareSort.alphabetical:
      rows.sort((x, y) {
        final c = x.headword.compareTo(y.headword);
        return c != 0 ? c : byNumber(x, y);
      });
  }
}
