/// HOW MUCH THE WHEEL SAYS AT A GIVEN MAGNIFICATION — and that the
/// answer is a table, not an accident of paint order.
///
/// 2026-09-17, the first of Fable 5.1's ranked defects: there was no
/// level-of-detail rule at all. One gate, `zoom >= 1.6`, turned on ring
/// names, power names, lifespan names and record names together, and
/// they then competed for room first-come-first-served — so what a
/// reader saw depended on which painter ran first.
///
/// MEASURED BEFORE AND AFTER, same camera, 1280x663 pane, the view
/// parked ON THE RING STACK — radius 0.21 of the side, which is inside
/// the bands. WHERE THE CAMERA SITS IS PART OF THE MEASUREMENT, and an
/// earlier version of this comment got that wrong: it parked at 0.34,
/// which on this pane is PAST `bandsFractionFor` (0.26) and out in the
/// lifespan annulus, and then reported "at 1600% nothing on the screen
/// is named" as a defect. Nothing was named because nothing was there.
/// The numbers below are from a camera on the rings:
///
///            painted    on screen    on screen
///            (before)   (before)     (after)
///    200%       66          63           59
///    400%       55          24           25
///    800%       82          12           13
///   1600%      118           6            6
///
/// The middle column is the one to read twice. At 1600% the painter was
/// laying a hundred and eighteen names on the canvas for six the reader
/// could see; it now lays six. What the reader gets is the same or one
/// more at every scale, for a fifth of the work, because a label
/// outside the camera was also taking the room beside one inside it.
///
/// Where the caps bind is 200%, and there they change the MIX rather
/// than only the count: powers 30 to 27, lifespans 27 to 23, records 6
/// to 8, and a ring name that could not get a plate at all before.
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
import 'package:yahwehs_sword/utils/wheel_view_layout.dart';
import 'package:yahwehs_sword/widgets/chart_help_sheet.dart';

