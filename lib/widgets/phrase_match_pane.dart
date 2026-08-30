/// 2026-08-07 (SeekSparks): the Phrase Matching pane — BibleWorks help
/// topic bwh51, laid out for a pane instead of a window.
///
/// bwh51 gives the tool a phrase list, a result list and three ways of
/// ordering the results. Two of those three are orderings of the same
/// list; the third — "grouped by most frequently used phrases" — is a
/// different shape of data, phrases with verses under them rather than
/// verses with counts beside them. So `Phrase` is not a sort chip that
/// re-sorts; it swaps the whole result body for the other projection.
///
/// The phrase list is bounded and scrolls inside itself. A verse of any
/// length produces about as many phrases as it has words — Esther 8:9
/// yields 83 — and a Wrap of 83 three-word chips is some 28 rows deep,
/// which in a 320 px pane would push the results off the bottom of the
/// screen. BibleWorks itself uses a scrolling list here, so bounding it
/// is faithful as well as necessary. The chevron collapses it entirely
/// when you have finished choosing and want the room for results.
///
/// All the thinking is in `utils/phrase_match.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/utils/phrase_match.dart';
import 'package:seeksparks/utils/short_book_name.dart';
import 'package:seeksparks/widgets/wb_pane_bits.dart';

class PhraseMatchPane extends StatefulWidget {
  const PhraseMatchPane({
    super.key,
    required this.corpus,
    required this.verses,
    required this.baseIndex,
    required this.locale,
    required this.version,
    this.scope,
    this.scopeLabel,
    this.onOpenVerse,
  });

  /// Sanitized verse text, word boundaries intact, parallel to
  /// [verses] and in canonical order — `MainProvider.wordKeys`.
  final List<String> corpus;

  /// The loaded corpus, for turning a hit's index into a reference.
  final List<Verse> verses;

  /// Which verse to find the phrases of.
  final int baseIndex;

  final String locale;

  /// The reading version, so the abbreviated references are in the same
  /// language as the verses they label.
  final String version;

  /// bwh51's "use search limits from main window". Null means the whole
  /// Bible; a set restricts the scan to those corpus indices.
  final Set<int>? scope;

  /// What that limit is called, for the chip that says it is on.
  final String? scopeLabel;

  /// Jump the reader to a hit.
  final void Function(Verse verse)? onOpenVerse;

  @override
  State<PhraseMatchPane> createState() => _PhraseMatchPaneState();
}

class _PhraseMatchPaneState extends State<PhraseMatchPane> {
  PhraseMatchIndex _index = PhraseMatchIndex.empty;
  Set<int> _enabled = <int>{};

  /// Null until the reader touches the stepper, so the default can
  /// follow the script of the verse — 4 for Chinese, 3 otherwise.
  int? _length;
  int _gap = 0;
  bool _useScope = true;
  bool _showPhrases = true;
  PhraseMatchSort _sort = PhraseMatchSort.matches;

  /// Which result row is open. Keyed by string because in the phrase
  /// view one verse can appear under several phrases.
  String? _expanded;
  bool _busy = false;
  int _elapsedMs = 0;

  int get _effectiveLength =>
      _length ??
      (widget.baseIndex >= 0 && widget.baseIndex < widget.corpus.length
          ? defaultPhraseLength(widget.corpus[widget.baseIndex])
          : 3);

  Set<int>? get _activeScope =>
      _useScope && widget.scope != null && widget.scope!.isNotEmpty
          ? widget.scope
          : null;

  @override
  void initState() {
    super.initState();
    _rescan();
  }

  @override
  void didUpdateWidget(covariant PhraseMatchPane old) {
    super.didUpdateWidget(old);
    if (old.baseIndex != widget.baseIndex ||
        !identical(old.corpus, widget.corpus) ||
        !identical(old.scope, widget.scope)) {
      if (old.baseIndex != widget.baseIndex) {
        // A different verse is a different question: the phrase length
        // the reader chose belonged to the old one's script.
        _length = null;
      }
      _expanded = null;
      _rescan();
    }
  }

  /// Re-read the corpus. The only slow step — a tenth of a second over a
  /// whole Bible, a third for the longest verse in it at the widest gap
  /// — so it happens on a frame boundary, letting the spinner paint
  /// first rather than freezing on a dead pane.
  ///
  /// Only length, gap and scope come through here. Checking a phrase off
  /// re-filters hits that are already in hand, and must not rescan.
  Future<void> _rescan() async {
    setState(() => _busy = true);
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    final sw = Stopwatch()..start();
    final ix = buildPhraseMatchIndex(
      corpus: widget.corpus,
      baseIndex: widget.baseIndex,
      phraseLength: _effectiveLength,
      maxGap: _gap,
      scope: _activeScope,
    );
    sw.stop();
    if (!mounted) return;
    setState(() {
      _index = ix;
      _enabled = defaultEnabledPhrases(ix);
      _elapsedMs = sw.elapsedMilliseconds;
      _busy = false;
      _expanded = null;
    });
  }

