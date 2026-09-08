import 'package:flutter/material.dart';

import 'package:seeksparks/constants/workbench_theme.dart' show WbColors;

/// Theme-aware color helpers for places where we want to use a
/// **specific palette** (teal for Aramaic, indigo for Hebrew, etc.)
/// rather than the surrounding ColorScheme's primary/secondary slots,
/// but still need to adapt to light vs. dark mode.
///
/// Pattern before this helper:
/// ```dart
/// Container(
///   color: Colors.teal.shade100,        // washed out in dark mode
///   child: Text('...', style: TextStyle(color: Colors.teal.shade900)), // unreadable in dark
/// )
/// ```
///
/// Pattern after:
/// ```dart
/// Container(
///   color: paletteBg(context, Colors.teal),
///   child: Text('...', style: TextStyle(color: paletteFg(context, Colors.teal))),
/// )
/// ```
///
/// In light mode: shade100 bg + shade900 text (high contrast, vivid).
/// In dark mode: shade900 bg with alpha + shade100/200 text (vivid
/// without being eye-searing on a dark surface).
///
/// WHICH "DARK" THESE ASK ABOUT. `WbColors.of(ctx).isDark`, not
/// `Theme.of(ctx).brightness`. The app has THREE palettes and only two
/// brightnesses: 护眼纸质 is a cream page that can sit under a dark
/// `ThemeMode`, and every one of these helpers used to ask Material
/// which brightness was set. The result was a shade900-at-45%-alpha
/// tint and shade200 ink painted on a cream page — the Aramaic teal in
/// the originals sheet, and the pass/warn rows, both inverted, in the
/// one reading mode most likely to be on for hours at a time.
///
/// `stats_page.dart` had already worked around this locally
/// (`_scriptHue(wb, hue)`) and `family_tree_page.dart` by hand; two
/// independent local fixes for one wrong question is the signal that
/// the question was wrong. `WbColors.isDark` was written for exactly
/// this and answers false for paper.

/// Background tint for a colored card / chip / pill.
/// Light: shade100 (pastel). Dark: shade900 with low alpha so the
/// card sits as a tinted surface above the dark scaffold.
Color paletteBg(BuildContext ctx, MaterialColor color) {
  final dark = WbColors.of(ctx).isDark;
  return dark ? color.shade900.withValues(alpha: 0.45) : color.shade100;
}

/// Foreground (text / icon) on a [paletteBg] surface.
/// Light: shade900 (deep, readable). Dark: shade200 (vivid, readable).
Color paletteFg(BuildContext ctx, MaterialColor color) {
  final dark = WbColors.of(ctx).isDark;
  return dark ? color.shade200 : color.shade900;
}

/// Border / accent line — visible in both modes without overpowering
/// the content.
Color paletteBorder(BuildContext ctx, MaterialColor color) {
  final dark = WbColors.of(ctx).isDark;
  return dark
      ? color.shade400.withValues(alpha: 0.55)
      : color.shade700.withValues(alpha: 0.45);
}

/// Stronger accent color for icons, chips, link-text. Stays vivid
/// in both modes.
Color paletteAccent(BuildContext ctx, MaterialColor color) {
  final dark = WbColors.of(ctx).isDark;
  // Brighter shade in dark mode so it pops against the dark surface;
  // standard `color` (which is `shade500`) in light mode stays readable.
  return dark ? color.shade300 : color.shade700;
}

/// Status colors — used for the diagnostic page's pass/fail/warn
/// rows. Adapt to dark mode while keeping the semantic meaning.
Color statusOk(BuildContext ctx) => paletteAccent(ctx, Colors.green);
Color statusWarn(BuildContext ctx) => paletteAccent(ctx, Colors.orange);
Color statusBgOk(BuildContext ctx) => paletteBg(ctx, Colors.green);
Color statusBgWarn(BuildContext ctx) => paletteBg(ctx, Colors.orange);
