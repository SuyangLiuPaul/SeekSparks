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

import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/original_word.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/services/concordance_service.dart';
import 'package:seeksparks/services/modern_concordance_service.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/scripture_markup.dart';
import 'package:seeksparks/services/cross_reference_service.dart';
import 'package:seeksparks/services/strongs_service.dart';
import 'package:seeksparks/utils/reference_parser.dart' show BibleReference;
import 'package:seeksparks/utils/version_mapper.dart' show localeAwareBookName;

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
}

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
  });

  final AnalysisTab current;
  final ValueChanged<AnalysisTab> onChanged;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const items = <(AnalysisTab, IconData, String, String)>[
      (AnalysisTab.wordStudy, Icons.translate_rounded, 'wordStudyTitle',
          'Word Study'),
      (AnalysisTab.crossRefs, Icons.hub_outlined, 'analysisTabCrossRefs',
          'X-Refs'),
      (AnalysisTab.stats, Icons.bar_chart_rounded, 'analysisTabStats',
          'Stats'),
      (AnalysisTab.kwic, Icons.format_align_center_rounded,
          'analysisTabKwic', 'KWIC'),
      (AnalysisTab.related, Icons.linear_scale_rounded,
          'analysisTabRelated', 'Related'),
      (AnalysisTab.verseLists, Icons.playlist_add_check_rounded,
          'analysisTabVerseLists', 'Lists'),
      (AnalysisTab.phrases, Icons.format_quote_rounded,
          'analysisTabPhrases', 'Phrases'),
      (AnalysisTab.vocabulary, Icons.style_outlined, 'analysisTabVocabulary',
          'Vocab'),
      (AnalysisTab.morphology, Icons.account_tree_outlined,
          'analysisTabMorphology', 'Forms'),
      (AnalysisTab.topics, Icons.topic_outlined, 'analysisTabTopics',
          'Topics'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      color: scheme.surface,
      child: LayoutBuilder(
        builder: (context, box) {
          // A labelled tab needs ~66 px; the Analysis pane can be as
          // narrow as 320. Below that the label is what goes — an
          // ellipsised "Wor…/X-R…/Sta…" identifies nothing, whereas the
          // icons already differ from one another at a glance.
          final showLabels = box.maxWidth / items.length >= 66;
          return Row(
            children: [
              for (final (tab, icon, key, fallback) in items)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _TabButton(
                      icon: icon,
                      label: uiStrings[key]?[locale] ?? fallback,
                      showLabel: showLabels,
                      selected: tab == current,
                      onTap: () => onChanged(tab),
                    ),
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
    this.showLabel = true,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return Tooltip(
      message: label,
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: showLabel ? 15 : 17, color: fg),
                if (showLabel) ...[
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
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
            final label = '${localeAwareBookName(r.englishBook, widget.locale, widget.version)} '
                '${r.chapter}:$start';
            return InkWell(
              onTap: () => widget.onOpenRef(r),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
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
                          fontSize: 12.5,
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
  });

  final List<OriginalWord> words;
  final String locale;
  final ValueChanged<String> onOpenStrongs;

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
    if (old.words != widget.words) _future = _load();
  }

  Future<List<_StatRow>> _load() async {
    final rows = <_StatRow>[];
    final seen = <String>{};
    for (final w in widget.words) {
      if (w.strongs.isEmpty || !seen.add(w.strongs)) continue;
      final result = await ConcordanceService.lookup(w.strongs);
      final entry = await StrongsService.lookup(w.strongs);
      rows.add(_StatRow(
        word: w,
        total: result?.total ?? 0,
        gloss: entry?.localizedGloss(widget.locale) ?? '',
      ));
    }
    // Rarest first — that is the interesting end of the list.
    rows.sort((a, b) => a.total.compareTo(b.total));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
        final max = rows.fold<int>(1, (m, r) => r.total > m ? r.total : m);
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
          physics: const BouncingScrollPhysics(),
          itemCount: rows.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  uiStrings['analysisStatsHint']?[widget.locale] ??
                      'Whole-Bible occurrences, rarest first.',
                  style: TextStyle(fontSize: 11, color: scheme.outline),
                ),
              );
            }
            final r = rows[i - 1];
            return InkWell(
              onTap: () => widget.onOpenStrongs(r.word.strongs),
              borderRadius: BorderRadius.circular(8),
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
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${r.total}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (r.total / max).clamp(0.02, 1.0),
                        minHeight: 4,
                        backgroundColor:
                            scheme.outlineVariant.withValues(alpha: 0.5),
                        valueColor:
                            AlwaysStoppedAnimation(scheme.primary.withValues(
                          alpha: 0.65,
                        )),
                      ),
                    ),
                    if (r.gloss.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        r.gloss,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
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

class _StatRow {
  const _StatRow({
    required this.word,
    required this.total,
    required this.gloss,
  });

  final OriginalWord word;
  final int total;
  final String gloss;
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
              onToggle: () => setState(
                  () => _openTopic = _openTopic == hit.topicId ? null : hit.topicId),
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
    final text = ModernConcordanceService.attribution;
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 10.5,
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
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
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
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      citation.strongs,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
          for (final key in labels.keys)
            if (e.totals[key] != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: key == 'nt'
                      ? scheme.primary.withValues(alpha: 0.12)
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${labels[key]} ${e.totals[key]}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: key == 'nt' ? scheme.primary : scheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _refs(BuildContext context, ConcordanceEntry e) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
                    fontSize: 10.5,
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
