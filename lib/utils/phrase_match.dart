/// 2026-08-07 (SeekSparks): Phrase Matching — BibleWorks help topic
/// bwh51, the Phrase Matching Tool (PMT).
///
/// The Related Verses Tool shipped here a day earlier (bwh50,
/// `related_verses.dart`) asks: which verses share the most WORDS with
/// this one? That is a bag of words — Genesis 1:1 and a verse using
/// "beginning", "God", "created", "heaven" and "earth" in any order and
/// any arrangement score identically. It is the right question for
/// finding verses about the same subject.
///
/// It is the wrong question for finding QUOTATION. When Hebrews quotes
/// Jeremiah, or Matthew quotes Isaiah, or one Synoptic reworks another,
/// what survives is not a vocabulary overlap — it is a run of words in
/// order. A bag of words cannot tell "thus says the LORD of hosts" from
/// a verse that happens to contain all five of those words scattered
/// across a sentence. Word order is the entire evidence, and PMT is the
/// tool that keeps it.
///
/// So: chop the base verse into every overlapping run of N words, then
/// find the other verses that contain those runs, in order.
///
/// ── What the help topic says that a naive build would get wrong ──
///
///   1. **The gap is the feature, not a tolerance knob.** An exact
///      N-word substring search finds almost nothing, because quotation
///      is never verbatim: a translator inserts a word, a writer drops
///      the article, the LXX and the MT differ by a particle. bwh51
///      spells out three things that must all count as a match at gap
///      G: the phrase itself; the phrase with ONE of its words dropped;
///      and the phrase with 1..G words inserted between two of its
///      words. [_PhraseScanner] implements exactly those three as one
///      model — an order-preserving alignment with at most one dropped
///      phrase word and at most G verse tokens skipped between
///      consecutive matched words. Note "maximum SINGLE gap": G bounds
///      each step, it is not a budget spent across the phrase.
///
///   2. **One of the three result views is a different data shape.**
///      Sorting by book order and sorting by "verse with most phrases"
///      are two orderings of one list. "Grouped by most frequently used
///      phrases" is not — it is phrase → verses, with the phrase's own
///      total in brackets. A result modelled as `List<VerseHit>` cannot
///      render it at all. Every hit here therefore records WHICH phrase
///      matched, and both groupings are derived from the same hits.
///
///   3. **"the remainder of the Bible text"** — the base verse is
///      excluded. It matches all of its own phrases, perfectly, and
///      would sit at the top of every result forever.
///
///   4. **Search limits apply.** bwh51 lists "Use search limits from
///      main window" as a PMT option; [buildPhraseMatchIndex] takes a
///      `scope`, which the pane fills from the Verse List Manager's
///      active limit (v1.6.14).
///
/// ── What the help topic does NOT solve, and this file does ──
///
/// At phrase length 3 in English, most of what a verse yields is
/// grammar: "and it came", "of the lord", "unto the children". Those
/// match hundreds of verses each and drown the handful of real
/// parallels — which is the difference between a tool that answers a
/// question and a list nobody reads. BibleWorks offers no filtering
/// here at all; RVT's editable common-word list (`common-eng.iel`) has
/// no PMT counterpart.
///
/// Two defences, both borrowed from the RVT pane's idiom because it is
/// the one already established in this codebase: every phrase is a chip
/// carrying its own verse count, so the reader can see and drop the
/// noise; and [defaultEnabledPhrases] starts a phrase unchecked when it
/// is made entirely of function words, or when it occurs in more than
/// [kPhraseNoiseFraction] of the corpus. Both are one tap from being
/// back in — an unchecked phrase is visible, whereas a filtered one is
/// a decision made on the reader's behalf without telling them.
///
/// Accordance's INFER command — the nearest thing any competitor has to
/// PMT — solves the same problem by IGNORING any phrase more than half
/// of whose words are among the language's most common. That rule is
/// deliberately NOT copied here. It is a guess made before the evidence
/// arrives, and this scan has the evidence: "a virgin shall" is two
/// parts function word out of three and Accordance would throw it away,
/// but it occurs in a handful of verses and is exactly the run that
/// links Isaiah 7:14 to Matthew 1:23. The measured verse count
/// distinguishes those cases and a composition heuristic cannot, so the
/// composition test here stays at its strictest — ALL words function
/// words — and does the work the frequency test cannot: catching a
/// phrase that is meaningless but happens to be rare.
///
/// ── Chinese ──
///
/// `related_verses.dart` tokenizes Han text into overlapping BIGRAMS,
/// which is right for a bag of words and wrong here: a sequence of
/// overlapping bigrams double-counts every character, and a "phrase" of
/// three bigrams is four characters with a strange internal
/// constraint. Phrase matching in Chinese is character-sequence
/// matching, so [phraseTokens] emits ONE TOKEN PER HAN CHARACTER and a
/// phrase is a run of characters. [defaultPhraseLength] then asks for
/// four rather than three, because a Chinese character is closer to
/// half a word than to a word.
///
/// Pure list, set and integer work: no Flutter, no assets, no I/O.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:seeksparks/utils/related_verses.dart'
    show isCjkChar, isWordChar, kRelatedVersesCommonWords;
