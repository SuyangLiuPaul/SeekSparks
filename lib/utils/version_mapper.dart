import 'package:seeksparks/constants/book_name_mapping.dart'
    show zhToEn, toLocale, bookNameInScript, bookScriptFor;
import 'package:seeksparks/utils/reference_parser.dart' show BibleReference, parseReference;

String translateBookName(String? book, String version) {
  if (book == null) return '';
  final en = zhToEn(book) ?? book;
  return toLocale(en, version);
}

/// Returns the book name to display in cross-reference / aggregate
/// panels (Top books chips, "Used N times" refs, highlight browser,
/// Strong's search results). Driven by the reading [currentVersion]
/// so book names match the verse text the user is reading — KJV /
/// NASB / NIV / LEB → "Genesis"; CUVS / CNV / CUV → "创世记"; the
/// `-tr` variants → "創世記".
///
/// The English-version detection (kjv/leb/nasb/niv) lives in
/// `book_name_mapping.dart`'s `toLocale`; English versions not on
/// that list will be misclassified as Chinese — add new ones there.
///
/// Falls back to locale-driven naming when no version is provided.
String localeAwareBookName(
    String englishBook, String locale, [String? currentVersion]) {
  final en = zhToEn(englishBook) ?? englishBook;
  return bookNameInScript(en, bookScriptFor(locale, currentVersion));
}

/// Formats a single parsed [BibleReference] as `book chapter[:verse]`
/// with the book name localized via [localeAwareBookName]. Mirrors
/// `BibleReference.toString()`'s chapter/verse suffix logic (including
/// the compact non-contiguous-verses form) but swaps in the
/// locale-aware book name instead of the always-English one.
String _localizedRefPart(
    BibleReference ref, String locale, String? currentVersion) {
  final book = localeAwareBookName(ref.englishBook, locale, currentVersion);
  if (ref.verses.isNotEmpty) {
    final parts = <String>[];
    int start = ref.verses.first;
    int end = start;
    for (var i = 1; i < ref.verses.length; i++) {
      final v = ref.verses[i];
      if (v == end + 1) {
        end = v;
      } else {
        parts.add(start == end ? '$start' : '$start-$end');
        start = v;
        end = v;
      }
    }
    parts.add(start == end ? '$start' : '$start-$end');
    return '$book ${ref.chapter}:${parts.join(',')}';
  }
  final v = ref.verseStart == null
      ? ''
      : (ref.verseEnd != null && ref.verseEnd! > ref.verseStart!
          ? ':${ref.verseStart}-${ref.verseEnd}'
          : ':${ref.verseStart}');
  return '$book ${ref.chapter}$v';
}

/// Locale-aware display label for a raw scripture-reference string
/// (e.g. from `BibleEvidence.scriptureReference`, always stored in
/// English — "2 Samuel 5:9"). Parses the reference and re-renders its
/// book name via [localeAwareBookName], so Bible Evidence cards show
/// "撒母耳记下 5:9" in Chinese locales instead of the raw English
/// string every other reference-display surface in the app already
/// localizes (`VersePopupSheet._refLabel`, notes, highlights, search).
///
/// Handles `;`-separated multi-book references (e.g. "Matthew 5:3-12;
/// Luke 6:20-23") by localizing each segment independently. Segments
/// that fail to parse (e.g. "Multiple Books") are passed through
/// unchanged rather than dropped, so the label never loses content.
String localizedReferenceLabel(
    String raw, String locale, [String? currentVersion]) {
  final segments = raw.contains(';') ? raw.split(';') : [raw];
  return segments.map((segment) {
    final trimmed = segment.trim();
    final ref = parseReference(trimmed);
    if (ref == null) return trimmed;
    final rendered = _localizedRefPart(ref, locale, currentVersion);
    final kept = _extentKeptVerbatim(trimmed, ref, locale, currentVersion);
    return kept ?? rendered;
  }).join('; ');
}

/// The tail of a reference — everything after the book name.
final RegExp _refTail = RegExp(r'[\d:,–\-\s]+$');

/// Localise the book name and keep the reader's own extent, for the
/// references the parse-and-re-render round trip would NARROW.
///
/// Null when the round trip is faithful, which is the ordinary case.
///
/// [parseReference] answers "where does this land?", so it keeps a
/// start and discards what it does not need to navigate: `Genesis 6-9`
/// becomes chapter 6, `John 18:31-33, 37-38` loses its second range,
/// `2 Kings 9:2–10:36` loses the far end, and a bare `Leviticus`
/// acquires a chapter 1 nothing claimed. Re-rendering from that is
/// fine for navigation and wrong for a LABEL: 79 references across
/// `bible_timeline.json`, `family_tree.json` and `bible_evidence.json`
/// were printed narrower than they were written, and one of them told
/// the reader the tabernacle is Leviticus 1.
///
/// Narrowing is detected on the digits alone, so a genuine correction
/// still goes through the ordinary path — `Jude 11` must keep becoming
/// `Jude 1:11`, because Jude has one chapter and 11 is the verse.
String? _extentKeptVerbatim(
    String trimmed, BibleReference ref, String locale, String? version) {
  final book = localeAwareBookName(ref.englishBook, locale, version);
  final rawTail = (_refTail.firstMatch(trimmed)?.group(0) ?? '').trim();
  final rawDigits = rawTail.replaceAll(RegExp(r'\D'), '');
  final renderedDigits =
      _localizedRefPart(ref, 'en', null).replaceAll(RegExp(r'\D'), '');
  if (rawDigits.isEmpty) {
    return renderedDigits.isEmpty ? null : book;
  }
  final bookDigits = ref.englishBook.replaceAll(RegExp(r'\D'), '');
  final tailDigits = renderedDigits.startsWith(bookDigits)
      ? renderedDigits.substring(bookDigits.length)
      : renderedDigits;
  if (tailDigits.length < rawDigits.length &&
      rawDigits.startsWith(tailDigits)) {
    return '$book $rawTail';
  }
  return null;
}

String? toEnglish(String? book) {
  if (book == null || book.isEmpty) return null;

  final mapped = zhToEn(book);
  if (mapped != null) return mapped;

  return book;
}
