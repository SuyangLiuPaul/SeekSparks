/// Pure geometry for the horizontal chronology strip.
///
/// WHY THERE IS A SECOND FORM AT ALL. The wheel puts all 6226 years on
/// one screen by construction — that is its whole idea, and it is also
/// the thing that cannot be tuned. Measured over the shipped corpus:
/// the 22 stream rings share `side x 0.17`, which is **3.01 canvas units
/// each on a 390 px phone** against a 9 px finger, and four reigns
/// (Zimri, Huldah, Ahaziah of Judah, Jehoahaz of Judah) are **0.00 px
/// wide at every canvas and every zoom** because each begins and ends in
/// the same year. Neither is a parameter anybody can move: the cross
/// axis is bounded by the viewport radius, and `InteractiveViewer`
/// scales both axes together, so magnifying a seven-day reign magnifies
/// Methuselah's 969 years off the screen with it.
///
/// A strip unbinds both. Time gets as many pixels as it asks for and
/// scrolls; lanes get a height chosen in pixels and scroll; and the two
/// zooms are separate, so a reader can open one century to 20 px/year
/// without touching the lane height. That is the entire argument, and
/// the numbers behind it are in `WHEEL-UX-REDESIGN.md`.
///
/// WHAT A STRIP DOES NOT FIX, so that nobody expects it to. The corpus
/// is violently front-loaded. The wheel draws 851 events — 747 from
/// `wheel_history.json` plus 104 merged in from `bible_timeline.json`
/// by `WheelHistoryService.load()` — and 140 of the 851 fall in the 2%
/// of the axis after 1900 (8.06x its share of the axis), while the
/// whole 4200-2000 BC third holds 35 (0.12x its share). A *uniform*
/// strip at 2 px/year on a 900 px screen still has **298 events in its
/// densest window**, AD 1559-2008, needing about 30 rows to name them
/// all. The strip's win is not that crowding disappears; it is that
/// crowding becomes scrollable and x-zoomable, which the wheel
/// structurally forbids.
///
/// TWO RULES THIS FILE MAY NOT BREAK, both inherited and both earned:
///
///  1. **Painted width is duration.** A span narrower than a finger
///     keeps the ink its years bought. It may be given a wider TARGET
///     ([hitTargetFor]) and a marker glyph, and it may not be drawn
///     wider than it is — that is the same lie as widening Zimri's seven
///     days to look like twenty years on a chart whose one claim is that
///     width means time. It is why the wheel grew a centre dot rather
///     than a fatter bar.
///  2. **Nothing narrows in silence.** #280, #308 and #319 were all one
///     defect: a view dropped its own contents and said nothing. On a
///     strip the reader can always reach what is off-screen, so the
///     honest form is an indicator plus a scroll — never a silent drop.
///
/// Angle has no meaning here. x is the year, y is the lane, and both are
/// in *content* pixels: the caller's scroll offsets turn them into screen
/// pixels, and this file never knows about a viewport.
///
/// Kept free of widgets because it is the part worth testing.
library;

import 'dart:math' as math;

import 'package:seeksparks/utils/related_verses.dart' show isCjkChar;

// ── the time axis ────────────────────────────────────────────────────

/// The axis this strip draws, shared with the wheel so the two forms
/// cannot disagree about what history is.
const int kStripMinYear = -4200;
const int kStripMaxYear = 2026;

/// The zoom ladder, in pixels per year.
///
/// Chosen so each step roughly doubles and the ends are the two things a
/// reader actually wants: 0.15 fits the whole axis on a phone (6226 x
/// 0.15 = 934 px), and 24 puts a single year at two thirds of an inch,
/// which is what it takes to separate the 140 events after 1900.
const List<double> kStripZoomSteps = [0.15, 0.3, 0.6, 1.5, 3, 6, 12, 24];

/// The zoom the strip OPENS on — deliberately not the widest step.
///
/// `kStripZoomSteps.first` (0.15) puts all 6226 years on one screen,
/// which is the wheel's fixed condition and the one this form exists to
/// escape. Measured on the shipped corpus at that scale, an event tick
/// owns about 3 px before the next one, so no title fits and the events
/// lane opens as a field of bare `+n` badges: the reader is told a great
/// deal is here and shown none of it.
///
/// 1.5 px/year shows about 930 years on a 1400 px pane and about 250 on
/// a phone — an era at a time, with room for names — and the whole axis
/// is one drag or one press of Fit All away. Free scrolling is what a
/// strip buys; spending it to reproduce a single crowded screen would be
/// paying for the ticket and staying home.
const double kStripInitialPxPerYear = 1.5;

