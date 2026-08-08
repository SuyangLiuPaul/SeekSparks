/// 2026-08-06 (SeekSparks): the KWIC pane — BibleWorks' help topic
/// bwh31, rebuilt on data this app owns.
///
/// Every occurrence of one Strong's number, printed one per line and
/// aligned on the keyword, so what surrounds it becomes readable as a
/// column rather than as prose. Sorting by the words to the left or the
/// right is what makes collocations group.
///
/// The concordance supplies the references; the tagged text supplies
/// which word in each verse carries the number. Loading is capped and
/// incremental — ἀγαπάω has 140-odd hits and πᾶς over 1200, and a pane
/// that fetches 1200 book files before painting anything is not a tool.
library;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/services/concordance_service.dart';
import 'package:seeksparks/services/tagged_text_service.dart';
import 'package:seeksparks/utils/kwic.dart';
import 'package:seeksparks/utils/search_scope.dart' show scopedCountLabel;
import 'package:seeksparks/utils/verse_list.dart' show applySearchLimit;
import 'package:seeksparks/widgets/wb_pane_bits.dart';

class KwicPane extends StatefulWidget {
  const KwicPane({
    super.key,
    required this.strongs,
    required this.version,
    required this.locale,
    this.scope,
    this.scopeName,
    this.onOpenRef,
  });

  /// The number under study, e.g. `G25`.
  final String strongs;

  /// Which translation's tagging to read the context from. When this
  /// version is untagged the pane says so rather than showing nothing —
  /// KJV and NASB genuinely cannot answer the question.
  final String version;

  final String locale;

  /// The active search limit, as verse keys, or null for no limit
  /// (#280). A concordance is a result list over the corpus, so it
  /// honours the scope — bwh10l draws the line at word lists that
  /// DESCRIBE a corpus, which keep their own range.
  final Set<String>? scope;

  /// What to call [scope] on screen. Null when nothing is limiting.
  final String? scopeName;

  /// Tapping a line jumps the reader there.
  final void Function(String englishBook, int chapter, int verse)? onOpenRef;

  @override
  State<KwicPane> createState() => _KwicPaneState();
}

class _KwicPaneState extends State<KwicPane> {
  /// How many references to turn into lines at once. One batch is a
  /// few book-file reads; the rest arrive when the reader asks.
  static const _batch = 60;

  KwicSort _sort = KwicSort.reference;
  List<KwicLine> _lines = const [];

