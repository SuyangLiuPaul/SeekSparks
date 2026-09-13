/// The wall itself: one verse, very large, with the reference in a
/// corner and nothing else.
///
/// Split out of `projection_page.dart` because the page is the operator
/// — cursor, keys, controls, the second edition's corpus — and this is
/// the congregation. The two have different audiences and almost no
/// shared state, and keeping them apart is what lets a test assert what
/// the room can see without driving a keyboard.
///
/// ## THE CHOSEN SIZE IS A CEILING
///
/// [typeSize] is what the operator asked for, and the passage is drawn
/// at that size whenever it fits. When it does not, `BoxFit.scaleDown`
/// shrinks the whole block rather than letting it run off the wall or
/// clip — a clipped verse is not an ugly verse, it is a different verse,
/// and the congregation has no way to know which. The fit's child is
/// pinned to the full usable WIDTH, so the horizontal scale factor is
/// always exactly 1 and the only thing `scaleDown` can respond to is a
/// block too tall for the room. Without that pin a `FittedBox` gives its
/// child unbounded width and the verse lays out as a single line.
///
/// ## WHY THE SECOND EDITION IS STACKED, NOT COLUMNED
///
/// The Browse window puts editions side by side because a desk is wider
/// than it is tall and the reader is comparing words. A projector is
/// 16:9 and the congregation is reading sentences, so two half-width
/// columns would halve the line length and roughly double the number of
/// lines — the same words, in a narrower measure, smaller. Stacked, both
/// editions keep the full width.
///
/// The second block is set slightly smaller ([kProjectionSecondScale]).
/// Not because it matters less, but because something has to lead: two
/// blocks of identical type with a gap between them read as one
/// paragraph that has been interrupted, and the room needs to know at a
/// glance which one is the sermon's text.
///
/// ## THE GROUND IS CHOSEN, AND BLANKING GOES TO THE SAME GROUND
///
/// 2026-09-09. This used to paint one fixed colour, `WbColors.dark`'s
/// `groundBg`, and the blank state painted the same one — which is why
/// the blank key was honest. The operator can now choose
/// ([ProjectionGround]), and the honesty is now a property that has to
/// be maintained rather than one that falls out of there being no
/// choice: [blank] paints the SAME [ProjectionGroundPaint] the lit
/// state does, whatever the choice is. Blanking is a shutter over the
/// text, not a different screen.
///
/// Every ground is dark, and `projection_setup.dart`'s library doc
/// argues why at length: a projector adds light, so a light ground
/// washes the room and makes the blank key a flash. That file is also
/// where the two numbers live that stop this from being a matter of
/// taste — a luminance ceiling on any colour a ground paints, and a
/// contrast floor for scripture against it, both asserted in
/// `projection_setup_test.dart`.
///
/// One ground is a gradient rather than a flat fill, and it is drawn
/// with a `DecoratedBox` where the flat ones stay a `ColoredBox`. Not an
/// implementation detail: a one-colour `LinearGradient` would paint
/// identically and would make the default ground stop being the plain
/// fill of the app's own `groundBg` that it has always been.
///
/// ## EVERY STYLE HERE PINS `kCjkFontFallback`, INCLUDING THE REFERENCE
///
/// The app theme already carries the bundled CJK subset in its own
/// `fontFamilyFallback`, so inheriting would work today. Scripture
/// surfaces in this app pin it anyway — `main.dart`'s own comment says
/// "verse text + word spans already use kCjkFontFallback" — and this is
/// the surface where the failure is worst. On CanvasKit an unresolved
/// face draws as tofu, and 34 tofu boxes at 64 px on a wall in front of
/// a congregation is not a degraded reading, it is no reading at all.
/// One inherited property away from that is too close.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/bible_versions.dart'
    show shortBibleVersionLabel;
import 'package:seeksparks/constants/projection_setup.dart';
import 'package:seeksparks/constants/projection_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart'
    show WbColors, WbMetrics;
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;

/// The second edition's size, as a fraction of the first's.
const double kProjectionSecondScale = 0.82;

/// The corner reference's size, as a fraction of the passage's.
const double kProjectionReferenceScale = 0.26;

/// The size the corner reference will not go below however small the
/// operator sets the passage.
///
/// The reference is the one thing on the wall the congregation uses to
/// find the place in their own Bible, so it is the last thing that
/// should become unreadable when the operator winds the type down to fit
/// a long verse. Set above `WbMetrics.smallPrintFloor` — that floor is
/// about a person a foot from a laptop, and this is about a person at
/// the back of a hall.
///
/// Worth knowing which of the two numbers is actually in force: below
/// about 85 px of passage type the FLOOR governs and the ratio does
/// nothing, so across most of [kProjectionTypeSteps] the reference is a
/// fixed 22 px. That is the intent, not an accident — the reference's
/// job does not get smaller because the verse did. The ratio exists for
/// the top of the ladder, where 22 px under 160 px scripture would read
/// as a mistake rather than as restraint.
const double kProjectionReferenceFloor = 22.0;

