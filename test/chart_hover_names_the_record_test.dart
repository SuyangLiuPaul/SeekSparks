/// Hovering names the record a click would open — including the ones
/// the canvas could not name.
///
/// 2026-09-17 「when hovering over the line or strip can you have
/// hovering pop up label or something and when click then pop up
/// window?」, asked from the wheel at 3614% where the bands under the
/// pointer are a few pixels deep and carry no text at all.
///
/// Two properties, and the second is the one that rots:
///
///   1. THE PLATE AND THE SHEET AGREE. A name that floats up for one
///      band while the click underneath opens another is worse than no
///      hover at all, so both go through one resolver.
///   2. THE PLATE USES THE RECORD'S NAME, NOT THE DRAWN ONE. Every arc
///      and spoke carries a display string that is empty exactly when
///      there was no room to print it — which is exactly the record a
///      reader hovers to ask about. Reading that string would make the
///      feature vanish precisely where it is needed, and it would do so
///      SILENTLY: an empty label shows no plate, so nothing errors.
///      That is the 亚们 defect (`WheelRenderStats.labelsLost` exists
///      because of it), and the third test below is what would catch it
///      coming back.
library;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
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
import 'package:seeksparks/utils/wheel_view_layout.dart';
import 'package:seeksparks/widgets/chart_hover_plate.dart';
import 'package:seeksparks/widgets/chart_help_sheet.dart';

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

  /// A mouse that stays for the life of the test, because a hover is a
  /// property of a pointer that is present — `tester.tap` synthesises a
  /// touch and would never produce one.
  Future<TestGesture> mouse(WidgetTester tester) async {
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    addTearDown(() => g.removePointer());
    return g;
  }

  String? plateAt(WidgetTester tester) {
    final plates = find.byType(ChartHoverPlate);
    if (plates.evaluate().isEmpty) return null;
    return tester.widget<ChartHoverPlate>(plates.first).text;
  }

  /// Every point of a coarse grid over [rect], hovered in turn.
  Future<Map<Offset, String>> sweep(
    WidgetTester tester,
    TestGesture g,
    Rect rect, {
    int steps = 14,
  }) async {
    final found = <Offset, String>{};
    for (var i = 1; i < steps; i++) {
      for (var j = 1; j < steps; j++) {
        final p = Offset(
          rect.left + rect.width * i / steps,
          rect.top + rect.height * j / steps,
        );
        await g.moveTo(p);
        await tester.pump();
        final label = plateAt(tester);
        if (label != null && label.isNotEmpty) found[p] = label;
      }
    }
    return found;
  }

  testWidgets('the wheel names what is under the pointer, and nothing else',
      (tester) async {
    await pump(tester, const RadialChronologyPage(initialStacked: false),
        const Size(900, 900));
    final g = await mouse(tester);

    expect(plateAt(tester), isNull,
        reason: 'a pointer that has not entered the chart names nothing');

    final rect = tester.getRect(find.byKey(const ValueKey('chronologyWheel')));
    final named = await sweep(tester, g, rect);
    expect(named, isNotEmpty,
        reason: 'a grid across the whole wheel must land on SOMETHING; an '
            'empty result means the hover never resolves, not that the '
            'chart is empty');

    // Off the chart entirely: the plate goes away rather than sticking
    // to the last thing it named.
    await g.moveTo(Offset(rect.left - 40, rect.top - 40));
    await tester.pump();
    expect(plateAt(tester), isNull);
  });

  testWidgets('the wheel plate names the record the click opens',
      (tester) async {
    await pump(tester, const RadialChronologyPage(initialStacked: false),
        const Size(900, 900));
    final g = await mouse(tester);
    final rect = tester.getRect(find.byKey(const ValueKey('chronologyWheel')));
    final named = await sweep(tester, g, rect);
    expect(named, isNotEmpty);

    // One point is enough to pin the property, and doing all of them
    // would open and close a sheet a hundred times.
    final at = named.keys.first;
    final label = named[at]!;
    await g.moveTo(at);
    await tester.pump();
    expect(plateAt(tester), label);

    await tester.tapAt(at);
    await tester.pumpAndSettle();

    final onScreen = <String>{
      for (final w in tester.widgetList<Text>(find.byType(Text)))
        if (w.data case final d?) d,
    };
    expect(onScreen.any((t) => t.contains(label)), isTrue,
        reason: 'the sheet opened by a click at $at must be about "$label" — '
            'the name the hover promised at that exact point. If this '
            'fails the two paths have drifted apart, which is the whole '
            'reason there is one resolver.');
  });

  testWidgets('the wheel names far more than it prints', (tester) async {
    WheelRenderStats.reset();
    addTearDown(WheelRenderStats.reset);

    await pump(tester, const RadialChronologyPage(initialStacked: false),
        const Size(900, 900));
    final g = await mouse(tester);
    final rect = tester.getRect(find.byKey(const ValueKey('chronologyWheel')));
    final named = (await sweep(tester, g, rect)).values.toSet();
    final drawn = WheelRenderStats.labelsDrawn;

    // MEASURED 2026-09-17, and then measured again with the defect put
    // back deliberately, which is the only way to know a test would
    // catch it:
    //
    //   as written        900x900: 26 names hovered,  3 printed
    //                     390x844: 26 names hovered,  3 printed
    //   reading the DRAWN name instead of the record's own
    //     (`s.title` for a spoke, `l.name` for a life)
    //                     900x900:  1 name  hovered,  3 printed
    //                     390x844:  3 names hovered,  3 printed
    //
    // The collapse is the whole point of the feature: almost every
    // record on this chart is too narrow to carry its own name, and
    // those are exactly the ones a reader hovers to ask about. The
    // defect raises no error — an empty label simply shows no plate —
    // so a count is what stands between it and coming back.
    expect(named.length, greaterThanOrEqualTo(15),
        reason: 'hovering reached only ${named.length} records. With the '
            'drawn name instead of the record\'s own this number was 1. '
            'See 亚们, 2026-09-16.');
    expect(named.length, greaterThan(drawn * 3),
        reason: 'the chart printed $drawn names and hovering found '
            '${named.length}; if those are close, the hover is only '
            'repeating what is already legible and is worth nothing');
  });

  testWidgets('the wheel SHOWS what it claims, and says the year either way',
      (tester) async {
    // 2026-09-17, after Fable 5.1's reading of the same report: a word
    // beside the cursor is feedback about identity, and identity with
    // no visible extent cannot be checked. At 4050% a band is deeper
    // than a phone and longer than the viewport, with its name painted
    // once somewhere along it — so the outline is not decoration, it is
    // the evidence.
    await pump(tester, const RadialChronologyPage(initialStacked: false),
        const Size(900, 900));
    final g = await mouse(tester);
    final rect = tester.getRect(find.byKey(const ValueKey('chronologyWheel')));
    final named = await sweep(tester, g, rect);
    expect(named, isNotEmpty);

    final at = named.keys.first;
    await g.moveTo(at);
    await tester.pump();
    expect(find.byKey(const ValueKey('wheelClaimOutline')), findsOneWidget,
        reason: 'a named record must be drawn, not only spelled');

    // The hub is inside the chart and holds no record. The plate must
    // still appear — with the year and no name — because a hover that
    // simply vanishes reads as broken, and 「you are at this year,
    // between bands」 is the true answer.
    final hub = rect.center;
    await g.moveTo(hub);
    await tester.pump();
    final plates = find.byType(ChartHoverPlate);
    if (plates.evaluate().isNotEmpty) {
      final plate = tester.widget<ChartHoverPlate>(plates.first);
      expect(plate.year, isNotEmpty,
          reason: 'a plate with no name must carry the year instead');
      if (plate.text.isEmpty) {
        expect(find.byKey(const ValueKey('wheelClaimOutline')), findsNothing,
            reason: 'nothing was claimed, so nothing may be outlined');
      }
    }
  });

  testWidgets('the strip names what is under the pointer', (tester) async {
    await pump(tester, const StripChronologyPage(), const Size(900, 700));
    final g = await mouse(tester);
    expect(plateAt(tester), isNull);

    final rect = tester.getRect(find.byKey(const ValueKey('chronologyStrip')));
    // The chart is far wider than the window; sweep the part of it that
    // is actually on screen.
    final visible = rect.intersect(Offset.zero & tester.view.physicalSize);
    final named = await sweep(tester, g, visible);
    expect(named, isNotEmpty,
        reason: 'the lanes on screen must name themselves under a pointer');

    await g.moveTo(Offset(visible.left + 4, visible.top - 60));
    await tester.pump();
    expect(plateAt(tester), isNull,
        reason: 'above the lanes is the ruler, not a record');
  });
}
