/// 2026-08-17 (#313): which sermons treat the passage in front of the
/// reader, and — the part that was missing — **which verses each one
/// actually cites**.
///
/// `SermonService.sermonsForVerse` already matched at chapter level for
/// a good reason recorded there: a sermon expounding Genesis 1:1-5 is
/// just as relevant when the reader is on Genesis 1:7. But it returned
/// one flat list, so the reader could not tell a sermon that preaches
/// the verse in front of them from one that merely mentions another
/// verse of the same chapter. **Measured over the whole corpus: of the
/// 9,857 rows that list produces across its 946 verse-level keys, only
/// 1,211 — 12.3% — cite the verse the reader selected.** On Romans 8:1
/// it returns 49 sermons and says nothing about which of them are on
/// 8:1. That is the #308 defect class: a list whose unit is unstated.
///
/// The exactness was not lost, only invisible — the service sorted
/// exact hits first, and sort order is not a label. This file makes it
/// a structure the pane can print.
///
/// Kept pure, and out of the service, so the classification can be
/// tested against a hand-written index without `rootBundle`: everything
/// here is a function of the reverse index and a reference.
library;

/// What one sermon cites inside one chapter.
class SermonCitation {
  const SermonCitation({
    required this.sermonId,
    required this.verses,
    required this.citesFocusedVerse,
    required this.citesWholeChapter,
  });

  final String sermonId;

  /// The verses of the focused chapter this sermon cites, ascending.
  ///
  /// Empty when the sermon names the chapter without naming a verse —
  /// which is [citesWholeChapter], a different claim from "cites no
  /// verse we could find" and printed differently.
  final List<int> verses;

  /// This sermon cites the exact verse the reader has selected.
  final bool citesFocusedVerse;

  /// This sermon cites the chapter as a whole ("Romans 8") somewhere,
  /// with no verse attached.
  final bool citesWholeChapter;
}

/// Every sermon in [byVerse] that cites [englishBook] [chapter],
/// carrying the verses of that chapter it cites.
///
/// [byVerse] is `SermonRefs.byVerse` — canonical `"Book C"` or
/// `"Book C:V"` keys to sermon ids. Both shapes are real and only both
/// exist: 351 chapter-level keys and 946 verse-level ones.
///
/// [verse] is the verse the reader has selected. Pass 0 when there is
/// no focused verse (the chapter-scoped entry point); nothing then
/// reports [SermonCitation.citesFocusedVerse], which is correct rather
/// than merely convenient — no verse was asked about.
///
/// **Ordering is deliberate and is not the old one.** The service
/// iterated the JSON's key order into a `Set`, so the list came out in
/// whatever order the index was written. Here: sermons that cite the
/// focused verse first, then by the earliest verse each cites, then by
/// id. A reader scanning Romans 8 meets the sermons in the order the
/// chapter unfolds, and the same passage always produces the same list.
List<SermonCitation> citationsInChapter({
  required Map<String, List<String>> byVerse,
  required String englishBook,
  required int chapter,
  required int verse,
}) {
  final chapterKey = '$englishBook $chapter';
  // The colon is what keeps Psalm 1 out of Psalm 119: "Psalms 119:3"
  // neither equals "Psalms 1" nor begins with "Psalms 1:".
  final versePrefix = '$chapterKey:';

  final verses = <String, Set<int>>{};
  final wholeChapter = <String>{};

  byVerse.forEach((key, ids) {
    if (key == chapterKey) {
      wholeChapter.addAll(ids);
      for (final id in ids) {
        verses.putIfAbsent(id, () => <int>{});
      }
      return;
    }
    if (!key.startsWith(versePrefix)) return;
    final n = int.tryParse(key.substring(versePrefix.length));
    if (n == null) return;
    for (final id in ids) {
      verses.putIfAbsent(id, () => <int>{}).add(n);
    }
  });

  final out = <SermonCitation>[];
  verses.forEach((id, vs) {
    final sorted = vs.toList()..sort();
    out.add(SermonCitation(
      sermonId: id,
      verses: sorted,
      citesFocusedVerse: verse > 0 && vs.contains(verse),
      citesWholeChapter: wholeChapter.contains(id),
    ));
  });

  out.sort((a, b) {
    if (a.citesFocusedVerse != b.citesFocusedVerse) {
      return a.citesFocusedVerse ? -1 : 1;
    }
    // A chapter-only citation has no verse to sort by; it follows the
    // sermons that named one rather than leading them.
    final av = a.verses.isEmpty ? 1 << 30 : a.verses.first;
    final bv = b.verses.isEmpty ? 1 << 30 : b.verses.first;
    if (av != bv) return av.compareTo(bv);
    return a.sermonId.compareTo(b.sermonId);
  });
  return out;
}

/// The verses a citation names, as a compact `"3, 5, 14"` — or null
/// when it named none, so the caller prints the chapter-level phrase
/// instead of an empty string.
///
/// Consecutive runs are folded (`"1-4"`) because a sermon that walks a
/// paragraph cites it verse by verse and the reader wants the span, not
/// the enumeration. Measured before writing it: the most any sermon
/// cites in one chapter is **4** verses, so this never has to be clever.
String? citedVerseLabel(SermonCitation c) {
  if (c.verses.isEmpty) return null;
  final parts = <String>[];
  var start = c.verses.first;
  var prev = start;
  for (final v in c.verses.skip(1)) {
    if (v == prev + 1) {
      prev = v;
      continue;
    }
    parts.add(start == prev ? '$start' : '$start-$prev');
    start = v;
    prev = v;
  }
  parts.add(start == prev ? '$start' : '$start-$prev');
  return parts.join(', ');
}

/// Which count-line string the pane should ask for.
///
/// English agrees a verb with each of the two numbers in that sentence,
/// so "1 of them cite Romans 8:1" is wrong and shipped in v1.6.135. The
/// combination `total == 1 && onVerse == 0` cannot arise here: the
/// with-verse line is only drawn when a sermon is on the verse, and the
/// total includes it. Chinese does not inflect for number, so its four
/// entries are deliberately identical sentences.
String sermonCountKey({required int total, required int onVerse}) {
  if (onVerse < 1) {
    return total == 1 ? 'sermonsCountChapterOne' : 'sermonsCountChapter';
  }
  if (total == 1) return 'sermonsCountOnlyOne';
  return onVerse == 1 ? 'sermonsCountWithVerseOne' : 'sermonsCountWithVerse';
}
