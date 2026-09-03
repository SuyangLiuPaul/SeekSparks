/// The strip's geometry, which is the part worth testing.
///
/// Where a claim in `strip_chronology_layout.dart`'s own doc comments is
/// measurable against the shipped corpus, these tests measure it rather
/// than restate the code — the same discipline `wheel_arc_hit_test.dart`
/// and `wheel_lifespans_test.dart` hold the radial file to.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/models/hebrew_king.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/utils/strip_chronology_layout.dart';

List<HebrewKing> _kings() =>
    ((jsonDecode(File('assets/hebrew_kings.json').readAsStringSync())
            as Map<String, dynamic>)['kings'] as List)
        .cast<Map<String, dynamic>>()
        .map(HebrewKing.fromJson)
        .toList();

List<WheelMinistry> _ministries() =>
    ((jsonDecode(File('assets/wheel_history.json').readAsStringSync())
            as Map<String, dynamic>)['ministries'] as List)
        .cast<Map<String, dynamic>>()
        .map(WheelMinistry.fromJson)
        .toList();

void main() {
  group('xForYear / yearForX', () {
    test('the axis start maps to content-x 0', () {
      expect(xForYear(kStripMinYear, 1.0), 0);
    });

    test('is the exact inverse of yearForX at every zoom step', () {
      for (final pxPerYear in kStripZoomSteps) {
        for (final year in [kStripMinYear, -1, 1, 1000, kStripMaxYear]) {
          final x = xForYear(year, pxPerYear);
          expect(yearForX(x, pxPerYear), closeTo(year, 1e-6),
              reason: 'round trip broke at $pxPerYear px/year, year $year');
        }
      }
    });

    test('is linear: doubling the year gap doubles the x gap', () {
      final a = xForYear(0, 2.0);
      final b = xForYear(500, 2.0);
      final c = xForYear(1000, 2.0);
      expect(c - b, closeTo(b - a, 1e-9));
    });
  });

  group('stripContentWidth', () {
    test('the whole 6226-year axis is 934 px at the smallest zoom step, '
        'as the library doc claims', () {
      expect(stripContentWidth(0.15), closeTo(933.9, 0.1));
    });

    test('equals xForYear at the max year', () {
      for (final pxPerYear in kStripZoomSteps) {
        expect(stripContentWidth(pxPerYear),
            xForYear(kStripMaxYear, pxPerYear));
      }
    });
  });

  group('spanWidth', () {
    test('a normal span is duration times zoom, never wider than that', () {
      expect(spanWidth(-100, -50, 2.0), 100);
    });

    test('is legitimately 0 for the corpus\' real zero-width reigns', () {
      // Zimri (seven days), Ahaziah of Judah, Jehoahaz of Judah and
      // Shallum of Israel all begin and end in the same year in the
      // real asset — verified in strip_lanes_test.dart, which is where
      // the claim actually matters. Here it only has to not crash and
      // not invent width.
      for (final k in _kings().where((k) => k.reignStart == k.reignEnd)) {
        for (final pxPerYear in kStripZoomSteps) {
          expect(spanWidth(k.reignStart, k.reignEnd, pxPerYear), 0,
              reason: '${k.id} must paint 0 px, not a fabricated sliver');
        }
      }
    });
  });

  group('pxPerYearToFit', () {
    test('fitting the whole axis into a viewport gives back the same '
        'ratio stripContentWidth would need to be undone', () {
      const viewport = 900.0;
      final fit = pxPerYearToFit(kStripMinYear, kStripMaxYear, viewport);
      expect(stripContentWidth(fit), closeTo(viewport, 1e-6));
    });

    test('a degenerate zero-year request falls back to the top of the '
        'ladder rather than dividing by zero', () {
      expect(pxPerYearToFit(500, 500, 900), kStripZoomSteps.last);
      expect(() => pxPerYearToFit(500, 500, 900), returnsNormally);
    });
  });

  group('snapZoom', () {
    test('every ladder value snaps to itself', () {
      for (final step in kStripZoomSteps) {
        expect(snapZoom(step), step);
      }
    });

    test('a value between two steps snaps to the nearer one', () {
      // 0.3 and 0.6: 0.4 is nearer 0.3, 0.5 is nearer 0.6.
      expect(snapZoom(0.4), 0.3);
      expect(snapZoom(0.5), 0.6);
    });

    test('always returns a real ladder member, for values far outside it',
        () {
      expect(kStripZoomSteps, contains(snapZoom(-5)));
      expect(kStripZoomSteps, contains(snapZoom(1000)));
    });
  });

  group('rulerStep', () {
    test('every zoom step\'s chosen ruler step clears the label width', () {
      for (final pxPerYear in kStripZoomSteps) {
        final step = rulerStep(pxPerYear);
        expect(step * pxPerYear, greaterThanOrEqualTo(56),
            reason: 'at $pxPerYear px/year, step $step gives '
                '${step * pxPerYear} px, under the 56 px a label needs');
      }
    });

    test('is always one of the nine nice values', () {
      const nice = {1, 5, 10, 25, 50, 100, 250, 500, 1000};
      for (final pxPerYear in kStripZoomSteps) {
        expect(nice, contains(rulerStep(pxPerYear)));
      }
    });

    test('a smaller labelPx never demands a larger step', () {
      for (final pxPerYear in kStripZoomSteps) {
        expect(rulerStep(pxPerYear, labelPx: 20),
            lessThanOrEqualTo(rulerStep(pxPerYear, labelPx: 80)));
      }
    });
  });

  group('rulerTicks', () {
    test('never emits year 0 — 1 BC is followed by AD 1', () {
      for (final step in [1, 5, 10, 25, 50, 100, 250, 500, 1000]) {
        expect(rulerTicks(step), isNot(contains(0)),
            reason: 'step $step must skip the year that does not exist');
      }
    });

    test('is strictly ascending and stays inside the axis', () {
      final ticks = rulerTicks(500);
      for (var i = 1; i < ticks.length; i++) {
        expect(ticks[i], greaterThan(ticks[i - 1]));
      }
      expect(ticks.first, greaterThanOrEqualTo(kStripMinYear));
      expect(ticks.last, lessThanOrEqualTo(kStripMaxYear));
    });

    test('lands on absolute multiples of step, not offsets from minYear',
        () {
      final ticks = rulerTicks(500);
      for (final y in ticks) {
        expect(y % 500, 0);
      }
      expect(ticks, contains(-4000));
      expect(ticks, contains(2000));
    });

    test('a step that does not divide the range still terminates and '
        'stays in range', () {
      final ticks = rulerTicks(137);
      expect(ticks, isNotEmpty);
      expect(ticks.first, greaterThanOrEqualTo(kStripMinYear));
      expect(ticks.last, lessThanOrEqualTo(kStripMaxYear));
    });
  });

  group('packIntoLanes', () {
    test('non-overlapping spans all land on lane 0', () {
      final lanes = packIntoLanes([0, 100, 200], [50, 150, 250]);
      expect(lanes, [0, 0, 0]);
    });

    test('two spans overlapping in pixels never share a lane', () {
      final lanes = packIntoLanes([0, 10], [50, 60]);
      expect(lanes[0], isNot(lanes[1]));
    });

    test('the lane count is exactly what the overlaps demand: four '
        'spans all mutually overlapping need four lanes, not the '
        'ring-count ceiling packIntoRings would have imposed', () {
      final lanes = packIntoLanes([0, 0, 0, 0], [100, 100, 100, 100]);
      expect(lanes.toSet().length, 4);
    });

    test('a span reuses a lane once the gap clears minGapPx', () {
      final lanes =
          packIntoLanes([0, 20], [10, 30], minGapPx: 5); // gap = 10
      expect(lanes, [0, 0]);
    });

    test('a span does NOT reuse a lane when the gap is under minGapPx', () {
      final lanes =
          packIntoLanes([0, 12], [10, 30], minGapPx: 5); // gap = 2
      expect(lanes, [0, 1]);
    });

    test('never overprints: no two spans sharing a lane come closer '
        'than minGapPx, over a randomised property check', () {
      final rand = math.Random(7);
      for (var trial = 0; trial < 50; trial++) {
        final n = 5 + rand.nextInt(20);
        final starts = List.generate(n, (_) => rand.nextDouble() * 500)
          ..sort();
        final ends = [
          for (final s in starts) s + rand.nextDouble() * 40,
        ];
        const gap = 4.0;
        final lanes = packIntoLanes(starts, ends, minGapPx: gap);
        final byLane = <int, List<int>>{};
        for (var i = 0; i < n; i++) {
          byLane.putIfAbsent(lanes[i], () => []).add(i);
        }
        for (final members in byLane.values) {
          for (var a = 0; a < members.length; a++) {
            for (var b = a + 1; b < members.length; b++) {
              final i = members[a], j = members[b];
              // starts is ascending, so whichever of i/j starts first
              // must end at least `gap` before the other starts.
              final first = starts[i] <= starts[j] ? i : j;
              final second = first == i ? j : i;
              expect(starts[second] - ends[first], greaterThanOrEqualTo(gap),
                  reason: 'trial $trial: spans $first and $second share a '
                      'lane but touch within $gap px');
            }
          }
        }
      }
    });
  });

  group('hitTargetFor', () {
    test('a span already wider than a finger is returned unchanged — '
        'the target never shrinks the ink, and never widens it either',
        () {
      final t = hitTargetFor(0, 20, fingerPx: 9);
      expect(t.x0, 0);
      expect(t.x1, 20);
    });

    test('a zero-width span gets exactly a finger of target, centred', () {
      final t = hitTargetFor(100, 100, fingerPx: 9);
      expect(t.x1 - t.x0, 9);
      expect((t.x0 + t.x1) / 2, closeTo(100, 1e-9));
    });

    test('a span narrower than a finger is widened to exactly a finger',
        () {
      final t = hitTargetFor(10, 13, fingerPx: 9); // 3 px wide
      expect(t.x1 - t.x0, 9);
      expect((t.x0 + t.x1) / 2, closeTo(11.5, 1e-9));
    });
  });

  group('nearestSpanAt', () {
    test('every one of the 42 real kings is hittable at the smallest '
        'zoom step, ONE LANE AT A TIME — the same precondition '
        '`nearestArcAt` states ("already filtered to ONE ring")', () {
      // A flat, unpacked tap test fails for a real and interesting
      // reason: Jotham of Judah (-750..-732) and Pekahiah of Israel
      // (-742..-740) share the exact same regnal MIDPOINT, -741, so a
      // tap at that year is genuinely ambiguous between two different
      // kings' widened targets until something else — a lane — tells
      // them apart. That is exactly why `buildStripLanes` packs the
      // 42 kings into sub-lanes instead of drawing them on one row:
      // this test packs first, the way the real page would, and then
      // asks the honest question per lane.
      const pxPerYear = 0.15; // kStripZoomSteps.first
      final kings = _kings();
      final starts = [for (final k in kings) xForYear(k.reignStart, pxPerYear)];
      final ends = [for (final k in kings) xForYear(k.reignEnd, pxPerYear)];
      final laneOf = packIntoLanes(starts, ends);

      final byLane = <int, List<int>>{};
      for (var i = 0; i < kings.length; i++) {
        byLane.putIfAbsent(laneOf[i], () => []).add(i);
      }
      expect(byLane.length, greaterThan(1),
          reason: 'the corpus has genuinely contemporary reigns; if this '
              'ever collapses to one lane the test above is meaningless');

      for (final members in byLane.values) {
        final laneSpans = [
          for (final i in members) (x0: starts[i], x1: ends[i]),
        ];
        for (var m = 0; m < members.length; m++) {
          final i = members[m];
          final centre = (laneSpans[m].x0 + laneSpans[m].x1) / 2;
          final hit = nearestSpanAt(centre, laneSpans);
          expect(hit, isNotNull,
              reason: '${kings[i].id} has no hittable target at rest zoom');
          expect(hit!.index, m,
              reason: 'a tap on ${kings[i].id}\'s own centre, within its '
                  'own lane, found a different king '
                  '(${kings[members[hit.index]].id})');
        }
      }
    });

    test('a tap well clear of every target finds nothing', () {
      final spans = [(x0: 0.0, x1: 5.0), (x0: 100.0, x1: 105.0)];
      expect(nearestSpanAt(50, spans), isNull);
    });

    test('of two overlapping widened targets, the point with the '
        'smaller NORMALISED distance wins, not the raw-closer one',
        () {
      // A: narrow (0..2, own floors to 4.5). B: wide (0..20, own 10).
      // x=3 is 2 px from A's centre and 7 px from B's — nearer in raw
      // terms too, but the claim being tested is the normalised score,
      // not raw distance, so this pins the actual formula.
      final spans = [(x0: 0.0, x1: 2.0), (x0: 0.0, x1: 20.0)];
      final hit = nearestSpanAt(3, spans);
      expect(hit!.index, 0);
      expect(hit.score, closeTo((3 - 1).abs() / 4.5, 1e-9));
    });
  });

  group('fitBarLabel', () {
    double latinMeasure(String text, double size) => text.length * size * 0.6;
    double cjkAwareMeasure(String text, double size) {
      var w = 0.0;
      for (final r in text.runes) {
        w += (r >= 0x4E00 && r <= 0x9FFF) ? size : size * 0.6;
      }
      return w;
    }

    test('text that already fits is returned whole, unellipsised', () {
      final r = fitBarLabel(
          text: 'Rome', roomPx: 200, size: 10, measure: latinMeasure);
      expect(r.text, 'Rome');
      expect(r.ellipsised, isFalse);
    });

    test('Chinese is whole or nothing — never cut mid-word', () {
      final r = fitBarLabel(
        text: '大英帝国',
        roomPx: 10, // room for well under one character
        size: 12,
        measure: cjkAwareMeasure,
      );
      expect(r.text, '');
      expect(r.ellipsised, isFalse);
      // Never, at any room size, does a CJK result contain a partial
      // word or an ellipsis.
      for (final room in [0.0, 5, 12, 24, 36, 48, 100, 1000]) {
        final res = fitBarLabel(
            text: '大英帝国', roomPx: room.toDouble(), size: 12,
            measure: cjkAwareMeasure);
        expect(res.ellipsised, isFalse);
        expect(res.text, anyOf('', '大英帝国'));
      }
    });

    test('Latin falls back to whole words with an ellipsis', () {
      final r = fitBarLabel(
        text: 'Holy Roman Empire',
        roomPx: 70, // fits one or two words, not all three
        size: 10,
        measure: latinMeasure,
      );
      expect(r.text, isNotEmpty);
      expect(r.text.endsWith('…'), isTrue);
      expect('Holy Roman Empire'.startsWith(r.text.replaceAll('…', '')),
          isTrue);
    });

    test('nothing legible fits: empty text, not a crash', () {
      final r = fitBarLabel(
          text: 'Rome', roomPx: 0, size: 10, measure: latinMeasure);
      expect(r.text, '');
    });
  });

  group('barLabelX', () {
    test('a bar entirely inside the viewport starts at its own left edge',
        () {
      final x = barLabelX(
          barX0: 100, barX1: 200, labelW: 40, viewX0: 0, viewX1: 900);
      expect(x, 100);
    });

    test('a bar much wider than the viewport pins its label to the '
        'visible left edge, not the bar\'s own start off-screen', () {
      // A 400-year empire at 6 px/year is 2400 px wide; the viewport
      // is scrolled to its middle.
      final x = barLabelX(
          barX0: 0, barX1: 2400, labelW: 100, viewX0: 800, viewX1: 1200);
      expect(x, 800);
    });

    test('the label never runs past the bar\'s own right edge, even '
        'when the visible slice would push it there', () {
      final x = barLabelX(
          barX0: 0, barX1: 2400, labelW: 100, viewX0: 2350, viewX1: 2750);
      expect(x + 100, closeTo(2400, 1e-9));
    });

    test('the label never starts left of the bar\'s own start', () {
      final x = barLabelX(
          barX0: 500, barX1: 600, labelW: 40, viewX0: 0, viewX1: 300);
      expect(x, greaterThanOrEqualTo(500));
    });
  });

  group('clusterByX', () {
    test('points well apart each become their own cluster', () {
      final out = clusterByX([0, 100, 200], 5);
      expect(out, hasLength(3));
      expect(out.every((c) => c.members.length == 1), isTrue);
    });

    test('points within minGapPx of the first member merge into one', () {
      final out = clusterByX([0, 1, 2, 3], 5);
      expect(out, hasLength(1));
      expect(out.first.members, [0, 1, 2, 3]);
      expect(out.first.representative, 0);
    });

    test('a new cluster starts once an x clears the FIRST member, even '
        'if it is close to the most recent one', () {
      // 0, 4, 8: each 4 from the last, but 8 is 8 from the first (0),
      // so it starts a new cluster once the gap to the anchor clears 5.
      final out = clusterByX([0, 4, 8], 5);
      expect(out, hasLength(2));
      expect(out[0].members, [0, 1]);
      expect(out[1].members, [2]);
    });

    test('the pinned member represents its own cluster', () {
      final out = clusterByX([0, 1, 2], 5, pinned: 2);
      expect(out, hasLength(1));
      expect(out.first.representative, 2);
    });
  });

  group('scrollToCentre', () {
    test('content narrower than the viewport needs no scroll', () {
      expect(scrollToCentre(0, 0.15, 2000), 0);
    });

    test('centres a mid-content year exactly, away from the clamps', () {
      const pxPerYear = 6.0;
      const viewport = 400.0;
      final px = xForYear(0, pxPerYear);
      final offset = scrollToCentre(0, pxPerYear, viewport);
      expect(offset, closeTo(px - viewport / 2, 1e-6));
    });

    test('never scrolls past the content\'s start or end', () {
      const pxPerYear = 6.0;
      const viewport = 400.0;
      final maxOffset = stripContentWidth(pxPerYear) - viewport;
      expect(scrollToCentre(kStripMinYear, pxPerYear, viewport), 0);
      expect(scrollToCentre(kStripMaxYear, pxPerYear, viewport),
          closeTo(maxOffset, 1e-6));
    });
  });

  // Guard on the guards above: if the corpus stops having zero-width
  // reigns, the tests that lean on that fact are proving nothing.
  test('the corpus really does still have zero-width reigns and '
      'zero-width ministries', () {
    final zeroKings =
        _kings().where((k) => k.reignStart == k.reignEnd).map((k) => k.id);
    expect(zeroKings,
        containsAll(<String>{'zimri', 'ahaziah_judah', 'jehoahaz_judah'}));
    final zeroMinistries =
        _ministries().where((m) => m.start == m.end).map((m) => m.id);
    expect(zeroMinistries, contains('huldah_prophet'));
  });
}
