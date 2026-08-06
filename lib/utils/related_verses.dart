/// 2026-08-06 (SeekSparks): Related Verses — BibleWorks help topic
/// bwh50.
///
/// The name is a trap. "Related verses" sounds like cross-references,
/// and SeekSparks already ships those: TSK and OpenBible, in the X-Refs
/// tab. Those are a CURATED list — somebody decided, once, that Genesis
/// 1:1 relates to John 1:1, and every reader gets that same decision.
///
/// BibleWorks' Related Verses Tool is a different thing entirely. It
/// COMPUTES the relation, from the text, at the moment you ask: take
/// the words of the verse in front of you, and rank the rest of the
/// Bible by how many of those words it shares. Nobody curated the
/// result, so nothing is missing because an editor in 1830 did not
/// think of it. It is how you find where Scripture is quoting or
/// echoing Scripture, and it answers questions a cross-reference list
/// cannot: not "what is the classic parallel to this verse" but "what
/// else in this book talks like this".
///
/// Three things in the help topic that a naive build would miss:
///
///   * Common words are UNCHECKED, not removed. BibleWorks ships an
///     editable list (`common-eng.iel`) and puts a checkbox next to
///     every word, because whether "shall" is noise depends on the
///     verse. A filter would decide for the reader; a checkbox asks.
///   * A word can be given EXTRA WEIGHT — BibleWorks weights a
///     double-clicked word "as if it occurred three times".
///   * The result threshold DEFAULTS RELATIVE to how many words are
///     checked ("1/3 or less of the checked words"), because a fixed
///     cutoff is meaningless when one search has 4 words and the next
///     has 30.
///
/// The scoring is deliberately BibleWorks' — a plain weighted count of
/// distinct matching words, not TF-IDF cosine similarity. The count is
/// the number printed next to each hit, and a reader who sees "[9]"
/// can go and find nine shared words. A similarity score of 0.6183 is
/// more defensible statistically and cannot be checked by eye.
///
/// Pure list and set work: no Flutter, no assets, no I/O. The widget
/// loads the corpus and draws; everything worth being wrong about is
/// here, where a test can reach it.
library;

import 'package:seeksparks/utils/search_highlight.dart' show HighlightSpan;

// ── Tokenizing ──────────────────────────────────────────────────────

/// Whether [c] is an ideograph we should tokenize as Chinese.
///
/// CJK Unified (U+4E00–U+9FFF), Extension A (U+3400–U+4DBF), and the
/// Compatibility block (U+F900–U+FAFF), which is where a handful of
/// characters used in Chinese Bible editions live.
bool _isCjk(int c) =>
    (c >= 0x4E00 && c <= 0x9FFF) ||
    (c >= 0x3400 && c <= 0x4DBF) ||
    (c >= 0xF900 && c <= 0xFAFF);

/// Whether [c] can sit inside an alphabetic word.
///
/// Latin, Greek (both the modern block and the polytonic Extended
/// block), Hebrew including its vowel points — a pointed word must not
/// shred into one token per consonant — plus digits and the two
/// apostrophes, which are word-internal in "God's" and "don't".
bool _isWordChar(int c) {
  if (c >= 0x61 && c <= 0x7A) return true; // a-z
  if (c >= 0x41 && c <= 0x5A) return true; // A-Z
  if (c >= 0x30 && c <= 0x39) return true; // 0-9
  if (c == 0x27 || c == 0x2019) return true; // ' ’
  if (c >= 0x00C0 && c <= 0x024F) return true; // Latin-1 + Extended A/B
  if (c >= 0x0370 && c <= 0x03FF) return true; // Greek and Coptic
  if (c >= 0x1F00 && c <= 0x1FFF) return true; // Greek Extended
  if (c >= 0x0590 && c <= 0x05FF) return true; // Hebrew + niqqud
  return false;
}

/// A token and where it sits in the source string.
typedef _Span = ({String token, int start, int end});

