/// 2026-09-08 (SeekSparks): the GSE ordering box's PUNCTUATION TEST,
/// lifted off the canvas and onto the command line — BibleWorks help
/// topics bwh19 (§"How to search on punctuation"), bwh21 (§"The GSE
/// Ordering and Proximity Box Window" and §"Query Properties –
/// Punctuation Tab") and bwh22 (Example 4, `punctn.qf`).
///
/// ## What BibleWorks actually does, quoted rather than remembered
///
/// bwh21 on the ordering box: *"the ordering box is used to specify that
/// punctuation does or does not occur between two words. The set of
/// characters to be included in the punctuation test can be defined per
/// query."* Its three settings are **Allow** ("does not check for
/// punctuation between the two words"), **Exclude** ("no punctuation …
/// may occur between the two words") and **Require** ("punctuation from
/// the punctuation group … must occur between the two words"), plus a
/// per-box **Custom punctuation** override that supersedes the query's
/// group for that one link.
///
/// Two facts about it are easy to get wrong from memory:
///
/// * **The group is per LANGUAGE, not per query alone.** bwh21's
///   Punctuation Tab is *"where the user can specify the punctuation
///   group for each language"*, and *"the default punctuation groups
///   include all legal characters for the language group"* — i.e. its
///   shipped default is EVERY punctuation mark, not the sentence-final
///   ones. It names the maqqef and sof passuq as the Hebrew entries.
/// * **The help contradicts itself on the names.** bwh21 lists the three
///   as Allow / Exclude / Require; bwh19 and bwh22 tell you to *"check
///   Require or None"* and describe Example 4 as having *"the punctuation
///   flag … set to 'none'"*. Same setting, two vocabularies. This file
///   uses bwh21's, because that is the reference chapter.
///
/// And one fact about where it sits: in BibleWorks the test belongs to an
/// **ordering link between two word boxes**. A merge box — the AND/OR/NOT
/// node — has no punctuation setting at all, only a verse *Proximity*.
/// That is not an accident of the UI, it is what "between" can mean: two
/// words joined in sequence have a span, and a bag of words does not.
/// [PunctuationGate] is therefore offered on `'` and `;` sequences and
/// refused on `.` and `/`, which is the same line BibleWorks draws.
///
/// ## Why this is not the rejected canvas
///
/// `docs/PARITY-BACKLOG.md` §3.2 re-decided the GSE on 2026-09-07: *"the
/// DIAGRAM is REJECTED, the power is not"*, on the ground that a query
/// canvas is the one surface where a four-pixel drag miss silently
/// changes the question. The punctuation test needs no canvas. It is one
/// bit of state and an optional character set, and "these two words
/// within five, but not across a sentence end" is a sentence a command
/// line can hold. Nothing here re-opens the diagram.
///
/// It matters more here than it did in BibleWorks, because SeekSparks'
/// `;N` verse context lets a linear phrase run out of the verse it
/// started in and on into the next one. A proximity hit that spans a
/// verse boundary has almost always spanned a sentence end too, and
/// until now there was no way to say so.
///
/// ## The default character set, measured per script
///
/// BibleWorks' default is "all legal characters", which makes `Exclude`
/// mean *same clause*. That is a defensible setting and a terrible
/// default: in the KJV the comma alone occurs 70,574 times over 31,102
/// verses, so an all-punctuation Exclude would answer a question about
/// sentences with an answer about clauses. The default here is instead
/// the marks that END A SENTENCE, and every one of them was counted in a
/// shipped asset before it was let in.
///
/// **Latin script** (`kjv.json`, `bsb.json`, `leb.json`, …) → `. ? !`
///
///   | mark | KJV    | BSB    | in the default? |
///   |------|--------|--------|-----------------|
///   | `.`  | 26,201 | 34,874 | yes             |
///   | `?`  |  3,297 |  3,198 | yes             |
///   | `!`  |    313 |  1,832 | yes             |
///   | `,`  | 70,574 | 50,801 | no — 2.3/verse  |
///   | `:`  | 12,698 |  2,519 | no              |
///   | `;`  | 10,139 |  4,906 | no              |
///
///   `:` and `;` are excluded on evidence rather than on taste. The KJV
///   uses the colon where a modern text uses a comma — Genesis 1:4 reads
///   *"that it was good: and God divided the light"* — so a colon there
///   is a pause inside one sentence, and Psalm 139:12 puts one between
///   "day" and "the darkness" in a single breath. Quotation marks, the
///   BSB's 1,669 em dashes and parentheses are excluded for the same
///   reason: they open and close, they do not end.
///
/// **Han script** (`cuvs-yhwh.json`, `cuvs-plus.json`) → `。 ！ ？`
///
///   | mark | 和合本 (雅伟版) | in the default? |
///   |------|----------------|-----------------|
///   | `。` | 30,736 | yes — one per verse, near enough  |
///   | `？` |  3,311 | yes |
///   | `！` |  3,059 | yes |
///   | `，` | 59,017 | no — 1.9 per verse |
///   | `；` |  9,318 | no |
///   | `：` |  8,244 | no |
///   | `、` |  6,214 | no |
///
///   This is the part BibleWorks never had to answer, and the answer is
///   NOT the English set with fullwidth glyphs substituted:
///
///   * `、` is an enumeration comma. It separates the items of one noun
///     phrase — 马太福音 21:14 *瞎子、瘸子到耶稣跟前* — so it is weaker
///     than an English comma, not stronger, and a rule that treated it as
///     a break would cut a list in half.
///   * `；` is the mark the 和合本 uses to join the two halves of a
///     Hebrew parallelism, which is one sentence with two limbs:
///     箴言 4:7 *智慧为首；所以要得智慧*. Its 9,318 occurrences are
///     concentrated in the poetry, exactly where a reader most wants a
///     proximity search to reach across.
///   * `：` almost always OPENS direct speech (…就说：“…”), so it is the
///     start of a sentence rather than the end of one.
///   * **The quotation marks are `“ ” ‘ ’`, not `「 」`.** 「」, 『』 and
///     ｛｝ occur **zero** times in all 31,102 verses of
///     `assets/cuvs-yhwh.json`; the edition punctuates speech with
///     `“`(6,569) `”`(5,969) `‘`(1,229) `’`(1,204). A default set written
///     for 「」 would have been dead code against the corpus this app
///     actually ships, which is why it was counted first.
///
/// **Greek and Hebrew** → nothing, and that is a measurement too. The
/// only original-language edition bundled as running text is
/// `lxxwh.json`, and after `versificationPattern` strips its `<vs:…>`
/// markers it contains **no punctuation at all** — 30,800 verses of
/// unaccented, unpointed, unpunctuated text. So the Greek question mark
/// `;` never has to be reconciled with the Latin semicolon `;`, because
/// no shipped Greek verse contains either. See [kSentenceEndPunctuation].
///
/// The three script sets are disjoint, so the default is simply their
/// union and no per-edition switch is needed. The one overlap measured is
/// 15 verses of the 和合本 carrying a stray ASCII `.`, every one of them
/// immediately before a `。` that is already in the set (创世纪 6:11
/// *…满了强暴.。*), so it cannot change an answer.
///
/// Flutter-free, asset-free: this decides what counts as a break and
/// where the breaks are, and nothing else.
library;

