/// A label's size says what KIND of thing it names, not how much room
/// happened to be free beside it.
///
/// 2026-09-17, from Fable 5.1's reading of a screenshot the owner called
/// 「为什么很多没有做好」: ring names, power names and event names were the
/// same visual weight, and their SIZE varied per label because the
/// planner shrank each one until it fitted. The eye then cannot tell
/// what contains what — the type is reporting on spacing.
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
import 'package:yahwehs_sword/utils/radial_chronology_layout.dart';
import 'package:yahwehs_sword/utils/wheel_view_layout.dart';
import 'package:yahwehs_sword/widgets/chart_help_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await WheelHistoryService.instance.load();
    await ChronologyService.instance.load();
  });

  testWidgets('one screen carries a few sizes, not one per label',
      (tester) async {
    WheelRenderStats.reset();
    WheelRenderStats.trackHits = true;
    addTearDown(() {
      WheelRenderStats.trackHits = false;
      WheelRenderStats.reset();
    });
    SharedPreferences.setMockInitialValues(
        <String, Object>{ChartHelp.seenKey: true});
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

    for (var step = 0; step < 4; step++) {
      WheelRenderStats.labelSizesForTest.clear();
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(const ValueKey('wheelZoomInControl')));
        await tester.pumpAndSettle();
      }
      final distinct = WheelRenderStats.labelSizesForTest
          .map((s) => (s * 100).round())
          .toSet();
      expect(distinct, isNotEmpty);
      // MEASURED 2026-09-17, before and after the continuous shrink
      // became a three-step ladder, and the cost measured with it:
      //
      //          distinct sizes      labels drawn
      //   196%      4  →  4            28 → 28
      //   384%     13  →  7            64 → 62
      //   753%     32  →  7           107 → 100
      //  1476%     56  →  9           161 → 154
      //
      // Fifty-six sizes bought seven extra labels. The seven are not
      // lost: a name that will not fit at the smallest step is dropped
      // from the canvas and the hover still gives it, which is a thing
      // this chart could not do before today and is what makes the
      // trade payable at all.
      expect(distinct.length, lessThanOrEqualTo(12),
          reason: 'zoom step ${step + 1} put ${distinct.length} distinct '
              'font sizes on one screen. Past about a dozen the size of a '
              'label has stopped meaning anything except how much room '
              'was free beside it.');
    }
  });

  group('the ladder itself', () {
    double measure(String text, double size) => text.length * size * 0.9;

    test('a name that fits is set at its class size, untouched', () {
      final size = fitArcLabel(
        text: 'AB',
        radius: 100,
        sweep: 1.0,
        maxEm: 12,
        desiredSize: 10,
        zoom: 1,
        floorPx: 5,
        measure: measure,
      );
      expect(size, 10, reason: 'there was room; nothing should have moved');
    });

    test('a name that does not fit lands on a step, never between them',
        () {
      // Room for about 8.6 units of type, so the top step (10) misses
      // and the second (8.6) is taken exactly.
      final size = fitArcLabel(
        text: 'AB',
        radius: 100,
        sweep: 2 * 8.6 * 0.9 / (100 * 0.92),
        maxEm: 12,
        desiredSize: 10,
        zoom: 1,
        floorPx: 1,
        measure: measure,
      );
      expect([10.0, 8.6, 7.4], contains(size),
          reason: 'got $size, which is not one of the three steps — the '
              'slider is back');
    });

    test('a name that fits no step is dropped, not shrunk to a fourth', () {
      final size = fitArcLabel(
        text: 'A very long name indeed',
        radius: 100,
        sweep: 0.01,
        maxEm: 12,
        desiredSize: 10,
        zoom: 1,
        floorPx: 1,
        measure: measure,
      );
      expect(size, 0,
          reason: 'the canvas says nothing and the hover says the name');
    });
  });
}
