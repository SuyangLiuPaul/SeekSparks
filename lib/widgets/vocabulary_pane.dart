/// 2026-08-07 (SeekSparks): the Vocabulary Flashcard pane — BibleWorks
/// help topic bwh40, laid out for a pane instead of a window.
///
/// ── Three modes, because bwh40 is three activities ──
///
/// Read the topic and the module is not "a flashcard": it is a list
/// builder, a card cycler and an Example Verse Finder that happen to
/// share a word list. The list builder is where nearly all the topic's
/// text goes — frequency range, language, exclude learned — and it is
/// the part that makes the tool worth anything, because a deck of the
/// right 300 words is a term's work and a deck of all 14,039 is a
/// museum. So `Words`, `Drill` and `Read` are three bodies over one
/// deck rather than one screen with a mode switch buried in it.
///
/// `Read` is the mode a naive reading of "flashcard module" would never
/// produce, and it is the reason the feature is here: it answers "given
/// what I know, what can I actually sit down and read?" — which is the
/// only question a vocabulary list exists to answer.
///
/// ── What the scope selector is for ──
///
/// The deck defaults to the chapter you are looking at. That is the
/// case bwh40's verse-range filter serves and the one a reader is in:
/// you are about to read Mark 1 and you want the words in it, sorted by
/// how often they turn up *there*. Book and All widen it. See
/// `services/vocabulary_service.dart` for why those three and not an
/// arbitrary range.
///
/// All the thinking is in `utils/vocabulary.dart`; this pane chooses
/// defaults and paints.
library;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/original_word.dart';
import 'package:seeksparks/services/originals_service.dart';
import 'package:seeksparks/services/vocabulary_service.dart';
import 'package:seeksparks/services/vocabulary_store.dart';
import 'package:seeksparks/utils/vocabulary.dart';

enum VocabMode { list, drill, read }

class VocabularyPane extends StatefulWidget {
  const VocabularyPane({
    super.key,
    required this.englishBook,
    required this.chapter,
    required this.locale,
    this.onOpenVerse,
  });

  final String englishBook;
  final int chapter;
  final String locale;

  /// Jump the reader to an example verse in the book being studied.
  final void Function(int chapter, int verse)? onOpenVerse;

  @override
  State<VocabularyPane> createState() => _VocabularyPaneState();
}

class _VocabularyPaneState extends State<VocabularyPane> {
  VocabScope _scope = VocabScope.chapter;
  VocabMode _mode = VocabMode.list;

  List<VocabWord> _words = const <VocabWord>[];
  List<VocabWord> _deck = const <VocabWord>[];
  Map<String, List<OriginalWord>> _bookText =
      const <String, List<OriginalWord>>{};
  Set<String> _learned = <String>{};
  bool _loading = true;

  int _minFrequency = 1;
  bool _includeFunctionWords = false;
  bool _hideLearned = false;
  VocabSort _sort = VocabSort.scopeFrequency;
  String _query = '';

  String? _expanded;

  DrillQueue? _drill;
  bool _flipped = false;

  /// bwh40 shows the lemma and asks for the meaning. Going the other way
  /// — gloss first, recall the Greek — is the direction that gets you
  /// writing rather than only reading.
  ///
  /// It is also the module's best-attested missing feature: forum thread
  /// #3431, richardsugg 2009-03-04, "You want to see the English word
  /// first and then give the Greek. BW will only do Greek first" — he
  /// ended up writing an external converter to get it. It costs one
  /// bool here, so it is here.
  bool _glossFirst = false;

