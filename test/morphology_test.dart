/// 2026-08 (SeekSparks): pins the morphology decoder.
///
/// Every code below is a REAL code taken from the merged assets, so the
/// tests double as documentation of what the shipped data looks like.
/// A wrong parse is worse than no parse — this is the guard for that.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/morphology.dart';

void main() {
  group('Greek — MorphGNT codes', () {
    test('finite verb puts number with person, not with case', () {
      // John 3:16 ἠγάπησεν
      expect(describeMorphology('V-3AAI-S--', 'en'),
          'verb · aorist active indicative · 3rd person singular');
    });

    test('article declines: case number gender', () {
      // John 3:16 ὁ
      expect(describeMorphology('RA----NSM-', 'en'),
          'article · nominative singular masculine');
    });

    test('noun declines the same way', () {
      // John 3:16 Θεὸς / κόσμον
      expect(describeMorphology('N-----NSM-', 'en'),
          'noun · nominative singular masculine');
      expect(describeMorphology('N-----ASM-', 'en'),
          'noun · accusative singular masculine');
    });

    test('participle keeps BOTH the verbal and the nominal parse', () {
      expect(describeMorphology('V--PAPNSM-', 'en'),
          'verb · present active participle · nominative singular masculine');
      expect(describeMorphology('V--XPPNSM-', 'en'),
          'verb · perfect passive participle · nominative singular masculine');
    });

    test('indeclinable words reduce to their part of speech', () {
      expect(describeMorphology('D---------', 'en'), 'adverb');
      expect(describeMorphology('C---------', 'en'), 'conjunction');
      expect(describeMorphology('P---------', 'en'), 'preposition');
    });

    test('comparative/superlative degree is carried through', () {
      expect(describeMorphology('A-----NSM-', 'en'),
          'adjective · nominative singular masculine');
      expect(describeMorphology('A-----NSMC', 'en'),
          'adjective · nominative singular masculine · comparative');
    });

    test('Chinese labels join without spaces', () {
      expect(describeMorphology('N-----NSM-', 'zh-Hans'), '名词 · 主格单数阳性');
      expect(describeMorphology('N-----NSM-', 'zh-Hant'), '名詞 · 主格單數陽性');
      expect(describeMorphology('V-3AAI-S--', 'zh-Hans'),
          '动词 · 简单过去时主动直说语气 · 第三人称单数');
    });
  });

  group('Hebrew — Open Scriptures codes', () {
    test('prefix morphemes are shown, not dropped', () {
      // Genesis 1:1 בְּרֵאשִׁית — preposition + noun
      expect(describeMorphology('HR/Ncfsa', 'en'),
          'preposition + noun common feminine singular absolute');
    });

    test('finite verb reads stem, conjugation, person gender number', () {
      // Genesis 1:1 בָּרָא
      expect(describeMorphology('HVqp3ms', 'en'),
          'Qal perfect 3rd person masculine singular');
    });

    test('bare noun', () {
      // Genesis 1:1 אֱלֹהִים
      expect(describeMorphology('HNcmpa', 'en'),
          'noun common masculine plural absolute');
    });

    test('particles decode to their type', () {
      // Genesis 1:1 אֵת — direct object marker
      expect(describeMorphology('HTo', 'en'), 'object marker');
      // הַשָּׁמַיִם — article + noun
      expect(describeMorphology('HTd/Ncmpa', 'en'),
          'definite article + noun common masculine plural absolute');
      // וְאֵת — conjunction + object marker
      expect(describeMorphology('HC/To', 'en'), 'conjunction + object marker');
    });

    test('participles inflect for gender number state, not person', () {
      expect(describeMorphology('HVqrmsa', 'en'),
          'Qal active participle masculine singular absolute');
    });

    test('Aramaic is labelled as such', () {
      // Daniel is partly Aramaic.
      expect(describeMorphology('ANcmsa', 'en'),
          'Aramaic · noun common masculine singular absolute');
    });

    test('Chinese Hebrew labels', () {
      expect(describeMorphology('HNcmpa', 'zh-Hant'), '名詞普通陽性複數獨立式');
    });
  });

  group('part-of-speech shorthand', () {
    test('reads the leading code only', () {
      expect(morphologyPartOfSpeech('V-3AAI-S--', 'en'), 'verb');
      expect(morphologyPartOfSpeech('HVqp3ms', 'en'), 'verb');
      expect(morphologyPartOfSpeech('HR/Ncfsa', 'en'), 'preposition');
      expect(morphologyPartOfSpeech('RA----NSM-', 'en'), 'article');
    });
  });

  group('degrades safely instead of throwing', () {
    test('null / empty input', () {
      expect(describeMorphology(null, 'en'), isNull);
      expect(describeMorphology('', 'en'), isNull);
      expect(describeMorphology('   ', 'en'), isNull);
      expect(morphologyPartOfSpeech(null, 'en'), isNull);
    });

    test('truncated and unknown codes never throw', () {
      for (final code in ['V', 'H', 'A', 'N-', 'HV', 'H/', 'ZZZZ', '?']) {
        expect(() => describeMorphology(code, 'en'), returnsNormally,
            reason: 'code "$code" must not throw');
        expect(() => morphologyPartOfSpeech(code, 'en'), returnsNormally);
      }
    });

    test('an unrecognised code falls back to showing itself', () {
      expect(describeMorphology('ZZ--------', 'en'), 'ZZ--------');
    });
  });
}
