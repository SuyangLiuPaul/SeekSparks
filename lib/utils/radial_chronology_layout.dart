/// Pure geometry for the world-history wheel.
///
/// A radial chronology was asked for by the owner after seeing a
/// printed one: time sweeping clockwise round a rim, concentric rings,
/// text set along the radius. That *form* is centuries old — radial
/// chronologies were being engraved long before any living publisher —
/// and it is all this file takes. The data underneath is ours
/// (`assets/wheel_history.json`, every nation carrying its verse), the
/// palette is the app's own line-of-descent hues, and no wording,
/// artwork or compiled table from any printed chart is reproduced.
///
/// THE GENESIS LIFESPANS ARE DRAWN HERE AGAIN, AND ON THE BC AXIS —
/// NOT ON A SECOND ONE. This file once carried an Anno Mundi half: one
/// ring per generation, each life an arc, the creation at twelve
/// o'clock. It went in `b75ffc6`/`2d1a66d`, and the reason it went is
/// still true and still binding — two axes on one circle point one
/// angle at two different years. What changed is the DATA, not the
/// drawing. Since the creation anchor was derived
/// (`bible_timeline.json` `_meta.creation`, 4114 BC: Thiele's Solomon
/// counted back along twenty-five stated intervals) every Anno Mundi
/// figure has one honest BC year, `creation + am`, and [buildLifeArcs]
/// draws the lives at those years through the SAME [angleForSpan]
/// every event uses. There is no AM geometry in this file and there
/// must never be: the conversion happens once, in the caller, out of
/// the one field that holds the anchor.
///
/// A SPOKE SAYS WHEN; AN ARC SAYS HOW LONG, AND ALONGSIDE WHOM. The
/// births of Genesis 5 and 11 are events with their own spokes. The
/// lives are arcs in the label annulus, and they carry the one thing
/// no event may state: that Methuselah's years run out in the year of
/// the flood — which the text nowhere says and the arithmetic does.
///
/// Angle convention is the canvas's: 0 rad points right (+x), positive
/// is clockwise because y grows downward. The axis starts at twelve
/// o'clock and runs clockwise through [sweepRad], leaving a gap wedge
/// before twelve o'clock again so the first and last rim labels cannot
/// collide.
///
/// Kept free of widgets because it is the part worth testing.
library;

import 'dart:math' as math;

import 'package:seeksparks/models/chronology.dart' show Patriarch;
import 'package:seeksparks/utils/related_verses.dart' show isCjkChar;

/// How far round the wheel the axis runs. The remaining 40° is the gap.
const double sweepRad = 320 * math.pi / 180;

/// Twelve o'clock in canvas angles.
const double startRad = -math.pi / 2;

/// Centre-to-centre spacing of the rings, which is what a label has to
/// stay inside to keep clear of the neighbouring stream — the band
/// returned by [ringRadii] is only four fifths of it.
double ringPitch(int ringCount, double rHub, double rMax) =>
    ringCount <= 0 ? 0 : (rMax - rHub) / ringCount;

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

