/// 2026-08-19 (SeekSparks): compound searches — help topic bwh16,
/// "Doing Compound Searches". The last missing piece of BibleWorks'
/// search algebra, and the piece whose name is the most misleading.
///
/// ## What a naive reading of "parentheses" would get wrong
///
/// "Compound search" sounds like parenthesised boolean grouping — the
/// thing you add so that `a AND b OR c` stops being ambiguous. It is
/// not that. bwh16 spells it out:
///
///     (.grac* work*;5).15(/jesus christ)
///
/// Four facts that a grouping-operator reading would miss, every one of
/// which changes the answer:
///
/// 1. **Each group is a WHOLE search, not a term.** It carries its own
///    control character — `.` AND, `/` OR, `'` phrase, `;` linear — so
///    a compound combines an AND-search with an OR-search, which is a
///    thing our command line could not express at all.
/// 2. **Each group carries its own `;N` verse context.** The `;5` above
///    belongs to the grace/works search and to nothing else.
/// 3. **The separator carries a verse context of its OWN.** `.15` is
///    not "AND"; it is "AND, and the two groups' verses must fall within
///    fifteen verses of each other". That is a proximity JOIN between
///    two result sets, not a set intersection, and it is the whole
///    reason the feature is more than sugar: it finds a passage about
///    grace and works that sits near a passage about Christ, in verses
///    that share not one word.
/// 4. **Order is significant, and it decides what you are shown.**
///    bwh16: put `(/jesus christ)` last and "the verse List Box will
///    only have the verses that actually had the words jesus or
///    christ"; put the other group last and you get the grace/works
///    verses instead. The result set is drawn from the LAST group. A
///    reader who swaps two groups expecting the same list gets a
///    different one, so the echo says which side it is listing.
///
/// The separators are `.` (AND), `/` (OR) and `!` (NOT), each optionally
/// followed by a verse distance.
///
/// ## When a leading `(` is NOT a compound search
///
/// Our command line diverges from BibleWorks in one standing way: a
/// line with no control character is a plain substring search, because
/// most of our readers have never heard of a control character
/// (`command_query.dart`, "Deliberate divergences"). That divergence
/// reaches here. `(hello)` is a line somebody might type meaning the
/// literal text, and claiming it as a malformed compound would take a
/// working search away.
///
/// So a `(` line is claimed only when it is unambiguously compound
/// SHAPED: the first group opens with a control character, or the line
/// has one group followed by a separator and another. Anything else
/// falls through to [CommandIssue.notACommand] and the caller's own
/// text handling, exactly as before. `(hello)` still searches for
/// "(hello)"; `(.hello` is claimed and reported as unclosed.
///
/// ## Deliberately not implemented
///
/// * **Nesting.** BibleWorks' grammar is flat and ours refuses depth by
///   name rather than half-parsing it. Nesting would also make fact 4
///   above — which group's verses are listed — a question with no
///   single answer.
/// * **A Strong's expression as a group** (`(G25 AND G26).(.faith)`).
///   The two engines return different things: this one returns corpus
///   indices, `strongs_boolean_search.dart` returns concordance
///   references, and it is asynchronous. Joining them needs a
///   reference-to-index map and a decision about what a proximity join
///   means across a tagged layer, which is its own feature. A group
///   without a control character is reported by name
///   ([CommandIssue.compoundGroupOperator]) rather than guessed at.
///
/// Flutter-free on purpose, like the grammar it extends.
library;

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/utils/command_query.dart';

/// How a group combines with everything to its left.
enum CompoundJoin {
  /// `.` — both sides, in the same verse, or within the separator's
  /// verse distance of each other.
  and,

  /// `/` — either side.
  or,

  /// `!` — the left side, minus anything the right side matched.
  not,
}

/// One group after the first, with the separator that introduced it.
class CompoundStep {
  const CompoundStep({
    required this.join,
    required this.verseContext,
    required this.query,
    required this.source,
  });

  final CompoundJoin join;

  /// The number written on the separator: `.15`. 0 means "the same
  /// verse" for [CompoundJoin.and] and [CompoundJoin.not].
  final int verseContext;

