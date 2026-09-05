// SeekSparks addition: word-order proximity check for the NEARn and
// BEFOREn operators in `strongs_boolean_search.dart`.
//
// Whether two Strong's numbers are "within N words" of each other can only
// be answered from a verse's actual word order, which the concordance
// (verse-level occurrence sets) doesn't carry. This file is the pure
// logic — given the ordered list of Strong's numbers for one verse's
// words (as bundled in `assets/originals/<book>.json`, already loaded via
// `OriginalsService.forVerse`), it answers the yes/no proximity question.
// No asset/Flutter dependency, so it stays unit-testable on its own.

import 'strongs_boolean_search.dart' show StrongsTerm;

bool _matches(String strongsNumber, StrongsTerm term) {
  return term.wildcard
      ? strongsNumber.startsWith(term.number)
      : strongsNumber == term.number;
}

/// True when some occurrence of [termA] and some occurrence of [termB] in
/// [strongsNumbersInOrder] (one verse's words, in reading order) are within
/// [maxWords] words of each other. Distance is measured in word positions;
/// NEAR1 means adjacent words (distance 1 apart), NEAR0 would mean the
/// same word so [maxWords] is expected to be >= 1.
///
/// When [termA] and [termB] are the same term (e.g. a repeated word), two
/// distinct occurrences still count — the check only looks at position,
/// not term identity.
///
/// [ordered] is `BEFOREn` rather than `NEARn` (2026-09-05): [termA] must
/// come FIRST. It defaults to false, which is the question this function
/// answered for its first three months and the one every existing caller
/// is asking.
///
/// Note what ordering does NOT change: the pair still has to be two
/// distinct words, and the distance is still `b - a`. What it removes is
/// the mirror half of the search — with [ordered] set, an occurrence of
/// B four words *before* A no longer satisfies the query, which is the
/// entire reason a directional result set differs from an unordered one.
bool verseSatisfiesProximity({
  required List<String> strongsNumbersInOrder,
  required StrongsTerm termA,
  required StrongsTerm termB,
  required int maxWords,
  bool ordered = false,
}) {
  final aPositions = <int>[];
  final bPositions = <int>[];
  for (var i = 0; i < strongsNumbersInOrder.length; i++) {
    final s = strongsNumbersInOrder[i];
    if (_matches(s, termA)) aPositions.add(i);
    if (_matches(s, termB)) bPositions.add(i);
  }
  for (final a in aPositions) {
    for (final b in bPositions) {
      if (a == b) continue; // same word can't satisfy proximity to itself
      if (ordered) {
        if (b > a && b - a <= maxWords) return true;
      } else if ((a - b).abs() <= maxWords) {
        return true;
      }
    }
  }
  return false;
}