import 'package:seeksparks/utils/search_highlight.dart' show HighlightSpan;

// ── Limits ──────────────────────────────────────────────────────────

const int kPhraseLengthMin = 2;
const int kPhraseLengthMax = 8;
const int kPhraseGapMax = 5;

/// Above this many verses, a phrase's hits are counted but not kept.
///
/// A three-word phrase in more than about 2.5% of the Bible is grammar,
/// not quotation, and [defaultEnabledPhrases] has already unchecked it
/// at a twentieth of this. The cap exists so that one pathological base
/// verse — Esther 8:9 is 80 words, hence 78 phrases — cannot make the
/// scan allocate a hit object for a million verse/phrase pairs. The
/// count still shows on the chip, so nothing is hidden; the phrase just
/// cannot be listed.
const int kPhraseVerseCap = 800;

/// A phrase in more than this fraction of the scanned corpus starts
/// unchecked. 1% of a whole Bible is ~311 verses, which leaves the
/// prophetic formulae ("thus says the LORD", ~290 verses in the KJV)
/// checked — those ARE the signal for a prophetic verse — while
/// dropping the pure connective tissue that runs into the thousands.
const double kPhraseNoiseFraction = 0.01;

/// Never uncheck a phrase for rarity alone below this many verses.
/// Without a floor the fraction test unchecks everything on a small
/// corpus, where 1% rounds to nothing.
const int kPhraseNoiseFloor = 3;

// ── Tokenizing ──────────────────────────────────────────────────────

/// A token and the half-open UTF-16 range it occupies.
typedef PhraseToken = ({String text, int start, int end});

bool _isApostrophe(int c) => c == 0x27 || c == 0x2019;

/// Split [text] into the ordered units a phrase is made of.
///
/// One token per Han character; one lower-cased token per alphabetic
/// run (Latin, Greek, Hebrew), apostrophes kept inside a word and
/// stripped from its edges.
///
/// **Punctuation is fully transparent** — it is a separator that
/// occupies no token position, so a phrase may cross a comma, a colon
/// or a full stop without cost. This is the opposite of
/// `related_verses.dart`, whose Chinese bigrams stop dead at
/// punctuation, and the difference is deliberate: a bigram that bridges
/// 天地。神 into 地神 is an invented word, whereas a PHRASE that bridges
/// a comma is the normal case. Translations punctuate differently from
/// one another and from their source — Isaiah 7:14 reads "Behold, a
/// virgin shall conceive", and "Behold a virgin" is precisely the run
/// that must survive.
///
/// Deliberately NOT `related_verses.dart`'s tokenizer: see the library
/// comment on Chinese.
List<PhraseToken> phraseTokens(String text) {
  final out = <PhraseToken>[];
  final n = text.length;
  var i = 0;
  while (i < n) {
    final c = text.codeUnitAt(i);
    if (isCjkChar(c)) {
      out.add((text: text.substring(i, i + 1), start: i, end: i + 1));
      i++;
      continue;
    }
    if (isWordChar(c)) {
      var j = i;
      while (j < n && isWordChar(text.codeUnitAt(j))) {
        j++;
      }
      var s = i;
      var e = j;
      while (s < e && _isApostrophe(text.codeUnitAt(s))) {
        s++;
      }
      while (e > s && _isApostrophe(text.codeUnitAt(e - 1))) {
        e--;
      }
      if (e > s) {
        out.add((
          text: text.substring(s, e).toLowerCase(),
          start: s,
          end: e,
        ));
      }
      i = j;
      continue;
    }
    i++;
  }
  return out;
}

