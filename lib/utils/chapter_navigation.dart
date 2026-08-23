import 'package:seeksparks/models/book.dart';

/// Where "the next chapter" and "the previous chapter" are, given the
/// canon the CURRENT VERSION actually ships.
///
/// 2026-08-24 (#313): this used to live twice inside
/// `_BibleReadingPaneState` — fifty lines of index arithmetic that only
/// the reader's own bottom bar could reach. The workbench toolbar now
/// needs the same answer, and the reference it moves belongs to the
/// whole workspace (the Analysis pane and the status bar follow it), so
/// the traversal is here, pure and tested, rather than copied.
///
/// The canon is [MainProvider.books] — the books and chapters of the
/// version on screen, not a fixed 66/1189 table. That matters: an
/// NT-only edition has no chapter before Matthew 1, and the arithmetic
/// must say so rather than walking off the front of the list.
class ChapterRef {
  final String book;
  final int chapter;

  const ChapterRef(this.book, this.chapter);

  @override
  bool operator ==(Object other) =>
      other is ChapterRef && other.book == book && other.chapter == chapter;

  @override
  int get hashCode => Object.hash(book, chapter);

  @override
  String toString() => '$book $chapter';
}

/// The chapter [step] places away, crossing book boundaries.
///
/// Returns null at either end of the canon, and on any reference the
/// canon does not contain — a stale book title, or a chapter the
/// current version omits. Null means "there is nowhere to go", which is
/// what greys the button; it never means "try again".
ChapterRef? adjacentChapter(
  List<Book> books,
  String? book,
  int? chapter, {
  required int step,
}) {
  if (book == null || chapter == null || step == 0) return null;
  final bookIdx = books.indexWhere((b) => b.title == book);
  if (bookIdx < 0) return null;
  final chapters = books[bookIdx].chapters;
  final chapIdx = chapters.indexWhere((c) => c.title == chapter);
  if (chapIdx < 0) return null;

  final forward = step > 0;
  final withinBook = chapIdx + (forward ? 1 : -1);
  if (withinBook >= 0 && withinBook < chapters.length) {
    return ChapterRef(book, chapters[withinBook].title);
  }

  // Off the end of this book. Walk to the neighbouring book — skipping
  // any that ships no chapters at all, which a partial-canon edition
  // can produce — and take its first or last chapter.
  var next = bookIdx + (forward ? 1 : -1);
  while (next >= 0 && next < books.length) {
    final neighbour = books[next];
    if (neighbour.chapters.isNotEmpty) {
      final target =
          forward ? neighbour.chapters.first : neighbour.chapters.last;
      return ChapterRef(neighbour.title, target.title);
    }
    next += forward ? 1 : -1;
  }
  return null;
}

ChapterRef? nextChapter(List<Book> books, String? book, int? chapter) =>
    adjacentChapter(books, book, chapter, step: 1);

ChapterRef? previousChapter(List<Book> books, String? book, int? chapter) =>
    adjacentChapter(books, book, chapter, step: -1);
