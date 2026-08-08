class BibleVersionInfo {
  final String value;

  /// The badge printed in the parallel gutter, the reading-pane chip,
  /// the Browse header and the Copy Center — and, because the command
  /// line accepts it as a token, also a typed handle for the edition.
  ///
  /// 2026-08-08 (task #285): the Chinese editions no longer carry Latin
  /// abbreviations. A Chinese reader had to decode `CUVS` and `LJK` to
  /// pick a Chinese text, which is the wrong way round.
  ///
  /// The scheme, confirmed by the owner:
  ///   1st character = WHICH TEXT   雅 = 和合本雅伟版, 和 = 和合本, 梁 = 梁家铿
  ///   2nd character = WHICH SCRIPT 简 = 简体, 繁 = 繁體
  ///   trailing `+`  = carries Strong's tagging
  ///
  /// That is the same information architecture BibleWorks uses for its
  /// own Chinese rows — `bwh42` lists `CUS` and `CU5` under the section
  /// headings *ChineseGB* and *ChineseB5*, one identifier per (text,
  /// script) pair, with the machine-readable layer marked by a suffix
  /// (`BNT`/`BNM`). Only the alphabet differs.
  ///
  /// The English and Greek rows keep their Latin abbreviations on
  /// purpose: KJV, LEB, NASB, BSB, KJV+S and LXX+WH are the names those
  /// texts are actually known by, and sinicising them would invent
  /// abbreviations no reader has ever seen.
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
    shortLabel: '雅简+',
    menuLabel: '和合本雅伟版(简体)',
    language: 'zh-Hans',
    // 2026-08 (ported from YsWords v1.4.6): the edition-year sub-line was
    // dropped — this and the 繁體 row below were the only ones carrying a
    // note in the version picker, which made the list look inconsistent
    // next to the 梁家铿译本 rows (no editionYear). `editionYear` defaults
    // to '' and is only rendered by version_picker_sheet.dart behind an
    // isNotEmpty guard, so omitting it simply hides the line.
  ),
  // ⚠️ `雅繁+` claims Strong's that this row does not ship TODAY:
  // `TaggedTextService.taggedVersions` holds `cuvs-yhwh` but not
  // `cuvs-yhwh-tr`, because `assets/tagged/` has no traditional set.
  // The label is the one the owner wrote out in the confirmed scheme
  // and it is kept verbatim — naming is their call — but the gap is
  // real and `test/version_label_scheme_test.dart` pins it as a named
  // exception so it cannot quietly become the norm. Closing it means
  // serving the simplified tagging through a 简→繁 conversion, which
  // the app has no converter for.
  BibleVersionInfo(
    value: 'cuvs-yhwh-tr',
    shortLabel: '雅繁+',
    menuLabel: '和合本雅伟版(繁體)',
    language: 'zh-Hant',
  ),
  BibleVersionInfo(
    value: 'biblexg-v2',
    shortLabel: '梁简',
    menuLabel: '梁家铿译本(简体)',
    language: 'zh-Hans',
  ),
  BibleVersionInfo(
    value: 'biblexg-v2-tr',
    shortLabel: '梁繁',
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
    shortLabel: '和简+',
    menuLabel: "和合本+Strong's(简体)",
    language: 'zh-Hans',
    editionYear: '1919 / 和合本原文',
  ),
  // `cuv-yhwd` (yahwehdehua.net, imported 2026-08-07) was listed here and
  // has been REMOVED. Do not re-import it without reading this first.
  //
  // The import itself succeeded — all 31,102 verses, all 66 books. The
  // problem is that the text is `cuvs-yhwh`, which this catalog already
  // carries. Not "similar to": the two share all 31,102 references, and
  // every one of the 1,678 verses that differ differs only in how the
  // translator's notes are marked (〔或作："成"〕 against <note: 或作：成>).
  //
  // Its tagging looked like the reason to keep it — 100% of runs carrying
  // a Strong's number, against 98.2% for cuvs-yhwh. That reading was
  // backwards. The runs are otherwise identical; the extra 1.8% is
  // Chinese sentence-final particles absorbed into the preceding word:
  //
  //   cuvs-yhwh  Rom 6:1   '显多' G4121   '吗？' (untagged)
  //   cuv-yhwd   Rom 6:1   '显多吗？' G4121
  //
  // 吗 is an interrogative particle with no Greek behind it, so leaving it
  // untagged is right and 98.2% is the honest number. 呢/吗/了/的 account
  // for 96% of cuvs-yhwh's "untagged" runs. Shipping cuv-yhwd would have
  // put two indistinguishable rows in the picker, made Split View compare
  // a text against itself, and cost 22 MB to do it.
  //
  // tools/import_yahwehdehua_export.py is kept, and its two decoding bugs
  // are fixed, so the set can be rebuilt if the source ever diverges.
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