/// x, in content pixels from the strip's left edge, for [year].
///
/// Linear and uniform, deliberately. A log or era-compressed axis would
/// fix the density in one move and would make width stop meaning
/// duration — see rule 1. If the axis is ever compressed, the
/// compression must be DRAWN (a visible fold or break), not silent.
double xForYear(int year, double pxPerYear, {int minYear = kStripMinYear}) =>
    (year - minYear) * pxPerYear;

/// The year at content-x [x]. The inverse of [xForYear], and the thing a
/// tap on the ruler means.
double yearForX(double x, double pxPerYear, {int minYear = kStripMinYear}) =>
    minYear + x / pxPerYear;

/// The whole strip's content width at [pxPerYear].
double stripContentWidth(double pxPerYear,
        {int minYear = kStripMinYear, int maxYear = kStripMaxYear}) =>
    xForYear(maxYear, pxPerYear, minYear: minYear);

/// The px a span of [start]..[end] occupies. May be 0 — see rule 1.
double spanWidth(int start, int end, double pxPerYear) =>
    (end - start) * pxPerYear;

/// The pxPerYear at which [year] range fits [viewportPx], for "fit all"
/// and for search's "show me this century".
///
/// A degenerate request — [fromYear] equals [toYear], or a viewport of
/// no width — has no honest ratio to report, so it returns the ladder's
/// own maximum rather than a divide-by-zero: "fit this single year"
/// can only mean "as close as the ladder gets".
double pxPerYearToFit(int fromYear, int toYear, double viewportPx) {
  final span = (toYear - fromYear).abs();
  if (span <= 0 || viewportPx <= 0) return kStripZoomSteps.last;
  return viewportPx / span;
}

/// The nearest ladder step to [want], so the reader's zoom always lands
/// on a value the ruler has a sensible tick step for.
///
/// Distance is measured linearly, not geometrically, even though the
/// ladder itself roughly doubles step to step. "Nearest" is the literal
/// contract and the ladder was chosen for its two ENDS (0.15 fits the
/// axis, 24 separates the post-1900 events), not for even perceptual
/// spacing, so there is no geometric mean here worth preferring over
/// the plain one.
double snapZoom(double want) {
  var best = kStripZoomSteps.first;
  var bestDiff = (want - best).abs();
  for (final step in kStripZoomSteps.skip(1)) {
    final diff = (want - step).abs();
    if (diff < bestDiff) {
      best = step;
      bestDiff = diff;
    }
  }
  return best;
}

// ── the ruler ────────────────────────────────────────────────────────

/// The year step between labelled ticks at [pxPerYear], given that a
/// label needs [labelPx] of room.
///
/// Returns one of 1, 5, 10, 25, 50, 100, 250, 500, 1000 — a "nice"
/// ladder, because a ruler stepping by 137 years is a ruler nobody can
/// read. The smallest step whose spacing clears [labelPx] wins.
int rulerStep(double pxPerYear, {double labelPx = 56}) {
  for (final step in _kNiceSteps) {
    if (step * pxPerYear >= labelPx) return step;
  }
  // Even the coarsest step does not clear labelPx: pxPerYear is smaller
  // than any ladder value would ever produce (kStripZoomSteps bottoms
  // out at 0.15, where 1000 * 0.15 = 150 already clears 56). Returning
  // the coarsest step is the honest best effort rather than a step the
  // ladder promises but cannot reach.
  return _kNiceSteps.last;
}

const List<int> _kNiceSteps = [1, 5, 10, 25, 50, 100, 250, 500, 1000];

/// Every labelled tick year on the axis at [step], ascending.
///
/// Year 0 does not exist in this calendar — 1 BC is followed by AD 1 —
/// so a tick never lands on it and the caller never has to render "0".
List<int> rulerTicks(int step,
    {int minYear = kStripMinYear, int maxYear = kStripMaxYear}) {
  if (step <= 0 || minYear > maxYear) return const [];
  final out = <int>[];
  // The first multiple of `step`, in the ordinary numeric sense, at or
  // after minYear — ticks land on ..., -1000, -500, 500, 1000, ..., not
  // on offsets from minYear, which is what a reader means by "every 500
  // years" on a calendar that did not start counting at -4200.
  var y = (minYear / step).ceil() * step;
  for (; y <= maxYear; y += step) {
    if (y != 0) out.add(y);
  }
  return out;
}

// ── lanes ────────────────────────────────────────────────────────────

