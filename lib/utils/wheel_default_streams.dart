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

/// How many rings a wheel of this size can hold and still be read.
///
/// [side] is the shorter edge of the square the wheel is drawn in.
/// [hubFraction] and [bandsFraction] are the page's own radii, passed in
/// rather than duplicated, so this cannot drift from the layout.
///
/// The geometry and the device each set a ceiling. A 360 dp canvas has
/// 55.8 px between its hub and bands: four shares of 13.95 px, each
/// painting 80% of its share. Eleven painted pixels and two pixels of
/// separation express that budget without pretending it is a 24 px
/// touch target. Full-size event rows provide the alternative on phones.
/// The device ceiling prevents a large canvas becoming a wall of hues.
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
  final byDevice = side < 600
      ? 4
      : side < 1024
          ? 8
          : 12;
  return byGeometry.clamp(1, byDevice);
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

const double kBandsFracNarrow = 0.27;
const double kBandsFracMedium = 0.28;
const double kBandsFracWide = 0.30;

/// Shared space for events, lifespans, reigns, ministries and genealogy.
/// The full 0.16 annulus is preserved on tablet and desktop. A phone
/// trades some of it for the fixed-size axis text outside the rim.
const double kRimAnnulus = 0.16;

double rimFractionFor(double side) {
  if (side <= 0) return 0;
  final bands = bandsFractionFor(side);
  // The old fit test stopped at the circle. At least 32 px outside it
  // now belongs to axis text, checked in the bundled Latin/CJK faces.
  final axisRoom = 0.5 - 32 / side;
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