  final CommandQuery query;

  /// The group as typed, parentheses stripped — for the echo.
  final String source;
}

/// A parsed, runnable compound query.
class CompoundQuery {
  const CompoundQuery({
    required this.first,
    required this.firstSource,
    required this.steps,
  });

  final CommandQuery first;
  final String firstSource;
  final List<CompoundStep> steps;

  /// Every group, in the order written.
  List<CommandQuery> get groups => [first, for (final s in steps) s.query];

  /// Every group's source, in the order written.
  List<String> get groupSources => [firstSource, for (final s in steps) s.source];

  /// Terms the reader is looking for, across all groups. Drives
  /// highlighting: a term only marks where it actually occurs, so
  /// carrying all of them cannot mark anything spurious.
  Iterable<QueryTerm> get positiveTerms =>
      groups.expand((g) => g.positiveTerms);

  /// Whether the joins are mixed, so that reading the echo with the
  /// usual "AND binds tighter than OR" precedence would give the wrong
  /// answer.
  ///
  /// There is no precedence here: like BibleWorks, groups combine
  /// strictly left to right, so `(.a)/(.b).(.c)` is `(a or b) and c` and
  /// not `a or (b and c)`. Two groups cannot be misread — one operator
  /// has nothing to bind against — so this is the exact condition under
  /// which the echo has to say so.
  bool get mixedJoins =>
      steps.length > 1 && steps.any((s) => s.join != steps.first.join);

  /// Whether the verses reported come from the last group rather than
  /// coinciding with every group's — true exactly when the last join is
  /// a proximity AND, which is the only case where the two differ and
  /// the reader could be surprised. See fact 4 in the library comment.
  bool get listsLastGroup =>
      steps.isNotEmpty &&
      steps.last.join == CompoundJoin.and &&
      steps.last.verseContext > 0;
}

/// Parse outcome: exactly one of [query] / [issue] is non-null.
class CompoundParse {
  const CompoundParse.ok(CompoundQuery this.query) : issue = null;
  const CompoundParse.failed(CommandIssue this.issue) : query = null;

  final CompoundQuery? query;
  final CommandIssue? issue;

  /// True when the line was claimed by this grammar, whether or not it
  /// ran. [CommandIssue.notACommand] is the caller's signal to carry on
  /// with references, version abbreviations and plain text.
  bool get isCompound => query != null || issue != CommandIssue.notACommand;
}

/// True when [raw] can only have been meant as a compound search.
///
/// The two shapes, and nothing else: a first group that opens with a
/// control character, or a group followed by a separator and another
/// group. See "When a leading `(` is NOT a compound search".
bool looksCompound(String raw) {
  final s = raw.trim();
  if (!s.startsWith('(')) return false;
  final after = s.substring(1).trimLeft();
  if (after.isNotEmpty && kCommandControls.contains(after[0])) return true;
  return _separatorShape.hasMatch(s);
}

final RegExp _separatorShape = RegExp(r'\)\s*[./!]\d*\s*\(');