/// The angle for [year] on an axis running [minYear]..[maxYear].
///
/// THE ONLY YEAR→ANGLE FUNCTION ON THIS WHEEL, and that is the whole
/// point of it. An Anno Mundi form used to live beside it, back when
/// the lifespans were drawn on their own axis; it went with them
/// (`b75ffc6`) and has not come back. The lifespans return through
/// [buildLifeArcs], which converts each figure to a BC year against the
/// derived creation anchor and then calls THIS — so a life and an event
/// in the same year are at the same angle, which is the claim the chart
/// is making.
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
///
/// [badge] — the `+65` of a spoke standing for a cluster — is reserved
/// BEFORE the title, and is the last thing given up. A title is one
/// event's name and can be recovered by zooming or by tapping; the
/// badge is the only mark on the whole wheel saying that sixty-five
/// other events are behind this one, and a chart that drops it is back
/// to narrowing in silence. So the order of sacrifice is verse, then
/// title, then badge.
///
/// It is set at [refSize] — the size the verse already rides this same
/// label at — for hierarchy, NOT for room. It buys no room worth having:
/// measured in the shipped faces, Chinese titles are quantised in whole
/// ideographs, so shrinking the badge from [titleSize] to [refSize]
/// recovers the same 22 of 48 at 700 px and the same 53 of 55 at 900 px.
/// (A one-space gap at 0.85 does recover 7 more at 700 px, and that is
/// exactly the kind of knife-edge not to build on — one space either
/// way, on one corpus, at one canvas size.) The reason is that `+65`
/// set in the title's own face reads as another word in the name; at
/// the verse's size it reads as an annotation on it, which is what it
/// is.
///
/// WHAT THE BADGE COSTS, measured in the shipped faces over the real
/// corpus at rest. English keeps every label — 48 of 48 at 700 px and
/// 55 of 55 at 900 px, badge or no badge — and an earlier version of
/// this comment read "English pays nothing at all" on the strength of
/// that. That is the count of labels DRAWN, not of names drawn WHOLE,
/// and English does pay: titles that fit with no ellipsis fall from 31
/// to 22 at 900 px and from 6 to 3 at 700 px. English pays in words
/// where Chinese pays in whole names, because Latin may cut at a word
/// and Han may not (#297): 55 Chinese titles become 53 at 900 px, and
/// 38 become 22 at 700 px. At 1400 px the badge is free in both — 79 of
/// 79, whole and uncut, either way — so the entire cost sits on the two
/// smallest canvases the wheel is reachable on.
///
/// Against that, the number of spokes saying NOTHING AT ALL falls from
/// 10 to 2 at 700 px, and 43 spokes that stood mute for their 400-odd
/// hidden events now say how many they stand for. A name the reader can
/// recover by zooming or by tapping is the cheaper thing to spend.
({String title, String ref, String badge, double width, bool ellipsised})
    fitRadialLabel({
  required String title,
  required String ref,
  required double room,
  required double titleSize,
  required double refSize,
  required LabelMeasure measure,
  String badge = '',
}) {
  const nothing =
      (title: '', ref: '', badge: '', width: 0.0, ellipsised: false);
  if (room <= 0) return nothing;

  final badgeW = badge.isEmpty ? 0.0 : measure('  $badge', refSize);
  if (badgeW > room) return nothing;
  final forText = room - badgeW;
  final badgeOnly =
      (title: '', ref: '', badge: badge, width: badgeW, ellipsised: false);
  if (title.isEmpty) return badge.isEmpty ? nothing : badgeOnly;

  final full = measure(title, titleSize);
  if (full <= forText) {
    // The verse rides along only when the title did not spend the
    // radius. Measured on the LOCALISED reference, which is what the
    // caller passes: 创世纪 10:6 and Genesis 10:6 are not the same width.
    if (ref.isNotEmpty) {
      final refW = measure('  $ref', refSize);
      if (full + refW <= forText) {
        return (
          title: title,
          ref: ref,
          badge: badge,
          width: full + refW + badgeW,
          ellipsised: false
        );
      }
    }
    return (
      title: title,
      ref: '',
      badge: badge,
      width: full + badgeW,
      ellipsised: false
    );
  }

  if (title.runes.any(isCjkChar)) return badge.isEmpty ? nothing : badgeOnly;

  final words = title.split(' ').where((w) => w.isNotEmpty).toList();
  for (var take = words.length - 1; take >= 1; take--) {
    final cut = '${words.take(take).join(' ')}…';
    final w = measure(cut, titleSize);
    if (w <= forText) {
      return (
        title: cut,
        ref: '',
        badge: badge,
        width: w + badgeW,
        ellipsised: true
      );
    }
  }
  return badge.isEmpty ? nothing : badgeOnly;
}

/// The events that one spoke stands for.
///
/// WHY THIS EXISTS. Angle on this wheel is a linear function of the
/// year, so two events in the same year are at the same angle and no
/// magnification separates them — 55 years of the corpus carry more
/// than one event and 125 events are involved. The page's answer used
/// to be a first-past-the-post declutter: sort by year, keep an event
/// only when it clears the last KEPT one by [minGap], drop the rest
/// with no mark of any kind. Measured over the shipped 491 events on a
/// 900 px canvas that keeps **55 at rest and 136 at the viewer's
/// maximum 14x** — one drawn spoke stood for the 66 events of
/// 1900-1957 and said only *Boxer Uprising Martyrdoms* — while the hub
/// prints the figure 491 two inches away.
///
/// Dropping is not the problem; a rim cannot carry 588 labels at once
/// and something must give. Dropping in SILENCE is the problem, and it
/// is the same defect this project has now fixed three times over
/// (#280, #308, #319): a view narrowed its own contents and said
/// nothing. BibleWorks' own Timeline (`bwh39`) carries "thousands of
/// chronological events" and never does this — it scrolls the axis
/// both ways, stacks events into era rows, and puts an explicit
/// indicator on the toolbar "when there are more timeline items
/// visible by scrolling up or down". Our axis cannot scroll: it IS the
/// whole of history, by design. So the equivalent honesty is to make
/// the survivor say how many it stands for and to let a tap list them.
///
/// Grouping is greedy on the same rule the declutter used, so the
/// representatives are the identical set of events at the identical
/// angles — the wheel does not move, it only stops lying about what is
/// on it.
class SpokeCluster {
  const SpokeCluster({required this.members, required this.representative});

