import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Central font catalogue for the Settings → Font Family dropdown.
///
/// Flutter on web (CanvasKit) can only render a face that is in its
/// Skia registry, so a CSS-only name like "Times New Roman" silently
/// renders as Roboto. Every option here is therefore either BUNDLED
/// (declared under `fonts:` in pubspec.yaml, so it works offline on
/// every platform) or explicitly marked as a best-effort system font.
///
/// 2026-08-08 (v1.6.62 — one worldwide build): the `google_fonts`
/// package and its 14 runtime-downloaded options are GONE. They
/// fetched from `fonts.gstatic.com`, which is unreachable from
/// mainland China — so on a single worldwide build they would be
/// dead entries in the picker for a large share of readers. That is
/// exactly the confusion the old CHINA_MODE flag existed to prevent
/// by hiding them; with the flag deleted, removing them outright is
/// the honest equivalent. Saved selections migrate in
/// [migrateLegacyFontKey].
///
/// The cost is real and worth naming: there is no serif option left.
/// Restoring one means BUNDLING an OFL face (EB Garamond has good
/// Greek coverage) as an asset, not reinstating a runtime download.

class FontOption {
  /// Stable identifier — what gets persisted in SharedPreferences.
  final String key;

  /// Display label shown in the dropdown row.
  final Map<String, String> label;

  /// True for fonts shipped as bundled assets in pubspec.yaml.
  /// These work offline and on all platforms.
  final bool isBundled;

  const FontOption({
    required this.key,
    required this.label,
    this.isBundled = false,
  });

  String labelFor(String locale) =>
      label[locale] ?? label['en'] ?? key;
}

/// 2026-05-22 (v1.2.71): comprehensive CJK font fallback chain. When a
/// TextStyle sets `fontFamily: settings.fontFamily` it should also set
/// `fontFamilyFallback: kCjkFontFallback` so rare Chinese characters
/// (e.g. `赒` U+8D52 in Acts 10:2, `䍁` U+4341, `𨱔` U+28C54) render
/// even if the primary font's subset doesn't include them.
///
/// 2026-05-24 (v1.3.31): The first entry `NotoSansSC-Sub` is a
/// BUNDLED font subset (assets/fonts/NotoSansSC-Sub.otf) covering
/// every CJK character used anywhere in the app. It's the only entry
/// in this list that Flutter web's CanvasKit renderer can actually
/// see — the rest are CSS names that only work on native iOS / macOS /
/// Android (where the OS fonts are accessible) or when the browser's
/// HTML renderer is active. CanvasKit needs fonts loaded into its
/// Skia font registry, and `fonts:` declarations in `pubspec.yaml`
/// are the standard way to register a font. Without this first entry
/// the user would see "X" tofu glyphs for rare characters on the web
/// build even though the chain has 20+ candidates.
///
/// Order rationale:
///   • Bundled → `NotoSansSC-Sub` (registered via pubspec, web-safe)
///   • Apple system → PingFang SC / Heiti SC — complete CJK on macOS/iOS
///   • Apple legacy → STSong / STFangsong
///   • Windows → Microsoft YaHei
///   • Google web → Noto Sans SC / Noto Serif SC — also complete
///   • Generic CSS → sans-serif (browser picks)
const List<String> kCjkFontFallback = [
  // 2026-06-16: Latin UI faces FIRST so Latin glyphs render in a clean
  // sans-serif on native desktop (Windows → Segoe UI; bundled Roboto
  // elsewhere) instead of falling through to a CJK serif (SimSun 宋体)
  // when the `-apple-system` token can't be resolved by the native
  // Skia engine. Per-glyph fallback means CJK characters skip these
  // (no Latin-only font has the glyph) and still resolve via the CJK
  // families below. Web/CanvasKit skips the unresolvable system names
  // and uses bundled Roboto for Latin, then NotoSansSC-Sub for CJK
  // — so this is safe on web too.
  'Segoe UI',
  'Roboto',
  'SF Pro Text',
  'Helvetica Neue',
  'Arial',
  // FIRST CJK: the bundled subset — the only CJK fallback that CanvasKit
  // can resolve on Flutter web. See `pubspec.yaml` for the bundle
  // declaration + the build script `tools/build_cjk_font_subset.sh`.
  'NotoSansSC-Sub',
  // After: native-platform / browser-CSS fallbacks. These work on
  // iOS / macOS / Android where Flutter can access OS-installed fonts,
  // and on the HTML renderer (not CanvasKit) where the browser
  // honours CSS font names. Kept as defence-in-depth.
  'PingFang SC',
  'PingFang TC',
  'Heiti SC',
  'Heiti TC',
  'STSong',
  'STFangsong',
  'STHeiti',
  'Hiragino Sans GB',
  'Microsoft YaHei',
  '微软雅黑',
  'Source Han Sans SC',
  'Source Han Sans TC',
  '思源黑体',
  'Noto Sans SC',
  'Noto Sans TC',
  'Noto Sans CJK SC',
  'Noto Sans CJK TC',
  'Noto Serif SC',
  'Noto Serif TC',
  'SimSun',
  '宋体',
  'sans-serif',
];

