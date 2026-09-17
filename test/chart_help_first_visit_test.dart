/// The two charts say how to use them, once, on the way in.
///
/// 2026-09-17 「可不可以有类似于popup windows 第一次打开的话 教人们怎么使用
/// strip和wheel 也可以有个icon ... 在不同devices上怎么用」.
///
/// Everything these pages can do is invisible until it is done: the
/// pointer names a record, a tap opens it, two fingers get closer, and
/// the list beside the chart is the index. A reader who does not know
/// that is looking at coloured bands.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart';
import 'package:seeksparks/pages/strip_chronology_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/chronology_service.dart';
import 'package:seeksparks/widgets/chart_help_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await WheelHistoryService.instance.load();
    await ChronologyService.instance.load();
  });

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MainProvider()),
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child: MaterialApp(home: page),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a first visit is met with the card', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await pumpPage(tester, const RadialChronologyPage(initialStacked: false));
    expect(find.byKey(const ValueKey('chartHelpBody')), findsOneWidget,
        reason: 'the first reader of this chart was told nothing about how '
            'to use it');
    expect(await ChartHelp.hasSeen(), isTrue,
        reason: 'shown and not remembered is worse than not shown: it '
            'would meet them again every visit');
    await tester.tap(find.byKey(const ValueKey('chartHelpDone')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chartHelpBody')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('and never again on its own', (tester) async {
    SharedPreferences.setMockInitialValues(
        <String, Object>{ChartHelp.seenKey: true});
    await pumpPage(tester, const RadialChronologyPage(initialStacked: false));
    expect(find.byKey(const ValueKey('chartHelpBody')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the strip shares the flag, not a second card',
      (tester) async {
    // A reader who lands on the strip first is taught there; one who
    // has already been taught on the wheel is not taught twice. The
    // card describes both charts, so the second showing would carry no
    // new information at all.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await pumpPage(tester, const StripChronologyPage());
    expect(find.byKey(const ValueKey('chartHelpBody')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chartHelpDone')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());

    await pumpPage(tester, const RadialChronologyPage(initialStacked: false));
    expect(find.byKey(const ValueKey('chartHelpBody')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the question mark opens it again', (tester) async {
    SharedPreferences.setMockInitialValues(
        <String, Object>{ChartHelp.seenKey: true});
    await pumpPage(tester, const RadialChronologyPage(initialStacked: false));
    expect(find.byKey(const ValueKey('chartHelpButton')), findsOneWidget,
        reason: 'a card shown once and unreachable afterwards is a card '
            'most readers will never see again');
    await tester.tap(find.byKey(const ValueKey('chartHelpButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chartHelpBody')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chartHelpDone')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('it speaks all three of this app\'s languages', () {
    for (final entry in chartHelpStrings.entries) {
      for (final locale in ['zh-Hans', 'zh-Hant', 'en']) {
        final text = entry.value[locale];
        expect(text, isNotNull,
            reason: '${entry.key} has nothing to say in $locale');
        expect(text!.trim(), isNotEmpty);
      }
    }
  });

  test('it names every gesture a reader has to guess at', () {
    // The four invisible affordances, in the copy, in every locale: the
    // pointer that names, the tap that opens, the pinch that gets
    // closer, and the list that indexes. A rewrite that drops one of
    // them leaves the reader with the same question they arrived with.
    for (final locale in ['zh-Hans', 'zh-Hant', 'en']) {
      final all = chartHelpStrings.values
          .map((m) => m[locale] ?? '')
          .join(' ')
          .toLowerCase();
      for (final probe in switch (locale) {
        'en' => ['pinch', 'tap', 'pointer', 'search'],
        'zh-Hant' => ['捏合', '點', '指', '搜'],
        _ => ['捏合', '点', '指', '搜'],
      }) {
        expect(all.contains(probe), isTrue,
            reason: 'the $locale card never mentions "$probe"');
      }
    }
  });
}
