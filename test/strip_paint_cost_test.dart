/// Count the layouts made by the real strip painters, not a copy of
/// their label loop. The first frame includes measuring and painting;
/// a warm frame and a pan over the same records must lay out nothing.
/// Full-axis and viewport-only counts isolate culling from caching.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/timeline_event.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/utils/font_catalog.dart';
import 'package:seeksparks/utils/strip_chronology_layout.dart';
import 'package:seeksparks/utils/strip_event_cards.dart';
import 'package:seeksparks/models/strip_lanes.dart';
import 'package:seeksparks/utils/strip_paint_text.dart';
import 'package:seeksparks/utils/strip_paint_visibility.dart';
import 'package:seeksparks/widgets/strip_chronology_painter.dart';

void _paint(CustomPainter painter, Size size) {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  recorder.endRecording().dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(StripPaintTextCache.resetForTest);
  tearDown(StripPaintTextCache.resetForTest);

  test('a cached line preserves the old text width and line height', () {
    for (final text in ['犹大与以色列', '猶大與以色列', 'Kings of Israel']) {
      final style = canvasTextStyle(fontSize: 12, fontWeight: FontWeight.w600);
      final old = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final line = StripPaintTextCache.layout(text: text, style: style);
      expect(line.width, closeTo(old.width, 0.01), reason: text);
      expect(line.height, closeTo(old.height, 0.01), reason: text);
      old.dispose();
    }
  });

  test('width, ellipsis, theme and size distinguish cached lines', () {
    final style = canvasTextStyle(fontSize: 12, color: WbColors.light.text);
    final full =
        StripPaintTextCache.layout(text: 'Kings of Israel', style: style);
    final clipped = StripPaintTextCache.layout(
        text: 'Kings of Israel', style: style, maxWidth: 40, ellipsis: '…');
    expect(full.width, greaterThan(clipped.width));
    expect(clipped.width, lessThanOrEqualTo(40));
    StripPaintTextCache.layout(
        text: 'Kings of Israel', style: style.copyWith(fontSize: 24));
    StripPaintTextCache.layout(
        text: 'Kings of Israel',
        style: style.copyWith(color: WbColors.dark.text));
    expect(StripPaintTextCache.layoutsForTest, 4);
    StripPaintTextCache.zeroCounterForTest();
    expect(
        identical(full,
            StripPaintTextCache.layout(text: 'Kings of Israel', style: style)),
        isTrue);
    expect(StripPaintTextCache.layoutsForTest, 0);
  });

  test('the line cache has a fixed memory bound', () {
    final style = canvasTextStyle(fontSize: 12);
    for (var i = 0; i <= StripPaintTextCache.maxEntries; i++) {
      StripPaintTextCache.layout(text: 'Label $i', style: style);
    }
    expect(StripPaintTextCache.entriesForTest, StripPaintTextCache.maxEntries);
  });

  test('culling keeps point marks and the visible tail of an earlier label',
      () {
    bool visible(double start, double end) => stripPaintIntersects(
        start: start, end: end, visibleStart: 100, visibleEnd: 200);
    expect(visible(100, 100), isTrue);
    expect(visible(200, 200), isTrue);
    expect(visible(60, 140), isTrue);
    expect(visible(10, 90), isFalse);
    expect(visible(210, 230), isFalse);
  });

  test('adjacent ruler labels keep a readable gap', () {
    expect(
        stripPaintLabelFits(labelStart: 105, previousLabelEnd: 100), isFalse);
    expect(stripPaintLabelFits(labelStart: 108, previousLabelEnd: 100), isTrue);
  });

  test('the high-zoom ruler lays out only the visible years, then reuses them',
      () {
    const zoom = 96.0;
    final x0 = xForYear(1, zoom);
    final fullWidth = stripContentWidth(zoom);
    _paint(
        StripRulerPainter(
          pxPerYear: zoom,
          locale: 'zh-Hans',
          wb: WbColors.light,
          tickFontPx: 11,
        ),
        Size(fullWidth, 40));
    final full = StripPaintTextCache.layoutsForTest;
    // The old renderer made one layout for each of these same ticks,
    // plus the two differently styled endpoint labels, every frame.
    expect(full, rulerTicks(rulerStep(zoom)).length + 2);
    StripPaintTextCache.resetForTest();
    final visible = StripRulerPainter(
      pxPerYear: zoom,
      locale: 'zh-Hans',
      wb: WbColors.light,
      tickFontPx: 11,
      visibleX0: x0,
      visibleX1: x0 + 900,
    );
    _paint(visible, Size(fullWidth, 40));
    final cold = StripPaintTextCache.layoutsForTest;
    expect(cold, greaterThan(0));
    expect(cold, lessThan(20));
    StripPaintTextCache.zeroCounterForTest();
    _paint(visible, Size(fullWidth, 40));
    expect(StripPaintTextCache.layoutsForTest, 0);
    // ignore: avoid_print
    print('STRIP RULER: full axis=$full layouts; 900px viewport=$cold; warm=0');
  });

  test('the merged event corpus is culled before text layout', () {
    Map<String, dynamic> json(String path) =>
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final base = WheelHistoryData.fromJson(json('assets/wheel_history.json'));
    final timeline = json('assets/bible_timeline.json');
    final events = [
      ...base.events,
      ...bibleNarrativeEvents([
        for (final entry in timeline['events'] as List)
          TimelineEvent.fromJson(entry as Map<String, dynamic>),
      ]),
    ]..sort((a, b) => a.year.compareTo(b.year));
    const zoom = 1.5;
    final plan = buildStripEventCards(
        events: events,
        pxPerYear: zoom,
        viewportWidth: 900,
        laneFontPx: 12,
        locale: 'zh-Hant',
        measureHeight: measureStripEventTextHeight);
    var rowTop = 0.0;
    final rows = <StripRow>[];
    for (var i = 0; i < plan.rows.length; i++) {
      rows.add(StripRow.events(
        StripLane(
            id: 'events:$i',
            kind: StripLaneKind.events,
            subLane: i,
            spans: const []),
        eventCards: plan.rows[i],
        top: rowTop,
        height: plan.rowHeights[i],
      ));
      rowTop += plan.rowHeights[i];
    }
    StripPaintTextCache.resetForTest();
    final palette = StripPalette(
      streamColors: const {},
      spanLabel: const {},
      eventById: {for (final event in events) event.id: event},
    );
    final width = stripContentWidth(zoom);
    final height = rowTop;
    StripLanesPainter painter(double x0, double x1,
            {double y0 = 0, double y1 = double.infinity}) =>
        StripLanesPainter(
          rows: rows,
          pxPerYear: zoom,
          locale: 'zh-Hant',
          selectedId: null,
          wb: WbColors.light,
          laneFontPx: 12,
          palette: palette,
          visibleX0: x0,
          visibleX1: x1,
          visibleY0: y0,
          visibleY1: y1,
        );
    expect(events.length, greaterThan(500));
    _paint(painter(0, width), Size(width, height));
    final full = StripPaintTextCache.layoutsForTest;
    StripPaintTextCache.resetForTest();
    final x0 = xForYear(-1000, zoom);
    final visible = painter(x0, x0 + 900);
    _paint(visible, Size(width, height));
    final cold = StripPaintTextCache.layoutsForTest;
    expect(cold, greaterThan(0));
    expect(cold, lessThan(full));
    StripPaintTextCache.zeroCounterForTest();
    _paint(visible, Size(width, height));
    expect(StripPaintTextCache.layoutsForTest, 0);
    StripPaintTextCache.resetForTest();
    _paint(painter(x0, x0 + 900, y0: height + 1, y1: height + 100),
        Size(width, height));
    expect(StripPaintTextCache.layoutsForTest, 0,
        reason:
            'off-screen lanes must be rejected before measuring their labels');
    // ignore: avoid_print
    print('STRIP EVENTS (${events.length} merged): full axis=$full layouts; '
        '900px viewport=$cold; warm=0');
  });
}
