/// The chart's labels are lossy at overview scale, so the explorer must
/// keep a readable route to the same real records. These checks exercise
/// the shared filtering and the actual layout budget used by both pages;
/// screenshots of the built pages still decide whether the chart reads.
library;

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/chronology_explorer_strings.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/utils/chronology_explorer.dart';
import 'package:seeksparks/utils/date_hedge.dart';
import 'package:seeksparks/utils/version_mapper.dart'
    show localizedReferenceLabel;
import 'package:seeksparks/widgets/chronology_explorer.dart';

class _CountedEvents extends ListBase<WheelHistoryEvent> {
  _CountedEvents(this.source);

  final List<WheelHistoryEvent> source;
  int reads = 0;

  @override
  int get length => source.length;

  @override
  set length(int value) => source.length = value;

  @override
  WheelHistoryEvent operator [](int index) {
    reads++;
    return source[index];
  }

  @override
  void operator []=(int index, WheelHistoryEvent value) =>
      source[index] = value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WheelHistoryData corpus;

  setUpAll(() async {
    corpus = await WheelHistoryService.instance.load();
    // Ahem gives every Latin character a square advance. The real
    // bundled fonts make this a check of the shipped label widths,
    // rather than of a test font no reader can select in the app.
    for (final family in ['Roboto', '-apple-system']) {
      await (FontLoader(family)
            ..addFont(rootBundle
                .load('assets/fonts/Roboto-VariableFont_wdth,wght.ttf')))
          .load();
    }
    await (FontLoader('NotoSansSC')
          ..addFont(rootBundle.load('assets/fonts/NotoSansSC-Sub.otf')))
        .load();
  });

  WheelHistoryData withEvents(List<WheelHistoryEvent> events) =>
      WheelHistoryData(
        streams: corpus.streams,
        nations: corpus.nations,
        powers: corpus.powers,
        ministries: corpus.ministries,
        omissions: corpus.omissions,
        events: events,
        meta: corpus.meta,
      );

  test('periods cover the existing axis without inventing named eras', () {
    expect(chronologyPeriods.first.start, -4200);
    expect(chronologyPeriods.first.end, 2026);
    final windows = chronologyPeriods.skip(1).toList();
    expect(windows.first.start, chronologyPeriods.first.start);
    expect(windows.last.end, chronologyPeriods.first.end);
    for (var i = 1; i < windows.length; i++) {
      expect(windows[i - 1].end, windows[i].start);
      expect(windows[i - 1].contains(windows[i].start), isTrue);
      expect(windows[i].contains(windows[i].start), isTrue);
    }
  });

  test('visible plus hidden accounts for every event in a window', () {
    final sorted = sortedChronologyEvents(corpus.events.reversed);
    for (var i = 1; i < sorted.length; i++) {
      expect(sorted[i].year, greaterThanOrEqualTo(sorted[i - 1].year));
      if (sorted[i].year == sorted[i - 1].year) {
        expect(
            sorted[i].id.compareTo(sorted[i - 1].id), greaterThanOrEqualTo(0));
      }
    }
    final hidden = {corpus.streams.first.id};
    for (final period in chronologyPeriods) {
      final selection = selectChronologyEvents(
          sortedEvents: sorted, period: period, hiddenStreams: hidden);
      expect(selection.events.length + selection.hiddenInPeriod,
          selection.totalInPeriod);
      expect(selection.totalInPeriod,
          corpus.events.where((event) => period.contains(event.year)).length);
      expect(selection.events.every((event) => !hidden.contains(event.stream)),
          isTrue);
      expect(selection.events.every((event) => period.contains(event.year)),
          isTrue);
    }
    expect(() => sorted.clear(), throwsUnsupportedError);
  });

