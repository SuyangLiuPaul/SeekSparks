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
import 'package:seeksparks/utils/related_verses.dart' show isCjkChar;

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

/// The angle for [year] on an axis running [minYear]..[maxYear] — the
/// general form of [angleForYear], for the full-history mode whose axis
/// starts at 4000 BC rather than at the creation's AM 0.
double angleForSpan(int year, int minYear, int maxYear) {
  final span = maxYear - minYear;
  if (span <= 0) return startRad;
  final t = ((year - minYear) / span).clamp(0.0, 1.0);
  return startRad + t * sweepRad;
}

/// Where one event's radial label starts and ends.
///
/// The engraved chronologies set their event text along the RADIUS,
/// not along the arc, and that one choice is what lets them carry
/// thousands of entries without overprinting. Angular space is scarce
/// — every degree is contested — while radial space is nearly free: a
/// label running outward occupies an angle no wider than its type.
/// Tangential labels on neighbouring years fight for the same arc and
/// can only be resolved by dropping one, which loses information and
/// still looks crowded.
class RadialLabel {
  const RadialLabel({
    required this.angle,
    required this.rStart,
    required this.rEnd,
    required this.flipped,
  });

  final double angle;
  final double rStart;
  final double rEnd;

  /// True on the left half of the wheel, where a label running outward
  /// would read upside down and is drawn inward-to-outward reversed so
  /// it stays right way up.
  final bool flipped;
}

/// Stack radial labels that share an angle, so several events in one
/// year step outward instead of printing on each other.
///
/// [angles] must be sorted. Two labels are "the same spoke" when they
/// are within [minGap] radians; each subsequent one starts where the
/// previous ended plus [gapPx].
List<RadialLabel> stackRadialLabels(
  List<double> angles,
  List<double> lengths,
  double rBase, {
  double minGap = 0.008,
  double gapPx = 6,
}) {
  final out = <RadialLabel>[];
  var lastAngle = double.negativeInfinity;
  var cursor = rBase;
  for (var i = 0; i < angles.length; i++) {
    if ((angles[i] - lastAngle).abs() > minGap) {
      cursor = rBase; // a new spoke — start again at the base radius
    }
    final flipped = math.cos(angles[i]) < 0;
    out.add(RadialLabel(
      angle: angles[i],
      rStart: cursor,
      rEnd: cursor + lengths[i],
      flipped: flipped,
    ));
    cursor += lengths[i] + gapPx;
    lastAngle = angles[i];
  }
  return out;
}

// ── what the rim can actually say ────────────────────────────────────

/// The painted width of [text] at [size], in canvas units.
///
/// Passed in rather than computed here so this file stays free of
/// widgets, and so a test can lay the strings out in the faces the app
/// really ships instead of `flutter test`'s fixed-width stand-in.
typedef LabelMeasure = double Function(String text, double size);

