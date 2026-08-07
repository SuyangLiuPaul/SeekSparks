/// One version, one colour, everywhere, always.
///
/// The parallel view prints a small tinted pill ahead of each reading.
/// Its colour used to be `scheme.secondary` at alpha 0.13 — translucent,
/// so it composited against whatever sat behind it. A selected verse has
/// a tinted background, so the SAME version rendered as two visibly
/// different colours depending on whether its row happened to be
/// selected. A reader learns "this shade is KJV" in one verse and is
/// wrong two verses later, which is worse than having no colour at all.
///
/// Two rules follow, and both matter:
///
///   1. The colour is a pure function of the VERSION CODE. Not the row
///      index, not the position in the list, not the order the panes
///      were opened — those all change while the version does not.
///   2. The colours are OPAQUE. Anything translucent inherits its
///      background, which is the bug above wearing a different hat.
///
/// The palette is picked for hue separation at a 9.5pt pill rather than
/// for beauty; these are identification marks, not decoration. Each
/// entry ships a light and a dark variant because the same hex cannot
/// carry legible text on both grounds.
library;

import 'package:flutter/material.dart';

/// Pill background/foreground pairs, light and dark. Index is chosen by
/// [_slotFor], never by call order.
const List<({Color bgLight, Color fgLight, Color bgDark, Color fgDark})>
    _palette = [
  // indigo
  (
    bgLight: Color(0xFFE0E4F5), fgLight: Color(0xFF2A3A78),
    bgDark: Color(0xFF2C3560), fgDark: Color(0xFFC5CDF0)
  ),
  // teal
  (
    bgLight: Color(0xFFD8ECEA), fgLight: Color(0xFF18514C),
    bgDark: Color(0xFF1E4844), fgDark: Color(0xFFB3DCD7)
  ),
  // amber
  (
    bgLight: Color(0xFFF3E7D2), fgLight: Color(0xFF6B4A12),
    bgDark: Color(0xFF4E3A17), fgDark: Color(0xFFE6CB9B)
  ),
  // rose
  (
    bgLight: Color(0xFFF3E0E4), fgLight: Color(0xFF743241),
    bgDark: Color(0xFF572833), fgDark: Color(0xFFE8BDC7)
  ),
  // olive
  (
    bgLight: Color(0xFFE3EBD8), fgLight: Color(0xFF3F5424),
    bgDark: Color(0xFF334420), fgDark: Color(0xFFCADCB2)
  ),
  // slate
  (
    bgLight: Color(0xFFE2E6E9), fgLight: Color(0xFF35434D),
    bgDark: Color(0xFF333F48), fgDark: Color(0xFFC3CDD4)
  ),
];

/// Stable slot for a version code.
///
/// Deliberately NOT `hashCode`: Dart makes no promise that String.hashCode
/// is stable across runs or releases, so a version's colour could change
/// between builds — the exact drift this file exists to prevent. A tiny
/// explicit sum is boring, reproducible, and enough to spread a dozen
/// codes across six slots.
int _slotFor(String code) {
  var sum = 0;
  for (final unit in code.codeUnits) {
    sum = (sum + unit) % 1000003;
  }
  return sum % _palette.length;
}

/// Original-language readings (Greek/Hebrew) share one reserved
/// treatment rather than joining the rotation. They are a different KIND
/// of row — the source rather than a rendering of it — and reading them
/// as "just another version colour" loses that.
const _originalLight = (bg: Color(0xFFEDE3F3), fg: Color(0xFF4A2A63));
const _originalDark = (bg: Color(0xFF3F2B52), fg: Color(0xFFD9C4E8));

bool _isDark(ColorScheme scheme) => scheme.brightness == Brightness.dark;

Color versionPillColor(
  String code,
  ColorScheme scheme, {
  bool isOriginal = false,
}) {
  final dark = _isDark(scheme);
  if (isOriginal) return dark ? _originalDark.bg : _originalLight.bg;
  final slot = _palette[_slotFor(code)];
  return dark ? slot.bgDark : slot.bgLight;
}

Color versionPillTextColor(
  String code,
  ColorScheme scheme, {
  bool isOriginal = false,
}) {
  final dark = _isDark(scheme);
  if (isOriginal) return dark ? _originalDark.fg : _originalLight.fg;
  final slot = _palette[_slotFor(code)];
  return dark ? slot.fgDark : slot.fgLight;
}
