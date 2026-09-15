/// The filter is a transaction: the live chart receives exactly one
/// result on Apply and none on every dismissal path. Use the real
/// corpus and strings so preserving the old options is checked too.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/chronology_filter_strings.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart' show wheelStrings;
import 'package:seeksparks/utils/wheel_search.dart'
    show kLifespanLayerId, kReignLayerId, kMinistryLayerId, kLineageLayerId;
import 'package:seeksparks/widgets/chronology_filter_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WheelHistoryData data;

  setUpAll(() async {
    data = await WheelHistoryService.instance.load();
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

  String text(String key, String fallback, String locale) =>
      wheelStrings[key]?[locale] ?? wheelStrings[key]?['en'] ?? fallback;

  Future<void> pumpHost(
    WidgetTester tester, {
    required Set<String> hidden,
    required ValueChanged<Set<String>> onApply,
    Size size = const Size(900, 900),
    String locale = 'en',
    String keyPrefix = 'wheelFilter',
    AppSettings? settings,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => settings ?? AppSettings(),
      child: MaterialApp(
        theme: ThemeData(
          fontFamily: 'Roboto',
          fontFamilyFallback: const ['NotoSansSC'],
        ),
        home: Builder(builder: (context) {
          return Scaffold(
            body: Center(
              child: OutlinedButton(
                key: const ValueKey('openFilter'),
                onPressed: () async {
                  final result = await showChronologyFilterSheet(
                    context: context,
                    locale: locale,
                    data: data,
                    hidden: hidden,
                    streamColors: const {},
                    layerColors: const {},
                    text: (key, fallback) => text(key, fallback, locale),
                    keyPrefix: keyPrefix,
                  );
                  if (result != null) onApply(result);
                },
                child: const Text('Open filter'),
              ),
            ),
          );
        }),
      ),
    ));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('openFilter')));
    await tester.pumpAndSettle();
  }

  Future<void> reopen(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('openFilter')));
    await tester.pumpAndSettle();
  }

  test('new decision text exists in all supported locales', () {
    for (final entry in chronologyFilterStrings.entries) {
      expect(entry.value.keys, containsAll(['en', 'zh-Hans', 'zh-Hant']),
          reason: entry.key);
      expect(entry.value.values.every((value) => value.isNotEmpty), isTrue);
    }
  });

  testWidgets('draft edits never mutate the chart; Apply returns once',
      (tester) async {
    addTearDown(tester.view.reset);
    final hidden = {data.streams.first.id};
    final original = Set<String>.of(hidden);
    var applications = 0;
    Set<String>? applied;
    await pumpHost(tester, hidden: hidden, onApply: (result) {
      applications++;
      applied = result;
      hidden
        ..clear()
        ..addAll(result);
    });
    await tester.tap(find.byKey(const ValueKey('wheelFilterLifespans')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('wheelFilterMinistries')));
    await tester.pump();
    expect(hidden, original);
    expect(applications, 0);
    expect(
        tester
            .widget<CheckboxListTile>(
                find.byKey(const ValueKey('wheelFilterLifespans')))
            .value,
        isFalse);

    final apply = tester
        .widget<FilledButton>(
            find.byKey(const ValueKey('chronologyFilterApply')))
        .onPressed!;
    apply();
    apply();
    await tester.pumpAndSettle();
    expect(applications, 1);
    expect(hidden, {...original, kLifespanLayerId, kMinistryLayerId});
    expect(() => applied!.clear(), throwsUnsupportedError);
    expect(find.byKey(const ValueKey('openFilter')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final dismissal in ['cancel', 'barrier', 'back']) {
    testWidgets('$dismissal discards every draft change and reopens unchanged',
        (tester) async {
      addTearDown(tester.view.reset);
      final hidden = {data.streams.first.id};
      final original = Set<String>.of(hidden);
      var applications = 0;
      await pumpHost(tester, hidden: hidden, onApply: (_) => applications++);
      await tester.tap(find.byKey(const ValueKey('chronologyFilterNone')));
      await tester.pump();
      expect(hidden, original);
      expect(
          tester
              .widget<CheckboxListTile>(
                  find.byKey(const ValueKey('wheelFilterLifespans')))
              .value,
          isFalse);
      switch (dismissal) {
        case 'cancel':
          await tester
              .tap(find.byKey(const ValueKey('chronologyFilterCancel')));
        case 'barrier':
          await tester.tapAt(const Offset(5, 5));
        case 'back':
          await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(applications, 0);
      expect(hidden, original);
      await reopen(tester);
      expect(
          tester
              .widget<CheckboxListTile>(
                  find.byKey(const ValueKey('wheelFilterLifespans')))
              .value,
          isTrue);
      await tester.tap(find.byKey(const ValueKey('chronologyFilterCancel')));
      await tester.pumpAndSettle();
      expect(applications, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('None and All preserve every stream and special layer',
      (tester) async {
    addTearDown(tester.view.reset);
    final hidden = <String>{};
    var applications = 0;
    await pumpHost(tester, hidden: hidden, keyPrefix: 'stripFilter',
        onApply: (result) {
      applications++;
      hidden
        ..clear()
        ..addAll(result);
    });
    final list = tester.widget<ListView>(
        find.byKey(const ValueKey('chronologyFilterOptions')));
    // Four non-stream layers and the All/None shortcut row accompany
    // the complete stream list; no option is lost during extraction.
    expect(list.childrenDelegate.estimatedChildCount, data.streams.length + 5);
    expect(find.byKey(const ValueKey('stripFilterLifespans')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chronologyFilterNone')));
    await tester.pump();
    expect(hidden, isEmpty);
    await tester.tap(find.byKey(const ValueKey('chronologyFilterApply')));
    await tester.pumpAndSettle();
    expect(hidden, {
      ...data.streams.map((stream) => stream.id),
      kLifespanLayerId,
      kReignLayerId,
      kMinistryLayerId,
      kLineageLayerId,
    });
    expect(applications, 1);
    await reopen(tester);
    await tester.tap(find.byKey(const ValueKey('chronologyFilterAll')));
    await tester.pump();
    expect(hidden, isNotEmpty);
    await tester.tap(find.byKey(const ValueKey('chronologyFilterApply')));
    await tester.pumpAndSettle();
    expect(hidden, isEmpty);
    expect(applications, 2);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(360, 640), const Size(800, 360)]) {
    for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
      testWidgets('decision stays visible while options scroll $size $locale',
          (tester) async {
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});
        final settings = AppSettings();
        await settings.setFontSize(kFontSizeMax);
        await settings.setMenuScale(kMenuScaleMax);
        await tester.pump(const Duration(milliseconds: 650));
        var applications = 0;
        await pumpHost(tester,
            hidden: {},
            onApply: (_) => applications++,
            size: size,
            locale: locale,
            settings: settings);
        final apply = find.byKey(const ValueKey('chronologyFilterApply'));
        final cancel = find.byKey(const ValueKey('chronologyFilterCancel'));
        final before = tester.getRect(apply);
        expect(before.height, greaterThanOrEqualTo(48));
        expect(before.bottom, lessThanOrEqualTo(size.height));
        expect(before.top, greaterThanOrEqualTo(0));
        expect(before.overlaps(tester.getRect(cancel)), isFalse);
        for (final (control, key) in [(apply, 'apply'), (cancel, 'cancel')]) {
          final label = chronologyFilterText(key, locale);
          final labelFinder =
              find.descendant(of: control, matching: find.text(label));
          final paragraph = tester.renderObject<RenderParagraph>(labelFinder);
          final rect = tester.getRect(control);
          expect(paragraph.didExceedMaxLines, isFalse);
          for (final box in paragraph.getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: label.length))) {
            final start = paragraph.localToGlobal(Offset(box.left, box.top));
            final end = paragraph.localToGlobal(Offset(box.right, box.bottom));
            expect(start.dx, greaterThanOrEqualTo(rect.left - .5));
            expect(start.dy, greaterThanOrEqualTo(rect.top - .5));
            expect(end.dx, lessThanOrEqualTo(rect.right + .5));
            expect(end.dy, lessThanOrEqualTo(rect.bottom + .5));
          }
        }
        final last = data.streams.last;
        final lastOption = find.byKey(ValueKey('wheelFilterStream-${last.id}'));
        await tester.scrollUntilVisible(lastOption, 240,
            scrollable: find.descendant(
              of: find.byKey(const ValueKey('chronologyFilterOptions')),
              matching: find.byType(Scrollable),
            ));
        await tester.pump();
        expect(find.text(last.nameFor(locale)), findsOneWidget);
        expect(tester.getRect(apply), before);
        expect(
            tester
                .getRect(find.byKey(const ValueKey('chronologyFilterOptions')))
                .bottom,
            lessThanOrEqualTo(before.top));
        await tester.tap(apply);
        await tester.pumpAndSettle();
        expect(applications, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
