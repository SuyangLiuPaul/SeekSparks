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
/// is violently front-loaded — 140 of 747 events fall in the 2% of the
/// axis after 1900, and 271 fall in the last 390 years. A *uniform*
/// strip at 2 px/year on a 900 px screen still has **298 events in its
/// densest window**, needing about 30 rows to name them all. The strip's
/// win is not that crowding disappears; it is that crowding becomes
/// scrollable and x-zoomable, which the wheel structurally forbids.
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

/// x, in content pixels from the strip's left edge, for [year].
///
/// Linear and uniform, deliberately. A log or era-compressed axis would
/// fix the density in one move and would make width stop meaning
/// duration — see rule 1. If the axis is ever compressed, the
/// compression must be DRAWN (a visible fold or break), not silent.
double xForYear(int year, double pxPerYear, {int minYear = kStripMinYear}) =>
    throw UnimplementedError();

/// The year at content-x [x]. The inverse of [xForYear], and the thing a
/// tap on the ruler means.
double yearForX(double x, double pxPerYear, {int minYear = kStripMinYear}) =>
    throw UnimplementedError();

/// The whole strip's content width at [pxPerYear].
double stripContentWidth(double pxPerYear,
        {int minYear = kStripMinYear, int maxYear = kStripMaxYear}) =>
    throw UnimplementedError();

/// The px a span of [start]..[end] occupies. May be 0 — see rule 1.
double spanWidth(int start, int end, double pxPerYear) =>
    throw UnimplementedError();

/// The pxPerYear at which [year] range fits [viewportPx], for "fit all"
/// and for search's "show me this century".
double pxPerYearToFit(int fromYear, int toYear, double viewportPx) =>
    throw UnimplementedError();

/// The nearest ladder step to [want], so the reader's zoom always lands
/// on a value the ruler has a sensible tick step for.
double snapZoom(double want) => throw UnimplementedError();

// ── the ruler ────────────────────────────────────────────────────────

/// The year step between labelled ticks at [pxPerYear], given that a
/// label needs [labelPx] of room.
///
/// Returns one of 1, 5, 10, 25, 50, 100, 250, 500, 1000 — a "nice"
/// ladder, because a ruler stepping by 137 years is a ruler nobody can
/// read. The smallest step whose spacing clears [labelPx] wins.
int rulerStep(double pxPerYear, {double labelPx = 56}) =>
    throw UnimplementedError();

/// Every labelled tick year on the axis at [step], ascending.
///
/// Year 0 does not exist in this calendar — 1 BC is followed by AD 1 —
/// so a tick never lands on it and the caller never has to render "0".
List<int> rulerTicks(int step,
        {int minYear = kStripMinYear, int maxYear = kStripMaxYear}) =>
    throw UnimplementedError();

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
        {double minGapPx = 4}) =>
    throw UnimplementedError();

/// The hit target for a span painted from [x0] to [x1].
///
/// The span keeps the ink its years bought (rule 1) and borrows target
/// from the air either side when it is thinner than a finger — which is
/// exactly what `nearestArcAt` does on the wheel, and for the same
/// reported reason: 「按也很难按到，打也打不开」.
({double x0, double x1}) hitTargetFor(double x0, double x1,
        {double fingerPx = 9}) =>
    throw UnimplementedError();

/// Which span a tap at content-x [x] in one lane means, or null.
///
/// Ties go to the nearer centre, normalised against each span's own
/// target — so a reader aiming at a hairline between two long reigns
/// gets the hairline, not whichever long reign was first in the list.
({int index, double score})? nearestSpanAt(
        double x, List<({double x0, double x1})> spans,
        {double fingerPx = 9}) =>
    throw UnimplementedError();

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
}) =>
    throw UnimplementedError();

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
}) =>
    throw UnimplementedError();

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
        {int pinned = -1}) =>
    throw UnimplementedError();

/// Where the strip must scroll to put [year] in the middle of a
/// [viewportPx]-wide window, clamped to the content.
///
/// The strip's `focusTranslation`. Zoom is deliberately NOT changed —
/// the reader set it, and a search that silently rescales the chart is a
/// search that loses their place.
double scrollToCentre(int year, double pxPerYear, double viewportPx,
        {int minYear = kStripMinYear, int maxYear = kStripMaxYear}) =>
    throw UnimplementedError();
