/// The year cursor on both chronology forms — the rule on the strip, the
/// spoke on the wheel, and the one [YearDigestBar] they share.
///
/// WHY THIS FILE EXISTS AT ALL, given that both pages already have a test
/// file that taps them. Neither of those files can see this feature: the
/// rule and the spoke are the first pieces of either chart that are real
/// WIDGETS rather than paint on a canvas, and the readout under them is
/// the first row of chrome whose text a finder can actually read. So the
/// behaviour is newly visible from outside, and newly worth pinning.
///
/// THE TEST WITH TEETH IS THE DRAG. Both pages place the cursor from a
/// raw `Listener` on pointer-UP, guarded by `kTouchSlop`, and both carry
/// a comment saying why: a `TapGestureRecognizer` fires `onTapDown` when
/// it wins the arena OR after 100 ms, so the obvious implementation makes
/// press-and-hold set the cursor and a quick tap do nothing — a bug found
/// on a device and NOT reproducible from a tap test, because
/// `tester.tapAt` sends down and up with nothing in between and therefore
/// passes under the correct implementation and the broken one alike. The
/// drag tests below are the ones that can tell them apart.
library;

import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/chronology.dart';
import 'package:seeksparks/models/hebrew_king.dart';
import 'package:seeksparks/models/strip_lanes.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart'
    show RadialChronologyPage, kDrawnTradition, kMaxYear, kMinYear, yearLabel;
import 'package:seeksparks/pages/strip_chronology_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/chronology_service.dart';
import 'package:seeksparks/services/hebrew_kings_service.dart';
import 'package:seeksparks/services/timeline_service.dart';
import 'package:seeksparks/utils/radial_chronology_layout.dart'
    show angleForSpan, startRad, sweepRad;
