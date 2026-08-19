/// 2026-08-19: the browsable side of Nave's Topical Bible — pure logic.
///
/// `NavesService` answers "what does Nave say about the verse I am on".
/// This answers the other direction: "what does Nave say about a WORD I
/// have in my head", and "how do I read a topic that is 801 lines long".
/// Both questions turn out to be about size, and the sizes were measured
/// before any of this was written:
///
/// * 5,322 headwords. 51.6% carry two references or fewer and 649 carry
///   none at all (they are pure redirects — "MALICE, See ANGER"). A flat
///   list of 5,322 equal-looking rows would hide that, so the caller is
///   given each row's weight.
/// * JESUS, THE CHRIST is 801 lines and 3,828 references. Its depth-1
///   skeleton is 87 lines. The median topic's depth-1 count is 2. So the
///   rule is the same for both: show depth 1, collapse what hangs under
///   it and say how much is there. No size threshold, no special case.
/// * The headwords are a 1896 vocabulary and a reader's is not. "worry"
///   and "depression" both match zero of them. The entry text is a
///   genuinely different index — "divorce" is 2 headwords but 37 lines,
///   and DESPONDENCY is a headword that ALSO appears inside AFFLICTIONS
///   AND ADVERSITIES and ELIJAH — so [searchLineText] is the second tier
///   that keeps a reasonable question off a blank page.
///   It is not a cure, and the caller must not present it as one:
///   "depression" is zero in the lines too, and "worry" matches exactly
///   one, about Sidon living without one. When Nave has nothing, the
///   honest answer is that he has nothing.
///
/// Everything here takes plain lists and returns plain lists so it can
/// be tested without a bundle. The counts it returns are TOTALS, never
/// the length of what it handed back: a cap on a sorted list is a silent
/// WHERE clause, and the caller has to be able to name what it hid.
library;

/// One matched headword, with the weight that decides how it reads in a
/// list.
class NaveHeadHit {
  const NaveHeadHit({required this.topicId, required this.prefix});

  final int topicId;

  /// True when the query matched the START of the headword. A reader
  /// typing "love" wants LOVE above BROTHERLY LOVE; both are wanted, so
  /// neither is dropped.
  final bool prefix;
}

/// Every headword matching [query], prefix matches first.
///
/// Uncapped on purpose. The caller shows a count, and a count that was
/// itself truncated is worse than no count.
List<NaveHeadHit> matchHeadwords(List<String> heads, String query) {
  final q = query.trim().toUpperCase();
  if (q.isEmpty) return const [];
  final starts = <NaveHeadHit>[];
  final contains = <NaveHeadHit>[];
  for (var i = 0; i < heads.length; i++) {
    final h = heads[i].toUpperCase();
    if (h.startsWith(q)) {
      starts.add(NaveHeadHit(topicId: i, prefix: true));
    } else if (h.contains(q)) {
      contains.add(NaveHeadHit(topicId: i, prefix: false));
    }
  }
  return [...starts, ...contains];
}

/// A hit inside the body of an entry: which topic, which line.
class NaveTextHit {
  const NaveTextHit({required this.topicId, required this.lineIndex});

  final int topicId;
  final int lineIndex;
}

/// A capped page of entry-text hits that still knows its own size.
class NaveTextResult {
  const NaveTextResult({required this.hits, required this.total});

  final List<NaveTextHit> hits;

  /// How many lines matched in the whole work, not how many came back.
  final int total;

  bool get truncated => total > hits.length;
}

/// Search the text of every line. [lines] is topic id → line texts in
/// Nave's order, so a hit is a (topic, line) pair the shards resolve
/// without a second key.
///
/// Ordered by topic id, which is alphabetical by headword, then by line.
/// Ranking by "relevance" over 1896 prose would be a guess; alphabetical
/// is a promise the reader can hold.
NaveTextResult searchLineText(
  Map<int, List<String>> lines,
  String query, {
  int limit = 200,
}) {
  final q = query.trim().toUpperCase();
  if (q.isEmpty) return const NaveTextResult(hits: [], total: 0);
  final ids = lines.keys.toList()..sort();
  final hits = <NaveTextHit>[];
  var total = 0;
  for (final id in ids) {
    final texts = lines[id]!;
    for (var i = 0; i < texts.length; i++) {
      if (!texts[i].toUpperCase().contains(q)) continue;
      total++;
      if (hits.length < limit) {
        hits.add(NaveTextHit(topicId: id, lineIndex: i));
      }
    }
  }
  return NaveTextResult(hits: hits, total: total);
}

