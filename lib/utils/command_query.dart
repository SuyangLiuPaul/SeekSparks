/// 2026-08-07 (SeekSparks): the BibleWorks command-line query language —
/// help topic bwh16, "The Command Line - Introduction".
///
/// The command line is the thing BibleWorks users describe when they say
/// BibleWorks was fast. It is one text box that does everything, and what
/// makes it a language rather than a search field is a single design
/// decision: **the first character says what kind of search this is.**
///
///     . word1 word2     both words, same verse            (AND)
///     / word1 word2     either word                       (OR)
///     ' word1 word2     word1 immediately followed by word2 (PHRASE)
///     ; word1 word2     the same, scanned verse by verse, so it may
///                       cross verse boundaries            (LINEAR PHRASE)
///
/// Until now SeekSparks' command line understood a reference, a version
/// abbreviation, a Strong's expression and a plain substring — and
/// nothing else. Typing `.love god`, which is the first thing anyone
/// with BibleWorks muscle memory types, searched for the literal string
/// ".love god" and found nothing. Worse, `love god` (no operator) went to
/// the space-stripped substring scan, so in English it quietly meant
/// "the phrase love god" and returned almost nothing, while in Chinese it
/// meant the right thing. One box, two silently different languages.
///
/// ## What a naive reading of "search operators" would miss
///
/// * `!` means two different things and both are needed. In an AND/OR
///   search `!barnabas` EXCLUDES the verse. In a phrase it matches a
///   position — "any word except this one" — which is how you find
///   anarthrous nouns in Greek: `'!the god`. Same character, one
///   filters verses, the other fills a slot.
/// * `*` means two different things too. Inside a word it is the
///   zero-or-more wildcard (`faith*`). Standing alone inside a phrase it
///   is a GAP: `'faith * christ` finds "faith in Christ" and "faith of
///   Christ", and `*3` widens that to three or fewer intervening words.
/// * `;N` appended to a search is a VERSE context, not a word count:
///   `.paul silas;10` finds Paul and Silas within ten verses of each
///   other. It is the operator that turns a verse search into a passage
///   search, and it is the one people forget exists.
///
/// ## Where BibleWorks has no answer and we need one: Chinese
///
/// BibleWorks' Far East command-line topic (bwh17b) is four pages about
/// IMEs, code pages and keyboard layouts. It says nothing whatsoever
/// about what a search MEANS in a language with no spaces — its whole
/// engine is built on whitespace-delimited words. SeekSparks' first
/// audience reads 和合本.
///
/// The resolution here is to keep one rule and let the script decide what
/// a token is, exactly as `phrase_match.dart` already does: **one token
/// per Han character, one token per alphabetic run.** Then
///
///     .爱 神        two terms, each one token → both characters present
///     .爱神         ONE term, two tokens in sequence → the substring 爱神
///     '神说要有光    one term, five tokens → an exact character run
///
/// falls out without a single Chinese-specific branch. A Chinese term is
/// a substring search and an English term is a word search, which is what
/// a reader of each language expects, and the difference is a property of
/// the script rather than a mode anyone has to select.
///
/// ## Deliberately not implemented (and why)
///
/// Detected and reported by name rather than silently mis-parsed:
///
/// * `( )` compound searches — a second grammar layer (sub-searches
///   combined with their own verse contexts) and its own feature.
/// * `~` regular expressions — BibleWorks itself calls this one "for
///   those hardy souls"; it is English-only there, case-sensitive, and a
///   user-supplied regex over 31k verses is a denial-of-service waiting
///   to happen without a timeout budget.
/// * `@` Strong's tag binding (`.man@444`) — the single most valuable
///   remaining piece, but it needs the tagged-text service, and this app
///   already has a *different* Strong's syntax (`G25 AND G26`) in the
///   same box. Reconciling two Strong's grammars is a design decision,
///   not a parser change.
/// * `=` fuzzy link stemming — BibleWorks drives it from `elm.txt`, a
///   hand-edited proprietary database we may not ship. Porter stemming
///   (its other mode) is implementable but BibleWorks' own help calls it
///   "more of a curiosity than a refined tool".
///
/// ## Deliberate divergences from BibleWorks
///
/// * BibleWorks treats input with NO control character as a reference or
///   a shortcut only — a bare word is never a search. SeekSparks keeps
///   its existing bare-text behaviour, because most of its readers have
///   never heard of a control character and taking their search box away
///   to be faithful to a manual would be a straight regression.
/// * BibleWorks forbids a `;N` verse context on a `'` lexical phrase
///   ("verse context limits are not permissible"), because its lexical
///   path is index-driven and cannot cross a verse. Ours scans, so the
///   restriction is an implementation artefact rather than a meaning, and
///   `'x y;2` is accepted and behaves as `;x y;2`.
///
/// Flutter-free on purpose: this parses and matches, nothing else.
library;

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/utils/diacritics.dart' show foldDiacritics;
import 'package:seeksparks/utils/phrase_match.dart' show phraseTokens;
import 'package:seeksparks/utils/related_verses.dart' show isCjkChar, isWordChar;

// ── Limits ──────────────────────────────────────────────────────────

/// Largest `;N` verse context accepted.
///
/// BibleWorks documents no ceiling. One is needed here because the window
/// scan is O(candidates x N), and because a context wider than a long
/// chapter has stopped meaning "near each other" — Psalm 119 is 176
/// verses and is the longest chapter in the Bible.
const int kMaxVerseContext = 176;