  void _togglePhrase(int i) {
    if (!_index.phrases[i].listed) return;
    setState(() {
      if (!_enabled.remove(i)) _enabled.add(i);
      _expanded = null;
    });
  }

  String _label(Verse v) =>
      '${shortBookName(v.book, widget.locale, widget.version)} '
      '${v.chapter}:${v.verseLabel}';

  void _copy(List<PhraseVerseGroup> groups) {
    final text = [
      for (final g in groups)
        if (g.verseIndex < widget.verses.length)
          '[${g.phraseIndexes.length}] ${_label(widget.verses[g.verseIndex])}\t'
              '${widget.corpus[g.verseIndex]}',
    ].join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(uiStrings['kwicCopied']?[widget.locale] ?? 'Copied'),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    String s(String k, String fallback) =>
        uiStrings[k]?[widget.locale] ?? fallback;

    if (_busy && _index.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final groups = groupPhraseHitsByVerse(_index, _enabled, sort: _sort);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(wb, t, s, groups),
        const Divider(height: 1),
        Expanded(child: _results(wb, t, s, groups)),
      ],
    );
  }

  Widget _notice(WbColors wb, WbType t, String text) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: t.text, color: wb.mutedText)),
        ),
      );

  // ── The phrases ────────────────────────────────────────────────────

  Widget _header(WbColors wb, WbType t, String Function(String, String) s,
      List<PhraseVerseGroup> groups) {
    final base = widget.baseIndex >= 0 && widget.baseIndex < widget.verses.length
        ? widget.verses[widget.baseIndex]
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  base == null
                      ? s('analysisTabPhrases', 'Phrases')
                      : '${_label(base)} · ${_enabled.length}/'
                          '${_index.phrases.length} '
                          '${s('phraseUnit', 'phrases')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: t.text,
                    fontWeight: FontWeight.w600,
                    color: wb.text,
                  ),
                ),
              ),
              if (_index.phrases.isNotEmpty)
                WbIconTap(
                  icon: _showPhrases ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: wb.mutedText,
                  onTap: () => setState(() => _showPhrases = !_showPhrases),
                ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                IconButton(
                  tooltip: s('kwicCopy', 'Copy all'),
                  icon: const Icon(Icons.copy_all_outlined, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: groups.isEmpty ? null : () => _copy(groups),
                ),
            ],
          ),
          if (_showPhrases && _index.phrases.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              s('phraseHint', 'Tap a phrase to use it or drop it. The '
                  'number is how many verses contain it.'),
              style: TextStyle(fontSize: t.chrome, color: wb.mutedText),
            ),
            const SizedBox(height: 5),
            // Bounded: a long verse has as many phrases as it has words.
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 116),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (var i = 0; i < _index.phrases.length; i++)
                      _phraseChip(wb, t, i),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          _controls(wb, t, s, groups),
        ],
      ),
    );
  }

  Widget _phraseChip(WbColors wb, WbType t, int i) {
    final phrase = _index.phrases[i];
    final on = _enabled.contains(i);
    // Too common to have been kept at all. Showing it greyed is honest;
    // hiding it would make the phrase list not match the verse.
    final dead = !phrase.listed || phrase.verseCount == 0;
    final fg = dead
        ? wb.border
        : on
            ? wb.strongsLexical
            : wb.mutedText;
    return WbPaneChip(
      label: phrase.display,
      on: on,
      onTap: dead ? null : () => _togglePhrase(i),
      foreground: fg,
      strikeWhenOff: true,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      trailing: '${phrase.verseCount}',
    );
  }

  Widget _controls(WbColors wb, WbType t, String Function(String, String) s,
      List<PhraseVerseGroup> groups) {
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _numberField(
          wb,
          t,
          s('phraseLength', 'Len'),
          _effectiveLength,
          kPhraseLengthMin,
          kPhraseLengthMax,
          (v) {
            _length = v;
            _rescan();
          },
        ),
        // The gap is the feature, not a tolerance: it is what lets a
        // quotation that added a word still read as the same phrase.
        _numberField(
          wb,
          t,
          s('phraseGap', 'Gap'),
          _gap,
          0,
          kPhraseGapMax,
          (v) {
            _gap = v;
            _rescan();
          },
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _chip(wb, t, s('phraseSortMatches', 'Matches'),
                _sort == PhraseMatchSort.matches, () {
              setState(() => _sort = PhraseMatchSort.matches);
            }),
            const SizedBox(width: 4),
            _chip(wb, t, s('kwicSortRef', 'Reference'),
                _sort == PhraseMatchSort.reference, () {
              setState(() => _sort = PhraseMatchSort.reference);
            }),
            const SizedBox(width: 4),
            _chip(wb, t, s('phraseSortPhrase', 'Phrase'),
                _sort == PhraseMatchSort.phrase, () {
              setState(() => _sort = PhraseMatchSort.phrase);
            }),
          ],
        ),
        // Only when there is a limit to honour — a chip that is always
        // off tells the reader nothing.
        if (widget.scope != null && widget.scope!.isNotEmpty)
          _chip(
            wb,
            t,
            widget.scopeLabel?.isNotEmpty == true
                ? widget.scopeLabel!
                : s('phraseScope', 'Search limit'),
            _useScope,
            () {
              setState(() => _useScope = !_useScope);
              _rescan();
            },
          ),
        Text(
          '${groups.length} · ${_elapsedMs}ms',
          style: TextStyle(fontSize: t.chrome, color: wb.mutedText),
        ),
      ],
    );
  }

  Widget _numberField(WbColors wb, WbType t, String label, int value, int min,
      int max, void Function(int) onChange) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ',
            style: TextStyle(fontSize: t.chrome, color: wb.mutedText)),
        _stepper(wb, Icons.remove, value > min, () => onChange(value - 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Text('$value',
              style: TextStyle(
                  fontSize: t.chrome,
                  color: wb.text,
                  fontWeight: FontWeight.w700)),
        ),
        _stepper(wb, Icons.add, value < max, () => onChange(value + 1)),
      ],
    );
  }

  Widget _stepper(WbColors wb, IconData icon, bool on, VoidCallback onTap) =>
      WbIconTap(icon: icon, onTap: on ? onTap : null);

  Widget _chip(
          WbColors wb, WbType t, String label, bool on, VoidCallback onTap) =>
      WbPaneChip(label: label, on: on, onTap: onTap);

  // ── The results ────────────────────────────────────────────────────

  Widget _results(WbColors wb, WbType t, String Function(String, String) s,
      List<PhraseVerseGroup> groups) {
    if (_index.isEmpty) {
      return _notice(
        wb,
        t,
        s('phraseTooShort',
            'This verse is shorter than the phrase length. Lower it.'),
      );
    }
    if (groups.isEmpty) {
      return _notice(
        wb,
        t,
        s('phraseNoHits',
            'No other verse repeats a phrase from this one. Shorten the '
                'phrase, widen the gap, or check more phrases.'),
      );
    }

    if (_sort == PhraseMatchSort.phrase) {
      final byPhrase = groupPhraseHitsByPhrase(_index, _enabled);
      return ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: byPhrase.length,
        itemBuilder: (context, i) => _phraseBand(wb, t, s, byPhrase[i]),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: groups.length,
      itemBuilder: (context, i) {
        final g = groups[i];
        return _row(
          wb,
          t,
          verseIndex: g.verseIndex,
          count: g.phraseIndexes.length,
          ranges: g.ranges,
          rowKey: 'v${g.verseIndex}',
        );
      },
    );
  }

  /// One phrase with the verses that carry it — bwh51's third view. Not
  /// a re-sort of the verse list but the other way round the same hits.
  Widget _phraseBand(WbColors wb, WbType t, String Function(String, String) s,
      PhraseGroup group) {
    final phrase = _index.phrases[group.phraseIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          color: wb.paneAltBg,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(
            '${phrase.display} · ${group.occurrences}',
            style: TextStyle(
              fontSize: t.chrome,
              color: wb.mutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (final h in group.hits)
          _row(
            wb,
            t,
            verseIndex: h.verseIndex,
            count: h.occurrences,
            ranges: h.ranges,
            rowKey: 'p${group.phraseIndex}-${h.verseIndex}',
          ),
      ],
    );
  }

  Widget _row(
    WbColors wb,
    WbType t, {
    required int verseIndex,
    required int count,
    required List<int> ranges,
    required String rowKey,
  }) {
    if (verseIndex >= widget.verses.length) return const SizedBox.shrink();
    final v = widget.verses[verseIndex];
    final open = _expanded == rowKey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = open ? null : rowKey),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  child: Text('[$count]',
                      style: TextStyle(
                          fontSize: t.chrome, color: wb.mutedText)),
                ),
                Expanded(
                  child: Text(
                    _label(v),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: t.chrome,
                      color: wb.link,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.onOpenVerse != null)
                  WbIconTap(
                    icon: Icons.arrow_forward,
                    size: 13,
                    color: wb.mutedText,
                    onTap: () => widget.onOpenVerse!(v),
                  ),
              ],
            ),
          ),
        ),
        if (open) _expandedText(wb, t, verseIndex, ranges),
      ],
    );
  }

  /// The verse with the matched words marked — and only those. A word
  /// the gap bridged over stays dark, which is what makes a loose match
  /// visibly different from an exact one at a glance.
  Widget _expandedText(
      WbColors wb, WbType t, int verseIndex, List<int> ranges) {
    final spans = highlightPhraseRanges(widget.corpus[verseIndex], ranges);
    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 0, 8, 8),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: t.text - 1,
            height: t.lineHeight,
            color: wb.text,
            fontFamily: t.fontFamily,
          ),
          children: [
            for (final sp in spans)
              TextSpan(
                text: sp.text,
                style: sp.isHit
                    ? TextStyle(
                        color: wb.strongsLexical,
                        fontWeight: FontWeight.w700,
                        backgroundColor: wb.selectionBg,
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
