/// The looser reading of a search — measured, never merely suggested.
///
/// A reader in Hong Kong searched for the English phrase `the true God`,
/// got 3 verses, and could not find John 17:3, "the only true God". The
/// verses she wanted were three keystrokes away: `.the true God` finds
/// every verse holding those words in any arrangement. She never learned
/// that, because the line that teaches the `.` operator only appears
/// when a search returns ZERO results. Three is not zero, so the app
/// showed her a short list and said nothing.
///
/// The fix is not another hint. The same report contained a hint that
/// made things worse — offered `.ὁ θεός` against a corpus set without
/// accents, so tapping it led to a second empty page. **A dead end
/// dressed as help is worse than silence.** So the rule this file exists
/// to enforce is: the app never offers a query it has not run. What the
/// reader sees is the looser query's REAL verse count, measured under
/// the same edition and the same scope as the search they just ran, and
/// the offer is withheld entirely when that count is not larger.
///
/// ONE RUNG ONLY, and the choice is semantic rather than cautious.
/// BibleWorks' ladder (bwh16) is phrase `'` → AND `.` → OR `/`, and only
/// the first step is safe to propose. Dropping the phrase constraint
/// drops *word order and adjacency*; it does not change which words the
/// reader asked for, and readers impose that constraint by accident all
/// the time — a plain multi-word line is already an order-sensitive
/// substring scan. Dropping the conjunction is a different question:
/// measured over the BSB, `.the true God` is 18 verses and `/the true
/// God` is 23,248, which is not a broader answer but a different one.
/// So AND is never broadened to OR.
///
/// BibleWorks itself has no equivalent. Its answer to a query too strict
/// for the text is "fuzzy" Porter or Link stemming, English only,
/// reached by right-clicking the command line — and its own help calls
/// Porter stemming "more of a curiosity than a refined tool". The
/// capability exists and is undiscoverable, which is precisely the shape
/// of the defect being fixed here.
library;

import 'package:seeksparks/utils/command_query.dart';

/// Below this many results, the looser reading is worth measuring.
///
/// A judgement, and stated as one. The offer exists to rescue a search
/// that under-delivered, and there is no way to read the reader's
/// expectation off the query — so the signal used is that the result did
/// not fill the pane. Above it the reader has a list to work with and a
/// second, larger number is noise: `'in the beginning` returns 17 verses
/// in the KJV and 36 without the order, and a reader holding 17 verses
/// of Genesis, John and Judges is not stuck.
const int kBroadenBelow = 20;

/// The looser query and what it actually returns.
class SearchBroadening {
  const SearchBroadening({
    required this.line,
    required this.query,
    required this.verses,
  });

  /// The command line to put in the box — shown as well as run, because
  /// the operator is the thing the reader has to learn.
  final String line;

  /// The parsed form, so the caller can read it back in words.
  final CommandQuery query;

  /// Verses found, measured under the same edition and scope as the
  /// search this broadens.
  final int verses;
}

/// Which of a query's words the corpus does not contain at all.
///
/// The terminus of the ladder. When the loosest honest reading still
/// finds nothing, "No results found" is true and useless; naming the
/// word that is not there turns it into a diagnosis. Had this existed
/// before the accent fold landed, the same reader's first query would
/// have answered "no verse contains ὁ" — which is the whole bug, said
/// out loud.
class TermPresence {
  const TermPresence({required this.absent, required this.checked});

  /// Term sources, as typed, that occur in no verse searched.
  final List<String> absent;

  /// How many positive terms were probed.
  final int checked;

  /// Every word is somewhere in the text; they simply never meet.
  bool get allPresentApart => absent.isEmpty && checked >= 2;
}

/// The command line one rung looser than what the reader ran, or null
/// when there is no honest one.
///
/// [parsed] is the grammar's reading of the line when it had a control
/// character; [raw] is the line as typed, which is all there is for a
/// plain multi-word search — the shape the original report was made
/// against.
String? broadenedCommandLine({CommandQuery? parsed, required String raw}) {
  final line = parsed != null
      ? _broadenParsed(parsed)
      : _broadenPlainText(raw);
  if (line == null) return null;
  // Validate by parsing our own output: the terms are re-read through
  // the same grammar the reader would have typed, so a source carrying
  // a character that changes meaning in AND position — a `!`, a stray
  // control — is caught here rather than shipped as an offer that means
  // something else.
  final check = parseCommandQuery(line).query;
  if (check == null) return null;
  if (check.kind != CommandKind.and) return null;
  if (check.terms.any((t) => t.negated)) return null;
  if (check.positiveTerms.length < 2) return null;
  return line;
}

String? _broadenParsed(CommandQuery query) {
  // AND is already the loosest rung offered; OR answers a different
  // question. See the library comment.
  if (query.kind != CommandKind.phrase) return null;
  // `'!the god` fills one sequence position with "any word but the".
  // The same `!` in an AND excludes the whole verse, so the AND form is
  // not a loosening of the phrase form — it is a different search that
  // happens to share the words.
  if (query.terms.any((t) => t.negated)) return null;
  final sources = [for (final t in query.positiveTerms) t.source];
  if (sources.length < 2) return null;
  final context = query.verseContext > 0 ? ';${query.verseContext}' : '';
  return '.${sources.join(' ')}$context';
}

String? _broadenPlainText(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  if (kCommandControls.contains(trimmed[0])) return null;
  // A plain line is scanned as a substring with the spaces removed, so
  // it is an exact run of words in an exact order. One word has no order
  // to drop.
  if (!trimmed.contains(RegExp(r'\s'))) return null;
  return '.$trimmed';
}

/// The positive terms of [query] that occur in no verse of the corpus.
///
/// Each term is probed by rebuilding it as a one-term AND query and
/// running the real engine over it, rather than testing its literal
/// against the keys directly. A term is not a literal — `faith*` is a
/// pattern, `爱神` is two token positions that punctuation may separate
/// — and this file re-implementing any part of that is how the probe
/// ends up being the thing that is wrong.
TermPresence termPresence({
  required CommandQuery query,
  required List<String> texts,
  required List<String> searchKeys,
  required List<String> books,
  bool Function(int index)? inScope,
}) {
  final absent = <String>[];
  var checked = 0;
  for (final term in query.positiveTerms) {
    checked++;
    final probe = CommandQuery(
      kind: CommandKind.and,
      control: '.',
      terms: [term],
      outline: [(term: term, gap: null)],
      sequence: const [],
      // "Does this word occur at all" — the reader's verse window is
      // about how far apart the words may fall, which cannot matter to
      // a question about one of them.
      verseContext: 0,
    );
    final hits = runCommandQuery(
      query: probe,
      texts: texts,
      searchKeys: searchKeys,
      books: books,
    ).indices;
    final present =
        inScope == null ? hits.isNotEmpty : hits.any(inScope);
    if (!present) absent.add(term.source);
  }
  return TermPresence(absent: absent, checked: checked);
}