/// Largest `*N` word gap accepted inside a phrase.
///
/// The gap cannot reach past the end of the verse it is searching, so the
/// ceiling that means anything is the longest verse in any shipped
/// edition: 202 tokens, `lxxwh` 1 Kings 16:28. Above that the number
/// cannot change an answer, and [CommandIssue.gapTooLarge] says so
/// instead of silently rewriting it.
///
/// The previous ceiling was 50, applied by clamping rather than by
/// refusing. KJV alone has 782 verses longer than that, and Esther 8:9
/// (90 tokens) is a verse the clamp lost: `'then *89 language` finds it,
/// `'then *50 language` does not. Width is free — `_matchFrom` clamps
/// each gap to the tokens actually remaining — so the old number bought
/// nothing it cost.
const int kMaxWordGap = 202;

/// Most groups one compound search may hold (`compound_query.dart`).
///
/// Every group is a separate pass over the corpus, and the command line
/// runs synchronously on the UI thread by design
/// (`WorkbenchProvider._runCommand`), where one pass measures in the low
/// tens of milliseconds. Six is where that budget stops being
/// comfortable; BibleWorks documents no ceiling because its engine is
/// index-driven and ours scans. Declared here so that
/// [describeCommandIssue] can quote it without importing back.
const int kMaxCompoundGroups = 6;

// ── What went wrong, if anything ────────────────────────────────────

/// Why a string is not a runnable command query.
///
/// [notACommand] is the ordinary case — no control character, so the
/// caller should fall through to its own handling. Every other value is
/// a real problem the reader should be told about by name; guessing at
/// what `~(a|b)` meant and running half of it would be worse than saying
/// it is not supported.
///
/// The `compound*` values belong to `compound_query.dart` and are
/// declared here so that one enum covers the whole command line and
/// `describeCommandIssue` stays the single place a failure is worded.
enum CommandIssue {
  notACommand,
  emptyBody,
  regexUnsupported,
  fuzzyUnsupported,
  strongsTagUnsupported,
  phraseNotMultiToken,
  contextTooLarge,
  gapTooLarge,
  compoundUnclosed,
  compoundSeparator,
  compoundGroupOperator,
  compoundNested,
  compoundTooManyGroups,
}

/// Parse outcome: exactly one of [query] / [issue] is non-null.
class CommandParse {
  const CommandParse.ok(CommandQuery this.query) : issue = null;
  const CommandParse.failed(CommandIssue this.issue) : query = null;

  final CommandQuery? query;
  final CommandIssue? issue;

  bool get isCommand => query != null || issue != CommandIssue.notACommand;
}

// ── Matching one token ──────────────────────────────────────────────

/// Matches a single token: a word in an alphabetic script, or one Han
/// character.
///
/// A pattern without metacharacters keeps a plain string and compares by
/// equality — the overwhelmingly common case, and roughly an order of
/// magnitude cheaper than a `RegExp` over a 31k-verse corpus.
class TokenMatcher {
  const TokenMatcher._(this.source, this._literal, this._re, this.literalCore);

  /// Compile one command-line word pattern.
  ///
  /// `*` matches zero or more characters, `?` exactly one, and `[abc]` or
  /// `{abc}` any one of the enclosed characters. BibleWorks accepts both
  /// bracket styles because the Hebrew keyboard puts ayin on `[`.
  /// Diacritics are folded here and nowhere else on the query side, so
  /// [source] keeps the accents the reader typed and the echo can quote
  /// the line back to them unchanged (#321).
  factory TokenMatcher.compile(String source) {
    final lower = foldDiacritics(source).toLowerCase();
    if (!_hasMeta(lower)) {
      return TokenMatcher._(source, lower, null, lower);
    }
    final buf = StringBuffer('^');
    final runs = <String>[];
    final run = StringBuffer();
    var i = 0;
    while (i < lower.length) {
      final c = lower[i];
      if (c == '*') {
        buf.write('.*');
        i++;
      } else if (c == '?') {
        buf.write('.');
        i++;
      } else if (c == '[' || c == '{') {
        final close = c == '[' ? ']' : '}';
        final end = lower.indexOf(close, i + 1);
        if (end < 0) {
          // Unclosed: the bracket is just a character.
          buf.write(RegExp.escape(c));
          run.write(c);
          i++;
          continue;
        }
        final body = lower.substring(i + 1, end);
        buf.write('[${RegExp.escape(body)}]');
        i = end + 1;
      } else {
        buf.write(RegExp.escape(c));
        run.write(c);
        i++;
        continue;
      }
      if (run.isNotEmpty) {
        runs.add(run.toString());
        run.clear();
      }
    }
    if (run.isNotEmpty) runs.add(run.toString());
    buf.write(r'$');
    var core = '';
    for (final r in runs) {
      if (r.length > core.length) core = r;
    }
    return TokenMatcher._(source, null, RegExp(buf.toString()), core);
  }

  /// The pattern exactly as the reader typed it.
  final String source;

  final String? _literal;
  final RegExp? _re;

  /// The longest run of ordinary characters in the pattern, lower-cased.
  ///
  /// Two jobs, both of which need the same string. It is a *necessary*
  /// condition for a match, so a whole-corpus scan can reject a verse
  /// with one `String.contains` before tokenizing it; and it is what the
  /// reader sees marked in the text, since highlighting `faithfulness`
  /// for the query `faith*` is right and highlighting nothing is not.
  ///
  /// Empty when the pattern is all metacharacters (`*`, `?`).
  final String literalCore;

  /// A matcher with neither a literal nor a pattern matches ANY token —
  /// the `?` that stands alone beside a Han character, where there is no
  /// word for it to be a wildcard inside of.
  bool matches(String token) {
    final literal = _literal;
    if (literal != null) return token == literal;
    final re = _re;
    if (re == null) return true;
    return re.hasMatch(token);
  }

