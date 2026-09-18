/// A ROW IN ONE SHEET OPENS THE NEXT SHEET, and does not take the page
/// down with it.
///
/// 2026-09-17, from the web build of 1.6.313: "Null check operator used
/// on a null value", route `/minified:wg`, with breadcrumbs that named
/// the path exactly — a modal popped, and the crash landed inside the
/// next sheet's opening. Read out of the deployed `main.dart.js`, the
/// frame was `showModalBottomSheet`'s own first line, `Navigator.of`.
///
/// Nine handlers in `wheel_sheets.dart` read
///
///     Navigator.of(sheet).pop();
///     showPerson(context, ...);
///
/// and both halves are wrong when the sheet is the persistent PANEL —
/// which is what `_present` gives whenever there is a Scaffold, i.e.
/// normally. The panel is not a route, so the `pop` pops the PAGE, and
/// the `context` captured from the caller then belongs to a widget that
/// has just left the tree.
///
/// This drives the one path a test can reach end to end: a mark on the
/// genealogy rail, the cohort sheet it opens, and a person's row inside
/// it. The rail marks only became reachable at all earlier today —
/// before that their target was a pointer's width in the middle of a
/// line — which is why a defect this old surfaced now.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yahwehs_sword/models/app_settings.dart';
import 'package:yahwehs_sword/models/wheel_history.dart';
import 'package:yahwehs_sword/pages/radial_chronology_page.dart';
import 'package:yahwehs_sword/providers/main_provider.dart';
import 'package:yahwehs_sword/services/chronology_service.dart';
import 'package:yahwehs_sword/services/family_tree_service.dart';
import 'package:yahwehs_sword/utils/radial_chronology_layout.dart';
import 'package:yahwehs_sword/widgets/chart_help_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await WheelHistoryService.instance.load();
    await ChronologyService.instance.load();
    // Without the tree there is no rail, and every assertion below
    // would pass by never finding anything.
    await FamilyTreeService.instance.loadAll();
  });

  testWidgets('a person in the cohort sheet opens, and the wheel stays',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        <String, Object>{ChartHelp.seenKey: true});
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(900, 900);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MainProvider()),
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child:
          const MaterialApp(home: RadialChronologyPage(initialStacked: false)),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // A MARK ON THE RAIL. Its radius is just outside the band stack and
    // its angle is somewhere in 主前2200..主前2 — the stretch the rail
    // actually covers, which is not the whole wheel.
    final box = tester.getRect(find.byKey(const ValueKey('chronologyWheel')));
    final side = math.min(box.width, box.height);
    final centre = box.topLeft + Offset(box.width / 2, box.height / 2);
    var opened = false;
    for (final year in [-1000, -1200, -800, -1500, -600]) {
      final a = angleForSpan(year, kMinYear, kMaxYear);
      final p = centre +
          Offset(math.cos(a), math.sin(a)) * (side * 0.2896);
      await tester.tapAt(p);
      await tester.pumpAndSettle();
      if (find.byType(BottomSheet).evaluate().isNotEmpty) {
        opened = true;
        break;
      }
    }
    expect(opened, isTrue,
        reason: 'no tap on the rail opened a sheet, so this test never '
            'reaches the row it exists to press');

    // A PERSON'S ROW inside it. The sheet lists the cohort's people as
    // tappable rows; take the first one under the sheet itself.
    // A PERSON'S ROW, not the sheet's own close button — which is an
    // `IconButton` in the same subtree and was what `.last` found on the
    // first run of this test.
    final row = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(InkWell),
        matchRoot: false);
    final people = row
        .evaluate()
        .where((e) => find
            .descendant(of: find.byWidget(e.widget), matching: find.byType(Text))
            .evaluate()
            .isNotEmpty)
        .toList();
    expect(people, isNotEmpty,
        reason: 'the cohort sheet listed nobody to tap');
    await tester.tap(find.byWidget(people.first.widget),
        warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'tapping a person in the cohort sheet threw — this is the '
            'crash the 1.6.313 report named');
    expect(find.byType(RadialChronologyPage), findsOneWidget,
        reason: 'the wheel page went away when a sheet row was tapped: the '
            'pop took the page instead of the panel');
    expect(find.byType(BottomSheet), findsWidgets,
        reason: 'the row closed its own sheet and opened nothing');
  });

  test('no handler here pops a sheet and then reuses the old context', () {
    // THE SOURCE GUARD, and it is the honest half of this file.
    //
    // I could not reproduce the reported crash in a widget test: under
    // the test binding `_present` takes its modal path, the popped
    // route is a route, and the captured context outlives it. What IS
    // certain is where the crash happened — read out of the deployed
    // `main.dart.js`, the throwing frame is `showModalBottomSheet`'s
    // own `Navigator.of`, called from a closure that had just popped a
    // sheet — and that the pattern is wrong on its own terms for the
    // PANEL path, where `pop` takes the page.
    //
    // So this pins the pattern rather than the symptom. `dismissSheet`
    // closes whichever kind of sheet is open and returns the
    // NavigatorState's own context, which outlives both.
    final src = File('lib/pages/wheel_sheets.dart')
        .readAsStringSync()
        // The helper's own doc quotes the old pattern, which is the
        // point of it. Only real code counts.
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('///'))
        .join('\n');
    expect(src.contains('Navigator.of(sheet).pop();'), isFalse,
        reason: 'a handler is popping the sheet itself again — on the '
            'persistent panel that pops the PAGE, and whatever context it '
            'reuses afterwards may already be off the tree');
    expect(src.contains('BuildContext dismissSheet(BuildContext sheet)'),
        isTrue);
  });
}
