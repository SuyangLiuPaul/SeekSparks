/// 2026-08 (SeekSparks): the Analysis window's tab strip and the two
/// panes that are not the word study.
///
/// BibleWorks' Analysis window is tabbed — one verse, several ways of
/// looking at it, without losing your place in the text. SeekSparks had
/// only the word study docked on the right, so the cross-reference and
/// frequency data the app already ships were reachable only by leaving
/// the workspace.
///
/// The word-study tab stays in `OriginalsSheet`; this file adds:
///   * **Cross-Refs** — TSK + OpenBible references for the focused
///     verse, each with its text, tappable to navigate.
///   * **Stats** — how often the focused verse's original-language
///     words occur in the whole Bible, from the bundled concordance.
library;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/original_word.dart';
import 'package:seeksparks/models/reader_analysis_request.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/services/concordance_service.dart';
import 'package:seeksparks/services/greek_stats_service.dart';
import 'package:seeksparks/services/modern_concordance_service.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/scripture_markup.dart';
import 'package:seeksparks/services/cross_reference_service.dart';
import 'package:seeksparks/services/strongs_service.dart';
import 'package:seeksparks/utils/reference_parser.dart' show BibleReference;
import 'package:seeksparks/constants/book_groups.dart' show oldTestamentBooks;
import 'package:seeksparks/utils/search_scope.dart'
    show kScopeAllBooks, scopedCountLabel;
import 'package:seeksparks/utils/search_stats.dart';
import 'package:seeksparks/utils/verse_list.dart' show applySearchLimit;
import 'package:seeksparks/utils/version_mapper.dart' show localeAwareBookName;
import 'package:seeksparks/widgets/word_distribution_strip.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/widgets/wb_pane_bits.dart';
import 'package:seeksparks/widgets/wb_surfaces.dart';

/// Which pane the Analysis window is showing.
/// 2026-08-06: `kwic` joins them — BibleWorks' Key Word In Context
/// (help topic bwh31), then `related` — the Related Verses Tool
/// (bwh50), then `verseLists` — the Verse List Manager (bwh27), then
/// `phrases` — the Phrase Matching Tool (bwh51), then `vocabulary` —
/// the Vocabulary Flashcard Module (bwh40).
/// Appended rather than inserted because the tab is persisted by
/// INDEX (`workbench.analysisTab`), so reordering would silently move
/// every existing reader to a different tab.
enum AnalysisTab {
  wordStudy,
  crossRefs,
  stats,
  kwic,
  related,
  verseLists,
  phrases,
  vocabulary,

  /// Appended, not inserted: the selected tab is persisted by INDEX
  /// under `workbench.analysisTab`, so reordering this enum would move
  /// every reader who had a tab open to a different one.
  morphology,

  /// 2026-08-07: Eagle's View's Modern Concordance, keyed to the focused
  /// verse. Appended for the same reason as `morphology`.
  topics,

  /// 2026-08-07: BibleWorks' Context tab (bwh10h) — the vocabulary of
  /// the pericope, chapter and book around the focused verse. Appended
  /// for the same reason as `morphology`.
  context,

  /// 2026-08-08: the gazetteer, read verse-first. Appended for the same
  /// reason as `morphology`.
  places,

  /// 2026-08-17 (#313): the sermon corpus, read verse-first —
  /// BibleWorks' Resource Summary answers "where is this verse cited"
  /// from a docked tab (bwh10/bwh14), and this was the last reader
  /// action still answering it over the top of the verse. Appended for
  /// the same reason as `morphology`.
  sermons,
}

/// 2026-08-11 (#313): the docked tab that answers [request], or null
/// when nothing docked answers it and a sheet is the honest surface.
///
/// This is the whole of the reader-to-pane contract, kept pure so it can
/// be read in one screen and tested without a widget: the reader hands
/// over a subject, the workbench looks it up here, and a null means the
/// reader keeps the presentation it already had.
///
/// [ReaderAnalysisRequest.sermons] became a tab on 2026-08-17: the body
/// moved out of `bible_reading_pane.dart` into `SermonsPane`, and the
/// thirteenth tab was re-measured against #297's strip arithmetic
/// (`Sermons` / 講道 are both narrower than the widest label the strip
/// already carries, so the labelled width does not move).
///
/// [ReaderAnalysisRequest.aiExplain] returns null as a decision, not a
/// deferral: see the enum. It is now the only one, so a null here means
/// "deliberately a sheet" rather than "not got to yet".
AnalysisTab? analysisTabForRequest(ReaderAnalysisRequest request) =>
    switch (request) {
      ReaderAnalysisRequest.originals => AnalysisTab.wordStudy,
      ReaderAnalysisRequest.crossRefs => AnalysisTab.crossRefs,
      ReaderAnalysisRequest.sermons => AnalysisTab.sermons,
      ReaderAnalysisRequest.aiExplain => null,
    };

