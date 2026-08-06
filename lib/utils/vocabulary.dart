/// 2026-08-07 (SeekSparks): Vocabulary Flashcards — BibleWorks help
/// topic bwh40, the Vocabulary Flashcard Module.
///
/// Every other Analysis tab in this app answers a question about the
/// TEXT. This one answers a question about the READER: which words do
/// you not yet know, and which of them are worth the trouble?
///
/// ── What bwh40 actually is, past the name ──
///
/// "Flashcards" sounds like a toy — front, back, flip. The help topic
/// spends one paragraph on flipping and the rest on the two things that
/// make it a study tool rather than a novelty:
///
///   1. **Filtering is the feature.** bwh40: "You probably will want to
///      work with a small subset of the total word list at a given
///      time." Five filters — chapter range, word-frequency range, part
///      of speech, VERSE RANGE, and learned status. The verse-range one
///      is the interesting one: it scopes the deck to the passage you
///      are about to read, which turns a 5,399-word vocabulary into the
///      forty words standing between you and Mark 1. A deck you can
///      finish before breakfast beats a complete one you never open.
///
///   2. **The Example Verse Finder.** Given the CURRENTLY FILTERED
///      list, find verses containing at least N of its words and at
///      most M words outside it. bwh40 frames this as a teacher's tool
///      ("instructors often spend a lot of time searching for example
///      verses that ... have a limited vocabulary range"), but it is
///      really the student's reward: set M to zero and it prints the
///      verses you can read right now with nothing but the words in
///      front of you. Nothing else in the program answers that. See
///      [findExampleVerses].
///
/// ── What is deliberately NOT built ──
///
///   * **Sound files.** bwh40 ships recorded Erasmian/Modern Greek and
///     Hebrew pronunciation. That audio is licensed content inside
///     BibleWorks; we may not ship it and have no substitute.
///   * **Printing to perforated card stock.** A 2003 answer to a
///     problem a phone does not have.
///   * **`.vrc`/`.vrt` import-export.** A BibleWorks-private format
///     with no readers outside BibleWorks.
///   * **The chapter-number filter.** bwh40's "chapter" is the chapter
///     of YOUR TEXTBOOK that introduces a word — every bundled entry
///     carries the placeholder 999, and the field only becomes
///     meaningful once you hand-author a list. Without user-authored
///     lists it filters nothing.
///   * **The part-of-speech filter.** Our morphology is per-TOKEN
///     (`assets/originals/*.json`), not per-lemma, so a lemma's part of
///     speech is only derivable inside a scope we have actually
///     scanned — it would be present for a chapter deck and absent for
///     a whole-corpus one. A filter that silently stops working when
///     you widen the scope is worse than no filter; this needs a
///     precomputed lemma→POS asset first.
///
/// ── Lemma identity: Strong's, not a lexeme ──
///
/// bwh40 keys a card on the BibleWorks lemma string. This app keys
/// everything on Strong's numbers, and so does its bundled lexicon, so
/// a card here is a Strong's number. That is not the same thing —
/// Strong's occasionally merges two lexemes under one number and
/// occasionally splits one across two. It is the honest choice
/// nonetheless: it is the only key for which we HAVE glosses, and
/// inventing a lexeme layer on top would put a guess between the
/// reader and the dictionary.
///
/// ── Frequency counts are measured, not quoted ──
///
/// bwh40 ships fixed frequency numbers. Ours are counted from the text
/// this app actually bundles (`assets/strongs/concordance.json`, built
/// from `assets/originals/*.json`), which is why they differ slightly
/// from any printed list — SBLGNT is not the BibleWorks BNM text. That
/// is the right trade: a number that describes the text in front of you
/// beats a rounder number describing a text you do not have.
///
/// Everything here is Flutter-free and synchronous so it can be tested
/// against the real 438,821-word tagged corpus without a widget tree.
library;

import 'dart:math' show Random;

// ── The card ────────────────────────────────────────────────────────

