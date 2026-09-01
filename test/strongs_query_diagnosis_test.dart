// #295: `G25 NEAR G26` used to fall through parseStrongsBoolean's null
// return all the way to the literal text scan, which found nothing — the
// reader saw "no results" for a query the engine actually REFUSED to run.
// diagnoseStrongsBoolean names the refusal so the app can say so instead
// of silently pretending it was an empty search.
//
// It is deliberately narrow: one unrecognised token (`H1 will`,
// `G25 AND love`) and it defers to null, leaving the line as plain text.
// A false refusal would take a working text search away from a reader who
// never meant to write a Strong's expression at all.
import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/utils/command_query.dart';
import 'package:seeksparks/utils/strongs_boolean_search.dart';

void main() {
  group('diagnoseStrongsBoolean names the refusal', () {
    test('NEAR / WITHIN with no distance', () {
      expect(diagnoseStrongsBoolean('G25 NEAR G26'),
          CommandIssue.strongsNearNeedsDistance);
      expect(diagnoseStrongsBoolean('G25 WITHIN G26'),
          CommandIssue.strongsNearNeedsDistance);
    });

    test('NEAR distance out of range', () {
      expect(diagnoseStrongsBoolean('G25 NEAR0 G26'),
          CommandIssue.strongsNearDistanceOutOfRange);
      expect(diagnoseStrongsBoolean('G25 NEAR99 G26'),
          CommandIssue.strongsNearDistanceOutOfRange);
    });

    test('an operator with no term on one side', () {
      expect(diagnoseStrongsBoolean('G25 AND'),
          CommandIssue.strongsOperatorNeedsTerms);
      expect(diagnoseStrongsBoolean('G25 NEAR5'),
          CommandIssue.strongsOperatorNeedsTerms);
      expect(diagnoseStrongsBoolean('AND G25'),
          CommandIssue.strongsOperatorNeedsTerms);
      expect(diagnoseStrongsBoolean('G25 AND AND G26'),
          CommandIssue.strongsOperatorNeedsTerms);
    });

    test('a Strong\'s number out of range', () {
      expect(diagnoseStrongsBoolean('G9999 AND G26'),
          CommandIssue.strongsNumberOutOfRange);
      expect(diagnoseStrongsBoolean('G25 AND H9999'),
          CommandIssue.strongsNumberOutOfRange);
    });

    test('a wildcard term does not escape the NEAR check', () {
      // G25* NEAR G26 also carries a `*`, which is why the diagnosis must
      // run BEFORE wildcard-promotion in the provider — otherwise this
      // line is rewritten into a wildcard TEXT search instead.
      expect(diagnoseStrongsBoolean('G25* NEAR G26'),
          CommandIssue.strongsNearNeedsDistance);
    });
  });

  group('it keeps its hands off everything else', () {
    test('ordinary text, even when it starts with a Strong\'s-shaped word',
        () {
      for (final q in [
        'H1 will',
        'G25 AND love',
        'love god',
        'in the beginning',
        'Genesis 1:1',
        'kjv',
        '',
        '   ',
      ]) {
        expect(diagnoseStrongsBoolean(q), isNull, reason: q);
      }
    });

    test('a single Strong\'s number is the single-lexicon path', () {
      expect(diagnoseStrongsBoolean('G25'), isNull);
      expect(diagnoseStrongsBoolean('H157'), isNull);
    });

    test('anything that actually parses is left alone', () {
      for (final q in [
        'G25 AND G26',
        'G25 OR G26',
        'G25 NEAR5 G26',
        'G25*',
        'G25 G26 G27',
        'G25 !G26',
      ]) {
        expect(parseStrongsBoolean(q), isNotNull,
            reason: '$q should parse — diagnosis and parse must agree');
        expect(diagnoseStrongsBoolean(q), isNull, reason: q);
      }
    });
  });

  group('every new issue is worded in all three languages', () {
    const issues = [
      CommandIssue.strongsNearNeedsDistance,
      CommandIssue.strongsNearDistanceOutOfRange,
      CommandIssue.strongsOperatorNeedsTerms,
      CommandIssue.strongsNumberOutOfRange,
    ];

    for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
      test('locale $locale', () {
        for (final issue in issues) {
          final msg = describeCommandIssue(issue, locale);
          expect(msg, isNotNull, reason: '$issue / $locale');
          expect(msg, isNotEmpty, reason: '$issue / $locale');
          if (issue == CommandIssue.strongsNearDistanceOutOfRange) {
            expect(msg, isNot(contains('{max}')));
            expect(msg, contains('50'));
          }
          if (issue == CommandIssue.strongsNumberOutOfRange) {
            expect(msg, isNot(contains('{g}')));
            expect(msg, isNot(contains('{h}')));
            expect(msg, contains('5700'));
            expect(msg, contains('8700'));
          }
        }
      });
    }
  });

  test('the range constants match what the parser enforces', () {
    expect(kMaxNearDistance, 50);
    expect(kMaxGreekStrongs, 5700);
    expect(kMaxHebrewStrongs, 8700);
  });

  test('every new key exists in every language (guards uiStrings)', () {
    for (final key in [
      'cmdIssueNearNoDistance',
      'cmdIssueNearRange',
      'cmdIssueStrongsOperator',
      'cmdIssueStrongsRange',
    ]) {
      expect(uiStrings[key], isNotNull, reason: key);
      for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
        expect(uiStrings[key]![locale], isNotNull, reason: '$key/$locale');
      }
    }
  });
}