/// Tokenize [text] into the units relatedness is measured in.
///
/// Two scripts, two rules, because Chinese does not put spaces between
/// words:
///
///   * Alphabetic runs (Latin, Greek, Hebrew) become one lower-cased
///     token each, the way anyone would split English.
///   * A run of Han characters becomes its overlapping BIGRAMS —
///     起初神创造天地 gives 起初, 初神, 神创, 创造, 造天, 天地. Roughly
///     seven in ten modern Chinese words are two characters, so the
///     real words are in there; the spurious pairs that straddle a word
///     boundary (初神, 神创) are near-unique and therefore harmless —
///     when one of them DOES recur it is because the whole phrase
///     recurs, which is precisely the signal being looked for.
///
/// Segmenting properly would need a dictionary and a Chinese word
/// segmenter, which is a large dependency for a gain that bigram
/// indexing mostly already delivers. The useful side effect: Chinese
/// function words are overwhelmingly SINGLE characters (的, 了, 是, 在,
/// 我), and single characters are never emitted from a run longer than
/// one — so bigrams throw away most Chinese stop words for free.
///
/// Bigrams inside a run only. A run ends at punctuation, so a term can
/// never bridge 天地。神 into 地神.
List<_Span> _spans(String text) {
  final out = <_Span>[];
  final runes = text.runes.toList(growable: false);
  // Rune index -> UTF-16 offset, so ranges are usable for substring().
  final offsets = List<int>.filled(runes.length + 1, 0);
  var utf16 = 0;
  for (var i = 0; i < runes.length; i++) {
    offsets[i] = utf16;
    utf16 += runes[i] > 0xFFFF ? 2 : 1;
  }
  offsets[runes.length] = utf16;

  var i = 0;
  while (i < runes.length) {
    final c = runes[i];
    if (_isCjk(c)) {
      var j = i;
      while (j < runes.length && _isCjk(runes[j])) {
        j++;
      }
      final len = j - i;
      if (len == 1) {
        out.add((
          token: String.fromCharCode(runes[i]),
          start: offsets[i],
          end: offsets[i + 1],
        ));
      } else {
        for (var k = i; k < j - 1; k++) {
          out.add((
            token: String.fromCharCodes(runes, k, k + 2),
            start: offsets[k],
            end: offsets[k + 2],
          ));
        }
      }
      i = j;
      continue;
    }
    if (_isWordChar(c)) {
      var j = i;
      while (j < runes.length && _isWordChar(runes[j])) {
        j++;
      }
      // Apostrophes are word-INTERNAL; a quote mark that happened to
      // hug the word is punctuation and not part of it.
      var s = i;
      var e = j;
      while (s < e && (runes[s] == 0x27 || runes[s] == 0x2019)) {
        s++;
      }
      while (e > s && (runes[e - 1] == 0x27 || runes[e - 1] == 0x2019)) {
        e--;
      }
      if (e > s) {
        out.add((
          token: String.fromCharCodes(runes, s, e).toLowerCase(),
          start: offsets[s],
          end: offsets[e],
        ));
      }
      i = j;
      continue;
    }
    i++;
  }
  return out;
}

/// The tokens of [text], in order, with duplicates kept.
///
/// The reference implementation. [_TermMatcher] is the same rules
/// written for speed, and `related_verses_test` cross-checks the two
/// against each other over the whole corpus so they cannot drift.
List<String> tokenizeForRelatedVerses(String text) =>
    [for (final s in _spans(text)) s.token];

/// The candidate words, arranged so that a whole-Bible scan can reject
/// a token without building the string for it.
///
/// Tokenizing 31,102 verses the straightforward way costs about a
/// second — most of it spent allocating substrings for words that were
/// never candidates, then throwing them away. The scan only ever needs
/// a yes or no, so:
///
///   * a Chinese bigram is two UTF-16 units and becomes ONE integer,
///     `(first << 16) | second`, compared with no allocation at all —
///     which matters because Chinese produces a token per character;
///   * an alphabetic word is pre-screened on its length and initial
///     together, so "beginning" is never built as a string unless some
///     candidate is also a nine-letter word starting with b.
///
/// The screen can only skip work, never reject a real match: a word
/// whose initial is not ASCII bypasses it and is checked in full.
class _TermMatcher {
  _TermMatcher(Iterable<String> terms) {
    for (final t in terms) {
      if (t.isEmpty) continue;
      final u = t.codeUnits;
      if (_isCjk(u[0])) {
        if (u.length == 2 && _isCjk(u[1])) {
          _cjkBigrams.add((u[0] << 16) | u[1]);
        } else if (u.length == 1) {
          _cjkSingles.add(u[0]);
        }
        continue;
      }
      _alphaTerms.add(t);
      final first = u[0];
      if (first < 0x80) _alphaShapes.add((u.length << 16) | first);
    }
  }

