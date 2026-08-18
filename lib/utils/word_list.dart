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
import 'package:seeksparks/models/strongs.dart';

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
    this.lemma,
    this.lemmaTranslit,
  });

  /// e.g. `G25`.
  final String strongs;

  /// The most frequent surface form, e.g. `ἠγάπησεν`. Ties resolve to
  /// whichever came first in the text, so the result is deterministic.
  final String form;

  /// Occurrences within the scope counted.
  final int count;

  /// The lexicon headword this row counts, e.g. `ἀγαπάω`. Null for the
  /// 76 extended MorphGNT numbers (G6000+) that have no Strong's entry.
  final String? lemma;

  /// The LEMMA's transliteration, from the lexicon.
  ///
  /// Never an occurrence's own transliteration. The row is a lemma, so
  /// a romanisation printed on it must describe the lemma: until
  /// v1.6.88 this carried the first occurrence's, which for G2064 in
  /// John meant the row read `ἔρχεται … ēlthen` — a form and the
  /// romanisation of a different form. That was wrong on 8,030 of the
  /// corpus's 58,447 rows, and merely *unverifiable* on the rest.
  final String? lemmaTranslit;

  bool get isHapax => count == 1;
}

/// Count [words] into a word list.
///
/// Words with no Strong's number are skipped: they are punctuation and
/// unmatched fragments, and a "word" with no lexical identity cannot be
/// looked up, which is the only thing this list is for.
///
/// [lexicon] supplies the lemma and its transliteration per Strong's
/// number — see [WordListEntry.lemmaTranslit] for why they cannot be
/// taken from the occurrences. Pass an empty map and the rows carry
/// their counts and forms only; nothing is invented to fill the gap.
List<WordListEntry> buildWordList(
  Iterable<OriginalWord> words, {
  WordListSort sort = WordListSort.frequency,
  int minCount = 1,
  Map<String, StrongsEntry> lexicon = const {},
}) {
  // strongs → (total, form → count, firstSeen)
  final totals = <String, int>{};
  final forms = <String, Map<String, int>>{};
  final order = <String, int>{};
  // Forms met at least once as something other than a Ketiv, per
  // Strong's number. See the tie-break below.
  final read = <String, Set<String>>{};

  var i = 0;
  for (final w in words) {
    final key = w.strongs.trim().toUpperCase();
    if (key.isEmpty) continue;
    totals[key] = (totals[key] ?? 0) + 1;
    final byForm = forms.putIfAbsent(key, () => <String, int>{});
    final text = w.text.trim();
    if (text.isNotEmpty) {
      byForm[text] = (byForm[text] ?? 0) + 1;
      if (!w.isKetiv) {
        read.putIfAbsent(key, () => <String>{}).add(text);
      }
    }
    order.putIfAbsent(key, () => i);
    i++;
  }

  final out = <WordListEntry>[];
  for (final e in totals.entries) {
    if (e.value < minCount) continue;
    final byForm = forms[e.key] ?? const <String, int>{};
    final readForms = read[e.key] ?? const <String>{};
    var best = '';
    var bestCount = -1;
    var bestIsKetiv = false;
    for (final f in byForm.entries) {
      final isKetiv = !readForms.contains(f.key);
      // Count wins; a tie goes to the form the Masoretes direct be read.
      // Where a number's only occurrences in scope are one Ketiv and its
      // Qere — 360 rows at book scope, 747 at chapter scope — both forms
      // count 1, and the old `>` handed the headline to whichever came
      // first in the verse. That is always the Ketiv, so the row was
      // labelled with the unpointed consonantal form the reader is
      // directed NOT to read: 1 Chronicles 1:11 headed H3866 `לודיים`
      // rather than `לוּדִ֧ים`. Arbitrary before, principled now; nothing
      // is dropped and both still count toward [count].
      if (f.value > bestCount ||
          (f.value == bestCount && bestIsKetiv && !isKetiv)) {
        best = f.key;
        bestCount = f.value;
        bestIsKetiv = isKetiv;
      }
    }
    final lex = lexicon[e.key];
    out.add(WordListEntry(
      strongs: e.key,
      form: best.isEmpty ? e.key : best,
      count: e.value,
      lemma: (lex?.lemma.isNotEmpty ?? false) ? lex!.lemma : null,
      lemmaTranslit: (lex?.translit.isNotEmpty ?? false) ? lex!.translit : null,
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
