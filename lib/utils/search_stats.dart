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

  /// Only books with at least one hit, in canonical order. Books with
  /// none are omitted rather than listed as zero — 66 rows of mostly
  /// zeroes is not a chart, it is a wall.
  final List<BookHits> books;

  final int total;
  final int oldTestament;
  final int newTestament;

  /// The largest single-book count, for scaling bars. Never zero when
  /// there is at least one hit, so callers can divide by it safely.
  final int peak;

  bool get isEmpty => total == 0;

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
  final counts = <String, int>{};
  for (final b in hitBooks) {
    if (!bookOrder.contains(b)) continue;
    counts[b] = (counts[b] ?? 0) + 1;
  }

  final books = <BookHits>[];
  var total = 0;
  var ot = 0;
  var peak = 0;
  for (final name in bookOrder) {
    final c = counts[name];
    if (c == null || c == 0) continue;
    final isOt = oldTestamentBooks.contains(name);
    books.add(BookHits(englishBook: name, count: c, isOldTestament: isOt));
    total += c;
    if (isOt) ot += c;
    if (c > peak) peak = c;
  }

  return SearchDistribution(
    books: books,
    total: total,
    oldTestament: ot,
    newTestament: total - ot,
    peak: peak,
  );
}

/// The books carrying the most hits, for a one-line summary.
///
/// Ties are broken by canonical order (the input order), so "Psalms ·
/// Isaiah" never swaps to "Isaiah · Psalms" between rebuilds.
List<BookHits> topBooks(SearchDistribution d, {int limit = 3}) {
  final sorted = [
    for (var i = 0; i < d.books.length; i++) (i, d.books[i]),
  ]..sort((a, b) {
      final c = b.$2.count.compareTo(a.$2.count);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
  final out = [for (final e in sorted) e.$2];
  return out.length <= limit ? out : out.sublist(0, limit);
}
