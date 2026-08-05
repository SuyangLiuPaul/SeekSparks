/// 2026-08 (SeekSparks): the Workbench's own dense desktop theme.
///
/// The rest of SeekSparks is a touch-first reading app — rounded cards,
/// generous padding, a purple Material 3 palette. That is right for a
/// phone and wrong for this workspace: BibleWorks is a *dense, flat,
/// neutral, keyboard-driven desktop tool*, and putting its three windows
/// inside Material 3 chrome produced something that read as "a mobile
/// app in three columns" rather than as BibleWorks.
///
/// So the Workbench gets its own [ThemeData], applied to that subtree
/// only. Nothing here leaks into the phone reader.
///
/// The rules this encodes, taken from BibleWorks 10:
///   * ~12px body text on a ~1.3 line height — roughly half the vertical
///     space per line that the reading app uses.
///   * Square corners and 1px hairline borders. No shadows, no cards.
///   * A neutral ground. The ONLY saturated colour in the whole window
///     is the per-version tag and the blue of a clickable reference —
///     which is exactly why those read as information rather than
///     decoration.
///   * Chrome (menu bar, pane titles, status bar) one step smaller
///     again, at 11px.
library;

import 'package:flutter/material.dart';

/// Metrics shared by every Workbench surface. Numbers, not opinions —
/// they exist so panes stay on the same rhythm instead of each picking
/// its own padding.
abstract final class WbMetrics {
  /// Body text in the Browse and Search windows.
  static const double text = 12.0;

  /// Menu bar, pane titles, status bar, version tags.
  static const double chrome = 11.0;

  /// Original-language text needs a little more size to stay legible
  /// with pointing/accents, even in a dense layout.
  static const double original = 15.0;

  static const double lineHeight = 1.32;

  /// Height of the menu bar, the toolbar and the status bar.
  static const double menuBarHeight = 22.0;
  static const double toolbarHeight = 26.0;
  static const double statusBarHeight = 20.0;

  /// Height of a pane's title strip.
  static const double paneTitleHeight = 21.0;

  /// One row in a verse list.
  static const double rowPadV = 1.5;
  static const double rowPadH = 6.0;

  /// Hairline. BibleWorks separates everything with a single pixel.
  static const double hairline = 1.0;
}

/// The Workbench palette. Kept separate from `ColorScheme` because most
/// of these have no Material equivalent — "the colour of a pane's title
/// strip" is not a Material role.
@immutable
class WbColors extends ThemeExtension<WbColors> {
  const WbColors({
    required this.paneBg,
    required this.paneAltBg,
    required this.chromeBg,
    required this.border,
    required this.text,
    required this.mutedText,
    required this.link,
    required this.selectionBg,
    required this.hoverBg,
  });

  /// Background of a content pane (Browse, Search list, Analysis).
  final Color paneBg;

  /// Zebra/alternate row background — BibleWorks alternates version
  /// blocks so the eye can find the version boundary at a glance.
  final Color paneAltBg;

  /// Menu bar, toolbar, pane title strips, status bar.
  final Color chromeBg;

  final Color border;
  final Color text;
  final Color mutedText;

  /// Clickable scripture references. BibleWorks uses plain hyperlink
  /// blue and so do we — it is the one thing users already know.
  final Color link;

  /// Current verse / selected row.
  final Color selectionBg;

  /// Mouse-over highlight. The Workbench is hover-driven, so this gets
  /// used constantly.
  final Color hoverBg;

  static const light = WbColors(
    paneBg: Color(0xFFFFFFFF),
    paneAltBg: Color(0xFFF7F7F5),
    chromeBg: Color(0xFFECECEC),
    border: Color(0xFFBFBFBF),
    text: Color(0xFF1A1A1A),
    mutedText: Color(0xFF6B6B6B),
    link: Color(0xFF0B4FA8),
    selectionBg: Color(0xFFD9E8FB),
    hoverBg: Color(0xFFF0F4FA),
  );

  static const dark = WbColors(
    paneBg: Color(0xFF1C1C1C),
    paneAltBg: Color(0xFF232323),
    chromeBg: Color(0xFF2A2A2A),
    border: Color(0xFF3D3D3D),
    text: Color(0xFFE4E4E4),
    mutedText: Color(0xFF9A9A9A),
    link: Color(0xFF6FA8F0),
    selectionBg: Color(0xFF23405F),
    hoverBg: Color(0xFF262E38),
  );

  @override
  WbColors copyWith({
    Color? paneBg,
    Color? paneAltBg,
    Color? chromeBg,
    Color? border,
    Color? text,
    Color? mutedText,
    Color? link,
    Color? selectionBg,
    Color? hoverBg,
  }) =>
      WbColors(
        paneBg: paneBg ?? this.paneBg,
        paneAltBg: paneAltBg ?? this.paneAltBg,
        chromeBg: chromeBg ?? this.chromeBg,
        border: border ?? this.border,
        text: text ?? this.text,
        mutedText: mutedText ?? this.mutedText,
        link: link ?? this.link,
        selectionBg: selectionBg ?? this.selectionBg,
        hoverBg: hoverBg ?? this.hoverBg,
      );

