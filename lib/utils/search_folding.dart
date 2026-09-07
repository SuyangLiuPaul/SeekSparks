/// Whether a search ignores Hebrew vowel points and Greek accents —
/// BibleWorks help topic bwh17, "Including Vowel Points in Hebrew
/// Searches and Accents in Greek".
///
/// ## What the backlog entry said, and what was actually true
///
/// `docs/PARITY-BACKLOG.md` §3.1 recorded: *"Hebrew points are stripped
/// when the query contains Hebrew; Greek accents are not stripped …
/// ours is a hardcoded asymmetry."* That was written 2026-08-12 and
/// stopped being true four days later: #321 folded BOTH, on both sides
/// of the comparison, because Aunty Rosa searched `ὁ θεός` against a
/// corpus that spells it `ο θεος` and got a blank page.
///
/// So the asymmetry was already gone. What is missing is the thing
/// bwh17 actually offers, which the entry mentioned only in passing:
/// **the choice**. Folding is right for a reader who types what they see
/// and wrong for one who wants the pointing to count — `בָּרָא` and
/// `בָּרָה` share three consonants and are different words, and a
/// search that cannot tell them apart cannot answer a question about
/// vocalisation. Sixth confirmed case of §1's "the code will not rot,
/// this document will".
///
/// ## Why a switch here rather than a parameter threaded through
///
/// Six call sites fold, and they must agree or the search lies:
///
///   * the corpus key (`searchCorpusKey`)                — the haystack
///   * the plain scan's query (`SearchService.scanText`) — the needle
///   * `TokenMatcher`'s compile and the command matcher's verse tokens
///     (`command_query.dart`)                            — both sides
///   * both halves of `search_highlight.dart`            — what is drawn
///
/// Two of those run inside `parseCommandQuery`, which has no settings in
/// scope and is deliberately Flutter-free, and the corpus key is built
/// by a lazy getter on a provider. Threading a flag to all six means
/// giving the parser a parameter it would carry only to hand on — and
/// the failure mode of getting it wrong is not a crash but a **silent
/// asymmetry**: fold one side and not the other, and the search simply
/// finds nothing, which is exactly the defect #321 existed to fix.
///
/// One switch that all six read cannot be half-applied. It is a single
/// global user preference with a single writer (Settings), which is the
/// one shape a global variable is honest about.
///
/// **Anything that caches a folded string must invalidate on
/// [searchFoldingGeneration].** `MainProvider.searchKeys` does; it is
/// the only such cache, and the counter exists so that a second one
/// cannot be added without meeting this comment.
library;

import 'package:seeksparks/utils/diacritics.dart'
    show FoldedText, foldDiacritics, foldDiacriticsAligned;

bool _ignorePointing = true;
int _generation = 0;

/// True when searches ignore Hebrew points and Greek accents.
///
/// Default true: it is what this app has done since #321, and it is the
/// answer a reader who types what they see on screen needs.
bool get searchIgnoresPointing => _ignorePointing;

/// Bumped whenever [searchIgnoresPointing] changes. Caches of folded
/// text compare against this and rebuild when it moves.
int get searchFoldingGeneration => _generation;

/// Set by `AppSettings`, on load and on change. Returns true when the
/// value actually moved, so a caller can skip an invalidation it does
/// not need.
bool setSearchIgnoresPointing(bool value) {
  if (_ignorePointing == value) return false;
  _ignorePointing = value;
  _generation++;
  return true;
}

/// Reset to the shipped default. Tests only — the app has one writer.
void resetSearchFoldingForTest() {
  _ignorePointing = true;
  _generation++;
}

/// The fold every side of a search goes through.
///
/// [foldDiacritics] itself stays unconditional and is still the right
/// call for collation and transliteration (`lexicon_browse.dart`,
/// `romanised_lemma.dart`): a lexicon's alphabetical order does not
/// change because a reader wants a pointed search.
String foldSearchMarks(String s) =>
    _ignorePointing ? foldDiacritics(s) : s;

/// [foldDiacriticsAligned] under the same switch.
///
/// When the reader has asked for the pointing to count, the "fold" is
/// the identity — and it still has to arrive as a [FoldedText], because
/// the highlighter slices the ORIGINAL string by `sourceIndex` and a
/// null here would mean two code paths for one drawing. The identity
/// mapping is `i → i`, plus the trailing length entry the contract
/// requires.
FoldedText foldSearchMarksAligned(String s) {
  if (_ignorePointing) return foldDiacriticsAligned(s);
  return FoldedText(s, [for (var i = 0; i <= s.length; i++) i]);
}
