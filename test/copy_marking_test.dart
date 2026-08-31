// A copy of the search results carries the marking the results carry.
//
// 2026-08-31 (owner-reported): the list marks the word that answered the
// query and the copy of that list did not, so the pasted document could
// not be read for what was found. The clipboard's `text/html` flavour is
// the only one that can hold a mark, so the mark travels as sentinels
// and the two flavours are derived at the end — that derivation, and the
// escaping it has to survive, is what this pins.

import 'package:flutter/painting.dart' show TextStyle, FontWeight;
import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/copy_marking.dart';
import 'package:seeksparks/utils/search_highlight.dart';

List<({String text, String strongs})> runs(List<List<String>> pairs) =>
    [for (final p in pairs) (text: p[0], strongs: p[1])];

void main() {
  const h430 = SearchHighlight(strongsNumbers: {'H430'});
  const god = SearchHighlight(textTerms: ['god']);

  group('marking a verse', () {
    test('a text query marks its term in any edition', () {
      final marked = markVerseHits(
        'In the beginning God created the heavens and the earth.',
        highlight: god,
      );
      expect(marked, contains('${hitOpen}God$hitClose'));
      expect(stripHitMarks(marked),
          'In the beginning God created the heavens and the earth.');
    });

    test('a Strong\'s query marks the run that carries the number', () {
      final marked = markVerseHits(
        'In the beginning God created the heavens and the earth.',
        highlight: h430,
        runs: runs([
          ['In the beginning', 'H7225'],
          ['God', 'H430'],
          ['created', 'H1254'],
        ]),
      );
      expect(marked, contains('${hitOpen}God$hitClose'));
    });

    test('an untagged edition asked for a number marks nothing', () {
      const verse = 'In the beginning God created the heavens and the earth.';
      // NASB, 梁家铿 and 雅偉版繁體 ship no tagging, so nothing here can
      // say which word carries H430. Returning the verse unmarked is the
      // honest answer; guessing at "God" because it looks right is not.
      expect(markVerseHits(verse, highlight: h430, runs: null), verse);
      expect(hasHitMarks(markVerseHits(verse, highlight: h430)), isFalse);
    });

    test('no search leaves the verse exactly as it was', () {
      const verse = '起初神创造天地。';
      expect(markVerseHits(verse, highlight: const SearchHighlight()), verse);
    });

    test('a term that is absent marks nothing rather than everything', () {
      const verse = 'In the beginning God created the heavens and the earth.';
      expect(
        markVerseHits(verse, highlight: const SearchHighlight(textTerms: ['x'])),
        verse,
      );
    });

    test('Chinese marks the matched characters', () {
      final marked = markVerseHits('起初神创造天地。',
          highlight: const SearchHighlight(textTerms: ['神']));
      expect(marked, '起初$hitOpen神$hitClose创造天地。');
    });
  });

  group('the two clipboard flavours', () {
    test('plain is the marked string with the sentinels gone', () {
      const marked = '创世记 1:1  起初$hitOpen神$hitClose创造天地。';
      expect(stripHitMarks(marked), '创世记 1:1  起初神创造天地。');
      expect(stripHitMarks(marked).contains(hitOpen), isFalse);
    });

    test('plain marks the hit in brackets the destination cannot strip', () {
      // The whole reason this exists: a .txt paste keeps no formatting,
      // and Word and Pages did not take the rich flavour either.
      const marked = '创世记 1:1  起初$hitOpen神$hitClose创造天地。';
      expect(plainHitMarks(marked), '创世记 1:1  起初【神】创造天地。');
    });

    test('the brackets do not collide with the corpus own brackets', () {
      // `[ ]` is a supplied word and the divine-name glosses print it
      // unconditionally, so marking a hit on 主 with square brackets
      // would be indistinguishable from 主[雅伟]. 【 】 occurs in no
      // shipped edition.
      final marked = markVerseHits('主[雅伟]是我的牧者',
          highlight: const SearchHighlight(textTerms: ['主']));
      expect(plainHitMarks(marked), '【主】[雅伟]是我的牧者');
    });

    test('an unmarked string is untouched by the plain flavour', () {
      expect(plainHitMarks('nothing marked here'), 'nothing marked here');
    });

    test('html wraps the hit and escapes everything else', () {
      final html = hitMarkedHtml('a ${hitOpen}b$hitClose <c> & d');
      expect(html, contains('<span style="$kHitHtmlStyle">b</span>'));
      // The angle brackets in the TEXT are escaped; the ones the mark
      // introduced are not. One escape pass, then substitution — the
      // order is the whole point.
      expect(html, contains('&lt;c&gt; &amp; d'));
      expect(html.contains('<c>'), isFalse);
    });

    test('newlines survive as breaks, because Word ignores pre-wrap', () {
      expect(hitMarkedHtml('one\ntwo'), contains('one<br>two'));
      expect(hitMarkedHtml('one\r\ntwo'), contains('one<br>two'));
    });

    test('an unmarked string still produces valid html', () {
      final html = hitMarkedHtml('nothing marked here');
      expect(html, '<div style="line-height:1.5">nothing marked here</div>');
    });

    test('hasHitMarks is what tells the caller a rich flavour is worth it',
        () {
      expect(hasHitMarks('plain'), isFalse);
      expect(hasHitMarks('a ${hitOpen}b$hitClose'), isTrue);
    });
  });

  group('the preview spans', () {
    const base = TextStyle(fontSize: 12);
    const hit = TextStyle(fontSize: 12, fontWeight: FontWeight.w700);

    test('the hit is the only span carrying the hit style', () {
      final spans =
          hitMarkedSpans('起初$hitOpen神$hitClose创造天地。', base: base, hit: hit);
      expect(spans.map((s) => s.text).join(), '起初神创造天地。');
      expect(
        spans.where((s) => s.style == hit).map((s) => s.text).toList(),
        ['神'],
      );
    });

    test('an unbalanced sentinel shows the rest instead of dropping it', () {
      // Cannot arise from `markHits`, and a display path that silently
      // ate the tail of a verse would be the worst possible failure.
      final spans = hitMarkedSpans('起初$hitOpen神创造天地。', base: base, hit: hit);
      expect(spans.map((s) => s.text).join(), '起初神创造天地。');
    });
  });
}
