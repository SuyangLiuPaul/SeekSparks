/// The cross-version conjunction — `docs/PARITY-BACKLOG.md` §3.1.
///
/// This entry exists because the ORIGINAL cross-version row described a
/// feature BibleWorks does not have; when that was corrected, the thing
/// it had described turned out to be worth building on its own account.
/// The guards below are mostly about the grammar staying unambiguous:
/// a colon is a common character and a version prefix must never take
/// one a reader meant literally.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/utils/cross_version_query.dart';

void main() {
  group('what counts as a cross-version query', () {
    test('two tagged terms under an AND', () {
      final q = parseCrossVersionQuery('.kjv:propitiation csb:atoning', 'bsb');
      expect(q, isNotNull);
      expect(q!.isCrossVersion, isTrue);
      expect(q.all, isTrue);
      expect(q.terms.map((t) => t.version), ['kjv', 'csb']);
      expect(q.terms.map((t) => t.query), ['.propitiation', '.atoning']);
    });

    test('an untagged term belongs to the edition being read', () {
      final q = parseCrossVersionQuery('.love csb:atoning', 'kjv');
      expect(q, isNotNull);
      expect(q!.terms.map((t) => t.version), ['kjv', 'csb']);
      expect(q.terms.first.query, '.love');
    });

    test('OR keeps its meaning', () {
      final q = parseCrossVersionQuery('/kjv:charity csb:love', 'bsb');
      expect(q!.all, isFalse);
    });

    test('several terms for one edition stay together', () {
      // `.kjv:a kjv:b csb:c` is "the KJV says a AND b, the CSB says c",
      // not three separate editions.
      final q = parseCrossVersionQuery('.kjv:faith kjv:hope csb:love', 'bsb');
      expect(q!.terms, hasLength(2));
      expect(q.terms.first.query, '.faith hope');
    });
  });

  group('what is NOT one, and must fall through untouched', () {
    test('a line with no control character', () {
      expect(parseCrossVersionQuery('kjv:love', 'kjv'), isNull);
    });

    test('a line with no colon at all', () {
      expect(parseCrossVersionQuery('.love god', 'kjv'), isNull);
    });

    test('a prefix that is not a version this build can load', () {
      // The whole ambiguity defence. `H1254:` is not an edition, so the
      // term keeps its colon and the line is an ordinary search.
      expect(parseCrossVersionQuery('.H1254:x kjv:y', 'kjv'), isNull,
          reason: 'only one real edition is named, so it is not a '
              'cross-version query');
      final q = parseCrossVersionQuery('.notaversion:x', 'kjv');
      expect(q, isNull);
    });

    test('only one edition named is an ordinary search', () {
      expect(parseCrossVersionQuery('.kjv:love', 'kjv'), isNull,
          reason: 'the tag and the reading version are the same edition');
    });

    test('the phrase forms are refused, not cut in half', () {
      // A phrase is an ORDER over adjacent tokens; splitting it per
      // edition would run each half as its own term and quietly return
      // the wrong verses.
      expect(parseCrossVersionQuery("'kjv:in the beginning", 'kjv'), isNull);
      expect(parseCrossVersionQuery(';kjv:a csb:b', 'kjv'), isNull);
    });

    test('an empty term after the colon is refused', () {
      expect(parseCrossVersionQuery('.kjv: csb:love', 'bsb'), isNull);
    });

    test('a retired code resolves rather than being read as a word', () {
      // `cuv-yhwd` maps to `cuvs-yhwh`. If it mapped onto the same
      // edition as the other term the query would collapse to one
      // edition and correctly stop being cross-version.
      final q = parseCrossVersionQuery('.cuv-yhwd:爱 kjv:love', 'bsb');
      expect(q, isNotNull);
      expect(q!.terms.map((t) => t.version), ['cuvs-yhwh', 'kjv']);
    });
  });

  group('combining the per-edition answers', () {
    test('AND is an intersection of verse ids', () {
      expect(
        combineCrossVersion([
          {'001001001', '001001002'},
          {'001001002', '001001003'},
        ], all: true),
        {'001001002'},
      );
    });

    test('OR is a union', () {
      expect(
        combineCrossVersion([
          {'001001001'},
          {'001001002'},
        ], all: false),
        {'001001001', '001001002'},
      );
    });

    test('AND with an empty side is empty, not the other side', () {
      expect(
        combineCrossVersion([
          {'001001001'},
          <String>{},
        ], all: true),
        isEmpty,
      );
    });

    test('nothing at all is empty rather than everything', () {
      expect(combineCrossVersion(const [], all: true), isEmpty);
      expect(combineCrossVersion(const [], all: false), isEmpty);
    });

    test('the input sets are not mutated', () {
      // `intersection` returns a new set, but a future edit that reached
      // for `retainAll` would corrupt a caller's corpus index and the
      // damage would show up two searches later.
      final a = {'001001001', '001001002'};
      final b = {'001001002'};
      combineCrossVersion([a, b], all: true);
      expect(a, hasLength(2));
      expect(b, hasLength(1));
    });
  });
}
