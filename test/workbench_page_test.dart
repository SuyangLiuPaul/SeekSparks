/// 2026-08-04 (Workbench): widget tests for `WorkbenchPage` — the
/// three-pane BibleWorks-style pad workspace. Covers the responsive
/// pane rules (3 panes ≥1024, 2 panes 600–1023, reader-only <600),
/// divider drag-resize, collapse/reopen rails, and the selection→
/// analysis wiring that embeds OriginalsSheet (with its close button
/// swapped for a collapse button in embedded mode).
///
/// Fixed pumps instead of pumpAndSettle — the reader kicks off async
/// loads (prefs, asset JSON) whose spinners never settle (same
/// pattern as responsive_all_pages_smoke_test.dart).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/pages/workbench_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/widgets/bible_reading_pane.dart';
import 'package:seeksparks/widgets/browse_window.dart';
import 'package:seeksparks/widgets/command_pane.dart';
import 'package:seeksparks/widgets/originals_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<MainProvider> pumpWorkbench(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    late MainProvider mp;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) {
            mp = MainProvider();
            mp.setVerses(const [
              Verse(book: 'Genesis', chapter: 1, verse: 1, text: 'seed 1'),
              Verse(book: 'Genesis', chapter: 1, verse: 2, text: 'seed 2'),
            ]);
            mp.setCurrentChapter(book: 'Genesis', chapter: 1);
            return mp;
          }),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: const MaterialApp(home: WorkbenchPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    return mp;
  }

  testWidgets('iPad landscape (1194×820): all three panes render',
      (tester) async {
    addTearDown(tester.view.reset);
    await pumpWorkbench(tester, const Size(1194, 820));
    expect(tester.takeException(), isNull);
    expect(find.byType(CommandPane), findsOneWidget);
    // 2026-08-06: the centre pane now defaults to the Browse window
    // (whole chapter × every version), matching BibleWorks. The chapter
    // reader is the alternate mode, reachable from View / the toolbar.
    expect(find.byType(BrowseWindow), findsOneWidget);
    expect(find.byType(BibleReadingPane), findsNothing);
    // No selection yet → analysis empty-state hint, no embedded sheet.
    expect(find.byType(OriginalsSheet), findsNothing);
    expect(find.byKey(const ValueKey('workbench-divider-left')), findsOneWidget);
    expect(find.byKey(const ValueKey('workbench-divider-right')),
        findsOneWidget);
  });

  testWidgets('iPad portrait (768×1024): command + reader, analysis hidden',
      (tester) async {
    addTearDown(tester.view.reset);
    await pumpWorkbench(tester, const Size(768, 1024));
    expect(tester.takeException(), isNull);
    expect(find.byType(CommandPane), findsOneWidget);
    // 768 is below the three-pane breakpoint, so Browse is suppressed
    // and the chapter reader holds the centre.
    expect(find.byType(BibleReadingPane), findsOneWidget);
    expect(find.byKey(const ValueKey('workbench-divider-right')), findsNothing);
    expect(find.byType(OriginalsSheet), findsNothing);
  });

  testWidgets('phone width (390): reader alone', (tester) async {
    addTearDown(tester.view.reset);
    await pumpWorkbench(tester, const Size(390, 844));
    expect(tester.takeException(), isNull);
    expect(find.byType(CommandPane), findsNothing);
    expect(find.byType(BibleReadingPane), findsOneWidget);
  });

  testWidgets('dragging the left divider resizes the command pane',
      (tester) async {
    addTearDown(tester.view.reset);
    await pumpWorkbench(tester, const Size(1366, 900));
    final before = tester.getSize(find.byType(CommandPane)).width;

    await tester.drag(
        find.byKey(const ValueKey('workbench-divider-left')),
        const Offset(60, 0));
    await tester.pump(const Duration(milliseconds: 100));

    final after = tester.getSize(find.byType(CommandPane)).width;
    expect(after, greaterThan(before));
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapse hides the command pane; the rail reopens it',
      (tester) async {
    addTearDown(tester.view.reset);
    await pumpWorkbench(tester, const Size(1366, 900));

    // The Search window's title strip carries the only left-pointing
    // collapse chevron (the Analysis strip's points right). Plain
    // `chevron_left` since the dense chrome dropped the rounded icons.
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CommandPane), findsNothing);
    expect(find.byKey(const ValueKey('workbench-rail-left')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('workbench-rail-left')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CommandPane), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'selecting a verse embeds OriginalsSheet with a collapse button '
      '(no close button)', (tester) async {
    addTearDown(tester.view.reset);
    final mp = await pumpWorkbench(tester, const Size(1366, 900));

    mp.toggleVerse(verse: mp.verses.first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.byType(OriginalsSheet), findsOneWidget);
    final sheet = find.byType(OriginalsSheet);
    // Embedded mode: collapse chevron replaces the sheet/route close
    // button (Navigator.maybePop would pop a route it doesn't own).
    expect(find.descendant(of: sheet, matching: find.byIcon(Icons.close)),
        findsNothing);
    expect(
        find.descendant(
            of: sheet, matching: find.byIcon(Icons.chevron_right_rounded)),
        findsOneWidget);
  });

  // 2026-08: 护眼纸质 reaches the workbench. Before this, the paper
  // setting was the ONLY setting in Settings → Display that did nothing
  // here — the BibleReadingPane had its own private override at the
  // verse-content level, and every workbench chrome surface read
  // WbColors.of directly. The Browse window was the obvious tell: cream
  // never reached it.
  Future<AppSettings> pumpWorkbenchPaper(WidgetTester tester,
      {required bool paper}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1366, 900);
    SharedPreferences.setMockInitialValues(
        <String, Object>{'readingPaperTheme': paper});
    // The pumpWorkbench helper above doesn't call loadSettings — its
    // AppSettings uses constructor defaults. We do the same, then flip
    // the paper flag via the public setter INSIDE a tester.runAsync
    // block so the awaited prefs write completes before the test ends.
    // Without runAsync, the framework's "no pending timers" assertion
    // fires on the dangling write.
    late AppSettings settings;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) {
            final mp = MainProvider();
            mp.setVerses(const [
              Verse(book: 'Genesis', chapter: 1, verse: 1, text: 'seed 1'),
              Verse(book: 'Genesis', chapter: 1, verse: 2, text: 'seed 2'),
            ]);
            mp.setCurrentChapter(book: 'Genesis', chapter: 1);
            return mp;
          }),
          ChangeNotifierProvider(create: (_) {
            settings = AppSettings();
            return settings;
          }),
        ],
        child: const MaterialApp(home: WorkbenchPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      await settings.setReadingPaperTheme(paper);
    });
    await tester.pump(const Duration(milliseconds: 400));
    return settings;
  }

  testWidgets(
      'paper theme on → workbench subtree reads WbColors.paper', (tester) async {
    addTearDown(tester.view.reset);
    await pumpWorkbenchPaper(tester, paper: true);

    // Read WbColors from inside the Browse window — the most-affected
    // surface, and the one that used to stay grey.
    final browseFinder = find.byType(BrowseWindow);
    expect(browseFinder, findsOneWidget);
    final ctx = tester.element(browseFinder);
    expect(WbColors.of(ctx), WbColors.paper,
        reason: 'paper mode should reach the workbench chrome');
  });

  testWidgets(
      'paper theme off → workbench reads the brightness-matched palette',
      (tester) async {
    addTearDown(tester.view.reset);
    await pumpWorkbenchPaper(tester, paper: false);

    final ctx = tester.element(find.byType(BrowseWindow));
    expect(WbColors.of(ctx), WbColors.light,
        reason: 'paper off should keep the neutral light palette');
  });
}
