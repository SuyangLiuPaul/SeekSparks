/// THE FIRST REAL CRASH REPORT THIS APP HAS EVER RECEIVED, reproduced.
///
///     Bad state: No element
///     Version 1.6.204   Platform web   Locale en   Route /wheel
///     05:48:35.965Z nav:push  /
///     05:48:35.965Z nav:push  /wheel
///
/// Source-map-deobfuscated against a rebuild of `20e3d36` (the commit
/// that shipped v1.6.204), the frames read:
///
///     js_array.dart:469          JSArray.single
///     scroll_controller.dart:173 ScrollController.position
///     scrollable_positioned_list.dart:543/559 _startScroll
///     scrollable_positioned_list.dart:526     _scrollTo
///
/// — `_positions.single` on a `ScrollController` that has no positions.
/// In debug that is the framework's `_positions.isNotEmpty` assertion on
/// line 171; release compiles the assertion out and `.single` throws
/// instead, which is the message the reader saw.
///
/// The two breadcrumbs share a millisecond and are the `[home, wheel]`
/// initial stack `af9d956` introduced — shipped in this very version. So
/// the reader cold-opened a shared `#/wheel` link and never navigated
/// again; the Browse pane they crashed in was one they never saw.
///
/// What makes that possible is the difference between BUILDING and being
/// LAID OUT. The Overlay lays out only the entries above the last opaque
/// one, so the workbench under the wheel is never laid out — but it is
/// still built, and it keeps building, because a descendant's `setState`
/// does not need layout. So the pane mounts, loads its chapter, and
/// builds its `ScrollablePositionedList`, whose `initState` attaches the
/// `ItemScrollController`. `isAttached` is now true. The scroll POSITION
/// is created by the `Scrollable` inside the list, and that lives under a
/// `LayoutBuilder`, which never runs. `isAttached && positions.isEmpty`
/// is the state the app had never been in before, and the post-frame
/// scroll-to-the-focused-verse walks straight into it.
///
/// The test is written against the real `BrowseWindow` under the app's
/// real `appGenerateRoute`, so what it pins is the shipped path and not a
/// model of it. Falsified by reverting `_listIsLaidOut` to `isAttached`
/// alone: it fails with exactly the frames above.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/main.dart' show appGenerateRoute, appUnknownRoute;
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart' show kWheelUrlPath;
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/originals_service.dart';
import 'package:seeksparks/services/strongs_service.dart';
import 'package:seeksparks/services/tagged_text_service.dart';
import 'package:seeksparks/services/versification.dart';
import 'package:seeksparks/widgets/browse_window.dart';

/// The edition the pane prints. `bsb` rather than the app's default
/// Chinese one because the pane's load reaches for a tagged text and the
/// originals, and those have to be warm — see [main]'s `setUpAll`.
const String _edition = 'bsb';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Real I/O never completes inside a widget test's fake-async zone,
    // and the pane's load awaits five different assets before it can
    // emit a row. Every one of these services caches, so warming them
    // out here is what lets the load actually finish under `pump`.
    // (`radial_chronology_page_test.dart` warms the wheel's asset for
    // the same reason.)
    await WheelHistoryService.instance.load();
    await Versification.load();
    for (var n = 1; n <= 31; n++) {
      await OriginalsService.forVerse('Genesis', 1, n);
    }
    await StrongsService.lookup('H430');
    await TaggedTextService.forVerse(
        version: _edition, englishBook: 'Genesis', chapter: 1, verse: 1);
  });

  testWidgets(
      'a Browse pane that boots UNDER the wheel does not scroll a list '
      'that was never laid out', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);
    // The reporter's own viewport class: a 1080p Windows desktop, where
    // the workbench's centre pane is the Browse window.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1920, 1080);

    final chapter = <Verse>[
      for (var n = 1; n <= 31; n++)
        Verse(book: 'Genesis', chapter: 1, verse: n, text: 'verse $n text'),
    ];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) {
            final mp = MainProvider();
            mp.setVerses(chapter);
            mp.setCurrentChapter(book: 'Genesis', chapter: 1);
            mp.cacheVersionForTest(_edition, chapter);
            return mp;
          }),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: const MaterialApp(
          // The cold door, verbatim: on the web the engine's boot route
          // name IS the hash path, so this is what a shared `#/wheel`
          // link hands the app, and `home:` is added BENEATH the page
          // rather than replaced by it.
          initialRoute: kWheelUrlPath,
          onGenerateRoute: appGenerateRoute,
          onUnknownRoute: appUnknownRoute,
          home: Scaffold(
            body: BrowseWindow(
              book: 'Genesis',
              chapter: 1,
              versionCodes: <String>[_edition],
              focusedVerse: 1,
            ),
          ),
        ),
      ),
    );

    // Long enough for the pane's chapter load to land and for the list
    // it builds from that load to reach a post-frame callback.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // The state the crash needs, stated rather than assumed: the pane is
    // in the tree, its list is in the tree, and NEITHER has been laid
    // out. If any of these three ever stops holding, this test has
    // stopped reproducing the report and the expectation below is
    // passing for the wrong reason.
    expect(find.byType(BrowseWindow, skipOffstage: false), findsOneWidget,
        reason: 'the app root under the wheel is still built');
    expect(
        find.byType(ScrollablePositionedList, skipOffstage: false),
        findsOneWidget,
        reason: 'and it built its list after the load, while offstage');
    expect(find.textContaining('Genesis 1:', findRichText: true,
            skipOffstage: false),
        findsNothing,
        reason: 'but not one row was ever laid out — a list builds its '
            'children during layout — so there is no scroll position for '
            '`scrollTo` to move');

    expect(tester.takeException(), isNull,
        reason: 'scrolling a list that was never laid out is the crash: '
            'ScrollController.position on empty _positions');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  /// The other half of the guard, because a guard that never lets the
  /// scroll through would pass the test above and break the feature: the
  /// focused verse is what the nav strip and the search hit both move
  /// this pane to. On screen the list HAS been laid out by the time the
  /// post-frame callback runs, so the scroll goes ahead.
  ///
  /// The reference row is the assertion rather than a scroll offset
  /// because a list only builds the rows near its viewport: finding
  /// `Genesis 1:25` on screen at all is proof the list moved to it.
  testWidgets('the same pane ON SCREEN still scrolls to the focused verse',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1920, 1080);

    final chapter = <Verse>[
      for (var n = 1; n <= 31; n++)
        Verse(book: 'Genesis', chapter: 1, verse: n, text: 'verse $n text'),
    ];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) {
            final mp = MainProvider();
            mp.setVerses(chapter);
            mp.setCurrentChapter(book: 'Genesis', chapter: 1);
            mp.cacheVersionForTest(_edition, chapter);
            return mp;
          }),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: BrowseWindow(
              book: 'Genesis',
              chapter: 1,
              versionCodes: <String>[_edition],
              focusedVerse: 25,
            ),
          ),
        ),
      ),
    );

    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.textContaining('Genesis 1:25', findRichText: true),
        findsWidgets,
        reason: 'the focused verse was scrolled into view — a list only '
            'builds the rows near its viewport, so finding it at all is '
            'the proof the scroll went ahead');
    // `1:5` and not `1:1`, which is a prefix of `1:10` … `1:19`.
    expect(find.textContaining('Genesis 1:5', findRichText: true),
        findsNothing,
        reason: 'and the pane really did MOVE: the top of the chapter is '
            'behind it now');
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
