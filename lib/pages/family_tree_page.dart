import 'dart:async';

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/era_palette.dart';
import 'package:flutter/rendering.dart';
import 'package:seeksparks/utils/clipboard_helper.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/text_patterns.dart' show sanitizeForSearch;
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/biblical_person.dart';
import 'package:seeksparks/services/family_tree_service.dart';
import 'package:seeksparks/utils/biblical_role.dart' show localizedRole;
import 'package:seeksparks/utils/floating_toast.dart';
import 'package:seeksparks/widgets/home_icon_button.dart';
import 'package:seeksparks/widgets/language_switcher_button.dart';
import 'package:seeksparks/widgets/localized_back_button.dart';
import 'package:seeksparks/widgets/person_detail_sheet.dart';
import 'package:seeksparks/widgets/wb_surfaces.dart';

/// Browseable Bible family tree, modelled on the structure of the
/// Wikipedia article *"Genealogies in the Bible"*:
///
///   * **Sectioned per family / era.** Eight collapsible sections
///     (Antediluvian / Post-Flood / Patriarchs / Mosaic / Davidic
///     Line / Kings of Judah / Exile & Return / New Testament).
///     Each section is a self-contained mini-tree — the walk
///     descends only into same-era children, so Levi appears in
///     "Patriarchs" but his Mosaic-era descendants (Kohath,
///     Jochebed → Aaron / Moses / Miriam) live under the
///     "Mosaic" section instead. No more 96-deep walls.
///   * **Comparison table at the bottom.** Linear Adam → Jesus
///     chain (rows) × Bible-source columns (Genesis 5 / Genesis
///     11 / 1 Chronicles 1 / Ruth 4 / Matthew 1 / Luke 3); cells
///     ✓ when the person's refs include that book/chapter. Tap
///     any row → detail sheet. Horizontally scrollable on
///     phones.
///   * **Search**: filter-as-you-type. Sections that contain
///     matches auto-uncollapse; ancestor rows auto-expand;
///     matches get the workbench's `hit` fill.
///   * **Tap behaviour**: chevron toggles children, row body tap
///     opens the detail sheet. Conventional, least-surprise.
///
/// Per-row info (kept across iterations): role pill, year span,
/// spouse chips inline, verse-ref count badge, accent stripe
/// (priestly red, royal blue, messianic gold, prophetic purple).
///
/// 2026-08-08 (task #279): this is a workbench Resource now, not a
/// standalone consumer screen, so it wears the workbench's chrome —
/// square, hairline, no shadows — and honours 护眼纸质 by re-applying
/// [workbenchTheme] the way `workbench_page` does.
///
/// The one thing the pass did NOT flatten is era colour. The workbench
/// spends saturation on exactly two things, the version tag and the
/// link, and both put the hue on INK; era hue is DATA (see
/// `era_palette.dart`), so it survives here on ink too — a title, a 2px
/// left rule, a tag's text — and dies wherever it was only a wash.
class FamilyTreePage extends StatelessWidget {
  const FamilyTreePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Re-applying the theme is what carries 护眼纸质 in here. Without it
    // a reader in paper mode opens this Resource from a cream workbench
    // and lands on a grey page — the inversion `workbench_page` fixed
    // for itself the same way.
    //
    // It wraps the STATE rather than sitting inside its `build`, because
    // `_showDetail` opens the person sheet from `State.context`. A Theme
    // applied inside `build` would be below that context, so the sheet
    // would come up in the app's palette while the page behind it was
    // cream.
    return Theme(
      data: workbenchTheme(
        Theme.of(context),
        paper: context.watch<AppSettings>().readingPaperTheme,
        textScale: WbType.of(context).textScale,
      ),
      child: const _FamilyTreeBody(),
    );
  }
}

class _FamilyTreeBody extends StatefulWidget {
  const _FamilyTreeBody();

  @override
  State<_FamilyTreeBody> createState() => _FamilyTreePageState();
}

class _FamilyTreePageState extends State<_FamilyTreeBody> {
  Future<_TreeData>? _future;
  String _query = '';
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;

  /// Persons whose children rows are visible. Search auto-unions
  /// in ancestor chains so matches are revealed in context.
  final Set<String> _expanded = {};

  /// Era keys that are currently collapsed. Default state is "all
  /// sections collapsed" so the page opens as a clean TOC view of
  /// 8 era headers + comparison table — the user clicks into the
  /// era they're interested in. Once a section is opened, every
  /// person inside is rendered in full (see `_load`).
  final Set<String> _collapsedEras = {};

  /// Per-era anchor keys so the bridge chips at the end of one
  /// section can `Scrollable.ensureVisible` the next section into
  /// view when tapped.
  final Map<String, GlobalKey> _eraKeys = {};

  /// Per-person row keys, populated lazily as rows render. Used so
  /// a bridge-leaf tap can scroll *the destination person's row*
  /// into view (not just the section header) and so we can
  /// highlight that row with a flash for a few seconds.
  final Map<String, GlobalKey> _personKeys = {};

  /// Person id currently being flashed as "you just jumped here".
  /// Cleared by [_highlightTimer] after [_kHighlightDuration].
  String? _recentlyJumpedTo;
  Timer? _highlightTimer;
  static const Duration _kHighlightDuration = Duration(seconds: 3);

  /// Bridge map: "at the end of era X, link to person Y (and Z) who
  /// continues the lineage in the next era." Drives the
  /// "Continues with: …" footer row inside each expanded section.
  /// Mosaic and NT are dead-ends (no canonical continuation), so
  /// their lists are empty.
  static const Map<String, List<String>> _eraBridges = {
    'antediluvian': ['noah'],
    'post_flood': ['abraham'],
    'patriarchs': ['kohath', 'perez'],
    'mosaic': [],
    'davidic_line': ['david'],
    // Kings era bridges to BOTH Matthew's exile chain (via
    // Shealtiel, son of Jeconiah) and Luke's Lukan Lineage (via
    // Mattatha, descendant of Nathan son of David).
    'kings': ['shealtiel', 'mattatha_lk_31'],
    'exile': ['joseph_father_of_jesus'],
    'lukan_lineage': ['mary'],
    'nt': [],
  };

  /// Canonical era ordering — drives the order of section blocks.
  static const List<String> _eraOrder = [
    'antediluvian',
    'post_flood',
    'patriarchs',
    'mosaic',
    'davidic_line',
    'kings',
    'exile',
    'lukan_lineage',
    'nt',
  ];

  /// Bible-source columns for the comparison table at the bottom.
  /// Each tuple = (column label key, list of "Book Chapter"
  /// prefixes that count as a hit). The label key resolves through
  /// ui_strings for short table headers.
  static const List<(String, List<String>)> _comparisonColumns = [
    ('familyTreeColGen5', ['Genesis 5']),
    ('familyTreeColGen11', ['Genesis 11']),
    (
      'familyTreeColChron1',
      ['1 Chronicles 1', '1 Chronicles 2', '1 Chronicles 3']
    ),
    ('familyTreeColRuth4', ['Ruth 4']),
    ('familyTreeColMatt1', ['Matthew 1']),
    ('familyTreeColLuke3', ['Luke 3']),
  ];