const List<FontOption> _catalog = [
  // ── System default (preferred default since v1.1.2) ──────────────
  // Routes through the OS's native UI font via the CSS font-stack
  // chain configured in main.dart's `fontFamilyFallback`. Apple
  // devices render in San Francisco, Windows in Segoe UI, Android
  // in Roboto, Linux in Cantarell / Noto Sans, etc. — every user
  // sees their own system's typography out of the box, no setting
  // change needed.
  //
  // The `key` field is treated as a special token by
  // `resolveFontFamily` below: when it equals `'system'` we return
  // an empty string so Flutter falls all the way through the
  // `fontFamilyFallback` list configured in `main.dart` (which
  // starts with `-apple-system`, then `BlinkMacSystemFont`, then
  // OS-specific candidates, then bundled Roboto as a last resort).
  FontOption(
    key: 'system',
    label: {
      'en': 'System default',
      'zh-Hans': '系统默认',
      'zh-Hant': '系統預設',
    },
    isBundled: true,
  ),
  // ── Bundled (works everywhere, offline) ──────────────────────────
  FontOption(
    key: 'Roboto',
    label: {
      'en': 'Roboto',
      'zh-Hans': 'Roboto',
      'zh-Hant': 'Roboto',
    },
    isBundled: true,
  ),
  // Microsoft YaHei was previously a bundled option here. Removed in
  // 2026-05 because it is a proprietary Microsoft font and the
  // licence forbids redistribution.

  // ── System fonts (best-effort fallback) ──────────────────────────
  // Kept for users on platforms that ship them locally; if the
  // engine can't find them it falls back to the theme default.
  FontOption(
    key: 'PingFang SC',
    label: {
      'en': 'PingFang SC (Apple devices)',
      'zh-Hans': '苹方（Apple 设备）',
      'zh-Hant': '蘋方（Apple 設備）',
    },
  ),
  FontOption(
    key: 'SimSun',
    label: {
      'en': 'SimSun (Windows classic)',
      'zh-Hans': '宋体（Windows 经典）',
      'zh-Hant': '宋體（Windows 經典）',
    },
  ),
];

/// Public list ordered for the dropdown.
List<FontOption> availableFontOptions() => List.unmodifiable(_catalog);

/// Whether [key] points at a real entry in the catalogue.
/// Used by [AppSettings.loadSettings] to migrate users whose stored
/// `fontFamily` came from an older catalogue — those keys would
/// crash the dropdown because no item matches the assigned `value:`.
bool isValidFontKey(String key) {
  for (final f in _catalog) {
    if (f.key == key) return true;
  }
  return false;
}

