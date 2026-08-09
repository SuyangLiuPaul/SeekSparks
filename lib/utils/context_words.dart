/// 2026-08-07 (SeekSparks): the Context tab's word lists — BibleWorks
/// `bwh10h`, plus the measure BibleWorks leaves to the eye.
///
/// BibleWorks shows three frequency lists side by side (pericope,
/// chapter, book) and tells the reader that "noticing the repeating
/// words helps you to identify likely themes". That is the right goal
/// and the wrong instrument. Raw frequency does not find a theme, it
/// finds the language: every list in every passage of both testaments
/// opens with the article, the conjunction and the copula. A published
/// review of the tab says exactly this — you have to "scroll past
/// insignificant high frequency words".
///
/// Two things fix it, and both are here:
///
///   1. **Filter by part of speech** (see `word_pos.dart`). Content
///      words only, by default.
///   2. **Measure over-representation, not frequency.** A word is
///      distinctive of this pericope if it occurs here at a higher rate
///      than in the rest of the book. That is the log-likelihood ratio
///      G², the standard keyness statistic in corpus linguistics.
///
/// **The baseline is the containing book, deliberately — not the whole
/// Bible.** Authorial vocabulary varies so much between books that
/// measuring John 1 against Leviticus mostly rediscovers that John wrote
/// John. "What marks this paragraph off within this book" is both the
/// better exegetical question and the one we can answer from data
/// already in memory, since the book is loaded anyway.
///
/// The reference is the book **minus** the scope. Leaving the scope
/// inside its own baseline would let a word that occurs only here
/// inflate its own expected value, which flattens exactly the signal
/// the statistic exists to find. For the book scope there is no
/// reference left, so keyness is null and the pane says so rather than
/// printing a number that means nothing.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:seeksparks/models/original_word.dart';
import 'package:seeksparks/utils/word_pos.dart';

/// Which nested scope the list covers. BibleWorks' three sub-windows,
/// as one list with a chooser — three scrolling lists do not fit a
/// 320 px pane, and the reader compares them one at a time anyway.
enum ContextScope { pericope, chapter, book }

enum ContextSort {
  /// Commonest first. BibleWorks' only order.
  frequency,

  /// Rarest first — where a passage does something unusual.
  rarity,

  /// Most over-represented here versus the rest of the book.
  distinctive,
}

/// One lemma in the scope.
@immutable
class ContextWordEntry {
  const ContextWordEntry({
    required this.strongs,
    required this.form,
    required this.pos,
    required this.count,
    required this.bookCount,
    this.keyness,
  });

  /// `G3056`. Counting is by Strong's number, never by printed form:
  /// λόγος appears as λόγον, λόγῳ, λόγου, and a list keyed on the form
  /// would report each separately and so report nothing.
  final String strongs;

  /// The commonest surface form within the scope — what the reader
  /// recognises on the page.
  final String form;

  final WordPos pos;

  /// Occurrences within the scope.
  final int count;

  /// Occurrences in the whole book, so a reader can see at a glance
  /// whether a word is local or the book's habit.
  final int bookCount;

  /// Signed log-likelihood G². Positive = denser here than in the rest
  /// of the book, negative = thinner, null = no reference corpus (the
  /// scope IS the book, or the book is a single chapter).
  final double? keyness;

  bool get isHapax => count == 1;

  /// Occurs here and nowhere else in the book — the strongest form of
  /// local, and worth its own marker.
  bool get isExclusive => count == bookCount;
}

/// A finished list plus the headline numbers BibleWorks prints in the
/// title bar of each sub-window: how many verses, how many words.
@immutable
class ContextWordList {
  const ContextWordList({
    required this.entries,
    required this.scopeTokens,
    required this.scopeDistinct,
    required this.bookTokens,
    required this.hasBaseline,
  });

  /// Filtered and sorted.
  final List<ContextWordEntry> entries;

  /// Every tagged word in the scope, before the part-of-speech filter.
  /// The filter is a display choice; the corpus size that keyness
  /// divides by must not move when the reader toggles it.
  final int scopeTokens;

  final int scopeDistinct;
  final int bookTokens;

  /// False when the scope is the whole book: nothing left to compare
  /// against, so every [ContextWordEntry.keyness] is null.
  final bool hasBaseline;

  static const empty = ContextWordList(
    entries: [],
    scopeTokens: 0,
    scopeDistinct: 0,
    bookTokens: 0,
    hasBaseline: false,
  );
}

/// Signed log-likelihood ratio G² for one word.
///
/// [a] occurrences in the target of [c] tokens; [b] occurrences in the
/// reference of [d] tokens. Positive when the target rate exceeds the
/// reference rate.
///
/// Null when either corpus is empty or the word occurs in neither —
/// there is no ratio to report, and returning 0 would sort those rows
/// among the genuinely unremarkable ones.
double? logLikelihood({
  required int a,
  required int c,
  required int b,
  required int d,
}) {
  if (c <= 0 || d <= 0) return null;
  final total = a + b;
  if (total <= 0) return null;
  final expectedA = c * total / (c + d);
  final expectedB = d * total / (c + d);
  var g2 = 0.0;
  if (a > 0) g2 += a * math.log(a / expectedA);
  if (b > 0) g2 += b * math.log(b / expectedB);
  g2 *= 2;
  if (g2 < 0) g2 = 0; // floating-point dust around a perfect fit
  return (a / c) >= (b / d) ? g2 : -g2;
}

