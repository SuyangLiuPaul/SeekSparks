import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:seeksparks/utils/app_nav.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/widgets/press_scale.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/utils/theme_color_helpers.dart';
import 'package:seeksparks/models/bible_evidence.dart';
import 'package:seeksparks/pages/evidence_detail_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/utils/version_mapper.dart'
    show localeAwareBookName, localizedReferenceLabel;
import 'package:seeksparks/services/bible_evidence_service.dart';
import 'package:seeksparks/utils/jump_to_reference.dart';
import 'package:seeksparks/utils/reference_parser.dart';
import 'package:seeksparks/widgets/confidence_badge.dart';
import 'package:seeksparks/widgets/home_icon_button.dart';
import 'package:seeksparks/widgets/language_switcher_button.dart';
import 'package:seeksparks/widgets/localized_back_button.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/navigate_to_reader.dart';

/// Browse the Biblical Evidence Archive — 225 archaeological,
/// manuscript, scientific, and historical findings that intersect
/// with biblical accounts. Search box + category + confidence
/// filters; tap a card to open the full description. Optional
/// chapter / book pre-filter via [filterBook] + [filterChapter].
class EvidencePage extends StatefulWidget {
  /// When non-null, the list is pre-filtered to evidences referencing
  /// this English book name. Used by the reader's "Evidence for
  /// this chapter" entry point.
  final String? filterBook;

  /// When [filterBook] AND this are both set, narrow further to the
  /// specific chapter — entries whose [scriptureReference] either
  /// covers this chapter directly (e.g. "Genesis 1:1") or spans a
  /// chapter range that includes it (e.g. "Genesis 1:1-2:3"). Avoids
  /// the previous behaviour where reading Genesis 1 surfaced
  /// Genesis-37 evidences whose images had nothing to do with the
  /// chapter on screen.
  final int? filterChapter;

  const EvidencePage({super.key, this.filterBook, this.filterChapter});

  @override
  State<EvidencePage> createState() => _EvidencePageState();
}

/// What scope of evidences the page is currently showing. Drives the
/// disclosure banner so the user always knows whether the list is
/// chapter-narrowed, book-narrowed, or showing the full archive.
enum _EvidenceScope { chapter, book, archive }

class _EvidencePageState extends State<EvidencePage> {
  /// The complete archive — kept around so the user can widen out
  /// from chapter -> book -> archive without re-fetching.
  List<BibleEvidence> _allEntries = const [];

  /// The currently shown subset, scoped by [_scope].
  List<BibleEvidence> _all = const [];
  _EvidenceScope _scope = _EvidenceScope.archive;