/// How long a phrase should be, for a verse written in [baseText].
///
/// Three words in an alphabetic script — short enough that a reworded
/// quotation still shares one, long enough that the match is not an
/// accident. Four in Chinese: [phraseTokens] emits characters there,
/// and three characters is a word and a half, which matches far too
/// much. The test is on the majority of the verse rather than on the
/// version, so a Chinese verse quoting a Latin phrase still gets the
/// Chinese default.
int defaultPhraseLength(String baseText) {
  var cjk = 0;
  var total = 0;
  for (final t in phraseTokens(baseText)) {
    total++;
    if (isCjkChar(t.text.codeUnitAt(0))) cjk++;
  }
  if (total == 0) return 3;
  return cjk * 2 > total ? 4 : 3;
}

// ── The pieces of a result ──────────────────────────────────────────

/// One run of [PhraseMatchIndex.phraseLength] tokens taken from the
/// base verse, and how the rest of the Bible answered it.
class MatchPhrase {
  const MatchPhrase({
    required this.words,
    required this.display,
    required this.start,
    required this.end,
    required this.verseCount,
    required this.occurrences,
    required this.allCommon,
    required this.listed,
  });

  /// The tokens, lower-cased, in order — what is actually matched.
  final List<String> words;

  /// The same run as it reads in the base verse: original case, and any
  /// punctuation that sits between the first and last token. What to
  /// put on a chip.
  final String display;

  /// UTF-16 range of [display] within the base verse text.
  final int start;
  final int end;

  /// How many scanned verses contain this phrase. The number a reader
  /// needs in order to judge whether the phrase is worth anything.
  final int verseCount;

  /// Total match instances, which exceeds [verseCount] when a verse
  /// contains the phrase twice.
  final int occurrences;

  /// Every token is a closed-class English function word, so the phrase
  /// carries no sense of its own.
  final bool allCommon;

  /// False when [verseCount] exceeded [kPhraseVerseCap] and the hits
  /// were dropped. Such a phrase cannot be enabled.
  final bool listed;

  @override
  String toString() => '"$display"($verseCount)';
}

/// One verse matching one phrase.
class PhraseHit {
  const PhraseHit({
    required this.verseIndex,
    required this.phraseIndex,
    required this.occurrences,
    required this.ranges,
  });

  /// Position in the corpus passed to [buildPhraseMatchIndex].
  final int verseIndex;

  /// Which phrase matched — index into [PhraseMatchIndex.phrases].
  /// Keeping this is what makes the "grouped by phrase" view possible.
  final int phraseIndex;

  /// Non-overlapping instances of the phrase in this verse.
  final int occurrences;

  /// Flat `[start, end, start, end, …]` UTF-16 ranges of the tokens
  /// that were actually matched, in the hit verse's own text. Only the
  /// matched tokens: bwh51 is explicit that with gaps enabled the words
  /// bridged over are not highlighted.
  final List<int> ranges;

  @override
  String toString() => '#$verseIndex/p$phraseIndex×$occurrences';
}

/// One pass over the corpus, held so that checking and unchecking
/// phrases is a filter rather than another scan. Changing the phrase
/// LENGTH or the GAP changes what was searched for and does need a
/// rebuild.
class PhraseMatchIndex {
  const PhraseMatchIndex({
    required this.phrases,
    required this.hits,
    required this.baseIndex,
    required this.baseText,
    required this.baseTokenCount,
    required this.corpusSize,
    required this.scanned,
    required this.phraseLength,
    required this.maxGap,
  });

  /// In the order the runs occur in the base verse, deduped.
  final List<MatchPhrase> phrases;

  /// Every hit, grouped by phrase. Never mentions [baseIndex].
  final List<PhraseHit> hits;

  final int baseIndex;
  final String baseText;

  /// How many tokens the base verse has. Below [phraseLength] there are
  /// no phrases to search for, and the pane needs to say why.
  final int baseTokenCount;