/// The height of one lane row, in content pixels.
///
/// A CONSTANT, and that is the point of the whole rebuild: on the wheel
/// this number was `side x 0.17 / laneCount` and fell to 3.01 px on a
/// phone. Here the lanes decide the strip's height instead of the
/// viewport deciding the lanes' thickness.
///
/// 22 clears the 9 px finger target with room for a 12 px label and its
/// leading, and it is scaled by the reader's Font Size setting at the
/// call site, never here.
const double kLaneHeight = 22;

/// The gap between lanes, so two bars in adjacent lanes read as separate.
const double kLaneGap = 2;

/// Greedy first-fit packing of spans into sub-lanes.
///
/// The strip's answer to overlap, and the direct descendant of
/// `packIntoRings`. Unlike that one it may return as many lanes as the
/// overlaps demand, because a lane costs height and height is free here
/// — there is no rim to run out of.
///
/// [starts] and [ends] are content-x, already sorted by start.
/// [minGapPx] is the clear space two spans need before they may share a
/// lane; it is in PIXELS, not years, because what must not touch is ink.
///
/// Returns a lane index per span. Never overprints: the lane count is
/// whatever the data requires.
List<int> packIntoLanes(List<double> starts, List<double> ends,
    {double minGapPx = 4}) {
  // lastEnd[lane] is the x the lane is occupied until. Unlike
  // packIntoRings there is no fixed ringCount to run out of, so a span
  // that cannot join any existing lane simply opens a new one.
  final lastEnd = <double>[];
  final out = <int>[];
  for (var i = 0; i < starts.length; i++) {
    var lane = -1;
    for (var l = 0; l < lastEnd.length; l++) {
      if (starts[i] - lastEnd[l] >= minGapPx) {
        lane = l;
        break;
      }
    }
    if (lane < 0) {
      lane = lastEnd.length;
      lastEnd.add(double.negativeInfinity);
    }
    lastEnd[lane] = ends[i] > starts[i] ? ends[i] : starts[i];
    out.add(lane);
  }
  return out;
}

/// The hit target for a span painted from [x0] to [x1].
///
/// The span keeps the ink its years bought (rule 1) and borrows target
/// from the air either side when it is thinner than a finger — which is
/// exactly what `nearestArcAt` does on the wheel, and for the same
/// reported reason: 「按也很难按到，打也打不开」.
({double x0, double x1}) hitTargetFor(double x0, double x1,
    {double fingerPx = 9}) {
  final width = x1 - x0;
  if (width >= fingerPx) return (x0: x0, x1: x1);
  final centre = (x0 + x1) / 2;
  final half = fingerPx / 2;
  return (x0: centre - half, x1: centre + half);
}

/// Which span a tap at content-x [x] in one lane means, or null.
///
/// Ties go to the nearer centre, normalised against each span's own
/// target — so a reader aiming at a hairline between two long reigns
/// gets the hairline, not whichever long reign was first in the list.
({int index, double score})? nearestSpanAt(
    double x, List<({double x0, double x1})> spans,
    {double fingerPx = 9}) {
  int? best;
  var bestScore = double.infinity;
  for (var i = 0; i < spans.length; i++) {
    final s = spans[i];
    final centre = (s.x0 + s.x1) / 2;
    final own = math.max((s.x1 - s.x0).abs() / 2, fingerPx / 2);
    final score = (x - centre).abs() / own;
    if (score <= 1 && score < bestScore) {
      best = i;
      bestScore = score;
    }
  }
  return best == null ? null : (index: best, score: bestScore);
}

// ── labels in bars ───────────────────────────────────────────────────

/// The painted width of [text] at [size], in content pixels. Passed in
/// so this file stays free of widgets — the same contract as the wheel's
/// `LabelMeasure`, and for the same reason.
typedef LabelMeasure = double Function(String text, double size);

