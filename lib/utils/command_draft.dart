// 2026-08-08 (task #294): what the command line currently holds, read from
// the operator strip's point of view.
//
// The strip under the command line carries THREE grammars on one
// undifferentiated row of identical buttons:
//
//   . / '        line mode   — first position only, mutually exclusive
//   ! *          modifiers   — attach to a word of a TEXT search
//   AND OR NOT NEARn BEFOREn — combine two STRONG'S NUMBERS
//
// Nothing on screen says which is which, and two of them mean different
// things in the two grammars (`*` is a character wildcard glued to a word,
// a word gap standing alone, and a prefix wildcard after a Strong's
// number; `!` negates a term in text and is an alias for NOT in a
// Strong's expression). A reader who taps `NEAR5` on an empty line gets
// `NEAR5 ` and, on Enter, a text search for the literal string — which is
// indistinguishable from a dead button.
//
// This file is the pure part of the answer: given the raw line, say which
// grammar it is in, whether the combining operators can do anything yet,
// where a `NEARn` token sits so its distance can be edited in place, and
// what the line still needs. No Flutter, no assets.

import 'package:seeksparks/constants/ui_strings.dart';

import 'command_query.dart' show kCommandControls, kMaxWordGap;
import 'strongs_boolean_search.dart' show parseStrongsBoolean;

/// Which grammar the line is currently in.
enum CommandDraftMode {
  /// Nothing typed.
  empty,

  /// A text search — either a leading control character, or words that
  /// are not Strong's numbers.
  text,

  /// At least one Strong's number and no leading control character, so
  /// the combining operators apply.
  strongs,
}

/// What the line is still missing, if anything.
enum CommandDraftHint {
  /// `G25 NEAR5 ` — a combining operator with no second number after it.
  needsSecondNumber,

  /// `AND ` / `NEAR5 ` on their own: a combining operator was inserted
  /// with no Strong's number anywhere to combine.
  combinerWithoutNumber,

  /// A complete `G25 NEAR5 G26` — say what the window actually means,
  /// because the number is a word DISTANCE and reads like a word GAP.
  nearWindow,

  /// `yahweh NEAR5 god` — a combining operator standing between ordinary
  /// WORDS. Nothing in the app parses that: it is not a command (no
  /// leading control character) and not a Strong's expression (no
  /// number), so the WHOLE LINE reaches `SearchService.scanText`, which
  /// matches the literal substring "yahwehnear5god" and finds nothing.
  /// The reader is told "no results" about a query that was never run.
  combinerOnWords,

  /// `G25 NEAR G26` — the keyword with no distance after it. The parser
  /// requires digits, so this too falls through to the literal scan.
  nearWithoutDistance,

  /// `G25 AND god` — a number is present, so the line is plainly meant as
  /// a Strong's expression, but some token is not one and the parser
  /// refuses the whole thing.
  notAStrongsExpression,
}

/// A `NEAR5` / `WITHIN5` token located in the line, so the distance can be
/// changed without the reader retyping the query.
class NearToken {
  const NearToken({
    required this.start,
    required this.end,
    required this.keyword,
    required this.distance,
  });

  /// Character offsets of the whole token in the raw line.
  final int start;
  final int end;

  /// `NEAR` or `WITHIN`, in the case the reader typed, so rewriting the
  /// distance does not also rewrite their spelling.
  final String keyword;

  final int distance;

  @override
  bool operator ==(Object other) =>
      other is NearToken &&
      other.start == start &&
      other.end == end &&
      other.keyword == keyword &&
      other.distance == distance;

  @override
  int get hashCode => Object.hash(start, end, keyword, distance);

  @override
  String toString() => '$keyword$distance@$start';
}

class CommandDraft {
  const CommandDraft({
    required this.mode,
    required this.hasStrongsTerm,
    this.near,
    this.hint,
    this.combiner,
    this.suggestion,
    this.offender,
  });

  final CommandDraftMode mode;

