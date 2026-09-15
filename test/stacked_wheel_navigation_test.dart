/// Search and genealogy taps must resolve to the records the projected
/// wheel actually displays. Data comes from the same real services as
/// the page; the projected widget exposes its range, ids and callbacks.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/biblical_person.dart';
import 'package:seeksparks/models/chronology.dart' show Patriarch;
import 'package:seeksparks/models/hebrew_king.dart';
import 'package:seeksparks/models/strip_lanes.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/chronology_service.dart';
import 'package:seeksparks/services/family_tree_service.dart';
import 'package:seeksparks/services/hebrew_kings_service.dart';
import 'package:seeksparks/services/timeline_service.dart';
import 'package:seeksparks/utils/chronology_explorer.dart';
import 'package:seeksparks/utils/wheel_search.dart';
import 'package:seeksparks/widgets/chronology_explorer.dart';
import 'package:seeksparks/widgets/stacked_chronology_wheel.dart';
import 'package:seeksparks/widgets/year_digest_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WheelHistoryData data;
  late List<Patriarch> patriarchs;
  late List<HebrewKing> kings;
  late List<BiblicalPerson> people;

  setUpAll(() async {
    data = await WheelHistoryService.instance.load();
    await ChronologyService.instance.load();
    await HebrewKingsService.instance.load();
    people = await FamilyTreeService.instance.loadAll();
    patriarchs = ChronologyService.instance.cached!.patriarchs;
    kings = HebrewKingsService.instance.cached!.kings;
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> pump(WidgetTester tester,
      {required Set<String> hidden, ChronologyPeriod? period}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MainProvider()),
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child: MaterialApp(
          home: RadialChronologyPage(
        initialPeriod: period,
        initialHiddenStreams: hidden,
      )),
    ));
    await settle(tester);
  }

  StackedChronologyWheel chart(WidgetTester tester) => tester
      .widget<StackedChronologyWheel>(find.byType(StackedChronologyWheel));

  Finder bottomText(String text) =>
      find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

  for (final kind in [
    WheelHitKind.power,
    WheelHitKind.ministry,
    WheelHitKind.patriarch
  ]) {
    testWidgets(
        'a hidden out-of-period $kind search selects its visible 3D record',
        (tester) async {
      final (id, name) = switch (kind) {
        WheelHitKind.power => (
            data.powers.first.id,
            data.powers.first.nameFor('zh-Hans')
          ),
        WheelHitKind.ministry => (
            data.ministries.first.id,
            data.ministries.first.nameFor('zh-Hans')
          ),
        _ => (patriarchs.first.id, patriarchs.first.nameFor('zh-Hans')),
      };
      final hit = searchWheel(
              data: data,
              query: name,
              locale: 'zh-Hans',
              axisEnd: kMaxYear,
              patriarchs: patriarchs,
              creationYear: TimelineService.instance.meta.creation!.year,
              tradition: kDrawnTradition)
          .hits
          .singleWhere((hit) => hit.kind == kind && hit.id == id);
      final oldPeriod = chronologyPeriods.singleWhere((p) => p.id == 'recent');
      expect(oldPeriod.contains(hit.year!), isFalse);
      final expected =
          chronologyPeriods.skip(1).firstWhere((p) => p.contains(hit.year!));
      await pump(tester, hidden: {hit.streamId}, period: oldPeriod);
      expect(chart(tester).startYear, oldPeriod.start);
      expect(chart(tester).groups.where((g) => g.id == hit.streamId), isEmpty);

      await tester.tap(find.byKey(const ValueKey('chronology-find')));
      await settle(tester);
      await tester.enterText(
          find.byKey(const ValueKey('wheelFindField')), name);
      await settle(tester);
      final result = find.descendant(
          of: find.byKey(const ValueKey('wheelFindList')),
          matching: find.text(hit.title));
      expect(result, findsOneWidget);
      await tester.tap(result);
      await settle(tester);

      final selected =
          kind == WheelHitKind.ministry ? '$kMinistryArcPrefix$id' : id;
      final drawn = chart(tester);
      expect(drawn.startYear, expected.start);
      expect(drawn.endYear, expected.end);
      expect(drawn.selectedId, selected);
      expect(
          drawn.groups
              .singleWhere((g) => g.id == hit.streamId)
              .records
              .any((r) => r.id == selected),
          isTrue);
      expect(
          tester
              .widget<DropdownButton<String>>(
                  find.byKey(const ValueKey('stackedWheelGroup')))
              .value,
          hit.streamId);
      final explorer =
          tester.widget<ChronologyExplorer>(find.byType(ChronologyExplorer));
      expect(explorer.controller!.period.id, expected.id);
      expect(
          tester
              .widget<DropdownButton<ChronologyPeriod>>(
                  find.byKey(const ValueKey('chronology-period')))
              .value!
              .id,
          expected.id);
      expect(find.byType(BottomSheet), findsOneWidget);
      final sheet = tester
          .renderObjectList<RenderParagraph>(find.descendant(
              of: find.byType(BottomSheet), matching: find.byType(RichText)))
          .map((text) => text.text.toPlainText())
          .join('\n');
      expect(sheet, contains(name),
          reason: 'selection keeps the raw id for detail lookup');
      final dynamic painter = tester
          .widget<CustomPaint>(find.descendant(
              of: find.byKey(const ValueKey('stackedChronologyWheel')),
              matching: find.byType(CustomPaint)))
          .painter!;
      expect(
          (painter.scene.prisms as List).any((dynamic p) => p.id == selected),
          isTrue,
          reason: 'the selected result must exist in the projected range');
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('stackedWheelFlat')));
      await settle(tester);
      // The projected chart has its own record rail; the year digest
      // belongs to the flat form. Switching through the visible control
      // verifies that search retained the exact cursor behind both forms.
      expect(
          tester.widget<YearDigestBar>(find.byType(YearDigestBar)).digest!.year,
          hit.year);
      final dynamic flatPainter = tester
          .widget<CustomPaint>(find.descendant(
              of: find.byKey(const ValueKey('wheelSceneBoundary')),
              matching: find.byType(CustomPaint)))
          .painter!;
      expect(flatPainter.selectedId, selected);
      expect(flatPainter.rangeStart, expected.start);
      expect(flatPainter.rangeEnd, expected.end);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
      'repeating the same search restores its group and resets the view',
      (tester) async {
    final song = data.powers.singleWhere((power) => power.id == 'song-dynasty');
    await pump(tester, hidden: {});
    final groupFinder = find.byKey(const ValueKey('stackedWheelGroup'));
    Future<void> searchSong() async {
      await tester.tap(find.byKey(const ValueKey('chronology-find')));
      await settle(tester);
      await tester.enterText(find.byKey(const ValueKey('wheelFindField')),
          song.nameFor('zh-Hans'));
      await settle(tester);
      final result = find.descendant(
          of: find.byKey(const ValueKey('wheelFindList')),
          matching: find.text(song.nameFor('zh-Hans')));
      expect(result, findsOneWidget);
      await tester.tap(result);
      await settle(tester);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(bottomText(song.nameFor('zh-Hans')), findsOneWidget);
    }

    await searchSong();
    expect(chart(tester).selectedId, song.id);
    expect(
        tester.widget<DropdownButton<String>>(groupFinder).value, song.stream);
    final range = (chart(tester).startYear, chart(tester).endYear);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(tester);

    final groupMenu = tester.widget<DropdownButton<String>>(groupFinder);
    expect(groupMenu.items!.any((item) => item.value == 'egypt'), isTrue);
    groupMenu.onChanged!('egypt');
    await settle(tester);
    expect(tester.widget<DropdownButton<String>>(groupFinder).value, 'egypt');
    expect(chart(tester).selectedId, song.id,
        reason: 'changing the visible layer leaves the previous selection id');
    final viewer =
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    viewer.transformationController!.value = Matrix4.identity()
      ..translateByDouble(42, -24, 0, 1)
      ..scaleByDouble(2, 2, 1, 1);
    await tester.pump();
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 2);
    expect(viewer.transformationController!.value.entry(0, 3), isNot(0));

    await searchSong();
    expect(chart(tester).selectedId, song.id);
    expect((chart(tester).startYear, chart(tester).endYear), range,
        reason: 'the reset must come from a new reveal, not a range change');
    expect(
        tester.widget<DropdownButton<String>>(groupFinder).value, song.stream);
    expect(viewer.transformationController!.value.storage,
        orderedEquals(Matrix4.identity().storage),
        reason: 'a repeated search must undo the intervening zoom and pan');
    final dynamic painter = tester
        .widget<CustomPaint>(find.descendant(
            of: find.byKey(const ValueKey('stackedChronologyWheel')),
            matching: find.byType(CustomPaint)))
        .painter!;
    expect(
        (painter.scene.prisms as List)
            .any((dynamic prism) => prism.id == song.id),
        isTrue,
        reason: 'the same selected record is actually visible again');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final hideOtherMentions in [false, true]) {
    testWidgets(
        'rail taps use visible source exclusions (hidden=$hideOtherMentions)',
        (tester) async {
      final david = people.singleWhere((p) => p.id == 'david');
      final hidden = <String>{
        if (hideOtherMentions) kReignLayerId,
        if (hideOtherMentions)
          for (final event in data.events)
            if (event.people.any((person) => person.id == david.id))
              event.stream,
      };
      final expected = stripLineageCohorts(people: people, drawnIds: {
        for (final p in patriarchs) p.id,
        if (!hidden.contains(kReignLayerId))
          for (final king in kings) king.id,
        for (final event in data.events)
          if (!hidden.contains(event.stream))
            for (final person in event.people) person.id,
      }).singleWhere((cohort) => cohort.year == david.birthYear);
      expect(expected.people.any((p) => p.id == david.id), hideOtherMentions);
      await pump(tester, hidden: hidden);
      final projected = chart(tester);
      final record = projected.groups
          .singleWhere((g) => g.id == kLineageLayerId)
          .records
          .singleWhere((r) => r.startYear == david.birthYear);
      // The projection's own callback already carries the exact record
      // chosen by its shared hit geometry, exercised in the renderer tests.
      projected.onOpen(record);
      await settle(tester);
      expect(find.byType(BottomSheet), findsOneWidget);
      for (final person in expected.people) {
        expect(bottomText(person.localizedName('zh-Hans')), findsOneWidget);
      }
      for (final person in people.where((p) =>
          p.yearSystem == 'bc' &&
          p.birthYear == david.birthYear &&
          !expected.people.contains(p))) {
        expect(bottomText(person.localizedName('zh-Hans')), findsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