/// Parse a compound command line.
///
/// Returns [CommandIssue.notACommand] for anything [looksCompound]
/// rejects, including every line that does not begin with `(`.
CompoundParse parseCompoundQuery(String raw) {
  final s = raw.trim();
  if (!looksCompound(s)) {
    return const CompoundParse.failed(CommandIssue.notACommand);
  }

  final sources = <String>[];
  final queries = <CommandQuery>[];
  final joins = <CompoundJoin>[];
  final contexts = <int>[];

  var i = 0;
  while (true) {
    while (i < s.length && s[i] == ' ') {
      i++;
    }
    if (i >= s.length || s[i] != '(') {
      // A separator with nothing after it, or trailing junk.
      return const CompoundParse.failed(CommandIssue.compoundSeparator);
    }
    final open = i;
    var close = -1;
    for (var j = open + 1; j < s.length; j++) {
      if (s[j] == '(') {
        return const CompoundParse.failed(CommandIssue.compoundNested);
      }
      if (s[j] == ')') {
        close = j;
        break;
      }
    }
    if (close < 0) {
      return const CompoundParse.failed(CommandIssue.compoundUnclosed);
    }

    final body = s.substring(open + 1, close).trim();
    final parsed = parseCommandQuery(body);
    if (parsed.query == null) {
      // "Not a command" here means the group has no control character.
      // That is a different, teachable thing from a group whose grammar
      // is wrong, and it is the one a reader arriving from a Strong's
      // expression will hit.
      return CompoundParse.failed(parsed.issue == CommandIssue.notACommand
          ? CommandIssue.compoundGroupOperator
          : parsed.issue!);
    }
    sources.add(body);
    queries.add(parsed.query!);
    if (queries.length > kMaxCompoundGroups) {
      return const CompoundParse.failed(CommandIssue.compoundTooManyGroups);
    }

    i = close + 1;
    while (i < s.length && s[i] == ' ') {
      i++;
    }
    if (i >= s.length) break;

    final join = switch (s[i]) {
      '.' => CompoundJoin.and,
      '/' => CompoundJoin.or,
      '!' => CompoundJoin.not,
      _ => null,
    };
    if (join == null) {
      return const CompoundParse.failed(CommandIssue.compoundSeparator);
    }
    i++;
    final digits = StringBuffer();
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (c < 0x30 || c > 0x39) break;
      digits.writeCharCode(c);
      i++;
    }
    // `tryParse` for the same reason `parseCommandQuery` uses it: the
    // digit scan above bounds the characters, not the magnitude, and on
    // the VM `int.parse` throws where JS quietly returns 1e20.
    final n = digits.isEmpty ? 0 : int.tryParse(digits.toString());
    if (n == null || n > kMaxVerseContext) {
      return const CompoundParse.failed(CommandIssue.contextTooLarge);
    }
    var context = n;
    // A distance on an OR cannot mean anything — a union constrains
    // nothing, so there is no window to widen. Dropped rather than
    // reported, which is the same call `parseCommandQuery` makes for
    // `/a b;5`, and the echo then does not claim a distance it is not
    // applying.
    if (join == CompoundJoin.or) context = 0;
    joins.add(join);
    contexts.add(context);
  }

  if (queries.isEmpty) {
    return const CompoundParse.failed(CommandIssue.emptyBody);
  }

  return CompoundParse.ok(CompoundQuery(
    first: queries.first,
    firstSource: sources.first,
    steps: List.unmodifiable([
      for (var k = 1; k < queries.length; k++)
        CompoundStep(
          join: joins[k - 1],
          verseContext: contexts[k - 1],
          query: queries[k],
          source: sources[k],
        ),
    ]),
  ));
}

/// Verse indices that matched, plus what each group found on its own.
class CompoundSearchResult {
  const CompoundSearchResult({
    required this.indices,
    required this.tokenized,
    required this.groupCounts,
  });

  /// Matching corpus indices, ascending.
  final List<int> indices;

  /// Verses tokenized across all groups.
  final int tokenized;

  /// How many verses each group matched before any combining. A zero
  /// here is why an empty compound result is empty, and it is the only
  /// place that can be seen — the combined list cannot tell a reader
  /// which half of their line was the problem.
  final List<int> groupCounts;
}

/// Run [query] over a parallel corpus. Arguments are the ones
/// [runCommandQuery] takes and mean the same things.
CompoundSearchResult runCompoundQuery({
  required CompoundQuery query,
  required List<String> texts,
  required List<String> searchKeys,
  required List<String> books,
}) {
  var tokenized = 0;
  final counts = <int>[];

  List<int> run(CommandQuery q) {
    final r = runCommandQuery(
      query: q,
      texts: texts,
      searchKeys: searchKeys,
      books: books,
    );
    tokenized += r.tokenized;
    counts.add(r.indices.length);
    return r.indices;
  }

  var acc = run(query.first);
  for (final step in query.steps) {
    final right = run(step.query);
    acc = switch (step.join) {
      // The reported verses become the RIGHT group's — bwh16's rule
      // that the last sub-search decides what is listed. With no
      // distance the two sides are the same verses anyway, so one
      // expression covers both.
      CompoundJoin.and => [
          for (final r in right)
            if (_hasNeighbour(acc, r, step.verseContext, books)) r
        ],
      CompoundJoin.or => _union(acc, right),
      CompoundJoin.not => [
          for (final a in acc)
            if (!_hasNeighbour(right, a, step.verseContext, books)) a
        ],
    };
  }

  return CompoundSearchResult(
    indices: acc,
    tokenized: tokenized,
    groupCounts: List.unmodifiable(counts),
  );
}

