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

/// Which records put their name on the canvas: the selected one, and
/// nothing else.
///
/// 2026-09-15. This used to read `selected || zoom >= 1.6`, and the
/// owner photographed what that produced — at 381% a fan of `+9 +1 +3
/// +4 +8 +8` rotated badges with a truncated `The…` among them, and at
/// 2474% six event titles running in four different directions across
/// each other.
///
/// The names were never the problem; their ORIENTATION was. Each one
/// was laid along its own bearing, so a chart that is a circle ends up
/// with text at every angle on it, and the reader has to turn their
/// head or their phone to read half of it. The dataviz literature is
/// unusually blunt about this — Sheffield's guide says rotated or
/// overlapping text "is never justified under any circumstances", and
/// the standing advice when labels will not fit horizontally is to
/// change the chart rather than to tilt the words.
///
/// So this chart changes. Every record keeps a MARK on its own ring at
/// its own year, which is the claim the wheel actually makes; the names
/// are read from the list beside it, which is already sorted by year
/// and already scrolls with the cursor. One name is drawn on the
/// canvas — the selected one — because "which mark did I just tap" is
/// the one question the list cannot answer.
///
/// This is the overview-plus-detail split the research recommends for
/// dense radial charts, and it is also the largest paint saving
/// available here: the per-character arc layout in `_charsOnArc` ran
/// about 8,000 times a frame.
bool wheelShowsEventText({required double zoom, required bool selected}) =>
    selected;

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
  // UPRIGHT, both kinds. 2026-09-15.
  //
  // The century labels used to run ALONG the ring, and
  // `ringLabelRadius`'s own doc explains why: horizontal did not fit.
  // `rRim` was 0.445 of the canvas side against a 0.5 clip, so there
  // were only `side x 0.055` units outside the rim — 49.5 at a 900 px
  // pane — while a horizontal 主后1000 needs about 54.
  //
  // That arithmetic was right, and the conclusion drawn from it was
  // wrong. It says the DISC IS TOO BIG FOR ITS FRAME, not that the
  // words should be bent around it; the fix is the margin, not the
  // type. `bandsFractionFor` and `rimFractionFor` now leave that
  // margin, so the labels stand up.
  //
  // Rotation is gone rather than parameterised, so the bounds this
  // returns are axis-aligned and `retainSeparatedWheelAxisLabels`
  // measures the box that is actually painted. A label that still
  // cannot clear its neighbours is dropped and its tick stays — the
  // reader loses a number they can read off the cursor, not a mark.
  final radius = axialLabelRadius(
      angle: angle,
      rRim: rimRadius,
      width: width,
      height: height,
      clearance: clearance);
  const rotation = 0.0;
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
  Rect? canvasBounds,
}) {
  final retained = labels.where((label) => !label.onRing).toSet();
  final occupied = [
    for (final label in retained) boundsOf(label).inflate(gap / 2),
  ];
  for (final label in labels.where((label) => label.onRing)) {
    final ink = boundsOf(label);
    // The shared mode row leaves a 131 px wheel in the short landscape
    // case. Even separated Chinese tick labels can cross that boundary;
    // their ticks and the year cursor remain when the words cannot fit.
    if (canvasBounds != null &&
        (ink.left < canvasBounds.left ||
            ink.right > canvasBounds.right ||
            ink.top < canvasBounds.top ||
            ink.bottom > canvasBounds.bottom)) {
      continue;
    }
    final bounds = ink.inflate(gap / 2);
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
