/// These assertions inspect the actual scroll viewport, not a second
/// implementation of the zoom controls. Fit once left the last three
/// quarters of history off screen on a phone while its utility tests passed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/strip_chronology_page.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/utils/strip_chronology_layout.dart';
import 'package:seeksparks/utils/chronology_explorer.dart';
import 'package:seeksparks/widgets/strip_chronology_painter.dart';
import 'package:seeksparks/widgets/chronology_explorer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await WheelHistoryService.instance.load();
  });

  Future<void> mount(WidgetTester tester,
      {Widget page = const StripChronologyPage()}) async {
    SharedPreferences.setMockInitialValues({'locale': 'en'});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider(create: (_) => MainProvider()),
      ChangeNotifierProvider(create: (_) => AppSettings()),
    ], child: MaterialApp(home: page)));
    await tester.pumpAndSettle();
  }

  ScrollableState horizontal(WidgetTester tester) =>
      tester.state<ScrollableState>(find
          .descendant(
              of: find.byKey(const ValueKey('stripHScroll')),
              matching: find.byType(Scrollable))
          .first);
  StripLanesPainter painter(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter)
      .whereType<StripLanesPainter>()
      .single;

  testWidgets('phone Fit All really puts both axis ends in the viewport',
      (tester) async {
    await mount(tester);
    final fit = find.byWidgetPredicate((w) =>
        w is IconButton &&
        w.icon is Icon &&
        (w.icon as Icon).icon == Icons.fit_screen);
    await tester.tap(fit);
    await tester.pumpAndSettle();
    final scroll = horizontal(tester).position;
    expect(scroll.pixels, 0);
    expect(scroll.maxScrollExtent, closeTo(0, 0.01));
    expect(stripContentWidth(painter(tester).pxPerYear),
        closeTo(scroll.viewportDimension, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a real strip event row opens its own detail and selects the chart',
      (tester) async {
    await mount(tester);
    final explorer =
        tester.widget<ChronologyExplorer>(find.byType(ChronologyExplorer));
    final row = find
        .byWidgetPredicate((widget) =>
            widget.key is ValueKey<String> &&
            (widget.key as ValueKey<String>)
                .value
                .startsWith('chronology-event-') &&
            widget is InkWell)
        .first;
    final id = (tester.widget(row).key as ValueKey<String>)
        .value
        .substring('chronology-event-'.length);
    final event = explorer.data.events.singleWhere((event) => event.id == id);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(event.titleFor(explorer.locale)).hitTestable(),
        findsOneWidget);
    expect(find.text(event.descFor(explorer.locale)).hitTestable(),
        findsOneWidget);
    expect(painter(tester).selectedId, event.id);
  });

  testWidgets('time zoom preserves the actual visible centre year',
      (tester) async {
    await mount(tester);
    final zoomIn = find.byWidgetPredicate((w) =>
        w is IconButton &&
        w.icon is Icon &&
        (w.icon as Icon).icon == Icons.add);
    while (painter(tester).pxPerYear < kStripInitialPxPerYear) {
      await tester.tap(zoomIn);
      await tester.pumpAndSettle();
    }
    horizontal(tester).position.jumpTo(4712.37);
    await tester.pump();
    final plannedRows = painter(tester).rows;
    horizontal(tester).position.jumpTo(4722.37);
    await tester.pump();
    expect(identical(plannedRows, painter(tester).rows), isTrue,
        reason: 'a pan must reuse the same packed lanes');
    final scroll = horizontal(tester).position;
    final before = yearForX(scroll.pixels + scroll.viewportDimension / 2,
        painter(tester).pxPerYear);
    await tester.tap(zoomIn);
    await tester.pumpAndSettle();
    final afterScroll = horizontal(tester).position;
    expect(
        yearForX(afterScroll.pixels + afterScroll.viewportDimension / 2,
            painter(tester).pxPerYear),
        closeTo(before, 1e-8));
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching forms carries the chosen range and layers both ways',
      (tester) async {
    final period = chronologyPeriods.singleWhere((p) => p.id == 'biblical');
    const hidden = {'japan', 'china'};
    await mount(tester,
        page: StripChronologyPage(
            initialPeriod: period, initialHiddenStreams: hidden));
    await tester.tap(find.byIcon(Icons.donut_large));
    await tester.pumpAndSettle();
    expect(find.byType(RadialChronologyPage), findsOneWidget);
    var explorer =
        tester.widget<ChronologyExplorer>(find.byType(ChronologyExplorer));
    expect(explorer.controller!.period, same(period));
    expect(explorer.hiddenStreams, hidden);
    await tester.tap(find.byIcon(Icons.view_week));
    await tester.pumpAndSettle();
    expect(find.byType(StripChronologyPage), findsOneWidget);
    explorer =
        tester.widget<ChronologyExplorer>(find.byType(ChronologyExplorer));
    expect(explorer.controller!.period, same(period));
    expect(explorer.hiddenStreams, hidden);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 700));
  });
}
