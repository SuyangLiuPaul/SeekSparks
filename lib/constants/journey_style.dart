/// 2026-08-17 (SeekSparks): how a journey is drawn, and what each part of
/// the drawing claims.
///
/// **The visual grammar, and the one deliberate departure from the
/// brief.** There are two orthogonal facts to encode — which route a line
/// belongs to, and what the text says about that leg — and only so many
/// channels to encode them in. The dash pattern was spent on the TEXT:
///
///   * solid       — the travellers went by land, and the text says so
///   * long dash   — they sailed, and the text says so (`ἀπέπλευσαν`)
///   * short dash  — the text names the arrival but not a way that can be
///                   drawn
///   * fine dots   — provisional: the text does not put them here at all
///
/// **2026-08-24: the short dash covers two cases, not one.** It began as
/// "the text refuses the manner" — Acts 20:1, which sends Paul to
/// Macedonia and will not say how. Mark's itinerary brought the second:
/// the manner is plain (they walked) but the text routes them through a
/// place this gazetteer cannot put on a map — the wilderness of Mark
/// 1:12, the country of the Gerasenes, the Decapolis. Both cases make the
/// same claim to the reader, which is why they share a dash: THIS LINE IS
/// NOT UNDERWRITTEN AS A DIRECT JOURNEY. Drawing Nazareth→Capernaum solid
/// because the verbs are verbs of walking would erase the baptism and the
/// forty days that Mark puts between them.
///
/// A fifth case has no dash because it has no line: a place the narrative
/// names beside the track — Phoenix, aimed at and missed; Syrtis, feared
/// and avoided — is a hollow marker joined to nothing. See
/// [JourneyStopKind.aside]. It is drawn hollow rather than merely faint
/// for the reason a provisional leg is dotted rather than merely pale: a
/// solid mark reads as an assertion at a glance, and no amount of
/// lightening takes that back.
///
/// Route identity is carried instead by colour AND by the numbered
/// markers at each stop, which are the reason this is not a colour-only
/// scheme: a reader who cannot tell amber from teal can still read `1`
/// and `8,10`, and the numbers say something the dash never could, which
/// is the ORDER — the whole point of an itinerary. The brief asked for
/// colour plus dash so that a colour-blind reader could separate two
/// overlapping routes; the numbers meet that requirement, and they leave
/// the dash free to say whether Paphos→Perga was a voyage. Spending the
/// only non-colour channel on decoration while the text's own
/// distinction went undrawn would have been the wrong trade.
///
/// A provisional leg is drawn thin, faint AND dotted — never merely
/// faint. A thin pale solid line still reads as an assertion at a glance,
/// and the whole discipline here is that the drawing must not claim more
/// than the verse behind it.
library;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/bible_journey.dart';

/// The ink and the marker for one route.
class JourneyStyle {
  const JourneyStyle({
    required this.colour,
    required this.onColour,
    this.mark = JourneyMark.round,
  });

  final Color colour;

  /// What to print ON [colour] — the marker numerals. Fixed per swatch
  /// rather than derived per frame, because these are chosen together.
  final Color onColour;

  final JourneyMark mark;

  JourneyStyle withMark(JourneyMark m) =>
      JourneyStyle(colour: colour, onColour: onColour, mark: m);
}

/// Draw one stop marker of [mark] at [centre], sized so that every
/// silhouette carries the same ink.
///
/// **Equal area, not equal radius.** A square drawn across the circle's
/// diameter has 4/π ≈ 1.27 times its area and reads as a heavier, more
/// important stop; a diamond inscribed in the same box has half of it
/// and reads as a fainter one. Weight is not a channel this scheme is
/// spending, so the two polygons are scaled to the circle's area and the
/// shapes differ in outline alone — which is the whole point of a second
/// channel that must not compete with the first.
void paintJourneyMark(
  Canvas canvas,
  Offset centre,
  double radius,
  Paint paint,
  JourneyMark mark,
) {
  switch (mark) {
    case JourneyMark.round:
      canvas.drawCircle(centre, radius, paint);
    case JourneyMark.square:
      // side² = πr²
      final half = radius * 0.8862269254527580;
      canvas.drawRect(Rect.fromCenter(
          center: centre, width: half * 2, height: half * 2), paint);
    case JourneyMark.diamond:
      // 2d² = πr², d the half-diagonal
      final d = radius * 1.2533141373155003;
      canvas.drawPath(
        Path()
          ..moveTo(centre.dx, centre.dy - d)
          ..lineTo(centre.dx + d, centre.dy)
          ..lineTo(centre.dx, centre.dy + d)
          ..lineTo(centre.dx - d, centre.dy)
          ..close(),
        paint,
      );
  }
}

/// The legend's swatch: a bar of the route's ink with the route's own
/// marker sitting on it.
///
/// It draws the mark because the mark is half the identity. Two routes
/// sharing a hue — which is now allowed, and is why [JourneyMark] exists
/// — would otherwise be two identical bars in the list, and a reader
/// looking for the amber diamond on the map would have nothing in the
/// legend to match it against.
class JourneySwatch extends StatelessWidget {
  const JourneySwatch({super.key, required this.style, required this.lit});

  final JourneyStyle style;

  /// False where the route is switched off: the bar goes to [dimTo] but
  /// the SILHOUETTE stays, because the shape is what a reader is
  /// scanning the list for.
  final bool lit;

  static const Size _size = Size(18, 9);

  @override
  Widget build(BuildContext context) {
    final c = WbColors.of(context);
    // A childless CustomPaint lays out at zero, so the size is given.
    return CustomPaint(
      size: _size,
      painter: _SwatchPainter(style, lit ? style.colour : c.border),
    );
  }
}

