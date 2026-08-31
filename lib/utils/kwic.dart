/// 2026-08-06 (SeekSparks): KWIC — Key Word In Context.
///
/// BibleWorks' KWIC window (help topic bwh31) is the tool that turns a
/// concordance list into an argument. A concordance answers "where does
/// ἀγαπάω occur"; KWIC answers "what does it occur WITH" — every hit
/// printed on one line, all of them aligned on the keyword, so the
/// patterns in the surrounding words become visible down the column.
/// Sorting by the words to the LEFT or the RIGHT is the whole point:
/// it groups the collocations that repeat.
///
/// This became buildable when BSB landed. KWIC needs to know which word
/// in a verse carries the number, not merely that the verse does, and
/// until there was a tagged English translation that was answerable
/// only in Chinese. Everything here works off `TaggedRun`s, so any
/// version in `TaggedTextService.taggedVersions` can drive it.
///
/// Pure string/list work on purpose — the widget does the loading, this
/// does the thinking, and the thinking is what is worth testing.
library;

import 'package:seeksparks/services/tagged_text_service.dart';

/// How the hit list is ordered.
enum KwicSort {
  /// Canonical order — Genesis to Revelation. The default, because it
  /// is the only order in which the list also reads as a narrative.
  reference,

  /// By the context immediately BEFORE the keyword, read right-to-left
  /// from the keyword outward. Groups repeated lead-ins.
  leftContext,

  /// By the context immediately AFTER the keyword. Groups repeated
  /// objects and complements.
  rightContext,
}

/// One aligned line: the keyword, and what sits either side of it.
class KwicLine {
  const KwicLine({
    required this.reference,
    required this.left,
    required this.keyword,
    required this.right,
    required this.hitIndex,
  });

  /// Display reference, e.g. `John 3:16`.
  final String reference;

  /// Text before the keyword, in reading order.
  final String left;

  /// The word carrying the Strong's number, as printed.
  final String keyword;

  /// Text after the keyword, in reading order.
  final String right;

  /// Which occurrence this is within its verse (0-based). A verse can
  /// use the same number twice — "God said … God saw" — and each gets
  /// its own line rather than being collapsed.
  final int hitIndex;

  /// The whole line as plain text, for copying out.
  String get plain => plainWith(reference);

  /// As [plain], but with the reference rendered for the reader —
  /// [reference] itself stays canonical English (see `ConcordanceRef`).
  String plainWith(String reference) =>
      '$reference\t$left\t$keyword\t$right';
}