  static bool _hasMeta(String s) {
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '*' || c == '?' || c == '[' || c == '{') return true;
    }
    return false;
  }

  @override
  String toString() => 'TokenMatcher($source)';
}

// ── Elements of a search sequence ───────────────────────────────────

/// One position in a search sequence.
sealed class QueryElement {
  const QueryElement();
}

/// A position that must (or, when [negated], must not) be filled by a
/// token matching [matcher]. Occupies exactly one token either way.
class TokenElement extends QueryElement {
  const TokenElement(this.matcher, {this.negated = false});
  final TokenMatcher matcher;
  final bool negated;
}

/// A run of unmatched tokens between two neighbours.
///
/// `'jesus * christ` is `GapElement(1, 1)` — exactly one word. `*3` is
/// `GapElement(0, 3)` — three or fewer, which per BibleWorks includes
/// none. [max] of -1 means unbounded, which only arises from a `*` that
/// sits between Han characters, where there is no word for it to attach
/// to and "zero or more characters" can only mean "zero or more tokens".
class GapElement extends QueryElement {
  const GapElement(this.min, this.max);
  final int min;
  final int max;
  bool get unbounded => max < 0;
}

/// One whitespace-delimited search term, compiled.
///
/// [elements] is usually a single [TokenElement]. It is longer for a
/// Chinese term (one element per character, so 爱神 is a two-token run)
/// and for a term whose wildcard could not be folded into a word.
class QueryTerm {
  const QueryTerm({
    required this.source,
    required this.elements,
    required this.negated,
  });

  /// The term as typed, without its `!`.
  final String source;
  final List<QueryElement> elements;

  /// Had a leading `!`. In an AND/OR search this excludes any verse
  /// containing the term; in a phrase it inverts one position.
  final bool negated;

  /// The best single literal a corpus prefilter can test for, or '' when
  /// the term is all wildcards. See [TokenMatcher.literalCore].
  ///
  /// The literals of adjacent elements are deliberately NOT concatenated,
  /// even though that would make a Chinese term far more selective than
  /// the one character this returns. Two adjacent TOKENS are not adjacent
  /// CHARACTERS: the tokenizer steps over punctuation, so 爱、神 matches
  /// the term 爱神 while the string "爱神" appears nowhere in the verse.
  /// A prefilter that is merely weak costs time; one that is wrong loses
  /// hits silently.
  String get literalCore {
    var best = '';
    for (final e in elements) {
      if (e is TokenElement && e.matcher.literalCore.length > best.length) {
        best = e.matcher.literalCore;
      }
    }
    return best;
  }

  /// Exactly one token position — the only shape `!` can invert inside a
  /// phrase.
  bool get isSingleToken =>
      elements.length == 1 && elements.first is TokenElement;
}

/// What kind of search the control character asked for.
enum CommandKind {
  /// `.` — every term somewhere in the verse (or verse window).
  and,

  /// `/` — at least one term.
  or,

  /// `'` and `;` — the terms in order, adjacent unless a gap says
  /// otherwise.
  phrase,
}

/// One item of a query as the reader wrote it: a term, or a gap between
/// terms. Exactly one field is non-null.
///
/// [CommandQuery.sequence] is the same information flattened for
/// matching, which loses the grouping — 爱神 becomes two anonymous token
/// positions. The echo has to quote the query back the way it was typed,
/// so it reads this instead.
typedef QueryPart = ({QueryTerm? term, GapElement? gap});

/// A parsed, runnable command-line query.
class CommandQuery {
  const CommandQuery({
    required this.kind,
    required this.control,
    required this.terms,
    required this.outline,
    required this.sequence,
    required this.verseContext,
  });

  final CommandKind kind;

  /// The control character as typed — kept so the echo can quote it back
  /// and so `'` and `;` stay distinguishable in the UI even though they
  /// evaluate the same way here.
  final String control;

  /// Terms in order, gaps excluded. Drives the prefilter and the
  /// highlighter.
  final List<QueryTerm> terms;

  /// Terms and gaps in order, as typed. Drives the echo.
  final List<QueryPart> outline;

  /// For [CommandKind.phrase]: every element in order, gaps included.
  /// Empty for AND/OR, which match terms independently.
  final List<QueryElement> sequence;

  /// `;N` — how many verses the terms may be spread across. 0 means one
  /// verse, which is the default and by far the common case.
  final int verseContext;

  /// Terms the verse must contain (used by the prefilter and the
  /// highlighter); excludes `!` terms, which describe absence.
  Iterable<QueryTerm> get positiveTerms => terms.where((t) => !t.negated);
}

// ── Parsing ─────────────────────────────────────────────────────────

/// The characters that turn a line into a command, in first position
/// only. Exported so the UI's control chips and the parser cannot
/// disagree about what counts as one.
const String kCommandControls = "./';";

/// True when [raw] carries no control character but uses `*`, so the
/// plain substring scan can only return nothing.
///
/// 2026-08-09 (#295): the operator strip's own tooltip advertises the
/// wildcard as `faith✶` — no leading dot — and tapping `✶` after typing
/// `faith` produced exactly that. Submitted, it found nothing, because
/// the fallback path is a literal substring search and no Bible text
/// contains an asterisk. Promoting the line to `.faith*` costs nothing:
/// the only queries this catches are ones that were already guaranteed
/// empty.
///
/// `?` is deliberately NOT promoted even though it is BibleWorks'
/// single-character wildcard. Scripture is full of question marks, so
/// `who is this?` is a substring search a reader may well have meant,
/// and silently turning it into a wildcard AND-search would break a
/// case that works today to fix one that never did.
bool needsWildcardPromotion(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return false;
  if (kCommandControls.contains(trimmed[0])) return false;
  if (!trimmed.contains('*')) return false;
  // All-asterisk lines are not a search anyone meant; let them fall
  // through to the text scan and its empty result rather than promote
  // them into a wildcard slot matching the whole Bible.
  return trimmed.replaceAll('*', '').trim().isNotEmpty;
}