  /// References inside the scope, and — bwh23's denominator — how many
  /// there are in the whole version. Printing the first without the
  /// second is what makes "64 hits" unreadable under a limit.
  int _totalRefs = 0;
  int _wholeRefs = 0;
  int _loaded = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant KwicPane old) {
    super.didUpdateWidget(old);
    if (old.strongs != widget.strongs ||
        old.version != widget.version ||
        !setEquals(old.scope, widget.scope)) {
      _reload();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _lines = const [];
      _loaded = 0;
      _totalRefs = 0;
      _wholeRefs = 0;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await ConcordanceService.lookup(widget.strongs);
      final whole = result?.refs ?? const <ConcordanceRef>[];
      final refs = applySearchLimit(whole, widget.scope,
          (r) => '${r.englishBook}-${r.chapter}-${r.verse}');
      final from = _loaded;
      final to = (from + _batch) > refs.length ? refs.length : from + _batch;

      final added = <KwicLine>[];
      for (var i = from; i < to; i++) {
        final ref = refs[i];
        final runs = await TaggedTextService.forVerse(
          version: widget.version,
          englishBook: ref.englishBook,
          chapter: ref.chapter,
          verse: ref.verse,
        );
        if (runs == null) continue;
        added.addAll(kwicLinesForVerse(
          reference: ref.label,
          runs: runs,
          strongs: widget.strongs,
        ));
      }
      if (!mounted) return;
      setState(() {
        _totalRefs = refs.length;
        _wholeRefs = whole.length;
        _loaded = to;
        _lines = [..._lines, ...added];
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The reference for one line, in the reading version's language.
  ///
  /// `KwicLine.reference` is the concordance's canonical English string;
  /// it is data, not display. [short] for the 84px column, formal for
  /// the clipboard — a pasted reference leaves the app and has to stand
  /// on its own.
  String _ref(KwicLine l, {required bool short}) =>
      ConcordanceRef.tryParse(l.reference)
          ?.display(widget.locale, widget.version, short: short) ??
      l.reference;

  void _copyAll() {
    final text = sortKwic(_lines, _sort)
        .map((l) => l.plainWith(_ref(l, short: false)))
        .join('\n');
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

    if (!TaggedTextService.supports(widget.version)) {
      return _notice(
        wb,
        t,
        s(
            'kwicUntagged',
            'This translation carries no Strong\'s tagging, so its '
                'context cannot be aligned. Switch to BSB or 和合本雅伟版.'),
      );
    }
    if (_lines.isEmpty && _busy) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_lines.isEmpty) {
      // Under a limit, "no occurrences" is a claim about the scope, not
      // about the version — and the reader needs the whole-Bible count
      // to know whether widening would help.
      final name = widget.scopeName;
      return _notice(
        wb,
        t,
        name == null || _wholeRefs == 0
            ? s('kwicNoHits', 'No occurrences in this version.')
            : s(
                    'scopeEmptyHere',
                    'Nothing inside the scope ({name}). {total} in the '
                        'whole Bible.')
                .replaceAll('{name}', name)
                .replaceAll('{total}', '$_wholeRefs'),
      );
    }

    final sorted = sortKwic(_lines, _sort);
    final collocates = kwicCollocates(_lines);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(wb, t, s, collocates),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: sorted.length + 1,
            itemBuilder: (context, i) {
              if (i == sorted.length) return _footer(wb, t, s);
              return _line(wb, t, sorted[i]);
            },
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

  Widget _header(WbColors wb, WbType t, String Function(String, String) s,
      List<({String word, int count})> collocates) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.strongs} · '
                  '${scopedCountLabel(_totalRefs, _wholeRefs)} '
                  '${s('kwicHits', 'hits')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: t.text,
                    fontWeight: FontWeight.w600,
                    color: wb.text,
                  ),
                ),
              ),
              IconButton(
                tooltip: s('kwicCopy', 'Copy all'),
                icon: const Icon(Icons.copy_all_outlined, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: _copyAll,
              ),
            ],
          ),
          if (widget.scopeName != null)
            Text(
              s('scopeOfWhole', '{total} in all — limited to {name}')
                  .replaceAll('{total}', '$_wholeRefs')
                  .replaceAll('{name}', widget.scopeName!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: t.chrome, color: wb.mutedText),
            ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: [
              for (final entry in const [
                (KwicSort.reference, 'kwicSortRef', 'Reference'),
                (KwicSort.leftContext, 'kwicSortLeft', 'Left'),
                (KwicSort.rightContext, 'kwicSortRight', 'Right'),
              ])
                _chip(
                  wb,
                  t,
                  s(entry.$2, entry.$3),
                  _sort == entry.$1,
                  () => setState(() => _sort = entry.$1),
                ),
            ],
          ),
          if (collocates.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${s('kwicCollocates', 'Occurs with')}: '
              '${collocates.map((c) => '${c.word} ${c.count}').join(' · ')}',
              style: TextStyle(fontSize: t.chrome, color: wb.mutedText),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(
          WbColors wb, WbType t, String label, bool on, VoidCallback onTap) =>
      WbPaneChip(
        label: label,
        on: on,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      );

  /// One aligned row. The keyword column is centred and fixed-ish so
  /// the eye can run down it; left context is right-aligned into it,
  /// which is the alignment that makes the whole thing legible.
  Widget _line(WbColors wb, WbType t, KwicLine l) {
    final ref = ConcordanceRef.tryParse(l.reference);
    return InkWell(
      onTap: ref == null || widget.onOpenRef == null
          ? null
          : () => widget.onOpenRef!(ref.englishBook, ref.chapter, ref.verse),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 84,
              child: Text(
                _ref(l, short: true),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: t.chrome,
                  color: wb.link,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: Text(
                l.left,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(fontSize: t.chrome, color: wb.mutedText),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                l.keyword,
                style: TextStyle(
                  fontSize: t.chrome,
                  color: wb.strongsLexical,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: Text(
                l.right,
                maxLines: 2,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(fontSize: t.chrome, color: wb.mutedText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(WbColors wb, WbType t, String Function(String, String) s) {
    if (_loaded >= _totalRefs && _totalRefs > 0) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: Center(
          child: Text(
            '${s('kwicAllShown', 'All')} $_totalRefs '
            '${s('kwicRefs', 'references')}',
            style: TextStyle(fontSize: t.chrome, color: wb.mutedText),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Center(
        child: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : TextButton(
                onPressed: _loadMore,
                child: Text(
                  '${s('kwicMore', 'Load more')} '
                  '($_loaded / $_totalRefs)',
                  style: TextStyle(fontSize: t.chrome),
                ),
              ),
      ),
    );
  }
}