import 'package:seeksparks/utils/strip_chronology_layout.dart';
import 'package:seeksparks/widgets/strip_chronology_painter.dart';
import 'package:seeksparks/widgets/year_digest_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WheelHistoryData data;
  late List<HebrewKing> kings;
  late List<Patriarch> patriarchs;
  late int creationYear;

  setUpAll(() async {
    // Real I/O never completes inside a widget test's fake-async zone, so
    // every service either page's `initState` awaits is warmed here and
    // resolves from the cache — the same reason both sibling page tests
    // do it.
    data = await WheelHistoryService.instance.load();
    await ChronologyService.instance.load();
    kings = HebrewKingsService.instance.cached!.kings;
    patriarchs = ChronologyService.instance.cached!.patriarchs;
    creationYear = TimelineService.instance.meta.creation!.year;
  });

  Future<void> pumpPage(WidgetTester tester, Widget page, Size size) async {
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

  Future<void> pumpStrip(WidgetTester tester,
          [Size size = const Size(1440, 900)]) =>
      pumpPage(tester, const StripChronologyPage(), size);

  Future<void> pumpWheel(WidgetTester tester,
          [Size size = const Size(1440, 900)]) =>
      pumpPage(tester, const RadialChronologyPage(), size);

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  }

  ScrollableState scrollableFor(WidgetTester tester, Key key) =>
      tester.state<ScrollableState>(find
          .descendant(of: find.byKey(key), matching: find.byType(Scrollable))
          .first);

  /// The page's own row layout, rebuilt from the same PUBLIC functions the
  /// page calls — the discipline `strip_chronology_page_test.dart` uses,
  /// because `_buildRows` is private to the page.
  List<StripRow> rowsFor(double pxPerYear) {
    final lanes = buildStripLanes(
      wheel: data,
      kings: kings,
      familyTreePeople: const [],
      patriarchs: patriarchs,
      tradition: kDrawnTradition,
      creationYear: creationYear,
      pxPerYear: pxPerYear,
    );
    final laneH = stripLaneHeightPx(1);
    final headH = stripHeadingHeightPx(1);
    final rows = <StripRow>[];
    var y = 0.0;
    StripLaneKind? lastKind;
    for (final lane in lanes) {
      if (lane.kind != lastKind) {
        rows.add(StripRow.heading('_', top: y, height: headH));
        y += headH;
        lastKind = lane.kind;
      }
      rows.add(StripRow.lane(lane, top: y, height: laneH));
      y += laneH;
    }
    return rows;
  }

  StripRow rowContaining(List<StripRow> rows, String spanId) {
    for (final row in rows) {
      if (row.isHeading) continue;
      for (final s in row.lane!.spans) {
        if (s.id == spanId) return row;
      }
    }
    fail('no row carries $spanId');
  }

  /// Scroll the strip's two real, draggable `Scrollable`s so that content
  /// point ([contentX], [contentY]) is inside the viewport, and answer
  /// with its GLOBAL position.
  ///
  /// A `SingleChildScrollView` lays its child out in full, but the
  /// `Viewport` still clips HIT TESTING to the visible window — a point
  /// off-screen hits nothing even though its on-screen rectangle can
  /// still be asked for. `getTopLeft` reports the position the scroll
  /// just produced, so content coordinates need nothing subtracted.
  Future<Offset> revealStripPoint(
      WidgetTester tester, double contentX, double contentY) async {
    final h = scrollableFor(tester, const ValueKey('stripHScroll'));
    h.position.jumpTo((contentX - h.position.viewportDimension / 2)
        .clamp(0.0, h.position.maxScrollExtent));
    final v = scrollableFor(tester, const ValueKey('stripVScroll'));
    v.position.jumpTo((contentY - v.position.viewportDimension / 2)
        .clamp(0.0, v.position.maxScrollExtent));
    await tester.pump();
    return tester.getTopLeft(find.byKey(const ValueKey('chronologyStrip'))) +
        Offset(contentX, contentY);
  }

  String readout(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const ValueKey('chronoYearReadout')))
      .data!;

  String sheetText(WidgetTester tester) => tester
      .renderObjectList<RenderParagraph>(find.byType(RichText))
      .map((p) => p.text.toPlainText())
      .join('\n');

  /// Press, travel further than the slop, lift. The travel is broken into
  /// steps so the scroll views underneath react the way a real finger
  /// makes them react, rather than teleporting once.
  Future<void> dragFromBy(WidgetTester tester, Offset from, Offset by) async {
    assert(by.distance > kTouchSlop);
    final gesture = await tester.startGesture(from);
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(by / 4);
      await tester.pump();
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 400));
  }

  // ── the strip: a rule at an x ───────────────────────────────────────

  /// The year is computed through `yearForX` — the page's own inverse —
  /// rather than written in, so a change to `kStripMinYear` or to the
  /// opening zoom moves the expectation with the page instead of leaving
  /// a stale string here to re-baseline.
  ///
  /// Tapped on the first row, which `_buildRows` always emits as a
  /// heading, so this test is about the cursor alone: `_handleTap` opens
  /// nothing on a heading.
  testWidgets(
      'a tap on the strip draws the rule and names the year that '
      'x maps to', (tester) async {
    await pumpStrip(tester);
    expect(find.byKey(const ValueKey('stripYearCursor')), findsNothing,
        reason: 'an untouched strip must show no rule — a line where '
            'nobody pointed is a claim about a year the reader did not '
            'choose');

    final contentX = xForYear(-586, kStripInitialPxPerYear);
    final expected = yearForX(contentX, kStripInitialPxPerYear).round();
    await tester.tapAt(await revealStripPoint(tester, contentX, 4));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('stripYearCursor')), findsOneWidget);
    expect(readout(tester), yearLabel(expected, 'zh-Hans'));
    await unmount(tester);
  });

  /// THE ONE WITH TEETH — see this file's own library note. A tap test
  /// passes whether the cursor commits on pointer-DOWN or on a slop-
  /// guarded pointer-UP; only a press that TRAVELS can tell the two
  /// apart, and travelling is exactly what a reader scrolling the strip
  /// does all day.
  testWidgets('dragging the strip scrolls it without leaving a rule behind',
      (tester) async {
    await pumpStrip(tester);
    final contentX = xForYear(-586, kStripInitialPxPerYear);
    final from = await revealStripPoint(tester, contentX, 4);
    final before =
        scrollableFor(tester, const ValueKey('stripHScroll')).position.pixels;

    await dragFromBy(tester, from, const Offset(-120, 0));

    expect(tester.takeException(), isNull);
    expect(
        scrollableFor(tester, const ValueKey('stripHScroll')).position.pixels,
        isNot(before),
        reason: 'the drag has to have actually scrolled something, or the '
            'absence of a rule below proves nothing about the slop guard');
    expect(find.byKey(const ValueKey('stripYearCursor')), findsNothing);
    // The readout row is permanent — see [YearDigestBar]'s doc on why
    // it may not appear and disappear. "No cursor" is the hint showing
    // in place of a year, not the row being gone.
    expect(find.byKey(const ValueKey('chronoYearHint')), findsOneWidget);
    expect(find.byKey(const ValueKey('chronoYearReadout')), findsNothing);

    // And the same page, at the same kind of point, still answers a press
    // that does NOT travel — otherwise "no rule appeared" could just as
    // well mean the gesture never reached the `Listener` at all, and this
    // test would be green for the wrong reason.
    await tester.tapAt(await revealStripPoint(tester, contentX, 4));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('stripYearCursor')), findsOneWidget);
    await unmount(tester);
  });

  /// BOTH, FROM ONE TAP. The `Listener` sits outside the gesture arena
  /// precisely so it cannot be robbed of the press by the page's own
  /// `GestureDetector` — pointing at a record has to mean "open it" AND
  /// "that year", not one or the other.
  ///
  /// Zimri because his reign is zero years long (`reignStart ==
  /// reignEnd`), which makes the tapped x an exact year rather than
  /// somewhere inside a bar: the readout can then be checked against the
  /// king's own reign year and not merely against arithmetic.
  testWidgets(
      'tapping a king opens his sheet and lands the rule on his '
      'reign year', (tester) async {
    final zimri = kings.firstWhere((k) => k.id == 'zimri');
    expect(zimri.reignStart, zimri.reignEnd,
        reason: 'the corpus moved — this test wants a reign whose start '
            'and end share one x');

    await pumpStrip(tester);
    final row = rowContaining(
        rowsFor(kStripInitialPxPerYear), '$kStripKingPrefix${zimri.id}');
    final contentX = xForYear(zimri.reignStart, kStripInitialPxPerYear);

    await tester.tapAt(
        await revealStripPoint(tester, contentX, row.top + row.height / 2));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.byType(BottomSheet), findsOneWidget,
        reason: 'the raw Listener must not have swallowed the press the '
            'tap detector needs');
    expect(sheetText(tester), contains(zimri.nameFor('zh-Hans')));
    expect(find.byKey(const ValueKey('stripYearCursor')), findsOneWidget,
        reason: 'and the tap detector must not have swallowed the press '
            'the Listener needs');
    expect(readout(tester), yearLabel(zimri.reignStart, 'zh-Hans'));
    await unmount(tester);
  });

  /// The ruler has a `Listener` of its OWN, on its own separately-driven
  /// scroll view — a second code path, not the same one reached twice.
  /// It is also the row a reader asking "which year is this" points at
  /// first, so a ruler that ignored the press would be the odd one out.
  testWidgets('a tap on the sticky ruler places the rule too', (tester) async {
    await pumpStrip(tester);
    final contentX = xForYear(1000, kStripInitialPxPerYear);
    final expected = yearForX(contentX, kStripInitialPxPerYear).round();

    final h = scrollableFor(tester, const ValueKey('stripHScroll'));
    h.position.jumpTo((contentX - h.position.viewportDimension / 2)
        .clamp(0.0, h.position.maxScrollExtent));
    await tester.pump();

    // The ruler's content origin, found through its painter: the row has
    // no key of its own, and the painter is what defines the box the
    // Listener measures `localPosition` against.
    final rulerPaint = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is StripRulerPainter);
    expect(rulerPaint, findsOneWidget);
    final rect = tester.getRect(rulerPaint);
    await tester.tapAt(rect.topLeft + Offset(contentX, rect.height / 2));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('stripYearCursor')), findsOneWidget);
    expect(readout(tester), yearLabel(expected, 'zh-Hans'));
    await unmount(tester);
  });

  /// Null is a real state on both pages, not "year zero", so closing the
  /// readout has to take the RULE with it — a bar dismissed while the
  /// line stayed would leave the chart marked at a year nothing on screen
  /// still names.
  testWidgets('closing the readout clears the rule as well as the bar',
      (tester) async {
    await pumpStrip(tester);
    final contentX = xForYear(-586, kStripInitialPxPerYear);
    await tester.tapAt(await revealStripPoint(tester, contentX, 4));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('chronoYearReadout')), findsOneWidget);

    await tester.tap(find.descendant(
        of: find.byType(YearDigestBar), matching: find.byIcon(Icons.close)));
    await tester.pump(const Duration(milliseconds: 400));

    // The readout row is permanent — see [YearDigestBar]'s doc on why
    // it may not appear and disappear. "No cursor" is the hint showing
    // in place of a year, not the row being gone.
    expect(find.byKey(const ValueKey('chronoYearHint')), findsOneWidget);
    expect(find.byKey(const ValueKey('chronoYearReadout')), findsNothing);
    expect(find.byKey(const ValueKey('stripYearCursor')), findsNothing);
    await unmount(tester);
  });

  // ── the wheel: a spoke at an angle ──────────────────────────────────

  /// A point at [year]'s own angle, [rFrac] of the side out from the
  /// centre. Built through `angleForSpan` — the public forward function
  /// the page's private `_yearAt` claims to invert — so the assertion is
  /// a round trip through the real geometry rather than a guessed pixel.
  Offset wheelPointFor(Rect wheel, double angle, double rFrac) =>
      wheel.center +
      Offset(math.cos(angle), math.sin(angle)) * (wheel.width * rFrac);

  testWidgets(
      'a tap inside the wheel\'s sweep draws the spoke and names '
      'that angle\'s year', (tester) async {
    await pumpWheel(tester);
    expect(find.byKey(const ValueKey('wheelYearCursor')), findsNothing);

    final wheel = tester.getRect(find.byKey(const ValueKey('chronologyWheel')));
    const year = -586;
    await tester.tapAt(
        wheelPointFor(wheel, angleForSpan(year, kMinYear, kMaxYear), 0.35));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('wheelYearCursor')), findsOneWidget);
    expect(readout(tester), yearLabel(year, 'zh-Hans'),
        reason: 'radius is the LAYER on this wheel and angle alone is the '
            'year, so the spoke must land on the year the angle was '
            'built from');
    await unmount(tester);
  });

  /// The wheel is a 320-degree sweep with a 40-degree gap, and the gap is
  /// blank paper. Blank paper names no year — the same rule `_handleTap`
  /// already applies there — so `_yearAt` returns null and nothing is
  /// placed. Without this, an implementation that let the angle wrap
  /// would quietly report the gap as either end of history.
  testWidgets('a tap in the wheel\'s blank wedge places nothing',
      (tester) async {
    await pumpWheel(tester);
    final wheel = tester.getRect(find.byKey(const ValueKey('chronologyWheel')));
    // The middle of the gap, computed from the sweep itself rather than
    // eyeballed: half a turn past the end of the sweep is exactly where
    // the wedge is widest.
    final gapMid = startRad + sweepRad + (2 * math.pi - sweepRad) / 2;

    await tester.tapAt(wheelPointFor(wheel, gapMid, 0.35));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('wheelYearCursor')), findsNothing);
    // The readout row is permanent — see [YearDigestBar]'s doc on why
    // it may not appear and disappear. "No cursor" is the hint showing
    // in place of a year, not the row being gone.
    expect(find.byKey(const ValueKey('chronoYearHint')), findsOneWidget);
    expect(find.byKey(const ValueKey('chronoYearReadout')), findsNothing);
    await unmount(tester);
  });

  /// The wheel's half of the drag guard. Its `Listener` sits INSIDE the
  /// `InteractiveViewer`, so every pan a reader makes is a press that
  /// travels across the chart and lifts on some other year — precisely
  /// the gesture that must not leave a spoke behind.
  testWidgets('panning the wheel does not leave a spoke behind',
      (tester) async {
    await pumpWheel(tester);
    final wheel = tester.getRect(find.byKey(const ValueKey('chronologyWheel')));
    final from =
        wheelPointFor(wheel, angleForSpan(-586, kMinYear, kMaxYear), 0.35);

    await dragFromBy(tester, from, const Offset(-90, -60));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('wheelYearCursor')), findsNothing);
    // The readout row is permanent — see [YearDigestBar]'s doc on why
    // it may not appear and disappear. "No cursor" is the hint showing
    // in place of a year, not the row being gone.
    expect(find.byKey(const ValueKey('chronoYearHint')), findsOneWidget);
    expect(find.byKey(const ValueKey('chronoYearReadout')), findsNothing);

    // The same guard against a false green as on the strip: a press that
    // stays put, on the wheel the pan just left behind, still places a
    // spoke. Its year is not checked — the `InteractiveViewer` has moved
    // the chart under the point, which is the whole reason the slop is
    // measured in global coordinates.
    await tester.tapAt(from);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('wheelYearCursor')), findsOneWidget);
    await unmount(tester);
  });
}