/// One vocabulary card: a Strong's number with everything needed to
/// show, sort and filter it.
class VocabWord {
  const VocabWord({
    required this.strongs,
    required this.lemma,
    required this.translit,
    required this.gloss,
    required this.corpusCount,
    int? scopeCount,
    this.isFunctionWord = false,
  }) : scopeCount = scopeCount ?? corpusCount;

  /// `H####` / `G####`.
  final String strongs;

  /// Dictionary form in Hebrew or Greek script — the citation form you
  /// would look up, NOT the inflected surface form in the text.
  final String lemma;

  final String translit;

  /// Short definition, already localised by the caller. The core stays
  /// out of locale handling so it can be tested without a lexicon.
  final String gloss;

  /// Occurrences in the whole bundled Bible.
  final int corpusCount;

  /// Occurrences inside the deck's scope. Equal to [corpusCount] when
  /// the scope IS the whole corpus.
  final int scopeCount;

  /// A grammatical particle rather than a content word, per the audited
  /// list in `originals_stats_service.dart`.
  ///
  /// These are NOT junk the way an English stopword is: καί and ὁ are
  /// real vocabulary to someone learning Greek, and every curriculum
  /// teaches them in week one. They are separable because by week two
  /// they are noise at the top of every frequency list.
  final bool isFunctionWord;

  bool get isHebrew => strongs.startsWith('H');

  /// Collation key — see [foldForSort]. Computed on demand rather than
  /// stored so the model stays a value.
  String get sortKey => foldForSort(lemma);

  VocabWord withScopeCount(int count) => VocabWord(
        strongs: strongs,
        lemma: lemma,
        translit: translit,
        gloss: gloss,
        corpusCount: corpusCount,
        scopeCount: count,
        isFunctionWord: isFunctionWord,
      );

  @override
  String toString() => 'VocabWord($strongs $lemma ×$corpusCount)';
}

// ── Assembling the corpus vocabulary ────────────────────────────────

/// Join the bundled concordance to the bundled lexicons to get one
/// [VocabWord] per Strong's number.
///
/// Takes already-decoded JSON rather than asset paths so the same code
/// runs in the app (via `rootBundle`) and in the corpus test (via
/// `File`). The alternative — assembly inside the service, re-done by
/// hand in the test — means the test verifies a copy of the code
/// instead of the code.
///
/// A Strong's number with no lexicon entry is dropped. There are 76 of
/// them (`G6xxx`/`G9xxx`, extended numbers used by the tagging), and a
/// card with no gloss on the back is not a card.
List<VocabWord> vocabularyFromAssets({
  required Map<String, dynamic> concordance,
  required Map<String, dynamic> hebrewLexicon,
  required Map<String, dynamic> greekLexicon,
  String locale = 'en',
  Set<String> functionWords = const <String>{},
}) {
  final out = <VocabWord>[];
  for (final entry in concordance.entries) {
    final key = entry.key;
    if (key.startsWith('_')) continue; // metadata
    final value = entry.value;
    if (value is! Map<String, dynamic>) continue;
    final isHebrew = key.startsWith('H');
    final lex = (isHebrew ? hebrewLexicon[key] : greekLexicon[key])
        as Map<String, dynamic>?;
    if (lex == null) continue;
    out.add(VocabWord(
      strongs: key,
      lemma: (lex['lemma'] ?? '').toString(),
      translit: (lex['translit'] ?? '').toString(),
      gloss: _gloss(lex, locale),
      corpusCount: (value['n'] as num?)?.toInt() ?? 0,
      isFunctionWord: functionWords.contains(key),
    ));
  }
  return out;
}

String _gloss(Map<String, dynamic> lex, String locale) {
  String at(String key) => (lex[key] ?? '').toString();
  if (locale == 'zh-Hant') {
    final zh = at('glossZhTw');
    if (zh.isNotEmpty) return zh;
  }
  if (locale.startsWith('zh')) {
    final zh = at('glossZh');
    if (zh.isNotEmpty) return zh;
  }
  return at('gloss');
}

// ── Filtering ───────────────────────────────────────────────────────

/// No upper bound. bwh40's own filter dialog uses 99999 for this; the
/// corpus maximum is 19,859 (G3588, the article), so anything past that
/// is the same thing said less clearly.
const int kNoFrequencyCeiling = 1 << 30;