  /// Indices into the caller's list, ascending. Never empty.
  final List<int> members;

  /// The member whose title is drawn, and whose year the tick marks.
  final int representative;

  /// How many members are not the one drawn.
  int get hidden => members.length - 1;
}

/// Group [angles] — ascending — into one cluster per spoke.
///
/// A new cluster starts when an angle clears the FIRST member of the
/// open cluster by [minGap], which is exactly the comparison the old
/// declutter made against the last event it kept. [minGap] must be
/// positive; at zero every entry becomes its own cluster and coincident
/// labels would print on each other.
///
/// [pinned] is an index that must represent its own cluster rather than
/// merely belong to it — the reader's selection, which may not be
/// hidden behind a neighbour's title. That moves one tick by up to
/// [minGap] and is the single exception to the collision argument in
/// [planRadialSpokes]. It is a smaller exception than the one it
/// replaces: the old code added the selected event as an EXTRA label
/// beside the one already there.
List<SpokeCluster> clusterByAngle(
  List<double> angles,
  double minGap, {
  int pinned = -1,
}) {
  final out = <SpokeCluster>[];
  var members = <int>[];
  var anchor = double.negativeInfinity;

  void close() {
    if (members.isEmpty) return;
    out.add(SpokeCluster(
      members: members,
      representative: members.contains(pinned) ? pinned : members.first,
    ));
  }

  for (var i = 0; i < angles.length; i++) {
    if (members.isEmpty || angles[i] - anchor >= minGap) {
      close();
      members = [i];
      anchor = angles[i];
    } else {
      members.add(i);
    }
  }
  close();
  return out;
}

/// One event asking for a place on the rim, already localised.
class SpokeRequest {
  const SpokeRequest({
    required this.angle,
    required this.scripture,
    required this.title,
    required this.ref,
    this.badge = '',
  });

  final double angle;

  /// True when the year rests on the text rather than on a general
  /// reference — which decides the radius the label starts from, the
  /// scripture baseline the wheel draws as a hairline arc.
  final bool scripture;

  final String title;

  /// Empty when the event cites no verse.
  final String ref;

  /// What this spoke stands for beyond the one event named — `+65` —
  /// or empty when it stands for itself alone.
  final String badge;
}

/// A planned label: where it goes and what it says.
class PlannedSpoke {
  const PlannedSpoke({
    required this.index,
    required this.label,
    required this.title,
    required this.ref,
    required this.badge,
    required this.ellipsised,
  });

  /// Into the request list the caller passed.
  final int index;
  final RadialLabel label;

  /// Empty when only the tick is drawn — see [fitRadialLabel].
  final String title;
  final String ref;

  /// The `+65` this spoke carries, or empty. It can survive alone: a
  /// spoke whose title would not fit still says how many events it
  /// stands for.
  final String badge;
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
/// `rBands`. The one exception is [clusterByAngle]'s `pinned`: the
/// reader's selection represents its own cluster rather than hiding
/// behind a neighbour's title, which can move one tick by up to
/// [minGap] and so bring one pair closer than that. Hiding the thing
/// just tapped would be worse — and this is the smaller of the two
/// exceptions available, since the alternative is an extra label beside
/// one already drawn.
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
          badge: requests[i].badge,
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
        badge: overflows ? '' : fit.badge,
        ellipsised: !overflows && fit.ellipsised,
      ));
    }
  }
  return out;
}

