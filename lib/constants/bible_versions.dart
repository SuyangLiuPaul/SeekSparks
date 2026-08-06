class BibleVersionInfo {
  final String value;
  final String shortLabel;
  final String menuLabel;

  /// 2026-06-22: which language family this edition belongs to, so the
  /// version picker can group the ~14 editions under English / 繁體 /
  /// 简体 tabs instead of one long flat list. Values match the app
  /// locale codes: `en`, `zh-Hant`, `zh-Hans`.
  final String language;

  /// Round 56 user feedback: "和合本新译本should mention which year
  /// version". Year / edition info shown in the version-picker
  /// secondary line so the reader knows which published edition the
  /// asset corresponds to. Empty string when not applicable / unknown.
  final String editionYear;

  const BibleVersionInfo({
    required this.value,
    required this.shortLabel,
    required this.menuLabel,
    required this.language,
    this.editionYear = '',
  });
}

const bibleVersions = <BibleVersionInfo>[
  BibleVersionInfo(
    value: 'kjv',
    shortLabel: 'KJV',
    menuLabel: 'King James Version',
    language: 'en',
    editionYear: '1611 / 1769 revision',
  ),
  BibleVersionInfo(
    value: 'leb',
    shortLabel: 'LEB',
    menuLabel: 'Lexham English Bible',
    language: 'en',
    editionYear: '2012',
  ),
  BibleVersionInfo(
    value: 'nasb',
    shortLabel: 'NASB',
    menuLabel: 'New American Standard Bible',
    language: 'en',
    editionYear: '2020 update',
  ),
  BibleVersionInfo(
    value: 'bsb',
    shortLabel: 'BSB',
    menuLabel: 'Berean Standard Bible',
    language: 'en',
    editionYear: '2020 / public domain',
  ),
  // 2026-08-07: the three editions below come from Eagle's View, the
  // electronic statistical concordance by Pastor Ho
  // (eaglesviewsoftware.com), imported by tools/import_eaglesview.py.
  // All three are public-domain texts and all three ship Strong's
  // tagging, which is why they earn a row of their own rather than
  // replacing anything.
  //
  // KJVS is a SEPARATE row from `kjv` on purpose. They are different
  // editions of the same translation — EV keeps 1769 British spelling
  // (shewbread, honour, alway) where the bundled `kjv` is modernised,
  // and they disagree on ~3% of verses. Word-level tagging has to travel
  // with the exact text it was aligned against, so grafting EV's tags
  // onto the existing `kjv` would mis-tag roughly 960 verses.
  BibleVersionInfo(
    value: 'kjvs',
    shortLabel: 'KJV+S',
    menuLabel: "King James Version + Strong's",
    language: 'en',
    editionYear: "1769 / with Strong's + TVM",
  ),
  BibleVersionInfo(
    value: 'lxxwh',
    shortLabel: 'LXX+WH',
    menuLabel: 'Septuagint + Westcott-Hort',
    language: 'grc',
    // Unaccented, as the source encodes it — worth saying, because a
    // reader who knows Greek will notice the missing breathings before
    // they notice anything else.
    editionYear: 'Greek OT + NT / unaccented',
  ),
  // NIV (New International Version) was previously listed here.
  // Removed in 2026-05 — Biblica / Zondervan retain commercial
  // copyright on the full text and we cannot redistribute the bundled
  // JSON without an explicit publisher licence. Users seeking NIV
  // should follow Bible Gateway / YouVersion. The asset file
  // `assets/niv.json` was also removed in the same change.
  BibleVersionInfo(
    value: 'cuvs-yhwh',
    shortLabel: 'CUVS(简)',
    menuLabel: '和合本雅伟版(简体)',
    language: 'zh-Hans',
    // 2026-08 (ported from YsWords v1.4.6): the edition-year sub-line was
    // dropped — this and the 繁體 row below were the only ones carrying a
    // note in the version picker, which made the list look inconsistent
    // next to the 梁家铿译本 rows (no editionYear). `editionYear` defaults
    // to '' and is only rendered by version_picker_sheet.dart behind an
    // isNotEmpty guard, so omitting it simply hides the line.
  ),
  BibleVersionInfo(
    value: 'cuvs-yhwh-tr',
    shortLabel: 'CUVS(繁)',
    menuLabel: '和合本雅伟版(繁體)',
    language: 'zh-Hant',
  ),
  BibleVersionInfo(
    value: 'biblexg-v2',
    shortLabel: 'LJK(简)',
    menuLabel: '梁家铿译本(简体)',
    language: 'zh-Hans',
  ),
  BibleVersionInfo(
    value: 'biblexg-v2-tr',
    shortLabel: 'LJK(繁)',
    menuLabel: '梁家铿譯本(繁體)',
    language: 'zh-Hant',
  ),
  // Deliberately LAST among the 简体 rows, not next to its two sibling
  // Eagle's View imports. `defaultSecondaryVersion` seeds a new split
  // pane with the first other edition in the same language, and this is
  // the standard 和合本 — the same base text as 和合本雅伟版, differing
  // mostly by the 4,857 divine-name restorations. Opening it beside
  // 雅伟版 would make Split View compare a text against itself. 梁家铿译本
  // is a genuinely different translation, so it keeps the default.
  BibleVersionInfo(
    value: 'cuvs-plus',
    shortLabel: 'CUV+S(简)',
    menuLabel: "和合本+Strong's(简体)",
    language: 'zh-Hans',
    editionYear: '1919 / 和合本原文',
  ),
];