  final Set<int> _cjkBigrams = {};
  final Set<int> _cjkSingles = {};
  final Set<int> _alphaShapes = {};
  final Set<String> _alphaTerms = {};

  bool get isEmpty =>
      _cjkBigrams.isEmpty && _cjkSingles.isEmpty && _alphaTerms.isEmpty;

  /// Call [sink] once for every candidate word occurring in [text].
  /// May repeat a word that occurs twice; callers collect into a set.
  void forEachMatch(String text, void Function(String term) sink) {
    // `codeUnitAt` rather than the `codeUnits` list view: the view
    // allocates and its `[]` dispatches, and this loop runs a few
    // million times per scan.
    final n = text.length;
    var i = 0;
    while (i < n) {
      final c = text.codeUnitAt(i);
      if (_isCjk(c)) {
        var prev = c;
        var j = i + 1;
        while (j < n) {
          final d = text.codeUnitAt(j);
          if (!_isCjk(d)) break;
          if (_cjkBigrams.contains((prev << 16) | d)) {
            sink(text.substring(j - 1, j + 1));
          }
          prev = d;
          j++;
        }
        if (j - i == 1 && _cjkSingles.contains(c)) {
          sink(text.substring(i, j));
        }
        i = j;
        continue;
      }
      if (_isWordChar(c)) {
        var j = i;
        while (j < n && _isWordChar(text.codeUnitAt(j))) {
          j++;
        }
        var s = i;
        var e = j;
        while (s < e) {
          final d = text.codeUnitAt(s);
          if (d != 0x27 && d != 0x2019) break;
          s++;
        }
        while (e > s) {
          final d = text.codeUnitAt(e - 1);
          if (d != 0x27 && d != 0x2019) break;
          e--;
        }
        if (e > s && _alphaTerms.isNotEmpty) {
          final first = text.codeUnitAt(s);
          // ASCII case-fold is enough to screen on; anything else
          // skips the screen rather than risking a wrong rejection.
          final ascii = first < 0x80;
          final folded =
              (first >= 0x41 && first <= 0x5A) ? first | 0x20 : first;
          if (!ascii ||
              _alphaShapes.contains(((e - s) << 16) | folded)) {
            final w = text.substring(s, e).toLowerCase();
            if (_alphaTerms.contains(w)) sink(w);
          }
        }
        i = j;
        continue;
      }
      i++;
    }
  }
}

// ── Common words ────────────────────────────────────────────────────

/// English function words, unchecked by default.
///
/// BibleWorks' equivalent is `common-eng.iel`, an editable file. This
/// list is deliberately CLOSED-CLASS only — articles, pronouns,
/// prepositions, conjunctions, auxiliaries, and the King James forms of
/// the same (thee, hath, shalt, unto). Content words that merely happen
/// to be frequent — "said", "God", "man", "LORD" — are left to the
/// frequency test in [defaultEnabledTerms], which unchecks them on the
/// evidence rather than on a hunch.
///
/// There is no Chinese list: [_spans] emits bigrams, and Chinese
/// function words are single characters, so they never become terms.
const kRelatedVersesCommonWords = <String>{
  'a', 'about', 'above', 'after', 'again', 'against', 'all', 'also',
  'am', 'among', 'an', 'and', 'any', 'are', 'art', 'as', 'at', 'be',
  'because', 'been', 'before', 'being', 'beside', 'besides',
  'between', 'both', 'but', 'by', 'can', 'cannot', 'could', 'did',
  'do', 'does', 'doeth', 'doth', 'down', 'during', 'each', 'either',
  'else', 'ere', 'even', 'ever', 'every', 'for', 'from', 'further',
  'had', 'has', 'hast', 'hath', 'have', 'having', 'he', 'her', 'here',
  'hers', 'herself', 'him', 'himself', 'his', 'how', 'i', 'if', 'in',
  'indeed', 'into', 'is', 'it', 'its', 'itself', 'may', 'me', 'might',
  'mine', 'more', 'most', 'much', 'must', 'my', 'myself', 'neither',
  'never', 'nevertheless', 'no', 'nor', 'not', 'now', 'o', 'of', 'off',
  'on', 'once', 'or', 'other', 'ought', 'our', 'ours',
  'ourselves', 'out', 'over', 'own', 'same', 'shall', 'shalt', 'she',
  'should', 'since', 'so', 'some', 'such', 'than', 'that',
  'the', 'thee', 'their', 'theirs', 'them', 'themselves', 'then',
  'thence', 'there', 'therefore', 'therein', 'thereof', 'these',
  'they', 'thine', 'this', 'those', 'thou', 'though', 'through',
  'throughout', 'thus', 'thy', 'thyself', 'till', 'to', 'together',
  'too', 'toward', 'towards', 'under', 'unto', 'up', 'upon', 'us',
  'very', 'was', 'we', 'were', 'what', 'when', 'whence', 'where',
  'wherefore', 'whether', 'which', 'while', 'whither', 'who', 'whom',
  'whose', 'why', 'will', 'with', 'within', 'without', 'would', 'ye',
  'yea', 'yet', 'you', 'your', 'yours', 'yourself', 'yourselves',
};