enum VocabLanguage { hebrew, greek }

/// Frequency floors offered as presets — and they differ by language,
/// because the curricula do.
///
/// The temptation is a tidy ladder (100/50/20/10/5). Resist it: a
/// threshold is only worth offering if someone is actually assigned it,
/// otherwise "≥20×" is a number the reader has no way to interpret.
/// Checking the syllabi turned up no standard 20×, 25× or 30× tier in
/// either language — those are software conveniences — so they are not
/// here. What is:
///
///   * **Greek 50×** — Mounce, *Basics of Biblical Greek*: the
///     first-year target. 312 lemmas in our corpus; Mounce counts ~320.
///   * **Greek 10×** — Metzger, *Lexical Aids for Students of NT
///     Greek*. 1,130 here; Metzger lists 1,067.
///   * **Hebrew 70×** — Pratico & Van Pelt, *Basics of Biblical Hebrew
///     Grammar*, first-year target. 574 here.
///   * **Hebrew 50×** — Van Pelt & Pratico, *Vocabulary Guide*. 751
///     here against their 641, but the corpus agrees where it counts:
///     they state 50× covers ~80% of all OT tokens and ours covers
///     81.8%. The lemma counts differ because Strong's splits some
///     entries a lexicon keeps together; the coverage is the same text.
///   * **Hebrew 10×** — Landes, *Building Your Biblical Hebrew
///     Vocabulary*.
///   * **1×** — everything, hapax legomena included. Past any syllabus,
///     but it is the only honest way to say "no floor".
List<int> frequencyPresetsFor(VocabLanguage? language) {
  switch (language) {
    case VocabLanguage.greek:
      return const <int>[50, 10, 1];
    case VocabLanguage.hebrew:
      return const <int>[70, 50, 10, 1];
    case null:
      // A mixed deck spans both syllabi, so offer both ladders.
      return const <int>[70, 50, 10, 1];
  }
}

/// Which cards are in the deck. Every field is independent; the default
/// is "everything, minus what you already know".
class VocabFilter {
  const VocabFilter({
    this.minFrequency = 1,
    this.maxFrequency = kNoFrequencyCeiling,
    this.language,
    this.includeFunctionWords = true,
    this.excludeLearned = false,
    this.query = '',
  });

  /// Both bounds test [VocabWord.corpusCount], never [VocabWord
  /// .scopeCount] — deliberately.
  ///
  /// "Is this word worth learning?" is a question about the language,
  /// not about the chapter: a word occurring 60 times in the GNT earns
  /// its card whether it shows up once in Mark 1 or ten times. Testing
  /// the scope count instead would make "50×" mean something different
  /// in every scope and destroy the comparison with a syllabus, which
  /// is the only reason the preset is worth anything.
  ///
  /// The local question — "which of these actually pays off in the
  /// passage I am about to read?" — is real too, and it is answered by
  /// [VocabSort.scopeFrequency] rather than by a second filter.
  final int minFrequency;
  final int maxFrequency;

  /// `null` keeps both. Only meaningful for a whole-corpus deck; a book
  /// is either Hebrew or Greek on its own.
  final VocabLanguage? language;

  final bool includeFunctionWords;

  /// bwh40's "Exclude Learned Words" checkbox.
  ///
  /// Note this only governs the LIST. Learned words are skipped by the
  /// card cycle unconditionally — bwh40: "so it will not be displayed
  /// as you cycle through the cards" — while staying visible (greyed)
  /// in the list so you can take the mark back. See [reviewQueue].
  final bool excludeLearned;

  /// Substring match over lemma, transliteration and gloss,
  /// case-insensitively. Not a bwh40 feature; a list of 8,640 Hebrew
  /// lemmas with no way to find one in it is a list nobody searches.
  final String query;

