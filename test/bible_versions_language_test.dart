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
    expect(versionsForLanguage('en').map((v) => v.value),
        containsAll(<String>['kjv', 'leb', 'nasb']));
    expect(versionsForLanguage('zh-Hans').map((v) => v.value),
        containsAll(<String>['cuvs-yhwh', 'biblexg-v2', 'cuv-yhwd']));
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
    expect(disabledVersions, isEmpty,
        reason: 'nothing should be hidden — the mechanism is unused '
            'until a future version needs it');
  });

  test('bibleVersionLanguage resolves known codes + falls back safely', () {
    expect(bibleVersionLanguage('nasb'), 'en');
    expect(bibleVersionLanguage('cuvs-yhwh'), 'zh-Hans');
    expect(bibleVersionLanguage('cuvs-yhwh-tr'), 'zh-Hant');
    // Unknown code falls back to the primary audience, never throws.
    expect(bibleVersionLanguage('does-not-exist'), 'zh-Hans');
  });

  test('the locale-default versions exist in the catalog', () {
    // Mirrors MainProvider.restoreState fresh-install defaults:
    //   en → nasb, zh-Hant → cuvs-yhwh-tr, zh-Hans → cuvs-yhwh.
    final codes = bibleVersions.map((v) => v.value).toSet();
    expect(codes, containsAll(<String>['nasb', 'cuvs-yhwh-tr', 'cuvs-yhwh']));
  });
}
