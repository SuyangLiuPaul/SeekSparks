// 2026-06-18 (v1.3.91): boolean Strong's-number search.
// SeekSparks addition: NOT and NEARn (word-proximity) operators.
//
// Lets the user combine original-language word searches with set operators:
//
//   G25 AND G26     → verses that contain BOTH Strong's numbers
//   G25 OR G26      → verses that contain EITHER
//   G25 NOT G26     → verses with G25 but WITHOUT G26
//   G25 !G26        → the same; `!` is the NOT alias, spaced or glued
//   G25 NEAR5 G26   → verses where G25 and G26 occur within 5 words of
//                     each other (proximity is resolved separately — see
//                     `nearPairs` and `lib/utils/strongs_proximity.dart` —
//                     since it needs per-verse word order, not just set
//                     membership; the plain evaluator below treats NEAR
//                     like AND as a safe first-pass filter)
//   G25 G26         → implicit AND (adjacent terms)
//   G25* AND H7225  → "G25*" is a PREFIX wildcard: any Greek number whose
//                     digits start with "25" (G25, G250, G251, … G2599)
//
// This file is the PURE logic — a tokeniser/parser plus a set-operation
// evaluator that is given a `refsFor(term)` callback. The concordance data
// and UI live elsewhere (search_page.dart), so this stays unit-testable with
// no asset or Flutter dependency.

import 'package:seeksparks/utils/command_query.dart' show CommandIssue;

/// One term in a boolean query, e.g. `G25` or `H7225*`.
class StrongsTerm {
  /// 'G' (Greek) or 'H' (Hebrew).
  final String prefix;

  /// The digit string exactly as typed, leading zeros stripped ("25").
  final String digits;

  /// True when the term ended with `*` (prefix wildcard).
  final bool wildcard;

  const StrongsTerm({
    required this.prefix,
    required this.digits,
    required this.wildcard,
  });

  /// The canonical Strong's number for a NON-wildcard term (e.g. "G25").
  String get number => '$prefix$digits';

  @override
  String toString() => '$prefix$digits${wildcard ? '*' : ''}';

  @override
  bool operator ==(Object other) =>
      other is StrongsTerm &&
      other.prefix == prefix &&
      other.digits == digits &&
      other.wildcard == wildcard;

  @override
  int get hashCode => Object.hash(prefix, digits, wildcard);
}

/// A parsed boolean query: N terms joined by N-1 operators
/// (`ops[i]` joins `terms[i]` and `terms[i+1]`). Evaluated left to right.
/// `nearDistance[i]` holds the word-count for `ops[i] == StrongsOp.near`
/// (null for every other operator) — parallel-indexed to `ops`.
class StrongsBooleanQuery {
  final List<StrongsTerm> terms;
  final List<StrongsOp> ops;
  final List<int?> nearDistance;
  const StrongsBooleanQuery(this.terms, this.ops, [this.nearDistance = const []]);

  /// True when any operator is a proximity NEAR — the caller then needs
  /// the async per-verse word-order pass (see `strongs_proximity.dart`)
  /// on top of plain set algebra.
  bool get hasProximity => ops.contains(StrongsOp.near);
}

enum StrongsOp { and, or, not, near }

/// Largest word distance accepted after NEAR / WITHIN.
///
/// Declared so `describeCommandIssue` can quote the same number the parser
/// enforces. A NEARn above this is refused, not clamped — #311's rule:
/// two clamps that disagree with the control feeding them is how a
/// control comes to look dead.
const int kMaxNearDistance = 50;

/// The Strong's ranges this parser accepts. Deliberately a little above
/// the highest number either lexicon actually carries: the guard exists to
/// stop plain text like `H1 will` masquerading as an expression, not to
/// adjudicate what a real Strong's number is.
const int kMaxGreekStrongs = 5700;
const int kMaxHebrewStrongs = 8700;

final RegExp _termRe = RegExp(r'^([gGhH])0*(\d+)(\*?)$');
final RegExp _nearRe = RegExp(r'^(?:NEAR|WITHIN)(\d+)$');