  final int corpusSize;

  /// Verses actually examined — smaller than [corpusSize] when a scope
  /// was given.
  final int scanned;

  final int phraseLength;
  final int maxGap;

  static const empty = PhraseMatchIndex(
    phrases: [],
    hits: [],
    baseIndex: -1,
    baseText: '',
    baseTokenCount: 0,
    corpusSize: 0,
    scanned: 0,
    phraseLength: 3,
    maxGap: 0,
  );

  bool get isEmpty => phrases.isEmpty;

  /// One phrase word may be dropped only when the reader has asked for
  /// slack, and only from the middle — see [_PhraseScanner].
  bool get allowsDrop => maxGap >= 1 && phraseLength >= 3;
}

// ── Building the index ──────────────────────────────────────────────

/// Chop `corpus[baseIndex]` into phrases and find them in the rest of
/// [corpus].
///
/// [corpus] must be sanitized, display-ready verse text with word
/// boundaries intact, in canonical order — `MainProvider.wordKeys` —
/// so a verse index is also its position in the Bible.
///
/// [scope], when given, restricts the scan to those corpus indices.
/// This is bwh51's "Use search limits from main window".
PhraseMatchIndex buildPhraseMatchIndex({
  required List<String> corpus,
  required int baseIndex,
  int phraseLength = 3,
  int maxGap = 0,
  Set<int>? scope,
}) {
  final len = phraseLength.clamp(kPhraseLengthMin, kPhraseLengthMax);
  final gap = maxGap.clamp(0, kPhraseGapMax);
  if (baseIndex < 0 || baseIndex >= corpus.length) {
    return PhraseMatchIndex.empty;
  }

  final baseText = corpus[baseIndex];
  final tokens = phraseTokens(baseText);

  PhraseMatchIndex barren() => PhraseMatchIndex(
        phrases: const [],
        hits: const [],
        baseIndex: baseIndex,
        baseText: baseText,
        baseTokenCount: tokens.length,
        corpusSize: corpus.length,
        scanned: 0,
        phraseLength: len,
        maxGap: gap,
      );

  if (tokens.length < len) return barren();

  // Every distinct token of the base verse is a candidate word: when
  // the verse is at least `len` tokens long, every token falls inside
  // some window.
  final wordIds = <String, int>{};
  final idWords = <String>[];
  for (final t in tokens) {
    if (wordIds.containsKey(t.text)) continue;
    wordIds[t.text] = idWords.length;
    idWords.add(t.text);
  }

  // The windows, deduped on their word sequence — a verse that says the
  // same three words twice should search for them once.
  final phraseWords = <List<int>>[];
  final phraseSpans = <(int, int)>[];
  final seenPhrase = <String>{};
  for (var w = 0; w + len <= tokens.length; w++) {
    final ids = <int>[for (var k = 0; k < len; k++) wordIds[tokens[w + k].text]!];
    if (!seenPhrase.add(ids.join(' '))) continue;
    phraseWords.add(ids);
    phraseSpans.add((tokens[w].start, tokens[w + len - 1].end));
  }
  if (phraseWords.isEmpty) return barren();

  final scanner = _PhraseScanner(
    idWords: idWords,
    phraseWords: phraseWords,
    maxGap: gap,
  );

  final buckets = List<List<PhraseHit>>.generate(
      phraseWords.length, (_) => <PhraseHit>[],
      growable: false);
  final verseCounts = Int32List(phraseWords.length);
  final occurrenceCounts = Int32List(phraseWords.length);

  var scanned = 0;
  for (var vi = 0; vi < corpus.length; vi++) {
    if (vi == baseIndex) continue;
    if (scope != null && !scope.contains(vi)) continue;
    scanned++;
    scanner.scanVerse(corpus[vi], vi + 1);
    if (scanner.isEmpty) continue;
    for (var pi = 0; pi < phraseWords.length; pi++) {
      if (!scanner.couldMatch(pi)) continue;
      final found = scanner.match(pi);
      if (found == null) continue;
      verseCounts[pi]++;
      occurrenceCounts[pi] += found.occurrences;
      if (buckets[pi].length < kPhraseVerseCap) {
        buckets[pi].add(PhraseHit(
          verseIndex: vi,
          phraseIndex: pi,
          occurrences: found.occurrences,
          ranges: found.ranges,
        ));
      }
    }
  }

  final phrases = <MatchPhrase>[];
  final hits = <PhraseHit>[];
  for (var pi = 0; pi < phraseWords.length; pi++) {
    final words = [for (final id in phraseWords[pi]) idWords[id]];
    final listed = verseCounts[pi] <= kPhraseVerseCap;
    final (start, end) = phraseSpans[pi];
    phrases.add(MatchPhrase(
      words: words,
      display: baseText.substring(start, end),
      start: start,
      end: end,
      verseCount: verseCounts[pi],
      occurrences: occurrenceCounts[pi],
      allCommon: words.every(kRelatedVersesCommonWords.contains),
      listed: listed,
    ));
    if (listed) hits.addAll(buckets[pi]);
  }

  return PhraseMatchIndex(
    phrases: phrases,
    hits: hits,
    baseIndex: baseIndex,
    baseText: baseText,
    baseTokenCount: tokens.length,
    corpusSize: corpus.length,
    scanned: scanned,
    phraseLength: len,
    maxGap: gap,
  );
}

