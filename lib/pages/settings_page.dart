// 2026-05-20 (v1.2.67): `dart:js_interop` was here. See
// `lib/utils/clear_cache_helper.dart` for the conditional-import
// pattern that replaced it.
import 'package:seeksparks/utils/atomic_text_edit.dart';
import 'package:seeksparks/utils/clear_cache_helper.dart';
import 'package:seeksparks/utils/clipboard_helper.dart';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard;
import 'package:seeksparks/constants/app_version.dart';
import 'package:seeksparks/constants/text_patterns.dart' show sanitizeForCopy;
import 'package:seeksparks/constants/sermon_credit.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart'
    show WbMetrics, WbType, WbSettingsScale;
import 'package:provider/provider.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/app_style_preset.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/app_icon_service.dart';
import 'package:seeksparks/utils/app_nav.dart';
import 'package:seeksparks/pages/about_page.dart';
import 'package:seeksparks/utils/ai_markdown.dart' show parseAiMarkdown;
import 'package:seeksparks/utils/theme_color_helpers.dart';
import 'package:seeksparks/pages/profiles_page.dart';
import 'package:seeksparks/widgets/gemini_key_card.dart';
import 'package:seeksparks/models/notification_category.dart';
import 'package:seeksparks/services/notification_service.dart';
import 'package:seeksparks/widgets/contact_line.dart';
import 'package:seeksparks/widgets/profile_avatar.dart';
// 2026-05-07 (v17): fetch_books / fetch_verses imports removed; the
// only consumer was the deleted "Check for Updates" reload path.
import 'package:seeksparks/services/export_service.dart';
import 'package:seeksparks/services/import_service.dart';
import 'package:seeksparks/utils/floating_toast.dart';
import 'package:seeksparks/services/install_prompt_service.dart';
import 'package:seeksparks/services/profile_service.dart';
import 'package:seeksparks/utils/font_catalog.dart';

import 'package:seeksparks/services/offline_pack_service.dart';
import 'package:seeksparks/widgets/home_icon_button.dart';
import 'package:seeksparks/widgets/language_switcher_button.dart';
import 'package:seeksparks/widgets/localized_back_button.dart';
import 'package:seeksparks/widgets/onboarding_dialog.dart';
import 'package:seeksparks/utils/responsive.dart';

String getDevotionalFormattedText(
    List<Map<String, dynamic>> verses, String? book, int? chapter) {
  if (verses.isEmpty || book == null || chapter == null) return '';

  List<int> verseNums = verses.map((v) => v['verse'] as int).toList()..sort();
  // 2026-05-19 (v1.2.58): use the shared `sanitizeForCopy` helper
  // (defined in lib/constants/text_patterns.dart) so the preview is
  // byte-for-byte identical to the real copy output produced by
  // bible_reading_pane.dart::copyVerses. v1.2.56's brace-content
  // fix had landed in sanitize but NOT in the three preview regexes
  // here — they kept stripping `{phrase}` entirely. Plus v1.2.57's
  // poetry `\n` was leaking through. One helper, one truth.
  List<String> textParts = verses.map((v) {
    return sanitizeForCopy(v['text'] as String);
  }).toList();

  // Build reference string
  List<String> ranges = [];
  for (int i = 0; i < verseNums.length;) {
    int start = verseNums[i];
    int end = start;
    while (i + 1 < verseNums.length && verseNums[i + 1] == end + 1) {
      end = verseNums[++i];
    }
    ranges.add(start == end ? '$start' : '$start–$end');
    i++;
  }

  final ref = '$book $chapter:${ranges.join(',')}';
  // 2026-05-17 (v1.2.48): devotional mode flows all verse text as
  // one continuous paragraph — user explicitly wants "all together,
  // not one verse per line". 灵修 / 抄经 style: text reads as a
  // single passage, then the reference in parens at the end. Same
  // change in bible_reading_pane.dart's real copy logic.
  final fullText = textParts.join(' ');
  return '$fullText\n($ref)';
}

/// Top-level page identifier for the dashboard / external surfaces
/// that want to deep-link into a specific settings section.
///
/// Currently only `account` is wired up (greeting-card profile tap →
/// Account / cloud-sync section), but adding more is mechanical: drop
/// a [GlobalKey] on the section header in [SettingsPage.build] and add
/// a case in [_SettingsPageBody._scrollToInitialSection].
enum SettingsSection {
  display,
  reading,
  account,
  notifications,
  // 2026-05-08 (v1.1.10): when an AI feature hits "quota exhausted"
  // (HTTP 429) the error UI now shows a button that deep-links here
  // so the user can paste their own Gemini key without hunting
  // through the Settings list.
  ai,
  about,
}

class SettingsPage extends StatelessWidget {
  /// When non-null, the page scrolls to that section on first build.
  /// Used by the dashboard greeting-card profile tap to land the user
  /// directly on Account / cloud-sync.
  final SettingsSection? initialSection;

  const SettingsPage({super.key, this.initialSection});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 300) {
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        // The settings locale is now available inside the Consumer below
        title: Consumer<AppSettings>(
          builder: (context, settings, _) =>
              Text(uiStrings['settings']?[settings.locale] ?? 'Settings'),
        ),
        actions: const [LanguageSwitcherButton(), HomeIconButton()],
      ),
      body: _SettingsPageBody(initialSection: initialSection),
    ),
    );
  }
}

/// Stateful body so we can hold the per-section keys + run a
/// post-frame `Scrollable.ensureVisible` when the page is opened with
/// a deep-link target. Keeps the StatelessWidget API intact for the
/// 99% of callers that just want plain Settings.
class _SettingsPageBody extends StatefulWidget {
  final SettingsSection? initialSection;
  const _SettingsPageBody({this.initialSection});

  @override
  State<_SettingsPageBody> createState() => _SettingsPageBodyState();
}

class _SettingsPageBodyState extends State<_SettingsPageBody> {
  final _displayKey = GlobalKey();
  final _readingKey = GlobalKey();
  final _accountKey = GlobalKey();
  final _notificationsKey = GlobalKey();
  final _aiKey = GlobalKey();
  final _aboutKey = GlobalKey();

