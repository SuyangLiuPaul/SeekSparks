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
/// 2026-09-16, AND THIS IS A CORRECTION OF THE ABOVE. It read
/// `=> selected` for one day, and the owner found what that costs:
/// 「你label没有的时候我都看不了对比了」, with screenshots at 888% and 789%
/// showing coloured bands and grey arcs carrying no text at all.
///
/// The argument above is right about ROTATION and wrong about what
/// follows from it. Zooming really does not fix text laid along a
/// tangent — it makes more of it, bigger, still pointing every way. But
/// the remedy for that is to stand the words up, not to delete them,
/// and I deleted them. Magnifying a chart is how a reader asks "what is
/// this one"; a list beside the chart cannot answer that, because it
/// does not know where the finger is.
///
/// So the names come back at 1.6x, drawn LEVEL, on plates, and
/// decluttered against what is already painted. The selected record
/// keeps its name at every zoom, because that is the one question the
/// list can never answer.
bool wheelShowsEventText({required double zoom, required bool selected}) =>
    selected || wheelDetailFor(zoom).records > 0;

/// THE FAINTEST A NAME MAY BE DRAWN, as a multiplier on its colour.
///
/// When one record is selected the rest are dimmed, and that is right
/// for MARKS — a tick at 28% is still a tick. It is not right for
/// WORDS. Measured on the dark palette, compositing the label's own
/// plate over the chart and the text over that:
///
///     dim 1.00   13.23:1
///     dim 0.75    7.75:1
///     dim 0.55    4.73:1   ← the floor
///     dim 0.35    2.70:1   ← an unselected arc's name
///     dim 0.28    2.20:1   ← an unselected record's name
///
/// The last two are not words. They are smudges shaped like words,
/// inside a plate the reader CAN still see — which is why the owner
/// circled them twice and called them 「线」: 2026-09-17 「中间这些线你
/// 还是没有fix啊」, of two faint boxes beside a selected 以撒.
///
/// So a name is drawn legibly or not at all, and what a dimmed record
/// keeps is its mark. 4.5:1 is the app's own standard everywhere else
/// (`palette_legibility_walk_test`).
const double kLegibleLabelDim = 0.55;

/// One million square pixels — the unit the detail table's densities are
/// quoted in. A 1280x663 pane is 0.85 of one; a 390x620 phone is 0.24.
const double kWheelLabelArea = 1000000;

/// The kinds of name this wheel can put on the canvas.
///
/// One enum rather than four booleans scattered through the painter,
/// because the question the reader is actually asking — "why is there so
/// much text on this" — is about the MIX, and a mix cannot be read out
/// of conditions that each know only about themselves.
enum WheelLabelKind {
  /// A stream's own name: 犹大, 教会, 圣经, 全世界.
  ring,

  /// A power, a reign, a ministry — a span with a width.
  power,

  /// A lifespan on the genealogy annulus.
  life,

  /// One record's title, beside its tick.
  record,
}

/// WHAT THE WHEEL DRAWS AT A GIVEN MAGNIFICATION — the whole of it, as
/// rows, in one place.
///
/// Until 2026-09-17 there was no table: every name on the chart was
/// gated by the single `zoom >= 1.6` above, so every class of label
/// arrived at once and then competed for room first-come-first-served.
/// Measured on one 900x900 screen, that put 30 record names on the
/// canvas at 332% — which is the density the owner has been reporting
/// since the redesign, and it is not a decluttering failure. Each of
/// those labels cleared its neighbours honestly. There were simply too
/// many of them, and nothing in the code had an opinion about how many
/// is too many.
///
/// A cap is only half of it. A cap with no ranking is still first-come-
/// first-served — it just stops earlier — so the caps here are paired
/// with a rank inside each kind (see `_paintSpokes`): the selected
/// record, then the biggest clusters, then the ones carrying scripture,
/// then by year. What a cap removes is the thirtieth most useful name
/// on the screen, not whichever one happened to be painted last.
class WheelDetailLevel {
  const WheelDetailLevel({
    required this.name,
    required this.minZoom,
    required this.rings,
    required this.powers,
    required this.lives,
    required this.records,
  });

  /// For tests and the probe. Also what a reader would call this view.
  final String name;

  /// The magnification at which this row takes over.
  final double minZoom;

