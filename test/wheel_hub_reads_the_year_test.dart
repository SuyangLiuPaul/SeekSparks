/// The hub answers the question the chart is being asked.
///
/// 2026-09-15. It used to print the page title — which the AppBar
/// already carries two rows above it — so the calmest circle on the
/// chart was spending itself on a repeat.
///
/// What it says now is the year under the reader's finger. The footer
/// invites the tap 「点一下图表，读出那一年」 and the answer used to appear
/// in the digest bar BELOW the wheel, so a reader tapping near the rim
/// had to look away from their own fingertip to read the result. It is
/// now inside the circle their finger is pointing at.
///
/// Before the first tap the hub says what the chart COVERS, which is
/// the other question asked of a chronology before anyone touches it.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/chronology_service.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await WheelHistoryService.instance.load();
    await ChronologyService.instance.load();
    await (FontLoader('Roboto')
          ..addFont(rootBundle
              .load('assets/fonts/Roboto-VariableFont_wdth,wght.ttf')))
        .load();
  });

  Future<void> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MainProvider()),
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child: MaterialApp(
        theme: ThemeData(
            fontFamily: 'Roboto', fontFamilyFallback: kCjkFontFallback),
        home: const RadialChronologyPage(initialStacked: false),
      ),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Finder hub() => find.byKey(const ValueKey('wheelHubCaption'));

  List<String> hubLines(WidgetTester tester) => [
        for (final text in tester.widgetList<Text>(
            find.descendant(of: hub(), matching: find.byType(Text))))
          text.data ?? ''
      ];

  void year(WidgetTester tester, int value) {
    tester
        .widget<Slider>(find.byKey(const ValueKey('chronoYearScrubber')))
        .onChanged!(value.toDouble());
  }

  testWidgets('before the first tap the hub says what the chart covers',
      (tester) async {
    await pump(tester);
    final lines = hubLines(tester);
    expect(lines, isNotEmpty);
    expect(lines.first, contains('4200'),
        reason: 'the hub does not say where the chart starts: $lines');
    expect(lines.first, contains('2026'),
        reason: 'the hub does not say where the chart ends: $lines');
    // And it is NOT the page title, which the AppBar is already saying.
    for (final line in lines) {
      expect(line, isNot(contains('World History Wheel')));
      expect(line, isNot(contains('世界史轮盘')));
    }
  });

  testWidgets('after a tap the hub reads out that year', (tester) async {
    await pump(tester);
    year(tester, -586);
    await tester.pump();
    expect(hubLines(tester).first, contains('586'),
        reason: 'the hub did not follow the year cursor: '
            '${hubLines(tester)}');

    // And it follows a second reading rather than sticking on the first
    // — the cursor is a live readout, not a one-shot.
    year(tester, 1517);
    await tester.pump();
    expect(hubLines(tester).first, contains('1517'));
    expect(hubLines(tester).first, isNot(contains('586')));
  });

  testWidgets('the hub still fits inside the hub', (tester) async {
    // The reason the old caption was one line of small type. Two lines
    // of larger type is a bigger claim on an 86 px circle, and
    // `wheel_narrow_pane_test` holds the phone case; this holds the
    // case the year makes it tallest — a four-digit BC year with the
    // hint under it.
    await pump(tester);
    year(tester, -4200);
    await tester.pump();
    const hubFrac = 0.115; // mirrors `_kHubFrac`, private to the page
    final side =
        tester.getSize(find.byKey(const ValueKey('chronologyWheel'))).width;
    expect(tester.getSize(hub()).height, lessThanOrEqualTo(side * hubFrac * 2));
  });
}