  VocabFilter copyWith({
    int? minFrequency,
    int? maxFrequency,
    VocabLanguage? language,
    bool clearLanguage = false,
    bool? includeFunctionWords,
    bool? excludeLearned,
    String? query,
  }) =>
      VocabFilter(
        minFrequency: minFrequency ?? this.minFrequency,
        maxFrequency: maxFrequency ?? this.maxFrequency,
        language: clearLanguage ? null : (language ?? this.language),
        includeFunctionWords: includeFunctionWords ?? this.includeFunctionWords,
        excludeLearned: excludeLearned ?? this.excludeLearned,
        query: query ?? this.query,
      );

  bool accepts(VocabWord w, Set<String> learned) {
    if (w.corpusCount < minFrequency) return false;
    if (w.corpusCount > maxFrequency) return false;
    if (!includeFunctionWords && w.isFunctionWord) return false;
    if (excludeLearned && learned.contains(w.strongs)) return false;
    if (language != null) {
      final wanted = language == VocabLanguage.hebrew;
      if (w.isHebrew != wanted) return false;
    }
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      if (!w.lemma.toLowerCase().contains(q) &&
          !w.translit.toLowerCase().contains(q) &&
          !w.gloss.toLowerCase().contains(q)) {
        return false;
      }
    }
    return true;
  }
}

// ── Sorting ─────────────────────────────────────────────────────────

/// bwh40 offers alphabetical, frequency, language, chapter and random.
///
/// "Language" is dropped: it is a grouping, and [VocabFilter.language]
/// already separates the two alphabets more usefully. "Chapter" is
/// dropped with the chapter filter (see the library comment).
/// [scopeFrequency] is added, and is the one that makes a scoped deck
/// worth building — it puts the words this passage leans on at the top.
enum VocabSort { frequency, scopeFrequency, alphabetical, random }

/// Build the deck: filter, then order.
///
/// [seed] only matters for [VocabSort.random]; it is a parameter rather
/// than a fresh `Random()` so a rebuild caused by an unrelated setState
/// does not reshuffle the deck under the reader's thumb.
List<VocabWord> buildDeck({
  required Iterable<VocabWord> words,
  VocabFilter filter = const VocabFilter(),
  VocabSort sort = VocabSort.frequency,
  Set<String> learned = const <String>{},
  int seed = 0,
}) {
  final out = <VocabWord>[
    for (final w in words)
      if (filter.accepts(w, learned)) w,
  ];

  // Dart's sort is not stable, so every comparator below bottoms out in
  // the Strong's number. Without that, two words of equal frequency
  // could swap places between rebuilds and the card you were looking at
  // would move.
  switch (sort) {
    case VocabSort.frequency:
      out.sort((a, b) {
        final c = b.corpusCount.compareTo(a.corpusCount);
        if (c != 0) return c;
        return _byLemmaThenNumber(a, b);
      });
    case VocabSort.scopeFrequency:
      out.sort((a, b) {
        final c = b.scopeCount.compareTo(a.scopeCount);
        if (c != 0) return c;
        final f = b.corpusCount.compareTo(a.corpusCount);
        if (f != 0) return f;
        return _byLemmaThenNumber(a, b);
      });
    case VocabSort.alphabetical:
      out.sort(_byLemmaThenNumber);
    case VocabSort.random:
      // Sort to a known order first: `words` may arrive in any order,
      // and a shuffle of an unknown order is not reproducible from the
      // seed alone.
      out.sort(_byLemmaThenNumber);
      out.shuffle(Random(seed));
  }
  return out;
}

int _byLemmaThenNumber(VocabWord a, VocabWord b) {
  final c = a.sortKey.compareTo(b.sortKey);
  if (c != 0) return c;
  return _byStrongsNumber(a.strongs, b.strongs);
}

/// `G80` before `G100`. Plain string order would put `G100` first and
/// make the "sorted by Strong's" tiebreak look broken.
int _byStrongsNumber(String a, String b) {
  if (a.isEmpty || b.isEmpty) return a.compareTo(b);
  if (a[0] != b[0]) return a[0].compareTo(b[0]);
  final na = int.tryParse(a.substring(1));
  final nb = int.tryParse(b.substring(1));
  if (na != null && nb != null) return na.compareTo(nb);
  return a.compareTo(b);
}