/// Parse a command line into a runnable query.
///
/// Returns [CommandIssue.notACommand] for anything that does not start
/// with a control character, which is the caller's signal to carry on
/// with references, version abbreviations and plain text.
CommandParse parseCommandQuery(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return const CommandParse.failed(CommandIssue.notACommand);

  final control = trimmed[0];
  // `(` opens a compound search, which is `compound_query.dart`'s
  // grammar, not this one. Callers try that parser first; by the time a
  // `(` line reaches here it has already been declined there, so the
  // honest answer is that this parser has no claim on it.
  if (control == '~') {
    return const CommandParse.failed(CommandIssue.regexUnsupported);
  }
  if (control == '=') {
    return const CommandParse.failed(CommandIssue.fuzzyUnsupported);
  }
  if (!kCommandControls.contains(control)) {
    return const CommandParse.failed(CommandIssue.notACommand);
  }
  // A lone `.` is how numbers and abbreviations end sentences; a lone
  // `'` is an apostrophe someone started typing. Neither is a query.
  var body = trimmed.substring(1).trim();
  if (body.isEmpty) return const CommandParse.failed(CommandIssue.emptyBody);

  if (body.contains('@')) {
    return const CommandParse.failed(CommandIssue.strongsTagUnsupported);
  }

  // Trailing `;N` is the verse context. It binds to the whole search,
  // not to the last word, even though it is written flush against it:
  // `.faith works;3`.
  var verseContext = 0;
  final ctx = RegExp(r';(\d+)$').firstMatch(body);
  if (ctx != null) {
    // `tryParse`, not `parse`: the regex guarantees digits but not that
    // they fit in an int, and the two targets disagree about what
    // happens next. On the VM `;99999999999999999999` throws, and the
    // throw escapes `WorkbenchProvider.runSearch`'s `finally` to leave
    // the reader looking at an empty result list for a search that never
    // ran; compiled to JS the same line yields 1e20 and is refused
    // politely. A null here is the same fact either way — too large.
    final n = int.tryParse(ctx.group(1)!);
    if (n == null || n > kMaxVerseContext) {
      return const CommandParse.failed(CommandIssue.contextTooLarge);
    }
    verseContext = n;
    body = body.substring(0, ctx.start).trim();
    if (body.isEmpty) return const CommandParse.failed(CommandIssue.emptyBody);
  }

  final kind = switch (control) {
    '.' => CommandKind.and,
    '/' => CommandKind.or,
    _ => CommandKind.phrase,
  };
  // A verse context on an OR search cannot mean anything: every verse
  // qualifies on its own, so there is no window to widen. Dropped rather
  // than reported, because it is harmless and the echo simply will not
  // claim a context that is not being applied.
  if (kind == CommandKind.or) verseContext = 0;

  final terms = <QueryTerm>[];
  final outline = <QueryPart>[];
  final sequence = <QueryElement>[];

  for (final piece in body.split(RegExp(r'\s+'))) {
    if (piece.isEmpty) continue;

    // A bare `*` or `*N` between words of a phrase is a gap, not a
    // pattern. Only in a phrase — in an AND search "any word" is a
    // condition every verse meets.
    if (kind == CommandKind.phrase) {
      final parsed = _asGap(piece);
      if (parsed.tooLarge) {
        return const CommandParse.failed(CommandIssue.gapTooLarge);
      }
      final gap = parsed.gap;
      if (gap != null) {
        sequence.add(gap);
        outline.add((term: null, gap: gap));
        continue;
      }
    }

    var negated = false;
    var text = piece;
    while (text.startsWith('!')) {
      negated = true;
      text = text.substring(1);
    }
    if (text.isEmpty) continue;

    final elements = _compileTerm(text);
    if (elements.isEmpty) continue;

    final term =
        QueryTerm(source: text, elements: elements, negated: negated);

    // `'!the god` inverts ONE position. A multi-token term has no single
    // position to invert, and quietly picking one would silently change
    // what the reader asked for.
    if (kind == CommandKind.phrase && negated && !term.isSingleToken) {
      return const CommandParse.failed(CommandIssue.phraseNotMultiToken);
    }

    terms.add(term);
    outline.add((term: term, gap: null));
    if (kind == CommandKind.phrase) {
      if (negated) {
        final only = elements.first as TokenElement;
        sequence.add(TokenElement(only.matcher, negated: true));
      } else {
        sequence.addAll(elements);
      }
    }
  }

  if (terms.isEmpty) return const CommandParse.failed(CommandIssue.emptyBody);
  // A phrase that is nothing but gaps matches everywhere.
  if (kind == CommandKind.phrase &&
      !sequence.any((e) => e is TokenElement && !e.negated)) {
    return const CommandParse.failed(CommandIssue.emptyBody);
  }

  return CommandParse.ok(CommandQuery(
    kind: kind,
    control: control,
    terms: List.unmodifiable(terms),
    outline: List.unmodifiable(outline),
    sequence: List.unmodifiable(kind == CommandKind.phrase ? sequence : const []),
    verseContext: verseContext,
  ));
}

