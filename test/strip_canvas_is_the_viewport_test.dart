// The strip paints the viewport, not the whole of history.
//
// 2026-09-15, two crash reports out of a reader's browser on 1.6.285:
//
//     Bad state: RenderBox was not laid out
//     RuntimeError: Aborted().  …at constructor PictureRecorder
//
// The strip's `CustomPaint` used to live INSIDE the horizontal scroll
// view, on a canvas as wide as the entire timeline. The arithmetic:
//
//     kStripMaxYear - kStripMinYear = 6,226 years
//     top of kStripZoomSteps        = 96 px/year
//     canvas                        = 597,696 px wide
//
// Skia cannot record a picture that size. It aborts, CanvasKit reports
// it from inside `PictureRecorder`, and the RenderBox that could not be
// laid out is reported beside it.
//
// Culling the DRAW CALLS does not help and never could — the painter
// already culled, which is what `visibleX0`/`visibleX1` are for. A
// picture's bounds are its canvas, not its marks. So the canvas had to
// shrink: the painters are siblings of the scroll views now, sized to
// what is on screen, and they translate by the scroll offset so every
// coordinate in the drawing code stays in content space.
//
// These assertions are about the CANVAS, because that is the thing that
// aborted. A future change that puts a painter back inside a scroll
// view fails here on the day it is written.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/pages/strip_chronology_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/utils/strip_chronology_layout.dart';
import 'package:seeksparks/widgets/chart_help_sheet.dart';

/// What the whole timeline measures at the deepest zoom the ladder
/// offers — the number that aborted CanvasKit.
double get _timelineAtMaxZoom => stripContentWidth(kStripZoomSteps.last);

Future<void> _pump(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues(
        <String, Object>{ChartHelp.seenKey: true});
  addTearDown(tester.view.reset);
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MainProvider()),
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child: const MaterialApp(home: StripChronologyPage()),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Real I/O never completes inside a widget test's fake-async zone,
    // so the service is warmed here and the page's own `initState`
    // resolves from the cache — the same reason
    // `strip_chronology_page_test.dart` does it. Without this the page
    // sits on its loading state and every assertion below passes
    // vacuously, which is worse than failing.
    await WheelHistoryService.instance.load();
  });

  test('the canvas this replaces really was unrecordable', () {
    // The premise, stated as arithmetic rather than as a memory of a
    // crash report. If the ladder or the date range ever changes, this
    // line says whether the danger is still there.
    expect(_timelineAtMaxZoom, greaterThan(500000),
        reason: 'the top of the zoom ladder no longer produces a huge '
            'timeline — the rest of this file is still correct, but the '
            'reasoning in its header needs revisiting');
  });

  testWidgets('no painter is inside a scroll view', (tester) async {
    // The structural form of the rule, and the one that catches a
    // regression regardless of zoom: a CustomPaint under a Scrollable
    // gets the SCROLLABLE'S content as its canvas.
    await _pump(tester, const Size(1400, 900));

    final inside = find.descendant(
      of: find.byType(Scrollable),
      matching: find.byType(CustomPaint),
    );
    final offenders = <String>[];
    for (final element in inside.evaluate()) {
      final paint = element.widget as CustomPaint;
      final painter = paint.painter ?? paint.foregroundPainter;
      if (painter == null) continue;
      final name = painter.runtimeType.toString();
      // Flutter's own scrollbars and material internals paint inside
      // scroll views; this rule is about the STRIP's painters.
      if (name.startsWith('Strip')) offenders.add(name);
    }
    expect(offenders, isEmpty,
        reason: 'these painters are inside a Scrollable, so their canvas '
            'is the scrolled content rather than the viewport: '
            '${offenders.join(", ")}');
  });

  testWidgets('every strip canvas fits on the screen', (tester) async {
    // The direct assertion. Whatever the structure, no picture the
    // strip records may be bigger than the window it is drawn in.
    const window = Size(1400, 900);
    await _pump(tester, window);

    final boxes = <String, Size>{};
    for (final element in find.byType(CustomPaint).evaluate()) {
      final paint = element.widget as CustomPaint;
      final painter = paint.painter ?? paint.foregroundPainter;
      if (painter == null) continue;
      final name = painter.runtimeType.toString();
      if (!name.startsWith('Strip')) continue;
      boxes[name] = (element.renderObject! as RenderBox).size;
    }

    expect(boxes, isNotEmpty,
        reason: 'the strip drew nothing, so this test proved nothing');
    for (final entry in boxes.entries) {
      expect(entry.value.width, lessThanOrEqualTo(window.width),
          reason: '${entry.key} has a ${entry.value.width.round()} px '
              'canvas on a ${window.width.round()} px screen');
      expect(entry.value.height, lessThanOrEqualTo(window.height),
          reason: '${entry.key} is ${entry.value.height.round()} px tall '
              'on a ${window.height.round()} px screen');
    }
  });

  testWidgets('and still fits after scrolling to the far end',
      (tester) async {
    // The canvas must not grow as the reader moves through the
    // timeline — the failure reported was on a push after minutes of
    // navigating, not on first paint.
    const window = Size(1400, 900);
    await _pump(tester, window);

    final scrollable = tester
        .state<ScrollableState>(find
            .descendant(
                of: find.byKey(const ValueKey('stripHScroll')),
                matching: find.byType(Scrollable))
            .first);
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();

    for (final element in find.byType(CustomPaint).evaluate()) {
      final paint = element.widget as CustomPaint;
      final painter = paint.painter ?? paint.foregroundPainter;
      if (painter == null) continue;
      if (!painter.runtimeType.toString().startsWith('Strip')) continue;
      final size = (element.renderObject! as RenderBox).size;
      expect(size.width, lessThanOrEqualTo(window.width),
          reason: '${painter.runtimeType} grew to ${size.width.round()} px '
              'once scrolled');
    }
  });
}