import 'package:seeksparks/utils/phrase_match.dart' show PhraseToken;
import 'package:seeksparks/utils/related_verses.dart' show isCjkChar, isWordChar;

/// bwh21's three settings, under bwh21's names.
enum PunctuationMode {
  /// "Does not check for punctuation between the two words." The default,
  /// and the behaviour every query written before this file existed has.
  allow,

  /// "No punctuation … may occur between the two words."
  exclude,

  /// "Punctuation from the punctuation group … must occur between the two
  /// words."
  require,
}

/// The marks that end a sentence in the scripts this app ships, unioned.
///
/// Latin `.?!` and Han `。！？`. The two sets cannot collide — no Latin
/// verse holds a fullwidth mark and the 15 Han verses holding an ASCII
/// `.` hold a `。` beside it — so one constant serves every edition and
/// nothing has to know which one is on screen. See the library comment
/// for the counts behind every inclusion and every exclusion, and for why
/// Greek and Hebrew contribute nothing.
const String kSentenceEndPunctuation = '.?!。！？';

/// Sof pasuq, paseq and maqqef — the three marks that live inside the
/// Hebrew Unicode block and are punctuation rather than letters.
///
/// NOT in [kSentenceEndPunctuation], because no bundled edition prints
/// them: `lxxwh.json` is the only original-language running text and it
/// is Greek, and `assets/originals/*.json` is a word list whose 55,026
/// sampled entries (Genesis, Psalms, John) contain zero punctuation
/// characters of any kind. This constant exists only so that
/// [parsePunctuationMarker] lets a reader type them into a custom set
/// even though `isWordChar` claims their code points; see the note there.
const String kHebrewPunctuation = '׃׀־'; // ׃ ׀ ־