/// The cards actually shown in the card cycle: the deck minus what is
/// marked learned.
///
/// Split from [buildDeck] on purpose. bwh40 greys learned words in the
/// list but skips them while cycling, which is exactly right: a word
/// you cannot see is a word you cannot un-learn, and everyone
/// eventually marks something too early.
List<VocabWord> reviewQueue(List<VocabWord> deck, Set<String> learned) =>
    learned.isEmpty
        ? deck
        : <VocabWord>[
            for (final w in deck)
              if (!learned.contains(w.strongs)) w,
          ];

// ── The drill ───────────────────────────────────────────────────────

/// One pass through a deck, where missing a card brings it back.
///
/// ── Why this is not just next/prev ──
///
/// bwh40 has no notion of getting a card right. You step through with
/// two arrow buttons and, when you decide you know a word, you press
/// "learned" to take it out. Marking is a filing action you perform on
/// the list, not an answer you give to a question — so nothing in the
/// program ever finds out which words you actually missed.
///
/// That is the gap users left over. The one substantive BibleWorks
/// forum thread on this module — #3431, "BibleWorks Vocabulary Modules
/// and Spaced Repetition Software", Dec 2008 to Jul 2009, 12 posts as
/// archived — is a handful of users exporting their vocabulary OUT of
/// the module into spaced-repetition tools, one of them (KramerK,
/// 2009-02-28) saying outright: "I think Bibleworks should replace its
/// vocab program with Anki!"
///
/// Not a stampede — five or so people, several of whom had not heard of
/// Anki before the thread. But the direction of travel is the point:
/// nobody was exporting INTO the module. Shipping the arrow buttons and
/// stopping would be rebuilding the thing they left.
///
/// ── Why it is not Anki either ──
///
/// The obvious answer is SM-2 with per-word intervals in days. That is
/// deliberately NOT what this is, because it answers a different
/// question. SM-2 optimises retention over months and needs dates,
/// a scheduler, and something to nag you; this deck is scoped to a
/// passage you are reading THIS WEEK, so the useful unit is one sitting.
/// Within a sitting, the whole of spaced repetition reduces to: a card
/// you missed comes back before you leave, and far enough away that you
/// have to recall it rather than echo it.
///
/// So there is no persistence here beyond the learned flag, and no
/// clock. Genuine cross-day scheduling is a real feature and a
/// different one; it is recorded as the next increment rather than
/// half-built into this.
class DrillQueue {
  DrillQueue(Iterable<VocabWord> cards, {int reinsertAfter = 5})
      : _queue = List<VocabWord>.of(cards),
        _total = cards.length,
        // 0 would put a missed card straight back under the reader's
        // thumb, which tests nothing.
        reinsertAfter = reinsertAfter < 1 ? 1 : reinsertAfter;

  final List<VocabWord> _queue;
  final int _total;

  /// How many cards to let past before a missed card returns.
  final int reinsertAfter;

  final Set<String> _missed = <String>{};
  final Set<String> _cleared = <String>{};

  /// The card facing the reader, or null once the drill is done.
  VocabWord? get current => _queue.isEmpty ? null : _queue.first;

  bool get isDone => _queue.isEmpty;

  /// Cards in the deck when the drill started.
  int get total => _total;

  /// Cards still to get right — includes missed cards waiting to come
  /// back round, so this can stay put while you work.
  int get remaining => _queue.length;

  /// Distinct cards answered correctly and retired.
  int get clearedCount => _cleared.length;

  /// Distinct cards missed at least once, whether or not they were
  /// later cleared. This is the set worth drilling again, which is why
  /// a card that comes good does not leave it.
  int get missedCount => _missed.length;

  Set<String> get missedStrongs => Set<String>.unmodifiable(_missed);

  /// 0..1 over cards retired, for a progress bar.
  double get progress => _total == 0 ? 1 : _cleared.length / _total;

