/// Pure geometry for the chronology wheel — the radial rendering of the
/// same Genesis lifespans `chronology_layout.dart` lays out as bars.
///
/// The wheel was asked for by the owner after seeing a printed radial
/// chart: time sweeping clockwise round a rim, one concentric ring per
/// generation, each life an arc. That *form* is centuries old — radial
/// chronologies were being engraved long before any living publisher —
/// and it is all this file takes. The data underneath is ours
/// (`assets/chronology.json`, every figure carrying its verse), the
/// palette is the app's own line-of-descent hues, and no wording,
/// artwork or compiled table from any printed chart is reproduced.
///
/// Angle convention is the canvas's: 0 rad points right (+x), positive
/// is clockwise because y grows downward. The creation (AM 0) sits at
/// twelve o'clock and time runs clockwise through [sweepRad], leaving a
/// gap wedge before twelve o'clock again so the first and last rim
/// labels cannot collide.
///
/// Kept free of widgets because it is the part worth testing.
library;

import 'dart:math' as math;

import 'package:seeksparks/models/chronology.dart';

/// How far round the wheel the axis runs. The remaining 40° is the gap.
const double sweepRad = 320 * math.pi / 180;

/// Twelve o'clock in canvas angles.
const double startRad = -math.pi / 2;

/// The angle at which [year] falls on an axis running from AM 0 to
/// [endAm].
double angleForYear(int year, int endAm) {
  if (endAm <= 0) return startRad;
  final t = (year / endAm).clamp(0.0, 1.0);
  return startRad + t * sweepRad;
}

/// The inverse: which AM year an angle points at, or null when the
/// angle is inside the gap wedge.
int? yearForAngle(double angle, int endAm) {
  // Normalise into [startRad, startRad + 2π).
  var a = angle;
  while (a < startRad) {
    a += 2 * math.pi;
  }
  while (a >= startRad + 2 * math.pi) {
    a -= 2 * math.pi;
  }
  final t = (a - startRad) / sweepRad;
  if (t > 1.0) return null; // the gap
  return (t * endAm).round();
}

/// One life, ready to draw: ring number and the three angles that carve
/// the arc into its two tones (birth→fathering dark, fathering→death
/// light — the same split the bar chart draws).
class WheelArc {
  const WheelArc({
    required this.personId,
    required this.line,
    required this.ring,
    required this.birthAngle,
    required this.begatAngle,
    required this.deathAngle,
  });

  final String personId;

  /// `seth` / `shem` / `abraham` / `levi` — the four ways an age reaches
  /// this chart. Colour is decided from this by the painter.
  final String line;

  /// 0 is the outermost ring. Adam is 0: the earliest generation rides
  /// the rim, and each generation steps one ring inward, which is also
  /// the order the eye meets them sweeping clockwise.
  final int ring;

  final double birthAngle;

  /// Null when the man ends the chain and no fathering age exists.
  final double? begatAngle;
  final double deathAngle;
}

/// Every life in [people] under [traditionId], as arcs. Ring order is
/// the list's order, which `ChronologyData.inTradition` already gives
/// generationally.
List<WheelArc> buildWheelArcs(
  List<Patriarch> people,
  String traditionId,
  int endAm,
) {
  final out = <WheelArc>[];
  for (var i = 0; i < people.length; i++) {
    final f = people[i].figures[traditionId];
    if (f == null) continue;
    final begat = f.begatAt;
    out.add(WheelArc(
      personId: people[i].id,
      line: people[i].line,
      ring: i,
      birthAngle: angleForYear(f.birthAm, endAm),
      begatAngle:
          begat == null ? null : angleForYear(f.birthAm + begat, endAm),
      deathAngle: angleForYear(f.deathAm, endAm),
    ));
  }
  return out;
}

/// The band of radii ring [ring] occupies, given [ringCount] rings
/// between the hub at [rHub] and the rim at [rMax]. A fifth of each
/// ring's width is left as the gap between neighbours, so the bands
/// read as separate arcs rather than a solid disc.
({double inner, double outer, double centre, double width}) ringRadii(
  int ring,
  int ringCount,
  double rHub,
  double rMax,
) {
  final ringW = ringCount <= 0 ? 0.0 : (rMax - rHub) / ringCount;
  final outer = rMax - ring * ringW;
  final band = ringW * 0.8;
  return (
    inner: outer - band,
    outer: outer,
    centre: outer - band / 2,
    width: band,
  );
}

/// Which arc a point at polar ([r], [angle]) lands on, or null.
///
/// This is the whole of tap handling: the page converts the tap to
/// polar about the wheel's centre and asks. Endpoint years count as
/// inside, matching the closed intervals `sharedYears` measures.
WheelArc? hitTest(
  double r,
  double angle,
  List<WheelArc> arcs,
  int ringCount,
  double rHub,
  double rMax,
) {
  if (r < rHub || r > rMax || ringCount <= 0) return null;
  // Normalise like yearForAngle, then reject the gap.
  var a = angle;
  while (a < startRad) {
    a += 2 * math.pi;
  }
  while (a >= startRad + 2 * math.pi) {
    a -= 2 * math.pi;
  }
  if (a - startRad > sweepRad) return null;
  for (final arc in arcs) {
    final band = ringRadii(arc.ring, ringCount, rHub, rMax);
    if (r < band.inner || r > band.outer) continue;
    if (a >= arc.birthAngle && a <= arc.deathAngle) return arc;
  }
  return null;
}

/// The century spokes: every 100 years minor, every 500 major (major
/// ticks carry a year label at the rim). AM 0 is skipped — the axis
/// start already marks it — and the final century is kept even when it
/// falls within 50 years of the end, because the wheel's rim has room
/// where a linear axis would not.
List<({int year, bool major})> wheelTicks(int endAm) {
  final out = <({int year, bool major})>[];
  for (var y = 100; y <= endAm; y += 100) {
    out.add((year: y, major: y % 500 == 0));
  }
  return out;
}