// ── The index ───────────────────────────────────────────────────────

/// One candidate word, with how much of the Bible contains it.
class RelatedTerm {
  const RelatedTerm({
    required this.term,
    required this.documentFrequency,
    required this.fromBaseVerse,
  });

  /// The token, as matched and as displayed.
  final String term;

  /// How many verses in the scanned corpus contain it, the base verse
  /// included. BibleWorks does not show this; it is most of what tells
  /// a reader whether a word is worth checking, and the scan has
  /// already counted it.
  final int documentFrequency;

  /// False for a word the reader typed in that is not in the verse —
  /// BibleWorks allows this and it is how you steer a search.
  final bool fromBaseVerse;

  @override
  bool operator ==(Object other) =>
      other is RelatedTerm &&
      other.term == term &&
      other.documentFrequency == documentFrequency &&
      other.fromBaseVerse == fromBaseVerse;

  @override
  int get hashCode => Object.hash(term, documentFrequency, fromBaseVerse);

  @override
  String toString() => '$term($documentFrequency)';
}

/// The result of one pass over the corpus: for every candidate word,
/// exactly which verses contain it.
///
/// Held so that checking and unchecking words is set arithmetic rather
/// than another scan — the scan is the only slow part, and BibleWorks
/// makes you press "Find verses" again after every change.
class RelatedVersesIndex {
  const RelatedVersesIndex({
    required this.terms,
    required this.postings,
    required this.corpusSize,
    required this.baseIndex,
  });

  /// Candidates in the order they appear in the base verse, deduped,
  /// with any reader-added words appended.
  final List<RelatedTerm> terms;

  /// term → indices of the verses containing it. Never contains
  /// [baseIndex]: a verse is not related to itself.
  final Map<String, Set<int>> postings;

  final int corpusSize;
  final int baseIndex;

  static const empty = RelatedVersesIndex(
    terms: [],
    postings: {},
    corpusSize: 0,
    baseIndex: -1,
  );

  bool get isEmpty => terms.isEmpty;
}

