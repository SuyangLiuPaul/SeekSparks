/// 2026-08-06 (SeekSparks): the Related Verses pane — BibleWorks help
/// topic bwh50, laid out for a pane instead of a window.
///
/// BibleWorks gives this tool three side-by-side columns: the words
/// down the left, the hits in the middle, the text on the right. That
/// needs about 900 px, and the Analysis pane is 320–560. So the columns
/// become bands stacked down the pane, and the third column — the one
/// that shows you WHY a verse came back — is folded into the hit list:
/// tap a result and its text opens underneath with the shared words
/// marked. On a narrow pane that reads better than three columns would,
/// because the verse text sits directly under the reference it belongs
/// to instead of across the window from it.
///
/// The words themselves are chips in a Wrap rather than BibleWorks'
/// scrolling checkbox list — same two states (checked, weighted), a
/// third of the vertical space.
///
/// All the thinking is in `utils/related_verses.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/utils/related_verses.dart';
import 'package:seeksparks/utils/short_book_name.dart';

class RelatedVersesPane extends StatefulWidget {
  const RelatedVersesPane({
    super.key,
    required this.corpus,
    required this.verses,
    required this.baseIndex,
    required this.locale,
    this.onOpenVerse,
  });

  /// Sanitized verse text, word boundaries intact, parallel to
  /// [verses] and in canonical order — `MainProvider.wordKeys`.
  final List<String> corpus;

  /// The loaded corpus, for turning a hit's index into a reference.
  final List<Verse> verses;

  /// Which verse to find relatives of.
  final int baseIndex;

  final String locale;

  /// Jump the reader to a hit.
  final void Function(Verse verse)? onOpenVerse;

  @override
  State<RelatedVersesPane> createState() => _RelatedVersesPaneState();
}

class _RelatedVersesPaneState extends State<RelatedVersesPane> {
  RelatedVersesIndex _index = RelatedVersesIndex.empty;
  Set<String> _enabled = <String>{};
  final Set<String> _emphasized = <String>{};
  final List<String> _extraTerms = <String>[];
  final TextEditingController _addCtl = TextEditingController();

  /// Null means "follow the checked-word count", which is what
  /// BibleWorks does until you touch the dropdown.
  int? _threshold;
  RelatedVersesSort _sort = RelatedVersesSort.hits;
  int? _expanded;
  bool _busy = false;
  int _elapsedMs = 0;

  int get _effectiveThreshold =>
      _threshold ?? defaultRelatedThreshold(_enabled.length);

  @override
  void initState() {
    super.initState();
    _rescan();
  }

  @override
  void didUpdateWidget(covariant RelatedVersesPane old) {
    super.didUpdateWidget(old);
    if (old.baseIndex != widget.baseIndex ||
        !identical(old.corpus, widget.corpus)) {
      // A different verse is a different question: the reader's word
      // choices belonged to the old one.
      _extraTerms.clear();
      _emphasized.clear();
      _threshold = null;
      _expanded = null;
      _rescan();
    }
  }

  @override
  void dispose() {
    _addCtl.dispose();
    super.dispose();
  }

  /// Re-read the corpus. The only slow step — about a tenth of a second
  /// over a whole Bible — so it happens on a frame boundary, letting
  /// the spinner paint first rather than freezing on a dead pane.
  Future<void> _rescan() async {
    setState(() => _busy = true);
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    final sw = Stopwatch()..start();
    final ix = buildRelatedVersesIndex(
      corpus: widget.corpus,
      baseIndex: widget.baseIndex,
      extraTerms: _extraTerms,
    );
    sw.stop();
    if (!mounted) return;
    setState(() {
      _index = ix;
      // A word the reader typed in is one they mean; it starts checked
      // even if it is common enough that the default would drop it.
      _enabled = defaultEnabledTerms(ix)
        ..addAll(ix.terms.where((t) => !t.fromBaseVerse).map((t) => t.term));
      _emphasized.removeWhere((t) => !_enabled.contains(t));
      _elapsedMs = sw.elapsedMilliseconds;
      _busy = false;
    });
  }

  void _toggle(String term) {
    setState(() {
      if (_enabled.remove(term)) {
        _emphasized.remove(term);
      } else {
        _enabled.add(term);
      }
      _expanded = null;
    });
  }

