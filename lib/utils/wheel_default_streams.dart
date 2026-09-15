/// Which streams the wheel shows before the reader has chosen.
///
/// 2026-09-15. 「一开始filter不要全部都有 这样loading很慢 一些主要的和圣经
/// 里面有的就行 像中国日本这些可以user后面加进去filter」.
///
/// Capacity follows the band annulus and the viewport. Four streams fit
/// on a 360 dp wheel; the remaining streams stay available in Filter.
/// The chronology explorer also lists their events when the reader
/// searches, so reducing the initial ring count does not discard data.
library;

import 'dart:math' as math;

/// The canonical order. Earlier means kept longer when rings are scarce.
///
/// The ordering is an argument, not a preference:
///
///   1. **The spine first.** This is a Bible study application, so the
///      line the app is about — scripture itself, Israel and Judah, and
///      the church that continues the story — is never the thing that
///      gets dropped.
///   2. **Then the powers scripture names**, roughly in the order the
///      text meets them: Egypt, Assyria, Babylon, Persia, Greece, Rome.
///      A reader who opens a chart in a Bible app is looking for the
///      empires of Daniel 2 before anything else.
///   3. **Then the rest of the biblical world** — the neighbours and the
///      successors.
///   4. **Then the world beyond it.** China, India, Japan and the
///      Americas are last NOT because they matter less, but because they
///      touch this book's narrative last, and because the owner named
///      exactly these as the ones a reader should add for themselves.
const List<String> kStreamPriority = <String>[
  'scripture',
  'israel',
  'judah',
  'church',
  'egypt',
  'assyria',
  'babylon',
  'persia',
  'greece',
  'rome',
  'byzantium',
  'anatolia',
  'phoenicia',
  'philistia',
  'arabia',
  'islam',
  'europe',
  'world',
  'china',
  'india',
  'japan',
  'americas',
];

/// The most rings a reader may show at once, on ANY canvas.
///
/// 2026-09-15. 「filter in的时候我建议一次别超过3~5个 因为那么多在一起
/// 都没有用其实」 — and 「一次不要load太多」.
///
/// Five is the ceiling and [kOpeningStreams] is what the wheel opens
/// with. The gap between them is the whole point, and it is an argument
/// rather than a rounding of the owner's range:
///
///   • The opening four are the SPINE — scripture, Israel, Judah, the
///     church. That is the line this application exists to follow, and
///     it is never the thing a reader has to go and switch on.
///   • The fifth slot is THE COMPARISON the reader came to make: what
///     Egypt was doing then, where Babylon falls against the kings. A
///     chart with no free slot is a fixed poster. A chart with six or
///     more asks the reader to tell one muted hue from another around a
///     circle, which is the failure the owner described.
///
/// What this caps is what gets DRAWN, never what exists. All 22 streams
/// and all 1,039 records stay reachable through Find and through the
/// event list beside the chart, so a ring that is off is a quieter
/// chart and not a smaller dataset. That distinction is the reason the
/// cap is defensible at all.
///
/// The strip chart does not share this ceiling. Its lanes stack
/// vertically and each carries its own printed name, so a reader there
/// is reading labels rather than matching hues, and twelve lanes are
/// legible in a way twelve rings are not.
const int kMaxVisibleStreams = 5;

/// How many rings the wheel opens with, leaving exactly one slot free.
const int kOpeningStreams = 4;

/// How many rings a wheel of this size can hold and still be read.
///
/// [side] is the shorter edge of the square the wheel is drawn in.
/// [hubFraction] and [bandsFraction] are the page's own radii, passed in
/// rather than duplicated, so this cannot drift from the layout.
///
/// The geometry and the ceiling each set a bound. A 360 dp canvas has
/// 55.8 px between its hub and bands: four shares of 13.95 px, each
/// painting 80% of its share. Eleven painted pixels and two pixels of
/// separation express that budget without pretending it is a 24 px
/// touch target. Full-size event rows provide the alternative on phones.
///
/// 2026-09-15: the device arm used to READ 4 / 8 / 12 — more room, more
/// rings. That is now gone, and its absence is the point. Room was
/// never the binding constraint: at 1400 px even twenty-two rings clear
/// this app's 9 px finger target, and the chart was still unreadable,
/// because the limit on a ring chart is how many muted hues a reader
/// can tell apart around a circle, and that number does not grow with
/// the window. A desktop and a phone therefore get the same ceiling and
/// the desktop simply draws its five rings thicker.
int ringCapacity(
  double side, {
  required double hubFraction,
  required double bandsFraction,
  double minThickness = 11,
  double gap = 2,
}) {
  final annulus = side * (bandsFraction - hubFraction);
  final byGeometry =
      annulus <= 0 ? 1 : (annulus / (minThickness + gap)).floor();
  return byGeometry.clamp(1, kMaxVisibleStreams);
}

