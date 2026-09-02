import 'package:flutter/material.dart';

import 'package:seeksparks/constants/era_palette.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/text_patterns.dart' show sanitizeForSearch;
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/widgets/left_accent_card.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/biblical_person.dart';
import 'package:seeksparks/models/timeline_event.dart';
import 'package:seeksparks/pages/chronology_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/family_tree_service.dart';
import 'package:seeksparks/services/timeline_service.dart';
import 'package:seeksparks/widgets/person_detail_sheet.dart';
import 'package:seeksparks/utils/jump_to_reference.dart' as jumper;
import 'package:seeksparks/utils/reference_parser.dart';
import 'package:seeksparks/utils/timeline_basis.dart';
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
/// WHY EVERY YEAR SAYS WHAT IT RESTS ON. 75 of the 98 events are
/// `conventional` — a reconstruction no chain of stated intervals
/// reaches — 5 are Thiele's outright, and 18 are counted from Thiele's
/// anchor along intervals the text states. Until v1.6.142 the page
/// printed all 98 identically, because [TimelineEvent] dropped `basis`
/// and `approximate` when it parsed the asset. A reader was told
/// "4000 BC" for the creation in the same voice as "1446 BC" for the
/// exodus, and only one of those is countable from anything.
///
/// THE SPLIT WAS 85/13 UNTIL v1.6.146, AND THAT WAS NOT A MEASUREMENT.
/// It came from thirteen event ids typed into `tools/audit_dates.py`,
/// which never checked a year. Nine events it called `conventional`
/// have years the text's own arithmetic fixes exactly — Ishmael's
/// birth is stated outright at Genesis 16:16, and the page told the
/// reader the text fixes no year for it. The basis is now derived, and
/// a step whose arithmetic disagrees with the shipped year abstains
/// rather than re-dating it.
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
/// Search at top filters by title / description / id / linked person
/// name, in all three scripts.
/// Tap a verse-ref chip → jumps to that verse in the reader.
/// Tap a person chip → opens that person's family-tree sheet.
///
/// THE PEOPLE WERE IN THE ASSET AND ON NO SCREEN (#318 phase 20).
/// `bible_timeline.json` files `personIds` on 61 of the 98 events — 88
/// links naming 37 people — and [TimelineEvent] had parsed the field
/// since the model was written. `personIds` appeared at exactly three
/// lines in all of `lib/`, all three inside `timeline_event.dart`:
/// declaration, constructor, `fromJson`. Nothing read it.
///
/// Publishing 88 claims meant auditing them first, and the audit found
/// the two assets disagreeing about Moses: the tree said -1525..-1405,
/// the timeline -1526 and -1406, both stated exactly, on the same
/// basis, citing the same two verses. The tree was corrected and
/// `test/timeline_person_join_test.dart` now walks every link.
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
    _future = _load();
    _searchController = TextEditingController();
  }

  /// The family tree is awaited here rather than looked up lazily
  /// because [FamilyTreeService.byId] is synchronous and returns null
  /// until [FamilyTreeService.loadAll] has completed. A chip row that
  /// filled in one frame late would be a row that silently rendered
  /// empty, and the search below would agree with it.
  Future<List<TimelineEvent>> _load() async {
    final loaded = await Future.wait([
      TimelineService.instance.loadAll(),
      FamilyTreeService.instance.loadAll(),
    ]);
    return loaded.first as List<TimelineEvent>;
  }

  /// The people this event files, in the asset's own order, dropping
  /// ids the tree does not hold. `test/timeline_person_join_test.dart`
  /// asserts all 88 resolve, so the drop is a belt on a fastened
  /// braces — but a missing id must not take the row down with it.
  List<BiblicalPerson> _peopleOf(TimelineEvent e) => [
        for (final id in e.personIds)
          if (FamilyTreeService.instance.byId(id) != null)
            FamilyTreeService.instance.byId(id)!,
      ];

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
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: uiStrings['timelineAbout']?[locale] ?? 'About this chart',
            onPressed: () => _showAbout(locale),
          ),
          const LanguageSwitcherButton(),
          const HomeIconButton(),
        ],
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
                    // The people are searched because they are now
                    // PRINTED. 17 of the 88 links name someone the
                    // title and description never do, so without this
                    // the page would show a reader a chip reading
                    // "Jeconiah" and then answer "0 events" when they
                    // typed it — denying a record it was displaying.
                    // All three scripts, because the chip renders one
                    // and the reader may be typing another.
                    for (final p in _peopleOf(e)) ...[
                      p.name,
                      p.nameZhHans,
                      p.nameZhHant,
                      // And the KJV's spelling, for the same reason one
                      // step further: the chip renders "Kenan" and the
                      // reader's Bible reads "Cainan".
                      p.nameKjv,
                    ],
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
                          (uiStrings[filtered.length == 1
                                          ? 'bibleTimelineCountOne'
                                          : 'bibleTimelineCount']?[locale] ??
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
                                people: _peopleOf(ev),
                                onTapRef: (raw) =>
                                    _jumpToRef(context, raw),
                                onTapPerson: _showPerson,
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
              'Search events and people…',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
    );
  }

  /// The shape of the whole chart, which no single row can state: 75 of
  /// 98 years are commonly published reconstructions and the axis is
  /// counted back from one fixed point. Every row already discloses its
  /// own basis on expand (since v1.6.142); this says it once for the
  /// chart as a whole. Modelled on `FamilyTreePage._showAbout`.
  Future<void> _showAbout(String locale) async {
    await TimelineService.instance.loadAll();
    if (!mounted) return;
    final svc = TimelineService.instance;
    final meta = svc.meta;
    final all = svc.allOrEmpty();
    final septuagintCount =
        all.where((e) => e.septuagintYear != null).length;
    String s(String key, String fallback) =>
        uiStrings[key]?[locale] ?? fallback;
    String basisString(String key) =>
        uiStrings[key]?[locale] ?? uiStrings[key]?['en'] ?? '';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 720),
      shape: const RoundedRectangleBorder(),
      builder: (sheetCtx) {
        final wb = WbColors.of(sheetCtx);
        final t = WbType.of(sheetCtx);
        Widget section(String heading, List<String> paragraphs) {
          final body = paragraphs.where((p) => p.isNotEmpty).toList();
          if (body.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(heading,
                    style: TextStyle(
                        color: wb.mutedText,
                        fontSize: t.chrome,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                for (final p in body) ...[
                  Text(p,
                      style: TextStyle(
                          color: wb.mutedText, fontSize: t.chrome, height: 1.35)),
                  if (p != body.last) const SizedBox(height: 8),
                ],
              ],
            ),
          );
        }

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s('timelineAbout', 'About this chart'),
                    style: TextStyle(
                        color: wb.text,
                        fontSize: t.text,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  s('bibleTimelineCount', '{count} events')
                      .replaceAll('{count}', '${all.length}'),
                  style: TextStyle(color: wb.mutedText, fontSize: t.chrome),
                ),
                const SizedBox(height: 10),
                section(
                  s('timelineAboutAnchor', 'What every year is counted from'),
                  [meta.anchorFor(locale)],
                ),
                section(
                  s('timelineAboutHowMany', 'How many rest on what'),
                  [
                    '${meta.counts['conventional'] ?? 0} — '
                        '${basisString('timelineBasisConventional')}',
                    '${meta.counts['scripture+thiele'] ?? 0} — '
                        '${basisString('timelineBasisScripture')}',
                    '${meta.counts['thiele'] ?? 0} — '
                        '${basisString('timelineBasisThiele')}',
                  ],
                ),
                Text(
                  s('timelineAboutSeptuagint',
                          '{count} events also carry the year the '
                          'Septuagint gives.')
                      .replaceAll('{count}', '$septuagintCount'),
                  style: TextStyle(
                      color: wb.mutedText, fontSize: t.chrome, height: 1.35),
                ),
                const SizedBox(height: 10),
                Text(
                  meta.noteFor(locale),
                  style: TextStyle(
                      color: wb.mutedText, fontSize: t.chrome, height: 1.35),
                ),
              ],
            ),
          ),
        );
      },
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

  /// The same sheet the family tree opens, with the same lineage
  /// hopping. It is opened here rather than pushing the family tree
  /// page because the reader asked about one person in one event, and
  /// dropping them into a 277-row scroller loses their place on the
  /// timeline.
  Future<void> _showPerson(BiblicalPerson p) async {
    final settings = context.read<AppSettings>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.35,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => PersonDetailSheet(
          person: p,
          locale: settings.locale,
          scrollController: scrollController,
          onPersonTap: (other) {
            Navigator.of(sheetCtx).maybePop();
            _showPerson(other);
          },
        ),
      ),
    );
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

  /// Resolved by the host, not by this widget, so that the row and the
  /// search filter cannot disagree about who is in the event.
  final List<BiblicalPerson> people;
  final void Function(BiblicalPerson) onTapPerson;

  const _EventTile({
    required this.event,
    required this.locale,
    required this.yearLane,
    required this.yearStyle,
    required this.scheme,
    required this.expanded,
    required this.onToggleExpand,
    required this.onTapRef,
    required this.people,
    required this.onTapPerson,
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
                          basisText(event, locale),
                          style: TextStyle(
                            fontSize: t.scaled(11.5),
                            fontStyle: FontStyle.italic,
                            color:
                                scheme.onSurface.withValues(alpha: 0.6),
                            height: 1.45,
                          ),
                        ),
                        if (event.septuagintYear != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            (uiStrings['timelineSeptuagintYear']?[locale] ??
                                    uiStrings['timelineSeptuagintYear']
                                        ?['en'] ??
                                    '')
                                .replaceFirst(
                              '{year}',
                              event.displaySeptuagintYear(locale) ?? '',
                            ),
                            style: TextStyle(
                              fontSize: t.scaled(11.5),
                              fontStyle: FontStyle.italic,
                              color:
                                  scheme.onSurface.withValues(alpha: 0.6),
                              height: 1.45,
                            ),
                          ),
                        ],
                        // The verses the year was counted along. Kept
                        // apart from the narrative chips below and
                        // labelled, because they answer a different
                        // question and often name different chapters.
                        if (event.datingRefs.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                uiStrings['timelineDatedBy']?[locale] ??
                                    uiStrings['timelineDatedBy']?['en'] ??
                                    '',
                                style: TextStyle(
                                  fontSize: t.scaled(11),
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.55),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              for (final r in event.datingRefs)
                                _RefChip(
                                  raw: r,
                                  locale: locale,
                                  scheme: scheme,
                                  onTap: () => onTapRef(r),
                                  outlined: true,
                                ),
                            ],
                          ),
                        ],
                        // The people the record files under this event.
                        // Both ref rows spend `scheme.primary`, which
                        // on this page means "tapping this opens the
                        // reader at a verse". A person chip does not —
                        // it opens a sheet — so it is deliberately not
                        // given that hue, and carries the family tree's
                        // own `person_outline` instead of a third
                        // invented glyph.
                        if (people.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                uiStrings['timelinePeople']?[locale] ??
                                    uiStrings['timelinePeople']?['en'] ??
                                    '',
                                style: TextStyle(
                                  fontSize: t.scaled(11),
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.55),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              for (final p in people)
                                _PersonChip(
                                  person: p,
                                  locale: locale,
                                  scheme: scheme,
                                  onTap: () => onTapPerson(p),
                                ),
                            ],
                          ),
                        ],
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

  /// Dating verses read as an outline, narrative refs as a fill. Two
  /// chip rows that jump to the same reader would otherwise look like
  /// one list split by a line break.
  final bool outlined;
  const _RefChip({
    required this.raw,
    required this.locale,
    required this.scheme,
    required this.onTap,
    this.outlined = false,
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: outlined
                ? Colors.transparent
                : scheme.primaryContainer.withValues(alpha: 0.25),
            border: Border.all(
              color: scheme.primary.withValues(alpha: outlined ? 0.5 : 0.35),
              width: 0.7,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(outlined ? Icons.straighten_rounded : Icons.menu_book_rounded,
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

/// A person the event's record names, and a door into their sheet.
///
/// NO YEARS ON THE CHIP, though [BiblicalPerson.displayYears] is right
/// there and the family tree's own chip prints them. This row sits two
/// lines under a year column and a hedged event year, and a chip
/// reading "Moses (1526–1406 BC)" beside a row reading "1446 BC" asks
/// the reader to hold three dates to read one. The sheet gives the
/// lifespan the moment the chip is tapped.
class _PersonChip extends StatelessWidget {
  final BiblicalPerson person;
  final String locale;
  final ColorScheme scheme;
  final VoidCallback onTap;

  const _PersonChip({
    required this.person,
    required this.locale,
    required this.scheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = WbType.of(context);
    final ink = scheme.onSurface.withValues(alpha: 0.75);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: scheme.onSurface.withValues(alpha: 0.05),
            border: Border.all(
              color: scheme.onSurface.withValues(alpha: 0.25),
              width: 0.7,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_outline, size: 11, color: ink),
              const SizedBox(width: 3),
              Text(
                person.localizedName(locale),
                style: TextStyle(
                  fontSize: t.scaled(11),
                  color: ink,
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
