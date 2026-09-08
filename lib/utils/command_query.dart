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
/// * `=` fuzzy link stemming — BibleWorks drives it from `elm.txt`, a
///   hand-edited proprietary database we may not ship. Porter stemming
///   (its other mode) is implementable but BibleWorks' own help calls it
///   "more of a curiosity than a refined tool".
///
/// ## Formerly on that list: `@` Strong's tag binding
///
/// 2026-09-08. `.man@444` — "man, where the Greek behind it is
/// ἄνθρωπος" — is now parsed here and matched against the tagged text.
/// `strongs_tag_binding.dart` carries the rationale, the leading-zero
/// rule and the measurements. The two reasons this list used to give
/// were checked rather than overturned:
///
/// * *"it needs the tagged-text service"* — true when it was written and
///   no longer true: `services/tagged_text_service.dart` landed the day
///   before, and six of the twelve bundled editions now ship
///   `assets/tagged/<version>/<book>.json`, one run of rendered text per
///   original-language word.
/// * *"the app already has a different Strong's syntax in the same box"*
///   — still true, and still a design decision, but the two grammars
///   cannot collide positionally. `G25 AND G26` carries no leading
///   control character, so this parser answers
///   [CommandIssue.notACommand] and `WorkbenchProvider` passes the line
///   on to `parseStrongsBoolean`; `.man@444` opens with `.`, which that
///   parser has never accepted. What had to be decided was how a number
///   is spelled, and the answer is that both spellings are read into one
///   — see `normaliseStrongsTag`.
///
/// The honest-failure half is deliberately NOT here, because this file
/// does not know which edition is on screen. Six editions carry tagging
/// and six do not, and a `@` query against one of the six that do not is
/// **unanswerable, not empty** — `WorkbenchProvider.runSearch` refuses it
/// by name with [CommandIssue.strongsTagNoTaggedText] before any search
/// runs. [runCommandQuery] therefore asserts when it is handed a tag
/// query without the tagged tokens to answer it, rather than quietly
/// returning nothing.
///
/// ## Formerly absent entirely: the GSE's punctuation test
///
/// 2026-09-08. `'love *5 god %-` — "these two words within five, but not
/// across a sentence end" — is now parsed here and applied to the span a
/// phrase match occupies. `punctuation_gate.dart` carries what bwh19,
/// bwh21 and bwh22 actually say, the per-script character sets and the
/// counts behind them.
///
/// It was never on the list above, because it arrived attached to the
/// Graphical Search Engine and left with it: `docs/PARITY-BACKLOG.md`
/// §3.2 rejected the GSE **canvas** on 2026-09-07 — *"the DIAGRAM is
/// REJECTED, the power is not"* — and the punctuation test went out in
/// the same motion despite needing no canvas at all. It is one bit of
/// state plus an optional character set. This does not re-open §3.2; it
/// collects a piece of the power §3.2 explicitly kept.
///
/// Three things were deliberately NOT built, each for a reason:
///
/// * **`.` and `/` do not take it.** In BibleWorks the punctuation test
///   belongs to an ordering LINK between two word boxes; the merge box —
///   the AND/OR/NOT node — has no punctuation setting at all, only a
///   verse proximity (bwh21). Two words in sequence have one span and
///   "between" names it; a bag of words has several and no way to say
///   which. [CommandIssue.punctuationNeedsPhrase] says so.
/// * **Per-link control.** bwh21 lets every ordering box in a query set
///   its own mode and its own custom set. A command line has no way to
///   point at one link out of several without inventing a second
///   grammar, and the query that would need it — different rules for
///   different joints of one phrase — has no reader asking for it.
/// * **`@` cannot be combined with it.** A tag query reads its tokens off
///   `assets/tagged/`, which stores rendered runs and nothing between
///   them. There is no punctuation in that asset to test, so
///   [CommandIssue.punctuationWithStrongsTag] refuses the pair rather
///   than testing one corpus and matching another.
///
/// `strongs_proximity.dart`'s `G25 BEFORE5 G26` wanted this too and
/// cannot have it, for a reason that is a measurement rather than a
/// judgement — see the note in that file.
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
import 'package:seeksparks/utils/search_folding.dart' show foldSearchMarks;
import 'package:seeksparks/utils/phrase_match.dart' show phraseTokens;
import 'package:seeksparks/utils/punctuation_gate.dart';
import 'package:seeksparks/utils/related_verses.dart' show isCjkChar, isWordChar;
import 'package:seeksparks/utils/strongs_boolean_search.dart'
    show kMaxNearDistance, kMaxGreekStrongs, kMaxHebrewStrongs;
import 'package:seeksparks/utils/strongs_tag_binding.dart';

