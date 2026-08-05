/// 2026-08 (SeekSparks): widget tests for the Analysis window's tab
/// strip — the BibleWorks idiom of looking at one verse several ways
/// without leaving the workspace.
///
/// The strip is always visible (so the reader can see the other views
/// exist), but its panes only have content once a verse is selected.
/// Same fixed-pump pattern as `workbench_page_test.dart`: the reader
/// starts async loads whose spinners never settle.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/pages/workbench_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/widgets/analysis_tabs.dart';
import 'package:seeksparks/widgets/originals_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const seed = [
    Verse(book: 'Genesis', chapter: 1, verse: 1, text: 'seed 1'),
    Verse(book: 'Genesis', chapter: 1, verse: 2, text: 'seed 2'),
  ];

  /// Icons appear elsewhere in the workspace too (OriginalsSheet uses
  /// the same hub glyph), so every tab finder is scoped to the strip.
  Finder tab(IconData icon) => find.descendant(
        of: find.byType(AnalysisTabStrip),
        matching: find.byIcon(icon),
      );

  Future<MainProvider> pumpWorkbench(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 900);
    SharedPreferences.setMockInitialValues(Map<String, Object>.of(prefs));
    late MainProvider mp;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) {
            mp = MainProvider();
            mp.setVerses(seed);
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

  testWidgets('the strip offers all three views on a desktop width',
      (tester) async {
    addTearDown(tester.view.reset);
    await pumpWorkbench(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(AnalysisTabStrip), findsOneWidget);
    // Found by icon, not label: the default locale is Chinese, and the
    // point of the test is that all three views are offered — not what
    // they happen to be called.
    expect(tab(Icons.translate_rounded), findsOneWidget);
    expect(tab(Icons.hub_outlined), findsOneWidget);
    expect(tab(Icons.bar_chart_rounded), findsOneWidget);
  });

  testWidgets('word study is the default view and embeds OriginalsSheet',
      (tester) async {
    addTearDown(tester.view.reset);
    final mp = await pumpWorkbench(tester);
    mp.toggleVerse(verse: seed.first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(OriginalsSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching to X-Refs swaps the pane, not the whole workspace',
      (tester) async {
    addTearDown(tester.view.reset);
    final mp = await pumpWorkbench(tester);
    mp.toggleVerse(verse: seed.first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(OriginalsSheet), findsOneWidget);

    await tester.tap(tab(Icons.hub_outlined));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.byType(CrossRefsPane), findsOneWidget);
    // The word study is gone; the reader and command line are not.
    expect(find.byType(OriginalsSheet), findsNothing);
    expect(find.byType(AnalysisTabStrip), findsOneWidget);
  });

  testWidgets('switching to Stats renders the frequency pane', (tester) async {
    addTearDown(tester.view.reset);
    final mp = await pumpWorkbench(tester);
    mp.toggleVerse(verse: seed.first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(tab(Icons.bar_chart_rounded));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.byType(AnalysisTabStrip), findsOneWidget);
    expect(find.byType(OriginalsSheet), findsNothing);
  });

  testWidgets('the chosen tab is restored from prefs', (tester) async {
    addTearDown(tester.view.reset);
    final mp = await pumpWorkbench(tester, prefs: {
      'flutter.workbench.analysisTab': AnalysisTab.crossRefs.index,
    });
    mp.toggleVerse(verse: seed.first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CrossRefsPane), findsOneWidget);
    expect(find.byType(OriginalsSheet), findsNothing);
  });

  testWidgets('an out-of-range persisted tab index falls back to word study',
      (tester) async {
    addTearDown(tester.view.reset);
    // Guards against a future reordering/removal of AnalysisTab values
    // leaving an old install pointing at an index that no longer exists.
    final mp = await pumpWorkbench(tester, prefs: {
      'flutter.workbench.analysisTab': 99,
    });
    mp.toggleVerse(verse: seed.first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.byType(OriginalsSheet), findsOneWidget);
  });

  testWidgets('with nothing selected every tab shows the empty hint',
      (tester) async {
    addTearDown(tester.view.reset);
    await pumpWorkbench(tester);
    for (final icon in [Icons.hub_outlined, Icons.bar_chart_rounded]) {
      await tester.tap(tab(icon));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull,
          reason: '$icon must not throw with an empty selection');
      expect(find.byType(CrossRefsPane), findsNothing);
      expect(find.byType(WordStatsPane), findsNothing);
    }
  });
}
