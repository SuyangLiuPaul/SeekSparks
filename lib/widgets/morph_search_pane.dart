/// 2026-08-07 (SeekSparks): morphological search — BibleWorks' help
/// topic bwh17 and its Graphical Search Engine, rebuilt on the codes
/// this app already ships.
///
/// Until now every original-language question here had to start from a
/// word: a Strong's number, a lemma, a phrase. This pane starts from a
/// *form* — "every aorist imperative", "every Niphal participle" —
/// which is the class of question a grammar exercise actually asks and
/// the largest thing SeekSparks could not do.
///
/// The interaction is faceted rather than syntactic. BibleWorks makes
/// you type `V?AAD` and tells you afterwards whether it matched
/// anything; here every value carries the number of words it would
/// bring back, computed in the same pass as the search, so a query can
/// never be silently built into a dead end. That count is the whole
/// design: it turns morphology from something you must already know
/// into something you can explore.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/book_groups.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/services/morph_search_service.dart';
import 'package:seeksparks/utils/ketiv_qere.dart'
    show ketivQereLabel;
import 'package:seeksparks/utils/morph_construction.dart';
import 'package:seeksparks/utils/morph_query.dart';
import 'package:seeksparks/utils/morphology.dart';
import 'package:seeksparks/utils/short_book_name.dart';
import 'package:seeksparks/widgets/wb_pane_bits.dart';

class MorphSearchPane extends StatefulWidget {
  const MorphSearchPane({
    super.key,
    required this.englishBook,
    required this.chapter,
    required this.locale,
    required this.version,
    this.seedCode,
    this.onOpenRef,
  });

  final String englishBook;
  final int chapter;
  final String locale;

  /// The reading version — decides the language of the hit references.
  /// `MorphHit.book` is canonical English because the morphology corpus
  /// is, whatever translation the reader has open.
  final String version;

  /// The morphology code of the word the reader is pointing at, if any.
  /// Offered as a starting point rather than applied automatically —
  /// pinning all eight features of whatever the pointer last crossed
  /// would leave the pane showing one hit and no explanation.
  final String? seedCode;

  final void Function(String englishBook, int chapter, int verse)? onOpenRef;

  @override
  State<MorphSearchPane> createState() => _MorphSearchPaneState();
}

class _MorphSearchPaneState extends State<MorphSearchPane> {
  MorphScope _scope = MorphScope.book;
  late MorphQuery _query;

  // bwh17's agreement, as far as one pane can carry it: the reader has
  // already built the FIRST form above; this is the second, and what
  // must hold between them. Off until a part of speech is chosen, so the
  // pane opens exactly as it did.
  Set<String> _secondPos = <String>{};
  Set<MorphSlot> _agree = <MorphSlot>{};
  bool _agreeLemma = false;
  int _agreeGap = 0;

  bool get _isConstruction => _secondPos.isNotEmpty;

  MorphConstruction get _construction => MorphConstruction(
        terms: [
          ConstructionTerm(query: _query),
          ConstructionTerm(
            query: MorphQuery(
              scheme: _query.scheme,
              aramaic: _query.aramaic,
              constraints: {MorphSlot.pos: _secondPos},
            ),
            gapMax: _agreeGap,
          ),
        ],
        agreements: [
          if (_agree.isNotEmpty || _agreeLemma)
            AgreementRule(a: 0, b: 1, features: _agree, lemma: _agreeLemma),
        ],
      );
  MorphSearchResult? _result;
  bool _busy = false;

  /// Async runs are cheap but not instant, and a reader clicking through
  /// facets can start three before the first returns. Only the newest
  /// result may be shown.
  int _run = 0;

  @override
  void initState() {
    super.initState();
    _query = MorphQuery(scheme: _schemeForBook(widget.englishBook));
    _search();
  }

  @override
  void didUpdateWidget(MorphSearchPane old) {
    super.didUpdateWidget(old);
    final scheme = _schemeForBook(widget.englishBook);
    if (scheme != _query.scheme) {
      // Crossing the testament line invalidates every constraint: the
      // two schemes share almost no letters.
      _query = MorphQuery(scheme: scheme);
      _secondPos = <String>{};
      _agree = <MorphSlot>{};
      _agreeLemma = false;
      _search();
    } else if (widget.englishBook != old.englishBook ||
        (_scope == MorphScope.chapter && widget.chapter != old.chapter)) {
      _search();
    }
  }

