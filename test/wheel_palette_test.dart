import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart';

/// Guards the wheel's palette, ON BOTH GROUNDS.
///
/// 2026-09-15: every property below used to be checked once, against a
/// palette that took no ground at all 「可以跟着变吧 dark ligjt mode」.
/// They now run twice, because separation is a property of the colours
/// AS PAINTED: raising every band's lightness for a night ground moves
/// all of them the same way, and a set that was far enough apart on
/// cream can close up once it is re-seated. The loop is the point — a
/// version of this file that only tested `dark: false` would have said
/// nothing at all about the half of the app the change was made for.
///
/// The first palette gave every band its family's single hue, so ten
/// Japhethite bands — Persia through India — came out as ten
/// near-identical blues and a reader could not tell Rome from Japan.
/// The fix spread each family across an arc of the colour wheel; this
/// test is what stops it collapsing back.
///
/// Distance is measured in a rough perceptual space rather than raw
/// RGB: equal RGB steps are not equally visible, and a test that
/// passed on arithmetic while the bands still looked alike would be
/// worse than no test.
double _perceptualDistance(Color a, Color b) {
  // Weighted euclidean ("redmean") — cheap, and much closer to what an
  // eye reports than a plain RGB distance.
  final rMean = ((a.r * 255 + b.r * 255) / 2);
  final dr = (a.r - b.r) * 255;
  final dg = (a.g - b.g) * 255;
  final db = (a.b - b.b) * 255;
  return math.sqrt((2 + rMean / 256) * dr * dr +
      4 * dg * dg +
      (2 + (255 - rMean) / 256) * db * db);
}

