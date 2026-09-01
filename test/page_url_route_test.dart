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
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/main.dart' show appUnknownRoute;
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
}
