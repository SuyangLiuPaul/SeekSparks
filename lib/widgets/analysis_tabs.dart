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

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/original_word.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/services/concordance_service.dart';
import 'package:seeksparks/utils/scripture_markup.dart';
import 'package:seeksparks/services/cross_reference_service.dart';
import 'package:seeksparks/services/strongs_service.dart';
import 'package:seeksparks/utils/reference_parser.dart' show BibleReference;
import 'package:seeksparks/utils/version_mapper.dart' show localeAwareBookName;

/// Which pane the Analysis window is showing.
/// 2026-08-06: `kwic` joins them — BibleWorks' Key Word In Context
/// (help topic bwh31), then `related` — the Related Verses Tool
/// (bwh50), then `verseLists` — the Verse List Manager (bwh27).
/// Appended rather than inserted because the tab is persisted by
/// INDEX (`workbench.analysisTab`), so reordering would silently move
/// every existing reader to a different tab.
enum AnalysisTab { wordStudy, crossRefs, stats, kwic, related, verseLists }

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
