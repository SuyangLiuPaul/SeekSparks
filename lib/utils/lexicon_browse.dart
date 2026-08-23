/// 2026-08-23: the browsable side of the Strong's lexicons — BibleWorks
/// help topic bwh35, the Lexicon and Dictionary Browser.
///
/// **Why it exists.** `StrongsService` has always answered "what does
/// this word mean" — you tap a word in the text and
/// `strongs_entry_page.dart` shows you its entry. That is the only door,
/// and it opens one way: you must already have the word in front of you.
/// bwh35 is the other direction, and it lists the capability plainly:
/// "look up any word or entry … by typing in the word or entry, **or by
/// scrolling through a complete list of entries**", and "do wildcard
/// searches on both the list of entries **and on the entire text of the
/// databases**". A reader who wants to know which entries discuss a
/// covenant, or what sits either side of ἀγάπη, could not ask.
///
/// **bwh35's two searches are genuinely two, and the help separates them
/// deliberately.** The box above the entry list filters the *headwords*
/// ("enter `*ew` … you will see a list of all Greek words ending in
/// ew"); `Edit ▸ Search` searches the *body* of the articles. They
/// answer different questions and return different things, so they are
/// [matchHeadwords] and [searchDefinitions] here, never one blurred box.
///
/// **The measurement that shaped all of it: alphabetical order is not
/// the order the characters are in.** Taken over the shipped assets
/// before any of this was written:
///
/// * **1,994 of 5,523 Greek lemmas (36%) begin with a precomposed
///   polytonic codepoint** in U+1F00–U+1FFF, which sorts *after* the
///   whole basic Greek block. Under a plain `sort()` every word carrying
///   a breathing mark is exiled past ω: **ἀγάπη lands at index 3,528 of
///   5,516** in a list whose only promise is that it is alphabetical.
///   Folded, it lands at 27, which is where alpha belongs.
/// * **All 8,674 Hebrew lemmas carry combining points**, and a plain
///   sort compares the *vowel* before the next consonant — so the aleph
///   section opened at אֱגוֹז (a nut) and אָב, H1, the first word of
///   every printed Hebrew lexicon, was nowhere near it.
/// * The two scripts encode their marks by **different mechanisms** —
///   Greek precomposed, Hebrew combining — so one naive strip fixes
///   exactly one of them. [lexiconCollationKey] goes through
///   `foldDiacritics`, which #321 built to handle both.
///
/// Proof the key is right, and it is cheap to re-run: the distinct
/// initials it produces are **exactly the 22 Hebrew letters** (the five
/// final forms correctly absent, since no word begins with one) and
/// **exactly the 24 Greek letters**. The two enclitics G4452 `-πω` and
/// G4458 `-πώς` file under no letter at all, which is right — they are
/// suffixes, and a printed lexicon does not shelve them under pi either.
///
/// **Strong's numbering is itself the printed lexicon order**, which is
/// why [LexiconOrder.number] is offered as a peer and not a debug view:
/// walked in number order, the folded lemmas are non-decreasing at
/// **99.5% of Greek steps and 99.0% of Hebrew steps**. The two orders
/// agree about the shape of the book and disagree only about homographs.
///
/// Pure — no Flutter, no assets, no I/O. Counts returned are TOTALS and
/// never the length of the page handed back: a cap on a sorted list is a
/// silent WHERE clause, and the caller has to be able to name what it
/// hid.
library;

import 'package:seeksparks/utils/diacritics.dart' show foldDiacritics;
import 'package:seeksparks/utils/romanised_lemma.dart'
    show collapseGreek, collapseHebrew, romanisedKey;

/// Which lexicon is open. BibleWorks lists "the Hebrew Lexicons first,
/// then the Greek"; the order here follows it, and matches the canon.
enum LexiconId { hebrew, greek }

extension LexiconIdX on LexiconId {
  /// The Strong's prefix this lexicon numbers its entries with.
  String get prefix => this == LexiconId.hebrew ? 'H' : 'G';
}