/// Where each initial letter starts in the headword list, for a jump
/// strip. Anything that does not begin with A–Z is filed under `#`.
///
/// Returns only letters that are actually present: a strip offering a
/// letter with nothing behind it is a promise the list cannot keep.
Map<String, int> letterStarts(List<String> heads) {
  final out = <String, int>{};
  for (var i = 0; i < heads.length; i++) {
    final h = heads[i].toUpperCase();
    final c = h.isEmpty ? '#' : h[0];
    final key = (c.compareTo('A') >= 0 && c.compareTo('Z') <= 0) ? c : '#';
    out.putIfAbsent(key, () => i);
  }
  return out;
}

/// How many lines hang beneath the line at [index] — its whole subtree,
/// not just its immediate children.
int descendantCount(List<int> depths, int index) {
  if (index < 0 || index >= depths.length) return 0;
  final d = depths[index];
  var n = 0;
  for (var i = index + 1; i < depths.length && depths[i] > d; i++) {
    n++;
  }
  return n;
}

/// The line indices the line at [index] hangs beneath, outermost first.
///
/// Mirrors `NaveTopic.ancestorsOf`: any line SHALLOWER than the one
/// being sought closes the subtree, so it is the ancestor even when it
/// skips a level. Matching only on `depth - 1` would step over it and
/// keep walking into the previous branch.
List<int> ancestorIndices(List<int> depths, int index) {
  if (index < 0 || index >= depths.length) return const [];
  final out = <int>[];
  var want = depths[index] - 1;
  for (var i = index - 1; i >= 0 && want > 0; i--) {
    if (depths[i] <= want) {
      out.insert(0, i);
      want = depths[i] - 1;
    }
  }
  return out;
}

/// One rendered row of a topic outline.
class NaveOutlineRow {
  const NaveOutlineRow({
    required this.lineIndex,
    required this.depth,
    required this.hidden,
    required this.expanded,
  });

  final int lineIndex;
  final int depth;

  /// Lines in this row's subtree that the outline is not showing. Zero
  /// when the row is a leaf or is expanded.
  final int hidden;

  final bool expanded;

  bool get hasChildren => hidden > 0 || expanded;
}

/// The visible rows of a topic, given which lines the reader opened.
///
/// Top-level lines are always shown; a deeper line is shown only when
/// every line it hangs beneath is in [expanded]. That single rule turns
/// JESUS, THE CHRIST's 801 lines into 87 rows and leaves a two-line
/// topic exactly as Nave wrote it.
List<NaveOutlineRow> outlineRows(List<int> depths, Set<int> expanded) {
  final rows = <NaveOutlineRow>[];
  // The depth of the collapsed row currently swallowing its subtree.
  var suppressBelow = -1;
  for (var i = 0; i < depths.length; i++) {
    final d = depths[i];
    if (suppressBelow >= 0) {
      if (d > suppressBelow) continue;
      suppressBelow = -1;
    }
    final open = expanded.contains(i);
    var children = 0;
    for (var j = i + 1; j < depths.length && depths[j] > d; j++) {
      children++;
    }
    rows.add(NaveOutlineRow(
      lineIndex: i,
      depth: d,
      hidden: open ? 0 : children,
      expanded: open && children > 0,
    ));
    if (children > 0 && !open) suppressBelow = d;
  }
  return rows;
}

/// Everything on the path to [lineIndex], so opening a topic at a line
/// found by search shows that line rather than the reader's having to
/// hunt for it.
Set<int> expandedForLine(List<int> depths, int lineIndex) =>
    ancestorIndices(depths, lineIndex).toSet();
