/// 2026-08-09 (#298): `books` is a projection of `verses`, and the
library;

/// reader goes blank the moment the two disagree.
///
/// The reported symptom was a workbench whose Browse mode rendered
/// Genesis 1 fine while the reader and split modes showed nothing —
/// and, on the first page, "End of Bible". Reproduced on dev v1.6.83
/// by switching edition from the Browse nav strip, which called
/// `setVersion` + `FetchVerses` and skipped `FetchBooks`: the pager's
/// page identities stayed on the previous edition's book names
/// ('Genesis') while the verses moved to the new one ('创世纪'), so
/// every page asked for a chapter that, under that name, held nothing.
///
/// These tests pin the invariant at the two places `verses` is
/// assigned, so no future caller can perform half a version swap.

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/utils/build_books_from_verses.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Verse> _chapter(String book, int chapter, int count) => [
      for (int i = 1; i <= count; i++)
        Verse(book: book, chapter: chapter, verse: i, text: '$book $chapter:$i'),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // `setVersion` persists the reading position; without a backing
  // store it throws after the test completes.
  SharedPreferences.setMockInitialValues(<String, Object>{});

  group('buildBooksFromVerses', () {
    test('titles books with the edition\'s own name, in canonical order', () {
      final books = buildBooksFromVerses([
        ..._chapter('约翰福音', 1, 2),
        ..._chapter('创世纪', 1, 3),
      ]);
      expect(books.map((b) => b.title).toList(), ['创世纪', '约翰福音']);
    });

    test('sorts chapters numerically, not by first appearance', () {
      final books = buildBooksFromVerses([
        ..._chapter('Genesis', 10, 1),
        ..._chapter('Genesis', 2, 1),
        ..._chapter('Genesis', 1, 1),
      ]);
      expect(books.single.chapters.map((c) => c.title).toList(), [1, 2, 10]);
    });

    test('sorts verses within a chapter', () {
      final books = buildBooksFromVerses([
        Verse(book: 'Genesis', chapter: 1, verse: 3, text: 'c'),
        Verse(book: 'Genesis', chapter: 1, verse: 1, text: 'a'),
        Verse(book: 'Genesis', chapter: 1, verse: 2, text: 'b'),
      ]);
      expect(
        books.single.chapters.single.verses.map((v) => v.verse).toList(),
        [1, 2, 3],
      );
    });

    test('drops books outside the canonical 66', () {
      final books = buildBooksFromVerses([
        ..._chapter('Genesis', 1, 1),
        ..._chapter('Enoch', 1, 1),
      ]);
      expect(books.map((b) => b.title).toList(), ['Genesis']);
    });

    test('an empty verse list projects to no books', () {
      expect(buildBooksFromVerses(const []), isEmpty);
    });
  });

  group('booksMatchVerses', () {
    test('true for a projection of the same verses', () {
      final verses = _chapter('创世纪', 1, 3);
      expect(booksMatchVerses(buildBooksFromVerses(verses), verses), isTrue);
    });

    test('false when the book names come from another edition', () {
      final english = _chapter('Genesis', 1, 3);
      final chinese = _chapter('创世纪', 1, 3);
      expect(booksMatchVerses(buildBooksFromVerses(english), chinese), isFalse);
    });

    test('false when a chapter is missing from the projection', () {
      final one = _chapter('Genesis', 1, 3);
      final two = [...one, ..._chapter('Genesis', 2, 3)];
      expect(booksMatchVerses(buildBooksFromVerses(one), two), isFalse);
    });
  });

  group('MainProvider keeps books in step with verses', () {
    test('setVerses re-projects, so a caller that skips FetchBooks is safe',
        () {
      final mp = MainProvider();
      mp.setVerses(_chapter('Genesis', 1, 31));
      expect(mp.chapterList.first.book, 'Genesis');

      // The exact repro: change edition WITHOUT calling FetchBooks.
      mp.setVersion('cuvs-yhwh');
      mp.setVerses(_chapter('创世纪', 1, 31));

      expect(mp.chapterList.first.book, '创世纪');
      expect(mp.versesInChapter('创世纪', 1), hasLength(31));
      // And the page the reader lands on is addressable, which is what
      // failed: chapterList[0] resolved but held no verses.
      final first = mp.chapterList.first;
      expect(mp.versesInChapter(first.book, first.chapter), isNotEmpty);
    });

    test('the warm-cache swap re-projects too', () {
      final mp = MainProvider();
      mp.setVerses(_chapter('Genesis', 1, 31));
      mp.cacheVersionForTest('cuvs-yhwh', _chapter('创世纪', 1, 31));

      expect(mp.useCachedVersion('cuvs-yhwh'), isTrue);
      expect(mp.chapterList.first.book, '创世纪');
      expect(mp.versesInChapter('创世纪', 1), hasLength(31));
    });

    test('an empty load leaves the previous projection standing', () {
      final mp = MainProvider();
      mp.setVerses(_chapter('Genesis', 1, 31));
      mp.setVerses(const []);
      // A failed fetch is not an empty Bible: the revert-to-previous
      // path in the reading pane needs something to revert to.
      expect(mp.books, isNotEmpty);
    });

    test('resyncBooksWithVerses repairs a desync and reports it', () {
      final mp = MainProvider();
      mp.setVerses(_chapter('创世纪', 1, 31));
      // Force the broken state the old code could reach.
      mp.setBooks(buildBooksFromVerses(_chapter('Genesis', 1, 31)));
      expect(mp.versesInChapter(mp.chapterList.first.book, 1), isEmpty);

      expect(mp.resyncBooksWithVerses(), isTrue);
      expect(mp.versesInChapter(mp.chapterList.first.book, 1), hasLength(31));
    });

    test('resync is a no-op when already in step, so it cannot loop', () {
      final mp = MainProvider();
      mp.setVerses(_chapter('创世纪', 1, 31));
      var notified = 0;
      mp.addListener(() => notified++);

      expect(mp.resyncBooksWithVerses(), isFalse);
      expect(notified, 0);
    });
  });
}