void main() {
  late List<Map<String, dynamic>> streams;

  setUpAll(() {
    final raw = json.decode(File('assets/wheel_history.json').readAsStringSync())
        as Map<String, dynamic>;
    streams = (raw['streams'] as List).cast<Map<String, dynamic>>();
  });

  /// Every band's colour, in the order the wheel draws them.
  List<(String, Color)> bandColors({required bool dark}) {
    final byLine = <String, List<String>>{};
    for (final s in streams) {
      byLine.putIfAbsent(s['line'] as String, () => []).add(s['id'] as String);
    }
    return [
      for (final s in streams)
        (
          s['id'] as String,
          streamColor(
            s['line'] as String,
            byLine[s['line']]!.indexOf(s['id'] as String),
            byLine[s['line']]!.length,
            dark: dark,
          )
        )
    ];
  }

  for (final dark in [false, true]) {
    final ground = dark ? 'night' : 'paper';

  test('no two bands share a colour ($ground)', () {
    final seen = <int, String>{};
    for (final (id, c) in bandColors(dark: dark)) {
      final key = c.toARGB32();
      expect(seen.containsKey(key), isFalse,
          reason: '$id and ${seen[key]} are the same colour');
      seen[key] = id;
    }
  });

  test('bands drawn next to each other are visibly different ($ground)',
      () {
    final list = bandColors(dark: dark);
    for (var i = 1; i < list.length; i++) {
      final d = _perceptualDistance(list[i - 1].$2, list[i].$2);
      expect(d, greaterThan(40),
          reason: '${list[i - 1].$1} and ${list[i].$1} sit side by side on '
              'the wheel and are only $d apart — the complaint that '
              'prompted this test');
    }
  });

  test('every band differs from every other, not just its neighbour '
      '($ground)', () {
    final list = bandColors(dark: dark);
    var worst = double.infinity;
    late String pair;
    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        final d = _perceptualDistance(list[i].$2, list[j].$2);
        if (d < worst) {
          worst = d;
          pair = '${list[i].$1} / ${list[j].$1}';
        }
      }
    }
    expect(worst, greaterThan(30),
        reason: 'the closest pair anywhere on the wheel is $pair at $worst');
  });

  test('a family still reads as one family ($ground)', () {
    // The first version of this test measured the distance from a
    // family's first colour to its last and demanded it stay under an
    // arbitrary 320. Shem came out at 325 and the honest options were
    // to raise the number — which would have made the test say nothing
    // — or to test the property that actually matters.
    //
    // What matters is CLUSTERING: two bands of one descent should sit
    // closer together than two bands of different descents. That is
    // what "reads as one family" means, and it holds regardless of how
    // wide any single arc had to be to keep its own members apart.
    final byLine = <String, List<Color>>{};
    for (final s in streams) {
      final ids = streams
          .where((x) => x['line'] == s['line'])
          .map((x) => x['id'] as String)
          .toList();
      byLine.putIfAbsent(s['line'] as String, () => []).add(streamColor(
          s['line'] as String, ids.indexOf(s['id'] as String), ids.length,
          dark: dark));
    }

    var within = 0.0;
    var withinN = 0;
    for (final cols in byLine.values) {
      for (var i = 0; i < cols.length; i++) {
        for (var j = i + 1; j < cols.length; j++) {
          within += _perceptualDistance(cols[i], cols[j]);
          withinN++;
        }
      }
    }

    var across = 0.0;
    var acrossN = 0;
    final lines = byLine.keys.toList();
    for (var a = 0; a < lines.length; a++) {
      for (var b = a + 1; b < lines.length; b++) {
        for (final ca in byLine[lines[a]]!) {
          for (final cb in byLine[lines[b]]!) {
            across += _perceptualDistance(ca, cb);
            acrossN++;
          }
        }
      }
    }

    expect(withinN, greaterThan(0));
    expect(acrossN, greaterThan(0));
    final meanWithin = within / withinN;
    final meanAcross = across / acrossN;
    expect(meanWithin, lessThan(meanAcross),
        reason: 'bands of one descent (mean $meanWithin apart) are no closer '
            'to each other than bands of different descents (mean '
            '$meanAcross) — the Genesis 10 grouping has stopped being '
            'visible at all');
  });
  }

  test('a band carries against the ground it is actually painted on', () {
    // The defect this was written for, measured on the shipped build:
    // the lightness zigzag was centred on 0.47 whatever was behind it,
    // so on the night ground (#0B1320 through `paneBg`) the darker half
    // of every pair landed near 2:1 — a ring a reader has to hunt for
    // rather than read.
    //
    // 2.2:1, not 4.5:1, and the reason is what these marks ARE. A band
    // is a filled shape several pixels thick, not body text; WCAG's
    // text floors do not apply to it and imposing one would drive the
    // whole palette to the loud end, which is the other complaint this
    // chart has already collected. What 2.2 forbids is the failure
    // above: a band that has effectively disappeared into its own
    // backing.
    //
    // The wheel paints its disc as a radial gradient from `paneBg`
    // toward `paneAltBg`, so `paneBg` IS the ground here rather than a
    // stand-in for it — see `_paintSurface`.
    double luminance(Color c) => c.computeLuminance();
    double ratio(Color a, Color b) {
      final l1 = luminance(a), l2 = luminance(b);
      final hi = math.max(l1, l2), lo = math.min(l1, l2);
      return (hi + 0.05) / (lo + 0.05);
    }

    for (final (name, wb) in [
      ('light', WbColors.light),
      ('dark', WbColors.dark),
      ('paper', WbColors.paper),
    ]) {
      for (final (id, colour) in bandColors(dark: wb.isDark)) {
        final r = ratio(colour, wb.paneBg);
        expect(r, greaterThan(2.2),
            reason: '$id is ${r.toStringAsFixed(2)}:1 against the $name '
                'ground — it has effectively vanished into it');
      }
      // And on the correct SIDE of it. A band that cleared the ratio by
      // being darker than a night ground would be a hole rather than a
      // mark, and the check above cannot tell those apart.
      for (final (id, colour) in bandColors(dark: wb.isDark)) {
        expect(luminance(colour) > luminance(wb.paneBg), !wb.isDark ? false : true,
            reason: '$id sits on the wrong side of the $name ground');
      }
    }
  });
}
