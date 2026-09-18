// Stacking must separate simultaneous records without changing dates.
// The corpus assertions use the asset itself; synthetic integer spans
// below exercise adjacency and point records, not historical claims.
// Projection, face paths, labels and hit tests share the shipped helpers.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:yahwehs_sword/pages/radial_chronology_page.dart' show kMaxYear;
import 'package:yahwehs_sword/utils/chronology_explorer.dart'
    show chronologyPeriods;
import 'package:yahwehs_sword/utils/radial_chronology_layout.dart'
    show angleForSpan;
import 'package:yahwehs_sword/utils/wheel_stack_layout.dart';

WheelStackInterval interval(String id, int start, int end,
        {String stream = 'test'}) =>
    WheelStackInterval(id: id, stream: stream, start: start, end: end);

bool overlap(WheelStackInterval a, WheelStackInterval b) {
  if (a.stream != b.stream) return false;
  if (a.isPoint && b.isPoint) return a.start == b.start;
  if (a.isPoint) return b.start <= a.start && a.start < b.end;
  if (b.isPoint) return a.start <= b.start && b.start < a.end;
  return a.start < b.end && b.start < a.end;
}

int maximumConcurrency(Iterable<WheelStackInterval> rows) {
  var maximum = 0;
  for (final year in rows.map((row) => row.start).toSet()) {
    final active = rows.where((row) =>
        row.isPoint ? row.start == year : row.start <= year && year < row.end);
    maximum = math.max(maximum, active.length);
  }
  return maximum;
}

void expectNoTierConflicts(WheelStackPlan plan) {
  for (var i = 0; i < plan.assignments.length; i++) {
    final a = plan.assignments[i];
    for (var j = i + 1; j < plan.assignments.length; j++) {
      final b = plan.assignments[j];
      if (overlap(a.interval, b.interval)) {
        expect(a.tier, isNot(b.tier),
            reason: '${a.interval.id} and ${b.interval.id} coexist');
      }
    }
  }
}

WheelStackPrism prism(String id,
        {double inner = 40,
        double outer = 100,
        double start = 0,
        double end = math.pi,
        double bottom = 5,
        double top = 10}) =>
    WheelStackPrism(
        id: id,
        projection: const WheelStackProjection(),
        innerRadius: inner,
        outerRadius: outer,
        startAngle: start,
        endAngle: end,
        bottomHeight: bottom,
        topHeight: top);

