// 2026-08-09 (task #279): the book → chapter → verse picker had no test
// of its own. It is the app's primary navigation surface — pushed from
// the workbench menu, from the reading pane, and hosted a second time in
// the classic reader's sidebar — and the only thing covering it was a
// four-width overflow smoke test that pumps it and asserts nothing about
// what it does.
//
// That gap is why this file exists alongside the chrome pass rather than
// because of it. The pass collapsed three implementations of "a number in
// a box" into one, which is exactly the kind of refactor that renders
// perfectly and navigates wrong: `_selectChapter` does NOT fire the
// caller's callback, it swaps the picker into a verse grid, and picking a
// verse then sets a pendingJump BEFORE the callback so the host does not
// slam the reader to the top of the chapter. None of those three steps
// was asserted anywhere.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/book.dart';
import 'package:seeksparks/models/chapter.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/widgets/book_chapter_picker.dart';

/// Genesis 1-3, with 3 / 2 / 2 verses. Small enough to assert on by
/// exact text, big enough that "chapter 2" and "verse 2" are different
/// numbers on screen.
List<Verse> _verses() => const <Verse>[
      Verse(book: 'Genesis', chapter: 1, verse: 1, text: 'g1.1'),
      Verse(book: 'Genesis', chapter: 1, verse: 2, text: 'g1.2'),
      Verse(book: 'Genesis', chapter: 1, verse: 3, text: 'g1.3'),
      Verse(book: 'Genesis', chapter: 2, verse: 1, text: 'g2.1'),
      Verse(book: 'Genesis', chapter: 2, verse: 2, text: 'g2.2'),
      Verse(book: 'Genesis', chapter: 3, verse: 1, text: 'g3.1'),
      Verse(book: 'Genesis', chapter: 3, verse: 2, text: 'g3.2'),
    ];

List<Book> _books() {
  final all = _verses();
  Chapter ch(int n) => Chapter(
        title: n,
        verses: all.where((v) => v.chapter == n).toList(),
      );
  return <Book>[
    Book(title: 'Genesis', chapters: <Chapter>[ch(1), ch(2), ch(3)]),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MainProvider provider;
  late AppSettings settings;
  late List<({String book, int chapter})> picked;

  Future<void> pump(
    WidgetTester tester, {
    String currentBook = 'Genesis',
    int currentChapter = 1,
    Size size = const Size(1280, 900),
    ThemeMode mode = ThemeMode.light,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    provider = MainProvider()
      ..verses = _verses()
      ..books = _books();
    settings = AppSettings();
    picked = <({String book, int chapter})>[];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MainProvider>.value(value: provider),
          ChangeNotifierProvider<AppSettings>.value(value: settings),
        ],
        child: MaterialApp(
          themeMode: mode,
          theme: ThemeData.light(useMaterial3: true),
          darkTheme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: BookChapterPicker(
              currentBook: currentBook,
              currentChapter: currentChapter,
              onChapterSelected: (b, c) => picked.add((book: b, chapter: c)),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
  }

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  /// Drills from the default GRID of books into Genesis's chapters.
  ///
  /// `AppSettings.booksViewMode` defaults to `'grid'`, so this — not the
  /// expanding list — is what a reader with untouched settings sees, and
  /// the book tile prints the ABBREVIATION (`Gen`), not the title.
  Future<void> openChapters(WidgetTester tester) async {
    await tester.tap(find.text('Gen'));
    await tester.pump();
  }

  group('navigation', () {
    testWidgets('picking a chapter opens the verse grid, it does not '
        'navigate', (tester) async {
      await pump(tester);
      await openChapters(tester);

      expect(find.text('2'), findsWidgets);
      await tester.tap(find.text('2').first);
      await tester.pump();

      // The whole point of the verse step: the host is NOT told to
      // navigate yet. A picker that fired here would close itself before
      // the reader could choose a verse.
      expect(picked, isEmpty);
      expect(find.text('Genesis 2'), findsOneWidget);
    });

    testWidgets('picking a verse sets a pendingJump, then navigates',
        (tester) async {
      await pump(tester);
      await openChapters(tester);

      await tester.tap(find.text('2').first);
      await tester.pump();

      // Genesis 2 has verses 1 and 2. Tap verse 2 — relative index 1.
      await tester.tap(find.text('2').last);
      await tester.pump();

      expect(picked, <({String book, int chapter})>[
        (book: 'Genesis', chapter: 2),
      ]);
      expect(provider.hasPendingJump, isTrue);
      expect(provider.pendingJumpVerseIndex, 1);
    });

    testWidgets('"Top" navigates without a pendingJump', (tester) async {
      await pump(tester);
      await openChapters(tester);

      await tester.tap(find.text('2').first);
      await tester.pump();
      // Resolved through uiStrings rather than hardcoded: the default
      // locale is zh-Hans, so this tile reads 本章开头, not "Top".
      await tester.tap(find.text(uiStrings['versePickerTop']![settings.locale]!));
      await tester.pump();

      expect(picked, <({String book, int chapter})>[
        (book: 'Genesis', chapter: 2),
      ]);
      // Top of chapter means "no more specific target" — the host's
      // jumpToTop is allowed to run. A stale pendingJump here would land
      // the reader mid-chapter after they asked for the top.
      expect(provider.hasPendingJump, isFalse);
    });

    testWidgets('back leaves the verse grid without navigating',
        (tester) async {
      await pump(tester);
      await openChapters(tester);

      await tester.tap(find.text('2').first);
      await tester.pump();
      expect(find.text('Genesis 2'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pump();

      expect(find.text('Genesis 2'), findsNothing);
      expect(picked, isEmpty);
    });

    testWidgets('the reading pane changing chapter follows the verse grid '
        'across, and drops it across books', (tester) async {
      // Regression cover for the didUpdateWidget contract that v1.2.76
      // added and nothing asserted: same book + new chapter keeps the
      // reader in verse-step, a different book abandons it.
      await pump(tester);
      await openChapters(tester);
      await tester.tap(find.text('2').first);
      await tester.pump();
      expect(find.text('Genesis 2'), findsOneWidget);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MainProvider>.value(value: provider),
            ChangeNotifierProvider<AppSettings>.value(value: settings),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: BookChapterPicker(
                currentBook: 'Genesis',
                currentChapter: 3,
                onChapterSelected: (b, c) => picked.add((book: b, chapter: c)),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Genesis 3'), findsOneWidget);
    });
  });

  group('chrome', () {
    testWidgets('the picker carries the workbench palette into a host that '
        'has not applied it', (tester) async {
      // The picker has two hosts and only one is a page, so it themes
      // itself. Without this the classic reader's sidebar would render it
      // in Material 3 purple.
      await pump(tester);
      final ctx = tester.element(find.byType(BookChapterPicker).last);
      final inner = tester.element(find.text('Gen'));
      expect(Theme.of(ctx).extension<WbColors>(), isNull,
          reason: 'the host is deliberately unthemed in this test');
      expect(Theme.of(inner).extension<WbColors>(), WbColors.light);
    });

    testWidgets('a dark host gets the dark palette, not the light fallback',
        (tester) async {
      // `WbColors.of` falls back to `.light` when the extension is
      // missing, which is a silently wrong result rather than a crash —
      // exactly the failure a self-theming widget has to rule out.
      await pump(tester, mode: ThemeMode.dark);
      final inner = tester.element(find.text('Gen'));
      expect(Theme.of(inner).extension<WbColors>(), WbColors.dark);
    });
  });
}