  /// Names of each kind per [kWheelLabelArea] of visible chart.
  ///
  /// A DENSITY, not a count, and that is the correction of 2026-09-17:
  /// the first version of this table was a flat count, and 「很多这些也
  /// 看不见了」 was the owner watching dynasty names disappear from a
  /// desktop pane that had plenty of room for them. How many names a
  /// screen can carry is a question about the SCREEN. A phone and a
  /// 27-inch monitor do not have the same answer, and a table that
  /// gives them the same one is wrong on one of them — it was wrong on
  /// the big one, where nothing was crowded and names went missing.
  final double rings;
  final double powers;
  final double lives;
  final double records;

  double densityFor(WheelLabelKind kind) => switch (kind) {
        WheelLabelKind.ring => rings,
        WheelLabelKind.power => powers,
        WheelLabelKind.life => lives,
        WheelLabelKind.record => records,
      };

  /// How many names of [kind] a pane of [areaPx] square pixels may
  /// carry. A kind this row does not draw at all stays at zero;
  /// everything else gets at least one, because a chart that names
  /// nothing at all is not calmer, it is mute.
  int capFor(WheelLabelKind kind, {required double areaPx}) {
    final density = densityFor(kind);
    if (density <= 0) return 0;
    final count = (density * (areaPx / kWheelLabelArea)).round();
    return count < 1 ? 1 : count;
  }
}

/// The table. Ordered by [WheelDetailLevel.minZoom]; the last row whose
/// threshold the zoom has passed is the one in force.
///
/// The numbers are measured, not chosen: see
/// `test/wheel_detail_levels_test.dart` for what each row admits on a
/// 900x900 screen, and the counts before this existed.
const List<WheelDetailLevel> kWheelDetailLevels = [
  // At rest the wheel is a SHAPE — four rings, their colours, their
  // spans. The only words are the rings' own names and the century
  // axis, which is what the eye needs to know what it is looking at.
  WheelDetailLevel(
      name: 'fit', minZoom: 0, rings: 16, powers: 0, lives: 0, records: 0),
  // The first zoom is a reader asking "what is in here". Measured on a
  // 1280x663 pane at 200%: 0.57 million square pixels of chart (the
  // disc does not fill a wide pane), carrying 22 power names, 24
  // lifespan names and 5 record names before any of this existed.
  // These densities come to 22, 19 and 19 there — the powers are
  // exactly what a desktop reader already had, the lifespans give some
  // of their room to the records, and nothing a big screen was showing
  // goes missing. On a 390x620 phone the same row says 10, 8 and 8.
  WheelDetailLevel(
      name: 'survey', minZoom: 1.6, rings: 16, powers: 40, lives: 34,
      records: 34),
  // Closer in, the same screen covers fewer years, so the same names
  // are further apart and more of them fit without crowding.
  WheelDetailLevel(
      name: 'read', minZoom: 5, rings: 16, powers: 52, lives: 44,
      records: 52),
  // Far enough in that a screen holds a handful of records: whatever
  // fits, fits. The declutter list is the only limit left.
  WheelDetailLevel(
      name: 'close', minZoom: 16, rings: 18, powers: 72, lives: 60,
      records: 72),
];

/// Which row of [kWheelDetailLevels] is in force at [zoom].
WheelDetailLevel wheelDetailFor(double zoom) {
  var level = kWheelDetailLevels.first;
  for (final row in kWheelDetailLevels) {
    if (zoom >= row.minZoom) level = row;
  }
  return level;
}

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
  double? canvasHalf,
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
  // The outward placement, and how far past the rim its ink reaches.
  final reach = (width / 2) * math.cos(angle).abs() +
      (height / 2) * math.sin(angle).abs();
  final outward = rimRadius + clearance + reach;
  // OUTSIDE WHEN THERE IS ROOM, JUST INSIDE WHEN THERE IS NOT, AND
  // NEVER ROTATED. 2026-09-15.
  //
  // The margin outside the rim is a fixed number of pixels and the
  // canvas is not, so a small wheel runs out of it: a 360 px phone
  // leaves 32 px outside the rim and `3000 BC` needs about 55. Letting
  // the rim shrink to make room is what deleted the lifespan annulus
  // 「另外没有家谱寿命了」, and dropping every label leaves a chronology
  // with no year scale at all — which is worse than the curved labels
  // this replaced.
  //
  // So the label steps INWARD instead, onto the outer edge of the
  // annulus, still level. It costs a little of the layer beneath it and
  // the painter gives it a plate; what it does not cost is the reader's
  // neck, which is the whole point of the change.
  final inward = rimRadius - clearance - reach;
  final radius = canvasHalf == null || outward + reach <= canvasHalf
      ? outward
      : math.max(inward, rimRadius * 0.5);
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
/// How many century labels a wheel of this size should carry words on.
///
/// 2026-09-15, and it is a COUNT rather than a size or a position,
/// because that is what the problem turned out to be.
///
/// A 360 px phone has no room outside its rim for an upright year
/// label, so the labels step inward onto the annulus — and eight of
/// them, each on its own plate, buried the very layers that had just
/// been rescued from the same squeeze. Making them smaller would undo
/// 「字体感觉太小」; pushing the rim in to make room outside is what
/// deleted the lifespans 「另外没有家谱寿命了」. Neither was the problem.
/// Eight labels is simply too many words for a 360 px circle.
///
/// One per 120 px of side: three on a phone, seven at 900, eleven at
/// 1400 — and the TICK LINES are unaffected, so the scale keeps its
/// resolution and loses only some of its numbers. The cursor and the
/// hub read any year exactly.
int axisLabelBudget(double side) => math.max(2, (side / 120).round());