void main() {
  group('interval tiers', () {
    test('adjacent intervals reuse a tier while nested ones stay separate', () {
      final rows = [
        interval('outer', 0, 10),
        interval('left', 0, 4),
        interval('right', 4, 10),
        interval('next', 10, 20),
        interval('independent', 0, 20, stream: 'other'),
      ];
      final plan = planWheelStackTiers(rows);
      expect(plan.depthByStream, {'other': 1, 'test': 2});
      expect(plan.tierById['left'], plan.tierById['right']);
      expect(plan.tierById['outer'], plan.tierById['next']);
      expectNoTierConflicts(plan);
      for (final assignment in plan.assignments) {
        expect(rows.contains(assignment.interval), isTrue,
            reason: 'the planner retains the exact input interval');
      }
    });

    test('points occupy their own year without inventing a duration', () {
      final rows = [
        interval('ends', 0, 5),
        interval('continues', 3, 8),
        interval('point-a', 5, 5),
        interval('point-b', 5, 5),
        interval('starts', 5, 7),
        interval('later', 8, 9),
      ];
      final plan = planWheelStackTiers(rows);
      expect(plan.depthByStream['test'], 4);
      expect(plan.tierById['ends'], plan.tierById['starts']);
      expect(plan.tierById['later'], 0);
      expectNoTierConflicts(plan);
      final points = plan.assignments.where((a) => a.interval.isPoint);
      expect(points.length, 2);
      for (final point in points) {
        expect(point.interval.start, 5);
        expect(point.interval.end, 5);
      }
    });

    test('source order does not change tiers and depths are minimal', () {
      final random = math.Random(734);
      final rows = [
        for (var i = 0; i < 120; i++)
          interval('record-$i', i % 17, i % 17 + random.nextInt(12),
              stream: 'stream-${i % 3}'),
      ];
      final original = planWheelStackTiers(rows);
      expectNoTierConflicts(original);
      final shuffled = rows.toList()..shuffle(random);
      expect(planWheelStackTiers(shuffled).tierById, original.tierById);
      expect(planWheelStackTiers(rows.reversed).tierById, original.tierById);
      for (final stream in original.depthByStream.keys) {
        expect(original.depthByStream[stream],
            maximumConcurrency(rows.where((row) => row.stream == stream)));
      }
    });

    test('bad intervals and repeated identifiers are rejected', () {
      expect(() => planWheelStackTiers([interval('bad', 2, 1)]),
          throwsArgumentError);
      expect(
          () => planWheelStackTiers(
              [interval('same', 0, 2), interval('same', 2, 4)]),
          throwsArgumentError);
      expect(planWheelStackTiers([]).assignments, isEmpty);
    });

    test('actual powers retain their dates and attain their measured depths',
        () {
      final data =
          jsonDecode(File('assets/wheel_history.json').readAsStringSync())
              as Map<String, dynamic>;
      final rows = [
        for (final power in data['powers'] as List)
          WheelStackInterval(
              id: power['id'] as String,
              stream: power['stream'] as String,
              start: power['start'] as int,
              end: (power['end'] as int?) ?? kMaxYear),
      ];
      final plan = planWheelStackTiers(rows);
      expect(plan.assignments.length, rows.length);
      expectNoTierConflicts(plan);
      expect(plan.depthByStream, {
        'israel': 2,
        'judah': 2,
        'assyria': 1,
        'babylon': 2,
        'persia': 1,
        'arabia': 2,
        'islam': 2,
        'egypt': 2,
        'phoenicia': 1,
        'philistia': 1,
        'anatolia': 2,
        'greece': 5,
        'rome': 6,
        'byzantium': 3,
        'europe': 8,
        'americas': 4,
        'china': 2,
        // 2026-09-16: 1 → 2. Japan's lane used to hold four bands that
        // never overlapped. It now runs 飛鳥 → 日本國, and 戰國 (1467-
        // 1603) crosses the two shogunates it broke, exactly as 推古
        // sits inside 飛鳥 — so the lane needs two tiers, which is what
        // this number is for.
        'japan': 2,
        'india': 2,
        'church': 6,
        'world': 7,
      });
      for (final stream in plan.depthByStream.keys) {
        expect(plan.depthByStream[stream],
            maximumConcurrency(rows.where((row) => row.stream == stream)));
      }
      expect(planWheelStackTiers(rows.reversed).tierById, plan.tierById);
      for (final assignment in plan.assignments) {
        expect(rows.contains(assignment.interval), isTrue);
      }
      // 2026-09-16: 20 → 23. 「中国还有很多其他的在清朝之后很多 都
      // missing了在strip里面」 — the chain used to stop at 清朝/1912,
      // 114 years short of the axis. 民国, 軍閥割據 and 人民共和國 close
      // it.
      final china = rows.where((row) => row.stream == 'china');
      expect(china.length, 23);
      expect(rows.where((row) => row.isPoint).map((row) => row.id).toSet(),
          {'gedaliah-governor', 'eighth-crusade'});
    });
  });

  group('projected annular prisms', () {
    test('projection preserves the flat point and year angle at every height',
        () {
      const projection = WheelStackProjection(centre: Offset(25, 40));
      expect(projection.project(const Offset(10, 20), height: 8),
          const Offset(35, 44.8));
      for (final height in [0.0, 12.0, 96.0]) {
        for (final angle in [-math.pi / 2, 0.0, 2.7, math.pi * 1.5]) {
          final flat = Offset(math.cos(angle), math.sin(angle)) * 70;
          final recovered = projection.unproject(
              projection.project(flat, height: height),
              height: height);
          expect((flat - recovered).distance, lessThan(1e-9));
        }
      }
    });

    test('top, bottom, visible wall and hit footprint agree', () {
      final solid = prism('solid', inner: 50, outer: 90, bottom: 4);
      final top = solid.projection.polar(70, math.pi / 2, height: 10);
      final bottom = solid.projection.polar(70, math.pi / 2, height: 4);
      final wall = solid.projection.polar(90, math.pi / 2, height: 7);
      expect(solid.topPath.contains(top), isTrue);
      expect(solid.bottomPath.contains(bottom), isTrue);
      expect(solid.topPath.contains(wall), isFalse);
      expect(solid.sidePaths.any((path) => path.contains(wall)), isTrue);
      expect(solid.contains(top), isTrue);
      expect(solid.contains(wall), isTrue);
      expect(solid.contains(const Offset(0, -10)), isFalse,
          reason: 'the annular hole must stay transparent and untappable');
      final point = prism('point', start: 1, end: 1);
      expect(point.footprint.getBounds().isEmpty, isTrue);
      expect(point.contains(point.projection.polar(70, 1)), isFalse);
    });

    test('a zero-year marker is tappable without widening its duration', () {
      final point = prism('point', start: 1, end: 1);
      final centre = point.projection.polar(point.middleRadius, 1, height: 10);
      expect(hitWheelStackPrism([point], centre)?.id, 'point');
      expect(hitWheelStackPrism([point], centre + const Offset(5, 0))?.id,
          'point');
      expect(hitWheelStackPrism([point], centre + const Offset(7, 0)), isNull);
      expect(
          hitWheelStackPrism([point], centre + const Offset(4, 0),
              pointRadius: 3),
          isNull);
      expect(point.sweep, 0);
      expect(point.topPath.getBounds().isEmpty, isTrue);
      expect(point.bottomPath.getBounds().isEmpty, isTrue);
      expect(point.footprint.getBounds().isEmpty, isTrue);
    });

    test('clicks choose the last painted visible footprint', () {
      final lower = prism('lower', top: 6, bottom: 0);
      final upper = prism('upper', top: 10, bottom: 7);
      final point = upper.projection.polar(70, math.pi / 2, height: 10);
      expect(lower.contains(point), isTrue);
      expect(upper.contains(point), isTrue);
      final order = wheelStackPaintOrder([upper, lower]);
      expect(order.map((p) => p.id), ['lower', 'upper']);
      expect(hitWheelStackPrism(order, point)?.id, 'upper');
      expect(hitWheelStackPrism(order, const Offset(300, 300)), isNull);
      expect(wheelStackPaintOrder(order.reversed).map((p) => p.id),
          order.map((p) => p.id));
    });

    test('same-tier near faces paint after the far side', () {
      final far = prism('far', start: math.pi, end: 2 * math.pi);
      final near = prism('near');
      expect(
          wheelStackPaintOrder([near, far]).map((p) => p.id), ['far', 'near']);
    });
  });

  group('top-face labels', () {
    test('a fitting name remains upright and wholly on its own top face', () {
      final solid = prism('label');
      final label = wheelStackLabelPlacement(solid, const Size(28, 12));
      expect(label, isNotNull);
      expect(label!.rotation.abs(), lessThanOrEqualTo(math.pi / 2));
      expect(solid.topPath.contains(label.centre), isTrue);
      for (final corner in label.corners) {
        expect(solid.topPath.contains(corner), isTrue);
      }
      expect(wheelStackLabelPlacement(solid, const Size(1000, 12)), isNull);
    });

    test('hidden faces and previously used text space cannot receive labels',
        () {
      final lower = prism('lower');
      final upper = prism('upper', bottom: 7, top: 12);
      // A name may stand just past the end of its own face when nothing
      // fits ON it (2026-09-16 「如果框框放不下 就放在那个线或者窄框框后
      // 面」) — but not here: `upper` covers this sector at a greater
      // height, and its side walls sweep down across the room past the
      // end of `lower` too.
      expect(
          wheelStackLabelPlacement(lower, const Size(28, 12),
              occluders: [upper]),
          isNull);
      expect(
          wheelStackLabelPlacement(lower, const Size(28, 12),
              occupied: [const Rect.fromLTRB(-200, -200, 200, 200)]),
          isNull);
      final first = wheelStackLabelPlacement(lower, const Size(20, 8));
      final next = wheelStackLabelPlacement(lower, const Size(20, 8),
          occupied: [first!.bounds]);
      expect(next, isNotNull);
      expect(next!.bounds.inflate(2).overlaps(first.bounds), isFalse);
    });

    test('a face too small for its name is named just past its end', () {
      // 2026-09-16 「如果框框放不下 就放在那个线或者窄框框后面 如果后面有
      // 位置」 and 「这样wheel strip就一致了」. A three-degree sliver cannot
      // carry a name; the ring beside it usually can, and the strip
      // already does exactly this for a bar too narrow to hold one.
      final sliver = prism('sliver', start: 0, end: .05);
      final placed = wheelStackLabelPlacement(sliver, const Size(30, 11));
      expect(placed, isNotNull,
          reason: 'a sliver with an empty ring beside it got no name');
      expect(placed!.beyondFace, isTrue);

      // It stays on the record's OWN ring, so which ring it belongs to
      // is never in doubt.
      const projection = WheelStackProjection();
      final ring = (placed.centre - projection.centre).distance;
      expect(ring, greaterThan(sliver.innerRadius * .55));

      // And it gives way to whatever is already there.
      final neighbour = prism('neighbour', start: .06, end: math.pi);
      expect(
          wheelStackLabelPlacement(sliver, const Size(30, 11),
              beside: [sliver, neighbour]),
          isNull);
    });

    test('visible point markers also reserve their ink above rear labels', () {
      // The placement search walks several points along the arc
      // (2026-09-16 「这些放得了放得下的都应该放」), so a marker sitting on
      // one of them moves the name rather than cancelling it. What must
      // hold either way is that a name is never drawn THROUGH a marker.
      final lower = prism('lower');
      final points = [
        for (final fraction in [.25, .5, .75])
          prism('point-$fraction',
              start: math.pi * fraction, end: math.pi * fraction),
      ];
      final moved = wheelStackLabelPlacement(lower, const Size(28, 12),
          occluders: points, pointRadius: 3);
      expect(moved, isNotNull);
      for (final point in points) {
        final ink = wheelStackPointFootprint(point, radius: 3);
        for (final corner in moved!.corners) {
          expect(ink.contains(corner), isFalse,
              reason: 'the name was placed over ${point.id}');
        }
      }

      // And when everywhere on the face AND the room past its end are
      // both taken, it still refuses rather than drawing over them.
      final everywhere = [
        for (final fraction in [.12, .25, .37, .5, .63, .75, .88, 1.1])
          prism('point-$fraction',
              start: math.pi * fraction, end: math.pi * fraction),
      ];
      expect(
          wheelStackLabelPlacement(lower, const Size(28, 12),
              occluders: everywhere,
              beside: [lower, ...everywhere],
              pointRadius: 3),
          isNull);
    });
  });

  group('side callouts', () {
    const content = Rect.fromLTRB(6, 32, 494, 310);

    WheelStackPrism calloutPrism(String id,
            {double start = 0,
            double end = math.pi,
            double top = 10,
            double bottom = 5}) =>
        WheelStackPrism(
            id: id,
            projection: const WheelStackProjection(centre: Offset(250, 180)),
            innerRadius: 40,
            outerRadius: 100,
            startAngle: start,
            endAngle: end,
            bottomHeight: bottom,
            topHeight: top);

    test('banks fit the viewport and retain the per-side limit and text gap',
        () {
      final points = [
        for (var i = 0; i < 8; i++)
          calloutPrism('point-$i',
              start: i * math.pi / 4 + .1, end: i * math.pi / 4 + .1),
      ];
      final result = planWheelStackCallouts(
          paintOrder: points,
          contentArea: content,
          measure: (_) => const Size(100, 18),
          maxPerSide: 2);
      expect(result.length, 4);
      for (final side in WheelStackCalloutSide.values) {
        expect(result.where((callout) => callout.side == side).length, 2);
      }
      for (final callout in result) {
        expect(content.contains(callout.anchor), isTrue);
        expect(callout.bounds.left, greaterThanOrEqualTo(content.left));
        expect(callout.bounds.right, lessThanOrEqualTo(content.right));
        expect(callout.bounds.top, greaterThanOrEqualTo(content.top));
        expect(callout.bounds.bottom, lessThanOrEqualTo(content.bottom));
        expect(callout.bounds.size, const Size(100, 18));
        if (callout.side == WheelStackCalloutSide.left) {
          expect(callout.bounds.right, lessThanOrEqualTo(144));
        } else {
          expect(callout.bounds.left, greaterThanOrEqualTo(356));
        }
        for (final other in result.where((other) => other.id != callout.id)) {
          expect(callout.bounds.inflate(7).overlaps(other.bounds), isFalse);
          // Check the route the painter will actually draw, independent
          // of the planner's rectangle/segment intersection calculation.
          for (var step = 0; step <= 1000; step++) {
            final point =
                Offset.lerp(callout.anchor, callout.leaderEnd, step / 1000)!;
            expect(other.bounds.contains(point), isFalse);
          }
        }
      }
    });

    test('excluded front names still occlude rear anchors', () {
      final back = calloutPrism('back');
      final front = calloutPrism('front', bottom: 7, top: 12);
      final result = planWheelStackCallouts(
          paintOrder: [back, front],
          contentArea: content,
          measure: (_) => const Size(100, 18),
          excludedIds: {'front'});
      expect(result, isEmpty,
          reason: 'removing already named faces from paintOrder would reveal '
              'an anchor that the actual painting hides');
      final visible = planWheelStackCallouts(
          paintOrder: [back, front],
          contentArea: content,
          measure: (_) => const Size(100, 18));
      expect(visible.map((callout) => callout.id), ['front']);
      expect(front.topPath.contains(visible.single.anchor), isTrue);
    });

    test('point markers hide anchors but keep their own zero-width date', () {
      final back = calloutPrism('back');
      final front = [
        for (final fraction in [.5, .25, .75])
          calloutPrism('point-$fraction',
              start: math.pi * fraction, end: math.pi * fraction),
      ];
      final behindMarkers = planWheelStackCallouts(
          paintOrder: [back, ...front],
          contentArea: content,
          measure: (_) => const Size(100, 18),
          excludedIds: {for (final point in front) point.id});
      expect(behindMarkers, hasLength(1),
          reason: 'three marks hide their own ink, not the entire rear face');
      expect(behindMarkers.single.id, 'back');
      for (final point in front) {
        expect(
            wheelStackPointFootprint(point, radius: 3)
                .contains(behindMarkers.single.anchor),
            isFalse);
      }
      final callout = planWheelStackCallouts(
          paintOrder: [front.first],
          contentArea: content,
          measure: (_) => const Size(100, 18));
      expect(callout, hasLength(1));
      expect(
          wheelStackPointFootprint(front.first, radius: 3)
              .contains(callout.single.anchor),
          isTrue);
      expect(front.first.sweep, 0);
    });

    test('Liao remains nameable when Song hides its middle-radius anchors', () {
      final data =
          jsonDecode(File('assets/wheel_history.json').readAsStringSync())
              as Map<String, dynamic>;
      final powers = data['powers'] as List;
      final rows = [
        for (final id in ['liao-khitan', 'song-dynasty'])
          (() {
            final power = powers.firstWhere((power) => power['id'] == id);
            return WheelStackInterval(
                id: id,
                stream: power['stream'] as String,
                start: power['start'] as int,
                end: power['end'] as int);
          })(),
      ];
      final tiers = planWheelStackTiers(rows);
      final period = chronologyPeriods.singleWhere((p) => p.id == 'late');
      const projection = WheelStackProjection(centre: Offset(250, 169.6));
      final prisms = [
        for (final row in rows)
          WheelStackPrism(
              id: row.id,
              projection: projection,
              innerRadius: 140 * .4544,
              outerRadius: 140,
              startAngle:
                  angleForSpan(row.start, period.start, period.end) - .28,
              endAngle: angleForSpan(row.end, period.start, period.end) - .28,
              bottomHeight: tiers.tierById[row.id]! * 24.0 + 5,
              topHeight: tiers.tierById[row.id]! * 24.0 + 13),
      ];
      final liao = prisms.singleWhere((p) => p.id == 'liao-khitan');
      final song = prisms.singleWhere((p) => p.id == 'song-dynasty');
      for (final fraction in [.5, .25, .75]) {
        final oldAnchor = projection.polar(
            liao.middleRadius, liao.startAngle + liao.sweep * fraction,
            height: liao.topHeight);
        expect(song.contains(oldAnchor), isTrue,
            reason: 'the old centre-only search misses Liao in this view');
      }
      final result = planWheelStackCallouts(
          paintOrder: wheelStackPaintOrder(prisms),
          contentArea: const Rect.fromLTRB(6, 32, 494, 350),
          measure: (_) => const Size(95, 18),
          bankWidth: 95,
          excludedIds: {song.id});
      expect(result.map((callout) => callout.id), [liao.id]);
      final callout = result.single;
      expect(liao.topPath.contains(callout.anchor), isTrue);
      expect(song.contains(callout.anchor), isFalse);
      expect(callout.bounds.left, greaterThanOrEqualTo(6));
      expect(callout.bounds.right, lessThanOrEqualTo(494));
      expect(callout.bounds.top, greaterThanOrEqualTo(32));
      expect(callout.bounds.bottom, lessThanOrEqualTo(350));
    });

    test('leaders route around existing labels instead of drawing through them',
        () {
      final point = calloutPrism('point', start: math.pi, end: math.pi);
      const obstacle = Rect.fromLTRB(138, 145, 160, 185);
      final result = planWheelStackCallouts(
          paintOrder: [point],
          contentArea: content,
          measure: (_) => const Size(100, 18),
          occupied: [obstacle]);
      expect(result, hasLength(1));
      final callout = result.single;
      expect(callout.bounds.inflate(7).overlaps(obstacle), isFalse);
      for (var step = 0; step <= 1000; step++) {
        expect(
            obstacle.contains(
                Offset.lerp(callout.anchor, callout.leaderEnd, step / 1000)!),
            isFalse);
      }
    });

    test('caller-sized narrow banks do not silently shrink the measured text',
        () {
      final point = WheelStackPrism(
          id: 'narrow-point',
          projection: const WheelStackProjection(centre: Offset(180, 170)),
          innerRadius: 60,
          outerRadius: 107,
          startAngle: 0,
          endAngle: 0,
          bottomHeight: 5,
          topHeight: 10);
      const phoneContent = Rect.fromLTRB(6, 32, 354, 310);
      final fitting = planWheelStackCallouts(
          paintOrder: [point],
          contentArea: phoneContent,
          measure: (_) => const Size(58, 18),
          bankWidth: 58);
      expect(fitting, hasLength(1));
      expect(fitting.single.bounds.size, const Size(58, 18));
      expect(
          planWheelStackCallouts(
              paintOrder: [point],
              contentArea: phoneContent,
              measure: (_) => const Size(59, 18),
              bankWidth: 58),
          isEmpty);
    });
  });
}
