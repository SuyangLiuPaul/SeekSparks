/// Exercise the actual projected chart with real Chinese, European and
/// Roman records. Painter diagnostics report the text it really drew;
/// this test never reimplements the label-admission algorithm.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/strip_lanes.dart' show StripLaneKind;
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/utils/wheel_stack_layout.dart';
import 'package:seeksparks/utils/wheel_text_metrics.dart';
import 'package:seeksparks/utils/year_digest.dart';
import 'package:seeksparks/widgets/stacked_chronology_wheel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WheelHistoryData data;
  late Map<String, WheelPower> powers;
  late Map<String, WheelHistoryEvent> events;

  setUpAll(() async {
    data = await WheelHistoryService.instance.load();
    powers = {for (final power in data.powers) power.id: power};
    events = {for (final event in data.events) event.id: event};
    for (final family in ['Roboto']) {
      await (FontLoader(family)
            ..addFont(rootBundle
                .load('assets/fonts/Roboto-VariableFont_wdth,wght.ttf')))
          .load();
    }
    await (FontLoader('NotoSansSC-Sub')
          ..addFont(rootBundle.load('assets/fonts/NotoSansSC-Sub.otf')))
        .load();
  });

  List<StackedChronologyGroup> groupsFor(String locale) {
    const colors = [Color(0xFF376684), Color(0xFF756140), Color(0xFF596B4C)];
    return [
      for (final (index, id) in ['china', 'europe', 'rome'].indexed)
        StackedChronologyGroup(
          id: id,
          name: data.streams
              .singleWhere((stream) => stream.id == id)
              .nameFor(locale),
          color: colors[index],
          records: [
            for (final power
                in data.powers.where((power) => power.stream == id))
              YearDigestItem(
                id: power.id,
                kind: StripLaneKind.stream,
                moment: YearMoment.ongoing,
                startYear: power.start,
                endYear: power.endFor(2026),
                openEnded: power.ongoing,
              ),
            // Preserve a real point event beside durations. Its complete
            // name remains reachable in the record rail even when its
            // zero-length prism has no room to carry canvas text.
            for (final event
                in data.events.where((event) => event.stream == id).take(1))
              YearDigestItem(
                id: event.id,
                kind: StripLaneKind.events,
                moment: YearMoment.happened,
                startYear: event.year,
                endYear: event.year,
              ),
          ],
        ),
    ];
  }

  String label(YearDigestItem item, String locale) =>
      powers[item.id]?.nameFor(locale) ?? events[item.id]!.titleFor(locale);

  Finder paintFinder() => find.descendant(
      of: find.byKey(const ValueKey('stackedChronologyWheel')),
      matching: find.byType(CustomPaint));

  dynamic painter(WidgetTester tester) =>
      tester.widget<CustomPaint>(paintFinder()).painter!;

  List<WheelStackPrism> prisms(WidgetTester tester) =>
      (painter(tester).scene.prisms as List).cast<WheelStackPrism>();

  TransformationController viewController(WidgetTester tester) => tester
      .widget<InteractiveViewer>(find.byType(InteractiveViewer))
      .transformationController!;

  Future<void> pumpWheel(
    WidgetTester tester, {
    Size size = const Size(1000, 700),
    String locale = 'en',
    List<StackedChronologyGroup>? groups,
    ValueChanged<YearDigestItem>? onOpen,
    VoidCallback? onFlat,
    String? selectedId,
    int startYear = -4200,
    int endYear = 2026,
    AppSettings? settings,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    SharedPreferences.setMockInitialValues({});
    final activeSettings = settings ?? AppSettings();
    await activeSettings.setFontFamily('Roboto');
    // Font selection starts AppSettings' 600 ms preference-write debounce.
    // Drain it in the fixture, including range-update pumps that do not
    // otherwise wait for a dropdown animation before the test ends.
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => activeSettings,
      child: MaterialApp(
        theme: ThemeData(
            fontFamily: 'Roboto', fontFamilyFallback: const ['NotoSansSC-Sub']),
        home: Scaffold(
          body: StackedChronologyWheel(
            groups: groups ?? groupsFor(locale),
            locale: locale,
            label: (item) => label(item, locale),
            onOpen: onOpen ?? (_) {},
            onFlat: onFlat ?? () {},
            selectedId: selectedId,
            startYear: startYear,
            endYear: endYear,
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  Future<void> chooseGroup(
      WidgetTester tester, String? id, String locale) async {
    await tester.tap(find.byKey(const ValueKey('stackedWheelGroup')));
    await tester.pumpAndSettle();
    final name = id == null
        ? stackedWheelText('overview', locale)
        : data.streams.singleWhere((stream) => stream.id == id).nameFor(locale);
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
    expect(painter(tester).fontFamily, 'Roboto');
    expect(
        tester
            .widget<DropdownButton<String>>(
                find.byKey(const ValueKey('stackedWheelGroup')))
            .style!
            .fontFamily,
        'Roboto');
  }

  void expectRealPaintClear(WidgetTester tester) {
    final paint = painter(tester);
    final size = tester.getSize(paintFinder());
    final recorder = ui.PictureRecorder();
    paint.paint(Canvas(recorder), size);
    recorder.endRecording().dispose();
    final labels = (paint.paintedLabelBounds as List).cast<Rect>();
    final recordIds = (paint.paintedRecordIds as List).cast<String>();
    expect(recordIds.toSet().length, recordIds.length,
        reason: 'Each drawn name must refer to one visible original record.');
    expect((paint.scene.records as Map).keys, containsAll(recordIds));
    expect(labels, isNotEmpty,
        reason: 'An empty diagnostic list cannot prove readable canvas type.');
    for (var i = 0; i < labels.length; i++) {
      final box = labels[i];
      expect(box.left, greaterThanOrEqualTo(-.5));
      expect(box.top, greaterThanOrEqualTo(-.5));
      expect(box.right, lessThanOrEqualTo(size.width + .5));
      expect(box.bottom, lessThanOrEqualTo(size.height + .5));
      for (var j = i + 1; j < labels.length; j++) {
        expect(box.overlaps(labels[j]), isFalse,
            reason:
                'Actual painted labels $i and $j overlap: $box / ${labels[j]}');
      }
    }
    // Check the shapes from the scene passed to this very painter, not a
    // second fit formula. Camera controls occupy the final 44 px.
    for (final prism in prisms(tester)) {
      if (prism.bounds.isEmpty) continue;
      expect(prism.bounds.left, greaterThanOrEqualTo(-.5), reason: prism.id);
      expect(prism.bounds.top, greaterThanOrEqualTo(-.5), reason: prism.id);
      expect(prism.bounds.right, lessThanOrEqualTo(size.width + .5),
          reason: prism.id);
      expect(prism.bounds.bottom, lessThanOrEqualTo(size.height - 44 + .5),
          reason: '${prism.id} intersects the camera controls');
    }
  }

  testWidgets('choosing a group shows exactly its original records',
      (tester) async {
    addTearDown(tester.view.reset);
    final groups = groupsFor('en');
    await pumpWheel(tester, groups: groups);
    await chooseGroup(tester, 'europe', 'en');
    final expected = groups
        .singleWhere((group) => group.id == 'europe')
        .records
        .where((record) => record.endYear >= -4200 && record.startYear <= 2026)
        .map((record) => record.id)
        .toSet();
    expect((painter(tester).scene.records as Map).keys.toSet(), expected);
    expect(
        tester
            .widget<DropdownButton<String>>(
                find.byKey(const ValueKey('stackedWheelGroup')))
            .value,
        'europe');
    await chooseGroup(tester, null, 'en');
    final all = {
      for (final group in groups)
        for (final record in group.records)
          if (record.endYear >= -4200 && record.startYear <= 2026) record.id
    };
    expect((painter(tester).scene.records as Map).keys.toSet(), all);
    expect(tester.takeException(), isNull);
  });

  testWidgets('separation and rotation change geometry without changing dates',
      (tester) async {
    addTearDown(tester.view.reset);
    await pumpWheel(tester);
    await chooseGroup(tester, 'china', 'en');
    final before = {for (final prism in prisms(tester)) prism.id: prism};
    final tiered =
        before.values.where((prism) => prism.topHeight > 13).toList();
    expect(tiered, isNotEmpty,
        reason: 'The real China corpus must exercise concurrent tiers.');
    final selected = tester
        .widget<IconButton>(find.byKey(const ValueKey('stackedWheelExpand')))
        .isSelected;
    await tester.tap(find.byKey(const ValueKey('stackedWheelExpand')));
    await tester.pump();
    expect(
        tester
            .widget<IconButton>(
                find.byKey(const ValueKey('stackedWheelExpand')))
            .isSelected,
        !selected!);
    final after = {for (final prism in prisms(tester)) prism.id: prism};
    expect(after.keys.toSet(), before.keys.toSet());
    expect(tiered.any((prism) => after[prism.id]!.topHeight != prism.topHeight),
        isTrue);
    for (final id in before.keys) {
      expect(after[id]!.startAngle, before[id]!.startAngle);
      expect(after[id]!.endAngle, before[id]!.endAngle);
    }
    final rotation = painter(tester).scene.rotation as double;
    await tester.tap(find.byKey(const ValueKey('stackedRotateRight')));
    await tester.pump();
    expect((painter(tester).scene.rotation as double) - rotation,
        closeTo(math.pi / 6, 1e-9));
    await tester.tap(find.byKey(const ValueKey('stackedRotateLeft')));
    await tester.pump();
    expect(painter(tester).scene.rotation, closeTo(rotation, 1e-9));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'zoom and reset operate the actual viewer; Flat leaves through callback',
      (tester) async {
    addTearDown(tester.view.reset);
    var flats = 0;
    await pumpWheel(tester, onFlat: () => flats++);
    final controller = viewController(tester);
    expect(controller.value.getMaxScaleOnAxis(), 1);
    await tester.tap(find.byKey(const ValueKey('stackedZoomIn')));
    await tester.pump();
    expect(controller.value.getMaxScaleOnAxis(), greaterThan(1));
    final larger = controller.value.getMaxScaleOnAxis();
    await tester.tap(find.byKey(const ValueKey('stackedZoomOut')));
    await tester.pump();
    expect(controller.value.getMaxScaleOnAxis(), lessThan(larger));
    await tester.tap(find.byKey(const ValueKey('stackedZoomIn')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('stackedReset')));
    await tester.pump();
    expect(controller.value, Matrix4.identity());
    await tester.tap(find.byKey(const ValueKey('stackedWheelFlat')));
    expect(flats, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a visible prism opens its original record', (tester) async {
    addTearDown(tester.view.reset);
    final opened = <YearDigestItem>[];
    await pumpWheel(tester, onOpen: opened.add);
    await chooseGroup(tester, 'china', 'en');
    final scenePrisms = prisms(tester);
    final size = tester.getSize(paintFinder());
    Offset? target;
    String? id;
    for (final prism in scenePrisms.reversed) {
      if (prism.sweep == 0) continue;
      final candidate = prism.projection.polar(
          prism.middleRadius, prism.middleAngle,
          height: prism.topHeight);
      if (candidate.dy < 32 || candidate.dy > size.height - 48) continue;
      if (hitWheelStackPrism(scenePrisms, candidate)?.id != prism.id) continue;
      target = candidate;
      id = prism.id;
      break;
    }
    expect(target, isNotNull,
        reason: 'The focused real China group must have a reachable segment.');
    final origin = tester.getTopLeft(paintFinder());
    await tester.tapAt(origin + target!);
    await tester.pump();
    expect(opened.single.id, id);
    expect(opened.single.startYear, powers[id]!.start);
    expect(opened.single.endYear, powers[id]!.endFor(2026));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an 8x point marker keeps a six-screen-pixel touch radius',
      (tester) async {
    addTearDown(tester.view.reset);
    final source = groupsFor('en').singleWhere((group) => group.id == 'china');
    final event = source.records
        .firstWhere((record) => record.kind == StripLaneKind.events);
    final opened = <YearDigestItem>[];
    await pumpWheel(tester,
        groups: [
          StackedChronologyGroup(
              id: source.id,
              name: source.name,
              color: source.color,
              records: [event]),
        ],
        onOpen: opened.add);
    await chooseGroup(tester, 'china', 'en');
    final originalPrism = prisms(tester).single;
    expect(originalPrism.sweep, 0);
    final projected = originalPrism.projection.polar(
        originalPrism.middleRadius, originalPrism.middleAngle,
        height: originalPrism.topHeight);
    final viewer = find.byType(InteractiveViewer);
    final viewport = tester.getSize(viewer);
    final centre = viewport.center(Offset.zero);
    final controller = viewController(tester);
    // Place the real projected marker in the centre of the actual viewer,
    // clear of the header and camera controls, at the supported 8x limit.
    controller.value = Matrix4.identity()
      ..translateByDouble(centre.dx, centre.dy, 0, 1)
      ..scaleByDouble(8, 8, 1, 1)
      ..translateByDouble(-projected.dx, -projected.dy, 0, 1);
    await tester.pump();
    expect(controller.value.getMaxScaleOnAxis(), 8);
    final actualPrism = prisms(tester).single;
    final actualPoint = actualPrism.projection.polar(
        actualPrism.middleRadius, actualPrism.middleAngle,
        height: actualPrism.topHeight);
    final screenPoint =
        MatrixUtils.transformPoint(controller.value, actualPoint);
    final near = screenPoint + const Offset(5.5, 0);
    final far = screenPoint + const Offset(12, 0);
    final callouts =
        (painter(tester).scene.callouts as List).cast<WheelStackCallout>();
    for (final point in [near, far]) {
      expect((Offset.zero & viewport).deflate(44).contains(point), isTrue);
      expect(
          callouts.any((callout) => callout.bounds
              .inflate(4 / 8)
              .contains(controller.toScene(point))),
          isFalse,
          reason: 'This gesture must test the point marker, not a side name.');
    }
    final origin = tester.getTopLeft(viewer);
    await tester.tapAt(origin + far);
    await tester.pump();
    expect(opened, isEmpty,
        reason: 'A scene-space radius of six would wrongly capture this '
            '12-screen-pixel miss when zoomed to 8x.');
    await tester.tapAt(origin + near);
    await tester.pump();
    expect(opened.single, same(event));
    expect(opened.single.startYear, events[event.id]!.year);
    expect(opened.single.endYear, events[event.id]!.year);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a painted side callout opens its original record',
      (tester) async {
    addTearDown(tester.view.reset);
    final opened = <YearDigestItem>[];
    await pumpWheel(tester,
        locale: 'zh-Hant', startYear: 100, endYear: 1500, onOpen: opened.add);
    await chooseGroup(tester, 'china', 'zh-Hant');
    expectRealPaintClear(tester);
    final callouts =
        (painter(tester).scene.callouts as List).cast<WheelStackCallout>();
    expect(callouts, isNotEmpty,
        reason: 'Real overlapping China durations need readable side names.');
    final target = callouts.first;
    final original =
        (painter(tester).scene.records as Map)[target.id] as YearDigestItem;
    final transform = viewController(tester).value.clone();
    await tester.tapAt(tester.getTopLeft(paintFinder()) + target.bounds.center);
    await tester.pump();
    expect(opened.single, same(original));
    expect(opened.single.id, target.id);
    expect(viewController(tester).value, transform);
    expect(tester.takeException(), isNull);
  });

  testWidgets('record cards keep a point event reachable by its full id',
      (tester) async {
    addTearDown(tester.view.reset);
    final opened = <YearDigestItem>[];
    final groups = groupsFor('zh-Hant');
    final event =
        groups.first.records.firstWhere((r) => r.kind == StripLaneKind.events);
    await pumpWheel(tester,
        locale: 'zh-Hant', groups: groups, onOpen: opened.add);
    await chooseGroup(tester, 'china', 'zh-Hant');
    final card = find.byKey(ValueKey('stackedRecord-${event.id}'));
    await tester.scrollUntilVisible(card, 200,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('stackedWheelRecords')),
          matching: find.byType(Scrollable),
        ));
    await tester.tap(card);
    await tester.pump();
    expect(opened.single, same(event));
    expect(opened.single.startYear, opened.single.endYear);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selection and date-window updates keep the correct group',
      (tester) async {
    addTearDown(tester.view.reset);
    final groups = groupsFor('en');
    final selected = groups
        .singleWhere((group) => group.id == 'rome')
        .records
        .firstWhere(
            (record) => record.startYear >= 100 && record.endYear <= 1500);
    await pumpWheel(tester, groups: groups);
    await pumpWheel(tester,
        groups: groups, selectedId: selected.id, startYear: 100, endYear: 1500);
    expect(
        tester
            .widget<DropdownButton<String>>(
                find.byKey(const ValueKey('stackedWheelGroup')))
            .value,
        'rome');
    expect(painter(tester).selectedId, selected.id);
    expect(painter(tester).scene.start, 100);
    expect(painter(tester).scene.end, 1500);
    final visible =
        (painter(tester).scene.records as Map).values.cast<YearDigestItem>();
    expect(visible.map((record) => record.id), contains(selected.id));
    expect(
        visible.every(
            (record) => record.endYear >= 100 && record.startYear <= 1500),
        isTrue);
    expect(viewController(tester).value, Matrix4.identity());
    expect(tester.takeException(), isNull);
  });

  testWidgets('the actual painter reuses text on warm frames and rotation',
      (tester) async {
    addTearDown(tester.view.reset);
    final china =
        groupsFor('zh-Hant').singleWhere((group) => group.id == 'china');
    WheelTextMetrics.resetStatsForTest();
    await pumpWheel(tester,
        groups: [china], locale: 'zh-Hant', startYear: 100, endYear: 1500);
    await chooseGroup(tester, 'china', 'zh-Hant');
    final cold = WheelTextMetrics.layoutsForTest;
    final visibleRecords = (painter(tester).scene.records as Map).length;
    expect(cold, greaterThan(0));
    expect(cold, lessThanOrEqualTo(visibleRecords + 5),
        reason:
            'Only one paragraph per record and the five date ticks are needed.');
    WheelTextMetrics.zeroCounterForTest();
    expectRealPaintClear(tester);
    final warm = WheelTextMetrics.layoutsForTest;
    final paintedIds =
        (painter(tester).paintedRecordIds as List).cast<String>();
    final paintedNames = paintedIds.length;
    expect(paintedIds, containsAll(['song-dynasty', 'liao-khitan']),
        reason: 'The overlapping Song and Liao durations both retain visible '
            'surface, so both original names must be painted in this window.');
    expect(paintedNames, greaterThanOrEqualTo(3),
        reason: 'The real China 100–1500 window needs at least three names; '
            'date ticks alone do not make the chart readable.');
    expect(warm, 0);
    WheelTextMetrics.zeroCounterForTest();
    await tester.tap(find.byKey(const ValueKey('stackedRotateRight')));
    await tester.pump();
    final rotation = WheelTextMetrics.layoutsForTest;
    expect(rotation, 0,
        reason: 'Rotation moves the existing text; it must not reshape it.');
    WheelTextMetrics.zeroCounterForTest();
    await tester.tap(find.byKey(const ValueKey('stackedZoomIn')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('stackedZoomIn')));
    await tester.pump();
    final zoom = WheelTextMetrics.layoutsForTest;
    expect(zoom, lessThanOrEqualTo(visibleRecords + 5),
        reason: 'A new text size needs at most one new paragraph per label.');
    expect(viewController(tester).value.getMaxScaleOnAxis(), greaterThan(1));
    debugPrint('Stacked China actual painter layouts: cold=$cold; warm=$warm; '
        'rotation=$rotation; zoom=$zoom; '
        'painted record names=$paintedNames; '
        'painted labels=${(painter(tester).paintedLabelBounds as List).length}');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the focused all-time window follows the real group extent',
      (tester) async {
    addTearDown(tester.view.reset);
    final groups = groupsFor('en');
    await pumpWheel(tester, groups: groups);
    await chooseGroup(tester, 'rome', 'en');
    final records = groups.singleWhere((group) => group.id == 'rome').records;
    final earliest = records.map((record) => record.startYear).reduce(math.min);
    final latest = records.map((record) => record.endYear).reduce(math.max);
    expect(painter(tester).scene.start, earliest.clamp(-4200, 2026));
    expect(painter(tester).scene.end, latest.clamp(-4200, 2026));
    await chooseGroup(tester, null, 'en');
    expect(painter(tester).scene.start, -4200);
    expect(painter(tester).scene.end, 2026);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short screens recover every record through All names',
      (tester) async {
    addTearDown(tester.view.reset);
    final groups = groupsFor('zh-Hant');
    final opened = <YearDigestItem>[];
    await pumpWheel(tester,
        size: const Size(800, 304),
        locale: 'zh-Hant',
        groups: groups,
        onOpen: opened.add);
    await chooseGroup(tester, 'china', 'zh-Hant');
    expect(find.byKey(const ValueKey('stackedWheelRecords')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('stackedWheelAllNames')));
    await tester.pumpAndSettle();
    final records = groups
        .singleWhere((group) => group.id == 'china')
        .records
        .where((record) => record.endYear >= -4200 && record.startYear <= 2026)
        .toList()
      ..sort((a, b) => a.startYear.compareTo(b.startYear));
    final sheet = find.byType(BottomSheet);
    final list = find.descendant(of: sheet, matching: find.byType(ListView));
    expect(tester.widget<ListView>(list).childrenDelegate.estimatedChildCount,
        records.length);
    final lastName = find.descendant(
        of: sheet, matching: find.text(label(records.last, 'zh-Hant')));
    await tester.scrollUntilVisible(lastName, 180,
        scrollable:
            find.descendant(of: sheet, matching: find.byType(Scrollable)));
    // ensureVisible changes the scroll offset after scrollUntilVisible's
    // last frame. Lay out that offset before measuring or tapping: the
    // stale final-row centre was y305.3 in a 304 px viewport.
    await tester.pumpAndSettle();
    final rowRect = tester.getRect(lastName);
    final listRect = tester.getRect(list);
    expect(rowRect.top, greaterThanOrEqualTo(listRect.top - .5));
    expect(rowRect.bottom, lessThanOrEqualTo(listRect.bottom + .5));
    expect(lastName.hitTestable(), findsOneWidget);
    await tester.tap(lastName);
    await tester.pumpAndSettle();
    expect(opened.single, same(records.last));
    expect(sheet, findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(360, 435), const Size(800, 304)]) {
    for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
      testWidgets(
          'real painted labels and controls stay clear at $size $locale',
          (tester) async {
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});
        final settings = AppSettings();
        await settings.setFontSize(kFontSizeMax);
        await settings.setMenuScale(kMenuScaleMax);
        await tester.pump(const Duration(milliseconds: 650));
        await pumpWheel(tester, size: size, locale: locale, settings: settings);
        await chooseGroup(tester, 'china', locale);
        expectRealPaintClear(tester);
        final camera = <Rect>[];
        for (final key in [
          'stackedRotateLeft',
          'stackedRotateRight',
          'stackedWheelAllNames',
          'stackedZoomOut',
          'stackedReset',
          'stackedZoomIn'
        ]) {
          final control = tester.getRect(find.byKey(ValueKey(key)));
          expect(control.width, greaterThanOrEqualTo(44));
          expect(control.height, greaterThanOrEqualTo(44));
          expect(control.left, greaterThanOrEqualTo(0));
          expect(control.right, lessThanOrEqualTo(size.width));
          for (final earlier in camera) {
            expect(control.overlaps(earlier), isFalse);
          }
          camera.add(control);
        }
        final allNames = find.byKey(const ValueKey('stackedWheelAllNames'));
        final allNamesLabel = stackedWheelText('allNames', locale);
        final allNamesParagraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: allNames, matching: find.text(allNamesLabel)));
        expect(allNamesParagraph.didExceedMaxLines, isFalse);
        final allNamesRect = tester.getRect(allNames);
        for (final box in allNamesParagraph.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: allNamesLabel.length))) {
          final start =
              allNamesParagraph.localToGlobal(Offset(box.left, box.top));
          final end =
              allNamesParagraph.localToGlobal(Offset(box.right, box.bottom));
          expect(start.dx, greaterThanOrEqualTo(allNamesRect.left - .5));
          expect(end.dx, lessThanOrEqualTo(allNamesRect.right + .5));
          expect(start.dy, greaterThanOrEqualTo(allNamesRect.top - .5));
          expect(end.dy, lessThanOrEqualTo(allNamesRect.bottom + .5));
        }
        final dropdown = find.byKey(const ValueKey('stackedWheelGroup'));
        final name = data.streams
            .singleWhere((stream) => stream.id == 'china')
            .nameFor(locale);
        final nameFinder =
            find.descendant(of: dropdown, matching: find.text(name));
        final paragraph = tester.renderObject<RenderParagraph>(nameFinder);
        expect(paragraph.didExceedMaxLines, isFalse);
        final dropdownRect = tester.getRect(dropdown);
        for (final box in paragraph.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: name.length))) {
          final a = paragraph.localToGlobal(Offset(box.left, box.top));
          final b = paragraph.localToGlobal(Offset(box.right, box.bottom));
          expect(a.dx, greaterThanOrEqualTo(dropdownRect.left - .5));
          expect(b.dx, lessThanOrEqualTo(dropdownRect.right + .5));
          expect(a.dy, greaterThanOrEqualTo(dropdownRect.top - .5));
          expect(b.dy, lessThanOrEqualTo(dropdownRect.bottom + .5));
        }
        await chooseGroup(tester, 'europe', locale);
        expectRealPaintClear(tester);
        await tester.tap(find.byKey(const ValueKey('stackedWheelExpand')));
        await tester.pump();
        expectRealPaintClear(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