/// How the entry list is ordered.
///
/// Both are real lexicon orders and neither is a fallback — see the
/// 99.5% / 99.0% agreement in the library comment. [alphabetical] is
/// what a printed lexicon looks like; [number] is what a concordance
/// looks like, and it is the order a reader following G26 → G25 wants.
enum LexiconOrder { alphabetical, number }

/// One row of the entry list: enough to draw it and to match against,
/// with the collation key computed once rather than per comparison.
class LexiconHead {
  LexiconHead({
    required this.number,
    required this.lemma,
    required this.translit,
    required this.gloss,
  })  : sortKey = lexiconCollationKey(lemma),
        isHebrew = number.toUpperCase().startsWith('H'),
        _strictKey = romanisedKey(translit, fromLexicon: true) ?? '',
        _numeric = _numberOf(number) {
    _looseKey = isHebrew ? collapseHebrew(_strictKey) : collapseGreek(_strictKey);
  }

  final String number;
  final String lemma;
  final String translit;
  final String gloss;
  final bool isHebrew;

  /// The lemma folded for ordering and matching. Never displayed — an
  /// accent is part of the word, and #321's rule is that the fold lives
  /// in the comparison layer and dies there.
  final String sortKey;

  /// The two romanised keys bwh45 already established, reused rather
  /// than re-derived. `lexiconCollationKey` is not enough for a
  /// transliteration: it leaves Strong's `ʼ` for aleph and its
  /// superscript shewa `ᵉ` in place, so a reader typing `elohim` would
  /// miss `ʼĕlôhîym`, and the 1890 spelling differs from the modern one
  /// at a dozen systematic points besides. [_strictKey] is the printed
  /// romanisation reduced to `a-z`; [_looseKey] is that put through the
  /// language's collapse rules.
  final String _strictKey;
  late final String _looseKey;
  final int _numeric;

  /// The letter this entry files under, for the alphabet index. Empty
  /// for the handful of entries that begin with punctuation.
  String get initial {
    if (sortKey.isEmpty) return '';
    final c = sortKey[0];
    return RegExp(r'\p{L}', unicode: true).hasMatch(c) ? c : '';
  }

