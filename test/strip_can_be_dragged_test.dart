/// The strip pans under a finger.
///
/// 2026-09-16 「还有我可以点击拽着这一块左右吗 很多user experience也要做好」.
///
/// At the resting zoom the whole 6,226 years fit the screen, so there is
/// nowhere to pan TO and a drag correctly does nothing — which is itself
/// worth pinning, because "it doesn't move" and "it is broken" look the
/// same to a reader and only one of them is a bug.
///
/// Once zoomed in there IS somewhere to go, and then a horizontal drag
/// has to move the chart. The strip stacks a horizontal scroll view
/// around a vertical one and puts a raw `Listener` inside both to place
/// the year cursor; a press that commits the cursor instead of scrolling
/// would make the chart feel nailed down, which is exactly the failure
/// this file exists to catch.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/strip_chronology_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/chronology_service.dart';
import 'package:seeksparks/services/hebrew_kings_service.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/widgets/chart_help_sheet.dart';

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

  Future<void> pump(WidgetTester tester, Size size) async {
    SharedPreferences.setMockInitialValues(
        <String, Object>{ChartHelp.seenKey: true});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
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

  // `.first`: the horizontal view wraps the vertical one, so a
  // descendant search finds both Scrollables and the outer one is ours.
  ScrollPosition across(WidgetTester tester) => tester
      .state<ScrollableState>(find
          .descendant(
              of: find.byKey(const ValueKey('stripHScroll')),
              matching: find.byType(Scrollable))
          .first)
      .position;

  testWidgets('at the resting zoom the whole range fits, so there is '
      'nothing to pan', (tester) async {
    await pump(tester, const Size(390, 844));
    expect(across(tester).maxScrollExtent, lessThan(1),
        reason: 'the resting view is meant to be the whole chronology; if '
            'it scrolls, the reader is being shown a window onto it '
            'without being told');
  });

  testWidgets('zoomed in, a horizontal drag moves the chart',
      (tester) async {
    await pump(tester, const Size(390, 844));
    for (var i = 0; i < 4; i++) {
      // By its icon: the zoom cluster labels its buttons rather than
      // keying them.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(across(tester).maxScrollExtent, greaterThan(100),
        reason: 'four steps of zoom did not make the chart wider than its '
            'viewport, so the drag below would prove nothing');

    final before = across(tester).pixels;
    // On the lanes themselves, not on the ruler: this is the surface a
    // reader puts a finger on, and it is the one carrying the cursor
    // Listener that could swallow the drag.
    final lanes = tester.getRect(find.byKey(const ValueKey('stripVScroll')));
    await tester.dragFrom(lanes.center, const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(across(tester).pixels, greaterThan(before + 60),
        reason: 'dragging left across the lanes did not move the chart — '
            'the cursor Listener has taken the drag');

    // And back, so this is a pan rather than a one-way ratchet.
    final mid = across(tester).pixels;
    await tester.dragFrom(lanes.center, const Offset(90, 0));
    await tester.pumpAndSettle();
    expect(across(tester).pixels, lessThan(mid - 40));
  });
}