  @override
  void initState() {
    super.initState();
    _future = _load();
    _searchController = TextEditingController();
    _scrollController = ScrollController();
    // Default-collapse every section. User opens what they're
    // interested in; a search match auto-uncollapses its section.
    _collapsedEras.addAll(_eraOrder);
    for (final e in _eraOrder) {
      _eraKeys[e] = GlobalKey();
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _personKeyFor(String id) =>
      _personKeys.putIfAbsent(id, () => GlobalKey());

  Future<_TreeData> _load() async {
    final svc = FamilyTreeService.instance;
    final all = await svc.loadAll();
    // Default-expand every parent in the dataset so each section's
    // mini-tree shows its full lineage on first load (Wikipedia-
    // style "everything visible"). User can collapse via chevrons.
    for (final p in all) {
      if (p.childIds.isNotEmpty) {
        _expanded.add(p.id);
      }
    }
    return _TreeData(all: all, svc: svc);
  }

  // ── Filter helpers ───────────────────────────────────────────────

  /// Tiered relevance search. Returns only the **best non-empty
  /// tier** of matches so a search for "Jesus" returns just Jesus
  /// (exact name match) rather than every ancestor whose summary
  /// happens to mention Him.
  ///
  /// Tiers, in priority order:
  ///   1. Exact name match (any of en / zh-Hans / zh-Hant)
  ///   2. Name starts with
  ///   3. Name contains
  ///   4. Role contains (e.g. "PATRIARCH" → all patriarchs)
  ///   5. Summary contains (catch-all — only used if all earlier
  ///      tiers are empty)
  ///
  /// Within a tier, results are sorted by canonical era order so
  /// the user sees the chronological flow (Adam first, NT last).
  List<BiblicalPerson> _filtered(List<BiblicalPerson> all, String query) {
    final q = sanitizeForSearch(query).toLowerCase();
    if (q.isEmpty) return const [];

    int eraIndexOf(BiblicalPerson p) {
      final i = _eraOrder.indexOf(p.era ?? '');
      return i < 0 ? _eraOrder.length : i;
    }

    final tiers = <int, List<BiblicalPerson>>{};
    void addTier(int tier, BiblicalPerson p) {
      tiers.putIfAbsent(tier, () => <BiblicalPerson>[]).add(p);
    }

    for (final p in all) {
      final names = <String>[
        p.name.toLowerCase(),
        (p.nameZhHans ?? '').toLowerCase(),
        (p.nameZhHant ?? '').toLowerCase(),
      ];
      final role = (p.role ?? '').toLowerCase();
      final summary = [
        p.summary,
        p.summaryZhHans ?? '',
        p.summaryZhHant ?? '',
      ].join(' ').toLowerCase();

      if (names.any((n) => n.isNotEmpty && n == q)) {
        addTier(1, p);
      } else if (names.any((n) => n.startsWith(q))) {
        addTier(2, p);
      } else if (names.any((n) => n.contains(q))) {
        addTier(3, p);
      } else if (role.isNotEmpty && role.contains(q)) {
        addTier(4, p);
      } else if (summary.contains(q)) {
        addTier(5, p);
      }
    }

    // Aggregation rules:
    //   • If ANY name match (tiers 1-3): return all name matches.
    //     "Joseph" → 4 results (tribe + father of Jesus + 2 Lukan
    //     Josephs); "Jesus" → 1 result (only Jesus exactly).
    //   • Otherwise role matches (tier 4) — e.g. "PATRIARCH"
    //     surfaces every patriarch.
    //   • Otherwise summary matches (tier 5) as a last-resort
    //     catch-all so users can find people by topic keywords.
    List<BiblicalPerson> sortByEra(List<BiblicalPerson> xs) {
      xs.sort((a, b) => eraIndexOf(a).compareTo(eraIndexOf(b)));
      return xs;
    }

    final nameHits = <BiblicalPerson>[
      for (final t in [1, 2, 3])
        if (tiers.containsKey(t)) ...tiers[t]!,
    ];
    if (nameHits.isNotEmpty) return sortByEra(nameHits);
    if (tiers.containsKey(4)) return sortByEra(tiers[4]!);
    if (tiers.containsKey(5)) return sortByEra(tiers[5]!);
    return const [];
  }

  Set<String> _ancestorsOf(BiblicalPerson p, FamilyTreeService svc) {
    final out = <String>{p.id};
    var cur = p;
    for (var i = 0; i < 200; i++) {
      final pid = cur.fatherId ?? cur.motherId;
      if (pid == null || out.contains(pid)) break;
      out.add(pid);
      final next = svc.byId(pid);
      if (next == null) break;
      cur = next;
    }
    return out;
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(uiStrings['familyTree']?[locale] ?? 'Family Tree'),
        actions: const [LanguageSwitcherButton(), HomeIconButton()],
      ),
      body: FutureBuilder<_TreeData>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                // 2026-05-10 (v1.2.21): localised — was hardcoded
                // English. Reuses `loadErrorTitle` ui-string that
                // LoadingPage's error scaffold already uses, with
                // the raw error suffixed for diagnostics.
                child: Text(
                  '${uiStrings['loadErrorTitle']?[locale] ?? 'Failed to load'}: ${snap.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            );
          }
          final data = snap.data!;
          final filtered =
              _query.trim().isEmpty ? null : _filtered(data.all, _query.trim());

          // Compute match + ancestor sets so sections auto-expand
          // around matches.
          final matchIds = <String>{};
          final ancestorIds = <String>{};
          if (filtered != null) {
            for (final m in filtered) {
              matchIds.add(m.id);
              ancestorIds.addAll(_ancestorsOf(m, data.svc));
            }
          }

          // Era → list of people in that era. Used by sections.
          final byEra = <String, List<BiblicalPerson>>{
            for (final e in _eraOrder) e: <BiblicalPerson>[],
          };
          for (final p in data.all) {
            final era = p.era;
            if (era != null && byEra.containsKey(era)) {
              byEra[era]!.add(p);
            }
          }

          // Adam → Jesus spine for the comparison table. Walk
          // father chain backwards from Jesus and reverse.
          final spine = _computeAdamToJesus(data);

          // Cap the content width so on a wide iPad / desktop the
          // article doesn't sprawl edge-to-edge — readability over
          // 960 px lines tanks. On phones this is a no-op.
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                children: [
                  _buildSearchField(locale),
                  _buildSummary(
                    data: data,
                    filtered: filtered,
                    locale: locale,
                    wb: wb,
                    t: t,
                  ),
                  Expanded(
                    // Search-active: show a clean flat search-results
                    // list instead of the article. Tapping a result
                    // clears the query and jumps to that person in
                    // their era's section. This is what the user
                    // asked for — search should "just show the one"
                    // matched person, not auto-expand the whole
                    // article inline.
                    child: filtered == null
                        ? _buildArticle(
                            data: data,
                            byEra: byEra,
                            spine: spine,
                            matchIds: matchIds,
                            ancestorIds: ancestorIds,
                            locale: locale,
                          )
                        : filtered.isEmpty
                            ? _buildNoMatches(locale, wb)
                            : _buildSearchResults(
                                matches: filtered,
                                locale: locale,
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

  Widget _buildNoMatches(String locale, WbColors wb) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          uiStrings['familyTreeNoMatches']?[locale] ??
              'No one matches that search.',
          style: TextStyle(color: wb.mutedText),
        ),
      ),
    );
  }

  // ── Search field ────────────────────────────────────────────────

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
          hintText: uiStrings['familyTreeSearchHint']?[locale] ??
              'Search by name or biography…',
          // No `border:` — `workbenchTheme`'s inputDecorationTheme is
          // already a square hairline. The radius-10 override this
          // replaces was the page arguing with the theme.
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
    );
  }

  Widget _buildSummary({
    required _TreeData data,
    required List<BiblicalPerson>? filtered,
    required String locale,
    required WbColors wb,
    required WbType t,
  }) {
    final s = filtered != null
        ? (uiStrings['familyTreeFilterCount']?[locale] ??
                '{count} of {total} people')
            .replaceAll('{count}', filtered.length.toString())
            .replaceAll('{total}', data.all.length.toString())
        : (uiStrings['familyTreeTotalCount']?[locale] ?? '{total} people')
            .replaceAll('{total}', data.all.length.toString());

    // "Are most sections collapsed?" → if so the toggle button
    // says "Expand all", otherwise "Collapse all". We compute on
    // the eras that actually have people; otherwise an empty era
    // would skew the heuristic.
    final eraCount = _eraOrder.length;
    final allCollapsed = _collapsedEras.length >= eraCount;
    final toggleLabel = allCollapsed
        ? (uiStrings['familyTreeExpandAll']?[locale] ?? 'Expand all')
        : (uiStrings['familyTreeCollapseAll']?[locale] ?? 'Collapse all');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              s,
              style: TextStyle(fontSize: t.scaled(12), color: wb.mutedText),
            ),
          ),
          // Power-user lever — flip every section open / closed at
          // once. Toggles between "expand all sections" and
          // "collapse all sections" based on the current global
          // state.
          TextButton.icon(
            onPressed: () => setState(() {
              if (allCollapsed) {
                _collapsedEras.clear();
              } else {
                _collapsedEras
                  ..clear()
                  ..addAll(_eraOrder);
              }
            }),
            icon: Icon(
              allCollapsed
                  ? Icons.unfold_more_rounded
                  : Icons.unfold_less_rounded,
              size: 16,
            ),
            label: Text(
              toggleLabel,
              style: TextStyle(fontSize: t.scaled(12)),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: wb.link,
            ),
          ),
        ],
      ),
    );
  }

  // ── Search results panel ────────────────────────────────────────

  /// Flat list of matched persons shown WHILE search is active.
  /// Replaces the article body so the user sees only the matches —
  /// addresses the "search shows nothing useful" report. Tapping a
  /// result clears the query and jumps to that person's row in the
  /// era's section (which auto-uncollapses).
  Widget _buildSearchResults({
    required List<BiblicalPerson> matches,
    required String locale,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
      itemCount: matches.length,
      itemBuilder: (_, i) => _SearchResultTile(
        person: matches[i],
        locale: locale,
        onTap: () {
          final p = matches[i];
          // Clear the query so the article body comes back, then
          // post-frame jump to this person's row + flash highlight.
          _searchController.clear();
          setState(() => _query = '');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final era = p.era;
            if (era != null && era.isNotEmpty) {
              _jumpToEra(era, personId: p.id);
            } else {
              _showDetail(p);
            }
          });
        },
      ),
    );
  }

  // ── Article body ────────────────────────────────────────────────

  Widget _buildArticle({
    required _TreeData data,
    required Map<String, List<BiblicalPerson>> byEra,
    required List<BiblicalPerson> spine,
    required Set<String> matchIds,
    required Set<String> ancestorIds,
    required String locale,
  }) {
    final sections = <Widget>[];
    for (final era in _eraOrder) {
      final eraPeople = byEra[era] ?? const <BiblicalPerson>[];
      if (eraPeople.isEmpty) continue;
      final hasMatch = matchIds.any((id) => eraPeople.any((p) => p.id == id));
      // Auto-uncollapse any section that contains a match.
      final isCollapsed = _collapsedEras.contains(era) && !hasMatch;
      // Resolve bridge people to objects for the "continues with"
      // footer chips. Bridges may live in a different era than the
      // current one (that's the whole point — they link forward).
      final bridges = <BiblicalPerson>[];
      final bridgeIds = _eraBridges[era] ?? const <String>[];
      for (final bid in bridgeIds) {
        final bp = data.svc.byId(bid);
        if (bp != null) bridges.add(bp);
      }
      sections.add(KeyedSubtree(
        key: _eraKeys[era],
        child: _EraSection(
          era: era,
          people: eraPeople,
          svc: data.svc,
          locale: locale,
          isCollapsed: isCollapsed,
          onToggle: () => setState(() {
            if (_collapsedEras.contains(era)) {
              _collapsedEras.remove(era);
            } else {
              _collapsedEras.add(era);
            }
          }),
          expanded: _expanded,
          ancestorIds: ancestorIds,
          matchIds: matchIds,
          onTogglePerson: (id) => setState(() {
            if (_expanded.contains(id)) {
              _expanded.remove(id);
            } else {
              _expanded.add(id);
            }
          }),
          onTapPerson: _showDetail,
          bridges: bridges,
          onJumpToEra: _jumpToEra,
          onJumpToSpouse: _jumpToSpouse,
          recentlyJumpedTo: _recentlyJumpedTo,
          personKeyFor: _personKeyFor,
        ),
      ));
    }

    return ListView(
      controller: _scrollController,
      // Force every section to be laid out eagerly (instead of
      // lazily as items scroll into view). Without this, sections
      // below the viewport don't have a settled RenderBox, so
      // their GlobalKey.currentContext is null and bridge jumps
      // (e.g. Patriarchs → Lukan Lineage) silently no-op with a
      // "no context for lukan_lineage / mattatha_lk_31" debug.
      // We only have 9 list items (8 sections + comparison table)
      // so the memory cost is trivial.
      // v1.3.95 (Flutter 3.44): dropped the deprecated `cacheExtent:
      // double.infinity` (its replacement now takes a ScrollCacheExtent
      // object). Only 9 items here, so the default cache extent is fine.
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        ...sections,
        _ComparisonTable(
          spine: spine,
          locale: locale,
          matchIds: matchIds,
          comparisonColumns: _comparisonColumns,
          onTapPerson: _showDetail,
        ),
      ],
    );
  }

  // ── Adam → Jesus spine ─────────────────────────────────────────

  /// Walk fatherId backwards from Jesus to the topmost ancestor
  /// (Adam) and reverse to get the canonical genealogy as a flat
  /// list. If Jesus isn't in the dataset, fall back to whichever
  /// NT-era person we can reach.
  List<BiblicalPerson> _computeAdamToJesus(_TreeData data) {
    final svc = data.svc;
    final start = svc.byId('jesus') ?? svc.byId('joseph_father_of_jesus');
    if (start == null) return const [];
    final out = <BiblicalPerson>[start];
    var cur = start;
    final seen = <String>{cur.id};
    for (var i = 0; i < 200; i++) {
      final pid = cur.fatherId ?? cur.motherId;
      if (pid == null || seen.contains(pid)) break;
      final next = svc.byId(pid);
      if (next == null) break;
      seen.add(pid);
      out.add(next);
      cur = next;
    }
    return out.reversed.toList();
  }

  /// Bridge-chip / bridge-leaf tap handler. Uncollapses the target
  /// era, scrolls the destination's row into view, and flashes
  /// the destination person with a temporary highlight tint so the
  /// user gets unambiguous "you landed here" feedback.
  ///
  /// Uses an explicit [ScrollController.animateTo] with offset
  /// computed from `RenderAbstractViewport.getOffsetToReveal` —
  /// this is more reliable across Flutter web than the older
  /// `Scrollable.ensureVisible` path, which had a timing bug where
  /// jumps to deeper sections (Perez → Davidic Line, Kohath under
  /// Levi) would silently no-op while jumps to closer sections
  /// (Kohath via the bridge footer chip) happened to fire.
  void _jumpToEra(String era, {String? personId}) {
    setState(() {
      _collapsedEras.remove(era);
      _recentlyJumpedTo = personId;
    });

    _highlightTimer?.cancel();
    if (personId != null) {
      _highlightTimer = Timer(_kHighlightDuration, () {
        if (!mounted) return;
        setState(() => _recentlyJumpedTo = null);
      });
    }

    // Aggressive deferral chain: postFrame → postFrame → 250 ms.
    // Layout for a 40-row Lukan Lineage body completes well
    // within this on phones, so the destination row's RenderBox
    // always has a settled non-zero position before we measure.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 250), () {
          if (!mounted) return;
          _scrollToTarget(era: era, personId: personId);
        });
      });
    });
  }

  /// Spouse-chip tap handler. If the spouse has an era assigned,
  /// jump-and-highlight their row in that era's section. Otherwise
  /// fall back to opening the detail sheet (for orphan spouses
  /// without era data — rare in our dataset).
  void _jumpToSpouse(BiblicalPerson s) {
    final era = s.era;
    if (era != null && era.isNotEmpty) {
      _jumpToEra(era, personId: s.id);
    } else {
      _showDetail(s);
    }
  }

  void _scrollToTarget({required String era, String? personId}) {
    if (!_scrollController.hasClients) return;
    BuildContext? ctx;
    if (personId != null) {
      ctx = _personKeys[personId]?.currentContext;
    }
    ctx ??= _eraKeys[era]?.currentContext;
    if (ctx == null) {
      debugPrint('familyTree: no context for $era / $personId');
      return;
    }
    final box = ctx.findRenderObject();
    if (box is! RenderBox) {
      debugPrint('familyTree: no RenderBox for $era / $personId');
      return;
    }
    final viewport = RenderAbstractViewport.of(box);
    final reveal = viewport.getOffsetToReveal(box, 0.05);
    final position = _scrollController.position;
    final raw = reveal.offset;
    final clamped = raw.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _scrollController.jumpTo(clamped);
    // The landing is announced by the destination row's `pinned` mark,
    // not by a SnackBar. What used to fire here was an untranslated
    // developer diagnostic ("jumped: was=1240 → 3180") shown to users.
    debugPrint('familyTree: jumped to ${clamped.toInt()} (raw ${raw.toInt()})');
  }

  // ── Detail sheet ───────────────────────────────────────────────

  Future<void> _showDetail(BiblicalPerson p) async {
    final settings = context.read<AppSettings>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 720),
      // No `shape:` / `backgroundColor:` — `workbenchTheme`'s
      // bottomSheetTheme is already square and already `paneBg`.
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
            _showDetail(other);
          },
        ),
      ),
    );
  }
}

