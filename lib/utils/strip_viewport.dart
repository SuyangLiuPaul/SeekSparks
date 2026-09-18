/// Navigation in screen space. Fit is a ratio, not a ladder step:
/// 0.15 px/year needs 933.9 px for this axis, while a 360 px phone's
/// time viewport is only part of that width. Rounding fit up loses the
/// right end; the exact ratio is a first-class zoom alongside the ladder.
library;

import 'dart:math' as math;
import 'package:yahwehs_sword/utils/strip_chronology_layout.dart';

double stripFitScale(double viewportWidth) =>
    pxPerYearToFit(kStripMinYear, kStripMaxYear, math.max(1, viewportWidth));

double stripNextScale(double current, int direction, double viewportWidth) {
  final fit = stripFitScale(viewportWidth);
  final steps = <double>{fit, ...kStripZoomSteps.where((s) => s > fit)}.toList()
    ..sort();
  if (direction > 0) {
    return steps.firstWhere((s) => s > current + 0.000001,
        orElse: () => steps.last);
  }
  return steps.reversed
      .firstWhere((s) => s < current - 0.000001, orElse: () => steps.first);
}

/// Preserve the fractional year under the centre, not its rounded date.
/// Rounding at 96 px/year can move the point under the reader by 48 px.
double stripZoomOffset({
  required double offset,
  required double viewportWidth,
  required double oldScale,
  required double newScale,
}) {
  final centre = yearForX(offset + viewportWidth / 2, oldScale);
  return stripOffsetForYear(centre, viewportWidth, newScale);
}

double stripOffsetForYear(double year, double viewportWidth, double scale) =>
    ((year - kStripMinYear) * scale - viewportWidth / 2)
        .clamp(0.0, math.max(0.0, stripContentWidth(scale) - viewportWidth));

/// A CONTINUOUS zoom, for a pinch and for a scroll wheel.
///
/// The ladder in [stripNextScale] belongs to the two buttons, where a
/// press should land somewhere predictable. A pinch is not a press: the
/// reader is describing a magnification with their fingers, and
/// snapping it to the nearest rung throws that away.
double stripScaleBy(double current, double factor, double viewportWidth) {
  if (!factor.isFinite || factor <= 0) return current;
  return (current * factor)
      .clamp(stripFitScale(viewportWidth), kStripZoomSteps.last);
}

/// Keep the year under [focusX] where it is, [focusX] being measured
/// from the left edge of the time viewport.
///
/// Zooming about the centre is right for a button and wrong for a
/// pinch or a wheel: there the reader is pointing at the thing they
/// want to keep, and moving it out from under them is the whole
/// complaint about charts that zoom.
double stripZoomOffsetAt({
  required double offset,
  required double focusX,
  required double viewportWidth,
  required double oldScale,
  required double newScale,
}) {
  final year = yearForX(offset + focusX, oldScale);
  return ((year - kStripMinYear) * newScale - focusX)
      .clamp(0.0, math.max(0.0, stripContentWidth(newScale) - viewportWidth));
}