/// `*` → exactly one word; `*3` → three or fewer.
///
/// [gap] is null when the piece is an ordinary pattern rather than a gap.
/// [tooLarge] means it IS a gap and is wider than [kMaxWordGap], which
/// used to be clamped to 50 without saying so — the reader typed `*99`,
/// got the answer to `*50`, and the echo agreed with them. A ceiling the
/// reader is told about is the same bargain `;N` already offers.
typedef GapParse = ({GapElement? gap, bool tooLarge});

GapParse _asGap(String piece) {
  if (piece == '*') return (gap: const GapElement(1, 1), tooLarge: false);
  final m = RegExp(r'^\*(\d+)$').firstMatch(piece);
  if (m == null) return (gap: null, tooLarge: false);
  final n = int.tryParse(m.group(1)!);
  if (n == null || n > kMaxWordGap) return (gap: null, tooLarge: true);
  return (gap: GapElement(0, n), tooLarge: false);
}

/// Split one term into the sequence of positions it occupies.
///
/// Han characters are one position each. An alphabetic run takes its
/// wildcards with it, so `faith*` is one position and not two. A
/// A metacharacter with no word to attach to becomes a gap (`*`) or an
/// any-token (`?`) — but only inside a term that also has Han characters,
/// because that is the only place the reader can have meant a position.
/// English wildcards arrive as their own whitespace-delimited piece and
/// are turned into gaps by [_asGap] before this is called; a bare `?`
/// reaching here is therefore an ordinary one-letter-word pattern, not a
/// wildcard slot that would silently match the entire Bible.
List<QueryElement> _compileTerm(String term) {
  final out = <QueryElement>[];
  final n = term.length;
  final hasCjk = [
    for (var k = 0; k < n; k++) term.codeUnitAt(k)
  ].any(isCjkChar);
  var i = 0;
  while (i < n) {
    final c = term.codeUnitAt(i);
    if (isCjkChar(c)) {
      out.add(TokenElement(TokenMatcher.compile(term.substring(i, i + 1))));
      i++;
      continue;
    }
    if (isWordChar(c) || _isMetaChar(c)) {
      var j = i;
      while (j < n &&
          (isWordChar(term.codeUnitAt(j)) || _isMetaChar(term.codeUnitAt(j)))) {
        j++;
      }
      final run = _trimEdgeApostrophes(term.substring(i, j));
      i = j;
      if (run.isEmpty) continue;
      if (_isAllMeta(run) && hasCjk) {
        for (var k = 0; k < run.length; k++) {
          out.add(run[k] == '?'
              ? const TokenElement(_anyToken)
              : const GapElement(0, -1));
        }
      } else {
        out.add(TokenElement(TokenMatcher.compile(run)));
      }
      continue;
    }
    // Punctuation inside a term is dropped, matching the tokenizer: the
    // verse side does not keep it either, so "god's," and "god's" are
    // the same term.
    i++;
  }
  return out;
}

/// Drop apostrophes from the ends of a term, because `phraseTokens` drops
/// them from the ends of every corpus token.
///
/// An apostrophe INSIDE a word is a letter here and stays: `god's` is one
/// token on both sides and finds its 25 verses. An apostrophe at the edge
/// is not, and until this existed the two sides spelled the possessive
/// plural differently — the corpus held `sons`, the query held `sons'`,
/// and `.sons'` reported that the King James Bible does not contain the
/// word, in 212 verses of which it does. The cost is that `.sons'` now
/// answers the same as `.sons`; this engine cannot tell them apart, and
/// over-matching shows the reader verses they can check where the zero
/// told them a plain untruth.
String _trimEdgeApostrophes(String run) {
  var s = 0;
  var e = run.length;
  while (s < e && _isApostrophe(run.codeUnitAt(s))) {
    s++;
  }
  while (e > s && _isApostrophe(run.codeUnitAt(e - 1))) {
    e--;
  }
  return run.substring(s, e);
}

bool _isApostrophe(int c) => c == 0x27 || c == 0x2019;

const TokenMatcher _anyToken = TokenMatcher._('?', null, null, '');

bool _isMetaChar(int c) =>
    c == 0x2A /* * */ ||
    c == 0x3F /* ? */ ||
    c == 0x5B /* [ */ ||
    c == 0x5D /* ] */ ||
    c == 0x7B /* { */ ||
    c == 0x7D /* } */;

bool _isAllMeta(String run) {
  for (var i = 0; i < run.length; i++) {
    if (!_isMetaChar(run.codeUnitAt(i))) return false;
  }
  return true;
}

// ── Matching ────────────────────────────────────────────────────────

/// Whether [sequence] matches [tokens] starting exactly at [start].
bool matchSequenceAt(List<String> tokens, int start, List<QueryElement> sequence) =>
    _matchFrom(tokens, start, sequence, 0);

bool _matchFrom(
    List<String> tokens, int ti, List<QueryElement> seq, int si) {
  if (si == seq.length) return true;
  switch (seq[si]) {
    case GapElement(:final min, :final unbounded, :final max):
      final remaining = tokens.length - ti;
      final hi = unbounded ? remaining : (max > remaining ? remaining : max);
      for (var g = min; g <= hi; g++) {
        if (_matchFrom(tokens, ti + g, seq, si + 1)) return true;
      }
      return false;
    case TokenElement(:final matcher, :final negated):
      if (ti >= tokens.length) return false;
      if (matcher.matches(tokens[ti]) == negated) return false;
      return _matchFrom(tokens, ti + 1, seq, si + 1);
  }
}