/// The text the wheel can honestly draw for one event, given [room]
/// canvas units of radius.
///
/// WHY THIS IS NOT A TRUNCATION. Until 2026-08-25 the painter cut the
/// title down two characters at a time until it fitted a box of a
/// CONSTANT length — `span * 0.36`, about 40 px, the same box whatever
/// the label said. Measured in the shipped faces over all 491 events on
/// a 700 px canvas at rest: **not one English title was drawn whole**,
/// 462 of 491 Chinese ones were cut, and 77% of the English characters
/// never reached the reader. What did reach them was
/// `Mosc…` for *Moscow Council Restores the Patriarchate* and `奧斯…`
/// for *奧斯曼境內基督徒遭驅逐與殺害* — a rim of stubs that names
/// nothing and reads as a broken chart.
///
/// So a label is now **legible or absent**:
///
///  * Chinese is whole or nothing. Every ideograph is a morpheme, so
///    two of them are not an abbreviation of ten, they are a different
///    word — 莫斯 is not 莫斯科. This is the standing rule (#297) that
///    a CJK label is never ellipsised, and the wheel is the surface
///    that broke it hardest.
///  * Latin may fall back to whole WORDS with an ellipsis, because
///    *Moscow…* still names something and *Mosc…* does not. If not even
///    the first word fits, nothing is drawn.
///
/// Nothing is lost by omitting text: the tick stays, so the event is
/// still visible and still tappable, and the band's own sheet lists
/// every event on that stream. The reader's lever is zoom, which shrinks
/// type against a fixed canvas and so buys real room.
({String title, String ref, double width, bool ellipsised}) fitRadialLabel({
  required String title,
  required String ref,
  required double room,
  required double titleSize,
  required double refSize,
  required LabelMeasure measure,
}) {
  const nothing = (title: '', ref: '', width: 0.0, ellipsised: false);
  if (room <= 0 || title.isEmpty) return nothing;

  final full = measure(title, titleSize);
  if (full <= room) {
    // The verse rides along only when the title did not spend the
    // radius. Measured on the LOCALISED reference, which is what the
    // caller passes: 创世纪 10:6 and Genesis 10:6 are not the same width.
    if (ref.isNotEmpty) {
      final refW = measure('  $ref', refSize);
      if (full + refW <= room) {
        return (title: title, ref: ref, width: full + refW, ellipsised: false);
      }
    }
    return (title: title, ref: '', width: full, ellipsised: false);
  }

  if (title.runes.any(isCjkChar)) return nothing;

  final words = title.split(' ').where((w) => w.isNotEmpty).toList();
  for (var take = words.length - 1; take >= 1; take--) {
    final cut = '${words.take(take).join(' ')}…';
    final w = measure(cut, titleSize);
    if (w <= room) {
      return (title: cut, ref: '', width: w, ellipsised: true);
    }
  }
  return nothing;
}

/// One event asking for a place on the rim, already localised.
class SpokeRequest {
  const SpokeRequest({
    required this.angle,
    required this.scripture,
    required this.title,
    required this.ref,
  });

  final double angle;

  /// True when the year rests on the text rather than on a general
  /// reference — which decides the radius the label starts from, the
  /// scripture baseline the wheel draws as a hairline arc.
  final bool scripture;

  final String title;

  /// Empty when the event cites no verse.
  final String ref;
}

/// A planned label: where it goes and what it says.
class PlannedSpoke {
  const PlannedSpoke({
    required this.index,
    required this.label,
    required this.title,
    required this.ref,
    required this.ellipsised,
  });

  /// Into the request list the caller passed.
  final int index;
  final RadialLabel label;

  /// Empty when only the tick is drawn — see [fitRadialLabel].
  final String title;
  final String ref;
  final bool ellipsised;

  bool get hasText => title.isNotEmpty;
}

/// Where the scripture group's labels begin, as a radius. Five canvas
/// units clear of the bands, so the tick has somewhere to be.
double scriptureLabelBase(double rBands) => rBands + 5;

