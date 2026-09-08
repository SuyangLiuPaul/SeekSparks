/// 2026-09-08 (SeekSparks): the `@` Strong's tag binding — BibleWorks
/// help topic bwh16, "Doing Searches on Strong's Numbers".
///
/// `@` is the one operator on the BibleWorks command line that crosses
/// languages. Every other operator asks a question about the words on
/// the page; `@` asks a question about the words BEHIND the page:
///
///     .man@444     "man", where the Greek behind it is ἄνθρωπος
///
/// SeekSparks could already ask "every G444" (`G25 AND G26`, the
/// concordance path) and "every *man*" (`.man`). It could not ask for
/// their intersection, and the intersection is a different question:
/// bwh16 lists G444 rendered as *any, anyone, child, enemy, everyone,
/// fellow, friend, human* — eight English words that a search for `man`
/// cannot reach and a search for G444 cannot separate.
///
/// ## Why `command_query.dart` used to refuse this, and what changed
///
/// That file's "Deliberately not implemented" list gave two reasons.
/// Both were checked before this was written rather than assumed:
///
///   * **"it needs the tagged-text service".** It did, and the service
///     did not exist on 2026-08-07. It landed the day before as
///     `services/tagged_text_service.dart`, and by now six of the twelve
///     bundled editions carry `assets/tagged/<version>/<book>.json` —
///     bsb, csb, cuvs-plus, cuvs-yhwh, kjvs, lxxwh. Each verse is a list
///     of runs, `{"w": "the heavens ", "s": "H8064"}`, which is exactly
///     the alignment `@` needs and the reason this is now a parser
///     change and not a research project. The reason is spent.
///
///   * **"the app already has a *different* Strong's syntax in the same
///     box".** Still true, and still a design decision — but not a
///     collision. The two grammars are told apart by the FIRST
///     character and cannot reach for the same line: `G25 AND G26` has
///     no leading control character, so `parseCommandQuery` returns
///     [CommandIssue.notACommand] for it and `WorkbenchProvider` hands
///     it on to `parseStrongsBoolean`; `.man@444` opens with `.`, which
///     `parseStrongsBoolean` has never accepted. The decision this file
///     makes is therefore about MEANING, not about precedence: `@444`
///     spells a number the same way `G444` does once it has been
///     normalised, so a reader who learned one number in the concordance
///     can type it in the other grammar and get the same word.
///
/// ## Reading a number: the leading zero
///
/// BibleWorks has no `G`/`H` prefix on the command line. It tells Greek
/// from Hebrew by a **leading zero** — bwh16's own examples are `@444`
/// (Greek ἄνθρωπος) and `@06635` / `@03068` (Hebrew צָבָא, יהוה) — and
/// its Strong's help says outright that "Old Testament reference numbers
/// have a zero in front of the number". SeekSparks' own assets and its
/// other Strong's grammar spell the same numbers `G444` and `H6635`.
///
/// So [normaliseStrongsTag] accepts both and returns one:
///
///     @444     → G444     (no leading zero ⇒ Greek, BibleWorks' rule)
///     @06635   → H6635    (leading zero ⇒ Hebrew, BibleWorks' rule)
///     @G444    → G444     (SeekSparks' own spelling, accepted)
///     @H6635   → H6635
///
/// Accepting the explicit letter is an addition, not a divergence:
/// nothing in bwh16 uses it, and every BibleWorks line keeps working.
/// It exists because this app shows the reader `H6635` everywhere else —
/// in the analysis pane, in the concordance, in `G25 AND G26` — and a
/// box that refused the only spelling the app itself prints would be a
/// puzzle rather than a shortcut. The zero rule stays because a
/// BibleWorks user's fingers already know it, and because dropping it
/// would make `@06635` mean G6635, a number that does not exist.
///
/// ## What a run is, and why the tag binds every token of a term
///
/// BibleWorks tags word by word. These assets tag by RUN, and a run can
/// be several words:
///
///     kjvs   Gen 1:1   {"w": "In the beginning", "s": "H7225"}
///     cuvs   Gen 1:1   {"w": "起初", "s": "H7225"}
///
/// Two consequences, both measured against the shipped assets rather
/// than reasoned about:
///
///   1. **Every token of a run carries the run's number.** In the BSB,
///      `.and@H430` matches, because "and God" is one run tagged H430.
///      That is over-broad next to BibleWorks and it is what the data
///      says; inventing a head-word rule would be this file guessing at
///      an alignment the importer did not record. The visible cost is
///      `.!god@H430` — "אֱלֹהִים rendered as something other than God" —
///      which returns 103 verses of BSB Genesis whose leading words are
///      *and* (31), *the* (22), *of* (15) and *then* (15) rather than a
///      real alternative rendering of the noun.
///
///   2. **A term's tag applies to every token the term occupies**, which
///      is what makes the feature work in Chinese at all. 起初 is two
///      tokens here (one per Han character, `phrase_match.dart`'s rule)
///      and one run, H7225. Binding the tag to "the last token" or "the
///      first token" would both be arbitrary; requiring all of them is
///      the reading under which `.起初@H7225` finds Genesis 1:1 and
///      `.起初@H1254` does not. BibleWorks never faced the question —
///      bwh17b, its Far East topic, is four pages about keyboards.
///
/// ## `!` here is positional, which is its third meaning on this line
///
/// bwh16: "`.!man@444` will find occurrences of ἄνθρωπος that have not
/// been translated as man". That is NOT the `!` of `.paul !barnabas`,
/// which throws the whole verse away. On a tag-bound term `!` fills a
/// position — *some word that is not "man", tagged 444* — exactly as it
/// already does inside a `'` phrase. `command_query.dart`'s library
/// comment already warns that `!` means two things; this is the third,
/// and it is the one bwh16 spends a bullet on.
///
/// ## Deliberately not implemented
///
///   * **A wildcard inside the number.** bwh16 has `.*@[1234567890]*`,
///     "all the words tagged with some Strong's number". `@*` already
///     says that here and says it in one character, because SeekSparks
///     stores an untagged run as an empty string and BibleWorks stores
///     it as `-`; the bracket form exists there to work around that
///     representation and buys nothing here. Anything else inside a
///     number (`@44*`) is refused by name rather than guessed at: the
///     leading-zero rule above makes `@0*` ambiguous between "Hebrew,
///     any number" and "Greek 0-something", and a prefix search that
///     silently picked one would be wrong half the time.
///
///   * **"Extend <> Tags to All Words"**, bwh16's option that pushes a
///     number backwards over every preceding untagged word. It is a
///     workaround for a tagging format that marks positions between
///     words; these assets mark the words themselves, so there are no
///     orphans for it to adopt.
///
///   * **The `implied` list** (`"i": ["H853"]`) is not searched. Those
///     are numbers the original has and the translation does not render
///     — the Hebrew direct-object marker, the Greek article. `@` asks
///     "this word renders that lemma", and a word that renders nothing
///     is the one case where the answer is no. `TaggedRun`'s own doc
///     says the same thing: implied numbers are "worth showing as
///     secondary, never as the word's own identity".
///
/// Flutter-free, like `command_query.dart` which imports it: this parses
/// a number and compares strings.
library;

