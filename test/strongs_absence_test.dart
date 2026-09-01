/// #295: an empty single-Strong's result must say WHICH kind of empty.
///
/// "No results found" was one sentence for three different facts: a
/// number that is not Strong's at all, a real number nothing in our
/// tagged text uses, and a number the `l` search limit excluded. The
/// third is #280's rule again — a scope must never narrow silently.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/strongs_absence.dart';

void main() {
  group('classifyStrongsAbsence', () {
    test('a number outside Strong\'s numbering is named as such', () {
      expect(
          classifyStrongsAbsence(
              label: 'G9999', corpusVerses: null, shownVerses: 0, scoped: false),
          StrongsAbsence.unknownNumber);
    });

    test('the boundary is the last number the lexicon holds', () {
      // greek.json tops out at G5624, hebrew.json at H8674 — measured
      // off the two assets this app ships, not looked up.
      StrongsAbsence? c(String n) => classifyStrongsAbsence(
          label: n, corpusVerses: null, shownVerses: 0, scoped: false);
      expect(c('G5624'), StrongsAbsence.notInCorpus);
      expect(c('G5625'), StrongsAbsence.unknownNumber);
      expect(c('H8674'), StrongsAbsence.notInCorpus);
      expect(c('H8675'), StrongsAbsence.unknownNumber);
    });

    test('G0 is not a Strong\'s number, and leading zeros are stripped', () {
      expect(
          classifyStrongsAbsence(
              label: 'G0', corpusVerses: null, shownVerses: 0, scoped: false),
          StrongsAbsence.unknownNumber);
      expect(
          classifyStrongsAbsence(
              label: 'G0025', corpusVerses: 110, shownVerses: 0, scoped: true),
          StrongsAbsence.outsideScope);
    });

    test('a real number the tagged text never uses', () {
      // 199 Greek and 34 Hebrew lexicon entries sit in this position:
      // a dictionary entry with no occurrence in our corpus. G33 is one.
      expect(
          classifyStrongsAbsence(
              label: 'G33', corpusVerses: null, shownVerses: 0, scoped: false),
          StrongsAbsence.notInCorpus);
    });

    test('a scope that emptied the list is not an empty Bible', () {
      // Measured: G25 is 143 occurrences in 110 verses, none in Genesis.
      expect(
          classifyStrongsAbsence(
              label: 'G25', corpusVerses: 110, shownVerses: 0, scoped: true),
          StrongsAbsence.outsideScope);
    });

    test('unscoped and empty is unreachable, so it says nothing', () {
      expect(
          classifyStrongsAbsence(
              label: 'G25', corpusVerses: 110, shownVerses: 0, scoped: false),
          isNull);
    });

    test('a result with rows is not an absence', () {
      expect(
          classifyStrongsAbsence(
              label: 'G25', corpusVerses: 110, shownVerses: 110, scoped: false),
          isNull);
    });

    test('a composed expression is declined, not guessed at', () {
      for (final q in ['G25 AND G26', 'G25*', 'love', '', 'G12345']) {
        expect(
            classifyStrongsAbsence(
                label: q, corpusVerses: null, shownVerses: 0, scoped: false),
            isNull,
            reason: 'must not adjudicate "$q"');
      }
    });
  });

  group('describeStrongsAbsence', () {
    test('each locale words all three, with no placeholder left behind', () {
      for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
        for (final a in StrongsAbsence.values) {
          final s = describeStrongsAbsence(a, locale,
              label: 'G25',
              corpusVerses: 110,
              corpusOccurrences: 143,
              scopeLabel: 'Genesis');
          expect(s, isNotNull, reason: '$a in $locale');
          expect(s, isNotEmpty, reason: '$a in $locale');
          expect(s, contains('G25'), reason: '$a in $locale');
          // Catches an unreplaced {n}/{range}/{occ}/{verses}/{scope} in
          // any of the twelve strings.
          expect(s, isNot(contains('{')), reason: '$a in $locale');
        }
      }
    });

    test('the scoped sentence carries both units and the scope', () {
      final s = describeStrongsAbsence(StrongsAbsence.outsideScope, 'en',
          label: 'G25',
          corpusVerses: 110,
          corpusOccurrences: 143,
          scopeLabel: 'Genesis')!;
      expect(s, contains('143'));
      expect(s, contains('110'));
      expect(s, contains('Genesis'));
    });

    test('a four-digit total is grouped', () {
      // H430, measured: 2,600 occurrences in 2,246 verses.
      final s = describeStrongsAbsence(StrongsAbsence.outsideScope, 'en',
          label: 'H430',
          corpusVerses: 2246,
          corpusOccurrences: 2600,
          scopeLabel: 'Genesis')!;
      expect(s, contains('2,600'));
      expect(s, contains('2,246'));
    });

    test('a blank scope label falls back rather than printing nothing', () {
      for (final scope in [null, '', '   ']) {
        final s = describeStrongsAbsence(StrongsAbsence.outsideScope, 'en',
            label: 'G25',
            corpusVerses: 110,
            corpusOccurrences: 143,
            scopeLabel: scope);
        expect(s, contains('the current search limit'));
      }
    });

    test('a missing count produces no sentence at all', () {
      // A missing number must never become a wrong number.
      expect(
          describeStrongsAbsence(StrongsAbsence.outsideScope, 'en',
              label: 'G25', corpusVerses: 110, corpusOccurrences: null),
          isNull);
      expect(
          describeStrongsAbsence(StrongsAbsence.outsideScope, 'en',
              label: 'G25', corpusVerses: null, corpusOccurrences: 143),
          isNull);
    });

    test('the range printed matches the prefix', () {
      final g = describeStrongsAbsence(StrongsAbsence.unknownNumber, 'en',
          label: 'G9999')!;
      expect(g, contains('G1–G5624'));
      expect(g, isNot(contains('H1–')));
      final h = describeStrongsAbsence(StrongsAbsence.unknownNumber, 'en',
          label: 'H9999')!;
      expect(h, contains('H1–H8674'));
    });
  });
}
