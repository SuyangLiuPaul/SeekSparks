/// A record too narrow to hold its own name still gets one.
///
/// 2026-09-16 「亚们还是没有解决」 — Amon of Judah, 主前643 to 主前641,
/// with 玛拿西's fifty-five years hard against one end of him and
/// 约西亚's thirty-one against the other. At 3404% he was a bare strip
/// with a dot in it, and the branch of the painter written for exactly
/// this case had never once run for him.
///
/// WHY IT HAD NEVER RUN. `_Life.name` is the name AS DRAWN ALONG THE
/// ARC, set only when the planner found free room inside the arc's own
/// sweep. The callout branch — the one that exists for records with no
/// such room — was guarded on `name.isNotEmpty`, which is false in
/// every case that branch serves. Dead from the day it was written, and
/// invisible to every test in this repo, because canvas text leaves no
/// widget and no semantics node behind.
///
/// SO THE PAINTER REPORTS. `WheelRenderStats.trackLabels` turns on two
/// sets: the names the canvas was asked to draw, and the names it could
/// find no free room for. Off in every shipped build. This is the only
/// test that can see a canvas label at all, which is why it asserts on
/// named records rather than on a count of pixels.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yahwehs_sword/models/app_settings.dart';
import 'package:yahwehs_sword/models/wheel_history.dart';
import 'package:yahwehs_sword/pages/radial_chronology_page.dart';
import 'package:yahwehs_sword/providers/main_provider.dart';
import 'package:yahwehs_sword/services/chronology_service.dart';
import 'package:yahwehs_sword/utils/radial_chronology_layout.dart';
import 'package:yahwehs_sword/utils/wheel_view_layout.dart';
import 'package:yahwehs_sword/widgets/chart_help_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Real I/O never completes inside a widget test's fake-async zone;
    // the services cache, so the page's own load resolves from cache.
    await WheelHistoryService.instance.load();
    await ChronologyService.instance.load();
  });

  /// The wheel, zoomed in [steps] presses of its own zoom control, with
  /// the label tracker armed for the LAST press only — the sets are
  /// per-run and a name lost at 500% and found at 2900% would otherwise
  /// read as lost.
  Future<void> pumpZoomed(WidgetTester tester, int steps) async {
    SharedPreferences.setMockInitialValues(
        <String, Object>{ChartHelp.seenKey: true});
    addTearDown(tester.view.reset);
    addTearDown(() {
      WheelRenderStats.trackLabels = false;
      WheelRenderStats.reset();
    });
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child:
            const MaterialApp(home: RadialChronologyPage(initialStacked: false)),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    for (var i = 0; i < steps - 1; i++) {
      await tester.tap(find.byKey(const ValueKey('wheelZoomInControl')));
      await tester.pump(const Duration(milliseconds: 60));
    }
    await tester.pump(const Duration(milliseconds: 400));
    WheelRenderStats.trackLabels = true;
    WheelRenderStats.labelsAsked.clear();
    WheelRenderStats.labelsLost.clear();
    await tester.tap(find.byKey(const ValueKey('wheelZoomInControl')));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('a two-year reign wedged between two long ones is named',
      (tester) async {
    // Nine presses of 1.4 from rest is about 2900%, which is where the
    // owner's screenshot was taken.
    await pumpZoomed(tester, 10);
    expect(WheelRenderStats.labelsAsked, contains('亚们'),
        reason: 'the canvas never even tried to name Amon');
    expect(WheelRenderStats.labelsLost, isNot(contains('亚们')),
        reason: 'Amon was asked for and then found nowhere to stand');
    // His neighbours, so a pass cannot come from the kings layer being
    // hidden and the assertion above being vacuous.
    for (final name in ['玛拿西', '约西亚', '希西家']) {
      expect(WheelRenderStats.labelsAsked, contains(name));
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('almost every name the zoomed canvas asks for lands',
      (tester) async {
    await pumpZoomed(tester, 10);
    final asked = WheelRenderStats.labelsAsked.length;
    final lost = WheelRenderStats.labelsLost.length;
    expect(asked, greaterThan(150),
        reason: 'the sweep is meant to cover the whole zoomed wheel');
    // 4 of 184 on the day this was written, all of them popes or
    // crusades in the church ring, where the records are three deep. A
    // regression that broke placement would put this in the dozens.
    //
    // 2026-09-16, later the same day: 26 of 213, and the ceiling moved
    // from an eighth to a sixth. The corpus grew by 15, and the leader
    // a name may follow was capped — 「手机上看就很恐怖了」, of names
    // standing over the empty middle of a phone screen with a hairline
    // running off to an arc near the rim. The names that lose now are
    // exactly the ones that used to be dragged furthest from what they
    // name, and they are all in the pope ring, six deep. A name nobody
    // can trace back is not a name that landed.
    expect(lost, lessThan(asked ~/ 6),
        reason: '$lost of $asked names found nowhere to stand: '
            '${WheelRenderStats.labelsLost.take(12).join(", ")}');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  group('arcLabelDetours', () {
    test('tries its own lane before leaving it, and forward before back',
        () {
      final moves = arcLabelDetours(step: 0.1, rowStep: 5);
      expect(moves.first, (dAngle: 0.1, dRadius: 0.0));
      expect(moves[1], (dAngle: -0.1, dRadius: 0.0));
      final firstOut = moves.indexWhere((m) => m.dRadius != 0);
      expect(firstOut, 12, reason: 'six steps each way along the ring first');
      expect(moves[firstOut], (dAngle: 0.0, dRadius: 5.0),
          reason: 'outward before inward, into the margin not the hub');
    });

    test('an outward move keeps the year and only leaves the lane', () {
      for (final m in arcLabelDetours(step: 0.1, rowStep: 5)) {
        expect(m.dAngle == 0 || m.dRadius == 0, isTrue,
            reason: 'a diagonal would move the name to a year it is not');
      }
    });

    test('counts are what the caller asked for', () {
      expect(arcLabelDetours(step: 1, rowStep: 1, along: 2, out: 1).length, 6);
      expect(arcLabelDetours(step: 1, rowStep: 1, out: 0).length, 12);
    });
  });
}