  int _minListWords = 3;
  int _maxNonListWords = 0;
  List<ExampleVerse> _examples = const <ExampleVerse>[];

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant VocabularyPane old) {
    super.didUpdateWidget(old);
    // A new chapter is a new deck only when the deck is chapter-scoped;
    // rebuilding a corpus deck because the reader scrolled would throw
    // away a drill for nothing.
    final bookChanged = old.englishBook != widget.englishBook;
    final chapterChanged = old.chapter != widget.chapter;
    if (bookChanged ||
        (chapterChanged && _scope == VocabScope.chapter) ||
        old.locale != widget.locale) {
      _load();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final learned = await VocabularyStore.loadLearned();
    final words = await VocabularyService.wordsForScope(
      scope: _scope,
      englishBook: widget.englishBook,
      chapter: widget.chapter,
      locale: widget.locale,
    );
    final text = await OriginalsService.versesOfBook(widget.englishBook);
    if (!mounted) return;
    setState(() {
      _learned = learned;
      _words = words;
      _bookText = text;
      _loading = false;
      // A corpus deck with no floor is 5,399 cards, which is not a deck.
      // Chapter and book decks are already small enough to show whole.
      final presets = frequencyPresetsFor(
          words.isEmpty ? null : (words.first.isHebrew
              ? VocabLanguage.hebrew
              : VocabLanguage.greek));
      _minFrequency =
          _scope == VocabScope.corpus && presets.isNotEmpty ? presets.first : 1;
      _sort = _scope == VocabScope.corpus
          ? VocabSort.frequency
          : VocabSort.scopeFrequency;
      _drill = null;
      _expanded = null;
    });
    _recompute();
  }

  VocabLanguage? get _language {
    for (final w in _words) {
      return w.isHebrew ? VocabLanguage.hebrew : VocabLanguage.greek;
    }
    return null;
  }

  VocabFilter get _filter => VocabFilter(
        minFrequency: _minFrequency,
        includeFunctionWords: _includeFunctionWords,
        excludeLearned: _hideLearned,
        query: _query,
      );

  /// The deck is memoised rather than rebuilt in `build`, because
  /// [VocabSort.random] must not reshuffle every time the pane repaints
  /// and a corpus deck is several thousand words to sort.
  void _recompute() {
    setState(() {
      _deck = buildDeck(
        words: _words,
        filter: _filter,
        sort: _sort,
        learned: _learned,
      );
    });
    _findExamples();
  }

  /// The finder runs over the current BOOK whatever the deck's scope is.
  ///
  /// A corpus-scoped search would mean loading all 66 assets to answer
  /// a question about what you can read next, and the honest answer to
  /// "what can I read?" while you are sitting in Mark is a verse in
  /// Mark. Widening this is a real feature; it needs a precomputed
  /// index, not 47 MB of JSON at a keystroke.
  void _findExamples() {
    if (_mode != VocabMode.read) return;
    final byRef = <String, List<String>>{
      for (final e in _bookText.entries)
        e.key: <String>[
          for (final w in e.value)
            if (w.strongs.isNotEmpty) w.strongs,
        ],
    };
    // Deck ∪ learned: with "hide learned" on, the deck is by definition
    // what you do NOT know, and scoring mastered words as obstacles is
    // the opposite of the question. See findExampleVerses.
    final known = <String>{
      for (final w in _deck) w.strongs,
      ..._learned,
    };
    setState(() {
      _examples = findExampleVerses(
        versesByRef: byRef,
        known: known,
        minListWords: _minListWords,
        maxNonListWords: _maxNonListWords,
        limit: 300,
      );
    });
  }

  Future<void> _toggleLearned(String strongs) async {
    setState(() {
      if (!_learned.remove(strongs)) _learned.add(strongs);
    });
    await VocabularyStore.saveLearned(_learned);
    _recompute();
  }

  void _startDrill() {
    setState(() {
      _drill = DrillQueue(reviewQueue(_deck, _learned));
      _flipped = false;
    });
  }

  void _answer({required bool correct}) {
    setState(() {
      _drill?.answer(correct: correct);
      _flipped = false;
    });
  }

  String _s(String key, String fallback) =>
      uiStrings[key]?[widget.locale] ?? fallback;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_words.isEmpty) {
      return _notice(
        wb,
        t,
        _s('vocabNoOriginals',
            'No tagged original-language text for this book yet.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(wb, t),
        const Divider(height: 1),
        Expanded(
          child: switch (_mode) {
            VocabMode.list => _wordList(wb, t),
            VocabMode.drill => _drillBody(wb, t),
            VocabMode.read => _readBody(wb, t),
          },
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

  // ── Header ─────────────────────────────────────────────────────────

  Widget _header(WbColors wb, WbType t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final m in VocabMode.values) ...[
                _chip(wb, t, _modeLabel(m), _mode == m, () {
                  setState(() => _mode = m);
                  if (m == VocabMode.read) _findExamples();
                }),
                const SizedBox(width: 4),
              ],
              const Spacer(),
              Text(
                '${_deck.length}/${_words.length}',
                style: TextStyle(fontSize: t.chrome, color: wb.mutedText),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final sc in VocabScope.values)
                _chip(wb, t, _scopeLabel(sc), _scope == sc, () {
                  if (_scope == sc) return;
                  setState(() => _scope = sc);
                  _load();
                }),
              const SizedBox(width: 6),
              for (final f in frequencyPresetsFor(_language))
                _chip(wb, t, f == 1 ? _s('vocabFreqAll', 'All') : '≥$f×',
                    _minFrequency == f, () {
                  setState(() => _minFrequency = f);
                  _recompute();
                }),
            ],
          ),
          if (_mode == VocabMode.list) ...[
            const SizedBox(height: 5),
            _listControls(wb, t),
          ],
        ],
      ),
    );
  }

  Widget _listControls(WbColors wb, WbType t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final s in VocabSort.values)
              if (s != VocabSort.scopeFrequency || _scope != VocabScope.corpus)
                _chip(wb, t, _sortLabel(s), _sort == s, () {
                  setState(() => _sort = s);
                  _recompute();
                }),
            const SizedBox(width: 6),
            // The article and καί are the top of every frequency list and
            // the last thing anyone needs a card for; off by default,
            // but they are real vocabulary so they stay reachable.
            _chip(wb, t, _s('vocabParticles', 'Particles'),
                _includeFunctionWords, () {
              setState(() => _includeFunctionWords = !_includeFunctionWords);
              _recompute();
            }),
            _chip(wb, t, _s('vocabHideLearned', 'Hide learned'), _hideLearned,
                () {
              setState(() => _hideLearned = !_hideLearned);
              _recompute();
            }),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 28,
          child: TextField(
            controller: _searchController,
            style: TextStyle(fontSize: t.chrome, color: wb.text),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              hintText: _s('vocabSearch', 'Find a word'),
              hintStyle: TextStyle(fontSize: t.chrome, color: wb.mutedText),
              prefixIcon: Icon(Icons.search, size: 14, color: wb.mutedText),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 26, minHeight: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: wb.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: wb.border),
              ),
            ),
            onChanged: (v) {
              _query = v;
              _recompute();
            },
          ),
        ),
      ],
    );
  }

  String _modeLabel(VocabMode m) => switch (m) {
        VocabMode.list => _s('vocabModeList', 'Words'),
        VocabMode.drill => _s('vocabModeDrill', 'Drill'),
        VocabMode.read => _s('vocabModeRead', 'Read'),
      };

  String _scopeLabel(VocabScope s) => switch (s) {
        VocabScope.chapter => _s('vocabScopeChapter', 'Chapter'),
        VocabScope.book => _s('vocabScopeBook', 'Book'),
        VocabScope.corpus => _s('vocabScopeCorpus', 'All'),
      };

  String _sortLabel(VocabSort s) => switch (s) {
        VocabSort.frequency => _s('vocabSortCorpus', 'Corpus'),
        VocabSort.scopeFrequency => _s('vocabSortHere', 'Here'),
        VocabSort.alphabetical => _s('vocabSortAlpha', 'A–Z'),
        VocabSort.random => _s('vocabSortShuffle', 'Shuffle'),
      };

  // ── Words ──────────────────────────────────────────────────────────

  Widget _wordList(WbColors wb, WbType t) {
    if (_deck.isEmpty) {
      return _notice(
        wb,
        t,
        _s('vocabEmpty',
            'No words match. Lower the frequency floor or widen the scope.'),
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: _deck.length,
      itemBuilder: (context, i) => _wordRow(wb, t, _deck[i]),
    );
  }

  Widget _wordRow(WbColors wb, WbType t, VocabWord w) {
    final learned = _learned.contains(w.strongs);
    final open = _expanded == w.strongs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = open ? null : w.strongs),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    // The count that matters is the one you sorted by.
                    '${_sort == VocabSort.scopeFrequency && w.scopeCount > 0 ? w.scopeCount : w.corpusCount}',
                    style:
                        TextStyle(fontSize: t.chrome - 1, color: wb.mutedText),
                  ),
                ),
                SizedBox(
                  width: 92,
                  child: Text(
                    w.lemma,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection:
                        w.isHebrew ? TextDirection.rtl : TextDirection.ltr,
                    style: TextStyle(
                      fontSize: t.original,
                      color: learned ? wb.mutedText : wb.strongsLexical,
                      fontWeight: FontWeight.w600,
                      decoration: learned ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    w.gloss,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: t.chrome,
                      color: learned ? wb.border : wb.text,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _toggleLearned(w.strongs),
                  borderRadius: BorderRadius.circular(3),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Icon(
                      learned ? Icons.check_circle : Icons.circle_outlined,
                      size: 14,
                      color: learned ? wb.link : wb.border,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (open) _wordDetail(wb, t, w),
      ],
    );
  }

  Widget _wordDetail(WbColors wb, WbType t, VocabWord w) => Container(
        width: double.infinity,
        color: wb.paneAltBg,
        padding: const EdgeInsets.fromLTRB(42, 4, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${w.strongs} · ${w.translit}',
              style: TextStyle(fontSize: t.chrome - 1, color: wb.mutedText),
            ),
            const SizedBox(height: 2),
            Text(
              w.scopeCount > 0
                  ? '${w.scopeCount}× ${_s('vocabHere', 'here')} · '
                      '${w.corpusCount}× ${_s('vocabInAll', 'in all')}'
                  : '${w.corpusCount}× ${_s('vocabInAll', 'in all')}',
              style: TextStyle(fontSize: t.chrome - 1, color: wb.mutedText),
            ),
            const SizedBox(height: 3),
            Text(w.gloss,
                style: TextStyle(fontSize: t.chrome, color: wb.text)),
          ],
        ),
      );

  // ── Drill ──────────────────────────────────────────────────────────

  Widget _drillBody(WbColors wb, WbType t) {
    final drill = _drill;
    if (drill == null) {
      final pending = reviewQueue(_deck, _learned).length;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$pending',
              style: TextStyle(
                  fontSize: t.text * 2,
                  fontWeight: FontWeight.w300,
                  color: wb.text),
            ),
            Text(_s('vocabCardsToGo', 'cards to go'),
                style: TextStyle(fontSize: t.chrome, color: wb.mutedText)),
            const SizedBox(height: 12),
            _chip(wb, t, _s('vocabGlossFirst', 'Gloss first'), _glossFirst,
                () => setState(() => _glossFirst = !_glossFirst)),
            const SizedBox(height: 12),
            if (pending > 0)
              TextButton(
                onPressed: _startDrill,
                child: Text(_s('vocabDrillStart', 'Start drill')),
              )
            else
              Text(
                _s('vocabAllLearned',
                    'Every word in this deck is marked learned.'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: t.chrome, color: wb.mutedText),
              ),
          ],
        ),
      );
    }

    final card = drill.current;
    if (card == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.done_all, size: 28, color: wb.link),
            const SizedBox(height: 8),
            Text(
              '${drill.total - drill.missedCount}/${drill.total} '
              '${_s('vocabFirstTime', 'first time')}',
              style: TextStyle(fontSize: t.text, color: wb.text),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _startDrill,
              child: Text(_s('vocabDrillRestart', 'Go again')),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        LinearProgressIndicator(
          value: drill.progress,
          minHeight: 2,
          backgroundColor: wb.border,
        ),
        Expanded(
          child: InkWell(
            onTap: () => setState(() => _flipped = !_flipped),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _cardFace(wb, t, card),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () => _answer(correct: false),
                child: Text(_s('vocabDrillMissed', 'Missed'),
                    style: TextStyle(fontSize: t.chrome, color: wb.mutedText)),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _drill?.skip();
                  _flipped = false;
                }),
                child: Text(_s('vocabDrillSkip', 'Skip'),
                    style: TextStyle(fontSize: t.chrome, color: wb.mutedText)),
              ),
              TextButton(
                onPressed: () => _answer(correct: true),
                child: Text(_s('vocabDrillKnew', 'Knew it'),
                    style: TextStyle(fontSize: t.chrome, color: wb.link)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cardFace(WbColors wb, WbType t, VocabWord card) {
    // The front is one thing and the back is everything, so that a flip
    // is a reveal rather than a second puzzle.
    final showLemma = _flipped || !_glossFirst;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLemma)
          Text(
            card.lemma,
            textAlign: TextAlign.center,
            textDirection:
                card.isHebrew ? TextDirection.rtl : TextDirection.ltr,
            style: TextStyle(
              fontSize: t.original * 1.9,
              color: wb.strongsLexical,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (_flipped || _glossFirst) ...[
          const SizedBox(height: 10),
          Text(
            card.gloss,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: t.text, color: wb.text),
          ),
        ],
        if (_flipped) ...[
          const SizedBox(height: 8),
          Text(
            '${card.translit} · ${card.strongs} · ${card.corpusCount}×',
            style: TextStyle(fontSize: t.chrome - 1, color: wb.mutedText),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => _toggleLearned(card.strongs),
            icon: Icon(
              _learned.contains(card.strongs)
                  ? Icons.check_circle
                  : Icons.circle_outlined,
              size: 14,
            ),
            label: Text(_s('vocabMarkLearned', 'Learned'),
                style: TextStyle(fontSize: t.chrome)),
          ),
        ] else ...[
          const SizedBox(height: 14),
          Text(_s('vocabTapReveal', 'Tap to reveal'),
              style: TextStyle(fontSize: t.chrome, color: wb.mutedText)),
        ],
      ],
    );
  }

  // ── Read ───────────────────────────────────────────────────────────

  Widget _readBody(WbColors wb, WbType t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _stepperField(wb, t, _s('vocabMinList', 'Uses'), _minListWords, 1,
                  12, (v) {
                _minListWords = v;
                _findExamples();
              }),
              _stepperField(
                  wb, t, _s('vocabMaxUnknown', 'Unknown'), _maxNonListWords, 0,
                  10, (v) {
                _maxNonListWords = v;
                _findExamples();
              }),
              Text(
                '${_examples.length}',
                style: TextStyle(fontSize: t.chrome - 1, color: wb.mutedText),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _examples.isEmpty
              ? _notice(
                  wb,
                  t,
                  _s(
                      'vocabReadEmpty',
                      'No verse in this book is readable with this deck yet. '
                          'Ask for fewer list words, or allow an unknown word '
                          'or two.'),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _examples.length,
                  itemBuilder: (context, i) => _exampleRow(wb, t, _examples[i]),
                ),
        ),
      ],
    );
  }

  Widget _exampleRow(WbColors wb, WbType t, ExampleVerse ex) {
    final words = _bookText[ex.ref] ?? const <OriginalWord>[];
    final known = <String>{for (final w in _deck) w.strongs, ..._learned};
    final hebrew = words.isNotEmpty && words.first.strongs.startsWith('H');
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: widget.onOpenVerse == null
                    ? null
                    : () => widget.onOpenVerse!(ex.chapter, ex.verse),
                child: Text(
                  ex.ref,
                  style: TextStyle(
                    fontSize: t.chrome,
                    color: wb.link,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${ex.listWords} · ${(ex.coverage * 100).round()}%',
                style: TextStyle(fontSize: t.chrome - 1, color: wb.mutedText),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // The words you cannot read yet are dimmed rather than hidden,
          // so a verse with one obstacle in it shows you exactly which
          // word to look up before you start.
          Directionality(
            textDirection: hebrew ? TextDirection.rtl : TextDirection.ltr,
            child: Wrap(
              spacing: 5,
              runSpacing: 2,
              children: [
                for (final w in words)
                  Text(
                    w.text,
                    style: TextStyle(
                      fontSize: t.original,
                      color: known.contains(w.strongs) ? wb.text : wb.border,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Small shared bits ──────────────────────────────────────────────

  Widget _stepperField(WbColors wb, WbType t, String label, int value, int min,
      int max, void Function(int) onChange) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ',
            style: TextStyle(fontSize: t.chrome, color: wb.mutedText)),
        _stepper(wb, Icons.remove, value > min,
            () => setState(() => onChange(value - 1))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Text('$value',
              style: TextStyle(
                  fontSize: t.chrome,
                  color: wb.text,
                  fontWeight: FontWeight.w700)),
        ),
        _stepper(wb, Icons.add, value < max,
            () => setState(() => onChange(value + 1))),
      ],
    );
  }

  Widget _stepper(WbColors wb, IconData icon, bool on, VoidCallback onTap) =>
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: t.chrome,
              color: on ? wb.strongsLexical : wb.mutedText,
              fontWeight: on ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      );
}
