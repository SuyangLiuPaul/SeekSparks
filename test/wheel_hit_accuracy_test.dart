/// What the wheel's hit test claims, measured rather than argued about.
///
/// 2026-09-17 「我的意思就是hover over那个不准确」 — reported at 3660%,
/// where hovering blank paper named a band far away from the pointer.
///
/// This asks the resolver the same question a reader's pointer does, at
/// several scales, and checks the answer against the geometry of the
/// record it named. See [WheelHitProbe] for why the recorder exists and
/// for the two versions of it that measured the instrument instead of
/// the code.
library;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
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

  testWidgets('every answer is inside the target it was admitted by',
      (tester) async {
    WheelRenderStats.reset();
    WheelRenderStats.trackHits = true;
    addTearDown(() {
      WheelRenderStats.trackHits = false;
      WheelRenderStats.reset();
    });
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(900, 900);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MainProvider()),
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child:
          const MaterialApp(home: RadialChronologyPage(initialStacked: false)),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(() => gesture.removePointer());

    Future<void> sweepAndCheck(String at) async {
      WheelRenderStats.hitsForTest.clear();
      const rect = Rect.fromLTRB(20, 150, 880, 800);
      const steps = 26;
      for (var i = 1; i < steps; i++) {
        for (var j = 1; j < steps; j++) {
          await gesture.moveTo(Offset(rect.left + rect.width * i / steps,
              rect.top + rect.height * j / steps));
          await tester.pump();
        }
      }
      final named = WheelRenderStats.hitsForTest
          .where((p) => p.id.isNotEmpty)
          .toList();
      expect(named, isNotEmpty,
          reason: 'at $at the sweep must land on something, or this '
              'measures nothing');
      final worst = named
          .map(WheelRenderStats.hitErrorPx)
          .fold<double>(0, (a, b) => a > b ? a : b);
      // 8 px, which is under the nine every branch here calls a finger:
      // the slack is allowed, drifting past it is not. Measured
      // 2026-09-17 at 100 / 196 / 384 / 753%: 0, 0, 2 and 7 px, the last
      // two both the `world` stream at the outer edge of its ring.
      expect(worst, lessThan(8),
          reason: 'at $at an answer was $worst px outside the target that '
              'admitted it — the reader pointed at one thing and was '
              'given another');
    }

    await sweepAndCheck('100%');
    for (var step = 0; step < 3; step++) {
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(const ValueKey('wheelZoomInControl')));
        await tester.pumpAndSettle();
      }
      await sweepAndCheck('zoom step ${step + 1}');
    }
  });
}
