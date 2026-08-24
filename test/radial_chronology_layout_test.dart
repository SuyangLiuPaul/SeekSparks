import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/models/chronology.dart';
import 'package:seeksparks/utils/radial_chronology_layout.dart';

Patriarch _man(String id, int birth, int? begat, int death,
    {String line = 'seth', String tradition = 'mt'}) {
  return Patriarch(
    id: id,
    line: line,
    names: {'en': id},
    figures: {
      tradition: ChronologyFigures(
        begatAt: begat,
        livedAfter: begat == null ? null : death - birth - begat,
        lifespan: death - birth,
        birthAm: birth,
        deathAm: death,
        checked: true,
        refs: const {},
      ),
    },
  );
}

void main() {
  group('angleForYear', () {
    test('AM 0 sits at twelve o\'clock', () {
      expect(angleForYear(0, 2768), startRad);
    });

    test('the last year sits at the end of the sweep, not back at the start',
        () {
      expect(angleForYear(2768, 2768), closeTo(startRad + sweepRad, 1e-9));
    });

    test('is monotonic — later years are further round the wheel', () {
      var prev = angleForYear(0, 2768);
      for (var y = 100; y <= 2768; y += 100) {
        final a = angleForYear(y, 2768);
        expect(a, greaterThan(prev));
        prev = a;
      }
    });

    test('yearForAngle inverts it and rejects the gap wedge', () {
      for (final y in [0, 1, 930, 1656, 2768]) {
        expect(yearForAngle(angleForYear(y, 2768), 2768), y);
      }
      // Halfway into the gap: just before twelve o'clock coming the
      // long way round.
      final gapAngle = startRad + sweepRad + (2 * math.pi - sweepRad) / 2;
      expect(yearForAngle(gapAngle, 2768), isNull);
    });
  });

  group('buildWheelArcs', () {
    final people = [
      _man('adam', 0, 130, 930),
      _man('seth', 130, 105, 1042),
      _man('joseph', 2199, null, 2309, line: 'abraham'),
    ];

    test('ring follows generation order, first man outermost', () {
      final arcs = buildWheelArcs(people, 'mt', 2768);
      expect(arcs.map((a) => a.ring).toList(), [0, 1, 2]);
      expect(arcs.first.personId, 'adam');
    });

    test('birth, fathering and death angles come in order', () {
      final arcs = buildWheelArcs(people, 'mt', 2768);
      final adam = arcs.first;
      expect(adam.begatAngle, isNotNull);
      expect(adam.birthAngle, lessThan(adam.begatAngle!));
      expect(adam.begatAngle, lessThan(adam.deathAngle));
    });

    test('a man who ends the chain has no fathering angle rather than a '
        'zero one', () {
      final arcs = buildWheelArcs(people, 'mt', 2768);
      expect(arcs.last.personId, 'joseph');
      expect(arcs.last.begatAngle, isNull);
    });

    test('a man absent from the tradition is skipped, as Kainan is from '
        'the Hebrew', () {
      final withKainan = [
        _man('arphaxad', 1658, 35, 2096, tradition: 'lxx'),
        _man('kainan', 1793, 130, 2253, tradition: 'lxx'),
      ];
      expect(buildWheelArcs(withKainan, 'mt', 2768), isEmpty);
      expect(buildWheelArcs(withKainan, 'lxx', 2768).length, 2);
    });
  });

  group('ringRadii', () {
    test('ring 0 touches the rim and rings step inward without meeting '
        'the hub', () {
      final r0 = ringRadii(0, 26, 100, 400);
      final r25 = ringRadii(25, 26, 100, 400);
      expect(r0.outer, 400);
      expect(r25.inner, greaterThanOrEqualTo(100));
      expect(r0.inner, greaterThan(r25.outer));
    });

    test('leaves a gap between neighbouring rings', () {
      final r0 = ringRadii(0, 26, 100, 400);
      final r1 = ringRadii(1, 26, 100, 400);
      expect(r1.outer, lessThan(r0.inner));
    });
  });

  group('hitTest', () {
    final people = [
      _man('adam', 0, 130, 930),
      _man('seth', 130, 105, 1042),
    ];
    final arcs = buildWheelArcs(people, 'mt', 2768);

    test('the middle of an arc returns its man', () {
      final band = ringRadii(0, 2, 100, 400);
      final mid = angleForYear(465, 2768); // halfway through Adam's life
      expect(hitTest(band.centre, mid, arcs, 2, 100, 400)?.personId, 'adam');
    });

    test('the right ring decides between men alive in the same year', () {
      final year = angleForYear(500, 2768); // both alive in AM 500
      final adamBand = ringRadii(0, 2, 100, 400);
      final sethBand = ringRadii(1, 2, 100, 400);
      expect(
          hitTest(adamBand.centre, year, arcs, 2, 100, 400)?.personId, 'adam');
      expect(
          hitTest(sethBand.centre, year, arcs, 2, 100, 400)?.personId, 'seth');
    });

    test('the hub, the space beyond the rim, and the gap wedge all miss',
        () {
      final mid = angleForYear(465, 2768);
      expect(hitTest(50, mid, arcs, 2, 100, 400), isNull);
      expect(hitTest(450, mid, arcs, 2, 100, 400), isNull);
      final gapAngle = startRad + sweepRad + 0.1;
      final band = ringRadii(0, 2, 100, 400);
      expect(hitTest(band.centre, gapAngle, arcs, 2, 100, 400), isNull);
    });

    test('a year before birth on the right ring misses', () {
      final beforeSeth = angleForYear(60, 2768);
      final band = ringRadii(1, 2, 100, 400);
      expect(hitTest(band.centre, beforeSeth, arcs, 2, 100, 400), isNull);
    });
  });

  group('wheelTicks', () {
    test('every century, majors every five, none at zero', () {
      final ticks = wheelTicks(2768);
      expect(ticks.first.year, 100);
      expect(ticks.length, 27);
      expect(ticks.where((t) => t.major).map((t) => t.year),
          [500, 1000, 1500, 2000, 2500]);
    });
  });

  group('angleForSpan', () {
    test('min and max map to the axis ends, BC years included', () {
      expect(angleForSpan(-4000, -4000, 2026), startRad);
      expect(angleForSpan(2026, -4000, 2026),
          closeTo(startRad + sweepRad, 1e-9));
    });

    test('AD 1 lands past the halfway point of a -4000..2026 axis', () {
      final a = angleForSpan(1, -4000, 2026);
      expect(a, greaterThan(startRad + sweepRad / 2));
    });
  });

  group('stackRadialLabels', () {
    test('labels on distinct spokes each start at the base radius', () {
      final out = stackRadialLabels([0.0, 0.5, 1.0], [20, 20, 20], 100);
      expect(out.map((l) => l.rStart), [100, 100, 100]);
    });

    test('labels sharing a spoke step outward instead of overprinting', () {
      final out = stackRadialLabels([0.0, 0.0, 0.0], [20, 30, 10], 100);
      expect(out[0].rStart, 100);
      expect(out[1].rStart, greaterThanOrEqualTo(out[0].rEnd));
      expect(out[2].rStart, greaterThanOrEqualTo(out[1].rEnd));
    });

    test('a near-identical angle counts as the same spoke', () {
      // Two events four days apart on a 6000-year axis.
      final out = stackRadialLabels([0.0, 0.001], [20, 20], 100);
      expect(out[1].rStart, greaterThan(out[0].rStart));
    });

    test('the left half of the wheel is flagged for flipping', () {
      // 0 rad points right, pi points left.
      final out = stackRadialLabels([0.0, math.pi], [10, 10], 100);
      expect(out[0].flipped, isFalse);
      expect(out[1].flipped, isTrue);
    });
  });

  group('packIntoRings', () {
    test('non-overlapping items all stay on ring 0', () {
      expect(
          packIntoRings([0.0, 0.5, 1.0], [0.1, 0.6, 1.1], 3), [0, 0, 0]);
    });

    test('items closer than the gap spread across rings', () {
      final rings =
          packIntoRings([0.0, 0.005, 0.01], [0.0, 0.005, 0.01], 3);
      expect(rings.toSet().length, 3);
    });

    test('overflow falls back to a ring instead of crashing', () {
      final rings = packIntoRings(
          [0.0, 0.001, 0.002, 0.003], [0.0, 0.001, 0.002, 0.003], 2);
      expect(rings.length, 4);
      expect(rings.every((r) => r >= 0 && r < 2), isTrue);
    });

    test('a long band holds its ring for its whole length', () {
      // The band spans 0.0..1.0 on ring 0, so the dot at 0.5 must be
      // pushed to ring 1.
      expect(packIntoRings([0.0, 0.5], [1.0, 0.5], 2), [0, 1]);
    });
  });
}