import 'package:seeksparks/constants/text_patterns.dart'
    show sanitizeForSearchKey;
import 'package:seeksparks/utils/phrase_match.dart' show phraseTokens;
import 'package:seeksparks/utils/search_folding.dart' show foldSearchMarks;
import 'package:seeksparks/utils/strongs_boolean_search.dart'
    show kMaxGreekStrongs, kMaxHebrewStrongs;

/// One token of a verse, and the Strong's number of the run it came from.
///
/// [text] is spelled the way `command_query.dart` spells a corpus token —
/// sanitised, folded, lower-cased — so the two paths compare like with
/// like. [strongs] is `''` for a run the tagger left unmarked, which is
/// what `@-` looks for.
class TaggedToken {
  const TaggedToken(this.text, this.strongs);

  final String text;
  final String strongs;

  @override
  String toString() => strongs.isEmpty ? text : '$text@$strongs';
}

/// A verse's tagged runs as this file needs them, so that nothing here
/// has to import `TaggedRun` and with it `package:flutter`.
typedef TaggedRunView = ({String text, String strongs});

/// Corpus index → that verse's tagged tokens, or null when the edition
/// has no tagged entry for it.
///
/// A callback rather than a list because the prefilter opens a small
/// fraction of the corpus: `.beginning@H7225` tokenizes 108 of the BSB's
/// 31,086 verses, and building 31,086 token lists to answer it would
/// cost more than the search.
typedef TaggedTokensLookup = List<TaggedToken>? Function(int index);

/// What the text after `@` asked for.
enum StrongsTagForm {
  /// `@444`, `@06635`, `@G444` — one particular lemma.
  number,

  /// `@*` — tagged with anything at all.
  any,

  /// `@-` — not tagged. bwh16 calls these the "untagged" words: text
  /// the translation supplies that the original does not have.
  none,
}

/// The `@…` half of one search term.
class StrongsTagBinding {
  const StrongsTagBinding({
    required this.source,
    required this.form,
    required this.negated,
    this.number,
  });

  /// The tag exactly as typed, `@` and `!` stripped — so the echo can
  /// quote it back if it has nothing better to print.
  final String source;