/// One verse's answer for one phrase.
typedef _Found = ({int occurrences, List<int> ranges});

/// The corpus walk and the gapped matcher, in one reusable object so a
/// 31,102-verse scan allocates almost nothing.
///
/// The walk has to visit every token — token POSITIONS are what the gap
/// is measured in, so a candidate word's position depends on the words
/// before it that were not candidates. But it only has to BUILD the
/// candidates: an alphabetic word is screened on its length and initial
/// together before any substring is cut, and a Han character is one
/// integer looked up in a set. `related_verses.dart`'s `_TermMatcher`
/// established the trick; this is the same screen with positions kept.
///
/// The matcher itself is a depth-first alignment of the phrase's words
/// onto the candidate positions:
///
///   * step forward by 1..maxGap+1 token positions between consecutive
///     matched words — bwh51's inserted words, and its "maximum SINGLE
///     gap", since the bound is per step and not a budget;
///   * or drop one phrase word entirely — bwh51's dropped word —
///     which costs no token position, so its neighbours must still be
///     within one step of each other.
///
/// **A dropped word must be an INTERIOR one.** The help says only "one
/// of the phrase words dropped", but dropping the first or last would
/// make a phrase of length N match on N-1 words, i.e. silently answer a
/// question the reader did not ask and flood the result with every
/// shorter phrase. Interior-only keeps "phrase length 3" meaning three.
class _PhraseScanner {
  _PhraseScanner({
    required this.idWords,
    required this.phraseWords,
    required this.maxGap,
  }) : present = Int32List(idWords.length) {
    for (var id = 0; id < idWords.length; id++) {
      final w = idWords[id];
      final first = w.codeUnitAt(0);
      if (isCjkChar(first) && w.length == 1) {
        _cjkIds[first] = id;
      } else {
        _alphaIds[w] = id;
        if (first < 0x80) _alphaShapes.add((w.length << 16) | first);
      }
    }
    _dropAllowed = maxGap >= 1 && phraseWords.first.length >= 3;
  }

  final List<String> idWords;
  final List<List<int>> phraseWords;
  final int maxGap;

  final Map<int, int> _cjkIds = {};
  final Map<String, int> _alphaIds = {};
  final Set<int> _alphaShapes = {};
  late final bool _dropAllowed;

  /// id → the stamp of the verse it was last seen in. A stamp rather
  /// than a per-verse set: 31,102 small set allocations is real time,
  /// and this is allocation-free.
  final Int32List present;
  int _stamp = 0;

  // Candidate occurrences in the verse being examined, position-sorted.
  final List<int> _ids = [];
  final List<int> _pos = [];
  final List<int> _start = [];
  final List<int> _end = [];

  bool get isEmpty => _ids.isEmpty;