// ── Era section ────────────────────────────────────────────────

class _EraSection extends StatelessWidget {
  final String era;
  final List<BiblicalPerson> people;
  final FamilyTreeService svc;
  final String locale;
  final bool isCollapsed;
  final VoidCallback onToggle;
  final Set<String> expanded;
  final Set<String> ancestorIds;
  final Set<String> matchIds;
  final void Function(String id) onTogglePerson;
  final void Function(BiblicalPerson) onTapPerson;
  final List<BiblicalPerson> bridges;
  final void Function(String era, {String? personId}) onJumpToEra;
  final void Function(BiblicalPerson) onJumpToSpouse;
  final String? recentlyJumpedTo;
  final GlobalKey Function(String id) personKeyFor;

  const _EraSection({
    required this.era,
    required this.people,
    required this.svc,
    required this.locale,
    required this.isCollapsed,
    required this.onToggle,
    required this.expanded,
    required this.ancestorIds,
    required this.matchIds,
    required this.onTogglePerson,
    required this.onTapPerson,
    required this.bridges,
    required this.onJumpToEra,
    required this.onJumpToSpouse,
    required this.recentlyJumpedTo,
    required this.personKeyFor,
  });

  @override
  Widget build(BuildContext context) {
    // One colour now, not two. The old pair — a raw deep hue for the
    // gradient fill plus a lifted one for the ink on top of it — existed
    // only because there WAS a fill. With the hue on ink alone, the
    // palette-aware value is the only one there is.
    final accent = eraColorFor(context, era);
    // Section roots = people in this era whose parent is NOT in
    // this era (or has no parent). Spouses-in (no parent) are
    // shown inline as chips on their husband's row, so we exclude
    // anyone who is in someone-else-in-era's spouseIds.
    final eraIds = people.map((p) => p.id).toSet();
    final indexOf = <String, int>{
      for (var i = 0; i < people.length; i++) people[i].id: i,
    };

    // "Inline spouse" = someone who married into the lineage and
    // should appear as a `═ Spouse` chip on their husband's row,
    // not as a separate section root. Two cases:
    //
    //   1. Their partner has a parent in the dataset → partner is
    //      the anchor, this person is the chip.
    //   2. Mutual no-parent pair (e.g. Adam ↔ Eve, where both
    //      reciprocate spouseIds but neither has a parent). Without
    //      a tiebreaker BOTH would be filtered → the section ends
    //      up with zero roots (the antediluvian bug). Resolve by
    //      keeping whichever person appears earlier in the dataset
    //      and filtering the other.
    bool isInlineSpouse(BiblicalPerson p) {
      if (p.fatherId != null || p.motherId != null) return false;
      for (final s in people) {
        if (s.id == p.id) continue;
        if (!s.spouseIds.contains(p.id)) continue;
        // s claims p as spouse.
        if (s.fatherId != null || s.motherId != null) {
          // s has parent → s is anchor, p is the chip.
          return true;
        }
        // Mutual no-parent pair → keep the earlier-indexed one.
        final pi = indexOf[p.id] ?? 0;
        final si = indexOf[s.id] ?? 0;
        if (pi > si) return true;
      }
      return false;
    }

    final roots = people.where((p) {
      final pid = p.fatherId ?? p.motherId;
      final hasParentInEra = pid != null && eraIds.contains(pid);
      return !hasParentInEra && !isInlineSpouse(p);
    }).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: WbPanel(
        // The chevron is the only glyph left. The `history_edu` book
        // that used to sit beside it was identical on all nine
        // sections, so it distinguished nothing.
        icon: isCollapsed ? Icons.chevron_right : Icons.expand_more,
        title: _eraLabel(era, locale),
        subtitle: _eraSubtitle(era, locale),
        accent: accent,
        onTap: onToggle,
        trailing: WbTag(text: '${people.length}', color: accent),
        padding: EdgeInsets.zero,
        child: isCollapsed
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final root in roots)
                      _buildSubtree(
                        root,
                        depth: 0,
                        eraIds: eraIds,
                        seen: <String>{},
                      ),
                    if (bridges.isNotEmpty)
                      _BridgeFooter(
                        bridges: bridges,
                        locale: locale,
                        eraAccent: accent,
                        onTapBridge: (target) {
                          // Tap = jump only. Pass the person id so
                          // the destination row gets a flash highlight
                          // and the scroll lands on the row, not just
                          // the section header.
                          final targetEra = target.era;
                          if (targetEra != null) {
                            onJumpToEra(targetEra, personId: target.id);
                          }
                        },
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  /// Recursively render a node's subtree. In-era children expand
  /// recursively (full subtree); **cross-era** children render as
  /// "bridge leaves" — single-row markers with a `→ {next era}`
  /// indicator that tap-jumps the user to that next section. So
  /// the user sees Lamech → Noah (→ Post-Flood) inside the
  /// Antediluvian section, instead of the chain abruptly ending
  /// at Lamech.
  Widget _buildSubtree(
    BiblicalPerson p, {
    required int depth,
    required Set<String> eraIds,
    required Set<String> seen,
  }) {
    if (!seen.add(p.id)) return const SizedBox.shrink();

    final allKids = <BiblicalPerson>[];
    final inEraKids = <BiblicalPerson>[];
    final crossEraKids = <BiblicalPerson>[];
    for (final cid in p.childIds) {
      final c = svc.byId(cid);
      if (c == null) continue;
      allKids.add(c);
      if (eraIds.contains(cid)) {
        if (!seen.contains(cid)) inEraKids.add(c);
      } else if ((c.era ?? '').isNotEmpty) {
        crossEraKids.add(c);
      }
    }
    final hasAnyKids = inEraKids.isNotEmpty || crossEraKids.isNotEmpty;
    final isExpanded = !hasAnyKids
        ? false
        : (expanded.contains(p.id) || ancestorIds.contains(p.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KeyedSubtree(
          // Per-person key so _jumpToEra(..., personId: ...) can
          // scroll directly to this row and the flash-highlight
          // can re-target on each rebuild.
          key: personKeyFor(p.id),
          child: _PersonRow(
            person: p,
            depth: depth,
            locale: locale,
            svc: svc,
            showExpander: hasAnyKids,
            isExpanded: isExpanded,
            isMatch: matchIds.contains(p.id),
            isRecentlyJumped: recentlyJumpedTo == p.id,
            onToggleExpand: hasAnyKids ? () => onTogglePerson(p.id) : null,
            // Tap row body = expand/collapse children when this
            // person has any. For leaf nodes (no kids) tap falls
            // back to opening the detail sheet so the action isn't
            // a no-op.
            onTap:
                hasAnyKids ? () => onTogglePerson(p.id) : () => onTapPerson(p),
            onOpenDetail: () => onTapPerson(p),
            onTapSpouse: onTapPerson,
            onJumpToSpouse: onJumpToSpouse,
          ),
        ),
        if (isExpanded) ...[
          for (final c in inEraKids)
            _buildSubtree(
              c,
              depth: depth + 1,
              eraIds: eraIds,
              seen: seen,
            ),
          for (final c in crossEraKids)
            _BridgeLeafRow(
              person: c,
              depth: depth + 1,
              locale: locale,
              svc: svc,
              onTapPerson: onTapPerson,
              onJumpToEra: onJumpToEra,
              isRecentlyJumped: recentlyJumpedTo == c.id,
            ),
        ],
      ],
    );
  }
}

// ── Bridge footer ──────────────────────────────────────────────

/// "Continues with: [Person] [Person]" footer at the bottom of an
/// expanded era section. Each person chip is tappable — tap to
/// uncollapse + scroll to whichever section they live in (the next
/// era in canonical order) and open the detail sheet for them.
class _BridgeFooter extends StatelessWidget {
  final List<BiblicalPerson> bridges;
  final String locale;

  /// The era's colour, already lifted for the palette by the section.
  final Color eraAccent;
  final void Function(BiblicalPerson) onTapBridge;

  const _BridgeFooter({
    required this.bridges,
    required this.locale,
    required this.eraAccent,
    required this.onTapBridge,
  });

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8, left: 8, right: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: wb.paneAltBg,
        border: Border.all(color: wb.border, width: WbMetrics.hairline),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: [
          Icon(Icons.east_rounded, size: 14, color: eraAccent),
          const SizedBox(width: 2),
          Text(
            uiStrings['familyTreeContinuesWith']?[locale] ?? 'Continues with',
            style: TextStyle(
              fontSize: t.scaled(11),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: eraAccent,
            ),
          ),
          for (final p in bridges)
            WbTag(
              text: p.localizedName(locale),
              icon: Icons.person_pin_rounded,
              color: eraAccent,
              dense: false,
              onTap: () => onTapBridge(p),
            ),
        ],
      ),
    );
  }
}