/// Every label on the rim: its radius, its flip, and the text it can
/// honestly carry.
///
/// [requests] must be in ascending angle and no two closer than
/// [minGap] — which is what the page's declutter guarantees, and what
/// the argument below rests on.
///
/// WHY BOTH GROUPS NOW GET THE WHOLE ANNULUS. Until 2026-08-25 the
/// annulus was cut in two: scripture-dated events were given its inner
/// 36% and conventionally-dated ones a band starting at 46%, so that a
/// reader could tell the two apart by which ring a label sat in. The
/// idea is good and the cost was not affordable — measured over the
/// real corpus at 900 px, the split left **20 of 55 Chinese labels able
/// to say anything at all** where the undivided annulus lets all 55 say
/// it whole, and took English from 31 whole labels to 3. Two thirds of
/// the wheel's words were being spent on a cue **nothing on screen
/// explains**: there is no legend entry for the two rings, and the
/// basis is disclosed properly where it is actually read — in words, on
/// the detail sheet, for every event.
///
/// The distinction is kept, and kept for free, by ANCHORING rather than
/// by zoning: a scripture label is flush against the bands and grows
/// outward, a conventional label is flush against the rim and grows
/// inward. Two straight edges, each already drawn as a ring, and every
/// label may use the full radius.
///
/// They cannot collide. Any two labels are at least [minGap] apart in
/// angle, and [minGap] is one line-height divided by [rBands] — so at
/// any radius `r >= rBands` their arc separation is at least
/// `r * lineHeight / rBands >= lineHeight`. Every label sits outside
/// `rBands`. The one exception is an event forced back in because the
/// reader selected it, which may sit closer than [minGap] to its
/// neighbour: hiding the thing just tapped would be worse.
List<PlannedSpoke> planRadialSpokes({
  required List<SpokeRequest> requests,
  required double rBands,
  required double rRim,
  required double titleSize,
  required double refSize,
  required LabelMeasure measure,
  required double minGap,
  required double lineHeight,
}) {
  if (requests.isEmpty) return const [];
  final base = scriptureLabelBase(rBands);
  final room = rRim - base;

  final scripture = <int>[];
  final conventional = <int>[];
  for (var i = 0; i < requests.length; i++) {
    (requests[i].scripture ? scripture : conventional).add(i);
  }

  final out = <PlannedSpoke>[];
  for (final group in [scripture, conventional]) {
    if (group.isEmpty) continue;
    final inward = !requests[group.first].scripture;
    final fits = [
      for (final i in group)
        fitRadialLabel(
          title: requests[i].title,
          ref: requests[i].ref,
          room: room,
          titleSize: titleSize,
          refSize: refSize,
          measure: measure,
        )
    ];
    // Stack from zero, then mirror the outward group about the rim.
    // Stacking is what lets several events in one year step clear of
    // each other; going inward from the rim is the same arithmetic
    // read the other way, so there is one implementation of it.
    final stacked = stackRadialLabels(
        [for (final i in group) requests[i].angle],
        [for (final f in fits) f.width],
        0,
        minGap: minGap * 0.5,
        gapPx: 3);
    for (var k = 0; k < group.length; k++) {
      final s = stacked[k];
      final label = inward
          ? RadialLabel(
              angle: s.angle,
              rStart: rRim - s.rEnd,
              rEnd: rRim - s.rStart,
              flipped: s.flipped)
          : RadialLabel(
              angle: s.angle,
              rStart: base + s.rStart,
              rEnd: base + s.rEnd,
              flipped: s.flipped);
      // Stacking can push a label past the annulus its text was
      // measured against. Rather than let it print into the bands or
      // through the rim, it keeps its tick and loses its words.
      final fit = fits[k];
      final overflows = fit.width > 0 &&
          (label.rStart < base - 0.001 || label.rEnd > rRim + 0.001);
      out.add(PlannedSpoke(
        index: group[k],
        label: label,
        title: overflows ? '' : fit.title,
        ref: overflows ? '' : fit.ref,
        ellipsised: !overflows && fit.ellipsised,
      ));
    }
  }
  return out;
}

/// Greedy first-fit packing of angular items into a small number of
/// rings, so a dense century of events spreads across neighbouring
/// rings instead of printing on top of itself.
///
/// [starts] and [ends] are angles in radians, already sorted by start.
/// Returns a ring index per item, always < [ringCount]: when every
/// ring is occupied within [minGap] of an item, it goes to the ring
/// whose last occupant ends earliest — overprinting the least-recently
/// used ring is the least-bad option, and the tap target still works
/// because hit-testing is by ring and angle.
List<int> packIntoRings(
  List<double> starts,
  List<double> ends,
  int ringCount, {
  double minGap = 0.02,
}) {
  final lastEnd = List<double>.filled(ringCount, double.negativeInfinity);
  final out = <int>[];
  for (var i = 0; i < starts.length; i++) {
    var ring = -1;
    for (var r = 0; r < ringCount; r++) {
      if (starts[i] - lastEnd[r] >= minGap) {
        ring = r;
        break;
      }
    }
    if (ring < 0) {
      ring = 0;
      for (var r = 1; r < ringCount; r++) {
        if (lastEnd[r] < lastEnd[ring]) ring = r;
      }
    }
    lastEnd[ring] = ends[i] > starts[i] ? ends[i] : starts[i];
    out.add(ring);
  }
  return out;
}
