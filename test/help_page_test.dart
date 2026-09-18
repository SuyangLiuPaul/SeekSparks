/// The Help page, mounted — 2026-09-18.
///
/// `help_catalog_test.dart` pins the words and the search. This pins the
/// page: that it reaches the screen, that a search shows the answer
/// open rather than a list of titles, that keys follow the platform
/// chosen, and the ordering bug a browser found on the first day —
/// "Take me there" for a workbench action pushed its dialog ABOVE the
/// Help page, because the page closed itself with `maybePop`, which
/// waits a turn before popping.
///
/// Asserted in Chinese: `AppSettings` defaults to zh-Hans, and it is the
/// locale a default reader sees.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yahwehs_sword/models/app_settings.dart';
import 'package:yahwehs_sword/pages/help_page.dart';
import 'package:yahwehs_sword/utils/help_catalog.dart';

class _Log extends NavigatorObserver {
  _Log(this.events);
  final List<String> events;
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      events.add('pop');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => helpDestinationHandler = null);

  Future<List<String>> pumpHelp(WidgetTester t, {String? query}) async {
    t.view.physicalSize = const Size(1400, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final events = <String>[];
    await t.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppSettings(),
      child: MaterialApp(
        navigatorObservers: [_Log(events)],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => HelpPage(initialQuery: query))),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    return events;
  }

  testWidgets('every section is on the page', (t) async {
    await pumpHelp(t);
    for (final s in HelpSection.values) {
      expect(find.text(kHelpSectionNames[s]!.hans), findsWidgets,
          reason: s.name);
    }
  });

  testWidgets('a search opens its answers rather than listing titles',
      (t) async {
    await pumpHelp(t, query: '投影');
    expect(find.text('投影'), findsWidgets);
    // The body of the projection topic, not only its title.
    expect(find.textContaining('B 黑屏', findRichText: true), findsWidgets);
    // Where it lives, in the menu's own words.
    expect(find.textContaining('资源 › 投影', findRichText: true), findsOneWidget);
  });

  testWidgets('a key name finds the key and the feature', (t) async {
    await pumpHelp(t, query: 'F4');
    expect(find.text('经文研读报告'), findsOneWidget);
    expect(find.text('F4'), findsWidgets);
    expect(find.text('生成本章研读报告'), findsOneWidget);
  });

  testWidgets('no Take-me-there without somewhere to go', (t) async {
    await pumpHelp(t, query: 'F4');
    expect(find.text('带我去'), findsNothing);
  });

  testWidgets('a workbench action closes Help BEFORE it acts', (t) async {
    final calls = <HelpDestination>[];
    final events = await pumpHelp(t, query: 'F4');
    helpDestinationHandler = (d) {
      calls.add(d);
      events.add('act');
    };
    // The handler is read at build time; rebuild to show the button.
    await t.enterText(find.byType(TextField), 'F4 ');
    await t.pumpAndSettle();
    await t.tap(find.text('带我去').first);
    await t.pumpAndSettle();
    expect(calls, [HelpDestination.passageReport]);
    expect(events, ['pop', 'act']);
    expect(find.byType(HelpPage), findsNothing);
  });

  testWidgets('a page destination opens over Help, so Back returns to it',
      (t) async {
    final calls = <HelpDestination>[];
    final events = await pumpHelp(t, query: '内夫');
    helpDestinationHandler = (d) {
      calls.add(d);
      events.add('act');
    };
    await t.enterText(find.byType(TextField), '内夫 ');
    await t.pumpAndSettle();
    await t.tap(find.text('带我去').first);
    await t.pumpAndSettle();
    expect(calls, [HelpDestination.naves]);
    expect(events, ['act']);
    expect(find.byType(HelpPage), findsOneWidget);
  });
}