export 'package:seeksparks/utils/punctuation_gate.dart'
    show
        PunctuationGate,
        PunctuationMode,
        kHebrewPunctuation,
        kSentenceEndPunctuation;

export 'package:seeksparks/utils/strongs_tag_binding.dart'
    show
        StrongsTagBinding,
        StrongsTagForm,
        TaggedToken,
        TaggedRunView,
        TaggedTokensLookup,
        taggedRunTokens;

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
/// The `compound*` values belong to `compound_query.dart`, the
/// `strongsNear*`/`strongsOperator*`/`strongsNumberOutOfRange` values to
/// `strongs_boolean_search.dart`, and two of the `strongsTag*` values to
/// `WorkbenchProvider` — [strongsTagNoTaggedText] and
/// [strongsTagUnsupportedHere] are facts about the edition on screen and
/// the shape of the line, neither of which a parser can see. All are
/// declared here so that one enum covers the whole command line and
/// `describeCommandIssue` stays the single place a failure is worded.
enum CommandIssue {
  notACommand,
  emptyBody,
  regexUnsupported,
  fuzzyUnsupported,
  strongsTagNoWord,
  strongsTagNumber,
  strongsTagNotOneWord,
  strongsTagNoTaggedText,
  strongsTagUnsupportedHere,
  phraseNotMultiToken,
  contextTooLarge,
  gapTooLarge,
  compoundUnclosed,
  compoundSeparator,
  compoundGroupOperator,
  compoundNested,
  compoundTooManyGroups,
  strongsNearNeedsDistance,
  strongsNearDistanceOutOfRange,
  strongsOperatorNeedsTerms,
  strongsNumberOutOfRange,
  punctuationSetInvalid,
  punctuationRepeated,
  punctuationNeedsPhrase,
  punctuationWithStrongsTag,
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
    final lower = foldSearchMarks(source).toLowerCase();
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
  const TokenElement(this.matcher, {this.negated = false, this.tag});
  final TokenMatcher matcher;
  final bool negated;