// ── Person row ────────────────────────────────────────────────

/// The fill and border behind a tree row, in the workbench's own
/// highlight vocabulary rather than a second one.
///
/// A search match is a `hit` — [WbColors.selectionBg] at 55%, exactly
/// what `wordMarkDecoration` prints behind a word the search found. A
/// jumped-to row is `pinned` — the full selection fill plus the gold
/// [WbColors.pinMark] rule, exactly what marks the word under study.
/// Both questions are the same question the Browse window already
/// answers ("did I ask for this, or did I land on it?"), so reusing the
/// answer means a reader learns the code once.
BoxDecoration? _rowMark(
  WbColors wb, {
  required bool isMatch,
  required bool isJumped,
}) {
  if (isJumped) {
    return BoxDecoration(
      color: wb.selectionBg,
      border: Border.all(color: wb.pinMark, width: 1.5),
    );
  }
  if (isMatch) {
    return BoxDecoration(color: wb.selectionBg.withValues(alpha: 0.55));
  }
  return null;
}

class _PersonRow extends StatelessWidget {
  final BiblicalPerson person;
  final int depth;
  final String locale;
  final FamilyTreeService svc;
  final bool showExpander;
  final bool isExpanded;
  final bool isMatch;
  final bool isRecentlyJumped;
  final VoidCallback? onToggleExpand;
  final VoidCallback onTap;
  final VoidCallback onOpenDetail;
  final void Function(BiblicalPerson) onTapSpouse;
  final void Function(BiblicalPerson) onJumpToSpouse;

