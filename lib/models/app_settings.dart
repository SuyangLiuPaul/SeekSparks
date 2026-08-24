import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_style_preset.dart' show CardMaterial;
import 'package:seeksparks/models/notification_category.dart';
import 'package:seeksparks/services/app_icon_service.dart';
import 'package:seeksparks/services/notification_scheduler.dart'
    as scheduler;
import 'package:seeksparks/services/profile_service.dart';
import 'package:seeksparks/utils/font_catalog.dart';

/// The range the Font Size slider offers, in points, and the value that
/// counts as "unscaled".
///
/// Canonical. `settings_page` builds the slider from these and
/// `WbType.resolve` derives the workbench's type scale from the same
/// three numbers, so a stop the slider offers is a stop the workbench
/// can express. They were independent literals until 2026-08-11 and had
/// drifted apart: the slider ran 12–40 while the scale was clamped to
/// 0.75–1.6, i.e. 15–32 pt, so **11 of the slider's 29 stops moved
/// nothing at all**.
///
/// 2026-08-25 (#315): the slider is not the only control over this
/// number. The reader's `Aa` sheet is a second one, and it carried its
/// own literals — `.clamp(12, 32)` — from the initial commit, i.e. from
/// before these constants existed. So the app shipped two controls over
/// one setting that disagreed about its maximum. Anything that MOVES the
/// font size now goes through [fontSizeAfterStep]; anything that STORES
/// it goes through [setFontSize], which bounds it. A third control
/// cannot reintroduce a range of its own.
const double kFontSizeMin = 12.0;
const double kFontSizeMax = 40.0;
const double kFontSizeDefault = 20.0;

/// The range the Menu Size slider offers. Same contract as above; the
/// narrower 0.8–1.4 clamp ate 2 of its 9 stops.
const double kMenuScaleMin = 0.7;
const double kMenuScaleMax = 1.5;

/// The range the Line Spacing slider offers. Named for the same reason
/// as the two above: the slider held these as literals and no setter,
/// restore path or import bounded the stored value against them.
const double kLineSpacingMin = 1.0;
const double kLineSpacingMax = 3.0;
const double kLineSpacingDefault = 1.5;

/// One tap of a font-size stepper, as a value rather than as arithmetic
/// at a call site.
///
/// [delta] is in points and may be negative. The result is bounded by
/// the range Settings offers, so a stepper cannot walk outside it — and,
/// more to the point, cannot stop short of it. Returns [current]
/// unchanged when the step would leave the range, which is what
/// [canStepFontSize] reports to the button's `onPressed`.
double fontSizeAfterStep(double current, double delta) =>
    (current + delta).clamp(kFontSizeMin, kFontSizeMax).toDouble();

/// Whether a stepper button that moves the font size by [delta] should
/// be offered at all.
///
/// False only at the ends. A button that is enabled but cannot move is
/// worse than a disabled one: it reports success and does nothing.
bool canStepFontSize(double current, double delta) =>
    fontSizeAfterStep(current, delta) != current;

const _kFontFamily = 'fontFamily';
const _kFontSize = 'fontSize';
const _kLineSpacing = 'lineSpacing';
const _kPrimaryColor = 'primaryColor';
const _kCopyFormat = 'copyFormat';
const _kLocale = 'locale';
const _kThemeMode = 'themeMode';
const _kParagraphMode = 'paragraphMode';
// 2026-08 (ported from YsWords v1.3.156): "护眼" paper reading theme —
// scoped to the reading pane only, not a global theme swap.
const _kReadingPaperTheme = 'readingPaperTheme';
const _kMenuScale = 'menuScale';
// 2026-05-08 (v1.1.1): which card / tile material to render across
// the app's framing surfaces. See `lib/models/app_style_preset.dart`
// for the [CardMaterial] enum. Default `classic` keeps the look the
// app shipped with through v1.0.x.
const _kCardMaterial = 'cardMaterial';
// 2026-05-07 (v17): _kOfflineMode removed; the toggle that wrote it
// was deleted from the Settings card. The persisted bool is left in
// SharedPreferences for users that have it -- it's harmless dead
// data and not worth a migration step.
const _kBooksViewMode = 'booksViewMode';
const _kBoldVerseText = 'boldVerseText';
const _kShowStrongsInOriginals = 'showStrongsInOriginals';
const _kAutoExpandFirstRef = 'autoExpandFirstRef';
const _kNotificationsEnabled = 'notificationsEnabled';
// 2026-05-24 (v1.3.0): per-category notification prefs. Stored as a
// JSON string mapping category id → NotificationCategoryPrefs JSON.
const _kNotificationCategories = 'notificationCategories';
const _kShowSectionTitles = 'showSectionTitles';
const _kShowBookIntro = 'showBookIntro';
// User-supplied Gemini API key (BYOK). When non-empty, AI calls are
// routed through the user's own AI Studio key — gives them their own
// quota (15 RPM / 1500 RPD on the free tier) and keeps the app
// developer's shared quota for users who haven't pasted a key. The
// key never leaves this device's localStorage; the AI service only
// adds it to outbound POST bodies destined for our own Netlify
// function (which forwards to Google without persisting).
const _kGeminiApiKey = 'geminiApiKey';
// 2026-05-10 (v1.2.26): user's chosen AI response-depth tier.
// Maps to a Gemini model on the server side:
//   'flash-lite' → 'gemini-2.5-flash-lite' (fast, simple, default)
//   'flash'      → 'gemini-2.5-flash'      (balanced)
//   'pro'        → 'gemini-2.5-pro'        (deep, slower, smaller quota)
const _kAiModel = 'aiModel';
// Allowlist mirrored on the Netlify function side so a corrupt
// SharedPrefs entry can't drive the server to a model we don't
// support. Default 'flash-lite' matches the previous hardcoded
// MODEL constant in netlify/functions/aiBibleSearch.mjs.
const Set<String> _kAiModelAllowed = {'flash-lite', 'flash', 'pro'};
const String _kAiModelDefault = 'flash-lite';