  /// True when the current [_scope] is the result of falling back
  /// from a more-specific scope that came up empty. Drives the
  /// "showing book-wide because chapter has no curated entries"
  /// hint in the banner.
  bool _scopeWasFallback = false;
  bool _loading = true;
  final _searchController = TextEditingController();
  String _query = '';
  String? _categoryFilter;
  String? _confidenceFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await BibleEvidenceService.all();
    if (!mounted) return;
    // Narrow chain: chapter (most specific) -> book -> archive-wide.
    // Each step falls back to the broader scope if it would otherwise
    // strand the user on an empty page; better to show neighbouring
    // entries than nothing at all when curated coverage is thin.
    var filtered = list;
    var scope = _EvidenceScope.archive;
    var fallback = false;
    if (widget.filterBook != null) {
      if (widget.filterChapter != null) {
        final byChapter = BibleEvidenceService.forChapter(
          list,
          widget.filterBook!,
          widget.filterChapter!,
        );
        if (byChapter.isNotEmpty) {
          filtered = byChapter;
          scope = _EvidenceScope.chapter;
        } else {
          final byBook = BibleEvidenceService.forBook(
            list,
            widget.filterBook!,
          );
          if (byBook.isNotEmpty) {
            filtered = byBook;
            scope = _EvidenceScope.book;
            fallback = true; // chapter -> book widening
          } else {
            filtered = list;
            scope = _EvidenceScope.archive;
            fallback = true; // chapter -> archive widening
          }
        }
      } else {
        final byBook = BibleEvidenceService.forBook(
          list,
          widget.filterBook!,
        );
        if (byBook.isNotEmpty) {
          filtered = byBook;
          scope = _EvidenceScope.book;
        } else {
          filtered = list;
          scope = _EvidenceScope.archive;
          fallback = true; // book -> archive widening
        }
      }
    }
    setState(() {
      _allEntries = list;
      _all = filtered;
      _scope = scope;
      _scopeWasFallback = fallback;
      _loading = false;
    });
  }

  /// User taps the banner to widen scope by one step.
  void _widenScope() {
    if (_scope == _EvidenceScope.chapter && widget.filterBook != null) {
      final byBook =
          BibleEvidenceService.forBook(_allEntries, widget.filterBook!);
      setState(() {
        _all = byBook.isNotEmpty ? byBook : _allEntries;
        _scope =
            byBook.isNotEmpty ? _EvidenceScope.book : _EvidenceScope.archive;
        _scopeWasFallback = false;
      });
    } else if (_scope == _EvidenceScope.book) {
      setState(() {
        _all = _allEntries;
        _scope = _EvidenceScope.archive;
        _scopeWasFallback = false;
      });
    }
  }

  List<BibleEvidence> _filtered(String locale) {
    var list = _all;
    if (_categoryFilter != null) {
      list = list.where((e) => e.category == _categoryFilter).toList();
    }
    if (_confidenceFilter != null) {
      list = list.where((e) => e.confidenceLevel == _confidenceFilter).toList();
    }
    return BibleEvidenceService.search(list, _query, locale);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final t = settings.wbType;
    final scheme = Theme.of(context).colorScheme;
    final locale = settings.locale;
    // `filterBook` arrives as the canonical ENGLISH book name, because
    // that is what the evidence data is keyed on. Every surface that
    // PRINTS it has to go back through the version-aware mapper first
    // — the reading version decides the script, not the UI locale.
    final currentVersion =
        context.select<MainProvider, String>((m) => m.currentVersion);
    final localizedBook = widget.filterBook == null
        ? null
        : localeAwareBookName(widget.filterBook!, locale, currentVersion);
    final isWide = MediaQuery.of(context).size.width >= 720;
    final maxW = isWide ? 1100.0 : double.infinity;
    final crossAxisCount = isWide ? 2 : 1;

    final filtered = _filtered(locale);
    final categories = _all.map((e) => e.category).toSet().toList()..sort();

    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(
          localizedBook != null
              ? (uiStrings['evidenceForBook']?[locale] ?? 'Evidence — {book}')
                  .replaceAll('{book}', localizedBook)
              : (uiStrings['bibleEvidence']?[locale] ?? 'Bible Evidence'),
        ),
        actions: [
          const LanguageSwitcherButton(),
          const HomeIconButton(),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: Column(
                  children: [
                    // Scope disclosure banner — only shown when the
                    // page is narrowed (chapter or book scope) so the
                    // user knows the list isn't the full archive and
                    // can widen out with one tap. Hidden in the
                    // archive-wide default state.
                    if (_scope != _EvidenceScope.archive)
                      _ScopeBanner(
                        scope: _scope,
                        wasFallback: _scopeWasFallback,
                        book: localizedBook,
                        chapter: widget.filterChapter,
                        locale: locale,
                        count: _all.length,
                        onWiden: _widenScope,
                      ),
                    // Search.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(
                            fontFamily: settings.fontFamily,
                            fontFamilyFallback: kCjkFontFallback,
                            fontSize: settings.fontSize),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, size: 20),
                          hintText: uiStrings['search']?[locale] ?? 'Search',
                          isDense: true,
                          // No `border:` — the theme's is already the
                          // square hairline this page wants, and naming
                          // one here only overrode the rule.
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                ),
                        ),
                        onChanged: (s) => setState(() => _query = s.trim()),
                      ),
                    ),
                    // Filter chip rows: category + confidence.
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          _Chip(
                            label: uiStrings['allCategories']?[locale] ?? 'All',
                            selected: _categoryFilter == null,
                            onTap: () => setState(() => _categoryFilter = null),
                          ),
                          for (final c in categories)
                            _Chip(
                              label: _categoryLabel(c, locale),
                              selected: _categoryFilter == c,
                              onTap: () => setState(() {
                                _categoryFilter =
                                    _categoryFilter == c ? null : c;
                              }),
                            ),
                          const SizedBox(width: 12),
                          for (final lvl in const [
                            'Definitive',
                            'Strong',
                            'Circumstantial'
                          ])
                            _Chip(
                              label: _confidenceLabel(lvl, locale),
                              selected: _confidenceFilter == lvl,
                              outlineColor: _confidenceColor(lvl),
                              onTap: () => setState(() {
                                _confidenceFilter =
                                    _confidenceFilter == lvl ? null : lvl;
                              }),
                            ),
                        ],
                      ),
                    ),
                    // Result count.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            (uiStrings['resultsCount']?[locale] ??
                                    '{n} results')
                                .replaceAll('{n}', filtered.length.toString()),
                            style: TextStyle(
                              fontSize: t.scaledSmall(14),
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (filtered.isEmpty)
                      Expanded(
                        child: Center(
                          child: Text(
                            uiStrings['noResults']?[locale] ?? 'No results',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _refreshEvidence,
                          child: GridView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              // v1.3.84: 220 → 240. The 100px hero + the
                              // Expanded text block (title + 2-line summary +
                              // tappable scripture row) needed a few px more
                              // than 220 once the block was Expanded (it had
                              // been overflowing the column unboundedly — see
                              // the card). 240 leaves headroom for larger font
                              // scales and taller CJK text without overflow.
                              //
                              // 2026-08-25 (#315): the headroom was fictional.
                              // It held because all three text sizes in the
                              // card were clamped and stopped growing at the
                              // default, so "larger font scales" never
                              // actually arrived here. Unclamping them makes
                              // the tile's own 240 the frozen number, so the
                              // 140 px the text block gets moves with the
                              // reader while the 100 px hero does not.
                              // Evaluates to exactly 240 at the default.
                              //
                              // The `max` is not belt-and-braces: below the
                              // default the card's three sizes stop shrinking
                              // at `WbMetrics.smallPrintFloor`, so the text
                              // block has a hard minimum height that a
                              // proportional extent would undercut. Measured
                              // at 12 pt: ten columns overflowed until the
                              // tile was allowed to keep its 240.
                              mainAxisExtent:
                                  100 + math.max(140, t.scaled(140)),
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) => _EvidenceCard(
                              evidence: filtered[i],
                              locale: locale,
                              onTap: () => pushPage(
                                  EvidenceDetailPage(evidence: filtered[i])),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _refreshEvidence() async {
    await BibleEvidenceService.refresh();
    if (!mounted) return;
    final list = await BibleEvidenceService.all();
    if (!mounted) return;
    final filtered = widget.filterBook != null
        ? BibleEvidenceService.forBook(list, widget.filterBook!)
        : list;
    setState(() {
      _all = filtered.isEmpty ? list : filtered;
    });
  }

  String _categoryLabel(String c, String locale) =>
      uiStrings['category$c']?[locale] ?? c;

  String _confidenceLabel(String c, String locale) =>
      uiStrings['confidence$c']?[locale] ?? c;

  Color _confidenceColor(String c) {
    // Theme-aware confidence colors — paletteAccent gives shade700 in
    // light (deep green/orange = vivid against light surface) and
    // shade300 in dark (lighter so the indicator pops on dark
    // scaffold). Previously hardcoded shade800 hex values that were
    // too dark to read in dark mode.
    switch (c) {
      case 'Definitive':
        return paletteAccent(context, Colors.green);
      case 'Strong':
        return Theme.of(context).colorScheme.primary;
      case 'Circumstantial':
      default:
        return paletteAccent(context, Colors.orange);
    }
  }
}

class _EvidenceCard extends StatelessWidget {
  final BibleEvidence evidence;
  final String locale;
  final VoidCallback onTap;

  const _EvidenceCard({
    required this.evidence,
    required this.locale,
    required this.onTap,
  });

  // 2026-08 (ported from YsWords v1.4.5): press-scale feedback on the
  // whole card. PressScale is passive (Listener-based), so the InkWell
  // inside still owns the tap — see lib/widgets/press_scale.dart.
  @override
  Widget build(BuildContext context) => PressScale(child: _buildCard(context));

  Widget _buildCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wb = WbColors.of(context);
    // PERF: scoped select instead of full watch<AppSettings>() — this
    // card is instantiated per evidence entry (225 entries) inside a
    // ListView.builder; an unrelated settings change would otherwise
    // rebuild every mounted card. Same pattern as VerseWidget /
    // ParagraphGroupWidget.
    context.select<AppSettings, (String, double)>(
        (s) => (s.fontFamily, s.fontSize));
    final settings = context.read<AppSettings>();
    final t = settings.wbType;
    // Scoped select (not watch) for the same perf reason as above: only
    // a Bible-version change should re-render these reference labels.
    final currentVersion =
        context.select<MainProvider, String>((m) => m.currentVersion);
    final imgUrl = evidence.images.isNotEmpty ? evidence.images.first : null;

    return Material(
      color: wb.paneBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: wb.border, width: WbMetrics.hairline),
      ),
      child: Ink(
        child: InkWell(
          onTap: onTap,
          hoverColor: wb.hoverBg,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero image / icon fallback.
              //
              // 2026-08-08 (#279): the top corners used to be clipped to
              // a 12px radius. On this page that is not a style choice —
              // the photograph IS the evidence, and rounding it crops
              // the artefact. BibleWorks' own image surface (bwh10 Mss
              // tab) is a flush plate in a frame, and its whole help
              // topic is about examining the image, not framing it.
              Container(
                height: 100,
                decoration: BoxDecoration(
                  border: Border(
                    bottom:
                        BorderSide(color: wb.border, width: WbMetrics.hairline),
                  ),
                ),
                child: imgUrl != null
                    ?
                    // 2026-05-07: prefer <img> tag over canvaskit
                    // XHR fetch — external evidence-image CDNs
                    // generally lack CORS headers.
                    Image.network(
                        imgUrl,
                        fit: BoxFit.cover,
                        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                        // 2026-05-08 (v1.0.1 perf): card hero image
                        // is 100 px tall, full card width (~340 px
                        // on mobile, ~480 on tablet). 960 cache px
                        // is 2× the largest card on retina without
                        // holding source bitmaps.
                        cacheWidth: 960,
                        cacheHeight: 240,
                        // 2026-05-22 (v1.2.78): both LOADING and
                        // ERROR fall back to the gradient placeholder
                        // — never the emoji. Earlier rounds left the
                        // emoji on hard image errors, but Wikimedia
                        // rate-limits (429) and CORS surprises mean
                        // a non-trivial fraction of cards rendered as
                        // emoji on first paint. The gradient + small
                        // category icon reads as "loading / image
                        // unavailable" without visual jarring.
                        errorBuilder: (_, __, ___) => _ShimmerPlaceholder(
                          category: evidence.category,
                          showCategoryIcon: true,
                        ),
                        loadingBuilder: (_, child, p) {
                          if (p == null) return child;
                          return _ShimmerPlaceholder(
                            category: evidence.category,
                          );
                        },
                      )
                    : _ShimmerPlaceholder(
                        category: evidence.category,
                        showCategoryIcon: true,
                      ),
              ),
              // v1.3.84: Expanded so this text block gets the tile's
              // BOUNDED remaining height (mainAxisExtent 220 − 100 image).
              // Without it the block was a non-flex child of the outer
              // Column, which hands children UNBOUNDED vertical space — so
              // the `Spacer()` below ("non-zero flex but unbounded
              // constraints") threw and the whole evidence grid failed to
              // lay out (blank page + a cascade of RenderBox-not-laid-out
              // on /EvidencePage, reported from iOS).
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              evidence.localizedTitle(locale),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: settings.fontFamily,
                                fontFamilyFallback: kCjkFontFallback,
                                // `scaledSmall`, not `scaled`: at 12 pt a
                                // plain 18 × 0.6 is 10.8, which puts the
                                // card's own heading UNDER the floor its
                                // summary is held at — the same inversion
                                // this pass exists to remove, arriving from
                                // the other end of the slider.
                                fontSize: t.scaledSmall(18),
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          ConfidenceBadge(
                            level: evidence.confidenceLevel,
                            color: evidence.confidenceColor(scheme),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        evidence.localizedSummary(locale),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: settings.fontFamily,
                          fontFamilyFallback: kCjkFontFallback,
                          fontSize: t.scaledSmall(15),
                          color: scheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                      const Spacer(),
                      // Round 56: scripture-reference row is now its
                      // own tappable surface — tap takes the user
                      // straight to the cited verse in the reader,
                      // bypassing the detail page. User feedback:
                      // "圣经实证不是跟 bible 有关 — fix". Was: card
                      // showed the ref as plain text and only the
                      // detail page exposed a tappable chip, so the
                      // direct connection to scripture was buried.
                      InkWell(
                        onTap: () => _openReferenceFromCard(context, evidence),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 4),
                          child: Row(
                            children: [
                              Icon(Icons.menu_book_rounded,
                                  size: 14, color: scheme.primary),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  // 2026-08 (ported from YsWords v1.4.x):
                                  // scriptureReference is always stored in
                                  // English; render it through the same
                                  // locale-aware path every other reference
                                  // surface already uses.
                                  localizedReferenceLabel(
                                      evidence.scriptureReference,
                                      locale,
                                      currentVersion),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: settings.fontFamily,
                                    fontFamilyFallback: kCjkFontFallback,
                                    fontSize: t.scaledSmall(14),
                                    fontWeight: FontWeight.w700,
                                    color: scheme.primary,
                                    decoration: TextDecoration.underline,
                                    decorationColor:
                                        scheme.primary.withValues(alpha: 0.4),
                                    decorationStyle: TextDecorationStyle.dotted,
                                  ),
                                ),
                              ),
                              Icon(Icons.arrow_forward_rounded,
                                  size: 12,
                                  color:
                                      scheme.primary.withValues(alpha: 0.65)),
                            ],
                          ),
                        ),
                      ),
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

  /// Tapping the scripture-reference row on a card jumps the reader
  /// straight to the cited verse, bypassing the detail page. Mirrors
  /// `EvidenceDetailPage._openReference`: parse → resolveAndPrepareJump
  /// (with full-canon companion fallback for OT refs in NT-only
  /// versions) → SnackBar feedback → push HomePage.
  Future<void> _openReferenceFromCard(
      BuildContext context, BibleEvidence evidence) async {
    final raw = evidence.scriptureReference;
    BibleReference? ref = parseReference(raw);
    if (ref == null && raw.contains(';')) {
      for (final part in raw.split(';')) {
        ref = parseReference(part.trim());
        if (ref != null) break;
      }
    }
    if (ref == null) {
      final locale = context.read<AppSettings>().locale;
      final msg = (uiStrings['couldNotParseRef']?[locale] ??
              "Couldn't parse reference: {ref}")
          .replaceFirst('{ref}', raw);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 3),
      ));
      return;
    }
    final mp = context.read<MainProvider>();
    final result = await resolveAndPrepareJump(reference: ref, mp: mp);
    if (!context.mounted) return;
    final ok = await showJumpResultSnackBar(context, result);
    if (!ok || !context.mounted) return;
    navigateToReader(context);
  }
}