  const _PersonRow({
    required this.person,
    required this.depth,
    required this.locale,
    required this.svc,
    required this.showExpander,
    required this.isExpanded,
    required this.isMatch,
    required this.isRecentlyJumped,
    required this.onToggleExpand,
    required this.onTap,
    required this.onOpenDetail,
    required this.onTapSpouse,
    required this.onJumpToSpouse,
  });

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    // Indent caps at depth 6; deeper rows stop sliding right.
    final clampedDepth = depth > 6 ? 6 : depth;
    final indent = clampedDepth * 14.0;
    final years = person.displayYears(locale);
    final accent = _accentTheme(person.accent);
    final accentLine = accent == null
        ? null
        : liftForDarkGround(accent.line, isDark: wb.isDark);
    final spouses = [for (final id in person.spouseIds) svc.byId(id)]
        .whereType<BiblicalPerson>()
        .toList();

    return Padding(
      padding: EdgeInsets.only(left: indent),
      // Static (non-animated) highlight wrapper. We tried
      // AnimatedContainer here but the 320 ms animation could
      // shift the row's RenderBox during scroll-offset
      // measurement, making the jump land at a stale offset.
      // Switching to a static Container keeps the highlight
      // visible (just no fade-in) and the layout deterministic.
      child: Container(
        decoration: _rowMark(
          wb,
          isMatch: isMatch,
          isJumped: isRecentlyJumped,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            hoverColor: wb.hoverBg,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    // The lineage accent (priestly red, royal blue,
                    // messianic gold, prophetic purple) is data, so it
                    // stays — at full strength, because a 3px rule at 60%
                    // opacity over a `pinned` fill was already reading as
                    // a different colour on the jumped-to row.
                    color: accentLine ?? wb.border,
                    width: accentLine != null ? 3 : WbMetrics.hairline,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: showExpander
                        ? IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 30, minHeight: 30),
                            iconSize: 20,
                            icon: Icon(isExpanded
                                ? Icons.expand_more
                                : Icons.chevron_right),
                            onPressed: onToggleExpand,
                          )
                        : const SizedBox.shrink(),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Text(
                              person.localizedName(locale),
                              style: TextStyle(
                                fontSize: t.scaled(15),
                                fontWeight: FontWeight.w700,
                                color: wb.text,
                              ),
                            ),
                            for (final s in spouses)
                              // Tap a spouse chip → jump to that
                              // person's row in their own era section
                              // (so e.g. Mary on Joseph's row jumps to
                              // Mary in the NT section). Falls back to
                              // the detail sheet if the spouse has no
                              // era to jump to.
                              _spouseTag(s, locale, wb,
                                  onTap: () => onJumpToSpouse(s)),
                            if ((person.role ?? '').isNotEmpty)
                              WbTag(
                                text: localizedRole(person.role!, locale),
                                color: accentLine ?? wb.mutedText,
                              ),
                            if (person.refs.isNotEmpty)
                              _refTag(person.refs.length, wb),
                          ],
                        ),
                        if (years.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              years,
                              style: TextStyle(
                                fontSize: t.scaled(11.5),
                                color: wb.mutedText,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Info button — explicit, discoverable path to the
                  // detail sheet. Tap row body = expand/collapse.
                  // Tap this little box = open popup. Matches the
                  // human-natural pattern the user asked for.
                  _RowInfoButton(
                    onPressed: onOpenDetail,
                    locale: locale,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final BiblicalPerson person;
  final String locale;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.person,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final accent = _accentTheme(person.accent);
    final accentColor = accent == null
        ? wb.border
        : liftForDarkGround(accent.line, isDark: wb.isDark);
    final years = person.displayYears(locale);
    final era = person.era ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: WbTile(
        onTap: onTap,
        alt: false,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Row(
          children: [
            // The lineage accent, as a square rule rather than a
            // rounded pill. It is the same 4px bar; only its ends
            // changed.
            Container(width: 4, height: 40, color: accentColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text(
                        person.localizedName(locale),
                        style: TextStyle(
                          fontSize: t.scaled(16),
                          fontWeight: FontWeight.w700,
                          color: wb.text,
                        ),
                      ),
                      if (era.isNotEmpty)
                        WbTag(
                          text: _eraLabelShort(era, locale),
                          color: eraColorFor(context, era),
                        ),
                      if ((person.role ?? '').isNotEmpty)
                        WbTag(
                          text: localizedRole(person.role!, locale),
                          color: accent == null ? wb.mutedText : accentColor,
                        ),
                      if (person.refs.isNotEmpty)
                        _refTag(person.refs.length, wb),
                    ],
                  ),
                  if (years.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        years,
                        style: TextStyle(
                          fontSize: t.scaled(12),
                          color: wb.mutedText,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.east_rounded, size: 18, color: wb.link),
          ],
        ),
      ),
    );
  }
}

