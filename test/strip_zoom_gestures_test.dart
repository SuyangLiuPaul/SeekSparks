/// The strip zooms under a wheel and under two fingers.
///
/// 2026-09-16 「另外wheel strip可以鼠标上下滑zoom in out吗 然后ipad可以两
/// 个手指zoom in out这样」.
///
/// The strip had two zoom BUTTONS and no zoom GESTURE, which made it the
/// odd one out: its sibling wheel page is an `InteractiveViewer` and has
/// answered a pinch since the day it was written. This page cannot be
/// one, because its whole reason for existing is that the two axes are
/// unbound — so the gesture is assembled by hand, and these are the two
/// ways that can go wrong quietly.
///
/// FIRST, THE SCROLL CAN BE EATEN. The page stacks a horizontal scroll
/// view around a vertical one, and a `PointerSignalResolver` runs the
/// FIRST handler registered for an event. The zoom handler only wins
/// because its `Listener` sits INSIDE both scroll views; move it out and
/// the wheel silently goes back to scrolling lanes.
///
/// SECOND, THE PINCH CAN BE STOLEN. A `GestureDetector`'s scale
/// callbacks would enter the gesture arena and take single-pointer drags
/// away from the scrolling this page depends on — which is why the pinch
/// is tracked with raw pointers instead, and why a test that only
/// checked "does it zoom" would not notice the panning had died.
library;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yahwehs_sword/models/app_settings.dart';
import 'package:yahwehs_sword/models/wheel_history.dart';
import 'package:yahwehs_sword/pages/strip_chronology_page.dart';
import 'package:yahwehs_sword/providers/main_provider.dart';
import 'package:yahwehs_sword/services/chronology_service.dart';
import 'package:yahwehs_sword/services/hebrew_kings_service.dart';
import 'package:yahwehs_sword/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:yahwehs_sword/utils/strip_chronology_layout.dart'
    show kStripMinYear, kStripZoomSteps, yearForX;
