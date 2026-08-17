import 'package:flutter/material.dart';

import 'package:seeksparks/constants/era_palette.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/text_patterns.dart' show sanitizeForSearch;
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/widgets/left_accent_card.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/timeline_event.dart';
import 'package:seeksparks/pages/chronology_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/timeline_service.dart';
import 'package:seeksparks/utils/jump_to_reference.dart' as jumper;
import 'package:seeksparks/utils/reference_parser.dart';
import 'package:seeksparks/utils/version_mapper.dart' show localeAwareBookName;
import 'package:seeksparks/widgets/home_icon_button.dart';
import 'package:seeksparks/widgets/language_switcher_button.dart';
import 'package:seeksparks/widgets/localized_back_button.dart';
import 'package:seeksparks/utils/navigate_to_reader.dart';

/// Bible timeline — chronological view of 98 key biblical events
/// from Creation (c. 4000 BC) to John on Patmos (AD 95), modelled
/// on BibleHub's timeline structure but localized and visually
/// nicer.
///
/// Layout (per row):
///   [Year column]   ●   [Title + refs chips on tap-expand
///                        shows description and what the year rests on]
///
/// WHY EVERY YEAR SAYS WHAT IT RESTS ON. 85 of the 98 events are
/// `conventional` — a commonly published reconstruction that nothing
/// the app ships fixes — and 13 are derived, either from an interval
/// the text states or from Thiele. Until v1.6.142 the page printed all
/// 98 identically, because [TimelineEvent] dropped `basis` and
/// `approximate` when it parsed the asset. A reader was told "4000 BC"
/// for the creation in the same voice as "1446 BC" for the exodus,
/// and only one of those is countable from anything.
///
/// THE YEAR COLUMN IS MEASURED, NOT CHOSEN. It was 90 px holding a
/// string the Font Size slider scales 0.6x-2x, and the hedge makes the
/// string longer still: 「约 公元前 4000 年」 is half again the width of
/// 「公元前 4000 年」. Nothing here ellipsises, so an overflow would have
/// wrapped the year onto two lines rather than throwing. See
/// [_measureYearLane] for why no constant works either.
///
/// Era section dividers (Antediluvian / Patriarchs / Mosaic /
/// Conquest / Monarchy / Exile / Inter-testamental / NT) reuse the
/// family-tree era palette.
///
/// Search at top filters by title / description / id.
/// Tap a verse-ref chip → jumps to that verse in the reader.
double _yearFont(WbType t) => t.scaled(11.5);

