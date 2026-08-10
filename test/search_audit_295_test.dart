// #295: the three defects the LIVE search audit found that 447 passing
// search tests did not, pinned as pure unit tests.
//
// The audit drove the deployed dev build over CDP because `flutter test`
// has no DOM text field and no rendered header; these tests cover the
// logic underneath each fix so a regression fails here first.

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/utils/command_query.dart'
    show needsWildcardPromotion, parseCommandQuery, CommandKind;
import 'package:seeksparks/utils/command_verb.dart';
import 'package:seeksparks/utils/strongs_result_counts.dart';
import 'package:seeksparks/utils/version_abbreviation.dart';

void main() {
  group('a Strong\'s header reports both units and claims neither falsely',
      () {
    test('H3068 (יהוה): 5,522 verses, 6,521 occurrences, both complete', () {
      // The verse list stopped at 500 until v1.6.96, and the header
      // inferred truncation from a list that reached the cap. With the
      // cap gone that inference would fire on all 123 formerly capped
      // entries and say "first 500 verses listed" about a complete list.
      final c = strongsResultCounts(versesShown: 5522, occurrences: 6521);
      expect(c.truncated, isFalse);
      expect(c.occurrences, 6521);
      expect(c.verses, 5522);
    });

    test('hits exceeding verses is normal, not a sign of truncation', () {
      // G25 really does occur 143 times in 110 verses.
      final c = strongsResultCounts(versesShown: 110, occurrences: 143);
      expect(c.truncated, isFalse);
      expect(c.occurrences, 143);
    });

    test('a composed expression has verses but no occurrence total', () {
      // A set operation over verse lists: one verse can carry several
      // hits of each term, so the two totals cannot be added.
      final c = strongsResultCounts(versesShown: 335);
      expect(c.verses, 335);
      expect(c.occurrences, isNull);
      expect(c.truncated, isFalse);
    });

    test('a cut wildcard expansion makes the verse count a floor', () {
      // The one incompleteness that survives the uncapping: `G1✶` matches
      // 1,067 numbers and only the first 300 are unioned, so the result
      // stands for less than the query named.
      final c = strongsResultCounts(versesShown: 4210, incomplete: true);
      expect(c.truncated, isTrue);
      expect(c.verses, 4210);
    });

    test('under a search limit the Bible-wide total is withheld', () {
      // Printing 6,521 next to a list narrowed to Genesis would read as
      // the scope's own total.
      final c = strongsResultCounts(
        versesShown: 12,
        occurrences: 6521,
        scoped: true,
      );
      expect(c.verses, 12);
      expect(c.occurrences, isNull);
      expect(c.truncated, isFalse);
    });

    test('a scoped result still admits a cut wildcard', () {
      final c = strongsResultCounts(
        versesShown: 12,
        occurrences: 6521,
        scoped: true,
        incomplete: true,
      );
      expect(c.occurrences, isNull);
      expect(c.truncated, isTrue);
    });

    test('thousands grouping', () {
      expect(groupThousands(0), '0');
      expect(groupThousands(500), '500');
      expect(groupThousands(6521), '6,521');
      expect(groupThousands(19859), '19,859');
    });
  });

  group('bare wildcard is promoted to an AND search', () {
    test('faith* — the tooltip\'s own example', () {
      expect(needsWildcardPromotion('faith*'), isTrue);
      final parsed = parseCommandQuery('.faith*');
      expect(parsed.isCommand, isTrue);
      expect(parsed.query?.kind, CommandKind.and);
    });

    test('a line already carrying a control character is left alone', () {
      for (final q in ['.faith*', '/faith*', "'faith*", ';faith*']) {
        expect(needsWildcardPromotion(q), isFalse, reason: q);
      }
    });

    test('no asterisk, no promotion', () {
      expect(needsWildcardPromotion('faith'), isFalse);
      expect(needsWildcardPromotion(''), isFalse);
      expect(needsWildcardPromotion('   '), isFalse);
    });

    test('an all-asterisk line is not a search', () {
      expect(needsWildcardPromotion('*'), isFalse);
      expect(needsWildcardPromotion('***'), isFalse);
      expect(needsWildcardPromotion(' * * '), isFalse);
    });

    test('question marks are left to the substring scan', () {
      // Scripture is full of them; `who is this?` is a search someone
      // may well have meant literally.
      expect(needsWildcardPromotion('who is this?'), isFalse);
    });
  });

  group('version abbreviations', () {
    // The live version list, as the dev build reports it.
    const versions = {
      'kjv': 'KJV',
      'leb': 'LEB',
      'nasb': 'NASB',
      'bsb': 'BSB',
      'kjvs': 'KJV+S',
      'lxxwh': 'LXX+WH',
      'cuvs': '雅简+',
    };

    test('nas resolves to NASB — the case the audit caught failing', () {
      expect(matchVersionAbbreviation('nas', versions), 'nasb');
    });

    test('exact wins over prefix, so kjv never drifts to KJV+S', () {
      expect(matchVersionAbbreviation('kjv', versions), 'kjv');
      expect(matchVersionAbbreviation('KJV', versions), 'kjv');
    });

    test('an ambiguous prefix resolves to nothing', () {
      // `l` is also the scope verb, and LEB/LXX+WH both start with it.
      expect(matchVersionAbbreviation('l', versions), isNull);
      expect(matchVersionAbbreviation('lx', versions), isNull);
      expect(matchVersionAbbreviation('lxx', versions), 'lxxwh');
    });

    test('short prefixes stay available to the command verbs', () {
      expect(matchVersionAbbreviation('b', versions), isNull);
      expect(matchVersionAbbreviation('bs', versions), isNull);
      expect(matchVersionAbbreviation('bsb', versions), 'bsb');
    });

    test('a non-version falls through', () {
      expect(matchVersionAbbreviation('zzz', versions), isNull);
      expect(matchVersionAbbreviation('', versions), isNull);
      expect(matchVersionAbbreviation('kjv leb', versions), isNull);
    });

    test('matching on the short label, not just the code', () {
      expect(matchVersionAbbreviation('lxx+wh', versions), 'lxxwh');
      expect(matchVersionAbbreviation('雅简+', versions), 'cuvs');
    });
  });

  group('the d verb resolves abbreviations too', () {
    // The audit's `d nas` went through VerbContext, not the command
    // pane's own matcher — two copies of the same exact-only comparison,
    // and fixing one left the live defect standing.
    const registry = [
      VerbVersion(code: 'kjv', label: 'KJV', language: 'en'),
      VerbVersion(code: 'nasb', label: 'NASB', language: 'en'),
      VerbVersion(code: 'bsb', label: 'BSB', language: 'en'),
      VerbVersion(code: 'lxxwh', label: 'LXX/WH', language: 'grc'),
    ];
    final ctx = VerbContext(
      versions: registry,
      searchVersion: 'kjv',
      displayVersions: const ['kjv'],
      currentEnglishBook: 'John',
      currentChapter: 3,
    );

    test('nas resolves to NASB', () {
      expect(ctx.resolveVersion('nas'), 'nasb');
      expect(parseCommandVerb('d nas', ctx).verb?.kind,
          CommandVerbKind.displayAdd);
    });

    test('an unknown edition is still refused', () {
      expect(ctx.resolveVersion('niv'), isNull);
      expect(parseCommandVerb('d niv', ctx).issue,
          CommandVerbIssue.unknownVersion);
    });

    test('exact still wins and short prefixes are left alone', () {
      expect(ctx.resolveVersion('kjv'), 'kjv');
      expect(ctx.resolveVersion('b'), isNull);
    });
  });
}
