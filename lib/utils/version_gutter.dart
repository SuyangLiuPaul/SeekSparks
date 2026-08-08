import 'package:seeksparks/constants/bible_versions.dart'
    show shortBibleVersionLabel;

/// How wide the parallel view's version gutter has to be.
///
/// The gutter is a FIXED column — that is its whole point, because a
/// wall of interleaved parallel rows is only readable if the text of
/// every edition starts on the same x. So the width has to be decided
/// once, for the widest label present, and every row obeys it.
///
/// It was a hard-coded pixel constant until 2026-08-08 and was wrong
/// three times (52 → 68 → 92), for two different reasons:
///
///   * it was sized against the longest label the author happened to be
///     looking at rather than the longest label that EXISTS; and
///   * it was sized at the DEFAULT type scale, while `WbType.chrome`
///     is multiplied by the reader's `menuScale` over the range
///     0.8 – 1.4. At 1.4 the 92px box clipped `CUV+S(雅伟)` again — a
///     latent defect nobody had reported yet, because the font-size
///     slider and the version gutter are not obviously related.
///
/// Both go away by making the width a multiple of the type size and
/// deriving the multiple from the label text itself.
///
/// The measurement is deliberately a cheap, pure character model rather
/// than a `TextPainter`: the reader chooses the app font, and on Flutter
/// web a real measurement taken before the web font finishes loading is
/// simply wrong with no repaint to correct it. A pure function is also
/// the only version a unit test can pin, since the headless test font
/// has nothing to do with the shipped one.
///
/// The model over-estimates on purpose. A CJK glyph is exactly one em;
/// Latin is charged [_latinEm], which clears bold Roboto's widest real
/// label (`LXX+WH`, ≈4.21 em) with about 10% to spare. `TextOverflow
/// .ellipsis` stays on the tag as the honest fallback for a font wider
/// than the model.

/// Em width charged to a non-full-width character.
const double _latinEm = 0.78;

/// Extra pixels between the tag and the verse text.
const double versionGutterGap = 8.0;

/// Never collapse below this, so a one-character label still reads as a
/// column rather than as a stray glyph.
const double versionGutterMinWidth = 30.0;

bool _isFullWidth(int rune) =>
    // CJK radicals, Kangxi, punctuation, kana, Hangul, unified ideographs
    (rune >= 0x2E80 && rune <= 0x303E) ||
    (rune >= 0x3041 && rune <= 0x33FF) ||
    (rune >= 0x3400 && rune <= 0x4DBF) ||
    (rune >= 0x4E00 && rune <= 0x9FFF) ||
    (rune >= 0xA000 && rune <= 0xA4CF) ||
    (rune >= 0xAC00 && rune <= 0xD7A3) ||
    (rune >= 0xF900 && rune <= 0xFAFF) ||
    (rune >= 0xFE30 && rune <= 0xFE4F) ||
    (rune >= 0xFF00 && rune <= 0xFF60) ||
    (rune >= 0xFFE0 && rune <= 0xFFE6) ||
    (rune >= 0x20000 && rune <= 0x3FFFD);

/// Width in ems of one label under the character model.
double versionLabelEms(String label) {
  var ems = 0.0;
  for (final r in label.runes) {
    ems += _isFullWidth(r) ? 1.0 : _latinEm;
  }
  return ems;
}

/// The gutter width for a set of already-resolved [labels] rendered at
/// [fontSize] with [letterSpacing].
double versionGutterWidthForLabels(
  Iterable<String> labels,
  double fontSize, {
  double letterSpacing = 0.2,
  double gap = versionGutterGap,
}) {
  var widest = 0.0;
  for (final label in labels) {
    final w = versionLabelEms(label) * fontSize +
        letterSpacing * label.runes.length;
    if (w > widest) widest = w;
  }
  if (widest == 0) return versionGutterMinWidth;
  final total = widest + gap;
  return total < versionGutterMinWidth ? versionGutterMinWidth : total;
}

/// The gutter width for the editions actually on screen.
///
/// Sizing to the displayed set rather than to the whole catalog is the
/// point: a reader comparing four Chinese editions gets a 2-character
/// gutter, and does not pay for `LXX+WH` being in the catalog.
///
/// [codes] are version codes; the original-language rows pass their
/// pseudo-codes (`wtt` / `bgt`), which resolve to themselves.
double versionGutterWidth(
  Iterable<String> codes,
  double fontSize, {
  double letterSpacing = 0.2,
  double gap = versionGutterGap,
}) =>
    versionGutterWidthForLabels(
      [for (final c in codes) shortBibleVersionLabel(c).toUpperCase()],
      fontSize,
      letterSpacing: letterSpacing,
      gap: gap,
    );