List<AxisLabel> retainSeparatedWheelAxisLabels({
  required List<AxisLabel> labels,
  required Rect Function(AxisLabel label) boundsOf,
  double gap = 4,
  Rect? canvasBounds,
  int? maxOnRing,
}) {
  // THE RANGE ENDS ARE NO LONGER EXEMPT FROM THE CANVAS.
  //
  // They used to be admitted unconditionally, and the reason was good:
  // they are what the chart's range IS, and a chronology that will not
  // say where it starts and stops is not much of one.
  //
  // That reason expired on 2026-09-15, when the hub stopped repeating
  // the page title and started printing the range itself. The range is
  // now stated inside the circle, in full, at every canvas size — so an
  // end label that cannot fit on a 360 px phone is a duplicate that
  // does not fit, and pushing the rim inward to make room for it is
  // what cost the lifespans their annulus 「另外没有家谱寿命了」.
  //
  // Its RAY is drawn either way (`_paintAxisEnds` draws the line before
  // it places the text), so what a dropped end costs is a word, not the
  // mark. They still take precedence over the century ticks.
  bool fits(AxisLabel label) {
    if (canvasBounds == null) return true;
    final ink = boundsOf(label);
    return ink.left >= canvasBounds.left &&
        ink.right <= canvasBounds.right &&
        ink.top >= canvasBounds.top &&
        ink.bottom <= canvasBounds.bottom;
  }

  final retained =
      labels.where((label) => !label.onRing && fits(label)).toSet();
  final occupied = [
    for (final label in retained) boundsOf(label).inflate(gap / 2),
  ];
  // Thinned to the budget BEFORE the collision pass, and spread across
  // the range rather than taken from the front: keeping the first N
  // would put every word in the chart's oldest quarter and leave the
  // modern end unlabelled.
  var onRing = labels.where((label) => label.onRing).toList();
  if (maxOnRing != null && onRing.length > maxOnRing) {
    final step = onRing.length / maxOnRing;
    onRing = [
      for (var i = 0; i < maxOnRing; i++) onRing[(i * step).floor()],
    ];
  }
  for (final label in onRing) {
    final ink = boundsOf(label);
    // The shared mode row leaves a 131 px wheel in the short landscape
    // case. Even separated Chinese tick labels can cross that boundary;
    // their ticks and the year cursor remain when the words cannot fit.
    if (!fits(label)) continue;
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

/// ONE ANSWER THE HIT TEST GAVE, AND THE SHAPE IT CLAIMED TO BE IN.
///
/// 2026-09-17 「我的意思就是hover over那个不准确」 — reported from the
/// wheel at 3660%, where hovering blank paper named a band three hundred
/// pixels away.
///
/// The problem with that report is not the report, it is that nothing
/// in this codebase could answer it. The hit test is three hundred lines
/// of ring-before-angle, normalised distance and finger-width-in-radians,
/// every clause of it written against a real complaint, and the only
/// instrument anyone has ever had for it is a person looking at a screen
/// and saying "that's wrong". Two theories were tried against this
/// particular report before this record existed; the first was measured
/// and found to account for 1 point in 169, which is to say it was
/// wrong, and the second would have been another guess.
///
/// So: the resolver now reports, for every question it is asked, what it
/// answered AND the true extent of the thing it answered with. That
/// turns "is the hit test accurate" from an opinion into arithmetic —
/// how far outside its own target, in SCREEN pixels, was the point it
/// claimed?
///
/// Off in every shipped build; one boolean read per resolve when off.
typedef WheelHitProbe = ({
  /// What was asked: the point, in canvas polar coordinates, and the
  /// scale it was asked at.
  double r,
  double a,
  double zoom,

  /// What was answered. [id] is empty when the answer was "nothing".
  String id,
  String label,
  String kind,

  /// The answer's own true extent — the unpadded geometry, exactly as
  /// the painter drew it. [a0]/[a1] are its angular run and are equal
  /// for a point-like target (a tick, a rail mark); [centre] and
  /// [halfDepth] are its radial band.
  double a0,
  double a1,
  double centre,
  double halfDepth,

  /// The slack the branch ITSELF allowed, in radians either side of
  /// [a0]/[a1]. Recorded rather than assumed, because every branch
  /// computes its own and they do not agree: a tick allows
  /// `9 / (zoom * r)`, an arc allows `fingerHalfWidth`, a rail mark
  /// allows `max(9 / centre, 0.004)`.
  ///
  /// Without it the instrument would report a tick as wrong whenever
  /// the pointer was not exactly on it — measuring the target as a
  /// point when it was never meant to be one, and burying the real
  /// mistakes under a pile of false ones. (It did, on the first run:
  /// 14 of the 15 "errors" at 100% were ticks behaving correctly.)
  double halfAngle,

  /// Half the depth of the record's own INK — what the painter actually
  /// drew. [halfDepth] is the target; this is the part of it a reader
  /// can see. The difference is the air, and the air is where an answer
  /// is not merely surprising but wrong: the eye says "I am between two
  /// bands" and the plate names one of them.
  double inkHalf,
});

/// Deterministic work counters for the real page, independent of device
/// speed. They measure scene planning and painter invocations separately.
class WheelRenderStats {
  WheelRenderStats._();

  static int sceneBuilds = 0;
  static int paints = 0;

  /// WHAT THE CANVAS TRIED TO SAY, FOR TESTS ONLY.
  ///
  /// Every word on this wheel is a `TextPainter` on a canvas: no widget,
  /// no semantics node, nothing `find.text` can reach. That blindness is
  /// how 亚们 could go unlabelled for a day with its own branch of code
  /// written for him — the branch read the name AS DRAWN ALONG THE ARC,
  /// which is empty exactly when a record is too narrow to carry it, so
  /// the guard was false in every case it existed to serve. No test
  /// could see it. 2026-09-16 「亚们还是没有解决」.
  ///
  /// So the painter reports the two things a test needs: which names it
  /// was asked to draw, and which of those it could find no free room
  /// for. OFF BY DEFAULT — [trackLabels] is false in every shipped
  /// build, and the two calls below cost one boolean read per label.
  /// `wheel_paint_cost_test.dart` is the reason that matters.
  /// How many label plates the last frame actually put on the canvas.
  /// One int per paint, always on — the density of this chart is the
  /// thing the owner keeps reporting, and it should be measurable
  /// without arming anything.
  static int labelsDrawn = 0;

  static bool trackLabels = false;
  static final Set<String> labelsAsked = <String>{};
  static final Set<String> labelsLost = <String>{};

  static void noteLabelAsked(String text) {
    if (trackLabels) labelsAsked.add(text);
  }

  static void noteLabelLost(String text) {
    if (trackLabels) labelsLost.add(text);
  }

  /// WHAT THE HIT TEST ANSWERED, FOR TESTS ONLY. See [WheelHitProbe].
  static bool trackHits = false;
  static final List<WheelHitProbe> hitsForTest = <WheelHitProbe>[];

  /// WHERE A RING'S NAME WAS ACTUALLY PAINTED, in canvas coordinates.
  ///
  /// The third of Fable 5.1's rules, 2026-09-17: test accuracy in the
  /// READER's frame, not the resolver's. The resolver can be exact and
  /// the reader still lost, if the name of the thing under the pointer
  /// is not on the screen at all. That is a measurement, and this is
  /// what makes it one.
  static final List<({String text, double x, double y})> bandNamesForTest =
      <({String text, double x, double y})>[];

  static void noteBandName(String text, double x, double y) {
    if (trackHits) bandNamesForTest.add((text: text, x: x, y: y));
  }

  /// EVERY FONT SIZE THAT REACHED THE CANVAS, for tests only.
  ///
  /// The count of DISTINCT values is the measurement: a chart whose
  /// labels are sized by how much room happened to be free has as many
  /// sizes as it has labels, and a reader cannot then tell a container
  /// from a point by looking.
  static final List<double> labelSizesForTest = <double>[];

  static void noteLabelSize(double size) {
    if (trackHits) labelSizesForTest.add(size);
  }

  /// HOW MANY OF EACH KIND OF NAME REACHED THE CANVAS ON THE LAST
  /// FRAME, for tests only.
  ///
  /// `labelsDrawn` counts plates and cannot tell a ring's name from a
  /// record's, so it could not answer the question the detail table
  /// exists to answer: what is the MIX at this zoom.
  ///
  /// The LAST frame, not a running total, and that is the whole point:
  /// the table's caps are per screen, so a measurement that added up
  /// every frame of a zoom animation would be measuring the animation.
  static final Map<WheelLabelKind, int> labelKindsForTest =
      <WheelLabelKind, int>{};

  /// WHAT THE READER COULD SEE ON THE LAST FRAME, in canvas units.
  ///
  /// A count of labels means nothing without the camera that produced
  /// it: at 1476% the viewport covers about a two-hundredth of the
  /// canvas, so "no labels" can mean a decluttering failure or can mean
  /// the view is parked on the empty hub, and the two look identical in
  /// a number. Armed with `trackHits`.
  static Rect? cameraForTest;

  /// The visible area the caps were computed from, in screen pixels
  /// squared. A cap is a density times this number, so a test that
  /// asserts on caps needs it.
  static double frameAreaForTest = 0;

  /// EVERY PLATE THE LAST FRAME PUT ON THE CANVAS, in canvas units.
  ///
  /// With [cameraForTest] this is what makes "the reader can see it" a
  /// measurement rather than a claim: a box that does not overlap the
  /// camera is a name nobody read, drawn anyway, holding room beside
  /// one they could have. Armed with `trackHits`.
  static final List<Rect> labelBoxesForTest = <Rect>[];

  static void noteLabelBox(Rect box) {
    if (trackHits) labelBoxesForTest.add(box);
  }

  /// WHERE EACH RECORD'S NAME WAS DRAWN on the last frame, by id.
  ///
  /// The hit test answers from these boxes, so a test that wants to
  /// know whether an answer came from a name the reader could see has
  /// to be able to see them too. Armed with `trackHits`.
  static final Map<String, Rect> recordNameBoxesForTest = <String, Rect>{};

  static void noteRecordNameBoxes(Map<String, Rect> boxes) {
    if (!trackHits) return;
    recordNameBoxesForTest
      ..clear()
      ..addAll(boxes);
  }

  static void noteFrameKinds(Map<WheelLabelKind, int> drawn) {
    if (!trackHits) return;
    labelKindsForTest
      ..clear()
      ..addAll(drawn);
  }

  static void noteHit(WheelHitProbe probe) {
    if (trackHits) hitsForTest.add(probe);
  }

  /// How far the point was from the answer's own target, in SCREEN
  /// pixels — 0 when the point is genuinely inside it.
  ///
  /// The two errors are reported as one number because they are the
  /// same kind of wrongness: the reader pointed at something and was
  /// given something they were not pointing at. Angular distance is
  /// converted at the point's own radius, which is what makes it
  /// comparable with the radial one.
  /// Whether the point was on the record's own ink, rather than in the
  /// air its target also claims. False for a point-like target, which
  /// has no ink to be on.
  static bool hitWasOnInk(WheelHitProbe p) =>
      p.id.isNotEmpty && (p.r - p.centre).abs() <= p.inkHalf;

  static double hitErrorPx(WheelHitProbe p) {
    if (p.id.isEmpty) return 0;
    final outward = (p.r - p.centre).abs() - p.halfDepth;
    final radial = outward > 0 ? outward : 0.0;
    final before = p.a0 - p.halfAngle - p.a;
    final after = p.a - (p.a1 + p.halfAngle);
    final gap = before > after ? before : after;
    final angular = gap > 0 ? gap * p.r : 0.0;
    return (radial > angular ? radial : angular) * p.zoom;
  }

  static void reset() {
    sceneBuilds = 0;
    paints = 0;
    labelsDrawn = 0;
    labelsAsked.clear();
    labelsLost.clear();
    hitsForTest.clear();
    bandNamesForTest.clear();
    labelSizesForTest.clear();
    labelKindsForTest.clear();
    labelBoxesForTest.clear();
    recordNameBoxesForTest.clear();
    cameraForTest = null;
    frameAreaForTest = 0;
  }
}