TextStyle _yearStyle(WbType t, ColorScheme scheme) => TextStyle(
      fontSize: _yearFont(t),
      color: scheme.onSurface.withValues(alpha: 0.65),
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// The width of the year column, measured rather than chosen.
///
/// A multiple of the font size would have fixed the scaling but not the
/// font. The widest string is the Simplified hedge on a four-digit BC
/// year, 「约 公元前 4000 年」 — five CJK glyphs, four digits and three
/// spaces — which needs about 8 em in a real face and 12.5 em in the
/// font the widget tests load, because that font advances a digit and a
/// space by a full em. Any constant is therefore either too tight to
/// ship or too wide to look at. Measuring asks whichever font is
/// actually in front of us, so the ratchet in
/// `bible_timeline_page_test.dart` tests the app rather than the
/// harness.
///
/// Pass the WHOLE event list, never the search results. A lane measured
/// from the filtered set is narrower whenever the filter is, so the rail
/// and every card on it slide left as the reader types and back as they
/// delete — the column was a fixed 90 px before this, and jitter would
/// be a regression introduced by the fix.
///
/// This runs over the distinct years, once per page build. Scrolling
/// does not rebuild the page — `ListView.builder` calls the item
/// builder, not this — so the cost lands on a keystroke in the search
/// field and on opening a row.
///
/// [context] must be one the year [Text] itself would resolve against.
/// A bare `TextPainter` measures the style handed to it and nothing
/// else, while the widget merges that style onto `DefaultTextStyle` and
/// then scales it by the ambient `textScaler`. Measuring without the
/// first of those undercounted the lane by exactly the inherited
/// `letterSpacing` — 0.25 px a character, three pixels across
/// 「约 公元前 4000 年」, which is enough to wrap it.
double _measureYearLane(
  BuildContext context,
  Iterable<TimelineEvent> events,
  String locale,
  TextStyle style,
) {
  final resolved = DefaultTextStyle.of(context).style.merge(style);
  final scaler = MediaQuery.textScalerOf(context);
  var widest = 0.0;
  for (final s in {for (final e in events) e.displayYear(locale)}) {
    final painter = TextPainter(
      text: TextSpan(text: s, style: resolved),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    if (painter.width > widest) widest = painter.width;
  }
  return widest;
}

class BibleTimelinePage extends StatefulWidget {
  const BibleTimelinePage({super.key});

  @override
  State<BibleTimelinePage> createState() => _BibleTimelinePageState();
}

class _BibleTimelinePageState extends State<BibleTimelinePage> {
  Future<List<TimelineEvent>>? _future;
  String _query = '';
  late final TextEditingController _searchController;
  final Set<String> _expanded = <String>{};

  @override
  void initState() {
    super.initState();
    _future = TimelineService.instance.loadAll();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final scheme = Theme.of(context).colorScheme;
    final t = WbType.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(
          uiStrings['bibleTimeline']?[locale] ?? 'Bible Timeline',
        ),
        actions: const [LanguageSwitcherButton(), HomeIconButton()],
      ),
      body: FutureBuilder<List<TimelineEvent>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                // 2026-05-10 (v1.2.21): localised via shared
                // `loadErrorTitle` ui-string.
                child: Text(
                  '${uiStrings['loadErrorTitle']?[locale] ?? 'Failed to load'}: ${snap.error}',
                  style: TextStyle(color: scheme.error),
                ),
              ),
            );
          }
          final all = snap.data!;
          final q = sanitizeForSearch(_query.trim()).toLowerCase();
          final filtered = q.isEmpty
              ? all
              : all.where((e) {
                  final hay = [
                    e.titleEn,
                    e.titleZhHans,
                    e.titleZhHant,
                    e.descEn,
                    e.descZhHans,
                    e.descZhHant,
                    e.id,
                  ].join(' ').toLowerCase();
                  return hay.contains(q);
                }).toList();

          // Group by era while preserving chronological order.
          final items = <_ListItem>[];
          String? lastEra;
          for (final e in filtered) {
            if (e.era != lastEra) {
              items.add(_ListItem.eraHeader(e.era));
              lastEra = e.era;
            }
            items.add(_ListItem.event(e));
          }

          final yearStyle = _yearStyle(t, scheme);
          final yearLane = _measureYearLane(context, all, locale, yearStyle);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                children: [
                  _buildSearchField(locale),
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          (uiStrings['bibleTimelineCount']?[locale] ??
                                  '{count} events')
                              .replaceAll(
                                  '{count}', '${filtered.length}'),
                          style: TextStyle(
                            fontSize: t.scaled(12),
                            color: scheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              uiStrings['bibleTimelineNoMatches']
                                      ?[locale] ??
                                  'No events match.',
                              style: TextStyle(
                                color: scheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 32),
                            itemCount: items.length,
                            itemBuilder: (_, i) {
                              final it = items[i];
                              if (it.isEra) {
                                return _EraDivider(
                                  era: it.eraKey!,
                                  locale: locale,
                                  scheme: scheme,
                                );
                              }
                              final ev = it.event!;
                              return _EventTile(
                                event: ev,
                                locale: locale,
                                scheme: scheme,
                                yearLane: yearLane,
                                yearStyle: yearStyle,
                                expanded: _expanded.contains(ev.id),
                                onToggleExpand: () => setState(() {
                                  if (_expanded.contains(ev.id)) {
                                    _expanded.remove(ev.id);
                                  } else {
                                    _expanded.add(ev.id);
                                  }
                                }),
                                onTapRef: (raw) =>
                                    _jumpToRef(context, raw),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchField(String locale) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  iconSize: 18,
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
          hintText: uiStrings['bibleTimelineSearchHint']?[locale] ??
              'Search events, descriptions…',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
    );
  }

  Future<void> _jumpToRef(BuildContext context, String raw) async {
    final ref = parseReference(raw);
    if (ref == null) {
      final locale = context.read<AppSettings>().locale;
      final msg = (uiStrings['couldNotParseRef']?[locale] ??
              "Couldn't parse reference: {ref}")
          .replaceFirst('{ref}', raw);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
      ));
      return;
    }
    final mp = context.read<MainProvider>();
    final result =
        await jumper.resolveAndPrepareJump(reference: ref, mp: mp);
    if (!context.mounted) return;
    final ok = await jumper.showJumpResultSnackBar(context, result);
    if (!ok || !context.mounted) return;
    navigateToReader(context);
  }
}

