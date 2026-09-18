/// A NAME IS DRAWN LEGIBLY OR NOT AT ALL.
///
/// 2026-09-17 「中间这些线你还是没有fix啊」, twice, with two faint boxes
/// circled beside a selected 以撒 — and they are not lines. They are
/// LABELS: when one record is selected the rest are dimmed, and the
/// dimming that is right for a mark is wrong for a word. The plate
/// survives the dimming better than the text inside it does, so what is
/// left on the chart is a box with a smudge in it.
///
/// This file is the arithmetic that says so. It composites what the
/// painter composites — the plate over the chart, the text over the
/// plate — and reads the contrast off the result.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yahwehs_sword/constants/workbench_theme.dart';
import 'package:yahwehs_sword/pages/radial_chronology_page.dart'
    show lineageRailColor;
import 'package:yahwehs_sword/utils/chronology_palette.dart';
import 'package:yahwehs_sword/utils/wheel_view_layout.dart';

/// WCAG relative luminance.
double _luminance(Color c) {
  double channel(double v) {
    final s = v;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

double _ratio(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

Color _over(Color fg, double alpha, Color bg) => Color.from(
      alpha: 1,
      red: fg.r * alpha + bg.r * (1 - alpha),
      green: fg.g * alpha + bg.g * (1 - alpha),
      blue: fg.b * alpha + bg.b * (1 - alpha),
    );

void main() {
  // The dark palette's own values, and the navy the wheel paints under
  // a label. Dark rather than light because that is the screenshot, and
  // because white-on-dark loses contrast faster as alpha falls.
  const pane = Color(0xFF14171C);
  const text = Color(0xFFE0E3E8);
  const chart = Color(0xFF1C2233);

  /// What a name actually reads at, at a given dim: the painter puts
  /// the plate down at `0.86 * dim` and the text on it at `0.98 * dim`.
  double contrastAt(double dim) {
    final plate = _over(pane, 0.86 * dim, chart);
    final ink = _over(text, 0.98 * dim, plate);
    return _ratio(ink, plate);
  }

  test('the dim values a selection applies put a name below reading', () {
    // 0.35 is what an unselected ARC gets while something else is
    // selected; 0.28 is what an unselected RECORD gets.
    expect(contrastAt(0.35), lessThan(3.0),
        reason: 'measured 2.70:1 — below even the large-text floor');
    expect(contrastAt(0.28), lessThan(3.0),
        reason: 'measured 2.20:1');
  });

  test('the floor is where a name becomes readable again', () {
    expect(contrastAt(kLegibleLabelDim), greaterThanOrEqualTo(4.5),
        reason: 'the floor must clear the app\'s own 4.5:1 standard');
    // And it is not higher than it needs to be: the 0.75 an unselected
    // lifespan carries has always been legible and must stay drawn.
    expect(kLegibleLabelDim, lessThanOrEqualTo(0.75));
    expect(contrastAt(0.75), greaterThan(4.5));
  });

  test('both label painters stop at the floor', () {
    // Canvas text leaves no widget behind, so this is the pin: the two
    // methods that draw a name each refuse below the floor, and the
    // mark they belong to is drawn either way.
    final src = File('lib/pages/radial_chronology_page.dart')
        .readAsStringSync()
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('///') &&
            !l.trimLeft().startsWith('//'))
        .join('\n');
    expect('if (dim < kLegibleLabelDim) return;'.allMatches(src).length, 2,
        reason: 'one of the two label painters no longer refuses to draw '
            'an unreadable name');
  });
  group('and a MARK stays a mark when it recedes', () {
    // 2026-09-17, second round on the same photograph: after the names
    // were fixed the owner circled the same spot again — 「还有啊在那 你好好
    // 查一下以色列和以撒中间」 — so the region was RENDERED to an image
    // rather than reasoned about. Between the 以色列 ring and 以撒's arc
    // lie the other lifespans, and with 以撒 selected they were drawn
    // at 0.22 x 0.35 = 0.077 alpha. Measured against the ground the
    // annulus is painted on, in both palettes:
    //
    //                    rest 0.22    receded 0.077    now: rest 0.36  receded 0.18
    //   dark  (shem)       1.27:1        1.07:1              ~1.6:1        ~1.25:1
    //   light (shem)       1.36:1        1.11:1              ~1.7:1        ~1.30:1
    //
    // 1.07:1 is present enough to notice and too faint to be anything —
    // a stain shaped like an arc. The receded state is now what the
    // resting state used to be, and the resting state can be seen.
    final grounds = {
      'dark': Color.lerp(WbColors.dark.paneBg, WbColors.dark.paneAltBg, 0.65)!,
      'light':
          Color.lerp(WbColors.light.paneBg, WbColors.light.paneAltBg, 0.65)!,
    };

    test('the old receded alpha was invisible on both grounds', () {
      for (final e in grounds.entries) {
        final c = familyColor('shem', dark: e.key == 'dark');
        expect(_ratio(_over(c, 0.22 * 0.35, e.value), e.value), lessThan(1.15),
            reason: '${e.key}: if this is now readable the palette moved '
                'and the numbers above are stale');
      }
    });

    test('a receded lifespan still reads as a shape, at rest more so', () {
      for (final e in grounds.entries) {
        final c = familyColor('shem', dark: e.key == 'dark');
        expect(_ratio(_over(c, kLifespanRecededAlpha, e.value), e.value),
            greaterThanOrEqualTo(1.2),
            reason: '${e.key}: receded below the point of being a shape');
        expect(_ratio(_over(c, kLifespanRestAlpha, e.value), e.value),
            greaterThanOrEqualTo(1.5),
            reason: '${e.key}: at rest a lifespan must be visibly there');
        expect(kLifespanRecededAlpha, lessThan(kLifespanRestAlpha),
            reason: 'receding must still recede');
      }
    });
  });

  group('and the genealogy rail is a scale, not debris', () {
    // The fourth circle on the same photograph, 2026-09-17: with the
    // lifespans fixed, what was left were the rail's ticks — a hundred
    // and seven short grey dashes, at 0.30 alpha on a dark ground
    // (1.80:1) and 0.18 behind a selection (1.38:1), floating in the
    // annulus with nothing joining them. Rendered and looked at, they
    // read as artefacts. A scale has a line.
    final grounds = {
      'dark': Color.lerp(WbColors.dark.paneBg, WbColors.dark.paneAltBg, 0.65)!,
      'light':
          Color.lerp(WbColors.light.paneBg, WbColors.light.paneAltBg, 0.65)!,
    };

    test('a tick at rest clears 2:1 on both grounds', () {
      for (final e in grounds.entries) {
        final c = lineageRailColor(dark: e.key == 'dark');
        expect(_ratio(_over(c, kRailTickAlpha, e.value), e.value),
            greaterThanOrEqualTo(2.0),
            reason: '${e.key}: a tick the reader cannot see is a tick '
                'they will circle');
        // The old value, for the record: it failed on the light ground.
        expect(_ratio(_over(c, 0.30, e.value), e.value), lessThan(2.0),
            reason: '${e.key}: if 0.30 now clears 2:1 the palette moved');
      }
    });

    test('ticks behind a selection are not drawn, and the track is', () {
      final src = File('lib/pages/radial_chronology_page.dart')
          .readAsStringSync();
      final rail = src.substring(src.indexOf('void _paintRail('),
          src.indexOf('void _paintLifespans('));
      expect(rail.contains('if (has && !sel) continue;'), isTrue,
          reason: 'receded rail ticks are being drawn again — that is the '
              'scatter of grey dashes beside a selected record');
      expect(rail.contains('canvas.drawArc('), isTrue,
          reason: 'the rail has no track: its ticks are floating in the '
              'annulus with nothing to say they belong together');
      expect(rail.contains('kRailTickAlpha'), isTrue);
    });
  });

}
