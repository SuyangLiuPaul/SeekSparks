/// The chronology strip, mounted against the real asset and TAPPED —
/// the strip's own `radial_chronology_page_test.dart`.
///
/// Canvas text leaves no widget and no semantics node, so a sweep like
/// that file's cannot read a label off the strip's three painters. What
/// CAN be pinned from outside them: that a tap resolves through the
/// same geometry the painters draw from (`nearestSpanAt` on the exact
/// `xForYear` position `buildStripLanes` placed a span at) to the
/// correct detail sheet; that the four scroll surfaces the page wires
/// up by hand (`docs/strip-painter-spec.md` §1) stay in step; and that
/// the page claims and releases the address bar the way the wheel does
/// (`UrlClaim`'s own doc — required since a `pushReplacement` between
/// the two forms fires `didReplace`, which `_UrlRestoreObserver` does
/// not watch).
library;

import 'dart:io';

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
    show RadialChronologyPage, kDrawnTradition;
import 'package:seeksparks/pages/strip_chronology_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/chronology_service.dart';
import 'package:seeksparks/services/hebrew_kings_service.dart';
import 'package:seeksparks/services/timeline_service.dart';
import 'package:seeksparks/utils/strip_chronology_layout.dart';
import 'package:seeksparks/widgets/strip_chronology_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WheelHistoryData data;
  late List<HebrewKing> kings;
  late List<Patriarch> patriarchs;
  late int creationYear;

  setUpAll(() async {
    // Real I/O never completes inside a widget test's fake-async zone;
    // `WheelHistoryService.load` awaits `HebrewKingsService` and
    // `ChronologyService` itself, so warming it here is enough to let
    // the page's own `initState` resolve from the cache — the same
    // reason `radial_chronology_page_test.dart` does it.
    data = await WheelHistoryService.instance.load();
    kings = HebrewKingsService.instance.cached!.kings;
    patriarchs = ChronologyService.instance.cached!.patriarchs;
    creationYear = TimelineService.instance.meta.creation!.year;
  });

  /// The page's own row layout, rebuilt here from the same PUBLIC
  /// functions the page calls (`buildStripLanes`, `stripLaneHeightPx`,
  /// `stripHeadingHeightPx`) rather than duplicating a private method —
  /// the same discipline `radial_chronology_page_test.dart` uses when
  /// it restates the wheel's own geometry fractions because the real
  /// ones are private to the page.
  List<StripRow> rowsFor(double pxPerYear) {
    final lanes = buildStripLanes(
      wheel: data,
      kings: kings,
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

  /// Where one span's row sits, at the page's own starting zoom — the
  /// widest step, `kStripZoomSteps.first`, which is what the page opens
  /// on (`_pxPerYear = kStripZoomSteps.first`).
  StripRow rowContaining(List<StripRow> rows, String spanId) {
    for (final row in rows) {
      if (row.isHeading) continue;
      for (final s in row.lane!.spans) {
        if (s.id == spanId) return row;
      }
    }
    fail('no row carries $spanId');
  }

  Future<void> pump(WidgetTester tester, Size size) async {
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
        child: const MaterialApp(home: StripChronologyPage()),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// The `Scrollable` a keyed `SingleChildScrollView` actually builds —
  /// the key finds the wrapper widget, not the state-carrying element,
  /// the same descent `radial_chronology_page_test.dart` uses to reach
  /// a `BottomSheet`'s own `Scrollable`. `.first`, because the
  /// horizontal pane's `SingleChildScrollView` has the VERTICAL one
  /// nested inside it (§1's "time outer, lanes inner"), so a plain
  /// descendant search on the outer key also finds the inner
  /// `Scrollable` — pre-order traversal visits the outer one first.
  ScrollableState scrollableFor(WidgetTester tester, Key key) =>
      tester.state<ScrollableState>(find
          .descendant(of: find.byKey(key), matching: find.byType(Scrollable))
          .first);

  /// Scroll the strip's real, draggable vertical `Scrollable` so
  /// [contentY] is inside the viewport, then tap it at [contentX].
  ///
  /// The content `SizedBox` is never virtualised (a `SingleChildScroll
  /// View`'s child is laid out in full), but `Viewport` still clips HIT
  /// TESTING to what is actually visible, so a point outside the
  /// current scroll window hits nothing even though the widget's own
  /// on-screen rectangle can still be asked for. `tester.getTopLeft`
  /// answers with the CURRENT on-screen position, already net of
  /// whatever the scroll just did — content coordinates and this
  /// widget's local coordinates are the same box, so nothing else has
  /// to be subtracted.
  Future<void> tapContent(
      WidgetTester tester, double contentX, double contentY) async {
    final hScrollable = scrollableFor(tester, const ValueKey('stripHScroll'));
    final hTarget = (contentX - hScrollable.position.viewportDimension / 2)
        .clamp(0.0, hScrollable.position.maxScrollExtent);
    hScrollable.position.jumpTo(hTarget);

    final vScrollable = scrollableFor(tester, const ValueKey('stripVScroll'));
    final vTarget = (contentY - vScrollable.position.viewportDimension / 2)
        .clamp(0.0, vScrollable.position.maxScrollExtent);
    vScrollable.position.jumpTo(vTarget);
    await tester.pump();

    final topLeft =
        tester.getTopLeft(find.byKey(const ValueKey('chronologyStrip')));
    await tester.tapAt(topLeft + Offset(contentX, contentY));
    await tester.pump(const Duration(milliseconds: 400));
  }

  String sheetText(WidgetTester tester) => tester
      .renderObjectList<RenderParagraph>(find.byType(RichText))
      .map((p) => p.text.toPlainText())
      .join('\n');

  testWidgets('the strip builds and paints against the real asset',
      (tester) async {
    await pump(tester, const Size(1440, 900));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('chronologyStrip')), findsOneWidget);
    await unmount(tester);
  });

  /// THE ONE-YEAR (ZERO-LENGTH) REIGN. `strip_chronology_layout.dart`'s
  /// own doc names Zimri as one of the four spans that are 0.00 px wide
  /// at every canvas and every zoom — `hebrew_kings.json` confirms
  /// `reignStart == reignEnd == -885`. Rule 1 says this bar is drawn as
  /// a DOT, never stretched, and its hit target still has to reach a
  /// finger via `hitTargetFor`/`nearestSpanAt`'s own widening.
  testWidgets('a tap on a one-year reign opens that king\'s sheet',
      (tester) async {
    final zimri = kings.firstWhere((k) => k.id == 'zimri');
    expect(zimri.reignStart, zimri.reignEnd,
        reason: 'the corpus moved — this test needs a real zero-length '
            'reign to prove rule 1');

    await pump(tester, const Size(1440, 900));
    final rows = rowsFor(kStripZoomSteps.first);
    final row = rowContaining(rows, '$kStripKingPrefix${zimri.id}');
    final x = xForYear(zimri.reignStart, kStripZoomSteps.first);

    await tapContent(tester, x, row.top + row.height / 2);
    expect(tester.takeException(), isNull,
        reason: 'a tap handler is not a build — `WbType.of`/`WbColors.of` '
            'watch and throw if resolved outside one');
    expect(find.byType(BottomSheet), findsOneWidget,
        reason: 'the dot still needs a reachable target — rule 1 widens '
            'it without widening the ink');
    expect(sheetText(tester), contains(zimri.nameFor('zh-Hans')));
    await unmount(tester);
  });

  /// THE SAME KING, REACHABLE AT EVERY STEP OF THE LADDER. Lane
  /// assignment moves with zoom (`strip_lanes.dart`'s own doc: it is a
  /// rendering decision, not a data one) — a span may land in a
  /// different SUB-LANE at each `pxPerYear`, and that is by design. What
  /// must not move is whether the span can still be found and opened:
  /// this taps the same king at the FIRST and LAST rungs of
  /// `kStripZoomSteps` and asks for the same sheet both times, which is
  /// the strip's own version of "changing zoom does not change which
  /// lane a span is in more than the geometry requires."
  testWidgets('the same king opens at both ends of the zoom ladder',
      (tester) async {
    final zimri = kings.firstWhere((k) => k.id == 'zimri');
    await pump(tester, const Size(1440, 900));

    for (final zoom in [kStripZoomSteps.first, kStripZoomSteps.last]) {
      final rows = rowsFor(zoom);
      final row = rowContaining(rows, '$kStripKingPrefix${zimri.id}');
      final x = xForYear(zimri.reignStart, zoom);

      // Zoom the page itself to `zoom` via its own control, not by
      // reaching into private state — the '+' button steps one rung of
      // `kStripZoomSteps` per tap.
      final steps = kStripZoomSteps.indexOf(zoom) -
          kStripZoomSteps.indexOf(kStripZoomSteps.first);
      for (var i = 0; i < steps.abs(); i++) {
        await tester.tap(find.byTooltip('放大'));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 200));

      await tapContent(tester, x, row.top + row.height / 2);
      expect(tester.takeException(), isNull);
      expect(find.byType(BottomSheet), findsOneWidget,
          reason: 'zimri was not reachable at ${zoom}px/yr');
      expect(sheetText(tester), contains(zimri.nameFor('zh-Hans')));
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pump(const Duration(milliseconds: 300));
    }
    await unmount(tester);
  });

  /// THE STICKY RULER STAYS ALIGNED THROUGH A HORIZONTAL SCROLL. The
  /// ruler's own `SingleChildScrollView` is driven programmatically —
  /// `_onHScroll` mirrors it onto the real, draggable one — so this
  /// pins the mirror rather than the drag itself: if the listener were
  /// ever dropped, the ruler would freeze while the lanes moved under
  /// it, which is exactly the "collision the wheel spent three phases
  /// fixing" the sticky ruler exists to make structurally impossible
  /// (`docs/strip-painter-spec.md` §4).
  testWidgets('the sticky ruler tracks the content\'s own horizontal scroll',
      (tester) async {
    await pump(tester, const Size(900, 700));
    final content = scrollableFor(tester, const ValueKey('stripHScroll'));
    final ruler = scrollableFor(tester, const ValueKey('stripRulerHScroll'));

    expect(content.position.pixels, ruler.position.pixels);
    content.position.jumpTo(37);
    await tester.pump();
    expect(ruler.position.pixels, 37,
        reason: 'the ruler must follow the content it sits above');
    await unmount(tester);
  });

  /// THE STICKY LANE-HEADER COLUMN STAYS ALIGNED THROUGH A VERTICAL
  /// SCROLL. The header column's own vertical row heights are built
  /// from the SAME [StripRow] list the lanes canvas paints from, so a
  /// scroll that moves the content by N px must move the header column
  /// by the same N — otherwise a reader would see a lane's bars sitting
  /// beside the wrong name.
  testWidgets(
      'the sticky lane-header column tracks the content\'s own vertical '
      'scroll', (tester) async {
    await pump(tester, const Size(900, 700));
    final content = scrollableFor(tester, const ValueKey('stripVScroll'));
    final header = scrollableFor(tester, const ValueKey('stripHeaderVScroll'));

    expect(content.position.pixels, header.position.pixels);
    content.position.jumpTo(53);
    await tester.pump();
    expect(header.position.pixels, 53);
    await unmount(tester);
  });

  /// AN OFF-SCREEN LANE GROUP RAISES ITS INDICATOR. At rest the strip
  /// opens scrolled to the very top, where nothing is above it — no
  /// indicator — and, given how many rows the real corpus needs (298
  /// events in the densest window alone, `strip_chronology_layout.dart`'s
  /// own worked example), certainly more below. Scrolling to the very
  /// bottom must flip both.
  testWidgets('an off-screen lane group raises its indicator', (tester) async {
    await pump(tester, const Size(900, 500));
    expect(find.text('下方还有更多'), findsOneWidget,
        reason: 'the corpus needs far more rows than a 500 px pane shows '
            'at rest, and nothing says so');
    expect(find.text('上方还有更多'), findsNothing,
        reason: 'the strip opens scrolled to its own top — there is '
            'nothing above it yet');

    final content = scrollableFor(tester, const ValueKey('stripVScroll'));
    content.position.jumpTo(content.position.maxScrollExtent);
    await tester.pump();

    expect(find.text('上方还有更多'), findsOneWidget,
        reason: 'scrolled to the bottom, everything above is off-screen '
            'and nothing said so');
    expect(find.text('下方还有更多'), findsNothing,
        reason: 'at the true bottom there is nothing further below');
    await unmount(tester);
  });

  /// THE PAGE CLAIMS THE ADDRESS BAR ON OPEN AND RELEASES IT ON CLOSE —
  /// the wheel's own contract (`radial_chronology_page_test.dart`
  /// asserts the same two calls exist in that page's own source), and
  /// load-bearing here specifically because the view switch moves
  /// between the two forms with `pushReplacement`, which fires
  /// `didReplace` — the one route-change `_UrlRestoreObserver`
  /// (`main.dart`) does not watch. Only the page's own claim keeps the
  /// address bar honest across that switch.
  test(
      'the page claims kStripUrlPath on open and releases it on close, '
      'the same two calls the wheel makes', () {
    expect(kStripUrlPath, '/strip');
    final src = File('lib/pages/strip_chronology_page.dart').readAsStringSync();
    expect(RegExp(r'claimUrl\(').allMatches(src).length, 2,
        reason: 'the page claims the URL on open and releases it on '
            'close, and nothing else may write the address bar');
    expect(src, contains('claimUrl(kStripUrlPath, owner: this)'));
    expect(src, contains('claimUrl(null, owner: this)'));
    expect(src, isNot(contains("claimUrl('")),
        reason: 'the path must stay the constant, never a literal');
  });

  /// THE VIEW SWITCH IS A ROUND TRIP. The strip's own `SegmentedButton`
  /// has to offer 'wheel' selected as 'strip' — this page's own side of
  /// the pair the wheel's `radial_chronology_page.dart` already carries.
  testWidgets('the view switch can send a reader back to the wheel',
      (tester) async {
    await pump(tester, const Size(1440, 900));
    expect(find.text('轮盘'), findsOneWidget,
        reason: 'the switch must offer the wheel as an option, in the '
            'same string the wheel\'s own switch uses');
    await tester.tap(find.text('轮盘'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    // `UrlSyncService`'s claim is a no-op stub off the web target
    // (`url_sync_service_stub.dart`), so the runtime claim itself is
    // pinned at the source level above; what a widget test CAN see is
    // that the switch actually navigated, which is the other half of
    // the contract — a claim with no page behind it would be a lie too.
    expect(find.byType(RadialChronologyPage), findsOneWidget,
        reason: 'tapping the wheel segment must replace this page with '
            'the wheel, the same pushReplacement the wheel\'s own switch '
            'does in reverse');
    await unmount(tester);
  });
}
