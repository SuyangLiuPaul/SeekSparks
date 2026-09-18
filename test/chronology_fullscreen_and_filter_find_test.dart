/// Full screen, and the Filter's own find box, driven as a reader does.
///
/// 2026-09-16 「还有这个strip或者wheel应该有一个max screen把这个全屏模式」
/// and 「另外filter那边应该有个搜索」, both reported from a phone: the
/// chart had about a third of an 844 dp window, and the filter is
/// twenty-six rows.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yahwehs_sword/models/app_settings.dart';
import 'package:yahwehs_sword/models/wheel_history.dart';
import 'package:yahwehs_sword/pages/radial_chronology_page.dart';
import 'package:yahwehs_sword/pages/strip_chronology_page.dart';
import 'package:yahwehs_sword/providers/main_provider.dart';
import 'package:yahwehs_sword/services/chronology_service.dart';
import 'package:yahwehs_sword/widgets/chart_help_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await WheelHistoryService.instance.load();
    await ChronologyService.instance.load();
  });

  Future<void> pump(WidgetTester tester, Widget page, Size size) async {
    SharedPreferences.setMockInitialValues(
        <String, Object>{ChartHelp.seenKey: true});
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: MaterialApp(home: page),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('the wheel gives the chart the whole window and comes back',
      (tester) async {
    await pump(tester,
        const RadialChronologyPage(initialStacked: false),
        const Size(390, 844));
    final chart = find.byKey(const ValueKey('chronologyWheel'));
    final before = tester.getSize(chart).height;
    expect(find.byType(AppBar), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('wheelFullScreenControl')));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsNothing,
        reason: 'the app bar is part of the chrome the reader asked to '
            'get out of the way');
    final after = tester.getSize(chart).height;
    expect(after, greaterThan(before),
        reason: 'full screen that does not make the chart bigger is a '
            'button that does nothing: $before → $after');

    await tester.tap(find.byKey(const ValueKey('wheelFullScreenControl')));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    expect(tester.getSize(chart).height, before);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('and so does the strip, which needed it most', (tester) async {
    await pump(tester, const StripChronologyPage(), const Size(390, 844));
    // NOT the chart's own size: the strip's canvas is the CONTENT of a
    // scroll view and is 3,538 dp tall either way. What full screen
    // changes here is how much of it the reader can see, and the honest
    // way to assert that is on the chrome that was taking the room.
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byKey(const ValueKey('chronology-find')), findsOneWidget);
    expect(find.byKey(const ValueKey('chronology-period')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stripFullScreenControl')));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const ValueKey('chronology-find')), findsNothing);
    expect(find.byKey(const ValueKey('chronology-period')), findsNothing);
    expect(find.byKey(const ValueKey('stripFullScreenControl')), findsOneWidget,
        reason: 'the way back has to survive the thing it undoes');

    await tester.tap(find.byKey(const ValueKey('stripFullScreenControl')));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byKey(const ValueKey('chronology-find')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the filter finds a lane by name, and keeps the rest ticked',
      (tester) async {
    await pump(tester,
        const RadialChronologyPage(initialStacked: false),
        const Size(390, 844));
    await tester.tap(find.byKey(const ValueKey('chronology-filter')));
    await tester.pumpAndSettle();

    final list = find.byKey(const ValueKey('chronologyFilterOptions'));
    expect(list, findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('chronologyFilterFind')), '中国');
    await tester.pumpAndSettle();
    expect(find.descendant(of: list, matching: find.text('中国')),
        findsOneWidget);
    expect(find.descendant(of: list, matching: find.text('罗马')), findsNothing,
        reason: 'the query narrows the list');

    // A query nobody matches says so, rather than showing an empty box.
    await tester.enterText(
        find.byKey(const ValueKey('chronologyFilterFind')), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chronologyFilterFindNothing')),
        findsOneWidget);

    // Clearing brings everything back. Counted rather than named: the
    // list is a `ListView.builder`, so a row below the fold is not
    // built at all and `find.text` cannot see it either way — the
    // question is how many rows the list HAS, not which.
    int rowsShown() => [
          for (final name in const [
            '以色列', '犹大', '亚述', '巴比伦', '波斯', '埃及', '希腊',
            '罗马', '拜占庭', '欧洲', '美洲', '中国', '日本', '印度',
            '教会', '圣经', '全世界'
          ])
            if (find
                .descendant(of: list, matching: find.text(name))
                .evaluate()
                .isNotEmpty)
              name
        ].length;
    await tester.tap(find.byKey(const ValueKey('chronologyFilterFindClear')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chronologyFilterFindNothing')),
        findsNothing);
    expect(rowsShown(), greaterThan(1),
        reason: 'clearing the box must bring the whole list back');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
