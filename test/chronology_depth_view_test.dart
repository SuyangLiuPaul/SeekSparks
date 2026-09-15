// The 3D view must keep the original countries, radii and date angles.
// These tests use the shipped ring arithmetic and real power intervals;
// synthetic coordinates below are camera/layout scenarios, not chronology.
// The painter's prism paths also have to fit, including their raised walls.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/chronology_depth_view.dart';
import 'package:seeksparks/utils/chronology_explorer.dart'
    show chronologyPeriods;
import 'package:seeksparks/utils/radial_chronology_layout.dart';
import 'package:seeksparks/utils/wheel_default_streams.dart';
import 'package:seeksparks/utils/wheel_stack_layout.dart';

void expectOffset(Offset actual, Offset expected, {String? reason}) {
  expect(actual.dx, closeTo(expected.dx, 1e-8), reason: reason);
  expect(actual.dy, closeTo(expected.dy, 1e-8), reason: reason);
}

void expectInside(Rect inner, Rect outer, {String? reason}) {
  expect(inner.left, greaterThanOrEqualTo(outer.left - 1e-7), reason: reason);
  expect(inner.top, greaterThanOrEqualTo(outer.top - 1e-7), reason: reason);
  expect(inner.right, lessThanOrEqualTo(outer.right + 1e-7), reason: reason);
  expect(inner.bottom, lessThanOrEqualTo(outer.bottom + 1e-7), reason: reason);
}

