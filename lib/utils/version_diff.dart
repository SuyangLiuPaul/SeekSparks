/// Word-level difference highlighting for the Browse stack — bwh30,
/// "Using Colors" § *Comparing Bible Versions*.
///
/// `docs/PARITY-BACKLOG.md` §3.3 filed this as ABSENT and cited
/// **bwh37**. That citation is wrong: bwh37 is *Compiling Version
/// Databases* and has nothing to do with colour. The feature is
/// specified in **bwh30**, and reading the right topic changed the
/// design in three ways that a guess from the feature's NAME would have
/// missed.
///
/// **1. It is a SAME-LANGUAGE operation.** bwh30's own framing: "this
/// feature facilitates comparing two translations *in the same
/// language*", and the one-click form is *"Toggle Difference
/// Highlighting … this will cause all **same language** versions
/// displayed to be compared"*. Our Browse pane routinely stacks
/// `LXX+WH · BSB · NASB · KJV · WTT` (#322's screenshot), and a naive
/// implementation would diff Greek against English and paint every word
/// of both. So the stack is partitioned by
/// [BibleVersionInfo.language] first, and a language with fewer than
/// two editions on screen is not compared at all.
///
/// That partition also settles 简体 vs 繁體 without a special case:
/// they are `zh-Hans` and `zh-Hant`, so 雅简+ is never diffed against
/// 雅繁+. It would be a true diff and useless — nearly every character
/// differs by script, which says nothing about the *translation*.
///
/// **2. The first version is the base.** bwh30: "the order of the
/// versions is significant. The first version will be the base version
/// for the comparison." In our stack the first row is
/// `WorkbenchProvider.displayVersions.first`, which is the reader's own
/// reading version — so the base is the text they are actually reading
/// and everything else is measured against it. That is a better default
/// than BibleWorks', where the base is whatever was typed first into a
/// settings box.
///
/// **3. Where BibleWorks cannot follow us.** bwh30 states flatly:
/// *"Color filters and text coloring are not currently supported for
/// double-byte languages (Chinese, Arabic, Korean, Japanese, Thai,
/// Vietnamese)."* Chinese difference highlighting is a thing BibleWorks
/// does **not** do, and it is the comparison this app's readers most
/// need. Measured over the whole corpus, `cuvs-plus` against
/// `cuvs-yhwh` — the same 和合本 base text, one with the Name restored
/// — differs in **7,892 of 31,102 verses (25.4%)**, and in **71.7% of
/// those the ONLY characters marked are divine-name characters**
/// (76.1% of all 46,569 marked characters). That is the feature working
/// as intended: one toggle shows a reader every place the restoration
/// touched, without running a search.
///
/// **What the marks look like on an English pair, so nobody later
/// "fixes" it.** A true LCS diff of two independent translations marks
/// a LOT: `kjv`→`nasb` marks 36.9% of the NASB's tokens, `bsb`→`leb`
/// 38.3%, and 99%+ of verses differ somewhere. That is not a bug and
/// not a tokeniser fault — those editions really are worded that
/// differently, and an implementation that showed less would be hiding
/// something. The reader controls the noise by choosing what to stack,
/// which is why this ships behind a toggle that is off by default.
///
/// Pure string, list and set work: no Flutter, no assets, no I/O.
library;

import 'package:seeksparks/constants/bible_versions.dart' show bibleVersions;
import 'package:seeksparks/utils/phrase_match.dart' show phraseTokens;

/// One token of a row, and where it sits in the row's rendering.
///
/// [unit] is the index of the *drawn piece* the token came from — a
/// scripture span for an untagged edition, a tagged run for a tagged
/// one. [start] and [end] are UTF-16 offsets **inside that unit's own
/// string**, which is what a renderer can act on without re-deriving
/// anything.
typedef VersionDiffToken = ({int unit, int start, int end, String norm});

