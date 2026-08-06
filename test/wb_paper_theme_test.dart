// 2026-08: 护眼纸质 used to stop at BibleReadingPane's content subtree —
// the workbench chrome and the parallel Browse window stayed on the
// neutral desktop palette, so a reader who turned paper on got a cream
// square in a grey workspace. These pin the wiring that fixes that:
// `workbenchTheme(paper: true)` swaps the WbColors extension to a warm
// cream variant regardless of ThemeMode, and that variant is internally
// consistent (text legible on pane background, link legible on chrome).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/workbench_theme.dart';

void main() {
  group('WbColors.paper', () {
    test('is warm, not a tinted dark mode', () {
      // The whole point of "paper" is paper — Kindle/WeChat-Read-style
      // warm cream regardless of system theme, not a brown-shifted dark
      // mode. Pane and chrome must read as cream, not as charcoal.
      final paneHsl = HSLColor.fromColor(WbColors.paper.paneBg);
      final chromeHsl = HSLColor.fromColor(WbColors.paper.chromeBg);
      expect(paneHsl.lightness, greaterThan(0.75),
          reason: 'pane should be a light cream');
      expect(chromeHsl.lightness, greaterThan(0.75),
          reason: 'chrome should be a light cream too');
      // Hue in the yellow/amber band — warm, not cool.
      expect(paneHsl.hue, inInclusiveRange(30, 60));
      expect(chromeHsl.hue, inInclusiveRange(30, 60));
    });

    test('body text is legible on the pane background', () {
      // 4.5:1 is the WCAG AA threshold for body text. A paper palette
      // that doesn't clear it isn't paper, it's muddy.
      final ratio = _contrast(WbColors.paper.text, WbColors.paper.paneBg);
      expect(ratio, greaterThan(4.5),
          reason: 'text on pane should clear WCAG AA');
    });

    test('muted text is darker than the border, lighter than full ink', () {
      // Muted text sits between ink and the surface — a paper palette
      // that printed muted in full ink would lose the visual hierarchy
      // that makes BibleWorks' status bar scannable.
      final inkL = HSLColor.fromColor(WbColors.paper.text).lightness;
      final mutedL = HSLColor.fromColor(WbColors.paper.mutedText).lightness;
      final paneL = HSLColor.fromColor(WbColors.paper.paneBg).lightness;
      expect(mutedL, greaterThan(inkL));
      expect(mutedL, lessThan(paneL));
    });

    test('link stays blue, not gold — hyperlinks are the one known colour', () {
      // BibleWorks uses hyperlink blue for clickable references and so
      // does the rest of the workbench. A gold link on cream is harder
      // to read, not easier. Paper mode keeps the blue.
      final linkHsl = HSLColor.fromColor(WbColors.paper.link);
      expect(linkHsl.hue, inInclusiveRange(200, 240),
          reason: 'link should remain in the blue band');
      final ratio = _contrast(WbColors.paper.link, WbColors.paper.paneBg);
      expect(ratio, greaterThan(4.5),
          reason: 'link on pane should clear WCAG AA');
    });

    test('selection is a deeper tan, not the default blue primaryContainer', () {
      // The whole palette is warm — a default-Blue selection against
      // cream is the thing the original paper-mode port was avoiding.
      final selHsl = HSLColor.fromColor(WbColors.paper.selectionBg);
      expect(selHsl.hue, inInclusiveRange(30, 60),
          reason: 'selection should be in the warm band');
      // Selection is darker than the pane so the focused verse still
      // reads against the page.
      final selL = selHsl.lightness;
      final paneL = HSLColor.fromColor(WbColors.paper.paneBg).lightness;
      expect(selL, lessThan(paneL),
          reason: 'selection should be deeper than the pane');
    });

    test("Strong's lexical/grammar hues survive on cream", () {
      // The convention is green for the word's own number, blue for a
      // grammar code. Both need to stay readable on a cream pane.
      expect(_contrast(WbColors.paper.strongsLexical, WbColors.paper.paneBg),
          greaterThan(3.0),
          reason: "Strong's lexical green on pane");
      expect(_contrast(WbColors.paper.strongsGrammar, WbColors.paper.paneBg),
          greaterThan(3.0),
          reason: "Strong's grammar blue on pane");
    });
  });

  group('workbenchTheme paper flag', () {
    testWidgets('paper: false picks the brightness-matched palette',
        (tester) async {
      // Use a raw Theme widget instead of MaterialApp — MaterialApp
      // honours themeMode.system + the test harness's platform
      // brightness, and "did the right theme win" is a MaterialApp
      // question, not a workbenchTheme question. We only need to know
      // the extension was registered.
      late WbColors lightCaptured;
      late WbColors darkCaptured;
      await tester.pumpWidget(Theme(
        data: workbenchTheme(ThemeData.light()),
        child: Builder(builder: (ctx) {
          lightCaptured = WbColors.of(ctx);
          return const SizedBox();
        }),
      ));
      await tester.pumpWidget(Theme(
        data: workbenchTheme(ThemeData.dark()),
        child: Builder(builder: (ctx) {
          darkCaptured = WbColors.of(ctx);
          return const SizedBox();
        }),
      ));
      expect(lightCaptured, WbColors.light);
      expect(darkCaptured, WbColors.dark);
    });

    testWidgets('paper: true overrides brightness — cream in light AND dark',
        (tester) async {
      late WbColors lightPaper;
      late WbColors darkPaper;
      await tester.pumpWidget(Theme(
        data: workbenchTheme(ThemeData.light(), paper: true),
        child: Builder(builder: (ctx) {
          lightPaper = WbColors.of(ctx);
          return const SizedBox();
        }),
      ));
      await tester.pumpWidget(Theme(
        data: workbenchTheme(ThemeData.dark(), paper: true),
        child: Builder(builder: (ctx) {
          darkPaper = WbColors.of(ctx);
          return const SizedBox();
        }),
      ));
      expect(lightPaper, WbColors.paper);
      expect(darkPaper, WbColors.paper);
    });
  });
}

/// WCAG-style contrast ratio between two colours. Returns 1..21.
double _contrast(Color a, Color b) {
  double ch(double v) {
    final s = v / 255.0;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  double lum(Color c) =>
      0.2126 * ch(c.r * 255.0) +
      0.7152 * ch(c.g * 255.0) +
      0.0722 * ch(c.b * 255.0);

  final la = lum(a) + 0.05;
  final lb = lum(b) + 0.05;
  return la > lb ? la / lb : lb / la;
}