  /// Answer the current card. Correct retires it; wrong sends it to the
  /// back of the near queue.
  void answer({required bool correct}) {
    if (_queue.isEmpty) return;
    final card = _queue.removeAt(0);
    if (correct) {
      _cleared.add(card.strongs);
      return;
    }
    _missed.add(card.strongs);
    _cleared.remove(card.strongs);
    // Re-insert `reinsertAfter` cards along, or at the end when the
    // queue is shorter than that. When it is the only card left it
    // comes straight back, which is correct — you still do not know it.
    final at = reinsertAfter < _queue.length ? reinsertAfter : _queue.length;
    _queue.insert(at, card);
  }

  /// Give up on the current card without recording an answer — bwh40's
  /// arrow buttons, kept because sometimes you just want to look.
  void skip() {
    if (_queue.length < 2) return;
    _queue.add(_queue.removeAt(0));
  }
}

// ── Scope ───────────────────────────────────────────────────────────

/// How many times each Strong's number occurs across [versesByRef],
/// whose keys are `"chapter:verse"` and whose values are that verse's
/// Strong's numbers in reading order.
///
/// This is what makes a deck scoped to a chapter or a book exact rather
/// than approximate. The bundled concordance stores per-BOOK totals
/// only, so anything narrower has to be counted from the tagged text.
Map<String, int> tallyStrongs(Map<String, List<String>> versesByRef) {
  final out = <String, int>{};
  for (final words in versesByRef.values) {
    for (final s in words) {
      if (s.isEmpty) continue;
      out[s] = (out[s] ?? 0) + 1;
    }
  }
  return out;
}

/// [versesByRef] restricted to one chapter.
Map<String, List<String>> versesInChapter(
  Map<String, List<String>> versesByRef,
  int chapter,
) =>
    <String, List<String>>{
      for (final e in versesByRef.entries)
        if (_refChapter(e.key) == chapter) e.key: e.value,
    };

int? _refChapter(String ref) {
  final i = ref.indexOf(':');
  return i <= 0 ? null : int.tryParse(ref.substring(0, i));
}

int? _refVerse(String ref) {
  final i = ref.indexOf(':');
  return i < 0 ? null : int.tryParse(ref.substring(i + 1));
}

// ── The Example Verse Finder ────────────────────────────────────────

/// One verse the finder turned up.
class ExampleVerse {
  const ExampleVerse({
    required this.chapter,
    required this.verse,
    required this.listWords,
    required this.nonListWords,
    required this.totalWords,
  });

  final int chapter;
  final int verse;

  /// How many DISTINCT known lemmas the verse exercises.
  final int listWords;

  /// How many word TOKENS the verse contains that you do not know.
  final int nonListWords;

  final int totalWords;

  /// Share of the verse's tokens you can already read, 0..1.
  double get coverage =>
      totalWords == 0 ? 0 : (totalWords - nonListWords) / totalWords;

  String get ref => '$chapter:$verse';

  @override
  String toString() => 'ExampleVerse($ref +$listWords -$nonListWords)';
}

