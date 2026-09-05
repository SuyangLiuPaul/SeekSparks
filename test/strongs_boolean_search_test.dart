// 2026-06-18 (v1.3.91): tests for the boolean Strong's-search logic.
import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/strongs_boolean_search.dart';

void main() {
  group('parseStrongsBoolean', () {
    test('single plain number is NOT boolean (null → single-entry path)', () {
      expect(parseStrongsBoolean('G2664'), isNull);
      expect(parseStrongsBoolean('  H7225 '), isNull);
    });

    test('single wildcard term parses', () {
      final q = parseStrongsBoolean('G25*')!;
      expect(q.terms.length, 1);
      expect(q.terms.first.wildcard, true);
      expect(q.terms.first.number, 'G25');
      expect(q.ops, isEmpty);
    });

    test('explicit AND', () {
      final q = parseStrongsBoolean('G25 AND G26')!;
      expect(q.terms.map((t) => t.number).toList(), ['G25', 'G26']);
      expect(q.ops, [StrongsOp.and]);
    });

    test('explicit OR, case-insensitive', () {
      final q = parseStrongsBoolean('g25 or H7225')!;
      expect(q.terms.map((t) => t.number).toList(), ['G25', 'H7225']);
      expect(q.ops, [StrongsOp.or]);
    });

    test('adjacent terms imply AND', () {
      final q = parseStrongsBoolean('G25 G26 G27')!;
      expect(q.terms.length, 3);
      expect(q.ops, [StrongsOp.and, StrongsOp.and]);
    });

    test('symbol operators & | + /', () {
      expect(parseStrongsBoolean('G25 & G26')!.ops, [StrongsOp.and]);
      expect(parseStrongsBoolean('G25 | G26')!.ops, [StrongsOp.or]);
      expect(parseStrongsBoolean('G25 + G26')!.ops, [StrongsOp.and]);
      expect(parseStrongsBoolean('G25 / G26')!.ops, [StrongsOp.or]);
    });

    test('leading zeros stripped', () {
      expect(parseStrongsBoolean('G0025 AND G0026')!.terms.first.number, 'G25');
    });

    test('mixed AND/OR keeps order for left-to-right eval', () {
      final q = parseStrongsBoolean('G25 AND G26 OR G27')!;
      expect(q.ops, [StrongsOp.and, StrongsOp.or]);
    });

    test('non-Strong text aborts (→ null, falls back to text search)', () {
      expect(parseStrongsBoolean('love AND faith'), isNull);
      expect(parseStrongsBoolean('G25 AND love'), isNull);
      expect(parseStrongsBoolean('John 3:16'), isNull);
    });

    test('trailing / dangling operator is invalid', () {
      expect(parseStrongsBoolean('G25 AND'), isNull);
      expect(parseStrongsBoolean('AND G25'), isNull);
    });

    test('out-of-range numbers rejected', () {
      expect(parseStrongsBoolean('G99999 AND G26'), isNull);
      expect(parseStrongsBoolean('H99999 OR H1'), isNull);
    });

    test('NOT operator, word and symbol form', () {
      final q1 = parseStrongsBoolean('G25 NOT G26')!;
      expect(q1.ops, [StrongsOp.not]);
      final q2 = parseStrongsBoolean('G25 ! G26')!;
      expect(q2.ops, [StrongsOp.not]);
    });

    test('NOT is case-insensitive', () {
      expect(parseStrongsBoolean('g25 not h7225')!.ops, [StrongsOp.not]);
    });

    test('NEARn operator parses distance, NEAR and WITHIN both work', () {
      final q1 = parseStrongsBoolean('G25 NEAR5 G26')!;
      expect(q1.ops, [StrongsOp.near]);
      expect(q1.nearDistance, [5]);
      final q2 = parseStrongsBoolean('G25 WITHIN10 G26')!;
      expect(q2.ops, [StrongsOp.near]);
      expect(q2.nearDistance, [10]);
    });

    test('NEAR is case-insensitive', () {
      final q = parseStrongsBoolean('g25 near3 h7225')!;
      expect(q.ops, [StrongsOp.near]);
      expect(q.nearDistance, [3]);
    });

    test('NEAR distance out of range rejected', () {
      expect(parseStrongsBoolean('G25 NEAR0 G26'), isNull);
      expect(parseStrongsBoolean('G25 NEAR51 G26'), isNull);
    });

    test('hasProximity reflects presence of a NEAR op', () {
      expect(parseStrongsBoolean('G25 AND G26')!.hasProximity, false);
      expect(parseStrongsBoolean('G25 NEAR5 G26')!.hasProximity, true);
    });

    test('mixed AND/NOT/NEAR keeps parallel nearDistance list', () {
      final q = parseStrongsBoolean('G25 AND G26 NOT G27 NEAR4 H100')!;
      expect(q.ops, [StrongsOp.and, StrongsOp.not, StrongsOp.near]);
      expect(q.nearDistance, [null, null, 4]);
    });
  });

  group('evaluateStrongsBoolean (set algebra)', () {
    // Stub occurrence sets per term.
    final data = {
      'G25': {'John 3:16', 'Romans 5:8', '1 John 4:8'},
      'G26': {'Romans 5:8', '1 John 4:8', 'John 13:35'},
      'G27': {'1 John 4:8'},
    };
    Set<String> refsFor(StrongsTerm t) => {...?data[t.number]};

    test('AND = intersection', () {
      final q = parseStrongsBoolean('G25 AND G26')!;
      expect(evaluateStrongsBoolean(q, refsFor),
          {'Romans 5:8', '1 John 4:8'});
    });

    test('OR = union', () {
      final q = parseStrongsBoolean('G25 OR G26')!;
      expect(evaluateStrongsBoolean(q, refsFor), {
        'John 3:16',
        'Romans 5:8',
        '1 John 4:8',
        'John 13:35',
      });
    });

    test('three-way AND', () {
      final q = parseStrongsBoolean('G25 G26 G27')!;
      expect(evaluateStrongsBoolean(q, refsFor), {'1 John 4:8'});
    });

    test('left-to-right: (G25 AND G26) OR G27', () {
      final q = parseStrongsBoolean('G25 AND G26 OR G27')!;
      // (G25 ∩ G26) = {Romans 5:8, 1 John 4:8}; ∪ G27 {1 John 4:8}
      expect(evaluateStrongsBoolean(q, refsFor),
          {'Romans 5:8', '1 John 4:8'});
    });

    test('empty term set yields empty AND result', () {
      final q = parseStrongsBoolean('G25 AND H7225')!; // H7225 absent in stub
      expect(evaluateStrongsBoolean(q, refsFor), isEmpty);
    });

    test('NOT = difference', () {
      final q = parseStrongsBoolean('G25 NOT G26')!;
      // G25 {John 3:16, Romans 5:8, 1 John 4:8} minus G26 → John 3:16 only
      expect(evaluateStrongsBoolean(q, refsFor), {'John 3:16'});
    });

    test('NEAR behaves as AND in the plain set-algebra evaluator', () {
      final q = parseStrongsBoolean('G25 NEAR5 G26')!;
      expect(evaluateStrongsBoolean(q, refsFor),
          {'Romans 5:8', '1 John 4:8'});
    });
  });

  group('proximityPairs', () {
    test('empty for a query with no NEAR operator', () {
      final q = parseStrongsBoolean('G25 AND G26 NOT G27')!;
      expect(proximityPairs(q), isEmpty);
    });

    test('extracts (termIndex, termIndex+1, maxWords) for each NEAR', () {
      final q = parseStrongsBoolean('G25 NEAR5 G26')!;
      expect(proximityPairs(q), [(a: 0, b: 1, maxWords: 5, ordered: false)]);
    });

    test('finds every NEAR in a longer chain, ignoring other ops', () {
      final q = parseStrongsBoolean('G25 AND G26 NEAR3 G27 OR H1 NEAR8 H2')!;
      expect(proximityPairs(q), [
        (a: 1, b: 2, maxWords: 3, ordered: false),
        (a: 3, b: 4, maxWords: 8, ordered: false),
      ]);
    });
  });
}
