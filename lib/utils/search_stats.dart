/// 2026-08-06 (SeekSparks): Search Statistics — BibleWorks bwh23.
///
/// A hit count is a number; a DISTRIBUTION is an observation. That
/// ἀγαπάω clusters in John and 1 John, or that a word appears only in
/// the Pentateuch, is the kind of thing that changes what a passage
/// means — and it is invisible in a flat list of 140 references.
///
/// Counts by book, in canonical order, with the shares each testament
/// takes. Pure arithmetic over references; the widget draws the bars.
///
/// 2026-08-10 (#308): a count here has a UNIT, and it is now declared
/// rather than assumed. bwh23's "What to Plot" dropdown separates
/// *"Number of verses in the book containing a hit"* from *"Number of
/// hits in the book"* as two menu entries, and the two differ by a
/// third on a common word — G25 is 27 verses but 37 occurrences in
/// John. Every builder here therefore names its [HitUnit], and every
/// surface that draws one prints it.
library;

/// What one unit of a distribution counts.
///
/// The distinction is bwh23's and it is not pedantry: a reader arriving
/// from software that plots occurrences reads "John 27" as a frequency
/// and is wrong by ten.
enum HitUnit {
  /// Verses carrying at least one hit — bwh23's "Number of verses in
  /// the book containing a hit", and what a result LIST holds.
  verses,

  /// Individual hits — bwh23's "Number of hits in the book". A verse
  /// carrying the word twice counts twice.
  occurrences,
}

/// Hits in one book.
class BookHits {
  const BookHits({
    required this.englishBook,
    required this.count,
    required this.isOldTestament,
    this.secondary,
  });

  final String englishBook;

  /// The book's count in the distribution's [SearchDistribution.unit].
  final int count;

  final bool isOldTestament;

  /// The same book counted in the OTHER unit, when both are known.
  ///
  /// Null is the ordinary case: a text search knows its verses and
  /// nothing about occurrences, and a truncated verse list knows its
  /// occurrences and cannot know its verses. Where both exist the
  /// surfaces print both, because that settles the question permanently
  /// instead of teaching the reader one vocabulary at a time.
  final int? secondary;
}

/// The whole distribution.
class SearchDistribution {
  const SearchDistribution({
    required this.books,
    required this.total,
    required this.oldTestament,
    required this.newTestament,
    required this.peak,
    required this.unit,
    this.partial = false,
  });

  /// The books this distribution draws, in canonical order.
  ///
  /// Whether books with no hits appear here is the caller's choice, and
  /// bwh23 makes it one too ("Show Zeros … the graph will also show the
  /// chapters, books, or verses that do not contain a search hit"). It
  /// is not a matter of taste — it depends on whether the reader can
  /// see the LABELS:
  ///   * A labelled list omits them. 66 rows of mostly zeroes is not a
  ///     chart, it is a wall, and [bookCount] states the absence in one
  ///     number instead.
  ///   * A label-less strip keeps them. There the bar's POSITION is the
  ///     only thing naming the book, so dropping the empty ones slides
  ///     every remaining bar leftwards and "heavy in the Gospels"
  ///     becomes unreadable.
  final List<BookHits> books;

  final int total;
  final int oldTestament;
  final int newTestament;

  /// The largest single-book count, for scaling bars. Never zero when
  /// there is at least one hit, so callers can divide by it safely.
  final int peak;

  /// What [total] and every [BookHits.count] count.
  final HitUnit unit;

  /// True when [books] was tallied from a SAMPLE rather than a census —
  /// the source list stopped at a cap before every hit was seen.
  ///
  /// This is not a footnote. `concordance.json`'s verse list stops at
  /// 500, in canonical order, so a partial tally of a common word is not
  /// a rough distribution: it is a picture of the cap. Tallying H3068's
  /// listed verses puts the divine name in 3 books peaking in Exodus,
  /// where it is in 36 peaking in Jeremiah. A surface handed a partial
  /// distribution must say so and must NOT draw the bars — a wrong shape
  /// drawn confidently is worse than no shape, because a reader has
  /// nothing to check it against.
  final bool partial;

  /// The unit [BookHits.secondary] is counted in.
  HitUnit get secondaryUnit =>
      unit == HitUnit.verses ? HitUnit.occurrences : HitUnit.verses;

  /// Whether any book carries a second count worth printing.
  bool get hasSecondary => books.any((b) => b.secondary != null);

  bool get isEmpty => total == 0;

  /// How many books actually carry a hit.
  ///
  /// Counted rather than taken from `books.length`, because that length
  /// depends on whether the caller asked for the empty books. "Occurs in
  /// 24 books" has to mean the same thing under both renderings.
  int get bookCount => books.where((b) => b.count > 0).length;

  /// Share of hits in the OT, 0–1. Zero when there are no hits at all
  /// rather than NaN, which would render as a blank bar.
  double get oldTestamentShare => total == 0 ? 0 : oldTestament / total;
}

/// Count hits per book.
///
/// [bookOrder] is the canonical 66-book list; anything not in it is
/// dropped rather than appended, because an unrecognised book name
/// means a stale reference and putting it at the end would present it
/// as canonical.
SearchDistribution buildDistribution({
  required Iterable<String> hitBooks,
  required List<String> bookOrder,
  required Set<String> oldTestamentBooks,
  required HitUnit unit,
  Map<String, int>? secondaryCounts,
  bool partial = false,
}) {
  final known = bookOrder.toSet();
  final counts = <String, int>{};
  for (final b in hitBooks) {
    if (!known.contains(b)) continue;
    counts[b] = (counts[b] ?? 0) + 1;
  }
  return buildDistributionFromCounts(
    counts: counts,
    bookOrder: bookOrder,
    oldTestamentBooks: oldTestamentBooks,
    unit: unit,
    secondaryCounts: secondaryCounts,
    partial: partial,
  );
}

