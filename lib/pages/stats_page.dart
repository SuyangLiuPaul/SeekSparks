import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/widgets/originals_sheet.dart';
import 'package:seeksparks/widgets/word_distribution_table.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/widgets/wb_surfaces.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/daily_verse_service.dart';
import 'package:seeksparks/services/fetch_books.dart' show standardBookOrder;
import 'package:seeksparks/services/originals_stats_service.dart';
import 'package:seeksparks/utils/clipboard_helper.dart';
import 'package:seeksparks/services/concordance_service.dart'
    show ConcordanceRef;
import 'package:seeksparks/utils/jump_to_reference.dart'
    show resolveAndPrepareJump;
import 'package:seeksparks/utils/reference_parser.dart'
    show BibleReference, parseReference;
import 'package:seeksparks/utils/version_mapper.dart'
    show toEnglish, localeAwareBookName;
import 'package:seeksparks/widgets/home_icon_button.dart';
import 'package:seeksparks/widgets/language_switcher_button.dart';
import 'package:seeksparks/widgets/localized_back_button.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;

/// Bible Tools page — three tabs (Overview / Lookup / Distribution).
/// Round 56 cleanup: the Vocabulary tab and the Strong's-search
/// section of the Lookup tab were both pulled out. User feedback:
/// "原文查询感觉下面的点任意... 下面的都没有用，上面的选择经文已经
/// 出来的popup窗口那个强多了。包括词汇其实也没有用那个tab，remove
/// those". The two removed surfaces re-implemented search affordances
/// the Distribution-tab's own picker already covers; keeping them
/// just gave users three near-identical search lists.
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    // Round 56: stats are now computed from Hebrew/Greek originals
    // via OriginalsStatsService, not from the current Bible version.
    // The old BibleStatsService translation-text counts are dead.

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: const LocalizedBackButton(),
          title: Text(uiStrings['statistics']?[locale] ?? 'Statistics'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            // 2026-05 dark-mode fix: was explicitly setting labelColor
            // / unselectedLabelColor / indicatorColor to onPrimary —
            // tuned for the light-mode primary-coloured AppBar. In
            // dark mode the AppBar uses primaryContainer (different
            // contrast pair), so onPrimary text was invisible.
            // Removing the override lets the global tabBarTheme in
            // main.dart handle both modes correctly (it sets
            // onPrimary in light + onPrimaryContainer in dark).
            tabs: [
              Tab(
                icon: const Icon(Icons.dashboard_outlined),
                text: uiStrings['statsOverview']?[locale] ?? 'Overview',
              ),
              // Round 56 (continued — Bible Tools rename): the
              // 'Books' tab was per-book originals stats — same data
              // the Overview now exposes via its book filter, so it
              // wasn't earning its slot. Replaced with a Strong's
              // lookup tool that opens the full StrongsEntryPage
              // (entry + word-family + concordance) for any tapped
              // result. User feedback: "书卷这一个tab感觉没有什么用，
              // 但是在经文里面的释经，里面的全部内容可以搬过来".
              Tab(
                icon: const Icon(Icons.search_rounded),
                text: uiStrings['statsLookup']?[locale] ?? 'Lookup',
              ),
              // Round 56 (continued): Word Distribution tab —
              // exposes the WordDistributionTable widget that
              // previously was only reachable via tap-a-verse →
              // originals sheet → tap a word → "show distribution".
              // User feedback: "ALSo there is a table, can you
              // have another tab for that table from exegesis?"
              Tab(
                icon: const Icon(Icons.table_chart_outlined),
                text: uiStrings['statsDistribution']?[locale] ?? 'Distribution',
              ),
            ],
          ),
          actions: const [
            LanguageSwitcherButton(),
            HomeIconButton(),
          ],
        ),
        // Round 56: every tab now sources from
        // `OriginalsStatsService.aggregate()` per user request:
        // "统计分析、词汇、书卷总揽都需要基于原文". The translation-text
        // word counts (BibleStatsService) are gone — those varied
        // per-version and conflated translator choices with the
        // underlying text. Hebrew + Greek lemma counts give a
        // consistent, version-independent view of "what's actually
        // in the Bible."
        body: TabBarView(
          children: [
            _OriginalsOverviewTab(locale: locale, settings: settings),
            _StrongsLookupTab(locale: locale, settings: settings),
            _WordDistributionTab(locale: locale, settings: settings),
          ],
        ),
      ),
    );
  }
}

String _humanNum(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) {
    return '${(n / 1000).toStringAsFixed(n < 10000 ? 1 : 0)}K';
  }
  return '${(n / 1000000).toStringAsFixed(1)}M';
}

/// Round 56: Overview tab — originals-based summary.
///
/// User: "统计分析、词汇、书卷总揽都需要基于原文". Drops the prior
/// translation-text word counts (which varied per-version) and
/// shows version-independent Hebrew/Greek lemma stats:
///   - Total Hebrew + Greek words (raw occurrences)
///   - Unique Hebrew + Greek lemmas (Strong's #s)
///   - Hapax (lemmas appearing exactly once)
///   - Top 5 Hebrew + 5 Greek lemmas with counts
class _OriginalsOverviewTab extends StatefulWidget {
  final String locale;
  final AppSettings settings;
  const _OriginalsOverviewTab({required this.locale, required this.settings});

  @override
  State<_OriginalsOverviewTab> createState() => _OriginalsOverviewTabState();
}