/// A row's tokens, in reading order.
///
/// Built by walking the pieces the row will actually be DRAWN from and
/// tokenising each. That is deliberate and is the only reason the marks
/// can be trusted: the diff and the renderer traverse the same list in
/// the same order, so a token index can never mean one word to the
/// comparison and a different word to the paint.
///
/// The tokeniser is `phrase_match.dart`'s house rule — one token per Han
/// character, one lower-cased token per alphabetic run, punctuation
/// transparent. Deliberately not a second one: #307 already records that
/// this app must not grow a rival Chinese tokeniser.
List<VersionDiffToken> versionDiffTokens(List<String> units) {
  final out = <VersionDiffToken>[];
  for (final (i, u) in units.indexed) {
    for (final t in phraseTokens(u)) {
      out.add((unit: i, start: t.start, end: t.end, norm: t.text));
    }
  }
  return out;
}

/// The token indices of `a` and of `b` that are **not** in their longest
/// common subsequence.
///
/// bwh30 offers two methods and says to use this one: *"The LCS method
/// is the most commonly used, and you should probably use it unless you
/// have reasons to do otherwise."* The other, *Word Occurrence*, "finds
/// words that occur in only one of the verses" — a set difference that
/// ignores order, so it cannot see a reordering and reports nothing when
/// two versions use the same vocabulary in a different arrangement.
/// Only LCS is built; the second is recorded here rather than shipped,
/// because a second method needs a second control and its results
/// differ from this one only in cases the reader would have to be
/// taught to expect.
(Set<int>, Set<int>) lcsDifferences(List<String> a, List<String> b) {
  final n = a.length;
  final m = b.length;
  if (n == 0 || m == 0) {
    return (
      {for (var i = 0; i < n; i++) i},
      {for (var j = 0; j < m; j++) j},
    );
  }
  // Full table: verses are tens of tokens, so n*m stays in the low
  // thousands and the backtrack needs the whole grid anyway.
  final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    final ai = a[i];
    final rowI = dp[i];
    final rowI1 = dp[i + 1];
    for (var j = m - 1; j >= 0; j--) {
      rowI[j] = ai == b[j]
          ? rowI1[j + 1] + 1
          : (rowI1[j] >= rowI[j + 1] ? rowI1[j] : rowI[j + 1]);
    }
  }
  final aOut = <int>{for (var i = 0; i < n; i++) i};
  final bOut = <int>{for (var j = 0; j < m; j++) j};
  var i = 0;
  var j = 0;
  while (i < n && j < m) {
    if (a[i] == b[j]) {
      aOut.remove(i);
      bOut.remove(j);
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }
  return (aOut, bOut);
}

/// Which tokens to mark, for every row of one same-language group.
///
/// `rows[0]` is the base, per bwh30. Every other row is marked where it
/// does not align with the base — the plain reading of "here is what I
/// am reading; here is where that edition says something else".
///
/// **The base row is marked where it aligns with NO other row**, which
/// is a departure from BibleWorks and is stated rather than hidden.
/// BibleWorks unions the base's differences across every comparison, so
/// a base word survives unmarked only if EVERY other row happens to
/// carry it. Measured on the five-English stack this pane offers —
/// `kjv nasb bsb leb kjvs`, 31,080 verses all five carry, 789,310 base
/// tokens — the two rules are not a matter of taste:
///
///   union (BibleWorks)     460,253 tokens marked — **58.3%** of the
///                          base row painted
///   intersection (ours)        489 tokens marked — **0.1%**
///
/// bwh30 half-admits the problem itself, offering a fourth option that
/// re-runs the comparison with every version as base "to provide a
/// better visual display … when you are comparing more than 2
/// versions". Intersecting makes the base row answer a question worth
/// asking — *what does my edition say that nobody else on screen says*
/// — and 489 answers across the whole Bible is a finding a reader can
/// act on, where 58% of the page is wallpaper. For the two-version
/// case, which is what this is mostly used for, the two rules are
/// identical.
List<Set<int>> versionDiffMarks(List<List<String>> rows) {
  if (rows.length < 2) {
    return List.generate(rows.length, (_) => <int>{});
  }
  final base = rows.first;
  final marks = List.generate(rows.length, (_) => <int>{});
  Set<int>? baseShared;
  for (var i = 1; i < rows.length; i++) {
    final (baseOnly, otherOnly) = lcsDifferences(base, rows[i]);
    marks[i] = otherOnly;
    baseShared = baseShared == null
        ? baseOnly
        : baseShared.intersection(baseOnly);
  }
  marks[0] = baseShared ?? <int>{};
  return marks;
}