  /// True when some token is a plausible Strong's number.
  final bool hasStrongsTerm;

  /// The LAST `NEARn` on the line, when one applies. Null in a text
  /// search, where `near5` is an ordinary word.
  final NearToken? near;

  final CommandDraftHint? hint;

  /// The combining operator the hint is about, as typed (`AND`, `NEAR5`).
  final String? combiner;

  /// A query that does what this line was reaching for, in a grammar the
  /// app actually runs — offered for one tap rather than described in
  /// prose. Null when the line is ambiguous enough that any rewrite would
  /// be a guess at what the reader meant.
  final String? suggestion;

  /// The token that stopped the parse (`god` in `G25 AND god`), when one
  /// token is identifiably at fault.
  final String? offender;

  /// Whether AND / OR / NOT / NEARn can do anything with this line. The
  /// strip dims them when they cannot, rather than hiding them: a button
  /// that vanishes as you type cannot be learned from.
  bool get combinersApply => mode == CommandDraftMode.strongs;

  /// Whether the strip should show its explanation row at all.
  bool get showsHint => hint != null;

  /// The line names a combining operator but will not run as one — it
  /// reaches `SearchService.scanText` and is matched as one literal
  /// string, so it answers "no results" to a question nobody asked.
  ///
  /// Recents exists to be re-run (bwh09: "Entries are not added to this
  /// list until they are executed without any error messages"), so a
  /// line in this state must not join it. ↑/↓ history still carries it,
  /// which is the list for fixing the thing you just mistyped.
  bool get willNotRunAsWritten =>
      hint == CommandDraftHint.combinerOnWords ||
      hint == CommandDraftHint.nearWithoutDistance ||
      hint == CommandDraftHint.notAStrongsExpression;
}

/// The parser's own bounds, so the strip lights up on exactly the numbers
/// `parseStrongsBoolean` would accept and not on the `H1` of `.H1 will`.
const int _maxGreek = 5700;
const int _maxHebrew = 8700;

final RegExp _termRe = RegExp(r'^([gGhH])0*(\d+)\*?$');
final RegExp _wordCombinerRe = RegExp(r'^(AND|OR|NOT)$');
final RegExp _nearRe =
    RegExp(r'^(NEAR|WITHIN|BEFORE|THEN)(\d+)$', caseSensitive: false);
final RegExp _nearInLineRe =
    RegExp(r'(NEAR|WITHIN|BEFORE|THEN)(\d+)', caseSensitive: false);

bool _isStrongsTerm(String token) {
  final m = _termRe.firstMatch(token);
  if (m == null) return false;
  final n = int.tryParse(m.group(2)!) ?? 0;
  if (n < 1) return false;
  return m.group(1)!.toUpperCase() == 'G' ? n <= _maxGreek : n <= _maxHebrew;
}

bool _isCombiner(String token) =>
    _wordCombinerRe.hasMatch(token.toUpperCase()) || _nearRe.hasMatch(token);

/// A combining operator spelled the way the strip's buttons write it and
/// the help card prints it: UPPERCASE, exactly.
///
/// Case matters here and nowhere else in this file. `near`, `and` and
/// `not` are ordinary English words — "abide near god", "faith and
/// works" — and reading a lowercase one as a broken operator would put an
/// error under a perfectly good text search. Reading an UPPERCASE one as
/// prose costs the reader nothing but a missed suggestion, so that is the
/// side to err on.
final RegExp _typedCombinerRe =
    RegExp(r'^(AND|OR|NOT|NEAR\d*|WITHIN\d*|BEFORE\d*|THEN\d*)$');

/// `NEAR` / `WITHIN` with the distance missing.
final RegExp _bareNearRe =
    RegExp(r'^(NEAR|WITHIN|BEFORE|THEN)$', caseSensitive: false);