// v1.2.78: `_IconFallback` removed. Was the 36-px emoji shown on image
// load failure; replaced by `_ShimmerPlaceholder(showCategoryIcon: true)`
// which uses a Material category icon over the gradient — no emoji.

/// The empty plate — what a specimen frame holds when there is no
/// photograph. Used in two cases:
///   • While the hero Image.network is still loading (no icon)
///   • On hard image-load error (with a Material category icon)
/// In both cases this replaces the earlier emoji-only fallback — users
/// no longer see a wall of emoji-faces in the grid when images are slow
/// or Wikimedia rate-limits a batch of requests.
///
/// 2026-08-08 (#279): the fill was a three-stop category-tinted
/// gradient off `scheme.primary`/`secondary`/`tertiary`. Those roles
/// are seed-derived and untouched by `workbenchTheme`, so a grid with
/// several missing images was the most colourful thing on screen —
/// competing with the actual photographs, which are the information.
/// Flat `paneAltBg` with the category icon says "no image" without
/// asking for attention.
class _ShimmerPlaceholder extends StatelessWidget {
  final String category;
  final bool showCategoryIcon;
  const _ShimmerPlaceholder({
    required this.category,
    this.showCategoryIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    return Container(
      color: wb.paneAltBg,
      child: showCategoryIcon
          ? Center(
              child: Icon(
                evidenceCategoryIcon(category),
                size: 32,
                color: wb.mutedText,
              ),
            )
          : null,
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? outlineColor;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.outlineColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettings>();
    final t = settings.wbType;
    final accent = outlineColor ?? scheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: accent.withValues(alpha: 0.18),
        side: BorderSide(
            color: selected ? accent : scheme.outlineVariant,
            width: selected ? 1.4 : 1),
        labelStyle: TextStyle(
          fontFamily: settings.fontFamily,
          fontFamilyFallback: kCjkFontFallback,
          fontSize: t.scaledSmall(16),
          fontWeight: FontWeight.w600,
          color: selected ? accent : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ScopeBanner extends StatelessWidget {
  final _EvidenceScope scope;
  final bool wasFallback;

  /// Already localised by the caller. The English name it came from
  /// stays in `widget.filterBook`, which is what the service filters
  /// on; only the displayed one is translated.
  final String? book;
  final int? chapter;
  final String locale;
  final int count;
  final VoidCallback onWiden;

  const _ScopeBanner({
    required this.scope,
    required this.wasFallback,
    required this.book,
    required this.chapter,
    required this.locale,
    required this.count,
    required this.onWiden,
  });

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    // Both states used to be colour: a `primaryContainer` wash for the
    // normal one, `surfaceContainerHighest` for the fallback. Neither
    // role is remapped by `workbenchTheme`, so the normal state came
    // out as a seed-derived lilac — the one thing a neutral window
    // reserves for real information. The states are told apart by the
    // ICON and the words instead, which is what was carrying the
    // meaning anyway.
    final tone = wasFallback ? wb.paneAltBg : wb.chromeBg;
    final onTone = wb.text;
    final t = WbType.of(context);

    String fmt(String key, String fallback) {
      final raw = uiStrings[key]?[locale] ?? fallback;
      return raw
          .replaceAll('{n}', '$count')
          .replaceAll('{book}', book ?? '')
          .replaceAll('{chapter}', '${chapter ?? ''}');
    }

    String headline;
    String widenLabel;
    switch (scope) {
      case _EvidenceScope.chapter:
        headline = fmt('evidenceScopeChapter',
            '$count entries for ${book ?? ""} $chapter');
        widenLabel = fmt('evidenceWidenBook', 'Show all in ${book ?? ""}');
        break;
      case _EvidenceScope.book:
        if (wasFallback && chapter != null) {
          headline = fmt(
            'evidenceScopeBookFallback',
            'No entries for ${book ?? ""} $chapter — showing all $count from ${book ?? ""}',
          );
        } else {
          headline =
              fmt('evidenceScopeBook', '$count entries for ${book ?? ""}');
        }
        widenLabel = fmt('evidenceWidenArchive', 'Show full archive');
        break;
      case _EvidenceScope.archive:
        return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tone,
        border: Border.all(color: wb.border, width: WbMetrics.hairline),
      ),
      child: Row(
        children: [
          Icon(
            wasFallback ? Icons.info_outline : Icons.tune,
            size: 16,
            color: onTone,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              headline,
              style: TextStyle(fontSize: t.scaledSmall(13), color: onTone),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onWiden,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              widenLabel,
              style: TextStyle(fontSize: t.scaledSmall(13)),
            ),
          ),
        ],
      ),
    );
  }
}
