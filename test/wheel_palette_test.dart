import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/pages/radial_chronology_page.dart';

/// Guards the wheel's palette.
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
  List<(String, Color)> bandColors() {
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
          )
        )
    ];
  }

  test('no two bands share a colour', () {
    final seen = <int, String>{};
    for (final (id, c) in bandColors()) {
      final key = c.toARGB32();
      expect(seen.containsKey(key), isFalse,
          reason: '$id and ${seen[key]} are the same colour');
      seen[key] = id;
    }
  });

  test('bands drawn next to each other are visibly different', () {
    final list = bandColors();
    for (var i = 1; i < list.length; i++) {
      final d = _perceptualDistance(list[i - 1].$2, list[i].$2);
      expect(d, greaterThan(40),
          reason: '${list[i - 1].$1} and ${list[i].$1} sit side by side on '
              'the wheel and are only $d apart — the complaint that '
              'prompted this test');
    }
  });

  test('every band differs from every other, not just its neighbour', () {
    final list = bandColors();
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

  test('a family still reads as one family', () {
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
          s['line'] as String, ids.indexOf(s['id'] as String), ids.length));
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