/// Whether [sequence] occurs anywhere in [tokens].
bool sequenceOccurs(List<String> tokens, List<QueryElement> sequence) {
  for (var i = 0; i <= tokens.length; i++) {
    if (_matchFrom(tokens, i, sequence, 0)) return true;
  }
  return false;
}

// ── Running a query over a corpus ───────────────────────────────────

/// Verse indices that matched, plus how much work it took.
class CommandSearchResult {
  const CommandSearchResult({required this.indices, required this.tokenized});

  /// Matching corpus indices, ascending — which for a canonically
  /// ordered corpus is already canonical order.
  final List<int> indices;

  /// How many verses had to be tokenized after the cheap prefilter. Kept
  /// because it is the only honest way to see whether the prefilter is
  /// doing its job on a real corpus.
  final int tokenized;
}

/// Run [query] over a parallel corpus.
///
/// * [texts] — sanitized verse text with spaces intact
///   (`MainProvider.wordKeys`). Tokenized on demand.
/// * [searchKeys] — the same text lower-cased with whitespace removed
///   (`MainProvider.searchKeys`). Used only as a prefilter: a verse that
///   contains the word "faith" necessarily contains the substring
///   "faith" here too, so a `String.contains` that costs nothing rejects
///   most of the corpus before any of it is tokenized. Whitespace being
///   stripped makes it a superset, never a filter that loses a hit.
/// * [books] — book name per verse, so a `;N` window never runs off the
///   end of Malachi into Matthew.
///
/// Assumes [texts] is in canonical order and that a book's verses are
/// contiguous, which is how `MainProvider` loads them; the window scan
/// re-checks the book name at each step rather than trusting it.
CommandSearchResult runCommandQuery({
  required CommandQuery query,
  required List<String> texts,
  required List<String> searchKeys,
  required List<String> books,
}) {
  assert(texts.length == searchKeys.length);
  assert(texts.length == books.length);

  // The prefilter tests a query literal against a verse key, so both
  // sides have to be spelled the same way. `searchKeys` arrives folded
  // (`MainProvider.searchKeys`) and the query literals are folded in
  // `TokenMatcher.compile`, so the two already agree and this used to be
  // where a whole extra copy of the corpus was allocated per query.
  final keys = searchKeys;

  final tokenCache = List<List<String>?>.filled(texts.length, null);
  var tokenized = 0;

  // `texts` is `MainProvider.wordKeys`, which is NOT folded — it is
  // printed on screen by the Phrases and Related panes. Folding happens
  // on the token, after the split, so nothing the reader sees changes.
  List<String> tokensAt(int i) {
    final cached = tokenCache[i];
    if (cached != null) return cached;
    tokenized++;
    final built = [
      for (final t in phraseTokens(texts[i])) foldDiacritics(t.text)
    ];
    tokenCache[i] = built;
    return built;
  }

  // ── Simple case: one verse at a time ────────────────────────────
  if (query.verseContext == 0) {
    final candidates = _prefilter(query, keys);
    final out = <int>[];
    for (final i in candidates) {
      if (_verseSatisfies(query, tokensAt(i))) out.add(i);
    }
    return CommandSearchResult(indices: out, tokenized: tokenized);
  }

  // ── Verse context: the terms may be spread over a window ────────
  final n = query.verseContext;

  if (query.kind == CommandKind.phrase) {
    // A linear phrase may run past the end of the verse it starts in.
    // Report the verse it STARTS in — that is where a reader wants to be
    // taken, and it is the only choice that does not report a verse
    // containing none of the words.
    final out = <int>[];
    for (final i in _phraseWindowCandidates(query, keys, books, n)) {
      final tokens = <String>[];
      final firstLen = tokensAt(i).length;
      tokens.addAll(tokensAt(i));
      for (var j = i + 1; j <= i + n && j < texts.length; j++) {
        if (books[j] != books[i]) break;
        tokens.addAll(tokensAt(j));
      }
      var hit = false;
      for (var s = 0; s < firstLen; s++) {
        if (matchSequenceAt(tokens, s, query.sequence)) {
          hit = true;
          break;
        }
      }
      // A phrase that is entirely gaps at the front can legitimately
      // start at the very end of the verse with zero tokens consumed.
      if (!hit && firstLen == 0 && matchSequenceAt(tokens, 0, query.sequence)) {
        hit = true;
      }
      if (hit) out.add(i);
    }
    return CommandSearchResult(indices: out, tokenized: tokenized);
  }

  // AND with a verse context. Every term must occur somewhere in a
  // window of at most N+1 consecutive verses of one book, and every
  // verse of that window which itself contains a term is a hit.
  //
  // Reporting the whole participating set rather than the first verse is
  // deliberate: "find all verses that contain the word Paul and the word
  // Silas within 10 verses of each other" describes both verses, and a
  // reader scanning the list wants to see each place a word landed.
  final positives = query.positiveTerms.toList();
  final negatives = query.terms.where((t) => t.negated).toList();
  if (positives.isEmpty) {
    // `.!barnabas;5` — a window with nothing to hold together. Falls back
    // to the plain per-verse reading rather than returning nothing.
    final out = <int>[];
    for (var i = 0; i < texts.length; i++) {
      if (_verseSatisfies(query, tokensAt(i))) out.add(i);
    }
    return CommandSearchResult(indices: out, tokenized: tokenized);
  }
  final occ = <List<int>>[];
  for (final t in positives) {
    final where = <int>[];
    for (final i in _prefilterTerm(t, keys)) {
      if (sequenceOccurs(tokensAt(i), t.elements)) where.add(i);
    }
    occ.add(where);
    if (where.isEmpty) {
      return CommandSearchResult(indices: const [], tokenized: tokenized);
    }
  }

  final out = <int>[];
  final seen = <int>{};
  for (final where in occ) {
    for (final v in where) {
      if (!seen.add(v)) continue;
      if (_windowSatisfies(v, n, occ, books, texts.length)) out.add(v);
    }
  }
  out.sort();
  // NOT terms exclude on the verse itself, not on the window: `.paul
  // silas !barnabas;10` should still list a Paul verse ten verses away
  // from a Barnabas verse. Excluding across the window would make the
  // context operator quietly subtract results as it widened.
  if (negatives.isNotEmpty) {
    out.removeWhere((i) =>
        negatives.any((t) => sequenceOccurs(tokensAt(i), t.elements)));
  }
  return CommandSearchResult(indices: out, tokenized: tokenized);
}