/// The share of the viewport left as margin on each side, and top and
/// bottom.
///
/// A projected image is almost never square with the screen it lands on;
/// generous margins are what stop the first and last words of a verse
/// falling off the edge of the physical screen in a room nobody
/// calibrated. Vertical is roomier than horizontal because that is where
/// the control strip and the reference live.
const double kProjectionSideMargin = 0.07;
const double kProjectionVerticalMargin = 0.11;

class ProjectionStage extends StatelessWidget {
  const ProjectionStage({
    super.key,
    required this.verses,
    required this.reference,
    required this.versionCode,
    required this.typeSize,
    required this.blank,
    required this.locale,
    this.ground = kProjectionGroundDefault,
    this.secondOn = false,
    this.secondTexts,
    this.secondCode,
    this.secondLoading = false,
    this.countdownRemaining,
  });

  /// The verse on the wall, or null when the corpus has not arrived.
  /// The verses on the wall — one, or the block a selection opened.
  /// Empty is the empty state.
  final List<Verse> verses;

  /// Time left before the service starts, or null when no countdown is
  /// running. While it runs it REPLACES the passage: a room that is
  /// filling is being told when to sit down, and a verse behind a clock
  /// is neither.
  ///
  /// `Duration.zero` is a real state — 「就要开始了」 — and not the same
  /// as null. A countdown that vanished at zero would take the wall back
  /// to the passage at the exact moment every eye is on it.
  final Duration? countdownRemaining;

  /// Book, chapter and verse as the room reads it — built by the page,
  /// because the reference and the text must name the same edition.
  final String reference;

  final String versionCode;

  /// The size the operator asked for. A ceiling — see the library doc.
  final double typeSize;

  /// The blank key. The wall goes to the ground and stays there: the
  /// passage is not merely hidden, the whole stage is, reference
  /// included. A "blank" screen that still names a verse tells the room
  /// where the sermon is while the preacher is somewhere else.
  ///
  /// "The ground" is [ground], not black — see the library doc. Cutting
  /// to black from a ground that is not black is a flash, which is the
  /// one thing the blank key must not be.
  final bool blank;

  final String locale;

  /// Which dark the passage sits on. Every option is dark; see
  /// `projection_setup.dart`.
  final ProjectionGround ground;

  final bool secondOn;
  /// The second edition's text per verse in [verses], by position;
  /// null when the block is off or not loaded.
  final List<String?>? secondTexts;
  final String? secondCode;
  final bool secondLoading;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.dark;
    // ONE call for both states, so the blanked wall cannot drift away
    // from the lit one. A second `_ground(...)` written out in the
    // blank branch is exactly how the flash would come back.
    if (blank) return _ground();

