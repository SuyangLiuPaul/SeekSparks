/// TAPPING BLANK PAPER PUTS THE WHEEL BACK.
///
/// Selecting anything on the wheel dims everything it does not cover to
/// alpha 0.35 — that is what makes a selection legible — so getting OUT
/// of a selection matters as much as getting into one. `_handleTap`'s
/// last line has always cleared the selection for a tap that hit
/// nothing, and for a tap inside the hub or outside the rim it did.
///
/// It never ran for the one piece of blank paper a reader is most
/// likely to aim at. The wheel sweeps 320 degrees, so a 40-degree wedge
/// carries no band, no arc and no label, and `_handleTap` opened with
///
///     if (a - startRad > sweepRad) return;
///
/// — a bare return, before the clear. On a phone at deep zoom that
/// wedge is most of the screen, so the gesture did nothing at all: no
/// sheet, no change, no way back short of the reset button. Reported
/// from an iPhone at 1049%: 「这个可以选中，但是按空白地方不能取消选中」.
///
/// The selection lives in canvas state with no widget and no semantics
/// node of its own, so it is read here off the painter the page hands
/// its `CustomPaint` — dynamically, because the painter's type is
/// private to the page. That is the only honest way to see it: asserting
/// on the pixels would be asserting on a screenshot, and asserting on
/// the sheet that opens says nothing about whether the DIMMING cleared.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yahwehs_sword/models/app_settings.dart';
import 'package:yahwehs_sword/models/wheel_history.dart';
import 'package:yahwehs_sword/pages/radial_chronology_page.dart';
import 'package:yahwehs_sword/providers/main_provider.dart';
import 'package:yahwehs_sword/services/chronology_service.dart';
import 'package:yahwehs_sword/services/hebrew_kings_service.dart';
import 'package:yahwehs_sword/utils/radial_chronology_layout.dart';
import 'package:yahwehs_sword/utils/wheel_default_streams.dart';
import 'package:yahwehs_sword/widgets/chart_help_sheet.dart';

// The page's own fractions, restated because they are private to it —
// the same thing wheel_band_target_test.dart and wheel_lifespans_test
// already do.
const double _hubFrac = 0.115;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await WheelHistoryService.instance.load();
    await ChronologyService.instance.load();
    await HebrewKingsService.instance.load();
  });

  Future<void> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(
        <String, Object>{ChartHelp.seenKey: true});
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1000, 1000);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: const MaterialApp(home: RadialChronologyPage(initialStacked: false)),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  final wheel = find.byKey(const ValueKey('chronologyWheel'));

  Finder painterOf() =>
      find.descendant(of: wheel, matching: find.byType(CustomPaint)).first;

  // Private painter type, read by name at runtime. See the library doc.
  String? selectedId(WidgetTester tester) =>
      // ignore: avoid_dynamic_calls
      (tester.widget<CustomPaint>(painterOf()).painter as dynamic).selectedId
          as String?;

  testWidgets('a tap in the empty wedge clears the selection', (tester) async {
    await pump(tester);
    expect(wheel, findsOneWidget);

    final rect = tester.getRect(wheel);
    final side = math.min(rect.width, rect.height);
    final centre = rect.center;

    Offset at(double r, double angle) => Offset(
        centre.dx + r * math.cos(angle), centre.dy + r * math.sin(angle));

    expect(selectedId(tester), isNull, reason: 'nothing is selected at rest');

    // Select something — and on a RECORD, not just on a radius.
    //
    // 2026-09-16 「我要按这空白处，却显示这个，experience就很不好」: a press
    // on an empty part of a ring used to round into whichever ring was
    // nearest and open everything that ring has ever held. It does not
    // any more, so this test asks its question where there is something
    // to ask about: the widest arc the chart drew, at its own middle.
    // ignore: avoid_dynamic_calls
    final drawn = (tester.widget<CustomPaint>(painterOf()).painter as dynamic)
        .arcs as List<dynamic>;
    expect(drawn, isNotEmpty, reason: 'the chart drew no power bands at all');
    dynamic widest = drawn.first;
    for (final arc in drawn) {
      // ignore: avoid_dynamic_calls
      if ((arc.a1 as double) - (arc.a0 as double) >
          // ignore: avoid_dynamic_calls
          (widest.a1 as double) - (widest.a0 as double)) {
        widest = arc;
      }
    }
    // ignore: avoid_dynamic_calls
    final ring = widest.ring as int;
    // ignore: avoid_dynamic_calls
    final mid = ((widest.a0 as double) + (widest.a1 as double)) / 2;
    // ignore: avoid_dynamic_calls
    final streamCount = (tester.widget<CustomPaint>(painterOf()).painter
            as dynamic)
        .streams
        .length as int;
    final rBand = ringRadii(ring, streamCount, side * _hubFrac,
            side * bandsFractionFor(side))
        .centre;
    await tester.tapAt(at(rBand, mid));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final picked = selectedId(tester);
    expect(picked, isNotNull,
        reason: 'a tap on the annulus selects the band under it');

    // The band opened its sheet. Close it — the selection is meant to
    // OUTLIVE the sheet, and the next tap is the thing under test.
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(selectedId(tester), picked,
        reason: 'closing the sheet does not clear the selection');

    // Now the wedge: past the end of the 320-degree sweep, at a radius
    // that is well inside the wheel, so this is blank paper and not the
    // outside of the rim (which already cleared).
    final wedge = at(rBand, startRad + sweepRad + (2 * math.pi - sweepRad) / 2);
    expect(tester.getRect(wheel).contains(wedge), isTrue,
        reason: 'the wedge point has to be ON the wheel for this to be '
            'the case that was broken');
    await tester.tapAt(wedge);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(selectedId(tester), isNull,
        reason: 'blank paper deselects; before this fix the handler '
            'returned before it could');
    // And it opened nothing on the way — a deselect is not a navigation.
    expect(find.byType(BottomSheet), findsNothing);
  });
}