/// Versions hidden from the picker (currently none). CUV, CNV, and LJK1
/// (`biblexg`/`biblexg-tr`) were REMOVED OUTRIGHT (2026-08, ported from
/// YsWords v1.4.0) rather than hidden — superseded by CUVS-YHWH /
/// biblexg-v2. ⚠️ Old shared links using those version codes no longer
/// resolve; this mirrors the explicit product choice made for YsWords.
/// Kept as a mechanism in case a future edition needs to be superseded
/// without breaking old shared links.
const disabledVersions = <String>{};

/// Versions shown in the picker (excludes disabled ones).
List<BibleVersionInfo> get availableVersions =>
    bibleVersions.where((v) => !disabledVersions.contains(v.value)).toList();

/// The order languages appear in the version picker's language selector.
/// English first, then Traditional, then Simplified — matches the way
/// the user phrased it ("英语繁体简体"). Greek goes last: it is an
/// original-language column for study, not a reading language anyone
/// picks by default. Only languages that actually have at least one
/// available version are kept (defensive against a future all-disabled
/// language).
List<String> get bibleLanguageOrder {
  const order = ['en', 'zh-Hant', 'zh-Hans', 'grc'];
  final present = availableVersions.map((v) => v.language).toSet();
  return order.where(present.contains).toList();
}

/// The available versions belonging to [language] (`en` / `zh-Hant` /
/// `zh-Hans`), in catalog order.
List<BibleVersionInfo> versionsForLanguage(String language) =>
    availableVersions.where((v) => v.language == language).toList();

/// The language family (`en` / `zh-Hant` / `zh-Hans`) of a version code.
/// Falls back to `zh-Hans` for an unknown code (the app's primary
/// audience) so the picker never lands on an empty tab.
String bibleVersionLanguage(String value) {
  for (final v in bibleVersions) {
    if (v.value == value) return v.language;
  }
  return 'zh-Hans';
}

String shortBibleVersionLabel(String version) {
  return bibleVersions
      .firstWhere(
        (item) => item.value == version,
        orElse: () => BibleVersionInfo(
          value: version,
          shortLabel: version,
          menuLabel: version,
          language: 'zh-Hans',
        ),
      )
      .shortLabel;
}

/// Some bundled versions only ship one Testament — most notably the
/// LJK1 / LJK2 (梁家铿译本) editions are NT-only because the
/// translator's OT work isn't published yet.  When the daily-verse
/// lookup hits a book that doesn't exist in those bundles (e.g. an
/// OT reference for a user reading on LJK1), we fall back to a
/// same-language full-canon bundle instead of showing an empty
/// daily-verse card.
///
/// Returns the version code to fall back to, or null when [version]
/// already has full OT+NT coverage.
String? bibleVersionFullCanonFallback(String version) {
  switch (version) {
    case 'biblexg-v2':    // LJK2 (Simplified Chinese, NT only)
      return 'cuvs-yhwh';      // 和合本雅伟版 (Simplified, full canon)
    case 'biblexg-v2-tr': // LJK2 (Traditional Chinese, NT only)
      return 'cuvs-yhwh-tr';   // 和合本雅伟版 (Traditional, full canon)
  }
  return null;
}

/// The version a NEW split-view pane should open with, given what the
/// primary pane is showing.
///
/// 2026-08-06: the second pane used to be seeded with
/// `primary.currentVersion`, so opening Split View produced the same
/// chapter in the same translation twice — half the screen spent saying
/// nothing. A comparison view has to compare something.
///
/// Prefers a different version in the SAME language, because that is
/// the comparison a reader can actually use: NASB beside KJV, 和合本
/// beside 梁家铿译本. Cross-language is the second choice, not the
/// first — a pane in a script you don't read is only marginally better
/// than the duplicate it replaces. Script variants of one language
/// (繁體/简体) count as the same family for that fallback, since
/// 和合本繁體 beside 和合本简体 is one text in two character sets.
///
/// Falls back to any other available version, and finally to
/// [primaryVersion] itself when the catalog holds only one — duplicated
/// is still better than blank.
String defaultSecondaryVersion(String primaryVersion) {
  final all = availableVersions;
  final others = all.where((v) => v.value != primaryVersion).toList();
  if (others.isEmpty) return primaryVersion;

  final primaryLang = bibleVersionLanguage(primaryVersion);
  for (final v in others) {
    if (v.language == primaryLang) return v.value;
  }

  // 'en' vs 'zh' — zh-Hant and zh-Hans collapse into one family.
  String family(String lang) => lang.startsWith('zh') ? 'zh' : lang;
  final primaryFamily = family(primaryLang);
  for (final v in others) {
    if (family(v.language) == primaryFamily) return v.value;
  }

  return others.first.value;
}
