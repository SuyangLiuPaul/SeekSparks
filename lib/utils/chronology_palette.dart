/// The chronology's colours, and the ground they assume.
///
/// 2026-09-15. 「可以跟着变吧 dark ligjt mode」 — the wheel and the strip
/// now take their hues from the same palette the rest of the app is
/// themed with, instead of one fixed set painted on whatever happens to
/// be behind it.
///
/// This file exists because the old version did not. The hue arcs and
/// the lightness zigzag lived inside `radial_chronology_page.dart` as
/// private functions, which is how they came to be brightness-blind: a
/// band was `HSLColor(..., 0.47 ± 0.10)` whether it sat on cream or on
/// #0B1320, and on the night ground the darker half of every pair fell
/// to roughly 2:1 against it. Moving the decision into `utils/` is the
/// same rule the rest of this project follows — the page and the test
/// call ONE function, so a test cannot pass over a copy of the
/// algorithm while the shipped painter uses another.
///
/// What did NOT change: the hue arcs, the family assignment, and the
/// zigzag that separates neighbours. Those were each learned from a
/// test failing rather than by eye, and they are reproduced verbatim
/// below with their reasoning. The ONLY new input is the ground.
library;

import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// The arc of the colour wheel each Genesis 10 family occupies.
///
/// (start hue, end hue) in degrees. A family's bands spread across its
/// own arc, so no two bands share a colour, while the arcs stay far
/// enough apart that a family still reads as one.
///
/// The first attempt kept every family inside a narrow swing around a
/// single hue. That was faithful to the idea and useless in practice:
/// ten Japhethite bands came out as ten near-identical blues and a
/// reader could not tell Rome from Japan. The bands are ALREADY
/// contiguous by family on the wheel — Israel through the Islamic
/// world sit together, Persia through India sit together — so
/// adjacency is already saying "these belong together", which frees
/// hue to spend itself on telling them apart. Japheth gets the widest
/// arc because it carries ten of the twenty-two.
///
/// Kept literal: a reader learns what a colour means, and that must
/// hold whatever accent the app is themed with — and, since 2026-09-15,
/// whichever ground it is painted on. Hue is the channel that carries
/// the MEANING here, so hue is the channel the ground may not move.
const Map<String, (double, double)> kLineHueArcs = {
  'shem': (10, 64), // red through amber to olive
  'ham': (88, 150), // yellow-green through green
  'japheth': (178, 300), // teal, cyan, blue, indigo, violet
  'institution': (312, 342), // magenta through rose
  'none': (0, 0), // grey: belongs to no descent
};

/// The RELATIVE LUMINANCE a band is aimed at, per ground.
///
/// Luminance, not HSL lightness, and that swap is the whole fix.
///
/// The old palette set `HSLColor` lightness to 0.47 ± 0.10 and stopped
/// there. HSL lightness is not perceptual: at lightness 0.54 a yellow
/// band carries roughly four times the luminance of a blue one, so the
/// palette was never actually level. Measured on the shipped build,
/// that produced BOTH failures at once — Babylon at 2.09:1 against the
/// near-white pane (a band you have to hunt for), and the darker half
/// of every pair near 2:1 against the #0B1320 night ground.
///
/// Aiming at luminance instead fixes both, and it makes the zigzag
/// below mean something it never meant before: two neighbouring bands
/// now differ by a step a reader can actually see, rather than by a
/// number that happens to differ in a colour space.
///
/// The figures, worked against the two grounds:
///
///   • ON PAPER the pane is near-white (luminance ~1.0). 0.135 and
///     0.285 give 5.7:1 and 3.1:1 — both past the 3:1 floor this
///     project uses for marks that must be findable.
///   • AT NIGHT the pane is #0B1320 (luminance ~0.008). 0.195 and
///     0.345 give 4.2:1 and 6.8:1.
///
/// Night sits higher than paper on purpose: a band on a night ground is
/// a light mark on dark, the same way the app's text is. It is not the
/// paper ink with the canvas swapped underneath it, which is precisely
/// what the old palette was.
const double kBandLuminanceOnPaper = 0.21;
const double kBandLuminanceOnNight = 0.27;