/// The same distribution, from counts that were tallied elsewhere.
///
/// The concordance index stores a per-book count map already, absolute
/// and uncapped. [buildDistribution] would require expanding it back
/// into 6,521 repeated book names purely so this file could count them
/// again, and the reference list it would have to expand from is capped
/// at 500 — so that route is both wasteful and, for common words, wrong.
///
/// [includeEmpty] adds every book of [bookOrder] the counts do not
/// mention, at zero. See [SearchDistribution.books] for when that is the
/// right request.
SearchDistribution buildDistributionFromCounts({
  required Map<String, int> counts,
  required List<String> bookOrder,
  required Set<String> oldTestamentBooks,
  required HitUnit unit,
  Map<String, int>? secondaryCounts,
  bool includeEmpty = false,
  bool partial = false,
}) {
  final books = <BookHits>[];
  var total = 0;
  var ot = 0;
  var peak = 0;
  for (final name in bookOrder) {
    // A negative count is corrupt data, not a small one; treating it as
    // zero keeps it out of the total instead of subtracting from it.
    final c = counts[name] ?? 0;
    final safe = c > 0 ? c : 0;
    if (safe == 0 && !includeEmpty) continue;
    final isOt = oldTestamentBooks.contains(name);
    books.add(BookHits(
      englishBook: name,
      count: safe,
      isOldTestament: isOt,
      secondary: secondaryCounts?[name],
    ));
    total += safe;
    if (isOt) ot += safe;
    if (safe > peak) peak = safe;
  }

  return SearchDistribution(
    books: books,
    total: total,
    oldTestament: ot,
    newTestament: total - ot,
    peak: peak,
    unit: unit,
    partial: partial,
  );
}

/// The distribution a Strong's result can draw HONESTLY.
///
/// `concordance.json` describes the same word twice over, in two units:
///
///   * `b`, a per-book map of OCCURRENCES, summing exactly to the
///     entry's total.
///   * `r`, the VERSE list, in canonical order.
///
/// Both are complete since v1.6.96, so tallying `r` per book — the list
/// the reader is scrolling, and bwh23's default plot — is now correct
/// for all 14,039 numbers. It was not: `r` used to stop at 500, and
/// because the list is in canonical order a capped entry drew the cap
/// rather than the word. H3068's listed verses ended inside Leviticus,
/// putting the divine name in 3 books and peaking it in Exodus where it
/// is in 36 and peaks in Jeremiah; 58 of the 123 capped entries named
/// the wrong heaviest book.
///
/// [listTruncated] survives for the one incompleteness the data cannot
/// answer — a wildcard expansion stopped at its own limit, which drops
/// whole words out of a composed query. Nothing drawn from such a term
/// is a census.
SearchDistribution strongsDistribution({
  required Iterable<String> listedBooks,
  required List<String> bookOrder,
  required Set<String> oldTestamentBooks,
  Map<String, int> occurrencesByBook = const <String, int>{},
  bool listTruncated = false,
  bool scoped = false,
}) {
  // Scoped: the whole-Bible occurrence map describes a different corpus
  // than the listed verses do, so it can be neither the primary count
  // nor the secondary one. Printing it beside a scoped verse tally is
  // exactly the unit mixing this function exists to stop.
  if (scoped) {
    return buildDistribution(
      hitBooks: listedBooks,
      bookOrder: bookOrder,
      oldTestamentBooks: oldTestamentBooks,
      unit: HitUnit.verses,
      partial: listTruncated,
    );
  }

  if (listTruncated) {
    if (occurrencesByBook.isEmpty) {
      // A composed expression: a set operation over lists that were
      // already cut short, with no uncapped total anywhere to fall back
      // on. Nothing here is a census.
      return buildDistribution(
        hitBooks: listedBooks,
        bookOrder: bookOrder,
        oldTestamentBooks: oldTestamentBooks,
        unit: HitUnit.verses,
        partial: true,
      );
    }
    return buildDistributionFromCounts(
      counts: occurrencesByBook,
      bookOrder: bookOrder,
      oldTestamentBooks: oldTestamentBooks,
      unit: HitUnit.occurrences,
    );
  }

  return buildDistribution(
    hitBooks: listedBooks,
    bookOrder: bookOrder,
    oldTestamentBooks: oldTestamentBooks,
    unit: HitUnit.verses,
    secondaryCounts:
        occurrencesByBook.isEmpty ? null : occurrencesByBook,
  );
}

/// [d]'s books ordered by count, heaviest first.
///
/// bwh23's "Sort Books" dropdown, which offers canonical order and
/// ascending/descending value alongside each other because they answer
/// different questions: canonical order shows the SHAPE of a word across
/// the canon, sorted order ranks the books. Ties keep canonical order so
/// the list does not reshuffle between rebuilds.
///
/// Books at zero are dropped whatever [d] contains — a ranking of the
/// books a word does not appear in is 42 rows of nothing.
List<BookHits> booksByCount(SearchDistribution d) {
  final ranked = [
    for (var i = 0; i < d.books.length; i++)
      if (d.books[i].count > 0) (i, d.books[i]),
  ]..sort((a, b) {
      final c = b.$2.count.compareTo(a.$2.count);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
  return [for (final e in ranked) e.$2];
}

/// The books carrying the most hits, for a one-line summary.
///
/// Ties are broken by canonical order (the input order), so "Psalms ·
/// Isaiah" never swaps to "Isaiah · Psalms" between rebuilds.
List<BookHits> topBooks(SearchDistribution d, {int limit = 3}) {
  final out = booksByCount(d);
  return out.length <= limit ? out : out.sublist(0, limit);
}