class _RowInfoButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String locale;
  const _RowInfoButton({
    required this.onPressed,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    return Tooltip(
      message: uiStrings['familyTreeOpenDetails']?[locale] ?? 'Details',
      child: InkResponse(
        onTap: onPressed,
        radius: 18,
        hoverColor: wb.hoverBg,
        child: Padding(
          padding: const EdgeInsets.all(4),
          // Muted, not link blue. The whole row is already clickable
          // and this workspace signals that by hovering; spending the
          // link hue on a second control in the same row would say
          // "reference" where there is none.
          child:
              Icon(Icons.info_outline_rounded, size: 18, color: wb.mutedText),
        ),
      ),
    );
  }
}

// ── Bridge leaf row ──────────────────────────────────────────

/// A single-row marker rendered inside a parent section to surface
/// children whose era is different from the section's era. Shows
/// the person + their spouses inline + a trailing `→ {next era}`
/// tag. Tapping the row jumps to the target era's section AND
/// opens the detail sheet for that person.
class _BridgeLeafRow extends StatelessWidget {
  final BiblicalPerson person;
  final int depth;
  final String locale;
  final FamilyTreeService svc;
  final void Function(BiblicalPerson) onTapPerson;
  final void Function(String era, {String? personId}) onJumpToEra;
  final bool isRecentlyJumped;

