import 'package:seeksparks/constants/ui_strings.dart';

/// Why a reference exists in an edition but carries no scripture of its
/// own.
///
/// Four shipped editions store a *typographic instruction* where the
/// verse text would be, and until v1.6.93 the app rendered all of them
/// in scripture type:
///
/// * The 和合本 merges some adjacent verses under one combined number
///   ("6-8") and prints 見上節 — "see the verse above" — in the
///   verse-number column of every reference after the first. Our data
///   models one text per reference, so those three characters became
///   the verse's `text`. A reader on 詩篇 8:8 was shown a sentence that
///   is not scripture, could copy it into a sermon, and could match it
///   in a text search. 70 references × 3 editions = 210.
/// * 詩篇 63:6 says so in words — 合和譯本並入上一節, "the Union Version
///   folds this into the previous verse" — and 約翰福音 7:53 points the
///   other way, 見下節, because the pericope it opens is printed from
///   8:1. Both ship wrapped in `<note: …>` in two of the three editions
///   and bare in the third, so the reader saw either a bare footnote
///   marker on an empty line or the instruction itself as scripture,
///   depending on which 和合本 they had open.
/// * `assets/lxxwh.json` stores the literal string `OMIT` for the
///   sixteen Received-Text verses the critical text does not contain.
///   Same shape, worse consequence: it is the Greek column, the one a
///   reader cannot check against anything except us. That those sixteen
///   are exactly the set `Versification` derived independently in
///   v1.6.90 (from KJV-vs-BSB disagreement, knowing nothing about this
///   file) is two unrelated sources agreeing.
/// * One reference ships with an empty string, which renders as a blank
///   line and reads as a layout bug rather than as information.
///
/// The instruction is kept in the assets rather than deleted — it is
/// what the printed page says, and the honest presentation is to
/// *explain* the edition's convention, not to hide it.
enum VerseAbsence {
  /// Printed with an earlier verse under a combined number.
  merged,

  /// Printed with the verse that follows — 約翰福音 7:53, whose words
  /// open a pericope the edition sets from 8:1. Deliberately separate
  /// from [merged]: the head is in the *next chapter*, so it cannot be
  /// resolved from this chapter and must not be guessed at.
  mergedNext,

  /// The edition's own base text does not contain this verse.
  omitted,

  /// The reference is in the file with no text at all.
  blank,
}

/// The exact strings an edition uses in place of verse text.
///
/// Matched whole, after trimming and after unwrapping a lone `<note:
/// …>`, and never as a substring: a rule that fired on "上节" *inside* a
/// verse would silently blank real scripture, and the corpus contains
/// verses like 除酵节，又名逾越节，近了。 that a loose rule would eat.
///
/// Measured over all 11 shipped edition assets (295,527 records),
/// exactly 233 match — 210 + 3 merged, 3 mergedNext, 16 omitted, 1
/// blank — and every one is a placeholder. See `docs/DATA-INTEGRITY.md`
/// check 14.
const Map<String, VerseAbsence> kVerseAbsenceMarkers = {
  '见上节': VerseAbsence.merged,
  '見上節': VerseAbsence.merged,
  '合和译本并入上一节': VerseAbsence.merged,
  '合和譯本並入上一節': VerseAbsence.merged,
  '见下节': VerseAbsence.mergedNext,
  '見下節': VerseAbsence.mergedNext,
  'OMIT': VerseAbsence.omitted,
};

/// Longest marker (`合和譯本並入上一節` inside a `<note: …>`), plus slack.
/// Checked before the trim because this runs once per verse for every
/// whole-corpus scan — 31k verses per search-key rebuild.
const int _kMaxMarkerLength = 24;

/// Classifies a verse's stored text, or null when it is scripture.
///
/// A note-wrapped marker counts, but only when the note is the *whole*
/// verse. Two of the three 和合本 editions also store real scripture
/// that way (約書亞記 2:6 and fourteen others the Union Version prints
/// as footnotes) — those are left alone here on purpose: they have
/// words, and hiding them behind this sentence would be the same defect
/// pointed the other way.
VerseAbsence? verseAbsenceOf(String text) {
  if (text.length > _kMaxMarkerLength) return null;
  final t = text.trim();
  if (t.isEmpty) return VerseAbsence.blank;
  final direct = kVerseAbsenceMarkers[t];
  if (direct != null) return direct;
  if (t.startsWith('<note:') && t.endsWith('>')) {
    return kVerseAbsenceMarkers[t.substring(6, t.length - 1).trim()];
  }
  return null;
}

/// Maps each backward-merged reference in one chapter to the verse
/// number whose text it is printed under.
///
/// Walks forward in verse order tracking the last reference that
/// carried scripture, because the merge **chains**: 詩篇 8:7 and 8:8 are
/// both marked, and 8:7's "verse above" is itself a marker, so a
/// resolver that simply looked at `verse - 1` would send a reader from
/// one placeholder to another. Only a text-bearing verse can be a head —
/// an omitted or blank reference cannot hold another verse's words.
///
/// [VerseAbsence.mergedNext] is never mapped: its head is the verse
/// *after* it, which in the one shipped case lives in the next chapter.
///
/// A marker with nothing before it is left unmapped rather than guessed
/// at; the caller then says "printed with an earlier verse" without
/// naming one. The shipped corpus contains no such case and an audit
/// check asserts it, but a wrong verse number is worse than a vaguer
/// sentence.
Map<int, int> mergedVerseHeads(Map<int, String> chapterTexts) {
  final numbers = chapterTexts.keys.toList()..sort();
  final out = <int, int>{};
  int? head;
  for (final n in numbers) {
    final absence = verseAbsenceOf(chapterTexts[n] ?? '');
    if (absence == null) {
      head = n;
    } else if (absence == VerseAbsence.merged && head != null) {
      out[n] = head;
    }
  }
  return out;
}

/// The line shown in place of the verse text, in the reader's UI
/// language.
///
/// Localised to the **UI** locale rather than the edition's script: the
/// sentence is the app speaking, not the edition, and a reader running
/// an English UI over a Chinese text should be told why the row is
/// empty in English.
String verseAbsenceNote(
  VerseAbsence kind,
  String locale, {
  int? mergedWith,
}) {
  switch (kind) {
    case VerseAbsence.merged:
      if (mergedWith == null) {
        return uiStrings['verseMergedWithEarlier']?[locale] ??
            'Printed with an earlier verse';
      }
      final template = uiStrings['verseMergedWith']?[locale] ??
          'Printed with verse {v}';
      return template.replaceAll('{v}', '$mergedWith');
    case VerseAbsence.mergedNext:
      return uiStrings['verseMergedWithNext']?[locale] ??
          'Printed with the verse that follows';
    case VerseAbsence.omitted:
      return uiStrings['verseOmittedFromBaseText']?[locale] ??
          "Not in this edition's base text";
    case VerseAbsence.blank:
      return uiStrings['verseTextMissing']?[locale] ??
          'This edition has no text here';
  }
}
