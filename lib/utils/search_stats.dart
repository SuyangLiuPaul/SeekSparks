/// 2026-08-06 (SeekSparks): Search Statistics — BibleWorks bwh23.
///
/// A hit count is a number; a DISTRIBUTION is an observation. That
/// ἀγαπάω clusters in John and 1 John, or that a word appears only in
/// the Pentateuch, is the kind of thing that changes what a passage
/// means — and it is invisible in a flat list of 140 references.
///
/// Counts by book, in canonical order, with the shares each testament
/// takes. Pure arithmetic over references; the widget draws the bars.
library;

/// Hits in one book.
class BookHits {
  const BookHits({
    required this.englishBook,
    required this.count,
    required this.isOldTestament,
  });

  final String englishBook;
  final int count;
  final bool isOldTestament;
}

/// The whole distribution.
class SearchDistribution {
  const SearchDistribution({
    required this.books,
    required this.total,
    required this.oldTestament,
    required this.newTestament,
    required this.peak,
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
  bool includeEmpty = false,
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
    books.add(BookHits(englishBook: name, count: safe, isOldTestament: isOt));
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
