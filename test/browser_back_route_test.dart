/// Browser Back must move you back — not stack a second app on top.
///
/// 2026-09-02. Reproduced on an instrumented profile web build before
/// anything was changed: cold-open `#/genesis/1:1?v=nasb`, read a few
/// chapters, press the browser's Back button once —
///
///     [POP]   popstate hash=#/genesis/1:1?v=nasb   (x4, the walk)
///     [ROUTE] onGenerateRoute name=/genesis/1:1?v=nasb  (null)
///     [ROUTE] onUnknownRoute  name=/genesis/1:1?v=nasb
///     [MOUNT] _RootRouter #2
///
/// — and the screen showed two Search panes and two menu bars. A second
/// press gave `#3`. With the chronology wheel open the same press slid a
/// whole workbench in OVER the wheel while the address bar still read
/// `#/wheel`. `browserRouteAction` in `main.dart` carries the full
/// mechanism and the statement of what Back is supposed to do; these
/// pin it.
///
/// The falsifier for the widget tests below is the pre-fix shape, which
/// is one line: make `BrowserRouteObserver.didPushRouteInformation`
/// return `false` in every case. That is exactly what the app did before
/// this observer existed — decline the notification and let
/// `WidgetsApp.didPushRouteInformation` `pushNamed` the path. Against
/// that shape `pushes` is 1 instead of 0 and the app root is buried.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/main.dart'
    show
        BrowserRouteAction,
        BrowserRouteObserver,
        appGenerateRoute,
        appUnknownRoute,
        browserRouteAction;
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart'
    show RadialChronologyPage, kWheelUrlPath;
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/utils/page_links.dart' show samePageUrlPath;

/// Counts what the Navigator was actually asked to do. The bug was a
/// PUSH, so this is the assertion that matters most: browser Back must
/// cause zero of them.
class _RouteCounter extends NavigatorObserver {
  int pushes = 0;
  int pops = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushes += 1;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => pops += 1;
}

/// Exactly what the web engine sends when the user presses Back and the
/// walk lands back on its own history entry: a `pushRoute` method call
/// on `flutter/navigation`, JSON-encoded. Going through the channel
/// rather than calling `WidgetsBinding.handlePushRoute` keeps the test
/// on the real path, observer dispatch included.
Future<void> _engineSaysPushRoute(WidgetTester tester, String path) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec()
        .encodeMethodCall(MethodCall('pushRoute', path)),
    (_) {},
  );
  await tester.pump();
}

