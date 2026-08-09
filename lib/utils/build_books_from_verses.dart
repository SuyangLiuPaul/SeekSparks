import 'package:seeksparks/constants/book_names.dart';
import 'package:seeksparks/models/book.dart';
import 'package:seeksparks/models/chapter.dart';
import 'package:seeksparks/models/verse.dart';

/// Derives the book/chapter tree from a flat verse list.
///
/// 2026-08-09 (#298): extracted from `FetchBooks.execute` so that
/// `MainProvider` can run it itself. `books` was never independent
/// data — it has always been a *projection* of `verses`, and the
/// reader's blank-chapter bug was three version-switch sites
/// updating one without the other. A projection the provider can
/// compute is a projection that cannot fall out of step; keeping it
/// dependency-free (no `MainProvider`) is what makes that possible
/// and keeps it testable on the unit-test VM.
///
/// Semantics are FetchBooks' verbatim, and two of them are load-
/// bearing:
///   * a book whose English name is not in [standardBookOrder] is
///     dropped, not appended — the canonical order is the contract;
///   * [Book.title] is the *localised* name taken from the book's
///     first verse, because the reader's chapter pager and the URL
///     both address books by the name the loaded edition uses.
///
/// One pass per grouping level, where FetchBooks re-filtered the whole
/// verse list once per book (66 x 31,000). That mattered: this now
/// runs on every version swap, including the warm-cache path whose
/// entire purpose is to feel instant.
List<Book> buildBooksFromVerses(List<Verse> verses) {
  if (verses.isEmpty) return const <Book>[];

  final byEnglish = <String, List<Verse>>{};
  for (final v in verses) {
    (byEnglish[bookNameToEnglish[v.book] ?? v.book] ??= <Verse>[]).add(v);
  }

  final out = <Book>[];
  for (final english in standardBookOrder) {
    final bookVerses = byEnglish[english];
    if (bookVerses == null || bookVerses.isEmpty) continue;

    final byChapter = <int, List<Verse>>{};
    for (final v in bookVerses) {
      (byChapter[v.chapter] ??= <Verse>[]).add(v);
    }
    final numbers = byChapter.keys.toList()..sort();

    out.add(Book(
      title: bookVerses.first.book,
      chapters: [
        for (final n in numbers)
          Chapter(
            title: n,
            verses: byChapter[n]!..sort((a, b) => a.verse.compareTo(b.verse)),
          ),
      ],
    ));
  }
  return out;
}

/// True when [books] is the projection [verses] would produce, judged
/// on the identity the chapter pager actually consumes: the ordered
/// book titles and each book's ordered chapter numbers.
///
/// Deliberately not a deep verse comparison. This answers "can the
/// pager address the loaded text", which is the invariant that broke;
/// re-walking 31,000 verses to answer it would cost more than
/// rebuilding the projection outright.
bool booksMatchVerses(List<Book> books, List<Verse> verses) {
  final expected = buildBooksFromVerses(verses);
  if (expected.length != books.length) return false;
  for (int i = 0; i < expected.length; i++) {
    final a = expected[i];
    final b = books[i];
    if (a.title != b.title) return false;
    if (a.chapters.length != b.chapters.length) return false;
    for (int c = 0; c < a.chapters.length; c++) {
      if (a.chapters[c].title != b.chapters[c].title) return false;
    }
  }
  return true;
}
