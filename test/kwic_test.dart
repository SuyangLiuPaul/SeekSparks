import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/services/tagged_text_service.dart';
import 'package:seeksparks/utils/kwic.dart';

TaggedRun r(String text, String strongs, {List<String> implied = const []}) =>
    TaggedRun(text: text, strongs: strongs, implied: implied);

void main() {
  group('kwicLinesForVerse', () {
    test('splits a verse around the keyword', () {
      final lines = kwicLinesForVerse(
        reference: 'Genesis 1:1',
        runs: [
          r('In the beginning ', 'H7225'),
          r('God ', 'H430'),
          r('created ', 'H1254'),
          r('the heavens ', 'H8064', implied: ['H853']),
          r('and ', 'H853'),
          r('the earth.', 'H776'),
        ],
        strongs: 'H1254',
      );
      expect(lines, hasLength(1));
      expect(lines.single.left, 'In the beginning God');
      expect(lines.single.keyword, 'created');
      expect(lines.single.right, 'the heavens and the earth.');
    });

    test('one line per occurrence, indexed', () {
      final lines = kwicLinesForVerse(
        reference: 'Genesis 1:4',
        runs: [
          r('And God ', 'H430'),
          r('saw ', 'H7200'),
          r('the light ', 'H216'),
          r('and God ', 'H430'),
          r('separated ', 'H914'),
        ],
        strongs: 'H430',
      );
      expect(lines, hasLength(2));
      expect(lines[0].hitIndex, 0);
      expect(lines[1].hitIndex, 1);
      expect(lines[1].left, 'And God saw the light');
    });

    test('an implied number is context, not a hit', () {
      // H853 rides on "the heavens" but is not the word's own identity;
      // counting it would double every direct-object marker in the OT.
      final lines = kwicLinesForVerse(
        reference: 'Genesis 1:1',
        runs: [
          r('the heavens ', 'H8064', implied: ['H853']),
          r('and ', 'H853'),
        ],
        strongs: 'H853',
      );
      expect(lines, hasLength(1));
      expect(lines.single.keyword, 'and');
    });

    test('context is clamped at the verse edges', () {
      final lines = kwicLinesForVerse(
        reference: 'John 1:1',
        runs: [r('In ', 'G1722'), r('the beginning', 'G746')],
        strongs: 'G1722',
        contextWords: 8,
      );
      expect(lines.single.left, isEmpty);
      expect(lines.single.right, 'the beginning');
    });

    test('matching is case-insensitive on the number', () {
      final lines = kwicLinesForVerse(
        reference: 'X 1:1',
        runs: [r('word ', 'g25')],
        strongs: 'G25',
      );
      expect(lines, hasLength(1));
    });

    test('no occurrence yields no lines', () {
      final lines = kwicLinesForVerse(
        reference: 'X 1:1',
        runs: [r('word ', 'G26')],
        strongs: 'G25',
      );
      expect(lines, isEmpty);
    });
  });

  group('sorting', () {
    KwicLine line(String ref, String left, String right) =>
        KwicLine(reference: ref, left: left, keyword: 'loved',
            right: right, hitIndex: 0);

    test('left sort keys on the ADJACENT word, not the furthest', () {
      // "so" is what matters — it sits against the keyword. Sorting the
      // raw string would key on "zebra"/"apple" instead.
      expect(leftSortKey('zebra so'), 'so zebra');
      expect(leftSortKey('apple to'), 'to apple');
      expect(leftSortKey(''), '');
    });

    test('leftContext groups repeated lead-ins', () {
      final lines = [
        line('A 1:1', 'apple so', ''),
        line('B 1:1', 'banana to', ''),
        line('C 1:1', 'cherry so', ''),
      ];
      final sorted = sortKwic(lines, KwicSort.leftContext);
      // Both "so" lines come together, ahead of "to".
      expect(sorted.map((l) => l.reference), ['A 1:1', 'C 1:1', 'B 1:1']);
    });

    test('rightContext orders by what follows', () {
      final lines = [
        line('A 1:1', '', 'the world'),
        line('B 1:1', '', 'his neighbour'),
      ];
      expect(sortKwic(lines, KwicSort.rightContext).first.reference,
          'B 1:1');
    });

    test('reference sort is the input order, and sorting is stable', () {
      final lines = [
        line('A 1:1', 'same', ''),
        line('B 1:1', 'same', ''),
        line('C 1:1', 'same', ''),
      ];
      expect(sortKwic(lines, KwicSort.reference).map((l) => l.reference),
          ['A 1:1', 'B 1:1', 'C 1:1']);
      // Identical keys must not shuffle.
      expect(sortKwic(lines, KwicSort.leftContext).map((l) => l.reference),
          ['A 1:1', 'B 1:1', 'C 1:1']);
    });

    test('sorting does not mutate the input', () {
      final lines = [line('B 1:1', 'b', ''), line('A 1:1', 'a', '')];
      sortKwic(lines, KwicSort.leftContext);
      expect(lines.first.reference, 'B 1:1');
    });
  });

  group('kwicCollocates', () {
    test('counts words either side, descending', () {
      final lines = [
        KwicLine(reference: 'A 1:1', left: 'God so', keyword: 'loved',
            right: 'the world', hitIndex: 0),
        KwicLine(reference: 'B 1:1', left: 'God so', keyword: 'loved',
            right: 'the church', hitIndex: 0),
      ];
      final got = kwicCollocates(lines);
      expect(got.first.count, 2);
      expect(got.map((c) => c.word), containsAll(['god', 'so', 'the']));
      // Singletons are noise at this sample size.
      expect(got.map((c) => c.word), isNot(contains('world')));
    });

    test('punctuation is not a collocate', () {
      final lines = [
        KwicLine(reference: 'A 1:1', left: '— ,', keyword: 'x',
            right: '. ;', hitIndex: 0),
        KwicLine(reference: 'B 1:1', left: '— ,', keyword: 'x',
            right: '. ;', hitIndex: 0),
      ];
      expect(kwicCollocates(lines), isEmpty);
    });

    test('handles Chinese context', () {
      final lines = [
        KwicLine(reference: 'A 1:1', left: '起初 神', keyword: '创造',
            right: '天 地', hitIndex: 0),
        KwicLine(reference: 'B 1:1', left: '起初 神', keyword: '创造',
            right: '天 地', hitIndex: 0),
      ];
      expect(kwicCollocates(lines).map((c) => c.word), contains('神'));
    });
  });
}
