/// Which streams the wheel shows before the reader has chosen.
///
/// 2026-09-15. 「一开始filter不要全部都有 这样loading很慢 一些主要的和圣经
/// 里面有的就行 像中国日本这些可以user后面加进去filter」.
///
/// THE GEOMETRY SAYS THE SAME THING. A ring has to be thick enough to
/// tap — WCAG 2.5.8 puts the minimum target at 24 px — so the number of
/// rings a wheel can hold is not a taste question, it is
///
///     rings = (radius − hub − axis) / (thickness + gap)
///
/// On a 360 dp phone that is about four. On a tablet, eleven. On a
/// desktop pane, sixteen. Twenty-two rings is not a phone layout in any
/// arrangement, and drawing them anyway is what makes the chart both
/// slow and unreadable at once.
///
/// The colour literature lands on the same ceiling from the other side:
/// a categorical palette holds six to eight hues before a reader stops
/// being able to tell one from another (Atlassian's guidance, and
/// Datawrapper's "no more than 6, 12 at the very most").
///
/// So the default is a COUNT derived from the viewport, and this file is
/// the order in which streams claim the rings that exist.
library;

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
/// TWO CEILINGS, and the lower one wins.
///
/// **Geometry.** A band has to be thick enough to read, and the annulus
/// is what there is. 14 px is the floor used here rather than WCAG's
/// 24 px target minimum, because the binding dimension of a TAP on an
/// arc is its angular length, which is hundreds of pixels — a 14 px band
/// spanning a third of a circle is not a small target, it is a long thin
/// one.
///
/// **The device.** Four rings on a phone, eight on a tablet, twelve on a
/// desktop pane. This is the published guidance for exactly this chart:
/// a categorical palette stops being discriminable past six to eight
/// hues, and the controlled studies of radial timelines on phones put
/// the usable ring count far below what the pixels would allow. Past
/// twelve the wheel is a texture, not a chart.
int ringCapacity(
  double side, {
  required double hubFraction,
  required double bandsFraction,
  double minThickness = 14,
  double gap = 2,
}) {
  final annulus = side * (bandsFraction - hubFraction);
  final byGeometry = annulus <= 0
      ? 1
      : (annulus / (minThickness + gap)).floor();
  final byDevice = side < 600
      ? 4
      : side < 1024
          ? 8
          : 12;
  return byGeometry.clamp(1, byDevice);
}

/// The share of the wheel's radius the BANDS get.
///
/// 2026-09-15, and this is the heart of what was wrong. The wheel gave
/// its bands the ring from 11.5% to 28.5% of the radius — seventeen per
/// cent — and handed the whole outer two thirds to event titles. With
/// twenty-two streams in that annulus each band was under three pixels
/// thick on a phone: the data was a hairline and the annotation had the
/// chart.
///
/// The bands are the data. On a narrow viewport they take most of the
/// radius and the event annulus shrinks to a margin; on a wide one there
/// is room for both and the original proportion is close to right.
double bandsFractionFor(double side, {double hubFraction = 0.115}) {
  if (side < 600) return kBandsFracNarrow;
  if (side < 1024) return kBandsFracMedium;
  return kBandsFracWide;
}

/// Named so the page and the layout tests can reach the same figures.
const double kBandsFracNarrow = 0.44;
const double kBandsFracMedium = 0.36;
const double kBandsFracWide = 0.30;

/// The annulus between the bands and the rim, where the Genesis
/// lifespans are drawn. A fixed share of the side, so widening the
/// bands moves this ring OUTWARD rather than squeezing it — the room
/// comes from the event-label field beyond the rim, which had 55% of
/// the radius while the data had 17%.
const double kRimAnnulus = 0.16;

/// The rim radius, as a fraction of the side.
double rimFractionFor(double side) => bandsFractionFor(side) + kRimAnnulus;

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
  return ordered.take(capacity.clamp(1, ordered.length)).toList();
}
