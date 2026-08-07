/// 2026-08-07 (SeekSparks): part of speech, read off the morphology code.
///
/// Needed by the Context tab (BibleWorks `bwh10h`). A raw frequency list
/// of any passage is topped by the article, `καί`, and the prepositions,
/// which is why the published reviews of BibleWorks' own Context tab say
/// you have to "scroll past insignificant high frequency words like
/// articles, pronouns, and prepositions". Filtering by part of speech is
/// what turns that list into something that answers a question.
///
/// **The two schemes disagree about letters, and that is the whole
/// difficulty.** `assets/originals/` carries Greek in the CCAT/Nestle
/// scheme and Hebrew/Aramaic in the OSHB scheme:
///
/// | letter | Greek       | Hebrew/Aramaic |
/// |--------|-------------|----------------|
/// | `R`    | pronoun     | preposition    |
/// | `P`    | preposition | pronoun        |
///
/// So the language must be decided FIRST, from the Strong's prefix
/// (`G…` / `H…`) — never from the morphology string, whose own first
/// letter is a language marker in Hebrew (`H`/`A`) and a part of speech
/// in Greek (`A-----NPN-` is an adjective, not Aramaic).
///
/// **Semitic codes are compound, and the head is not at a fixed end.**
/// The code is a `/`-joined chain of morphemes and the Strong's number
/// belongs to exactly one of them:
///
///   * `HTd/Ncmpa`     — article **prefix**, noun last  (הַשָּׁמַיִם, H8064)
///   * `ANcmsd/Td`     — noun **first**, article last   (מַלְכָּא, H4430)
///   * `HR/Ncmsc/Sp3ms`— noun in the middle, pronominal suffix last
///   * `HC/To`         — conjunction prefix, object marker last (H853)
///
/// Neither "take the first segment" nor "take the last" is right; both
/// are wrong on real verses in Genesis 1. The rule used here is to take
/// the first segment that carries content (noun/verb/adjective/adverb),
/// and only failing that the last segment that is not a suffix.
library;

/// The part-of-speech buckets the Context tab filters on. Deliberately
/// coarse: the question is "is this a content word", not "what is its
/// case", and a longer list would only make the filter unusable in a
/// 320 px pane.
enum WordPos {
  noun,
  verb,
  adjective,
  adverb,
  pronoun,
  article,
  preposition,
  conjunction,
  particle,
  interjection,

  /// No morphology code, or a code neither scheme explains. ~0.7% of
  /// the corpus. Counted as content and shown by default: dropping a
  /// real word because we could not parse its tag is the worse error.
  unknown,
}

/// What survives the default filter — the words a passage is *about*.
const kContentPos = <WordPos>{
  WordPos.noun,
  WordPos.verb,
  WordPos.adjective,
  WordPos.adverb,
  WordPos.unknown,
};

/// The rest: grammar rather than subject matter.
const kFunctionPos = <WordPos>{
  WordPos.pronoun,
  WordPos.article,
  WordPos.preposition,
  WordPos.conjunction,
  WordPos.particle,
  WordPos.interjection,
};

/// Classify one tagged word.
///
/// [strongs] decides the scheme; [morph] is the code from
/// `assets/originals/`. Anything unrecognised is [WordPos.unknown]
/// rather than a guess.
WordPos posOf(String strongs, String? morph) {
  final code = (morph ?? '').trim();
  if (code.isEmpty) return WordPos.unknown;
  final lang = strongs.trim().toUpperCase();
  if (lang.startsWith('H')) return _semitic(code);
  if (lang.startsWith('G')) return _greek(code);
  return WordPos.unknown;
}

WordPos _greek(String code) {
  // `RA` is the article; every other `R…` is a pronoun. Checked before
  // the single-letter switch because both start with the same letter.
  if (code.startsWith('RA')) return WordPos.article;
  switch (code[0]) {
    case 'N':
      return WordPos.noun;
    case 'V':
      return WordPos.verb;
    // `M` is the numeral tag; numerals are adjectives for this purpose,
    // and Hebrew has no separate numeral bucket either, so keeping them
    // apart would make the two languages filter differently.
    case 'A':
    case 'M':
      return WordPos.adjective;
    case 'D':
      return WordPos.adverb;
    case 'R':
      return WordPos.pronoun;
    case 'P':
      return WordPos.preposition;
    case 'C':
      return WordPos.conjunction;
    case 'X':
      return WordPos.particle;
    case 'I':
      return WordPos.interjection;
    default:
      return WordPos.unknown;
  }
}

WordPos _semitic(String code) {
  final segments = _stripLanguageMarker(code)
      .split('/')
      .where((s) => s.isNotEmpty)
      .toList(growable: false);
  if (segments.isEmpty) return WordPos.unknown;

  // The head morpheme is the one the Strong's number names. Prefer the
  // first content-bearing segment: that is the noun in `HTd/Ncmpa`, in
  // `ANcmsd/Td`, and in `HR/Ncmsc/Sp3ms` alike.
  for (final seg in segments) {
    final pos = _semiticSegment(seg);
    if (kContentPos.contains(pos) && pos != WordPos.unknown) return pos;
  }
  // Nothing contentful: the word IS a function word. Take the LAST
  // non-suffix segment — `HC/To` is the object marker with a prefixed
  // conjunction, not a conjunction.
  for (final seg in segments.reversed) {
    if (seg.startsWith('S')) continue;
    return _semiticSegment(seg);
  }
  return _semiticSegment(segments.first);
}

/// Drop the `H`/`A` language marker that opens an OSHB code.
///
/// Only when the next character is uppercase, i.e. it is really a
/// part-of-speech letter underneath. Without that guard a bare
/// `Aamsa` (adjective, no marker) would be read as Aramaic and lose
/// its own tag.
String _stripLanguageMarker(String code) {
  if (code.length < 2) return code;
  final first = code[0];
  if (first != 'H' && first != 'A') return code;
  final next = code[1];
  if (next.toUpperCase() != next) return code;
  return code.substring(1);
}

WordPos _semiticSegment(String seg) {
  // `Td` is the definite article; the other `T…` tags are particles
  // (negative, interrogative, object marker, interjection).
  if (seg.startsWith('Td')) return WordPos.article;
  switch (seg[0]) {
    case 'N':
      return WordPos.noun;
    case 'V':
      return WordPos.verb;
    case 'A':
      return WordPos.adjective;
    case 'D':
      return WordPos.adverb;
    case 'P':
      return WordPos.pronoun;
    case 'R':
      return WordPos.preposition;
    case 'C':
      return WordPos.conjunction;
    case 'T':
      return WordPos.particle;
    default:
      // `S…` is a suffix, which is never a head; anything else is a tag
      // this scheme does not define.
      return WordPos.unknown;
  }
}
