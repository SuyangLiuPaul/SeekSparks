/// 2026-08-06 (SeekSparks): Word List Manager — BibleWorks bwh26.
///
/// Every distinct original-language word in a passage, with how often it
/// occurs there. It answers the question a concordance cannot: not
/// "where is this word" but "what IS this passage made of". The hapax
/// legomena at the bottom of a frequency list are usually the
/// interesting part of a chapter.
///
/// Counting is by STRONG'S NUMBER, not by surface form. Hebrew and Greek
/// inflect heavily — ἀγαπάω appears as ἠγάπησεν, ἀγαπᾷ, ἀγαπῶν — and a
/// list keyed on the printed form would report each as its own word and
/// so report nothing. The most frequent surface form is kept alongside,
/// because that is what a reader recognises.
///
/// Pure list work: the service loads, this counts, the widget draws.
library;

import 'package:seeksparks/models/original_word.dart';

/// How a word list is ordered.
enum WordListSort {
  /// Commonest first — the passage's skeleton.
  frequency,

  /// Rarest first. BibleWorks does not offer this and it is the more
  /// useful direction for exegesis: the words used once are where a
  /// passage is doing something unusual.
  rarity,

  /// By Strong's number, which groups Hebrew before Greek and is the
  /// order to use when comparing two lists side by side.
  number,

  /// By the printed form, for looking something up.
  alphabetical,
}

/// One distinct word in the passage.
class WordListEntry {
  const WordListEntry({
    required this.strongs,
    required this.form,
    required this.count,
    this.translit,
  });

  /// e.g. `G25`.
  final String strongs;

  /// The most frequent surface form, e.g. `ἠγάπησεν`. Ties resolve to
  /// whichever came first in the text, so the result is deterministic.
  final String form;

  /// Occurrences within the scope counted.
  final int count;

  final String? translit;

  bool get isHapax => count == 1;
}

/// Count [words] into a word list.
///
/// Words with no Strong's number are skipped: they are punctuation and
/// unmatched fragments, and a "word" with no lexical identity cannot be
/// looked up, which is the only thing this list is for.
List<WordListEntry> buildWordList(
  Iterable<OriginalWord> words, {
  WordListSort sort = WordListSort.frequency,
  int minCount = 1,
}) {
  // strongs → (total, form → count, firstSeen, translit)
  final totals = <String, int>{};
  final forms = <String, Map<String, int>>{};
  final order = <String, int>{};
  final translits = <String, String?>{};

  var i = 0;
  for (final w in words) {
    final key = w.strongs.trim().toUpperCase();
    if (key.isEmpty) continue;
    totals[key] = (totals[key] ?? 0) + 1;
    final byForm = forms.putIfAbsent(key, () => <String, int>{});
    final text = w.text.trim();
    if (text.isNotEmpty) byForm[text] = (byForm[text] ?? 0) + 1;
    order.putIfAbsent(key, () => i);
    translits.putIfAbsent(key, () => w.translit);
    i++;
  }

  final out = <WordListEntry>[];
  for (final e in totals.entries) {
    if (e.value < minCount) continue;
    final byForm = forms[e.key] ?? const <String, int>{};
    var best = '';
    var bestCount = -1;
    for (final f in byForm.entries) {
      if (f.value > bestCount) {
        best = f.key;
        bestCount = f.value;
      }
    }
    out.add(WordListEntry(
      strongs: e.key,
      form: best.isEmpty ? e.key : best,
      count: e.value,
      translit: translits[e.key],
    ));
  }

  sortWordList(out, sort, order);
  return out;
}

/// Numeric part of a Strong's number, for ordering. `G25` sorts before
/// `G100`, which string comparison gets wrong.
int strongsNumericPart(String strongs) {
  final m = RegExp(r'\d+').firstMatch(strongs);
  return m == null ? 0 : int.parse(m.group(0)!);
}

/// Sort in place. [firstSeen] breaks ties by textual order so the list
/// never reshuffles between identical rebuilds.
void sortWordList(
  List<WordListEntry> list,
  WordListSort sort, [
  Map<String, int> firstSeen = const {},
]) {
  int tie(WordListEntry a, WordListEntry b) =>
      (firstSeen[a.strongs] ?? 0).compareTo(firstSeen[b.strongs] ?? 0);

  switch (sort) {
    case WordListSort.frequency:
      list.sort((a, b) {
        final c = b.count.compareTo(a.count);
        return c != 0 ? c : tie(a, b);
      });
    case WordListSort.rarity:
      list.sort((a, b) {
        final c = a.count.compareTo(b.count);
        return c != 0 ? c : tie(a, b);
      });
    case WordListSort.number:
      list.sort((a, b) {
        // Hebrew before Greek, then numerically.
        final la = a.strongs.isEmpty ? '' : a.strongs[0];
        final lb = b.strongs.isEmpty ? '' : b.strongs[0];
        final c = la.compareTo(lb);
        if (c != 0) return c;
        final n =
            strongsNumericPart(a.strongs).compareTo(strongsNumericPart(b.strongs));
        return n != 0 ? n : tie(a, b);
      });
    case WordListSort.alphabetical:
      list.sort((a, b) {
        final c = a.form.compareTo(b.form);
        return c != 0 ? c : tie(a, b);
      });
  }
}

/// Headline numbers for a word list.
///
/// `distinct / total` is the type-token ratio — a rough measure of how
/// varied a passage's vocabulary is, and the one number that makes two
/// word lists comparable when the passages are different lengths.
({int total, int distinct, int hapax}) wordListSummary(
    List<WordListEntry> list) {
  var total = 0;
  var hapax = 0;
  for (final e in list) {
    total += e.count;
    if (e.isHapax) hapax++;
  }
  return (total: total, distinct: list.length, hapax: hapax);
}