/// A punctuation test: a mode, and the characters it tests for.
///
/// Immutable and cheap to copy — one is carried on every parsed query,
/// including the overwhelming majority that never asked for one.
class PunctuationGate {
  const PunctuationGate(this.mode, this.characters);

  /// The state of a query that never mentioned punctuation.
  ///
  /// Keeps [kSentenceEndPunctuation] rather than an empty set so that
  /// [characters] always answers "which marks would this test look at",
  /// but [isActive] is false so nothing ever looks.
  static const PunctuationGate off =
      PunctuationGate(PunctuationMode.allow, kSentenceEndPunctuation);

  final PunctuationMode mode;

  /// The character set, defaulting to [kSentenceEndPunctuation].
  ///
  /// bwh21's "Custom punctuation" overrides the group for one ordering
  /// box; there is one span here rather than a graph of links, so the
  /// override is per query.
  final String characters;

  bool get isActive => mode != PunctuationMode.allow;

  /// Whether the reader supplied their own set, which the echo says out
  /// loud — a test running on characters the reader did not choose is
  /// exactly the kind of silent difference this app's echo exists for.
  bool get isCustom => characters != kSentenceEndPunctuation;

  /// Whether [text] holds any character of the set.
  ///
  /// Linear in both, which is the right shape: the set is a handful of
  /// characters and the text is the whitespace-and-punctuation run
  /// between two words, usually one character long.
  bool marks(String text) {
    for (var i = 0; i < text.length; i++) {
      if (characters.contains(text[i])) return true;
    }
    return false;
  }

  /// Whether a match spanning tokens `[first, last]` satisfies this test,
  /// given [gaps] from [punctuationGapFlags].
  ///
  /// "Between" excludes the outer edges, exactly as BibleWorks' ordering
  /// box does: the full stop that closes "…created the heaven and the
  /// earth." sits AFTER the last matched word and is not between
  /// anything, so a phrase ending a sentence is not a phrase crossing
  /// one. That is `gaps[first + 1 .. last]` and not `gaps[first .. last +
  /// 1]`, and getting it wrong would make Exclude reject every phrase
  /// that happens to end a verse.
  ///
  /// A match one token wide (or zero) has no interior at all, so Exclude
  /// passes it and Require fails it. Consistent with the same reading:
  /// there is nothing between one word and itself.
  bool spanPasses(List<bool> gaps, int first, int last) {
    if (!isActive) return true;
    var crossed = false;
    for (var k = first + 1; k <= last && k < gaps.length; k++) {
      if (gaps[k]) {
        crossed = true;
        break;
      }
    }
    return mode == PunctuationMode.exclude ? !crossed : crossed;
  }

  @override
  String toString() => 'PunctuationGate($mode, "$characters")';
}

/// One flag per token BOUNDARY: `gaps[k]` is true when the text lying
/// between token `k-1` and token `k` holds a character of [gate]'s set.
///
/// Length is `tokens.length + 1`. Index 0 covers the text before the
/// first token and the last index covers the text after the last, so the
/// array can be concatenated across verses without either end being lost
/// — see `command_query.dart`'s `;N` window, where verse *i*'s trailing
/// flag and verse *i+1*'s leading flag OR together into the single
/// boundary that separates the last word of one verse from the first word
/// of the next.
///
/// Booleans rather than the substrings themselves, deliberately: the set
/// is known before the corpus is opened, so the only thing worth keeping
/// per boundary is the one bit the test will ask for. A 31k-verse corpus
/// would otherwise allocate a string per word.
///
/// [text] must be the same string [tokens] were produced from —
/// `phraseTokens` records UTF-16 offsets into it, and offsets into a
/// different string would silently read punctuation out of the wrong
/// place.
List<bool> punctuationGapFlags(
    String text, List<PhraseToken> tokens, PunctuationGate gate) {
  final out = List<bool>.filled(tokens.length + 1, false);
  var cursor = 0;
  for (var k = 0; k < tokens.length; k++) {
    out[k] = gate.marks(text.substring(cursor, tokens[k].start));
    cursor = tokens[k].end;
  }
  out[tokens.length] = gate.marks(text.substring(cursor));
  return out;
}

// ── The marker on the command line ──────────────────────────────────