  const _BridgeLeafRow({
    required this.person,
    required this.depth,
    required this.locale,
    required this.svc,
    required this.onTapPerson,
    required this.onJumpToEra,
    required this.isRecentlyJumped,
  });

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final clampedDepth = depth > 6 ? 6 : depth;
    final indent = clampedDepth * 14.0;
    final years = person.displayYears(locale);
    final accent = _accentTheme(person.accent);
    final accentLine = accent == null
        ? null
        : liftForDarkGround(accent.line, isDark: wb.isDark);
    final spouses = [for (final id in person.spouseIds) svc.byId(id)]
        .whereType<BiblicalPerson>()
        .toList();
    final targetEra = person.era ?? '';
    final targetEraColor = eraColorFor(context, targetEra);

    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Container(
        // Zebra fill, not an era wash. A bridge leaf is "a row that
        // belongs to the next section", which is a structural fact and
        // so gets the structural shade; the era it belongs to is said
        // once, in the trailing tag, in words.
        decoration: _rowMark(wb, isMatch: false, isJumped: isRecentlyJumped) ??
            BoxDecoration(color: wb.paneAltBg),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            // Tap = jump only. Opening the detail sheet here would
            // cover the scroll animation and make the jump feel like
            // it didn't fire. The trailing ⓘ button opens the
            // detail sheet without jumping.
            onTap: () {
              if (targetEra.isNotEmpty) {
                onJumpToEra(targetEra, personId: person.id);
              }
            },
            onLongPress: () => onTapPerson(person),
            hoverColor: wb.hoverBg,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: accentLine ?? targetEraColor,
                    width: accentLine != null ? 3 : 2,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                children: [
                  // Same width as the chevron column on a regular row,
                  // for vertical alignment with siblings.
                  SizedBox(
                    width: 30,
                    child: Center(
                      child: Icon(
                        Icons.subdirectory_arrow_right_rounded,
                        size: 16,
                        color: wb.mutedText,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Text(
                              person.localizedName(locale),
                              style: TextStyle(
                                fontSize: t.scaled(14.5),
                                fontWeight: FontWeight.w700,
                                color: wb.text,
                              ),
                            ),
                            for (final s in spouses)
                              _spouseTag(s, locale, wb,
                                  onTap: () => onTapPerson(s)),
                            if ((person.role ?? '').isNotEmpty)
                              WbTag(
                                text: localizedRole(person.role!, locale),
                                color: accentLine ?? wb.mutedText,
                              ),
                            // The trailing "→ {next era}" tag. This
                            // is the visual cue that the lineage
                            // continues in another section.
                            WbTag(
                              text: '→ ${_eraLabelShort(targetEra, locale)}',
                              color: targetEraColor,
                            ),
                          ],
                        ),
                        if (years.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              years,
                              style: TextStyle(
                                fontSize: t.scaled(11),
                                color: wb.mutedText,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.east_rounded, size: 16, color: targetEraColor),
                  // Info button — opens detail without jumping. Tap
                  // row body = jump to next era; this little box =
                  // peek at details first.
                  _RowInfoButton(
                    onPressed: () => onTapPerson(person),
                    locale: locale,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shorter, single-word labels for the trailing era tag (so the
/// row stays compact when wrapped). Falls back to the full era
/// label when no short form is registered.
String _eraLabelShort(String era, String locale) {
  const labels = {
    'antediluvian': {
      'en': 'Antediluvian',
      'zh-Hans': '洪水之前',
      'zh-Hant': '洪水之前'
    },
    'post_flood': {'en': 'Post-Flood', 'zh-Hans': '洪水之后', 'zh-Hant': '洪水之後'},
    'patriarchs': {'en': 'Patriarchs', 'zh-Hans': '列祖', 'zh-Hant': '列祖'},
    'mosaic': {'en': 'Mosaic', 'zh-Hans': '摩西时代', 'zh-Hant': '摩西時代'},
    'davidic_line': {
      'en': 'Davidic Line',
      'zh-Hans': '大卫世系',
      'zh-Hant': '大衛世系'
    },
    'kings': {'en': 'Kings', 'zh-Hans': '列王', 'zh-Hant': '列王'},
    'exile': {'en': 'Exile', 'zh-Hans': '被掳', 'zh-Hant': '被擄'},
    'lukan_lineage': {'en': 'Lukan', 'zh-Hans': '路加家谱', 'zh-Hant': '路加家譜'},
    'nt': {'en': 'NT', 'zh-Hans': '新约', 'zh-Hant': '新約'},
  };
  return labels[era]?[locale] ?? _eraLabel(era, locale);
}

// ── Comparison table ──────────────────────────────────────────

class _ComparisonTable extends StatefulWidget {
  final List<BiblicalPerson> spine;
  final String locale;
  final Set<String> matchIds;
  final List<(String, List<String>)> comparisonColumns;
  final void Function(BiblicalPerson) onTapPerson;

  const _ComparisonTable({
    required this.spine,
    required this.locale,
    required this.matchIds,
    required this.comparisonColumns,
    required this.onTapPerson,
  });

  @override
  State<_ComparisonTable> createState() => _ComparisonTableState();
}

class _ComparisonTableState extends State<_ComparisonTable> {
  /// Collapsed by default — the table is ~50 rows tall and would
  /// otherwise dominate the page. Header stays visible so the
  /// feature is discoverable; tap to expand.
  bool _collapsed = true;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final spine = widget.spine;
    final locale = widget.locale;
    final matchIds = widget.matchIds;
    final comparisonColumns = widget.comparisonColumns;
    final onTapPerson = widget.onTapPerson;

    if (spine.isEmpty) return const SizedBox.shrink();

    final headerStyle = TextStyle(
      fontSize: t.scaled(11),
      fontWeight: FontWeight.w800,
      letterSpacing: 0.5,
      color: wb.text,
    );
    final cellStyle = TextStyle(fontSize: t.scaled(12), color: wb.text);

    Widget headerCell(String text, {double width = 70}) => Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: wb.paneAltBg,
            border: Border(
              right: BorderSide(color: wb.border, width: WbMetrics.hairline),
              bottom: BorderSide(color: wb.border, width: WbMetrics.hairline),
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: headerStyle,
          ),
        );

    Widget bodyCell({
      required Widget child,
      double width = 70,
      bool isMatch = false,
      VoidCallback? onTap,
    }) {
      final cell = Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isMatch ? wb.selectionBg.withValues(alpha: 0.55) : null,
          border: Border(
            right: BorderSide(color: wb.border, width: WbMetrics.hairline),
            bottom: BorderSide(color: wb.border, width: WbMetrics.hairline),
          ),
        ),
        child: child,
      );
      if (onTap == null) return cell;
      return Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, hoverColor: wb.hoverBg, child: cell),
      );
    }

    // Column widths — base layout that always horizontally scrolls
    // on phones (~640 px wide content). The outer LayoutBuilder
    // below expands these proportionally on iPad / desktop so the
    // table fills the available width instead of leaving a gap.
    const double baseGenW = 50;
    const double baseNameW = 130;
    const double baseYearW = 100;
    const double baseSourceW = 60;
    final baseTotal = baseGenW +
        baseNameW +
        baseYearW +
        comparisonColumns.length * baseSourceW;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      child: WbPanel(
        // Same header shape as an era section, because it is the same
        // kind of thing: a collapsible block of the article. The
        // `table_view` glyph it used to carry alongside the chevron is
        // gone for the reason the sections' book glyph is.
        icon: _collapsed ? Icons.chevron_right : Icons.expand_more,
        title: uiStrings['familyTreeComparisonTitle']?[locale] ??
            'Comparison of genealogies',
        subtitle: uiStrings['familyTreeComparisonSubtitle']?[locale] ??
            'Adam → Jesus by canonical Bible source',
        onTap: () => setState(() => _collapsed = !_collapsed),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Copy-table button: copies the entire comparison table as
            // a tab-separated payload that pastes cleanly into Excel /
            // Sheets / Numbers / Notion.
            _ComparisonCopyButton(
              spine: spine,
              comparisonColumns: comparisonColumns,
              locale: locale,
            ),
            const SizedBox(width: 4),
            WbTag(text: '${spine.length}'),
          ],
        ),
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_collapsed) const SizedBox.shrink(),
            if (!_collapsed)
              // Width-adaptive: on phones (< baseTotal px) we
              // horizontally scroll. On iPad / desktop we expand
              // every column proportionally so the table fills its
              // container instead of leaving whitespace.
              LayoutBuilder(builder: (ctx, c) {
                final scale =
                    c.maxWidth > baseTotal ? c.maxWidth / baseTotal : 1.0;
                final genW = baseGenW * scale;
                final nameW = baseNameW * scale;
                final yearW = baseYearW * scale;
                final sourceW = baseSourceW * scale;

                final headerRow = Row(
                  children: [
                    headerCell(uiStrings['familyTreeColGen']?[locale] ?? 'Gen',
                        width: genW),
                    headerCell(
                        uiStrings['familyTreeColName']?[locale] ?? 'Name',
                        width: nameW),
                    headerCell(
                        uiStrings['familyTreeColYears']?[locale] ?? 'Years',
                        width: yearW),
                    for (final col in comparisonColumns)
                      headerCell(uiStrings[col.$1]?[locale] ?? col.$1,
                          width: sourceW),
                  ],
                );

                final rows = <Widget>[];
                for (var i = 0; i < spine.length; i++) {
                  final p = spine[i];
                  final isMatch = matchIds.contains(p.id);
                  final years = p.displayYears(locale);
                  rows.add(Row(
                    children: [
                      bodyCell(
                        child: Text('${i + 1}',
                            style: cellStyle.copyWith(
                              fontWeight: FontWeight.w700,
                              color: wb.mutedText,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            )),
                        width: genW,
                        isMatch: isMatch,
                      ),
                      bodyCell(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            p.localizedName(locale),
                            // Link blue and underlined, because this
                            // cell IS a link — it opens the person.
                            style: cellStyle.copyWith(
                              fontWeight: FontWeight.w700,
                              color: wb.link,
                              decoration: TextDecoration.underline,
                              decorationColor: wb.link,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        width: nameW,
                        isMatch: isMatch,
                        onTap: () => onTapPerson(p),
                      ),
                      bodyCell(
                        child: Text(
                          years,
                          style: cellStyle.copyWith(
                            fontSize: t.scaled(11),
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: wb.mutedText,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                        ),
                        width: yearW,
                        isMatch: isMatch,
                      ),
                      for (final col in comparisonColumns)
                        bodyCell(
                          // A ✓ is not a link, so it is not blue. It is
                          // the presence of data, which is text.
                          child: _hasSourceRef(p, col.$2)
                              ? Icon(Icons.check, size: 16, color: wb.text)
                              : Text('·',
                                  style: TextStyle(color: wb.mutedText)),
                          width: sourceW,
                          isMatch: isMatch,
                        ),
                    ],
                  ));
                }

                final body = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [headerRow, ...rows],
                );

                if (scale > 1.0) {
                  return body;
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: body,
                );
              }),
          ],
        ),
      ),
    );
  }

  bool _hasSourceRef(BiblicalPerson p, List<String> prefixes) {
    for (final r in p.refs) {
      for (final prefix in prefixes) {
        if (r.startsWith(prefix)) return true;
      }
    }
    return false;
  }
}

// ── Era label / colour ────────────────────────────────────────

String _eraSubtitle(String era, String locale) {
  const map = {
    'antediluvian': 'familyTreeEraSubAntediluvian',
    'post_flood': 'familyTreeEraSubPostFlood',
    'patriarchs': 'familyTreeEraSubPatriarchs',
    'mosaic': 'familyTreeEraSubMosaic',
    'davidic_line': 'familyTreeEraSubDavidic',
    'kings': 'familyTreeEraSubKings',
    'exile': 'familyTreeEraSubExile',
    'lukan_lineage': 'familyTreeEraSubLukan',
    'nt': 'familyTreeEraSubNt',
  };
  final key = map[era];
  if (key == null) return '';
  return uiStrings[key]?[locale] ?? '';
}