  static int _numberOf(String n) =>
      int.tryParse(n.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
}

/// Sort [heads] into [order]. Returns a new list; the input is untouched.
///
/// Alphabetical ties break on the Strong's number rather than on the raw
/// string, because Strong's assigned its numbers in lexicon order: the
/// three spellings of אב stay in the order a printed lexicon prints
/// them, instead of in the order their vowel points happen to sit in
/// Unicode.
List<LexiconHead> sortHeads(List<LexiconHead> heads, LexiconOrder order) {
  final out = [...heads];
  if (order == LexiconOrder.number) {
    out.sort((a, b) => a._numeric.compareTo(b._numeric));
  } else {
    out.sort((a, b) {
      final k = a.sortKey.compareTo(b.sortKey);
      return k != 0 ? k : a._numeric.compareTo(b._numeric);
    });
  }
  return out;
}

/// The distinct initials present in [heads], in collation order — the
/// alphabet strip down the side of the list.
///
/// Derived from the data rather than from a hardcoded alphabet, so a
/// letter with no entries is never offered and a lexicon we have not
/// seen yet still gets a correct strip.
List<String> alphabetOf(List<LexiconHead> heads) {
  final set = <String>{};
  for (final h in heads) {
    final i = h.initial;
    if (i.isNotEmpty) set.add(i);
  }
  final out = set.toList()..sort();
  return out;
}

// ── Tier one: the headword list ─────────────────────────────────────

/// Match [query] against the headwords of [heads].
///
/// **Three things are matched, because a reader has three ways to name
/// an entry and only one of them needs a Greek keyboard:** the lemma
/// (ἀγάπη), the romanisation (so typing `agape` arrives), and the
/// Strong's number, with or without its prefix (`G26`, `26`). Diacritics
/// are folded on both sides, which is #321's fix applied to this surface
/// before a reader has to report it a second time.
///
/// **The romanised tier is bwh45's, not a second one.** It runs the
/// query through the same [romanisedKey] and the same collapse rules the
/// search line already offers lemmas with, so `elohim` reaches H430 here
/// exactly as it does there. Two romanisations in one app would drift,
/// and the reader would meet the difference as a lexicon that "does not
/// have" a word she just searched for. The one relaxation is the
/// three-letter floor: it exists to stop the *unbidden* offer firing on
/// half the index, and this box was typed into on purpose, so `ab`
/// filters rather than being refused.
///
/// **Wildcards.** `*` matches any run of characters, as bwh35 specifies:
/// `*ew` gives every word ending in `ew`, `*ag*` every word containing
/// `ag`. A query with no `*` is a PREFIX match, not a substring one —
/// bwh35's bare word "scroll[s] to the proper location", and a prefix is
/// what that looks like in a list you can also see. Substring-by-default
/// would answer `α` with most of the lexicon.
///
/// Exact matches are hoisted to the front so that typing a whole word
/// puts it under the cursor rather than three inflections above it.
/// Otherwise the collation order is preserved: relevance ranking over a
/// lexicon would be a guess, and order is a promise the reader can hold.
///
/// Uncapped on purpose — the caller prints a total, and a total that was
/// itself truncated is worse than no total.
List<LexiconHead> matchHeadwords(List<LexiconHead> heads, String query) {
  final q = lexiconCollationKey(query);
  if (q.isEmpty) return const [];

  final numeric = _numericQuery(query);
  final match = _matcher(q);

  // Null when the line is not romanisable at all — Greek or Hebrew
  // script, or CJK. That is not a failure: such a query has nothing to
  // say to a Latin key, and the lemma tier is already answering it.
  final roman = _romanisedQuery(query);
  final matchStrict = roman == null ? null : _matcher(roman);
  final looseHeb = roman == null ? null : collapseHebrew(roman);
  final looseGrk = roman == null ? null : collapseGreek(roman);
  final matchLooseHeb = looseHeb == null ? null : _matcher(looseHeb);
  final matchLooseGrk = looseGrk == null ? null : _matcher(looseGrk);

  final exact = <LexiconHead>[];
  final rest = <LexiconHead>[];
  for (final h in heads) {
    if (numeric != null && h._numeric == numeric && _sameLanguage(h, query)) {
      exact.add(h);
      continue;
    }
    if (match(h.sortKey)) {
      (h.sortKey == q ? exact : rest).add(h);
      continue;
    }
    if (roman == null || h._strictKey.isEmpty) continue;
    if (matchStrict!(h._strictKey)) {
      (h._strictKey == roman ? exact : rest).add(h);
      continue;
    }
    final loose = h.isHebrew ? looseHeb! : looseGrk!;
    final matchLoose = h.isHebrew ? matchLooseHeb! : matchLooseGrk!;
    if (matchLoose(h._looseKey)) {
      (h._looseKey == loose ? exact : rest).add(h);
    }
  }
  return [...exact, ...rest];
}

/// The query reduced to the romanised key space, `*` preserved.
///
/// [romanisedKey] refuses anything outside `a-z`, so a wildcard cannot
/// be handed to it whole; each fragment is romanised on its own and the
/// stars are put back. A fragment that will not romanise fails the whole
/// query rather than being dropped, because dropping it would silently
/// widen the search — `agap*θ` would become `agap*`, and the reader
/// would be shown matches for something she did not ask.
String? _romanisedQuery(String query) {
  final parts = query.trim().split('*');
  final out = <String>[];
  var any = false;
  for (final p in parts) {
    if (p.isEmpty) {
      out.add('');
      continue;
    }
    final k = romanisedKey(p, fromLexicon: true);
    if (k == null) return null;
    any = true;
    out.add(k);
  }
  return any ? out.join('*') : null;
}

/// `26` and `G26` both name an entry; `G26` must not also match H26.
/// A bare number carries no language, so it matches in whichever
/// lexicon is open — which is the one the caller passed in.
bool _sameLanguage(LexiconHead h, String query) {
  final m = RegExp(r'^\s*([GgHh])').firstMatch(query);
  if (m == null) return true;
  return h.number.toUpperCase().startsWith(m.group(1)!.toUpperCase());
}

int? _numericQuery(String query) {
  final m = RegExp(r'^\s*[GgHh]?\s*(\d+)\s*$').firstMatch(query);
  return m == null ? null : int.tryParse(m.group(1)!);
}

/// A folded query becomes a predicate. Split out so both tiers use the
/// same wildcard rule and cannot drift apart.
bool Function(String) _matcher(String foldedQuery) {
  if (!foldedQuery.contains('*')) {
    return (s) => s.startsWith(foldedQuery);
  }
  final parts = foldedQuery.split('*');
  final anchoredStart = parts.first.isNotEmpty;
  final anchoredEnd = parts.last.isNotEmpty;
  final fragments = parts.where((p) => p.isNotEmpty).toList();
  if (fragments.isEmpty) return (_) => true;
  return (s) {
    var at = 0;
    for (var i = 0; i < fragments.length; i++) {
      final f = fragments[i];
      final found = s.indexOf(f, at);
      if (found < 0) return false;
      if (i == 0 && anchoredStart && found != 0) return false;
      at = found + f.length;
    }
    return !anchoredEnd || at == s.length;
  };
}

// ── Tier two: the text of the articles ──────────────────────────────

/// How the terms of a body search combine. bwh35 offers "And, Or,
/// String"; [phrase] is its String — the words in that order.
enum LexiconTextMode { and, or, phrase }

/// One article whose text matched, with the fragment that matched it.
class LexiconTextHit {
  const LexiconTextHit(this.number, this.excerpt);