  void _toggleEmphasis(String term) {
    setState(() {
      if (!_enabled.contains(term)) _enabled.add(term);
      if (!_emphasized.remove(term)) _emphasized.add(term);
      _expanded = null;
    });
  }

  void _addWord(String raw) {
    final w = raw.trim();
    if (w.isEmpty) return;
    _addCtl.clear();
    _extraTerms.add(w);
    _rescan();
  }

  List<RelatedVerseHit> get _hits => scoreRelatedVerses(
        index: _index,
        enabled: _enabled,
        emphasized: _emphasized,
        threshold: _effectiveThreshold,
        sort: _sort,
      );

  String _label(Verse v) =>
      '${shortBookName(v.book, widget.locale)} ${v.chapter}:${v.verseLabel}';

  void _copy(List<RelatedVerseHit> hits) {
    final text = [
      for (final h in hits)
        if (h.verseIndex < widget.verses.length)
          '[${h.hits}] ${_label(widget.verses[h.verseIndex])}\t'
              '${widget.corpus[h.verseIndex]}',
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
    if (_index.isEmpty) {
      return _notice(
          wb, t, s('relatedNoWords', 'This verse has no words to match on.'));
    }

    final hits = _hits;
    final bands = _sort == RelatedVersesSort.hits
        ? groupRelatedByHits(hits)
        : <({int hits, List<RelatedVerseHit> verses})>[
            (hits: 0, verses: hits)
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(wb, t, s, hits),
        const Divider(height: 1),
        Expanded(
          child: hits.isEmpty
              ? _notice(
                  wb,
                  t,
                  s('relatedNoHits',
                      'No verse shares that many words. Lower the '
                          'threshold, or check more words.'))
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: bands.length,
                  itemBuilder: (context, i) => _band(wb, t, s, bands[i]),
                ),
        ),
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

  // ── The words ──────────────────────────────────────────────────────

  Widget _header(WbColors wb, WbType t, String Function(String, String) s,
      List<RelatedVerseHit> hits) {
    final base = widget.baseIndex < widget.verses.length
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
                      ? s('analysisTabRelated', 'Related')
                      : '${_label(base)} · ${_enabled.length}/'
                          '${_index.terms.length} ${s('relatedWords', 'words')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: t.text,
                    fontWeight: FontWeight.w600,
                    color: wb.text,
                  ),
                ),
              ),
              if (_busy)
                const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else
                IconButton(
                  tooltip: s('kwicCopy', 'Copy all'),
                  icon: const Icon(Icons.copy_all_outlined, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: hits.isEmpty ? null : () => _copy(hits),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            s('relatedWordsHint',
                'Tap a word to use it or drop it; hold to weight it ×3.'),
            style: TextStyle(fontSize: t.chrome, color: wb.mutedText),
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final term in _index.terms) _wordChip(wb, t, term),
            ],
          ),
          const SizedBox(height: 6),
          _addField(wb, t, s),
          const SizedBox(height: 6),
          _controls(wb, t, s, hits),
        ],
      ),
    );
  }

  Widget _wordChip(WbColors wb, WbType t, RelatedTerm term) {
    final on = _enabled.contains(term.term);
    final weighted = _emphasized.contains(term.term);
    final fg = weighted
        ? wb.strongsGrammar
        : on
            ? wb.strongsLexical
            : wb.mutedText;
    return InkWell(
      onTap: () => _toggle(term.term),
      onLongPress: () => _toggleEmphasis(term.term),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: on ? wb.selectionBg : Colors.transparent,
          border: Border.all(color: on ? fg : wb.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              term.term,
              style: TextStyle(
                fontSize: t.chrome,
                color: fg,
                fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                decoration: on ? null : TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(width: 4),
            // How much of the Bible has this word. The number is most of
            // what tells a reader whether checking it is worth anything.
            Text(
              weighted ? '×3' : '${term.documentFrequency}',
              style: TextStyle(
                fontSize: t.chrome - 1.5,
                color: weighted ? wb.strongsGrammar : wb.mutedText,
                fontWeight: weighted ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addField(WbColors wb, WbType t, String Function(String, String) s) {
    return SizedBox(
      height: 28,
      child: TextField(
        controller: _addCtl,
        onSubmitted: _addWord,
        style: TextStyle(fontSize: t.chrome, color: wb.text),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          hintText: s('relatedAddWord', 'Add a word not in the verse…'),
          hintStyle: TextStyle(fontSize: t.chrome, color: wb.mutedText),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: wb.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: wb.border),
          ),
        ),
      ),
    );
  }

  Widget _controls(WbColors wb, WbType t, String Function(String, String) s,
      List<RelatedVerseHit> hits) {
    final maxThreshold = _enabled.isEmpty ? 1 : _enabled.length;
    // A Wrap, not a Row: threshold + two sort chips + the status line
    // need about 360 px, and the pane starts at 320. On a narrow pane
    // the sort chips drop to a second line rather than the whole row
    // overflowing.
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${s('relatedThreshold', 'Min')} ',
                style: TextStyle(fontSize: t.chrome, color: wb.mutedText)),
            _stepper(wb, t, Icons.remove, _effectiveThreshold > 1,
                () => setState(() {
                      _threshold = _effectiveThreshold - 1;
                      _expanded = null;
                    })),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text('$_effectiveThreshold',
                  style: TextStyle(
                      fontSize: t.chrome,
                      color: wb.text,
                      fontWeight: FontWeight.w700)),
            ),
            _stepper(wb, t, Icons.add, _effectiveThreshold < maxThreshold,
                () => setState(() {
                      _threshold = _effectiveThreshold + 1;
                      _expanded = null;
                    })),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _chip(wb, t, s('relatedSortHits', 'Hits'),
                _sort == RelatedVersesSort.hits, () {
              setState(() => _sort = RelatedVersesSort.hits);
            }),
            const SizedBox(width: 4),
            _chip(wb, t, s('kwicSortRef', 'Reference'),
                _sort == RelatedVersesSort.reference, () {
              setState(() => _sort = RelatedVersesSort.reference);
            }),
          ],
        ),
        Text(
          '${hits.length} · ${_elapsedMs}ms',
          style: TextStyle(fontSize: t.chrome - 1, color: wb.mutedText),
        ),
      ],
    );
  }

  Widget _stepper(WbColors wb, WbType t, IconData icon, bool on,
          VoidCallback onTap) =>
      InkWell(
        onTap: on ? onTap : null,
        borderRadius: BorderRadius.circular(3),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(icon, size: 14, color: on ? wb.link : wb.border),
        ),
      );

  Widget _chip(
          WbColors wb, WbType t, String label, bool on, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: on ? wb.selectionBg : Colors.transparent,
            border: Border.all(color: on ? wb.strongsLexical : wb.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: t.chrome,
              color: on ? wb.strongsLexical : wb.mutedText,
              fontWeight: on ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      );

  // ── The hits ───────────────────────────────────────────────────────

  Widget _band(WbColors wb, WbType t, String Function(String, String) s,
      ({int hits, List<RelatedVerseHit> verses}) band) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (band.hits > 0)
          Container(
            width: double.infinity,
            color: wb.paneAltBg,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Text(
              '${band.hits} ${s('relatedHitsInVerse', 'shared words')}',
              style: TextStyle(
                fontSize: t.chrome,
                color: wb.mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        for (final h in band.verses) _row(wb, t, h),
      ],
    );
  }

  Widget _row(WbColors wb, WbType t, RelatedVerseHit h) {
    if (h.verseIndex >= widget.verses.length) return const SizedBox.shrink();
    final v = widget.verses[h.verseIndex];
    final open = _expanded == h.verseIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = open ? null : h.verseIndex),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  child: Text('[${h.hits}]',
                      style: TextStyle(
                          fontSize: t.chrome - 1, color: wb.mutedText)),
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
                  InkWell(
                    onTap: () => widget.onOpenVerse!(v),
                    borderRadius: BorderRadius.circular(3),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(Icons.arrow_forward,
                          size: 13, color: wb.mutedText),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (open) _expandedText(wb, t, h),
      ],
    );
  }

  /// The verse, with the words it shares with the base verse marked.
  /// This is the part that makes the number in brackets checkable — a
  /// hit you cannot see the reason for is just an assertion.
  Widget _expandedText(WbColors wb, WbType t, RelatedVerseHit h) {
    final spans =
        highlightRelatedTerms(widget.corpus[h.verseIndex], h.matchedTerms.toSet());
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