/// Scan [corpus] and record which verses share words with
/// `corpus[baseIndex]`.
///
/// [corpus] must be the sanitized, display-ready verse text in
/// canonical order, so that a verse index is also its position in the
/// Bible and sorting by index sorts by reference.
///
/// [extraTerms] are words the reader added by hand. They are tokenized
/// the same way as the verse, so typing a Chinese word adds the right
/// bigrams rather than a term that can never match.
RelatedVersesIndex buildRelatedVersesIndex({
  required List<String> corpus,
  required int baseIndex,
  List<String> extraTerms = const [],
}) {
  if (baseIndex < 0 || baseIndex >= corpus.length) {
    return RelatedVersesIndex.empty;
  }

  final baseTerms = <String>[];
  final seen = <String>{};
  for (final t in tokenizeForRelatedVerses(corpus[baseIndex])) {
    if (seen.add(t)) baseTerms.add(t);
  }
  final added = <String>[];
  for (final raw in extraTerms) {
    for (final t in tokenizeForRelatedVerses(raw)) {
      if (seen.add(t)) added.add(t);
    }
  }
  if (baseTerms.isEmpty && added.isEmpty) {
    return RelatedVersesIndex(
      terms: const [],
      postings: const {},
      corpusSize: corpus.length,
      baseIndex: baseIndex,
    );
  }

  final all = <String>[...baseTerms, ...added];
  final postings = <String, Set<int>>{for (final t in all) t: <int>{}};
  final matcher = _TermMatcher(all);

  // One closure for the whole scan, not one per verse.
  var current = 0;
  void sink(String t) => postings[t]!.add(current);
  for (var i = 0; i < corpus.length; i++) {
    if (i == baseIndex) continue;
    current = i;
    matcher.forEachMatch(corpus[i], sink);
  }

  final baseSet = baseTerms.toSet();
  return RelatedVersesIndex(
    terms: [
      for (final t in all)
        RelatedTerm(
          term: t,
          // The base verse contains every base term by construction and
          // is excluded from the postings, so add it back: a word's
          // frequency in the Bible should not depend on where you are
          // standing.
          documentFrequency:
              postings[t]!.length + (baseSet.contains(t) ? 1 : 0),
          fromBaseVerse: baseSet.contains(t),
        ),
    ],
    postings: postings,
    corpusSize: corpus.length,
    baseIndex: baseIndex,
  );
}

/// Which words start checked.
///
/// Two tests, and a word fails if it fails either:
///
///   * it is a closed-class English function word
///     ([kRelatedVersesCommonWords]); or
///   * it occurs in more than [maxDocumentFrequency] of the corpus.
///
/// The frequency test is what makes this work in a language the word
/// list does not cover. It is also the more honest of the two: a word
/// in one verse of every five cannot distinguish verses, whatever it
/// means. That is why "LORD" starts unchecked in the KJV and "God"
/// does not — the divine name is in a fifth of the Old Testament, so
/// sharing it says almost nothing. Both are one tap from being back
/// in the search, which is the whole reason BibleWorks made these
/// checkboxes instead of a filter.
Set<String> defaultEnabledTerms(
  RelatedVersesIndex index, {
  double maxDocumentFrequency = 0.20,
}) {
  final cap = index.corpusSize * maxDocumentFrequency;
  return {
    for (final t in index.terms)
      if (!kRelatedVersesCommonWords.contains(t.term) &&
          t.documentFrequency <= cap)
        t.term,
  };
}

// ── Scoring ─────────────────────────────────────────────────────────

/// How the hit list is ordered.
enum RelatedVersesSort {
  /// Most shared words first. The default: the top of the list is the
  /// answer to the question that was asked.
  hits,

  /// Genesis to Revelation. Useful when you want the echoes of a verse
  /// in one book, or in the order the Bible tells them.
  reference,
}

/// The weight of a word the reader singled out.
///
/// BibleWorks: a double-clicked word "will be weighted as if it
/// occurred three times".
const kRelatedVersesEmphasisWeight = 3;

/// One related verse.
class RelatedVerseHit {
  const RelatedVerseHit({
    required this.verseIndex,
    required this.hits,
    required this.matchedTerms,
  });

  /// Position in the corpus passed to [buildRelatedVersesIndex].
  final int verseIndex;

  /// Weighted count of distinct shared words — the number BibleWorks
  /// prints in brackets.
  final int hits;

  /// Which words matched, in candidate order. What the reader needs in
  /// order to see WHY this verse came back.
  final List<String> matchedTerms;

  @override
  String toString() => '#$verseIndex[$hits]${matchedTerms.join(",")}';
}

/// The default "N or more hits" cutoff for [enabledCount] checked words.
///
/// BibleWorks: "The default threshold is 1/3 or less of the checked
/// words". Never below 2, because a threshold of 1 returns every verse
/// that shares any word at all, which for even a moderately common
/// word is thousands of them — a list that long is the same as no
/// answer.
int defaultRelatedThreshold(int enabledCount) {
  if (enabledCount <= 0) return 1;
  final third = (enabledCount / 3).round();
  if (enabledCount < 2) return 1;
  return third < 2 ? 2 : third;
}