/// Read [text] as a draft query. Cheap enough to call on every keystroke.
///
/// [nearDistance] is the distance the strip's NEAR button currently
/// carries, used only to fill in a suggested rewrite for a line that
/// named NEAR without one.
CommandDraft analyseCommandDraft(String text, {int nearDistance = 5}) {
  final raw = text.trim();
  if (raw.isEmpty) {
    return const CommandDraft(
        mode: CommandDraftMode.empty, hasStrongsTerm: false);
  }
  final tokens = raw.split(RegExp(r'\s+'));
  final startsWithControl = kCommandControls.contains(raw[0]);
  final hasStrongsTerm = !startsWithControl && tokens.any(_isStrongsTerm);
  final mode = hasStrongsTerm ? CommandDraftMode.strongs : CommandDraftMode.text;

  // `.love and god` is prose, not a dangling operator. Only a line made of
  // NOTHING BUT combining operators is read as one the reader pressed a
  // button for — which is exactly the reported case (`NEAR5 ` alone).
  final allCombiners = !startsWithControl && tokens.every(_isCombiner);

  if (mode == CommandDraftMode.text && !allCombiners) {
    // `yahweh NEAR5 god`: an operator between words. Round one of #294
    // dimmed the buttons until a number was present but said nothing
    // about a line that already carries one of them, so this shape kept
    // running as a literal text scan and reporting no results.
    final opAt =
        startsWithControl ? -1 : tokens.indexWhere(_typedCombinerRe.hasMatch);
    if (opAt >= 0) {
      return CommandDraft(
        mode: mode,
        hasStrongsTerm: false,
        hint: CommandDraftHint.combinerOnWords,
        combiner: tokens[opAt],
        suggestion: suggestTextEquivalent(tokens, nearDistance: nearDistance),
      );
    }
    return CommandDraft(mode: mode, hasStrongsTerm: false);
  }

  final near = _lastNear(text);
  final last = tokens.last;

  if (mode == CommandDraftMode.strongs && _isCombiner(last)) {
    return CommandDraft(
      mode: mode,
      hasStrongsTerm: true,
      near: near,
      hint: CommandDraftHint.needsSecondNumber,
      combiner: last,
    );
  }
  if (allCombiners) {
    return CommandDraft(
      mode: mode,
      hasStrongsTerm: hasStrongsTerm,
      near: near,
      hint: CommandDraftHint.combinerWithoutNumber,
      combiner: tokens.first,
    );
  }

  // The line holds a number, so it is plainly meant as a Strong's
  // expression. Ask the SHARED PARSER whether it will actually run —
  // rather than enumerating the shapes that fail, which is how
  // `G25 NEAR G26` and `G25 AND god` were both missed. Anything it
  // refuses reaches `SearchService.scanText` as one literal string.
  //
  // A single token is exempt: a bare `G25` is refused on purpose, because
  // it belongs to the lexicon path.
  if (mode == CommandDraftMode.strongs &&
      tokens.length > 1 &&
      parseStrongsBoolean(raw) == null) {
    final bareAt = tokens.indexWhere(_bareNearRe.hasMatch);
    if (bareAt >= 0) {
      final filled = [...tokens];
      filled[bareAt] = '${tokens[bareAt]}$nearDistance';
      return CommandDraft(
        mode: mode,
        hasStrongsTerm: true,
        hint: CommandDraftHint.nearWithoutDistance,
        combiner: tokens[bareAt],
        suggestion: filled.join(' '),
      );
    }
    String? offender;
    String? namedCombiner;
    for (final t in tokens) {
      if (_isCombiner(t)) {
        namedCombiner ??= t;
        continue;
      }
      if (_isStrongsTerm(t)) continue;
      // `!G26` is the glued NOT alias and a legitimate term, so it is
      // never the reason a parse failed.
      if (t.startsWith('!') && _isStrongsTerm(t.substring(1))) continue;
      offender ??= t;
    }
    return CommandDraft(
      mode: mode,
      hasStrongsTerm: true,
      near: near,
      hint: CommandDraftHint.notAStrongsExpression,
      combiner: namedCombiner,
      offender: offender,
    );
  }

  return CommandDraft(
    mode: mode,
    hasStrongsTerm: true,
    near: near,
    hint: near == null ? null : CommandDraftHint.nearWindow,
    combiner: near == null ? null : '${near.keyword}${near.distance}',
  );
}