  static MorphScheme _schemeForBook(String book) =>
      canonicalNtBooks.contains(book)
          ? MorphScheme.greek
          : MorphScheme.semitic;

  Future<void> _search() async {
    final token = ++_run;
    setState(() => _busy = true);
    final books = MorphSearchService.booksFor(
        _scope, widget.englishBook, _query.scheme);
    final chapter = _scope == MorphScope.chapter ? widget.chapter : null;
    final kq = context.read<AppSettings>().ketivQereSearchScope;
    final result = _isConstruction
        ? await MorphSearchService.runConstruction(_construction,
            books: books, chapter: chapter, ketivQere: kq)
        : await MorphSearchService.run(_query,
            books: books, chapter: chapter, ketivQere: kq);
    if (!mounted || token != _run) return;
    setState(() {
      _result = result;
      _busy = false;
    });
  }

  void _apply(MorphQuery next) {
    setState(() => _query = next);
    _search();
  }

  void _applyAgreement(VoidCallback mutate) {
    setState(mutate);
    _search();
  }

  void _seedFromWord() {
    final w = MorphSearchService.parse(widget.seedCode);
    if (w == null) return;
    _apply(MorphQuery.fromWord(w));
  }

  String _s(String key, String fallback) =>
      uiStrings[key]?[widget.locale] ?? fallback;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(wb, t),
        Divider(height: 1, thickness: 1, color: wb.border),
        Expanded(child: _body(wb, t)),
      ],
    );
  }

  // ── Header: scope, seed, and the query as it stands ────────────────

  Widget _header(WbColors wb, WbType t) {
    final result = _result;
    final seed = MorphSearchService.parse(widget.seedCode);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final sc in MorphScope.values)
                _chip(wb, t, _scopeLabel(sc), _scope == sc, () {
                  if (_scope == sc) return;
                  setState(() => _scope = sc);
                  _search();
                }),
              const SizedBox(width: 6),
              if (seed != null && seed.scheme == _query.scheme)
                _chip(wb, t, _s('morphSeed', 'This word'), false,
                    _seedFromWord),
              if (!_query.isEmpty)
                _chip(wb, t, _s('morphClear', 'Clear'), false,
                    () => _apply(_query.cleared)),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(
                  _query.describe(widget.locale) ??
                      _s('morphAnyForm', 'Any form'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: t.text,
                    color: _query.isEmpty ? wb.mutedText : wb.strongsGrammar,
                    fontWeight:
                        _query.isEmpty ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (_busy)
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: wb.mutedText,
                  ),
                )
              else if (result != null)
                Text(
                  '${result.total} / ${result.scanned}',
                  style: TextStyle(fontSize: t.chrome, color: wb.mutedText),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _scopeLabel(MorphScope s) => switch (s) {
        MorphScope.chapter => _s('vocabScopeChapter', 'Chapter'),
        MorphScope.book => _s('vocabScopeBook', 'Book'),
        MorphScope.testament => _query.scheme == MorphScheme.greek
            ? _s('morphScopeNt', 'NT')
            : _s('morphScopeOt', 'OT'),
      };

  // ── Body: the facets, then the hits ────────────────────────────────

  Widget _body(WbColors wb, WbType t) {
    final result = _result;
    if (result == null) {
      return const SizedBox.shrink();
    }
    if (result.scanned == 0) {
      // Nothing was even eligible, which is a different failure from a
      // query that matched nothing — coverage is still rolling out and
      // "no hits" would read as an answer rather than as an absence.
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _s('morphNoOriginals',
              'This book has no tagged original text to search.'),
          style: TextStyle(fontSize: t.text, color: wb.mutedText),
        ),
      );
    }
    // Two scroll regions, not one list. A Greek query offers eight
    // features, which is more than a 700 px pane can show above the
    // results — and a faceted search whose results are below the fold
    // is just a form. The builder gets at most 45% of the height and
    // scrolls within it; the hits always own the rest.
    return LayoutBuilder(
      builder: (context, box) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: box.maxHeight * 0.45),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              shrinkWrap: true,
              children: [
                _slotRow(wb, t, MorphSlot.pos, result.facets),
                for (final slot in _query.activeSlots())
                  _slotRow(wb, t, slot, result.facets),
                _readingRow(wb, t),
                _agreementRow(wb, t),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: wb.border),
          Expanded(
            child: result.total == 0
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _s('morphNoHits',
                          'No word in this range has that form.'),
                      style:
                          TextStyle(fontSize: t.text, color: wb.mutedText),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
                    children: [
                      for (final hit in result.hits) _hitRow(wb, t, hit),
                      if (result.truncated)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _s('morphMore', 'Showing the first {n}.')
                                .replaceAll('{n}', '${result.hits.length}'),
                            style: TextStyle(
                                fontSize: t.chrome, color: wb.mutedText),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// One feature and every value it can take, each carrying the number
  /// of words choosing it would return.
  ///
  /// A value that would return nothing is dropped rather than disabled:
  /// the Semitic tables list 27 binyanim and a given chapter uses six,
  /// so showing all of them would bury the six that matter. A value the
  /// reader has already chosen always stays, so a selection can never
  /// become unclickable.
  Widget _slotRow(
      WbColors wb, WbType t, MorphSlot slot, MorphFacets facets) {
    final chosen = _query.valuesFor(slot);
    final pos = chosen.isEmpty && slot != MorphSlot.pos
        ? (_query.valuesFor(MorphSlot.pos).toList()..sort())
        : <String>[];
    final options = <String>[];
    for (final p in slot == MorphSlot.pos
        ? const ['']
        : (pos.isEmpty ? morphPartsOfSpeech(_query.scheme) : pos)) {
      for (final v in morphSlotOptions(_query.scheme, p, slot,
          aramaic: _query.aramaic)) {
        if (!options.contains(v)) options.add(v);
      }
    }
    final live = [
      for (final v in options)
        if (facets.countOf(slot, v) > 0 || chosen.contains(v)) v,
    ];
    if (live.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            morphSlotName(slot, widget.locale),
            style: TextStyle(
              fontSize: t.chrome,
              color: wb.mutedText,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 3),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final v in live)
                _valueChip(wb, t, slot, v, facets.countOf(slot, v),
                    chosen.contains(v)),
            ],
          ),
        ],
      ),
    );
  }

  /// bwh17's Qere/Kethib search codes, as a row of their own.
  ///
  /// Last, and only for the Semitic scheme: the Masoretic apparatus has
  /// nothing to say about Greek, and a row of two chips that can never
  /// return anything is worse than no row.
  ///
  /// No counts on these chips, unlike every other row. The facets are
  /// tallied from parsed morphology codes and the reading is not one —
  /// see `MorphQuery.readings` — so a number here would either be a
  /// second tally with different rules or a confident zero. A chip that
  /// says nothing is honest; a chip that says 0 is not.
  Widget _readingRow(WbColors wb, WbType t) {
    if (_query.scheme != MorphScheme.semitic) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _s('morphReadingSlot', 'Masoretic reading'),
            style: TextStyle(
              fontSize: t.chrome,
              color: wb.mutedText,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 3),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final r in const ['k', 'q'])
                WbPaneChip(
                  label: ketivQereLabel(r, widget.locale) ?? r,
                  on: _query.readings.contains(r),
                  onTap: () => _apply(_query.toggledReading(r)),
                  foreground: _query.readings.contains(r)
                      ? wb.strongsGrammar
                      : wb.text,
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// bwh17's agreement, as far as one pane can carry it.
  ///
  /// The reader has already built the first form in the rows above.
  /// This adds the SECOND — a part of speech is enough to be useful and
  /// keeps the pane one column wide — plus how far away it may sit and
  /// what must hold between the two.
  ///
  /// The agreement chips are the point, and they are not feature
  /// filters: "same gender" is not "masculine", and running the query
  /// once per gender is a different question that also returns the
  /// disagreeing pairs. Choosing no part of speech leaves the pane
  /// exactly as it was, so nothing here costs a reader who does not want
  /// it.
  Widget _agreementRow(WbColors wb, WbType t) {
    final poss = morphPartsOfSpeech(_query.scheme);
    if (poss.isEmpty) return const SizedBox.shrink();
    // Case is Greek-only and state is Semitic-only; person is shared.
    // Offering a feature the scheme cannot express would be offering a
    // rule that can only ever refuse.
    final features = <MorphSlot>[
      MorphSlot.gender,
      MorphSlot.number,
      if (_query.scheme == MorphScheme.greek) MorphSlot.grammaticalCase,
      MorphSlot.person,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _s('morphAgreementSlot', 'With a second word'),
            style: TextStyle(
              fontSize: t.chrome,
              color: wb.mutedText,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 3),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final p in poss)
                WbPaneChip(
                  // Same helper the part-of-speech row above uses, so
                  // the two lists cannot end up named differently.
                  label: morphSlotLabel(_query.scheme, p, MorphSlot.pos, p,
                          widget.locale, aramaic: _query.aramaic) ??
                      p,
                  on: _secondPos.contains(p),
                  onTap: () => _applyAgreement(() {
                    if (!_secondPos.remove(p)) _secondPos.add(p);
                    if (_secondPos.isEmpty) {
                      _agree = <MorphSlot>{};
                      _agreeLemma = false;
                    }
                  }),
                  foreground:
                      _secondPos.contains(p) ? wb.strongsGrammar : wb.text,
                ),
            ],
          ),
          if (_isConstruction) ...[
            const SizedBox(height: 5),
            Text(
              _s('morphAgreeingIn', 'agreeing in'),
              style: TextStyle(
                fontSize: t.chrome,
                color: wb.mutedText,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 3),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final f in features)
                  WbPaneChip(
                    label: morphSlotName(f, widget.locale),
                    on: _agree.contains(f),
                    onTap: () => _applyAgreement(() {
                      if (!_agree.remove(f)) _agree.add(f);
                    }),
                    foreground:
                        _agree.contains(f) ? wb.strongsGrammar : wb.text,
                  ),
                // Lemma agreement is a different axis from the feature
                // chips beside it — it is how you find a figura
                // etymologica (מוֹת תָּמוּת, "dying you shall die")
                // without naming the root.
                WbPaneChip(
                  label: _s('morphAgreeLemma', 'same root'),
                  on: _agreeLemma,
                  onTap: () =>
                      _applyAgreement(() => _agreeLemma = !_agreeLemma),
                  foreground: _agreeLemma ? wb.strongsGrammar : wb.text,
                ),
                for (final g in const [0, 2, 5])
                  WbPaneChip(
                    label: g == 0
                        ? _s('morphGapAdjacent', 'next to it')
                        : _s('morphGapWithin', 'within {n}')
                            .replaceAll('{n}', '$g'),
                    on: _agreeGap == g,
                    onTap: () => _applyAgreement(() => _agreeGap = g),
                    foreground: _agreeGap == g ? wb.strongsGrammar : wb.text,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _valueChip(WbColors wb, WbType t, MorphSlot slot, String value,
      int count, bool on) {
    final label = morphSlotLabel(
          _query.scheme,
          (_query.valuesFor(MorphSlot.pos).toList()..sort()).firstOrNull ?? '',
          slot,
          value,
          widget.locale,
          aramaic: _query.aramaic,
        ) ??
        value;
    // The accent is [WbColors.strongsGrammar], not the lexical green the
    // other panes use: these chips ARE grammar, and the workbench prints
    // a morphology code in that colour everywhere else.
    return WbPaneChip(
      label: label,
      on: on,
      onTap: () => _apply(_query.toggled(slot, value)),
      foreground: on ? wb.strongsGrammar : wb.text,
      trailing: '$count',
    );
  }

  Widget _hitRow(WbColors wb, WbType t, MorphHit hit) {
    final rtl = hit.parsed.scheme == MorphScheme.semitic;
    final matched =
        describeMorphologyAt(hit.parsed, hit.morphemeIndex, widget.locale);
    final whole = hit.parsed.morphemes.length > 1
        ? describeMorphology(hit.parsed.raw, widget.locale)
        : null;
    return InkWell(
      onTap: widget.onOpenRef == null
          ? null
          : () => widget.onOpenRef!(hit.book, hit.chapter, hit.verse),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${shortBookName(hit.book, widget.locale, widget.version)} '
                  '${hit.chapter}:${hit.verse}',
                  style: TextStyle(fontSize: t.chrome, color: wb.link),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hit.word.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection:
                        rtl ? TextDirection.rtl : TextDirection.ltr,
                    style: TextStyle(
                      fontSize: t.original,
                      color: wb.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (matched != null)
              Text(
                matched,
                style: TextStyle(
                  fontSize: t.chrome,
                  color: wb.strongsGrammar,
                  height: 1.3,
                ),
              ),
            // On a stacked word, say what the rest of it is — otherwise
            // a hit on the verb inside `HC/Vqv2mp/Sp3fs` looks like the
            // search ignored the two morphemes around it.
            if (whole != null)
              Text(
                whole,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: t.chrome,
                  color: wb.mutedText,
                  height: 1.3,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(
          WbColors wb, WbType t, String label, bool on, VoidCallback onTap) =>
      WbPaneChip(label: label, on: on, onTap: onTap);
}