class _SwatchPainter extends CustomPainter {
  const _SwatchPainter(this.style, this.ink);

  final JourneyStyle style;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    canvas.drawRect(
      Rect.fromLTWH(0, y - 1.5, size.width, 3),
      Paint()..color = ink,
    );
    paintJourneyMark(
        canvas, Offset(size.width / 2, y), 3.4, Paint()..color = ink, style.mark);
  }

  @override
  bool shouldRepaint(_SwatchPainter old) =>
      old.ink != ink || old.style.mark != style.mark;
}

/// Hues that survive both palettes and stay apart under the common forms
/// of colour blindness — a warm orange against a cold blue, which
/// deuteranopia and protanopia both preserve, unlike the red/green pair
/// that is the usual first guess.
///
/// **The fourth slot is a green, which looks like exactly the mistake the
/// paragraph above warns against, and is not.** The pair that collapses
/// for a deuteranope is a *pure* red against a *pure* green at similar
/// lightness. Okabe and Ito's set, built for this, carries orange and a
/// bluish green together for that reason: the green is pulled far towards
/// cyan and the orange far towards yellow, so the two separate on the
/// blue–yellow axis that red-green blindness leaves intact. It was
/// wanted here because Acts holds FOUR Pauline itineraries and three
/// hues would have wrapped the palette, drawing the voyage to Rome in the
/// first journey's amber.
///
/// **2026-08-24: the sixth route arrived, and it took the channel rather
/// than a hue.** Mark's itinerary reuses slot 0's amber and is separated
/// from Paul's first journey by [JourneyMark.diamond]. See
/// [journeyStyleFor], which now takes both.
///
/// **The fifth slot is where the palette reaches its honest limit.** Four
/// hues can be held apart under deuteranopia and protanopia; five cannot,
/// and pretending otherwise would be the colour-only scheme this file
/// exists to avoid. It is a strong blue because blue is the one axis both
/// forms of red-green blindness leave intact, and its nearest neighbour
/// is slot 2's teal — the two are separated by saturation and by hue
/// within that surviving axis, which is a thinner margin than any other
/// pair here. That margin is acceptable only because colour was never
/// carrying the identity on its own: every stop is numbered, and every
/// route is switched on by a NAMED check-box, so a reader who cannot
/// separate the two blues has two other channels that say which is which.
/// A sixth route should add a channel, not a sixth hue.
///
/// Darkened for the light palette and lightened for the dark one, because
/// a single hue legible on #FFFFFF is invisible on #101A2B.
List<JourneyStyle> journeyPalette(WbColors c) => c.isDark
    ? const <JourneyStyle>[
        JourneyStyle(colour: Color(0xFFE8913C), onColour: Color(0xFF1A1206)),
        JourneyStyle(colour: Color(0xFF5FB8DE), onColour: Color(0xFF06161C)),
        JourneyStyle(colour: Color(0xFFB99BE0), onColour: Color(0xFF150C1F)),
        JourneyStyle(colour: Color(0xFF44C79C), onColour: Color(0xFF04170F)),
        JourneyStyle(colour: Color(0xFF7FA3E8), onColour: Color(0xFF061024)),
      ]
    : const <JourneyStyle>[
        JourneyStyle(colour: Color(0xFFB35309), onColour: Color(0xFFFFFFFF)),
        JourneyStyle(colour: Color(0xFF0A6A8A), onColour: Color(0xFFFFFFFF)),
        JourneyStyle(colour: Color(0xFF5B3E96), onColour: Color(0xFFFFFFFF)),
        JourneyStyle(colour: Color(0xFF0A6E4E), onColour: Color(0xFFFFFFFF)),
        JourneyStyle(colour: Color(0xFF1D4E9C), onColour: Color(0xFFFFFFFF)),
      ];

/// The swatch and silhouette for a route.
///
/// [style] still wraps if a file ever ships more journeys than the
/// palette has hues, because the alternative is a crash or an invisible
/// route. But wrapping is no longer the only defence: [mark] is an
/// independent channel, so a repeated hue is a repeated APPEARANCE only
/// when the shape repeats too — which is what
/// `journey_asset_test.dart` fails the build over.
JourneyStyle journeyStyleFor(WbColors c, int style,
    [JourneyMark mark = JourneyMark.round]) {
  final p = journeyPalette(c);
  return p[style.abs() % p.length].withMark(mark);
}

/// The dash pattern for a leg, in `[on, off]` pixels. Empty means solid.
///
/// [attested] false overrides the leg entirely: what the text will not
/// support is drawn as dots whatever the manner of travel would have
/// been, because the manner is not the claim in question.
List<double> journeyDash(JourneyLeg leg, {required bool attested}) {
  if (!attested) return const <double>[1.5, 4];
  return switch (leg) {
    JourneyLeg.sea => const <double>[11, 6],
    JourneyLeg.unknown => const <double>[3.5, 4.5],
    _ => const <double>[],
  };
}

/// Stroke width for a leg. Provisional legs are thinner as well as
/// dotted — two signals, because either alone is easy to miss on a busy
/// coastline.
double journeyStrokeWidth({required bool attested, required bool selected}) {
  if (!attested) return selected ? 1.8 : 1.4;
  return selected ? 3.0 : 2.2;
}

/// Opacity for a leg. A route that is on but not the one being read is
/// held back so the selected itinerary can be followed across a crossing.
double journeyOpacity({required bool attested, required bool dimmed}) {
  final base = attested ? 1.0 : 0.55;
  return dimmed ? base * 0.45 : base;
}
