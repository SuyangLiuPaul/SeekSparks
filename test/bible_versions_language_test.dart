import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/bible_versions.dart';

/// 2026-06-22: guards for the language-grouped version picker.
/// The picker groups the ~14 editions under English / 繁體 / 简体 tabs,
/// so the `language` metadata and the grouping helpers must stay
/// consistent with the catalog.
void main() {
  // 2026-08-07: `grc` joined them with the Eagle's View LXX+WH import —
  // the first original-language column the picker has ever carried.
  const validLanguages = {'en', 'zh-Hant', 'zh-Hans', 'grc'};

  test('every available version declares a valid language', () {
    for (final v in availableVersions) {
      expect(validLanguages.contains(v.language), isTrue,
          reason: '${v.value} has invalid language "${v.language}"');
    }
  });

  test('language matches the naming convention', () {
    const english = {'kjv', 'leb', 'nasb', 'bsb', 'kjvs'};
    const greek = {'lxxwh'};
    for (final v in bibleVersions) {
      if (greek.contains(v.value)) {
        expect(v.language, 'grc', reason: '${v.value} should be Greek');
      } else if (english.contains(v.value)) {
        expect(v.language, 'en', reason: '${v.value} should be English');
      } else if (v.value.endsWith('-tr')) {
        expect(v.language, 'zh-Hant',
            reason: '${v.value} should be Traditional');
      } else {
        expect(v.language, 'zh-Hans',
            reason: '${v.value} should be Simplified');
      }
    }
  });

  test('bibleLanguageOrder lists every language that has versions', () {
    expect(bibleLanguageOrder, ['en', 'zh-Hant', 'zh-Hans', 'grc']);
    for (final lang in bibleLanguageOrder) {
      expect(versionsForLanguage(lang), isNotEmpty);
    }
  });

  test('every available version belongs to exactly one language group', () {
    final grouped = <String>[];
    for (final lang in bibleLanguageOrder) {
      grouped.addAll(versionsForLanguage(lang).map((v) => v.value));
    }
    expect(grouped.toSet(), availableVersions.map((v) => v.value).toSet());
    // No duplicates across groups.
    expect(grouped.length, grouped.toSet().length);
  });

  test('versionsForLanguage returns the expected editions', () {
    // 2026-09-02: `leb` and `nasb` used to be asserted here. They are
    // still in the catalog and their assets still ship — they are hidden
    // (see `disabledVersions`), and `versionsForLanguage` is what fills
    // the picker's English tab, so they must not come back out of it.
    expect(versionsForLanguage('en').map((v) => v.value),
        containsAll(<String>['kjv', 'bsb', 'kjvs']));
    expect(versionsForLanguage('en').map((v) => v.value),
        isNot(anyOf(contains('leb'), contains('nasb'))));
    expect(versionsForLanguage('zh-Hans').map((v) => v.value),
        containsAll(<String>['cuvs-yhwh', 'biblexg-v2', 'cuvs-plus']));
    expect(versionsForLanguage('zh-Hant').map((v) => v.value),
        containsAll(<String>['cuvs-yhwh-tr', 'biblexg-v2-tr']));
  });

  test(
      'cuv/cnv/biblexg(v1) were removed outright — no longer resolve at all',
      () {
    // 2026-08 (ported from YsWords v1.4.0): these versions used to be
    // hidden-but-resolvable (see git history); now deleted entirely —
    // superseded by cuvs-yhwh / biblexg-v2. Old shared links using these
    // codes no longer resolve, which is the explicit product choice.
    const removed = <String>[
      'cuv', 'cuv-tr',
      'cnv', 'cnv-tr',
      'biblexg', 'biblexg-tr',
    ];
    final allCodes = bibleVersions.map((v) => v.value).toSet();
    for (final code in removed) {
      expect(allCodes.contains(code), isFalse,
          reason: '$code should no longer exist in the catalog at all');
    }
    // 2026-09-02: the mechanism is no longer unused. NASB and LEB are
    // hidden from the interface at the owner's instruction while their
    // assets stay bundled and deployed — which is precisely the case
    // `disabledVersions` exists for, and the opposite of the outright
    // removal the rest of this test covers. Pinned exactly, so a third
    // edition cannot be hidden without someone saying so here.
    expect(disabledVersions, <String>{'nasb', 'leb'},
        reason: 'hiding an edition is a product decision, not a detail — '
            'it belongs in a diff someone reads');
  });

  test('bibleVersionLanguage resolves known codes + falls back safely', () {
    expect(bibleVersionLanguage('nasb'), 'en');
    expect(bibleVersionLanguage('cuvs-yhwh'), 'zh-Hans');
    expect(bibleVersionLanguage('cuvs-yhwh-tr'), 'zh-Hant');
    // Unknown code falls back to the primary audience, never throws.
    expect(bibleVersionLanguage('does-not-exist'), 'zh-Hans');
  });

  test('the locale-default versions are ones a reader can also pick', () {
    // Mirrors MainProvider.restoreState fresh-install defaults:
    //   en → bsb, zh-Hant → cuvs-yhwh-tr, zh-Hans → cuvs-yhwh.
    //
    // 2026-09-02: this asked `bibleVersions` — the raw catalog — which
    // was the weaker question. `nasb` satisfied it right up to the day
    // it was hidden, and a locale default nobody can find in the picker
    // is exactly the state that would have shipped. `availableVersions`
    // is what the picker offers, so that is what a default has to be in.
    final codes = availableVersions.map((v) => v.value).toSet();
    expect(codes, containsAll(<String>['bsb', 'cuvs-yhwh-tr', 'cuvs-yhwh']));
    for (final locale in const ['en', 'zh-Hant', 'zh-Hans', 'fr', '']) {
      expect(codes.contains(localeDefaultVersion(locale)), isTrue,
          reason: '$locale opens on an edition the picker does not offer');
    }
  });
}
