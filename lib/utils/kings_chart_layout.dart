import 'dart:math' as math;

/// Pure geometry for the kings chart.
///
/// The chart's hard problem is not drawing bands, it is labelling them.
/// Reign lengths in this data span four orders of magnitude — Manasseh
/// ruled 55 years, Zimri seven days — so a scale that makes Manasseh a
/// sensible height makes Zimri, Shallum, Jehoahaz and Jehoiachin
/// sub-pixel. Putting each name inside its own band therefore cannot
/// work, and letting the short ones fall off the chart would quietly
/// drop five kings.
///
/// So bands are drawn true to scale and the NAMES live in a separate
/// lane, pushed apart just enough to be readable and joined back to
/// their band by a leader line. That is what [placeLabels] does, and it
/// is kept here, free of widgets, because it is the part worth testing.

/// Vertical offset for [year] on an axis running from [firstYear] (top)
/// to [lastYear] (bottom) over [height] pixels.
double yForYear(int year, int firstYear, int lastYear, double height) {
  final span = lastYear - firstYear;
  if (span <= 0 || height <= 0) return 0;
  final t = (year - firstYear) / span;
  return (t * height).clamp(0.0, height);
}

/// Spread label positions so no two are closer than [slotHeight],
/// keeping them as near their [desired] anchors as possible and inside
/// `[0, height]`.
///
/// [desired] must be non-decreasing — kings arrive in chronological
/// order, so it always is.
///
/// Two passes. The first walks down, pushing each label below the one
/// before it; that alone can shove the tail off the bottom of the
/// chart, so the second walks back up, pulling labels in until the last
/// one fits. When the labels genuinely cannot fit — more of them than
/// the height allows — they are distributed evenly rather than piled at
/// one end, because an even overlap is legible and a pile is not.
List<double> placeLabels(
  List<double> desired,
  double slotHeight,
  double height,
) {
  final n = desired.length;
  if (n == 0) return const [];
  if (slotHeight <= 0) return List<double>.from(desired);

  if (n * slotHeight > height) {
    final step = height / n;
    return List<double>.generate(n, (i) => i * step);
  }

  final y = List<double>.from(desired);

  y[0] = math.max(0, y[0]);
  for (var i = 1; i < n; i++) {
    y[i] = math.max(y[i], y[i - 1] + slotHeight);
  }

  final overflow = y[n - 1] + slotHeight - height;
  if (overflow > 0) {
    y[n - 1] = height - slotHeight;
    for (var i = n - 2; i >= 0; i--) {
      y[i] = math.min(y[i], y[i + 1] - slotHeight);
    }
    // The downward pass can only have been undone into negative space
    // if the labels do fit, which the guard above already established.
    y[0] = math.max(0, y[0]);
  }

  return y;
}