/// The inverse: which reader-side action the pane is currently
/// answering, so the button that sent it there can show as active.
///
/// Without this the tap is acknowledged only at the far edge of a
/// 1400 px screen, in the reader's peripheral vision — the #294 lesson
/// that a live control with no local feedback reads as a dead one.
/// Tabs no reader action can reach return null, which is most of them.
ReaderAnalysisRequest? requestForAnalysisTab(AnalysisTab tab) =>
    switch (tab) {
      AnalysisTab.wordStudy => ReaderAnalysisRequest.originals,
      AnalysisTab.crossRefs => ReaderAnalysisRequest.crossRefs,
      AnalysisTab.sermons => ReaderAnalysisRequest.sermons,
      _ => null,
    };

/// The narrowest a tab can be drawn without clipping: a 17 px icon, the
/// button's 4 px padding either side, and the 2 px gap to its neighbour.
const double _kMinTabWidth = 30;

/// Everything a labelled tab spends that is not the label itself: the
/// 15 px icon, the 5 px gap to the text, the button's 4 px padding
/// either side and the 2 px margin either side. Add the widest label's
/// measured width to this and you have the narrowest tab that can carry
/// it without cutting a word in half.
const double _kLabelChrome = 32;

/// Fallback for callers that cannot measure (the pure function's unit
/// tests, mostly). A Latin guess — six characters of 11.5 px text plus
/// [_kLabelChrome] — and the reason this file shipped a CJK defect:
/// 原文研读 is four FULL-WIDTH glyphs, ~46 px of text before any chrome,
/// so 66 said "the labels fit" and Flutter then ellipsised them to
/// 原文…. English never showed it; Chinese always did. Real callers pass
/// [analysisStripMinLabelledWidth] instead of trusting this.
const double _kMinLabelledTabWidth = 66;

/// How many rows the strip will spend to keep the labels on its own
/// initiative. Past two it starts consuming the pane it is labelling.
const int _kMaxLabelledRows = 2;

/// How many tabs go on a row, and whether they keep their labels.
///
/// A bare icon needs 30 px; a labelled tab needs [minLabelledTabWidth],
/// which is a MEASUREMENT of the current locale's widest label, not a
/// constant — see [analysisStripMinLabelledWidth]. The strip WRAPS, so
/// what each tab actually gets is `width / perRow` — not `width / count`.
/// Measuring against the total was why the labels vanished for good
/// somewhere around the ninth tab: at 420 px and 12 tabs that reads 35 px
/// and gives up, while the same strip in two rows of six has 70 px a tab
/// and could have carried every label.
///
/// So rows are chosen for legibility first: the fewest rows that let the
/// labels fit. Two rows of named tabs beat one row of twelve unexplained
/// icons, and past two the strip starts eating the pane it labels —
/// hence the two-row ceiling when the strip is deciding for itself.
/// Failing that it falls back to icons in BALANCED rows (6+6 rather than
/// 11+1) so every tab keeps the same width.
///
/// [preferLabels] is the reader having asked for names (task #297). Then
/// the ceiling comes off and the strip spends as many rows as the labels
/// need, down to one tab a row. That is deliberate: an ellipsised label
/// "identifies nothing the icon did not already", and a toggle that
/// silently declines to do the one thing it advertises is worse than a
/// tall strip the reader can turn off again. At any pane width this app
/// can actually reach (256 px and up) one tab a row is far wider than
/// any label, so the icon fallback below is unreachable when
/// [preferLabels] is set — the request is always honoured.
({int perRow, bool showLabels}) analysisStripLayout(
  double width,
  int count, {
  double minLabelledTabWidth = _kMinLabelledTabWidth,
  double minTabWidth = _kMinTabWidth,
  bool preferLabels = false,
}) {
  if (count <= 0) return (perRow: 1, showLabels: false);
  if (!width.isFinite || width <= 0) {
    return (perRow: count, showLabels: false);
  }
  final maxRows = preferLabels ? count : _kMaxLabelledRows;
  for (var rows = 1; rows <= maxRows; rows++) {
    final n = (count / rows).ceil();
    if (width / n >= minLabelledTabWidth) {
      return (perRow: n, showLabels: true);
    }
  }
  final fit = (width / minTabWidth).floor().clamp(1, count);
  return (perRow: (count / (count / fit).ceil()).ceil(), showLabels: false);
}

/// The narrowest tab that can carry the widest of [labels] whole.
///
/// Laid out with the SELECTED tab's weight (w700), which is the widest
/// the label ever draws — measuring the unselected w500 would let the
/// selected tab, the one the reader is looking at, be the only one that
/// ellipsises.
double analysisStripMinLabelledWidth(
  Iterable<String> labels, {
  TextScaler textScaler = TextScaler.noScaling,
  double fontSize = _kLabelFontSize,
  double chrome = _kLabelChrome,
}) {
  var widest = 0.0;
  for (final label in labels) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          fontFamilyFallback: kCjkFontFallback,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    if (painter.width > widest) widest = painter.width;
    painter.dispose();
  }
  return widest + chrome;
}