  final String number;

  /// A window of the article around the first match, for the result
  /// row. The caller highlights; this only decides what to show.
  final String excerpt;
}

/// A page of body-text hits that still knows its own size.
class LexiconTextResult {
  const LexiconTextResult({required this.hits, required this.total});

  final List<LexiconTextHit> hits;

  /// How many articles matched in all — never `hits.length`.
  final int total;

  bool get truncated => total > hits.length;

  static const empty = LexiconTextResult(hits: [], total: 0);
}

/// Search the body text of the articles — bwh35's `Edit ▸ Search`, and
/// the question the headword list cannot answer: *which entries mention
/// covenant*.
///
/// [textOf] hands back everything of an article a reader would read. The
/// caller decides what that is, which is how one function serves the
/// English gloss and definition and the Chinese ones without knowing
/// about locales. It is called only for the rows that actually matched
/// and only while the page is unfilled, because it is the excerpt that
/// needs the original.
///
/// [foldedTextOf] is the same article already folded. Optional, and the
/// caller should supply it: the Hebrew lexicon is 845,000 characters of
/// article text, and folding all of it inside every keystroke is a
/// megabyte-per-character rebuild. Fold once, keep it, hand it in here.
///
/// **Matching is substring over folded text, and it over-matches on
/// purpose.** "covenant" also finds "covenanted"; a whole-word rule
/// would be wrong for Chinese, where there is no word boundary at all —
/// the same reason `phrase_match.dart` treats Han per character.
/// Over-matching shows a reader an entry they can judge; under-matching
/// tells them the lexicon is silent, which is the failure #321 was
/// reported for.
///
/// **What the fold does NOT do here, said plainly because the first
/// draft of this comment claimed otherwise and a test caught it:**
/// `foldDiacritics` folds accents, it does not transliterate. `theos`
/// typed into the article search does NOT reach an article that spells
/// the word θεός — Latin and Greek script are different strings and
/// folding leaves them different. Romanised input is answered by
/// [matchHeadwords], which goes through bwh45's index; this tier reads
/// the prose, and its prose is English or Chinese. Making it otherwise
/// would mean romanising every Greek run inside 1.3 million characters
/// of article text, which is a feature and not a fold.
///
/// Results stay in the [heads] order they were given, so the list a
/// reader searched and the list they get back are ordered the same way.
LexiconTextResult searchDefinitions(
  List<LexiconHead> heads,
  String query, {
  required String Function(String number) textOf,
  String Function(String number)? foldedTextOf,
  LexiconTextMode mode = LexiconTextMode.and,
  int limit = 200,
  int excerptRadius = 60,
}) {
  final terms = _terms(query, mode);
  if (terms.isEmpty) return LexiconTextResult.empty;

  final hits = <LexiconTextHit>[];
  var total = 0;
  for (final h in heads) {
    final folded = foldedTextOf == null
        ? lexiconCollationKey(textOf(h.number))
        : foldedTextOf(h.number);
    if (folded.isEmpty) continue;
    final at = _firstHit(folded, terms, mode);
    if (at < 0) continue;
    total++;
    if (hits.length < limit) {
      final raw = textOf(h.number);
      hits.add(
          LexiconTextHit(h.number, _excerpt(raw, folded, at, excerptRadius)));
    }
  }
  return LexiconTextResult(hits: hits, total: total);
}

List<String> _terms(String query, LexiconTextMode mode) {
  if (mode == LexiconTextMode.phrase) {
    final p = lexiconCollationKey(query);
    return p.isEmpty ? const [] : [p];
  }
  return [
    for (final w in query.split(RegExp(r'\s+')))
      if (lexiconCollationKey(w).isNotEmpty) lexiconCollationKey(w),
  ];
}

/// Offset of the match to build the excerpt around, or -1 for no match.
/// For AND every term must be present and the excerpt is built around
/// the FIRST of them in the text, not the first the reader typed — the
/// reader is shown where the article starts talking about their subject.
int _firstHit(String folded, List<String> terms, LexiconTextMode mode) {
  if (mode == LexiconTextMode.or) {
    var best = -1;
    for (final t in terms) {
      final i = folded.indexOf(t);
      if (i >= 0 && (best < 0 || i < best)) best = i;
    }
    return best;
  }
  var best = -1;
  for (final t in terms) {
    final i = folded.indexOf(t);
    if (i < 0) return -1;
    if (best < 0 || i < best) best = i;
  }
  return best;
}

/// A window of the ORIGINAL text around [at], which is an offset into
/// the FOLDED text.
///
/// The two are the same length by construction — `foldDiacritics` maps
/// codepoint to codepoint and drops only combining marks — so an offset
/// is not portable between them in general. The guard is explicit rather
/// than assumed: when the lengths differ the excerpt falls back to the
/// head of the article, which is always true even when it is not the
/// most useful thing to show.
String _excerpt(String raw, String folded, int at, int radius) {
  if (folded.length != raw.length) {
    return raw.length <= radius * 2 ? raw : '${raw.substring(0, radius * 2)}…';
  }
  var start = at - radius;
  var end = at + radius;
  if (start < 0) start = 0;
  if (end > raw.length) end = raw.length;
  final body = raw.substring(start, end);
  return '${start > 0 ? '…' : ''}$body${end < raw.length ? '…' : ''}';
}

// ── The key everything above rests on ───────────────────────────────

/// The comparison form of a lexicon string: diacritics folded, case
/// folded, whitespace trimmed.
///
/// **Never render this.** It is the same contract `foldDiacritics`
/// carries: ᾅ and ἁ and α all become α, so it is lossy and one-way, and
/// a reader who copies ἀγάπη must get ἀγάπη back. It exists so that a
/// Hebrew lexicon sorts by consonant and a Greek one sorts by letter,
/// and it dies in the comparison.
String lexiconCollationKey(String s) => foldDiacritics(s).toLowerCase().trim();