/// The text a bar [roomPx] wide can honestly carry.
///
/// The wheel's rule, unchanged and non-negotiable (#297): **Chinese is
/// whole or nothing** — every ideograph is a morpheme, so 莫斯 is not an
/// abbreviation of 莫斯科, it is a different word. Latin may fall back to
/// whole WORDS with an ellipsis, because *Moscow…* still names something
/// and *Mosc…* does not.
///
/// Returns an empty string when nothing legible fits. Nothing is lost by
/// that here: unlike the wheel, the reader can always widen the bar by
/// zooming x, and the lane's own sheet lists everything on it.
({String text, bool ellipsised}) fitBarLabel({
  required String text,
  required double roomPx,
  required double size,
  required LabelMeasure measure,
}) {
  const nothing = (text: '', ellipsised: false);
  if (text.isEmpty || roomPx <= 0) return nothing;

  final full = measure(text, size);
  if (full <= roomPx) return (text: text, ellipsised: false);

  // #297, restated for bars: a CJK label is whole or absent, never cut
  // mid-word, because every ideograph is its own morpheme.
  if (text.runes.any(isCjkChar)) return nothing;

  final words = text.split(' ').where((w) => w.isNotEmpty).toList();
  for (var take = words.length - 1; take >= 1; take--) {
    final cut = '${words.take(take).join(' ')}…';
    final w = measure(cut, size);
    if (w <= roomPx) return (text: cut, ellipsised: true);
  }
  return nothing;
}

/// Where a bar's label starts, so a label on a bar that runs off both
/// edges of the viewport stays visible.
///
/// A 400-year empire at 6 px/year is 2400 px wide; centring its name in
/// the bar puts the name off-screen for most of the scroll. The name is
/// therefore pinned to whichever part of the bar is actually in view —
/// the standard treatment on a scrolling gantt, and the reason this
/// function needs the viewport when nothing else in this file does.
double barLabelX({
  required double barX0,
  required double barX1,
  required double labelW,
  required double viewX0,
  required double viewX1,
}) {
  final visStart = math.max(barX0, viewX0);
  final visEnd = math.min(barX1, viewX1);
  // maxStart keeps the label from running past the bar's own right
  // edge — it may still overhang [viewX1] if the bar itself does, but
  // it may never claim to name ink that is not there.
  final maxStart = math.max(barX0, barX1 - labelW);
  if (visEnd <= visStart) {
    // Bar and viewport do not overlap at all — cannot happen if the
    // caller only calls this for bars it is about to paint, but the
    // honest answer for an off-screen bar is still a point inside it:
    // the middle of the range the label is allowed to start in.
    return (barX0 + maxStart) / 2;
  }
  return visStart.clamp(barX0, maxStart);
}

// ── events, which are points and not spans ───────────────────────────

/// Group event x-positions into one mark per cluster.
///
/// The strip's descendant of `clusterByAngle`, and it exists for the
/// same reason: 55 years of the corpus carry more than one event. What
/// differs is the remedy. The wheel had to DROP, because its axis is the
/// whole of history and cannot scroll; here a cluster that is too tight
/// at this zoom comes apart at the next one, so the badge is a promise
/// the reader can cash rather than an apology for lost data.
///
/// [xs] must be ascending. A new cluster starts when an x clears the
/// FIRST member of the open one by [minGapPx].
List<({List<int> members, int representative})> clusterByX(
    List<double> xs, double minGapPx,
    {int pinned = -1}) {
  final out = <({List<int> members, int representative})>[];
  var members = <int>[];
  var anchor = double.negativeInfinity;

  void close() {
    if (members.isEmpty) return;
    out.add((
      members: members,
      representative: members.contains(pinned) ? pinned : members.first,
    ));
  }

  for (var i = 0; i < xs.length; i++) {
    if (members.isEmpty || xs[i] - anchor >= minGapPx) {
      close();
      members = [i];
      anchor = xs[i];
    } else {
      members.add(i);
    }
  }
  close();
  return out;
}

/// Where the strip must scroll to put [year] in the middle of a
/// [viewportPx]-wide window, clamped to the content.
///
/// The strip's `focusTranslation`. Zoom is deliberately NOT changed —
/// the reader set it, and a search that silently rescales the chart is a
/// search that loses their place.
double scrollToCentre(int year, double pxPerYear, double viewportPx,
    {int minYear = kStripMinYear, int maxYear = kStripMaxYear}) {
  // Unlike focusTranslation's dx (a canvas translation for
  // InteractiveViewer), this returns a ScrollController-style OFFSET —
  // 0 at the axis start, increasing rightward — because the strip only
  // ever moves in x and that is the primitive a horizontal
  // ScrollController already speaks. The result can be handed straight
  // to `controller.jumpTo` / `animateTo`.
  final contentW =
      stripContentWidth(pxPerYear, minYear: minYear, maxYear: maxYear);
  final maxOffset = math.max(0.0, contentW - viewportPx);
  if (maxOffset == 0) return 0;
  final px = xForYear(year, pxPerYear, minYear: minYear);
  final offset = px - viewportPx / 2;
  return offset.clamp(0.0, maxOffset);
}