/// The label's type size AT THE DEFAULT Menu Size, shared by the
/// measurement and the widget so the two cannot drift.
///
/// It is the default rather than the size, because the strip is chrome
/// and the Menu Size slider moves it — `t.scaledChrome(_kLabelFontSize)`.
/// The literal stayed a literal through #311's arithmetic fix, so the
/// most-seen 30 px of the app was the one thing the slider could not
/// touch (#315). Everything the label sits in — icon, gap, padding,
/// margin, i.e. [_kLabelChrome] — has to move by the SAME factor, or
/// the measurement and the drawing disagree and #297's ellipsis is back.
const double _kLabelFontSize = 11.5;

/// Measurements are cached because the strip rebuilds on every hover
/// that changes the analysed word, and the answer only moves when the
/// locale or the reader's text scale does.
final Map<String, double> _minLabelledCache = {};

// Separators are written as escapes, never as literal control bytes: a
// raw NUL in the source makes grep and ripgrep classify the whole file
// as binary and skip it, so every later search of this file returns
// nothing and reads like a clean result.
double _cachedMinLabelledWidth(
  List<String> labels,
  TextScaler textScaler,
  double fontSize,
  double chrome,
) {
  final key = '$chrome:${textScaler.scale(fontSize)}\u0000${labels.join('\u0001')}';
  return _minLabelledCache[key] ??= analysisStripMinLabelledWidth(
    labels,
    textScaler: textScaler,
    fontSize: fontSize,
    chrome: chrome,
  );
}

/// The tabs, in strip order: which pane, its glyph, its `uiStrings`
/// key, and the English fallback for a locale that key does not cover.
const _kTabs = <(AnalysisTab, IconData, String, String)>[
  (AnalysisTab.wordStudy, Icons.translate_rounded, 'wordStudyTitle',
      'Word Study'),
  (AnalysisTab.crossRefs, Icons.hub_outlined, 'analysisTabCrossRefs',
      'X-Refs'),
  (AnalysisTab.stats, Icons.bar_chart_rounded, 'analysisTabStats', 'Stats'),
  (AnalysisTab.kwic, Icons.format_align_center_rounded, 'analysisTabKwic',
      'KWIC'),
  (AnalysisTab.related, Icons.linear_scale_rounded, 'analysisTabRelated',
      'Related'),
  (AnalysisTab.verseLists, Icons.playlist_add_check_rounded,
      'analysisTabVerseLists', 'Lists'),
  (AnalysisTab.phrases, Icons.format_quote_rounded, 'analysisTabPhrases',
      'Phrases'),
  (AnalysisTab.vocabulary, Icons.style_outlined, 'analysisTabVocabulary',
      'Vocab'),
  (AnalysisTab.morphology, Icons.account_tree_outlined,
      'analysisTabMorphology', 'Forms'),
  (AnalysisTab.topics, Icons.topic_outlined, 'analysisTabTopics', 'Topics'),
  (AnalysisTab.context, Icons.segment_rounded, 'analysisTabContext',
      'Context'),
  (AnalysisTab.places, Icons.place_outlined, 'analysisTabPlaces', 'Places'),
  (AnalysisTab.sermons, Icons.record_voice_over_outlined,
      'analysisTabSermons', 'Sermons'),
];

/// The tab names as they will be drawn in [locale], in strip order.
///
/// Public because the width a labelled tab needs is a measurement of
/// exactly these strings — a caller that wants to know whether the
/// strip can carry labels must measure what the strip will draw, not a
/// copy of it that can drift.
List<String> analysisTabLabels(String locale) => [
      for (final tab in _kTabs) uiStrings[tab.$3]?[locale] ?? tab.$4,
    ];

/// The tab strip itself. Deliberately a plain segmented row rather than
/// a Material `TabBar`: the pane is narrow (320–560 px) and the strip
/// has to sit under the existing pane header without a second
/// `DefaultTabController` scope fighting the reader's own.
class AnalysisTabStrip extends StatelessWidget {
  const AnalysisTabStrip({
    super.key,
    required this.current,
    required this.onChanged,
    required this.locale,
    this.preferLabels = false,
  });

  final AnalysisTab current;
  final ValueChanged<AnalysisTab> onChanged;
  final String locale;