class _OriginalsOverviewTabState extends State<_OriginalsOverviewTab>
    with AutomaticKeepAliveClientMixin {
  // Round 56 (continued — wide-screen + book filter redesign):
  //
  // Two futures load in parallel. `_aggregateFuture` gives the
  // whole-Bible totals + canonical bookStats list. `_lemmasFuture`
  // gives every lemma with its per-book occurrence map (`byBook`),
  // which is what powers the per-book filtered Top-25 lists.
  // Both are cached at the service layer so the second open is
  // instant.
  Future<OriginalsAggregateStats>? _aggregateFuture;
  Future<List<OriginalsLemma>>? _lemmasFuture;
  final ScrollController _scrollCtrl = ScrollController();

  // 'all' = whole-Bible aggregate; otherwise an English book name
  // ('Genesis', 'Romans', …). When set, every stat tile + Top-25
  // list recomputes from `lemma.byBook[bookName]`.
  String _bookFilter = 'all';

  bool _hideStopwords = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _aggregateFuture = OriginalsStatsService.aggregate();
    _lemmasFuture = OriginalsStatsService.load();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final locale = widget.locale;
    final settings = widget.settings;
    return FutureBuilder<OriginalsAggregateStats>(
      future: _aggregateFuture,
      builder: (context, aggSnap) {
        return FutureBuilder<List<OriginalsLemma>>(
          future: _lemmasFuture,
          builder: (context, lemmasSnap) {
            if (aggSnap.connectionState != ConnectionState.done ||
                lemmasSnap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final stats = aggSnap.data;
            final allLemmas = lemmasSnap.data;
            if (stats == null || allLemmas == null) {
              return Center(
                child: Text(
                  uiStrings['statsOriginalsEmpty']?[locale] ??
                      'Original-language data not loaded.',
                  style: TextStyle(color: WbColors.of(context).mutedText),
                ),
              );
            }
            // Compute the view-model. When _bookFilter == 'all' this
            // is the whole-Bible aggregate; otherwise it's a derived
            // slice keyed off lemma.byBook[bookName].
            final view = _buildViewModel(stats, allLemmas);
            return Scrollbar(
              controller: _scrollCtrl,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                child: Center(
                  child: ConstrainedBox(
                    // Round 56: cap layout width at 1200 so the
                    // Overview doesn't sprawl edge-to-edge on
                    // 4K monitors. Below 1200 the layout fluidly
                    // fills available width via LayoutBuilder
                    // inside _StatGrid + the side-by-side lemma
                    // row.
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: _buildBody(
                        view: view,
                        locale: locale,
                        settings: settings,
                        availableBooks:
                            stats.bookStats.map((b) => b.englishBook).toSet(),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBody({
    required _OverviewView view,
    required String locale,
    required AppSettings settings,
    required Set<String> availableBooks,
  }) {
    return LayoutBuilder(
      builder: (ctx, c) {
        // ≥ 900px → render the two Top-25 lemma cards side-by-side
        // (each in a 50% column). Below that, stack vertically.
        // The threshold matches the iPad-portrait breakpoint where
        // a single column starts wasting horizontal space.
        final wide = c.maxWidth >= 900;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OverviewFilterBar(
              locale: locale,
              settings: settings,
              bookFilter: _bookFilter,
              hideStopwords: _hideStopwords,
              availableBooks: availableBooks,
              onBookChanged: (v) => setState(() => _bookFilter = v),
              onStopwordChanged: (v) => setState(() => _hideStopwords = v),
            ),
            const SizedBox(height: 16),
            // Round 56 (continued — languages card): user feedback
            // 'those blocks in overview is not helpful. remove them.
            // also apart from Greek and Hebrew but also have other
            // languages right. I remember like Aramaic'. The
            // numeric stat tiles (Hebrew words / Greek words /
            // Hebrew lemmas / Greek lemmas / Hapax / Books covered)
            // mostly duplicated information already visible from the
            // Top-25 cards. Replaced with an educational card listing
            // all three biblical source languages — Hebrew, Aramaic,
            // and Greek — with a one-paragraph background each. The
            // numbers that did add value (Hebrew/Greek totals) now
            // appear inline within the language descriptions when
            // we have them.
            _BibleLanguagesCard(
              view: view,
              locale: locale,
              settings: settings,
            ),
            const SizedBox(height: 20),
            if (wide)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (view.showHebrew)
                      Expanded(
                        child: _TopLemmasCard(
                          title: _topHebrewTitle(view, locale),
                          lemmas: _applyStopwordFilter(view.topHebrew)
                              .take(25)
                              .toList(),
                          isHebrew: true,
                          settings: settings,
                          locale: locale,
                        ),
                      ),
                    if (view.showHebrew && view.showGreek)
                      const SizedBox(width: 12),
                    if (view.showGreek)
                      Expanded(
                        child: _TopLemmasCard(
                          title: _topGreekTitle(view, locale),
                          lemmas: _applyStopwordFilter(view.topGreek)
                              .take(25)
                              .toList(),
                          isHebrew: false,
                          settings: settings,
                          locale: locale,
                        ),
                      ),
                  ],
                ),
              )
            else ...[
              if (view.showHebrew)
                _TopLemmasCard(
                  title: _topHebrewTitle(view, locale),
                  lemmas:
                      _applyStopwordFilter(view.topHebrew).take(25).toList(),
                  isHebrew: true,
                  settings: settings,
                  locale: locale,
                ),
              if (view.showHebrew && view.showGreek) const SizedBox(height: 12),
              if (view.showGreek)
                _TopLemmasCard(
                  title: _topGreekTitle(view, locale),
                  lemmas: _applyStopwordFilter(view.topGreek).take(25).toList(),
                  isHebrew: false,
                  settings: settings,
                  locale: locale,
                ),
            ],
          ],
        );
      },
    );
  }

  String _topHebrewTitle(_OverviewView view, String locale) {
    final base =
        uiStrings['statsOriginalsTopHebrew']?[locale] ?? 'Top Hebrew (OT)';
    if (view.bookFilter == null) return base;
    return '$base · ${localeAwareBookName(view.bookFilter!, locale)}';
  }

  String _topGreekTitle(_OverviewView view, String locale) {
    final base =
        uiStrings['statsOriginalsTopGreek']?[locale] ?? 'Top Greek (NT)';
    if (view.bookFilter == null) return base;
    return '$base · ${localeAwareBookName(view.bookFilter!, locale)}';
  }

  /// Compute the view model for the current filter setting.
  /// When `_bookFilter == 'all'` returns the whole-Bible figures
  /// from [stats]. When set to a specific book, recomputes:
  ///   • word totals: sum of `lemma.byBook[book]` across that
  ///     language's lemmas
  ///   • unique lemmas: how many lemmas appear at least once in
  ///     that book
  ///   • Top lemmas: re-sorted by `byBook[book]` count
  /// `showHebrew` / `showGreek` flip off when the selected book is
  /// pure-OT or pure-NT respectively, so we don't waste rows on
  /// "Greek words: 0" when the user is reading Genesis.
  _OverviewView _buildViewModel(
      OriginalsAggregateStats stats, List<OriginalsLemma> allLemmas) {
    if (_bookFilter == 'all') {
      return _OverviewView(
        bookFilter: null,
        hebrewWords: stats.totalHebrewWords,
        greekWords: stats.totalGreekWords,
        hebrewUnique: stats.uniqueHebrewLemmas,
        greekUnique: stats.uniqueGreekLemmas,
        hebrewHapax: stats.hebrewHapaxCount,
        greekHapax: stats.greekHapaxCount,
        booksCovered: stats.bookStats.length,
        topHebrew: stats.topHebrew,
        topGreek: stats.topGreek,
        showHebrew: true,
        showGreek: true,
      );
    }
    final book = _bookFilter;
    int hebrewWords = 0;
    int greekWords = 0;
    int hebrewUnique = 0;
    int greekUnique = 0;
    final hebrewBookHits = <_BookHit>[];
    final greekBookHits = <_BookHit>[];
    for (final l in allLemmas) {
      final c = l.byBook[book] ?? 0;
      if (c == 0) continue;
      if (l.isHebrew) {
        hebrewWords += c;
        hebrewUnique += 1;
        hebrewBookHits.add(_BookHit(l, c));
      } else {
        greekWords += c;
        greekUnique += 1;
        greekBookHits.add(_BookHit(l, c));
      }
    }
    hebrewBookHits.sort((a, b) => b.count.compareTo(a.count));
    greekBookHits.sort((a, b) => b.count.compareTo(a.count));
    // Build virtual lemmas with the book-specific count overlaid
    // onto a fresh `byBook` so the rendered count column reflects
    // the in-book frequency, not the global one. The original lemma
    // metadata (lemma string, gloss, transliteration) stays
    // untouched.
    final topHebrew = hebrewBookHits
        .map((h) => OriginalsLemma(
              strongs: h.lemma.strongs,
              isHebrew: true,
              lemma: h.lemma.lemma,
              translit: h.lemma.translit,
              glossEn: h.lemma.glossEn,
              glossZhHans: h.lemma.glossZhHans,
              glossZhHant: h.lemma.glossZhHant,
              count: h.count,
              byBook: h.lemma.byBook,
            ))
        .toList();
    final topGreek = greekBookHits
        .map((h) => OriginalsLemma(
              strongs: h.lemma.strongs,
              isHebrew: false,
              lemma: h.lemma.lemma,
              translit: h.lemma.translit,
              glossEn: h.lemma.glossEn,
              glossZhHans: h.lemma.glossZhHans,
              glossZhHant: h.lemma.glossZhHant,
              count: h.count,
              byBook: h.lemma.byBook,
            ))
        .toList();
    return _OverviewView(
      bookFilter: book,
      hebrewWords: hebrewWords,
      greekWords: greekWords,
      hebrewUnique: hebrewUnique,
      greekUnique: greekUnique,
      hebrewHapax: 0,
      greekHapax: 0,
      booksCovered: 1,
      topHebrew: topHebrew,
      topGreek: topGreek,
      // Auto-hide the testament that has no presence in this book.
      showHebrew: hebrewWords > 0,
      showGreek: greekWords > 0,
    );
  }

  /// Apply the [_hideStopwords] toggle: when ON, drops entries
  /// flagged as `isStopword`. When OFF, returns the input list
  /// unchanged.
  List<OriginalsLemma> _applyStopwordFilter(List<OriginalsLemma> input) {
    if (!_hideStopwords) return input;
    return input.where((l) => !l.isStopword).toList();
  }
}

/// Rendered view-model for one Overview frame. The `_buildViewModel`
/// helper produces this from either the whole-Bible aggregate or a
/// per-book derivation. Keeping the rendering pure-from-this-struct
/// keeps `build()` short and makes the wide-screen layout trivial
/// to reason about.
class _OverviewView {
  final String? bookFilter; // null = whole Bible
  final int hebrewWords;
  final int greekWords;
  final int hebrewUnique;
  final int greekUnique;
  final int hebrewHapax;
  final int greekHapax;
  final int booksCovered;
  final List<OriginalsLemma> topHebrew;
  final List<OriginalsLemma> topGreek;
  final bool showHebrew;
  final bool showGreek;

  const _OverviewView({
    required this.bookFilter,
    required this.hebrewWords,
    required this.greekWords,
    required this.hebrewUnique,
    required this.greekUnique,
    required this.hebrewHapax,
    required this.greekHapax,
    required this.booksCovered,
    required this.topHebrew,
    required this.topGreek,
    required this.showHebrew,
    required this.showGreek,
  });
}

class _BookHit {
  final OriginalsLemma lemma;
  final int count;
  const _BookHit(this.lemma, this.count);
}

/// Round 56: filter row at the top of the Overview tab. Holds the
/// book-filter button + active-filter chip + stopword toggle.
/// Same modal-sheet pattern as the songs / trivia pages so users
/// see consistent affordances across the app.
class _OverviewFilterBar extends StatelessWidget {
  final String locale;
  final AppSettings settings;
  final String bookFilter;
  final bool hideStopwords;
  final Set<String> availableBooks;
  final ValueChanged<String> onBookChanged;
  final ValueChanged<bool> onStopwordChanged;

  const _OverviewFilterBar({
    required this.locale,
    required this.settings,
    required this.bookFilter,
    required this.hideStopwords,
    required this.availableBooks,
    required this.onBookChanged,
    required this.onStopwordChanged,
  });

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final filterLabel = uiStrings['sermonFilterByPassage']?[locale] ?? 'Filter';
    final scope = Text(
      bookFilter == 'all'
          ? (uiStrings['statsOriginalsScopeAll']?[locale] ?? 'Whole Bible')
          : (uiStrings['statsOriginalsScopeBook']?[locale] ?? 'Showing: {book}')
              .replaceAll('{book}', localeAwareBookName(bookFilter, locale)),
      style: TextStyle(
        fontSize: t.text,
        height: t.lineHeight,
        color: wb.mutedText,
        fontWeight: FontWeight.w600,
      ),
    );
    // Hide-stopwords toggle sits inline as a compact chip button —
    // frees the vertical space the old card took up.
    final stopwords = FilterChip(
      avatar: Icon(
        hideStopwords ? Icons.filter_alt : Icons.filter_alt_off,
        size: t.text + 4,
      ),
      label: Text(
        uiStrings['statsOriginalsHideStopwordsTitle']?[locale] ??
            'Hide common particles',
        style: TextStyle(fontSize: t.text),
      ),
      selected: hideStopwords,
      onSelected: onStopwordChanged,
    );
    final bookButton = OutlinedButton.icon(
      onPressed: () => _openBookSheet(context),
      icon: Icon(
        bookFilter == 'all' ? Icons.filter_list : Icons.filter_list_alt,
        size: t.text + 5,
      ),
      label: Text(filterLabel, style: TextStyle(fontSize: t.text)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        // "A filter is active" is a step in VALUE, not a tint —
        // the same rule WbPanel.alt encodes.
        backgroundColor: bookFilter == 'all' ? null : wb.selectionBg,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A Row hands its unflexed children their intrinsic width first,
        // and the stopword chip's label is a four-word sentence. At the
        // 320px pane minimum that left the Expanded scope label about
        // ten pixels and it printed one character per line. Under the
        // breakpoint the label takes its own line and the two controls
        // wrap instead.
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < 460
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    scope,
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [stopwords, bookButton],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: scope),
                    stopwords,
                    const SizedBox(width: 6),
                    bookButton,
                  ],
                ),
        ),
        if (bookFilter != 'all') ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: InputChip(
              avatar:
                  Icon(Icons.bookmark, size: t.text + 4, color: wb.mutedText),
              label: Text(localeAwareBookName(bookFilter, locale)),
              onDeleted: () => onBookChanged('all'),
              backgroundColor: wb.selectionBg,
            ),
          ),
        ],
      ],
    );
  }

  void _openBookSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return _OverviewBookFilterSheet(
          locale: locale,
          availableBooks: availableBooks,
          initialBook: bookFilter == 'all' ? null : bookFilter,
          onApply: (book) {
            onBookChanged(book ?? 'all');
            Navigator.of(sheetCtx).pop();
          },
          onClear: () {
            onBookChanged('all');
            Navigator.of(sheetCtx).pop();
          },
        );
      },
    );
  }
}

/// Modal book picker for the Overview filter — copies the layout
/// of `_TriviaBookFilterSheet` so the affordance is the same
/// everywhere.
class _OverviewBookFilterSheet extends StatefulWidget {
  final String locale;
  final Set<String> availableBooks;
  final String? initialBook;
  final void Function(String? book) onApply;
  final VoidCallback onClear;

