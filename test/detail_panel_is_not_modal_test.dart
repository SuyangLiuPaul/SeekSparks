/// The detail panel does not freeze the chart.
///
/// 2026-09-16 「我发现这种pop up给人的体验感很不好，可以换个吗？或者hover
/// 然后按的时候就freeze在那里之类的」.
///
/// The shape was never the complaint. A MODAL sheet takes the whole
/// screen's input, so everything the reader might want next — pan to
/// the century beside this one, tap the band above it, zoom to see what
/// this one overlaps — had to be bought by dismissing the answer first.
/// It froze the chart instead of freezing beside it.
///
/// `showBottomSheet` is the persistent one, and it is still a
/// `BottomSheet` in the tree: the side dock that was tried and reverted
/// in an hour changed the widget thirty-one assertions reach for by
/// type, and this does not. That is the whole reason this shape was
/// chosen over the one that looks better on a wide screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yahwehs_sword/models/app_settings.dart';
import 'package:yahwehs_sword/models/wheel_history.dart';
import 'package:yahwehs_sword/pages/radial_chronology_page.dart';
import 'package:yahwehs_sword/providers/main_provider.dart';
import 'package:yahwehs_sword/services/chronology_service.dart';
import 'package:yahwehs_sword/widgets/chart_help_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await WheelHistoryService.instance.load();
    await ChronologyService.instance.load();
  });

  Future<void> pump(WidgetTester tester, Size size) async {
    SharedPreferences.setMockInitialValues(
        <String, Object>{ChartHelp.seenKey: true});
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child:
            const MaterialApp(home: RadialChronologyPage(initialStacked: false)),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Open a RECORD's panel — the thing the complaint is about. About
  /// stays modal on purpose: it is a document a reader opens and leaves,
  /// not an answer they read while looking at the chart.
  Future<void> openPower(WidgetTester tester, String en, String zh) async {
    await tester.tap(find.byKey(const ValueKey('chronology-find')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('wheelFindField')), en);
    await tester.pumpAndSettle();
    final row = find.descendant(
        of: find.byKey(const ValueKey('wheelFindList')), matching: find.text(zh));
    expect(row, findsWidgets, reason: 'the box could not find $en');
    await tester.tap(row.first);
    await tester.pumpAndSettle();
  }

  testWidgets('it is still a BottomSheet, which is what the suite reads',
      (tester) async {
    await pump(tester, const Size(1440, 900));
    await openPower(tester, 'Kingdom of Judah', '南国犹大');
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('and it does not put a modal route over the page',
      (tester) async {
    await pump(tester, const Size(1440, 900));
    await openPower(tester, 'Kingdom of Judah', '南国犹大');
    expect(find.byType(BottomSheet), findsOneWidget);
    // A modal sheet is a ROUTE, so the chart underneath is off the
    // navigator's top and a ModalBarrier stands over it. Neither is
    // true of a persistent one.
    expect(find.byType(ModalBarrier).evaluate().length, lessThan(2),
        reason: 'a barrier over the chart is exactly what was reported: '
            'the reader could not touch what they were reading about');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the chart is still there to be used while it is open',
      (tester) async {
    await pump(tester, const Size(1440, 900));
    final zoomIn = find.byKey(const ValueKey('wheelZoomInControl'));
    await openPower(tester, 'Kingdom of Judah', '南国犹大');
    expect(find.byType(BottomSheet), findsOneWidget);
    // The zoom control is part of the chart's own chrome and sits
    // underneath the panel's route in the modal world. Driving it with
    // the panel open is the claim.
    expect(zoomIn, findsOneWidget);
    await tester.tap(zoomIn);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    expect(find.byType(BottomSheet), findsOneWidget,
        reason: 'using the chart must not dismiss the answer either — '
            'that is the other half of 「freeze在那里」');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a second answer replaces the first rather than stacking',
      (tester) async {
    await pump(tester, const Size(1440, 900));
    await openPower(tester, 'Kingdom of Judah', '南国犹大');
    await openPower(tester, 'Roman Empire', '罗马帝国');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(BottomSheet), findsOneWidget,
        reason: 'two panels deep is the modal behaviour this replaces');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the close button closes the panel, not the page',
      (tester) async {
    await pump(tester, const Size(1440, 900));
    await openPower(tester, 'Kingdom of Judah', '南国犹大');
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byType(BottomSheet), matching: find.byIcon(Icons.close)));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    // `maybePop` on a persistent sheet would have popped the PAGE.
    expect(find.byKey(const ValueKey('chronologyWheel')), findsOneWidget,
        reason: 'closing the panel took the chart with it');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
