import 'package:seeksparks/constants/bible_versions.dart'
    show bibleVersionFullCanonFallback, shortBibleVersionLabel;
import 'package:seeksparks/constants/ui_strings.dart' show uiStrings;
import 'package:seeksparks/utils/version_mapper.dart' show localeAwareBookName;

/// What the centre pane says when the open edition does not ship the
/// chapter the reader navigated to — the NT-only 梁家铿译本 with a
/// stored Psalms bookmark being the case that actually produces it.
///
/// Extracted from `bible_reading_pane` on 2026-08-08 because the string
/// it replaced was wrong in four separate ways, none of which any test
/// could see:
///
///   * it named `CUVS-YHWH / CNV` as the versions to switch to. **CNV
///     is not in the catalog** — it was removed outright in 2026-08
///     alongside CUV and LJK1 — so the screen recommended an edition
///     that cannot be selected. `CUVS-YHWH` is an internal code and has
///     never been a badge the reader sees anywhere in the app.
///   * it printed the raw canonical ENGLISH `book` into a Chinese
///     sentence (`当前版本没有 Psalms 23 章`) — task #283's defect class,
///     on a surface that audit missed.
///   * it branched on `locale.startsWith('zh')`, so a Traditional
///     reader was answered in Simplified.
///   * it was hardcoded at the call site, which is why the three above
///     survived every localisation pass.
///
/// The suggestion NAMES an edition only when the catalog can prove a
/// same-language full-canon sibling exists; otherwise it says the
/// honest generic thing. Guessing is what produced `CNV`.
String missingChapterMessage({
  required String book,
  required int chapter,
  required String locale,
  required String currentVersion,
}) {
  String s(String key, String fallback) =>
      uiStrings[key]?[locale] ?? uiStrings[key]?['en'] ?? fallback;

  // The reading version picks the script, not the UI locale: a Chinese
  // UI reading KJV must still be told about `Psalms`.
  final localizedBook = localeAwareBookName(book, locale, currentVersion);
  final first = s('chapterUnavailableAt',
          '{book} {n} is not available in the current version.')
      .replaceAll('{book}', localizedBook)
      .replaceAll('{n}', '$chapter');

  final fallbackCode = bibleVersionFullCanonFallback(currentVersion);
  final second = fallbackCode == null
      ? s('chapterSwitchAny', 'Switch to a version that includes it.')
      : s('chapterSwitchTo', 'Switch to {version}.')
          .replaceAll('{version}', shortBibleVersionLabel(fallbackCode));

  return '$first\n$second';
}
