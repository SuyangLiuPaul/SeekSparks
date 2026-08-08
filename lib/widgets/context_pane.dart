/// 2026-08-07 (SeekSparks): the Context tab — BibleWorks `bwh10h`.
///
/// "What is this passage made of, and what marks it off from the book it
/// sits in." Three nested scopes, following the verse the reader is on
/// rather than the word under the pointer, so the pane is stable enough
/// to read.
///
/// **Why this is not the Word List Manager over again.** The WLM
/// (`bwh26`, already shipped) is a workbench you go to: pick a passage,
/// sort it, look something up. The Context tab is ambient — it is
/// already showing the paragraph you are reading, and its unit is the
/// PERICOPE, which the WLM cannot express because a pericope is not a
/// chapter and SeekSparks' outline had never been read as ranges before.
///
/// **Why the top of the list is not the article.** See
/// `context_words.dart`: content-word filtering by default, and a
/// keyness ordering that ranks by over-representation against the rest
/// of the book instead of by raw count. On John 1:1-18 that is the
/// difference between a list headed `ὁ, καί, αὐτοῦ` and one headed
/// `χάρις, γίνομαι, φῶς, μονογενής, σκηνόω` — the prologue's own
/// vocabulary.
library;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/original_word.dart';
import 'package:seeksparks/models/strongs.dart';
import 'package:seeksparks/pages/strongs_entry_page.dart';
import 'package:seeksparks/services/originals_service.dart';
import 'package:seeksparks/services/section_title_service.dart';
import 'package:seeksparks/services/strongs_service.dart';
import 'package:seeksparks/utils/app_nav.dart';
import 'package:seeksparks/utils/context_words.dart';
import 'package:seeksparks/utils/pericope.dart';
import 'package:seeksparks/utils/word_pos.dart';

class ContextPane extends StatefulWidget {
  const ContextPane({
    super.key,
    required this.englishBook,
    required this.chapter,
    required this.verse,
    required this.locale,
    required this.version,
    required this.onOpenVerse,
  });

  final String englishBook;
  final int chapter;
  final int verse;
  final String locale;

  /// Only decides which set of outline headings to title the pericope
  /// with; the boundaries are the same in every set.
  final String version;

  final void Function(int chapter, int verse) onOpenVerse;

  @override
  State<ContextPane> createState() => _ContextPaneState();
}

class _ContextPaneState extends State<ContextPane> {
  ContextScope _scope = ContextScope.pericope;
  ContextSort _sort = ContextSort.distinctive;
  bool _includeFunctionWords = false;
  String? _expanded;

  bool _loading = true;
  Map<String, List<OriginalWord>> _bookVerses = const {};
  Map<int, int> _lastVerseByChapter = const {};
  PericopeRange? _pericope;
  ContextWordList _list = ContextWordList.empty;
  double _maxKeyness = 0;
  int _scopeVerses = 0;
  Map<String, StrongsEntry> _lex = const {};

  @override
  void initState() {
    super.initState();
    _loadBook();
  }

  @override
  void didUpdateWidget(ContextPane old) {
    super.didUpdateWidget(old);
    if (old.englishBook != widget.englishBook) {
      _loadBook();
    } else if (old.chapter != widget.chapter ||
        old.verse != widget.verse ||
        old.version != widget.version) {
      // Same book, new position: the pericope may have changed but the
      // text is already in memory.
      _recompute();
    }
  }

  String _s(String key, String fallback) =>
      uiStrings[key]?[widget.locale] ?? fallback;

  Future<void> _loadBook() async {
    setState(() {
      _loading = true;
      _expanded = null;
    });
    await SectionTitleService.ensureLoaded();
    final verses = await OriginalsService.versesOfBook(widget.englishBook);
    if (!mounted) return;
    final last = <int, int>{};
    for (final key in verses.keys) {
      final parts = key.split(':');
      if (parts.length != 2) continue;
      final c = int.tryParse(parts[0]);
      final v = int.tryParse(parts[1]);
      if (c == null || v == null) continue;
      if (v > (last[c] ?? 0)) last[c] = v;
    }
    _bookVerses = verses;
    _lastVerseByChapter = last;
    await _recompute();
  }

