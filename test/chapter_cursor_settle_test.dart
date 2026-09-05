/// Moving the reference moves the CURSOR with it.
///
/// `currentVerse` is the workspace cursor, and the reading pane's header
/// opens the book/chapter/verse picker at `currentVerse.book` /
/// `.chapter` rather than at `currentBook` / `currentChapter` — see the
/// `onBookTap` that pushes `BooksPage` in `bible_reading_pane.dart`. So
/// a cursor left behind by a reference move is a picker that opens on
/// the chapter the reader was on BEFORE they navigated.
///
/// The move that leaves it behind is the URL one:
/// `url_sync_service_web.dart` calls `setCurrentChapter` for every hash
/// it applies and `updateCurrentVerse` only when the link carried a
/// `:verse`. Chapter-only links, and browser Back / Forward onto a
/// chapter-only history entry, are the reachable cases. That file
/// imports `dart:js_interop` and cannot be reached by a VM test at all,
/// so these tests drive the provider the way it drives it — the same
/// call, in the same order, with no `updateCurrentVerse` behind it.
///
/// What is NOT covered here: that the reader's own `PageView` cannot
/// repair the cursor afterwards. That depends on `onPageChanged`'s
/// `if (idx == currentChapterPageIdx) return` gate firing against a
/// provider that has already moved, which is a widget-level ordering
/// fact about a pane that mounts a dozen services. It is stated in the
/// provider's comment and was read out of the source, not measured
/// here.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/providers/main_provider.dart';

Verse _v(String book, int chapter, int verse) =>
    Verse(book: book, chapter: chapter, verse: verse, text: '$book $chapter:$verse');

/// Two books, three chapters, so a move can cross a chapter AND a book.
final _corpus = <Verse>[
  _v('Genesis', 1, 1),
  _v('Genesis', 1, 2),
  _v('Genesis', 2, 1),
  _v('Genesis', 2, 2),
  _v('John', 3, 16),
  _v('John', 3, 17),
];

MainProvider _loaded() {
  final mp = MainProvider();
  mp.setVerses(List<Verse>.from(_corpus));
  mp.setCurrentChapter(book: 'Genesis', chapter: 1);
  mp.updateCurrentVerse(verse: _corpus.first);
  return mp;
}

void main() {
  // setCurrentChapter persists through saveCurrentState(), which needs a
  // binding and a prefs store. Neither is what is under test.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a chapter move with no verse behind it carries the cursor', () {
    final mp = _loaded();
    expect(mp.currentVerse?.chapter, 1, reason: 'precondition');

    // Exactly what url_sync_service_web.dart does for `#/genesis/2`:
    // setCurrentChapter, and nothing else.
    mp.setCurrentChapter(book: 'Genesis', chapter: 2);

    expect(mp.currentVerse?.chapter, 2,
        reason: 'the cursor is what the reading pane header opens the '
            'picker at — left on chapter 1 it opens the picker on the '
            'chapter the reader just left');
    expect(mp.currentVerse?.book, 'Genesis');
    expect(mp.currentVerse?.verse, 1,
        reason: 'the first verse of the chapter, not an arbitrary one');
  });

  test('and across a book, which is what Back off a shared link does', () {
    final mp = _loaded();
    mp.setCurrentChapter(book: 'John', chapter: 3);
    expect(mp.currentVerse?.book, 'John');
    expect(mp.currentVerse?.chapter, 3);
    expect(mp.currentVerse?.verse, 16,
        reason: "the chapter's first verse by NUMBER — John 3 starts at "
            '16 in this fixture and the index sorts, so a cursor on '
            'verse 17 would mean the list order was trusted instead');
  });

  test('a caller that picks its own verse still wins', () {
    final mp = _loaded();
    // The search-hit shape: setCurrentChapter, then the specific verse.
    mp.setCurrentChapter(book: 'John', chapter: 3);
    mp.updateCurrentVerse(verse: _corpus.last);
    expect(mp.currentVerse?.verse, 17);
  });

  test('a cursor already inside the chapter is not disturbed', () {
    final mp = _loaded();
    mp.updateCurrentVerse(verse: _v('Genesis', 1, 2));
    // Re-stating the chapter the reader is already on — every
    // notifyListeners in the pane can reach here.
    mp.setCurrentChapter(book: 'Genesis', chapter: 1);
    expect(mp.currentVerse?.verse, 2,
        reason: 'settling an already-settled cursor would scroll the '
            'reader back to verse 1 on an unrelated rebuild');
  });

  test('a chapter the corpus does not carry leaves the cursor alone', () {
    final mp = _loaded();
    // A partial-canon edition, or a versification the loaded corpus
    // numbers differently. A null cursor reads as "nothing open yet",
    // which is a bigger lie than a stale one.
    mp.setCurrentChapter(book: 'Obadiah', chapter: 1);
    expect(mp.currentVerse, isNotNull);
    expect(mp.currentVerse?.book, 'Genesis');
  });
}