/// How far a band steps either side of its centre, in luminance.
///
/// The separation rule, unchanged in intent and finally honest in
/// execution: two adjacent bands differ in hue AND in weight, never in
/// one channel only. Six Semitic bands inside a 34 degree swing left
/// Arabia and the Islamic world 35 apart in hue, which reads as the
/// same colour; this step is what fixes that.
const double kBandLuminanceStep = 0.075;

/// The same hue and saturation, re-seated to hit [target] luminance.
///
/// Luminance rises monotonically with HSL lightness — black at 0, white
/// at 1 — so a bisection always converges and every target in (0, 1) is
/// reachable for every hue. Twelve rounds put it inside 1/4096, which
/// is well under one step of an 8-bit channel.
Color _atLuminance(HSLColor base, double target) {
  var lo = 0.0, hi = 1.0;
  for (var i = 0; i < 12; i++) {
    final mid = (lo + hi) / 2;
    if (base.withLightness(mid).toColor().computeLuminance() < target) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return base.withLightness((lo + hi) / 2).toColor();
}

/// Grey, for what belongs to no descent — and for the genealogy rail,
/// whose placement is conventional rather than a claim.
///
/// Lifted at night for the same reason the bands are: #828282 is 2.4:1
/// on #0B1320, which is a mark a reader has to hunt for.
Color noDescentColor({required bool dark}) =>
    dark ? const Color(0xFFA2AAB4) : const Color(0xFF828282);

/// A colour for ONE band: its family's arc, at position [t] (0..1),
/// with [index] deciding which way its lightness steps, on the ground
/// named by [dark].
///
/// Three things had to be true at once, and each was learned by a test
/// failing rather than by eye:
///
///  * NEIGHBOURS MUST DIFFER. Hue alone was not enough, so lightness
///    zigzags with the index — see [kBandLightnessStep].
///  * NOTHING MAY GO NEAR BLACK OR WHITE. A smooth lightness ramp
///    across a ten-band family drove its ends to #612218 and #E69DE6 —
///    separable, and unreadable on the page.
///  * FAMILIES MUST NOT TOUCH. Ham's arc ended at 165° where Japheth's
///    began, so Philistia and Persia came out the SAME colour; the test
///    measured 0.0 between them. The arcs now leave a gap.
///
/// And, since 2026-09-15, a fourth: A BAND MUST CARRY ON ITS GROUND.
/// That one is [dark]'s whole job, and it is a required argument rather
/// than a defaulted one on purpose — a call site that has not thought
/// about the ground should not compile, because the failure it causes
/// is invisible in the light mode every developer works in.
Color bandColor(String line, double t, int index, {required bool dark}) {
  final arc = kLineHueArcs[line];
  if (arc == null || line == 'none') return noDescentColor(dark: dark);
  final (h0, h1) = arc;
  final centre = dark ? kBandLuminanceOnNight : kBandLuminanceOnPaper;
  final base = HSLColor.fromAHSL(
    1,
    (h0 + (h1 - h0) * t) % 360,
    // Saturation peaks mid-arc so the ends do not turn to mud. Pulled
    // back at night because the same saturation carried to a higher
    // luminance reads as neon on a near-black ground, and four neon
    // rings is a complaint this chart has already collected once.
    ((dark ? 0.50 : 0.62) + 0.12 * math.sin(math.pi * t)).clamp(0.0, 1.0),
    0.5,
  );
  return _atLuminance(
      base,
      (centre + (index.isEven ? -kBandLuminanceStep : kBandLuminanceStep))
          .clamp(0.02, 0.98));
}

/// The family's own colour, for the legend — the middle of its arc.
Color familyColor(String line, {required bool dark}) =>
    bandColor(line, 0.5, 0, dark: dark);

/// The colour of one band, given its position among its own family.
Color streamBandColor(String line, int index, int count,
        {required bool dark}) =>
    bandColor(line, count <= 1 ? 0.5 : index / (count - 1), index, dark: dark);