  test('every explorer label is supplied in all three locales', () {
    for (final entry in chronologyExplorerStrings.entries) {
      expect(entry.value.keys, containsAll(['en', 'zh-Hans', 'zh-Hant']),
          reason: entry.key);
    }
    final approximate = corpus.events.firstWhere((event) => event.approximate);
    for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
      expect(chronologyEventDate(approximate, locale),
          startsWith(approximatePrefix(locale)));
    }
    expect(chronologyYearLabel(100, 'zh-Hant'), '主後100');
    expect(chronologyExplorerText('traditional', 'en'),
        contains('Not established history'));
  });

  Future<void> pumpExplorer(
    WidgetTester tester, {
    required Size size,
    required WheelHistoryData data,
    Set<String>? hidden,
    String locale = 'en',
    String? selectedId,
    ChronologyExplorerController? controller,
    Widget? chart,
    void Function(int, int)? onRange,
    VoidCallback? onFind,
    VoidCallback? onFilter,
    ValueChanged<WheelHistoryEvent>? onEvent,
    AppSettings? settings,
    bool withAppBar = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => settings ?? AppSettings(),
        child: MaterialApp(
          theme: ThemeData(
            fontFamily: 'Roboto',
            fontFamilyFallback: const ['NotoSansSC'],
          ),
          home: Scaffold(
            appBar: withAppBar ? AppBar(title: const Text('History')) : null,
            body: ChronologyExplorer(
              chart: chart ??
                  const ColoredBox(key: ValueKey('chart'), color: Colors.white),
              data: data,
              locale: locale,
              hiddenStreams: hidden ?? const {},
              streamColors: const {},
              selectedId: selectedId,
              controller: controller,
              onEvent: onEvent ?? (_) {},
              onRange: onRange ?? (_, __) {},
              onFind: onFind ?? () {},
              onFilter: onFilter ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final size in [
    const Size(360, 744),
    const Size(1200, 800),
    const Size(800, 320)
  ]) {
    testWidgets('chart uses the shared available rectangle at $size',
        (tester) async {
      addTearDown(tester.view.reset);
      await pumpExplorer(tester, size: size, data: corpus);
      final chart = tester.getRect(find.byKey(const ValueKey('chart')));
      expect(chart.size, chronologyExplorerChartSize(size));
      expect(chart.height, greaterThan(0));
      expect(chart.bottom, lessThanOrEqualTo(size.height));
      expect(find.byKey(const ValueKey('chronology-find')), findsOneWidget);
      expect(find.byKey(const ValueKey('chronology-filter')), findsOneWidget);
      if (chronologyExplorerUsesCompactList(size)) {
        await tester.tap(find.byKey(const ValueKey('chronology-open-events')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('chronology-event-list')),
            findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('first fit runs once; rebuilds do not reread or sort the corpus',
      (tester) async {
    addTearDown(tester.view.reset);
    final counted = _CountedEvents(corpus.events.toList());
    final data = withEvents(counted);
    var ranges = 0;
    void range(int start, int end) {
      ranges++;
      expect(start, chronologyPeriods.first.start);
      expect(end, chronologyPeriods.first.end);
    }

    await pumpExplorer(tester,
        size: const Size(1200, 800), data: data, onRange: range);
    expect(ranges, 1);
    expect(counted.reads, greaterThan(0));
    counted.reads = 0;
    await pumpExplorer(tester,
        size: const Size(1200, 800),
        data: data,
        onRange: range,
        chart: const SizedBox.expand());
    expect(ranges, 1);
    expect(counted.reads, 0);
  });

  testWidgets('in-place layer changes update counts; search stays available',
      (tester) async {
    addTearDown(tester.view.reset);
    final event = corpus.events.first;
    final data = withEvents([event]);
    final hidden = <String>{};
    var finds = 0;
    await pumpExplorer(tester,
        size: const Size(360, 744),
        data: data,
        hidden: hidden,
        onFind: () => finds++);
    expect(find.text('1 event'), findsOneWidget);
    hidden.add(event.stream);
    await pumpExplorer(tester,
        size: const Size(360, 744),
        data: data,
        hidden: hidden,
        onFind: () => finds++);
    expect(find.text('0 events'), findsOneWidget);
    expect(find.text('1 more in this range hidden by layers'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chronology-find')));
    expect(finds, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('event rows keep approximation, basis, references and action',
      (tester) async {
    addTearDown(tester.view.reset);
    final event = corpus.events
        .firstWhere((event) => event.approximate && event.refs.isNotEmpty);
    WheelHistoryEvent? chosen;
    var ranges = 0;
    await pumpExplorer(tester,
        size: const Size(1200, 800),
        data: withEvents([event]),
        selectedId: event.id,
        onEvent: (event) => chosen = event,
        onRange: (_, __) => ranges++);
    expect(ranges, 0);
    expect(find.text(chronologyEventDate(event, 'en')), findsOneWidget);
    expect(
        find.text(chronologyExplorerText(event.basis, 'en')), findsOneWidget);
    expect(find.textContaining(localizedReferenceLabel(event.refs.first, 'en')),
        findsOneWidget);
    await tester.tap(find.byKey(ValueKey('chronology-event-${event.id}')));
    expect(chosen, same(event));
    expect(tester.takeException(), isNull);
  });

  testWidgets('fit control restores all years in the list and dropdown',
      (tester) async {
    addTearDown(tester.view.reset);
    final controller = ChronologyExplorerController();
    addTearDown(controller.dispose);
    final ranges = <(int, int)>[];
    await pumpExplorer(tester,
        size: const Size(1200, 800),
        data: corpus,
        controller: controller,
        onRange: (start, end) => ranges.add((start, end)));
    controller.selectPeriod(chronologyPeriods.last);
    await tester.pump();
    expect(ranges.last, (1500, 2026));
    expect(find.text('1500 — Present'), findsOneWidget);
    final recent = selectChronologyEvents(
        sortedEvents: sortedChronologyEvents(corpus.events),
        period: chronologyPeriods.last,
        hiddenStreams: const {});
    expect(find.text(chronologyExplorerEventCount(recent.events.length, 'en')),
        findsOneWidget);
    controller.showAll();
    await tester.pump();
    expect(ranges.last, (-4200, 2026));
    expect(find.text('All years'), findsOneWidget);
    controller.showAll();
    expect(ranges.length, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chinese event rows localize scripture references',
      (tester) async {
    addTearDown(tester.view.reset);
    final event = corpus.events.firstWhere((event) => event.refs.isNotEmpty);
    await pumpExplorer(tester,
        size: const Size(1200, 800),
        data: withEvents([event]),
        locale: 'zh-Hant');
    expect(find.text(event.titleFor('zh-Hant')), findsOneWidget);
    expect(
        find.textContaining(
            localizedReferenceLabel(event.refs.first, 'zh-Hant')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  void expectVisibleLabel(WidgetTester tester, String label, Finder control) {
    final text = find.descendant(of: control, matching: find.text(label));
    expect(text, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(text);
    final controlRect = tester.getRect(control);
    expect(paragraph.didExceedMaxLines, isFalse, reason: label);
    final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: label.length));
    expect(boxes, isNotEmpty, reason: label);
    // A Text can report its full natural width while an ancestor clips
    // every glyph. Measure the actual glyph boxes against the clickable
    // control, including both lines if a label wraps.
    for (final box in boxes) {
      final topLeft = paragraph.localToGlobal(Offset(box.left, box.top));
      final bottomRight =
          paragraph.localToGlobal(Offset(box.right, box.bottom));
      expect(topLeft.dx, greaterThanOrEqualTo(controlRect.left - .5),
          reason: label);
      expect(bottomRight.dx, lessThanOrEqualTo(controlRect.right + .5),
          reason: label);
      expect(topLeft.dy, greaterThanOrEqualTo(controlRect.top - .5),
          reason: label);
      expect(bottomRight.dy, lessThanOrEqualTo(controlRect.bottom + .5),
          reason: label);
    }
  }

  for (final size in [
    const Size(360, 800),
    const Size(360, 640),
    const Size(800, 360)
  ]) {
    for (final locale in ['en', 'zh-Hant']) {
      testWidgets(
          'largest reader/menu sizes retain visible controls $size $locale',
          (tester) async {
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});
        final settings = AppSettings();
        await settings.setFontSize(kFontSizeMax);
        await settings.setMenuScale(kMenuScaleMax);
        // The real settings object saves changes after 600 ms. Drain
        // that write before any assertion can end the test early.
        await tester.pump(const Duration(milliseconds: 650));
        final controller = ChronologyExplorerController()
          ..selectPeriod(chronologyPeriods[1]);
        addTearDown(controller.dispose);
        var finds = 0;
        var filters = 0;
        await pumpExplorer(tester,
            size: size,
            data: corpus,
            locale: locale,
            settings: settings,
            controller: controller,
            withAppBar: true,
            hidden: {corpus.streams.first.id},
            onFind: () => finds++,
            onFilter: () => filters++);
        final findButton = find.byKey(const ValueKey('chronology-find'));
        final filterButton = find.byKey(const ValueKey('chronology-filter'));
        final period = find.byKey(const ValueKey('chronology-period'));
        expectVisibleLabel(
            tester, chronologyExplorerText('find', locale), findButton);
        expectVisibleLabel(
            tester, chronologyExplorerText('early', locale), period);
        for (final control in [findButton, filterButton]) {
          expect(tester.getSize(control).height, greaterThanOrEqualTo(44));
          expect(tester.getSize(control).width, greaterThanOrEqualTo(44));
        }
        expect(tester.getRect(findButton).right,
            lessThanOrEqualTo(tester.getRect(filterButton).left));
        final chart = tester.getRect(find.byKey(const ValueKey('chart')));
        final available = Size(size.width, size.height - kToolbarHeight);
        expect(chart.size, chronologyExplorerChartSize(available));
        expect(chart.height, greaterThan(0));
        await tester.tap(findButton);
        await tester.tap(filterButton);
        expect(finds, 1);
        expect(filters, 1);
        if (chronologyExplorerUsesCompactList(available)) {
          await tester
              .tap(find.byKey(const ValueKey('chronology-open-events')));
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('chronology-event-list')),
              findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('controller period set before attaching survives first fit',
      (tester) async {
    addTearDown(tester.view.reset);
    final controller = ChronologyExplorerController()
      ..selectPeriod(chronologyPeriods.last);
    addTearDown(controller.dispose);
    final ranges = <(int, int)>[];
    await pumpExplorer(tester,
        size: const Size(360, 800),
        data: corpus,
        controller: controller,
        onRange: (start, end) => ranges.add((start, end)));
    expect(ranges, [(1500, 2026)]);
    expect(find.text('1500 — Present'), findsOneWidget);
    expect(controller.period, same(chronologyPeriods.last));
    final expected = selectChronologyEvents(
        sortedEvents: sortedChronologyEvents(corpus.events),
        period: chronologyPeriods.last,
        hiddenStreams: const {});
    expect(
        find.text(chronologyExplorerEventCount(expected.events.length, 'en')),
        findsOneWidget);
  });
}
