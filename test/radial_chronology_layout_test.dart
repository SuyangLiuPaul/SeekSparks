/// The wheel's geometry, which is the part worth testing.
///
/// FOUR GROUPS LEFT THIS FILE when the Anno Mundi half of
/// `radial_chronology_layout.dart` was deleted: `angleForYear`,
/// `buildWheelArcs`, `hitTest` and `wheelTicks`, plus the `Patriarch`
/// fixture they shared. They tested the wheel's first life, when it
/// drew the Genesis lifespans on an axis counted from the creation.
/// The wheel became world history in `b75ffc6` and the patriarchs kept
/// their own AM page; the code stayed behind, passing, for long enough
/// to read as an unfinished feature. `3b44f2e` holds all of it, tests
/// included, if it is ever wanted back.
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/utils/radial_chronology_layout.dart';

void main() {
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

  /// Panning a found record into view — the radial answer to what
  /// BibleWorks' timeline does when you type a date at it.
  group('focusTranslation', () {
    test('a point in the middle of the scene needs no pan', () {
      // At 4× the middle of the scene sits at 4 × 500 = 2000, and the
      // middle of the viewport is 500, so the scene moves back by 1500.
      final t = focusTranslation(
          px: 500, py: 400, scale: 4, viewW: 1000, viewH: 800);
      expect(t.dx, closeTo(-1500, 0.001));
      expect(t.dy, closeTo(-1200, 0.001));
    });

    /// The controller can be set to anything, so an unclamped jump
    /// leaves the canvas hanging half out of the frame until the
    /// reader's next gesture snaps it back. These are the bounds
    /// `InteractiveViewer` enforces for itself on a drag.
    test('a point near an edge is clamped to keep the canvas covering', () {
      final topLeft =
          focusTranslation(px: 0, py: 0, scale: 4, viewW: 1000, viewH: 800);
      expect(topLeft.dx, 0.0);
      expect(topLeft.dy, 0.0);

      final bottomRight = focusTranslation(
          px: 1000, py: 800, scale: 4, viewW: 1000, viewH: 800);
      expect(bottomRight.dx, closeTo(-3000, 0.001));
      expect(bottomRight.dy, closeTo(-2400, 0.001));
    });

    test('the clamp never lets the canvas leave the frame, anywhere', () {
      const w = 1000.0, h = 800.0;
      for (final scale in [1.5, 2.0, 7.0, 14.0]) {
        for (var i = 0; i <= 20; i++) {
          final t = focusTranslation(
              px: w * i / 20, py: h * i / 20, scale: scale, viewW: w, viewH: h);
          expect(t.dx, lessThanOrEqualTo(0.0001));
          expect(t.dy, lessThanOrEqualTo(0.0001));
          expect(t.dx, greaterThanOrEqualTo(w * (1 - scale) - 0.0001));
          expect(t.dy, greaterThanOrEqualTo(h * (1 - scale) - 0.0001));
        }
      }
    });

    /// At rest the whole wheel is on screen, so "centre this" has no
    /// work to do — and moving anyway would be motion for its own sake.
    test('nothing moves at a scale of 1 or less', () {
      for (final scale in [0.8, 1.0]) {
        final t = focusTranslation(
            px: 100, py: 700, scale: scale, viewW: 1000, viewH: 800);
        expect(t.dx, 0.0);
        expect(t.dy, 0.0);
      }
    });
  });
}