/// Whether some window of at most `n+1` consecutive verses of the same
/// book contains [v] and an occurrence of every term.
bool _windowSatisfies(
    int v, int n, List<List<int>> occ, List<String> books, int corpusLength) {
  final book = books[v];
  var lo = v - n;
  if (lo < 0) lo = 0;
  for (var s = lo; s <= v; s++) {
    if (books[s] != book) continue;
    var end = s + n;
    if (end >= corpusLength) end = corpusLength - 1;
    // Clip the window at the book edge rather than skipping it, so a
    // window that starts near the end of a book still works inside it.
    for (var e = s; e <= end; e++) {
      if (books[e] != book) {
        end = e - 1;
        break;
      }
    }
    if (end < v) continue;
    var all = true;
    for (final where in occ) {
      if (!_anyIn(where, s, end)) {
        all = false;
        break;
      }
    }
    if (all) return true;
  }
  return false;
}

/// Whether the sorted list [xs] has a value in [lo, hi].
bool _anyIn(List<int> xs, int lo, int hi) {
  var a = 0;
  var b = xs.length;
  while (a < b) {
    final mid = (a + b) >> 1;
    if (xs[mid] < lo) {
      a = mid + 1;
    } else {
      b = mid;
    }
  }
  return a < xs.length && xs[a] <= hi;
}

/// Verses worth tokenizing at all, for a single-verse query.
List<int> _prefilter(CommandQuery query, List<String> searchKeys) {
  final positives = query.positiveTerms.toList();
  if (positives.isEmpty) return _allIndices(searchKeys.length);

  if (query.kind == CommandKind.or) {
    // Any one term is enough, so the prefilter is a union — which only
    // helps if EVERY term has a literal to test.
    final cores = [for (final t in positives) t.literalCore];
    if (cores.any((c) => c.isEmpty)) return _allIndices(searchKeys.length);
    final out = <int>[];
    for (var i = 0; i < searchKeys.length; i++) {
      final key = searchKeys[i];
      for (final c in cores) {
        if (key.contains(c)) {
          out.add(i);
          break;
        }
      }
    }
    return out;
  }

  // AND and phrase: every positive term must be present in the verse, so
  // each literal we have is an independent necessary condition.
  final cores = [
    for (final t in positives)
      if (t.literalCore.isNotEmpty) t.literalCore
  ];
  if (cores.isEmpty) return _allIndices(searchKeys.length);
  final out = <int>[];
  outer:
  for (var i = 0; i < searchKeys.length; i++) {
    final key = searchKeys[i];
    for (final c in cores) {
      if (!key.contains(c)) continue outer;
    }
    out.add(i);
  }
  return out;
}

List<int> _prefilterTerm(QueryTerm term, List<String> searchKeys) {
  final core = term.literalCore;
  if (core.isEmpty) return _allIndices(searchKeys.length);
  final out = <int>[];
  for (var i = 0; i < searchKeys.length; i++) {
    if (searchKeys[i].contains(core)) out.add(i);
  }
  return out;
}

/// Start verses worth trying for a cross-verse phrase.
///
/// A match that starts in verse *i* must have all of its positive terms
/// inside the window `[i, i+n]`, so a verse can be skipped unless every
/// term's literal appears somewhere in its own window.
List<int> _phraseWindowCandidates(
    CommandQuery query, List<String> searchKeys, List<String> books, int n) {
  final cores = [
    for (final t in query.positiveTerms)
      if (t.literalCore.isNotEmpty) t.literalCore
  ];
  if (cores.isEmpty) return _allIndices(searchKeys.length);
  final out = <int>[];
  outer:
  for (var i = 0; i < searchKeys.length; i++) {
    for (final c in cores) {
      var found = false;
      for (var j = i; j <= i + n && j < searchKeys.length; j++) {
        if (j > i && books[j] != books[i]) break;
        if (searchKeys[j].contains(c)) {
          found = true;
          break;
        }
      }
      if (!found) continue outer;
    }
    out.add(i);
  }
  return out;
}

List<int> _allIndices(int length) => [for (var i = 0; i < length; i++) i];

/// Whether one verse's [tokens] satisfy [query] on their own.
bool _verseSatisfies(CommandQuery query, List<String> tokens) {
  switch (query.kind) {
    case CommandKind.phrase:
      if (!sequenceOccurs(tokens, query.sequence)) return false;
      // `!` inside a phrase already filled a position; a `!` term is
      // never a whole-verse exclusion in phrase mode.
      return true;
    case CommandKind.and:
      for (final t in query.terms) {
        final present = sequenceOccurs(tokens, t.elements);
        if (present == t.negated) return false;
      }
      return true;
    case CommandKind.or:
      var any = false;
      for (final t in query.terms) {
        final present = sequenceOccurs(tokens, t.elements);
        if (t.negated) {
          if (present) return false;
        } else if (present) {
          any = true;
        }
      }
      return any;
  }
}

