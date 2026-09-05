/// 2026-09-05: the browsable side of the Modern Concordance — pure logic.
///
/// `ModernConcordanceService.forVerse` answers "which topics file the
/// verse I am on". This answers the other direction — "what does the
/// concordance file under a word I have in my head" — which is the half
/// the app has never had a door for. `ModernConcordanceService.topics()`
/// has existed and returned all 341 topics since `34bef43` (2026-08-07)
/// with no caller anywhere in `lib/`.
///
/// **Nave's rule does not transfer, and the number says why.** The
/// sibling index ranks a whole-headword prefix first
/// (`naves_browse.dart`, `matchHeadwords`), because a Nave headword is
/// one term: LOVE, BROTHERLY LOVE. A Modern Concordance topic name is
/// usually not. **239 of the 341 names are compounds** joined by " - "
/// — `Catch - Seize - Steal`, `Abyss - Hades - Hell`, `Go - Pass` — 675
/// segments in all. Copying Nave's rule verbatim was tried first and
/// answers `seize` with **zero** topics, while the word is sitting in
/// the middle of a name the work does carry. So the prefix tier is
/// per-SEGMENT: a name is a prefix hit when any of its segments starts
/// with the query.
///
/// **Both languages, always, whatever the reader's locale.** All 341
/// topics carry a Chinese gloss (measured: none is empty), and the two
/// columns are not translations of one index but two ways into the same
/// one. `爱` matches 3 topics through the Chinese column and 0 through
/// the English; `seize` matches 1 through the English and 0 through the
/// Chinese. Searching only the reading language would silently halve the
/// work for every reader, so both columns are always searched and the
/// hit records which column answered — the caller needs that to show the
/// name the reader did not type.
///
/// **No letter strip, deliberately.** `naves_page.dart` carries an A–Z
/// jump bar because 5,322 rows cannot be scrolled. This index is 341
/// rows across 24 initial letters; the whole work is about eight flings,
/// and a strip that saves four of them costs a row of chrome on a phone.
///
/// Everything here takes plain records and returns plain indices, so it
/// runs without a bundle. Counts returned are TOTALS and the list is
/// uncapped: the caller prints a count, and a count that was itself
/// truncated is worse than no count.
library;

/// Which column answered the query. The caller shows the other name
/// beside the hit when the match did not come from the reading
/// language — a row that answered `爱` with `Spare` is unreadable
/// without saying that `饶恕` is why.
enum TopicMatch { english, chinese }

/// One matched topic: its position in the list handed in, how it
/// matched, and through which column.
class TopicHit {
  const TopicHit({
    required this.index,
    required this.prefix,
    required this.matched,
  });

  /// Index into the list passed to [matchTopics], not a topic id. The
  /// caller holds the topics and does the lookup, exactly as
  /// `matchHeadwords` returns positions into the head list.
  final int index;

  /// True when a SEGMENT of the name starts with the query. `love`
  /// puts `Love` above `Beloved - Loved`; both are wanted, so neither
  /// is dropped.
  final bool prefix;

  /// The column the match came from. When both columns match, English
  /// is reported — the English name is the one this work is organised
  /// and sorted by.
  final TopicMatch matched;
}

/// The separators a topic name is built from, in both columns.
///
/// ` - ` joins English compounds and most Chinese ones; `，` and `、`
/// appear only in the Chinese column (`上面，在…之上`). Splitting on the
/// bare hyphen would be wrong: `Twenty-four` is one term.
const List<String> _separators = <String>[' - ', '，', '、', '；'];

List<String> _segments(String name) {
  var parts = <String>[name];
  for (final sep in _separators) {
    parts = [
      for (final p in parts)
        for (final piece in p.split(sep)) piece.trim(),
    ];
  }
  return [
    for (final p in parts)
      if (p.isNotEmpty) p,
  ];
}

/// Every topic matching [query], segment-prefix matches first.
///
/// [names] is `(english, chinese)` per topic, in the order the caller
/// will render them. An empty or whitespace query matches nothing —
/// the caller shows the whole list itself rather than asking for it,
/// so that an unfiltered list never pays for a 341-entry scan.
List<TopicHit> matchTopics(List<(String, String)> names, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];

  final prefixes = <TopicHit>[];
  final contains = <TopicHit>[];

  for (var i = 0; i < names.length; i++) {
    final (en, zh) = names[i];
    final enLower = en.toLowerCase();
    final zhLower = zh.toLowerCase();

    // English first in every tier: this work is edited, ordered and
    // numbered on its English names, so when both columns answer, the
    // English one is the answer the list is sorted by.
    final enPrefix = _segments(enLower).any((s) => s.startsWith(q));
    final zhPrefix = _segments(zhLower).any((s) => s.startsWith(q));
    if (enPrefix || zhPrefix) {
      prefixes.add(TopicHit(
        index: i,
        prefix: true,
        matched: enPrefix ? TopicMatch.english : TopicMatch.chinese,
      ));
      continue;
    }

    final enHas = enLower.contains(q);
    final zhHas = zhLower.contains(q);
    if (enHas || zhHas) {
      contains.add(TopicHit(
        index: i,
        prefix: false,
        matched: enHas ? TopicMatch.english : TopicMatch.chinese,
      ));
    }
  }

  return [...prefixes, ...contains];
}