  @override
  WbColors lerp(ThemeExtension<WbColors>? other, double t) {
    if (other is! WbColors) return this;
    return WbColors(
      paneBg: Color.lerp(paneBg, other.paneBg, t)!,
      paneAltBg: Color.lerp(paneAltBg, other.paneAltBg, t)!,
      chromeBg: Color.lerp(chromeBg, other.chromeBg, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      link: Color.lerp(link, other.link, t)!,
      selectionBg: Color.lerp(selectionBg, other.selectionBg, t)!,
      hoverBg: Color.lerp(hoverBg, other.hoverBg, t)!,
    );
  }

  static WbColors of(BuildContext context) =>
      Theme.of(context).extension<WbColors>() ?? light;
}

/// Per-version tag colour. BibleWorks prints a short version code at the
/// start of every line in a saturated colour, and that single device is
/// what makes a wall of interleaved parallel text readable — you find
/// the version you want by colour, not by reading.
///
/// Codes are grouped so related versions sit near each other in hue:
/// English literal = blue, English traditional = green, Chinese = amber,
/// original languages = red/purple (they are the ones you scan for).
const Map<String, Color> kVersionTagColors = {
  // Original languages — the highest-value lines, so the strongest hue.
  'wtt': Color(0xFF9C1F1F), // Hebrew OT
  'bgt': Color(0xFF9C1F1F), // Greek NT
  'original': Color(0xFF9C1F1F),
  // English
  'nasb': Color(0xFF1B4F9C),
  'esv': Color(0xFF1B4F9C),
  'leb': Color(0xFF2A6BAF),
  'kjv': Color(0xFF1F7A3D),
  'asv': Color(0xFF1F7A3D),
  'web': Color(0xFF2A8A4A),
  // Chinese
  'cuvs': Color(0xFF9A6212),
  'cuvt': Color(0xFF9A6212),
  'cuvs-yhwh': Color(0xFFB0721A),
  'cuvt-yhwh': Color(0xFFB0721A),
  'ljk1': Color(0xFF7A3FA0),
  'ljk2': Color(0xFF7A3FA0),
};

/// Fallback for a version with no assigned colour — derived from the
/// code so it is at least stable across sessions rather than random.
Color versionTagColor(String code) {
  final hit = kVersionTagColors[code.toLowerCase()];
  if (hit != null) return hit;
  final h = code.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0x7fffffff);
  return HSLColor.fromAHSL(1, (h % 360).toDouble(), 0.55, 0.35).toColor();
}

/// Builds the Workbench's [ThemeData] from the app's own [parent] theme.
///
/// Deliberately does NOT inherit the app's seeded purple scheme: the
/// point is a neutral ground. `primary` is set to the link blue so the
/// handful of Material widgets we still use (checkboxes in the version
/// picker, progress indicators) land somewhere sane.
///
/// It DOES inherit the parent's font family and — critically — its
/// `fontFamilyFallback`. Replacing the text theme without carrying that
/// chain across dropped Hebrew and Greek to notdef boxes, because the
/// bundled CJK subset and the platform faces that actually have those
/// scripts live in the parent's fallback list, not in any font this
/// file names.
ThemeData workbenchTheme(ThemeData parent) {
  final brightness = parent.brightness;
  final wb = brightness == Brightness.dark ? WbColors.dark : WbColors.light;
  final base = brightness == Brightness.dark
      ? ThemeData.dark(useMaterial3: true)
      : ThemeData.light(useMaterial3: true);
  final inherited = parent.textTheme.bodyMedium;
  final fallback = inherited?.fontFamilyFallback;

  final scheme = ColorScheme.fromSeed(
    seedColor: wb.link,
    brightness: brightness,
  ).copyWith(
    surface: wb.paneBg,
    onSurface: wb.text,
    onSurfaceVariant: wb.mutedText,
    outline: wb.border,
    outlineVariant: wb.border,
    primary: wb.link,
    surfaceContainerHighest: wb.paneAltBg,
  );

  TextStyle body(double size, {FontWeight? w, Color? c}) => TextStyle(
        fontSize: size,
        height: WbMetrics.lineHeight,
        fontWeight: w,
        color: c ?? wb.text,
        // fontFamily deliberately NOT pinned: naming a family restricts
        // CanvasKit to that face plus the explicit fallback list, and
        // none of those carry Hebrew. Leaving it unset lets the engine
        // reach its own broader fallback for non-Latin scripts.
        fontFamilyFallback: fallback,
      );

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: wb.chromeBg,
    canvasColor: wb.paneBg,
    dividerColor: wb.border,
    dividerTheme: DividerThemeData(
      color: wb.border,
      thickness: WbMetrics.hairline,
      space: WbMetrics.hairline,
    ),
    textTheme: base.textTheme.copyWith(
      bodyLarge: body(WbMetrics.text),
      bodyMedium: body(WbMetrics.text),
      bodySmall: body(WbMetrics.chrome, c: wb.mutedText),
      labelSmall: body(WbMetrics.chrome, c: wb.mutedText),
      titleSmall: body(WbMetrics.chrome, w: FontWeight.w600),
    ),
    iconTheme: IconThemeData(color: wb.mutedText, size: 15),
    // Square, hairline-bordered, no elevation — everywhere.
    cardTheme: CardThemeData(
      color: wb.paneBg,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: wb.border),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 400),
      textStyle: body(WbMetrics.chrome, c: Colors.white),
    ),
    // A dense text field with a hairline box, not a filled pill.
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: wb.paneBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: wb.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: wb.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: wb.link, width: 1.4),
      ),
      hintStyle: body(WbMetrics.text, c: wb.mutedText),
    ),
    // Kill the ripple. A desktop tool highlights on hover, it doesn't
    // splash on click.
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    extensions: <ThemeExtension<dynamic>>[wb],
  );
}
