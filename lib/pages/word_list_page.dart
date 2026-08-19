/// 2026-08-06 (SeekSparks): the Word List Manager — BibleWorks bwh26.
///
/// What a passage is MADE of, rather than where a word occurs. Counted
/// by Strong's number so inflections collapse into one entry, sortable
/// by frequency or — the direction BibleWorks does not offer and
/// exegesis actually wants — by rarity, so the hapax legomena surface.
///
/// Scoped to a chapter or a book. Not the whole Bible: that is 66 file
/// loads and ~700k words for a list nobody reads to the end.
///
/// 2026-08-19: and COMPARED against a second book, which is what bwh26
/// says the Word List Manager is actually for. See
/// `lib/utils/word_list_compare.dart` for the three things a naive diff
/// of two lists gets wrong, and for why the comparison is book-to-book:
/// the "occurs nowhere else in the Bible" test adds the two counts, and
/// that is only sound while the two scopes cannot overlap. Two books
/// never do; two verse ranges need not be so kind.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:seeksparks/constants/book_names.dart'
    show bookNameToEnglish, standardBookOrder;
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart' show WbType;
import 'package:seeksparks/pages/strongs_entry_page.dart';
import 'package:seeksparks/services/concordance_service.dart';
import 'package:seeksparks/services/originals_service.dart';
import 'package:seeksparks/services/strongs_service.dart';
import 'package:seeksparks/utils/app_nav.dart';
import 'package:seeksparks/utils/short_book_name.dart' show shortBookName;
import 'package:seeksparks/utils/version_mapper.dart' show localeAwareBookName;
import 'package:seeksparks/utils/word_list.dart';
import 'package:seeksparks/utils/word_list_compare.dart';

enum _Scope { chapter, book, compare }

/// Which side of a comparison a row is on. Every one of these names a
/// bucket and carries its own count in the chip, so a number here can
/// never be read as counting something else (#308).
enum _CmpFilter { all, both, onlyA, onlyB }

class WordListPage extends StatefulWidget {
  const WordListPage({
    super.key,
    required this.book,
    required this.chapter,
    required this.locale,
    required this.version,
  });

  /// Book as the reader sees it (may be localized); mapped to English
  /// for the originals lookup.
  final String book;
  final int chapter;
  final String locale;
  final String version;

  @override
  State<WordListPage> createState() => _WordListPageState();
}

class _WordListPageState extends State<WordListPage> {
  _Scope _scope = _Scope.chapter;
  WordListSort _sort = WordListSort.frequency;
  List<WordListEntry> _entries = const [];
  bool _loading = true;

  /// Compare mode. [_aBook] starts at the book in view; [_bBook] has no
  /// default, because there is no second book a reader can be assumed to
  /// have meant.
  late String _aBook = _englishBook;
  String? _bBook;
  WordComparison? _cmp;
  WordCompareSort _cmpSort = WordCompareSort.corpusRarity;
  _CmpFilter _filter = _CmpFilter.both;

  /// Restrict every bucket to words that occur nowhere else in the Bible.
  bool _nowhereOnly = false;

  /// Guards against a slower load finishing after a faster one. Two
  /// whole books is ~40k words and a 6.9 MB concordance; a reader who
  /// changes the dropdown twice would otherwise see the first answer.
  int _token = 0;