/// The text-grammar query that means what `word OPERATOR word` was
/// reaching for, or null when translating it would be a guess.
///
/// The four operators do have text equivalents, and refusing without
/// naming them teaches nothing:
///
///   yahweh AND god    →  .yahweh god
///   yahweh OR god     →  /yahweh god
///   yahweh NOT god    →  .yahweh !god
///   yahweh NEAR5 god  →  'yahweh *4 god   (unordered → ordered: partial)
///   yahweh BEFORE5 god → 'yahweh *4 god   (ordered → ordered: exact)
///
/// The proximity case is the one worth reading twice. `NEARn` is a word
/// DISTANCE and admits `n - 1` words in between (`strongs_proximity.dart`
/// tests `(a - b).abs() <= n`), while `*n` inside a phrase is the number
/// of words in between (`GapElement(0, n)`) — so the distance drops by
/// one on the way across, for both operators.
///
/// Direction is the other half, and 2026-09-05 changed which half is
/// missing. A phrase is ORDERED. `NEARn` is not, so `'yahweh *4 god` was
/// only ever half of `yahweh NEAR5 god` and the caller had to say so.
/// `BEFOREn` IS ordered, so
///
///     yahweh BEFORE5 god  →  'yahweh *4 god
///
/// is the first exact translation this function has ever been able to
/// make between the two grammars — same words, same order, same window.
/// Both still route through the same rewrite; what differs is how much
/// the caller has to apologise for it.
///
/// Mixed operators return null. `a AND b OR c` has a precedence the text
/// grammar does not express, and inventing one would silently answer a
/// different question.
String? suggestTextEquivalent(List<String> tokens, {int nearDistance = 5}) {
  final kinds = <String>{};
  var nearAt = -1;
  var distance = nearDistance;
  final words = <String>[];
  final notFrom = <int>[];
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    if (!_typedCombinerRe.hasMatch(t)) {
      words.add(t);
      continue;
    }
    if (t.startsWith('NEAR') || t.startsWith('WITHIN')) {
      kinds.add('NEAR');
      nearAt = words.length;
      final digits = RegExp(r'\d+$').firstMatch(t)?.group(0);
      if (digits != null) distance = int.parse(digits);
    } else if (t.startsWith('BEFORE') || t.startsWith('THEN')) {
      kinds.add('BEFORE');
      nearAt = words.length;
      final digits = RegExp(r'\d+$').firstMatch(t)?.group(0);
      if (digits != null) distance = int.parse(digits);
    } else {
      kinds.add(t);
      if (t == 'NOT') notFrom.add(words.length);
    }
  }
  if (kinds.length != 1 || words.length < 2) return null;
  switch (kinds.first) {
    case 'AND':
      return '.${words.join(' ')}';
    case 'OR':
      return '/${words.join(' ')}';
    case 'NOT':
      final out = [
        for (var i = 0; i < words.length; i++)
          notFrom.any((at) => i >= at) ? '!${words[i]}' : words[i]
      ];
      return '.${out.join(' ')}';
    case 'NEAR':
    case 'BEFORE':
      final gap = (distance - 1).clamp(0, kMaxWordGap);
      final out = [...words]..insert(nearAt, '*$gap');
      return "'${out.join(' ')}";
  }
  return null;
}

NearToken? _lastNear(String text) {
  NearToken? found;
  for (final m in _nearInLineRe.allMatches(text)) {
    final n = int.tryParse(m.group(2)!);
    if (n == null) continue;
    found = NearToken(
      start: m.start,
      end: m.end,
      keyword: m.group(1)!,
      distance: n,
    );
  }
  return found;
}

