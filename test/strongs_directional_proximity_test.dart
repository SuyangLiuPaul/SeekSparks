/// 2026-09-05: `BEFOREn`, the DIRECTIONAL proximity operator.
///
/// `docs/PARITY-BACKLOG.md` §3.1: BibleWorks writes proximity as `*n`
/// between the two words and means "A followed within n words by B".
/// Ours was `NEARn` and unordered — and the backlog's own verdict is
/// that "an unordered answer to a directional question is a different
/// result set", not a different spelling.
///
/// So the test that matters is not that `BEFORE5` parses. It is that
/// `BEFORE5` and `NEAR5` return DIFFERENT verses over the same word
/// order, and that `NEAR5` still returns exactly what it always did.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/command_draft.dart'
    hide kMaxNearDistance, kMinNearDistance;
import 'package:seeksparks/utils/command_query.dart' show CommandIssue;
import 'package:seeksparks/utils/strongs_boolean_search.dart';
import 'package:seeksparks/utils/strongs_proximity.dart';

void main() {
  const g25 = StrongsTerm(prefix: 'G', digits: '25', wildcard: false);
  const g26 = StrongsTerm(prefix: 'G', digits: '26', wildcard: false);

  // One verse's words in reading order: G26 comes FIRST, G25 second.
  // Everything below turns on that.
  const g26ThenG25 = ['G1', 'G26', 'G2', 'G25', 'G3'];
  const g25ThenG26 = ['G1', 'G25', 'G2', 'G26', 'G3'];

  group('the operator parses', () {
    test('BEFOREn and THENn are the same directional operator', () {
      for (final line in ['G25 BEFORE5 G26', 'G25 THEN5 G26']) {
        final q = parseStrongsBoolean(line);
        expect(q, isNotNull, reason: line);
        expect(q!.ops, [StrongsOp.before], reason: line);
        expect(q.nearDistance, [5], reason: line);
        expect(q.hasProximity, isTrue, reason: line);
      }
    });

    test('lower case works, as it does for every other operator', () {
      expect(parseStrongsBoolean('g25 before5 h7225')!.ops,
          [StrongsOp.before]);
    });

    test('NEARn is untouched', () {
      final q = parseStrongsBoolean('G25 NEAR5 G26')!;
      expect(q.ops, [StrongsOp.near]);
      expect(q.nearDistance, [5]);
    });

    test('the two are distinguishable after parsing, which is the point',
        () {
      expect(parseStrongsBoolean('G25 NEAR5 G26')!.ops,
          isNot(parseStrongsBoolean('G25 BEFORE5 G26')!.ops));
    });

    test('an absurd distance is refused, on the same ceiling as NEAR', () {
      expect(parseStrongsBoolean('G25 BEFORE0 G26'), isNull);
      expect(
          parseStrongsBoolean('G25 BEFORE${kMaxNearDistance + 1} G26'), isNull);
      expect(parseStrongsBoolean('G25 BEFORE$kMaxNearDistance G26'),
          isNotNull);
    });

    test('BEFORE with no distance is NAMED, not silently dropped', () {
      // Same contract `NEAR` already had: the engine refusing a query and
      // the Bible containing no such verse are different facts.
      expect(diagnoseStrongsBoolean('G25 BEFORE G26'),
          CommandIssue.strongsNearNeedsDistance);
      expect(diagnoseStrongsBoolean('G25 BEFORE99 G26'),
          CommandIssue.strongsNearDistanceOutOfRange);
    });
  });

  group('proximityPairs carries the direction', () {
    test('an unordered pair reports ordered: false', () {
      expect(proximityPairs(parseStrongsBoolean('G25 NEAR5 G26')!),
          [(a: 0, b: 1, maxWords: 5, ordered: false)]);
    });

    test('a directional pair reports ordered: true', () {
      expect(proximityPairs(parseStrongsBoolean('G25 BEFORE5 G26')!),
          [(a: 0, b: 1, maxWords: 5, ordered: true)]);
    });

    test('a line may hold both, and each keeps its own answer', () {
      final q = parseStrongsBoolean('G25 NEAR3 G26 BEFORE8 H1')!;
      expect(proximityPairs(q), [
        (a: 0, b: 1, maxWords: 3, ordered: false),
        (a: 1, b: 2, maxWords: 8, ordered: true),
      ]);
    });
  });

  group('the direction changes the answer', () {
    test('NEAR matches whichever way round the words fall', () {
      for (final verse in [g25ThenG26, g26ThenG25]) {
        expect(
            verseSatisfiesProximity(
              strongsNumbersInOrder: verse,
              termA: g25,
              termB: g26,
              maxWords: 5,
            ),
            isTrue,
            reason: '$verse');
      }
    });

    test('BEFORE matches only when the left term really is first', () {
      expect(
          verseSatisfiesProximity(
            strongsNumbersInOrder: g25ThenG26,
            termA: g25,
            termB: g26,
            maxWords: 5,
            ordered: true,
          ),
          isTrue);
      // The whole feature in one assertion: the same two words, the same
      // window, the same verse — and a different answer, because G26
      // comes first here and the query said G25 first.
      expect(
          verseSatisfiesProximity(
            strongsNumbersInOrder: g26ThenG25,
            termA: g25,
            termB: g26,
            maxWords: 5,
            ordered: true,
          ),
          isFalse);
    });

    test('reversing the terms reverses which verse matches', () {
      expect(
          verseSatisfiesProximity(
            strongsNumbersInOrder: g26ThenG25,
            termA: g26,
            termB: g25,
            maxWords: 5,
            ordered: true,
          ),
          isTrue);
    });

    test('the window still binds in the ordered case', () {
      // G25 at 0, G26 at 4 — in the right order, but five apart.
      const spread = ['G25', 'G1', 'G2', 'G3', 'G26'];
      expect(
          verseSatisfiesProximity(
            strongsNumbersInOrder: spread,
            termA: g25,
            termB: g26,
            maxWords: 3,
            ordered: true,
          ),
          isFalse);
      expect(
          verseSatisfiesProximity(
            strongsNumbersInOrder: spread,
            termA: g25,
            termB: g26,
            maxWords: 4,
            ordered: true,
          ),
          isTrue);
    });

    test('a repeated word can satisfy the ordered form in one direction',
        () {
      // G25 … G26 … G25: unordered matches either way; ordered matches
      // because SOME G25 precedes the G26, and `G26 BEFORE1 G25` matches
      // because the second G25 follows it.
      const both = ['G25', 'G26', 'G25'];
      expect(
          verseSatisfiesProximity(
              strongsNumbersInOrder: both,
              termA: g25,
              termB: g26,
              maxWords: 1,
              ordered: true),
          isTrue);
      expect(
          verseSatisfiesProximity(
              strongsNumbersInOrder: both,
              termA: g26,
              termB: g25,
              maxWords: 1,
              ordered: true),
          isTrue);
    });

    test('ordered defaults to false, so every existing caller is unmoved',
        () {
      expect(
          verseSatisfiesProximity(
            strongsNumbersInOrder: g26ThenG25,
            termA: g25,
            termB: g26,
            maxWords: 5,
          ),
          isTrue);
    });
  });

  group('the strip and the hint line', () {
    test('a BEFOREn line is recognised as a finished window', () {
      final d = analyseCommandDraft('G25 BEFORE5 G26');
      expect(d.hint, CommandDraftHint.nearWindow);
      expect(d.near?.distance, 5);
      expect(d.near?.keyword.toUpperCase(), 'BEFORE');
    });

    test('the hint line does NOT say "either order" for BEFORE', () {
      final before = describeCommandDraft(
          analyseCommandDraft('G25 BEFORE5 G26'), 'en')!;
      final near =
          describeCommandDraft(analyseCommandDraft('G25 NEAR5 G26'), 'en')!;
      expect(near, contains('either order'));
      expect(before, isNot(contains('either order')));
      expect(before, isNot(equals(near)));
    });

    test('the distinction is worded in all three locales', () {
      for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
        final before = describeCommandDraft(
            analyseCommandDraft('G25 BEFORE5 G26'), locale);
        final near = describeCommandDraft(
            analyseCommandDraft('G25 NEAR5 G26'), locale);
        expect(before, isNotNull, reason: locale);
        expect(near, isNotNull, reason: locale);
        expect(before, isNot(equals(near)), reason: locale);
      }
    });

    test('the distance stepper rewrites a BEFORE token in place', () {
      const line = 'G25 BEFORE5 G26';
      final token = analyseCommandDraft(line).near!;
      expect(withNearDistance(line, token, 9), 'G25 BEFORE9 G26');
    });

    test('BEFORE between two ordinary words offers the exact phrase '
        'rewrite', () {
      // `'yahweh *4 god` is ordered, and so is BEFORE5 — which makes this
      // the one operator the two grammars translate between exactly.
      expect(suggestTextEquivalent(['yahweh', 'BEFORE5', 'god']),
          "'yahweh *4 god");
      // NEAR reaches the same line, and the caller has to say it is only
      // half the operator; that behaviour is unchanged.
      expect(suggestTextEquivalent(['yahweh', 'NEAR5', 'god']),
          "'yahweh *4 god");
    });
  });
}