import 'package:yahwehs_sword/utils/strip_viewport.dart';
import 'package:yahwehs_sword/widgets/year_digest_bar.dart' show YearDigestBar;
import 'package:yahwehs_sword/widgets/chart_help_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await WheelHistoryService.instance.load();
    await ChronologyService.instance.load();
    await HebrewKingsService.instance.load();
    await (FontLoader('Roboto')
          ..addFont(rootBundle
              .load('assets/fonts/Roboto-VariableFont_wdth,wght.ttf')))
        .load();
  });

  group('the arithmetic', () {
    test('a continuous zoom stays inside the same bounds as the buttons',
        () {
      const viewport = 900.0;
      final fit = stripFitScale(viewport);
      expect(stripScaleBy(fit, 0.01, viewport), fit,
          reason: 'pinching shut went past the fit-everything zoom, so the '
              'reader can get a chart with blank paper on both sides');
      expect(stripScaleBy(kStripZoomSteps.last, 100, viewport),
          kStripZoomSteps.last);
      expect(stripScaleBy(2, 2, viewport), closeTo(4, 0.000001));
      // A degenerate factor is what a pinch produces when two fingers
      // land on the same pixel.
      expect(stripScaleBy(2, 0, viewport), 2);
      expect(stripScaleBy(2, double.nan, viewport), 2);
    });

    test('the year under the fingers is the year that stays', () {
      const viewport = 800.0;
      const focus = 250.0;
      const offset = 1200.0;
      const oldScale = 2.0;
      const newScale = 5.0;
      final year = yearForX(offset + focus, oldScale);
      final moved = stripZoomOffsetAt(
        offset: offset,
        focusX: focus,
        viewportWidth: viewport,
        oldScale: oldScale,
        newScale: newScale,
      );
      expect(yearForX(moved + focus, newScale), closeTo(year, 0.5),
          reason: 'the point under the reader moved out from under them, '
              'which is the entire complaint about charts that zoom');
      // And it cannot scroll off the front of the chart.
      expect(
          stripZoomOffsetAt(
            offset: 0,
            focusX: 0,
            viewportWidth: viewport,
            oldScale: oldScale,
            newScale: newScale,
          ),
          greaterThanOrEqualTo(0));
      expect(kStripMinYear, lessThan(0));
    });
  });

  Future<void> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(
        <String, Object>{ChartHelp.seenKey: true});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MainProvider()),
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child: MaterialApp(
        theme: ThemeData(
            fontFamily: 'Roboto', fontFamilyFallback: kCjkFontFallback),
        home: const StripChronologyPage(initialStacked: false),
      ),
    ));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  ScrollPosition across(WidgetTester tester) => tester
      .state<ScrollableState>(find
          .descendant(
              of: find.byKey(const ValueKey('stripHScroll')),
              matching: find.byType(Scrollable))
          .first)
      .position;

  testWidgets('a scroll wheel over the lanes zooms the chart',
      (tester) async {
    await pump(tester);
    final lanes = tester.getRect(find.byKey(const ValueKey('stripVScroll')));
    expect(across(tester).maxScrollExtent, lessThan(1),
        reason: 'the resting view fits the whole chronology, so any '
            'scrollable width below is the zoom and nothing else');

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(lanes.center));
    for (var i = 0; i < 3; i++) {
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -120)));
      await tester.pump(const Duration(milliseconds: 120));
    }
    await tester.pumpAndSettle();
    final zoomed = across(tester).maxScrollExtent;
    expect(zoomed, greaterThan(100),
        reason: 'scrolling up over the lanes did not magnify the chart — '
            'the scroll views underneath took the signal');

    for (var i = 0; i < 3; i++) {
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
      await tester.pump(const Duration(milliseconds: 120));
    }
    await tester.pumpAndSettle();
    expect(across(tester).maxScrollExtent, lessThan(zoomed - 50),
        reason: 'scrolling the other way did not shrink it back, so the '
            'zoom is a one-way ratchet');
  });

  testWidgets('two fingers spreading apart zoom the chart', (tester) async {
    await pump(tester);
    final lanes = tester.getRect(find.byKey(const ValueKey('stripVScroll')));
    final c = lanes.center;
    final left = await tester.startGesture(c - const Offset(60, 0));
    final right = await tester.startGesture(c + const Offset(60, 0));
    for (var i = 0; i < 4; i++) {
      await left.moveBy(const Offset(-30, 0));
      await right.moveBy(const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 40));
    }
    await left.up();
    await right.up();
    await tester.pumpAndSettle();
    expect(across(tester).maxScrollExtent, greaterThan(100),
        reason: 'a pinch outward did not magnify the chart');
  });

  testWidgets('a pinch does not leave a year cursor behind', (tester) async {
    // The lanes carry a raw `Listener` that lands the year cursor on a
    // press, and a pinch is two presses as far as it can tell. Without
    // the second finger cancelling the press, every pinch would also
    // stamp a cursor line wherever the fingers happened to be.
    await pump(tester);
    final lanes = tester.getRect(find.byKey(const ValueKey('stripVScroll')));
    final c = lanes.center;
    final left = await tester.startGesture(c - const Offset(60, 0));
    final right = await tester.startGesture(c + const Offset(60, 0));
    await left.moveBy(const Offset(-4, 0));
    await right.moveBy(const Offset(4, 0));
    await tester.pump(const Duration(milliseconds: 40));
    await left.up();
    await right.up();
    await tester.pumpAndSettle();
    YearDigestBar bar() => tester.widget<YearDigestBar>(
        find.byType(YearDigestBar));
    expect(bar().digest, isNull,
        reason: 'the pinch was also read as a press and placed the cursor');

    // And the press itself still works, so the assertion above is not
    // passing because nothing ever lands a cursor.
    await tester.tapAt(c);
    await tester.pumpAndSettle();
    expect(bar().digest, isNotNull,
        reason: 'a plain tap no longer places the year cursor — the pinch '
            'tracking has taken the press with it');
  });
}
