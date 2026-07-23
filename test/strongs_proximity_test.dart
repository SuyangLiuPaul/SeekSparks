import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/strongs_boolean_search.dart' show StrongsTerm;
import 'package:seeksparks/utils/strongs_proximity.dart';

StrongsTerm term(String number, {bool wildcard = false}) {
  final prefix = number[0];
  final digits = number.substring(1);
  return StrongsTerm(prefix: prefix, digits: digits, wildcard: wildcard);
}

void main() {
  group('verseSatisfiesProximity', () {
    // John 1:1-ish word order for a readable fixture: G1722 G746 G1510
    // G3588 G3056 G2532 G3588 G3056 G1510 G4314 G3588 G2316
    final words = [
      'G1722', 'G746', 'G1510', 'G3588', 'G3056', 'G2532',
      'G3588', 'G3056', 'G1510', 'G4314', 'G3588', 'G2316',
    ];

    test('adjacent words satisfy NEAR1', () {
      // G1510 (index 2) and G3588 (index 3) are adjacent.
      expect(
        verseSatisfiesProximity(
          strongsNumbersInOrder: words,
          termA: term('G1510'),
          termB: term('G3588'),
          maxWords: 1,
        ),
        true,
      );
    });

    test('far-apart words fail a tight NEAR', () {
      // G1722 (index 0) and G2316 (index 11) are 11 apart.
      expect(
        verseSatisfiesProximity(
          strongsNumbersInOrder: words,
          termA: term('G1722'),
          termB: term('G2316'),
          maxWords: 3,
        ),
        false,
      );
    });

    test('far-apart words pass a generous NEAR', () {
      expect(
        verseSatisfiesProximity(
          strongsNumbersInOrder: words,
          termA: term('G1722'),
          termB: term('G2316'),
          maxWords: 20,
        ),
        true,
      );
    });

    test('picks the closest of multiple occurrences', () {
      // G3056 occurs at index 4 and 7; G2532 occurs at index 5.
      // distance(4,5)=1, so NEAR1 should already succeed.
      expect(
        verseSatisfiesProximity(
          strongsNumbersInOrder: words,
          termA: term('G3056'),
          termB: term('G2532'),
          maxWords: 1,
        ),
        true,
      );
    });

    test('no match when a term is entirely absent', () {
      expect(
        verseSatisfiesProximity(
          strongsNumbersInOrder: words,
          termA: term('G1722'),
          termB: term('G9999'),
          maxWords: 50,
        ),
        false,
      );
    });

    test('wildcard term matches by prefix', () {
      // G37* matches G3712 via prefix; the exact term matches G2222 as-is.
      expect(
        verseSatisfiesProximity(
          strongsNumbersInOrder: ['G1111', 'G3712', 'G2222'],
          termA: term('G37', wildcard: true),
          termB: term('G2222'),
          maxWords: 1,
        ),
        true,
      );
    });

    test('same-position occurrence does not satisfy proximity to itself', () {
      // A single-word verse containing only the term can't be "near itself".
      expect(
        verseSatisfiesProximity(
          strongsNumbersInOrder: ['G100'],
          termA: term('G100'),
          termB: term('G100'),
          maxWords: 5,
        ),
        false,
      );
    });

    test('empty verse never satisfies proximity', () {
      expect(
        verseSatisfiesProximity(
          strongsNumbersInOrder: const [],
          termA: term('G100'),
          termB: term('G200'),
          maxWords: 5,
        ),
        false,
      );
    });
  });
}