String _eraLabel(String era, String locale) {
  const labels = {
    'antediluvian': {
      'en': 'Antediluvian (Adam → Lamech)',
      'zh-Hans': '洪水之前（亚当 → 拉麦）',
      'zh-Hant': '洪水之前（亞當 → 拉麥）',
    },
    'post_flood': {
      'en': 'Post-Flood Patriarchs',
      'zh-Hans': '洪水之后的列祖',
      'zh-Hant': '洪水之後的列祖',
    },
    'patriarchs': {
      'en': 'Patriarchs of Israel',
      'zh-Hans': '以色列列祖',
      'zh-Hant': '以色列列祖',
    },
    'mosaic': {
      'en': 'Mosaic / Levitical',
      'zh-Hans': '摩西时代 / 利未支派',
      'zh-Hant': '摩西時代 / 利未支派',
    },
    'davidic_line': {
      'en': 'Pre-Monarchy / Davidic Line',
      'zh-Hans': '王朝之前 / 大卫世系',
      'zh-Hant': '王朝之前 / 大衛世系',
    },
    'kings': {
      'en': 'Kings of Judah',
      'zh-Hans': '犹大列王',
      'zh-Hant': '猶大列王',
    },
    'exile': {
      'en': 'Exile & Return',
      'zh-Hans': '被掳与回归',
      'zh-Hant': '被擄與回歸',
    },
    'lukan_lineage': {
      'en': "Lukan Lineage (Mary's line through Nathan)",
      'zh-Hans': '路加家谱（马利亚透过拿单的世系）',
      'zh-Hant': '路加家譜（馬利亞透過拿單的世系）',
    },
    'nt': {
      'en': 'New Testament',
      'zh-Hans': '新约',
      'zh-Hant': '新約',
    },
  };
  return labels[era]?[locale] ?? era;
}

// 2026-08-08 (task #279): the three brightness-keyed era helpers this
// file used to carry — `_eraColor`, `_eraColorOn` and `_readableEraFg` —
// are gone. `eraColorFor(context, era)` in `era_palette.dart` does the
// job for every caller, and does it by asking the PALETTE whether it is
// dark rather than the ThemeMode: under 护眼纸质 the mode can be dark
// while every surface is cream, which is exactly the case that made the
// old helpers wash era titles out to near-white on paper.

// ── Comparison-table copy button ─────────────────────────────────

class _ComparisonCopyButton extends StatefulWidget {
  final List<BiblicalPerson> spine;
  final List<(String, List<String>)> comparisonColumns;
  final String locale;
  const _ComparisonCopyButton({
    required this.spine,
    required this.comparisonColumns,
    required this.locale,
  });

  @override
  State<_ComparisonCopyButton> createState() => _ComparisonCopyButtonState();
}

class _ComparisonCopyButtonState extends State<_ComparisonCopyButton> {
  bool _justCopied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool _hasSourceRef(BiblicalPerson p, List<String> prefixes) {
    for (final r in p.refs) {
      for (final prefix in prefixes) {
        if (r.startsWith(prefix)) return true;
      }
    }
    return false;
  }

  String _buildTsv() {
    final loc = widget.locale;
    // Header row: Gen, Name, Years + each source column.
    final cols = <String>[
      uiStrings['familyTreeColGen']?[loc] ?? 'Gen',
      uiStrings['familyTreeColName']?[loc] ?? 'Name',
      uiStrings['familyTreeColYears']?[loc] ?? 'Years',
      for (final col in widget.comparisonColumns)
        uiStrings[col.$1]?[loc] ?? col.$1,
    ];
    final buf = StringBuffer(cols.join('\t'));
    buf.writeln();
    for (var i = 0; i < widget.spine.length; i++) {
      final p = widget.spine[i];
      final row = <String>[
        '${i + 1}',
        p.localizedName(loc),
        p.displayYears(loc),
        for (final col in widget.comparisonColumns)
          _hasSourceRef(p, col.$2) ? '✓' : '',
      ];
      buf.writeln(row.join('\t'));
    }
    return buf.toString().trim();
  }

  Future<void> _handleTap() async {
    final tsv = _buildTsv();
    final ok = await ClipboardHelper.copyText(tsv);
    if (!mounted) return;
    if (!ok) {
      showFloatingToast(
        context,
        message: uiStrings['familyTreeCopyFailedToast']?[widget.locale] ??
            'Copy failed — clipboard not available',
        icon: Icons.error_outline_rounded,
        background: Theme.of(context).colorScheme.error,
      );
      return;
    }
    showFloatingToast(
      context,
      message: uiStrings['familyTreeCopiedToast']?[widget.locale] ??
          'Copied to clipboard',
      icon: Icons.check_circle_rounded,
      background: Theme.of(context).colorScheme.primary,
    );
    setState(() => _justCopied = true);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _justCopied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    return IconButton(
      tooltip: _justCopied
          ? (uiStrings['familyTreeCopiedToast']?[widget.locale] ?? 'Copied')
          : (uiStrings['familyTreeCopyAll']?[widget.locale] ?? 'Copy table'),
      onPressed: _justCopied ? null : _handleTap,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
        child: _justCopied
            ? Icon(Icons.check_circle_rounded,
                key: const ValueKey('chk'),
                size: 22,
                // The palette's own green, which is tuned for all three
                // grounds. `paletteAccent(context, Colors.green)` keyed
                // off ThemeMode, so in dark-mode-plus-paper it lightened
                // a green that was already sitting on cream.
                color: wb.strongsLexical)
            : Icon(Icons.copy_rounded,
                key: const ValueKey('cp'), size: 18, color: wb.link),
      ),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}

// ── Accent palette / pills / badges ──────────────────────────────

/// A lineage's accent line — priestly red, royal blue, messianic gold,
/// prophetic purple.
///
/// The pale `tint` companion each of these used to carry is gone: it was
/// never read anywhere, and its whole job (a wash behind the row) is the
/// kind of decoration this pass removes. Tuned for a light ground, so
/// run [liftForDarkGround] before painting.
class _AccentTheme {
  final Color line;
  const _AccentTheme(this.line);
}

_AccentTheme? _accentTheme(String? accent) {
  switch (accent) {
    case 'priestly':
      return const _AccentTheme(Color(0xFFB42E2E));
    case 'royal':
      return const _AccentTheme(Color(0xFF2A4FB0));
    case 'messianic':
      return const _AccentTheme(Color(0xFFB8860B));
    case 'prophetic':
      return const _AccentTheme(Color(0xFF6B3FA0));
  }
  return null;
}

/// `═ Sarah` — a marriage, in the notation genealogies already use.
///
/// The `═` stays in the TEXT rather than becoming a [WbTag] icon,
/// because it is a genealogical operator, not a glyph decorating a
/// label: it says how the two names relate.
Widget _spouseTag(
  BiblicalPerson spouse,
  String locale,
  WbColors wb, {
  required VoidCallback onTap,
}) =>
    WbTag(
      text: '═ ${spouse.localizedName(locale)}',
      color: wb.mutedText,
      onTap: onTap,
    );

/// How many verses mention this person.
Widget _refTag(int count, WbColors wb) => WbTag(
      text: '$count',
      icon: Icons.menu_book_rounded,
      color: wb.mutedText,
    );

class _TreeData {
  final List<BiblicalPerson> all;
  final FamilyTreeService svc;
  const _TreeData({required this.all, required this.svc});
}
