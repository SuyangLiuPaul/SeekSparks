/// Oblique prisms for the complete strip. Time remains the front face's
/// x extent; projection only adds visible top and side faces. Every
/// country keeps its existing rows, so depth never means solo focus.
library;

import 'dart:math' as math;
import 'dart:ui';

class StripDepthShape {
  const StripDepthShape(
      {required this.id,
      required this.front,
      required this.top,
      required this.side,
      required this.bounds,
      required this.tier});
  final String id;
  final Rect front;
  final List<Offset> top;
  final List<Offset> side;
  final Rect bounds;
  final int tier;

  List<Offset> get frontFace =>
      [front.topLeft, front.topRight, front.bottomRight, front.bottomLeft];
  Iterable<List<Offset>> get faces => [top, side, frontFace];
  bool contains(Offset point) =>
      faces.any((face) => stripDepthFaceContains(face, point));
}

/// Each packed row reserves its own roof and vertical face. Increasing
/// tier height cannot cover the preceding row or its label.
double stripDepthRowHeight(double flatHeight, int tier) =>
    flatHeight + 16 + math.min(8, math.max(0, tier)) * 2;

StripDepthShape stripDepthPrism(
    {required String id,
    required Rect front,
    double skew = 6,
    double rise = 6,
    int tier = 0}) {
  final back = Offset(skew, -rise);
  final top = [
    front.topLeft,
    front.topLeft + back,
    front.topRight + back,
    front.topRight
  ];
  final side = [
    front.topRight,
    front.topRight + back,
    front.bottomRight + back,
    front.bottomRight
  ];
  return StripDepthShape(
      id: id,
      front: front,
      top: List.unmodifiable(top),
      side: List.unmodifiable(side),
      tier: tier,
      bounds: front.expandToInclude(front.shift(back)));
}

StripDepthShape layoutStripDepthSpan(
    {required String id,
    required double x0,
    required double x1,
    required double rowTop,
    required double rowHeight,
    required double flatHeight,
    required int tier,
    int? cohortSize}) {
  final level = math.min(8, math.max(0, tier));
  // A genealogy marker still encodes its actual cohort count using the
  // flat rail's height scale. Projection must not replace that fact
  // with the lane's packing tier.
  final cohortFraction = cohortSize == null
      ? 1.0
      : (.34 + .66 * ((cohortSize - 1) / 7)).clamp(.34, 1.0);
  final height = (flatHeight * .68 + level * 2) * cohortFraction;
  // The unprojected lower edge still names the exact start/end years,
  // including a zero-width point. Its side face is a marker, not extra
  // historical duration; widening the front would falsify the axis.
  final front = Rect.fromLTRB(
      x0, rowTop + rowHeight - 6 - height, x1, rowTop + rowHeight - 6);
  return stripDepthPrism(
      id: id,
      front: front,
      skew: 6 + level * .3,
      rise: 6 + level * .6,
      tier: tier);
}

/// A name only owns the readable front face, never the sloping roof or
/// a neighbour's side. The painter measures against this same rectangle.
Rect stripDepthLabelArea(StripDepthShape shape, double viewX0, double viewX1) {
  final left = math.max(shape.front.left, viewX0) + 4;
  final right = math.min(shape.front.right, viewX1) - 4;
  if (right <= left || shape.front.height <= 4) return Rect.zero;
  return Rect.fromLTRB(
      left, shape.front.top + 2, right, shape.front.bottom - 2);
}

double _segmentDistance(Offset p, Offset a, Offset b) {
  final delta = b - a;
  final length2 = delta.dx * delta.dx + delta.dy * delta.dy;
  if (length2 == 0) return (p - a).distance;
  final ratio =
      (((p.dx - a.dx) * delta.dx + (p.dy - a.dy) * delta.dy) / length2)
          .clamp(0.0, 1.0);
  return (p - (a + delta * ratio)).distance;
}

bool stripDepthFaceContains(List<Offset> polygon, Offset point) {
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final a = polygon[j];
    final b = polygon[i];
    if (_segmentDistance(point, a, b) <= .001) return true;
    if ((a.dy > point.dy) != (b.dy > point.dy) &&
        point.dx < (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx) {
      inside = !inside;
    }
  }
  return inside;
}

/// Actual visible faces win before any padded touch target. Reverse
/// paint order resolves overlapping roofs exactly as the eye sees them.
StripDepthShape? hitStripDepthShapes(
    Iterable<StripDepthShape> shapes, Offset point,
    {double touchRadius = 9}) {
  final reversed = shapes.toList().reversed;
  for (final shape in reversed) {
    if (shape.contains(point)) return shape;
  }
  StripDepthShape? nearest;
  var distance = touchRadius;
  for (final shape in reversed) {
    if (!shape.bounds.inflate(touchRadius).contains(point)) continue;
    for (final face in shape.faces) {
      for (var i = 0; i < face.length; i++) {
        final d = _segmentDistance(point, face[i], face[(i + 1) % face.length]);
        if (d < distance) {
          distance = d;
          nearest = shape;
        }
      }
    }
  }
  return nearest;
}

typedef StripDepthRowExtent = ({String id, double top, double height});
typedef StripDepthScrollAnchor = ({String id, double fraction});

StripDepthScrollAnchor? stripDepthScrollAnchor(
    Iterable<StripDepthRowExtent> rows, double offset) {
  for (final row in rows) {
    if (offset >= row.top && offset < row.top + row.height) {
      return (id: row.id, fraction: (offset - row.top) / row.height);
    }
  }
  return null;
}

double? stripDepthOffsetForAnchor(
    Iterable<StripDepthRowExtent> rows, StripDepthScrollAnchor? anchor) {
  if (anchor == null) return null;
  for (final row in rows) {
    if (row.id == anchor.id) return row.top + row.height * anchor.fraction;
  }
  return null;
}
