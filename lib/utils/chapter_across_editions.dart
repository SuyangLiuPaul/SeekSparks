// Find one chapter in an edition that may not name its books the way
// the asking edition does.
//
// EVERY CORPUS STORES BOOK NAMES IN ITS OWN LANGUAGE. Measured on the
// shipped assets: `cuvs-yhwh.json` keys its 31,102 verses on 创世纪 /
// 出埃及记 / 利未记, while `bsb.json` (31,086), `kjv.json` (31,102) and
// `leb.json` (31,199) key theirs on Genesis / Exodus / Leviticus. So a
// raw `v.book == otherProvider.currentBook` across two columns matches
// NOTHING whenever the two columns are in different languages — and two
// columns in different languages is the normal case, since
// `defaultSecondaryVersion` exists precisely to make Split View compare
// something.
//
// This is the same defect class as `MainProvider._realignBookTo` and
// `_realignCursorTo`, which is why it is stated once here instead of a
// third time inline: half a move across a language boundary leaves the
// reader looking at a pane that is either blank or on the wrong
// passage, with the toolbar still naming the right one.
//
// Round-tripping through English is the only join available:
// `bookNameToEnglish` is the one mapping every spelling agrees on, and
// it carries the simplified and traditional forms as well as the
// English identity.

import 'package:seeksparks/constants/book_names.dart';
import 'package:seeksparks/models/verse.dart';

/// The first verse of ([book], [chapter]) inside [verses], or null when
/// that edition does not carry it.
///
/// [book] is a name in ANY edition's spelling — the caller's, not
/// [verses]'. A null answer is a real answer and callers must handle
/// it: the editions can disagree about what exists (a partial canon, a
/// chapter one of them numbers differently), and inventing a landing
/// place for a chapter an edition does not have is how a second column
/// ends up on Genesis 1 while the first is in John 3.
Verse? firstVerseOfChapterAcrossEditions(
  List<Verse> verses,
  String? book,
  int? chapter,
) {
  if (book == null || book.isEmpty || chapter == null) return null;
  final english = bookNameToEnglish[book] ?? book;
  for (final v in verses) {
    if (v.chapter == chapter && (bookNameToEnglish[v.book] ?? v.book) == english) {
      return v;
    }
  }
  return null;
}

/// Where a BRAND-NEW second reading column should open, given the
/// passage the first column is on.
///
/// The same search, with one fallback, and the fallback is the whole
/// reason this is a second function rather than an argument. A column
/// that is already on a chapter can be LEFT there when the passage does
/// not exist in it — that is `_followPrimary`'s rule and it is right. A
/// column being constructed has nowhere to be left: its `MainProvider`
/// is fresh, `currentBook` and `currentChapter` are still null, and
/// `FetchVerses` does not set them, so returning null would open the
/// column on no chapter at all.
///
/// So an edition that genuinely cannot carry the passage — LJK V2 is
/// Matthew only, and a reader in Genesis asking for it is the real case
/// — opens at the start of what it does carry. What the fallback must
/// NOT do is stand in for a language mismatch, which is what it was
/// doing when it was the `orElse` of a raw string comparison: every
/// cross-language open took it, and it looked like a partial canon.
///
/// Null only when [verses] is empty, i.e. the edition failed to load.
/// The old code called `verses.first` unconditionally and would have
/// thrown a `StateError` there.
Verse? seedChapterForNewColumn(
  List<Verse> verses,
  String? book,
  int? chapter,
) {
  final exact = firstVerseOfChapterAcrossEditions(verses, book, chapter);
  if (exact != null) return exact;
  return verses.isEmpty ? null : verses.first;
}

/// Whether [verses] is already showing ([book], [chapter]), compared
/// the same way [firstVerseOfChapterAcrossEditions] searches.
///
/// Separate from the search because the caller that needs it — the
/// second column following the first — has to answer "am I already
/// there?" without paying a scan of 31,102 verses on every one of the
/// primary provider's notifications, and it notifies on selection and
/// highlight changes, not only on chapter moves.
bool sameChapterAcrossEditions({
  required String? bookA,
  required int? chapterA,
  required String? bookB,
  required int? chapterB,
}) {
  if (chapterA != chapterB) return false;
  if (bookA == null || bookB == null) return bookA == bookB;
  return (bookNameToEnglish[bookA] ?? bookA) ==
      (bookNameToEnglish[bookB] ?? bookB);
}