  void scanVerse(String text, int stamp) {
    _stamp = stamp;
    _ids.clear();
    _pos.clear();
    _start.clear();
    _end.clear();

    final n = text.length;
    var pos = 0;
    var i = 0;
    while (i < n) {
      final c = text.codeUnitAt(i);
      if (isCjkChar(c)) {
        final id = _cjkIds[c];
        if (id != null) _record(id, pos, i, i + 1);
        pos++;
        i++;
        continue;
      }
      if (isWordChar(c)) {
        var j = i;
        while (j < n && isWordChar(text.codeUnitAt(j))) {
          j++;
        }
        var s = i;
        var e = j;
        while (s < e && _isApostrophe(text.codeUnitAt(s))) {
          s++;
        }
        while (e > s && _isApostrophe(text.codeUnitAt(e - 1))) {
          e--;
        }
        if (e > s) {
          final first = text.codeUnitAt(s);
          // ASCII case-fold is enough to screen on; anything else skips
          // the screen rather than risking a wrong rejection.
          final ascii = first < 0x80;
          final folded = (first >= 0x41 && first <= 0x5A) ? first | 0x20 : first;
          if (!ascii || _alphaShapes.contains(((e - s) << 16) | folded)) {
            final id = _alphaIds[text.substring(s, e).toLowerCase()];
            if (id != null) _record(id, pos, s, e);
          }
          pos++;
        }
        i = j;
        continue;
      }
      i++;
    }
  }

  void _record(int id, int pos, int start, int end) {
    _ids.add(id);
    _pos.add(pos);
    _start.add(start);
    _end.add(end);
    present[id] = _stamp;
  }

  /// Cheap rejection before the alignment runs.
  ///
  /// Every phrase word must be somewhere in the verse — the alignment
  /// can reorder nothing, so a missing word is fatal. The one exception
  /// is the word the reader's gap setting lets us drop, and only if it
  /// is interior and occurs just once in the phrase (a word appearing
  /// twice and missing would need two drops).
  bool couldMatch(int phraseIndex) {
    final w = phraseWords[phraseIndex];
    var missing = 0;
    var missingAt = -1;
    for (var k = 0; k < w.length; k++) {
      if (present[w[k]] != _stamp) {
        missing++;
        if (missing > 1) return false;
        missingAt = k;
      }
    }
    if (missing == 0) return true;
    if (!_dropAllowed) return false;
    if (missingAt == 0 || missingAt == w.length - 1) return false;
    for (var k = 0; k < w.length; k++) {
      if (k != missingAt && w[k] == w[missingAt]) return false;
    }
    return true;
  }

  /// All non-overlapping instances of the phrase in the current verse,
  /// or null if there are none.
  _Found? match(int phraseIndex) {
    final w = phraseWords[phraseIndex];
    final len = w.length;
    final m = _ids.length;
    final chosen = List<int>.filled(len, -1);
    final failed = <int>{};
    // `_pos` is ascending, so its last entry bounds every state key.
    final posBound = _pos[m - 1] + 2;

    bool step(int k, int lastPos, bool dropUsed) {
      if (k == len) return true;
      final key = ((k * posBound + lastPos) << 1) | (dropUsed ? 1 : 0);
      if (failed.contains(key)) return false;
      final target = w[k];
      final hi = lastPos + maxGap + 1;
      for (var j = 0; j < m; j++) {
        final p = _pos[j];
        if (p <= lastPos) continue;
        if (p > hi) break;
        if (_ids[j] != target) continue;
        chosen[k] = j;
        if (step(k + 1, p, dropUsed)) return true;
      }
      if (!dropUsed && _dropAllowed && k >= 1 && k <= len - 2) {
        chosen[k] = -1;
        if (step(k + 1, lastPos, true)) return true;
      }
      failed.add(key);
      return false;
    }

    var occurrences = 0;
    List<int>? ranges;
    final head = w[0];
    var s = 0;
    while (s < m) {
      if (_ids[s] != head) {
        s++;
        continue;
      }
      chosen[0] = s;
      failed.clear();
      if (!step(1, _pos[s], false)) {
        s++;
        continue;
      }
      occurrences++;
      ranges ??= <int>[];
      var last = s;
      for (var k = 0; k < len; k++) {
        final j = chosen[k];
        if (j < 0) continue;
        ranges.add(_start[j]);
        ranges.add(_end[j]);
        if (j > last) last = j;
      }
      // Resume past the whole instance, so "God God God" with a
      // two-word phrase reads as one occurrence and then another,
      // rather than as every overlapping pair.
      s = last + 1;
    }
    if (ranges == null) return null;
    return (occurrences: occurrences, ranges: ranges);
  }
}