/// Whether [sorted] holds an index within [n] verses of [i] in the same
/// book.
///
/// The book test is what stops a window running off the end of Malachi
/// into Matthew; [runCommandQuery] guards its own `;N` window the same
/// way. Books are contiguous in the corpus, so the range scan below
/// touches at most `2n+1` entries.
bool _hasNeighbour(List<int> sorted, int i, int n, List<String> books) {
  final lo = i - n;
  final hi = i + n;
  var a = _lowerBound(sorted, lo);
  final book = books[i];
  while (a < sorted.length && sorted[a] <= hi) {
    if (books[sorted[a]] == book) return true;
    a++;
  }
  return false;
}

int _lowerBound(List<int> xs, int value) {
  var a = 0;
  var b = xs.length;
  while (a < b) {
    final mid = (a + b) >> 1;
    if (xs[mid] < value) {
      a = mid + 1;
    } else {
      b = mid;
    }
  }
  return a;
}

List<int> _union(List<int> a, List<int> b) {
  final out = <int>[];
  var i = 0;
  var j = 0;
  while (i < a.length && j < b.length) {
    if (a[i] == b[j]) {
      out.add(a[i]);
      i++;
      j++;
    } else if (a[i] < b[j]) {
      out.add(a[i++]);
    } else {
      out.add(b[j++]);
    }
  }
  while (i < a.length) {
    out.add(a[i++]);
  }
  while (j < b.length) {
    out.add(b[j++]);
  }
  return out;
}

/// The compound read back in words.
///
/// Each group is described by [describeCommandQuery] — the same
/// sentence it would get on its own — and the separators are spelled
/// out, distance included. When the last join is a proximity AND the
/// line also says which group's verses are being listed, because that
/// is the one fact about a compound that a list of verses cannot show
/// and that changes when two groups are swapped.
String describeCompoundQuery(CompoundQuery query, String locale) {
  String s(String key, String fallback) =>
      uiStrings[key]?[locale] ?? uiStrings[key]?['en'] ?? fallback;

  String group(CommandQuery q) => s('cmdEchoGroup', '({body})')
      .replaceAll('{body}', describeCommandQuery(q, locale));

  final buf = StringBuffer(group(query.first));
  for (final step in query.steps) {
    // The join pattern carries its own leading separator, because
    // English wants a space in front of "and" and Chinese wants a comma
    // and no space.
    final pattern = switch (step.join) {
      CompoundJoin.and => step.verseContext > 0
          ? s('cmdEchoJoinAndNear', ' and within {n} verses of {group}')
          : s('cmdEchoJoinAnd', ' and {group}'),
      CompoundJoin.or => s('cmdEchoJoinOr', ' or {group}'),
      CompoundJoin.not => step.verseContext > 0
          ? s('cmdEchoJoinNotNear', ' but not within {n} verses of {group}')
          : s('cmdEchoJoinNot', ' but not {group}'),
    };
    buf.write(pattern
        .replaceAll('{n}', '${step.verseContext}')
        .replaceAll('{group}', group(step.query)));
  }
  if (query.mixedJoins) {
    buf.write(s('cmdPartSeparator', ' · '));
    buf.write(s('cmdEchoCompoundLeftToRight', 'applied left to right'));
  }
  if (query.listsLastGroup) {
    buf.write(s('cmdPartSeparator', ' · '));
    buf.write(s('cmdEchoCompoundListing', 'listing the last group\'s verses'));
  }
  return buf.toString();
}
