// 2026-08-08 (task #294): what the command line currently holds, read from
// the operator strip's point of view.
//
// The strip under the command line carries THREE grammars on one
// undifferentiated row of identical buttons:
//
//   . / '        line mode   — first position only, mutually exclusive
//   ! *          modifiers   — attach to a word of a TEXT search
//   AND OR NOT NEARn         — combine two STRONG'S NUMBERS
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

import 'command_query.dart' show kCommandControls;

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

  /// Whether AND / OR / NOT / NEARn can do anything with this line. The
  /// strip dims them when they cannot, rather than hiding them: a button
  /// that vanishes as you type cannot be learned from.
  bool get combinersApply => mode == CommandDraftMode.strongs;

  /// Whether the strip should show its explanation row at all.
  bool get showsHint => hint != null;
}

/// The parser's own bounds, so the strip lights up on exactly the numbers
/// `parseStrongsBoolean` would accept and not on the `H1` of `.H1 will`.
const int _maxGreek = 5700;
const int _maxHebrew = 8700;

final RegExp _termRe = RegExp(r'^([gGhH])0*(\d+)\*?$');
final RegExp _wordCombinerRe = RegExp(r'^(AND|OR|NOT)$');
final RegExp _nearRe = RegExp(r'^(NEAR|WITHIN)(\d+)$', caseSensitive: false);
final RegExp _nearInLineRe =
    RegExp(r'(NEAR|WITHIN)(\d+)', caseSensitive: false);

bool _isStrongsTerm(String token) {
  final m = _termRe.firstMatch(token);
  if (m == null) return false;
  final n = int.tryParse(m.group(2)!) ?? 0;
  if (n < 1) return false;
  return m.group(1)!.toUpperCase() == 'G' ? n <= _maxGreek : n <= _maxHebrew;
}

bool _isCombiner(String token) =>
    _wordCombinerRe.hasMatch(token.toUpperCase()) || _nearRe.hasMatch(token);

/// Read [text] as a draft query. Cheap enough to call on every keystroke.
CommandDraft analyseCommandDraft(String text) {
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
  return CommandDraft(
    mode: mode,
    hasStrongsTerm: true,
    near: near,
    hint: near == null ? null : CommandDraftHint.nearWindow,
    combiner: near == null ? null : '${near.keyword}${near.distance}',
  );
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
      return (uiStrings['cmdDraftNearWindow']?[locale] ??
              'Within {n} words of each other, in either order '
                  '(up to {gap} words in between).')
          .replaceAll('{n}', '$n')
          .replaceAll('{gap}', '${n - 1}');
  }
}