/// Editions this build can no longer load, and the surviving edition a
/// reader who asked for each one should land on.
///
/// A version code outlives the version. It is written into
/// SharedPreferences on every chapter change, into every share link as
/// `?v=`, and into the persisted Browse stack — so retiring an edition
/// strands every bookmark, every synced device and every reader who
/// simply had it open when they last closed the tab.
///
/// That is not hypothetical. Between 2026-08-07 and 2026-08-08 the
/// codes below were removed with their assets, and the app went on
/// requesting `assets/<code>.json` for them. On the web that request
/// does not 404 into an exception: Netlify answers an unknown path with
/// the SPA fallback, so `rootBundle.loadString` returns `<!DOCTYPE
/// html>…` with a 200 and `json.decode` throws
/// `FormatException: Unexpected token '<'`. Boot died there, on a
/// message that named neither the version nor the file.
///
/// Every mapping preserves LANGUAGE and SCRIPT, because that is the
/// substitution a reader is least likely to be hurt by: a 繁體 reader
/// must not be handed 简体. Where the retirement was a supersession the
/// successor is the edition that replaced it; where the text has no
/// survivor (`cnv`, 新译本) it is the nearest edition in the same script,
/// and the reader is told rather than silently moved — see
/// `MainProvider.retiredVersionNotice`.
///
/// A code that is NOT listed here is not a failure: it falls through to
/// the locale default, which is still a Bible the reader can read. The
/// table only buys a *better* landing, so an omission degrades quietly
/// instead of breaking.
const Map<String, String> retiredVersionSuccessors = <String, String>{
  // 和合本 → 和合本雅伟版. Same base text; the successor restores the
  // divine name in the 4,857 places the received text had it.
  'cuv': 'cuvs-yhwh',
  'cuv-tr': 'cuvs-yhwh-tr',
  // 新译本 has no successor in the catalog. Nearest same-script Chinese
  // Bible, and the notice says so.
  'cnv': 'cuvs-yhwh',
  'cnv-tr': 'cuvs-yhwh-tr',
  // yahwehdehua.net's export, imported and removed the next day: it was
  // `cuvs-yhwh`, sharing all 31,102 references. See the catalog comment
  // above — this successor is the same text, not an approximation.
  'cuv-yhwd': 'cuvs-yhwh',
  // 梁家铿译本 LJK1 → LJK2.
  'biblexg': 'biblexg-v2',
  'biblexg-tr': 'biblexg-v2-tr',
  // Removed 2026-05 for licensing (Biblica / Zondervan). KJV is the
  // closest English text that is unambiguously public domain.
  'niv': 'kjv',
};

/// Whether [code] names an edition this build can actually load.
///
/// Checked against [availableVersions], not [bibleVersions], so a
/// version hidden through [disabledVersions] is treated as unloadable
/// too. Those two lists are the same today only because nothing is
/// hidden; keying on the wrong one would go wrong the first time
/// something is.
bool isKnownVersion(String? code) {
  if (code == null || code.isEmpty) return false;
  final c = code.toLowerCase();
  return availableVersions.any((v) => v.value == c);
}

/// The edition a fresh install opens with, by UI locale.
///
/// Lifted out of `MainProvider.restoreState` so the no-saved-version
/// branch and the retired-code fallback answer this question with the
/// same code rather than two copies that drift.
String localeDefaultVersion(String locale) {
  switch (locale) {
    case 'en':
      return 'nasb';
    case 'zh-Hant':
      return 'cuvs-yhwh-tr';
    case 'zh-Hans':
    default:
      // Mandarin is the app's primary audience, so anything
      // unrecognised lands here rather than on English.
      return 'cuvs-yhwh';
  }
}

