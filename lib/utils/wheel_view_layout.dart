import 'dart:math' as math;
import 'dart:ui';

import 'package:seeksparks/utils/radial_chronology_layout.dart';

/// The wheel controls occupy their own row above the year digest. The
/// initial stream budget reserves the same height as the rendered footer
/// so large touch targets cannot cover the axis or trigger a second fit.
const double wheelControlsFooterHeight = 48;

/// The divisor applied to canvas type before the viewer magnifies it.
///
/// Text grows through the first 4x of zoom, then holds at twice its
/// resting size. The previous square-root curve made 10.5 px labels
/// 115 px tall at 120x; that spent the space gained by zooming on type.
/// More magnification now reveals more records at a readable size.
double wheelLabelScale(double zoom) {
  final safeZoom = zoom.clamp(0.01, double.infinity);
  return safeZoom / math.min(math.sqrt(safeZoom), 2.0);
}

/// Radial names have enough room to accompany their marks once the wheel
/// is magnified. At fit size, the explorer and year digest supply readable
/// names and evidence; selected records keep their canvas label too.
bool wheelShowsEventText({required double zoom, required bool selected}) =>
    selected || zoom >= 1.6;

class WheelAxisLabelPlacement {
  const WheelAxisLabelPlacement(this.centre, this.rotation, this.bounds);

  final Offset centre;
  final double rotation;
  final Rect bounds;
}

/// Axis text placement and its visible box, relative to the wheel centre.
/// The painter and fit tests use this same geometry; measuring only the
/// rim radius missed the text that continued beyond it on small screens.
WheelAxisLabelPlacement placeWheelAxisLabel({
  required double angle,
  required double width,
  required double height,
  required double rimRadius,
  required double clearance,
  required bool onRing,
  double endpointGap = 4,
}) {
  final radius = onRing
      ? ringLabelRadius(rRim: rimRadius, clearance: clearance, height: height)
      : axialLabelRadius(
          angle: angle,
          rRim: rimRadius,
          width: width,
          height: height,
          clearance: clearance);
  final rotation =
      onRing ? angle + (math.sin(angle) > 0 ? -math.pi / 2 : math.pi / 2) : 0.0;
  var centre = Offset(math.cos(angle), math.sin(angle)) * radius;
  if (!onRing) {
    // At the measured 179 px landscape wheel, the two real-font end
    // labels meet inside the gap wedge. Give each horizontal box its
    // own side of that wedge's centre line, moving only text and only
    // as far as its measured width needs. Their year rays stay fixed.
    final gapAngle = startRad + (sweepRad + 2 * math.pi) / 2;
    final gapX = math.cos(gapAngle) * rimRadius;
    final opening = math.sin(angle - gapAngle) > 0;
    centre = Offset(
        opening
            ? math.max(centre.dx, gapX + width / 2 + endpointGap / 2)
            : math.min(centre.dx, gapX - width / 2 - endpointGap / 2),
        centre.dy);
  }
  final halfWidth =
      (width * math.cos(rotation).abs() + height * math.sin(rotation).abs()) /
          2;
  final halfHeight =
      (width * math.sin(rotation).abs() + height * math.cos(rotation).abs()) /
          2;
  return WheelAxisLabelPlacement(
      centre,
      rotation,
      Rect.fromLTRB(centre.dx - halfWidth, centre.dy - halfHeight,
          centre.dx + halfWidth, centre.dy + halfHeight));
}

/// Keep both range ends before admitting secondary tick labels. Small
/// wheels can fit every word inside their bounds yet still put the first
/// 500-year label against the opening year. Only the colliding words are
/// omitted: their tick lines remain, and the cursor still reads any year.
/// [gap] is in canvas units; callers divide the screen gap by their zoom.
List<AxisLabel> retainSeparatedWheelAxisLabels({
  required List<AxisLabel> labels,
  required Rect Function(AxisLabel label) boundsOf,
  double gap = 4,
}) {
  final retained = labels.where((label) => !label.onRing).toSet();
  final occupied = [
    for (final label in retained) boundsOf(label).inflate(gap / 2),
  ];
  for (final label in labels.where((label) => label.onRing)) {
    final bounds = boundsOf(label).inflate(gap / 2);
    if (occupied.any(bounds.overlaps)) continue;
    retained.add(label);
    occupied.add(bounds);
  }
  return [
    for (final label in labels)
      if (retained.contains(label)) label
  ];
}

/// Deterministic work counters for the real page, independent of device
/// speed. They measure scene planning and painter invocations separately.
class WheelRenderStats {
  WheelRenderStats._();

  static int sceneBuilds = 0;
  static int paints = 0;

  static void reset() {
    sceneBuilds = 0;
    paints = 0;
  }
}