/// The distance the parser will accept (`strongs_boolean_search.dart`
/// rejects anything outside this as an absurd window).
const int kMinNearDistance = 1;
const int kMaxNearDistance = 50;

/// [text] with [token]'s distance replaced, keeping the reader's own
/// spelling of the keyword and everything either side of it.
String withNearDistance(String text, NearToken token, int distance) {
  final n = distance.clamp(kMinNearDistance, kMaxNearDistance);
  return text.replaceRange(token.start, token.end, '${token.keyword}$n');
}

/// One line of plain language under the operator strip: what the query
/// still needs, or what the window it now describes actually means.
///
/// The pane already reads a FINISHED query back in words
/// (`describeCommandQuery`); this is the same idea moved earlier, to the
/// half-typed line, because the reported failure — tap `NEAR5`, press
/// Enter, nothing — happens before there is a query to echo.
String? describeCommandDraft(CommandDraft draft, String locale) {
  final hint = draft.hint;
  if (hint == null) return null;
  final op = draft.combiner ?? 'NEAR5';
  switch (hint) {
    case CommandDraftHint.needsSecondNumber:
      return (uiStrings['cmdDraftNeedsSecond']?[locale] ??
              '{op} needs a second Strong\'s number after it, e.g. G26.')
          .replaceAll('{op}', op);
    case CommandDraftHint.combinerWithoutNumber:
      return (uiStrings['cmdDraftNeedsPair']?[locale] ??
              '{op} joins two Strong\'s numbers — "G25 {op} G26". '
                  'Type a number first.')
          .replaceAll('{op}', op);
    case CommandDraftHint.nearWindow:
      final n = draft.near?.distance ?? 5;
      // The whole point of the directional operator is that it answers a
      // different question, so the line under the strip may not read the
      // same for both. A reader who taps BEFORE and is told "in either
      // order" has been told the operator does not work.
      final keyword = draft.near?.keyword.toUpperCase() ?? 'NEAR';
      final ordered = keyword == 'BEFORE' || keyword == 'THEN';
      return (uiStrings[ordered
                      ? 'cmdDraftBeforeWindow'
                      : 'cmdDraftNearWindow']?[locale] ??
              (ordered
                  ? 'The first, then the second within {n} words '
                      '(up to {gap} words in between).'
                  : 'Within {n} words of each other, in either order '
                      '(up to {gap} words in between).'))
          .replaceAll('{n}', '$n')
          .replaceAll('{gap}', '${n - 1}');
    case CommandDraftHint.combinerOnWords:
      // Two strings, because a rewrite we cannot offer must not be
      // described as though it were on screen.
      final key = draft.suggestion == null
          ? 'cmdDraftWordsNoFix'
          : (op.startsWith('NEAR') ||
                  op.startsWith('WITHIN') ||
                  op.startsWith('BEFORE') ||
                  op.startsWith('THEN')
              ? 'cmdDraftWordsNearFix'
              : 'cmdDraftWordsFix');
      return (uiStrings[key]?[locale] ??
              (draft.suggestion == null
                  ? '{op} joins two Strong\'s numbers, not words.'
                  : '{op} joins two Strong\'s numbers, not words. '
                      'For words:'))
          .replaceAll('{op}', op);
    case CommandDraftHint.nearWithoutDistance:
      return (uiStrings['cmdDraftNearNoDistance']?[locale] ??
              '{op} needs a distance — how many words apart:')
          .replaceAll('{op}', op);
    case CommandDraftHint.notAStrongsExpression:
      final bad = draft.offender;
      if (bad == null) {
        return uiStrings['cmdDraftNotStrongsShape']?[locale] ??
            "This will not run as a Strong's search. The shape is "
                'G25 AND G26.';
      }
      return (uiStrings['cmdDraftNotStrongsToken']?[locale] ??
              '"{token}" is not a Strong\'s number, so this runs as a '
                  'plain text search. Numbers look like G25 or H430.')
          .replaceAll('{token}', bad);
  }
}