/// Parse [input] into a boolean Strong's query, or return null when the
/// input is NOT a boolean Strong's expression (the caller then falls back to
/// single-Strong's / text / AI search). Returns non-null only when the query
/// is genuinely "combined": either 2+ Strong's terms, or a single wildcard
/// term (a single plain number like "G2664" stays null so the existing
/// single-entry lexicon path handles it).
StrongsBooleanQuery? parseStrongsBoolean(String input) {
  final raw = input.trim();
  if (raw.isEmpty) return null;
  final tokens = raw.split(RegExp(r'\s+'));
  final terms = <StrongsTerm>[];
  final ops = <StrongsOp>[];
  final nearDistance = <int?>[];
  // Expect: term (op term)* — operators are optional between two terms
  // (adjacent terms imply AND). Anything that isn't a term or a known
  // operator aborts the whole parse (→ null → fall back to text search).
  var expectingTerm = true;
  for (var tok in tokens) {
    // `G25 !G26` — the `!` button glues, because in a TEXT search `! word`
    // is a stray character the phrase parser drops. Split it back off here
    // so the same keystrokes mean NOT in both grammars; without this the
    // whole parse returned null and the query fell through to a text
    // search for the literal string "G25 !G26", which finds nothing and
    // looks exactly like a button that does not work.
    if (!expectingTerm && tok.length > 1 && tok.startsWith('!')) {
      ops.add(StrongsOp.not);
      nearDistance.add(null);
      expectingTerm = true;
      tok = tok.substring(1);
    }
    final upper = tok.toUpperCase();
    if (!expectingTerm && (upper == 'AND' || upper == '&' || upper == '+')) {
      ops.add(StrongsOp.and);
      nearDistance.add(null);
      expectingTerm = true;
      continue;
    }
    if (!expectingTerm && (upper == 'OR' || upper == '|' || upper == '/')) {
      ops.add(StrongsOp.or);
      nearDistance.add(null);
      expectingTerm = true;
      continue;
    }
    if (!expectingTerm && (upper == 'NOT' || upper == '!')) {
      ops.add(StrongsOp.not);
      nearDistance.add(null);
      expectingTerm = true;
      continue;
    }
    if (!expectingTerm) {
      final nearM = _nearRe.firstMatch(upper);
      if (nearM != null) {
        final n = int.parse(nearM.group(1)!);
        if (n < 1 || n > kMaxNearDistance) return null; // absurd distance, reject
        ops.add(StrongsOp.near);
        nearDistance.add(n);
        expectingTerm = true;
        continue;
      }
    }
    final m = _termRe.firstMatch(tok);
    if (m == null) return null; // not a Strong's term where one was needed
    final digits = m.group(2)!;
    // Reject absurd numbers so plain text like "H1 will" can't masquerade.
    final n = int.tryParse(digits) ?? 0;
    final prefix = m.group(1)!.toUpperCase();
    if (prefix == 'G' && (n < 1 || n > kMaxGreekStrongs)) return null;
    if (prefix == 'H' && (n < 1 || n > kMaxHebrewStrongs)) return null;
    if (!expectingTerm) {
      // Two terms with no operator between them → implicit AND.
      ops.add(StrongsOp.and);
      nearDistance.add(null);
    }
    terms.add(StrongsTerm(
      prefix: prefix,
      digits: digits,
      wildcard: m.group(3) == '*',
    ));
    expectingTerm = false;
  }
  if (expectingTerm) return null; // trailing operator, e.g. "G25 AND"
  // Only treat as boolean when it's actually combined.
  final isCombined = terms.length >= 2 || (terms.length == 1 && terms[0].wildcard);
  if (!isCombined) return null;
  return StrongsBooleanQuery(terms, ops, nearDistance);
}

/// Term-shape check only, no range: kept separate from [_termRe] (which is
/// identical today) because this one deliberately skips the 1..max range
/// guard — [diagnoseStrongsBoolean] needs to recognise a term SHAPE first
/// and decide separately whether its number is in range.
final RegExp _termShapeRe = RegExp(r'^([gGhH])0*(\d+)(\*?)$');
final RegExp _nearWordRe = RegExp(r'^(?:NEAR|WITHIN)(\d*)$');
const _strongsOpWords = {'AND', '&', '+', 'OR', '|', '/', 'NOT', '!'};

