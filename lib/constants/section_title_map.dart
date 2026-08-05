/// Maps each Bible-version code to the section-title set it should
/// render in the reading pane. New title sets can be authored in
/// `assets/section_titles.json` and added here without touching any
/// other code.
///
/// Decisions per the user's plan:
///   • CUV-derived translations (CUVS-YHWH, LJK1, LJK2) reuse the
///     master CUV title set — the verse layout matches CUV closely
///     so reusing its headings is editorially correct.
///   • CNV is a different translation philosophy and ideally has its
///     own headings; not yet authored, so we fall through to CUV.
///   • All four English versions share a neutral 'english-classic'
///     set — NIV/NASB/ESV headings are copyright protected and not
///     redistributable.
const sectionTitleSetByVersion = <String, String>{
  // English family — neutral classic-style headings.
  'kjv': 'english-classic',
  'leb': 'english-classic',
  'nasb': 'english-classic',
  // 'niv' entry removed in 2026-05 along with the NIV version itself
  // (see lib/constants/bible_versions.dart for the licence rationale).

  // 2026-08 (ported from YsWords v1.4.0): the 'cuv'/'cuv-tr'/'cnv'/
  // 'cnv-tr'/'biblexg'/'biblexg-tr' VERSION entries were removed here —
  // those versions were deleted outright (see bible_versions.dart). The
  // 'cuv'/'cuv-tr' SET IDs stay below since cuvs-yhwh and biblexg-v2
  // still reuse the CUV title set.

  // Yahweh-edition CUV uses CUV titles.
  'cuvs-yhwh': 'cuv',
  'cuvs-yhwh-tr': 'cuv-tr',

  // LJK2 (梁家铿译本 第二版) uses CUV titles.
  'biblexg-v2': 'cuv',
  'biblexg-v2-tr': 'cuv-tr',
};

/// When a primary title set has no entry for a given chapter, the
/// service falls back to the corresponding "fallback set" if one is
/// configured here. Currently unused — was CNV → CUV until CNV was
/// removed (2026-08, ported from YsWords v1.4.0); kept as a mechanism
/// for a future version that needs the same fallback shape.
const sectionTitleFallbackSet = <String, String>{};

String sectionTitleSetFor(String version) =>
    sectionTitleSetByVersion[version] ?? '';

String? sectionTitleFallbackFor(String setId) =>
    sectionTitleFallbackSet[setId];
