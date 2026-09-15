// Search may reveal an event outside the chosen period. The explorer's
// menu, event list and the actual painter must then name the same range,
// without clearing the selected event or resetting the user's zoom.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/chronology_service.dart';
import 'package:seeksparks/services/hebrew_kings_service.dart';
import 'package:seeksparks/utils/chronology_explorer.dart';
import 'package:seeksparks/widgets/chronology_explorer.dart';
import 'package:seeksparks/widgets/year_digest_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WheelHistoryData data;

  setUpAll(() async {
    data = await WheelHistoryService.instance.load();
    await ChronologyService.instance.load();
    await HebrewKingsService.instance.load();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  // Reading the actual CustomPaint delegate checks what the next frame
  // draws. The private class has public range/selection fields; no copy
  // of its selection arithmetic is used to infer the painted result.
  dynamic painter(WidgetTester tester) => tester
      .widget<CustomPaint>(find.descendant(
        of: find.byKey(const ValueKey('wheelSceneBoundary')),
        matching: find.byType(CustomPaint),
      ))
      .painter!;

  testWidgets(
      'a later search result updates the sector without losing the event',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MainProvider()),
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child: const MaterialApp(home: RadialChronologyPage(initialStacked: false)),
    ));
    await settle(tester);

    final early =
        chronologyPeriods.singleWhere((period) => period.id == 'early');
    final dropdown = find.byType(DropdownButton<ChronologyPeriod>);
    tester.widget<DropdownButton<ChronologyPeriod>>(dropdown).onChanged!(early);
    await settle(tester);
    expect(painter(tester).rangeStart, early.start);
    expect(painter(tester).rangeEnd, early.end);

    final viewer =
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    viewer.transformationController!.value = Matrix4.identity()
      ..scaleByDouble(2, 2, 1, 1);
    await tester.pump();

    final event = data.events.singleWhere((event) => event.id == 'magna_carta');
    expect(early.contains(event.year), isFalse);
    final expected = chronologyPeriods
        .skip(1)
        .firstWhere((period) => period.contains(event.year));
    await tester.tap(find.byKey(const ValueKey('chronology-find')));
    await settle(tester);
    await tester.enterText(
        find.byKey(const ValueKey('wheelFindField')), 'Magna Carta');
    await settle(tester);
    await tester.tap(find.descendant(
      of: find.byKey(const ValueKey('wheelFindList')),
      matching: find.text(event.titleFor('zh-Hans')),
    ));
    await settle(tester);

    expect(find.byType(BottomSheet), findsOneWidget,
        reason: 'the result still opens its evidence sheet');
    expect(painter(tester).selectedId, event.id);
    expect(painter(tester).rangeStart, expected.start);
    expect(painter(tester).rangeEnd, expected.end);
    final explorer =
        tester.widget<ChronologyExplorer>(find.byType(ChronologyExplorer));
    expect(explorer.selectedId, event.id);
    expect(explorer.controller!.period.id, expected.id);
    expect(tester.widget<DropdownButton<ChronologyPeriod>>(dropdown).value!.id,
        expected.id);
    expect(
        tester.widget<YearDigestBar>(find.byType(YearDigestBar)).digest!.year,
        event.year,
        reason:
            'revealing a range must not replace the selected event year with its midpoint');
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 2,
        reason: 'search may pan to its result, but must preserve the zoom');

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(tester);
    final row = find.byKey(ValueKey('chronology-event-${event.id}'));
    expect(row.hitTestable(), findsOneWidget,
        reason:
            'the revealed event remains visible in the matching period list');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