  /// The reader has asked for tab names rather than letting the strip
  /// decide (task #297). Costs rows, never letters.
  final bool preferLabels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = WbType.of(context);
    const items = _kTabs;
    final labels = analysisTabLabels(locale);
    // One factor for the label, the icon, the gaps and the paddings.
    // Measuring at one size and drawing at another is exactly how #297
    // ellipsised every label, so these four lines are the whole
    // contract: what the strip measures is what _TabButton draws.
    final labelSize = t.scaledChrome(_kLabelFontSize);
    final labelChrome = t.scaledChrome(_kLabelChrome);
    final minLabelled = _cachedMinLabelledWidth(
      labels,
      MediaQuery.textScalerOf(context),
      labelSize,
      labelChrome,
    );
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: t.scaledChrome(8), vertical: t.scaledChrome(6)),
      color: scheme.surface,
      child: LayoutBuilder(
        builder: (context, box) {
          final layout = analysisStripLayout(
            box.maxWidth,
            items.length,
            minLabelledTabWidth: minLabelled,
            minTabWidth: t.scaledChrome(_kMinTabWidth),
            preferLabels: preferLabels,
          );
          final perRow = layout.perRow;
          final showLabels = layout.showLabels;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var start = 0; start < items.length; start += perRow)
                Padding(
                  padding: EdgeInsets.only(
                      top: start == 0 ? 0 : t.scaledChrome(4)),
                  child: Row(
                    children: [
                      for (var i = start; i < start + perRow; i++)
                        if (i >= items.length)
                          const Expanded(child: SizedBox.shrink())
                        else
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: t.scaledChrome(2)),
                              child: _TabButton(
                                icon: items[i].$2,
                                label: labels[i],
                                showLabel: showLabels,
                                selected: items[i].$1 == current,
                                onTap: () => onChanged(items[i].$1),
                                type: t,
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.type,
    this.showLabel = true,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  /// Passed down rather than resolved here: the strip MEASURED with this
  /// exact scale before deciding to show labels at all.
  final WbType type;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    // `primaryContainer`/`onPrimaryContainer` are tonal roles that
    // `workbenchTheme` does NOT remap — `ColorScheme.fromSeed` fills
    // them with a Material pastel derived from the link colour, so the
    // selected tab in the app's most-seen 30 px was a lavender pill the
    // palette had never defined, and on 護眼紙質 a lavender pill on
    // cream. `selectionBg` under an accent label is what the workbench's
    // own toolbar already uses for an active button.
    final fg = selected ? wb.link : wb.mutedText;
    return Tooltip(
      message: label,
      child: Material(
        color: selected ? wb.selectionBg : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          hoverColor: wb.hoverBg,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Padding(
            padding: EdgeInsets.symmetric(
                vertical: type.scaledChrome(7),
                horizontal: type.scaledChrome(4)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: type.scaledChrome(showLabel ? 15 : 17), color: fg),
                if (showLabel) ...[
                  SizedBox(width: type.scaledChrome(5)),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      // Kept as a backstop only. What actually prevents
                      // a cut label is that the strip measured THIS
                      // style before deciding to show one — the two must
                      // stay in step, hence the shared font size and the
                      // fallback list the measurement also uses.
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: type.scaledChrome(_kLabelFontSize),
                        fontFamilyFallback: kCjkFontFallback,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Cross-references ────────────────────────────────────────────────

/// TSK / OpenBible cross-references for [verse], each rendered with the
/// referenced text so the pane is readable without navigating away.
class CrossRefsPane extends StatefulWidget {
  const CrossRefsPane({
    super.key,
    required this.englishBook,
    required this.chapter,
    required this.verse,
    required this.locale,
    required this.version,
    required this.verseByRef,
    required this.onOpenRef,
  });

  final String englishBook;
  final int chapter;
  final int verse;
  final String locale;
  final String version;

  /// `'EnglishBook-chapter-verse'` → verse, so each reference can show
  /// its text inline. Comes from `WorkbenchProvider.verseByRef`, which
  /// already caches this index and, crucially, canonicalises the book
  /// name to English — the corpus stores it in the version's own
  /// language, so indexing on `Verse.book` directly would never match a
  /// cross-reference on a Chinese version.
  final Map<String, Verse> verseByRef;
  final void Function(BibleReference ref) onOpenRef;

  @override
  State<CrossRefsPane> createState() => _CrossRefsPaneState();
}

class _CrossRefsPaneState extends State<CrossRefsPane> {
  late Future<List<BibleReference>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(CrossRefsPane old) {
    super.didUpdateWidget(old);
    if (old.englishBook != widget.englishBook ||
        old.chapter != widget.chapter ||
        old.verse != widget.verse) {
      _future = _load();
    }
  }

  Future<List<BibleReference>> _load() =>
      CrossReferenceService.forVerseOrNearby(
          widget.englishBook, widget.chapter, widget.verse);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = WbType.of(context);
    return FutureBuilder<List<BibleReference>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final refs = snap.data ?? const <BibleReference>[];
        if (refs.isEmpty) {
          return _EmptyPane(
            icon: Icons.hub_outlined,
            message: uiStrings['analysisNoCrossRefs']?[widget.locale] ??
                'No cross-references for this verse.',
          );
        }
        final index = widget.verseByRef;
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
          physics: const BouncingScrollPhysics(),
          itemCount: refs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final r = refs[i];
            final start = r.verseStart ?? 1;
            final hit = index['${r.englishBook}-${r.chapter}-$start'];
            final label =
                '${localeAwareBookName(r.englishBook, widget.locale, widget.version)} '
                '${r.chapter}:$start';
            return InkWell(
              onTap: () => widget.onOpenRef(r),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: t.scaled(12),
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                    if (hit != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        // Cross-refs print the verse itself, so it
                        // needs the same cleanup the reader gets —
                        // otherwise a NASB ¶ or an LEB <note:…>
                        // shows up here instead.
                        scriptureReadingText(hit.text),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: t.scaled(12.5),
                          height: 1.45,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Word frequency ──────────────────────────────────────────────────

/// How often each original-language word of the focused verse occurs in
/// the whole Bible — BibleWorks' word-list idiom, scoped to one verse
/// so it answers "is this word rare?" at a glance.
class WordStatsPane extends StatefulWidget {
  const WordStatsPane({
    super.key,
    required this.words,
    required this.locale,
    required this.onOpenStrongs,
    this.scope,
    this.scopeName,
    this.scopeBooks,
    this.version,
    this.currentBook,
    this.onOpenChart,
  });

  final List<OriginalWord> words;
  final String locale;
  final ValueChanged<String> onOpenStrongs;

  /// The reading version, so the strip's tooltip and the chart it opens
  /// name books the way the text being read names them (#283).
  final String? version;

  /// Canonical English name of the book in focus, marked on the strip.
  final String? currentBook;

  /// Open the labelled chart for this Strong's number in the centre
  /// pane. Null where there is no centre pane to open it into, in which
  /// case the strip is drawn but not tappable.
  final ValueChanged<String>? onOpenChart;

  /// The active search limit as verse keys, and what to call it. This
  /// is a count OVER the corpus, so it honours the scope and says so —
  /// "is this word rare?" has a different answer inside Ruth.
  final Set<String>? scope;
  final String? scopeName;

  /// The same limit as whole BOOKS, when it is expressible that way.
  ///
  /// #308: the row prints `inScope / total`, and [total] is the
  /// concordance's uncapped OCCURRENCE count. Filtering the reference
  /// list by [scope] answers in VERSES, and from a list that stops at
  /// 500 — so `12 / 6521` was two different units, the smaller one
  /// capped. Summing the per-book occurrence map over these books is the
  /// same unit as the denominator and has no cap at all. Null when the
  /// limit names chapters or verses, which that map cannot resolve.
  final Set<String>? scopeBooks;

  @override
  State<WordStatsPane> createState() => _WordStatsPaneState();
}

class _WordStatsPaneState extends State<WordStatsPane> {
  late Future<List<_StatRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(WordStatsPane old) {
    super.didUpdateWidget(old);
    if (old.words != widget.words ||
        !setEquals(old.scope, widget.scope) ||
        !setEquals(old.scopeBooks, widget.scopeBooks)) {
      _future = _load();
    }
  }

  Future<List<_StatRow>> _load() async {
    final rows = <_StatRow>[];
    final seen = <String>{};
    final scope = widget.scope;
    final scopeBooks = widget.scopeBooks;
    for (final w in widget.words) {
      if (w.strongs.isEmpty || !seen.add(w.strongs)) continue;
      final result = await ConcordanceService.lookup(w.strongs);
      final entry = await StrongsService.lookup(w.strongs);
      final total = result?.total ?? 0;
      final byBook = result?.byBook ?? const <String, int>{};

      // Unscoped and whole-book-scoped rows both count OCCURRENCES, so
      // the pair prints as a ratio. A chapter-level limit can only be
      // answered from the verse list, which counts something else — so
      // that row prints no denominator rather than an exact-looking
      // mixture of the two units (#308). It used to print a `≥` as well,
      // because the verse list stopped at 500; since v1.6.96 it is
      // complete and the scoped figure is exact.
      final int inScope;
      final int? denominator;
      if (scope == null) {
        inScope = total;
        denominator = null;
      } else if (scopeBooks != null) {
        var sum = 0;
        for (final b in scopeBooks) {
          sum += byBook[b] ?? 0;
        }
        inScope = sum;
        denominator = total;
      } else {
        final listed = result?.refs ?? const <ConcordanceRef>[];
        inScope = applySearchLimit(listed, scope,
            (r) => '${r.englishBook}-${r.chapter}-${r.verse}').length;
        denominator = null;
      }

      rows.add(_StatRow(
        word: w,
        inScope: inScope,
        denominator: denominator,
        gloss: entry?.localizedGloss(widget.locale) ?? '',
        greek: await GreekStatsService.lookup(w.strongs),
        // Every book kept, including the ones at zero: the strip has no
        // labels, so a book's POSITION is the only thing naming it.
        distribution: buildDistributionFromCounts(
          counts: byBook,
          bookOrder: kScopeAllBooks,
          oldTestamentBooks: oldTestamentBooks,
          includeEmpty: true,
          unit: HitUnit.occurrences,
        ),
      ));
    }
    // Rarest first — that is the interesting end of the list, and under
    // a limit the rarity that matters is the one inside it.
    rows.sort((a, b) => a.inScope.compareTo(b.inScope));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = WbType.of(context);
    return FutureBuilder<List<_StatRow>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snap.data ?? const <_StatRow>[];
        if (rows.isEmpty) {
          return _EmptyPane(
            icon: Icons.bar_chart_rounded,
            message: uiStrings['analysisNoStats']?[widget.locale] ??
                'No original-language data for this verse.',
          );
        }
        final max = rows.fold<int>(1, (m, r) => r.inScope > m ? r.inScope : m);
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
          physics: const BouncingScrollPhysics(),
          itemCount: rows.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, i) {
            if (i == 0) {
              // The old hint said "Whole-Bible occurrences", which a
              // limit makes false. Under one, the hint names the scope
              // and explains the pair of numbers instead.
              final name = widget.scopeName;
              final String hint;
              if (name == null) {
                hint = uiStrings['analysisStatsHint']?[widget.locale] ??
                    'Whole-Bible occurrences, rarest first.';
              } else {
                // A chapter-level limit is answered in verses, with no
                // denominator — so it gets its own sentence rather than
                // one that promises a ratio of occurrences (#308).
                final key = widget.scopeBooks == null
                    ? 'scopeStatsHintVerses'
                    : 'scopeStatsHint';
                final template = uiStrings[key]?[widget.locale] ??
                    (widget.scopeBooks == null
                        ? 'Verses in {name} carrying the word, rarest '
                            'first — not occurrences.'
                        : 'In scope / in all, rarest first — limited to '
                            '{name}.');
                hint = template.replaceAll('{name}', name);
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  hint,
                  style: TextStyle(
                      fontSize: t.scaled(11), color: scheme.outline),
                ),
              );
            }
            final r = rows[i - 1];
            return InkWell(
              onTap: () => widget.onOpenStrongs(r.word.strongs),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.word.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: t.scaledOriginal(15),
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          scopedCountLabel(r.inScope, r.denominator),
                          style: TextStyle(
                            fontSize: t.scaled(12),
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    // The `ClipRRect` this replaces was arguing with the
                    // theme twice over: `progressIndicatorTheme` already
                    // sets `BorderRadius.zero`, so the clip existed only
                    // to round a bar the workbench had squared.
                    WbMeterBar(
                      fraction: (r.inScope / max).clamp(0.02, 1.0),
                      color: scheme.primary.withValues(alpha: 0.65),
                      trackColor:
                          scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    // The shape of the word across the canon. Above it,
                    // the bar says how MANY; this says WHERE, which is
                    // the observation the total hides.
                    if (!r.distribution.isEmpty) ...[
                      const SizedBox(height: 3),
                      WordDistributionStrip(
                        distribution: r.distribution,
                        currentBook: widget.currentBook,
                        // The strip has no labels and no tooltip, so a
                        // screen reader — and a tablet, which has no
                        // hover at all — got the shape of the word and
                        // no idea what the bars counted. Name it (#308).
                        semanticsLabel: _stripSemantics(
                            r.distribution, widget.locale, widget.version),
                        onTap: widget.onOpenChart == null
                            ? null
                            : () => widget.onOpenChart!(r.word.strongs),
                      ),
                    ],
                    if (r.greek != null) _distribution(context, r.greek!),
                    if (r.gloss.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        r.gloss,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: t.scaled(11.5),
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Where a Greek word actually lives in the New Testament.
///
/// The bar above this says how often the word occurs. That single number
/// hides the fact worth knowing: βδέλυγμα occurs 6 times, but three of
/// them are in Revelation and the rest are one apiece in the Synoptics.
/// So this strip spends its space on the shape rather than repeating the
/// total — the books the word is commonest in, with its rank inside each,
/// and the author split when the word is spread widely enough for that
/// to say anything.
Widget _distribution(BuildContext context, GreekWordStats g) {
  final theme = Theme.of(context);
  final t = WbType.of(context);
  final scheme = theme.colorScheme;
  final top = g.byFrequency.take(4).toList();
  if (top.isEmpty) return const SizedBox.shrink();

  // Author groupings are only informative when the word crosses them.
  // A word confined to Paul does not need to be told it is 100% Paul.
  const groups = {
    'gospelsActs': 'G+A',
    'paul': 'Paul',
    'john': 'John',
    'otherAuthors': 'Other',
  };
  final present = groups.keys.where((k) => (g.totals[k] ?? 0) > 0).toList();

  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Wrap(
      spacing: 5,
      runSpacing: 3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final e in top)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.09),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.28),
              ),
            ),
            child: Text(
              // "Rev 3" — and "Rev 3 ·#6" when the source knows the
              // word's rank inside that book, which is the number
              // BibleWorks cannot give you.
              e.value.$2 == null
                  ? '${_abbr(e.key)} ${e.value.$1}'
                  : '${_abbr(e.key)} ${e.value.$1} ·#${e.value.$2}',
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: t.scaled(9.5),
                color: scheme.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        if (g.books.length > top.length)
          Text(
            '+${g.books.length - top.length}',
            style: theme.textTheme.labelSmall
                ?.copyWith(fontSize: t.scaled(9.5), color: scheme.outline),
          ),
        if (present.length > 1)
          Text(
            present.map((k) => '${groups[k]} ${g.totals[k]}').join(' / '),
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: t.scaled(9.5),
              color: scheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
      ],
    ),
  );
}

/// What the label-less strip would say if it could speak: the heaviest
/// books, in the unit [d] is counted in, and how to open the full chart.
String _stripSemantics(SearchDistribution d, String locale, String? version) {
  final open = uiStrings['wordChartOpen']?[locale] ??
      'Open the full distribution chart';
  final unit = uiStrings[
              d.unit == HitUnit.verses
                  ? 'hitUnitVerses'
                  : 'hitUnitOccurrences']?[locale] ??
          (d.unit == HitUnit.verses ? 'verses' : 'occurrences');
  final top = topBooks(d);
  if (top.isEmpty) return open;
  final label = uiStrings['searchStatsTopIn']?[locale] ?? 'Most in ({unit})';
  final heads = [
    for (final b in top)
      '${localeAwareBookName(b.englishBook, locale, version)} ${b.count}'
  ].join(' · ');
  return '${label.replaceAll('{unit}', unit)}: $heads · $open';
}

/// "1 Corinthians" -> "1Co". The pane is 320-560 px wide and these sit
/// four to a row, so the full name is not an option.
String _abbr(String book) {
  final parts = book.split(' ');
  return parts.length == 1
      ? book.substring(0, book.length < 3 ? book.length : 3)
      : '${parts[0]}${parts[1].substring(0, 2)}';
}

class _StatRow {
  const _StatRow({
    required this.word,
    required this.inScope,
    required this.gloss,
    required this.distribution,
    this.denominator,
    this.greek,
  });

  /// Per-book occurrences over the whole Bible, empty books included.
  ///
  /// Sourced from the concordance index rather than the Eagle's View
  /// Greek profile, which is what makes the strip appear for HEBREW
  /// words too — `greek` below is null for every one of them.
  final SearchDistribution distribution;

  final OriginalWord word;

  /// The number this row is about: occurrences over the whole Bible, or
  /// inside the active limit when there is one.
  final int inScope;

  /// What [inScope] is a part of, printed beside it — bwh23's
  /// parenthesised statistic. Null when there is nothing to compare
  /// against IN THE SAME UNIT, which is the unlimited case (`12 / 12`
  /// says nothing, #280) and the chapter-level limit (#308).
  final int? denominator;

  final String gloss;

  /// Eagle's View's distribution for this word, when it has one. Null
  /// for Hebrew and for Greek words outside the Westcott-Hort profile —
  /// the row still renders, just without the strip.
  final GreekWordStats? greek;
}

// ── Shared empty state ──────────────────────────────────────────────

class _EmptyPane extends StatelessWidget {
  const _EmptyPane({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: scheme.outlineVariant),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.outline, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// **Topics** — Eagle's View's Modern Concordance, entered from the verse
/// the reader is already on.
///
/// The concordance is a browsable scheme of 341 topics, and it would have
/// been simpler to ship it as its own page. That would also have made it a
/// place you go rather than something the workspace knows: the reader
/// sitting on Matthew 24:15 wants to be told that this verse is where the
/// concordance files "Abomination", not to go and look it up.
///
/// So the pane leads with the topics that cite the focused verse, each
/// expandable into the Greek word behind it, that word's other
/// occurrences, and the corpus statistics that make this a *statistical*
/// concordance — the NT total, split across Gospels & Acts, Paul, John,
/// and the other authors.
///
/// New Testament only, and silent about it: the source is a NT Greek
/// concordance, so an Old Testament verse yields nothing and that is the
/// correct answer, not a gap to apologise for.
class ConcordanceTopicsPane extends StatefulWidget {
  const ConcordanceTopicsPane({
    super.key,
    required this.englishBook,
    required this.chapter,
    required this.verse,
    required this.locale,
    required this.onOpenRef,
  });

  final String englishBook;
  final int chapter;
  final int verse;
  final String locale;
  final void Function(BibleReference ref) onOpenRef;

  @override
  State<ConcordanceTopicsPane> createState() => _ConcordanceTopicsPaneState();
}

class _ConcordanceTopicsPaneState extends State<ConcordanceTopicsPane> {
  late Future<List<ConcordanceCitation>> _future;
  int? _openTopic;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant ConcordanceTopicsPane old) {
    super.didUpdateWidget(old);
    if (old.englishBook != widget.englishBook ||
        old.chapter != widget.chapter ||
        old.verse != widget.verse) {
      _openTopic = null;
      _future = _load();
    }
  }

  Future<List<ConcordanceCitation>> _load() =>
      ModernConcordanceService.forVerse(
        englishBook: widget.englishBook,
        chapter: widget.chapter,
        verse: widget.verse,
      );

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    return FutureBuilder<List<ConcordanceCitation>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final hits = snap.data ?? const <ConcordanceCitation>[];
        if (hits.isEmpty) {
          return _EmptyPane(
            icon: Icons.topic_outlined,
            message: uiStrings['concordanceNoEntries']?[locale] ??
                'The Modern Concordance covers the New Testament; '
                    'this verse has no entry.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 14),
          physics: const BouncingScrollPhysics(),
          // +1 for the attribution that closes the list. The permission
          // this data ships under is conditional on naming its source, so
          // the credit travels with the pane, not with a settings page
          // nobody opens.
          itemCount: hits.length + 1,
          itemBuilder: (context, i) {
            if (i == hits.length) return _attribution(context);
            final hit = hits[i];
            return _TopicTile(
              citation: hit,
              locale: locale,
              expanded: _openTopic == hit.topicId,
              onToggle: () => setState(() =>
                  _openTopic = _openTopic == hit.topicId ? null : hit.topicId),
              onOpenRef: widget.onOpenRef,
              here: (widget.englishBook, widget.chapter, widget.verse),
            );
          },
        );
      },
    );
  }

  Widget _attribution(BuildContext context) {
    final theme = Theme.of(context);
    final t = WbType.of(context);
    final text = ModernConcordanceService.attribution;
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: t.scaled(10.5),
          height: 1.35,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({
    required this.citation,
    required this.locale,
    required this.expanded,
    required this.onToggle,
    required this.onOpenRef,
    required this.here,
  });

  final ConcordanceCitation citation;
  final String locale;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(BibleReference ref) onOpenRef;
  final (String, int, int) here;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      citation.topic.label(locale),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFamilyFallback: kCjkFontFallback,
                      ),
                    ),
                  ),
                  // `WbTag` is the workbench's existing answer to "a
                  // short code printed next to something", and it puts
                  // the hue on the TEXT rather than in a tinted fill —
                  // which is how a Strong's number is already printed
                  // after a word everywhere else in the app.
                  WbTag(
                    text: citation.strongs,
                    color: WbColors.of(context).strongsLexical,
                    dense: false,
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            _TopicDetail(
              topicId: citation.topicId,
              strongs: citation.strongs,
              locale: locale,
              onOpenRef: onOpenRef,
              here: here,
            ),
        ],
      ),
    );
  }
}

/// The Greek word behind one topic citation: its gloss, where else it
/// occurs, and its corpus statistics.
class _TopicDetail extends StatefulWidget {
  const _TopicDetail({
    required this.topicId,
    required this.strongs,
    required this.locale,
    required this.onOpenRef,
    required this.here,
  });

  final int topicId;
  final String strongs;
  final String locale;
  final void Function(BibleReference ref) onOpenRef;
  final (String, int, int) here;

  @override
  State<_TopicDetail> createState() => _TopicDetailState();
}

class _TopicDetailState extends State<_TopicDetail> {
  late Future<(List<ConcordanceSection>, String?)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(List<ConcordanceSection>, String?)> _load() async => (
        await ModernConcordanceService.sections(widget.topicId),
        await ModernConcordanceService.transliteration(widget.strongs),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return FutureBuilder<(List<ConcordanceSection>, String?)>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(10),
            child: SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final (sections, translit) = snap.data!;
        // Only the entries for the Greek word that brought us here. A
        // topic can run to dozens of words; showing all of them would
        // bury the one the reader's verse actually uses.
        final entries = [
          for (final s in sections)
            for (final e in s.entries)
              if (e.strongs == widget.strongs) (s, e),
        ];
        if (entries.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (translit != null && translit.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    translit,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              for (final (_, e) in entries) ...[
                Text(
                  e.label(widget.locale),
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.4,
                    fontFamilyFallback: kCjkFontFallback,
                  ),
                ),
                if (e.totals.isNotEmpty) _stats(context, e),
                if (e.refs.isNotEmpty) _refs(context, e),
                const SizedBox(height: 6),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _stats(BuildContext context, ConcordanceEntry e) {
    final wb = WbColors.of(context);
    const labels = {
      'nt': 'NT',
      'gospelsActs': 'Gospels+Acts',
      'paul': 'Paul',
      'john': 'John',
      'otherAuthors': 'Other',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          // `WbTag`'s own doc names this case — "a short code printed
          // next to something: H3068, OT, NT" — and it is what carries
          // the NT emphasis on the text instead of in a tinted fill.
          for (final key in labels.keys)
            if (e.totals[key] != null)
              WbTag(
                text: '${labels[key]} ${e.totals[key]}',
                color: key == 'nt' ? wb.link : wb.mutedText,
                dense: false,
              ),
        ],
      ),
    );
  }

  Widget _refs(BuildContext context, ConcordanceEntry e) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = WbType.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 2,
        children: [
          for (final (book, ch, vs) in e.refs)
            Builder(builder: (context) {
              // The verse we came from is in this list. Marking it rather
              // than hiding it keeps the count honest against the NT
              // total shown just above.
              final isHere = book == widget.here.$1 &&
                  ch == widget.here.$2 &&
                  vs == widget.here.$3;
              return InkWell(
                onTap: () => widget.onOpenRef(BibleReference(
                  englishBook: book,
                  chapter: ch,
                  verseStart: vs,
                  verseEnd: vs,
                )),
                child: Text(
                  '${localeAwareBookName(book, widget.locale)} $ch:$vs',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: t.scaled(10.5),
                    color: isHere ? scheme.primary : scheme.onSurfaceVariant,
                    fontWeight: isHere ? FontWeight.w700 : null,
                    decoration: isHere ? TextDecoration.underline : null,
                    fontFamilyFallback: kCjkFontFallback,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