/// Keys that used to be served by the `google_fonts` package,
/// removed in v1.6.62. Listed explicitly rather than inferred so a
/// stored selection lands somewhere deliberate: `'system'` gives the
/// reader their own OS face, which is a closer match to what these
/// were chosen FOR (a comfortable proportional reading face) than
/// bundled Roboto would be. Order matters against [_migrations]
/// below — a legacy CSS key like `'Georgia'` used to map to `'Lora'`,
/// so it has to resolve through this set too rather than land on a
/// key that no longer exists.
const Set<String> _removedGoogleFontKeys = {
  'EB Garamond',
  'Lora',
  'Merriweather',
  'Crimson Pro',
  'Playfair Display',
  'Open Sans',
  'Inter',
  'Lato',
  'Nunito',
  'Montserrat',
  'Noto Serif SC',
  'Noto Sans SC',
  'ZCOOL XiaoWei',
  'Ma Shan Zheng',
};

/// Legacy CSS-only keys from the pre-Round-56 catalogue.
const Map<String, String> _migrations = {
  'Times New Roman': 'EB Garamond',
  'Garamond': 'EB Garamond',
  'Georgia': 'Lora',
  'Palatino': 'Merriweather',
  'Arial': 'Open Sans',
  'Helvetica': 'Inter',
  'Verdana': 'Lato',
  'system-ui': 'Inter',
  'Source Han Sans CN': 'Noto Sans SC',
  'Heiti SC': 'Noto Sans SC',
  'KaiTi': 'Noto Serif SC',
  // Microsoft YaHei removed in 2026-05 (proprietary font, licence
  // forbids redistribution).
  'Microsoft YaHei': 'Noto Sans SC',
};

/// Migrate a legacy / unknown selection key to the closest catalogue
/// entry. Called at startup to repair a `fontFamily` stored by an
/// older build.
String migrateLegacyFontKey(String stored) {
  if (_removedGoogleFontKeys.contains(stored)) return 'system';
  if (isValidFontKey(stored)) return stored;
  final mapped = _migrations[stored];
  if (mapped != null) {
    // The legacy table points at Round-56 names, several of which
    // were themselves Google Fonts — run the result through the same
    // removal check instead of returning a key the picker no longer
    // has.
    if (_removedGoogleFontKeys.contains(mapped)) return 'system';
    if (isValidFontKey(mapped)) return mapped;
  }
  return 'Roboto';
}

/// Look up the catalogue entry for a stored key. Falls back to the
/// first entry if the key isn't recognised.
FontOption fontOptionFor(String key) {
  for (final f in _catalog) {
    if (f.key == key) return f;
  }
  return _catalog.first;
}

/// Resolve a stored selection key to the actual font family name
/// that TextStyle's `fontFamily` parameter expects.
String resolveFontFamily(String key) {
  // 2026-05-08 (v1.1.2): the special `'system'` key resolves to the
  // first entry of the OS-native CSS font-stack chain. The full
  // chain lives in `main.dart`'s `fontFamilyFallback` argument.
  // On Flutter web a browser resolves the CSS pseudo-token
  // `-apple-system` to the OS UI font. The native Skia engine matches
  // real installed family names only and silently drops it, so
  // returning it there makes Latin text fall through to a CJK serif.
  // Return an empty family on native so Flutter walks
  // `fontFamilyFallback` cleanly (it leads with Segoe UI / Roboto).
  if (key == 'system') return kIsWeb ? '-apple-system' : '';
  return fontOptionFor(key).key;
}

/// Build a TextStyle that previews [key] in its own font, so the
/// dropdown row physically looks like the font it advertises.
TextStyle previewTextStyle(String key, TextStyle base) {
  if (key == 'system') {
    return base.copyWith(fontFamily: kIsWeb ? '-apple-system' : '');
  }
  return base.copyWith(fontFamily: fontOptionFor(key).key);
}
