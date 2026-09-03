/// A URL that names a PAGE has to open that page — from either door.
///
/// `#/wheel` is not a passage. The chronology wheel claims that path
/// while it is open, so it is what a shared wheel link says and what a
/// `#/wheel` history entry holds. The app declares no `routes` map, so
/// `/wheel` is not a registered route either — which means every way of
/// reaching it that is NOT a cold start arrives at `onUnknownRoute`.
///
/// Before 2026-09-02 that handler answered every unknown name with the
/// app root. So editing the fragment in a live tab, or pressing
/// Back / Forward onto a `#/wheel` entry — both same-document
/// navigations, which the web engine delivers as `pushRoute('/wheel')`
/// rather than by restarting the app — pushed a SECOND workbench,
/// freshly mounted at Genesis 1, on top of whatever was showing, while
/// the address bar read `#/wheel`. Reproduced on a release web build
/// with the route logged: `onUnknownRoute name=/wheel`, followed
/// immediately by a second root router mounting.
///
/// The cold-open branch in `_RootRouter` was never the missing half —
/// it works, and is why this looked fixed. These pin the OTHER door.
///
/// 2026-09-02, second pass: the cold door was not fine either. It
/// worked, but only after the splash and the workbench's first frame,
/// because `/wheel` was dropped from the INITIAL route stack — the
/// engine's boot route name is the hash path, `defaultGenerateInitialRoutes`
/// asks the app for it with `allowNull: true`, and the app answered no
/// `onGenerateRoute` at all. Measured on dev v1.6.203: `main.dart.js` at
/// 179 ms, `wheel_history.json` not requested until 30.6 s. `appGenerateRoute`
/// answers both doors now, so the wheel is on the initial stack from the
/// first frame. These pin that, and pin that the app root is still
/// BENEATH it rather than replaced — `HomeIconButton` is
/// `popUntil(isFirst)` and needs something to land on.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/main.dart'
    show appGenerateRoute, appUnknownRoute;
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart'
    show RadialChronologyPage, kWheelUrlPath;
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/utils/page_links.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Real I/O never completes inside a widget test's fake-async zone,
    // and the wheel loads its asset in `initState`. The service caches,
    // so warming it here lets the page actually build. Same reason
    // `radial_chronology_page_test.dart` does it.
    await WheelHistoryService.instance.load();
  });

  group('pageForUrlPath', () {
    test('the wheel path names the wheel page', () {
      expect(pageForUrlPath(kWheelUrlPath), isA<RadialChronologyPage>());
      // The engine hands over a bare path; a shared link carries the `#`.
      expect(pageForUrlPath('#$kWheelUrlPath'), isA<RadialChronologyPage>());
      // Prefix match, so a future `#/wheel?year=-4000` still resolves.
      expect(pageForUrlPath('$kWheelUrlPath?year=-4000'),
          isA<RadialChronologyPage>());
    });

    test('a passage link, and a stray path, name no page', () {
      expect(pageForUrlPath('/genesis/1'), isNull);
      expect(pageForUrlPath('/genesis/1:1?v=nasb'), isNull);
      // Not a prefix of a different word.
      expect(pageForUrlPath('/wheelbarrow'), isNull);
      expect(pageForUrlPath('/'), isNull);
      expect(pageForUrlPath(''), isNull);
      expect(pageForUrlPath(null), isNull);
    });
  });

  group('appGenerateRoute', () {
    test('a reader path names no route', () {
      // Null, not a route: a passage is applied to MainProvider by the
      // URL-sync layer, and `home:` must keep answering it. If this ever
      // returned a route, every shared chapter link would push a page.
      //
      // Written against the function, deliberately NOT through
      // `initialRoute: '/genesis/1'`: `defaultGenerateInitialRoutes`
      // reports a FlutterError in debug when the initial route matches
      // nothing, and `takeException()` would surface it as a failure.
      expect(appGenerateRoute(const RouteSettings(name: '/genesis/1')), isNull);
      expect(appGenerateRoute(const RouteSettings(name: '/genesis/1?v=nasb')),
          isNull);
      expect(appGenerateRoute(const RouteSettings(name: '/')), isNull);
      expect(appGenerateRoute(const RouteSettings(name: null)), isNull);
    });

    test('the wheel path names a route', () {
      expect(appGenerateRoute(const RouteSettings(name: kWheelUrlPath)),
          isA<MaterialPageRoute<void>>());
    });
  });

  testWidgets(
      'a live-tab navigation to the wheel URL opens the wheel, '
      'not a second copy of the app root', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1440, 900);

    late BuildContext ctx;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: MaterialApp(
          // The app's own handler, verbatim — this is the seam the web
          // engine's `pushRoute` lands on.
          onUnknownRoute: appUnknownRoute,
          home: Builder(builder: (c) {
            ctx = c;
            return const Scaffold(body: SizedBox.shrink());
          }),
        ),
      ),
    );

    // Exactly what `WidgetsApp.didPushRoute` does with the path the
    // engine reports when the fragment changes under a running app.
    // ignore: unawaited_futures
    Navigator.of(ctx).pushNamed<void>(kWheelUrlPath);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    expect(find.byType(RadialChronologyPage), findsOneWidget,
        reason: 'the wheel URL must open the wheel');
    // The wheel really built, rather than sitting on its spinner.
    expect(find.byKey(const ValueKey('chronologyWheel')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets(
      'a cold #/wheel boots with the wheel on top of the app root, '
      'from the first frame', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1440, 900);

    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: MaterialApp(
          navigatorKey: nav,
          // In a test `platformDispatcher.defaultRouteName` is '/', so
          // `initialRoute` is honoured (app.dart:1430) — this stands in
          // for the web engine reporting the hash path as the boot route.
          initialRoute: kWheelUrlPath,
          onGenerateRoute: appGenerateRoute,
          onUnknownRoute: appUnknownRoute,
          home: const Scaffold(
            key: ValueKey('appRoot'),
            body: SizedBox.shrink(),
          ),
        ),
      ),
    );
    // ONE frame. The point is the FIRST frame, not "eventually": before
    // `appGenerateRoute` existed, `defaultGenerateInitialRoutes` dropped
    // `/wheel` and this was `findsNothing`.
    await tester.pump();

    expect(find.byType(RadialChronologyPage), findsOneWidget,
        reason: 'the wheel must be on the initial stack, not pushed later');
    // Added, not pushed: the app root is BENEATH and offstage, not gone.
    // `HomeIconButton` is popUntil(isFirst) and needs it there.
    expect(find.byKey(const ValueKey('appRoot')), findsNothing);
    expect(find.byKey(const ValueKey('appRoot'), skipOffstage: false),
        findsOneWidget);

    // The wheel really built, rather than sitting on its spinner.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('chronologyWheel')), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Back off the wheel lands on the app, once.
    nav.currentState!.pop();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(RadialChronologyPage), findsNothing);
    expect(find.byKey(const ValueKey('appRoot')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets(
      'the live-tab door does not depend on the stray-name fallback',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1440, 900);

    late BuildContext ctx;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: MaterialApp(
          // No `onUnknownRoute` at all: `pushNamed` consults
          // `onGenerateRoute` first, so a page path must never reach the
          // fallback. (If it did, this would throw the framework's
          // "Could not find a generator for route" assertion.)
          onGenerateRoute: appGenerateRoute,
          home: Builder(builder: (c) {
            ctx = c;
            return const Scaffold(body: SizedBox.shrink());
          }),
        ),
      ),
    );

    // ignore: unawaited_futures
    Navigator.of(ctx).pushNamed<void>(kWheelUrlPath);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    expect(find.byType(RadialChronologyPage), findsOneWidget);
    expect(find.byKey(const ValueKey('chronologyWheel')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  /// WHAT A READER'S SAVED WHEEL LINK ACTUALLY HOLDS, asked because a
  /// rename of the chart's ids had to answer it.
  ///
  /// `chronology.json` keyed five patriarchs on the Authorised Version's
  /// spelling — enos, cainan, mahalaleel, salah, nahor — and they were
  /// renamed onto `family_tree.json`'s. If any of those ids were ever
  /// written into a URL, a link somebody saved would now name a record
  /// that does not exist, and the honest fix would be to keep the old
  /// spellings resolving as aliases forever.
  ///
  /// They are not. The wheel's selection lives in `_selectedId`, in
  /// `State`, and the address bar is claimed with a CONSTANT: the page
  /// calls `claimUrl(kWheelUrlPath, owner: this)` on open and
  /// `claimUrl(null, owner: this)` on
  /// close, and `kWheelUrlPath` is the literal `/wheel`. There is no
  /// second argument, no interpolation, no query, and the page reads and
  /// writes no `SharedPreferences` at all — so no id of any kind is
  /// persisted, by the URL or by anything else, and a saved link opens
  /// the wheel with nothing selected exactly as it did before.
  ///
  /// Asserted against the source rather than described, because the
  /// claim is about what the page CANNOT do. The day someone puts a
  /// record id in the address bar, this fails and the alias question
  /// gets asked again.
  test('a saved wheel link names no record, so a rename cannot break one',
      () {
    expect(kWheelUrlPath, '/wheel');
    final src =
        File('lib/pages/radial_chronology_page.dart').readAsStringSync();
    expect(RegExp(r'claimUrl\(').allMatches(src).length, 2,
        reason: 'the page claims the URL on open and releases it on close, '
            'and nothing else may write the address bar');
    // 2026-09-03: both calls carry `owner: this` now, so a wheel that
    // is closing cannot release a claim the wheel that replaced it
    // holds (`UrlClaim`). What this test is about is unchanged — the
    // PATH is still the constant and still carries no record id — so
    // the match stops before the argument list ends rather than
    // pretending the extra argument is not there.
    expect(src, contains('claimUrl(kWheelUrlPath, owner: this)'));
    expect(src, contains('claimUrl(null, owner: this)'));
    expect(src, isNot(contains("claimUrl('")),
        reason: 'the path must stay the constant, never a literal');
    expect(src, contains("const String kWheelUrlPath = '/wheel';"),
        reason: 'the claimed path is a literal — the moment it is built '
            'from a record id, a saved link starts carrying one');
    expect(src, isNot(contains('SharedPreferences')),
        reason: 'a persisted selection would outlive a rename the same way '
            'a URL would');

    // And the door is wide anyway: a URL that DID carry a query still
    // resolves to the wheel, so even a hand-edited one opens the page
    // rather than falling through to the reader.
    expect(pageForUrlPath('#/wheel?year=-4000'), isA<RadialChronologyPage>());
    expect(pageForUrlPath('#/wheel'), isA<RadialChronologyPage>());
  });
}