/// Scale about the origin, then translate — written out rather than
/// built with `Matrix4.translate`/`scale`, which are deprecated in the
/// Flutter CI installs and warn-free here. See the note in
/// PROJECT_STATE about local analyze not being CI's.
Matrix4 _viewMatrix(double zoom, Offset translation) {
  final m = Matrix4.identity();
  m.setEntry(0, 0, zoom);
  m.setEntry(1, 1, zoom);
  m.setEntry(2, 2, zoom);
  m.setEntry(0, 3, translation.dx);
  m.setEntry(1, 3, translation.dy);
  return m;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await WheelHistoryService.instance.load();
    await ChronologyService.instance.load();
  });

  group('the table', () {
    test('a zoom lands on the last row it has passed', () {
      expect(wheelDetailFor(1.0).name, 'fit');
      expect(wheelDetailFor(1.59).name, 'fit');
      expect(wheelDetailFor(1.6).name, 'survey');
      expect(wheelDetailFor(4.9).name, 'survey');
      expect(wheelDetailFor(5.0).name, 'read');
      expect(wheelDetailFor(15.9).name, 'read');
      expect(wheelDetailFor(16.0).name, 'close');
      expect(wheelDetailFor(1000).name, 'close');
    });

    test('at rest the wheel is a shape, not a page of text', () {
      final fit = wheelDetailFor(1.0);
      expect(fit.records, 0);
      expect(fit.powers, 0);
      expect(fit.lives, 0);
      expect(fit.rings, greaterThan(0),
          reason: 'a chart with no ring names does not say what its rings '
              'are, which is the one thing the list beside it cannot');
    });

    test('closing in never says less', () {
      for (var i = 1; i < kWheelDetailLevels.length; i++) {
        final prev = kWheelDetailLevels[i - 1];
        final row = kWheelDetailLevels[i];
        expect(row.minZoom, greaterThan(prev.minZoom));
        for (final kind in WheelLabelKind.values) {
          expect(row.densityFor(kind),
              greaterThanOrEqualTo(prev.densityFor(kind)),
              reason: '${row.name} allows fewer ${kind.name} names than '
                  '${prev.name}. Zooming in is a reader asking for MORE.');
        }
      }
    });

    test('the one gate everything else reads agrees with the table', () {
      for (final zoom in [0.5, 1.0, 1.59, 1.6, 4.0, 20.0]) {
        expect(wheelShowsEventText(zoom: zoom, selected: false),
            wheelDetailFor(zoom).records > 0,
            reason: 'the record-name gate and the table disagree at $zoom');
      }
      expect(wheelShowsEventText(zoom: 0.2, selected: true), isTrue,
          reason: 'the selected record is named at every zoom — it is the '
              'one question the list beside the chart cannot answer');
    });
  });

  testWidgets('no kind of name exceeds its row, on a real screen',
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
    tester.view.physicalSize = const Size(1600, 1000);
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

    final iv = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final vp = tester.getSize(find.byType(InteractiveViewer));
    final canvas =
        tester.getSize(find.byKey(const ValueKey('wheelSceneBoundary')));
    final side = math.min(canvas.width, canvas.height);

    // THE CAMERA IS SET, NOT DRIVEN. Zooming with the control alone
    // parks the view on the hub, where there is nothing to count, and a
    // drag that overshoots the rim looks identical in the numbers —
    // both report "no labels" for a chart that is drawing plenty.
    //
    // 0.21 of the side is INSIDE the ring stack: the hub ends at 0.115
    // and `bandsFractionFor` puts the outer edge of the bands at 0.26
    // on a pane this size. Parking outside that range is how the first
    // run of this file mistook an empty annulus for a decluttering
    // failure.
    Future<void> park(double zoom) async {
      final r = zoom <= 1 ? 0.0 : side * 0.21;
      final p = Offset(side / 2 + r, side / 2);
      final q =
          Offset(p.dx + (vp.width - side) / 2, p.dy + (vp.height - side) / 2);
      iv.transformationController!.value = _viewMatrix(zoom,
          Offset(vp.width / 2 - zoom * q.dx, vp.height / 2 - zoom * q.dy));
      await tester.pumpAndSettle();
    }

    for (final zoom in [1.0, 2.0, 4.0, 8.0, 16.0]) {
      await park(zoom);
      // ZOOMED IN IS NOT MUTE. The one thing a reader deep in the chart
      // cannot get from the list beside it is "which ring am I on", and
      // at 1600% on the rings this comes back 4 ring names and 2
      // records. A change that empties the screen at magnification
      // fails here.
      if (zoom > 1) {
        final named = WheelRenderStats.labelKindsForTest.values
            .fold<int>(0, (a, b) => a + b);
        expect(named, greaterThan(0),
            reason: 'at ${(zoom * 100).round()}%, parked on the ring stack, '
                'the wheel named nothing at all');
      }
      final row = wheelDetailFor(zoom);
      final area = WheelRenderStats.frameAreaForTest;
      expect(area, greaterThan(0), reason: 'no frame was measured');
      final drawn = Map.of(WheelRenderStats.labelKindsForTest);
      for (final kind in WheelLabelKind.values) {
        final cap = row.capFor(kind, areaPx: area);
        expect(drawn[kind] ?? 0, lessThanOrEqualTo(cap),
            reason: 'at ${(zoom * 100).round()}% the wheel put '
                '${drawn[kind]} ${kind.name} names on one screen, and row '
                '"${row.name}" allows $cap there');
      }
    }
  });

  testWidgets('every name it draws is one the reader can see',
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
    tester.view.physicalSize = const Size(1600, 1000);
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

    final iv = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final vp = tester.getSize(find.byType(InteractiveViewer));
    final canvas =
        tester.getSize(find.byKey(const ValueKey('wheelSceneBoundary')));
    final side = math.min(canvas.width, canvas.height);
    final q = Offset(side / 2 + side * 0.21 + (vp.width - side) / 2,
        side / 2 + (vp.height - side) / 2);
    const zoom = 8.0;
    iv.transformationController!.value = _viewMatrix(zoom,
        Offset(vp.width / 2 - zoom * q.dx, vp.height / 2 - zoom * q.dy));
    await tester.pumpAndSettle();

    // 82 plates for 12 visible names, before the viewport entered the
    // declutter. Every plate is recorded with the camera that framed
    // it, so this asks the question directly rather than through a
    // count that cannot fail: is there a name drawn where nobody is
    // looking?
    final cam = WheelRenderStats.cameraForTest;
    expect(cam, isNotNull, reason: 'no camera recorded — nothing was painted');
    final boxes = List.of(WheelRenderStats.labelBoxesForTest);
    expect(boxes, isNotEmpty);
    final offScreen = boxes.where((b) => !cam!.overlaps(b)).toList();
    expect(offScreen, isEmpty,
        reason: '${offScreen.length} of ${boxes.length} plates were painted '
            'outside the camera. A label the reader cannot see still takes '
            'the room beside one they can.');
  });
  group('a cap is about the screen, not a number in a table', () {
    test('a phone is told less than a desktop by the same row', () {
      final row = wheelDetailFor(2.0);
      // A 1280x663 pane against a 390x620 phone. 「很多这些也看不见了」 was
      // the first version of this table applying the phone's answer to
      // the desktop.
      final desktop = row.capFor(WheelLabelKind.power, areaPx: 1280 * 663);
      final phone = row.capFor(WheelLabelKind.power, areaPx: 390 * 620);
      expect(phone, lessThan(desktop));
      expect(desktop, greaterThanOrEqualTo(22),
          reason: 'measured before any of this existed: a 1280x663 pane at '
              '200% drew 22 power names. A rule that takes those away is '
              'not decluttering, it is deleting.');
      expect(phone, lessThanOrEqualTo(10));
    });

    test('a kind this row draws never falls to none', () {
      final row = wheelDetailFor(2.0);
      for (final kind in WheelLabelKind.values) {
        expect(row.capFor(kind, areaPx: 120 * 120), greaterThan(0),
            reason: 'a chart that names nothing at all is not calmer, it '
                'is mute');
      }
    });

    test('and a kind it does not draw stays at none, however big', () {
      expect(
          wheelDetailFor(1.0)
              .capFor(WheelLabelKind.record, areaPx: 4000 * 3000),
          0);
    });
  });

  testWidgets('zoomed in, the rings still say which rings they are',
      (tester) async {
    // 2026-09-17, measured on the ring stack at 200%: ONE ring name on
    // the whole screen, out of five drawn rings. Every repeat was
    // correctly skipped — the anchored labels really are on screen at
    // that zoom — and then four of the five anchored labels lost their
    // plate to a POWER name, because `_paintBandNames` ran after
    // `_paintArcs` while its own comment said ring names go first.
    //
    // "Which ring am I on" is the one question the list beside the
    // chart cannot answer, so it wins the plate.
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
    tester.view.physicalSize = const Size(1600, 1000);
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
    final iv = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final vp = tester.getSize(find.byType(InteractiveViewer));
    final canvas =
        tester.getSize(find.byKey(const ValueKey('wheelSceneBoundary')));
    final side = math.min(canvas.width, canvas.height);
    const zoom = 2.0;
    final q = Offset(side / 2 + side * 0.21 + (vp.width - side) / 2,
        side / 2 + (vp.height - side) / 2);
    iv.transformationController!.value = _viewMatrix(zoom,
        Offset(vp.width / 2 - zoom * q.dx, vp.height / 2 - zoom * q.dy));
    await tester.pumpAndSettle();

    final rings =
        WheelRenderStats.labelKindsForTest[WheelLabelKind.ring] ?? 0;
    expect(rings, greaterThanOrEqualTo(3),
        reason: 'only $rings ring names on a 1280x663 screen at 200%. A '
            'reader who has zoomed past the legend cannot tell which '
            'thread they are reading.');
    await tester.pumpWidget(const SizedBox.shrink());
  });

}
