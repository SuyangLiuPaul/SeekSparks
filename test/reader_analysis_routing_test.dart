/// 2026-08-11 (#313): in the workbench, a selection acts on the docked
/// panes.
///
/// The defect these guard: the chapter reader answered 原文 and 互参 with
/// a modal bottom sheet even when the Analysis pane was on screen
/// holding exactly that content — so asking about a verse **covered the
/// verse**. The reader is YsWords inheritance: on a phone a sheet is the
/// only place content can go, and the workbench inherited the habit
/// along with the widget.
///
/// Two halves, tested two ways. The map from a reader-side subject to a
/// docked tab is pure and is asserted directly. The decision that
/// depends on width is not expressible as a pure function of the
/// reader's own state — it belongs to the host — so it is driven
/// through the real widget tree at two widths, which is also the only
/// way to prove the fallback still opens a sheet where there is no pane.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/reader_analysis_request.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/models/wb_centre_mode.dart';
import 'package:seeksparks/pages/workbench_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/utils/workbench_fit.dart';
import 'package:seeksparks/widgets/analysis_tabs.dart';
import 'package:seeksparks/widgets/bible_reading_pane.dart';
import 'package:seeksparks/widgets/originals_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the reader-to-pane map', () {
    test('the subjects with a pane name it', () {
      expect(analysisTabForRequest(ReaderAnalysisRequest.originals),
          AnalysisTab.wordStudy);
      expect(analysisTabForRequest(ReaderAnalysisRequest.crossRefs),
          AnalysisTab.crossRefs);
      // 2026-08-17: this test's earlier form asserted `sermons` was
      // null and said in its own comment that a later run should edit
      // it deliberately. This is that edit.
      expect(analysisTabForRequest(ReaderAnalysisRequest.sermons),
          AnalysisTab.sermons);
    });

    // aiExplain is now the ONLY null, and it is a decision rather than a
    // deferral: a docked pane promises to follow the selection, and
    // following it here would spend a network call per verse and give
    // generated prose the same frame and weight as the corpus. If a
    // later run wants to change that, this is the test to edit — but it
    // is a product decision, not a cost one.
    test('the one subject with no pane keeps its sheet on purpose', () {
      expect(analysisTabForRequest(ReaderAnalysisRequest.aiExplain), isNull);
      final withoutTab = ReaderAnalysisRequest.values
          .where((r) => analysisTabForRequest(r) == null)
          .toList();
      expect(withoutTab, [ReaderAnalysisRequest.aiExplain]);
    });

    // The inverse feeds the active state on the button that sent the
    // content there. Add a forward mapping without its inverse and the
    // routing still works while the button never lights — a defect
    // visible only to someone looking at the right pixels.
    test('every subject with a tab round-trips through it', () {
      for (final request in ReaderAnalysisRequest.values) {
        final tab = analysisTabForRequest(request);
        if (tab == null) continue;
        expect(requestForAnalysisTab(tab), request,
            reason: '$request routes to $tab but $tab does not point back');
      }
    });

    test('no two subjects share a tab', () {
      final seen = <AnalysisTab, ReaderAnalysisRequest>{};
      for (final request in ReaderAnalysisRequest.values) {
        final tab = analysisTabForRequest(request);
        if (tab == null) continue;
        expect(seen.containsKey(tab), isFalse,
            reason: '$tab would be claimed by both ${seen[tab]} and $request, '
                'so the active state could not say which');
        seen[tab] = request;
      }
    });

    // Most tabs are reached only from the strip. If one of those claimed
    // a reader action, tapping into it would light a button the reader
    // never pressed.
    test('a tab no reader action reaches points back at nothing', () {
      for (final tab in AnalysisTab.values) {
        final request = requestForAnalysisTab(tab);
        if (request == null) continue;
        expect(analysisTabForRequest(request), tab);
      }
      expect(requestForAnalysisTab(AnalysisTab.kwic), isNull);
      expect(requestForAnalysisTab(AnalysisTab.places), isNull);
      expect(requestForAnalysisTab(AnalysisTab.vocabulary), isNull);
    });
  });

  // ── The width decision, driven through the real tree ───────────────

  Future<MainProvider> pumpReaderWorkbench(
      WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    // Seeded rather than tapped through the View menu: the mode is a
    // precondition of the test, not its subject.
    SharedPreferences.setMockInitialValues(<String, Object>{
      kWorkbenchCentreModeKey: centreModeToStorage(WbCentreMode.reader),
    });
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

  /// The 原文 button on the reader's selection bar, in either state.
  Finder originalsButton() => find.byWidgetPredicate((w) =>
      w is Icon &&
      (w.icon == Icons.auto_stories || w.icon == Icons.auto_stories_outlined));

  testWidgets('three-pane: 原文 fills the docked pane, no sheet',
      (tester) async {
    addTearDown(tester.view.reset);
    final mp = await pumpReaderWorkbench(
        tester, const Size(1400, 900));
    expect(find.byType(BibleReadingPane), findsOneWidget);

    mp.toggleVerse(
        verse: const Verse(
            book: 'Genesis', chapter: 1, verse: 1, text: 'seed 1'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(originalsButton(), findsOneWidget,
        reason: 'the selection action bar should be up');

    await tester.tap(originalsButton());
    await tester.pump(const Duration(milliseconds: 300));

    // One interlinear, and it is the docked one. `embedded` is the
    // difference between the pane's body and the modal's: same widget,
    // and only this flag says which surface the reader is looking at.
    final sheets =
        tester.widgetList<OriginalsSheet>(find.byType(OriginalsSheet));
    expect(sheets.length, 1);
    expect(sheets.single.embedded, isTrue,
        reason: 'a modal here would cover the verse it is describing');
    expect(find.byType(BottomSheet), findsNothing);
    // The text stays on screen — the whole point.
    expect(find.byType(BibleReadingPane), findsOneWidget);
    // And the button that sent it there says so, without a hover.
    expect(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.auto_stories),
        findsOneWidget);
  });

  testWidgets('below the three-pane gate: the sheet is still the answer',
      (tester) async {
    addTearDown(tester.view.reset);
    // 768 is iPad portrait: two panes, no Analysis column at all. The
    // sheet is not a fallback here, it is the only surface there is.
    final mp = await pumpReaderWorkbench(tester, const Size(768, 1024));
    expect(WorkbenchFit.threePaneMinWidth, greaterThan(768));
    expect(find.byType(BibleReadingPane), findsOneWidget);

    mp.toggleVerse(
        verse: const Verse(
            book: 'Genesis', chapter: 1, verse: 1, text: 'seed 1'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(originalsButton());
    await tester.pump(const Duration(milliseconds: 300));

    final sheets =
        tester.widgetList<OriginalsSheet>(find.byType(OriginalsSheet));
    expect(sheets.length, 1);
    expect(sheets.single.embedded, isFalse,
        reason: 'with no pane to send it to the reader keeps its sheet');
  });
}