Widget _app({
  required GlobalKey<NavigatorState> nav,
  required NavigatorObserver counter,
  String? initialRoute,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => MainProvider()),
      ChangeNotifierProvider(create: (_) => AppSettings()),
    ],
    child: MaterialApp(
      navigatorKey: nav,
      navigatorObservers: [counter],
      initialRoute: initialRoute,
      // The app's own two handlers, verbatim.
      onGenerateRoute: appGenerateRoute,
      onUnknownRoute: appUnknownRoute,
      home: const Scaffold(
        key: ValueKey('appRoot'),
        body: SizedBox.shrink(),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Real I/O never completes inside a widget test's fake-async zone,
    // and the wheel loads its asset in `initState`. The service caches,
    // so warming it here lets the page actually build.
    await WheelHistoryService.instance.load();
  });

  group('samePageUrlPath', () {
    test('two spellings of the same page are the same page', () {
      expect(samePageUrlPath(kWheelUrlPath, kWheelUrlPath), isTrue);
      // A claim is written without its `#`; a link carries one.
      expect(samePageUrlPath('#$kWheelUrlPath', kWheelUrlPath), isTrue);
      // Page paths match by prefix, so a query is still the same page.
      expect(samePageUrlPath('$kWheelUrlPath?year=-4000', kWheelUrlPath),
          isTrue);
    });

    test('anything that is not a page is not the same page', () {
      expect(samePageUrlPath('/genesis/1', '/genesis/1'), isFalse);
      expect(samePageUrlPath(kWheelUrlPath, null), isFalse);
      expect(samePageUrlPath(null, kWheelUrlPath), isFalse);
      expect(samePageUrlPath(kWheelUrlPath, '/genesis/1'), isFalse);
      expect(samePageUrlPath('/wheelbarrow', kWheelUrlPath), isFalse);
    });
  });

  group('browserRouteAction', () {
    test('a passage is a Back, never a route to push', () {
      // The whole bug in one expectation: this path used to be handed to
      // `pushNamed`, which mounted a second copy of the app.
      expect(browserRouteAction('/genesis/1:1?v=nasb', null),
          BrowserRouteAction.goBack);
      // Including while a page holds the URL — Back off the wheel closes
      // the wheel rather than sliding a workbench over it.
      expect(browserRouteAction('/genesis/1:1?v=nasb', kWheelUrlPath),
          BrowserRouteAction.goBack);
    });

    test('a stray or empty name is a Back too', () {
      expect(browserRouteAction('/nonsense', null), BrowserRouteAction.goBack);
      expect(browserRouteAction('/', null), BrowserRouteAction.goBack);
      expect(browserRouteAction('', null), BrowserRouteAction.goBack);
      expect(browserRouteAction(null, null), BrowserRouteAction.goBack);
    });

    test('a page that is not open is a page to open', () {
      expect(browserRouteAction(kWheelUrlPath, null),
          BrowserRouteAction.openPage);
      // A claim held by something that is not this page changes nothing.
      expect(browserRouteAction(kWheelUrlPath, '/genesis/1'),
          BrowserRouteAction.openPage);
    });

    test('a page that IS open is a Back off it, not a second copy', () {
      // Reachable, and it was the second-wheel bug: opening the wheel
      // claims the URL and so writes another `#/wheel` entry, which the
      // next Back reports.
      expect(browserRouteAction(kWheelUrlPath, kWheelUrlPath),
          BrowserRouteAction.goBack);
      expect(browserRouteAction('$kWheelUrlPath?year=-4000', kWheelUrlPath),
          BrowserRouteAction.goBack);
    });
  });

  testWidgets(
      'Back within reader history mounts nothing, at the app root',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1440, 900);

    final nav = GlobalKey<NavigatorState>();
    final counter = _RouteCounter();
    final observer = BrowserRouteObserver(navigator: () => nav.currentState);
    // Ahead of the one `MaterialApp` registers when it mounts, exactly as
    // `_MainAppState` is ahead of `GetMaterialApp`'s.
    tester.binding.addObserver(observer);
    addTearDown(() => tester.binding.removeObserver(observer));

    await tester.pumpWidget(_app(nav: nav, counter: counter));
    counter.pushes = 0; // the initial route is not a Back

    await _engineSaysPushRoute(tester, '/genesis/1:1?v=nasb');
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(counter.pushes, 0,
        reason: 'browser Back must not push anything — pushing the app '
            'root is what put a second workbench on screen');
    expect(find.byKey(const ValueKey('appRoot')), findsOneWidget,
        reason: 'the app the reader was using is still the app on screen');
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets(
      'Back off the wheel closes the wheel and shows what was underneath',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1440, 900);

    final nav = GlobalKey<NavigatorState>();
    final counter = _RouteCounter();
    final observer = BrowserRouteObserver(navigator: () => nav.currentState);
    tester.binding.addObserver(observer);
    addTearDown(() => tester.binding.removeObserver(observer));

    // The cold-`#/wheel` stack `af9d956` builds: `[appRoot, wheel]`.
    await tester.pumpWidget(
        _app(nav: nav, counter: counter, initialRoute: kWheelUrlPath));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(RadialChronologyPage), findsOneWidget,
        reason: 'precondition: the wheel is open');
    counter.pushes = 0;

    // The path the engine reports is the OLDEST app entry, which for a
    // reader who opened the wheel mid-session is a passage.
    await _engineSaysPushRoute(tester, '/genesis/1:1?v=nasb');
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(counter.pushes, 0);
    expect(counter.pops, 1, reason: 'Back off a page closes the page');
    expect(find.byType(RadialChronologyPage), findsNothing);
    expect(find.byKey(const ValueKey('appRoot')), findsOneWidget,
        reason: 'what was underneath the wheel, not a fresh copy of it');
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('the wheel URL still opens the wheel through the observer',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1440, 900);

    final nav = GlobalKey<NavigatorState>();
    final counter = _RouteCounter();
    final observer = BrowserRouteObserver(navigator: () => nav.currentState);
    tester.binding.addObserver(observer);
    addTearDown(() => tester.binding.removeObserver(observer));

    await tester.pumpWidget(_app(nav: nav, counter: counter));
    counter.pushes = 0;

    // The live-tab door `50ee136` opened: the observer must DECLINE this
    // one so `WidgetsApp` pushes it and `appGenerateRoute` answers.
    await _engineSaysPushRoute(tester, kWheelUrlPath);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(counter.pushes, 1);
    expect(find.byType(RadialChronologyPage), findsOneWidget);
    expect(find.byKey(const ValueKey('chronologyWheel')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('Back onto the wheel URL with the wheel open does not open '
      'a second wheel', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1440, 900);

    final nav = GlobalKey<NavigatorState>();
    final counter = _RouteCounter();
    // The wheel holds the URL, which is what it does from its own
    // `initState` (`UrlSyncService.claimUrl(kWheelUrlPath)`). Injected
    // because the URL-sync layer is the no-op stub under `flutter test`.
    final observer = BrowserRouteObserver(
      navigator: () => nav.currentState,
      claimedPath: () => kWheelUrlPath,
    );
    tester.binding.addObserver(observer);
    addTearDown(() => tester.binding.removeObserver(observer));

    await tester.pumpWidget(
        _app(nav: nav, counter: counter, initialRoute: kWheelUrlPath));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(RadialChronologyPage), findsOneWidget);
    counter.pushes = 0;

    await _engineSaysPushRoute(tester, kWheelUrlPath);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(counter.pushes, 0, reason: 'the wheel is already the page');
    expect(find.byType(RadialChronologyPage), findsNothing,
        reason: 'so this is a plain Back off it');
    expect(find.byKey(const ValueKey('appRoot')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  group('the address bar rescues a request the engine lost', () {
    /// The engine keeps ONE history entry, so a reader who edits the
    /// fragment has their request rewound: the platform reports the
    /// OLDEST entry's path instead. Measured on dev v1.6.223 — after a
    /// single reader move, pasting `#/wheel` gave no wheel and a blank
    /// address bar, and it read as a broken page link when the request
    /// had simply been overwritten in transit.
    test('a lost page path is recovered from the live hash', () {
      expect(
          browserRouteAction('/genesis/1?v=bsb', null, livePath: '/wheel'),
          BrowserRouteAction.openPage);
    });

    test('but only to FIND a page, never to lose one', () {
      // A report that already names a page is trusted as it stands.
      expect(browserRouteAction('/wheel', null, livePath: '/genesis/1'),
          BrowserRouteAction.openPage);
      // And a live hash that names no page changes nothing.
      expect(browserRouteAction('/genesis/1', null, livePath: '/john/3'),
          BrowserRouteAction.goBack);
      expect(browserRouteAction('/genesis/1', null, livePath: null),
          BrowserRouteAction.goBack);
    });

    test('the page already open still means Back, however it was found', () {
      // Recovering `/wheel` from the bar while the wheel HOLDS the bar
      // is the reader pressing Back off it, not asking for a second one.
      expect(browserRouteAction('/genesis/1', '/wheel', livePath: '/wheel'),
          BrowserRouteAction.goBack);
    });
  });

}