/// The comparable groups in a Browse stack, keyed by language, in
/// display order, dropping any language with fewer than two editions.
///
/// Codes the catalog does not know are dropped rather than pooled under
/// an "unknown" language. The Browse pane's `wtt` and `bgt` rows are
/// exactly that case: they are the originals layer, assembled from
/// `assets/originals/` rather than loaded from the catalog, and there is
/// only ever one of each on screen, so they could not form a group even
/// if they were catalogued. The single `grc` edition (`lxxwh`) cannot
/// either. Both facts are why no Greek or Hebrew normalisation is built
/// here: bwh30's first three options — ignore accents, ignore a movable
/// final nu, ignore sin/shin — all describe comparisons this stack
/// cannot currently contain, and building an untested fold for a group
/// that never occurs is worse than not building it.
Map<String, List<String>> comparableVersionGroups(List<String> codes) {
  final lang = <String, String>{
    for (final v in bibleVersions) v.value: v.language,
  };
  final out = <String, List<String>>{};
  for (final c in codes) {
    final l = lang[c];
    if (l == null) continue;
    (out[l] ??= <String>[]).add(c);
  }
  out.removeWhere((_, v) => v.length < 2);
  return out;
}

/// The marked spans of one drawn unit, merged where they touch.
///
/// Two marked tokens with nothing but punctuation or a space between
/// them are drawn as ONE mark. Without this a Chinese diff is confetti —
/// the tokeniser emits one token per Han character, so a four-character
/// phrase that differs would otherwise draw four separate underlines
/// with hairline gaps between them, which reads as damage rather than as
/// a finding. English gains the same: a reworded clause becomes one
/// mark, not six.
List<({int start, int end})> mergedMarkSpans(
  List<VersionDiffToken> tokens,
  Set<int> marks,
  int unit,
) {
  final out = <({int start, int end})>[];
  for (var i = 0; i < tokens.length; i++) {
    if (!marks.contains(i) || tokens[i].unit != unit) continue;
    final start = tokens[i].start;
    var end = tokens[i].end;
    while (i + 1 < tokens.length &&
        marks.contains(i + 1) &&
        tokens[i + 1].unit == unit) {
      end = tokens[i + 1].end;
      i++;
    }
    out.add((start: start, end: end));
  }
  return out;
}

/// `[from, to)` cut into runs that are wholly marked or wholly not.
///
/// The difference mark has to share the line with the search
/// highlighter, which slices the same string on its own boundaries and
/// knows nothing about this one. Both are real: a word can be a search
/// hit AND be worded differently from the base, and the reader is owed
/// both facts. So neither owns the split — the pieces are cut on the
/// union of the two boundary sets, and each piece carries a fill from
/// one and an underline from the other.
///
/// [spans] must be sorted and disjoint, which is what
/// [mergedMarkSpans] returns.
List<({int start, int end, bool marked})> sliceByMarks(
  int from,
  int to,
  List<({int start, int end})> spans,
) {
  final out = <({int start, int end, bool marked})>[];
  var at = from;
  for (final s in spans) {
    if (s.end <= from || s.start >= to) continue;
    final a = s.start < from ? from : s.start;
    final b = s.end > to ? to : s.end;
    if (a > at) out.add((start: at, end: a, marked: false));
    out.add((start: a, end: b, marked: true));
    at = b;
  }
  if (at < to) out.add((start: at, end: to, marked: false));
  return out;
}