// 2026-05-24 (v1.3.19): TTS voice preference constants removed
// along with the 朗读 feature. Existing SharedPreferences keys
// (`ttsVoiceGender`, `ttsVoiceTier`) are left untouched on disk
// — harmless orphan data that a future version can clear during
// migration if storage size becomes a concern.

// 2026-05-24 (v1.2.91): user's preferred sort order for the
// Library → Notes tab.
//   'canonical' → Genesis → Revelation (verse index in the loaded
//                 Bible; the order the app has used since v1.0)
//   'recent'    → most recently created/edited first (uses the
//                 verseNoteTimestamps map in MainProvider)
//   'oldest'    → oldest first (reverse of 'recent')
// Defaults to 'canonical' so existing users see no behaviour
// change until they pick a different sort. Allowlist-clamped on
// load to match the established pattern for aiModel + tts*.
const _kNotesSortMode = 'notesSortMode';
const Set<String> _kNotesSortAllowed = {'canonical', 'recent', 'oldest'};
const String _kNotesSortDefault = 'canonical';


class AppSettings extends ChangeNotifier {
  /// User's selected font key — what gets persisted in
  /// SharedPreferences (e.g. `'EB Garamond'`). Drives the dropdown
  /// `value:` and the visible label.
  ///
  /// 2026-05-08 (v1.1.2): default switched from `'Roboto'` to
  /// `'system'`. The new default routes through the OS-native CSS
  /// font-stack chain (`-apple-system` → `Segoe UI` → `Roboto` →
  /// …), so first-launch users on every platform see their own
  /// system's typography out of the box. `'Roboto'` remains a
  /// pickable option in Settings if a user prefers it explicitly.
  String _fontSelection = 'system';
  /// Resolved family name passed to TextStyle's `fontFamily`. For
  /// bundled fonts this equals [_fontSelection]; for Google Fonts
  /// it's the registered family name (e.g. `'EBGaramond_regular'`)
  /// that the engine actually recognises. Round 56 split: previously
  /// these were the same string and Google Fonts options silently
  /// fell back to Roboto.
  String _fontFamily = '-apple-system';
  double _fontSize = kFontSizeDefault;
  double _lineSpacing = kLineSpacingDefault;
  Color _primaryColor = AppIconService.kDefaultPrimaryColor;
  // 2026-05-17 (v1.2.47): default changed from 'withRef' →
  // 'devotional' per user request — devotional puts the
  // reference in parens AFTER the text (灵修 / 抄经 friendly
  // format) which is the most common day-to-day copy use case.
  // Existing users keep whatever they had via the SharedPrefs
  // fallback in `loadSettings()`; only fresh installs (or
  // `resetAllSettings()`) get the new default.
  String _copyFormat = 'devotional';
  String _locale = 'zh-Hans';
  ThemeMode _themeMode = ThemeMode.system;
  bool _paragraphMode = true;
  bool _readingPaperTheme = false;
  double _menuScale = 1.0;
  // 2026-05-08 (v1.1.1): card / tile material; classic by default.
  CardMaterial _cardMaterial = CardMaterial.classic;
  /// 'list' or 'grid' — persisted choice for the books picker.
  String _booksViewMode = 'grid';
  /// Render verse text with FontWeight.w700 instead of normal weight.
  bool _boldVerseText = false;
  /// Show the Strong's # badge inside each word chip in the originals
  /// (exegesis) sheet — handy for power users, distracting for some.
  bool _showStrongsInOriginals = true;
  /// Auto-expand the first book group in the concordance section of
  /// each Strong's entry so the user sees verse refs immediately.
  bool _autoExpandFirstRef = false;

  /// Show the Today's Evidence card + Bible Evidence quick-link tile +
  /// the Bible Evidence page entry. Default ON.

  /// Whether the user has opted into notifications. When true, the
  /// app requests browser Notification permission on next launch and
  /// fires local reminders (today's verse, today's reading missed,
  /// etc.). Default OFF — must be explicit user opt-in.
  bool _notificationsEnabled = false;
  // 2026-05-24 (v1.3.0): per-category prefs. Lazy default — categories
  // not in the map fall back to NotificationCategoryPrefs.defaultFor.
  Map<String, NotificationCategoryPrefs> _notificationCategories = {};

  /// User-supplied Gemini API key. When non-empty, AI calls (word
  /// explanations, AI search) are billed against the user's own
  /// AI Studio quota instead of the developer-shared key.
  String _geminiApiKey = '';
  // 2026-05-10 (v1.2.26): see top-of-file _kAiModel comment.
  String _aiModel = _kAiModelDefault;
  // 2026-05-24 (v1.3.19): TTS fields removed with the 朗读 feature.
  // 2026-05-24 (v1.2.91): see _kNotesSortMode comment.
  String _notesSortMode = _kNotesSortDefault;