    final left = countdownRemaining;
    if (left != null) {
      return _ground(
        child: Center(
          // The same scaleDown rule the passage gets: drawn at the size
          // the operator asked for, shrunk only if the wall is narrower
          // than it needs.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: 24, vertical: typeSize * 0.4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatProjectionCountdown(left),
                    style: TextStyle(
                      color: wb.text,
                      fontFamilyFallback: kCjkFontFallback,
                      // Bigger than a verse: two or three glyphs seen
                      // from the back of a hall, and the only thing on
                      // the wall.
                      fontSize: typeSize * 2.2,
                      height: 1.1,
                      fontWeight: FontWeight.w300,
                      // Digits that do not jostle as the seconds tick.
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  SizedBox(height: typeSize * 0.3),
                  Text(
                    _s(
                        left == Duration.zero
                            ? 'projectionCountdownNow'
                            : 'projectionCountdownSoon',
                        left == Duration.zero
                            ? 'We are beginning'
                            : 'The service begins in',
                        locale),
                    style: TextStyle(
                      color: wb.mutedText,
                      fontFamilyFallback: kCjkFontFallback,
                      fontSize: math.max(typeSize * kProjectionReferenceScale,
                          kProjectionReferenceFloor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return _ground(
      child: LayoutBuilder(
        builder: (context, box) {
          final side = box.maxWidth * kProjectionSideMargin;
          final top = box.maxHeight * kProjectionVerticalMargin;
          final usable = math.max(box.maxWidth - side * 2, 1.0);
          return Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: side, vertical: top),
                  child: Center(
                    child: verses.isEmpty
                        ? _emptyState(wb)
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: SizedBox(
                              width: usable,
                              child: _passage(wb),
                            ),
                          ),
                  ),
                ),
              ),
              Positioned(
                left: side,
                bottom: top * _kReferenceInsetShare,
                right: side,
                child: _reference(wb),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The wall's own paint, with [child] on top of it.
  ///
  /// A flat ground stays a `ColoredBox` so the default is still the
  /// plain fill of `WbColors.dark.groundBg` it has always been — a
  /// one-colour gradient would render the same and would quietly change
  /// what the blank-state test is looking at.
  Widget _ground({Widget? child}) {
    final paint = projectionGroundPaintFor(ground);
    final gradient = paint.gradient;
    if (gradient == null) return ColoredBox(color: paint.base, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: child,
    );
  }

  /// How far up from the bottom edge the reference sits, as a share of
  /// the vertical margin — inside the margin the passage respects, so it
  /// can never collide with the text above it.
  static const double _kReferenceInsetShare = 0.35;

  Widget _emptyState(WbColors wb) => Text(
        _s('projectionNoPassage', 'No passage is open', locale),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: wb.mutedText,
          fontFamilyFallback: kCjkFontFallback,
          fontSize: math.max(typeSize * kProjectionReferenceScale,
              kProjectionReferenceFloor),
        ),
      );

  Widget _passage(WbColors wb) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < verses.length; i++)
            _line(wb, verses[i].text, verses[i].verseLabel, typeSize, wb.text),
          if (secondOn) ...[
            SizedBox(height: typeSize * _kBlockGapShare),
            ..._secondLines(wb),
          ],
        ],
      );

  /// One verse of the wall. With more than one verse up, each carries
  /// its number in the muted colour — small, because the room reads the
  /// words and the number is only there so a listener can find their
  /// place in a printed Bible. A single verse carries none; the
  /// reference below already names it.
  Widget _line(WbColors wb, String text, String label, double size, Color ink) {
    final numbered = verses.length > 1;
    return Text.rich(
      TextSpan(children: [
        if (numbered)
          TextSpan(
            text: '$label ',
            style: TextStyle(
              color: wb.mutedText,
              fontSize: size * kProjectionReferenceScale * 1.6,
            ),
          ),
        TextSpan(text: text),
      ]),
      textAlign: TextAlign.center,
      style: TextStyle(
        color: ink,
        fontFamilyFallback: kCjkFontFallback,
        fontSize: size,
        height: WbMetrics.lineHeight,
      ),
    );
  }

  /// The second edition, verse for verse under the first — or one line
  /// of apparatus when it has nothing to show, in the muted colour so it
  /// cannot be mistaken for scripture (the rule `versificationSpan`
  /// follows in the workbench).
  List<Widget> _secondLines(WbColors wb) {
    final texts = secondTexts;
    final size = typeSize * kProjectionSecondScale;
    if (secondLoading || texts == null || texts.every((t) => t == null)) {
      return [
        Text(
          _secondBody(null),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: wb.mutedText,
            fontFamilyFallback: kCjkFontFallback,
            fontSize: size,
            height: WbMetrics.lineHeight,
          ),
        ),
      ];
    }
    return [
      for (var i = 0; i < verses.length; i++)
        _line(wb, _secondBody(texts[i]), verses[i].verseLabel, size,
            texts[i] == null ? wb.mutedText : wb.text),
    ];
  }

  /// The gap between the two editions, as a share of the passage size —
  /// so it stays a gap at every step of the ladder instead of vanishing
  /// at 160 px and swallowing the wall at 32.
  static const double _kBlockGapShare = 0.6;

  String _secondBody(String? text) {
    if (secondLoading) {
      return _s('projectionSecondVersionLoading',
          'Loading the second edition', locale);
    }
    return text ??
        _s('projectionSecondVersionMissing',
            'This edition has no text here', locale);
  }

  /// The reference, and the edition or editions it belongs to.
  ///
  /// The edition tags are part of the reference and not a separate badge
  /// because the room's question is one question — *where is this, and
  /// in what?* — and because a second edition on the wall with no way to
  /// tell which translation is which is worse than one edition.
  Widget _reference(WbColors wb) {
    if (verses.isEmpty) return const SizedBox.shrink();
    final tags = <String>[
      shortBibleVersionLabel(versionCode),
      if (secondOn && secondCode != null) shortBibleVersionLabel(secondCode!),
    ];
    return Text(
      '$reference · ${tags.join(" · ")}',
      style: TextStyle(
        color: wb.mutedText,
        fontFamilyFallback: kCjkFontFallback,
        fontSize: math.max(
            typeSize * kProjectionReferenceScale, kProjectionReferenceFloor),
      ),
    );
  }
}

/// `5:00`, `12:34`, `1:02:03` — minutes and seconds, hours only when
/// there are some. Never negative: a countdown that has run out reads
/// `0:00` until the operator takes it down, which is the state the room
/// is actually in.
String formatProjectionCountdown(Duration left) {
  final total = left.isNegative ? 0 : left.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final sec = total % 60;
  final two = sec.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$two';
  return '$m:$two';
}

/// See `projection_page.dart`'s copy: named `_s` so
/// `ui_string_keys_test.dart` recognises the lookups and holds this file
/// to all three languages.
String _s(String key, String fallback, String locale) =>
    projectionStrings[key]?[locale] ??
    projectionStrings[key]?['en'] ??
    fallback;
