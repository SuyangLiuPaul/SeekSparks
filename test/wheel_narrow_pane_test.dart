/// The wheel and the strip AppBars, hub caption and legend, at a
/// PHONE width — `#/wheel` and `#/strip` stopped being gated by
/// `SmallScreenGate` on 2026-09-03 (`main.dart`), so a pane this
/// narrow is now a real reader, not a hypothetical one.
///
/// 375 px is an iPhone SE / iPhone 12-16 mini's logical width, the
/// narrowest this app is currently reached on. Measured against the
/// page BEFORE this file's fix (see each test's own comment for the
/// exact number): the AppBar title rendered at 0.0 px wide on both
/// pages, the hub caption's four stacked blocks measured 171 px
/// against an 86 px hub in the app's own default locale (简体中文),
/// and the legend — 238.5 x 216 px, independent of the canvas — sat
/// over most of the wheel's own bottom-left quadrant at a 375 px
/// diameter. None of those numbers change at a desktop width; only
/// the failure at 375 does.
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
import 'package:seeksparks/services/hebrew_kings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Same warm-up `radial_chronology_page_test.dart` and
    // `strip_chronology_page_test.dart` do: real asset I/O never
    // resolves inside a widget test's fake-async zone, so the caches
    // are primed here and the pages' own `initState` reads them back.
    await WheelHistoryService.instance.load();
    await ChronologyService.instance.load();
    await HebrewKingsService.instance.load();
  });

  Future<void> pump(WidgetTester tester, Widget page, Size size) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
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

  /// The width [text] wants when nothing constrains it, in the same
  /// style the `AppBar` sets its title in.
  ///
  /// `getSize(title).width > 0` is not the question, and asking it was
  /// how the first pass at this shipped a title nobody could read.
  /// `AppBar` gives the title a `Flexible`: when the actions have
  /// spent the toolbar, Flutter lays the `Text` out at its NATURAL
  /// size and then clips it, so `getSize` reports the full 71 px while
  /// the reader sees one glyph and an ellipsis — or, at 375 px,
  /// nothing at all. Read on the shipped page at a 500 px viewport
  /// the title rendered as `世···`, which is exactly the clipped
  /// fragment `wheelViewSwitch` refuses to make of a two-word label.
  ///
  /// So the assertion is that the title is WHOLE: the box it occupies
  /// is at least as wide as the text wants, and it ends before the
  /// first action begins.
  double naturalWidth(WidgetTester tester, Finder title) {
    final widget = tester.widget<Text>(title);
    final style = DefaultTextStyle.of(tester.element(title)).style
        .merge(widget.style);
    return (TextPainter(
      text: TextSpan(text: widget.data, style: style),
      textDirection: TextDirection.ltr,
    )..layout())
        .width;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('the wheel at 375 px', () {
    testWidgets('the AppBar title is actually on screen', (tester) async {
      await pump(tester, const RadialChronologyPage(), const Size(375, 812));
      expect(tester.takeException(), isNull);
      // Before the fix: `AppBar` gave the title a `Flexible` and six
      // actions (three `IconButton`s, the `SegmentedButton`, the
      // language switcher, the home button) spent the whole toolbar
      // before the title got a pixel — measured at
      // `Size(0.0, 28.0)`.
      final title = find.descendant(
          of: find.byType(AppBar), matching: find.text('世界史轮盘'));
      expect(title, findsOneWidget);
      expect(tester.getSize(title).width,
          greaterThanOrEqualTo(naturalWidth(tester, title) - 0.5),
          reason: 'the AppBar title must render WHOLE, not be laid out '
              'at its natural size and clipped away by the actions '
              'beside it — see naturalWidth');
      expect(tester.getTopRight(title).dx,
          lessThanOrEqualTo(tester.getTopLeft(find.byIcon(Icons.more_vert)).dx),
          reason: 'and it must end before the overflow button begins');
      await unmount(tester);
    });

    testWidgets('the view switch is still reachable in one tap',
        (tester) async {
      await pump(tester, const RadialChronologyPage(), const Size(375, 812));
      // A direct AppBar action, not one hidden behind the overflow
      // menu — the round trip itself (tapping it actually reaches
      // `StripChronologyPage`) is already covered at a desktop width
      // by `radial_chronology_page_test.dart`'s own switch test; this
      // only pins that a narrow pane still offers it directly.
      expect(find.byType(SegmentedButton<String>), findsOneWidget,
          reason: 'a narrow pane must still offer the wheel<->strip '
              'switch directly, not behind a second tap — it is how a '
              'phone reader escapes to the form that actually works '
              'at this width');
      expect(find.byIcon(Icons.donut_large), findsOneWidget,
          reason: 'below kWheelNarrowPaneWidth the switch is icon-only');
      expect(find.byIcon(Icons.view_week), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the hub caption fits inside the hub', (tester) async {
      await pump(tester, const RadialChronologyPage(), const Size(375, 812));
      final wheel = find.byKey(const ValueKey('chronologyWheel'));
      final side = tester.getSize(wheel).width;
      const hubFrac = 0.115; // mirrors `_kHubFrac`, private to the page
      final hubD = side * hubFrac * 2;
      final caption = find.byKey(const ValueKey('wheelHubCaption'));
      expect(caption, findsOneWidget);
      final captionH = tester.getSize(caption).height;
      // Before the fix: the four stacked blocks (title, year range,
      // counts, hint) measured 171 px against an 86 px hub — the
      // caption printed out over the bands it sits on at twice the
      // hub's own height. At the app's default locale the corpus's
      // own counts line is long enough that both the hint AND the
      // year range have to drop before title+counts alone fits (85
      // against 86.25) — the assertion below is on the real render,
      // not on which line(s) dropped, so it stays true either way.
      expect(captionH, lessThanOrEqualTo(hubD),
          reason: 'caption height $captionH must fit the hub diameter '
              '$hubD — see _hubCaption\'s own doc for the sacrifice '
              'order');
      await unmount(tester);
    });

    testWidgets('the legend is a chip, not a quadrant of the wheel',
        (tester) async {
      await pump(tester, const RadialChronologyPage(), const Size(375, 812));
      // Before the fix: `_legend` sat directly at `Positioned(left: 10,
      // bottom: 10, ...)` and measured 238.5 x 216 px at rest with
      // every layer on — 216 px of a 375 px wheel, most of its
      // bottom-left quadrant. The collapsed form is a small chip;
      // '闪族' (Shem, the legend's first row) must NOT be directly on
      // screen, because that is the full, uncollapsed legend.
      expect(find.text('闪族'), findsNothing,
          reason: 'the full legend must not be drawn directly on a '
              '375 px pane');
      expect(find.byIcon(Icons.legend_toggle), findsOneWidget,
          reason: 'a collapsed pane must still offer the legend, as a '
              'tappable chip in the same corner');
      // Tapping the chip must reach the SAME legend body, unchanged —
      // reusing `_legend`'s own widget rather than a second copy of
      // what it discloses (which lifespans read which tradition; that
      // reigns and lifespans are different kinds of claim).
      await tester.tap(find.byIcon(Icons.legend_toggle));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('闪族'), findsOneWidget,
          reason: 'the chip must open the legend\'s own content, not a '
              'reduced copy of it');
      await unmount(tester);
    });

    // 500 px is inside the band the FIRST version of this fix got
    // wrong. `kWheelNarrowPaneWidth` was 480, so 500 took the WIDE bar
    // — back, three icons, the two-word switch, language, home, 406 px
    // of chrome — and the shipped page rendered its title as `世···`,
    // one glyph and an ellipsis. A threshold chosen from what counts as
    // a phone rather than from what the bar actually costs is a
    // threshold that will be wrong again, so this pins the cost.
    testWidgets('500 px takes the narrow bar, and the title is whole',
        (tester) async {
      await pump(tester, const StripChronologyPage(), const Size(500, 800));
      expect(find.byIcon(Icons.more_vert), findsOneWidget,
          reason: '500 px cannot afford the wide bar');
      final title = find.descendant(
          of: find.byType(AppBar), matching: find.text('世界历史时间条'));
      expect(tester.getSize(title).width,
          greaterThanOrEqualTo(naturalWidth(tester, title) - 0.5));
      await unmount(tester);
    });

    testWidgets('nothing regresses at a desktop width', (tester) async {
      await pump(tester, const RadialChronologyPage(), const Size(1440, 900));
      expect(tester.takeException(), isNull);
      // The full legend is directly on screen, as before — no chip.
      expect(find.text('闪族'), findsOneWidget);
      expect(find.byIcon(Icons.legend_toggle), findsNothing);
      // All three icon actions are direct, and the view-switch carries
      // its words, as before.
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.filter_list), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsNothing);
      await unmount(tester);
    });
  });

  group('the strip at 375 px', () {
    testWidgets('the AppBar title is actually on screen', (tester) async {
      await pump(tester, const StripChronologyPage(), const Size(375, 812));
      expect(tester.takeException(), isNull);
      final title = find.descendant(
          of: find.byType(AppBar), matching: find.text('世界历史时间条'));
      expect(title, findsOneWidget);
      // The strip's own name is the LONGER of the two — seven Han
      // characters against the wheel's five, and 'World History Strip'
      // against 'World History Wheel' — so it is the page that decides
      // how much room the narrow bar has to leave, and the one that
      // fails first if it leaves too little.
      expect(tester.getSize(title).width,
          greaterThanOrEqualTo(naturalWidth(tester, title) - 0.5),
          reason: 'the strip carries the same actions as the wheel and '
              'a longer name; its title must render WHOLE, not be laid '
              'out at natural size and clipped away');
      expect(tester.getTopRight(title).dx,
          lessThanOrEqualTo(tester.getTopLeft(find.byIcon(Icons.more_vert)).dx),
          reason: 'and it must end before the overflow button begins');
      await unmount(tester);
    });

    testWidgets('the view switch is still reachable in one tap',
        (tester) async {
      await pump(tester, const StripChronologyPage(), const Size(375, 812));
      expect(find.byType(SegmentedButton<String>), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('nothing regresses at a desktop width', (tester) async {
      await pump(tester, const StripChronologyPage(), const Size(1440, 900));
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.filter_list), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsNothing);
      await unmount(tester);
    });
  });
}