  const _OverviewBookFilterSheet({
    required this.locale,
    required this.availableBooks,
    required this.initialBook,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_OverviewBookFilterSheet> createState() =>
      _OverviewBookFilterSheetState();
}

class _OverviewBookFilterSheetState extends State<_OverviewBookFilterSheet> {
  String? _selectedBook;

  @override
  void initState() {
    super.initState();
    _selectedBook = widget.initialBook;
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.bookmark,
                    size: 18, color: WbColors.of(context).mutedText),
                const SizedBox(width: 8),
                Text(
                  uiStrings['sermonFilterByPassage']?[locale] ??
                      'Filter by passage',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (widget.initialBook != null)
                  TextButton(
                    onPressed: widget.onClear,
                    child: Text(uiStrings['clearFilter']?[locale] ?? 'Clear'),
                  ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final b in standardBookOrder)
                      _OverviewBookChip(
                        book: b,
                        locale: locale,
                        hasData: widget.availableBooks.contains(b),
                        selected: _selectedBook == b,
                        onTap: () => setState(() {
                          _selectedBook = _selectedBook == b ? null : b;
                        }),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => widget.onApply(_selectedBook),
              child: Text(uiStrings['apply']?[locale] ?? 'Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewBookChip extends StatelessWidget {
  final String book;
  final String locale;
  final bool hasData;
  final bool selected;
  final VoidCallback onTap;
  const _OverviewBookChip({
    required this.book,
    required this.locale,
    required this.hasData,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final localized = localeAwareBookName(book, locale, '');
    return ChoiceChip(
      label: Text(
        localized,
        style: TextStyle(
          fontSize: 13,
          color: hasData ? null : Theme.of(context).disabledColor,
        ),
      ),
      selected: selected,
      onSelected: hasData ? (_) => onTap() : null,
    );
  }
}

/// Shared launcher for the OriginalsSheet flow. Both
/// `_StrongsLookupTabState` and `_BibleLanguagesCard` need to open
/// the exegesis sheet for an arbitrary (book, chapter, verse), with
/// cross-version fallback when the verse isn't in the loaded
/// translation. Pulled out as a top-level helper so the language
/// card can call it without going through Lookup-tab state.
class _ExegesisLauncher {
  /// Open OriginalsSheet for one verse. Same path the Lookup tab
  /// uses — handles "verse missing in current version" by routing
  /// through resolveAndPrepareJump so OT books open in CUVS-YHWH
  /// when the user is on an NT-only translation, etc.
  static void study({
    required BuildContext context,
    required String locale,
    required String book,
    required int chapter,
    required int verse,
  }) {
    final mp = context.read<MainProvider>();
    final matches = mp.verses
        .where(
            (v) => v.book == book && v.chapter == chapter && v.verse == verse)
        .toList();
    if (matches.isEmpty) {
      _resolveAndOpen(context,
          locale: locale, book: book, chapter: chapter, verse: verse);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 1100),
      builder: (sheetCtx) => OriginalsSheet(
        verses: matches,
        allVerses: mp.verses,
        locale: locale,
        currentVersion: mp.currentVersion,
        onNavigateRef: (ref) {
          Navigator.of(sheetCtx).maybePop();
          _hopToRef(context, locale, ref);
        },
      ),
    );
  }

  /// Open the 3-step verse picker, then study the picked verse.
  /// Used by the language card's Hebrew / Greek rows, which want a
  /// "any-verse" entry point rather than the curated Aramaic list.
  static Future<void> pickAndStudy({
    required BuildContext context,
    required String locale,
    required AppSettings settings,
  }) async {
    final mp = context.read<MainProvider>();
    final picked = await showModalBottomSheet<_PickedRef>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => _VersePickerSheet(
        mp: mp,
        locale: locale,
        settings: settings,
      ),
    );
    if (picked == null || !context.mounted) return;
    study(
      context: context,
      locale: locale,
      book: picked.book,
      chapter: picked.chapter,
      verse: picked.verse,
    );
  }

  static Future<void> _resolveAndOpen(BuildContext context,
      {required String locale,
      required String book,
      required int chapter,
      required int verse}) async {
    final mp = context.read<MainProvider>();
    final ref = BibleReference(
      englishBook: toEnglish(book) ?? book,
      chapter: chapter,
      verseStart: verse,
      verseEnd: verse,
    );
    final result = await resolveAndPrepareJump(reference: ref, mp: mp);
    if (!context.mounted || !result.ready) return;
    final v = mp.verses.firstWhere(
      (x) =>
          x.chapter == chapter &&
          x.verse == verse &&
          (x.book == book || toEnglish(x.book) == toEnglish(book)),
      orElse: () => mp.verses.isNotEmpty
          ? mp.verses.first
          : Verse(
              book: book,
              chapter: chapter,
              verse: verse,
              verseLabel: '$verse',
              text: '',
            ),
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 1100),
      builder: (sheetCtx) => OriginalsSheet(
        verses: [v],
        allVerses: mp.verses,
        locale: locale,
        currentVersion: mp.currentVersion,
        onNavigateRef: (ref) {
          Navigator.of(sheetCtx).maybePop();
          _hopToRef(context, locale, ref);
        },
      ),
    );
  }

  static void _hopToRef(
      BuildContext context, String locale, ConcordanceRef ref) {
    final mp = context.read<MainProvider>();
    final localBook = mp.verses.isEmpty
        ? null
        : mp.verses
            .firstWhere(
              (v) => (toEnglish(v.book) ?? v.book) == ref.englishBook,
              orElse: () => mp.verses.first,
            )
            .book;
    final book = localBook ?? ref.englishBook;
    study(
      context: context,
      locale: locale,
      book: book,
      chapter: ref.chapter,
      verse: ref.verse,
    );
  }
}

/// Round 56 (continued): one entry in the curated Aramaic-passages
/// list. Aramaic biblical content is small enough to enumerate
/// fully; this struct holds the reference + a one-phrase factual
/// note about what's in the passage (NOT the verse text itself —
/// taps open the OriginalsSheet which renders from the user's own
/// bundled Bible). For NT phrases the [transliteration] is the
/// actual Aramaic word as it appears transliterated in Greek text
/// (e.g. 'abba', 'maranatha').
class _AramaicEntry {
  final String englishBook;
  final int chapter;

  /// Starting verse — what we open the OriginalsSheet at.
  final int verse;

  /// Localised i18n key for the reference label shown to the user
  /// (e.g. 'aramRefDanielSection', 'aramRefMarkAbba').
  final String labelKey;

  /// Localised i18n key for the one-line description.
  final String descKey;

  /// For NT phrases, the transliterated Aramaic word/phrase.
  /// Null for OT sections (the whole passage is Aramaic, not a
  /// single embedded word).
  final String? transliteration;
  const _AramaicEntry({
    required this.englishBook,
    required this.chapter,
    required this.verse,
    required this.labelKey,
    required this.descKey,
    this.transliteration,
  });
}

/// Curated full list of Aramaic biblical passages. References are
/// factual citations; descriptions in [descKey] are short factual
/// notes authored fresh for this app. NT entries also carry the
/// transliterated phrase that's actually Aramaic embedded in
/// Greek text.
const List<_AramaicEntry> _aramaicPassages = [
  // ── OT sections (the entire passage is Aramaic) ───────────────
  _AramaicEntry(
    englishBook: 'Genesis',
    chapter: 31,
    verse: 47,
    labelKey: 'aramRefGenesis',
    descKey: 'aramDescGenesis',
    transliteration: 'יְגַר שָׂהֲדוּתָא',
  ),
  _AramaicEntry(
    englishBook: 'Jeremiah',
    chapter: 10,
    verse: 11,
    labelKey: 'aramRefJeremiah',
    descKey: 'aramDescJeremiah',
  ),
  _AramaicEntry(
    englishBook: 'Daniel',
    chapter: 2,
    verse: 4,
    labelKey: 'aramRefDaniel',
    descKey: 'aramDescDaniel',
  ),
  _AramaicEntry(
    englishBook: 'Ezra',
    chapter: 4,
    verse: 8,
    labelKey: 'aramRefEzraA',
    descKey: 'aramDescEzraA',
  ),
  _AramaicEntry(
    englishBook: 'Ezra',
    chapter: 7,
    verse: 12,
    labelKey: 'aramRefEzraB',
    descKey: 'aramDescEzraB',
  ),
  // ── NT phrases (single Aramaic word/phrase embedded in Greek) ─
  _AramaicEntry(
    englishBook: 'Matthew',
    chapter: 5,
    verse: 22,
    labelKey: 'aramRefRaca',
    descKey: 'aramDescRaca',
    transliteration: 'ῥακά (raqa)',
  ),
  _AramaicEntry(
    englishBook: 'Mark',
    chapter: 5,
    verse: 41,
    labelKey: 'aramRefTalitha',
    descKey: 'aramDescTalitha',
    transliteration: 'ταλιθα κουμ (talitha koum)',
  ),
  _AramaicEntry(
    englishBook: 'Mark',
    chapter: 7,
    verse: 34,
    labelKey: 'aramRefEphphatha',
    descKey: 'aramDescEphphatha',
    transliteration: 'εφφαθα (ephphatha)',
  ),
  _AramaicEntry(
    englishBook: 'Mark',
    chapter: 14,
    verse: 36,
    labelKey: 'aramRefAbba',
    descKey: 'aramDescAbba',
    transliteration: 'ἀββα (abba)',
  ),
  _AramaicEntry(
    englishBook: 'Mark',
    chapter: 15,
    verse: 34,
    labelKey: 'aramRefSabachthani',
    descKey: 'aramDescSabachthani',
    transliteration: 'ελωι ελωι λεμα σαβαχθανι',
  ),
  _AramaicEntry(
    englishBook: '1 Corinthians',
    chapter: 16,
    verse: 22,
    labelKey: 'aramRefMaranatha',
    descKey: 'aramDescMaranatha',
    transliteration: 'μαραν αθα (marana tha)',
  ),
];

/// Round 56 (continued): educational card replacing the old stat-
/// block grid. Lists every source language the Bible was originally
/// written in — Hebrew, Aramaic, Greek — with a one-paragraph
/// background each, the canonical sections each language covers,
/// and (for Hebrew + Greek) the running word totals from the
/// originals stats. Inline stats fold the numeric value the old
/// blocks carried into a more meaningful context.
///
/// Each row is tappable: Hebrew / Greek open the standard verse
/// picker → OriginalsSheet, Aramaic opens a curated list of all
/// Aramaic passages (small enough to enumerate fully). The
/// OriginalsSheet already has Gemini AI explain built in, so all
/// three flows give the user the same exegesis affordance.
class _BibleLanguagesCard extends StatelessWidget {
  final _OverviewView view;
  final String locale;
  final AppSettings settings;

  const _BibleLanguagesCard({
    required this.view,
    required this.locale,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final title = uiStrings['languagesCardTitle']?[locale] ??
        'Original languages of the Bible';
    final subtitle = uiStrings['languagesCardSubtitle']?[locale] ??
        'The three source languages and where each appears in the canon.';
    return WbPanel(
      icon: Icons.translate_rounded,
      title: title,
      subtitle: subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(builder: (rowCtx) {
            return _LanguageRow(
              scriptColor: Colors.indigo,
              scriptLabel: 'אבג',
              nameKey: 'languageHebrewName',
              roleKey: 'languageHebrewRole',
              sectionsKey: 'languageHebrewSections',
              backgroundKey: 'languageHebrewBackground',
              wordCount: view.hebrewWords > 0 ? view.hebrewWords : null,
              uniqueLemmas: view.hebrewUnique > 0 ? view.hebrewUnique : null,
              locale: locale,
              settings: settings,
              // Hebrew → standard verse picker. User picks any OT
              // verse and the OriginalsSheet shows word-by-word
              // breakdown (with Gemini AI explain).
              onTap: () => _ExegesisLauncher.pickAndStudy(
                context: rowCtx,
                locale: locale,
                settings: settings,
              ),
            );
          }),
          const SizedBox(height: 14),
          Builder(builder: (rowCtx) {
            return _LanguageRow(
              // Biblical Aramaic is written in the Hebrew square
              // script — Daniel 2:4-7:28 and Ezra 4:8-6:18 sit inside
              // Hebrew books and change language without changing
              // letters. So the badge repeats אבג deliberately, in a
              // different hue: two rows, one alphabet, which is the
              // fact the row exists to teach. It read ܐܒܓ until
              // v1.6.73, which is Syriac — a later and different
              // script, and the only glyph left in the UI that still
              // made the engine fetch a font from fonts.gstatic.com.
              scriptColor: Colors.teal,
              scriptLabel: 'אבג',
              nameKey: 'languageAramaicName',
              roleKey: 'languageAramaicRole',
              sectionsKey: 'languageAramaicSections',
              backgroundKey: 'languageAramaicBackground',
              wordCount: null,
              uniqueLemmas: null,
              locale: locale,
              settings: settings,
              // Aramaic → curated full passage list. Small enough
              // to enumerate fully (5 OT sections + 6 NT phrases).
              onTap: () => _openAramaicSheet(rowCtx, locale, settings),
            );
          }),
          const SizedBox(height: 14),
          Builder(builder: (rowCtx) {
            return _LanguageRow(
              scriptColor: Colors.deepPurple,
              scriptLabel: 'αβγ',
              nameKey: 'languageGreekName',
              roleKey: 'languageGreekRole',
              sectionsKey: 'languageGreekSections',
              backgroundKey: 'languageGreekBackground',
              wordCount: view.greekWords > 0 ? view.greekWords : null,
              uniqueLemmas: view.greekUnique > 0 ? view.greekUnique : null,
              locale: locale,
              settings: settings,
              // Greek → same standard verse picker as Hebrew.
              onTap: () => _ExegesisLauncher.pickAndStudy(
                context: rowCtx,
                locale: locale,
                settings: settings,
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Open the curated Aramaic-passages list. Each entry tap opens
  /// the same OriginalsSheet (with Gemini AI explain) Hebrew/Greek
  /// rows reach via the verse picker.
  void _openAramaicSheet(
      BuildContext context, String locale, AppSettings settings) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => _AramaicPassagesSheet(
        locale: locale,
        settings: settings,
      ),
    );
  }
}

/// Round 56 (continued — Aramaic full list): the 5 OT sections +
/// 6 NT phrases that are written in Aramaic rather than Hebrew or
/// Greek. Two visual sections (OT / NT). Each entry shows:
///   • localised reference (e.g. '但以理 2:4–7:28')
///   • the actual Aramaic / transliterated phrase (where applicable)
///   • a one-line factual description in the user's locale
///   • a 'Study →' affordance that opens the OriginalsSheet for
///     the starting verse — and from there Gemini AI explain is
///     one tap away inside the sheet itself.
///
/// We deliberately don't render the verse text in this sheet —
/// the OriginalsSheet is the single source of truth for that, and
/// reaches it from the user's already-loaded Bible asset.
class _AramaicPassagesSheet extends StatelessWidget {
  final String locale;
  final AppSettings settings;
  const _AramaicPassagesSheet({required this.locale, required this.settings});

  @override
  Widget build(BuildContext context) {
    // Split into OT (5 entries) and NT (6 entries) for visual
    // grouping; the canonical order matches the order entries are
    // declared in `_aramaicPassages`.
    final otEntries = _aramaicPassages
        .where((e) => _isOtBookForAramaic(e.englishBook))
        .toList();
    final ntEntries = _aramaicPassages
        .where((e) => !_isOtBookForAramaic(e.englishBook))
        .toList();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.translate_rounded,
                      size: 20, color: WbColors.of(context).mutedText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      uiStrings['aramSheetTitle']?[locale] ??
                          'Aramaic in the Bible',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  // Round 56 (continued — Aramaic copy): one-tap export
                  // of the full curated list (OT sections + NT phrases)
                  // as a plain-text outline. Uses copyWithFeedback so
                  // the user gets a "Copied!" snack and the sheet stays
                  // open in case they want to study a passage too.
                  IconButton(
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    tooltip: uiStrings['aramCopyTooltip']?[locale] ??
                        'Copy Aramaic passage list',
                    onPressed: () => _copyAramaicList(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                uiStrings['aramSheetSubtitle']?[locale] ??
                    'Tap any entry to open the verse with word-by-word breakdown and Gemini AI explanation.',
                style: TextStyle(
                  fontSize: 12,
                  color: WbColors.of(context).mutedText,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SheetGroupHeader(
                        text: uiStrings['aramGroupOt']?[locale] ??
                            'Old Testament sections',
                      ),
                      const SizedBox(height: 6),
                      for (final e in otEntries) ...[
                        _AramaicEntryTile(
                          entry: e,
                          locale: locale,
                          settings: settings,
                          onTap: () {
                            Navigator.of(context).maybePop();
                            _ExegesisLauncher.study(
                              context: context,
                              locale: locale,
                              book: _resolveLocalBook(context, e.englishBook),
                              chapter: e.chapter,
                              verse: e.verse,
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                      ],
                      const SizedBox(height: 8),
                      _SheetGroupHeader(
                        text: uiStrings['aramGroupNt']?[locale] ??
                            'New Testament phrases',
                      ),
                      const SizedBox(height: 6),
                      for (final e in ntEntries) ...[
                        _AramaicEntryTile(
                          entry: e,
                          locale: locale,
                          settings: settings,
                          onTap: () {
                            Navigator.of(context).maybePop();
                            _ExegesisLauncher.study(
                              context: context,
                              locale: locale,
                              book: _resolveLocalBook(context, e.englishBook),
                              chapter: e.chapter,
                              verse: e.verse,
                            );
                          },
                        ),
                        const SizedBox(height: 6),
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

  /// Resolve canonical English book to the localised name the
  /// MainProvider's verse list uses (e.g. 'Daniel' → '但以理书' for
  /// CUVS). Falls back to the English name when no match.
  String _resolveLocalBook(BuildContext context, String englishBook) {
    final mp = context.read<MainProvider>();
    if (mp.verses.isEmpty) return englishBook;
    return mp.verses
        .firstWhere(
          (v) => (toEnglish(v.book) ?? v.book) == englishBook,
          orElse: () => mp.verses.first,
        )
        .book;
  }

  /// Tiny helper: which entries belong to the OT half vs the NT
  /// half. Avoids a full canonical lookup for the small Aramaic
  /// list — just spot-checks the four OT books that have Aramaic.
  static bool _isOtBookForAramaic(String englishBook) {
    return englishBook == 'Genesis' ||
        englishBook == 'Jeremiah' ||
        englishBook == 'Daniel' ||
        englishBook == 'Ezra';
  }

  /// Round 56 (continued — Aramaic copy): builds a plain-text outline
  /// of the curated 11-passage list and copies it to the clipboard.
  /// Layout — sheet title, subtitle, OT group header with bullets
  /// (ref label — description), then NT group header with bullets
  /// (ref label, optional transliteration in brackets, description).
  ///
  /// All strings are rendered in the user's current locale so the
  /// copied output matches what they see on screen.
  void _copyAramaicList(BuildContext context) {
    final title =
        uiStrings['aramSheetTitle']?[locale] ?? 'Aramaic in the Bible';
    final subtitle = uiStrings['aramSheetSubtitle']?[locale] ?? '';
    final otHeader =
        uiStrings['aramGroupOt']?[locale] ?? 'Old Testament sections';
    final ntHeader =
        uiStrings['aramGroupNt']?[locale] ?? 'New Testament phrases';
    final buf = StringBuffer();
    buf.writeln(title);
    if (subtitle.isNotEmpty) buf.writeln(subtitle);
    buf.writeln();

    final otEntries = _aramaicPassages
        .where((e) => _isOtBookForAramaic(e.englishBook))
        .toList();
    final ntEntries = _aramaicPassages
        .where((e) => !_isOtBookForAramaic(e.englishBook))
        .toList();

    void writeGroup(String header, List<_AramaicEntry> entries) {
      buf.writeln(header);
      for (final e in entries) {
        final ref = uiStrings[e.labelKey]?[locale] ?? e.labelKey;
        final desc = uiStrings[e.descKey]?[locale] ?? '';
        final tl = e.transliteration ?? '';
        buf.write('  • ');
        buf.write(ref);
        if (tl.isNotEmpty) {
          buf.write('  [');
          buf.write(tl);
          buf.write(']');
        }
        if (desc.isNotEmpty) {
          buf.write(' — ');
          buf.write(desc);
        }
        buf.writeln();
      }
      buf.writeln();
    }

    writeGroup(otHeader, otEntries);
    writeGroup(ntHeader, ntEntries);

    final text = buf.toString().trimRight();
    ClipboardHelper.copyWithFeedback(
      context,
      text,
      messageOverride: uiStrings['aramCopiedToast']?[locale],
    );
  }
}

class _SheetGroupHeader extends StatelessWidget {
  final String text;
  const _SheetGroupHeader({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: WbColors.of(context).mutedText,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _AramaicEntryTile extends StatelessWidget {
  final _AramaicEntry entry;
  final String locale;
  final AppSettings settings;
  final VoidCallback onTap;
  const _AramaicEntryTile({
    required this.entry,
    required this.locale,
    required this.settings,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = uiStrings[entry.labelKey]?[locale] ??
        '${entry.englishBook} ${entry.chapter}:${entry.verse}';
    final desc = uiStrings[entry.descKey]?[locale] ?? '';
    final ref =
        '${localeAwareBookName(entry.englishBook, locale)} ${entry.chapter}:${entry.verse}';
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    return WbTile(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: settings.fontFamily,
                    fontFamilyFallback: kCjkFontFallback,
                    fontSize: t.text + 1,
                    height: t.lineHeight,
                    fontWeight: FontWeight.w700,
                    color: wb.text,
                  ),
                ),
                Text(
                  ref,
                  style: TextStyle(
                    fontSize: t.chrome,
                    height: t.lineHeight,
                    color: wb.link,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (entry.transliteration != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    entry.transliteration!,
                    style: TextStyle(
                      fontSize: t.text,
                      height: t.lineHeight,
                      fontWeight: FontWeight.w700,
                      // The workbench already has a colour for "this is
                      // the original-language form": the same green it
                      // prints a lexical Strong's number in.
                      color: wb.strongsLexical,
                    ),
                  ),
                ],
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    style: TextStyle(
                      fontFamily: settings.fontFamily,
                      fontFamilyFallback: kCjkFontFallback,
                      fontSize: t.text,
                      height: 1.4,
                      color: wb.mutedText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, size: t.text + 5, color: wb.mutedText),
        ],
      ),
    );
  }
}

/// The ink for an original-language marker — a script badge, a Strong's
/// tag — in a hue that stays legible on all three workbench palettes.
///
/// This replaces `paletteFg`/`paletteBg` in this file. Those key off
/// `Theme.of(context).brightness`, which is wrong under 护眼纸质: the
/// ThemeMode can be dark while every surface on screen is cream, so a
/// light-mode shade got picked for a dark background and vice versa.
/// [WbColors.isDark] asks the palette instead.
Color _scriptHue(WbColors wb, MaterialColor hue) =>
    wb.isDark ? hue.shade200 : hue.shade800;

/// As [_scriptHue], for the two testament languages, which are named by
/// a bool rather than by a colour everywhere they are printed.
Color _originalScriptHue(WbColors wb, {required bool hebrew}) =>
    _scriptHue(wb, hebrew ? Colors.red : Colors.purple);

/// Row inside _BibleLanguagesCard. Two columns: a script-glyph
/// badge on the left (אבג / αβγ) so the language is visually
/// recognisable before the user reads the text, and the localised
/// name + role + sections + background paragraph on the right.
/// Stats for languages we have counts for fold into the role line.
class _LanguageRow extends StatelessWidget {
  /// MaterialColor (not just Color) so we can access `.shade900`
  /// for the glyph badge text against the lightly-tinted box.
  final MaterialColor scriptColor;
  final String scriptLabel;
  final String nameKey;
  final String roleKey;
  final String sectionsKey;
  final String backgroundKey;
  final int? wordCount;
  final int? uniqueLemmas;
  final String locale;
  final AppSettings settings;

  /// Round 56: tappable affordance — Hebrew/Greek opens the verse
  /// picker, Aramaic opens the curated passages sheet. Each path
  /// ultimately lands on the OriginalsSheet which has Gemini AI
  /// explain built in.
  final VoidCallback? onTap;

  const _LanguageRow({
    required this.scriptColor,
    required this.scriptLabel,
    required this.nameKey,
    required this.roleKey,
    required this.sectionsKey,
    required this.backgroundKey,
    required this.wordCount,
    required this.uniqueLemmas,
    required this.locale,
    required this.settings,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = uiStrings[nameKey]?[locale] ?? '';
    final role = uiStrings[roleKey]?[locale] ?? '';
    final sections = uiStrings[sectionsKey]?[locale] ?? '';
    final background = uiStrings[backgroundKey]?[locale] ?? '';
    final wordsLabel = wordCount != null
        ? (uiStrings['languageWordCount']?[locale] ?? '{n} words')
            .replaceAll('{n}', _humanNum(wordCount!))
        : null;
    final lemmasLabel = uniqueLemmas != null
        ? (uiStrings['languageLemmaCount']?[locale] ?? '{n} lemmas')
            .replaceAll('{n}', _humanNum(uniqueLemmas!))
        : null;
    final body = _buildBody(
        context: context,
        name: name,
        role: role,
        sections: sections,
        background: background,
        wordsLabel: wordsLabel,
        lemmasLabel: lemmasLabel);
    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: body,
      );
    }
    // The whole row is the target — taps anywhere trigger the
    // language's flow — but it is not boxed, because these rows sit
    // inside a WbPanel that is already a box and a box in a box is how
    // the classic design got its stacked cards.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: WbColors.of(context).hoverBg,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: body,
        ),
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required String name,
    required String role,
    required String sections,
    required String background,
    required String? wordsLabel,
    required String? lemmasLabel,
  }) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: wb.paneAltBg,
            border: Border.all(color: wb.border, width: WbMetrics.hairline),
          ),
          alignment: Alignment.center,
          child: Text(
            scriptLabel,
            style: TextStyle(
              fontSize: t.original + 5,
              fontWeight: FontWeight.w700,
              color: _scriptHue(wb, scriptColor),
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontFamily: settings.fontFamily,
                        fontFamilyFallback: kCjkFontFallback,
                        fontSize: t.text + 2,
                        height: t.lineHeight,
                        fontWeight: FontWeight.w700,
                        color: wb.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      role,
                      style: TextStyle(
                        fontFamily: settings.fontFamily,
                        fontFamilyFallback: kCjkFontFallback,
                        fontSize: t.chrome,
                        height: t.lineHeight,
                        color: wb.mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (wordsLabel != null || lemmasLabel != null)
                Text(
                  [wordsLabel, lemmasLabel].whereType<String>().join(' · '),
                  style: TextStyle(
                    fontFamily: settings.fontFamily,
                    fontFamilyFallback: kCjkFontFallback,
                    fontSize: t.chrome,
                    height: t.lineHeight,
                    color: wb.mutedText,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              const SizedBox(height: 5),
              if (sections.isNotEmpty) ...[
                Text(
                  sections,
                  style: TextStyle(
                    fontFamily: settings.fontFamily,
                    fontFamilyFallback: kCjkFontFallback,
                    fontSize: t.text,
                    height: 1.5,
                    color: wb.text,
                  ),
                ),
                const SizedBox(height: 5),
              ],
              Text(
                background,
                style: TextStyle(
                  fontFamily: settings.fontFamily,
                  fontFamilyFallback: kCjkFontFallback,
                  fontSize: t.text,
                  height: 1.5,
                  color: wb.mutedText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopLemmasCard extends StatelessWidget {
  final String title;
  final List<OriginalsLemma> lemmas;
  final bool isHebrew;
  final AppSettings settings;
  final String locale;
  const _TopLemmasCard({
    required this.title,
    required this.lemmas,
    required this.isHebrew,
    required this.settings,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    // Hebrew and Greek keep separate hues because the distinction is
    // information, not decoration — but the hue moved to the tag's
    // TEXT (see [WbTag]), and both are drawn from the original-language
    // family `kVersionTagColors` already uses for `wtt` / `bgt`.
    final tagFg = _originalScriptHue(wb, hebrew: isHebrew);
    return WbPanel(
      title: title,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zebra rather than a rule between every row. A 25-row
          // frequency table with 24 dividers is a grid; alternating
          // fill is what the Browse window already uses to let the eye
          // find a row boundary without adding ink.
          for (var i = 0; i < lemmas.length; i++)
            Container(
              color: i.isOdd ? wb.paneAltBg : null,
              padding: const EdgeInsets.symmetric(
                horizontal: WbMetrics.rowPadH,
                vertical: 3,
              ),
              child: Row(
                children: [
                  WbTag(text: lemmas[i].strongs, color: tagFg),
                  const SizedBox(width: 8),
                  // 2:5 because a lemma is three or four letters and a
                  // gloss is a phrase. Equal flex spent half the row on
                  // whitespace after `אֱלֹהִים` and ellipsised the gloss
                  // that was the reason to read the row.
                  Expanded(
                    flex: 2,
                    child: Text(
                      lemmas[i].lemma,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: t.original,
                        height: t.lineHeight,
                        fontWeight: FontWeight.w700,
                        color: wb.text,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Text(
                      lemmas[i].glossFor(locale),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: t.fontFamily,
                        fontSize: t.text,
                        height: t.lineHeight,
                        color: wb.mutedText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${lemmas[i].count}',
                    style: TextStyle(
                      fontSize: t.text,
                      height: t.lineHeight,
                      fontWeight: FontWeight.w700,
                      color: wb.text,
                      fontFeatures: const [FontFeature.tabularFigures()],
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

/// Round 56: Books tab — per-book originals stats.
class _OriginalsBooksTab extends StatefulWidget {
  final String locale;
  final AppSettings settings;
  const _OriginalsBooksTab({required this.locale, required this.settings});

  @override
  State<_OriginalsBooksTab> createState() => _OriginalsBooksTabState();
}

class _OriginalsBooksTabState extends State<_OriginalsBooksTab>
    with AutomaticKeepAliveClientMixin {
  Future<OriginalsAggregateStats>? _future;
  String _filter = 'all'; // all / ot / nt
  final ScrollController _scrollCtrl = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = OriginalsStatsService.aggregate();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final locale = widget.locale;
    final settings = widget.settings;
    return FutureBuilder<OriginalsAggregateStats>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final stats = snap.data;
        if (stats == null) {
          return Center(
            child: Text(
              uiStrings['statsOriginalsEmpty']?[locale] ??
                  'Original-language data not loaded.',
              style: TextStyle(color: WbColors.of(context).mutedText),
            ),
          );
        }
        var rows = stats.bookStats;
        if (_filter == 'ot') {
          rows = rows.where((b) => b.isOt).toList();
        } else if (_filter == 'nt') {
          rows = rows.where((b) => !b.isOt).toList();
        }
        // Round 56 (continued — wide-screen): center the list
        // and cap at 1200 px so it doesn't stretch edge-to-edge
        // on iPad / desktop.
        return Scrollbar(
          controller: _scrollCtrl,
          thumbVisibility: true,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: ListView.separated(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                itemCount: rows.length + 1,
                // No gap: 66 books with a 4px gutter between each was
                // 66 floating cards. Zebra fill (see _BookOriginalsRow)
                // is what makes a long list scannable — it is what the
                // Browse window does with verses.
                separatorBuilder: (_, __) => const SizedBox.shrink(),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
                      child: SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'all',
                            label: Text(uiStrings['statsOriginalsAll']
                                    ?[locale] ??
                                'All'),
                          ),
                          ButtonSegment(
                            value: 'ot',
                            label: Text(
                                uiStrings['oldTestamentShort']?[locale] ??
                                    'Hebrew'),
                          ),
                          ButtonSegment(
                            value: 'nt',
                            label: Text(
                                uiStrings['newTestamentShort']?[locale] ??
                                    'Greek'),
                          ),
                        ],
                        selected: {_filter},
                        onSelectionChanged: (s) =>
                            setState(() => _filter = s.first),
                        multiSelectionEnabled: false,
                        showSelectedIcon: false,
                      ),
                    );
                  }
                  final book = rows[i - 1];
                  return _BookOriginalsRow(
                    book: book,
                    alt: (i - 1).isOdd,
                    settings: settings,
                    locale: locale,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BookOriginalsRow extends StatelessWidget {
  final OriginalsBookStat book;

  /// Zebra: every other row carries [WbColors.paneAltBg].
  final bool alt;
  final AppSettings settings;
  final String locale;
  const _BookOriginalsRow({
    required this.book,
    required this.alt,
    required this.settings,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final localizedName = localeAwareBookName(book.englishBook, locale);
    final tagFg = _scriptHue(wb, book.isOt ? Colors.indigo : Colors.deepPurple);
    // 2026-08-09 (#280): 希伯来 / 希腊, never 旧约 / 新约. These were the
    // last two places in the UI still using the old wording.
    final tagLabel = book.isOt
        ? (uiStrings['oldTestamentShort']?[locale] ?? 'Hebrew')
        : (uiStrings['newTestamentShort']?[locale] ?? 'Greek');
    return Container(
      color: alt ? wb.paneAltBg : null,
      padding: const EdgeInsets.symmetric(
          horizontal: WbMetrics.rowPadH, vertical: 4),
      child: Row(
        children: [
          WbTag(text: tagLabel, color: tagFg),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizedName,
                  style: TextStyle(
                    fontFamily: settings.fontFamily,
                    fontFamilyFallback: kCjkFontFallback,
                    fontSize: t.text + 1,
                    height: t.lineHeight,
                    fontWeight: FontWeight.w600,
                    color: wb.text,
                  ),
                ),
                Text(
                  book.englishBook,
                  style: TextStyle(
                    fontSize: t.chrome,
                    height: t.lineHeight,
                    color: wb.mutedText,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_humanNum(book.totalWords)} ${uiStrings['statsOriginalsWordsShort']?[locale] ?? 'words'}',
                style: TextStyle(
                  fontSize: t.text,
                  height: t.lineHeight,
                  fontWeight: FontWeight.w700,
                  color: wb.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '${book.uniqueLemmas} ${uiStrings['statsOriginalsLemmasShort']?[locale] ?? 'lemmas'}',
                style: TextStyle(
                  fontSize: t.chrome,
                  height: t.lineHeight,
                  color: wb.mutedText,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Round 56 cleanup: trimmed to just the Passage Study launcher.
/// User feedback: '原文查询感觉下面的点任意... 下面的都没有用，
/// 上面的选择经文已经出来的popup窗口那个强多了'. The previous
/// Strong's-search list duplicated the picker the Distribution
/// tab already exposes. The Lookup tab is now a single card that
/// opens the in-reader OriginalsSheet (word-by-word breakdown,
/// tap-a-word entry, family + synonyms + concordance) for any
/// verse the user picks. All the rich exegesis affordances live
/// inside that sheet.
class _StrongsLookupTab extends StatefulWidget {
  final String locale;
  final AppSettings settings;
  const _StrongsLookupTab({required this.locale, required this.settings});

  @override
  State<_StrongsLookupTab> createState() => _StrongsLookupTabState();
}

class _StrongsLookupTabState extends State<_StrongsLookupTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final locale = widget.locale;
    final settings = widget.settings;
    // Round 56 (continued — Lookup tab redesign): the previous
    // single-card centered layout looked sparse on iPad / desktop
    // (one small card floating in a wide empty page). User feedback:
    // "感觉原文查询，middle aligned 感觉看起来不好看". Page is now a
    // top-aligned column of three sections: hero CTA, popular-
    // passages quick picks, exegesis features card. Still capped at
    // 900 px so a 4K monitor doesn't sprawl, but the column is now
    // dense enough that the centered layout feels intentional.
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PassageStudyCard(
                  locale: locale,
                  settings: settings,
                  onPickVerse: () => _openVersePicker(context),
                  onContinueReading: () => _continueReading(context),
                ),
                const SizedBox(height: 16),
                _PopularPassagesCard(
                  locale: locale,
                  settings: settings,
                  onTap: (book, chapter, verse) => _openOriginalsSheetFor(
                    context,
                    book: book,
                    chapter: chapter,
                    verse: verse,
                  ),
                ),
                const SizedBox(height: 16),
                _ExegesisFeaturesCard(
                  locale: locale,
                  settings: settings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Open the 3-step modal picker (book → chapter → verse). When
  /// the user lands on a verse, dismiss the picker and open the
  /// shared OriginalsSheet — same widget the reader pops when you
  /// tap a verse in the reading pane.
  Future<void> _openVersePicker(BuildContext context) async {
    final mp = context.read<MainProvider>();
    final picked = await showModalBottomSheet<_PickedRef>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => _VersePickerSheet(
        mp: mp,
        locale: widget.locale,
        settings: widget.settings,
      ),
    );
    if (picked != null && context.mounted) {
      _openOriginalsSheetFor(
        context,
        book: picked.book,
        chapter: picked.chapter,
        verse: picked.verse,
      );
    }
  }

  /// "继续阅读" action: open OriginalsSheet for the verse the user
  /// last read in the main reader. Falls back to chapter:1 verse:1
  /// when the reader hasn't been opened yet this session.
  Future<void> _continueReading(BuildContext context) async {
    final mp = context.read<MainProvider>();
    final book = mp.currentBook;
    final chapter = mp.currentChapter;
    if (book == null || chapter == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          uiStrings['statsLookupNoCurrentReading']?[widget.locale] ??
              'Open a passage in the reader first to continue here.',
        ),
      ));
      return;
    }
    final firstVerse = mp.currentVerse?.verse ?? 1;
    _openOriginalsSheetFor(
      context,
      book: book,
      chapter: chapter,
      verse: firstVerse,
    );
  }

  /// Filter MainProvider.verses down to a single (book, chapter,
  /// verse) and pop the OriginalsSheet. The sheet itself handles the
  /// "no original-language data" empty state, so the affordance
  /// always opens.
  void _openOriginalsSheetFor(
    BuildContext context, {
    required String book,
    required int chapter,
    required int verse,
  }) {
    final mp = context.read<MainProvider>();
    final matches = mp.verses
        .where(
            (v) => v.book == book && v.chapter == chapter && v.verse == verse)
        .toList();
    if (matches.isEmpty) {
      _resolveAndOpen(context, book: book, chapter: chapter, verse: verse);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 1100),
      builder: (sheetCtx) => OriginalsSheet(
        verses: matches,
        allVerses: mp.verses,
        locale: widget.locale,
        currentVersion: mp.currentVersion,
        onNavigateRef: (ref) {
          Navigator.of(sheetCtx).maybePop();
          _hopToConcordanceRef(context, ref);
        },
      ),
    );
  }

  /// Re-target the OriginalsSheet at the verse a concordance ref
  /// points to. Filters MainProvider.verses; if the verse isn't in
  /// the current version, falls through to _resolveAndOpen which
  /// handles cross-version fallback.
  void _hopToConcordanceRef(BuildContext context, ConcordanceRef ref) {
    final mp = context.read<MainProvider>();
    final localBook = mp.verses.isEmpty
        ? null
        : mp.verses
            .firstWhere(
              (v) => (toEnglish(v.book) ?? v.book) == ref.englishBook,
              orElse: () => mp.verses.first,
            )
            .book;
    final book = localBook ?? ref.englishBook;
    _openOriginalsSheetFor(
      context,
      book: book,
      chapter: ref.chapter,
      verse: ref.verse,
    );
  }

  Future<void> _resolveAndOpen(BuildContext context,
      {required String book, required int chapter, required int verse}) async {
    final mp = context.read<MainProvider>();
    final ref = BibleReference(
      englishBook: toEnglish(book) ?? book,
      chapter: chapter,
      verseStart: verse,
      verseEnd: verse,
    );
    final result = await resolveAndPrepareJump(reference: ref, mp: mp);
    if (!context.mounted || !result.ready) return;
    final v = mp.verses.firstWhere(
      (x) =>
          x.chapter == chapter &&
          x.verse == verse &&
          (x.book == book || toEnglish(x.book) == toEnglish(book)),
      orElse: () => mp.verses.isNotEmpty
          ? mp.verses.first
          : Verse(
              book: book,
              chapter: chapter,
              verse: verse,
              verseLabel: '$verse',
              text: '',
            ),
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 1100),
      builder: (sheetCtx) => OriginalsSheet(
        verses: [v],
        allVerses: mp.verses,
        locale: widget.locale,
        currentVersion: mp.currentVersion,
        onNavigateRef: (ref) {
          Navigator.of(sheetCtx).maybePop();
          _hopToConcordanceRef(context, ref);
        },
      ),
    );
  }
}

/// Round 56 (continued — exegesis-table tab): wraps the
/// `WordDistributionTable` widget so users can reach it from a
/// dedicated Bible Tools tab instead of having to tap a verse →
/// originals sheet → tap a word → "show distribution".
///
/// The widget itself renders only lexical metadata (Strong's
/// number, lemma, gloss, per-book occurrence counts for the word
/// + its family + synonyms). No verse text or extended
/// commentary is shown by this tab — that's `OriginalsSheet`'s
/// job.
class _WordDistributionTab extends StatefulWidget {
  final String locale;
  final AppSettings settings;
  const _WordDistributionTab({required this.locale, required this.settings});

  @override
  State<_WordDistributionTab> createState() => _WordDistributionTabState();
}

class _WordDistributionTabState extends State<_WordDistributionTab>
    with AutomaticKeepAliveClientMixin {
  // Default to H3068 — יהוה, the Tetragrammaton — so the table
  // arrives populated with an interesting OT distribution rather
  // than an empty state.
  String _strongs = 'H3068';
  Future<List<OriginalsLemma>>? _lemmasFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _lemmasFuture = OriginalsStatsService.load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final locale = widget.locale;
    final settings = widget.settings;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          children: [
            // Sticky picker header — current focus word + change
            // button. Fits on one line; doesn't scroll with the
            // table body.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    uiStrings['statsDistributionHint']?[locale] ??
                        'Pick a Strong\'s word to see its distribution across books, plus word-family + synonym comparison.',
                    style: TextStyle(
                      fontSize: (settings.fontSize - 3).clamp(11.0, 14.0),
                      color: WbColors.of(context).mutedText,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _CurrentWordBar(
                    strongs: _strongs,
                    locale: locale,
                    settings: settings,
                    onChange: () => _openPicker(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: WordDistributionTable(
                // Re-key on every selection so the widget runs
                // its initState (which fires _loadAll) — without
                // this, switching words would leave the previous
                // rows visible until the user manually scrolled.
                key: ValueKey(_strongs),
                strongsNumber: _strongs,
                locale: locale,
                currentVersion: null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final all = await _lemmasFuture;
    if (!context.mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return _StrongsPickerSheet(
          allLemmas: all ?? const [],
          locale: widget.locale,
          settings: widget.settings,
          initialQuery: '',
          onPick: (strongs) => Navigator.of(sheetCtx).pop(strongs),
        );
      },
    );
    if (picked != null && picked.isNotEmpty) {
      setState(() => _strongs = picked);
    }
  }
}

/// Compact header showing which Strong's word the distribution
/// table is currently focused on, plus a "Change word" button
/// that opens the picker sheet.
class _CurrentWordBar extends StatefulWidget {
  final String strongs;
  final String locale;
  final AppSettings settings;
  final VoidCallback onChange;
  const _CurrentWordBar({
    required this.strongs,
    required this.locale,
    required this.settings,
    required this.onChange,
  });

  @override
  State<_CurrentWordBar> createState() => _CurrentWordBarState();
}

class _CurrentWordBarState extends State<_CurrentWordBar> {
  Future<OriginalsLemma?>? _future;

  @override
  void initState() {
    super.initState();
    _future = _lookup(widget.strongs);
  }

  @override
  void didUpdateWidget(covariant _CurrentWordBar old) {
    super.didUpdateWidget(old);
    if (old.strongs != widget.strongs) {
      _future = _lookup(widget.strongs);
    }
  }

  Future<OriginalsLemma?> _lookup(String s) async {
    final all = await OriginalsStatsService.load();
    for (final l in all) {
      if (l.strongs == s) return l;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final isHebrew = widget.strongs.startsWith('H');
    final tagFg = _originalScriptHue(wb, hebrew: isHebrew);
    return Container(
      decoration: BoxDecoration(
        color: wb.paneAltBg,
        border: Border.all(color: wb.border, width: WbMetrics.hairline),
      ),
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      child: Row(
        children: [
          WbTag(text: widget.strongs, color: tagFg, dense: false),
          const SizedBox(width: 10),
          Expanded(
            child: FutureBuilder<OriginalsLemma?>(
              future: _future,
              builder: (ctx, snap) {
                final lemma = snap.data;
                if (lemma == null) {
                  return Text(
                    widget.strongs,
                    style: TextStyle(
                      fontSize: t.original,
                      height: t.lineHeight,
                      fontWeight: FontWeight.w700,
                      color: wb.text,
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            lemma.lemma,
                            style: TextStyle(
                              fontFamily: widget.settings.fontFamily,
                              fontSize: t.original + 2,
                              height: t.lineHeight,
                              fontWeight: FontWeight.w700,
                              color: wb.text,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (lemma.translit.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              lemma.translit,
                              style: TextStyle(
                                fontSize: t.text,
                                height: t.lineHeight,
                                fontStyle: FontStyle.italic,
                                color: wb.mutedText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      lemma.glossFor(widget.locale),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: widget.settings.fontFamily,
                        fontSize: t.text,
                        height: t.lineHeight,
                        color: wb.mutedText,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: widget.onChange,
            icon: Icon(Icons.swap_horiz, size: t.text + 5),
            label: Text(
              uiStrings['statsDistributionPicker']?[widget.locale] ??
                  'Change word',
              style: TextStyle(fontSize: t.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal-sheet picker that lets the user choose a Strong's word
/// for the distribution table. Same fuzzy-search vocabulary as
/// the Lookup tab; selection returns a Strong's number string
/// via Navigator.pop.
class _StrongsPickerSheet extends StatefulWidget {
  final List<OriginalsLemma> allLemmas;
  final String locale;
  final AppSettings settings;
  final String initialQuery;
  final ValueChanged<String> onPick;

  const _StrongsPickerSheet({
    required this.allLemmas,
    required this.locale,
    required this.settings,
    required this.initialQuery,
    required this.onPick,
  });

  @override
  State<_StrongsPickerSheet> createState() => _StrongsPickerSheetState();
}

class _StrongsPickerSheetState extends State<_StrongsPickerSheet> {
  late String _query;
  String _filter = 'all';
  bool _hideStopwords = true;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
  }

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final locale = widget.locale;
    final allLabel = uiStrings['statsOriginalsAll']?[locale] ?? 'All';
    Iterable<OriginalsLemma> filtered = widget.allLemmas;
    if (_filter == 'hebrew') {
      filtered = filtered.where((e) => e.isHebrew);
    } else if (_filter == 'greek') {
      filtered = filtered.where((e) => !e.isHebrew);
    }
    if (_hideStopwords) {
      filtered = filtered.where((e) => !e.isStopword);
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      filtered = filtered.where((e) =>
          e.strongs.toLowerCase().contains(q) ||
          e.lemma.contains(_query.trim()) ||
          e.translit.toLowerCase().contains(q) ||
          e.glossEn.toLowerCase().contains(q) ||
          e.glossZhHans.contains(_query.trim()) ||
          e.glossZhHant.contains(_query.trim()));
    }
    final rows = filtered.toList();
    // Cap at 60 visible rows so the sheet doesn't laggy-scroll
    // through 14k entries; the search box is the primary tool.
    final showRows =
        (q.isEmpty && rows.length > 60) ? rows.take(60).toList() : rows;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.swap_horiz, size: t.text + 5, color: wb.mutedText),
                  const SizedBox(width: 8),
                  Text(
                    uiStrings['statsDistributionPicker']?[locale] ??
                        'Change word',
                    style: TextStyle(
                      fontSize: t.text + 2,
                      height: t.lineHeight,
                      fontWeight: FontWeight.w700,
                      color: wb.text,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, size: t.text + 6),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: uiStrings['statsLookupHint']?[locale] ??
                      'Search by Strong\'s, lemma, transliteration, or gloss',
                  isDense: true,
                  prefixIcon: Icon(Icons.search, size: t.text + 6),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: [
                        ButtonSegment(value: 'all', label: Text(allLabel)),
                        ButtonSegment(
                          value: 'hebrew',
                          label: Text(uiStrings['statsOriginalsHebrew']
                                  ?[locale] ??
                              'Hebrew'),
                        ),
                        ButtonSegment(
                          value: 'greek',
                          label: Text(uiStrings['statsOriginalsGreek']
                                  ?[locale] ??
                              'Greek'),
                        ),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (s) =>
                          setState(() => _filter = s.first),
                      multiSelectionEnabled: false,
                      showSelectedIcon: false,
                    ),
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    avatar: Icon(
                      _hideStopwords ? Icons.filter_alt : Icons.filter_alt_off,
                      size: 16,
                    ),
                    label: Text(
                      uiStrings['statsOriginalsHideStopwordsTitle']?[locale] ??
                          'Hide common particles',
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: _hideStopwords,
                    onSelected: (v) => setState(() => _hideStopwords = v),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: showRows.isEmpty
                    ? Center(
                        child: Text(
                          uiStrings['statsLookupEmpty']?[locale] ??
                              'No matching entries.',
                          style:
                              TextStyle(fontSize: t.text, color: wb.mutedText),
                        ),
                      )
                    : ListView.builder(
                        itemCount: showRows.length,
                        itemBuilder: (_, i) {
                          final e = showRows[i];
                          final tagFg =
                              _originalScriptHue(wb, hebrew: e.isHebrew);
                          return Material(
                            color: i.isOdd ? wb.paneAltBg : wb.paneBg,
                            child: InkWell(
                              onTap: () => widget.onPick(e.strongs),
                              hoverColor: wb.hoverBg,
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: WbMetrics.rowPadH, vertical: 4),
                                child: Row(
                                  children: [
                                    WbTag(text: e.strongs, color: tagFg),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${e.lemma}  ·  ${e.glossFor(locale)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily:
                                              widget.settings.fontFamily,
                                          fontSize: t.text + 1,
                                          height: t.lineHeight,
                                          color: wb.text,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${e.count}',
                                      style: TextStyle(
                                        fontSize: t.text,
                                        height: t.lineHeight,
                                        fontWeight: FontWeight.w700,
                                        color: wb.mutedText,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures()
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round 56 (continued — exegesis parity): card at the top of the
/// Lookup tab inviting the user to start an exegesis study from
/// a passage rather than from a Strong's number. Mirrors the
/// in-reader experience (tap-a-verse → originals sheet) but
/// reachable directly from Bible Tools without first opening the
/// reader.
class _PassageStudyCard extends StatelessWidget {
  final String locale;
  final AppSettings settings;
  final VoidCallback onPickVerse;
  final VoidCallback onContinueReading;

  const _PassageStudyCard({
    required this.locale,
    required this.settings,
    required this.onPickVerse,
    required this.onContinueReading,
  });

  @override
  Widget build(BuildContext context) {
    final title =
        uiStrings['statsLookupPassageTitle']?[locale] ?? 'Study a passage';
    final desc = uiStrings['statsLookupPassageDesc']?[locale] ??
        'Pick any verse to see its word-by-word original-language breakdown — same view the reader pops when you tap a verse.';
    final pickLabel =
        uiStrings['statsLookupPickVerse']?[locale] ?? 'Pick a verse';
    final continueLabel = uiStrings['statsLookupContinueReading']?[locale] ??
        'Continue from reader';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      // `alt` rather than the old `primaryContainer` wash: this card is
      // the tab's primary action, and in a neutral window that is a
      // step in value, not a tint of the seed colour.
      child: WbPanel(
        icon: Icons.menu_book_rounded,
        title: title,
        subtitle: desc,
        alt: true,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: onPickVerse,
              icon: const Icon(Icons.bookmark_outline, size: 18),
              label: Text(pickLabel),
            ),
            OutlinedButton.icon(
              onPressed: onContinueReading,
              icon: const Icon(Icons.history_edu_rounded, size: 18),
              label: Text(continueLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round 56 (continued — Lookup redesign): the recommended-
/// passages card now sources its entries from
/// [DailyVerseService.recentRefs] instead of a hardcoded eight-
/// passage list. User feedback: 'for recommended verse, in bible
/// study, can you also include daily verse? also yesterday and
/// the day before etc... to replace all current ones'.
///
/// Each chip shows a localised relative-date label (Today /
/// Yesterday / 2 days ago / …) above the canonical reference.
/// Tapping parses the reference via parseReference, resolves the
/// book to the current Bible version's localized name, and pops
/// the same OriginalsSheet the rest of the tab uses.
class _PopularPassagesCard extends StatefulWidget {
  final String locale;
  final AppSettings settings;

  /// (book, chapter, verse) → caller resolves through
  /// MainProvider.verses + opens the sheet.
  final void Function(String book, int chapter, int verse) onTap;

  const _PopularPassagesCard({
    required this.locale,
    required this.settings,
    required this.onTap,
  });

  @override
  State<_PopularPassagesCard> createState() => _PopularPassagesCardState();
}

class _PopularPassagesCardState extends State<_PopularPassagesCard> {
  Future<List<DailyVerseEntry>>? _future;

  @override
  void initState() {
    super.initState();
    _future = DailyVerseService.recentRefs(8);
  }

  @override
  Widget build(BuildContext context) {
    final mp = context.read<MainProvider>();
    final locale = widget.locale;
    final settings = widget.settings;
    final title =
        uiStrings['lookupPopularTitle']?[locale] ?? 'Recent daily verses';
    final desc = uiStrings['lookupPopularDesc']?[locale] ??
        'Each entry is one of the past few days of daily verse — tap to study it.';
    return WbPanel(
      icon: Icons.auto_awesome_rounded,
      title: title,
      subtitle: desc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<List<DailyVerseEntry>>(
            future: _future,
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                );
              }
              final entries = snap.data ?? const [];
              if (entries.isEmpty) {
                return Text(
                  uiStrings['lookupPopularEmpty']?[locale] ??
                      'No daily verses available yet.',
                  style: TextStyle(
                    fontSize: 12,
                    color: WbColors.of(context).mutedText,
                  ),
                );
              }
              return LayoutBuilder(builder: (ctx, c) {
                final cols = c.maxWidth >= 600 ? 4 : 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in entries)
                      SizedBox(
                        width: (c.maxWidth - (cols - 1) * 8) / cols,
                        child: _DailyVerseChip(
                          entry: e,
                          locale: locale,
                          settings: settings,
                          onTap: () => _onTap(mp, e.ref),
                        ),
                      ),
                  ],
                );
              });
            },
          ),
        ],
      ),
    );
  }

  /// Parse the daily-verse reference (e.g. 'John 3:16',
  /// 'Psalms 23:1-6', 'Genesis 1') and forward to the parent's
  /// onTap with the localised book name + the start verse. Falls
  /// back gracefully if the reference doesn't parse.
  void _onTap(MainProvider mp, String ref) {
    final parsed = parseReference(ref);
    if (parsed == null) return;
    final localBook = mp.verses.isEmpty
        ? parsed.englishBook
        : mp.verses
            .firstWhere(
              (v) => (toEnglish(v.book) ?? v.book) == parsed.englishBook,
              orElse: () => mp.verses.first,
            )
            .book;
    widget.onTap(
      localBook,
      parsed.chapter,
      parsed.verseStart ?? 1,
    );
  }
}

/// Single chip in the daily-verse history grid. Top line: relative
/// date label (Today / Yesterday / N days ago, localised). Bottom
/// line: canonical reference re-localised via
/// [localeAwareBookName] so 'John 3:16' shows as '约翰福音 3:16'
/// in zh-Hans, '約翰福音 3:16' in zh-Hant.
class _DailyVerseChip extends StatelessWidget {
  final DailyVerseEntry entry;
  final String locale;
  final AppSettings settings;
  final VoidCallback onTap;
  const _DailyVerseChip({
    required this.entry,
    required this.locale,
    required this.settings,
    required this.onTap,
  });

  /// Reference re-formatted into the user's locale book naming +
  /// the localized topical theme for the chapter. Preserves verse
  /// range when present (e.g. 'Psalms 23:1-6').
  ({String ref, String theme}) _displayParts() {
    final parsed = parseReference(entry.ref);
    if (parsed == null) {
      return (
        ref: entry.ref,
        theme: uiStrings['verseThemeGeneral']?[locale] ?? '',
      );
    }
    final book = localeAwareBookName(parsed.englishBook, locale);
    final tail = parsed.verseStart == null
        ? '${parsed.chapter}'
        : (parsed.verseEnd != null && parsed.verseEnd! > parsed.verseStart!
            ? '${parsed.chapter}:${parsed.verseStart}-${parsed.verseEnd}'
            : '${parsed.chapter}:${parsed.verseStart}');
    final themeKey = themeKeyFor(parsed.englishBook, parsed.chapter);
    final theme = uiStrings[themeKey]?[locale] ??
        uiStrings['verseThemeGeneral']?[locale] ??
        '';
    return (ref: '$book $tail', theme: theme);
  }

  @override
  Widget build(BuildContext context) {
    // Round 56 (continued — themes): user feedback "no need to
    // mention today yesterday etc. but show the theme of the verse
    // somehow". Top line is now a topical label resolved through
    // themeKeyFor() in daily_verse_service.dart instead of the
    // relative-date label that used to live there.
    final parts = _displayParts();
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    return WbTile(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            parts.theme,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: settings.fontFamily,
              fontFamilyFallback: kCjkFontFallback,
              fontSize: t.chrome,
              height: t.lineHeight,
              color: wb.mutedText,
            ),
          ),
          Text(
            parts.ref,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: settings.fontFamily,
              fontFamilyFallback: kCjkFontFallback,
              fontSize: t.text,
              height: t.lineHeight,
              fontWeight: FontWeight.w700,
              // The reference is the clickable thing in this tile, and
              // `wb.link` is the same blue the workbench prints every
              // other jump-to-verse reference in.
              color: wb.link,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Static educational card explaining what the user can do once
/// the OriginalsSheet pops. Adds visual weight to the otherwise
/// sparse Lookup tab and answers the implicit "what is this for"
/// question for first-time visitors.
class _ExegesisFeaturesCard extends StatelessWidget {
  final String locale;
  final AppSettings settings;
  const _ExegesisFeaturesCard({
    required this.locale,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final title = uiStrings['lookupFeaturesTitle']?[locale] ??
        'Inside the exegesis sheet';
    final features = <(IconData, String)>[
      (
        Icons.translate_rounded,
        uiStrings['lookupFeatureWords']?[locale] ??
            'Word-by-word original-language breakdown with transliteration and gloss.'
      ),
      (
        Icons.touch_app_rounded,
        uiStrings['lookupFeatureTap']?[locale] ??
            'Tap any word for the full Strong\'s entry — meaning, derivation, occurrence count.'
      ),
      (
        Icons.diversity_3_rounded,
        uiStrings['lookupFeatureFamily']?[locale] ??
            'Word family + synonym comparison — see related lemmas at a glance.'
      ),
      (
        Icons.format_list_numbered_rounded,
        uiStrings['lookupFeatureConcordance']?[locale] ??
            'Tappable concordance — every verse the word appears in, one tap to navigate.'
      ),
      (
        Icons.copy_rounded,
        uiStrings['lookupFeatureCopy']?[locale] ??
            'Copy the interlinear table to clipboard for sermon prep or notes.'
      ),
    ];
    return WbPanel(
      icon: Icons.lightbulb_outline,
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < features.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(features[i].$1, size: 16, color: wb.mutedText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    features[i].$2,
                    style: TextStyle(
                      fontFamily: settings.fontFamily,
                      fontFamilyFallback: kCjkFontFallback,
                      fontSize: 12,
                      height: 1.45,
                      color: wb.text,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Result of the verse-picker modal — the three coordinates needed
/// to filter MainProvider.verses to a single row before opening
/// OriginalsSheet.
class _PickedRef {
  final String book;
  final int chapter;
  final int verse;
  const _PickedRef(this.book, this.chapter, this.verse);
}

/// Three-step verse picker: book chips → chapter chips → verse
/// chips. Returns the picked (book, chapter, verse) triple via
/// Navigator.pop. Designed to be lightweight — uses
/// MainProvider.books for the structure rather than re-loading.
/// Falls back to the verse list when MainProvider.books is empty
/// (e.g. user opened Bible Tools before the reader loaded).
class _VersePickerSheet extends StatefulWidget {
  final MainProvider mp;
  final String locale;
  final AppSettings settings;
  const _VersePickerSheet({
    required this.mp,
    required this.locale,
    required this.settings,
  });

  @override
  State<_VersePickerSheet> createState() => _VersePickerSheetState();
}

class _VersePickerSheetState extends State<_VersePickerSheet> {
  String? _book; // English book name
  int? _chapter;

  /// Books the loaded version actually has. Built from the verse
  /// list so we never offer a book that has no data.
  late final List<String> _availableEnglishBooks = _computeBooks();

  List<String> _computeBooks() {
    final set = <String>{};
    for (final v in widget.mp.verses) {
      final en = toEnglish(v.book) ?? v.book;
      set.add(en);
    }
    final ordered = standardBookOrder.where((b) => set.contains(b)).toList();
    return ordered;
  }

  /// Chapters available in the selected book.
  List<int> _chaptersFor(String englishBook) {
    final set = <int>{};
    for (final v in widget.mp.verses) {
      final en = toEnglish(v.book) ?? v.book;
      if (en == englishBook) set.add(v.chapter);
    }
    final list = set.toList()..sort();
    return list;
  }

  /// Verses available in the selected book + chapter.
  List<int> _versesFor(String englishBook, int chapter) {
    final set = <int>{};
    for (final v in widget.mp.verses) {
      final en = toEnglish(v.book) ?? v.book;
      if (en == englishBook && v.chapter == chapter) {
        set.add(v.verse);
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  /// Localized version of `englishBook` to display in chips,
  /// matching the rest of the app's naming convention.
  String _displayBook(String englishBook) =>
      localeAwareBookName(englishBook, widget.locale);

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PickerHeader(
                step: _book == null
                    ? 1
                    : _chapter == null
                        ? 2
                        : 3,
                locale: locale,
                onBack: _book == null
                    ? null
                    : () => setState(() {
                          if (_chapter != null) {
                            _chapter = null;
                          } else {
                            _book = null;
                          }
                        }),
              ),
              const SizedBox(height: 10),
              if (_book == null)
                Expanded(
                  child: _BookGrid(
                    books: _availableEnglishBooks,
                    locale: locale,
                    onPick: (b) => setState(() => _book = b),
                  ),
                )
              else if (_chapter == null)
                Expanded(
                  child: _NumberGrid(
                    label: _displayBook(_book!),
                    numbers: _chaptersFor(_book!),
                    onPick: (c) => setState(() => _chapter = c),
                  ),
                )
              else
                Expanded(
                  child: _NumberGrid(
                    label: '${_displayBook(_book!)} ${_chapter!}',
                    numbers: _versesFor(_book!, _chapter!),
                    onPick: (v) => Navigator.of(context)
                        .pop(_PickedRef(_book!, _chapter!, v)),
                  ),
                ),
              const SizedBox(height: 4),
              if (_availableEnglishBooks.isEmpty)
                Text(
                  uiStrings['statsLookupNoCurrentReading']?[locale] ??
                      'Open a passage in the reader first to continue here.',
                  style: TextStyle(
                    fontSize: 12,
                    color: WbColors.of(context).mutedText,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerHeader extends StatelessWidget {
  final int step; // 1 = book, 2 = chapter, 3 = verse
  final String locale;
  final VoidCallback? onBack;
  const _PickerHeader({
    required this.step,
    required this.locale,
    required this.onBack,
  });
  @override
  Widget build(BuildContext context) {
    final stepText = step == 1
        ? (uiStrings['statsLookupStepBook']?[locale] ?? 'Pick a book')
        : step == 2
            ? (uiStrings['statsLookupStepChapter']?[locale] ?? 'Pick a chapter')
            : (uiStrings['statsLookupStepVerse']?[locale] ?? 'Pick a verse');
    return Row(
      children: [
        if (onBack != null)
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: onBack,
          ),
        Icon(Icons.bookmark_outline,
            size: 18, color: WbColors.of(context).mutedText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            stepText,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          '$step / 3',
          style: TextStyle(
            fontSize: 12,
            color: WbColors.of(context).mutedText,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.close, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

class _BookGrid extends StatelessWidget {
  final List<String> books;
  final String locale;
  final ValueChanged<String> onPick;
  const _BookGrid({
    required this.books,
    required this.locale,
    required this.onPick,
  });
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final b in books)
            ChoiceChip(
              label: Text(localeAwareBookName(b, locale)),
              selected: false,
              onSelected: (_) => onPick(b),
            ),
        ],
      ),
    );
  }
}

class _NumberGrid extends StatelessWidget {
  final String label;
  final List<int> numbers;
  final ValueChanged<int> onPick;
  const _NumberGrid({
    required this.label,
    required this.numbers,
    required this.onPick,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: WbColors.of(context).mutedText,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final n in numbers)
                  SizedBox(
                    // Round 56 (continued): widened 44 → 56 because
                    // two-digit verses (10, 11, 100, 119:176) were
                    // getting ellipsised to "1.." in the picker.
                    // FittedBox.scaleDown is a safety net for the
                    // longest book Psalms 119 (verse 176).
                    width: 56,
                    child: ChoiceChip(
                      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                      label: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('$n'),
                        ),
                      ),
                      selected: false,
                      onSelected: (_) => onPick(n),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
