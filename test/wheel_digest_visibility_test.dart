// The digest describes the visible chart, as year_digest.dart promises.
// It once received the full corpus even after the wheel removed a ring;
// a 450 BC readout therefore listed Japan and the Americas while its
// neighbouring event browser respected the filter. Exercise the actual
// page and its filter controls, not a second copy of the filtering code.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yahwehs_sword/models/app_settings.dart';
import 'package:yahwehs_sword/models/strip_lanes.dart';
import 'package:yahwehs_sword/models/wheel_history.dart';
import 'package:yahwehs_sword/pages/radial_chronology_page.dart';
import 'package:yahwehs_sword/providers/main_provider.dart';
import 'package:yahwehs_sword/services/chronology_service.dart';
import 'package:yahwehs_sword/services/hebrew_kings_service.dart';
import 'package:yahwehs_sword/utils/year_digest.dart';
import 'package:yahwehs_sword/widgets/year_digest_bar.dart';
import 'package:yahwehs_sword/widgets/chart_help_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WheelHistoryData data;

  setUpAll(() async {
    data = await WheelHistoryService.instance.load();
    await ChronologyService.instance.load();
    await HebrewKingsService.instance.load();
  });

  Future<void> mount(WidgetTester tester, Set<String> hidden) async {
    SharedPreferences.setMockInitialValues(
        <String, Object>{ChartHelp.seenKey: true});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MainProvider()),
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child:
          MaterialApp(home: RadialChronologyPage(initialHiddenStreams: hidden, initialStacked: false)),
    ));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> year(WidgetTester tester, int value) async {
    tester
        .widget<Slider>(find.byKey(const ValueKey('chronoYearScrubber')))
        .onChanged!(value.toDouble());
    await tester.pump();
  }

  List<YearDigestItem> items(WidgetTester tester) {
    final digest =
        tester.widget<YearDigestBar>(find.byType(YearDigestBar)).digest!;
    return [...digest.happened, ...digest.ongoing];
  }

  Set<String> idsOf(WidgetTester tester, StripLaneKind kind) => items(tester)
      .where((item) => item.kind == kind)
      .map((item) => item.id)
      .toSet();

  Future<void> toggle(WidgetTester tester, Finder row) async {
    await tester.tap(find.byKey(const ValueKey('chronology-filter')));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // THE OPTIONS LIST BY KEY, not "the first Scrollable in the sheet".
    // 2026-09-16 the sheet gained a find box 「另外filter那边应该有个搜
    // 索」, and a `TextField` carries an `EditableText` with a Scrollable
    // of its own — which is now the first one, so this was scrolling a
    // one-line text field looking for a checkbox.
    final scrolling = find.descendant(
        of: find.byKey(const ValueKey('chronologyFilterOptions')),
        matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(row, 250, scrollable: scrolling.first);
    // scrollUntilVisible stops as soon as the row is BUILT, which can
    // leave it straddling the footer; the tap then lands on the footer
    // and silently does nothing. Bring it properly into view first.
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chronologyFilterApply')));
    await tester.pump(const Duration(milliseconds: 400));
    // The Filter is REMEMBERED since 2026-09-16, which means applying it
    // writes to AppSettings, which debounces its own persistence by
    // 600 ms. Let that timer run rather than leave it pending at
    // teardown — the debounce is the app's, not this test's to dodge.
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('hidden stream powers and events stay out of the year readout',
      (tester) async {
    // 2026-09-15: this used to hide four streams and leave eighteen on.
    // The wheel now draws at most five rings, so that is a state no
    // reader can reach, and from it the sheet would rightly refuse to
    // turn Japan on — the toggle below would have gone through a
    // disabled checkbox and proved nothing. Hide everything but the
    // spine instead, which is what a reader actually has in front of
    // them, and Japan goes on into the free fifth slot.
    final hidden = data.streams
        .map((stream) => stream.id)
        .where((id) => !const ['scripture', 'israel', 'judah', 'church']
            .contains(id))
        .toSet();
    await mount(tester, hidden);
    await year(tester, -450);
    final absentPowers = data.powers
        .where((power) =>
            hidden.contains(power.stream) &&
            power.start <= -450 &&
            power.endFor(kMaxYear) >= -450)
        .map((power) => power.id)
        .toSet();
    expect(absentPowers, isNotEmpty,
        reason: 'the reported year must exercise hidden powers');
    expect(idsOf(tester, StripLaneKind.stream).intersection(absentPowers),
        isEmpty);

    // Read a real hidden event's own year as well: filtering only the
    // stream lanes would leave its event in the shared events group.
    final event = data.events.firstWhere((event) =>
        hidden.contains(event.stream) &&
        event.year >= kMinYear &&
        event.year <= kMaxYear);
    await year(tester, event.year);
    expect(idsOf(tester, StripLaneKind.events), isNot(contains(event.id)));

    // Applying the draft must invalidate the cached digest immediately.
    await year(tester, -450);
    final japanName = data.streams
        .singleWhere((stream) => stream.id == 'japan')
        .nameFor('zh-Hans');
    await toggle(tester, find.widgetWithText(CheckboxListTile, japanName));
    final japanesePowers = data.powers
        .where((power) =>
            power.stream == 'japan' &&
            power.start <= -450 &&
            power.endFor(kMaxYear) >= -450)
        .map((power) => power.id)
        .toSet();
    expect(japanesePowers, isNotEmpty);
    expect(idsOf(tester, StripLaneKind.stream), containsAll(japanesePowers));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('ministries follow their layer while reigns stay independent',
      (tester) async {
    final kings = HebrewKingsService.instance.cached!.kings;
    final ministry = data.ministries.firstWhere((ministry) => kings.any(
        (king) =>
            king.reignStart <= ministry.start &&
            king.reignEnd >= ministry.start));
    // Every stream is hidden, so this also checks that stream switches
    // do not swallow the separate reign and ministry layers.
    await mount(tester, data.streams.map((stream) => stream.id).toSet());
    await year(tester, ministry.start);
    final reignIds = idsOf(tester, StripLaneKind.kings);
    final ministryIds = idsOf(tester, StripLaneKind.ministries);
    expect(reignIds, isNotEmpty);
    expect(ministryIds, contains('$kStripMinistryPrefix${ministry.id}'));
    expect(idsOf(tester, StripLaneKind.stream), isEmpty);
    expect(idsOf(tester, StripLaneKind.events), isEmpty);

    await toggle(tester, find.byKey(const ValueKey('wheelFilterLifespans')));
    expect(idsOf(tester, StripLaneKind.kings), reignIds);
    expect(idsOf(tester, StripLaneKind.ministries), ministryIds);

    await toggle(tester, find.byKey(const ValueKey('wheelFilterMinistries')));
    expect(idsOf(tester, StripLaneKind.ministries), isEmpty);
    expect(idsOf(tester, StripLaneKind.kings), reignIds);

    await toggle(tester, find.byKey(const ValueKey('wheelFilterMinistries')));
    expect(idsOf(tester, StripLaneKind.ministries), ministryIds);
    expect(idsOf(tester, StripLaneKind.kings), reignIds);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
