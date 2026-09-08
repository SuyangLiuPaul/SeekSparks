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
    required this.verse,
    required this.reference,
    required this.versionCode,
    required this.typeSize,
    required this.blank,
    required this.locale,
    this.secondOn = false,
    this.secondText,
    this.secondCode,
    this.secondLoading = false,
  });

  /// The verse on the wall, or null when the corpus has not arrived.
  final Verse? verse;

  /// Book, chapter and verse as the room reads it — built by the page,
  /// because the reference and the text must name the same edition.
  final String reference;

  final String versionCode;

  /// The size the operator asked for. A ceiling — see the library doc.
  final double typeSize;

  /// The blank key. The wall goes to the ground colour and stays there:
  /// the passage is not merely hidden, the whole stage is, reference
  /// included. A "blank" screen that still names a verse tells the room
  /// where the sermon is while the preacher is somewhere else.
  final bool blank;

  final String locale;

  final bool secondOn;
  final String? secondText;
  final String? secondCode;
  final bool secondLoading;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.dark;
    if (blank) return ColoredBox(color: wb.groundBg);

    return ColoredBox(
      color: wb.groundBg,
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
                    child: verse == null
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
          Text(
            verse!.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: wb.text,
              fontFamilyFallback: kCjkFontFallback,
              fontSize: typeSize,
              height: WbMetrics.lineHeight,
            ),
          ),
          if (secondOn) ...[
            SizedBox(height: typeSize * _kBlockGapShare),
            Text(
              _secondBody(),
              textAlign: TextAlign.center,
              style: TextStyle(
                // A missing or still-loading second edition is
                // apparatus, not scripture, and must not be mistaken for
                // the verse — the same rule `versificationSpan` follows
                // in the workbench.
                color: secondText == null ? wb.mutedText : wb.text,
                fontFamilyFallback: kCjkFontFallback,
                fontSize: typeSize * kProjectionSecondScale,
                height: WbMetrics.lineHeight,
              ),
            ),
          ],
        ],
      );

  /// The gap between the two editions, as a share of the passage size —
  /// so it stays a gap at every step of the ladder instead of vanishing
  /// at 160 px and swallowing the wall at 32.
  static const double _kBlockGapShare = 0.6;

  String _secondBody() {
    if (secondLoading) {
      return _s('projectionSecondVersionLoading',
          'Loading the second edition', locale);
    }
    return secondText ??
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
    if (verse == null) return const SizedBox.shrink();
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

/// See `projection_page.dart`'s copy: named `_s` so
/// `ui_string_keys_test.dart` recognises the lookups and holds this file
/// to all three languages.
String _s(String key, String fallback, String locale) =>
    projectionStrings[key]?[locale] ??
    projectionStrings[key]?['en'] ??
    fallback;