/// bwh40's Example Finder: verses drawn only from vocabulary you know.
///
/// ── The two counts are counted differently, and that is deliberate ──
///
/// bwh40 gives the two knobs one sentence each — "the minimum number of
/// list words that each verse must contain" and "the maximum number of
/// non-list words that verses can contain" — and never says whether
/// either counts tokens or distinct lemmas. They are not the same
/// question, so they do not get the same count:
///
///   * [minListWords] counts **distinct** lemmas. It is the teacher's
///     knob — "how much of my list does this verse actually exercise?"
///     A verse repeating καί five times exercises one word, and
///     counting it as five would fill the results with verses that
///     demonstrate nothing.
///
///   * [maxNonListWords] counts **tokens**. It is the student's knob —
///     "how many times will I get stuck?" Every unknown token stops the
///     reader, including the second occurrence of the same unknown
///     word, and counting distinct lemmas here would advertise a verse
///     as readable when it is not.
///
/// The two counts coincide at bwh40's own worked example (maximum
/// non-list words = 0, i.e. "only vocabulary list words"), which is
/// presumably why the help never had to choose.
///
/// ── [known] is not the deck ──
///
/// bwh40 runs the finder over "the words that are in the current
/// Flashcard list box". Pass the deck's Strong's numbers UNION the
/// learned set, not the deck alone. With "Exclude Learned Words" on,
/// the deck is by definition the words you do NOT know, and running the
/// finder over it would score every word you have mastered as an
/// obstacle — the exact opposite of the question being asked.
///
/// Results are ordered by fewest obstacles first, then by how much of
/// the list they exercise, then canonically.
List<ExampleVerse> findExampleVerses({
  required Map<String, List<String>> versesByRef,
  required Set<String> known,
  int minListWords = 3,
  int maxNonListWords = 0,
  int limit = 100,
}) {
  if (known.isEmpty || limit <= 0) return const <ExampleVerse>[];
  final hits = <ExampleVerse>[];
  for (final entry in versesByRef.entries) {
    final chapter = _refChapter(entry.key);
    final verse = _refVerse(entry.key);
    if (chapter == null || verse == null) continue;

    final words = entry.value;
    if (words.isEmpty) continue;

    var nonList = 0;
    final listLemmas = <String>{};
    for (final s in words) {
      if (s.isEmpty) continue;
      if (known.contains(s)) {
        listLemmas.add(s);
      } else {
        nonList++;
        // Cheap exit: a verse already over budget cannot come back.
        if (nonList > maxNonListWords) break;
      }
    }
    if (nonList > maxNonListWords) continue;
    if (listLemmas.length < minListWords) continue;

    hits.add(ExampleVerse(
      chapter: chapter,
      verse: verse,
      listWords: listLemmas.length,
      nonListWords: nonList,
      totalWords: words.length,
    ));
  }

  hits.sort((a, b) {
    final c = a.nonListWords.compareTo(b.nonListWords);
    if (c != 0) return c;
    final l = b.listWords.compareTo(a.listWords);
    if (l != 0) return l;
    final ch = a.chapter.compareTo(b.chapter);
    if (ch != 0) return ch;
    return a.verse.compareTo(b.verse);
  });
  return hits.length > limit ? hits.sublist(0, limit) : hits;
}

// ── Collation ───────────────────────────────────────────────────────

/// A sort key for a Hebrew or Greek lemma that actually sorts.
///
/// Neither alphabet sorts correctly by code point, and both fail in a
/// way that is obvious the moment anyone taps "A–Z":
///
///   * **Greek.** Every letter carrying a breathing or an iota
///     subscript lives in the Extended block at U+1F00–U+1FFF, which is
///     past ALL of plain Greek. Sorted raw, ἀγάπη ("love", U+1F00)
///     lands after ὠφέλεια — the entire first half of a Greek lexicon
///     ends up at the bottom of the list.
///   * **Hebrew.** Vowel points and cantillation (U+0591–U+05C7) are
///     combining marks that sit BETWEEN the consonants they attach to,
///     so a pointed lemma sorts by its vocalisation rather than by its
///     letters — and the five final forms (ךםןףץ) each sort one place
///     before their base letter.
///
/// So: fold Greek to its base lowercase letter, drop Hebrew points,
/// normalise final forms, and discard the punctuation the lexicon uses
/// for compound headwords. Anything unrecognised is kept as-is, which
/// sorts it somewhere deterministic instead of throwing it away.
///
/// `vocabulary_corpus_test.dart` asserts this covers every character in
/// all 14,097 shipped lemmas — the map below was generated from that
/// data rather than typed out, and a lexicon update that introduced a
/// new character would otherwise silently mis-sort it.
String foldForSort(String lemma) {
  final buf = StringBuffer();
  for (final rune in lemma.runes) {
    final folded = _greekFold[rune];
    if (folded != null) {
      buf.writeCharCode(folded);
      continue;
    }
    if (_isHebrewMark(rune)) continue;
    final base = _hebrewFinals[rune];
    if (base != null) {
      buf.writeCharCode(base);
      continue;
    }
    if (_dropForSort.contains(rune)) continue;
    buf.writeCharCode(rune);
  }
  return buf.toString();
}

/// Hebrew points, accents and cantillation, plus the combining grapheme
/// joiner the WLC uses inside a handful of lemmas.
bool _isHebrewMark(int r) => (r >= 0x0591 && r <= 0x05C7) || r == 0x034F;

