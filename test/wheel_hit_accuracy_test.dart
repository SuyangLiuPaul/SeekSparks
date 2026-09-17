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
import 'package:seeksparks/services/family_tree_service.dart';
import 'package:seeksparks/utils/radial_chronology_layout.dart';
import 'package:seeksparks/utils/wheel_view_layout.dart';
import 'package:seeksparks/widgets/chart_help_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await WheelHistoryService.instance.load();
    await ChronologyService.instance.load();
    // The genealogy rail is built from the family tree, and is EMPTY
    // without it — a test that forgets this reports "the sweep never
    // landed on the rail" for a chart that has no rail to land on.
    await FamilyTreeService.instance.loadAll();
  });

  testWidgets('every answer is inside the target it was admitted by',
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

  testWidgets('deep in, an answer is never about air the reader cannot see',
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
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(() => gesture.removePointer());

    // 4050%, which is where the report came from. The camera starts on
    // the hub at this scale, so the sweep has to pan until there is
    // something under the pointer at all.
    for (var i = 0; i < 11; i++) {
      await tester.tap(find.byKey(const ValueKey('wheelZoomInControl')));
      await tester.pumpAndSettle();
    }

    var answered = 0;
    var fromAir = 0;
    var worstAir = 0.0;
    var silentOnInk = 0;
    var silent = 0;
    for (var pan = 0; pan < 8; pan++) {
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
      for (final p in WheelRenderStats.hitsForTest) {
        if (p.id.isEmpty) {
          silent++;
          if (p.kind == 'nothingButOnArcInk' ||
              p.kind == 'nothingButOnRingInk') {
            silentOnInk++;
          }
          continue;
        }
        answered++;
        if (WheelRenderStats.hitWasOnInk(p)) continue;
        fromAir++;
        final px = ((p.r - p.centre).abs() - p.inkHalf) * p.zoom;
        if (px > worstAir) worstAir = px;
      }
      await tester.dragFrom(const Offset(450, 470), const Offset(-260, -260));
      await tester.pumpAndSettle();
    }

    expect(answered, greaterThan(100),
        reason: 'the pans must find the bands, or this measures nothing');
    // MEASURED 2026-09-17, before and after the one-rule change:
    //
    //   before   57/243/228/41 answers per pan, of which 56/130/137/41
    //            came from air; a point could be 175 screen px past the
    //            edge of the ink it was told it was on
    //   after    every answer on ink, 0 px of air
    //
    // Air is not a rounding error at this scale: it is most of a ring's
    // depth, being the gaps between its layers, and it is invisible.
    expect(fromAir, 0,
        reason: '$fromAir of $answered answers were about a band the '
            'pointer was not on, the worst by ${worstAir.round()} px. '
            'That is 「hover over那个不准确」 coming back.');

    // AND THE OTHER HALF OF THE SAME PROPERTY. Silence over air is the
    // right answer; silence over a band that is plainly painted under
    // the pointer is the same defect facing the other way, and it is
    // the one 「有时候在这根线上却不会出现圈圈」 reported.
    //
    // MEASURED 2026-09-17 at 4050%, before the stream branch stopped
    // also demanding a power arc at the angle: two of the eight camera
    // positions had 144 of 193 and 269 of 325 silent points standing on
    // ink — one of them answered NOTHING anywhere on the screen. After:
    // 49 and 56 silent, none of them on ink, and the answers went from
    // 132 and 0 to 276 and 269.
    expect(silentOnInk, 0,
        reason: '$silentOnInk of $silent silent points were standing on a '
            'painted band. A reader pointing at ink and being told '
            'nothing cannot tell that from the feature being broken.');
  });
  testWidgets('the whole of a mark answers, not the middle of it',
      (tester) async {
    // 2026-09-17 「好像只有中间这个可以选的 要不这根线只有中间那么长 不然
    // 人们以为整根线都可以选」, photographed at 1488%: an event tick some
    // ninety screen pixels long with a target box a quarter of that,
    // centred on it.
    //
    // The tick gate asked for a FINGER — twelve screen pixels either
    // side of the ring — and never looked at how long the mark it was
    // answering for had been drawn. At rest those are the same number.
    // They come apart the moment the reader zooms, because the ink
    // grows with the chart and a finger does not.
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
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(() => gesture.removePointer());

    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byKey(const ValueKey('wheelZoomInControl')));
      await tester.pumpAndSettle();
    }
    WheelRenderStats.hitsForTest.clear();
    const rect = Rect.fromLTRB(20, 150, 880, 800);
    const steps = 30;
    for (var i = 1; i < steps; i++) {
      for (var j = 1; j < steps; j++) {
        await gesture.moveTo(Offset(rect.left + rect.width * i / steps,
            rect.top + rect.height * j / steps));
        await tester.pump();
      }
    }
    final spokes = WheelRenderStats.hitsForTest
        .where((p) => p.kind == 'spoke:tick' && p.id.isNotEmpty)
        .toList();
    expect(spokes, isNotEmpty,
        reason: 'the sweep never landed on a record, so this measures '
            'nothing');
    // 12 logical pixels is `_pointerPx` for a mouse — the old gate, and
    // the whole of it.
    final past = spokes
        .where((p) => (p.r - p.centre).abs() > 12 / p.zoom)
        .length;
    // MEASURED 2026-09-17 at 753%, a 29x29 sweep: 0 of 9 tick answers
    // before, 13 of 22 after. Before the change this number could not
    // be anything but zero — the gate WAS the finger — so it is the one
    // number that proves the mark answers end to end rather than in the
    // middle. The other number in that pair matters too: the sweep
    // found nine marks and now finds twenty-two, because most of a tick
    // used to be unreachable.
    //
    // It reads `p.kind == 'spoke:tick'` and not `'spoke'` for a reason
    // that cost a run: with both gates counted the test passed against
    // the very defect it was written for, five of its fifteen answers
    // having come in through the label gate, where a large radial
    // offset is normal and says nothing about the mark.
    expect(past, greaterThan(0),
        reason: 'every record answered within a finger of its ring, which '
            'is what a gate that ignores the ink does. The mark is drawn '
            'longer than that.');
    for (final p in spokes) {
      expect(WheelRenderStats.hitErrorPx(p), lessThan(8),
          reason: 'a record answered ${WheelRenderStats.hitErrorPx(p)} px '
              'outside its own target');
    }
  });

  testWidgets('a rail mark answers along its own height', (tester) async {
    // 2026-09-17 「这些线做什么的好像没用一样也按不了」, of two clusters of
    // genealogy rail marks at 2412% on a phone. The marks are drawn a
    // third to all of the rail's pitch — taller where more people share
    // the year, which is the only thing the rail says — and the hit
    // test asked for `ink: 0`, a pointer and nothing else. Seen whole,
    // answerable in the middle: the same defect the event ticks had,
    // one ring further in.
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
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(() => gesture.removePointer());

    // THE CAMERA IS SET, NOT DRIVEN. The rail sits just outside the band
    // stack, and zooming with the control alone parks the view on the
    // hub — where there is no rail, and a sweep then measures nothing
    // while looking exactly like a pass.
    final iv = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final vp = tester.getSize(find.byType(InteractiveViewer));
    final canvasSize =
        tester.getSize(find.byKey(const ValueKey('wheelSceneBoundary')));
    final side = canvasSize.width < canvasSize.height
        ? canvasSize.width
        : canvasSize.height;
    // 2412%, which is where the photograph was taken — and it has to be
    // up here: a rail mark's ink is a fraction of a sub-ring's pitch,
    // about 1.9 canvas units at most on this pane, and a mouse pointer
    // is 12 SCREEN pixels. Those two are the same size at about 800%,
    // so below that the pointer covers the whole mark and there is
    // nothing to measure.
    const zoom = 24.0;
    // WHERE THE RAIL ACTUALLY IS, in both coordinates.
    //
    // Radius: 0.2896 of the side — just outside `bandsFractionFor`
    // (0.26), on the innermost sub-ring of the lifespan annulus.
    // Measured 97.05 of 335.12.
    //
    // ANGLE: the genealogy does not go all the way round. Its marks run
    // from Adam to Joseph and stop, so a camera parked at an arbitrary
    // bearing sits on an empty stretch of that circle and the sweep
    // reports "never landed on the rail" for a chart drawing 107 of
    // them. And the stretch is not where a reader would guess: the rail
    // carries the genealogy people the chart does NOT draw somewhere
    // else, and the patriarchs are all drawn as lifespans — so what is
    // left is the line from Abraham down, 主前2200 to 主前2, between
    // 0.223 and 2.195 radians. 主前1000 is in the middle of it.
    final railAngle = angleForSpan(-1000, kMinYear, kMaxYear);
    final railR = side * 0.2896;
    final p = Offset(side / 2 + railR * math.cos(railAngle),
        side / 2 + railR * math.sin(railAngle));
    final q = Offset(p.dx + (vp.width - side) / 2,
        p.dy + (vp.height - side) / 2);
    final m = Matrix4.identity();
    m.setEntry(0, 0, zoom);
    m.setEntry(1, 1, zoom);
    m.setEntry(2, 2, zoom);
    m.setEntry(0, 3, vp.width / 2 - zoom * q.dx);
    m.setEntry(1, 3, vp.height / 2 - zoom * q.dy);
    iv.transformationController!.value = m;
    await tester.pumpAndSettle();

    WheelRenderStats.hitsForTest.clear();
    // The viewer's own rectangle ON SCREEN. `Offset.zero & size` would
    // start at the top-left of the WINDOW, which is the app bar.
    final rect = tester.getRect(find.byType(InteractiveViewer));
    const steps = 30;
    for (var i = 1; i < steps; i++) {
      for (var j = 1; j < steps; j++) {
        await gesture.moveTo(Offset(rect.left + rect.width * i / steps,
            rect.top + rect.height * j / steps));
        await tester.pump();
      }
    }
    final marks = WheelRenderStats.hitsForTest
        .where((p) => p.kind == 'rail' && p.id.isNotEmpty)
        .toList();
    expect(marks, isNotEmpty,
        reason: 'the sweep never landed on the genealogy rail, so this '
            'measures nothing');
    // MEASURED 2026-09-17 at 2412%, a 29x29 sweep across the rail:
    // 0 of 55 rail answers landed past a pointer's width from the
    // rail's own radius before the change, and 52 of 107 after. Zero
    // was not a coincidence — the gate WAS the pointer — and the other
    // number says the rest of it: the sweep reaches 107 marks where it
    // used to reach 55.
    final past =
        marks.where((p) => (p.r - p.centre).abs() > 12 / p.zoom).length;
    expect(past, greaterThan(0),
        reason: 'every rail answer came from within a pointer of the rail '
            'centre, which is what a gate that ignores the ink does. The '
            'marks are drawn taller than that — that is what their height '
            'is FOR.');
    for (final p in marks) {
      expect(WheelRenderStats.hitErrorPx(p), lessThan(8),
          reason: 'a rail mark answered ${WheelRenderStats.hitErrorPx(p)} px '
              'outside its own target');
    }
  });

}