void main() {
  final data = jsonDecode(File('assets/wheel_history.json').readAsStringSync())
      as Map<String, dynamic>;
  final ids = [
    for (final stream in data['streams'] as List) stream['id'] as String
  ];
  final allYears = chronologyPeriods.first;
  final intervals = [
    for (final power in data['powers'] as List)
      WheelStackInterval(
        id: power['id'] as String,
        stream: power['stream'] as String,
        start: power['start'] as int,
        end: (power['end'] as int?) ?? allYears.end,
      ),
  ];
  final tiers = planWheelStackTiers(intervals);

  group('original concentric rings', () {
    test('every asset stream keeps its flat ring, including the empty stream',
        () {
      for (final side in [179.0, 310.12, 800.0, 1200.0]) {
        final hub = side * .115;
        final outer = side * bandsFractionFor(side);
        final inputs = chronologyDepthRingInputs(
          ringIds: ids,
          depthByStream: tiers.depthByStream,
          hubRadius: hub,
          outerRadius: outer,
        );
        final rings = planChronologyDepthRings(inputs);
        expect(rings.map((ring) => ring.id), ids);
        for (var i = 0; i < rings.length; i++) {
          final flat = ringRadii(i, ids.length, hub, outer);
          final ring = rings[i];
          expect(identical(ring.input, inputs[i]), isTrue);
          expect(ring.innerRadius, flat.inner);
          expect(ring.outerRadius, flat.outer);
          expect(ring.depth, tiers.depthByStream[ring.id] ?? 0);
          expect(
              ring.maxHeight, lessThanOrEqualTo(flat.width * .70 * .60 + 1e-8));
        }
        final scripture = rings.singleWhere((ring) => ring.id == 'scripture');
        expect(scripture.depth, 0);
        expect(scripture.maxHeight, 0);
        expect(scripture.thickness, 0);
      }
    });

    test('deep records divide a local budget and respect narrower neighbours',
        () {
      const inputs = [
        ChronologyDepthRingInput(
            id: 'outer', innerRadius: 90, outerRadius: 100, depth: 2),
        ChronologyDepthRingInput(
            id: 'middle', innerRadius: 82, outerRadius: 86, depth: 8),
        ChronologyDepthRingInput(
            id: 'inner', innerRadius: 66, outerRadius: 78, depth: 3),
      ];
      final rings = planChronologyDepthRings(inputs);
      for (final ring in rings) {
        expect(ring.maxHeight, closeTo(4 * .70 * .60, 1e-10));
        for (var tier = 0; tier < ring.depth; tier++) {
          expect(ring.topHeight(tier), greaterThan(ring.bottomHeight(tier)));
          if (tier + 1 < ring.depth) {
            expect(ring.topHeight(tier), lessThan(ring.bottomHeight(tier + 1)));
          }
        }
      }
      expect(rings[1].tierStep, lessThan(rings[0].tierStep));
      final permuted = planChronologyDepthRings(inputs.reversed.toList());
      for (final ring in permuted) {
        final original = rings.singleWhere((r) => r.id == ring.id);
        expect(ring.tierStep, original.tierStep);
        expect(ring.maxHeight, original.maxHeight);
      }
    });

    test('flat starts with zero height and expansion preserves radii and tiers',
        () {
      final inputs = chronologyDepthRingInputs(
        ringIds: ids,
        depthByStream: tiers.depthByStream,
        hubRadius: 40,
        outerRadius: 140,
      );
      final flat = planChronologyDepthRings(inputs, lift: 0);
      final normal = planChronologyDepthRings(inputs);
      final expanded = planChronologyDepthRings(inputs, lift: 3);
      expect(chronologyDepthSquash(lift: 0), 1);
      expect(chronologyDepthSquash(lift: .5), closeTo(.85, 1e-10));
      expect(chronologyDepthSquash(lift: 3), closeTo(.70, 1e-10));
      for (var i = 0; i < inputs.length; i++) {
        expect(flat[i].maxHeight, 0);
        expect(flat[i].tierStep, 0);
        expect(expanded[i].maxHeight, closeTo(normal[i].maxHeight * 3, 1e-10));
        expect(expanded[i].innerRadius, normal[i].innerRadius);
        expect(expanded[i].outerRadius, normal[i].outerRadius);
        expect(expanded[i].depth, normal[i].depth);
      }
    });
  });

  group('whole wheel fit', () {
    test(
        'all real raised surfaces fit phones and short landscape at every tilt',
        () {
      for (final size in [const Size(360, 300), const Size(800, 180)]) {
        final side = math.min(size.width, size.height);
        final radius = side * rimFractionFor(side);
        final inputs = chronologyDepthRingInputs(
          ringIds: ids,
          depthByStream: tiers.depthByStream,
          hubRadius: side * .115,
          outerRadius: side * bandsFractionFor(side),
        );
        final content = Rect.fromLTRB(6, 12, size.width - 6, size.height - 12);
        for (final squash in [.35, .70, 1.0]) {
          for (final lift in [0.0, 1.0, 3.0]) {
            final rings =
                planChronologyDepthRings(inputs, tilt: squash, lift: lift);
            for (final yaw in [-math.pi, -.5, 0.0, math.pi / 2]) {
              final view = ChronologyDepthView.fit(
                contentArea: content,
                groundRadius: radius,
                rings: rings,
                squash: squash,
                yaw: yaw,
              );
              expectInside(view.screenBounds, content);
              final byId = {for (final ring in rings) ring.id: ring};
              for (final assignment in tiers.assignments) {
                final source = assignment.interval;
                final ring = byId[source.stream]!;
                final prism = WheelStackPrism(
                  id: source.id,
                  projection: view.projection,
                  innerRadius: ring.innerRadius,
                  outerRadius: ring.outerRadius,
                  startAngle:
                      angleForSpan(source.start, allYears.start, allYears.end) +
                          yaw,
                  endAngle:
                      angleForSpan(source.end, allYears.start, allYears.end) +
                          yaw,
                  bottomHeight: ring.bottomHeight(assignment.tier),
                  topHeight: ring.topHeight(assignment.tier),
                );
                if (prism.sweep == 0) {
                  final mark = view.fitTransform.toScreen(view.projection.polar(
                    prism.middleRadius,
                    prism.middleAngle,
                    height: prism.topHeight,
                  ));
                  expect(content.contains(mark), isTrue, reason: source.id);
                } else {
                  expectInside(
                      view.fitTransform.mapRect(prism.footprint.getBounds()),
                      content,
                      reason: '${source.id}, $size, $squash, $lift, $yaw');
                }
                expect(
                    identical(
                        source, intervals.firstWhere((r) => r.id == source.id)),
                    isTrue);
              }
            }
          }
        }
      }
    });

    test(
        'centred camera at fit does not throw elevated tops above the viewport',
        () {
      final rings = planChronologyDepthRings(const [
        ChronologyDepthRingInput(
            id: 'ring', innerRadius: 40, outerRadius: 100, depth: 8),
      ], lift: 3);
      const viewport = Rect.fromLTWH(0, 0, 360, 180);
      final view = ChronologyDepthView.fit(
        contentArea: viewport,
        groundRadius: 110,
        rings: rings,
      );
      final camera = const ChronologyDepthCamera();
      final transform = camera.restore(view: view, viewport: viewport);
      expect(transform.scale, view.fitTransform.scale);
      expectOffset(transform.translation, view.fitTransform.translation);
      expectInside(transform.mapRect(view.projectedBounds), viewport);
      expectOffset(transform.toScreen(view.projection.centre), viewport.center);
    });
  });

  group('shared flat and depth camera', () {
    test('ground picks preserve actual date angles through yaw and pitch', () {
      final years = {
        allYears.start,
        allYears.end,
        for (final interval in intervals) interval.start,
      };
      for (final squash in [.35, .70, 1.0]) {
        final projection =
            WheelStackProjection(centre: const Offset(170, 90), squash: squash);
        for (final yaw in [-2.4, 0.0, 1.3]) {
          for (final year in years) {
            final angle =
                angleForSpan(year, allYears.start, allYears.end) + yaw;
            final point = projection.polar(80, angle);
            expect(
                chronologyDepthYearAt(
                  point: point,
                  projection: projection,
                  startYear: allYears.start,
                  endYear: allYears.end,
                  yaw: yaw,
                  innerRadius: 40,
                  outerRadius: 120,
                ),
                year);
          }
          for (final point in [
            projection.polar(
                80, startRad + sweepRad + (2 * math.pi - sweepRad) / 2 + yaw),
            projection.polar(20, yaw),
            projection.polar(130, yaw),
          ]) {
            expect(
                chronologyDepthYearAt(
                  point: point,
                  projection: projection,
                  startYear: allYears.start,
                  endYear: allYears.end,
                  yaw: yaw,
                  innerRadius: 40,
                  outerRadius: 120,
                ),
                isNull);
          }
        }
      }
    });

    test(
        'the same ground point and fit-relative zoom survive tilt, yaw and resize',
        () {
      const flatViewport = Rect.fromLTWH(0, 0, 360, 300);
      const flatProjection =
          WheelStackProjection(centre: Offset(180, 150), squash: 1);
      const flatRadius = 118.0;
      for (final focal in [
        Offset.zero,
        const Offset(.42, -.31),
        const Offset(-1.4, .7)
      ]) {
        for (final zoom in [.8, 1.0, 3.4, 120.0]) {
          final camera =
              ChronologyDepthCamera(normalizedGroundCentre: focal, zoom: zoom);
          final flat = camera.toProjection(
            projection: flatProjection,
            groundRadius: flatRadius,
            viewport: flatViewport,
          );
          final captured = ChronologyDepthCamera.fromProjection(
            projection: flatProjection,
            groundRadius: flatRadius,
            viewport: flatViewport,
            scale: flat.scale,
            translation: flat.translation,
          );
          expectOffset(captured.normalizedGroundCentre, focal);
          expect(captured.zoom, closeTo(zoom, 1e-10));
          for (final squash in [.35, .70, 1.0]) {
            for (final yaw in [-2.4, .3, math.pi]) {
              final tilted = ChronologyDepthView(
                projection: WheelStackProjection(
                    centre: const Offset(14, 22), squash: squash),
                groundRadius: 175,
                contentArea: const Rect.fromLTWH(20, 10, 640, 210),
                maxHeight: 30,
                yaw: yaw,
              );
              final target =
                  captured.restore(view: tilted, viewport: tilted.contentArea);
              expectOffset(
                  target.toScreen(
                      tilted.projectGround(focal * tilted.groundRadius)),
                  tilted.contentArea.center);
              final returned = ChronologyDepthCamera.capture(
                view: tilted,
                viewport: tilted.contentArea,
                scale: target.scale,
                translation: target.translation,
              );
              expectOffset(returned.normalizedGroundCentre, focal);
              expect(returned.zoom, closeTo(zoom, 1e-10));
              final flatAgain = returned.toProjection(
                projection: flatProjection,
                groundRadius: flatRadius,
                viewport: flatViewport,
              );
              expect(flatAgain.scale, closeTo(flat.scale, 1e-8));
              expectOffset(flatAgain.translation, flat.translation);
            }
          }
        }
      }
    });

    test('height changes move the selected top without changing its date angle',
        () {
      final camera = const ChronologyDepthCamera(
        normalizedGroundCentre: Offset(.25, -.4),
        zoom: 2,
      );
      final view = ChronologyDepthView(
        projection: const WheelStackProjection(squash: .35),
        groundRadius: 120,
        contentArea: const Rect.fromLTWH(0, 0, 360, 200),
        maxHeight: 20,
        yaw: .8,
      );
      final transform = camera.restore(view: view, viewport: view.contentArea);
      final ground =
          view.projectGround(camera.normalizedGroundCentre * view.groundRadius);
      final top = view.projectGround(
          camera.normalizedGroundCentre * view.groundRadius,
          height: 12);
      expectOffset(transform.toScreen(ground), view.contentArea.center);
      expectOffset(transform.toScreen(top),
          view.contentArea.center - Offset(0, 12 * transform.scale));
    });
  });
}