  /// Render section / paragraph headings (e.g. "The Sermon on the
  /// Mount" / "登山宝训") above the matched verse in the reading
  /// pane. Default ON — gives chapters useful structure. Toggle in
  /// Settings → Reading.
  bool _showSectionTitles = true;

  /// Render the collapsible book-intro card at the top of chapter 1
  /// when an intro is authored for that book. Default ON. Toggle in
  /// Settings → Reading.
  bool _showBookIntro = true;

  /// The resolved family for TextStyle.fontFamily. Existing call
  /// sites (`fontFamily: settings.fontFamily`) automatically get the
  /// Google-Fonts-registered name without code changes elsewhere.
  String get fontFamily => _fontFamily;
  /// The user's stored selection key — use this for the dropdown
  /// `value:` and for round-tripping back into [setFontFamily].
  String get fontSelection => _fontSelection;
  double get fontSize => _fontSize;
  double get lineSpacing => _lineSpacing;
  Color get primaryColor => _primaryColor;
  String get copyFormat => _copyFormat;
  String get locale => _locale;
  ThemeMode get themeMode => _themeMode;
  bool get paragraphMode => _paragraphMode;
  bool get readingPaperTheme => _readingPaperTheme;
  double get menuScale => _menuScale;
  CardMaterial get cardMaterial => _cardMaterial;
  String get booksViewMode => _booksViewMode;
  bool get boldVerseText => _boldVerseText;
  bool get showStrongsInOriginals => _showStrongsInOriginals;
  bool get autoExpandFirstRef => _autoExpandFirstRef;
  bool get notificationsEnabled => _notificationsEnabled;
  /// Safe per-category lookup. Returns the stored prefs if present,
  /// or the shipped default if the user hasn't touched this category.
  NotificationCategoryPrefs notificationCategory(String categoryId) =>
      _notificationCategories[categoryId] ??
      NotificationCategoryPrefs.defaultFor(categoryId);
  bool get showSectionTitles => _showSectionTitles;
  bool get showBookIntro => _showBookIntro;

  /// User-supplied Gemini API key. Empty string when the user is on
  /// the developer-shared key. Caller services (AiWordService /
  /// AiSearchService) read this and include it in their request body
  /// when set. Never persisted off-device.
  String get geminiApiKey => _geminiApiKey;
  bool get hasUserGeminiKey => _geminiApiKey.trim().isNotEmpty;

  /// 2026-05-10 (v1.2.26): user's selected AI response-depth tier
  /// — one of {'flash-lite', 'flash', 'pro'}. Default 'flash-lite'
  /// matches the previous hardcoded server default.
  String get aiModel => _aiModel;

