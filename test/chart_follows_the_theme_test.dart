/// The chronology charts take their colours from the theme they are in.
///
/// 2026-09-15. 「可以跟着变吧 dark ligjt mode」.
///
/// `wheel_palette_test.dart` proves the PALETTE — that a band is level,
/// separable and carries against each ground. It cannot prove the
/// WIRING, and the wiring was the actual defect: the hue functions were
/// pure and correct, and the page called them without ever saying which
/// ground it was painting on. A palette test alone stays green against
/// a page that hands it `dark: false` forever.
///
/// So this file pumps the real pages under both themes and reads the
/// colours the real painter was handed. It also pins the part that is
/// easiest to get wrong and hardest to see: the scene and the strip
/// palette are CACHED, and a cache key that omits the ground leaves a
/// reader who switches to dark mode on the light palette until
/// something unrelated invalidates it.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/chronology_service.dart';
import 'package:seeksparks/utils/chronology_palette.dart';
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

  /// The wheel's CustomPainter, reached the way the other wheel tests
  /// reach it: `colors` is a public member of a private class, so a
  /// dynamic read works and no production API has to be widened for a
  /// test's convenience.
  dynamic wheelPainter(WidgetTester tester) => tester
      .widget<CustomPaint>(find.descendant(
          of: find.byKey(const ValueKey('chronologyWheel')),
          matching: find.byType(CustomPaint)))
      .painter!;

  Map<String, Color> paintedColors(WidgetTester tester) =>
      Map<String, Color>.from(wheelPainter(tester).colors as Map);

  Future<void> pump(WidgetTester tester, Brightness brightness) async {
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MainProvider()),
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child: MaterialApp(
        // `workbenchTheme`, not a bare ThemeData. `WbColors.of` reads a
        // ThemeExtension that only this builder installs, and falls
        // back to the LIGHT palette when it is absent — so a test that
        // merely set `brightness: dark` would be testing its own
        // scaffolding and would report the page as broken. (It did, on
        // the first run of this file.)
        theme: workbenchTheme(ThemeData(
          brightness: brightness,
          fontFamily: 'Roboto',
          fontFamilyFallback: kCjkFontFallback,
        )),
        home: const RadialChronologyPage(initialStacked: false),
      ),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('the wheel is handed the night palette in a dark theme',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);

    await pump(tester, Brightness.light);
    final onPaper = paintedColors(tester);
    expect(onPaper, isNotEmpty,
        reason: 'no colours reached the painter, so this test would pass '
            'by measuring nothing');

    await pump(tester, Brightness.dark);
    final atNight = paintedColors(tester);

    expect(atNight.keys.toSet(), onPaper.keys.toSet(),
        reason: 'the two themes drew different streams, so the comparison '
            'below is not about colour');
    for (final id in onPaper.keys) {
      expect(atNight[id], isNot(onPaper[id]),
          reason: '$id was painted the same colour on both grounds — the '
              'page is not telling the palette which ground it is on');
      // And in the right direction. Merely differing would also be
      // satisfied by a page that handed dark:true to the LIGHT theme.
      expect(atNight[id]!.computeLuminance(),
          greaterThan(onPaper[id]!.computeLuminance()),
          reason: '$id is no lighter at night than on paper');
    }
  });

  testWidgets('switching theme in place repaints, rather than keeping the '
      'cached scene', (tester) async {
    // The cache-key bug, stated as a test. `_sceneFor` keys on the data,
    // the size, the locale, the zoom, the hidden set and the services —
    // every one of which is unchanged when a reader flips to dark mode.
    // Without the ground in that key the first line below returns the
    // paper scene and the wheel stays light on a dark page.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);

    await pump(tester, Brightness.light);
    final onPaper = paintedColors(tester);

    // Same widget, same everything, only the theme swapped — NOT a
    // remount: pumpWidget with an identical child updates the existing
    // element, which is exactly what the app does.
    await pump(tester, Brightness.dark);
    final atNight = paintedColors(tester);
    expect(atNight, isNot(onPaper));

    await pump(tester, Brightness.light);
    expect(paintedColors(tester), onPaper,
        reason: 'going back to the light theme did not restore the light '
            'palette');
  });

  test('the palette itself moves with the ground, in the right direction',
      () {
    // A unit-level floor under the two widget tests above, so a failure
    // there can be read as wiring rather than as arithmetic.
    for (final line in kLineHueArcs.keys) {
      for (final index in [0, 1]) {
        final paper = bandColor(line, 0.5, index, dark: false);
        final night = bandColor(line, 0.5, index, dark: true);
        expect(night.computeLuminance(), greaterThan(paper.computeLuminance()),
            reason: '$line/$index is not lighter at night');
      }
    }
  });
}