/// Rank the corpus against the base verse.
///
/// Only the words in [enabled] count. Words also in [emphasized] score
/// [kRelatedVersesEmphasisWeight] instead of 1. Verses scoring below
/// [threshold] are dropped, and at most [limit] survive.
List<RelatedVerseHit> scoreRelatedVerses({
  required RelatedVersesIndex index,
  required Set<String> enabled,
  Set<String> emphasized = const {},
  required int threshold,
  RelatedVersesSort sort = RelatedVersesSort.hits,
  int limit = 300,
}) {
  if (index.isEmpty || enabled.isEmpty) return const [];

  final scores = <int, int>{};
  final matched = <int, List<String>>{};
  // Candidate order, not set order, so `matchedTerms` reads in the
  // order the words occur in the verse.
  for (final t in index.terms) {
    if (!enabled.contains(t.term)) continue;
    final posting = index.postings[t.term];
    if (posting == null) continue;
    final weight =
        emphasized.contains(t.term) ? kRelatedVersesEmphasisWeight : 1;
    for (final i in posting) {
      scores[i] = (scores[i] ?? 0) + weight;
      (matched[i] ??= <String>[]).add(t.term);
    }
  }

  final out = <RelatedVerseHit>[
    for (final e in scores.entries)
      if (e.value >= threshold)
        RelatedVerseHit(
          verseIndex: e.key,
          hits: e.value,
          matchedTerms: matched[e.key] ?? const [],
        ),
  ];

  switch (sort) {
    case RelatedVersesSort.hits:
      // Ties fall back to corpus order, so equally-related verses read
      // Genesis-first instead of in hash order — which would also mean
      // the list reshuffled itself between rebuilds.
      out.sort((a, b) {
        final c = b.hits.compareTo(a.hits);
        return c != 0 ? c : a.verseIndex.compareTo(b.verseIndex);
      });
    case RelatedVersesSort.reference:
      out.sort((a, b) => a.verseIndex.compareTo(b.verseIndex));
  }
  return out.length <= limit ? out : out.sublist(0, limit);
}

/// Break a hit list into BibleWorks' "N hits in verse" bands.
///
/// BibleWorks prints a header above each run of equally-scoring verses
/// rather than repeating the count on every line. Meaningful only for
/// [RelatedVersesSort.hits]; encounter order is preserved, so a list
/// sorted any other way simply yields one band per run.
List<({int hits, List<RelatedVerseHit> verses})> groupRelatedByHits(
  List<RelatedVerseHit> hits,
) {
  final out = <({int hits, List<RelatedVerseHit> verses})>[];
  for (final h in hits) {
    if (out.isEmpty || out.last.hits != h.hits) {
      out.add((hits: h.hits, verses: <RelatedVerseHit>[h]));
    } else {
      out.last.verses.add(h);
    }
  }
  return out;
}

// ── Showing the reader why ──────────────────────────────────────────

/// Split [text] so the shared words can be marked where they occur.
///
/// Token-aligned, not substring: "sin" must not light up inside
/// "since". Chinese bigrams overlap by a character (神创 and 创造 share
/// 创), so adjacent and overlapping matches are merged into one run —
/// otherwise a matched Chinese phrase would render as a stack of
/// alternating half-highlighted characters.
List<HighlightSpan> highlightRelatedTerms(String text, Set<String> terms) {
  if (text.isEmpty) return const [];
  if (terms.isEmpty) return [HighlightSpan(text, false)];

  final ranges = <(int, int)>[];
  for (final s in _spans(text)) {
    if (terms.contains(s.token)) ranges.add((s.start, s.end));
  }
  if (ranges.isEmpty) return [HighlightSpan(text, false)];

  final merged = <(int, int)>[];
  for (final r in ranges) {
    if (merged.isNotEmpty && r.$1 <= merged.last.$2) {
      final last = merged.removeLast();
      merged.add((last.$1, r.$2 > last.$2 ? r.$2 : last.$2));
    } else {
      merged.add(r);
    }
  }

  final out = <HighlightSpan>[];
  var cursor = 0;
  for (final (start, end) in merged) {
    if (start > cursor) {
      out.add(HighlightSpan(text.substring(cursor, start), false));
    }
    out.add(HighlightSpan(text.substring(start, end), true));
    cursor = end;
  }
  if (cursor < text.length) {
    out.add(HighlightSpan(text.substring(cursor), false));
  }
  return out;
}