/// Normalize a run's text for display in a fixed-width context column.
///
/// Runs carry their own trailing spaces (see `import_bsb.py`), which is
/// right for laying words out in a Wrap and wrong for a context string
/// where the words are being joined anyway.
String _clean(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Build the KWIC lines for one verse.
///
/// Returns one line per occurrence of [strongs]. Matching is exact on
/// the primary number only: a word merely *implying* the number (the
/// Hebrew direct-object marker riding on a noun) is context, not a hit,
/// which is the same call BibleWorks makes.
List<KwicLine> kwicLinesForVerse({
  required String reference,
  required List<TaggedRun> runs,
  required String strongs,
  int contextWords = 8,
}) {
  final target = strongs.toUpperCase();
  final out = <KwicLine>[];
  var hit = 0;
  for (var i = 0; i < runs.length; i++) {
    if (runs[i].strongs.toUpperCase() != target) continue;
    final from = (i - contextWords) < 0 ? 0 : i - contextWords;
    final to = (i + 1 + contextWords) > runs.length
        ? runs.length
        : i + 1 + contextWords;
    final left = runs
        .sublist(from, i)
        .map((r) => _clean(r.text))
        .where((t) => t.isNotEmpty)
        .join(' ');
    final right = runs
        .sublist(i + 1, to)
        .map((r) => _clean(r.text))
        .where((t) => t.isNotEmpty)
        .join(' ');
    out.add(KwicLine(
      reference: reference,
      left: left,
      keyword: _clean(runs[i].text),
      right: right,
      hitIndex: hit,
    ));
    hit++;
  }
  return out;
}

/// What the pane actually DREW, against what it fetched.
///
/// The KWIC pane asks the concordance for the verses that carry a number
/// and turns each into zero or more lines. Zero happens two ways: the
/// tagged layer has no such verse at all, or it has the verse and no run
/// whose PRIMARY number is the one under study — an implied number is
/// context, not a hit, by [kwicLinesForVerse]'s own rule. Either way the
/// reference is fetched and never drawn, so a footer reporting the
/// FETCHED count is naming a set the reader cannot see.
///
/// It is not a rounding error. Joining `assets/strongs/concordance.json`
/// against the shipped tagged layers, 4,442 of the 14,040 Strong's
/// numbers lose at least one reference on the BSB and 4,652 do on
/// 和合本雅伟版 — about one lookup in three. G25 is 110 references and
/// the BSB tags it in 108; H430 is 2,246, of which 29 are verses the BSB
/// tagged layer does not carry at all and 199 more carry no primary H430.
///
/// The counts must be taken FROM THE LINES rather than predicted from
/// the assets, because `TaggedTextService` rewrites runs on load —
/// `reuniteGlossRuns` strips a number off the closing half of a
/// bracketed gloss in 193 verses of `cuvs-yhwh` — so the asset and the
/// list do not have to agree.
class KwicTally {
  const KwicTally({
    required this.referencesFetched,
    required this.referencesShown,
    required this.lines,
  });

  /// How many concordance references the pane has consumed so far.
  final int referencesFetched;

  /// How many of those produced at least one line.
  final int referencesShown;

  /// How many lines they produced. A verse may carry the number more
  /// than once, so this is an OCCURRENCE count and is normally larger
  /// than [referencesShown] — G25 draws 141 lines from 108 verses.
  final int lines;

  /// Fetched and never drawn. Only meaningful once every reference has
  /// been loaded; while the list is still streaming, the references not
  /// yet reached are not the same claim as the references that drew
  /// nothing.
  int get referencesDropped => referencesFetched - referencesShown;

  static KwicTally of({
    required int referencesFetched,
    required List<KwicLine> lines,
  }) =>
      KwicTally(
        referencesFetched: referencesFetched,
        referencesShown: lines.map((l) => l.reference).toSet().length,
        lines: lines.length,
      );
}

/// The sort key for [KwicSort.leftContext].
///
/// Reversed word order, so the word ADJACENT to the keyword sorts
/// first. Sorting the left context as ordinary text would order by the
/// word furthest away, which is the one least likely to be related to
/// the keyword — the resulting list looks sorted and groups nothing.
String leftSortKey(String left) {
  final words = left.toLowerCase().split(' ').where((w) => w.isNotEmpty);
  return words.toList().reversed.join(' ');
}

/// Order [lines] by [sort], leaving the input untouched.
///
/// Every comparison falls back to the original index, so the result is
/// stable: two hits sharing a context keep canonical order relative to
/// each other instead of shuffling between rebuilds.
List<KwicLine> sortKwic(List<KwicLine> lines, KwicSort sort) {
  final indexed = [
    for (var i = 0; i < lines.length; i++) (i, lines[i]),
  ];
  int byKey(String a, String b, int ia, int ib) {
    final c = a.compareTo(b);
    return c != 0 ? c : ia.compareTo(ib);
  }

  switch (sort) {
    case KwicSort.reference:
      return lines.toList();
    case KwicSort.leftContext:
      indexed.sort((a, b) => byKey(
          leftSortKey(a.$2.left), leftSortKey(b.$2.left), a.$1, b.$1));
    case KwicSort.rightContext:
      indexed.sort((a, b) => byKey(a.$2.right.toLowerCase(),
          b.$2.right.toLowerCase(), a.$1, b.$1));
  }
  return [for (final e in indexed) e.$2];
}

/// The words that most often sit next to the keyword.
///
/// This is the payoff of sorting made explicit — BibleWorks leaves the
/// collocations for the eye to spot down the column, which works on a
/// 27-inch monitor and not on a tablet. Counting them costs nothing
/// once the lines exist.
///
/// Returns descending by count, ties broken alphabetically so the order
/// does not wobble between runs.
List<({String word, int count})> kwicCollocates(
  List<KwicLine> lines, {
  int limit = 8,
  int minCount = 2,
}) {
  final counts = <String, int>{};
  for (final l in lines) {
    final words = <String>[
      ...l.left.split(' '),
      ...l.right.split(' '),
    ];
    for (final raw in words) {
      // Punctuation is not a collocate; neither is the empty string a
      // split leaves behind.
      final w = raw.toLowerCase().replaceAll(RegExp(r'''[^\w一-鿿']'''), '');
      if (w.isEmpty) continue;
      counts[w] = (counts[w] ?? 0) + 1;
    }
  }
  final out = [
    for (final e in counts.entries)
      if (e.value >= minCount) (word: e.key, count: e.value),
  ]..sort((a, b) {
      final c = b.count.compareTo(a.count);
      return c != 0 ? c : a.word.compareTo(b.word);
    });
  return out.length <= limit ? out : out.sublist(0, limit);
}
