/// 2026-08-06 (SeekSparks): mark the search hits in the text itself.
///
/// SeekSparks could already list the verses a search matched, but the
/// text pane gave no clue WHICH word matched. In BibleWorks the hits are
/// highlighted where they occur, and that is what closes the loop: you
/// search, you glance at the verse, and you see the word without reading
/// the line looking for it. Without it a hit list is a table of
/// contents, not a result.
///
/// Two query shapes, two ways of matching:
///
///   * Strong's (`G25`, `G25 AND G26`, `G25*`) matches the NUMBER on a
///     tagged run. Exact, no guessing — the tagging already says which
///     word carries it.
///   * Plain text matches substrings, case-insensitively.
///
/// A NOT term is deliberately not highlighted: `G25 NOT G26` returns
/// verses that lack G26, so there is nothing there to mark. Highlighting
/// the excluded number would point at the reason a verse was filtered
/// OUT, in a list of verses that were kept in.
///
/// Pure matching. The widget decides what a highlight looks like.
library;

import 'package:seeksparks/utils/strongs_boolean_search.dart';

/// What an active query marks.
class SearchHighlight {
  const SearchHighlight({
    this.strongsNumbers = const {},
    this.strongsPrefixes = const {},
    this.textTerms = const [],
  });

  /// Exact numbers, upper-case: {'G25'}.
  final Set<String> strongsNumbers;

  /// Wildcard stems, upper-case: {'G25'} from `G25*`, which matches
  /// G25, G250, G2501 …
  final Set<String> strongsPrefixes;

  /// Lower-cased substrings for a plain-text query.
  final List<String> textTerms;

  bool get isEmpty =>
      strongsNumbers.isEmpty && strongsPrefixes.isEmpty && textTerms.isEmpty;

  /// Whether a tagged run carrying [strongs] is a hit.
  bool matchesStrongs(String strongs) {
    if (strongs.isEmpty) return false;
    final s = strongs.toUpperCase();
    if (strongsNumbers.contains(s)) return true;
    for (final p in strongsPrefixes) {
      if (s.startsWith(p)) return true;
    }
    return false;
  }
}

/// Work out what an active query should mark.
///
/// Returns an empty highlight for an empty or unparseable query rather
/// than guessing — marking the wrong words is worse than marking none.
SearchHighlight highlightsForQuery(String rawQuery) {
  final q = rawQuery.trim();
  if (q.isEmpty) return const SearchHighlight();

  final parsed = parseStrongsBoolean(q);
  if (parsed != null) {
    final numbers = <String>{};
    final prefixes = <String>{};
    for (var i = 0; i < parsed.terms.length; i++) {
      // Skip a term that is the right-hand side of a NOT: it describes
      // what the verse must LACK.
      final excluded = i > 0 &&
          i - 1 < parsed.ops.length &&
          parsed.ops[i - 1] == StrongsOp.not;
      if (excluded) continue;
      final t = parsed.terms[i];
      if (t.wildcard) {
        prefixes.add('${t.prefix}${t.digits}'.toUpperCase());
      } else {
        numbers.add(t.number.toUpperCase());
      }
    }
    return SearchHighlight(
        strongsNumbers: numbers, strongsPrefixes: prefixes);
  }

  // A bare Strong's number is not "boolean" but still a number query.
  if (RegExp(r'^[GgHh]\d{1,4}$').hasMatch(q)) {
    return SearchHighlight(strongsNumbers: {q.toUpperCase()});
  }

  // Plain text. Split on whitespace so "let there be" marks each word —
  // the verse may not contain the exact phrase, and marking nothing when
  // the phrase does not appear verbatim is the unhelpful answer.
  final terms = q
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();
  return SearchHighlight(textTerms: terms);
}

/// One piece of a line, and whether it is a hit.
class HighlightSpan {
  const HighlightSpan(this.text, this.isHit);
  final String text;
  final bool isHit;

  @override
  bool operator ==(Object other) =>
      other is HighlightSpan && other.text == text && other.isHit == isHit;

  @override
  int get hashCode => Object.hash(text, isHit);

  @override
  String toString() => isHit ? '[$text]' : text;
}

/// Split [text] on every occurrence of any of [terms].
///
/// Case-insensitive, and overlapping/adjacent matches are merged so a
/// query like "the there" does not produce a shredded line of
/// alternating spans.
List<HighlightSpan> splitOnTerms(String text, List<String> terms) {
  if (text.isEmpty || terms.isEmpty) {
    return text.isEmpty ? const [] : [HighlightSpan(text, false)];
  }
  final lower = text.toLowerCase();

  // Collect every match range, then merge.
  final ranges = <(int, int)>[];
  for (final t in terms) {
    if (t.isEmpty) continue;
    var from = 0;
    while (true) {
      final i = lower.indexOf(t, from);
      if (i < 0) break;
      ranges.add((i, i + t.length));
      from = i + 1; // +1, not +t.length: catches overlapping matches
    }
  }
  if (ranges.isEmpty) return [HighlightSpan(text, false)];
  ranges.sort((a, b) => a.$1.compareTo(b.$1));

  final merged = <(int, int)>[];
  for (final r in ranges) {
    if (merged.isNotEmpty && r.$1 <= merged.last.$2) {
      final last = merged.removeLast();
      merged.add((last.$1, r.$2 > last.$2 ? r.$2 : last.$2));
    } else {
      merged.add(r);
    }
  }

  final out = <HighlightSpan>[];
  var cursor = 0;
  for (final (start, end) in merged) {
    if (start > cursor) {
      out.add(HighlightSpan(text.substring(cursor, start), false));
    }
    out.add(HighlightSpan(text.substring(start, end), true));
    cursor = end;
  }
  if (cursor < text.length) {
    out.add(HighlightSpan(text.substring(cursor), false));
  }
  return out;
}