// ── the axis's own labels, outside the rim ───────────────────────────
//
// The century ticks and the two axis ends are not data; they are the
// SCALE, and until 2026-08-26 both families were placed by a bare
// constant — `rRim + 11`, alternating with `rRim + 22`, and `rRim + 17`
// — that knew nothing about the string it was positioning.
//
// A constant cannot be right here, and the reason is worth stating
// because it is not obvious: a scale label is drawn HORIZONTALLY, so it
// is not rotated with the ray it sits on, so how far it reaches back
// towards the wheel's centre depends on WHICH WAY THE RAY POINTS. At
// twelve o'clock only the label's height points inward; at nine o'clock
// its whole width does. Measured in the shipped faces over the real
// corpus, 主前2500 at ten past ten reached **12.3 canvas units inside
// the rim** and printed straight through the event titles ending there
// — 8 of the 12 century labels intruded at 900 px in Chinese, 192 of
// 432 across a 3-locale × 3-size × 4-zoom sweep, producing 113 pairs of
// overlapping ink. The photographed instance was 主前3500 mashed into
// 最早的轮式车辆, which is a *wheel-native* event at exactly -3500: a
// year that is a multiple of 500 puts an event's label at precisely the
// century label's own angle.
//
// [axialLabelRadius] is the honest form of that constant. It is the
// support function of an axis-aligned box in the ray's direction, so it
// is exact rather than a margin somebody guessed.

/// Where the CENTRE of a horizontal label must sit on the ray [angle]
/// for the whole of its [width] × [height] box to stay at least
/// [clearance] outside [rRim].
///
/// The box is axis-aligned — a year on a scale reads horizontally — so
/// its reach back towards the centre is `w/2·|cos| + h/2·|sin|`, which
/// swings between h/2 at the top of the wheel and w/2 at its side. That
/// is the whole content of this function, and it is why one constant
/// could never serve both.
double axialLabelRadius({
  required double angle,
  required double rRim,
  required double width,
  required double height,
  required double clearance,
}) =>
    rRim +
    clearance +
    (width / 2) * math.cos(angle).abs() +
    (height / 2) * math.sin(angle).abs();

/// Where the centre of a label lying ALONG the ring must sit, so its
/// run clears [rRim] by [clearance].
///
/// WHY THE CENTURY LABELS RUN ALONG THE RING AND THE AXIS ENDS DO NOT.
/// Horizontal placement was tried first and does not fit. [rRim] is
/// 0.445 of the canvas side and the painting is clipped at 0.5 of it, so
/// there are only `side × 0.055` units outside the rim — 38.5 at a 700 px
/// pane, 49.5 at 900 px — while the label's size is fixed in pixels and
/// does not shrink with the canvas. A horizontal 主后1000 sits at 175.5°,
/// very nearly due left, where it needs `clearance + w/2` of radial room
/// before it starts and another `w/2` after it: 53.6 units at 900 px
/// against the 49.5 available. It cannot be made to fit by moving it,
/// only by shrinking it, and shrinking axis type is the defect #315 spent
/// ten mechanisms closing.
///
/// A run laid along the ring needs only `clearance + h/2` inward and
/// `h/2 + w²/8r` outward — 16.5 and 8.1 at 900 px — because its width is
/// spent tangentially, where the ticks are 26.5° and about 190 units
/// apart and there is nothing to hit. The axis ENDS keep horizontal
/// placement: there are two of them, they state the chart's range, they
/// are the labels most often read, and they sit at 53° and 37° off the
/// horizontal where [axialLabelRadius] does fit.
double ringLabelRadius({
  required double rRim,
  required double clearance,
  required double height,
}) =>
    rRim + clearance + height / 2;

/// The farthest any corner of a ring-laid run gets from the centre.
///
/// The run is drawn straight, not bent character by character — at
/// 44.6 units on a radius of 417 the chord departs from the arc by
/// 0.6 units, which no reader can see and which costs none of the
/// kerning that per-character placement throws away. Its ENDS are
/// therefore further out than its middle, and this is that distance.
double ringLabelOuterReach({
  required double radius,
  required double width,
  required double height,
}) =>
    math.sqrt(radius * radius + (width * width) / 4) + height / 2;

/// One label the axis prints outside the rim.
class AxisLabel {
  const AxisLabel({
    required this.year,
    required this.angle,
    required this.text,
    required this.onRing,
  });

  final int year;

  /// Where it is drawn, which for the two ends is their axis line's
  /// angle plus the swing that keeps the words off the line.
  final double angle;
  final String text;

  /// True when it lies along the ring — see [ringLabelRadius] for why
  /// the century ticks do and the two ends do not.
  final bool onRing;
}

