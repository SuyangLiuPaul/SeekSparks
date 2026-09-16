/// How many words the wheel puts on a screen, and on a PHONE.
///
/// 2026-09-16, with a photograph of a 390 dp phone at 235%:
/// 「手机上看就很恐怖了」. Fifty-one label plates on a 390 dp canvas,
/// several of them standing over the empty middle of the disc with a
/// hairline running off to an arc near the rim.
///
/// TWO CAUSES, BOTH MEASURED BEFORE THEY WERE CHANGED.
///
///   1. The leader could reach anywhere. `_uprightArcLabel` walked six
///      box-widths either way when a name's own place was taken, and a
///      box-width is the NAME's width — 「Joshua son of Nun」 at the
///      canvas size is about 120 px, so six of them is 720 px, nearly
///      twice the width of the phone. The reach is a fraction of what
///      is on screen now.
///   2. The ring names repeated at twelve fixed BEARINGS, so at high
///      zoom on a small canvas three copies of 以色列 landed in one
///      screen. Twelve is a count; what a reader needs is a distance.
///
/// And the declutter's air was a flat 2 px, which on type this size
/// lets labels tile the canvas edge to edge. It is a fraction of the
/// line height now, so it scales with the words it separates.
///
/// This file is a RATCHET, not a specification: canvas text leaves no
/// widget behind, so without a number here the only way this regresses
/// is another photograph.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/chronology_service.dart';
import 'package:seeksparks/utils/wheel_view_layout.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await WheelHistoryService.instance.load();
    await ChronologyService.instance.load();
  });

  /// Labels on the canvas after [steps] presses of the zoom control.
  Future<int> labelsAt(WidgetTester tester, Size size, int steps) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
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
    for (var i = 0; i < steps; i++) {
      await tester.tap(find.byKey(const ValueKey('wheelZoomInControl')));
      await tester.pump(const Duration(milliseconds: 60));
    }
    await tester.pump(const Duration(milliseconds: 400));
    final drawn = WheelRenderStats.labelsDrawn;
    await tester.pumpWidget(const SizedBox.shrink());
    return drawn;
  }

  testWidgets('a phone at rest is not a wall of type', (tester) async {
    // At the resting zoom the chart is an overview and names only its
    // rings. This end was always calm; the ratchet keeps it that way.
    expect(await labelsAt(tester, const Size(390, 844), 0), lessThan(8));
  });

  testWidgets('a phone zoomed in stays readable', (tester) async {
    // 51 before, 21 after, at the zoom the owner's photograph was taken
    // at. 30 is the ratchet: it leaves room for the corpus to grow
    // without letting the density back to where it was.
    final two = await labelsAt(tester, const Size(390, 844), 2);
    expect(two, lessThan(30),
        reason: '$two labels on a 390 dp canvas is the wall of type the '
            'owner photographed');
    expect(two, greaterThan(8),
        reason: 'a zoomed chart that names almost nothing is the other '
            'failure, and the one the owner reported first');
  });

  testWidgets('a phone keeps its labels near what they name', (tester) async {
    // One more press, and the count may rise — but not without bound:
    // the reach that placed a name 720 px from its arc is what this
    // catches coming back.
    expect(await labelsAt(tester, const Size(390, 844), 3), lessThan(40));
  });

  testWidgets('a desktop is allowed more, in proportion to its canvas',
      (tester) async {
    final phone = await labelsAt(tester, const Size(390, 844), 3);
    final desktop = await labelsAt(tester, const Size(1440, 900), 3);
    expect(desktop, greaterThan(phone),
        reason: 'a bigger canvas should carry more words, not fewer');
    expect(desktop, lessThan(130));
  });
}
