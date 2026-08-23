import 'package:seeksparks/constants/bible_versions.dart'
    show shortBibleVersionLabel;

/// How wide the parallel view's two fixed columns have to be — the
/// version gutter, and the verse reference beside it.
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
///     is multiplied by the reader's `menuScale` — over 0.8 – 1.4 when
///     this was written, over the slider's full 0.7 – 1.5 since
///     2026-08-11. At 1.4 the 92px box clipped `CUV+S(雅伟)` again — a
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

/// Em widths charged to a character of a VERSE REFERENCE.
///
/// The version tag is a short, upper-case, bold abbreviation, so one
/// flat [_latinEm] over-estimates it by about 10% and nobody notices.
/// A reference is `2 Chronicles 1:1` — sixteen mixed-case characters —
/// and the same flat charge over-estimates it by 45%, which at the
/// default type size is about 70px of a 480px reading pane spent on
/// nothing. The classes below are measured from the shipped
/// `Roboto-VariableFont` at `wght=600`, the weight the reference is
/// actually set in (digits 0.571, space 0.249, colon 0.272, lower-case
/// mean 0.506, upper-case mean 0.640), then rounded UP so the model
/// still over-estimates every one of the 66 English book names.
///
/// Over-estimating is the safe direction but it is not the only
/// safeguard: [referenceGutterWidth] is applied as a MINIMUM width, not
/// a fixed one, so a reader whose chosen font is wider than Roboto gets
/// a slightly ragged column rather than a clipped reference. A clipped
/// reference is a lie about which verse this is.
/// Charging one flat width to every letter is what made the flat model
/// wrong, so `i j l` (≈0.26 em) and `m w` (≈0.87 em) are charged
/// separately — they are 2× off the mean in opposite directions and
/// they are common in book names (Phi**l**ipp**i**ans, 1 Ch**r**on**i**cles).
///
/// MEASURED against the shipped faces on 2026-08-24, 594 references,
/// by `browse_reference_real_font_test.dart` — the first test here to
/// lay the strings out in `Roboto-VariableFont` and `NotoSansSC-Sub`
/// rather than compare the model to itself:
///
///   English      +4.19% … +19.57%
///   Simplified   +1.34% …  +3.90%
///   Traditional  +1.34% …  +3.90%
///
/// An earlier version of this comment claimed "+4.5% to +15% across all
/// 66 English book names". Both ends were wrong, and it described only
/// English. **The Chinese margin is three times thinner**, and that is
/// structural rather than incidental: a Han glyph is charged exactly
/// 1.0 em with no rounding-up at all, so a Chinese reference's whole
/// safety margin comes from its ` 1:1` tail. Anyone retuning the Latin
/// classes below should know they are tuning the only slack a Chinese
/// reference has.
const double _refDigitEm = 0.60;
const double _refSpaceEm = 0.28;
const double _refColonEm = 0.30;
const double _refNarrowEm = 0.34;
const double _refWideEm = 0.92;
const double _refLowerEm = 0.58;
const double _refUpperEm = 0.74;

const String _refNarrowChars = 'ijl';
const String _refWideChars = 'mw';

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

/// Width in ems of one verse reference under the reference model.
double referenceLabelEms(String reference) {
  var ems = 0.0;
  for (final r in reference.runes) {
    if (_isFullWidth(r)) {
      ems += 1.0;
      continue;
    }
    final c = String.fromCharCode(r);
    if (r >= 0x30 && r <= 0x39) {
      ems += _refDigitEm;
    } else if (c == ' ') {
      ems += _refSpaceEm;
    } else if (c == ':') {
      ems += _refColonEm;
    } else if (_refNarrowChars.contains(c)) {
      ems += _refNarrowEm;
    } else if (_refWideChars.contains(c)) {
      ems += _refWideEm;
    } else if (c.toLowerCase() == c && c.toUpperCase() != c) {
      ems += _refLowerEm;
    } else {
      ems += _refUpperEm;
    }
  }
  return ems;
}

/// How wide the reference column of the parallel view has to be.
///
/// Same argument as the version gutter above, one column to its right,
/// and it was missing until 2026-08-17: three render paths printed the
/// reference three different ways — an untagged edition put it INSIDE
/// the text flow, so its first line began after the reference and every
/// wrapped line began under it, while the two tagged paths gave it an
/// intrinsic-width cell that moved with the verse number. On one screen
/// of five editions the verse text had three different left edges, and
/// the reason the reference is repeated on every row at all — so a
/// reader can run their eye down one translation — only works if the
/// column is straight.
///
/// Sized to the [references] actually on screen, which for a chapter is
/// one book name and a range of verse numbers, so a reader in Obadiah
/// does not pay for `Song of Solomon` existing.
///
/// [letterSpacing] is charged per character, exactly as
/// [versionGutterWidthForLabels] charges it one column to the left. It
/// was missing here until 2026-08-24, and the omission was invisible
/// because the [gap] happened to be larger than the error: a reference
/// `Text` inherits `bodyMedium`'s 0.25 from the ambient
/// `DefaultTextStyle`, so the painted string is `runes.length * 0.25`
/// px wider than this model believed. For `帖撒羅尼迦前書 1:1` that is
/// 2.75 px of an 8 px gap. The column stayed straight, but only because
/// one constant was absorbing another's mistake — shrink the gap for a
/// design reason and Chinese book names would have gone ragged with
/// nothing in the source to explain why.
double referenceGutterWidth(
  Iterable<String> references,
  double fontSize, {
  double letterSpacing = 0,
  double gap = referenceGutterGap,
}) {
  var widest = 0.0;
  for (final r in references) {
    final w = referenceLabelEms(r) * fontSize + letterSpacing * r.runes.length;
    if (w > widest) widest = w;
  }
  if (widest == 0) return 0;
  return widest + gap;
}

/// Space between the reference and the verse text it labels.
const double referenceGutterGap = 8.0;

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