/// Count [scopeWords] into a Context word list, with [bookWords] as the
/// containing corpus.
///
/// Pass the same iterable for both when the scope IS the book; the
/// result then reports `hasBaseline: false` and null keyness rather
/// than comparing the book to itself.
ContextWordList buildContextWordList({
  required Iterable<OriginalWord> scopeWords,
  required Iterable<OriginalWord> bookWords,
  Set<WordPos> include = kContentPos,
  ContextSort sort = ContextSort.frequency,
}) {
  final scopeCounts = <String, int>{};
  final forms = <String, Map<String, int>>{};
  final firstSeen = <String, int>{};
  final posByKey = <String, WordPos>{};
  var scopeTokens = 0;

  var i = 0;
  for (final w in scopeWords) {
    final key = w.strongs.trim().toUpperCase();
    // A word with no Strong's number has no lexical identity, so there
    // is nothing to count it as and nothing to look it up by.
    if (key.isEmpty) continue;
    scopeTokens++;
    scopeCounts[key] = (scopeCounts[key] ?? 0) + 1;
    final text = w.text.trim();
    if (text.isNotEmpty) {
      final byForm = forms.putIfAbsent(key, () => <String, int>{});
      byForm[text] = (byForm[text] ?? 0) + 1;
    }
    firstSeen.putIfAbsent(key, () => i);
    // The part of speech is a property of the OCCURRENCE, but the row
    // is a lemma. Take the first occurrence's tag: a lemma's tag is
    // stable in practice, and re-deciding it per row would need a vote
    // that changes as the reader scrolls between scopes.
    posByKey.putIfAbsent(key, () => posOf(key, w.morph));
    i++;
  }

  final bookCounts = <String, int>{};
  var bookTokens = 0;
  for (final w in bookWords) {
    final key = w.strongs.trim().toUpperCase();
    if (key.isEmpty) continue;
    bookTokens++;
    bookCounts[key] = (bookCounts[key] ?? 0) + 1;
  }

  final referenceTokens = bookTokens - scopeTokens;
  final hasBaseline = referenceTokens > 0 && scopeTokens > 0;

  final out = <ContextWordEntry>[];
  for (final e in scopeCounts.entries) {
    final pos = posByKey[e.key] ?? WordPos.unknown;
    if (!include.contains(pos)) continue;
    final byForm = forms[e.key] ?? const <String, int>{};
    var best = '';
    var bestCount = -1;
    for (final f in byForm.entries) {
      if (f.value > bestCount) {
        best = f.key;
        bestCount = f.value;
      }
    }
    final bookCount = bookCounts[e.key] ?? e.value;
    out.add(ContextWordEntry(
      strongs: e.key,
      form: best.isEmpty ? e.key : best,
      pos: pos,
      count: e.value,
      bookCount: bookCount,
      keyness: hasBaseline
          ? logLikelihood(
              a: e.value,
              c: scopeTokens,
              b: bookCount - e.value,
              d: referenceTokens,
            )
          : null,
    ));
  }

  sortContextWords(out, sort, firstSeen);
  return ContextWordList(
    entries: out,
    scopeTokens: scopeTokens,
    scopeDistinct: scopeCounts.length,
    bookTokens: bookTokens,
    hasBaseline: hasBaseline,
  );
}

/// Sort in place. [firstSeen] breaks ties by textual order so identical
/// rebuilds never reshuffle the list under the reader's finger.
void sortContextWords(
  List<ContextWordEntry> list,
  ContextSort sort, [
  Map<String, int> firstSeen = const {},
]) {
  int tie(ContextWordEntry a, ContextWordEntry b) =>
      (firstSeen[a.strongs] ?? 0).compareTo(firstSeen[b.strongs] ?? 0);

  switch (sort) {
    case ContextSort.frequency:
      list.sort((a, b) {
        final c = b.count.compareTo(a.count);
        return c != 0 ? c : tie(a, b);
      });
    case ContextSort.rarity:
      list.sort((a, b) {
        final c = a.count.compareTo(b.count);
        return c != 0 ? c : tie(a, b);
      });
    case ContextSort.distinctive:
      list.sort((a, b) {
        // Rows with no keyness sink rather than sorting as zero: "not
        // measurable" is not the same claim as "not distinctive".
        final ka = a.keyness;
        final kb = b.keyness;
        if (ka == null && kb == null) {
          final c = b.count.compareTo(a.count);
          return c != 0 ? c : tie(a, b);
        }
        if (ka == null) return 1;
        if (kb == null) return -1;
        final c = kb.compareTo(ka);
        if (c != 0) return c;
        final f = b.count.compareTo(a.count);
        return f != 0 ? f : tie(a, b);
      });
  }
}
