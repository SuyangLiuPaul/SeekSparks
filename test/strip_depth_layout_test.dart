/// The strip paints and taps the same faces. Depth is a screen-space
/// projection; the exact date width and every record identity survive.
library;

import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/strip_depth_layout.dart';

void main() {
  test('front keeps date width; roof and side resolve to the same record', () {
    final shape = stripDepthPrism(
        id: 'record', front: const Rect.fromLTWH(100, 20, 80, 28));
    expect(shape.front.left, 100);
    expect(shape.front.right, 180);
    for (final point in [
      shape.front.center,
      const Offset(140, 17),
      const Offset(183, 31)
    ]) {
      expect(hitStripDepthShapes([shape], point, touchRadius: 0)?.id, 'record');
    }
    expect(hitStripDepthShapes([shape], const Offset(106, 15), touchRadius: 0),
        isNotNull);
    expect(hitStripDepthShapes([shape], const Offset(100, 14), touchRadius: 0),
        isNull,
        reason: 'the empty corner of the bounds is not a face');
  });

  test('visible front wins over a rear roof and any padded target', () {
    final rear =
        stripDepthPrism(id: 'rear', front: const Rect.fromLTWH(0, 20, 30, 20));
    final front = stripDepthPrism(
        id: 'front', front: const Rect.fromLTWH(34, 20, 30, 20));
    const shared = Offset(35, 25);
    expect(rear.contains(shared), isTrue);
    expect(front.contains(shared), isTrue);
    expect(hitStripDepthShapes([rear, front], shared)?.id, 'front');
    expect(hitStripDepthShapes([front, rear], shared)?.id, 'rear');
    expect(hitStripDepthShapes([rear, front], const Offset(29, 36))?.id, 'rear',
        reason: 'the neighbouring padded target cannot steal a visible front');
  });

  test('a point gets a side marker and never a fictional duration', () {
    final shape = layoutStripDepthSpan(
        id: 'point',
        x0: 50,
        x1: 50,
        rowTop: 100,
        rowHeight: stripDepthRowHeight(32, 0),
        flatHeight: 32,
        tier: 0);
    expect(shape.front.width, 0);
    expect(stripDepthLabelArea(shape, 0, 100), Rect.zero);
    expect(hitStripDepthShapes([shape], shape.front.center)?.id, 'point');
    final side =
        shape.side.reduce((a, b) => a + b) / shape.side.length.toDouble();
    expect(hitStripDepthShapes([shape], side, touchRadius: 0)?.id, 'point');
  });

  test('genealogy depth retains the cohort count in marker height', () {
    StripDepthShape cohort(int count) => layoutStripDepthSpan(
        id: '$count',
        x0: 100,
        x1: 100,
        rowTop: 0,
        rowHeight: 48,
        flatHeight: 32,
        tier: 0,
        cohortSize: count);
    expect(cohort(1).front.height, lessThan(cohort(8).front.height));
    expect(cohort(8).front.height, cohort(44).front.height);
    expect(cohort(44).front.width, 0);
  });

  test('all supported tiers reserve roof and readable front within their row',
      () {
    for (final flatHeight in [32.0, 64.0, 96.0]) {
      var top = 0.0;
      for (var tier = 0; tier < 20; tier++) {
        final height = stripDepthRowHeight(flatHeight, tier);
        final shape = layoutStripDepthSpan(
            id: '$tier',
            x0: 10,
            x1: 200,
            rowTop: top,
            rowHeight: height,
            flatHeight: flatHeight,
            tier: tier);
        expect(shape.bounds.top, greaterThanOrEqualTo(top));
        expect(shape.bounds.bottom, lessThan(top + height));
        final label = stripDepthLabelArea(shape, 50, 150);
        expect(label.left, 54);
        expect(label.right, 146);
        expect(shape.front.contains(label.topLeft), isTrue);
        expect(shape.front.contains(label.bottomRight), isTrue);
        expect(label.height, greaterThan(16));
        top += height;
      }
    }
  });

  test(
      'mode switch restores the same row and relative location in both directions',
      () {
    const flat = [
      (id: 'heading', top: 0.0, height: 40.0),
      (id: 'egypt:0', top: 40.0, height: 32.0),
      (id: 'egypt:1', top: 72.0, height: 32.0)
    ];
    const raised = [
      (id: 'heading', top: 0.0, height: 40.0),
      (id: 'egypt:0', top: 40.0, height: 48.0),
      (id: 'egypt:1', top: 88.0, height: 50.0)
    ];
    final anchor = stripDepthScrollAnchor(flat, 80);
    expect(anchor, (id: 'egypt:1', fraction: .25));
    final offset = stripDepthOffsetForAnchor(raised, anchor)!;
    expect(offset, 100.5);
    expect(
        stripDepthOffsetForAnchor(flat, stripDepthScrollAnchor(raised, offset)),
        80);
  });
}
