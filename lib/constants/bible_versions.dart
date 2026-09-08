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
  // 2026-09-07: the Christian Standard Bible. The 2017 Holman grant, the
  // licensee's extension of it to the Yahweh's Words products and the
  // owner's decision on territory are all in `docs/permissions/`; the
  // credit line it requires is `aboutLicenseCsb`, and it is required
  // verbatim, which is why `test/csb_asset_test.dart` quotes it in full.
  //
  // What was licensed is the CSB **with Strong's Numbers**, so this row
  // is tagged — see `TaggedTextService.taggedVersions`. The badge stays
  // plain `CSB` rather than `CSB+S`: Holman's own naming rule is to use
  // CSB in running text and in Scripture references, and there is no
  // second, untagged CSB row for a suffix to tell it apart from.
  BibleVersionInfo(
    value: 'csb',
    shortLabel: 'CSB',
    menuLabel: 'Christian Standard Bible',
    language: 'en',
    editionYear: "2017 / with Strong's",
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
  // 2026-09-08: the two divine-name editions from the 雅伟的话 project's
  // own exported database, by `tools/import_yahwehdehua_texts.py`. Both
  // base translations are public domain, both carry Strong's tagging in
  // both Testaments, and in both the Yahweh reading is the ministry's
  // own restoration work rather than a third party's — which is why
  // neither needs a permission on file. `docs/permissions/README.md`
  // says so in the shape that file uses.
  //
  // They are LAST among the English rows, after `kjvs`, deliberately.
  // `defaultSecondaryVersion` seeds a new split pane with the first
  // OTHER row in the same language, so inserting either of them higher
  // would silently change which edition opens beside `kjv` and `bsb`
  // for every reader — a change to a default that has nothing to do
  // with adding a text. `test/default_secondary_version_test.dart` pins
  // those two answers.
  //
  // ⚠️ AN OPEN QUESTION FOR THE OWNER, recorded rather than decided.
  // `bsb-yhwh` is the same translation as `bsb`, and the reader-visible
  // difference is smaller than it looks. `bsb` stores "the LORD" in
  // 13,172 verses, but `text_patterns.dart::_normalizeDivineNames`
  // already rewrites all-caps LORD to Yahweh on the way to the screen,
  // so the two render identically in most of them. Measured
  // reference-by-reference over the 31,086 they share, AFTER that
  // normalisation, 636 verses still differ — 2.0%:
  //
  //   * 326 in the OT. 299 of them are "Lord GOD" — Adonai plus YHWH,
  //     which the BSB sets in small caps and this edition reads "Lord
  //     Yahweh" (Gen 15:2, 2 Sam 7:18-22, 1 Kgs 8:53). The app's
  //     normaliser rewrites `LORD` and cannot touch `GOD`. The other 27
  //     are the short form יָהּ, printed "Yah" here and "the LORD" in the
  //     BSB — "His name is Yah" (Ps 68:4), "the throne of Yah" (Ex
  //     17:16), and Exodus 15:2, which opens the Song of the Sea.
  //   * 310 in the NT, where κύριος is either restored as
  //     `Lord [Yahweh]` (188 verses — Matt 1:20, 1 Cor 1:31) or flagged
  //     with an asterisk (113 verses, 1 Cor 2:8). Nothing else in this
  //     catalog makes a claim about the divine name in the New
  //     Testament at all, and `[Yahweh]` is not a new convention for it:
  //     `bracketSpanKind` already types that exact token as
  //     `ScriptureSpanKind.divineName` for 和合本雅伟版's `主[雅伟]`.
  //   * plus 237 translator's footnotes across 224 verses ("not in the
  //     Hebrew") that the plain BSB does not carry at all.
  //
  // That is a real editorial claim and it is the ministry's own, which
  // is why the row ships. But on 2026-09-08 — the same day — the owner
  // hid `cuvs-plus` with 「有雅+ 就不用和合本+了」, and the relation there
  // is exactly this one: one base text, one row restoring the divine
  // name. Applied here that would mean hiding `bsb`, not this. It was
  // NOT done, because `bsb` is the English locale default
  // (`localeDefaultVersion`), is the only English row in
  // `unrestrictedCopyVersions` with tagging, and taking the English
  // default off the interface is the owner's call and not an
  // importer's. If he wants the same rule applied, it is two lines:
  // `bsb` into [disabledVersions] and a `'bsb': 'bsb-yhwh'` row in
  // [retiredVersionSuccessors].
  //
  // `test/no_duplicate_version_text_test.dart` was consulted before
  // either row was written, not after: it scores this pair at 83.7%
  // agreement, under its 90% gate, because it reads the ASSETS and the
  // assets really do differ in 13,172 verses. Passing that gate is not
  // the same as earning the row, which is what the paragraphs above are
  // for.
  BibleVersionInfo(
    value: 'bsb-yhwh',
    shortLabel: 'BSB-Y',
    menuLabel: 'Berean Standard Bible (Yahweh)',
    language: 'en',
    editionYear: "2020 / divine name restored, with Strong's",
  ),
  // The ASV has no plain counterpart in this catalog and needs none of
  // the argument above: it is a different translation from everything
  // here (11.1% agreement with `kjv`, its nearest relative, and 0.0%
  // with `bsb`), and at 1901 it is the oldest English text in the app
  // after the KJV.
  //
  // "(Yahweh)" is not decoration on this row either, and it is not the
  // usual restoration. The 1901 ASV is the one major English Bible that
  // already PRINTED the divine name — as *Jehovah*, and this edition
  // reads Yahweh 6,828 times in the same places. So what it changes is
  // the spelling of a name the translators had already chosen to print,
  // which is a smaller claim than the one `bsb-yhwh` makes and a
  // different one. Four verses keep JEHOVAH, all four in the all-caps
  // inscription "HOLY TO JEHOVAH" or "JEHOVAH THY GOD" (Ex 28:36,
  // Ex 39:30, Deut 28:58, Zech 14:20). The source left the small-caps
  // form alone; so does this, rather than tidying a text on the way in.
  BibleVersionInfo(
    value: 'asv-yhwh',
    shortLabel: 'ASV-Y',
    menuLabel: 'American Standard Version (Yahweh)',
    language: 'en',
    editionYear: "1901 / Jehovah as Yahweh, with Strong's",
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
  // 2026-09-08 — HIDDEN from the interface at the owner's instruction:
  // 「有雅+ 就不用和合本+了」. See [disabledVersions]. The row stays in the
  // catalog because a hidden edition still needs its label, its tag
  // colour and its attribution — `availableVersions` is what does the
  // hiding, not this list.
  //
  // The reason was already written down here before it was acted on.
  // This row used to carry a note explaining why it sat LAST among the
  // 简体 rows: `defaultSecondaryVersion` seeds a split pane with the
  // first other edition in the same language, and this is the standard
  // 和合本 — the same base text as 和合本雅伟版, differing mostly by the
  // 4,857 divine-name restorations, so opening it beside 雅伟版 made
  // Split View compare a text against itself. Ordering avoided that in
  // one surface. Hiding answers it everywhere.
  //
  // The ASSET is untouched and still ships. That is not caution, it is
  // load-bearing: `cuvs-plus` is one of the five editions
  // `tagged_layer_coverage_test.dart` sweeps against each other, and
  // `verse_alignment_test.dart` and `divine_name_gloss_test.dart` both
  // read it as a cross-check corpus. Deleting it would take out
  // integrity checks that have nothing to do with whether a reader can
  // pick the edition.
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

/// Versions hidden from every surface a reader picks from, while their
/// assets stay bundled and deployed.
///
/// CUV, CNV, and LJK1 (`biblexg`/`biblexg-tr`) were REMOVED OUTRIGHT
/// (2026-08, ported from YsWords v1.4.0) rather than hidden — superseded
/// by CUVS-YHWH / biblexg-v2, assets and all. ⚠️ Old shared links using
/// those version codes no longer resolve.
///
/// 2026-09-02 — the NASB is the only entry. The owner's instruction was
/// 只从界面藏掉: take it off the interface, do NOT take it out of the
/// build. So `pubspec.yaml` still lists `assets/nasb.json`, the file
/// still ships, and `test/data_integrity_test.dart` still pins that it
/// does. What changes is that nothing offers it: `availableVersions` is
/// what the picker, the Browse stack sheet, the command line's version
/// verb, the Browse nav strip and the Copy Center all read.
///
/// Hiding is not free, because a version code outlives the reader's
/// choice of it — see [retiredVersionSuccessors], which is where a
/// stored `nasb` is turned back into a Bible.
///
/// **LEB was hidden alongside it for a few hours the same day and is
/// visible again**: the owner checked the licence and it permits what
/// this app does with it. Only the NASB's permission is still in
/// question, and that question is out with the publisher rather than
/// settled here. Do not re-hide the LEB on the strength of the pair
/// having once been listed together — they were listed together because
/// the question had not been asked, not because the answers matched.
const disabledVersions = <String>{
  'nasb',
  // 2026-09-08 — 「有雅+ 就不用和合本+了」. Not a licensing question like
  // the NASB above: `cuvs-plus` is the standard 和合本 and `cuvs-yhwh`
  // is the same base text with the divine name restored in the 4,857
  // places the received text had it, so the picker was offering the
  // reader a choice between a text and the same text. The successor is
  // recorded in [retiredVersionSuccessors].
  'cuvs-plus',
};

/// Editions the reader imported — bwh47. code → the name they gave it.
///
/// A runtime registry beside the const catalog, because a version the
/// reader supplies cannot be a compile-time constant and every gate in
/// this file keys on the catalog. Registered by
/// `LocalVersionRegistry.restore()` at boot and by the importer;
/// everything else in the app asks the same three functions it always
/// did — [isKnownVersion], [loadableVersions], [availableVersions] —
/// and they consult both.
///
/// Empty on native and in every test that does not populate it, so the
/// app behaves exactly as it did before an import exists.
final Map<String, String> importedVersionLabels = <String, String>{};

/// code → `en` or `zh-Hans`, the script the imported file's own book
/// names are written in.
///
/// Separate from the label map because it answers a different question
/// and has a different reader: the label is what the picker prints,
/// this is what `bookScriptFor` needs so the reference beside a verse is
/// in the same language as the verse. Defaults to `en` for a code that
/// is registered without one, which is the old behaviour.
final Map<String, String> importedVersionScripts = <String, String>{};

/// The catalog rows for the imported editions, built on demand.
///
/// The language is the one the file's own BOOK NAMES are written in,
/// recorded by the validator at import time — not a guess, and not a
/// setting the reader has to find. It decides the picker tab and, more
/// importantly, `bookScriptFor`: the first browser test of this feature
/// showed an English import whose references read 創世紀 beside its own
/// English text, because a code outside the English set falls through
/// to Chinese.
List<BibleVersionInfo> get importedVersions => [
      for (final e in importedVersionLabels.entries)
        BibleVersionInfo(
          value: e.key,
          shortLabel: e.value.length <= 6
              ? e.value
              : '${e.value.substring(0, 5)}…',
          menuLabel: e.value,
          language: importedVersionScripts[e.key] ?? 'en',
          editionYear: '',
        ),
    ];

/// Versions shown in the picker (excludes disabled ones).
List<BibleVersionInfo> get availableVersions => [
      ...bibleVersions.where((v) => !disabledVersions.contains(v.value)),
      // Last, always. An imported text has not been checked by anyone,
      // and putting it above the editions that have would be a claim
      // about it that nothing supports.
      ...importedVersions,
    ];

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

/// The edition's full name — "和合本雅伟版(简体)", "Berean Standard
/// Bible" — as opposed to the gutter badge [shortBibleVersionLabel]
/// prints. Falls back to the raw code so an unknown one is visible
/// rather than blank.
/// The edition's full name, plus its year when the catalog states one.
///
/// 2026-09-08, reported as 「BGT BSB 雅简这些别人看简写不知道什么意思」. The
/// Browse gutter prints four-character tags because that is what a
/// parallel view has room for — and a reader who has not memorised the
/// catalog has no way in from there. Every one of those tags has a full
/// name sitting in `bibleVersions`; this is the string that says it.
///
/// Falls back to [menuBibleVersionLabel] for an edition with no year,
/// and to the raw code for one that is not in the catalog at all —
/// which is what an imported edition is, and its code IS its name.
String fullBibleVersionLabel(String version) {
  for (final v in bibleVersions) {
    if (v.value != version) continue;
    return v.editionYear.isEmpty
        ? v.menuLabel
        : '${v.menuLabel} · ${v.editionYear}';
  }
  return menuBibleVersionLabel(version);
}

String menuBibleVersionLabel(String version) {
  for (final v in bibleVersions) {
    if (v.value == version) return v.menuLabel;
  }
  return version;
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
  // 2026-09-08 — 和合本+Strong's → 和合本雅伟版. Hidden rather than
  // removed (see [disabledVersions]), and the same relation `cuv` has to
  // `cuvs-yhwh` two rows above: one base text, one of them restoring the
  // divine name. A reader sitting on `cuvs-plus`, or following a
  // `?v=cuvs-plus` link, lands on the edition that supersedes it instead
  // of falling through to the locale default.
  'cuvs-plus': 'cuvs-yhwh',
  // 梁家铿译本 LJK1 → LJK2.
  'biblexg': 'biblexg-v2',
  'biblexg-tr': 'biblexg-v2-tr',
  // Removed 2026-05 for licensing (Biblica / Zondervan). KJV is the
  // closest English text that is unambiguously public domain.
  'niv': 'kjv',
  // 2026-09-02 — hidden rather than removed (see [disabledVersions]),
  // but the reader-facing question is identical and so is the answer.
  // `isKnownVersion` keys on `availableVersions`, so a hidden code is
  // already "unloadable" as far as every caller is concerned; without a
  // row here a reader whose saved version is `nasb` would fall through
  // to the LOCALE default, and a zh-Hans-locale reader who had
  // deliberately chosen an English Bible would be handed 和合本.
  //
  // BSB: it is the English default now, it is public domain, and it is
  // the only English edition here carrying Strong's tagging. Language is
  // preserved, which is the property that matters — the same rule the
  // Chinese rows above are held to.
  //
  // There is deliberately NO `leb` row. The LEB is visible again, so a
  // stored `leb` is a Bible the reader can still find in the picker and
  // must be left alone; a successor row would silently move readers off
  // an edition that is on offer.
  'nasb': 'bsb',
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
      // 2026-09-02: was 'nasb'. NASB is hidden from the interface now
      // (see [disabledVersions]), so it can no longer be what a fresh
      // English install opens on. BSB is the owner's replacement.
      return 'bsb';
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
