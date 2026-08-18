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
/// * Two references ship with an empty string, which renders as a blank
///   line and reads as a layout bug rather than as information. They are
///   cuvs-plus 馬可福音 9:44 and 9:46, emptied in v1.6.98: the edition
///   was storing the second half of 9:43 and 9:45 there, so 和简+ alone
///   answered a verse the critical text omits with scripture. Its two
///   siblings print an editorial note in those slots, but that note is
///   *their* wording in *their* house style, so it was not copied
///   across.
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

  /// The reference is absent, and the critical text has no words there.
  ///
  /// Also inferred rather than read off a string, and from a table this
  /// repository derived for an unrelated purpose: `assets/versification
  /// .json`'s `absent` set is the reader keys with no counterpart in any
  /// original-language file, aligned in v1.6.90 from three independent
  /// tagged translations and knowing nothing about which editions carry
  /// what. Seventeen references are in it.
  ///
  /// Four editions' absences land on that set and on almost nothing
  /// else — BSB 16 of 16, NASB 13 of 13, LEB 16 of 21, both 梁家鏗譯本
  /// 11 of the 13 their publisher's own range labels do not explain
  /// (docs/DATA-INTEGRITY.md check 30). Four editions agreeing about
  /// which references the critical text lacks is why the row can say
  /// *why* it is empty rather than only that it is — and why the KJV
  /// column beside it, which does have the verse, stops looking like
  /// the one that is right.
  ///
  /// The claim is about the CRITICAL TEXT, not about the publisher's
  /// intent: the table proves the original has no words here, and
  /// cannot prove this edition left the verse out deliberately rather
  /// than losing it. [omitted] makes that stronger claim and is used
  /// only where the edition says so in its own words.
  notInCriticalText,

  /// The reference is not in the edition's file at all.
  ///
  /// Unlike the four above this is not read off a stored string — there
  /// is no record to read. It is inferred by the caller from the shape of
  /// the chapter: the edition carries this chapter and does not carry
  /// this verse of it. 426 canonical references across six editions are
  /// in this state, and every one of them sits inside a chapter the
  /// edition otherwise has, so the inference never fires on an edition
  /// that simply stops (a NT-only edition is not "missing" Genesis).
  ///
  /// The note deliberately makes the *weakest true claim* — that our
  /// file has no verse here — rather than [omitted]'s claim about the
  /// edition's base text. Most of them are the base text: 301 of the
  /// Septuagint's 303 Old-Testament absences were confirmed against an
  /// independent LXX witness (docs/DATA-INTEGRITY.md check 29). But
  /// "confirmed for most" is not "true for this one", and the two that
  /// were *not* the base text were our own defect. So the row says what
  /// it can prove and stops.
  absent,
}

/// The exact strings an edition uses in place of verse text.
///
/// Matched whole, after trimming and after unwrapping a lone `<note:
/// …>`, and never as a substring: a rule that fired on "上节" *inside* a
/// verse would silently blank real scripture, and the corpus contains
/// verses like 除酵节，又名逾越节，近了。 that a loose rule would eat.
///
/// Measured over all 11 shipped edition assets (295,532 records),
/// exactly 234 match — 210 + 3 merged, 3 mergedNext, 16 omitted, 2
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

/// Maps each reference an edition prints inside a RANGE to the verse
/// number that range is filed under, read from the publisher's own
/// label.
///
/// [chapterLabels] is one edition's `verseLabel` per verse number. A
/// label of `1-4` on the record numbered 1 says the publisher printed
/// Luke 1:1-4 as one block, so 1:2, 1:3 and 1:4 have no record of their
/// own and are not lost — they are on the page, under a number the
/// reader can see. 42 of the 72 references the two 梁家鏗譯本 editions
/// do not carry are this, which is the single largest class among them
/// and the only one where the *edition itself* supplies the evidence.
///
/// Derived at read time rather than tabulated, because the label is
/// already in the asset and a table would be a second copy of it. The
/// caller intersects the result with the references actually absent,
/// which is what keeps the two labels that name a verse *also* holding
/// its own row — 以弗所書 2:20 marked `20-21` and 3:10 marked `10-11`,
/// both frozen in `test/biblexg_verse_boundary_test.dart` — from
/// hiding scripture behind a note.
Map<int, int> rangeLabelHeads(Map<int, String> chapterLabels) {
  final out = <int, int>{};
  for (final entry in chapterLabels.entries) {
    final match = RegExp(r'^(\d+)\s*-\s*(\d+)$').firstMatch(entry.value.trim());
    if (match == null) continue;
    final from = int.parse(match.group(1)!);
    final to = int.parse(match.group(2)!);
    if (to <= from) continue;
    for (var n = from; n <= to; n++) {
      if (n != entry.key) out[n] = entry.key;
    }
  }
  return out;
}

