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

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/chronology_service.dart';
import 'package:seeksparks/services/hebrew_kings_service.dart';
import 'package:seeksparks/utils/radial_chronology_layout.dart';

// The page's own fractions, restated because they are private to it —
// the same thing wheel_band_target_test.dart and wheel_lifespans_test
// already do.
const double _hubFrac = 0.115;
const double _bandsFrac = 0.285;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await WheelHistoryService.instance.load();
    await ChronologyService.instance.load();
    await HebrewKingsService.instance.load();
  });

  Future<void> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1000, 1000);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: const MaterialApp(home: RadialChronologyPage()),
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

    // Select something: the middle of the annulus, halfway round the
    // sweep, which is a band whatever the corpus happens to hold there.
    final rBand = side * (_hubFrac + _bandsFrac) / 2;
    await tester.tapAt(at(rBand, startRad + sweepRad / 2));
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
