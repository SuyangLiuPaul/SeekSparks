/// These tests inspect the actual page's projected records and tap the
/// actual faces. A second copy of the packing algorithm would not prove
/// that the full chart survived a mode switch.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/widgets/chronology_depth_toggle.dart'
    show kDepthViewOffered;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/strip_lanes.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/strip_chronology_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/utils/strip_depth_layout.dart';
import 'package:seeksparks/utils/chronology_explorer.dart';
import 'package:seeksparks/widgets/chronology_explorer.dart';
import 'package:seeksparks/widgets/strip_chronology_painter.dart';
import 'package:seeksparks/widgets/chart_help_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WheelHistoryData data;
  setUpAll(() async {
    data = await WheelHistoryService.instance.load();
  });

  Future<void> mount(WidgetTester tester,
      {Size size = const Size(1000, 800),
      Set<String> hidden = const {},
      ChronologyPeriod? period}) async {
    SharedPreferences.setMockInitialValues(
        {'locale': 'en', ChartHelp.seenKey: true});
    // AppSettings does not load persisted preferences in its constructor.
    // This fixture promises English, so initialise the live setting too.
    final settings = AppSettings();
    await settings.setLocale('en');
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => settings),
        ],
        child: MaterialApp(
            home: StripChronologyPage(
                initialHiddenStreams: hidden,
                initialPeriod: period,
                // These tests are about the depth rendering, and the
                // page opens FLAT now 「sword wheel default应该是平面图」.
                initialStacked: true))));
    await tester.pumpAndSettle();
  }

  StripLanesPainter painter(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((widget) => widget.painter)
      .whereType<StripLanesPainter>()
      .single;
  ScrollPosition position(WidgetTester tester, String key) => tester
      .state<ScrollableState>(find
          .descendant(
              of: find.byKey(ValueKey(key)), matching: find.byType(Scrollable))
          .first)
      .position;
  Iterable<StripDepthRowExtent> extents(StripLanesPainter p) =>
      p.rows.map((row) => (
            id: row.headingKey ?? row.lane!.id,
            top: row.top,
            height: row.height
          ));
  Set<String> ids(StripLanesPainter p) => {
        for (final row in p.rows)
          if (!row.isHeading)
            for (final span in row.lane!.spans) span.id
      };
  Future<void> tapContent(WidgetTester tester, Offset point) async {
    final h = position(tester, 'stripHScroll');
    final v = position(tester, 'stripVScroll');
    h.jumpTo(
        (point.dx - h.viewportDimension / 2).clamp(0.0, h.maxScrollExtent));
    v.jumpTo(
        (point.dy - v.viewportDimension / 2).clamp(0.0, v.maxScrollExtent));
    await tester.pump();
    await tester.tapAt(
        tester.getTopLeft(find.byKey(const ValueKey('chronologyStrip'))) +
            point);
    await tester.pumpAndSettle();
  }

  Future<void> closeSheet(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await tester.pumpAndSettle();
  }

  Future<void> zoomToReadable(WidgetTester tester) async {
    while (painter(tester).pxPerYear < 3) {
      await tester.tap(find.byWidgetPredicate((w) =>
          w is IconButton &&
          w.icon is Icon &&
          (w.icon as Icon).icon == Icons.add));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('3D retains every country, layer and event from the flat chart',
      (tester) async {
    // 2026-09-16 「或者我觉得立体其实strip和wheel都没有必要要了」. The
    // depth view still builds, paints and hit-tests -- this test runs
    // again the moment `kDepthViewOffered` goes back to true -- but its
    // door is closed, so a test that presses the door cannot run.
    if (!kDepthViewOffered) {
      markTestSkipped('the depth view is not offered; see kDepthViewOffered');
      return;
    }
    await mount(tester);
    final raised = painter(tester);
    expect(raised.is3D, isTrue);
    expect({
      for (final row in raised.rows)
        if (row.lane?.kind == StripLaneKind.stream) row.lane!.ownerId
    }, data.streams.map((stream) => stream.id).toSet());
    expect(
        {
          for (final row in raised.rows)
            if (!row.isHeading) row.lane!.kind
        },
        containsAll([
          StripLaneKind.events,
          StripLaneKind.lives,
          StripLaneKind.kings,
          StripLaneKind.ministries,
          StripLaneKind.rail,
          StripLaneKind.stream
        ]));
    for (final row in raised.rows.where((row) => !row.isHeading)) {
      expect(
          row.depthShapes.length,
          row.eventCards.isEmpty
              ? row.lane!.spans.length
              : row.eventCards.length);
      for (final shape in row.depthShapes) {
        expect(shape.bounds.top, greaterThanOrEqualTo(row.top));
        expect(shape.bounds.bottom, lessThan(row.top + row.height));
      }
    }
    final eventIds = {
      for (final row in raised.rows)
        for (final card in row.eventCards)
          for (final event in card.events) event.id
    };
    expect(eventIds, data.events.map((event) => event.id).toSet());
    await tester.tap(find.byKey(const ValueKey('stripDepth-flat')));
    await tester.pumpAndSettle();
    final flat = painter(tester);
    expect(flat.is3D, isFalse);
    expect(ids(flat), ids(raised));
    expect(flat.rows.map((row) => row.headingKey ?? row.lane!.id),
        raised.rows.map((row) => row.headingKey ?? row.lane!.id));
    expect(flat.rows.expand((row) => row.eventCards).length,
        raised.rows.expand((row) => row.eventCards).length);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'front, roof and side of a concurrent power open its original record',
      (tester) async {
    // 2026-09-16 「或者我觉得立体其实strip和wheel都没有必要要了」. The
    // depth view still builds, paints and hit-tests -- this test runs
    // again the moment `kDepthViewOffered` goes back to true -- but its
    // door is closed, so a test that presses the door cannot run.
    if (!kDepthViewOffered) {
      markTestSkipped('the depth view is not offered; see kDepthViewOffered');
      return;
    }
    await mount(tester);
    await zoomToReadable(tester);
    final p = painter(tester);
    expect(p.locale, 'en');
    final row = p.rows.firstWhere((row) =>
        row.lane?.kind == StripLaneKind.stream &&
        row.lane!.subLane > 0 &&
        row.depthShapes.any((shape) => shape.front.width > 40));
    final shape = row.depthShapes.firstWhere((shape) => shape.front.width > 40);
    final power = data.powers.singleWhere((power) => power.id == shape.id);
    final roof =
        shape.top.reduce((a, b) => a + b) / shape.top.length.toDouble();
    final side =
        shape.side.reduce((a, b) => a + b) / shape.side.length.toDouble();
    for (final point in [shape.front.center, roof, side]) {
      expect(hitStripDepthShapes(row.depthShapes, point, touchRadius: 0)?.id,
          shape.id);
      await tapContent(tester, point);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(painter(tester).selectedId, power.id);
      expect(find.text(power.nameFor('en')).hitTestable(), findsWidgets);
      await closeSheet(tester);
    }
    final selected = painter(tester).selectedId;
    final h = position(tester, 'stripHScroll');
    final v = position(tester, 'stripVScroll');
    final scrollTo = row.top + row.height * .25;
    expect(scrollTo, lessThan(v.maxScrollExtent));
    v.jumpTo(scrollTo);
    await tester.pump();
    final oldScale = painter(tester).pxPerYear;
    final oldHorizontal = h.pixels;
    final anchor = stripDepthScrollAnchor(extents(painter(tester)), v.pixels)!;
    await tester.tap(find.byKey(const ValueKey('stripDepth-flat')));
    await tester.pumpAndSettle();
    expect(identical(h, position(tester, 'stripHScroll')), isTrue);
    expect(identical(v, position(tester, 'stripVScroll')), isTrue);
    expect(painter(tester).pxPerYear, oldScale);
    expect(h.pixels, oldHorizontal);
    expect(painter(tester).selectedId, selected);
    final flatAnchor =
        stripDepthScrollAnchor(extents(painter(tester)), v.pixels)!;
    expect(flatAnchor.id, anchor.id);
    expect(flatAnchor.fraction, closeTo(anchor.fraction, 1e-8));
    await tester.tap(find.byKey(const ValueKey('stripDepth-3d')));
    await tester.pumpAndSettle();
    expect(v.pixels, closeTo(scrollTo, 1e-8));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'phone mode targets stay reachable and keep active range and filters',
      (tester) async {
    // 2026-09-16 「或者我觉得立体其实strip和wheel都没有必要要了」. The
    // depth view still builds, paints and hit-tests -- this test runs
    // again the moment `kDepthViewOffered` goes back to true -- but its
    // door is closed, so a test that presses the door cannot run.
    if (!kDepthViewOffered) {
      markTestSkipped('the depth view is not offered; see kDepthViewOffered');
      return;
    }
    final period =
        chronologyPeriods.singleWhere((period) => period.id == 'biblical');
    const hidden = {'china', 'japan'};
    await mount(tester,
        size: const Size(360, 800), hidden: hidden, period: period);
    final before = ids(painter(tester));
    final scale = painter(tester).pxPerYear;
    for (final key in ['stripDepth-flat', 'stripDepth-3d']) {
      final target = find.byKey(ValueKey(key));
      expect(target.hitTestable(), findsOneWidget);
      final rect = tester.getRect(target);
      expect(rect.width, greaterThanOrEqualTo(44));
      expect(rect.height, greaterThanOrEqualTo(44));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
      await tester.tap(target);
      await tester.pumpAndSettle();
      final explorer =
          tester.widget<ChronologyExplorer>(find.byType(ChronologyExplorer));
      expect(explorer.controller!.period, same(period));
      expect(explorer.hiddenStreams, hidden);
      expect(ids(painter(tester)), before);
      expect(painter(tester).pxPerYear, scale);
    }
    expect(tester.takeException(), isNull);
  });
}
