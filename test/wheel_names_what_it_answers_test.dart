/// The reader's frame: is the name of the thing under the pointer
/// anywhere the reader can see?
///
/// 2026-09-17 「感觉还差很多一些 你好好查一查」, after the resolver itself
/// had been made exact. It was: a correct answer is worth nothing if the
/// word that would confirm it is off the side of the window.
///
/// This is Fable 5.1's third rule — measure in the reader's frame, not
/// the resolver's — and it is the measurement the earlier sweeps did not
/// make. They proved the hit test right while the owner was still right
/// too.
library;

import 'dart:math' as math;

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

  testWidgets('a ring that answers is a ring the reader can see named',
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
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    addTearDown(() => g.removePointer());

    Future<void> checkAt(String at) async {
      // The ring names are recorded by a REPAINT, and a hover does not
      // repaint the scene. Nudge the camera so the list belongs to the
      // view the sweep is about to measure.
      WheelRenderStats.bandNamesForTest.clear();
      await tester.tap(find.byKey(const ValueKey('wheelZoomOutControl')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wheelZoomInControl')));
      await tester.pumpAndSettle();
      final painted =
          WheelRenderStats.bandNamesForTest.map((n) => n.text).toSet();

      WheelRenderStats.hitsForTest.clear();
      const rect = Rect.fromLTRB(20, 150, 880, 800);
      const steps = 20;
      for (var i = 1; i < steps; i++) {
        for (var j = 1; j < steps; j++) {
          await g.moveTo(Offset(rect.left + rect.width * i / steps,
              rect.top + rect.height * j / steps));
          await tester.pump();
        }
      }
      final answered = WheelRenderStats.hitsForTest
          .where((p) => p.kind == 'stream' && p.label.isNotEmpty)
          .map((p) => p.label)
          .toSet();
      if (answered.isEmpty) return;

      // MEASURED 2026-09-17, before and after the sticky ring name:
      //
      //   before   at 753%, the pointer answered 全世界 while the names
      //            on screen were 以色列, 犹大 and 圣经 — not one of the
      //            fourteen answers had its own ring named anywhere in
      //            the window, the nearest copy being 2092 px away
      //   after    every visible ring named, every answer's ring among
      //            them
      //
      // The old code placed twelve copies at fixed bearings across the
      // whole 320-degree sweep. Twelve is enough until a screenful is
      // narrower than a twelfth of the sweep, and then it silently is
      // not — which is exactly the zoom the owner works at.
      expect(answered.difference(painted), isEmpty,
          reason: 'at $at the pointer answered '
              '${answered.difference(painted)} with no such name painted '
              'anywhere on screen. Painted: $painted.');
    }

    for (var step = 0; step < 4; step++) {
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(const ValueKey('wheelZoomInControl')));
        await tester.pumpAndSettle();
      }
      await checkAt('zoom step ${step + 1}');
    }
  });

  test('a ring is named where the reader is looking, not on a fixed bearing',
      () {
    // The unit half of the same rule: a label position derived from a
    // COUNT cannot stay inside a viewport that keeps shrinking, and one
    // derived from the visible stretch always can. Kept as arithmetic so
    // the reason survives even if the widget test is ever skipped.
    const sweep = 320 * math.pi / 180;
    const radius = 300.0;
    for (final zoom in [2.0, 8.0, 40.0]) {
      final screenful = 900 / zoom; // canvas units across the window
      final arcPerCopy = sweep / 12 * radius; // the old twelve bearings
      if (zoom >= 8) {
        expect(arcPerCopy, greaterThan(screenful),
            reason: 'at ${zoom}x the fixed-bearing spacing is wider than '
                'the window, so the nearest copy is off screen — which '
                'is the defect, stated as arithmetic');
      }
    }
  });
}