/// What a persisted or linked reading-version code should resolve to.
///
/// [stored] is whatever was found in SharedPreferences, in a `?v=`
/// parameter, or in a synced `lastRead` blob — none of which this build
/// controls the vintage of. It is validated rather than trusted, which
/// is the whole point: an unloadable code must land the reader on a
/// Bible, never on a boot that throws.
///
/// [fallback] is what to open when [stored] is empty or names an
/// edition with no surviving successor. It is a parameter rather than a
/// locale lookup because the right answer differs by caller and only
/// the caller knows it: boot wants the locale default, while a deep
/// link wants the edition already on screen — moving a reader to NASB
/// because someone sent them a stale link would be a worse outcome than
/// ignoring the link. Callers must pass a loadable code; it is returned
/// unexamined, since validating it would only push the question one
/// level out.
///
/// Returns the code to open. Compare it against [stored] to find out
/// whether a substitution happened and the reader is owed a notice.
String resolveReadingVersion({
  required String? stored,
  required String fallback,
}) {
  final code = stored?.trim().toLowerCase() ?? '';
  if (code.isEmpty) return fallback;
  if (isKnownVersion(code)) return code;
  final successor = retiredVersionSuccessors[code];
  // Guard the successor too. A mapping can rot when its target is
  // itself retired later, and a table that points at a missing asset
  // would reintroduce exactly the crash it exists to prevent.
  if (isKnownVersion(successor)) return successor!;
  return fallback;
}

/// Reduce a list of version codes to the ones this build can load, in
/// order, without duplicates.
///
/// The Browse stack is persisted as a list of codes, so it ages the same
/// way a single saved reading version does — and a stack is worse when
/// it rots, because one bad entry breaks a column of a comparison the
/// reader assembled deliberately.
///
/// Retired codes are mapped to their successors rather than dropped, so
/// a reader who arranged four columns still has four. Duplicates created
/// by that mapping collapse: `cuv` and `cuv-yhwd` both resolve to
/// `cuvs-yhwh`, and a Browse stack comparing a text against itself is
/// the one outcome worse than a missing column.
List<String> loadableVersions(Iterable<String> codes) {
  final out = <String>[];
  final seen = <String>{};
  for (final raw in codes) {
    final code = raw.trim().toLowerCase();
    if (code.isEmpty) continue;
    final resolved =
        isKnownVersion(code) ? code : retiredVersionSuccessors[code];
    if (!isKnownVersion(resolved)) continue;
    if (seen.add(resolved!)) out.add(resolved);
  }
  return out;
}

/// SharedPreferences key holding the edition the second reading column
/// last showed. Written by the second pane's own `MainProvider`, which
/// runs under `storagePrefix: 'secondary_'`.
const String kSecondaryVersionKey = 'secondary_version';

/// Which edition the second reading column should open with.
///
/// [stored] is whatever [kSecondaryVersionKey] holds — the reader's own
/// last pick, which wins over any default. It is validated against the
/// catalog rather than trusted, because a version can be retired between
/// releases (`cuv-yhwd` was, above) and a stale code would otherwise
/// open a column that can never load.
///
/// Shared by the split pane and by the boot warm-up rather than
/// duplicated in each. The warm-up's whole job is to fetch the edition
/// the pane is about to demand, so the two answering this question
/// differently would mean warming the wrong Bible — silently, and only
/// for readers who had ever changed the second column.
String resolveSecondaryVersion({
  required String primaryVersion,
  String? stored,
}) {
  if (isKnownVersion(stored)) return stored!.toLowerCase();
  // A retired pick keeps its successor where there is one, so a reader
  // who had 梁家铿译本 in the second column gets 梁家铿译本 back rather
  // than whatever the generic default happens to be — unless the
  // successor collapses onto the primary, which would leave Split View
  // comparing a text against itself.
  final successor = retiredVersionSuccessors[stored?.trim().toLowerCase()];
  if (isKnownVersion(successor) && successor != primaryVersion) {
    return successor!;
  }
  return defaultSecondaryVersion(primaryVersion);
}
