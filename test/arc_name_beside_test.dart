/// A name that will not fit inside its arc goes just after it.
///
/// 2026-09-16 「这种也是后面有位置就应该可以放label」, of a three-year reign
/// at 3295% zoom with empty chart all round it and no name on it — and
/// 「这样wheel strip就一致了」: the strip already does exactly this for a
/// bar too narrow to hold its own name.
///
/// A short span is narrower than its own name at EVERY zoom, because the
/// arc and the glyphs magnify together. No amount of zooming fixes it.
/// What changes with the zoom is the room BESIDE it, which is what this
/// reaches for.
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/utils/radial_chronology_layout.dart';

void main() {
  // Roughly a CJK glyph per `size`, which is what the page's own
  // measure does for Chinese names.
  double measure(String text, double size) => text.length * size;

  group('how much room is beside an arc', () {
    const limit = 3.0;

    test('an empty ring after it offers everything up to the axis end', () {
      expect(arcNameRoomAfter(1.0, const [], const [], limit),
          closeTo(2.0, 1e-9));
    });

    test('the next arc on the ring stops it', () {
      expect(
          arcNameRoomAfter(
              1.0, const [], const [(start: 1.5, end: 2.0)], limit),
          closeTo(0.5, 1e-9));
    });

    test('a name already placed there stops it too', () {
      expect(
          arcNameRoomAfter(
              1.0, const [(start: 1.2, end: 1.4)], const [], limit),
          closeTo(0.2, 1e-9));
    });

    test('a span the arc sits INSIDE leaves no room at all', () {
      // The defect the first version shipped with: a power nested in a
      // longer one — Mehmed IV inside the Ottoman Empire — ends before
      // its container does, so the ring after it is the container's
      // ink, and usually the container's name. Looking only at spans
      // that START after the arc missed every one of those.
      expect(
          arcNameRoomAfter(
              1.0, const [], const [(start: 0.5, end: 2.5)], limit),
          0);
      expect(
          arcNameRoomAfter(
              1.0, const [(start: 0.5, end: 2.5)], const [], limit),
          0);
    });

    test('the arc asking does not block itself', () {
      // Its own extent ends exactly where the search begins.
      expect(
          arcNameRoomAfter(
              1.0, const [], const [(start: 0.2, end: 1.0)], limit),
          closeTo(2.0, 1e-9));
    });

    test('an arc that reaches the axis end has nowhere to go', () {
      expect(arcNameRoomAfter(limit, const [], const [], limit), 0);
      expect(arcNameRoomAfter(1.0, const [], const [], limit, gap: 5), 0);
    });
  });

  group('planning the names', () {
    const ringCount = 4;
    const rHub = 100.0;
    const rBands = 400.0;

    List<PlannedArcName> plan(List<ArcNameRequest> requests) => planArcNames(
          requests: requests,
          ringCount: ringCount,
          rHub: rHub,
          rBands: rBands,
          desiredSize: 12,
          zoom: 1,
          floorPx: 6,
          measure: measure,
        );

    test('a sliver is named beside itself when the ring is clear', () {
      final start = startRad + 0.4;
      final out = plan([
        (ring: 0, a0: start, a1: start + 0.002, name: '撒迦利雅'),
      ]);
      expect(out.single.name, '撒迦利雅');
      expect(out.single.a0, greaterThan(start + 0.002),
          reason: 'the name has to begin after the arc, not on it');
      expect(out.single.sweep, greaterThan(0));
    });

    test('and is left unnamed when the ring beside it is taken', () {
      final start = startRad + 0.4;
      final out = plan([
        // The long one is planned first (the caller sorts by span
        // descending) and claims the ring after the sliver.
        (ring: 0, a0: start + 0.003, a1: start + 1.2, name: '约坦'),
        (ring: 0, a0: start, a1: start + 0.002, name: '撒迦利雅'),
      ]);
      expect(out[0].name, '约坦');
      expect(out[1].name, isEmpty,
          reason: 'there is nowhere beside it that is not already someone '
              "else's arc");
    });

    test('a name that fits inside still goes inside', () {
      // The rule is inside-first, which is what makes one more step of
      // zoom put a name back in its box rather than leaving it adrift.
      final start = startRad + 0.2;
      final out = plan([
        (ring: 0, a0: start, a1: start + 1.4, name: '约西亚'),
      ]);
      expect(out.single.name, '约西亚');
      expect(out.single.a0, greaterThanOrEqualTo(start));
      expect(out.single.a0 + out.single.sweep,
          lessThanOrEqualTo(start + 1.4 + 1e-9));
    });

    test('two slivers side by side do not both claim the same gap', () {
      final start = startRad + 0.4;
      final out = plan([
        (ring: 0, a0: start, a1: start + 0.002, name: '亚哈斯'),
        (ring: 0, a0: start + 0.004, a1: start + 0.006, name: '何细亚'),
      ]);
      final placed = [
        for (final p in out)
          if (p.name.isNotEmpty) (start: p.a0, end: p.a0 + p.sweep)
      ];
      for (var i = 0; i < placed.length; i++) {
        for (var j = i + 1; j < placed.length; j++) {
          expect(
              placed[i].start < placed[j].end &&
                  placed[j].start < placed[i].end,
              isFalse,
              reason: 'two names printed over each other');
        }
      }
    });
  });

  test('a layer is never thinner than a layer can be', () {
    // The sub-layer policy, measured rather than asserted: this file
    // argued against sub-ringing at 22 streams and the arithmetic was
    // right. What changed is that the chart opens on four and will not
    // draw more than twelve.
    expect(streamTierCount(wanted: 8, ringCount: 22, rHub: 100, rMax: 253), 1,
        reason: 'the case the old argument measured — 0.87 units a layer');
    expect(streamTierCount(wanted: 8, ringCount: 4, rHub: 100, rMax: 400),
        greaterThan(1));
    expect(streamTierCount(wanted: 1, ringCount: 4, rHub: 100, rMax: 400), 1,
        reason: 'a stream with no overlaps asks for one layer and gets it');

    for (final ringCount in [1, 4, 8, 12]) {
      final tiers =
          streamTierCount(wanted: 8, ringCount: ringCount, rHub: 100, rMax: 400);
      final band = ringRadii(0, ringCount, 100, 400).width;
      expect(tierRadii(0, ringCount, 100, 400, tier: 0, tiers: tiers).width,
          greaterThanOrEqualTo(kStreamTierFloorPx * 0.8 - 1e-9),
          reason: '$ringCount rings, $tiers layers of a $band band');
      // Every layer stays inside its own ring, and they do not overlap.
      var previous = double.infinity;
      for (var t = 0; t < tiers; t++) {
        final slice = tierRadii(0, ringCount, 100, 400, tier: t, tiers: tiers);
        expect(slice.outer, lessThanOrEqualTo(previous + 1e-9));
        expect(slice.inner, greaterThanOrEqualTo(
            ringRadii(0, ringCount, 100, 400).inner - 1e-9));
        previous = slice.inner;
      }
      expect(math.max(tiers, 1), tiers);
    }
  });
}
