import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/search_highlight.dart';

void main() {
  group('highlightsForQuery', () {
    test('a bare Strong\'s number marks that number', () {
      final h = highlightsForQuery('G25');
      expect(h.strongsNumbers, {'G25'});
      expect(h.matchesStrongs('G25'), isTrue);
      expect(h.matchesStrongs('g25'), isTrue, reason: 'case');
      expect(h.matchesStrongs('G26'), isFalse);
    });

    test('AND marks both terms', () {
      final h = highlightsForQuery('G25 AND G26');
      expect(h.strongsNumbers, {'G25', 'G26'});
    });

    test('a NOT term is NOT marked', () {
      // "G25 NOT G26" returns verses LACKING G26 — there is nothing to
      // highlight, and marking it would point at the exclusion reason.
      final h = highlightsForQuery('G25 NOT G26');
      expect(h.strongsNumbers, {'G25'});
      expect(h.matchesStrongs('G26'), isFalse);
    });

    test('a wildcard marks by stem', () {
      final h = highlightsForQuery('G25*');
      expect(h.matchesStrongs('G25'), isTrue);
      expect(h.matchesStrongs('G250'), isTrue);
      expect(h.matchesStrongs('G2501'), isTrue);
      expect(h.matchesStrongs('G26'), isFalse);
    });

    test('plain text becomes per-word terms', () {
      final h = highlightsForQuery('Let there be');
      expect(h.textTerms, ['let', 'there', 'be']);
      expect(h.strongsNumbers, isEmpty);
    });

    test('an empty query marks nothing', () {
      expect(highlightsForQuery('').isEmpty, isTrue);
      expect(highlightsForQuery('   ').isEmpty, isTrue);
    });

    test('an empty Strong\'s never matches', () {
      expect(highlightsForQuery('G25').matchesStrongs(''), isFalse);
    });
  });

  group('splitOnTerms', () {
    test('splits around a match', () {
      expect(splitOnTerms('let there be light', ['there']), [
        const HighlightSpan('let ', false),
        const HighlightSpan('there', true),
        const HighlightSpan(' be light', false),
      ]);
    });

    test('is case-insensitive but preserves the original casing', () {
      final out = splitOnTerms('God said', ['god']);
      expect(out.first.text, 'God');
      expect(out.first.isHit, isTrue);
    });

    test('marks every occurrence', () {
      final out = splitOnTerms('God saw, and God said', ['god']);
      expect(out.where((s) => s.isHit).length, 2);
    });

    test('overlapping matches merge rather than shred the line', () {
      // "there" and "here" overlap; the result must not alternate.
      final out = splitOnTerms('there', ['there', 'here']);
      expect(out, [const HighlightSpan('there', true)]);
    });

    test('adjacent matches merge', () {
      final out = splitOnTerms('abcd', ['ab', 'cd']);
      expect(out, [const HighlightSpan('abcd', true)]);
    });

    test('no match yields one plain span', () {
      expect(splitOnTerms('let there be', ['zebra']),
          [const HighlightSpan('let there be', false)]);
    });

    test('empty inputs are safe', () {
      expect(splitOnTerms('', ['a']), isEmpty);
      expect(splitOnTerms('abc', []), [const HighlightSpan('abc', false)]);
      expect(splitOnTerms('abc', ['']), [const HighlightSpan('abc', false)]);
    });

    test('reassembling the spans returns the original text', () {
      const text = 'And God said, Let there be light: and there was light.';
      final out = splitOnTerms(text, ['there', 'light']);
      expect(out.map((s) => s.text).join(), text);
    });

    test('works on Chinese with no word boundaries', () {
      final out = splitOnTerms('起初神创造天地', ['神']);
      expect(out.where((s) => s.isHit).map((s) => s.text), ['神']);
      expect(out.map((s) => s.text).join(), '起初神创造天地');
    });
  });
}