  Future<void> _recompute() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _expanded = null;
    });

    final headings = SectionTitleService.headingsInBook(
      setId: SectionTitleService.contextSetFor(
        version: widget.version,
        locale: widget.locale,
      ),
      englishBook: widget.englishBook,
    );
    _pericope = pericopeAt(
      headings: headings,
      chapter: widget.chapter,
      verse: widget.verse,
      lastVerseByChapter: _lastVerseByChapter,
    );

    // A book with no outline has no pericope to show. Fall back rather
    // than render an empty scope the reader cannot leave.
    var scope = _scope;
    if (scope == ContextScope.pericope && _pericope == null) {
      scope = ContextScope.chapter;
    }

    final scopeWords = <OriginalWord>[];
    final bookWords = <OriginalWord>[];
    var scopeVerses = 0;
    for (final entry in _bookVerses.entries) {
      final parts = entry.key.split(':');
      if (parts.length != 2) continue;
      final c = int.tryParse(parts[0]);
      final v = int.tryParse(parts[1]);
      if (c == null || v == null) continue;
      bookWords.addAll(entry.value);
      if (_inScope(scope, c, v)) {
        scopeWords.addAll(entry.value);
        scopeVerses++;
      }
    }

    final list = buildContextWordList(
      scopeWords: scopeWords,
      // Passing the same list for both is how `buildContextWordList`
      // learns there is no baseline left to compare against.
      bookWords: scope == ContextScope.book ? scopeWords : bookWords,
      include: _includeFunctionWords
          ? {...kContentPos, ...kFunctionPos}
          : kContentPos,
      sort: _sortFor(scope),
    );

    // Lemmas and glosses for what is actually on screen. The lexicon is
    // one cached map after the first hit, so this is a map lookup per
    // row, not a load per row — but it is still bounded, because a book
    // scope can run to several thousand rows and nobody reads past the
    // first few hundred.
    final lex = <String, StrongsEntry>{};
    for (final e in list.entries.take(400)) {
      final hit = await StrongsService.lookup(e.strongs);
      if (hit != null) lex[e.strongs] = hit;
    }

    if (!mounted) return;
    setState(() {
      _scope = scope;
      _list = list;
      _maxKeyness = list.entries.fold<double>(
          0, (m, e) => (e.keyness ?? 0) > m ? e.keyness! : m);
      _scopeVerses = scopeVerses;
      _lex = lex;
      _loading = false;
    });
  }

  /// The book scope has no reference corpus, so "distinctive" would be
  /// an empty ordering. Fall back to frequency there without changing
  /// what the reader picked, so switching back restores it.
  ContextSort _sortFor(ContextScope scope) =>
      scope == ContextScope.book && _sort == ContextSort.distinctive
          ? ContextSort.frequency
          : _sort;

  bool _inScope(ContextScope scope, int chapter, int verse) {
    switch (scope) {
      case ContextScope.pericope:
        return _pericope?.contains(chapter, verse) ?? false;
      case ContextScope.chapter:
        return chapter == widget.chapter;
      case ContextScope.book:
        return true;
    }
  }

  /// Where a lemma occurs inside the current scope, in reading order.
  List<({int chapter, int verse})> _occurrences(String strongs) {
    final out = <({int chapter, int verse})>[];
    for (final entry in _bookVerses.entries) {
      final parts = entry.key.split(':');
      if (parts.length != 2) continue;
      final c = int.tryParse(parts[0]);
      final v = int.tryParse(parts[1]);
      if (c == null || v == null) continue;
      if (!_inScope(_scope, c, v)) continue;
      if (entry.value.any((w) => w.strongs.toUpperCase() == strongs)) {
        out.add((chapter: c, verse: v));
      }
    }
    out.sort((a, b) {
      final c = a.chapter.compareTo(b.chapter);
      return c != 0 ? c : a.verse.compareTo(b.verse);
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _controls(scheme),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _list.entries.isEmpty
                  ? _empty(scheme)
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _list.entries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) =>
                          _row(_list.entries[i], scheme),
                    ),
        ),
      ],
    );
  }

  Widget _empty(ColorScheme scheme) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _s('contextNone',
                'No original-language text is bundled for this passage.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.outline, height: 1.6),
          ),
        ),
      );

  Widget _controls(ColorScheme scheme) {
    final scopeLabel = switch (_scope) {
      ContextScope.pericope => _pericope?.label ?? '',
      ContextScope.chapter => '${widget.chapter}',
      ContextScope.book => '',
    };
    final title = switch (_scope) {
      ContextScope.pericope => _pericope?.title,
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<ContextScope>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            segments: [
              ButtonSegment(
                value: ContextScope.pericope,
                label: Text(_s('contextScopePericope', 'Pericope'),
                    style: const TextStyle(fontSize: 11)),
                enabled: _pericope != null,
              ),
              ButtonSegment(
                value: ContextScope.chapter,
                label: Text(_s('contextScopeChapter', 'Chapter'),
                    style: const TextStyle(fontSize: 11)),
              ),
              ButtonSegment(
                value: ContextScope.book,
                label: Text(_s('contextScopeBook', 'Book'),
                    style: const TextStyle(fontSize: 11)),
              ),
            ],
            selected: {_scope},
            onSelectionChanged: (s) {
              _scope = s.first;
              _recompute();
            },
          ),
          const SizedBox(height: 6),
          Text(
            [
              if (scopeLabel.isNotEmpty) scopeLabel,
              if (title != null && title.isNotEmpty) title,
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          // BibleWorks prints the same three numbers in each sub-window's
          // title bar: how much text this list was counted over.
          Text(
            _s('contextCounts', '{verses} verses · {words} words · '
                    '{distinct} distinct')
                .replaceAll('{verses}', '$_scopeVerses')
                .replaceAll('{words}', '${_list.scopeTokens}')
                .replaceAll('{distinct}', '${_list.scopeDistinct}'),
            style: TextStyle(fontSize: 11, color: scheme.outline),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (sort, key, fallback) in [
                        (
                          ContextSort.distinctive,
                          'contextSortDistinctive',
                          'Distinctive'
                        ),
                        (ContextSort.frequency, 'contextSortFrequency',
                            'Frequent'),
                        (ContextSort.rarity, 'contextSortRarity', 'Rare'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            labelStyle: const TextStyle(fontSize: 11),
                            label: Text(_s(key, fallback)),
                            selected: _sortFor(_scope) == sort,
                            onSelected: sort == ContextSort.distinctive &&
                                    _scope == ContextScope.book
                                ? null
                                : (_) {
                                    _sort = sort;
                                    _recompute();
                                  },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // The filter that makes the list worth reading. Off = the
              // content words only; on = the raw list BibleWorks shows.
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                isSelected: _includeFunctionWords,
                tooltip: _s('contextIncludeFunction',
                    'Include grammar words (articles, prepositions)'),
                icon: const Icon(Icons.abc_rounded),
                onPressed: () {
                  _includeFunctionWords = !_includeFunctionWords;
                  _recompute();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(ContextWordEntry e, ColorScheme scheme) {
    final entry = _lex[e.strongs];
    // BibleWorks lists the LEMMA, not the inflected form on the page,
    // and it is right to: הָיְתָה tells a reader nothing that הָיָה does
    // not tell them better. The surface form stays as a secondary line
    // because it is what they will recognise in the verse.
    final headword = (entry?.lemma.isNotEmpty ?? false) ? entry!.lemma : e.form;
    final gloss = entry?.localizedGloss(widget.locale) ?? '';
    final expanded = _expanded == e.strongs;
    // Scaled against the list's MAXIMUM keyness, not the first row's:
    // under a frequency sort the first row is rarely the most
    // distinctive, and scaling to it would saturate every bar below.
    final strength = (e.keyness == null || _maxKeyness <= 0)
        ? 0.0
        : (e.keyness! / _maxKeyness).clamp(0.0, 1.0);

    return InkWell(
      onTap: () => setState(() => _expanded = expanded ? null : e.strongs),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Keyness as a bar rather than a number: G² = 33.0 means
                // nothing to a reader, and the counts on the right are
                // the honest explanation of the ranking anyway.
                Container(
                  width: 3,
                  height: 30,
                  margin: const EdgeInsets.only(right: 8, top: 2),
                  color: strength <= 0
                      ? Colors.transparent
                      : scheme.primary.withValues(alpha: 0.25 + strength * 0.6),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headword,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, height: 1.3),
                      ),
                      if (gloss.isNotEmpty)
                        Text(
                          gloss,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${e.count}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (_scope != ContextScope.book)
                      Text(
                        e.isExclusive
                            ? _s('contextOnlyHere', 'only here')
                            : '/ ${e.bookCount}',
                        style: TextStyle(
                          fontSize: 10,
                          color: e.isExclusive
                              ? scheme.primary
                              : scheme.outline,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final o in _occurrences(e.strongs))
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelStyle: const TextStyle(fontSize: 11),
                      label: Text('${o.chapter}:${o.verse}'),
                      onPressed: () => widget.onOpenVerse(o.chapter, o.verse),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  icon: const Icon(Icons.menu_book_outlined, size: 14),
                  label: Text('${e.strongs} · '
                      '${_s('contextOpenLexicon', 'Lexicon entry')}'),
                  onPressed: () =>
                      pushPage(StrongsEntryPage(number: e.strongs)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
