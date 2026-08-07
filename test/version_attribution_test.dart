import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/bible_versions.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/version_attribution.dart';

const _locales = ['en', 'zh-Hans', 'zh-Hant'];

void main() {
  group('attribution covers the catalog', () {
    // The failure this guards against is silent: a new edition is added,
    // the Copy Center finds no key for it, and text goes out with no
    // rights line at all. Adding a version should break this test.
    test('every bundled version has an attribution key', () {
      for (final v in bibleVersions) {
        expect(
          attributionKeyFor(v.value),
          isNotNull,
          reason: '${v.value} has no licence line for the Copy Center',
        );
      }
    });

    test('every attribution key resolves in all three locales', () {
      for (final key in versionAttributionKeys.values) {
        final entry = uiStrings[key];
        expect(entry, isNotNull, reason: '$key is not in uiStrings');
        for (final l in _locales) {
          expect(entry![l], isNotNull, reason: '$key has no $l');
          expect(entry[l], isNotEmpty, reason: '$key is empty in $l');
        }
      }
    });

    test('attribution keys name no version outside the catalog', () {
      final known = {for (final v in bibleVersions) v.value};
      expect(versionAttributionKeys.keys.toSet().difference(known), isEmpty);
    });

    test('unknown versions get no line rather than a wrong one', () {
      expect(attributionKeyFor('niv'), isNull);
      expect(attributionKeyFor(''), isNull);
    });
  });

  group('copy limit', () {
    test('public-domain editions are unrestricted', () {
      expect(copyIsRestricted(['kjv']), isFalse);
      expect(copyIsRestricted(['kjv', 'bsb', 'kjvs']), isFalse);
    });

    test('one licensed edition restricts the whole copy', () {
      expect(copyIsRestricted(['nasb']), isTrue);
      // The tightest permission among the selected versions governs —
      // mixing a public-domain text in does not loosen it.
      expect(copyIsRestricted(['kjv', 'nasb']), isTrue);
      expect(copyIsRestricted(['cuvs-yhwh']), isTrue);
    });

    test('copying nothing is not restricted', () {
      expect(copyIsRestricted(const []), isFalse);
    });

    test('every unrestricted code is a real version', () {
      final known = {for (final v in bibleVersions) v.value};
      expect(unrestrictedCopyVersions.difference(known), isEmpty);
    });
  });

  group('Copy Center strings', () {
    // Every key the Copy Center asks for. Each has an English fallback
    // in the widget, so a missing entry does not crash — it silently
    // ships English into a Chinese dialog, which is exactly the kind of
    // thing that survives review.
    const keys = [
      'copyCenterTitle',
      'copyCenterMenu',
      'copyCenterCopy',
      'copyCenterPreview',
      'copyCenterEmpty',
      'copyCenterCount',
      'copyCenterLimited',
      'copyCenterScope',
      'copyScopeSelection',
      'copyScopeVerse',
      'copyScopeChapter',
      'copyScopeResults',
      'copyCenterPreset',
      'copyPresetSermon',
      'copyPresetCitation',
      'copyPresetRefList',
      'copyPresetPlain',
      'copyPresetCustom',
      'copyCenterVersions',
      'copyCenterIncludeText',
      'copyCenterReference',
      'copyRefPassage',
      'copyRefPerVerse',
      'copyRefNone',
      'copyRefBefore',
      'copyRefAfter',
      'copyBookFull',
      'copyBookShort',
      'copyCenterTemplate',
      'copyCenterTemplateHelp',
      'copyCenterText',
      'copyCenterVerseNumbers',
      'copyCenterOnePerLine',
      'copyCenterQuote',
      'copyCenterBrackets',
      'copyCenterNotes',
      'copyCenterInterleave',
      'copyCenterRefList',
      'copyCenterMerge',
      'copyCenterRefPerLine',
      'copyCenterAttribution',
    ];

    test('all present in all three locales', () {
      for (final k in keys) {
        final entry = uiStrings[k];
        expect(entry, isNotNull, reason: '$k missing');
        for (final l in _locales) {
          expect(entry![l], isNotNull, reason: '$k has no $l');
          expect(entry[l], isNotEmpty, reason: '$k is empty in $l');
        }
      }
    });

    test('the count placeholders survive translation', () {
      for (final l in _locales) {
        expect(uiStrings['copyCenterCount']![l], contains('{n}'));
        expect(uiStrings['copyCenterLimited']![l], contains('{n}'));
        expect(uiStrings['copyCenterLimited']![l], contains('{total}'));
      }
    });
  });
}