  GlobalKey? _keyFor(SettingsSection? section) {
    switch (section) {
      case SettingsSection.display:
        return _displayKey;
      case SettingsSection.reading:
        return _readingKey;
      case SettingsSection.account:
        return _accountKey;
      case SettingsSection.notifications:
        return _notificationsKey;
      case SettingsSection.ai:
        return _aiKey;
      case SettingsSection.about:
        return _aboutKey;
      case null:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    final target = _keyFor(widget.initialSection);
    if (target == null) return;
    // Wait for the first frame so the target has a render box, then
    // smooth-scroll to it. Using ensureVisible keeps us inside the
    // existing ListView controller without us needing to manage one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = target.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        alignment: 0.05, // header just below the AppBar
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettings>(
        builder: (context, settings, _) {
          final mainProvider = Provider.of<MainProvider>(context);
          final currentBook = mainProvider.currentBook;
          final currentChapter = mainProvider.currentChapter;

          // 2026-06-16 (v1.3.87): exactly 7 swatches, each mapping 1:1 to one
          // of the 7 themed app icons (default-indigo, Red, Orange, Green,
          // Purple, Pink, Dark) via AppIconService.variantForColor — so every
          // pick predictably changes BOTH the theme AND the home-screen / dock
          // / favicon icon. Previously the picker offered 18 Material colours
          // that collapsed onto the same 7 icon buckets, so e.g. cyan /
          // light-blue silently mapped to the default icon → "why didn't my
          // icon change?". Order matches the README "Your theme, your icon"
          // row. Keep this list in lock-step with variantForColor's buckets.
          //
          // SeekSparks fork: swatch 0 is the app's own brand indigo (the
          // icon's gradient start colour) instead of YsWords' blue, so the
          // "default" pick matches the actual logo instead of clashing with
          // it.
          final List<Color> palette = [
            AppIconService.kDefaultPrimaryColor, // → default (indigo) icon
            Colors.red, // → AppIcon-Red
            Colors.orange, // → AppIcon-Orange
            Colors.green, // → AppIcon-Green
            Colors.purple, // → AppIcon-Purple
            Colors.pink, // → AppIcon-Pink
            Colors.blueGrey, // → AppIcon-Dark
          ];

          final versesInChapter = mainProvider.verses
              .where(
                  (v) => v.book == currentBook && v.chapter == currentChapter)
              .toList()
            ..sort((a, b) => a.verse.compareTo(b.verse));
          final verseSamples = versesInChapter
              .take(3)
              .map((v) => {'verse': v.verse, 'verseLabel': v.verseLabel, 'text': v.text})
              .toList();

          final dc = ResponsiveBreakpoints.classOf(
              MediaQuery.of(context).size.width);
          final maxW = ResponsiveBreakpoints.settingsMaxWidth(dc);
          final s = ResponsiveBreakpoints.spacingScale(dc);

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: ListView(
            padding: EdgeInsets.all(16 * s),
            children: [
              // Account section now FIRST — see comment below at the
              // old _accountKey location for the rationale.
              KeyedSubtree(
                key: _accountKey,
                child: _SectionHeader(
                    uiStrings['settingsSectionAccount']?[settings.locale] ??
                        'Account'),
              ),
              _AccountSection(settings: settings, s: s),
              SizedBox(height: 16 * s),
              KeyedSubtree(
                key: _displayKey,
                child: _SectionHeader(
                    uiStrings['settingsSectionDisplay']?[settings.locale] ??
                        'Display'),
              ),
              Card(
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16 * s, vertical: 12 * s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        uiStrings['fontSize']?[settings.locale] ?? 'Font Size',
                        style: TextStyle(
                          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                          fontSize: settings.fontSize + 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Slider(
                        value: settings.fontSize,
                        min: kFontSizeMin,
                        max: kFontSizeMax,
                        divisions: (kFontSizeMax - kFontSizeMin).round(),
                        label: '${settings.fontSize.toInt()} pt',
                        onChanged: (val) => settings.setFontSize(val),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16 * s),
              Card(
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16 * s, vertical: 12 * s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        uiStrings['menuScale']?[settings.locale] ?? 'Menu Size',
                        style: TextStyle(
                          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                          fontSize: settings.fontSize + 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Slider(
                        value: settings.menuScale,
                        min: kMenuScaleMin,
                        max: kMenuScaleMax,
                        divisions: ((kMenuScaleMax - kMenuScaleMin) * 10).round(),
                        label: '${settings.menuScale.toStringAsFixed(1)}x',
                        onChanged: (val) => settings.setMenuScale(val),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16 * s),
              Card(
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16 * s, vertical: 12 * s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        uiStrings['lineSpacing']?[settings.locale] ??
                            'Line Spacing',
                        style: TextStyle(
                          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                          fontSize: settings.fontSize + 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Slider(
                        value: settings.lineSpacing,
                        min: kLineSpacingMin,
                        max: kLineSpacingMax,
                        divisions:
                            ((kLineSpacingMax - kLineSpacingMin) * 10).round(),
                        label: settings.lineSpacing.toStringAsFixed(1),
                        onChanged: (val) => settings.setLineSpacing(
                            double.parse(val.toStringAsFixed(1))),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16 * s),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16 * s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        uiStrings['samplePreview']?[settings.locale] ??
                            'Sample Preview',
                        style: TextStyle(
                          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                          fontSize: settings.fontSize + 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 12 * s),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            uiStrings['copyFormat']?[settings.locale] ??
                                'Copy Format',
                            style: TextStyle(
                              fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                              fontSize: settings.fontSize + 2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8 * s),
                          DropdownButton<String>(
                            value: settings.copyFormat,
                            onChanged: (val) {
                              if (val != null) settings.setCopyFormat(val);
                            },
                            items: [
                              DropdownMenuItem(
                                  value: 'plain',
                                  child: Text(
                                    uiStrings['plainText']?[settings.locale] ??
                                        'Plain Text',
                                    style: TextStyle(
                                      fontSize: settings.fontSize,
                                      fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                                    ),
                                  )),
                              DropdownMenuItem(
                                  value: 'withRef',
                                  child: Text(
                                    uiStrings['withReference']
                                            ?[settings.locale] ??
                                        'With Reference',
                                    style: TextStyle(
                                      fontSize: settings.fontSize,
                                      fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                                    ),
                                  )),
                              DropdownMenuItem(
                                  value: 'devotional',
                                  child: Text(
                                    uiStrings['devotionalFormat']
                                            ?[settings.locale] ??
                                        'Devotional Format',
                                    style: TextStyle(
                                      fontSize: settings.fontSize,
                                      fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                                    ),
                                  )),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 12 * s),
                      Text(
                        currentBook != null && currentChapter != null
                            ? '$currentBook $currentChapter'
                            : uiStrings['noVersesAvailable']
                                    ?[settings.locale] ??
                                'No verses available',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: settings.fontSize,
                                ),
                      ),
                      SizedBox(height: 8 * s),
                      if (settings.copyFormat == 'devotional')
                        Padding(
                          padding:
                              EdgeInsets.only(bottom: settings.lineSpacing * 2),
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: settings.fontSize,
                                fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                                height: settings.lineSpacing,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color,
                              ),
                              children: [
                                TextSpan(
                                  text: getDevotionalFormattedText(verseSamples,
                                      currentBook, currentChapter),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...verseSamples.map((v) {
                          final label = v['verseLabel'] as String;
                          final ref =
                              '${currentBook ?? ''} $currentChapter:$label';
                          // 2026-05-19 (v1.2.58): switch the preview's
                          // ad-hoc regex pipeline to the shared
                          // `sanitizeForCopy` helper so the preview
                          // matches the real copy output byte-for-byte.
                          // Earlier regex chain stripped `{phrase}`
                          // entirely (the v1.2.56 brace bug that was
                          // only fixed in sanitize), and didn't strip
                          // `\n` (which v1.2.57 added to ~292 verses
                          // for poetry layout). Single helper, single
                          // truth.
                          final cleanText = sanitizeForCopy(v['text'] as String);
                          final headerText = settings.copyFormat == 'withRef'
                              ? '[$ref] '
                              : '';

                          return Padding(
                            padding: EdgeInsets.only(
                                bottom: settings.lineSpacing * 2),
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: settings.fontSize,
                                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                                  height: settings.lineSpacing,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color,
                                ),
                                children: [
                                  if (settings.copyFormat == 'plain') ...[
                                    TextSpan(
                                      text: '$label ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                    TextSpan(text: cleanText),
                                  ] else ...[
                                    TextSpan(text: '$headerText$cleanText'),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                      // Removed Copy Preview button and its padding
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16 * s),
              // Round 56: Style preset picker. Bundles font + size +
              // line spacing + menu scale + paragraph mode into
              // named one-tap presets (Classic / Modern / Reverent
              // / Compact / Reader). Sits at the top of Display so
              // users see it before manually tuning each setting.
              _StylePresetCard(settings: settings, s: s),
              SizedBox(height: 16 * s),
              Card(
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16 * s, vertical: 12 * s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        uiStrings['fontFamily']?[settings.locale] ??
                            'Font Family',
                        style: TextStyle(
                          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                          fontSize: settings.fontSize + 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 12 * s),
                      DropdownButton<String>(
                        value: settings.fontSelection,
                        isExpanded: true,
                        onChanged: (val) {
                          if (val != null) settings.setFontFamily(val);
                        },
                        // Each row physically renders in its own
                        // font via [previewTextStyle], so the user
                        // can compare options before picking. Every
                        // option is either a bundled asset or a
                        // system family that degrades to the engine
                        // default when not installed — nothing here
                        // is fetched at runtime.
                        items: [
                          for (final f in availableFontOptions())
                            DropdownMenuItem(
                              value: f.key,
                              child: Text(
                                f.labelFor(settings.locale),
                                style: previewTextStyle(
                                  f.key,
                                  TextStyle(
                                    fontSize: settings.fontSize,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 6 * s),
                      Text(
                        uiStrings['fontFamilyHint']?[settings.locale] ??
                            'Bundled fonts (Roboto, Microsoft YaHei) work everywhere. Other choices use the system fonts installed on your device.',
                        style: TextStyle(
                          fontSize:
                              settings.smallPrint(13),
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                          fontStyle: FontStyle.italic,
                          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16 * s),
              // Primary Color card - always visible (dark + light)
                Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 16 * s, vertical: 12 * s),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          uiStrings['primaryColor']?[settings.locale] ??
                              'Primary Color',
                          style: TextStyle(
                            fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                            fontSize: settings.fontSize + 2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 12 * s),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: palette.map((c) {
                            final isSelected = settings.primaryColor == c;
                            // Floor the avatar at ~22 dp so the swatch
                            // never falls below a comfortable tap
                            // target even when the user shrinks the
                            // font size to its minimum.
                            final avatarRadius =
                                (settings.fontSize * 0.8).clamp(20.0, 28.0);
                            return InkWell(
                              onTap: () => settings.setPrimaryColor(c),
                              child: Padding(
                                // Padding pushes the actual hit-test
                                // size up past 44 dp on every device
                                // class without changing the visual
                                // size of the swatch.
                                padding: const EdgeInsets.all(4),
                                child: Container(
                                  width: avatarRadius * 2,
                                  height: avatarRadius * 2,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: c,
                                    border: Border.all(
                                      color: isSelected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                          : Theme.of(context)
                                              .colorScheme
                                              .outlineVariant,
                                      width:
                                          isSelected ? 2 : WbMetrics.hairline,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Icon(Icons.check,
                                          color:
                                              c.computeLuminance() > 0.5
                                                  ? Colors.black
                                                  : Colors.white,
                                          size: settings.fontSize * 0.6)
                                      : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16 * s),
              SizedBox(height: 16 * s),
              KeyedSubtree(
                key: _readingKey,
                child: _SectionHeader(
                    uiStrings['settingsSectionReading']?[settings.locale] ??
                        'Reading'),
              ),
              Card(
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16 * s, vertical: 12 * s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        uiStrings['themeMode']?[settings.locale] ??
                            'Theme Mode',
                        style: TextStyle(
                          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                          fontSize: settings.fontSize + 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 12 * s),
                      DropdownButton<ThemeMode>(
                        value: settings.themeMode,
                        onChanged: (val) {
                          if (val != null) settings.setThemeMode(val);
                        },
                        items: [
                          DropdownMenuItem(
                            value: ThemeMode.system,
                            child: Text(
                              uiStrings['themeSystem']?[settings.locale] ??
                                  'System Default',
                              style: TextStyle(
                                fontSize: settings.fontSize,
                                fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.light,
                            child: Text(
                              uiStrings['themeDay']?[settings.locale] ?? 'Light Mode',
                              style: TextStyle(
                                fontSize: settings.fontSize,
                                fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.dark,
                            child: Text(
                              uiStrings['themeNight']?[settings.locale] ??
                                  'Dark Mode',
                              style: TextStyle(
                                fontSize: settings.fontSize,
                                fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16 * s),
              Card(
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16 * s, vertical: 12 * s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        uiStrings['readingMode']?[settings.locale] ??
                            'Reading Mode',
                        style: TextStyle(
                          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                          fontSize: settings.fontSize + 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 12 * s),
                      LayoutBuilder(
                        builder: (context, toggleConstraints) {
                          return ToggleButtons(
                            isSelected: [!settings.paragraphMode, settings.paragraphMode],
                            onPressed: (index) =>
                                settings.setParagraphMode(index == 1),
                            borderRadius: BorderRadius.zero,
                            constraints: BoxConstraints(
                              minHeight: 36,
                              minWidth: (toggleConstraints.maxWidth - 8) / 2,
                            ),
                            children: [
                              Text(
                                uiStrings['verseByVerse']?[settings.locale] ??
                                    'Verse by Verse',
                                style: TextStyle(
                                  fontSize: settings.fontSize * 0.9,
                                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                                ),
                              ),
                              Text(
                                uiStrings['paragraphFlow']?[settings.locale] ??
                                    'Paragraph Flow',
                                style: TextStyle(
                                  fontSize: settings.fontSize * 0.9,
                                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16 * s),
              // 2026-05-07 (v17): the "Offline Mode" toggle was
              // removed from this card. The bool was persisted in
              // SharedPreferences but never read by any other code
              // path -- a piece of dead UI that suggested the user
              // could opt out of network use, which was never true.
              // The Flutter web service worker decides what's cached;
              // the dedicated "Offline pack" card lower in this page
              // is the real "make this work without network" knob.
              Card(
                child: Column(
                  children: [
                    // 2026-08 (ported from YsWords v1.3.156): warm-paper
                    // reading theme, toggled independently of the app-wide
                    // ThemeMode above.
                    SwitchListTile(
                      title: Text(
                        uiStrings['readingPaperTheme']?[settings.locale] ??
                            'Paper reading theme',
                        style: TextStyle(
                          fontSize: settings.fontSize + 2,
                          fontWeight: FontWeight.w600,
                          fontFamily: settings.fontFamily,
                          fontFamilyFallback: kCjkFontFallback,
                        ),
                      ),
                      subtitle: Text(
                        uiStrings['readingPaperThemeSubtitle']
                                ?[settings.locale] ??
                            'Switch the reading pane to a warm, paper-like '
                                'background for more comfortable long '
                                'reading sessions.',
                        style: TextStyle(
                          fontSize: settings.fontSize,
                          fontFamily: settings.fontFamily,
                          fontFamilyFallback: kCjkFontFallback,
                        ),
                      ),
                      value: settings.readingPaperTheme,
                      onChanged: (val) => settings.setReadingPaperTheme(val),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: Text(
                        uiStrings['boldVerseText']?[settings.locale] ??
                            'Bold verse text',
                        style: TextStyle(
                          fontSize: settings.fontSize + 2,
                          fontWeight: FontWeight.w600,
                          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        ),
                      ),
                      subtitle: Text(
                        uiStrings['boldVerseTextSubtitle']?[settings.locale] ??
                            'Render scripture body text in semi-bold weight.',
                        style: TextStyle(
                          fontSize: settings.fontSize,
                          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        ),
                      ),
                      value: settings.boldVerseText,
                      onChanged: (val) => settings.setBoldVerseText(val),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: Text(
                        uiStrings['showSectionTitles']?[settings.locale] ??
                            'Section titles',
                        style: TextStyle(
                          fontSize: settings.fontSize + 2,
                          fontWeight: FontWeight.w600,
                          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        ),
                      ),
                      subtitle: Text(
                        uiStrings['showSectionTitlesSubtitle']
                                ?[settings.locale] ??
                            'Render paragraph headings (e.g. "The Sermon '
                                'on the Mount") above the verse.',
                        style: TextStyle(
                          fontSize: settings.fontSize,
                          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        ),
                      ),
                      value: settings.showSectionTitles,
                      onChanged: (val) => settings.setShowSectionTitles(val),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: Text(
                        uiStrings['showBookIntro']?[settings.locale] ??
                            'Book introductions',
                        style: TextStyle(
                          fontSize: settings.fontSize + 2,
                          fontWeight: FontWeight.w600,
                          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        ),
                      ),
                      subtitle: Text(
                        uiStrings['showBookIntroSubtitle']?[settings.locale] ??
                            'Show a collapsible card at the top of '
                                'chapter 1 with the book\'s author, '
                                'date, themes, and key passage.',
                        style: TextStyle(
                          fontSize: settings.fontSize,
                          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        ),
                      ),
                      value: settings.showBookIntro,
                      onChanged: (val) => settings.setShowBookIntro(val),
                    ),
                    // Round 56: removed the "Pick verse after
                    // chapter" toggle. The picker now always shows
                    // book → chapter → verse as 3-step grid flow,
                    // matching how YouVersion / Bible Hub etc. work
                    // and per user request: "选择节应该全部用 grid mode".
                    const Divider(height: 1),
                    SwitchListTile(
                      title: Text(
                        uiStrings['showStrongsBadge']?[settings.locale] ??
                            "Show Strong's number on word chips",
                        style: TextStyle(
                          fontSize: settings.fontSize + 2,
                          fontWeight: FontWeight.w600,
                          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        ),
                      ),
                      subtitle: Text(
                        uiStrings['showStrongsBadgeSubtitle']
                                ?[settings.locale] ??
                            "Display the G#### / H#### badge under each Hebrew/Greek word in the exegesis sheet.",
                        style: TextStyle(
                          fontSize: settings.fontSize,
                          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        ),
                      ),
                      value: settings.showStrongsInOriginals,
                      onChanged: (val) =>
                          settings.setShowStrongsInOriginals(val),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: Text(
                        uiStrings['autoExpandFirstRef']?[settings.locale] ??
                            'Auto-expand first verse group',
                        style: TextStyle(
                          fontSize: settings.fontSize + 2,
                          fontWeight: FontWeight.w600,
                          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        ),
                      ),
                      subtitle: Text(
                        uiStrings['autoExpandFirstRefSubtitle']
                                ?[settings.locale] ??
                            "Automatically open the first book group of concordance refs in the exegesis sheet.",
                        style: TextStyle(
                          fontSize: settings.fontSize,
                          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        ),
                      ),
                      value: settings.autoExpandFirstRef,
                      onChanged: (val) =>
                          settings.setAutoExpandFirstRef(val),
                    ),
                    // 2026-05-07 (v17): "Check for Updates" tile
                    // removed. It re-ran FetchVerses against the
                    // already-bundled assets and unconditionally
                    // showed "You're up to date", making it pure
                    // theatre. Real PWA updates are driven by the
                    // service worker (replaced on next reload), and
                    // the "Clear cache & reload" button further down
                    // this page already provides an honest force-
                    // refresh path.
                  ],
                ),
              ),
              SizedBox(height: 16 * s),
              _SectionHeader(
                  uiStrings['settingsSectionApp']?[settings.locale] ??
                      'App'),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16 * s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        uiStrings['interfaceLanguage']?[settings.locale] ??
                            'Interface Language',
                        style: TextStyle(
                          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                          fontSize: settings.fontSize + 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8 * s),
                      DropdownButton<String>(
                        value: settings.locale,
                        onChanged: (val) {
                          if (val != null) settings.setLocale(val);
                        },
                        items: [
                          DropdownMenuItem(
                            value: 'zh-Hans',
                            child: Text('简体中文',
                                style: TextStyle(
                                  fontSize: settings.fontSize,
                                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                                )),
                          ),
                          DropdownMenuItem(
                            value: 'zh-Hant',
                            child: Text('繁體中文',
                                style: TextStyle(
                                  fontSize: settings.fontSize,
                                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                                )),
                          ),
                          DropdownMenuItem(
                            value: 'en',
                            child: Text('English',
                                style: TextStyle(
                                  fontSize: settings.fontSize,
                                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                                )),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // 2026-05-06: Account section moved to TOP of Settings
              // (was after Display/Reading/App). User feedback: tapping
              // a profile chip on the dashboard navigates here, so
              // sync / sign-in controls should be the first thing they
              // see — not buried halfway down. Display/Reading/App
              // still come right after.
              // 2026-05-21 (v1.2.69): "Reading plans" section removed
              // along with the rest of the feature.
              // Round 56 day-3 (2026-05-06): the BYOK card was
              // briefly here at the top level, but the user wanted
              // "the app configures everything as long as I get
              // their permission" — i.e. zero AI setup for normal
              // users. The shared developer Gemini key already
              // covers AI features for everyone after sign-in, so
              // BYOK is purely an escape valve for power users / the
              // case when shared quota is exhausted. Moved the card
              // to AboutPage (Settings → About → Attributions &
              // licensing → bottom) so it stays discoverable without
              // cluttering the main Settings list.
              SizedBox(height: 16 * s),
              KeyedSubtree(
                key: _notificationsKey,
                child: _SectionHeader(
                    uiStrings['settingsSectionNotifications']
                            ?[settings.locale] ??
                        'Notifications'),
              ),
              _NotificationsCard(settings: settings, s: s),
              SizedBox(height: 16 * s),
              // 2026-05-08 (v1.1.9): BYOK Gemini-key card re-exposed.
              // The widget itself (lib/widgets/gemini_key_card.dart)
              // has been live the whole time, but on 2026-05-06 the
              // section was removed from the UI because the dev's
              // shared key was carrying everyone with no setup
              // friction. After 2026-05-08 the shared key started
              // hitting the Gemini free-tier 250-RPD ceiling for the
              // day; users who hit "AI quota exhausted" need a way
              // to drop in their own AI Studio key and keep working.
              // Putting it under its own "AI" section above About
              // so it's discoverable without crowding the daily-use
              // toggles further up.
              KeyedSubtree(
                key: _aiKey,
                child: _SectionHeader(
                    uiStrings['settingsSectionAi']?[settings.locale] ?? 'AI'),
              ),
              GeminiKeyCard(settings: settings, s: s),
              SizedBox(height: 12 * s),
              // 2026-05-10 (v1.2.26): AI model picker. Three tiers
              // mapped server-side to gemini-2.5-flash-lite (fast),
              // gemini-2.5-flash (balanced), gemini-2.5-pro (deep).
              // Defaults to fast — same model the server used pre-
              // v1.2.26 — so existing users see no behaviour change
              // unless they explicitly bump it.
              _AiModelCard(settings: settings, s: s),
              SizedBox(height: 12 * s),
              // 2026-05-24 (v1.3.19): _TtsVoiceCard removed with the
              // 朗读 feature.
              SizedBox(height: 16 * s),
              KeyedSubtree(
                key: _aboutKey,
                child: _SectionHeader(
                    uiStrings['settingsSectionAbout']?[settings.locale] ??
                        'About'),
              ),
              _AboutCard(settings: settings, s: s),
              // 2026-05-24 (v1.3.25): PWA install card — only shows
              // when the install affordance is meaningful (browser
              // not already in installed mode, native build hides
              // it entirely).
              const _InstallAppCard(),
              // 2026-05-24 (v1.3.26): export card — gives the user a
              // portable copy of their highlights / bookmarks / notes
              // in Markdown or JSON.
              const _ExportDataCard(),
              SizedBox(height: 12 * s),
              // 2026-08 (ported from YsWords v1.4.0): import card — the
              // reverse of the export above. Sits directly under it so
              // backup and restore read as one pair.
              const _ImportDataCard(),
              SizedBox(height: 16 * s),
            ],
              ),
            ),
          );
        },
    );
  }

  // 2026-05-07 (v17): _onCheckForUpdates() and _reloadVerses() were
  // removed. They were tied to a "Check for Updates" tile that
  // unconditionally said "You're up to date" -- the reload only
  // re-read the same bundled asset JSON. Real PWA updates ship via
  // service-worker replacement on next reload; the existing
  // "Clear cache & reload" button further down this page covers
  // any user-initiated force-refresh need. The app version is now
  // surfaced on the About page footer instead.
}

/// Settings card for picking a reading plan, choosing the start
/// date, and resetting completion progress. Lives at the bottom of
/// the settings list because it's an opt-in feature and most users
/// will never touch it.
class _AccountSection extends StatefulWidget {
  final AppSettings settings;
  final double s;
  const _AccountSection({required this.settings, required this.s});

  @override
  State<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<_AccountSection> {
  @override
  void initState() {
    super.initState();
    ProfileService.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    ProfileService.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final s = widget.s;
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;
    final p = ProfileService.instance.current;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16 * s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    uiStrings['profileTitle']?[locale] ?? 'Profiles',
                    style: TextStyle(
                      fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                      fontSize: settings.fontSize + 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8 * s),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ProfileAvatar(
                photoUrl: p.photoDataUrl,
                name: p.name,
                avatarColor: p.avatarColorArgb,
                radius: 22,
              ),
              title: Text(
                p.name,
                style: TextStyle(
                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                  fontSize: settings.fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                uiStrings["profileCurrent"]?[locale] ?? "Active profile",
                style: TextStyle(
                  fontSize: settings.fontSize - 2,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => pushPage(const ProfilesPage()),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                uiStrings['localOnlyDataNotice']?[locale] ??
                    'Highlights, notes and bookmarks stay on this '
                        'device. Use "Export my data" below to move '
                        'them to another one.',
                style: TextStyle(
                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                  fontSize: settings.smallPrint(13),
                  fontStyle: FontStyle.italic,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact uppercase section divider that sits above a group of
/// related cards in the settings list. Round 34 added these to
/// give the long settings list visual structure (Display / Reading
/// / App / Account / Reading plans) without forcing a refactor of
/// the existing card layout.
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The comment this replaces described a default of 16 pt and a cap
    // at 22; the default has been 20 for some time and the cap was
    // reached at 24, so a header stopped growing barely above the
    // default it was described from.
    final settings = context.watch<AppSettings>();
    final size = settings.smallPrint(18);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
          fontSize: size,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: scheme.primary,
        ),
      ),
    );
  }
}

/// Single switch row used by [_NotificationsCard]. Keeps font scaling
/// consistent with the rest of the settings page.
class _SettingsSwitch extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final AppSettings settings;

  const _SettingsSwitch({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.settings,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      secondary: Icon(icon, color: scheme.primary),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
          fontSize: settings.fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: (subtitle == null || subtitle!.isEmpty)
          ? null
          : Text(
              subtitle!,
              style: TextStyle(
                fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                fontSize: settings.smallPrint(14),
                color: scheme.onSurfaceVariant,
              ),
            ),
      value: value,
      onChanged: onChanged,
    );
  }
}


/// Notifications opt-in card. On web, toggling on prompts the
/// browser for permission via `Notification.requestPermission()`. On
/// non-web platforms (we don't ship them today), the row is hidden.
class _NotificationsCard extends StatefulWidget {
  final AppSettings settings;
  final double s;
  const _NotificationsCard({required this.settings, required this.s});

  @override
  State<_NotificationsCard> createState() => _NotificationsCardState();
}

class _NotificationsCardState extends State<_NotificationsCard> {
  bool _busy = false;

  Future<void> _toggle(bool v) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (v) {
        // Opting in — request browser permission first.
        if (!NotificationService.isSupported) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                uiStrings['notificationsUnsupported']
                        ?[widget.settings.locale] ??
                    "This browser doesn't support notifications.",
              ),
            ),
          );
          return;
        }
        final result = await NotificationService.requestPermission();
        if (result == NotificationPermission.granted) {
          await widget.settings.setNotificationsEnabled(true);
          if (!mounted) return;
          // Fire a confirmation notification so the user can see what
          // they look like.
          await NotificationService.show(
            title: uiStrings['appName']?[widget.settings.locale] ??
                "Yahweh's Swords",
            body: uiStrings['notificationsEnabledBody']
                    ?[widget.settings.locale] ??
                'Notifications are on. You\'ll get gentle daily reminders.',
            tag: 'seeksparks-confirm',
          );
        } else {
          await widget.settings.setNotificationsEnabled(false);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                uiStrings['notificationsDenied']
                        ?[widget.settings.locale] ??
                    'Browser denied notification permission. Allow notifications in your browser settings to enable.',
              ),
            ),
          );
        }
      } else {
        await widget.settings.setNotificationsEnabled(false);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final locale = settings.locale;
    final supported = NotificationService.isSupported;
    final perm = NotificationService.permission;
    final scheme = Theme.of(context).colorScheme;

    final hint = !supported
        ? (uiStrings['notificationsUnsupported']?[locale] ??
            "This browser doesn't support notifications.")
        : perm == NotificationPermission.denied
            ? (uiStrings['notificationsBlocked']?[locale] ??
                'Permission blocked at the browser level. Re-enable in browser settings, then toggle on here.')
            : (uiStrings['notificationsHint']?[locale] ??
                'Get gentle daily reminders for verse, reading, and news.');

    return Card(
      child: Padding(
        padding: EdgeInsets.fromLTRB(8 * widget.s, 4 * widget.s,
            8 * widget.s, 4 * widget.s),
        child: Column(
          children: [
            _SettingsSwitch(
              icon: Icons.notifications_active_outlined,
              label: uiStrings['notificationsToggle']?[locale] ??
                  'Enable notifications',
              subtitle: hint,
              value: settings.notificationsEnabled &&
                  perm == NotificationPermission.granted,
              onChanged: (supported &&
                      perm != NotificationPermission.denied &&
                      !_busy)
                  ? _toggle
                  : (_) {}, // ignore on unsupported / denied
              settings: settings,
            ),
            if (settings.notificationsEnabled &&
                perm == NotificationPermission.granted)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      // 2026-05-22 (v1.2.71): show in-app feedback for
                      // the test action so user sees something even if
                      // the OS-level notification is suppressed (focus
                      // mode, banner setting = none, etc.). The actual
                      // notification fires regardless via the plugin
                      // below — the SnackBar is just a UX
                      // confirmation that we DID send it.
                      //
                      // v1.3.25: capture the messenger BEFORE the
                      // await so `context` isn't reused after the
                      // async gap. Also closes the
                      // `use_build_context_synchronously` info lint
                      // that previously forced CI to run with
                      // `--no-fatal-infos`.
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await NotificationService.show(
                          title: uiStrings['appName']?[locale] ?? "Yahweh's Swords",
                          body: uiStrings['notificationsTestBody']
                                  ?[locale] ??
                              'This is a test notification.',
                          tag: 'seeksparks-test',
                        );
                        if (!mounted) return;
                        // 2026-06-18 (v1.3.89): name the ACTUAL platform in
                        // the hint — the old text hardcoded "iOS Settings"
                        // on every device (the localized key didn't even
                        // exist, so it always hit that English fallback).
                        final plat = kIsWeb
                            ? (uiStrings['platformBrowser']?[locale] ??
                                'browser')
                            : (defaultTargetPlatform == TargetPlatform.iOS
                                ? 'iOS'
                                : defaultTargetPlatform ==
                                        TargetPlatform.android
                                    ? 'Android'
                                    : defaultTargetPlatform ==
                                            TargetPlatform.macOS
                                        ? 'macOS'
                                        : defaultTargetPlatform ==
                                                TargetPlatform.windows
                                            ? 'Windows'
                                            : defaultTargetPlatform ==
                                                    TargetPlatform.linux
                                                ? 'Linux'
                                                : (uiStrings['platformDevice']
                                                        ?[locale] ??
                                                    'device'));
                        final sentMsg = (uiStrings['notificationsTestSent']
                                    ?[locale] ??
                                "Test notification sent. If you don't see a "
                                    'banner, check your {platform} '
                                    'notification settings for SeekSparks (or '
                                    'Focus / Do Not Disturb).')
                            .replaceAll('{platform}', plat);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(sentMsg),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Test notification failed: $e',
                            ),
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    },
                    icon: Icon(Icons.send_outlined,
                        size: 16, color: scheme.primary),
                    label: Text(
                      uiStrings['notificationsTest']?[locale] ??
                          'Send test notification',
                      style: TextStyle(
                        fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                        fontSize:
                            settings.smallPrint(14),
                      ),
                    ),
                  ),
                ),
              ),
            // 2026-05-24 (v1.3.0): per-category notification rows.
            // Each row: enable toggle + tap-to-pick time. Shows only
            // when the master toggle is on AND OS permission is
            // granted (because disabled rows would just confuse).
            if (settings.notificationsEnabled &&
                perm == NotificationPermission.granted) ...[
              const SizedBox(height: 8),
              _NotificationCategoriesSection(settings: settings),
            ],
          ],
        ),
      ),
    );
  }
}

/// 2026-05-24 (v1.3.0): list of per-category notification toggles +
/// time pickers. Renders one ListTile per category in
/// NotificationCategoryIds.phase1. Tapping the trailing time chip
/// opens a TimePicker; toggling the leading switch flips
/// .enabled. Both call AppSettings.setNotificationCategory which
/// reschedules via NotificationScheduler.
class _NotificationCategoriesSection extends StatelessWidget {
  final AppSettings settings;

  const _NotificationCategoriesSection({required this.settings});

  String _categoryLabel(String id, String locale) {
    switch (id) {
      case NotificationCategoryIds.dailyVerse:
        return locale.startsWith('zh') ? '每日经文' : 'Daily verse';
      case NotificationCategoryIds.bibleEvidence:
        return locale.startsWith('zh') ? '圣经考证' : 'Bible evidence';
      case NotificationCategoryIds.sermonOfDay:
        return locale.startsWith('zh') ? '今日讲道' : 'Sermon of the day';
      case NotificationCategoryIds.newsDigest:
        return locale.startsWith('zh') ? '新闻摘要' : 'News digest';
      case NotificationCategoryIds.memoryVerse:
        return locale.startsWith('zh') ? '晚安经文' : 'Bedtime verse';
      default:
        return id;
    }
  }

  IconData _categoryIcon(String id) {
    switch (id) {
      case NotificationCategoryIds.dailyVerse:
        return Icons.menu_book_rounded;
      case NotificationCategoryIds.bibleEvidence:
        return Icons.travel_explore_rounded;
      case NotificationCategoryIds.sermonOfDay:
        return Icons.podcasts_rounded;
      case NotificationCategoryIds.newsDigest:
        return Icons.newspaper_rounded;
      case NotificationCategoryIds.memoryVerse:
        return Icons.nightlight_round;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _formatTime(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(
      BuildContext context, String categoryId) async {
    final current = settings.notificationCategory(categoryId);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: settings.locale.startsWith('zh') ? '选择推送时间' : 'Pick time',
    );
    if (picked == null) return;
    await settings.setNotificationCategory(
      categoryId,
      current.copyWith(hour: picked.hour, minute: picked.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: Text(
            locale.startsWith('zh')
                ? '推送品类（点击编辑时间）'
                : 'Categories (tap a row to set the time)',
            style: TextStyle(
              fontSize: settings.smallPrint(13),
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...NotificationCategoryIds.phase1.map((id) {
          final prefs = settings.notificationCategory(id);
          // 2026-05-24 (v1.3.1): explicit time-edit chip instead of
          // tap-the-whole-row. User reported "时间应该可以改的" — they
          // didn't realise the row was tappable. The chip below has
          // an edit icon, a focused tappable target, and the local
          // time hint so it's unambiguous.
          return Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Icon(_categoryIcon(id),
                    color: prefs.enabled
                        ? scheme.primary
                        : scheme.onSurfaceVariant),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _categoryLabel(id, locale),
                    style: TextStyle(
                      fontFamily: settings.fontFamily,
                      fontFamilyFallback: kCjkFontFallback,
                      fontSize: settings.fontSize - 1,
                      fontWeight: prefs.enabled
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                // Tappable time chip — clearly an editable affordance.
                ActionChip(
                  avatar: Icon(Icons.access_time_rounded,
                      size: 16, color: scheme.primary),
                  label: Text(
                    _formatTime(prefs.hour, prefs.minute),
                    style: TextStyle(
                      fontSize: settings.smallPrint(14),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () => _pickTime(context, id),
                  tooltip: locale.startsWith('zh')
                      ? '点击修改本地时间'
                      : 'Tap to edit (local time)',
                ),
                const SizedBox(width: 8),
                Switch(
                  value: prefs.enabled,
                  onChanged: (v) async {
                    await settings.setNotificationCategory(
                      id,
                      prefs.copyWith(enabled: v),
                    );
                  },
                ),
              ],
            ),
          );
        }),
        // Help text: clarify times are local + when fires happen.
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Text(
            locale.startsWith('zh')
                ? '所有时间为本地时间。设置改动后立即重排，每天到点自动推送。'
                : 'Times are local. Changes apply immediately; '
                    'fires daily at the chosen time.',
            style: TextStyle(
              fontSize: settings.smallPrint(12),
              color: scheme.onSurfaceVariant
                  .withValues(alpha: 0.8),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}


/// Settings → About — app name, version line, and the unified
/// ContactLine. Lives at the bottom of the Settings list.
/// 2026-05-10 (v1.2.26): AI response-depth picker. Three tiers
/// mapped server-side to gemini-2.5-flash-lite / flash / pro.
/// Lives just below the BYOK card so the two AI-related cards
/// stay grouped. Renders as a SegmentedButton — most discoverable
/// way to surface "pick one of three" without opening a dialog.
class _AiModelCard extends StatelessWidget {
  final AppSettings settings;
  final double s;
  const _AiModelCard({required this.settings, required this.s});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;
    return Card(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16 * s, 14 * s, 16 * s, 14 * s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.psychology_outlined,
                    size: 18, color: scheme.primary),
                SizedBox(width: 8 * s),
                Text(
                  uiStrings['aiModelTitle']?[locale] ??
                      'AI response depth',
                  style: TextStyle(
                    fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                    fontSize: settings.smallPrint(16),
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6 * s),
            Text(
              uiStrings['aiModelBody']?[locale] ??
                  'Choose the trade-off between AI speed and depth.',
              style: TextStyle(
                fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                fontSize: settings.smallPrint(13),
                color: scheme.onSurface.withValues(alpha: 0.78),
                height: 1.5,
              ),
            ),
            SizedBox(height: 10 * s),
            // 2026-05-11 (v1.2.40): Deep tier is now backed by
            // `gemini-3-flash-preview` (free-tier compatible thinking
            // model) instead of `gemini-2.5-pro` (which Google moved
            // behind a paywall on April 1 2026). The v1.2.39 BYOK
            // gating is no longer needed — every tier works on the
            // free tier without BYOK. Re-enabled the Deep segment;
            // dropped the lock icon + locked-note. BYOK is still
            // recommended for users who hit Deep's higher RPD limit
            // (the BYOK card sits below this card with that pitch).
            Center(
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment<String>(
                    value: 'flash-lite',
                    label: Text(
                      uiStrings['aiModelFast']?[locale] ?? 'Fast',
                    ),
                    icon: const Icon(Icons.bolt_outlined),
                  ),
                  ButtonSegment<String>(
                    value: 'flash',
                    label: Text(
                      uiStrings['aiModelStandard']?[locale] ?? 'Standard',
                    ),
                    icon: const Icon(Icons.balance_outlined),
                  ),
                  ButtonSegment<String>(
                    value: 'pro',
                    label: Text(
                      uiStrings['aiModelDeep']?[locale] ?? 'Deep',
                    ),
                    icon: const Icon(Icons.psychology_alt_outlined),
                  ),
                ],
                selected: {settings.aiModel},
                onSelectionChanged: (selection) {
                  if (selection.isNotEmpty) {
                    settings.setAiModel(selection.first);
                  }
                },
              ),
            ),
            SizedBox(height: 12 * s),
            // 2026-05-10 (v1.2.27): per-tier detail panel — updates
            // when user picks a different option. Names the actual
            // Gemini model, marks the default, calls out free-tier
            // quota reality so users know when to BYOK before
            // hitting "quota exhausted".
            _AiModelDetailPanel(
                aiModel: settings.aiModel,
                settings: settings,
                scheme: scheme,
                s: s),
          ],
        ),
      ),
    );
  }
}


/// Detail card that updates with the user's currently-selected AI
/// tier. Subtle filled background so it reads as informational
/// (not a warning) but stays distinct from the parent card.
class _AiModelDetailPanel extends StatelessWidget {
  final String aiModel;
  final AppSettings settings;
  final ColorScheme scheme;
  final double s;
  const _AiModelDetailPanel({
    required this.aiModel,
    required this.settings,
    required this.scheme,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    final locale = settings.locale;
    final detailKey = switch (aiModel) {
      'flash' => 'aiModelStandardDetail',
      'pro' => 'aiModelDeepDetail',
      _ => 'aiModelFastDetail',
    };
    final detailEnFallback = switch (aiModel) {
      'flash' =>
          'Standard · Gemini 2.5 Flash. Balanced speed and depth.',
      'pro' =>
          'Deep · Gemini 2.5 Pro. Most thorough analysis, smallest free-tier quota — BYOK recommended.',
      _ => 'Fast (default) · Gemini 2.5 Flash-Lite. Quickest answers, largest free-tier quota.',
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 10 * s),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border:
            Border.all(color: scheme.outlineVariant, width: WbMetrics.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 16, color: scheme.primary.withValues(alpha: 0.85)),
          SizedBox(width: 8 * s),
          Expanded(
            // 2026-05-11 (v1.2.38): the tier-detail strings include
            // markdown emphasis (`**Free-tier quota is tiny**` etc.)
            // so users could see the trade-offs at a glance. Render
            // through the shared markdown parser instead of the
            // raw `Text(...)` so the asterisks resolve to actual
            // bold spans.
            child: Text.rich(
              TextSpan(
                children: parseAiMarkdown(
                  uiStrings[detailKey]?[locale] ?? detailEnFallback,
                  base: TextStyle(
                    fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                    fontSize: settings.smallPrint(13),
                    color: scheme.onSurface.withValues(alpha: 0.78),
                    height: 1.55,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  final AppSettings settings;
  final double s;
  const _AboutCard({required this.settings, required this.s});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;
    return Card(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16 * s, 14 * s, 16 * s, 8 * s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu_book_rounded,
                    color: scheme.primary,
                    size: settings.fontSize + 4),
                SizedBox(width: 8 * s),
                Text(
                  uiStrings['appName']?[locale] ?? 'SeekSparks',
                  style: TextStyle(
                    fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                    fontSize: settings.fontSize + 2,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4 * s),
            Text(
              uiStrings['appTagline']?[locale] ??
                  'A bilingual Bible study app.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                fontSize: settings.smallPrint(14),
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(height: 4 * s),
            // 2026-06-29: surface the running version HERE on the Settings
            // About card. It used to live ONLY on the AboutPage sub-page (its
            // app-bar title + a footer buried under a long scroll), so a user
            // on the Settings screen saw no version at all — reported as
            // "version number not showing" on the Mi Pad. kAppVersion is
            // guarded against a blank dart-define, so this never renders empty.
            Text(
              'v$kAppVersion',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: settings.fontFamily,
                fontFamilyFallback: kCjkFontFallback,
                fontSize: settings.smallPrint(14),
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 6 * s),
            const ContactLine(),
            SizedBox(height: 8 * s),
            // Round 56 day-3 (2026-05-06): button into the full
            // Attributions / Licensing / Takedown page. Copyright
            // audit prompted listing every bundled third-party
            // resource + per-item licence + a prominent takedown
            // contact, which doesn't fit on the existing _AboutCard.
            OutlinedButton.icon(
              icon: const Icon(Icons.gavel_rounded, size: 18),
              label: Text(
                uiStrings['aboutOpenButton']?[locale] ??
                    'Attributions & licensing',
              ),
              onPressed: () => pushPage(const AboutPage()),
            ),
            SizedBox(height: 10 * s),
            // Clear-cache button — wipes service workers + browser
            // Cache Storage + the build-stamp localStorage entry,
            // then reloads. Local profile data (highlights / notes /
            // bookmarks in SharedPreferences / IndexedDB) is NOT
            // touched. Useful when the app is stuck on a stale
            // build and the automatic kill-switch reload didn't
            // catch it.
            OutlinedButton.icon(
              icon: const Icon(Icons.cleaning_services_outlined, size: 18),
              label: Text(
                uiStrings['clearCache']?[locale] ??
                    'Clear cache & reload',
              ),
              onPressed: () => _confirmClearCache(context, locale),
            ),
            SizedBox(height: 4 * s),
            Text(
              uiStrings['clearCacheNote']?[locale] ??
                  'Wipes browser cache + service workers. Your profile '
                      'data (highlights, notes, bookmarks) stays put.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                fontSize: settings.smallPrint(13),
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(height: 16 * s),
            // ── Offline Pack (Round 56) ─────────────────────────
            // Bulk pre-fetch every Bible / sermon / tool the user
            // checks so the app launches instantly + works without
            // network. Lives in its own card section because the
            // download flow (categories + progress + clear) needs
            // its own state surface.
            _OfflinePackCard(settings: settings, s: s),
            SizedBox(height: 12 * s),
            // Show-tour-again — clears the v2 onboarding-seen flag and
            // immediately shows the dialog so the user can re-walk the
            // 5-slide tour without leaving Settings. Useful for users
            // who skipped the tour on first run.
            OutlinedButton.icon(
              icon: const Icon(Icons.school_outlined, size: 18),
              label: Text(
                uiStrings['showTourAgain']?[locale] ?? 'Show tour again',
              ),
              onPressed: () => _showTour(context, locale),
            ),
            SizedBox(height: 12 * s),
            // Reset settings — wipes visual / preference state back to
            // defaults but leaves user CONTENT alone. Locale is also
            // preserved so we don't yank the user out of their language.
            // Wrapped in a confirm dialog because there's no undo.
            OutlinedButton.icon(
              icon: Icon(Icons.restart_alt_rounded,
                  size: 18, color: scheme.error),
              label: Text(
                uiStrings['resetSettings']?[locale] ?? 'Reset settings',
                style: TextStyle(color: scheme.error),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
              ),
              onPressed: () => _confirmResetSettings(context, locale),
            ),
            SizedBox(height: 4 * s),
            Text(
              uiStrings['resetSettingsNote']?[locale] ??
                  'Restores fonts, theme, color, dashboard layout, and '
                      'other preferences. Your bookmarks, notes, '
                      'highlights, profile, and language are kept.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                fontSize: settings.smallPrint(13),
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTour(BuildContext context, String locale) async {
    // Clear the seen flag first so subsequent dashboard mounts also
    // pick it up; then immediately show the dialog inline.
    await OnboardingDialog.markUnseen();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const OnboardingDialog(),
    );
  }

  Future<void> _confirmResetSettings(
      BuildContext context, String locale) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(uiStrings['resetSettings']?[locale] ?? 'Reset settings'),
        content: Text(
          uiStrings['resetSettingsConfirm']?[locale] ??
              'This restores fonts, theme, color, dashboard layout, '
                  'and other preferences. Your bookmarks, notes, '
                  'highlights, profile, and language stay the same. '
                  'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(uiStrings['cancel']?[locale] ?? 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogCtx).colorScheme.error,
              foregroundColor: Theme.of(dialogCtx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child:
                Text(uiStrings['resetSettings']?[locale] ?? 'Reset settings'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await settings.resetAllSettings();
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(uiStrings['resetSettingsDone']?[locale] ??
          'Settings restored to defaults.'),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _confirmClearCache(
      BuildContext context, String locale) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          uiStrings['clearCacheTitle']?[locale] ?? 'Clear cache & reload?',
        ),
        content: Text(
          uiStrings['clearCacheBody']?[locale] ??
              'This will unregister the service worker, delete browser '
                  'caches, and reload the app. Your highlights, notes '
                  'and bookmarks are stored separately and will not be '
                  'cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(uiStrings['cancel']?[locale] ?? 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(uiStrings['clearCache']?[locale] ?? 'Clear cache'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // The heavy lifting (unregister service workers, delete Cache
    // Storage entries, clear the build-stamp, reload) lives in
    // web/index.html as window.seekSparksClearCacheAndReload(). The
    // Dart side just calls it.
    if (kIsWeb) clearCacheAndReload();
  }
}

// 2026-05-20 (v1.2.67): the `@JS('seekSparksClearCacheAndReload')`
// binding was here. Moved to `lib/utils/clear_cache_helper.dart`
// (conditional export — web stub + native no-op) so this file
// compiles on iOS / Android. Same UX, same web behaviour.

/// Round 56: Style-preset picker card. One-tap bundles of
/// fontFamily / fontSize / lineSpacing / menuScale /
/// paragraphMode for users who want a coordinated look without
/// tuning each setting individually.
class _StylePresetCard extends StatelessWidget {
  final AppSettings settings;
  final double s;
  const _StylePresetCard({required this.settings, required this.s});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;
    final active = detectActivePreset(settings);
    return Card(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 12 * s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(4 * s, 0, 4 * s, 6 * s),
              child: Text(
                uiStrings['stylePresetTitle']?[locale] ?? 'Style preset',
                style: TextStyle(
                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                  fontSize: settings.fontSize + 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(4 * s, 0, 4 * s, 10 * s),
              child: Text(
                active == null
                    ? (uiStrings['stylePresetCustom']?[locale] ??
                        'Custom — manually tuned settings')
                    : (uiStrings['stylePresetActive']?[locale] ??
                            'Active: {name}')
                        .replaceAll(
                            '{name}',
                            uiStrings[
                                        'stylePreset_${active.name}_label']
                                    ?[locale] ??
                                active.name),
                style: TextStyle(
                  fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                  fontSize: settings.smallPrint(13),
                  color: scheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            ...AppStylePreset.values.map((preset) {
              final selected = preset == active;
              final label = uiStrings['stylePreset_${preset.name}_label']
                      ?[locale] ??
                  preset.name;
              final desc = uiStrings[
                      'stylePreset_${preset.name}_description']?[locale] ??
                  '';
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 2 * s),
                child: Material(
                  color: selected
                      ? scheme.primaryContainer.withValues(alpha: 0.55)
                      : scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.zero,
                  child: InkWell(
                    borderRadius: BorderRadius.zero,
                    onTap: () => preset.apply(settings),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: selected
                                  ? scheme.primary
                                  : scheme.surfaceContainerHighest,
                            ),
                            child: Icon(
                              preset.icon,
                              size: 20,
                              color: selected
                                  ? scheme.onPrimary
                                  : scheme.onSurface
                                      .withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                                    fontSize:
                                        settings.smallPrint(18),
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                if (desc.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    desc,
                                    style: TextStyle(
                                      fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
                                      fontSize: settings.smallPrint(13),
                                      color: scheme.onSurface
                                          .withValues(alpha: 0.7),
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (selected)
                            Icon(Icons.check_rounded,
                                color: scheme.primary, size: 22),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Settings → About → "Offline Pack" card. Bulk pre-fetches the
/// content the user wants available offline (Bibles / Sermons /
/// Tools). Once downloaded, the app launches instantly + works
/// without network — Service Worker serves cached responses.
///
/// Three checkboxes (Bibles / Sermons / Tools) so the user can
/// pick a subset; default selection is all three for a one-click
/// "make this offline" experience.
class _OfflinePackCard extends StatefulWidget {
  final AppSettings settings;
  final double s;
  const _OfflinePackCard({required this.settings, required this.s});

  @override
  State<_OfflinePackCard> createState() => _OfflinePackCardState();
}

class _OfflinePackCardState extends State<_OfflinePackCard> {
  // Default: every category checked. User can uncheck before
  // hitting Download. Adding `originals` + `maps` (introduced
  // 2026-05) means a fresh download truly covers every offline-
  // capable feature instead of leaving exegesis + maps broken.
  final Set<OfflinePackCategory> _selected = {
    OfflinePackCategory.bibles,
    OfflinePackCategory.sermons,
    OfflinePackCategory.tools,
    OfflinePackCategory.originals,
    OfflinePackCategory.maps,
  };

  /// Tracks whether we've already shown the "✓ Offline pack ready"
  /// snackbar for the current `lastCompletedAt` timestamp. Without
  /// this guard the snackbar fires every rebuild.
  DateTime? _ackedCompletion;

  @override
  void initState() {
    super.initState();
    OfflinePackService.instance.addListener(_onChanged);
    // Pre-acknowledge whatever was already complete on entry so we
    // don't flash the "ready" snackbar for a download that
    // completed in a previous session.
    _ackedCompletion = OfflinePackService.instance.lastCompletedAt;
  }

  @override
  void dispose() {
    OfflinePackService.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    // Surface a brief success snackbar the first time we see a
    // fresh completion timestamp. User feedback (Round 56):
    // "after downloading how do i know it's done — no green tick
    // or anything".
    final svc = OfflinePackService.instance;
    final ts = svc.lastCompletedAt;
    if (!svc.downloading && ts != null && ts != _ackedCompletion) {
      _ackedCompletion = ts;
      final locale = widget.settings.locale;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                uiStrings['offlinePackDoneToast']?[locale] ??
                    'Offline pack ready — the app now works without network.',
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  String _categoryLabel(OfflinePackCategory c, String locale) {
    switch (c) {
      case OfflinePackCategory.bibles:
        return uiStrings['offlinePackBibles']?[locale] ?? 'Bibles';
      case OfflinePackCategory.sermons:
        return withPreacher(
            uiStrings['offlinePackSermons']?[locale] ??
                'Sermons by {name} (289 × 3 languages)',
            locale);
      case OfflinePackCategory.tools:
        return uiStrings['offlinePackTools']?[locale] ?? 'Tools & references';
      case OfflinePackCategory.originals:
        return uiStrings['offlinePackOriginals']?[locale] ??
            'Originals (Strong\'s + interlinear)';
      case OfflinePackCategory.maps:
        return uiStrings['offlinePackMaps']?[locale] ??
            'Bible-history maps (images)';
    }
  }

  String _statusLine(String locale, OfflinePackService svc) {
    if (svc.downloading) {
      final pct = (svc.progress * 100).clamp(0, 100).round();
      // 2026-05-07: include "files" unit so "1885 / 2063" reads as
      // "1885 / 2063 files" — user feedback was that the bare
      // number didn't communicate what was being measured. Plus
      // append a localized ETA ("~30 sec left") once we have
      // enough samples to compute a stable rate (see etaSeconds).
      final tmpl = uiStrings['offlinePackDownloading']?[locale] ??
          'Downloading… {done}/{total} files ({pct}%){eta}';
      String etaPart = '';
      final eta = svc.etaSeconds;
      if (eta != null && eta > 0) {
        final etaText = _formatEta(eta, locale);
        etaPart = (uiStrings['offlinePackEtaSuffix']?[locale] ??
                ' · ~{eta} left')
            .replaceAll('{eta}', etaText);
      }
      return tmpl
          .replaceAll('{done}', '${svc.done}')
          .replaceAll('{total}', '${svc.total}')
          .replaceAll('{pct}', '$pct')
          .replaceAll('{eta}', etaPart);
    }
    if (svc.lastCompletedAt != null && svc.lastDownloaded.isNotEmpty) {
      final cats = svc.lastDownloaded
          .map((c) => _categoryLabel(c, locale))
          .join(' · ');
      final tmpl = uiStrings['offlinePackReady']?[locale] ??
          'Ready offline · {categories}';
      return tmpl.replaceAll('{categories}', cats);
    }
    return uiStrings['offlinePackHint']?[locale] ??
        'Pre-download Bibles, sermons, and tools so the app launches instantly and works without network.';
  }

  /// 2026-05-07: format ETA for the offline-pack download status.
  /// "less than 10 sec" / "~30 sec" / "~2 min" / "~5 min". We round
  /// generously so users don't see jitter (e.g. 27s → 35s → 22s
  /// flickering). All three locales supported.
  String _formatEta(int sec, String locale) {
    final isZh = locale.startsWith('zh');
    if (sec < 10) {
      return isZh ? '不到 10 秒' : 'less than 10 sec';
    }
    if (sec < 60) {
      // round to nearest 10 seconds for stability
      final rounded = ((sec + 5) ~/ 10) * 10;
      return isZh ? '$rounded 秒' : '$rounded sec';
    }
    if (sec < 3600) {
      final mins = (sec / 60).round();
      return isZh ? '$mins 分钟' : '$mins min';
    }
    final hrs = (sec / 3600).round();
    return isZh ? '$hrs 小时' : '$hrs hr';
  }

  int _selectedTotalMb() {
    final svc = OfflinePackService.instance;
    return _selected.fold<int>(0, (sum, c) => sum + svc.approximateMbFor(c));
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.settings.locale;
    final scheme = Theme.of(context).colorScheme;
    final svc = OfflinePackService.instance;
    final s = widget.s;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.45),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
          width: WbMetrics.hairline,
        ),
      ),
      padding: EdgeInsets.fromLTRB(12 * s, 10 * s, 12 * s, 10 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_download_outlined,
                  size: 18, color: scheme.primary),
              SizedBox(width: 8 * s),
              Expanded(
                child: Text(
                  uiStrings['offlinePackTitle']?[locale] ?? 'Offline pack',
                  style: TextStyle(
                    fontFamily: widget.settings.fontFamily,
                    fontSize: widget.settings.smallPrint(17),
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4 * s),
          // Status line. When a completed download exists we prepend
          // a green check icon so "Ready offline" reads as a
          // positive state, not just another italic line.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!svc.downloading &&
                  svc.lastCompletedAt != null &&
                  svc.lastDownloaded.isNotEmpty) ...[
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  // Theme-aware green: paletteAccent gives shade700
                  // light, shade300 dark — visible in both modes.
                  color: paletteAccent(context, Colors.green),
                ),
                SizedBox(width: 6 * s),
              ],
              Expanded(
                child: Text(
                  _statusLine(locale, svc),
                  style: TextStyle(
                    fontFamily: widget.settings.fontFamily,
                    fontSize:
                        widget.settings.smallPrint(13),
                    color: !svc.downloading &&
                            svc.lastCompletedAt != null &&
                            svc.lastDownloaded.isNotEmpty
                        // Same fix for the "Ready offline" status text.
                        ? paletteFg(context, Colors.green)
                        : scheme.onSurface.withValues(alpha: 0.7),
                    fontStyle: svc.downloading
                        ? FontStyle.normal
                        : (svc.lastCompletedAt != null
                            ? FontStyle.normal
                            : FontStyle.italic),
                    fontWeight: !svc.downloading &&
                            svc.lastCompletedAt != null &&
                            svc.lastDownloaded.isNotEmpty
                        ? FontWeight.w600
                        : FontWeight.normal,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          // Live progress bar while downloading.
          if (svc.downloading) ...[
            SizedBox(height: 8 * s),
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: LinearProgressIndicator(
                value: svc.progress,
                minHeight: 4,
                backgroundColor:
                    scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
              ),
            ),
            if (svc.failed > 0) ...[
              SizedBox(height: 4 * s),
              Text(
                (uiStrings['offlinePackSomeFailed']?[locale] ??
                        '{n} files skipped (will retry on next download).')
                    .replaceAll('{n}', '${svc.failed}'),
                style: TextStyle(
                  fontFamily: widget.settings.fontFamily,
                  fontSize:
                      widget.settings.smallPrint(12),
                  color: scheme.error,
                ),
              ),
            ],
          ],
          SizedBox(height: 8 * s),
          // Category checkboxes (hidden during download to keep the
          // card calm).
          if (!svc.downloading)
            ...OfflinePackCategory.values.map((c) {
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                visualDensity: VisualDensity.compact,
                title: Text(
                  _categoryLabel(c, locale),
                  style: TextStyle(
                    fontFamily: widget.settings.fontFamily,
                    fontSize: widget.settings.smallPrint(15),
                  ),
                ),
                subtitle: Text(
                  '~${svc.approximateMbFor(c)} MB',
                  style: TextStyle(
                    fontFamily: widget.settings.fontFamily,
                    fontSize: widget.settings.smallPrint(12),
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                value: _selected.contains(c),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selected.add(c);
                    } else {
                      _selected.remove(c);
                    }
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              );
            }),
          SizedBox(height: 4 * s),
          Row(
            children: [
              Expanded(
                child: Builder(builder: (_) {
                  if (svc.downloading) {
                    return OutlinedButton.icon(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: Text(
                        uiStrings['cancel']?[locale] ?? 'Cancel',
                      ),
                      onPressed: () => svc.cancel(),
                    );
                  }
                  if (_selected.isEmpty) {
                    return FilledButton.icon(
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text(
                          uiStrings['offlinePackPickCategory']?[locale] ??
                              'Pick a category'),
                      onPressed: null,
                    );
                  }
                  // 2026-05-07: differentiate the action based on
                  // whether everything in the user's current
                  // selection has already been downloaded. When
                  // selection ⊆ lastDownloaded → button reads
                  // "Already downloaded · Re-download to refresh"
                  // (outlined, not filled) so the user sees they
                  // don't need to do anything; tapping still
                  // re-downloads which is useful for picking up
                  // updated assets after a deploy. When selection
                  // contains anything NEW → button reads
                  // "Download new (~X MB)" (filled, prominent) so
                  // the user knows there's actual work to do.
                  final allDownloaded = svc.lastDownloaded.isNotEmpty &&
                      _selected.every(svc.lastDownloaded.contains);
                  if (allDownloaded) {
                    return OutlinedButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(uiStrings['offlinePackRedownload']
                              ?[locale] ??
                          'Re-download to refresh'),
                      onPressed: () => svc.download(categories: _selected),
                    );
                  }
                  return FilledButton.icon(
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text(
                      '${uiStrings['offlinePackDownload']?[locale] ?? 'Download'} '
                      '(~${_selectedTotalMb()} MB)',
                    ),
                    onPressed: () => svc.download(categories: _selected),
                  );
                }),
              ),
              if (!svc.downloading &&
                  svc.lastCompletedAt != null &&
                  svc.lastDownloaded.isNotEmpty) ...[
                SizedBox(width: 8 * s),
                IconButton(
                  tooltip: uiStrings['offlinePackClear']?[locale] ??
                      'Clear offline pack',
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 20, color: scheme.error),
                  onPressed: () => svc.clear(),
                ),
              ],
            ],
          ),
          // Round 56 day-3 (2026-05-06): network-only feature note.
          // Some features genuinely cannot be cached because they
          // depend on a live API call — be upfront about that so the
          // "ready offline" label isn't read as "everything works".
          SizedBox(height: 8 * s),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 8 * s),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer.withValues(alpha: 0.35),
              border: Border.all(
                  color: scheme.outlineVariant, width: WbMetrics.hairline),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.cloud_outlined,
                    size: 14, color: scheme.tertiary),
                SizedBox(width: 6 * s),
                Expanded(
                  child: Text(
                    uiStrings['offlinePackNetworkNote']?[locale] ??
                        'Network is still required for AI explanations / search, '
                            'cloud sync (sign-in), live news refresh, and the first '
                            'load of any non-Roboto font.',
                    style: TextStyle(
                      fontFamily: widget.settings.fontFamily,
                      fontSize: widget.settings.smallPrint(12),
                      color: scheme.onSurface.withValues(alpha: 0.78),
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 2026-05-24 (v1.3.25): "Install as App" card.
///
/// Shows on web only — native builds short-circuit because the
/// app is already an installed binary. Within web, the card
/// branches on what the browser is offering:
///   * `nativePrompt`   — Chrome / Edge has fired
///     beforeinstallprompt. Show "Install SeekSparks" button which
///     triggers the OS install picker.
///   * `iosManual`      — iOS Safari has no programmatic install
///     API. Show a 2-step guide pointing at the Share sheet.
///   * `desktopManual`  — Desktop browser w/ Add-to-Home-Screen
///     capability but no beforeinstallprompt yet. Point at the
///     browser menu.
///   * `alreadyInstalled` — Hide the card entirely.
class _InstallAppCard extends StatefulWidget {
  const _InstallAppCard();

  @override
  State<_InstallAppCard> createState() => _InstallAppCardState();
}

class _InstallAppCardState extends State<_InstallAppCard> {
  InstallFlowKind _flow = InstallFlowKind.notApplicable;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _flow = InstallPromptService.detect();
    // Chrome's `beforeinstallprompt` can fire anytime after first
    // load (it's debounced server-side). Re-check after the first
    // frame so a late-arriving event still flips the UI.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final fresh = InstallPromptService.detect();
      if (fresh != _flow) setState(() => _flow = fresh);
    });
  }

  Future<void> _onInstallPressed() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await InstallPromptService.show();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _flow = InstallPromptService.detect();
    });
    if (outcome == 'accepted') {
      messenger.showSnackBar(const SnackBar(
        content: Text('Installing SeekSparks…'),
        duration: Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_flow == InstallFlowKind.notApplicable ||
        _flow == InstallFlowKind.alreadyInstalled) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final isZh = locale == 'zh-Hans' || locale == 'zh-Hant';

    String title;
    String body;
    Widget? action;

    switch (_flow) {
      case InstallFlowKind.nativePrompt:
        title = isZh ? '安装 SeekSparks' : 'Install SeekSparks';
        body = isZh
            ? '把 SeekSparks 安装到主屏幕,获得更快的启动速度和离线访问。'
            : 'Install SeekSparks to your home screen for faster launch + offline access.';
        action = FilledButton.icon(
          onPressed: _busy ? null : _onInstallPressed,
          icon: const Icon(Icons.install_mobile_outlined, size: 18),
          label: Text(isZh ? '安装' : 'Install'),
        );
        break;
      case InstallFlowKind.iosManual:
        title = isZh ? '添加到主屏幕' : 'Add to Home Screen';
        body = isZh
            ? '1. 点击 Safari 底部的「分享」按钮（⬆️）\n2. 选择「添加到主屏幕」\n3. 点击「添加」 — SeekSparks 就会像原生 App 一样运行。'
            : '1. Tap the Safari Share button at the bottom (⬆️)\n2. Choose "Add to Home Screen"\n3. Tap "Add" — SeekSparks runs like a native app.';
        break;
      case InstallFlowKind.desktopManual:
        title = isZh ? '安装 SeekSparks 桌面版' : 'Install SeekSparks as a desktop app';
        body = isZh
            ? '在地址栏右侧找到「安装」图标（⊕）, 或者打开浏览器菜单 → 「安装 SeekSparks」。安装后 SeekSparks 会有自己的窗口和 Dock / 开始菜单图标。'
            : 'Look for the install icon (⊕) on the right side of the address bar, or open the browser menu → "Install SeekSparks". Once installed SeekSparks gets its own window + Dock / Start Menu icon.';
        break;
      case InstallFlowKind.alreadyInstalled:
      case InstallFlowKind.notApplicable:
        return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.install_mobile_outlined,
                    size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: settings.fontFamily,
                      fontFamilyFallback: kCjkFontFallback,
                      fontSize:
                          settings.smallPrint(16),
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: TextStyle(
                fontFamily: settings.fontFamily,
                fontFamilyFallback: kCjkFontFallback,
                fontSize: settings.smallPrint(13),
                color: scheme.onSurface.withValues(alpha: 0.85),
                height: 1.5,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: action),
            ],
          ],
        ),
      ),
    );
  }
}

/// 2026-05-24 (v1.3.26): export-data card. See file-level header.
class _ExportDataCard extends StatelessWidget {
  const _ExportDataCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final isZh = locale == 'zh-Hans' || locale == 'zh-Hant';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.download_outlined,
                    size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isZh ? '导出我的数据' : 'Export my data',
                    style: TextStyle(
                      fontFamily: settings.fontFamily,
                      fontFamilyFallback: kCjkFontFallback,
                      fontSize:
                          settings.smallPrint(16),
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isZh
                  ? '导出全部标记、书签和笔记。 Markdown 格式可粘贴到 Notion / Obsidian / Apple Notes 等; JSON 格式是结构化备份。'
                  : 'Export all highlights, bookmarks, and notes. Markdown pastes cleanly into Notion / Obsidian / Apple Notes / Google Docs. JSON is a structured backup.',
              style: TextStyle(
                fontFamily: settings.fontFamily,
                fontFamilyFallback: kCjkFontFallback,
                fontSize: settings.smallPrint(13),
                color: scheme.onSurface.withValues(alpha: 0.85),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: () => _showExportDialog(context),
                icon: const Icon(Icons.ios_share_outlined, size: 18),
                label: Text(isZh ? '导出…' : 'Export…'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExportDialog(BuildContext context) async {
    final mp = context.read<MainProvider>();
    final settings = context.read<AppSettings>();
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ExportDialog(mp: mp, settings: settings),
    );
  }
}

class _ExportDialog extends StatefulWidget {
  final MainProvider mp;
  final AppSettings settings;
  const _ExportDialog({required this.mp, required this.settings});

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  // 'md' or 'json'
  String _format = 'md';
  late String _content;

  @override
  void initState() {
    super.initState();
    _content = _generate();
  }

  String _generate() {
    return _format == 'md'
        ? ExportService.toMarkdown(widget.mp)
        : ExportService.toJson(widget.mp);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = widget.settings.locale;
    final isZh = locale == 'zh-Hans' || locale == 'zh-Hant';
    final bytes = _content.length;
    final sizeLabel = bytes < 1024
        ? '$bytes B'
        : bytes < 1024 * 1024
            ? '${(bytes / 1024).toStringAsFixed(1)} KB'
            : '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return AlertDialog(
      title: Text(isZh ? '导出我的数据' : 'Export my data'),
      content: SizedBox(
        // v1.3.x responsive fix: a fixed 560 overflowed the dialog on
        // phones (≈390 dp). On narrow screens fill the dialog's own
        // (smaller) width via double.maxFinite; cap at 560 on tablet /
        // desktop so the export panel doesn't stretch too wide.
        width: MediaQuery.of(context).size.width < 640
            ? double.maxFinite
            : 560.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'md',
                  label: Text('Markdown'),
                  icon: Icon(Icons.text_snippet_outlined, size: 18),
                ),
                ButtonSegment(
                  value: 'json',
                  label: Text('JSON'),
                  icon: Icon(Icons.data_object_outlined, size: 18),
                ),
              ],
              selected: {_format},
              onSelectionChanged: (s) {
                if (s.isEmpty) return;
                setState(() {
                  _format = s.first;
                  _content = _generate();
                });
              },
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 280),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.6),
                    width: WbMetrics.hairline),
              ),
              padding: const EdgeInsets.all(8),
              child: Scrollbar(
                child: SelectableText(
                  _content,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: widget.settings.smallPrint(11),
                    height: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isZh ? '大小: $sizeLabel' : 'Size: $sizeLabel',
              style: TextStyle(
                fontSize: widget.settings.smallPrint(11),
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(isZh ? '关闭' : 'Close'),
        ),
        FilledButton.icon(
          onPressed: () async {
            await ClipboardHelper.copyWithFeedback(
              context,
              _content,
              messageOverride:
                  isZh ? '已复制到剪贴板' : 'Copied to clipboard',
            );
          },
          icon: const Icon(Icons.content_copy_outlined, size: 16),
          label: Text(isZh ? '复制' : 'Copy'),
        ),
      ],
    );
  }
}

/// 2026-08 (ported from YsWords v1.4.0): import-data card — the reverse of
/// `_ExportDataCard`. Paste-JSON, not a file picker: mirrors export's
/// own copy-to-clipboard UX exactly, works identically on every
/// platform with zero new dependencies (there's no `file_picker` in
/// this app — a true file-open dialog would need one, and export
/// itself doesn't even offer a file-download button, only clipboard).
/// Only the JSON export format round-trips; Markdown is prose for
/// pasting into OTHER apps, not parseable back into this one.
class _ImportDataCard extends StatelessWidget {
  const _ImportDataCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final isZh = locale == 'zh-Hans' || locale == 'zh-Hant';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.upload_outlined, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isZh ? '导入我的数据' : 'Import my data',
                    style: TextStyle(
                      fontFamily: settings.fontFamily,
                      fontFamilyFallback: kCjkFontFallback,
                      fontSize: settings.smallPrint(16),
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isZh
                  ? '粘贴之前导出的 JSON 备份，恢复标记、书签和笔记。同一节经文的数据会被导入的内容覆盖，其余数据保持不变。'
                  : 'Paste a previously exported JSON backup to restore highlights, bookmarks, and notes. Imported entries overwrite existing data for the same verse; everything else is left untouched.',
              style: TextStyle(
                fontFamily: settings.fontFamily,
                fontFamilyFallback: kCjkFontFallback,
                fontSize: settings.smallPrint(13),
                color: scheme.onSurface.withValues(alpha: 0.85),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: () => _showImportDialog(context),
                icon: const Icon(Icons.file_open_outlined, size: 18),
                label: Text(isZh ? '导入…' : 'Import…'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showImportDialog(BuildContext context) async {
    final mp = context.read<MainProvider>();
    final settings = context.read<AppSettings>();
    await showDialog<void>(
      context: context,
      // `pageContext` is the SETTINGS PAGE's context (captured here,
      // before the dialog opens), distinct from the dialog's own context
      // passed to _ImportDialog's build method. On success we pop the
      // dialog THEN show a confirmation toast — using the dialog's own
      // context for that toast would be popping-and-then-using an
      // about-to-be-removed context.
      builder: (ctx) =>
          _ImportDialog(mp: mp, settings: settings, pageContext: context),
    );
  }
}

class _ImportDialog extends StatefulWidget {
  final MainProvider mp;
  final AppSettings settings;
  final BuildContext pageContext;
  const _ImportDialog(
      {required this.mp, required this.settings, required this.pageContext});

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _controller = TextEditingController();
  ParsedImport? _parsed;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    if (text.trim().isEmpty) {
      setState(() {
        _parsed = null;
        _error = null;
      });
      return;
    }
    try {
      final parsed = ImportService.parse(text);
      setState(() {
        _parsed = parsed;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _parsed = null;
        _error = e is FormatException ? e.message : e.toString();
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    // Best-effort — some browser contexts reject programmatic clipboard
    // reads outside a fresh user-activation window. The field is still
    // directly pasteable by the user's own OS paste gesture regardless
    // of whether this succeeds.
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text != null && text.isNotEmpty) {
        _controller.setTextAtomic(text);
        _onTextChanged(text);
      }
    } catch (_) {
      // Silently ignore — no worse off than before the tap.
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = widget.settings.locale;
    final isZh = locale == 'zh-Hans' || locale == 'zh-Hant';
    final parsed = _parsed;

    return AlertDialog(
      title: Text(isZh ? '导入我的数据' : 'Import my data'),
      content: SizedBox(
        // Same responsive rule as _ExportDialog.
        width:
            MediaQuery.of(context).size.width < 640 ? double.maxFinite : 560.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _pasteFromClipboard,
                icon: const Icon(Icons.content_paste_outlined, size: 16),
                label: Text(isZh ? '从剪贴板粘贴' : 'Paste from clipboard'),
              ),
            ),
            Container(
              constraints: const BoxConstraints(maxHeight: 280, minHeight: 140),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.6),
                    width: WbMetrics.hairline),
              ),
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: _controller,
                onChanged: _onTextChanged,
                maxLines: null,
                expands: true,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: widget.settings.smallPrint(11),
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText:
                      isZh ? '粘贴 JSON 内容…' : 'Paste exported JSON here…',
                ),
              ),
            ),
            const SizedBox(height: 6),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(
                    fontSize: widget.settings.smallPrint(11),
                    color: scheme.error),
              )
            else if (parsed != null)
              Text(
                isZh
                    ? '找到 ${parsed.highlights.length} 条高亮、${parsed.bookmarks.length} 条书签、${parsed.notes.length} 条笔记——将覆盖同一节经文的本地数据。'
                    : 'Found ${parsed.highlights.length} highlights · ${parsed.bookmarks.length} bookmarks · ${parsed.notes.length} notes — will overwrite existing data for the same verse.',
                style: TextStyle(
                  fontSize: widget.settings.smallPrint(11),
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(isZh ? '取消' : 'Cancel'),
        ),
        FilledButton.icon(
          onPressed: parsed == null || parsed.totalCount == 0
              ? null
              : () {
                  final result = widget.mp.importMergedData(
                    highlights: parsed.highlights,
                    bookmarks: parsed.bookmarks,
                    notes: parsed.notes,
                  );
                  Navigator.of(context).pop();
                  showFloatingToast(
                    widget.pageContext,
                    message: isZh
                        ? '已导入 ${result.highlights} 条高亮、${result.bookmarks} 条书签、${result.notes} 条笔记'
                        : 'Imported ${result.highlights} highlights, ${result.bookmarks} bookmarks, ${result.notes} notes',
                    icon: Icons.check_circle_rounded,
                    background: scheme.primary,
                  );
                },
          icon: const Icon(Icons.upload_outlined, size: 16),
          label: Text(isZh ? '导入' : 'Import'),
        ),
      ],
    );
  }
}

/// The settings page's own subordinate type, on the reader's scale.
///
/// #315 counted three ways to write a size the Font Size slider cannot
/// move, and this file held the largest concentration of the third: 28
/// of the app's saturating ceilings, on the page that carries the
/// slider. Dragging it to 40 pt left every hint, subtitle and badge
/// here exactly where it was.
///
/// The page had already declared which scale it belongs to. Card
/// titles are `fontSize: settings.fontSize + 2` with no bound at all,
/// and a switch row's label is `settings.fontSize` outright — so this
/// is Font Size's page, not Menu Size's, and the clamped sites were
/// the ones that fell off that convention rather than a deliberate
/// second scale. Leaving them behind produced an INVERTED hierarchy at
/// the top of the range: at 40 pt a `_SettingsSwitch` printed its
/// title at 40 px and its own subtitle at 14, a 2.9× gap where the
/// design was 20 and 14.
///
/// [WbType.scaledSmall] keeps the floor those clamps carried and drops
/// the ceiling; the argument is the size the site renders today at the
/// default 20 pt, so nothing moves for a reader who never touched the
/// slider.
///
/// An extension on [AppSettings] rather than on [BuildContext] because
/// half this file's call sites are in widgets that hold the settings
/// as a field (`widget.settings`) and reach them from dialog builders,
/// where `context.watch` is not available.
extension _SettingsSmallPrint on AppSettings {
  double smallPrint(double atDefault) => wbType.scaledSmall(atDefault);
}
