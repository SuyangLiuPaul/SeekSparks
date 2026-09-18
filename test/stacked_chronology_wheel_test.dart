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

import 'package:yahwehs_sword/models/app_settings.dart';
import 'package:yahwehs_sword/models/strip_lanes.dart' show StripLaneKind;
import 'package:yahwehs_sword/models/wheel_history.dart';
import 'package:yahwehs_sword/utils/chronology_depth_view.dart';
import 'package:yahwehs_sword/utils/radial_chronology_layout.dart'
    show angleForSpan;
import 'package:yahwehs_sword/utils/wheel_stack_layout.dart';
import 'package:yahwehs_sword/utils/wheel_text_metrics.dart';
import 'package:yahwehs_sword/utils/year_digest.dart';
import 'package:yahwehs_sword/widgets/stacked_chronology_wheel.dart';

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
            // name remains reachable in All names even when its
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
    String? selectedId,
    int revealRevision = 0,
    int startYear = -4200,
    int endYear = 2026,
    AppSettings? settings,
    TransformationController? controller,
    ChronologyDepthCamera? initialCamera,
    ValueChanged<ChronologyDepthCamera>? onCameraChanged,
    double initialYaw = 0,
    double initialTilt = .70,
    double initialLift = 4,
    void Function(double, double)? onAnglesChanged,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    SharedPreferences.setMockInitialValues({});
    final activeSettings = settings ?? AppSettings();
    await activeSettings.setFontFamily('Roboto');
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
          onFlat: () {},
          selectedId: selectedId,
          revealRevision: revealRevision,
          startYear: startYear,
          endYear: endYear,
          controller: controller,
          initialCamera: initialCamera,
          onCameraChanged: onCameraChanged,
          initialYaw: initialYaw,
          initialTilt: initialTilt,
          initialLift: initialLift,
          onAnglesChanged: onAnglesChanged,
        )),
      ),
    ));
    await tester.pumpAndSettle();
    expect(painter(tester).fontFamily, 'Roboto');
  }

  Future<void> chooseSpacing(WidgetTester tester, String spacing) async {
    await tester.tap(find.byKey(const ValueKey('stackedWheelExpand')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('stackedWheelSpacing$spacing')));
    await tester.pumpAndSettle();
  }

  ChronologyDepthCamera camera(WidgetTester tester) {
    final view = viewController(tester).value;
    return ChronologyDepthCamera.capture(
      view: painter(tester).scene.view as ChronologyDepthView,
      viewport: Offset.zero & tester.getSize(find.byType(InteractiveViewer)),
      scale: view.getMaxScaleOnAxis(),
      translation: Offset(view.storage[12], view.storage[13]),
    );
  }

  void expectCamera(
      ChronologyDepthCamera actual, ChronologyDepthCamera expected) {
    expect(actual.zoom, closeTo(expected.zoom, 1e-7));
    expect(
        (actual.normalizedGroundCentre - expected.normalizedGroundCentre)
            .distance,
        lessThan(1e-7));
  }

  Set<String> visibleIds(List<StackedChronologyGroup> groups,
          {int start = -4200, int end = 2026}) =>
      {
        for (final group in groups)
          for (final record in group.records)
            if (record.endYear >= start && record.startYear <= end) record.id,
      };

  Offset toGlobal(WidgetTester tester, Offset point) =>
      tester.getTopLeft(find.byType(InteractiveViewer)) +
      MatrixUtils.transformPoint(viewController(tester).value, point);

  void expectRealPaintClear(WidgetTester tester, {bool fitShapes = false}) {
    final paint = painter(tester);
    final size = tester.getSize(paintFinder());
    final recorder = ui.PictureRecorder();
    paint.paint(Canvas(recorder), size);
    recorder.endRecording().dispose();
    final transform = viewController(tester).value;
    final labels = (paint.paintedLabelBounds as List)
        .cast<Rect>()
        .map((rect) => MatrixUtils.transformRect(transform, rect))
        .toList();
    final recordIds = (paint.paintedRecordIds as List).cast<String>();
    expect(recordIds.toSet().length, recordIds.length);
    expect((paint.scene.records as Map).keys, containsAll(recordIds));
    expect(labels, isNotEmpty,
        reason: 'An empty diagnostic list cannot establish readable type.');
    for (var i = 0; i < labels.length; i++) {
      final box = labels[i];
      expect(box.left, greaterThanOrEqualTo(-.5));
      expect(box.top, greaterThanOrEqualTo(31.5),
          reason: 'Actual canvas text must not slide under the fixed readout.');
      expect(box.right, lessThanOrEqualTo(size.width + .5));
      expect(box.bottom, lessThanOrEqualTo(size.height + .5));
      for (var j = i + 1; j < labels.length; j++) {
        expect(box.overlaps(labels[j]), isFalse,
            reason: 'Actual painted labels $i/$j overlap: $box / ${labels[j]}');
      }
    }
    if (fitShapes) {
      for (final prism in prisms(tester)) {
        if (prism.bounds.isEmpty) continue;
        final box = MatrixUtils.transformRect(transform, prism.bounds);
        expect(box.left, greaterThanOrEqualTo(-.5), reason: prism.id);
        expect(box.top, greaterThanOrEqualTo(-.5), reason: prism.id);
        expect(box.right, lessThanOrEqualTo(size.width + .5), reason: prism.id);
        expect(box.bottom, lessThanOrEqualTo(size.height + .5),
            reason: prism.id);
      }
    }
  }

  void expectVisibleText(WidgetTester tester, Finder control, String text) {
    final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: control, matching: find.text(text)));
    expect(paragraph.didExceedMaxLines, isFalse);
    final bounds = tester.getRect(control);
    final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: text.length));
    expect(boxes, isNotEmpty);
    for (final box in boxes) {
      final a = paragraph.localToGlobal(Offset(box.left, box.top));
      final b = paragraph.localToGlobal(Offset(box.right, box.bottom));
      expect(a.dx, greaterThanOrEqualTo(bounds.left - .5));
      expect(b.dx, lessThanOrEqualTo(bounds.right + .5));
      expect(a.dy, greaterThanOrEqualTo(bounds.top - .5));
      expect(b.dy, lessThanOrEqualTo(bounds.bottom + .5));
    }
  }

  testWidgets(
      'every selected country keeps its records, ring and original axis',
      (tester) async {
    addTearDown(tester.view.reset);
    final groups = groupsFor('en');
    await pumpWheel(tester, groups: groups);
    expect((painter(tester).scene.records as Map).keys.toSet(),
        visibleIds(groups));
    expect(
        (painter(tester).scene.rings as List).map((dynamic r) => r.id).toSet(),
        groups.map((g) => g.id).toSet());
    expect(find.byKey(const ValueKey('stackedWheelGroup')), findsNothing);
    expect(find.byKey(const ValueKey('stackedWheelFlat')), findsNothing);
    expect(find.byKey(const ValueKey('stackedWheelRecords')), findsNothing);
    for (final prism in prisms(tester)) {
      final record =
          (painter(tester).scene.records as Map)[prism.id] as YearDigestItem;
      expect(prism.startAngle,
          closeTo(angleForSpan(record.startYear, -4200, 2026), 1e-9));
      expect(prism.endAngle,
          closeTo(angleForSpan(record.endYear, -4200, 2026), 1e-9));
    }
    expectRealPaintClear(tester, fitShapes: true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('separation and rotation preserve all countries and their dates',
      (tester) async {
    addTearDown(tester.view.reset);
    await pumpWheel(tester);
    final before = {for (final prism in prisms(tester)) prism.id: prism};
    await chooseSpacing(tester, 'Compact');
    final after = {for (final prism in prisms(tester)) prism.id: prism};
    expect(after.keys.toSet(), before.keys.toSet());
    expect(before.values.any((p) => after[p.id]!.topHeight != p.topHeight),
        isTrue);
    for (final id in before.keys) {
      expect(after[id]!.innerRadius, before[id]!.innerRadius);
      expect(after[id]!.outerRadius, before[id]!.outerRadius);
      expect(after[id]!.startAngle, before[id]!.startAngle);
      expect(after[id]!.endAngle, before[id]!.endAngle);
    }
    final rotation = painter(tester).scene.rotation as double;
    await tester.tap(find.byKey(const ValueKey('stackedRotateRight')));
    await tester.pumpAndSettle();
    expect((painter(tester).scene.rotation as double) - rotation,
        closeTo(math.pi / 12, 1e-9));
    await tester.tap(find.byKey(const ValueKey('stackedRotateLeft')));
    await tester.pumpAndSettle();
    expect(painter(tester).scene.rotation, closeTo(rotation, 1e-9));
    expect((painter(tester).scene.records as Map).keys.toSet(),
        before.keys.toSet());
    expect(tester.takeException(), isNull);
  });

  testWidgets('drag orbits yaw and tilt; Pan moves the same complete wheel',
      (tester) async {
    addTearDown(tester.view.reset);
    final angles = <(double, double)>[];
    await pumpWheel(tester,
        initialLift: 10, onAnglesChanged: (a, b) => angles.add((a, b)));
    final all = (painter(tester).scene.records as Map).keys.toSet();
    final viewer = find.byType(InteractiveViewer);
    final initial = camera(tester);
    expect(tester.widget<InteractiveViewer>(viewer).panEnabled, isFalse);
    await tester.dragFrom(tester.getCenter(viewer), const Offset(60, 24));
    await tester.pumpAndSettle();
    expect(angles, isNotEmpty);
    // 2026-09-15: 「我用鼠标旋转wheel都反了」. This line used to read
    // `greaterThan(0)` — drag right, yaw up — which is the behaviour
    // that was reported. A positive yaw turns the wheel CLOCKWISE, and
    // clockwise carries the near edge (six o'clock, where the hand is)
    // to the LEFT, so the wheel ran away from the drag. See
    // `wheel_drag_follows_the_finger_test.dart`, which argues the sign
    // from the projection rather than from this widget.
    //
    // The BUTTONS keep the other sign and are still right: a button
    // says "turn it clockwise", a hand says "follow me".
    expect(angles.last.$1, lessThan(0),
        reason: 'dragging right must turn the wheel with the hand');
    // Vertical was always right and is unchanged: `tilt` is a squash
    // (1 = seen from above), so dragging down lays the wheel flatter,
    // which is what pulling the front of a turntable down does.
    expect(angles.last.$2, greaterThan(.70));
    expectCamera(camera(tester), initial);
    final yaw = painter(tester).scene.rotation;
    final tilt =
        (painter(tester).scene.projection as WheelStackProjection).squash;
    await tester.tap(find.byKey(const ValueKey('stackedWheelGestureMode')));
    await tester.pumpAndSettle();
    expect(tester.widget<InteractiveViewer>(viewer).panEnabled, isTrue);
    await tester.dragFrom(tester.getCenter(viewer), const Offset(32, -12));
    await tester.pumpAndSettle();
    expect(
        (camera(tester).normalizedGroundCentre - initial.normalizedGroundCentre)
            .distance,
        greaterThan(0));
    expect(painter(tester).scene.rotation, yaw);
    expect((painter(tester).scene.projection as WheelStackProjection).squash,
        tilt);
    final slider = find.byKey(const ValueKey('stackedWheelTilt'));
    await tester
        .tapAt(tester.getRect(slider).centerRight - const Offset(16, 0));
    await tester.pumpAndSettle();
    expect((painter(tester).scene.projection as WheelStackProjection).squash,
        greaterThan(tilt));
    expect((painter(tester).scene.records as Map).keys.toSet(), all);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'external camera survives projection changes; reset returns to fit',
      (tester) async {
    addTearDown(tester.view.reset);
    final controller = TransformationController();
    addTearDown(controller.dispose);
    const initial = ChronologyDepthCamera(
        normalizedGroundCentre: Offset(.15, -.12), zoom: 2.5);
    final updates = <ChronologyDepthCamera>[];
    await pumpWheel(tester,
        controller: controller,
        initialCamera: initial,
        initialYaw: .2,
        initialTilt: .55,
        initialLift: 10,
        onCameraChanged: updates.add);
    expect(identical(viewController(tester), controller), isTrue);
    expectCamera(camera(tester), initial);
    await tester.tap(find.byKey(const ValueKey('stackedRotateRight')));
    await tester.pumpAndSettle();
    expectCamera(camera(tester), initial);
    await tester.tap(find.byKey(const ValueKey('stackedZoomIn')));
    await tester.pumpAndSettle();
    expect(camera(tester).zoom, greaterThan(initial.zoom));
    await tester.tap(find.byKey(const ValueKey('stackedZoomOut')));
    await tester.pumpAndSettle();
    expectCamera(camera(tester), initial);
    await tester.tap(find.byKey(const ValueKey('stackedReset')));
    await tester.pumpAndSettle();
    expectCamera(camera(tester), const ChronologyDepthCamera());
    expect(painter(tester).scene.rotation, 0);
    expect(
        (painter(tester).scene.projection as WheelStackProjection).squash, .70);
    expect(updates, isNotEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.value = Matrix4.identity();
    expect(tester.takeException(), isNull,
        reason:
            'Disposing the chart must not dispose its parent-owned controller.');
  });

  testWidgets('a visible world prism opens its original record',
      (tester) async {
    addTearDown(tester.view.reset);
    final opened = <YearDigestItem>[];
    await pumpWheel(tester, onOpen: opened.add);
    final all = prisms(tester);
    final viewport = tester.getRect(find.byType(InteractiveViewer));
    Offset? target;
    String? id;
    for (final prism in all.reversed) {
      if (prism.sweep == 0) continue;
      final point = prism.projection.polar(
          prism.middleRadius, prism.middleAngle,
          height: prism.topHeight);
      if (!viewport.deflate(36).contains(toGlobal(tester, point))) continue;
      if (hitWheelStackPrism(all, point)?.id != prism.id) continue;
      if ((painter(tester).scene.callouts as List)
          .cast<WheelStackCallout>()
          .any((c) => c.bounds
              .inflate(4 / viewController(tester).value.getMaxScaleOnAxis())
              .contains(point))) {
        continue;
      }
      target = point;
      id = prism.id;
      break;
    }
    expect(target, isNotNull);
    await tester.tapAt(toGlobal(tester, target!));
    await tester.pump();
    expect(opened.single.id, id);
    expect(opened.single.startYear, powers[id]!.start);
    expect(opened.single.endYear, powers[id]!.endFor(2026));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an 8x point marker keeps a six-screen-pixel touch radius',
      (tester) async {
    addTearDown(tester.view.reset);
    final source = groupsFor('en').singleWhere((g) => g.id == 'china');
    final event =
        source.records.firstWhere((r) => r.kind == StripLaneKind.events);
    final opened = <YearDigestItem>[];
    await pumpWheel(tester,
        initialLift: 10,
        groups: [
          StackedChronologyGroup(
              id: source.id,
              name: source.name,
              color: source.color,
              records: [event])
        ],
        onOpen: opened.add);
    final prism = prisms(tester).single;
    expect(prism.sweep, 0);
    final point = prism.projection
        .polar(prism.middleRadius, prism.middleAngle, height: prism.topHeight);
    expect(point.dy, lessThan(0),
        reason: 'The fitted marker must remain tappable outside the original '
            'child hit box at expanded spacing.');
    final viewer = find.byType(InteractiveViewer);
    final viewport = tester.getSize(viewer);
    final centre = viewport.center(Offset.zero);
    final controller = viewController(tester);
    controller.value = Matrix4.identity()
      ..translateByDouble(centre.dx, centre.dy, 0, 1)
      ..scaleByDouble(8, 8, 1, 1)
      ..translateByDouble(-point.dx, -point.dy, 0, 1);
    await tester.pumpAndSettle();
    expect(controller.value.getMaxScaleOnAxis(), 8);
    final screen = MatrixUtils.transformPoint(controller.value, point);
    final near = screen + const Offset(5.5, 0);
    final far = screen + const Offset(12, 0);
    for (final position in [near, far]) {
      expect((Offset.zero & viewport).deflate(44).contains(position), isTrue);
      expect(
          (painter(tester).scene.callouts as List)
              .cast<WheelStackCallout>()
              .any((c) => c.bounds
                  .inflate(4 / 8)
                  .contains(controller.toScene(position))),
          isFalse);
    }
    final origin = tester.getTopLeft(viewer);
    await tester.tapAt(origin + far);
    await tester.pump();
    expect(opened, isEmpty);
    await tester.tapAt(origin + near);
    await tester.pump();
    expect(opened.single, same(event));
    expect(opened.single.startYear, events[event.id]!.year);
    expect(opened.single.endYear, events[event.id]!.year);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a painted side callout opens its original world record',
      (tester) async {
    addTearDown(tester.view.reset);
    final opened = <YearDigestItem>[];
    await pumpWheel(tester,
        locale: 'zh-Hant', startYear: 100, endYear: 1500, onOpen: opened.add);
    expectRealPaintClear(tester);
    final callouts =
        (painter(tester).scene.callouts as List).cast<WheelStackCallout>();
    expect(callouts, isNotEmpty);
    final target = callouts.first;
    final original =
        (painter(tester).scene.records as Map)[target.id] as YearDigestItem;
    final transform = viewController(tester).value.clone();
    await tester.tapAt(toGlobal(tester, target.bounds.center));
    await tester.pump();
    expect(opened.single, same(original));
    expect(viewController(tester).value, transform);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(360, 435), const Size(800, 304)]) {
    testWidgets('All names recovers every selected country at $size',
        (tester) async {
      addTearDown(tester.view.reset);
      final groups = groupsFor('zh-Hant');
      final opened = <YearDigestItem>[];
      await pumpWheel(tester,
          size: size, locale: 'zh-Hant', groups: groups, onOpen: opened.add);
      await tester.tap(find.byKey(const ValueKey('stackedWheelAllNames')));
      await tester.pumpAndSettle();
      final records = groups
          .expand((g) => g.records)
          .where((r) => r.endYear >= -4200 && r.startYear <= 2026)
          .toList()
        ..sort((a, b) => a.startYear.compareTo(b.startYear));
      final sheet = find.byType(BottomSheet);
      final list = find.descendant(of: sheet, matching: find.byType(ListView));
      expect(tester.widget<ListView>(list).childrenDelegate.estimatedChildCount,
          records.length + 1);
      final lastName = find.descendant(
          of: sheet, matching: find.text(label(records.last, 'zh-Hant')));
      await tester.scrollUntilVisible(lastName, 180,
          scrollable:
              find.descendant(of: sheet, matching: find.byType(Scrollable)));
      await tester.pumpAndSettle();
      final row = tester.getRect(lastName);
      final bounds = tester.getRect(list);
      expect(row.top, greaterThanOrEqualTo(bounds.top - .5));
      expect(row.bottom, lessThanOrEqualTo(bounds.bottom + .5));
      expect(lastName.hitTestable(), findsOneWidget);
      await tester.tap(lastName);
      await tester.pumpAndSettle();
      expect(opened.single, same(records.last));
      expect(sheet, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'selection reveals the record while range retains original angles',
      (tester) async {
    addTearDown(tester.view.reset);
    final groups = groupsFor('en');
    final selected = groups
        .singleWhere((g) => g.id == 'rome')
        .records
        .firstWhere((r) => r.startYear >= 100 && r.endYear <= 1500);
    await pumpWheel(tester, groups: groups);
    await pumpWheel(tester,
        groups: groups, selectedId: selected.id, startYear: 100, endYear: 1500);
    expect((painter(tester).scene.records as Map).keys.toSet(),
        visibleIds(groups, start: 100, end: 1500));
    expect(painter(tester).selectedId, selected.id);
    expect(painter(tester).scene.start, -4200);
    expect(painter(tester).scene.end, 2026);
    final prism = prisms(tester).singleWhere((p) => p.id == selected.id);
    expect(prism.startAngle,
        closeTo(angleForSpan(selected.startYear, -4200, 2026), 1e-9));
    final top = prism.projection
        .polar(prism.middleRadius, prism.middleAngle, height: prism.topHeight);
    expect(
        (toGlobal(tester, top) -
                tester.getCenter(find.byType(InteractiveViewer)))
            .distance,
        lessThan(.01));
    expect(camera(tester).zoom, greaterThanOrEqualTo(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('high zoom reveals the real raised top in the same period',
      (tester) async {
    addTearDown(tester.view.reset);
    final groups = groupsFor('en');
    await pumpWheel(tester,
        groups: groups,
        initialLift: 10,
        initialYaw: .55,
        initialCamera: const ChronologyDepthCamera(zoom: 80));
    final plan = painter(tester).plan as WheelStackPlan;
    final candidates = prisms(tester)
        .where((prism) => (plan.tierById[prism.id] ?? 0) >= 3)
        .toList()
      ..sort((a, b) => b.topHeight.compareTo(a.topHeight));
    expect(candidates, isNotEmpty);
    final target = candidates.first;
    final viewport = tester.getSize(find.byType(InteractiveViewer));
    final scale = viewController(tester).value.getMaxScaleOnAxis();
    expect(viewport.height / 2 - target.topHeight * scale, lessThan(32),
        reason:
            'Centring only the ground would put this actual top above the readout.');
    await pumpWheel(tester,
        groups: groups,
        initialLift: 10,
        selectedId: target.id,
        revealRevision: 1);
    final revealed =
        prisms(tester).singleWhere((prism) => prism.id == target.id);
    final top = revealed.projection.polar(
        revealed.middleRadius, revealed.middleAngle,
        height: revealed.topHeight);
    expect(
        (toGlobal(tester, top) -
                tester.getCenter(find.byType(InteractiveViewer)))
            .distance,
        lessThan(.01));
    expect(camera(tester).zoom, closeTo(80, 1e-6));
    expect(painter(tester).scene.start, -4200);
    expect(painter(tester).scene.end, 2026);
    expect((painter(tester).scene.records as Map).keys.toSet(),
        visibleIds(groups));
    expect(tester.takeException(), isNull);
  });

  testWidgets('All names reveals an offscreen record after parent selection',
      (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 600);
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    await settings.setFontFamily('Roboto');
    await tester.pump(const Duration(milliseconds: 650));
    final china = groupsFor('en').singleWhere((group) => group.id == 'china');
    final records = china.records
        .where((record) =>
            record.id == 'liao-khitan' || record.id == 'song-dynasty')
        .toList();
    expect(records.length, 2);
    final target = records.singleWhere((record) => record.id == 'song-dynasty');
    String? selected;
    await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => settings,
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'Roboto'),
          home: Scaffold(
              body: StatefulBuilder(
                  builder: (context, update) => StackedChronologyWheel(
                        groups: [
                          StackedChronologyGroup(
                              id: china.id,
                              name: china.name,
                              color: china.color,
                              records: records)
                        ],
                        locale: 'en',
                        label: (record) => label(record, 'en'),
                        onFlat: () {},
                        selectedId: selected,
                        initialCamera: const ChronologyDepthCamera(
                            normalizedGroundCentre: Offset(2, 2), zoom: 16),
                        onOpen: (record) => update(() => selected = record.id),
                      ))),
        )));
    await tester.pumpAndSettle();
    final before = prisms(tester).singleWhere((prism) => prism.id == target.id);
    final beforeTop = before.projection.polar(
        before.middleRadius, before.middleAngle,
        height: before.topHeight);
    expect(
        tester
            .getRect(find.byType(InteractiveViewer))
            .contains(toGlobal(tester, beforeTop)),
        isFalse);
    await tester.tap(find.byKey(const ValueKey('stackedWheelAllNames')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(label(target, 'en'))));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(selected, target.id);
    final after = prisms(tester).singleWhere((prism) => prism.id == target.id);
    final afterTop = after.projection
        .polar(after.middleRadius, after.middleAngle, height: after.topHeight);
    expect(
        (toGlobal(tester, afterTop) -
                tester.getCenter(find.byType(InteractiveViewer)))
            .distance,
        lessThan(.01));
    expect(camera(tester).zoom, closeTo(16, 1e-6));
    expect(tester.takeException(), isNull);
  });

  for (final chinaOnly in [false, true]) {
    testWidgets('real label cache is warm (China-only=$chinaOnly)',
        (tester) async {
      addTearDown(tester.view.reset);
      final groups = groupsFor('zh-Hant');
      WheelTextMetrics.resetStatsForTest();
      await pumpWheel(tester,
          locale: 'zh-Hant',
          startYear: 100,
          endYear: 1500,
          groups: chinaOnly
              ? groups.where((g) => g.id == 'china').toList()
              : groups);
      final cold = WheelTextMetrics.layoutsForTest;
      final count = (painter(tester).scene.records as Map).length;
      expect(cold, greaterThan(0));
      expect(cold, lessThanOrEqualTo(2 * (count + 5)),
          reason: 'Initial camera fit can require one additional font size.');
      WheelTextMetrics.zeroCounterForTest();
      expectRealPaintClear(tester);
      final warm = WheelTextMetrics.layoutsForTest;
      final names = (painter(tester).paintedRecordIds as List).length;
      expect(names, greaterThan(0),
          reason: 'Year ticks alone do not identify any records.');
      expect(warm, 0);
      WheelTextMetrics.zeroCounterForTest();
      await tester.tap(find.byKey(const ValueKey('stackedRotateRight')));
      await tester.pumpAndSettle();
      final rotation = WheelTextMetrics.layoutsForTest;
      expect(rotation, lessThanOrEqualTo(count + 5),
          reason:
              'Rotation may expose new names, but must reuse existing paragraphs.');
      WheelTextMetrics.zeroCounterForTest();
      await tester.tap(find.byKey(const ValueKey('stackedZoomIn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('stackedZoomIn')));
      await tester.pumpAndSettle();
      final zoom = WheelTextMetrics.layoutsForTest;
      expect(zoom, lessThanOrEqualTo(2 * (count + 5)));
      debugPrint('World wheel China-only=$chinaOnly: records=$count; '
          'cold=$cold; warm=$warm; rotation=$rotation; zoom=$zoom; painted names=$names');
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(360, 435), const Size(800, 304)]) {
    for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
      testWidgets('world names and controls stay clear at $size $locale',
          (tester) async {
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});
        final settings = AppSettings();
        await settings.setFontSize(kFontSizeMax);
        await settings.setMenuScale(kMenuScaleMax);
        await pumpWheel(tester, size: size, locale: locale, settings: settings);
        expectRealPaintClear(tester, fitShapes: true);
        final footer =
            tester.getRect(find.byKey(const ValueKey('stackedWheelFooter')));
        final viewport = tester.getRect(find.byType(InteractiveViewer));
        expect(footer.height, stackedWheelFooterHeight);
        expect(footer.overlaps(viewport), isFalse);
        final controls = <Rect>[];
        for (final key in [
          'stackedRotateLeft',
          'stackedRotateRight',
          'stackedWheelAllNames',
          'stackedZoomOut',
          'stackedReset',
          'stackedZoomIn'
        ]) {
          final box = tester.getRect(find.byKey(ValueKey(key)));
          expect(box.width, greaterThanOrEqualTo(44));
          expect(box.height, greaterThanOrEqualTo(44));
          expect(box.left, greaterThanOrEqualTo(0));
          expect(box.right, lessThanOrEqualTo(size.width));
          expect(box.top, greaterThanOrEqualTo(footer.top));
          expect(box.bottom, lessThanOrEqualTo(footer.bottom));
          for (final earlier in controls) {
            expect(box.overlaps(earlier), isFalse);
          }
          controls.add(box);
        }
        expectVisibleText(
            tester,
            find.byKey(const ValueKey('stackedWheelAllNames')),
            stackedWheelText('allNames', locale));
        expectVisibleText(
            tester,
            find.byKey(const ValueKey('stackedWheelGestureMode')),
            stackedWheelText('rotateMode', locale));
        await chooseSpacing(tester, 'Compact');
        expectRealPaintClear(tester, fitShapes: true);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