/// Band radii as fractions of the SQUARE SIDE, not of the radius.
///
/// The previous phone bands used 0.44 and added a 0.16 outer annulus:
/// a 360 px square therefore painted its rim at radius 216, 36 px past
/// the edge. Keeping the lifespan annulus intact and reclaiming band
/// space fixes the fit while preserving every independent arc layer.
/// The axis reservation below also includes its text and hairlines.
double bandsFractionFor(double side, {double hubFraction = 0.115}) {
  if (side < 600) return kBandsFracNarrow;
  if (side < 1024) return kBandsFracMedium;
  return kBandsFracWide;
}

/// 2026-09-15: each of these came down by 0.04, and the rim with them.
///
/// The disc was too big for its own frame. At the old 0.445 rim against
/// a 0.5 clip there were `side x 0.055` units outside the circle, which
/// is not enough to stand a year label up in — so the year labels were
/// bent around the ring instead, and a reader had to tilt their head to
/// read half the scale. The words were the symptom; the margin was the
/// defect.
///
/// The disc gives up about a seventh of its radius and gets a real
/// margin. Nothing in it gets thinner in practice, because the same
/// change capped the ring count at five: four rings in the reduced
/// annulus are still far thicker than twelve were in the full one.
const double kBandsFracNarrow = 0.27;
const double kBandsFracMedium = 0.26;
const double kBandsFracWide = 0.27;

/// Shared space for events, lifespans, reigns, ministries and genealogy.
///
/// Held at 0.16 while the bands came down. Taking the margin for the
/// year scale out of THIS was tried first and measured wrong: the
/// twenty-five Genesis lifespans pack into sub-rings of this annulus,
/// and at 0.14 their pitch fell to 5.81 px against the 6.6 px floor
/// `wheel_lifespans_test.dart` holds them to, with the ministries at
/// 8.45 against 9.0. The margin comes out of the BANDS, which is where
/// the room actually was once the ring count was capped at five.
const double kRimAnnulus = 0.16;

/// How much room outside the rim the year scale needs, in logical px.
///
/// Measured, and the first measurement was wrong in an instructive way.
/// `axialLabelRadius` already pushes the label's CENTRE out far enough
/// for its near edge to clear the rim, so the label then extends
/// another half-width beyond that centre: the room a horizontal label
/// needs is `clearance + full width`, not `clearance + half`. Reserving
/// the half put `2500 BC` 8.7 px outside a 300 px canvas.
///
/// 56 = a 9 px clearance (`kAxisLabelClearance`) plus the widest label
/// the axis prints, which is about 46 px for `2500 BC` at the axis size
/// in the bundled faces.
///
/// This is a CAP on the rim, not a floor under the margin: on a canvas
/// too small to honour it the rim falls back to `bands + 0.02` and the
/// bounds check in `retainSeparatedWheelAxisLabels` drops the labels
/// that still cannot fit. The ticks stay, and the cursor still reads
/// any year — the reader loses a number they can get another way, not
/// a mark.
const double kAxisTextRoomPx = 56;

double rimFractionFor(double side) {
  if (side <= 0) return 0;
  final bands = bandsFractionFor(side);
  final axisRoom = 0.5 - kAxisTextRoomPx / side;
  return math.max(bands + 0.02, math.min(bands + kRimAnnulus, axisRoom));
}

/// The streams to show when the reader has not chosen, given the room.
///
/// Returns ids in [kStreamPriority] order, capped at what fits. Anything
/// in [available] that the priority list does not name is appended after
/// the named ones — a stream added to the data later must not silently
/// become invisible because this file was not updated.
List<String> defaultVisibleStreams(Iterable<String> available, int capacity) {
  final have = available.toSet();
  final ordered = <String>[
    for (final id in kStreamPriority)
      if (have.remove(id)) id,
    ...have,
  ];
  if (ordered.isEmpty) return const [];
  return ordered.take(capacity.clamp(1, ordered.length)).toList();
}