// ── Which phrases start checked ─────────────────────────────────────

/// The phrases worth searching on, before the reader says otherwise.
///
/// A phrase is dropped when it cannot be listed at all, when it matched
/// nothing, when every one of its words is a function word, or when it
/// occurs in more than [maxVerseFraction] of what was scanned. See the
/// library comment: without this the top of the result list is
/// "and it came", every time.
Set<int> defaultEnabledPhrases(
  PhraseMatchIndex index, {
  double maxVerseFraction = kPhraseNoiseFraction,
}) {
  final cap = math.max(
    kPhraseNoiseFloor.toDouble(),
    index.scanned * maxVerseFraction,
  );
  return {
    for (var i = 0; i < index.phrases.length; i++)
      if (index.phrases[i].listed &&
          index.phrases[i].verseCount > 0 &&
          !index.phrases[i].allCommon &&
          index.phrases[i].verseCount <= cap)
        i,
  };
}

// ── The three views ─────────────────────────────────────────────────

/// bwh51's three result orderings.
enum PhraseMatchSort {
  /// Book order — BibleWorks' stated default.
  reference,

  /// The verses carrying the most distinct phrases first.
  matches,

  /// Grouped under the phrases themselves, most frequent first. Not an
  /// ordering of the same list: a different projection of the hits.
  phrase,
}

/// Every enabled phrase that one verse matched.
class PhraseVerseGroup {
  const PhraseVerseGroup({
    required this.verseIndex,
    required this.phraseIndexes,
    required this.occurrences,
    required this.ranges,
  });

  final int verseIndex;

  /// Distinct phrases matched, ascending. Its length is the number
  /// BibleWorks prints in brackets for "verse with most phrases".
  final List<int> phraseIndexes;

  /// Total instances, which can exceed `phraseIndexes.length`.
  final int occurrences;

  /// Merged, ascending flat ranges over the verse text.
  final List<int> ranges;

  @override
  String toString() => '#$verseIndex[${phraseIndexes.length}]';
}

/// Collapse the hits onto verses.
List<PhraseVerseGroup> groupPhraseHitsByVerse(
  PhraseMatchIndex index,
  Set<int> enabled, {
  PhraseMatchSort sort = PhraseMatchSort.matches,
  int limit = 300,
}) {
  final byVerse = <int, List<PhraseHit>>{};
  for (final h in index.hits) {
    if (!enabled.contains(h.phraseIndex)) continue;
    (byVerse[h.verseIndex] ??= <PhraseHit>[]).add(h);
  }

  final out = <PhraseVerseGroup>[];
  for (final e in byVerse.entries) {
    final phraseIndexes = [for (final h in e.value) h.phraseIndex]..sort();
    var occurrences = 0;
    final flat = <int>[];
    for (final h in e.value) {
      occurrences += h.occurrences;
      flat.addAll(h.ranges);
    }
    out.add(PhraseVerseGroup(
      verseIndex: e.key,
      phraseIndexes: phraseIndexes,
      occurrences: occurrences,
      ranges: mergePhraseRanges(flat),
    ));
  }

  switch (sort) {
    case PhraseMatchSort.reference:
    case PhraseMatchSort.phrase:
      out.sort((a, b) => a.verseIndex.compareTo(b.verseIndex));
    case PhraseMatchSort.matches:
      out.sort((a, b) {
        final c = b.phraseIndexes.length.compareTo(a.phraseIndexes.length);
        if (c != 0) return c;
        final d = b.occurrences.compareTo(a.occurrences);
        // Ties fall back to book order, so an equally-matched pair reads
        // Genesis-first rather than in hash order — which would also
        // mean the list reshuffled itself between rebuilds.
        return d != 0 ? d : a.verseIndex.compareTo(b.verseIndex);
      });
  }
  return out.length <= limit ? out : out.sublist(0, limit);
}

/// One phrase and the verses that contain it.
class PhraseGroup {
  const PhraseGroup({
    required this.phraseIndex,
    required this.occurrences,
    required this.hits,
  });

  final int phraseIndex;