/// Every word the axis prints outside the rim, in one list.
///
/// This exists for the same reason [planRadialSpokes] does. Canvas text
/// leaves no widget, no semantics node and nothing a `find.text` can
/// reach, so for as long as the painter decided where a label went, the
/// decision sat in the one place no test could read — and it was wrong
/// for years in both families at once. Returning the plan means a test
/// reads what the page runs instead of a copy of it that can only ever
/// agree with itself.
///
/// [tickLabel] and [endLabel] are passed in rather than called here so
/// this file stays free of the page's strings and its locale.
List<AxisLabel> planAxisLabels({
  required int minYear,
  required int maxYear,
  required String Function(int year) tickLabel,
  required String Function(int year) endLabel,
  required double endSwing,
}) {
  final out = <AxisLabel>[];
  for (var y = minYear; y <= maxYear; y += 100) {
    if (y == minYear || y % 500 != 0) continue;
    out.add(AxisLabel(
      year: y,
      angle: angleForSpan(y, minYear, maxYear),
      text: tickLabel(y),
      onRing: true,
    ));
  }
  for (final (y, swing) in [(minYear, -endSwing), (maxYear, endSwing)]) {
    out.add(AxisLabel(
      year: y,
      angle: angleForSpan(y, minYear, maxYear) + swing,
      text: endLabel(y),
      onRing: false,
    ));
  }
  return out;
}

// ── the arc labels, the last family no test could read ───────────────
//
// The rim's labels have been planned out here since phase 11. The band
// names and the arc labels were still decided inside the painter, where
// canvas text leaves no widget and no semantics node for a test to find
// — so both were measured in the shipped faces over the real 22 streams
// and 62 powers before anything was changed. The band names came back
// sound: rendered and read back pixel by pixel, no two adjacent rows'
// INK touches at 700, 900 or 1200 px in either locale, worst clearance
// 0.91 canvas units, and their size is already bounded when magnified.
// They are left exactly as they were.
//
// The arc labels were not sound. `.clamp(6.0, 10.0)` on top of the
// geometric cap made the FLOOR the binding limit — a 3.12-unit cap at
// 700 px came back out of the clamp as 6.0 — so a label was set at
// exactly 6.00 canvas units at every canvas size, every locale and
// every zoom. Three things followed:
//
//   * on screen the size was 6 x zoom: 48 px at 800%, beside rim
//     labels holding station at 10.5.
//   * the SET never grew. 26 of 62 English names at 900 px, the same 26
//     however far the reader zoomed in. The rule this page is built on
//     is that zooming shows MORE; here it showed the same, larger.
//   * at 700 px the ink of all 22 English and all 34 Chinese labels
//     drawn was 5.88-5.94 units tall in a ring pitch of 5.41 — they
//     printed across the neighbouring stream's row. That is what
//     overriding a geometric cap with a floor buys.
//
// The size now comes from the same two questions the rim answers, and
// the floor is kept but read in the units that make sense of it.

/// The smallest this wheel will put an arc label on the reader's
/// SCREEN, in logical pixels.
///
/// The number is not new: `.clamp(6.0, 10.0)` in the painter has been
/// the wheel's floor all along, and 6.0 is what it produced at every
/// canvas size. What changes is the units. As a floor on the CANVAS
/// size it was multiplied by the `InteractiveViewer` — 6 px at rest and
/// 48 px at 800% — and it could raise a size back over the geometry it
/// had just been capped by. As a floor on the SCREEN size it means at
/// rest what it always meant, and nothing absurd when magnified.
///
/// It is well under [WbMetrics.smallPrintFloor], the 11 px the app
/// holds its chrome to, and that gap is deliberate but unresolved:
/// 22 rings share 153 canvas units at 900 px, so no type that stays
/// inside a ring is 11 px at rest, and raising the floor to 11 would
/// take every arc label off the wheel until the reader zooms to about
/// 200%. Whether a chart's annotations owe the chrome floor is a
/// product question with a real cost either way, and no honest answer
/// is available from the code. This pass keeps the number that ships.
const double kArcLabelFloorPx = 6;

/// Whether the reader's selection covers a thing on a band.
///
/// A tap selects one id, and it may be a power's, an event's, or — when
/// the tap lands on a stretch of band nobody occupies — the STREAM's.
/// Both painters used to test `ownId == selectedId` alone, so selecting
/// a band dimmed the entire wheel, the tapped band included: the reader
/// asked "show me Assyria" and the wheel greyed out with nothing lit.
/// A power belongs to its stream and so does an event, so both count.
bool selectionCovers({
  required String? selectedId,
  required String ownId,
  required String streamId,
}) =>
    selectedId != null && (selectedId == ownId || selectedId == streamId);

