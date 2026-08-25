import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/app_version.dart';
import 'package:seeksparks/constants/sermon_credit.dart';
import 'package:seeksparks/widgets/update_check_tile.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/map_provenance.dart';
import 'package:seeksparks/services/link_opener.dart';
import 'package:seeksparks/utils/clipboard_helper.dart';
import 'package:seeksparks/utils/responsive.dart';
import 'package:seeksparks/widgets/home_icon_button.dart';
import 'package:seeksparks/widgets/language_switcher_button.dart';
import 'package:seeksparks/widgets/localized_back_button.dart';

/// Settings → About → "About / 关于" — full attributions + licensing
/// + takedown contact page.
///
/// Why this page exists: SeekSparks bundles or references material that
/// belongs to other rights holders (Bible publishers, lexicon
/// projects, sermon authors, font foundries). This page is the
/// app's single source of truth for who owns what, the licence each
/// piece is used under, and how to reach the developer for
/// takedown / licensing requests.
///
/// The page is **read-only** and never gates behaviour — it's purely
/// informational. Lives behind a button on the existing
/// `_AboutCard` in Settings so the page itself can be deep enough
/// to list every Bible version + every credit without crowding the
/// Settings list.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = WbType.of(context);
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final scheme = Theme.of(context).colorScheme;
    final dc = ResponsiveBreakpoints.classOf(
        MediaQuery.of(context).size.width);
    final maxW = ResponsiveBreakpoints.settingsMaxWidth(dc);

    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        // 2026-05-10 (v1.2.19): user reported "bibleapp version not
        // showing in dev/qat about page". The footer (~end of a
        // ListView) requires scrolling past 6+ sections + the cloud-
        // diagnostic block — most users never see it. Surface
        // the running version directly in the AppBar so it's
        // always one tap away. Also keep the footer entry for
        // historical / copy-paste support purposes.
        // 2026-05-10 (v1.2.22): added overflow + maxLines so the
        // combined "About · v1.2.22" doesn't clip on 320 px-class
        // viewports when the user has bumped settings.fontSize.
        title: Text(
          '${uiStrings['aboutPageTitle']?[locale] ?? 'About'} · v$kAppVersion',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: const [LanguageSwitcherButton(), HomeIconButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _Header(scheme: scheme, locale: locale, settings: settings),
              const SizedBox(height: 16),
              _DisclaimerCard(scheme: scheme, locale: locale),
              const SizedBox(height: 12),
              _ContactCard(scheme: scheme, locale: locale),
              // 2026-05-06: BYOK card was here briefly but the user
              // wanted AI to be fully automatic ("auth gemini for
              // them"). The developer-shared Gemini key already
              // handles AI for everyone after sign-in — no setup
              // needed. The BYOK widget (lib/widgets/gemini_key_card)
              // and Netlify function userApiKey support remain in
              // case we need to re-enable BYOK later.
              const SizedBox(height: 20),
              _SectionTitle(
                  text: uiStrings['aboutSectionScriptures']?[locale] ??
                      'Bundled scripture texts',
                  scheme: scheme),
              const SizedBox(height: 6),
              _ScripturesTable(scheme: scheme, locale: locale),
              const SizedBox(height: 20),
              _SectionTitle(
                  text: uiStrings['aboutSectionLexicons']?[locale] ??
                      "Strong's lexicons & original-language data",
                  scheme: scheme),
              const SizedBox(height: 6),
              _LexiconsTable(scheme: scheme, locale: locale),
              const SizedBox(height: 20),
              _SectionTitle(
                  text: uiStrings['aboutSectionOther']?[locale] ??
                      'Maps · Sermons · Fonts · AI · App icon',
                  scheme: scheme),
              const SizedBox(height: 6),
              _OtherAttributions(scheme: scheme, locale: locale),
              const SizedBox(height: 20),
              _SectionTitle(
                  text: uiStrings['aboutSectionAppLicense']?[locale] ??
                      'Application licence',
                  scheme: scheme),
              const SizedBox(height: 6),
              _AppLicenseCard(scheme: scheme, locale: locale),
              const SizedBox(height: 24),
              // 2026-05-06 second iteration: Cloud setup diagnostic +
              // walkthrough live here — at the bottom of AboutPage,
              // collapsed by default. Regular users never see them
              // (they don't need to). The developer can still find
              // them when they go to "About" to investigate sync
              // issues. User feedback: "开发者说明不用" — developer
              // setup info shouldn't be in the user-facing Settings
              // flow.
              Center(
                // 2026-05-07 (v17): also show the running app version
                // here. The "Check for Updates" tile in Settings used
                // to be the only place this surfaced; that tile was
                // removed (it was theatre — see settings_page.dart).
                // This footer is now the canonical version display.
                //
                child: Text(
                  // 2026-05-10 (v1.2.20): footer interpolates with
                  // kAppReleaseDate (was hardcoded date that drifted).
                  // 2026-05-10 (v1.2.24): kAppReleaseDate renamed
                  // to kAppReleaseTime (now wall-clock-minute precision
                  // — "YYYY-MM-DD HH:MM TZ"), placeholder `{date}` →
                  // `{time}`. Back-to-back same-day releases now
                  // distinguishable from the footer alone.
                  // 2026-05-10 (v1.2.35): swapped raw kAppReleaseTime
                  // for `formatReleaseTimeLocal()` so the displayed
                  // stamp converts to the viewer's local timezone.
                  // 2026-06-09 (v1.3.59): `kAppReleaseTime` is stamped
                  // into source by `tools/bump_version.sh` (NOT injected
                  // per-build), so every platform shows ONE identical
                  // value; the helper renders it with a self-computed
                  // UTC offset (`UTC+10`) rather than the platform-
                  // specific `DateTime.timeZoneName`, which differed
                  // across iOS/web/Android. Never blank — empty input
                  // falls back to an em dash.
                  '${(uiStrings['aboutFooterNote']?[locale] ?? 'Last updated {time}.').replaceFirst('{time}', formatReleaseTimeLocal())}'
                      ' · v$kAppVersion',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: t.scaled(11),
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final ColorScheme scheme;
  final String locale;
  final AppSettings settings;
  const _Header(
      {required this.scheme, required this.locale, required this.settings});
  @override
  Widget build(BuildContext context) {
    final t = WbType.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Row(
          children: [
            Icon(Icons.menu_book_rounded,
                color: scheme.primary, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    uiStrings['appName']?[locale] ?? "Yahweh's Sword",
                    style: TextStyle(
                      fontSize: t.scaled(18),
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    uiStrings['appTagline']?[locale] ??
                        'A bilingual Bible study app.',
                    style: TextStyle(
                      fontSize: t.scaled(12),
                      color: scheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  final ColorScheme scheme;
  final String locale;
  const _DisclaimerCard({required this.scheme, required this.locale});
  @override
  Widget build(BuildContext context) {
    final t = WbType.of(context);
    return Card(
      color: scheme.tertiaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded,
                size: 18, color: scheme.tertiary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                uiStrings['aboutDisclaimer']?[locale] ?? '',
                style: TextStyle(
                  fontSize: t.scaled(12.5),
                  color: scheme.onSurface,
                  height: 1.55,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final ColorScheme scheme;
  final String locale;
  const _ContactCard({required this.scheme, required this.locale});

  static const _email = 'paul.sy.liu@gmail.com';

  Future<void> _open(BuildContext context) async {
    final uri = 'mailto:$_email?subject=Yahweh%27s%20Sword%20copyright%20enquiry';
    if (LinkOpener.isAvailable) {
      final ok = await LinkOpener.open(uri);
      if (ok) return;
    }
    if (!context.mounted) return;
    await ClipboardHelper.copyWithFeedback(context, _email);
  }

  @override
  Widget build(BuildContext context) {
    final t = WbType.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.alternate_email_rounded,
                    size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  uiStrings['aboutContactTitle']?[locale] ??
                      'Contact / Takedown',
                  style: TextStyle(
                    fontSize: t.scaled(13),
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              uiStrings['aboutContactBody']?[locale] ?? '',
              style: TextStyle(
                fontSize: t.scaled(12.5),
                color: scheme.onSurface.withValues(alpha: 0.85),
                height: 1.55,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                icon: const Icon(Icons.email_outlined, size: 18),
                label: Text(
                  _email,
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                onPressed: () => _open(context),
              ),
            ),
            Text(
              uiStrings['aboutContactSla']?[locale] ?? '',
              style: TextStyle(
                fontSize: t.scaled(11),
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final ColorScheme scheme;
  const _SectionTitle({required this.text, required this.scheme});
  @override
  Widget build(BuildContext context) {
    final t = WbType.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: t.scaled(12),
          fontWeight: FontWeight.w800,
          color: scheme.primary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// A row inside an attributions table. Renders the resource name, its
/// rights holder / licence, and an optional URL the user can tap.
class _AttribRow extends StatelessWidget {
  final String name;
  final String licence;
  final String? url;
  final bool last;
  const _AttribRow({
    required this.name,
    required this.licence,
    this.url,
    this.last = false,
  });

  Future<void> _open(BuildContext context) async {
    if (url == null) return;
    if (!LinkOpener.isAvailable) return;
    await LinkOpener.open(url!);
  }

  @override
  Widget build(BuildContext context) {
    final t = WbType.of(context);
    final scheme = Theme.of(context).colorScheme;
    final hasUrl = url != null && url!.isNotEmpty;
    return InkWell(
      onTap: hasUrl ? () => _open(context) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: last
                  ? Colors.transparent
                  : scheme.outlineVariant.withValues(alpha: 0.5),
              width: 0.6,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Text(
                name,
                style: TextStyle(
                  fontSize: t.scaled(12.5),
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 6,
              child: Text(
                licence,
                style: TextStyle(
                  fontSize: t.scaled(12),
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
            if (hasUrl) ...[
              const SizedBox(width: 4),
              Icon(Icons.open_in_new_rounded,
                  size: 14,
                  color: scheme.primary.withValues(alpha: 0.75)),
            ],
          ],
        ),
      ),
    );
  }
}

class _AttribTable extends StatelessWidget {
  final List<_AttribRow> rows;
  final ColorScheme scheme;
  const _AttribTable({required this.rows, required this.scheme});
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(children: rows),
      ),
    );
  }
}

class _ScripturesTable extends StatelessWidget {
  final ColorScheme scheme;
  final String locale;
  const _ScripturesTable(
      {required this.scheme, required this.locale});
  @override
  Widget build(BuildContext context) {
    final t = WbType.of(context);
    final r = <_AttribRow>[
      _AttribRow(
        name: uiStrings['aboutVerKjv']?[locale] ?? 'KJV (1611 / 1769)',
        licence: uiStrings['aboutLicensePublicDomain']?[locale] ??
            'Public domain.',
      ),
      _AttribRow(
        name: uiStrings['aboutVerLeb']?[locale] ?? 'LEB (Lexham English Bible)',
        licence: uiStrings['aboutLicenseLeb']?[locale] ??
            '© Logos Bible Software · non-commercial study only.',
        url: 'https://lexhampress.com/product/9461/lexham-english-bible',
      ),
      _AttribRow(
        name: uiStrings['aboutVerBsb']?[locale] ??
            'BSB (Berean Standard Bible)',
        licence: uiStrings['aboutLicenseBsb']?[locale] ??
            'Dedicated to the public domain by the publisher.',
        url: 'https://bereanbible.com/',
      ),
      _AttribRow(
        name: uiStrings['aboutVerNasb']?[locale] ?? 'NASB 2020',
        licence: uiStrings['aboutLicenseNasb']?[locale] ??
            '© The Lockman Foundation · used under quotation provisions.',
        url: 'https://www.lockman.org/',
      ),
      _AttribRow(
        name: uiStrings['aboutVerCuvsYhwh']?[locale] ??
            'CUVS-YHWH (和合本雅伟版, 简/繁)',
        licence: uiStrings['aboutLicenseCuvsYhwh']?[locale] ??
            '© Yahweh De Hua Ministry · used with permission.',
        url: 'https://yahwehdehua.net/cn/bible',
      ),
      _AttribRow(
        name: uiStrings['aboutVerLjk']?[locale] ??
            'LJK1 / LJK2 梁家铿译本（2025年 · 第二版，简/繁）',
        licence: uiStrings['aboutLicenseLjk']?[locale] ??
            '© Bible Exegesis Ministry · used with permission.',
        url: 'https://www.biblexg.com/',
      ),
      // The three Eagle's View imports. Each underlying text is public
      // domain; the electronic editions and their Strong's alignment
      // come from Eagle's View, so it is credited by name.
      _AttribRow(
        name: uiStrings['aboutVerKjvs']?[locale] ??
            "KJV+S (1769 with Strong's + TVM)",
        licence: uiStrings['aboutLicenseEaglesView']?[locale] ??
            "Public domain text · electronic edition from Eagle's View.",
        url: 'https://eaglesviewsoftware.com/en/download/',
      ),
      _AttribRow(
        name: uiStrings['aboutVerLxxwh']?[locale] ??
            'LXX+WH (Septuagint + Westcott-Hort)',
        licence: uiStrings['aboutLicenseEaglesView']?[locale] ??
            "Public domain text · electronic edition from Eagle's View.",
        url: 'https://eaglesviewsoftware.com/en/download/',
      ),
      _AttribRow(
        name: uiStrings['aboutVerCuvsPlus']?[locale] ??
            "CUV+S 和合本+Strong's（简体）",
        licence: uiStrings['aboutLicenseEaglesView']?[locale] ??
            "Public domain text · electronic edition from Eagle's View.",
        url: 'https://eaglesviewsoftware.com/en/download/',
        last: true,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AttribTable(rows: r, scheme: scheme),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            uiStrings['aboutNivRemovedNote']?[locale] ?? '',
            style: TextStyle(
              fontSize: t.scaled(11),
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _LexiconsTable extends StatelessWidget {
  final ColorScheme scheme;
  final String locale;
  const _LexiconsTable({required this.scheme, required this.locale});
  @override
  Widget build(BuildContext context) {
    final r = <_AttribRow>[
      _AttribRow(
        name: uiStrings['aboutLexStrongs']?[locale] ??
            "Strong's Greek + Hebrew Concordance",
        licence: uiStrings['aboutLicensePublicDomain']?[locale] ??
            'Public domain (1890s).',
      ),
      _AttribRow(
        name: uiStrings['aboutLexCbol']?[locale] ??
            'CBOL Chinese definitions',
        licence: uiStrings['aboutLicenseCbol']?[locale] ??
            'CC-BY-NC-SA 4.0 · non-commercial only; derivatives must keep the licence.',
        url: 'https://bible.fhl.net/',
      ),
      _AttribRow(
        name: uiStrings['aboutLexLxx']?[locale] ??
            'LXX (Septuagint) cross-references',
        licence: uiStrings['aboutLicensePublicDomain']?[locale] ??
            'Public domain.',
      ),
      _AttribRow(
        name: uiStrings['aboutLexInterlinear']?[locale] ??
            'Greek + Hebrew interlinear (Strong\'s-tagged)',
        licence: uiStrings['aboutLicenseInterlinear']?[locale] ??
            'Public-domain morphological databases.',
      ),
      _AttribRow(
        name: uiStrings['aboutLexTsk']?[locale] ??
            'Treasury of Scripture Knowledge (TSK) cross-references',
        licence: uiStrings['aboutLicenseTsk']?[locale] ??
            'Public domain (R.A. Torrey, 1834) · merged with OpenBible.info community votes (CC-BY).',
        url: 'https://www.openbible.info/labs/cross-references',
      ),
      // Both morphology corpora require attribution by licence, so
      // these two rows are a condition of shipping the parsing line —
      // not optional credits.
      _AttribRow(
        name: uiStrings['aboutLexMorphGnt']?[locale] ??
            'Greek NT morphology — MorphGNT / SBLGNT',
        licence: uiStrings['aboutLicenseMorphGnt']?[locale] ??
            'CC BY-SA 3.0 · James Tauber et al.',
        url: 'https://github.com/morphgnt/sblgnt',
      ),
      _AttribRow(
        name: uiStrings['aboutLexOshb']?[locale] ??
            'Hebrew OT morphology — Open Scriptures Hebrew Bible (WLC)',
        licence: uiStrings['aboutLicenseOshb']?[locale] ??
            'CC BY 4.0 · Open Scriptures.',
        url: 'https://github.com/openscriptures/morphhb',
      ),
      // Used with the permission of the publisher at yahwehdehua.net.
      // These two are what let the Chinese column identify a word
      // rather than only its verse.
      _AttribRow(
        name: uiStrings['aboutLexCuvsTagged']?[locale] ??
            '和合本【雅伟】简体版＋［附原文编号］',
        licence: uiStrings['aboutLicenseCuvsTagged']?[locale] ??
            '修订编辑：孙树民 · Used with permission (yahwehdehua.net).',
        url: 'https://yahwehdehua.net/cn/resource/bible',
      ),
      _AttribRow(
        name: uiStrings['aboutLexBdbThayer']?[locale] ??
            'BDB (Hebrew) + Thayer (Greek) lexicons, Chinese edition',
        licence: uiStrings['aboutLicenseBdbThayer']?[locale] ??
            'Brown-Driver-Briggs (1906) & Thayer (1889), public domain · '
                'Chinese edition used with permission (yahwehdehua.net).',
        url: 'https://yahwehdehua.net/cn/resource/bible',
        last: true,
      ),
    ];
    return _AttribTable(rows: r, scheme: scheme);
  }
}

class _OtherAttributions extends StatelessWidget {
  final ColorScheme scheme;
  final String locale;
  const _OtherAttributions(
      {required this.scheme, required this.locale});
  @override
  Widget build(BuildContext context) {
    final r = <_AttribRow>[
      // Task #300. This was one row reading "Public domain / Creative
      // Commons archives", which is not true of the archive: 151 plates
      // have no recorded origin at all, and 40 carry a licence that
      // REQUIRES the author be named. One reassuring sentence covering
      // three different legal situations is the thing the audit was
      // for. The middle row is not a courtesy — CC BY-SA 3.0 sets
      // `AttributionRequired`, so it is a condition of shipping those
      // 40 plates, the same standing as the MorphGNT and OSHB rows.
      _AttribRow(
        name: uiStrings['aboutIllustrations']?[locale] ??
            'Illustrations and maps (1,192 plates)',
        licence: uiStrings['aboutIllustrationsPd']?[locale] ??
            'Public domain · Tissot, Schnorr, Doré, Rembrandt and others '
                '(artists dead over a century).',
      ),
      _AttribRow(
        name: uiStrings['aboutIllustrationsSweet']?[locale] ??
            'Sweet Publishing illustrations (40 plates)',
        // Not translated, and not a paraphrase: this is the wording the
        // upstream release asks for. Same string the viewer prints.
        licence: kSweetCredit,
        url: 'https://creativecommons.org/licenses/by-sa/3.0/',
      ),
      _AttribRow(
        name: uiStrings['aboutIllustrationsUnknown']?[locale] ??
            'Source not recorded (151 plates)',
        licence: uiStrings['aboutIllustrationsUnknownNote']?[locale] ??
            "Used by permission of the app's owner; where they were "
                'originally obtained was not recorded, so no licence is '
                'claimed.',
      ),
      _AttribRow(
        name: withPreacher(
            uiStrings['aboutSermons']?[locale] ??
                'Sermons by {name} (assets/sermons/)',
            locale),
        licence: uiStrings['aboutLicenseSermons']?[locale] ??
            '© Liang Jia-keng · used with permission.',
      ),
      _AttribRow(
        name: uiStrings['aboutFontsBundled']?[locale] ??
            'Bundled font: Roboto',
        licence: uiStrings['aboutLicenseRoboto']?[locale] ??
            'Apache 2.0 · Google.',
      ),
      _AttribRow(
        name: uiStrings['aboutFontsCjk']?[locale] ??
            'Bundled font: Noto Sans SC (subset)',
        licence: uiStrings['aboutLicenseOfl']?[locale] ??
            'SIL OFL · shipped with the app, not downloaded.',
      ),
      _AttribRow(
        name: uiStrings['aboutFontsScripts']?[locale] ??
            'Bundled fonts: Noto Sans Hebrew / Noto Sans / '
                'Noto Sans Symbols 2 (subsets)',
        licence: uiStrings['aboutLicenseOfl']?[locale] ??
            'SIL OFL · shipped with the app, not downloaded.',
      ),
      _AttribRow(
        name: uiStrings['aboutAi']?[locale] ?? 'AI explanations',
        licence: uiStrings['aboutLicenseAi']?[locale] ??
            'Google Gemini API · output redistribution permitted under API terms.',
      ),
      _AttribRow(
        name: uiStrings['aboutTrivia']?[locale] ??
            'Trivia text + diagrams',
        licence: uiStrings['aboutLicenseOriginal']?[locale] ??
            'Original to this app · MIT (same as application code).',
        last: true,
      ),
    ];
    return _AttribTable(rows: r, scheme: scheme);
  }
}

class _AppLicenseCard extends StatelessWidget {
  final ColorScheme scheme;
  final String locale;
  const _AppLicenseCard({required this.scheme, required this.locale});

  Future<void> _openRepo(BuildContext context) async {
    if (!LinkOpener.isAvailable) return;
    await LinkOpener.open('https://github.com/SuyangLiuPaul/SeekSparks');
  }

  @override
  Widget build(BuildContext context) {
    final t = WbType.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              uiStrings['aboutAppLicenseHeading']?[locale] ??
                  'Application code: MIT licence',
              style: TextStyle(
                fontSize: t.scaled(13),
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              uiStrings['aboutAppLicenseBody']?[locale] ?? '',
              style: TextStyle(
                fontSize: t.scaled(12),
                color: scheme.onSurface.withValues(alpha: 0.85),
                height: 1.55,
              ),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              icon: const Icon(Icons.code_rounded, size: 16),
              label: Text(
                uiStrings['aboutOpenRepo']?[locale] ??
                    'View source on GitHub',
              ),
              onPressed: () => _openRepo(context),
            ),
            // 2026-06-16 (v1.3.88): native-only "Check for updates" against
            // the GitHub release feed (hides itself on web — PWA is current).
            UpdateCheckTile(locale: locale, scheme: scheme),
          ],
        ),
      ),
    );
  }
}