  /// Total instances across the corpus — the number bwh51 puts in
  /// brackets next to the phrase.
  final int occurrences;

  /// Verse-ordered, and capped: the point of this view is to see WHICH
  /// phrases carry the weight, not to read nine hundred verses.
  final List<PhraseHit> hits;

  @override
  String toString() => 'p$phraseIndex[$occurrences]';
}

/// Collapse the hits onto phrases — bwh51's "grouped by most frequently
/// used phrases".
List<PhraseGroup> groupPhraseHitsByPhrase(
  PhraseMatchIndex index,
  Set<int> enabled, {
  int versesPerPhrase = 40,
}) {
  final byPhrase = <int, List<PhraseHit>>{};
  for (final h in index.hits) {
    if (!enabled.contains(h.phraseIndex)) continue;
    (byPhrase[h.phraseIndex] ??= <PhraseHit>[]).add(h);
  }

  final out = <PhraseGroup>[];
  for (final e in byPhrase.entries) {
    final hits = e.value..sort((a, b) => a.verseIndex.compareTo(b.verseIndex));
    var occurrences = 0;
    for (final h in hits) {
      occurrences += h.occurrences;
    }
    out.add(PhraseGroup(
      phraseIndex: e.key,
      occurrences: occurrences,
      hits: hits.length <= versesPerPhrase
          ? hits
          : hits.sublist(0, versesPerPhrase),
    ));
  }
  out.sort((a, b) {
    final c = b.occurrences.compareTo(a.occurrences);
    // Phrase order within a tie, so the list reads left-to-right across
    // the base verse.
    return c != 0 ? c : a.phraseIndex.compareTo(b.phraseIndex);
  });
  return out;
}

// ── Showing the reader why ──────────────────────────────────────────

/// Sort and coalesce flat `[start, end, …]` ranges.
List<int> mergePhraseRanges(List<int> flat) {
  if (flat.length <= 2) return flat;
  final pairs = <(int, int)>[
    for (var i = 0; i + 1 < flat.length; i += 2) (flat[i], flat[i + 1]),
  ]..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
  final out = <int>[];
  var start = pairs.first.$1;
  var end = pairs.first.$2;
  for (final p in pairs.skip(1)) {
    if (p.$1 <= end) {
      if (p.$2 > end) end = p.$2;
    } else {
      out
        ..add(start)
        ..add(end);
      start = p.$1;
      end = p.$2;
    }
  }
  out
    ..add(start)
    ..add(end);
  return out;
}

/// Split [text] on merged [ranges] so the matched tokens can be marked.
///
/// Ranges only, never a substring search: the matcher already knows
/// exactly which tokens it used, and re-finding them by text would
/// light up the gap-bridged words bwh51 says to leave dark.
///
/// Two matched tokens separated by nothing but whitespace are joined
/// into one run, so a matched phrase reads as a phrase rather than as a
/// row of separately-boxed words. Anything else between them — a word
/// the gap bridged over, or punctuation — keeps them apart, which is
/// what makes a gapped match visibly different from an exact one.
List<HighlightSpan> highlightPhraseRanges(String text, List<int> ranges) {
  if (text.isEmpty) return const [];
  if (ranges.length < 2) return [HighlightSpan(text, false)];

  final out = <HighlightSpan>[];
  var cursor = 0;
  var runStart = -1;
  var runEnd = -1;

  void flush() {
    if (runStart < 0) return;
    if (runStart > cursor) {
      out.add(HighlightSpan(text.substring(cursor, runStart), false));
    }
    out.add(HighlightSpan(text.substring(runStart, runEnd), true));
    cursor = runEnd;
    runStart = -1;
  }

  for (var i = 0; i + 1 < ranges.length; i += 2) {
    final start = ranges[i].clamp(0, text.length);
    final end = ranges[i + 1].clamp(start, text.length);
    if (end <= start) continue;
    if (runStart >= 0 &&
        start >= runEnd &&
        text.substring(runEnd, start).trim().isEmpty) {
      runEnd = end;
      continue;
    }
    flush();
    runStart = start;
    runEnd = end;
  }
  flush();

  if (cursor < text.length) {
    out.add(HighlightSpan(text.substring(cursor), false));
  }
  return out;
}