  String get _englishBook => bookNameToEnglish[widget.book] ?? widget.book;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_scope == _Scope.compare) return _loadCompare();
    final token = ++_token;
    setState(() => _loading = true);
    final words = _scope == _Scope.chapter
        ? await OriginalsService.forChapter(_englishBook, widget.chapter)
        : await OriginalsService.forBook(_englishBook);
    // Every row is a lemma, so every row needs the lexicon headword —
    // the corpus only carries a romanisation per OCCURRENCE, and the
    // Hebrew Bible carries none at all.
    final lexicon = await StrongsService.lookupAll(words.map((w) => w.strongs));
    if (!mounted || token != _token) return;
    setState(() {
      _entries = buildWordList(words, sort: _sort, lexicon: lexicon);
      _loading = false;
    });
  }

  Future<void> _loadCompare() async {
    final b = _bBook;
    if (b == null || b == _aBook) {
      setState(() {
        _cmp = null;
        _loading = false;
      });
      return;
    }
    final token = ++_token;
    setState(() => _loading = true);
    final wa = await OriginalsService.forBook(_aBook);
    final wb = await OriginalsService.forBook(b);
    final lexicon = await StrongsService.lookupAll(
        [...wa.map((w) => w.strongs), ...wb.map((w) => w.strongs)]);
    final la = buildWordList(wa, lexicon: lexicon);
    final lb = buildWordList(wb, lexicon: lexicon);
    // Corpus totals are the whole reason this mode can say "nowhere
    // else". Only `n` is read — see ConcordanceService.totalsFor.
    final totals = await ConcordanceService.totalsFor(
        [...la.map((e) => e.strongs), ...lb.map((e) => e.strongs)]);
    if (!mounted || token != _token) return;
    setState(() {
      _cmp = compareWordLists(la, lb, sort: _cmpSort, corpusTotals: totals);
      _loading = false;
    });
  }

  void _resort(WordListSort s) {
    setState(() {
      _sort = s;
      // Re-sorting a list already built is cheaper than recounting, but
      // the tie-break map lives in buildWordList, so rebuild from the
      // entries' own order to keep it deterministic.
      final copy = [..._entries];
      sortWordList(copy, s);
      _entries = copy;
    });
  }

  void _copy() {
    final s = wordListSummary(_entries);
    final head = '${_scopeLabel()}  ${s.distinct}/${s.total}';
    final body =
        _entries.map((e) => '${e.strongs}\t${e.form}\t${e.count}').join('\n');
    Clipboard.setData(ClipboardData(text: '$head\n$body'));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(uiStrings['kwicCopied']?[widget.locale] ?? 'Copied'),
      duration: const Duration(seconds: 2),
    ));
  }

  /// The rows the bucket chips count, before a bucket is chosen.
  ///
  /// "Nowhere else" is a MODIFIER and not a fifth bucket, because
  /// bwh26's own example of what a word-list comparison is for — *"all
  /// words that occur in John that do not occur anywhere else in the New
  /// Testament"* — is the two conditions AT ONCE, and a bucket cannot be
  /// combined with anything. As a modifier it also answers the question
  /// the pair was chosen for: in-both AND nowhere-else is the three
  /// words Jude and 2 Peter share with the rest of the Bible.
  List<WordComparisonRow> _pool(WordComparison c) =>
      _nowhereOnly ? c.rows.where((r) => r.nowhereElse).toList() : c.rows;

  /// Rows on screen: the pool, narrowed to the chosen side.
  List<WordComparisonRow> _visible(WordComparison c) {
    final pool = _pool(c);
    return switch (_filter) {
      _CmpFilter.all => pool,
      _CmpFilter.both =>
        pool.where((r) => r.bucket == WordCompareBucket.both).toList(),
      _CmpFilter.onlyA =>
        pool.where((r) => r.bucket == WordCompareBucket.onlyA).toList(),
      _CmpFilter.onlyB =>
        pool.where((r) => r.bucket == WordCompareBucket.onlyB).toList(),
    };
  }

  /// The four buckets, each with its own name and its own count — counted
  /// over the POOL, so a chip's number always matches the list it opens
  /// even with the modifier on (#308). One list, so the chips and the
  /// clipboard cannot disagree about what a number counted.
  List<(_CmpFilter, String, int)> _filters(WordComparison c) {
    final pool = _pool(c);
    int n(WordCompareBucket b) => pool.where((r) => r.bucket == b).length;
    return [
      (_CmpFilter.both, _s('wlCmpBoth', 'In both'), n(WordCompareBucket.both)),
      (
        _CmpFilter.onlyA,
        '${_s('wlCmpOnly', 'Only in')} ${_shortBook(_aBook)}',
        n(WordCompareBucket.onlyA)
      ),
      (
        _CmpFilter.onlyB,
        '${_s('wlCmpOnly', 'Only in')} ${_shortBook(_bBook ?? '')}',
        n(WordCompareBucket.onlyB)
      ),
      (_CmpFilter.all, _s('wlCmpAll', 'All'), pool.length),
    ];
  }

  String _filterLabel(WordComparison c) {
    final bucket = _filters(c).firstWhere((f) => f.$1 == _filter).$2;
    return _nowhereOnly
        ? '$bucket + ${_s('wlCmpNowhere', 'Nowhere else')}'
        : bucket;
  }

  void _cmpResort(WordCompareSort s) {
    final c = _cmp;
    if (c == null) return;
    setState(() {
      _cmpSort = s;
      sortComparison(c.rows, s);
    });
  }

  /// The visible rows as a pasteable table.
  ///
  /// Carries the filter's own name and the two scope sizes, because a
  /// pasted list of 51 rows says nothing about whether it is the whole
  /// comparison or the fifth of it now on screen, and the counts are
  /// unreadable without the sizes of the two books.
  void _copyCompare(WordComparison c) {
    final rows = _visible(c);
    final head = '${_scopeSize(_book(_aBook), c.distinctA, c.totalA)}\t'
        '${_scopeSize(_book(_bBook ?? ''), c.distinctB, c.totalB)}\t'
        '${_filterLabel(c)} ${rows.length}';
    final cols = 'Strong\t${_s('wordListSortAlpha', 'Word')}\t'
        '${_shortBook(_aBook)}\t${_shortBook(_bBook ?? '')}\t'
        '${_s('wlCmpBible', 'Bible')}\t${_s('wlCmpNowhere', 'Nowhere else')}';
    final body = rows
        .map((r) => '${r.strongs}\t${r.headword}\t'
            '${r.countA == 0 ? '' : r.countA}\t${r.countB == 0 ? '' : r.countB}\t'
            '${r.corpusTotal ?? ''}\t${r.nowhereElse ? 'Y' : ''}')
        .join('\n');
    Clipboard.setData(ClipboardData(text: '$head\n$cols\n$body'));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(uiStrings['kwicCopied']?[widget.locale] ?? 'Copied'),
      duration: const Duration(seconds: 2),
    ));
  }

  String _scopeLabel() {
    final book =
        localeAwareBookName(widget.book, widget.locale, widget.version);
    return _scope == _Scope.chapter ? '$book ${widget.chapter}' : book;
  }

  String _book(String english) =>
      localeAwareBookName(english, widget.locale, widget.version);

  /// The abbreviation, for the filter chips and the column heads. The
  /// formal name is right above in the two pickers, so the compact
  /// controls can carry the short form — the call bwh42 makes for its
  /// own reference columns.
  String _shortBook(String english) =>
      shortBookName(english, widget.locale, widget.version);

  String _s(String k, String fallback) =>
      uiStrings[k]?[widget.locale] ?? fallback;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = WbType.of(context);
    final compare = _scope == _Scope.compare;
    final cmp = _cmp;

    return Scaffold(
      appBar: AppBar(
        title: Text(_s('wordListTitle', 'Word List')),
        actions: [
          IconButton(
            tooltip: _s('kwicCopy', 'Copy all'),
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: compare
                ? (cmp == null ? null : () => _copyCompare(cmp))
                : (_entries.isEmpty ? null : _copy),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, box) => Column(
          children: [
            // The controls are pinned above the list, and at a large type
            // scale they stop fitting: two book pickers, five filter chips
            // and four sort chips is 505 px past a 320 × 640 phone at 40 pt.
            // A pinned block that cannot fit has to yield something, and
            // the honest thing to yield is its own pinning — it scrolls
            // internally and the list keeps the rest of the screen.
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: box.maxHeight * 0.6),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final e in [
                            (
                              _Scope.chapter,
                              'wordListScopeChapter',
                              'This chapter'
                            ),
                            (_Scope.book, 'wordListScopeBook', 'Whole book'),
                            (_Scope.compare, 'wlCmpScope', 'Compare two books'),
                          ])
                            ChoiceChip(
                              label: Text(_s(e.$2, e.$3)),
                              selected: _scope == e.$1,
                              onSelected: (_) {
                                setState(() => _scope = e.$1);
                                _load();
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (compare) ..._compareHeader(scheme, t),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: compare ? _compareBody(scheme, t) : _singleBody(scheme, t),
            ),
          ],
        ),
      ),
    );
  }

  Widget _singleBody(ColorScheme scheme, WbType t) {
    final summary = wordListSummary(_entries);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_scopeLabel()} · ${summary.distinct} '
                '${_s('wordListDistinct', 'distinct')} / ${summary.total} '
                '${_s('wordListTotal', 'words')} · ${summary.hapax} '
                '${_s('wordListHapax', 'used once')}',
                style: TextStyle(fontSize: t.scaled(13), color: scheme.outline),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final e in [
                    (WordListSort.frequency, 'wordListSortFreq', 'Frequency'),
                    (WordListSort.rarity, 'wordListSortRare', 'Rarest'),
                    (WordListSort.number, 'wordListSortNum', 'Number'),
                    (
                      WordListSort.alphabetical,
                      'wordListSortAlpha',
                      'Alphabetical'
                    ),
                  ])
                    ChoiceChip(
                      label: Text(_s(e.$2, e.$3)),
                      selected: _sort == e.$1,
                      onSelected: (_) => _resort(e.$1),
                    ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _entries.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _s('wordListNone',
                              'No original-language data for this passage.'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.outline),
                        ),
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _entries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) =>
                          _row(_entries[i], summary.total, scheme, t),
                    ),
        ),
      ],
    );
  }

  // ── Compare mode ──────────────────────────────────────────────────
  //
  // The two pickers are BOOKS. A chapter picker would be two more
  // controls and would break the one claim this mode makes that nothing
  // else in the app can: "nowhere else in the Bible" adds the two counts
  // and compares them with the corpus total, which is only sound while
  // the scopes cannot overlap.

  /// One book's size, both counts named. Two bare numbers over a slash
  /// would leave the reader to guess which was the vocabulary and which
  /// the length (#308) — and the length is the one that makes a pair of
  /// row counts readable at all.
  String _scopeSize(String book, int distinct, int total) =>
      '$book $distinct ${_s('wordListDistinct', 'distinct')} / '
      '$total ${_s('wordListTotal', 'words')}';

  List<Widget> _compareHeader(ColorScheme scheme, WbType t) {
    final cmp = _cmp;
    final labelStyle = TextStyle(fontSize: t.scaled(13), color: scheme.outline);
    return [
      LayoutBuilder(
        builder: (context, box) => Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _bookPicker(_aBook, (v) {
              setState(() => _aBook = v);
              _load();
            }, t, box.maxWidth),
            Text(_s('wlCmpWith', 'with'), style: labelStyle),
            _bookPicker(_bBook, (v) {
              setState(() => _bBook = v);
              _load();
            }, t, box.maxWidth),
          ],
        ),
      ),
      if (cmp != null) ...[
        const SizedBox(height: 8),
        // Both totals, always. Jude is 458 words and 2 Peter 1,099, so a
        // pair of raw counts on a row is not the tie it looks like; the
        // reader needs the denominators in view to read them at all.
        Text(
          '${_scopeSize(_book(_aBook), cmp.distinctA, cmp.totalA)}'
          '   ·   '
          '${_scopeSize(_book(_bBook ?? ''), cmp.distinctB, cmp.totalB)}',
          style: labelStyle,
        ),
        if (!cmp.sharesLanguage) ...[
          const SizedBox(height: 6),
          Text(
              _s(
                  'wlCmpLangs',
                  'These two books are not in the same '
                      'original language, so their numbers cannot overlap.'),
              style: TextStyle(fontSize: t.scaled(12), color: scheme.error)),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in _filters(cmp))
              ChoiceChip(
                label: Text('${e.$2} ${e.$3}'),
                selected: _filter == e.$1,
                onSelected: (_) => setState(() => _filter = e.$1),
              ),
            // Shaped as a switch, not as a fifth bucket, because it
            // narrows whichever bucket is open rather than replacing it.
            FilterChip(
              label: Text(
                  '${_s('wlCmpNowhere', 'Nowhere else')} ${cmp.nowhereElseCount}'),
              selected: _nowhereOnly,
              onSelected: (v) => setState(() => _nowhereOnly = v),
            ),
          ],
        ),
        if (_nowhereOnly) ...[
          const SizedBox(height: 6),
          Text(
            _s(
                'wlCmpNowhereHint',
                'Every occurrence of these words in the Bible is inside '
                    'these two books.'),
            style: TextStyle(fontSize: t.scaled(12), color: scheme.outline),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in [
              (
                WordCompareSort.corpusRarity,
                'wlCmpSortRare',
                'Rarest in the Bible'
              ),
              (WordCompareSort.combined, 'wlCmpSortCombined', 'Combined count'),
              (WordCompareSort.number, 'wordListSortNum', 'Number'),
              (
                WordCompareSort.alphabetical,
                'wordListSortAlpha',
                'Alphabetical'
              ),
            ])
              ChoiceChip(
                label: Text(_s(e.$2, e.$3)),
                selected: _cmpSort == e.$1,
                onSelected: (_) => _cmpResort(e.$1),
              ),
          ],
        ),
      ],
    ];
  }

  /// A book picker sized to the SPACE, not to its longest entry.
  ///
  /// A bare [DropdownButton] takes the intrinsic width of its widest
  /// item — here 帖撒罗尼迦前书 out of all 66 — and keeps it whatever the
  /// button is showing. At 40 pt on a 320 px phone that is 444 px inside
  /// a 288 px row, which does not shrink and does not clip: it throws.
  /// So the width is bounded by what the row actually has, and
  /// [isExpanded] makes the button honour it. The two then wrap onto
  /// separate lines when the type is large, which is the right answer at
  /// that size anyway.
  Widget _bookPicker(
      String? value, ValueChanged<String> onPick, WbType t, double avail) {
    final style = TextStyle(
      fontSize: t.scaled(14),
      color: Theme.of(context).colorScheme.onSurface,
    );
    return SizedBox(
      width: avail.isFinite && avail < t.scaled(200) ? avail : t.scaled(200),
      child: DropdownButton<String>(
        value: value,
        isDense: true,
        isExpanded: true,
        hint: Text(_s('wlCmpChoose', 'Choose a book'), style: style),
        style: style,
        // The menu row may be as wide as it likes; only the BUTTON is
        // bounded. Faded rather than ellipsised, because a CJK book name
        // cut before a … is unreadable either way and the … is a lie
        // about where the name ends (#297).
        selectedItemBuilder: (context) => [
          for (final b in standardBookOrder)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(_book(b),
                  style: style, softWrap: false, overflow: TextOverflow.fade),
            ),
        ],
        items: [
          for (final b in standardBookOrder)
            DropdownMenuItem(value: b, child: Text(_book(b))),
        ],
        onChanged: (v) {
          if (v != null) onPick(v);
        },
      ),
    );
  }

  Widget _compareBody(ColorScheme scheme, WbType t) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final cmp = _cmp;
    if (cmp == null) {
      final same = _bBook != null && _bBook == _aBook;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            same
                ? _s('wlCmpSameBook',
                    'Those are the same book. Choose two different ones.')
                : _s(
                    'wlCmpIntro',
                    'Pick two books to see which original-language words '
                        'they share, which belong to only one of them, and '
                        'which occur nowhere else in the Bible.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.outline, fontSize: t.scaled(14)),
          ),
        ),
      );
    }
    final rows = _visible(cmp);
    // One width for the three numeric columns, computed once so the
    // heads and the rows cannot drift apart. It scales with the type —
    // a reader at 40 pt must not get a four-digit count in a box built
    // for 17 pt — but never past a fifth of the row, because three
    // fixed cells wider than the screen do not shrink, they throw.
    return LayoutBuilder(builder: (context, box) {
      final cell = _min(t.scaled(56), (box.maxWidth - 32) / 5);
      return Column(
        children: [
          _cmpColumnHeads(scheme, t, cell),
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _s('wlCmpEmptyBucket', 'No words in this group.'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.outline),
                      ),
                    ),
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) =>
                        _cmpRow(rows[i], scheme, t, cell),
                  ),
          ),
        ],
      );
    });
  }

  static double _min(double a, double b) => a < b ? a : b;

  /// Named columns, because three bare numbers on a row would otherwise
  /// leave the reader to guess which book each belongs to.
  Widget _cmpColumnHeads(ColorScheme scheme, WbType t, double cell) {
    final style = TextStyle(
      fontSize: t.scaled(11),
      color: scheme.outline,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          const Expanded(child: SizedBox()),
          _numCell(_shortBook(_aBook), style, cell),
          _numCell(_shortBook(_bBook ?? ''), style, cell),
          _numCell(_s('wlCmpBible', 'Bible'), style, cell),
        ],
      ),
    );
  }

  /// One column of numbers. Same width for the head and every row, so
  /// the columns stay straight; wraps rather than clips.
  Widget _numCell(String text, TextStyle style, double cell) => SizedBox(
        width: cell,
        child: Text(text, style: style, textAlign: TextAlign.right),
      );

  Widget _cmpRow(
      WordComparisonRow r, ColorScheme scheme, WbType t, double cell) {
    final meta = <String>[r.strongs];
    if (r.lemmaTranslit != null) meta.add(r.lemmaTranslit!);
    // Two books inflect the same lemma differently, and the difference is
    // worth seeing: it is the evidence that the shared row is a lemma and
    // not a coincidence of spelling.
    if (r.formA != null && r.formB != null && r.formA != r.formB) {
      meta.add('${r.formA} / ${r.formB}');
    } else if (r.formA != null && r.formA != r.headword) {
      meta.add(r.formA!);
    } else if (r.formB != null && r.formB != r.headword) {
      meta.add(r.formB!);
    }
    final numStyle = TextStyle(fontSize: t.scaled(14));
    return InkWell(
      onTap: () => pushPage(StrongsEntryPage(number: r.strongs)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.headword,
                      style: TextStyle(fontSize: t.scaledOriginal(17))),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      style: TextStyle(
                          fontSize: t.scaled(12), color: scheme.outline),
                      children: [
                        TextSpan(text: meta.join(' · ')),
                        // The claim, not the identity: colour AND words,
                        // so the marking survives a colour-blind reader
                        // and never has to be looked up in a legend.
                        if (r.nowhereElse)
                          TextSpan(
                            text: ' · ${_s('wlCmpNowhere', 'nowhere else')}',
                            style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // An em dash rather than a 0: the word is not rare here, it
            // is absent, and a zero in a frequency column reads as a
            // count that was taken.
            _numCell(r.countA == 0 ? '—' : '${r.countA}', numStyle, cell),
            _numCell(r.countB == 0 ? '—' : '${r.countB}', numStyle, cell),
            _numCell(
              r.corpusTotal?.toString() ?? '—',
              numStyle.copyWith(color: scheme.outline),
              cell,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(WordListEntry e, int total, ColorScheme scheme, WbType t) {
    // A bar relative to the commonest word would make everything after
    // the top few invisible; relative to the total makes the long tail
    // legible, which is where the interesting words are.
    final share = total == 0 ? 0.0 : e.count / total;
    return ListTile(
      dense: true,
      onTap: () => pushPage(StrongsEntryPage(number: e.strongs)),
      title: Row(
        children: [
          Expanded(
            child: Text(e.form,
                style: TextStyle(fontSize: t.scaledOriginal(17)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Text('${e.count}',
              style: TextStyle(
                fontSize: t.scaled(14),
                fontWeight: FontWeight.w600,
                color: e.isHapax ? scheme.primary : scheme.onSurface,
              )),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The headline is the form the reader will meet on the page;
          // this line says what that form IS. Both the lemma and its
          // romanisation come from the lexicon, so they always describe
          // the same word — the form's own romanisation would not.
          // The lemma carries its own size: it is pointed Hebrew or
          // accented Greek sitting in a line of Latin metadata, and at
          // this line's size the points would be a smudge. See
          // WbMetrics.originalFloor.
          Text.rich(
            TextSpan(
              style: TextStyle(fontSize: t.scaled(12), color: scheme.outline),
              children: [
                TextSpan(text: e.strongs),
                if (e.lemma != null && e.lemma != e.form)
                  TextSpan(
                    text: ' · ${e.lemma!}',
                    style: TextStyle(fontSize: t.scaledOriginal(15)),
                  ),
                if (e.lemmaTranslit != null)
                  TextSpan(text: ' · ${e.lemmaTranslit!}'),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: share.clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}