const Map<int, int> _hebrewFinals = <int, int>{
  0x05DA: 0x05DB, // ך → כ
  0x05DD: 0x05DE, // ם → מ
  0x05DF: 0x05E0, // ן → נ
  0x05E3: 0x05E4, // ף → פ
  0x05E5: 0x05E6, // ץ → צ
};

/// Word-internal punctuation in lexicon headwords: space, maqaf,
/// hyphen, parentheses and the right single quote used for the Hebrew
/// aleph transliteration.
const Set<int> _dropForSort = <int>{
  0x0020, 0x002D, 0x0028, 0x0029, 0x05BE, 0x2019,
};

/// Greek base letter → every form of it, over the whole Greek (U+0370)
/// and Greek Extended (U+1F00) blocks.
///
/// Generated by NFD-stripping combining marks from every letter in both
/// blocks, not from the characters that happen to appear in today's
/// lexicon. The narrower version worked and was quietly brittle: it
/// covered the 131 characters our lemmas use, so a form as ordinary as
/// ᾧ — omega with rough breathing, circumflex and iota subscript, which
/// occurs in running text but not in any bundled HEADWORD — fell
/// through unfolded and would have sorted to the bottom the day a
/// lexicon update introduced it. Covering the block costs one constant
/// and removes the class of bug.
///
/// Left unfolded on purpose: digamma, koppa, sampi, san, sho, heta and
/// yot. They are archaic letters with no modern base to fold onto, and
/// none occurs in Koine or Hebrew lemmas. Stigma DOES occur — G5516,
/// χξϛ, the numeral 666 — and folds to σ, both because it is
/// historically a στ ligature and because σ is where a reader would go
/// looking for it.
const Map<String, String> _greekFoldGroups = <String, String>{
  'α': 'ΆΑάαἀἁἂἃἄἅἆἇἈἉἊἋἌἍἎἏὰάᾀᾁᾂᾃᾄᾅᾆᾇᾈᾉᾊᾋᾌᾍᾎᾏᾰᾱᾲᾳᾴᾶᾷᾸᾹᾺΆᾼ',
  'β': 'Ββϐ',
  'γ': 'Γγ',
  'δ': 'Δδ',
  'ε': 'ΈΕέεἐἑἒἓἔἕἘἙἚἛἜἝὲέῈΈϵ',
  'ζ': 'Ζζ',
  'η': 'ΉΗήηἠἡἢἣἤἥἦἧἨἩἪἫἬἭἮἯὴήᾐᾑᾒᾓᾔᾕᾖᾗᾘᾙᾚᾛᾜᾝᾞᾟῂῃῄῆῇῊΉῌ',
  'θ': 'Θθϴϑ',
  'ι': 'ΊΐΙΪίιϊἰἱἲἳἴἵἶἷἸἹἺἻἼἽἾἿὶίῐῑῒΐῖῗῘῙῚΊ',
  'κ': 'Κκϰ',
  'λ': 'Λλ',
  'μ': 'Μμ',
  'ν': 'Νν',
  'ξ': 'Ξξ',
  'ο': 'ΌΟοόὀὁὂὃὄὅὈὉὊὋὌὍὸόῸΌ',
  'π': 'Ππϖ',
  'ρ': 'ΡρῤῥῬϱϼ',
  'σ': 'ΣςσϛϚϲϹ',
  'τ': 'Ττ',
  'υ': 'ΎΥΫΰυϋύὐὑὒὓὔὕὖὗὙὛὝὟὺύῠῡῢΰῦῧῨῩῪΎϒϓϔ',
  'φ': 'Φφϕ',
  'χ': 'Χχ',
  'ψ': 'Ψψ',
  'ω': 'ΏΩωώὠὡὢὣὤὥὦὧὨὩὪὫὬὭὮὯὼώᾠᾡᾢᾣᾤᾥᾦᾧᾨᾩᾪᾫᾬᾭᾮᾯῲῳῴῶῷῺΏῼ',
};

final Map<int, int> _greekFold = <int, int>{
  for (final e in _greekFoldGroups.entries)
    for (final r in e.value.runes) r: e.key.runes.first,
};