/// Maps each absent reference to the earlier reference holding its
/// words, where the ORIGINAL text numbers the two as one verse.
///
/// The third of the four ways an absence gets explained, the last that
/// is a rule rather than a list, and the one that catches the cases a
/// reader is most likely to misread.
/// The critical text prints 2 Corinthians 13 in thirteen verses, joining
/// what the English tradition numbers 12 and 13; three editions follow
/// it, so their 13:12 holds both and they have no 13:13 at all. Beside a
/// KJV column reading "All the saints salute you" that looked like a
/// column that had lost a verse.
///
/// [originalKeysOf] is `Versification.originalKeys` for this book and
/// chapter — a table this repository derived in v1.6.90 by aligning
/// Strong's streams, for an unrelated purpose, knowing nothing about
/// which edition carries what. Two reader verses whose words come from
/// the same original verse are one verse in the original; if the edition
/// carries the earlier one and not the later, the later's words are in
/// that record.
///
/// Only the nearest preceding reference the edition actually carries is
/// considered, and only a genuine overlap counts. An unmapped verse
/// resolves to itself, so two unmapped references can never appear to
/// share — the claim is only ever made where the table says something.
///
/// Callers must rule out [VerseAbsence.notInCriticalText] first: a verse
/// the original has no words for is unmapped, resolves to itself, and is
/// a different fact.
Map<int, int> sharedOriginalHeads(
  Set<int> absent,
  Set<int> present,
  List<String> Function(int verse) originalKeysOf,
) {
  final out = <int, int>{};
  for (final n in absent) {
    for (var p = n - 1; p >= 1; p--) {
      if (!present.contains(p)) continue;
      final mine = originalKeysOf(n).toSet();
      if (mine.intersection(originalKeysOf(p).toSet()).isNotEmpty) {
        out[n] = p;
      }
      break;
    }
  }
  return out;
}

/// Reader references an edition prints inside an EARLIER record of its
/// own, named one at a time because nothing in the data can derive them.
///
/// The fourth way an absence gets explained, and the only one that is a
/// list rather than a rule. The other three read evidence the assets
/// already carry — a publisher's range label, `versification.json`'s
/// `absent` set, the same table's `map` read for overlap. None of them
/// reaches the Septuagint, because it is numbered in its **own** frame:
/// `versification.json` aligns reader keys to the *original's* verses,
/// and the Greek's chapter-and-verse is a third thing again.
///
/// What is left is content. English Exodus 40:31's words are in our
/// Greek Exodus 40:30 and no numbering anywhere says so — only reading
/// the two does. `docs/DATA-INTEGRITY.md` check 39 narrowed 302
/// absences to 55 candidates with two independent length instruments
/// and the edition's own `<vs:>` markers, read all 55 against the KJV,
/// and found these seven. Seven entries is a table; a rule that found
/// them would be a rule that guessed.
///
/// The bar is the **whole** English verse, not a clause of it. Eight
/// more absences have part of their verse in the preceding record —
/// Exodus 28:24, 28:25, 37:14, 37:22, 38:7, 39:35, Joshua 20:6 and
/// 1 Kings 9:19 — and are deliberately left out. "Printed with verse
/// 34" would send a reader to a record holding the ark and its staves
/// and not the mercy seat, which is a promise the row cannot keep.
const Map<String, String> kEditionMergedHeads = {
  'lxxwh|Exodus|38:5': '38:4',
  'lxxwh|Exodus|40:31': '40:30',
  'lxxwh|Exodus|40:32': '40:30',
  'lxxwh|1 Kings|4:28': '4:27',
  'lxxwh|1 Kings|9:21': '9:20',
  'lxxwh|Psalms|13:6': '13:5',
  'lxxwh|Isaiah|64:1': '63:19',
};

String? _editionMergedHeadRef(
        String version, String englishBook, int chapter, int verse) =>
    kEditionMergedHeads['$version|$englishBook|$chapter:$verse'];

/// Whether this edition prints this reference under an earlier one.
bool isEditionMerged(
        String version, String englishBook, int chapter, int verse) =>
    _editionMergedHeadRef(version, englishBook, chapter, verse) != null;

/// The head's verse number when the head is in the SAME chapter, and
/// null when it is not.
///
/// Isaiah 64:1 is the one entry whose head is in the chapter before it:
/// the Greek numbers English 64:2 as its own 64:1, so English 64:1 is
/// the tail of Greek 63:19, and the edition's marker on 64:2 says so
/// out loud. Returning null there is deliberate — the caller's sentence
/// names a verse of the chapter on screen, and a bare "19" beside a
/// 64:1 row would read as *this* chapter's 19. [verseAbsenceNote]
/// already has the vaguer wording for exactly this case.
int? editionMergedHeadVerse(
    String version, String englishBook, int chapter, int verse) {
  final ref = _editionMergedHeadRef(version, englishBook, chapter, verse);
  if (ref == null) return null;
  final parts = ref.split(':');
  if (int.parse(parts[0]) != chapter) return null;
  return int.parse(parts[1]);
}

/// The verse numbers an edition does not carry, in a chapter it does.
///
/// [chapterTexts] is one edition's verses for the chapter; [lastVerse] is
/// the chapter's extent across every edition currently on screen, which
/// is what makes the gap visible at all — a verse is only known to be
/// missing from one column because another column has it.
///
/// Returns empty when the edition carries none of the chapter. That is a
/// different fact with a different sentence ("this edition does not
/// include this book/chapter", see `missing_chapter_message.dart`), and
/// answering it here would fill Genesis with 1,533 absence rows for every
/// New-Testament-only edition on screen.
///
/// The extent is taken from the editions rather than from a canon table
/// on purpose. Where an edition versifies a chapter longer than the
/// English tradition — 3 John 1:15, where some editions split verse 14 —
/// the shorter edition genuinely has no verse at that reference, and
/// saying so is both true and what BibleWorks prints.
Set<int> absentVerseNumbers(Map<int, String> chapterTexts, int lastVerse) {
  if (chapterTexts.isEmpty) return const {};
  final out = <int>{};
  for (var n = 1; n <= lastVerse; n++) {
    if (!chapterTexts.containsKey(n)) out.add(n);
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
    case VerseAbsence.notInCriticalText:
      return uiStrings['verseNotInCriticalText']?[locale] ??
          'Not in the critical text most modern editions follow';
    case VerseAbsence.blank:
      return uiStrings['verseTextMissing']?[locale] ??
          'This edition has no text here';
    case VerseAbsence.absent:
      return uiStrings['verseNotInEdition']?[locale] ??
          'This edition has no verse here';
  }
}