/// Why a line that LOOKS like a Strong's expression did not parse — or
/// null when it does not look like one at all.
///
/// [parseStrongsBoolean] returns null for two different situations and the
/// caller cannot tell them apart: `H1 will` is ordinary text that must go
/// to the text scan, and `G25 NEAR G26` is a Strong's expression the
/// parser REFUSED. Before this function the second was shown to the reader
/// as an empty result list for a literal substring search — the engine
/// declining a query and the app reporting "no verses" are different
/// facts, and the reader was only ever told the second one.
///
/// **Deliberately narrow.** It answers only when EVERY token is either a
/// Strong's-shaped token or a known operator, and at least one is
/// Strong's-shaped. One unrecognised word — `H1 will`, `G25 AND love` —
/// and this returns null and the text scan keeps the line. That loses the
/// chance to explain `G25 AND love`, and it is the right trade: a false
/// refusal takes a working text search away from a reader who never meant
/// to write an expression, while a missed explanation only leaves them
/// where they already were.
CommandIssue? diagnoseStrongsBoolean(String input) {
  final raw = input.trim();
  if (raw.isEmpty) return null;
  if (parseStrongsBoolean(raw) != null) return null;

  final terms = <Match>[];
  final ops = <String>[];
  final nearDigits = <String>[];
  var hasOther = false;

  var expectingTerm = true;
  for (var tok in raw.split(RegExp(r'\s+'))) {
    // Same `!`-gluing split the parser applies: a leading `!` on a
    // non-first token is an operator plus a term, e.g. `G25 !G26`.
    if (!expectingTerm && tok.length > 1 && tok.startsWith('!')) {
      ops.add('!');
      expectingTerm = true;
      tok = tok.substring(1);
    }
    final upper = tok.toUpperCase();
    if (_strongsOpWords.contains(upper)) {
      ops.add(upper);
      expectingTerm = true;
      continue;
    }
    final nearM = _nearWordRe.firstMatch(upper);
    if (nearM != null) {
      nearDigits.add(nearM.group(1) ?? '');
      expectingTerm = true;
      continue;
    }
    final termM = _termShapeRe.firstMatch(tok);
    if (termM != null) {
      terms.add(termM);
      expectingTerm = false;
      continue;
    }
    hasOther = true;
    expectingTerm = false;
  }

  if (hasOther) return null;
  if (terms.isEmpty) return null;
  // A single valid-shaped term with no operator and no NEAR word is the
  // single-lexicon lookup path (`_singleStrongsRe` in the provider),
  // handled elsewhere and out of scope here.
  if (ops.isEmpty && nearDigits.isEmpty && terms.length == 1) return null;

  for (final d in nearDigits) {
    if (d.isEmpty) return CommandIssue.strongsNearNeedsDistance;
  }
  for (final d in nearDigits) {
    final n = int.tryParse(d);
    if (n == null || n < 1 || n > kMaxNearDistance) {
      return CommandIssue.strongsNearDistanceOutOfRange;
    }
  }
  for (final m in terms) {
    final digits = m.group(2)!;
    final n = int.tryParse(digits) ?? 0;
    final prefix = m.group(1)!.toUpperCase();
    if (prefix == 'G' && (n < 1 || n > kMaxGreekStrongs)) {
      return CommandIssue.strongsNumberOutOfRange;
    }
    if (prefix == 'H' && (n < 1 || n > kMaxHebrewStrongs)) {
      return CommandIssue.strongsNumberOutOfRange;
    }
  }
  return CommandIssue.strongsOperatorNeedsTerms;
}

/// Evaluate [query] to the set of verse-reference labels (e.g. "John 3:16")
/// that satisfy it. [refsFor] resolves a single term to its occurrence set
/// (handling wildcard expansion + concordance lookup); this function only
/// applies the AND/OR/NOT set algebra, left to right. A NEAR operator is
/// treated as AND here (both terms must co-occur in the verse) — the
/// caller narrows a NEAR result further with the async per-verse
/// word-order check in `strongs_proximity.dart` before showing it to the
/// user, since true proximity needs word position, not just set membership.
Set<String> evaluateStrongsBoolean(
  StrongsBooleanQuery query,
  Set<String> Function(StrongsTerm term) refsFor,
) {
  if (query.terms.isEmpty) return <String>{};
  var acc = <String>{...refsFor(query.terms.first)};
  for (var i = 0; i < query.ops.length; i++) {
    final next = refsFor(query.terms[i + 1]);
    switch (query.ops[i]) {
      case StrongsOp.and:
      case StrongsOp.near:
        acc = acc.intersection(next);
        break;
      case StrongsOp.or:
        acc = acc.union(next);
        break;
      case StrongsOp.not:
        acc = acc.difference(next);
        break;
    }
  }
  return acc;
}

/// The (termIndex, termIndex+1, maxWords) triples in [query] whose operator
/// is NEAR — i.e. the adjacent-term pairs that need the extra per-verse
/// word-order check on top of the plain set algebra above.
List<(int, int, int)> nearPairs(StrongsBooleanQuery query) {
  final out = <(int, int, int)>[];
  for (var i = 0; i < query.ops.length; i++) {
    if (query.ops[i] == StrongsOp.near) {
      out.add((i, i + 1, query.nearDistance[i]!));
    }
  }
  return out;
}
