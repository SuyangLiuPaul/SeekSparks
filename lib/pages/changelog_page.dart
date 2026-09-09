// 更新记录 — what changed, and when.
//
// From the owner on 2026-09-09: 「也要有历史的release note但是不要全部
// 的而是足够的不然太多」. The "不要全部" half is answered by
// `tools/build_changelog.py`, which bundles a 120-version window. The
// "不然太多" half is answered HERE, and the two halves needed different
// answers.
//
// **What makes a changelog for this app unreadable is not the notes,
// it is the version numbers.** 115 bundled versions carry 250 changes
// across 17 days — so a version-per-row list is a hundred and fifteen
// rows of "1.6.2xx" with one line under each, and the reader has to
// reconstruct that six of them were the same afternoon. Grouping by
// DAY collapses that to seventeen headings without discarding a single
// note. The version number stays, as a quiet label beside its own
// changes, because "which version was that in" is the other question
// this page gets asked.
//
// The list is lazy (`ListView.builder`) so the window can grow later
// without the page getting slower to open.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/app_version.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/services/changelog_service.dart';
import 'package:seeksparks/services/link_opener.dart';
import 'package:seeksparks/services/update_service.dart';
import 'package:seeksparks/utils/responsive.dart';
import 'package:seeksparks/widgets/localized_back_button.dart';

class ChangelogPage extends StatefulWidget {
  const ChangelogPage({super.key});

  @override
  State<ChangelogPage> createState() => _ChangelogPageState();
}

class _ChangelogPageState extends State<ChangelogPage> {
  late final Future<List<ChangelogDay>> _days = ChangelogService.load();

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);
    final locale = settings.locale;
    return Theme(
      data: workbenchTheme(
        Theme.of(context),
        paper: settings.readingPaperTheme,
        textScale: WbType.scaleFor(settings.fontSize),
        accent: settings.primaryColor,
      ),
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            leading: const LocalizedBackButton(),
            title: Text(
              uiStrings['changelogTitle']?[locale] ?? "What's new",
            ),
          ),
          body: FutureBuilder<List<ChangelogDay>>(
            future: _days,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final days = snap.data!;
              if (days.isEmpty) return _empty(context, locale);
              return _list(context, locale, days);
            },
          ),
        ),
      ),
    );
  }

  Widget _list(
      BuildContext context, String locale, List<ChangelogDay> days) {
    final wide = ResponsiveBreakpoints.isTabletOrWider(
        MediaQuery.of(context).size.width);
    // 2026-09-09 (review finding 4): under a Chinese title, the notes
    // are English commit subjects — the generator does not translate,
    // and this app does not invent translations. One line says so, in
    // the two Chinese locales only; the English key is deliberately
    // empty, because an English reader is not owed an explanation for
    // English. `?? ''` rather than an English fallback for the same
    // reason. Nothing is rendered when the string is empty.
    final languageNote = uiStrings['changelogLanguageNote']?[locale] ?? '';
    final hasNote = languageNote.isNotEmpty;
    final lead = hasNote ? 1 : 0;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: wide ? 760 : double.infinity),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          // +1 for the footer, which is part of the honest answer:
          // this page shows a window, and says where the rest is.
          itemCount: lead + days.length + 1,
          itemBuilder: (context, i) {
            if (hasNote && i == 0) return _languageNote(context, languageNote);
            final d = i - lead;
            return d == days.length
                ? _footer(context, locale)
                : _day(context, locale, days[d]);
          },
        ),
      ),
    );
  }

  Widget _languageNote(BuildContext context, String text) {
    final t = WbType.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: t.scaledChrome(WbMetrics.smallPrintFloor),
          height: 1.5,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _day(BuildContext context, String locale, ChangelogDay day) {
    final t = WbType.of(context);
    final wb = WbColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A Wrap, not a Row (review finding 3, 2026-09-09). Both
          // texts are sized from the reading font AND the OS text
          // scale, and a Row gives its children no way to yield: at
          // 360 dp with the OS at 200% the date alone is 300 px, so the
          // count overflowed the screen with a yellow-and-black stripe
          // on every heading. With a Wrap the count drops to a second
          // line instead, and the date is never cut.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 10,
            children: [
              Text(
                day.date,
                style: TextStyle(
                  fontSize: t.scaledChrome(15),
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
              // Changes, not versions. How often we deploy is our
              // business; what changed is theirs.
              Text(
                (uiStrings['changelogCount']?[locale] ?? '{n} changes')
                    .replaceAll('{n}', '${day.noteCount}'),
                style: TextStyle(
                  fontSize: t.scaledChrome(WbMetrics.smallPrintFloor),
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Divider(height: 1, thickness: WbMetrics.hairline, color: wb.border),
          for (final version in day.versions)
            _version(context, locale, version),
        ],
      ),
    );
  }

  Widget _version(
      BuildContext context, String locale, ChangelogEntry entry) {
    final t = WbType.of(context);
    final scheme = Theme.of(context).colorScheme;
    final running = entry.version == kAppVersion;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'v${entry.version}',
                style: TextStyle(
                  fontSize: t.scaledChrome(WbMetrics.smallPrintFloor),
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              // The reader's own build, marked. This page's second
              // question is "which version was that in", and the
              // useful half of that is "is it in mine".
              if (running) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius:
                        BorderRadius.circular(WbMetrics.radiusControl),
                  ),
                  child: Text(
                    uiStrings['changelogYours']?[locale] ?? 'yours',
                    style: TextStyle(
                      fontSize: t.scaledChrome(WbMetrics.smallPrintFloor),
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          for (final note in entry.notes)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('·  ',
                      style: TextStyle(
                          fontSize: t.scaled(14),
                          color: scheme.onSurfaceVariant)),
                  // No maxLines: a note that does not fit makes the
                  // row taller. Truncating a changelog entry hides
                  // exactly the clause that says what actually
                  // changed — these subjects put it at the end.
                  Expanded(
                    child: Text(
                      note,
                      style: TextStyle(
                        fontSize: t.scaled(14),
                        height: 1.5,
                        color: scheme.onSurface,
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

  Widget _footer(BuildContext context, String locale) {
    final t = WbType.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            uiStrings['changelogWindow']?[locale] ??
                'This page shows recent releases. Older ones are on GitHub.',
            style: TextStyle(
              fontSize: t.scaledChrome(WbMetrics.smallPrintFloor),
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (LinkOpener.isAvailable)
            TextButton.icon(
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text(
                uiStrings['changelogAllOnGitHub']?[locale] ??
                    'All releases on GitHub',
              ),
              onPressed: () => LinkOpener.open(
                'https://github.com/${UpdateService.repo}/releases',
              ),
            ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context, String locale) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            uiStrings['changelogEmpty']?[locale] ??
                'No release notes are bundled with this build.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: WbType.of(context).scaled(14),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
}
