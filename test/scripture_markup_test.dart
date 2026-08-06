import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/scripture_markup.dart';

ScriptureSpan plain(String s) => ScriptureSpan(s, ScriptureSpanKind.plain);
ScriptureSpan supplied(String s) =>
    ScriptureSpan(s, ScriptureSpanKind.supplied);
ScriptureSpan note(String s) => ScriptureSpan(s, ScriptureSpanKind.note);

void main() {
  group('parseScripture', () {
    test('the real LEB Genesis 1:2 splits correctly', () {
      const raw = 'Now<note: Or "And"> the earth was formless and empty, '
          'and darkness [was] over the face of the deep.';
      final spans = parseScripture(raw);
      expect(spans[0], plain('Now'));
      expect(spans[1], note('Or "And"'));
      expect(spans[2],
          plain(' the earth was formless and empty, and darkness '));
      expect(spans[3], supplied('was'));
      expect(spans[4], plain(' over the face of the deep.'));
    });

    test('plain text is one span, not chopped', () {
      final spans = parseScripture('In the beginning God created.');
      expect(spans, hasLength(1));
      expect(spans.single.kind, ScriptureSpanKind.plain);
    });

    test('adjacent insertions stay separate', () {
      final spans = parseScripture('a [b][c] d');
      expect(spans.where((s) => s.kind == ScriptureSpanKind.supplied),
          hasLength(2));
    });

    test('a note containing quotes and colons survives', () {
      final spans = parseScripture('x<note: Or "the Lord": see 1:1>y');
      expect(spans[1], note('Or "the Lord": see 1:1'));
      expect(spans[2], plain('y'));
    });

    test('empty markers produce no span', () {
      expect(parseScripture('a<note: >b'), [plain('ab')]);
      expect(parseScripture('a[]b'), [plain('ab')]);
    });

    test('an empty verse is an empty list', () {
      expect(parseScripture(''), isEmpty);
    });

    test('unclosed markup is left as literal text, not swallowed', () {
      // Better to show one stray bracket than to eat the rest of a verse.
      final spans = parseScripture('the earth [was over the deep.');
      expect(spans, hasLength(1));
      expect(spans.single.text, contains('['));
    });
  });

  group('scriptureReadingText', () {
    test('drops notes and unwraps supplied words', () {
      const raw = 'Now<note: Or "And"> the earth was formless, '
          'and darkness [was] over the deep.';
      expect(
        scriptureReadingText(raw),
        'Now the earth was formless, and darkness was over the deep.',
      );
    });

    test('does not leave a doubled space where a note was', () {
      expect(scriptureReadingText('a <note: x> b'), 'a b');
    });

    test('does not leave a space before punctuation', () {
      expect(scriptureReadingText('the deep<note: x> .'), 'the deep.');
    });

    test('plain text is returned unchanged', () {
      const s = 'In the beginning God created the heavens and the earth.';
      expect(scriptureReadingText(s), s);
    });

    test('Chinese apparatus is handled the same way', () {
      expect(
        scriptureReadingText('起初<note: 或作「太初」>，神创造天地。'),
        '起初，神创造天地。',
      );
    });
  });

  group('scriptureNotes', () {
    test('collects every note in order', () {
      expect(scriptureNotes('a<note: one>b<note: two>c'), ['one', 'two']);
    });

    test('is empty for plain text', () {
      expect(scriptureNotes('plain verse'), isEmpty);
    });
  });

  group('hasScriptureMarkup', () {
    test('is a cheap gate for the plain half of the Bible', () {
      expect(hasScriptureMarkup('plain verse'), isFalse);
      expect(hasScriptureMarkup('a<note: x>'), isTrue);
      expect(hasScriptureMarkup('a [b]'), isTrue);
    });
  });

  _noiseTests();

  group('cleanLexiconText', () {
    test('turns module reference syntax into a plain reference', () {
      expect(cleanLexiconText('雅完的儿子 (# 創 10:4|)'), '雅完的儿子 (創 10:4)');
    });

    test('strips bare pipes', () {
      expect(cleanLexiconText('a | b'), 'a b');
    });

    test('an empty reference leaves no empty parens', () {
      expect(cleanLexiconText('word (#|)'), 'word');
    });

    test('collapses the whitespace its own edits create', () {
      expect(cleanLexiconText('a (# 創 1:1|)  ,  b'), 'a (創 1:1), b');
    });

    test('CJK punctuation is not orphaned by the space fix', () {
      expect(cleanLexiconText('先知 | ，逃往'), '先知，逃往');
    });

    test('text with no module syntax is untouched', () {
      const s = 'to love, to have affection for';
      expect(cleanLexiconText(s), s);
    });

    test('empty in, empty out', () {
      expect(cleanLexiconText(''), '');
    });
  });
}

// Appended 2026-08-06: display noise, and the characters that must
// survive a cleanup pass.
void _noiseTests() {
  group('display noise', () {
    test('the NASB pilcrow is stripped, with its trailing space', () {
      expect(scriptureReadingText('¶“Reuben, you are my firstborn,'),
          '“Reuben, you are my firstborn,');
      expect(scriptureReadingText('¶ Simeon and Levi'), 'Simeon and Levi');
    });

    test('the Chinese appositive dash SURVIVES', () {
      // 利未记 4:22. Stripping this maims the apposition.
      const v = '官长若行了雅伟─他神所吩咐不可行的什么事';
      expect(scriptureReadingText(v), v);
    });

    test('rare but real CJK characters SURVIVE', () {
      // 民数记 15:38 — 䍁子, tassels. Not mojibake.
      const v = '在衣服边上做䍁子';
      expect(scriptureReadingText(v), v);
    });

    test('the thin space between nested quotes SURVIVES', () {
      const v = 'or you will die.’ ”';
      expect(scriptureReadingText(v), v);
    });

    test('a pilcrow mid-verse goes too', () {
      expect(scriptureReadingText('a ¶b'), 'a b');
    });
  });
}