  final StrongsTagForm form;

  /// Had a `!` directly after the `@` (`man@!444`). Inverts the TAG
  /// test only; the word still has to match. This is a different `!`
  /// from the one in `!man@444`, which inverts the WORD.
  final bool negated;

  /// The normalised number (`G444`, `H6635`), or null unless
  /// [form] is [StrongsTagForm.number].
  final String? number;

  /// Whether a run tagged [strongs] (empty for untagged) satisfies this.
  bool matchesTag(String strongs) {
    final hit = switch (form) {
      StrongsTagForm.number => strongs.toUpperCase() == number,
      StrongsTagForm.any => strongs.isNotEmpty,
      StrongsTagForm.none => strongs.isEmpty,
    };
    return hit != negated;
  }

  @override
  String toString() => '@${negated ? '!' : ''}${number ?? source}';
}

/// Why an `@…` could not be read.
enum StrongsTagIssue {
  /// `.man@` — the operator with nothing after it.
  empty,

  /// `.man@44x`, `.man@44*`, `.man@99999` — not a number this app can
  /// resolve. See "Deliberately not implemented" on wildcards.
  badNumber,
}

/// Parse outcome: exactly one of the two fields is non-null.
typedef StrongsTagParse = ({
  StrongsTagBinding? binding,
  StrongsTagIssue? issue,
});

/// Read the text that followed an `@`.
StrongsTagParse parseStrongsTag(String afterAt) {
  var body = afterAt.trim();
  var negated = false;
  while (body.startsWith('!')) {
    negated = true;
    body = body.substring(1).trim();
  }
  if (body.isEmpty) return (binding: null, issue: StrongsTagIssue.empty);
  if (body == '*') {
    return (
      binding: StrongsTagBinding(
          source: body, form: StrongsTagForm.any, negated: negated),
      issue: null,
    );
  }
  if (body == '-') {
    return (
      binding: StrongsTagBinding(
          source: body, form: StrongsTagForm.none, negated: negated),
      issue: null,
    );
  }
  final number = normaliseStrongsTag(body);
  if (number == null) {
    return (binding: null, issue: StrongsTagIssue.badNumber);
  }
  return (
    binding: StrongsTagBinding(
      source: body,
      form: StrongsTagForm.number,
      negated: negated,
      number: number,
    ),
    issue: null,
  );
}

/// `444` → `G444`, `06635` → `H6635`, `h157` → `H157`; null when the
/// text is not a number this app can resolve.
///
/// The ceilings are `strongs_boolean_search.dart`'s, deliberately, and
/// not the tighter real ones in `strongs_absence.dart`. Both Strong's
/// grammars share one search box, and a number that `G25 AND G26` would
/// accept must not be refused three characters later because it was
/// written `@25`. A number inside the range that nothing is tagged with
/// returns no verses, which is a different fact and already has its own
/// sentence.
String? normaliseStrongsTag(String body) {
  final m = RegExp(r'^([GgHh]?)(\d{1,6})$').firstMatch(body.trim());
  if (m == null) return null;
  final digits = m.group(2)!;
  final n = int.tryParse(digits);
  if (n == null || n < 1) return null;
  final letter = m.group(1)!;
  // BibleWorks' rule, and the whole reason a leading zero is not noise:
  // `@06635` is Hebrew, `@6635` would be a Greek number that does not
  // exist. An explicit letter always wins, because the reader who typed
  // one has said which language they meant.
  final lang = letter.isNotEmpty
      ? letter.toUpperCase()
      : (digits.startsWith('0') ? 'H' : 'G');
  final max = lang == 'G' ? kMaxGreekStrongs : kMaxHebrewStrongs;
  if (n > max) return null;
  return '$lang$n';
}

/// Flatten one verse's tagged runs into the tokens a query matches.
///
/// Spelled exactly the way `runCommandQuery` spells its own tokens —
/// [sanitizeForSearchKey], then [phraseTokens], then [foldSearchMarks] —
/// because the two token streams have to agree or a `@` search and a
/// plain search would disagree about what a word is.
///
/// The sanitiser runs per RUN rather than over the whole verse, which is
/// safe only because `TaggedTextService.reuniteGlossRuns` has already
/// pulled every `主[雅伟]` gloss back into the run that opened it: no
/// bracket in the loaded assets straddles a run boundary, so no
/// per-run pass can see half of one.
List<TaggedToken> taggedRunTokens(List<TaggedRunView> runs) {
  final out = <TaggedToken>[];
  for (final run in runs) {
    for (final t in phraseTokens(sanitizeForSearchKey(run.text))) {
      out.add(TaggedToken(foldSearchMarks(t.text), run.strongs));
    }
  }
  return out;
}