// ── List item type ──────────────────────────────────────────────

class _ListItem {
  final String? eraKey;
  final TimelineEvent? event;
  const _ListItem._({this.eraKey, this.event});
  factory _ListItem.eraHeader(String era) => _ListItem._(eraKey: era);
  factory _ListItem.event(TimelineEvent e) => _ListItem._(event: e);
  bool get isEra => eraKey != null;
}

// ── Era divider ─────────────────────────────────────────────────

class _EraDivider extends StatelessWidget {
  final String era;
  final String locale;
  final ColorScheme scheme;
  const _EraDivider({
    required this.era,
    required this.locale,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    // 2026-05-10 (v1.2.36): the icon/text use the brightness-aware
    // variant so they stay readable on the dark theme; the gradient
    // and border keep the raw era colour because they're decorative
    // accents (low alpha + thin border) where the deeper hue is
    // appropriate.
    final color = _eraColor(era);
    final t = WbType.of(context);
    final fg = _eraColorOn(Theme.of(context).brightness, era);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.0),
          ],
        ),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_edu, size: 14, color: fg),
              const SizedBox(width: 6),
              Text(
                _eraLabel(era, locale),
                style: TextStyle(
                  fontSize: t.scaled(12),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: fg,
                ),
              ),
            ],
          ),
          // The seam, said once where it happens rather than eight
          // times. Everything from Abraham down is counted back from
          // Solomon's fourth year; the eight events above him are not,
          // and the two halves are 110 years out of step. Repairing it
          // means fixing a year for the creation, which this repository
          // deliberately does not do — so it is disclosed instead, with
          // a door to the chart that does have the text's own numbers.
          if (era == 'antediluvian') ...[
            const SizedBox(height: 6),
            Text(
              uiStrings['timelineAntediluvianBasis']?[locale] ??
                  uiStrings['timelineAntediluvianBasis']?['en'] ??
                  '',
              style: TextStyle(
                fontSize: t.scaled(11),
                color: scheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ChronologyPage(),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: fg,
                ),
                child: Text(
                  uiStrings['timelineOpenChronology']?[locale] ??
                      'Open Bible Chronology',
                  style: TextStyle(
                    fontSize: t.scaled(11.5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One sentence saying what a year rests on, keyed on the asset's own
/// `basis` vocabulary. An unrecognised value reads as the weakest of
/// the three rather than as nothing, so a future basis added to the
/// generator cannot make the app silently confident.
String _basisText(TimelineEvent e, String locale) {
  const keys = <String, String>{
    'scripture': 'timelineBasisScripture',
    'thiele': 'timelineBasisThiele',
    'conventional': 'timelineBasisConventional',
  };
  final key = keys[e.basis] ?? 'timelineBasisConventional';
  return uiStrings[key]?[locale] ?? uiStrings[key]?['en'] ?? '';
}

// ── Event tile ──────────────────────────────────────────────────

class _EventTile extends StatelessWidget {
  final TimelineEvent event;
  final String locale;
  final ColorScheme scheme;
  final double yearLane;
  final TextStyle yearStyle;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final void Function(String raw) onTapRef;

  const _EventTile({
    required this.event,
    required this.locale,
    required this.yearLane,
    required this.yearStyle,
    required this.scheme,
    required this.expanded,
    required this.onToggleExpand,
    required this.onTapRef,
  });

  @override
  Widget build(BuildContext context) {
    final color = _eraColor(event.era);
    final t = WbType.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggleExpand,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Year column.
              SizedBox(
                width: yearLane,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    event.displayYear(locale),
                    textAlign: TextAlign.right,
                    style: yearStyle,
                  ),
                ),
              ),
              // Bullet on the timeline rail.
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.surface,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: LeftAccentCard(
                  // v1.3.x: was Container(BoxDecoration(border:
                  // Border(left:...), borderRadius:...)) — non-uniform
                  // border + radius throws in Border.paint.
                  padding:
                      const EdgeInsets.fromLTRB(10, 6, 10, 8),
                  background: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  accentColor: color.withValues(alpha: 0.55),
                  accentWidth: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.localizedTitle(locale),
                              style: TextStyle(
                                fontSize: t.scaled(14.5),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Icon(
                            expanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 18,
                            color: scheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                      if (expanded) ...[
                        const SizedBox(height: 4),
                        Text(
                          event.localizedDesc(locale),
                          style: TextStyle(
                            fontSize: t.scaled(13),
                            color:
                                scheme.onSurface.withValues(alpha: 0.85),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // What the year rests on. Shown only when the row
                        // is open, because a reader scanning the column
                        // wants the shape of the century, and the "c."
                        // in the year already tells them which years are
                        // reconstructions.
                        Text(
                          _basisText(event, locale),
                          style: TextStyle(
                            fontSize: t.scaled(11.5),
                            fontStyle: FontStyle.italic,
                            color:
                                scheme.onSurface.withValues(alpha: 0.6),
                            height: 1.45,
                          ),
                        ),
                      ],
                      if (event.refs.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final r in event.refs)
                              _RefChip(
                                raw: r,
                                locale: locale,
                                scheme: scheme,
                                onTap: () => onTapRef(r),
                              ),
                          ],
                        ),
                      ],
                    ],
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

class _RefChip extends StatelessWidget {
  final String raw;
  final String locale;
  final ColorScheme scheme;
  final VoidCallback onTap;
  const _RefChip({
    required this.raw,
    required this.locale,
    required this.scheme,
    required this.onTap,
  });

  String _localized() {
    final p = parseReference(raw);
    if (p == null) return raw;
    final book = localeAwareBookName(p.englishBook, locale);
    final tail = p.toString().replaceFirst(p.englishBook, '');
    return '$book$tail';
  }

  @override
  Widget build(BuildContext context) {
    final t = WbType.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.35),
              width: 0.7,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_rounded,
                  size: 11, color: scheme.primary),
              const SizedBox(width: 3),
              Text(
                _localized(),
                style: TextStyle(
                  fontSize: t.scaled(11),
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Era helpers (palette mirrors family tree) ──────────────────

String _eraLabel(String era, String locale) {
  const labels = {
    'antediluvian': {
      'en': 'Antediluvian (Creation → Flood)',
      'zh-Hans': '洪水之前（创世 → 洪水）',
      'zh-Hant': '洪水之前（創世 → 洪水）',
    },
    'patriarchs': {
      'en': 'Patriarchs (Abraham → Joseph)',
      'zh-Hans': '列祖时代（亚伯拉罕 → 约瑟）',
      'zh-Hant': '列祖時代（亞伯拉罕 → 約瑟）',
    },
    'mosaic': {
      'en': 'Exodus & Wilderness',
      'zh-Hans': '出埃及与旷野',
      'zh-Hant': '出埃及與曠野',
    },
    'conquest': {
      'en': 'Conquest & Judges',
      'zh-Hans': '征服与士师',
      'zh-Hant': '征服與士師',
    },
    'monarchy': {
      'en': 'United & Divided Monarchy',
      'zh-Hans': '联合与分裂王国',
      'zh-Hant': '聯合與分裂王國',
    },
    'exile': {
      'en': 'Exile & Return',
      'zh-Hans': '被掳与回归',
      'zh-Hant': '被擄與回歸',
    },
    'intertestamental': {
      'en': 'Inter-Testamental Period',
      'zh-Hans': '两约之间',
      'zh-Hant': '兩約之間',
    },
    'nt': {
      'en': 'New Testament',
      'zh-Hans': '新约',
      'zh-Hant': '新約',
    },
  };
  return labels[era]?[locale] ?? era.toUpperCase();
}

// The palette itself lives in constants/era_palette.dart — it was
// written out here AND in family_tree_page.dart, with a
// brightness-aware variant in each, so re-toning it meant four edits
// kept in step by hand. The era vocabularies still differ per view;
// only the colours are shared.
Color _eraColor(String era) => eraColor(era);

/// 2026-05-10 (v1.2.36): brightness-aware variant of `_eraColor`.
/// User reported that era titles ("OT / NT / Patriarchs / …") were
/// hard to read in dark mode — the palette above is tuned for light
/// surfaces (lightness ~33–44 %) and fades into the dark theme's
/// `#121212`-ish surface. Lightening via `Color.lerp(c, Colors.white,
/// 0.45)` keeps the era's hue (so colour-coding still works) while
/// pushing the value high enough to clear the WCAG contrast threshold
/// against a dark surface.
///
/// Use this everywhere a hardcoded era colour is rendered as text /
/// icon / chip-foreground; raw `_eraColor` is fine for backgrounds /
/// borders / accents that DON'T need to clear contrast.
Color _eraColorOn(Brightness brightness, String era) {
  final base = _eraColor(era);
  if (brightness == Brightness.dark) {
    return Color.lerp(base, Colors.white, 0.45) ?? base;
  }
  return base;
}