/// How much of the ring pitch an arc label's em box may occupy.
///
/// The em box is the right bound, and neither the line box nor the band
/// stroke is. The line box carries leading that is not ink — rendered
/// and read back pixel by pixel in the shipped faces, a label's ink is
/// 0.98 em in Latin and 0.99 in Han, against a line box of 1.17 and
/// 1.37 — so bounding the line box throws away a fifth of the size for
/// nothing. The band stroke is narrower than the pitch and there is no
/// harm in a name overhanging the colour it names. What must not happen
/// is reaching the NEXT stream's row, and an em inside the pitch cannot:
/// 0.99 x 0.9 leaves a tenth of the pitch as clearance.
const double kArcLabelPitchFraction = 0.9;

/// The size at which a power's name can be set along its own arc, or 0
/// when this arc cannot carry it.
///
/// Three limits, and the old painter respected only the third. The em
/// may not exceed [maxEm] or the label reaches the neighbouring stream
/// — measured, at 700 px it did, for all 22 English and all 34 Chinese
/// labels drawn, because `.clamp(6, 10)` RAISED the size back over the
/// geometric cap; it may not be smaller on screen than [floorPx], which
/// is that same clamp's floor read in the units that make sense of it;
/// and it must fit the arc, which carries [fillFraction] of
/// `sweep * radius` of arc length.
///
/// [measure] must be the SUM OF THE CHARACTERS' widths, because that is
/// what the painter lays out — one `TextPainter` per grapheme, set
/// along the curve. A whole-string measurement is shaped and kerned and
/// would decide "it fits" about a string nobody draws.
double fitArcLabel({
  required String text,
  required double radius,
  required double sweep,
  required double maxEm,
  required double desiredSize,
  required double zoom,
  required double floorPx,
  required LabelMeasure measure,
  double fillFraction = 0.92,
}) {
  if (text.isEmpty || sweep <= 0 || radius <= 0 || zoom <= 0) return 0;
  final smallest = floorPx / zoom;
  final room = sweep * fillFraction * radius;
  var size = math.min(desiredSize, maxEm);

  // Scaling the size by room/width is a good guess and not an answer:
  // glyph advances are hinted and quantised, so a string is not exactly
  // proportional to its size and the guess can still overrun. Measured
  // over the real corpus it overran for one power at 700 px. So the
  // guess is re-measured, with at least 2% taken off each pass to
  // guarantee it terminates, and a label that still will not fit keeps
  // its arc and loses its words.
  for (var attempt = 0; attempt < 6; attempt++) {
    if (size < smallest) return 0;
    final w = measure(text, size);
    if (w <= 0) return 0;
    if (w <= room) return size;
    size = math.min(size * room / w, size * 0.98);
  }
  return 0;
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

// ── the lifespans, as arcs in the annulus ────────────────────────────
//
// WHY THE ANNULUS AND NOT A BAND. Twenty-five lives, eleven of them
// running at once (Noah through Abraham, AM 1948-1996), will not go on
// the stream bands: a 23rd band at 900 px is 5.6 canvas units and
// eleven sub-rings of it are half a unit each. Eleven NEW bands among
// the streams drops the ring pitch from 6.95 to 4.8, so `fitArcLabel`'s
// cap (pitch x 0.9 = 4.3) falls under the 6 px floor and every one of
// the 62 power names goes dark at rest — the wheel's main content
// paying for a side layer. Shrinking the hub buys 6.3, cap 5.7, still
// under the floor.
//
// The annulus is the one region with room. It is 112 units deep at
// 700 px and 224 at 1400, it holds one label per spoke by design (see
// [planRadialSpokes] — stacking is deliberately unreachable), and in
// the 139 degrees these lives occupy it carries about 50 spokes against
// 88 slots. Eleven sub-rings there are 9.7 units apart at 700 px, which
// clears the 9 px finger target, and 19.9 at 1400.
//
// Radial space is nearly free; angular space is scarce. That is the
// sentence the whole page is built on, and a span layer is what it buys.

/// One life, placed: which sub-ring it sits in and the two angles its
/// years fall at.
///
/// [line] is the patriarch's own `line` out of `chronology.json`, not a
/// colour: the page decides the hue, this file decides the geometry.
class LifeArc {
  const LifeArc({
    required this.id,
    required this.ring,
    required this.a0,
    required this.a1,
    required this.line,
    required this.birthYear,
    required this.deathYear,
  });

  /// The `chronology.json` patriarch id.
  final String id;

  /// 0 is INNERMOST — flush against the scripture label base. That is
  /// the opposite of [ringRadii]'s convention, which counts 0 from the
  /// outside, so a caller turning one of these into a radius must index
  /// `ringCount - 1 - ring`. See [lifeArcRadii], which does it.
  final int ring;

  final double a0;
  final double a1;

  /// `seth` / `shem` / `abraham` / `levi`, straight from the asset.
  final String line;

  /// Astronomical BC years, `creationYear + am`. Carried so nothing
  /// downstream has to redo the conversion — see the library note.
  final int birthYear;
  final int deathYear;

  double get sweep => a1 - a0;
}

/// One span offered to [buildSpanArcs], in BC years already.
///
/// Deliberately not a model type. The band draws lives from
/// `chronology.json` and reigns from `hebrew_kings.json`, which share
/// no supertype and should not be made to — what the packer needs is
/// two years, an id to hand back, and a `line` the page can colour by.
typedef SpanInput = ({String id, String line, int startYear, int endYear});

/// Spans packed into as few sub-rings as their overlaps allow.
///
/// This is the whole of the band's geometry, and every layer that draws
/// in it MUST come through one call. Packing two sets separately and
/// concatenating them would give both a ring 0 and print one over the
/// other — which looks like a rendering bug and is really an arithmetic
/// one, so it is said here rather than discovered.
///
/// Years are BC-negative and already converted; see [buildLifeArcs] for
/// the Anno Mundi case.
List<LifeArc> buildSpanArcs({
  required List<SpanInput> spans,
  required int minYear,
  required int maxYear,
  double minGap = 0.02,
}) {
  final placed = <({SpanInput s, double a0, double a1})>[
    for (final s in spans)
      (
        s: s,
        a0: angleForSpan(s.startYear, minYear, maxYear),
        a1: angleForSpan(s.endYear, minYear, maxYear),
      )
  ]..sort((a, b) => a.a0.compareTo(b.a0));
  if (placed.isEmpty) return const [];

  // Enough rings that first-fit never has to overprint, so the count
  // that comes back is the one the overlaps actually require.
  final rings = packIntoRings(
    [for (final p in placed) p.a0],
    [for (final p in placed) p.a1],
    placed.length,
    minGap: minGap,
  );
  return [
    for (var i = 0; i < placed.length; i++)
      LifeArc(
        id: placed[i].s.id,
        ring: rings[i],
        a0: placed[i].a0,
        a1: placed[i].a1,
        line: placed[i].s.line,
        birthYear: placed[i].s.startYear,
        deathYear: placed[i].s.endYear,
      )
  ];
}

/// Every life the given tradition has figures for, packed into as few
/// sub-rings as their overlaps allow.
///
/// [creationYear] is `_meta.creation.year` out of `bible_timeline.json`
/// and there is no default: a caller that cannot find it must draw
/// nothing rather than substitute a literal, because a silent -4000 is
/// the calendar this anchor replaced.
///
/// [minGap] is passed to the packer IN RADIANS and is stated rather
/// than defaulted, because `packIntoRings`' own 0.02 rad default is 22
/// years on THIS axis and would silently become some other number of
/// years the day the axis moved.
///
/// The ring count is not an argument: it is whatever the overlaps
/// demand, which for the Masoretic figures is eleven. Writing a number
/// in would be a claim about the data that the data already makes.
List<LifeArc> buildLifeArcs({
  required List<Patriarch> patriarchs,
  required String tradition,
  required int creationYear,
  required int minYear,
  required int maxYear,
  double minGap = 0.02,
  List<SpanInput> alsoPack = const [],
}) =>
    buildSpanArcs(
      spans: [
        ...patriarchsAsSpans(patriarchs, tradition, creationYear),
        // Packed in the SAME call, never appended after one. See
        // [buildSpanArcs].
        ...alsoPack,
      ],
      minYear: minYear,
      maxYear: maxYear,
      minGap: minGap,
    );

/// The Anno Mundi → BC conversion, on its own so a caller that needs the
/// years without the packing can have them.
List<SpanInput> patriarchsAsSpans(
  List<Patriarch> patriarchs,
  String tradition,
  int creationYear,
) =>
    [
      for (final p in patriarchs)
        if (p.figures[tradition] != null)
          (
            id: p.id,
            line: p.line,
            startYear: creationYear + p.figures[tradition]!.birthAm,
            endYear: creationYear + p.figures[tradition]!.deathAm,
          )
    ];

/// How many sub-rings [arcs] occupy. Derived, never written down.
int lifeArcRingCount(List<LifeArc> arcs) {
  var top = -1;
  for (final a in arcs) {
    if (a.ring > top) top = a.ring;
  }
  return top + 1;
}

/// The radii of one life's sub-ring, with ring 0 INNERMOST.
///
/// [ringRadii] counts ring 0 from the rim inward, which is right for
/// the stream bands (the outermost band is the first stream) and wrong
/// here: the lives read outward from the scripture baseline, so Adam is
/// against the bands and the eleventh sub-ring is against the rim. The
/// index is flipped here, once, rather than at each call site.
({double inner, double outer, double centre, double width}) lifeArcRadii(
  int ring,
  int ringCount,
  double rInner,
  double rOuter,
) =>
    ringRadii(ringCount - 1 - ring, ringCount, rInner, rOuter);

/// An angular stretch something else has already claimed.
typedef ArcSpan = ({double start, double end});

/// The stretches of `[a0, a1]` that [occupied] does not cover, in order.
List<ArcSpan> _freeSpans(double a0, double a1, List<ArcSpan> occupied) {
  final blocks = [
    for (final o in occupied)
      if (o.end > a0 && o.start < a1)
        (start: math.max(o.start, a0), end: math.min(o.end, a1))
  ]..sort((x, y) => x.start.compareTo(y.start));
  final out = <ArcSpan>[];
  var cursor = a0;
  for (final b in blocks) {
    if (b.start > cursor) out.add((start: cursor, end: b.start));
    if (b.end > cursor) cursor = b.end;
  }
  if (cursor < a1) out.add((start: cursor, end: a1));
  return out;
}

/// The widest run of `[a0, a1]` no planned spoke label crosses.
///
/// What a name has to FIT, which is not the arc's own sweep. A
/// tangential name laid across a radial title is two illegible strings,
/// and this wheel's rule is legible or absent — so a life whose whole
/// span is under a spoke keeps its ink and loses its word, exactly as
/// the rim already does.
double arcNameRoom(double a0, double a1, List<ArcSpan> occupied) {
  var best = 0.0;
  for (final s in _freeSpans(a0, a1, occupied)) {
    final w = s.end - s.start;
    if (w > best) best = w;
  }
  return best;
}

/// Where a name [needed] radians wide can start, or null.
///
/// Centred in the widest free run rather than at the arc's midpoint,
/// which is the whole difference: the midpoint of Methuselah's 969
/// years is under the spokes of a dozen events.
double? placeArcName(
  double a0,
  double a1,
  List<ArcSpan> occupied,
  double needed,
) {
  if (needed <= 0) return null;
  ArcSpan? best;
  var bestW = 0.0;
  for (final s in _freeSpans(a0, a1, occupied)) {
    final w = s.end - s.start;
    if (w > bestW) {
      best = s;
      bestW = w;
    }
  }
  if (best == null || bestW < needed) return null;
  return best.start + (bestW - needed) / 2;
}

/// Where to move the scene so a point on the wheel sits under the middle
/// of the viewport, at the zoom the reader has already chosen.
///
/// Search has to do more than name a record: on a chart this dense,
/// telling a reader "it is on the wheel somewhere" is barely better
/// than not finding it. BibleWorks' timeline scrolls to the date
/// (`bwh39`); the radial equivalent is to pan the found spoke into the
/// middle. Zoom is deliberately NOT changed — the reader set it, and a
/// search that silently rescales the chart is a search that loses
/// their place.
///
/// [px], [py] are in scene coordinates: the `InteractiveViewer`'s child
/// fills the viewport, so the square canvas is centred inside it and a
/// point at radius r and angle a is at
/// `(viewW / 2 + r cos a, viewH / 2 + r sin a)`.
///
/// The result is CLAMPED to the range `InteractiveViewer` itself
/// enforces on a drag, because the transformation controller can be set
/// to anything and an unclamped jump would leave the canvas half off
/// the frame until the reader's next gesture snapped it back. At a
/// scale of 1 or less the whole canvas already fits, so there is
/// nothing to pan to and the identity is returned — which is also the
/// honest answer to "centre this" when it is already all visible.
({double dx, double dy}) focusTranslation({
  required double px,
  required double py,
  required double scale,
  required double viewW,
  required double viewH,
}) {
  if (scale <= 1.0) return (dx: 0, dy: 0);
  final tx = (viewW / 2 - scale * px).clamp(viewW * (1 - scale), 0.0);
  final ty = (viewH / 2 - scale * py).clamp(viewH * (1 - scale), 0.0);
  return (dx: tx, dy: ty);
}