  Future<void> setAiModel(String model) async {
    if (!_kAiModelAllowed.contains(model)) return;
    if (_aiModel == model) return;
    _aiModel = model;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAiModel, model);
  }

  // 2026-05-24 (v1.3.19): `ttsVoiceGender` / `ttsVoiceTier` getters
  // + setters removed with the 朗读 feature.

  /// 2026-05-24 (v1.2.91): which sort to apply in Library → Notes.
  /// One of 'canonical' / 'recent' / 'oldest'. See _kNotesSortMode
  /// for semantics. Defaults to 'canonical' for backwards compat.
  String get notesSortMode => _notesSortMode;

  Future<void> setNotesSortMode(String mode) async {
    if (!_kNotesSortAllowed.contains(mode)) return;
    if (_notesSortMode == mode) return;
    _notesSortMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNotesSortMode, mode);
  }

  Future<void> setGeminiApiKey(String key) async {
    final trimmed = key.trim();
    if (_geminiApiKey == trimmed) return;
    _geminiApiKey = trimmed;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      await prefs.remove(_kGeminiApiKey);
    } else {
      await prefs.setString(_kGeminiApiKey, trimmed);
    }
  }

  /// [selection] is a catalogue key like `'EB Garamond'` (see
  /// [availableFontOptions]). We persist the key as-is and resolve
  /// it through the Google Fonts package when needed so the rest of
  /// the codebase keeps using `settings.fontFamily` unchanged.
  Future<void> setFontFamily(String selection) async {
    if (_fontSelection == selection) return;
    _fontSelection = selection;
    _fontFamily = resolveFontFamily(selection);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFontFamily, selection);
  }

  Future<void> setFontSize(double size) async {
    final clamped = size.clamp(kFontSizeMin, kFontSizeMax).toDouble();
    if (_fontSize == clamped) return;
    _fontSize = clamped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kFontSize, clamped);
  }

  Future<void> setLineSpacing(double spacing) async {
    final clamped =
        spacing.clamp(kLineSpacingMin, kLineSpacingMax).toDouble();
    if (_lineSpacing == clamped) return;
    _lineSpacing = clamped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLineSpacing, clamped);
  }

  Future<void> setPrimaryColor(Color color) async {
    if (_primaryColor == color) return;
    _primaryColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPrimaryColor, color.toARGB32());
    // 2026-05-24 (v1.2.96): also swap the iOS home-screen icon if
    // the user picked a color that has a matching alternate-icon
    // variant. Non-iOS platforms are a silent no-op. The OS shows
    // a one-time alert per session ("icon changed for ...") which
    // is iOS-imposed and can't be suppressed.
    // Fire-and-forget — we don't await because the alert is async
    // and the user's already moved on from Settings.
    // ignore: unawaited_futures
    AppIconService.updateForColor(color);
  }

  Future<void> setCopyFormat(String format) async {
    if (_copyFormat == format) return;
    _copyFormat = format;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCopyFormat, format);
  }

  Future<void> setLocale(String langCode) async {
    if (_locale == langCode) return;
    _locale = langCode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocale, langCode);
    // 2026-06-16 (v1.3.89): scheduled-notification titles/bodies are
    // localized at schedule time, so a language change must re-create them
    // — otherwise pending reminders keep firing in the OLD language until
    // the next app launch. (No-op on web; the scheduler guards platform.)
    unawaited(_rescheduleAllSafely());
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, mode.name);
  }

  Future<void> setParagraphMode(bool enabled) async {
    if (_paragraphMode == enabled) return;
    _paragraphMode = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kParagraphMode, enabled);
  }

  Future<void> setReadingPaperTheme(bool enabled) async {
    if (_readingPaperTheme == enabled) return;
    _readingPaperTheme = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kReadingPaperTheme, enabled);
  }

  // 2026-05-08 (v1.1.1): card / tile material picker. Persisted as
  // the enum's name string so future enum reorderings don't reshuffle
  // user choices the way an int index would.
  Future<void> setCardMaterial(CardMaterial material) async {
    if (_cardMaterial == material) return;
    _cardMaterial = material;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCardMaterial, material.name);
  }

  Future<void> setBooksViewMode(String mode) async {
    final normalized = (mode == 'grid') ? 'grid' : 'list';
    if (_booksViewMode == normalized) return;
    _booksViewMode = normalized;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBooksViewMode, normalized);
  }

  Future<void> setBoldVerseText(bool enabled) async {
    if (_boldVerseText == enabled) return;
    _boldVerseText = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBoldVerseText, enabled);
  }

  Future<void> setShowStrongsInOriginals(bool enabled) async {
    if (_showStrongsInOriginals == enabled) return;
    _showStrongsInOriginals = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowStrongsInOriginals, enabled);
  }

  Future<void> setAutoExpandFirstRef(bool enabled) async {
    if (_autoExpandFirstRef == enabled) return;
    _autoExpandFirstRef = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoExpandFirstRef, enabled);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    if (_notificationsEnabled == enabled) return;
    _notificationsEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotificationsEnabled, enabled);
    // 2026-05-24 (v1.3.0): kick off (or tear down) all scheduled
    // category notifications when the master toggle flips.
    // Lazy-import to avoid pulling timezone/native code into web.
    unawaited(_rescheduleAllSafely());
  }

  /// Replace per-category prefs and persist. Callers from the
  /// Settings UI typically call this with a `copyWith` of the
  /// current category's prefs (e.g. toggling enabled, picking a
  /// new time). Fires a notify + a reschedule.
  Future<void> setNotificationCategory(
      String categoryId, NotificationCategoryPrefs newPrefs) async {
    if (_notificationCategories[categoryId] == newPrefs) return;
    _notificationCategories = {
      ..._notificationCategories,
      categoryId: newPrefs,
    };
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final map = <String, dynamic>{};
    for (final e in _notificationCategories.entries) {
      map[e.key] = e.value.toJson();
    }
    await prefs.setString(_kNotificationCategories, jsonEncode(map));
    unawaited(_rescheduleAllSafely());
  }

  /// Wrapper that pulls the scheduler off the conditional-import
  /// boundary. On web the scheduler short-circuits internally.
  Future<void> _rescheduleAllSafely() async {
    try {
      await scheduler.rescheduleAll(this);
    } catch (_) {
      // Schedule failures shouldn't kill the settings write path.
      // notification_scheduler logs internally with debugPrint.
    }
  }

  Future<void> setShowSectionTitles(bool enabled) async {
    if (_showSectionTitles == enabled) return;
    _showSectionTitles = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowSectionTitles, enabled);
  }

  Future<void> setShowBookIntro(bool enabled) async {
    if (_showBookIntro == enabled) return;
    _showBookIntro = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowBookIntro, enabled);
  }


  Future<void> setMenuScale(double scale) async {
    final clamped = scale.clamp(kMenuScaleMin, kMenuScaleMax).toDouble();
    if (_menuScale == clamped) return;
    _menuScale = clamped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kMenuScale, clamped);
  }

  /// Restore every visual / preference setting to its factory default
  /// (round 55 "Reset settings" button). Resets fonts, theme, primary
  /// color, copy format, theme mode, paragraph mode, menu scale,
  /// books view mode, the show-* flags, AND the onboarding-seen flag
  /// (so the user can re-walk the tour after resetting).
  ///
  /// Deliberately preserves:
  ///   • [_locale] — wiping it would yank the user back to the system
  ///     default mid-session, which is jarring and not what users
  ///     expect from a "Reset settings" button.
  ///   • Bookmarks, notes, highlights, profile, last-read positions,
  ///     sermon scroll positions — these are user *content*, not
  ///     preferences. Lives in MainProvider / SermonService /
  ///     ProfileService and is owned by those services.
  ///
  /// Caller (Settings page) is responsible for showing a confirm
  /// dialog before calling this — it's idempotent but visible.
  Future<void> resetAllSettings() async {
    // 2026-05-08 (v1.1.2): reset returns the user to the system
    // default font (not hardcoded Roboto), matching the priority
    // chain "user setting → system detect → app fallback". On
    // every platform the system token resolves via the CSS font
    // stack to the OS UI font.
    _fontSelection = 'system';
    _fontFamily = '-apple-system';
    _fontSize = kFontSizeDefault;
    _lineSpacing = kLineSpacingDefault;
    _primaryColor = AppIconService.kDefaultPrimaryColor;
    _copyFormat = 'devotional';
    _themeMode = ThemeMode.system;
    _paragraphMode = true;
    _readingPaperTheme = false;
    _menuScale = 1.0;
    _cardMaterial = CardMaterial.classic;
    _booksViewMode = 'grid';
    _boldVerseText = false;
    _showStrongsInOriginals = true;
    _autoExpandFirstRef = false;
    _notificationsEnabled = false;
    _showSectionTitles = true;
    _showBookIntro = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    // Wipe every preference key we've ever written. Loop is the
    // safest implementation — additions to AppSettings won't drift
    // out of sync the way an explicit list would.
    final managedKeys = <String>{
      _kFontFamily,
      _kFontSize,
      _kLineSpacing,
      _kPrimaryColor,
      _kCopyFormat,
      _kThemeMode,
      _kParagraphMode,
      _kMenuScale,
      _kCardMaterial,
      // 2026-05-07 (v17): the offlineMode toggle is gone, but we
      // still purge the stored bool on reset so users who toggled
      // it before don't carry dead data forever.
      'offlineMode',
      _kBooksViewMode,
      _kBoldVerseText,
      _kShowStrongsInOriginals,
      _kAutoExpandFirstRef,
      _kNotificationsEnabled,
      _kShowSectionTitles,
      _kShowBookIntro,
      // The dashboard was deleted when the Workbench became the app
      // (no home screen), but installs from before then still carry
      // its keys. Same treatment as 'offlineMode' above: the constants
      // are gone, the purge stays, so a reset clears the dead data.
      'showBibleEvidence',
      'dashboard_section_order',
      'dashboard_section_visible_readBible',
      'dashboard_section_visible_resumeSermon',
      'dashboard_section_visible_dailyVerse',
      'dashboard_section_visible_counts',
      'dashboard_section_visible_recentBookmarks',
      'dashboard_section_visible_todayEvidence',
      'dashboard_section_visible_quickLinks',
      // Re-show the onboarding tour after a reset so the user can
      // re-discover any features they hid by accident. Clear all
      // historical keys — `v3` is the active one (since v1.2.9), but
      // someone resetting from a v2 / v1 install needs both legacy
      // keys gone too so a stale flag from before this version
      // can't suppress the refreshed tour.
      'onboarding.seen.v3',
      'onboarding.seen.v2',
      'onboarding.seen.v1',
    };
    for (final k in managedKeys) {
      await prefs.remove(k);
    }
  }

  Future<void> loadSettings() async {
    // 2026-05-10 (v1.2.31): wrap in try/catch so a Safari-private-
    // browsing localStorage block, an iOS storage quota error, or
    // any other shared_preferences plugin failure leaves all
    // settings at compile-time defaults instead of throwing into
    // the bootstrap catch (which would mis-route the user to the
    // "Failed to load" verse-error scaffold even though the verse
    // load is fine). Compile-time defaults are sane: zh-Hans /
    // system theme / fontSize 20 — user can still use the app.
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e, st) {
      debugPrint('AppSettings.loadSettings: shared_preferences '
          'unavailable, using defaults — $e\n$st');
      // Notify listeners with default values so the rest of the
      // tree wires up immediately; later writes via setX(...) will
      // also fail-soft so functionality degrades gracefully.
      notifyListeners();
      return;
    }
    // Round 56: migrate legacy keys (Times New Roman, Garamond, …)
    // before resolving — DropdownButton would otherwise crash on a
    // value that doesn't match any item.
    //
    // 2026-05-08 (v1.1.2): when the user has no stored choice we
    // fall through to 'system' (the new default) — which routes
    // through the OS-native CSS font stack defined in main.dart's
    // fontFamilyFallback. Roboto remains the **app fallback** at
    // the end of that chain, but it's no longer the eager default
    // for users who haven't expressed a preference.
    final stored = prefs.getString(_kFontFamily) ?? 'system';
    _fontSelection = migrateLegacyFontKey(stored);
    _fontFamily = resolveFontFamily(_fontSelection);
    // Persist the migrated key so the next launch is clean.
    if (_fontSelection != stored) {
      await prefs.setString(_kFontFamily, _fontSelection);
    }
    // Round to nearest step, then bound to the range the slider offers.
    // The rounding alone was not enough: a `Slider` asserts on a value
    // outside min..max, and in release JS the assert is stripped and the
    // thumb simply paints off the end of the track. A value from a
    // legacy build, a hand-edited prefs file or an imported settings
    // blob can be anything.
    final rawFontSize = prefs.getDouble(_kFontSize) ?? kFontSizeDefault;
    _fontSize = ((rawFontSize - kFontSizeMin).roundToDouble() + kFontSizeMin)
        .clamp(kFontSizeMin, kFontSizeMax)
        .toDouble();
    final rawLineSpacing = prefs.getDouble(_kLineSpacing) ?? kLineSpacingDefault;
    _lineSpacing = ((rawLineSpacing * 10).roundToDouble() / 10)
        .clamp(kLineSpacingMin, kLineSpacingMax)
        .toDouble();
    _primaryColor =
        Color(prefs.getInt(_kPrimaryColor) ?? AppIconService.kDefaultPrimaryColor.toARGB32());
    // 2026-08-06: the icon was redesigned and the brand seed moved from
    // indigo to the mark's ink blue. Anyone still carrying the old seed
    // never picked it — it was just the shipped default — so move them
    // forward. A colour the reader actually chose is left alone.
    if (_primaryColor.toARGB32() ==
        AppIconService.kLegacyPrimaryColor.toARGB32()) {
      _primaryColor = AppIconService.kDefaultPrimaryColor;
      await prefs.setInt(_kPrimaryColor, _primaryColor.toARGB32());
    }
    // 2026-06-14 (v1.3.70): re-apply the themed home-screen / dock /
    // favicon icon on startup so it tracks the saved theme colour.
    // iOS resets `alternateIconName` to the primary icon on every app
    // reinstall/update (the nightly launchd reinstall + any App Store
    // update), and updateForColor previously fired ONLY when the user
    // CHANGED the colour — so after an update the icon reverted to the
    // default blue and never came back, and re-tapping the already-
    // selected swatch is a no-op (setPrimaryColor early-returns). Sync
    // here, once after the first frame so the platform channel is live;
    // the service no-ops when the icon already matches (no redundant
    // iOS "you changed the icon" alert on normal launches).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ignore: unawaited_futures
      AppIconService.updateForColor(_primaryColor);
    });
    _copyFormat = prefs.getString(_kCopyFormat) ?? 'devotional';
    // 2026-05-26 (v1.3.46): persist the detected locale on first
    // load. Previously `_locale = prefs.get ?? _detectSystemLocale()`
    // only kept the detection IN MEMORY — the prefs key stayed
    // empty. `MainProvider.restoreState` reads the prefs key (not
    // AppSettings.locale) to pick its locale-aware default Bible
    // version, so an English-locale fresh install hit the
    // switch's `default:` branch and got CUVS-YHWH instead of the
    // intended NASB. Writing the detected value back the first
    // time we see an unset prefs key fixes that without touching
    // the read path.
    final persistedLocale = prefs.getString(_kLocale);
    _locale = persistedLocale ?? _detectSystemLocale();
    if (persistedLocale == null) {
      await prefs.setString(_kLocale, _locale);
    }
    _themeMode = _parseThemeMode(prefs.getString(_kThemeMode));
    _paragraphMode = prefs.getBool(_kParagraphMode) ?? true;
    _readingPaperTheme = prefs.getBool(_kReadingPaperTheme) ?? false;
    final rawMenuScale = prefs.getDouble(_kMenuScale) ?? 1.0;
    _menuScale = ((rawMenuScale * 10).roundToDouble() / 10)
        .clamp(kMenuScaleMin, kMenuScaleMax)
        .toDouble();
    // 2026-05-08 (v1.1.1): card material — default `classic` so
    // existing users see no visual change from earlier versions
    // unless they explicitly opt into a new look.
    final rawCardMaterial = prefs.getString(_kCardMaterial);
    _cardMaterial = CardMaterial.values.firstWhere(
      (m) => m.name == rawCardMaterial,
      orElse: () => CardMaterial.classic,
    );
    final rawBooksView = prefs.getString(_kBooksViewMode) ?? 'grid';
    _booksViewMode = rawBooksView == 'grid' ? 'grid' : 'list';
    _boldVerseText = prefs.getBool(_kBoldVerseText) ?? false;
    _showStrongsInOriginals =
        prefs.getBool(_kShowStrongsInOriginals) ?? true;
    _autoExpandFirstRef = prefs.getBool(_kAutoExpandFirstRef) ?? false;
    _notificationsEnabled = prefs.getBool(_kNotificationsEnabled) ?? false;
    // 2026-05-24 (v1.3.0): load per-category notification prefs.
    // Stored as one JSON object keyed by category id. Missing keys
    // fall back to NotificationCategoryPrefs.defaultFor at read time
    // (via the notificationCategory() helper), so we don't need to
    // pre-populate the map here.
    final notifCatRaw = prefs.getString(_kNotificationCategories);
    if (notifCatRaw != null && notifCatRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(notifCatRaw) as Map<String, dynamic>;
        final map = <String, NotificationCategoryPrefs>{};
        decoded.forEach((id, value) {
          if (value is Map<String, dynamic>) {
            map[id] = NotificationCategoryPrefs.fromJson(value);
          }
        });
        _notificationCategories = map;
      } catch (_) {
        // Corrupted JSON — fall back to empty (defaults will apply).
        _notificationCategories = {};
      }
    }
    _showSectionTitles = prefs.getBool(_kShowSectionTitles) ?? true;
    _showBookIntro = prefs.getBool(_kShowBookIntro) ?? true;
    _geminiApiKey = prefs.getString(_kGeminiApiKey) ?? '';
    // 2026-05-10 (v1.2.26): restore aiModel from prefs. Allowlist
    // -clamp so a corrupt entry doesn't drive the server to an
    // unsupported model — invalid values fall back to default.
    final storedAiModel = prefs.getString(_kAiModel);
    _aiModel = (storedAiModel != null && _kAiModelAllowed.contains(storedAiModel))
        ? storedAiModel
        : _kAiModelDefault;

    // 2026-05-24 (v1.3.19): TTS voice pref restore removed with the
    // 朗读 feature. The stored SharedPreferences keys are left in
    // place as harmless orphan data.

    // 2026-05-24 (v1.2.91): Library → Notes sort mode. Same
    // allowlist-clamp pattern as aiModel.
    final storedNotesSort = prefs.getString(_kNotesSortMode);
    _notesSortMode = (storedNotesSort != null &&
            _kNotesSortAllowed.contains(storedNotesSort))
        ? storedNotesSort
        : _kNotesSortDefault;

    // 2026-05-25 (v1.3.41): if a userPrefs JSON blob exists, apply
    // it OVER the legacy individual-key reads above — it carries the
    // full settings snapshot and is the source of truth when
    // present. Fields the blob doesn't contain fall through to the
    // legacy values we just loaded, which keeps a blob written by an
    // older build forward-compatible with new fields.
    final userPrefsBlob = prefs.getString(
        ProfileService.instance.scopedKey('userPrefs'));
    if (userPrefsBlob != null && userPrefsBlob.isNotEmpty) {
      try {
        _applyUserPrefsBlob(jsonDecode(userPrefsBlob) as Map<String, dynamic>);
      } catch (_) {/* corrupt blob → keep legacy values already loaded */}
    }

    notifyListeners();

  }

  // 2026-05-25 (v1.3.41): debounce timer for the comprehensive
  // userPrefs blob writer. Every change to AppSettings fields
  // triggers notifyListeners(); we schedule a single blob write
  // 600 ms later so a burst of consecutive setter calls (e.g.
  // restoring a sheet that flips 5 toggles in a row) produces
  // exactly one blob write + one RTDB upload, not five.
  Timer? _userPrefsWriteDebounce;
  // While applying the blob from disk, suppress the write-back
  // scheduler — otherwise we'd echo the same blob right back to
  // RTDB on every device load.
  bool _suppressUserPrefsWrite = false;
  // 2026-06-15 (v1.3.80): the last userPrefs blob we actually wrote.
  // Content guard against the "Syncing↔Synced 发癫" flicker loop:
  // `notifyListeners()` fires for MANY reasons (incl. rebuilds driven
  // by a sync-status change that some widget listens to). Each one
  // used to stamp `userPrefsTimestamp = now()` + call requestUpload —
  // and because the timestamp changed every time, the sync layer's
  // own dedupe hash never matched, so it uploaded again, flipped the
  // status, triggered another rebuild → setter → notifyListeners →
  // upload … forever. Skipping the write when the serialized content
  // is byte-identical breaks the feedback loop at the source.
  String? _lastWrittenUserPrefsBlob;

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (_suppressUserPrefsWrite) return;
    _userPrefsWriteDebounce?.cancel();
    _userPrefsWriteDebounce = Timer(const Duration(milliseconds: 600), () {
      // ignore: unawaited_futures
      _writeUserPrefsBlob();
    });
  }

  /// Serialize all settings into a single JSON blob + write it to
  /// the ProfileService-scoped `userPrefs` key in SharedPreferences
  /// + bump the paired `userPrefsTimestamp` int.
  ///
  /// `geminiApiKey` is deliberately excluded — a credential does not
  /// belong in the general settings blob, for the reasons documented
  /// near the `_kGeminiApiKey` declaration.
  /// Single source of truth for the sync-eligible settings snapshot.
  /// Used by both the writer and the content-guard primer so the two
  /// can never drift (a drift would defeat the guard and re-open the
  /// flicker loop). `geminiApiKey` is deliberately excluded — separate
  /// sync path.
  Map<String, dynamic> _userPrefsSnapshot() => {
        'fontFamily': _fontSelection,
        'fontSize': _fontSize,
        'lineSpacing': _lineSpacing,
        'primaryColor': _primaryColor.toARGB32(),
        'copyFormat': _copyFormat,
        'locale': _locale,
        'themeMode': _themeMode.name,
        'paragraphMode': _paragraphMode,
        'readingPaperTheme': _readingPaperTheme,
        'menuScale': _menuScale,
        'cardMaterial': _cardMaterial.name,
        'booksViewMode': _booksViewMode,
        'boldVerseText': _boldVerseText,
        'showStrongsInOriginals': _showStrongsInOriginals,
        'autoExpandFirstRef': _autoExpandFirstRef,
        'notificationsEnabled': _notificationsEnabled,
        'showSectionTitles': _showSectionTitles,
        'showBookIntro': _showBookIntro,
        'aiModel': _aiModel,
        'notesSortMode': _notesSortMode,
      };

  Future<void> _writeUserPrefsBlob() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final blob = jsonEncode(_userPrefsSnapshot());
      // Content guard (v1.3.80): nothing sync-eligible actually
      // changed → don't bump the timestamp or trigger an upload.
      // This is the fix for the "Syncing↔Synced 来回跳" loop — a
      // status-driven rebuild that nudges any setter no longer
      // churns the sync pipeline when the resulting blob is the same.
      if (blob == _lastWrittenUserPrefsBlob) return;
      _lastWrittenUserPrefsBlob = blob;
      await prefs.setString(
          ProfileService.instance.scopedKey('userPrefs'), blob);
      await prefs.setInt(
          ProfileService.instance.scopedKey('userPrefsTimestamp'),
          DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      // Non-fatal — the legacy per-key writes already persisted the
      // change locally.
      debugPrint('AppSettings._writeUserPrefsBlob failed: $e');
    }
  }

  /// Apply a previously-serialized userPrefs blob onto the live
  /// state. Called from `loadSettings` after legacy per-key reads
  /// when the blob is present; takes precedence so a newer
  /// synced-blob device's preferences win over the local
  /// individual-key reads. Suppresses the write-back debounce so
  /// applying the blob doesn't immediately re-upload an identical
  /// copy.
  void _applyUserPrefsBlob(Map<String, dynamic> m) {
    _suppressUserPrefsWrite = true;
    try {
      if (m['fontFamily'] is String) {
        _fontSelection = m['fontFamily'] as String;
        _fontFamily = resolveFontFamily(_fontSelection);
      }
      // An imported blob is a file the reader chose off disk — a real
      // system boundary, and since sync was removed (#286) the only way
      // settings cross devices. Bound the three scales here; an
      // out-of-range one reaches a Slider directly.
      if (m['fontSize'] is num) {
        _fontSize = (m['fontSize'] as num)
            .toDouble()
            .clamp(kFontSizeMin, kFontSizeMax)
            .toDouble();
      }
      if (m['lineSpacing'] is num) {
        _lineSpacing = (m['lineSpacing'] as num)
            .toDouble()
            .clamp(kLineSpacingMin, kLineSpacingMax)
            .toDouble();
      }
      if (m['primaryColor'] is num) {
        _primaryColor = Color((m['primaryColor'] as num).toInt());
      }
      if (m['copyFormat'] is String) _copyFormat = m['copyFormat'] as String;
      if (m['locale'] is String) _locale = m['locale'] as String;
      if (m['themeMode'] is String) {
        _themeMode = _parseThemeMode(m['themeMode'] as String);
      }
      if (m['paragraphMode'] is bool) _paragraphMode = m['paragraphMode'] as bool;
      if (m['readingPaperTheme'] is bool) {
        _readingPaperTheme = m['readingPaperTheme'] as bool;
      }
      if (m['menuScale'] is num) {
        _menuScale = (m['menuScale'] as num)
            .toDouble()
            .clamp(kMenuScaleMin, kMenuScaleMax)
            .toDouble();
      }
      if (m['cardMaterial'] is String) {
        _cardMaterial = CardMaterial.values.firstWhere(
          (c) => c.name == m['cardMaterial'],
          orElse: () => _cardMaterial,
        );
      }
      if (m['booksViewMode'] is String) {
        final raw = m['booksViewMode'] as String;
        _booksViewMode = raw == 'grid' ? 'grid' : 'list';
      }
      if (m['boldVerseText'] is bool) _boldVerseText = m['boldVerseText'] as bool;
      if (m['showStrongsInOriginals'] is bool) {
        _showStrongsInOriginals = m['showStrongsInOriginals'] as bool;
      }
      if (m['autoExpandFirstRef'] is bool) {
        _autoExpandFirstRef = m['autoExpandFirstRef'] as bool;
      }
      if (m['notificationsEnabled'] is bool) {
        _notificationsEnabled = m['notificationsEnabled'] as bool;
      }
      if (m['showSectionTitles'] is bool) {
        _showSectionTitles = m['showSectionTitles'] as bool;
      }
      if (m['showBookIntro'] is bool) {
        _showBookIntro = m['showBookIntro'] as bool;
      }
      if (m['aiModel'] is String) {
        final raw = m['aiModel'] as String;
        _aiModel =
            _kAiModelAllowed.contains(raw) ? raw : _kAiModelDefault;
      }
      if (m['notesSortMode'] is String) {
        final raw = m['notesSortMode'] as String;
        _notesSortMode =
            _kNotesSortAllowed.contains(raw) ? raw : _kNotesSortDefault;
      }
    } finally {
      _suppressUserPrefsWrite = false;
      // Prime the content guard with the blob we just applied so the
      // write-back scheduled by loadSettings' notifyListeners() sees
      // identical content and skips the redundant seed-upload.
      _lastWrittenUserPrefsBlob = jsonEncode(_userPrefsSnapshot());
    }
  }

  static ThemeMode _parseThemeMode(String? raw) {
    if (raw == null) return ThemeMode.system;
    // Accept new 'light'/'dark'/'system' and legacy 'ThemeMode.light' etc.
    final normalized = raw.startsWith('ThemeMode.') ? raw.substring(10) : raw;
    return ThemeMode.values.firstWhere(
      (m) => m.name == normalized,
      orElse: () => ThemeMode.system,
    );
  }

  static String _detectSystemLocale() {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final locale = dispatcher.locale;
    if (locale.languageCode == 'zh') {
      return locale.scriptCode == 'Hant' ? 'zh-Hant' : 'zh-Hans';
    }
    return 'en';
  }
}