  /// The `@…` this position was bound to, or null for an ordinary word.
  ///
  /// A separate conjunct, not part of [matcher]: `!man@444` negates the
  /// WORD and keeps the tag positive, which is bwh16's own reading —
  /// "occurrences of ἄνθρωπος that have not been translated as man".
  final StrongsTagBinding? tag;
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
    this.tag,
  });

  /// The term as typed, without its `!` and without its `@…`.
  final String source;
  final List<QueryElement> elements;

  /// Had a leading `!`. In an AND/OR search this excludes any verse
  /// containing the term; in a phrase it inverts one position.
  ///
  /// False for `!man@444` even though a `!` was typed, because there the
  /// `!` fills a position rather than throwing the verse away — see
  /// [wordNegated]. Keeping the two apart is what lets the window scan
  /// and the prefilter go on treating this field as "describes absence".
  final bool negated;

  /// The `@…` bound to this term, or null.
  ///
  /// Bound to EVERY token position the term occupies, which is the only
  /// reading under which a two-character Chinese word works: 起初 is two
  /// tokens and one tagged run. See `strongs_tag_binding.dart`.
  final StrongsTagBinding? tag;

  /// True for `!man@444`: the `!` inverted the word, not the verse.
  ///
  /// Derived rather than stored, because it is exactly the state of the
  /// elements — a term whose positions are negated is a term looking for
  /// some OTHER word in that slot.
  bool get wordNegated =>
      elements.any((e) => e is TokenElement && e.negated);

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
  ///
  /// A NEGATED position contributes nothing, for the same reason: the
  /// verse `!man@444` is looking for is one that holds some word OTHER
  /// than "man", so requiring "man" to appear in it would lose exactly
  /// the hits the query asked for. `search_highlight.dart` reads this
  /// too, so the same line keeps `.!man@444` from marking the word it
  /// was told to avoid.
  String get literalCore {
    var best = '';
    for (final e in elements) {
      if (e is TokenElement &&
          !e.negated &&
          e.matcher.literalCore.length > best.length) {
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
    this.punctuation = PunctuationGate.off,
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

  /// `%-` / `%+` — the GSE ordering box's punctuation test, over the span
  /// a phrase match occupies. Defaults to [PunctuationGate.off], which is
  /// what every query written before 2026-09-08 carries and what keeps
  /// their answers identical. Only a [CommandKind.phrase] can hold an
  /// active one; see `punctuation_gate.dart` for why.
  final PunctuationGate punctuation;

  /// Terms the verse must contain (used by the prefilter and the
  /// highlighter); excludes `!` terms, which describe absence.
  ///
  /// A `!man@444` term IS here, because the verse must contain the
  /// position it describes. What it must not contain is the word, and
  /// that is [QueryTerm.literalCore]'s job — it comes back empty for a
  /// negated position, so neither the prefilter nor the highlighter can
  /// act on a word the query is avoiding.
  Iterable<QueryTerm> get positiveTerms => terms.where((t) => !t.negated);

  /// Whether any term carries an `@…`, and so can only be answered
  /// against a Strong's-tagged edition.
  ///
  /// The caller's gate: `WorkbenchProvider` refuses the query outright
  /// when the edition on screen has no tagging, and loads the tagging
  /// before running it when it has.
  bool get usesStrongsTags => terms.any((t) => t.tag != null);
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

  final kind = switch (control) {
    '.' => CommandKind.and,
    '/' => CommandKind.or,
    _ => CommandKind.phrase,
  };

  // `%-` / `%+` — pulled out before anything else looks at the line,
  // because the marker modifies the whole search rather than occupying a
  // position in it, exactly as `;N` does.
  //
  // It has to come out BEFORE the `;N` strip and not after, and that
  // ordering is a bug this file has already had once. `;N` is matched
  // with `;(\d+)$`, anchored at the end of the line; leave `%-` sitting
  // behind it and `'night *5 morning;1 %-` no longer ends in digits, so
  // the context is never recognised and `morning;1` compiles into two
  // token positions — "morning" followed by "1" — which matches nothing
  // and returns an empty list for a query that parsed cleanly. Taking the
  // marker out first makes both orders work and both mean the same thing.
  //
  // Taken from ANY position rather than only the last. `'a %- b` can only
  // have meant one thing, and today it means `'a b` (the piece is dropped
  // as punctuation), so refusing it would be inventing an error where
  // there is no ambiguity. Two markers IS ambiguous — nothing says which
  // one wins — and is refused by name.
  var punctuation = PunctuationGate.off;
  final kept = <String>[];
  for (final raw2 in body.split(RegExp(r'\s+'))) {
    if (raw2.isEmpty) continue;
    // `'a *5 b %-;3` — the two modifiers written flush against each
    // other, which is how `;N` is normally written and so how a reader
    // will write this. The tail is peeled off the marker before the set
    // is read, which is unambiguous in one direction only: a digit is
    // never punctuation, so `;3` cannot have been part of anyone's
    // character set. It goes back into the line so that the `;N` regex
    // below still finds it at the end.
    var piece = raw2;
    String? contextTail;
    if (piece.startsWith('%')) {
      final tail = RegExp(r';\d+$').firstMatch(piece);
      if (tail != null) {
        contextTail = piece.substring(tail.start);
        piece = piece.substring(0, tail.start);
      }
    }
    final marker = parsePunctuationMarker(piece);
    switch (marker.outcome) {
      case PunctuationMarkerOutcome.notAMarker:
        // Untouched, tail and all: nothing that is not a marker may be
        // rewritten on its way through here.
        kept.add(raw2);
      case PunctuationMarkerOutcome.setInvalid:
        return const CommandParse.failed(CommandIssue.punctuationSetInvalid);
      case PunctuationMarkerOutcome.ok:
        if (punctuation.isActive) {
          return const CommandParse.failed(CommandIssue.punctuationRepeated);
        }
        punctuation = marker.gate!;
        if (contextTail != null) kept.add(contextTail);
    }
  }
  body = kept.join(' ');
  if (body.isEmpty) return const CommandParse.failed(CommandIssue.emptyBody);
  // BibleWorks hangs the punctuation test on an ORDERING LINK between two
  // word boxes; its merge box — the AND/OR/NOT node — has no punctuation
  // setting at all, only a verse proximity (bwh21). The line is about
  // meaning rather than about its UI: two words joined in sequence have a
  // span and "between" names it, while a bag of words has several spans
  // and no way to say which one was meant. `.` and `/` are refused here
  // for that reason and not because it would have been hard.
  if (punctuation.isActive && kind != CommandKind.phrase) {
    return const CommandParse.failed(CommandIssue.punctuationNeedsPhrase);
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

    // `word@tag`. Split at the FIRST `@`: a word cannot contain one, and
    // `.man@444@555` is a typo that should be named rather than read as
    // a number `444@555`.
    StrongsTagBinding? tag;
    final at = text.indexOf('@');
    if (at >= 0) {
      // `.@444` — BibleWorks spells "any word" as `*`, and there is no
      // reading under which an absent word means the same thing.
      if (text.substring(0, at).trim().isEmpty) {
        return const CommandParse.failed(CommandIssue.strongsTagNoWord);
      }
      final parsed = parseStrongsTag(text.substring(at + 1));
      if (parsed.binding == null) {
        return const CommandParse.failed(CommandIssue.strongsTagNumber);
      }
      tag = parsed.binding;
      text = text.substring(0, at);
    }
    if (text.isEmpty) continue;

    // bwh16's third meaning of `!`: on a tag-bound term it fills a
    // position ("ἄνθρωπος not translated as man") instead of throwing
    // the verse away, so the negation moves onto the token elements and
    // the TERM stops describing absence.
    final wordNegated = negated && tag != null;
    final elements = _compileTerm(text, tag: tag, negated: wordNegated);
    if (elements.isEmpty) continue;

    final term = QueryTerm(
      source: text,
      elements: elements,
      negated: negated && tag == null,
      tag: tag,
    );

    // `'!the god` inverts ONE position. A multi-token term has no single
    // position to invert, and quietly picking one would silently change
    // what the reader asked for.
    if (kind == CommandKind.phrase && negated && !term.isSingleToken) {
      return const CommandParse.failed(CommandIssue.phraseNotMultiToken);
    }
    // Same objection, different operator: `.!爱神@G26` would otherwise
    // mean "two adjacent positions, neither of them 爱 or 神, both
    // tagged G26", which nobody typing it could have meant.
    if (wordNegated && !term.isSingleToken) {
      return const CommandParse.failed(CommandIssue.strongsTagNotOneWord);
    }

    terms.add(term);
    outline.add((term: term, gap: null));
    if (kind == CommandKind.phrase) {
      if (negated && !wordNegated) {
        final only = elements.first as TokenElement;
        sequence.add(TokenElement(only.matcher, negated: true, tag: only.tag));
      } else {
        // `wordNegated` elements already carry their negation.
        sequence.addAll(elements);
      }
    }
  }

  if (terms.isEmpty) return const CommandParse.failed(CommandIssue.emptyBody);
  // A phrase that is nothing but gaps matches everywhere. So does one
  // that is nothing but negations — `'!the` is every verse with a second
  // word — but `'!man@444` is not: a negated position that carries a tag
  // still has to land on a tagged word, so it constrains.
  if (kind == CommandKind.phrase &&
      !sequence.any((e) =>
          e is TokenElement && (!e.negated || e.tag != null))) {
    return const CommandParse.failed(CommandIssue.emptyBody);
  }
  // A `@` query reads its tokens off the TAGGED runs, which are stored as
  // text with no record of what sat between them — `taggedRunTokens`
  // flattens run after run and the punctuation is simply not in the
  // asset. So the span a punctuation test would measure does not exist on
  // that path, and answering `'man@444 *3 god %-` would mean silently
  // testing a different corpus from the one the query is matching
  // against. Refused by name instead.
  if (punctuation.isActive && terms.any((t) => t.tag != null)) {
    return const CommandParse.failed(CommandIssue.punctuationWithStrongsTag);
  }

  return CommandParse.ok(CommandQuery(
    kind: kind,
    control: control,
    terms: List.unmodifiable(terms),
    outline: List.unmodifiable(outline),
    sequence: List.unmodifiable(kind == CommandKind.phrase ? sequence : const []),
    verseContext: verseContext,
    punctuation: punctuation,
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
///
/// [tag] and [negated] are stamped onto every [TokenElement] the term
/// produces. Both are properties of the whole term — 起初 is two token
/// positions of one tagged run — and neither can be attached to just one
/// of them without picking a position arbitrarily.
List<QueryElement> _compileTerm(String term,
    {StrongsTagBinding? tag, bool negated = false}) {
  final out = <QueryElement>[];
  final n = term.length;
  final hasCjk = [
    for (var k = 0; k < n; k++) term.codeUnitAt(k)
  ].any(isCjkChar);
  var i = 0;
  while (i < n) {
    final c = term.codeUnitAt(i);
    if (isCjkChar(c)) {
      out.add(TokenElement(TokenMatcher.compile(term.substring(i, i + 1)),
          negated: negated, tag: tag));
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
              ? TokenElement(_anyToken, negated: negated, tag: tag)
              : const GapElement(0, -1));
        }
      } else {
        out.add(TokenElement(TokenMatcher.compile(run),
            negated: negated, tag: tag));
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
///
/// [tags] is the Strong's number of each token, same length and same
/// order, and is needed only when the sequence carries an `@…`. Passing
/// it for an ordinary query is harmless and costs nothing.
///
/// [gaps] and [gate] are the punctuation test: `gaps` is
/// `punctuationGapFlags` for the same tokens (length `tokens.length + 1`)
/// and `gate` says what to do with it. An inactive gate ignores both.
bool matchSequenceAt(List<String> tokens, int start, List<QueryElement> sequence,
        {List<String>? tags,
        List<bool>? gaps,
        PunctuationGate gate = PunctuationGate.off}) =>
    _matchFrom(tokens, tags, start, sequence, 0, start, gaps, gate);

/// The punctuation test is applied at the END of a candidate match rather
/// than as a filter afterwards, and that placement is the whole
/// correctness argument.
///
/// A gap backtracks: `'a *5 b` can match at several widths, and only some
/// of them may stay inside a sentence. Testing one arbitrary match and
/// rejecting the verse would answer "is the FIRST match clean" when the
/// question asked was "is there a clean match". Failing here instead lets
/// the recursion carry on trying the other widths, which is the existence
/// reading the reader means.
bool _matchFrom(
    List<String> tokens,
    List<String>? tags,
    int ti,
    List<QueryElement> seq,
    int si,
    int start,
    List<bool>? gaps,
    PunctuationGate gate) {
  if (si == seq.length) {
    if (!gate.isActive || gaps == null) return true;
    return gate.spanPasses(gaps, start, ti - 1);
  }
  switch (seq[si]) {
    case GapElement(:final min, :final unbounded, :final max):
      final remaining = tokens.length - ti;
      final hi = unbounded ? remaining : (max > remaining ? remaining : max);
      for (var g = min; g <= hi; g++) {
        if (_matchFrom(tokens, tags, ti + g, seq, si + 1, start, gaps, gate)) {
          return true;
        }
      }
      return false;
    case TokenElement(:final matcher, :final negated, :final tag):
      if (ti >= tokens.length) return false;
      if (matcher.matches(tokens[ti]) == negated) return false;
      if (tag != null) {
        // No tags to test against means this position can never be
        // satisfied. [runCommandQuery] asserts long before a query
        // reaches here in that state; returning false rather than
        // throwing keeps a release build from crashing on a line the
        // reader typed.
        if (tags == null || ti >= tags.length) return false;
        if (!tag.matchesTag(tags[ti])) return false;
      }
      return _matchFrom(tokens, tags, ti + 1, seq, si + 1, start, gaps, gate);
  }
}

/// Whether [sequence] occurs anywhere in [tokens]. See [matchSequenceAt]
/// for [tags], [gaps] and [gate].
bool sequenceOccurs(List<String> tokens, List<QueryElement> sequence,
    {List<String>? tags,
    List<bool>? gaps,
    PunctuationGate gate = PunctuationGate.off}) {
  for (var i = 0; i <= tokens.length; i++) {
    if (_matchFrom(tokens, tags, i, sequence, 0, i, gaps, gate)) return true;
  }
  return false;
}

// ── Running a query over a corpus ───────────────────────────────────

/// Verse indices that matched, plus how much work it took.
class CommandSearchResult {
  const CommandSearchResult({
    required this.indices,
    required this.tokenized,
    this.candidatesWithoutTagging = 0,
  });

  /// Matching corpus indices, ascending — which for a canonically
  /// ordered corpus is already canonical order.
  final List<int> indices;

  /// How many verses had to be tokenized after the cheap prefilter. Kept
  /// because it is the only honest way to see whether the prefilter is
  /// doing its job on a real corpus.
  final int tokenized;

  /// For an `@` query: how many of the verses this search actually
  /// opened had no tagged entry at all, and so could not answer it.
  ///
  /// Counted over CANDIDATES, not over the corpus, because the prefilter
  /// means most verses are never opened — so this is "how much of the
  /// work I did came back blank", not a coverage figure for the edition.
  /// Zero on every shipped edition measured so far (BSB Genesis: 0 of
  /// 1,533), which is why nothing renders it yet; it exists so that a
  /// partial import cannot become an empty result list with no trace.
  final int candidatesWithoutTagging;
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
/// * [taggedTokens] — verse index → that verse's tagged runs, already
///   flattened by `taggedRunTokens`, or null when the edition has no
///   entry for it. Required exactly when [CommandQuery.usesStrongsTags]
///   is true and ignored otherwise, and it REPLACES [texts] as the token
///   source for those queries: a token has to arrive already married to
///   its Strong's number, and re-deriving the marriage by lining up two
///   independently produced token streams is how an alignment silently
///   goes off by one. The two streams are spelled identically anyway —
///   `taggedRunTokens` runs the same sanitiser, tokenizer and fold this
///   function does — so the same query returns the same verses either
///   way when the tags are not consulted.
///
/// Assumes [texts] is in canonical order and that a book's verses are
/// contiguous, which is how `MainProvider` loads them; the window scan
/// re-checks the book name at each step rather than trusting it.
CommandSearchResult runCommandQuery({
  required CommandQuery query,
  required List<String> texts,
  required List<String> searchKeys,
  required List<String> books,
  TaggedTokensLookup? taggedTokens,
}) {
  assert(texts.length == searchKeys.length);
  assert(texts.length == books.length);
  // Not a defensive nicety: without the tagging every `@` position fails
  // and the reader gets an empty list for a question that was never
  // asked. `WorkbenchProvider` refuses the query by name before it gets
  // here; anything else calling in has to do the same.
  assert(
      !query.usesStrongsTags || taggedTokens != null,
      'a @ query needs taggedTokens — an untagged edition must be refused '
      'by name (CommandIssue.strongsTagNoTaggedText), not searched to zero');

  // The prefilter tests a query literal against a verse key, so both
  // sides have to be spelled the same way. `searchKeys` arrives folded
  // (`MainProvider.searchKeys`) and the query literals are folded in
  // `TokenMatcher.compile`, so the two already agree and this used to be
  // where a whole extra copy of the corpus was allocated per query.
  final keys = searchKeys;

  final tokenCache = List<List<String>?>.filled(texts.length, null);
  final tagCache = List<List<String>?>.filled(texts.length, null);
  // Built beside the tokens and only when a punctuation test asked for
  // them, so an ordinary query allocates nothing extra. See
  // `punctuation_gate.dart` on why one bit per boundary rather than the
  // separator text.
  final gate = query.punctuation;
  final gapCache =
      gate.isActive ? List<List<bool>?>.filled(texts.length, null) : null;
  // Held in a local so that the null check promotes inside the closures
  // below; `query.usesStrongsTags` gates it, so an ordinary query never
  // looks at the tagging even when a caller passed some.
  final lookup = query.usesStrongsTags ? taggedTokens : null;
  final needsTags = lookup != null;
  var tokenized = 0;
  var withoutTagging = 0;

  // `texts` is `MainProvider.wordKeys`, which is NOT folded — it is
  // printed on screen by the Phrases and Related panes. Folding happens
  // on the token, after the split, so nothing the reader sees changes.
  //
  // A tag query reads the tagged runs instead; see [taggedTokens]. A
  // verse the edition never tagged becomes zero tokens, so it matches
  // nothing and is counted rather than quietly skipped.
  List<String> tokensAt(int i) {
    final cached = tokenCache[i];
    if (cached != null) return cached;
    tokenized++;
    List<String> built;
    if (needsTags) {
      final runs = lookup(i);
      if (runs == null) {
        withoutTagging++;
        built = const [];
        tagCache[i] = const [];
      } else {
        built = [for (final t in runs) t.text];
        tagCache[i] = [for (final t in runs) t.strongs];
      }
    } else {
      final spans = phraseTokens(texts[i]);
      built = [for (final t in spans) foldSearchMarks(t.text)];
      // Needs the SPANS, not the strings: what sits between two words is
      // recoverable only from their offsets into the verse.
      gapCache?[i] = punctuationGapFlags(texts[i], spans, gate);
    }
    tokenCache[i] = built;
    return built;
  }

  /// Punctuation boundaries for verse [i], `tokens + 1` of them.
  ///
  /// All-false on the tagged path, which cannot arise: `parseCommandQuery`
  /// refuses an active gate on a `@` query
  /// ([CommandIssue.punctuationWithStrongsTag]) precisely because the
  /// tagged runs carry no punctuation to read.
  List<bool> gapsAt(int i) {
    final n = tokensAt(i).length;
    return gapCache![i] ??= List<bool>.filled(n + 1, false);
  }

  /// The Strong's numbers beside [tokensAt]'s tokens, or null when this
  /// query has no `@` to test.
  List<String>? tagsAt(int i) {
    if (!needsTags) return null;
    tokensAt(i);
    return tagCache[i];
  }

  CommandSearchResult done(List<int> indices) => CommandSearchResult(
        indices: indices,
        tokenized: tokenized,
        candidatesWithoutTagging: withoutTagging,
      );

  // ── Simple case: one verse at a time ────────────────────────────
  if (query.verseContext == 0) {
    final candidates = _prefilter(query, keys);
    final out = <int>[];
    for (final i in candidates) {
      if (_verseSatisfies(query, tokensAt(i), tagsAt(i),
          gate.isActive ? gapsAt(i) : null, gate)) {
        out.add(i);
      }
    }
    return done(out);
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
      final tags = needsTags ? <String>[] : null;
      // One flag per boundary across the whole window. Verse j's leading
      // boundary and verse j-1's trailing boundary are the SAME boundary
      // — the space between the last word of one verse and the first word
      // of the next — so they are OR-ed into one entry rather than both
      // being kept. Getting this wrong by one would shift every flag
      // after the first verse join and quietly test the wrong gaps, which
      // is the reason it is built here and not by concatenating lists.
      final gaps = gate.isActive ? <bool>[] : null;
      final firstLen = tokensAt(i).length;
      tokens.addAll(tokensAt(i));
      tags?.addAll(tagsAt(i)!);
      gaps?.addAll(gapsAt(i));
      for (var j = i + 1; j <= i + n && j < texts.length; j++) {
        if (books[j] != books[i]) break;
        tokens.addAll(tokensAt(j));
        tags?.addAll(tagsAt(j)!);
        if (gaps != null) {
          final next = gapsAt(j);
          gaps[gaps.length - 1] = gaps.last || next.first;
          gaps.addAll(next.skip(1));
        }
      }
      var hit = false;
      for (var s = 0; s < firstLen; s++) {
        if (matchSequenceAt(tokens, s, query.sequence,
            tags: tags, gaps: gaps, gate: gate)) {
          hit = true;
          break;
        }
      }
      // A phrase that is entirely gaps at the front can legitimately
      // start at the very end of the verse with zero tokens consumed.
      if (!hit &&
          firstLen == 0 &&
          matchSequenceAt(tokens, 0, query.sequence,
              tags: tags, gaps: gaps, gate: gate)) {
        hit = true;
      }
      if (hit) out.add(i);
    }
    return done(out);
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
      // AND cannot carry an active gate (CommandIssue.punctuationNeedsPhrase),
      // so there is nothing to hand it here.
      if (_verseSatisfies(query, tokensAt(i), tagsAt(i), null, gate)) {
        out.add(i);
      }
    }
    return done(out);
  }
  final occ = <List<int>>[];
  for (final t in positives) {
    final where = <int>[];
    for (final i in _prefilterTerm(t, keys)) {
      if (sequenceOccurs(tokensAt(i), t.elements, tags: tagsAt(i))) {
        where.add(i);
      }
    }
    occ.add(where);
    if (where.isEmpty) return done(const []);
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
    out.removeWhere((i) => negatives
        .any((t) => sequenceOccurs(tokensAt(i), t.elements, tags: tagsAt(i))));
  }
  return done(out);
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
bool _verseSatisfies(CommandQuery query, List<String> tokens,
    List<String>? tags, List<bool>? gaps, PunctuationGate gate) {
  switch (query.kind) {
    case CommandKind.phrase:
      if (!sequenceOccurs(tokens, query.sequence,
          tags: tags, gaps: gaps, gate: gate)) {
        return false;
      }
      // `!` inside a phrase already filled a position; a `!` term is
      // never a whole-verse exclusion in phrase mode.
      return true;
    case CommandKind.and:
      for (final t in query.terms) {
        final present = sequenceOccurs(tokens, t.elements, tags: tags);
        if (present == t.negated) return false;
      }
      return true;
    case CommandKind.or:
      var any = false;
      for (final t in query.terms) {
        final present = sequenceOccurs(tokens, t.elements, tags: tags);
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

  /// One term as prose: the word, its `!` if the `!` filled a position
  /// rather than excluded a verse, and its `@…`.
  ///
  /// `.*@444` reads back as "any word rendering G444" rather than
  /// "* rendering G444", because `*` is the only place in this grammar
  /// where a term is a hole and the echo exists to make holes visible.
  String label(QueryTerm t) {
    var word = t.source == '*' ? s('cmdEchoTagAnyWord', 'any word') : t.source;
    if (t.wordNegated) {
      word = s('cmdEchoNotWord', 'any word but {w}').replaceAll('{w}', word);
    }
    final tag = t.tag;
    if (tag == null) return word;
    final (key, fallback) = switch ((tag.form, tag.negated)) {
      (StrongsTagForm.number, false) => ('cmdEchoTagIs', '{w} rendering {n}'),
      (StrongsTagForm.number, true) =>
        ('cmdEchoTagNot', '{w} not rendering {n}'),
      (StrongsTagForm.any, false) || (StrongsTagForm.none, true) =>
        ('cmdEchoTagAny', '{w} with an original-language tag'),
      (StrongsTagForm.any, true) || (StrongsTagForm.none, false) =>
        ('cmdEchoTagNone', '{w} with no original-language tag'),
    };
    return s(key, fallback)
        .replaceAll('{w}', word)
        .replaceAll('{n}', tag.number ?? tag.source);
  }

  final positives = <String>[];
  final negatives = <String>[];
  for (final t in query.terms) {
    (t.negated ? negatives : positives).add(label(t));
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
            : label(term));
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
  // The punctuation test is the part of this grammar most likely to be
  // believed without being understood, because it SUBTRACTS results and
  // a shorter list looks like a better one. So the echo names the set
  // when the reader supplied their own, and names the concept —
  // "sentence end", not ". ? !" — when they took the default: the whole
  // claim of the default is that it is the sentence-ending marks of
  // whatever script is on screen, and printing six characters at a
  // reader of the 和合本 would put three irrelevant ones in front of
  // them.
  if (query.punctuation.isActive) {
    buf.write(partSep);
    final custom = query.punctuation.isCustom;
    final (key, fallback) =
        switch ((query.punctuation.mode, custom)) {
      (PunctuationMode.exclude, false) =>
        ('cmdEchoPunctNone', 'not crossing a sentence end'),
      (PunctuationMode.exclude, true) =>
        ('cmdEchoPunctNoneOf', 'with none of {chars} between'),
      (PunctuationMode.require, false) =>
        ('cmdEchoPunctSome', 'crossing a sentence end'),
      (PunctuationMode.require, true) =>
        ('cmdEchoPunctSomeOf', 'with one of {chars} between'),
      // The allow branch is unreachable behind `isActive`, and is spelled
      // out so that a fourth mode could not be added without the echo
      // failing to compile.
      (PunctuationMode.allow, _) => ('', ''),
    };
    buf.write(s(key, fallback)
        .replaceAll('{chars}', query.punctuation.characters));
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
    CommandIssue.strongsTagNoWord => s('cmdIssueStrongsTagNoWord',
        "A Strong's tag follows a word: .man@444, or .*@444 for every "
        'rendering of it.'),
    CommandIssue.strongsTagNumber => s('cmdIssueStrongsTagNumber',
        "After @ put a Strong's number — .man@444 for Greek, .man@0430 or "
        '.man@H430 for Hebrew — or @* for any tag and @- for none.'),
    CommandIssue.strongsTagNotOneWord => s('cmdIssueStrongsTagNotOneWord',
        "! in front of a tagged word can only stand in front of a single "
        'word — for example .!man@444.'),
    // The six editions are named, not counted. "Switch to a tagged
    // edition" is a refusal the reader cannot act on without opening the
    // version picker and reading twelve rows to find out which ones
    // qualify — and `test/strongs_tag_binding_test.dart` fails if this
    // list and `TaggedTextService.taggedVersions` ever disagree.
    CommandIssue.strongsTagNoTaggedText => s('cmdIssueStrongsTagNoTaggedText',
        "This edition carries no Strong's tagging, so @ has nothing to "
        'match against. Switch to BSB, CSB, KJV+S, LXX+WH, 雅简+ or 和简+ '
        'and run it again.'),
    CommandIssue.strongsTagUnsupportedHere => s('cmdIssueStrongsTagHere',
        "Strong's tags (@) work in a plain . / ' ; search only — not "
        'inside a compound ( ) search or a cross-version one.'),
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
    CommandIssue.strongsNearNeedsDistance => s('cmdIssueNearNoDistance',
        "NEAR needs a number: G25 NEAR5 G26 finds them within 5 words."),
    CommandIssue.strongsNearDistanceOutOfRange => s('cmdIssueNearRange',
            'The word distance after NEAR must be between 1 and {max}.')
        .replaceAll('{max}', '$kMaxNearDistance'),
    CommandIssue.strongsOperatorNeedsTerms => s('cmdIssueStrongsOperator',
        "Every operator needs a Strong's number on both sides — for example G25 AND G26."),
    CommandIssue.strongsNumberOutOfRange => s('cmdIssueStrongsRange',
            "Strong's numbers here run G1–G{g} and H1–H{h}.")
        .replaceAll('{g}', '$kMaxGreekStrongs')
        .replaceAll('{h}', '$kMaxHebrewStrongs'),
    CommandIssue.punctuationSetInvalid => s('cmdIssuePunctSet',
        'After %- or %+ put punctuation marks only — for example %-.?! or '
        '%-。！？ — or nothing at all to use the sentence-ending marks.'),
    CommandIssue.punctuationRepeated => s('cmdIssuePunctRepeated',
        'One punctuation test per search: write %- or %+ once.'),
    CommandIssue.punctuationNeedsPhrase => s('cmdIssuePunctPhraseOnly',
        "%- and %+ ask what lies BETWEEN words, so they need an ordered "
        "search — ' or ; — not . or /."),
    CommandIssue.punctuationWithStrongsTag => s('cmdIssuePunctStrongsTag',
        "The Strong's tagging carries no punctuation, so %- and %+ cannot "
        'be combined with @.'),
  };
}
