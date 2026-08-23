import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/book.dart';
import 'package:seeksparks/models/chapter.dart';
import 'package:seeksparks/utils/chapter_navigation.dart';

/// The chapter traversal behind the workspace toolbar's arrows, the
/// reader's `[` / `]` keys and its swipe (#313).
///
/// It ran for a year inside `_BibleReadingPaneState` with no test,
/// because reaching it meant building the whole reading pane. Pulled out
/// so the workbench toolbar could ask the same question, the interesting
/// cases become cheap: the ends of the canon, the book boundaries, and a
/// version whose canon is not the full 66.
Book _book(String title, List<int> chapters) => Book(
      title: title,
      chapters: [
        for (final c in chapters) Chapter(title: c, verses: const []),
      ],
    );

void main() {
  // Three books, the middle one short, so a boundary is crossed in one
  // step in either direction.
  final canon = [
    _book('创世记', [1, 2, 3]),
    _book('出埃及记', [1]),
    _book('利未记', [1, 2]),
  ];

  group('within a book', () {
    test('next moves one chapter on', () {
      expect(nextChapter(canon, '创世记', 1), const ChapterRef('创世记', 2));
    });

    test('previous moves one chapter back', () {
      expect(previousChapter(canon, '创世记', 3), const ChapterRef('创世记', 2));
    });
  });

  group('across a book boundary', () {
    test('next from the last chapter opens the next book at its first', () {
      expect(nextChapter(canon, '创世记', 3), const ChapterRef('出埃及记', 1));
    });

    test('previous from the first chapter opens the previous book at its last',
        () {
      expect(previousChapter(canon, '出埃及记', 1), const ChapterRef('创世记', 3));
    });

    test('a one-chapter book is stepped straight through, both ways', () {
      expect(nextChapter(canon, '出埃及记', 1), const ChapterRef('利未记', 1));
      expect(previousChapter(canon, '利未记', 1), const ChapterRef('出埃及记', 1));
    });
  });

  group('the ends of the canon', () {
    // Null is what greys the toolbar button. It has to be distinguishable
    // from "something went wrong", which is why nothing here throws.
    test('nothing before the first chapter of the first book', () {
      expect(previousChapter(canon, '创世记', 1), isNull);
    });

    test('nothing after the last chapter of the last book', () {
      expect(nextChapter(canon, '利未记', 2), isNull);
    });

    test('a partial canon ends where IT ends, not where the Bible does', () {
      // An NT-only edition: there is no Malachi 4 behind Matthew 1, and
      // the arithmetic must say so rather than walking off the list.
      final ntOnly = [
        _book('马太福音', [1, 2]),
        _book('马可福音', [1]),
      ];
      expect(previousChapter(ntOnly, '马太福音', 1), isNull);
      expect(nextChapter(ntOnly, '马可福音', 1), isNull);
    });
  });

  group('references the canon does not hold', () {
    test('an unknown book is null, not an exception', () {
      expect(nextChapter(canon, '所罗门智训', 1), isNull);
      expect(previousChapter(canon, '所罗门智训', 1), isNull);
    });

    test('a chapter this version omits is null', () {
      // Genesis has 3 chapters here; asking from 4 must not resolve to
      // "the last one" or to Exodus.
      expect(nextChapter(canon, '创世记', 4), isNull);
      expect(previousChapter(canon, '创世记', 4), isNull);
    });

    test('no book and no chapter yet is null', () {
      expect(nextChapter(canon, null, null), isNull);
      expect(previousChapter(canon, '创世记', null), isNull);
      expect(nextChapter(canon, null, 1), isNull);
    });

    test('an empty canon is null', () {
      expect(nextChapter(const [], '创世记', 1), isNull);
    });
  });

  group('books that ship no chapters', () {
    // A partial-canon edition can leave a book present but empty. Landing
    // on it would show a blank column, so the walk steps over it.
    final gappy = [
      _book('创世记', [1]),
      _book('出埃及记', const []),
      _book('利未记', [1, 2]),
    ];

    test('next steps over the empty book', () {
      expect(nextChapter(gappy, '创世记', 1), const ChapterRef('利未记', 1));
    });

    test('previous steps over it too, landing on the last real chapter', () {
      expect(previousChapter(gappy, '利未记', 1), const ChapterRef('创世记', 1));
    });
  });

  test('a step of zero goes nowhere', () {
    expect(adjacentChapter(canon, '创世记', 1, step: 0), isNull);
  });

  test('ChapterRef compares by value', () {
    expect(const ChapterRef('创世记', 2), const ChapterRef('创世记', 2));
    expect(const ChapterRef('创世记', 2), isNot(const ChapterRef('创世记', 3)));
    expect(const ChapterRef('创世记', 2).hashCode,
        const ChapterRef('创世记', 2).hashCode);
  });
}
