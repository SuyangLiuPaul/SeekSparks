// The overview must fit before the reader discovers zoom. These checks
// measure the same axis placement used by the painter in the bundled
// fonts, then exercise the real page's planning and drawing counters.
// A cache-only vocabulary loop does not establish a whole-frame budget.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/widgets/chronology_depth_toggle.dart'
    show kDepthViewOffered;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/chronology_service.dart';
import 'package:seeksparks/services/family_tree_service.dart';
import 'package:seeksparks/services/hebrew_kings_service.dart';
import 'package:seeksparks/utils/chronology_explorer.dart';
import 'package:seeksparks/utils/font_catalog.dart';
import 'package:seeksparks/utils/radial_chronology_layout.dart';
import 'package:seeksparks/utils/wheel_default_streams.dart';
import 'package:seeksparks/utils/wheel_text_metrics.dart';
import 'package:seeksparks/utils/wheel_view_layout.dart';
import 'package:seeksparks/widgets/chronology_explorer.dart';
import 'package:seeksparks/widgets/year_digest_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    for (final (family, path) in [
      ('Roboto', 'assets/fonts/Roboto-VariableFont_wdth,wght.ttf'),
      ('NotoSansSC-Sub', 'assets/fonts/NotoSansSC-Sub.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(path))).load();
    }
    await WheelHistoryService.instance.load();
    await ChronologyService.instance.load();
    await HebrewKingsService.instance.load();
    await FamilyTreeService.instance.loadAll();
  });

  setUp(() {
    WheelTextMetrics.resetStatsForTest();
    WheelRenderStats.reset();
  });

  // Loading Roboto does not replace Flutter test's default Ahem face.
  // Select it explicitly while retaining the production CJK fallback;
  // otherwise every Latin glyph becomes a square and overstates bounds.
  TextStyle axisStyle(AxisLabel label) =>
      canvasTextStyle(fontSize: label.onRing ? 10.5 : 11)
          .copyWith(fontFamily: 'Roboto');

  test('all axis text fits the resting wheel in all three locales', () {
    for (final side in [300.0, 320.0, 360.0, 390.0, 600.0, 768.0, 1280.0]) {
      for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
        final labels = planAxisLabels(
          minYear: kMinYear,
          maxYear: kMaxYear,
          tickLabel: (year) => centuryTickLabel(year, locale),
          endLabel: (year) => yearLabel(year, locale),
          endSwing: kAxisEndSwing,
        );
        for (final label in labels) {
          final paragraph =
              WheelTextMetrics.paragraphOf(label.text, axisStyle(label));
          final placement = placeWheelAxisLabel(
            angle: label.angle,
            width: paragraph.maxIntrinsicWidth,
            height: paragraph.height,
            rimRadius: side * rimFractionFor(side),
            clearance: kAxisLabelClearance,
            onRing: label.onRing,
            canvasHalf: side / 2,
          );
          final box = placement.bounds;
          final outside = math.max(math.max(box.left.abs(), box.right.abs()),
              math.max(box.top.abs(), box.bottom.abs()));
          expect(outside, lessThanOrEqualTo(side / 2),
              reason: '$locale, $side px: ${label.text} reaches $outside '
                  'from the centre of a ${side / 2} px canvas radius');
        }
      }
    }
  });

  test('type enlarges through 4x and stays bounded through 120x', () {
    // 12.5 at rest, not 10.5. 「字体感觉太小不是很responsive」 — and the
    // canvas was also asking `scaledChrome`, which multiplies without a
    // floor, so a reader below the default Menu Size was getting 8.4 px
    // where every other small label in the app is floored at 11.
    const restingPx = 12.5;
    double onScreen(double zoom) => restingPx * zoom / wheelLabelScale(zoom);
    expect(onScreen(1), restingPx);
    expect(onScreen(2), greaterThan(onScreen(1)));
    expect(onScreen(4), restingPx * 2);
    for (final zoom in [4.0, 8.0, 40.0, 120.0]) {
      expect(onScreen(zoom), closeTo(restingPx * 2, 0.001));
    }
  });

  test('zoom brings the names back, and selection keeps them at any zoom',
      () {
    // THIS TEST SAID THE OPPOSITE YESTERDAY, and the reversal is the
    // point rather than an embarrassment to be hidden.
    //
    // The owner photographed rotated labels at 381% and 2474% — a fan of
    // `+9 +1 +3` badges and six titles running across each other in four
    // directions. I concluded that zoom was the wrong switch and made
    // the names selection-only. Within a day, with screenshots at 888%
    // and 789% of a chart carrying no text at all:
    // 「你label没有的时候我都看不了对比了」.
    //
    // Both halves were right about different things. Zoom really does
    // not fix text laid along a tangent; it makes more of it, bigger,
    // still pointing every way. But the remedy for that is to stand the
    // words UP, which is what `_uprightSpokeLabel` does now — and
    // magnifying is precisely how a reader asks "what is this one",
    // which the list beside the chart cannot answer because it does not
    // know where the finger is.
    for (final zoom in [0.5, 1.0, 1.59]) {
      expect(wheelShowsEventText(zoom: zoom, selected: false), isFalse,
          reason: 'at rest the marks carry the chart and the list carries '
              'the names; zoom $zoom should not have turned them on');
    }
    for (final zoom in [1.6, 2.0, 12.0, 120.0]) {
      expect(wheelShowsEventText(zoom: zoom, selected: false), isTrue,
          reason: 'zoomed to $zoom the reader is asking what these are, '
              'and the chart answers with nothing');
    }
    for (final zoom in [0.5, 1.0, 1.6, 120.0]) {
      expect(wheelShowsEventText(zoom: zoom, selected: true), isTrue,
          reason: 'the selected record lost its name at zoom $zoom — that '
              'is the one question the list can never answer');
    }
  });

  void expectSeparatedAxis(double side, String locale) {
    final candidates = planAxisLabels(
      minYear: kMinYear,
      maxYear: kMaxYear,
      tickLabel: (year) => centuryTickLabel(year, locale),
      endLabel: (year) => yearLabel(year, locale),
      endSwing: kAxisEndSwing,
    );
    Rect boundsOf(AxisLabel label) {
      final paragraph =
          WheelTextMetrics.paragraphOf(label.text, axisStyle(label));
      return placeWheelAxisLabel(
        angle: label.angle,
        width: paragraph.maxIntrinsicWidth,
        height: paragraph.height,
        rimRadius: side * rimFractionFor(side),
        clearance: kAxisLabelClearance,
        onRing: label.onRing,
        canvasHalf: side / 2,
      ).bounds;
    }

    final labels = retainSeparatedWheelAxisLabels(
        labels: candidates,
        boundsOf: boundsOf,
        canvasBounds: Rect.fromLTRB(-side / 2, -side / 2, side / 2, side / 2));
    // The two range ends, WHEREVER THEY FIT — and where one does not,
    // the reason must be that it does not fit, not that something
    // quietly stopped admitting it.
    //
    // They used to be asserted unconditionally, because they were the
    // only statement of the chart's range. Since 2026-09-15 the hub
    // prints that range itself, at every size, so an end label a 360 px
    // phone cannot hold is a duplicate that does not fit — and the rim
    // is no longer pushed inward to make room for it, which is what had
    // cost the lifespan annulus half its depth.
    final ends = candidates.where((label) => !label.onRing).toList();
    for (final end in ends) {
      final ink = boundsOf(end);
      final inside = ink.left >= -side / 2 &&
          ink.right <= side / 2 &&
          ink.top >= -side / 2 &&
          ink.bottom <= side / 2;
      expect(labels.contains(end), inside,
          reason: '$locale, $side px: ${end.text} '
              '${inside ? 'fits and was dropped' : 'does not fit and was '
                  'drawn anyway'}');
    }
    expect(labels.where((label) => label.onRing), isNotEmpty);
    for (final label in labels) {
      final bounds = boundsOf(label);
      final outside = math.max(math.max(bounds.left.abs(), bounds.right.abs()),
          math.max(bounds.top.abs(), bounds.bottom.abs()));
      expect(outside, lessThanOrEqualTo(side / 2),
          reason:
              '$locale, $side px: ${label.text} must stay inside the canvas');
    }
    for (var i = 0; i < labels.length; i++) {
      for (var j = i + 1; j < labels.length; j++) {
        expect(
            boundsOf(labels[i])
                .inflate(2)
                .overlaps(boundsOf(labels[j]).inflate(2)),
            isFalse,
            reason: '$locale, $side px: ${labels[i].text} and '
                '${labels[j].text} must leave a 4 px gap');
      }
    }
  }

  test('phone axis keeps both ends and separates actual label bounds', () {
    for (final side in [300.0, 320.0, 360.0]) {
      for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
        expectSeparatedAxis(side, locale);
      }
    }
  });

  test('tiny canvas type retains its exact size in the cache', () {
    const first = TextStyle(fontSize: 0.141);
    const second = TextStyle(fontSize: 0.149);
    WheelTextMetrics.widthOf('A', first);
    WheelTextMetrics.widthOf('A', second);
    expect(WheelTextMetrics.layoutsForTest, 2,
        reason: 'rounding both to 0.1 px confuses two sizes that separate '
            'by almost one screen pixel at 120x');
  });

  Future<void> mount(WidgetTester tester, Size size) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    final settings = AppSettings();
    await settings.setFontFamily('Roboto');
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MainProvider()),
        ChangeNotifierProvider(create: (_) => settings),
      ],
      child: MaterialApp(
        theme: ThemeData(
            fontFamily: 'Roboto', fontFamilyFallback: kCjkFontFallback),
        home: const RadialChronologyPage(initialStacked: false),
      ),
    ));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('first scene uses the defaults shared with the event list',
      (tester) async {
    await mount(tester, const Size(360, 800));
    expect(tester.takeException(), isNull);
    expect(WheelRenderStats.sceneBuilds, 1,
        reason: 'the first frame must not lay out all streams before '
            'applying its viewport-sized defaults');
    final wheel = find.byKey(const ValueKey('chronologyWheel'));
    final side = tester.getSize(wheel).width;
    final explorer =
        tester.widget<ChronologyExplorer>(find.byType(ChronologyExplorer));
    // `openingStreamCount`, not `min(ringCapacity, kOpeningStreams)`.
    // 2026-09-16 「另外world应该的default tick」: the opening set is the
    // owner's and is trimmed only by the floor a LAYER is held to, not
    // by the 11 px a ring wants to be comfortable — which on a phone
    // answered four and dropped 全世界, the one lane that was asked for
    // by name.
    final expected = defaultVisibleStreams(
        explorer.data.streams.map((s) => s.id),
        openingStreamCount(side,
            hubFraction: 0.115, bandsFraction: bandsFractionFor(side)));
    final visible = explorer.data.streams
        .where((stream) => !explorer.hiddenStreams.contains(stream.id))
        .map((stream) => stream.id)
        .toSet();
    expect(visible, expected.toSet());
    // Said as a range too, not only as "whatever the helper returns" —
    // the mirror above would agree with the page if BOTH drifted.
    //
    // Five since 2026-09-16, on every canvas a phone has: the spine and
    // 全世界. It used to be three here — 360 dp of window is not 360 dp
    // of wheel — and three was inside the range the owner asked for
    // 「一次别超过3~5个」, but it dropped the lane they then asked for by
    // name. Five is still inside that range.
    expect(visible.length, lessThanOrEqualTo(kOpeningStreams));
    expect(visible.length, greaterThanOrEqualTo(3),
        reason: 'the wheel opened with ${visible.length} rings on a phone');
    final digest = find.byType(YearDigestBar);
    final digestContext = tester.element(digest);
    // This assertion runs outside build, so read the rendered page's
    // settings without subscribing through WbType.of's Provider.watch.
    final settings = digestContext.read<AppSettings>();
    final bodyScale = WbType.resolve(
      fontSize: settings.fontSize,
      lineSpacing: settings.lineSpacing,
      menuScale: settings.menuScale,
      fontFamily: settings.fontFamily,
      platform: Theme.of(digestContext).platform,
    );
    expect(
        tester.getSize(digest).height, closeTo(bodyScale.scaled(76) + 1, 0.01),
        reason: 'the default capacity must reserve the actual digest height');
    final chartSize = chronologyExplorerChartSize(const Size(360, 744));
    expect(
        side,
        closeTo(
            math.min(
                chartSize.width,
                chartSize.height -
                    tester.getSize(digest).height -
                    48 -
                    wheelControlsFooterHeight),
            0.01));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('wheel footer stays outside the chart in portrait and landscape',
      (tester) async {
    for (final size in [const Size(360, 800), const Size(800, 360)]) {
      await mount(tester, size);
      expect(tester.takeException(), isNull);
      final wheel =
          tester.getRect(find.byKey(const ValueKey('chronologyWheel')));
      final footer =
          tester.getRect(find.byKey(const ValueKey('wheelControlsFooter')));
      final digest = tester.getRect(find.byType(YearDigestBar));
      expect(footer.height, wheelControlsFooterHeight);
      expect(wheel.bottom, lessThanOrEqualTo(footer.top));
      expect(wheel.overlaps(footer), isFalse,
          reason: 'the controls must leave the full axis visible at $size');
      expect(footer.bottom, lessThanOrEqualTo(digest.top));
      expect(footer.left, greaterThanOrEqualTo(0));
      expect(footer.right, lessThanOrEqualTo(size.width));
      expect(digest.bottom, lessThanOrEqualTo(size.height));
      expect(wheel.width, greaterThan(0));
      debugPrint(
          'Wheel footer viewport=$size; actual circle side=${wheel.width}');
      for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
        expectSeparatedAxis(wheel.width, locale);
      }
      for (final key in ['wheelLegendControl', 'wheelZoomControls']) {
        final control = tester.getRect(find.byKey(ValueKey(key)));
        expect(control.top, greaterThanOrEqualTo(footer.top));
        expect(control.bottom, lessThanOrEqualTo(footer.bottom));
        expect(control.overlaps(wheel), isFalse);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('phone footer controls are named and have separate touch areas',
      (tester) async {
    // 2026-09-16 「或者我觉得立体其实strip和wheel都没有必要要了」. The
    // depth view still builds, paints and hit-tests -- this test runs
    // again the moment `kDepthViewOffered` goes back to true -- but its
    // door is closed, so a test that presses the door cannot run.
    if (!kDepthViewOffered) {
      markTestSkipped('the depth view is not offered; see kDepthViewOffered');
      return;
    }
    await mount(tester, const Size(360, 800));
    final semantics = tester.ensureSemantics();
    try {
      final settings =
          tester.element(find.byType(RadialChronologyPage)).read<AppSettings>();
      for (final (locale, legendLabel) in [
        ('en', 'Legend'),
        ('zh-Hans', '图例'),
        ('zh-Hant', '圖例'),
      ]) {
        await settings.setLocale(locale);
        for (final scale in [1.0, kMenuScaleMax]) {
          await settings.setMenuScale(scale);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final legend = find.byKey(const ValueKey('wheelLegendControl'));
          final controls = find.byKey(const ValueKey('wheelZoomControls'));
          final mode = find.byKey(const ValueKey('wheelDepth-3d'));
          final modeBox = tester.getRect(mode);
          final legendBox = tester.getRect(legend);
          final controlsBox = tester.getRect(controls);
          expect(legendBox.height, greaterThanOrEqualTo(44));
          expect(legendBox.width, greaterThanOrEqualTo(44));
          expect(legendBox.left, greaterThanOrEqualTo(0));
          expect(controlsBox.right, lessThanOrEqualTo(360));
          expect(modeBox.width, greaterThanOrEqualTo(44));
          expect(modeBox.height, greaterThanOrEqualTo(44));
          expect(tester.getSemantics(mode).label, isNotEmpty);
          expect(modeBox.overlaps(legendBox), isFalse);
          expect(modeBox.overlaps(controlsBox), isFalse,
              reason: 'the shared mode row stays above both chart forms');
          expect(legendBox.right + 4, lessThanOrEqualTo(controlsBox.left),
              reason: '$locale at menu scale $scale must leave room between '
                  'the legend and zoom controls');
          final label =
              find.descendant(of: legend, matching: find.text(legendLabel));
          expect(label, findsOneWidget);
          expect(legendBox.contains(tester.getRect(label).topLeft), isTrue);
          expect(legendBox.contains(tester.getRect(label).bottomRight), isTrue);
          expect(tester.getSemantics(legend).label, legendLabel);
          for (final key in [
            'wheelZoomOutControl',
            'wheelZoomInControl',
            'wheelResetControl',
          ]) {
            final target = find.byKey(ValueKey(key));
            final box = tester.getRect(target);
            expect(box.width, greaterThanOrEqualTo(44));
            expect(box.height, greaterThanOrEqualTo(44));
            expect(tester.getSemantics(target).label, isNotEmpty);
          }
        }
      }
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('real wheel drawing is warm and cursor/pan reuse the scene',
      (tester) async {
    await mount(tester, const Size(1440, 900));
    expect(tester.takeException(), isNull);
    final cold = WheelTextMetrics.layoutsForTest;
    expect(cold, greaterThan(0));
    final plans = WheelRenderStats.sceneBuilds;
    final boundary = find.byKey(const ValueKey('wheelSceneBoundary'));
    final paint = tester.widget<CustomPaint>(
        find.descendant(of: boundary, matching: find.byType(CustomPaint)));
    final size = tester.getSize(boundary);

    WheelTextMetrics.zeroCounterForTest();
    final recorder = ui.PictureRecorder();
    paint.painter!.paint(Canvas(recorder), size);
    recorder.endRecording().dispose();
    expect(WheelTextMetrics.layoutsForTest, 0,
        reason: 'the actual painter, including axis and radial runs, '
            'must reuse its paragraphs on a warm frame');

    final scrubber =
        tester.widget<Slider>(find.byKey(const ValueKey('chronoYearScrubber')));
    scrubber.onChanged!(0);
    await tester.pump();
    expect(WheelRenderStats.sceneBuilds, plans);
    expect(WheelTextMetrics.layoutsForTest, 0,
        reason: 'moving the cursor must not repeat label fitting');

    final viewer =
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    viewer.transformationController!.value =
        viewer.transformationController!.value.clone()
          ..translateByDouble(12, 0, 0, 1);
    await tester.pump();
    expect(WheelRenderStats.sceneBuilds, plans);
    expect(WheelTextMetrics.layoutsForTest, 0);
    debugPrint('Wheel real-page layouts: cold=$cold; warm=0; '
        'cursor=0; pan=0; initial scenes=$plans');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