// ── Saying back what was understood ─────────────────────────────────

/// A one-line, plain-language reading of [query].
///
/// This is the part BibleWorks, Logos and Accordance all lack. The
/// syntax is terse by design — that is what makes it fast — but terse
/// notation is also how people run the wrong search and believe the
/// answer. The documented failure is negation: BibleWorks' own forum has
/// users writing `'!your *5 house` expecting "your, not followed by
/// house" and getting nonsense, because the `*5` will happily match
/// "your" itself. One of its long-time contributors wrote that "the
/// intuitive solution frequently isn't correct," and a seminary teacher
/// there gave up on the syntax for students entirely.
///
/// So the results header does not repeat the query; it says what the
/// query MEANS. `'love *3 god` reads back as "In order: love · any 3 or
/// fewer words · god", which makes the gap's freedom visible at the
/// moment it matters, without anyone opening a manual.
String describeCommandQuery(CommandQuery query, String locale) {
  String s(String key, String fallback) =>
      uiStrings[key]?[locale] ?? uiStrings[key]?['en'] ?? fallback;

  final listSep = s('cmdListSeparator', ', ');
  final partSep = s('cmdPartSeparator', ' · ');

  final positives = <String>[];
  final negatives = <String>[];
  for (final t in query.terms) {
    (t.negated ? negatives : positives).add(t.source);
  }

  final buf = StringBuffer();
  switch (query.kind) {
    case CommandKind.and:
      buf.write(s('cmdEchoAll', 'All of: {terms}')
          .replaceAll('{terms}', positives.join(listSep)));
    case CommandKind.or:
      buf.write(s('cmdEchoAny', 'Any of: {terms}')
          .replaceAll('{terms}', positives.join(listSep)));
    case CommandKind.phrase:
      final parts = <String>[];
      for (final p in query.outline) {
        final gap = p.gap;
        if (gap != null) {
          parts.add(gap.min == gap.max
              ? s('cmdEchoGapExact', 'any {n} words')
                  .replaceAll('{n}', '${gap.min}')
              : s('cmdEchoGapUpTo', 'any {n} or fewer words')
                  .replaceAll('{n}', '${gap.max}'));
          continue;
        }
        final term = p.term!;
        parts.add(term.negated
            ? s('cmdEchoNotWord', 'any word but {w}')
                .replaceAll('{w}', term.source)
            : term.source);
      }
      buf.write(s('cmdEchoPhrase', 'In order: {parts}')
          .replaceAll('{parts}', parts.join(partSep)));
  }

  // A phrase folds its `!` into the sequence, so it has already been
  // spoken for above; only AND/OR carry whole-verse exclusions.
  if (negatives.isNotEmpty && query.kind != CommandKind.phrase) {
    buf.write(partSep);
    buf.write(s('cmdEchoWithout', 'without: {terms}')
        .replaceAll('{terms}', negatives.join(listSep)));
  }
  if (query.verseContext > 0) {
    buf.write(partSep);
    buf.write(s('cmdEchoContext', 'within {n} verses')
        .replaceAll('{n}', '${query.verseContext}'));
  }
  return buf.toString();
}

/// Why the command line could not run what was typed, in one sentence.
///
/// Returns null for [CommandIssue.notACommand], which is not an error —
/// it just means the caller should handle the text itself.
String? describeCommandIssue(CommandIssue issue, String locale) {
  String s(String key, String fallback) =>
      uiStrings[key]?[locale] ?? uiStrings[key]?['en'] ?? fallback;
  return switch (issue) {
    CommandIssue.notACommand => null,
    CommandIssue.emptyBody =>
      s('cmdIssueEmpty', 'Type what to search for after the operator.'),
    CommandIssue.regexUnsupported => s('cmdIssueRegex',
        'Regular expression searches (~) are not supported.'),
    CommandIssue.fuzzyUnsupported => s('cmdIssueFuzzy',
        'Fuzzy stemming searches (=) are not supported.'),
    CommandIssue.strongsTagUnsupported => s('cmdIssueStrongsTag',
        "Strong's tags (@) are not supported yet — use G25 AND G26."),
    CommandIssue.phraseNotMultiToken => s('cmdIssuePhraseNot',
        'In a phrase, ! can only stand in front of a single word.'),
    CommandIssue.contextTooLarge => s('cmdIssueContext',
            'The verse context after ; must be {max} or less.')
        .replaceAll('{max}', '$kMaxVerseContext'),
    CommandIssue.gapTooLarge => s('cmdIssueGap',
            'The word gap after * must be {max} or less.')
        .replaceAll('{max}', '$kMaxWordGap'),
    CommandIssue.compoundUnclosed => s('cmdIssueCompoundUnclosed',
        'Every ( in a compound search needs a matching ).'),
    CommandIssue.compoundSeparator => s('cmdIssueCompoundSeparator',
        'Join the groups of a compound search with . / or ! — for example (.a b).15(/c d).'),
    CommandIssue.compoundGroupOperator => s('cmdIssueCompoundGroupOperator',
        "Every group in a compound search starts with an operator: (.a b), not (a b). Strong's expressions cannot be a group."),
    CommandIssue.compoundNested => s('cmdIssueCompoundNested',
        'Compound searches cannot be nested inside each other.'),
    CommandIssue.compoundTooManyGroups => s('cmdIssueCompoundTooMany',
            'A compound search can hold at most {max} groups.')
        .replaceAll('{max}', '$kMaxCompoundGroups'),
  };
}