/// What [parsePunctuationMarker] made of one whitespace-delimited piece.
enum PunctuationMarkerOutcome {
  /// Not a marker. The caller must go on treating the piece exactly as it
  /// did before this file existed — see [parsePunctuationMarker] on why
  /// this is the answer for everything but `%-` and `%+`.
  notAMarker,

  /// A marker, and [PunctuationMarkerParse.gate] carries it.
  ok,

  /// `%-` or `%+` followed by something that is not punctuation.
  setInvalid,
}

typedef PunctuationMarkerParse = ({
  PunctuationMarkerOutcome outcome,
  PunctuationGate? gate,
});

/// Read one command-line piece as a punctuation marker.
///
/// The grammar is `%` then `-` (Exclude) or `+` (Require), then an
/// optional character set that replaces the default:
///
///     'love *5 god %-        love and god within five, same sentence
///     'love *5 god %+        … with a sentence end between them
///     'day *2 darkness %-,:; … and count the KJV's colon as a break too
///
/// ## Why `%`, and why it cannot collide
///
/// `.` `/` `'` `;` are `kCommandControls`; `!` negates; `*` is the
/// wildcard and the gap; `@` binds a Strong's tag; `~` and `=` are
/// refused by name; `(` `)` open a compound search; `[` `]` `{` `}` `?`
/// are pattern metacharacters; `&` `+` `|` are the Strong's boolean
/// operators. `%` is used by NONE of them: it appears nowhere in
/// `lib/` outside this file, and it appears nowhere in `kjv.json`,
/// `bsb.json` or `cuvs-yhwh.json` either, so it cannot be a character
/// someone is searching for.
///
/// ## Why a bare `%` is deliberately NOT a marker
///
/// The mode character is mandatory. Today a lone `%` inside a query is
/// dropped by `_compileTerm` as ordinary punctuation, so `.love %`
/// returns the same 280 KJV verses as `.love`; making `%` mean something
/// on its own would change the answer to a query somebody could already
/// have typed. Requiring the second character means the only lines whose
/// meaning changes are the ones that spell out a mode, and no query
/// written before today spelled one out.
///
/// A custom set may hold any punctuation. It may not hold a letter, a
/// digit, a Han character or a space — that is `setInvalid` rather than a
/// silent no-op, because `%-and` is a reader who meant something.
///
/// [kHebrewPunctuation] is the one exception carved out of that rule, and
/// it exists because `isWordChar` claims the whole Hebrew block U+0590–
/// U+05FF so that a pointed word does not shred into consonants — which
/// sweeps up the sof pasuq and the maqqef, the two marks bwh21 names by
/// hand on its Punctuation Tab. No shipped edition contains either (see
/// the library comment), so the carve-out buys nothing today; it is here
/// so that the day a pointed Hebrew text lands, `%-׃` is a query and not
/// a refusal.
///
/// The marker is lifted out of the line BEFORE the `;N` verse context is
/// read off the end of it, which is what keeps `'a *5 b;3 %-` and
/// `'a *5 b %-;3` the same query. The reverse order was tried and is
/// wrong in a way that returns an empty list rather than an error — see
/// the comment at that point in `parseCommandQuery`. A `;N` written flush
/// against the marker is peeled off there before this function sees the
/// piece, which is safe in one direction only: a digit is never
/// punctuation, so `%-.;3` can only be the set `.;` plus a context of 3
/// and never a set of three characters.
PunctuationMarkerParse parsePunctuationMarker(String piece) {
  const notAMarker =
      (outcome: PunctuationMarkerOutcome.notAMarker, gate: null);
  if (piece.length < 2 || piece[0] != '%') return notAMarker;
  final mode = switch (piece[1]) {
    '-' => PunctuationMode.exclude,
    '+' => PunctuationMode.require,
    _ => null,
  };
  if (mode == null) return notAMarker;
  final set = piece.substring(2);
  if (set.isEmpty) {
    return (
      outcome: PunctuationMarkerOutcome.ok,
      gate: PunctuationGate(mode, kSentenceEndPunctuation)
    );
  }
  for (var i = 0; i < set.length; i++) {
    final c = set.codeUnitAt(i);
    if (kHebrewPunctuation.contains(set[i])) continue;
    if (isCjkChar(c) || isWordChar(c) || c == 0x25 /* % */) {
      return (outcome: PunctuationMarkerOutcome.setInvalid, gate: null);
    }
  }
  return (
    outcome: PunctuationMarkerOutcome.ok,
    gate: PunctuationGate(mode, set)
  );
}
