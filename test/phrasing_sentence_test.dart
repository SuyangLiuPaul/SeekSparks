/// The sentence window: what a phrasing opens on.
///
/// Phrasing is an argument about a unit of thought, and the unit is a
/// sentence. Until now the pane opened on the cursor VERSE, which is the
/// wrong unit between a fifth and a third of the time — so the tests
/// that matter here are the corpus ones at the bottom, against the real
/// Ephesians 1 the request is about.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/utils/phrasing.dart';
import 'package:seeksparks/utils/scripture_markup.dart'
    show scriptureReadingText;

List<({int verse, String text})> _chapter(String version, String book, int ch) {
  final raw = jsonDecode(File('assets/$version.json').readAsStringSync()) as List;
  final out = <({int verse, String text})>[];
  for (final v in raw) {
    final m = v as Map<String, dynamic>;
    if (m['book'] != book || m['chapter'] != '$ch') continue;
    final n = int.tryParse('${m['verse']}');
    if (n == null) continue;
    out.add((verse: n, text: scriptureReadingText('${m['text']}')));
  }
  out.sort((a, b) => a.verse.compareTo(b.verse));
  return out;
}

void main() {
  group('phrasingEndsSentence', () {
    test('a full stop ends it, through closing quotes and brackets', () {
      expect(phrasingEndsSentence('God created the heavens and the earth.'),
          isTrue);
      expect(phrasingEndsSentence('and he said, "Let there be light."'), isTrue);
      expect(phrasingEndsSentence('神说：「要有光。」'), isTrue);
      // Two closers over one terminator — 和合本 writes quoted speech
      // inside quoted speech and the peel has to be repeated.
      expect(phrasingEndsSentence('他说：「耶稣说：『我是。』」'), isTrue);
      expect(phrasingEndsSentence('It is finished.]'), isTrue);
      expect(phrasingEndsSentence('Shall I not drink it?'), isTrue);
      expect(phrasingEndsSentence('Woe to you!'), isTrue);
      expect(phrasingEndsSentence('你们要往哪里去？'), isTrue);
    });

    test('a semicolon and a colon do NOT end it', () {
      // The one rule this whole feature turns on. The KJV leans on the
      // semicolon hard — Ephesians 1:7 ends on one — and counting it
      // would cut 1:7-12 into three sentences that are not there.
      expect(
        phrasingEndsSentence(
            'the forgiveness of sins, according to the riches of his grace;'),
        isFalse,
      );
      expect(
        phrasingEndsSentence(
            'with all spiritual blessings in heavenly places in Christ:'),
        isFalse,
      );
      expect(phrasingEndsSentence('and God said,'), isFalse);
      expect(phrasingEndsSentence('雅伟对摩西说，'), isFalse);
    });

    test('the Greek question mark and the Hebrew sof pasuq end it', () {
      // U+037E is a different codepoint from the ASCII semicolon
      // precisely so a Greek question can be told from a joint.
      expect(phrasingEndsSentence('τίς ἐστιν οὗτος;'), isTrue);
      expect(phrasingEndsSentence('הָאָֽרֶץ׃'), isTrue);
    });

    test('nothing at all ends nothing', () {
      expect(phrasingEndsSentence(''), isFalse);
      expect(phrasingEndsSentence('   '), isFalse);
      expect(phrasingEndsSentence('」'), isFalse);
      expect(phrasingEndsSentence('εν αρχη εποιησεν ο θεος'), isFalse);
    });
  });

  group('phrasingSentenceWindow', () {
    List<({int verse, String text})> chapter(Map<int, String> m) =>
        [for (final e in m.entries) (verse: e.key, text: e.value)];

    test('a verse that is a whole sentence opens on itself', () {
      final w = phrasingSentenceWindow(
          chapter({1: 'One.', 2: 'Two.', 3: 'Three.'}), 2);
      expect(w.start, 2);
      expect(w.end, 2);
      expect(w.widensVerse, isFalse);
      expect(w.capped, isFalse);
      expect(w.source, PhrasingWindowSource.phrased);
    });

    test('a verse inside a sentence opens on the whole sentence', () {
      final c = chapter({1: 'One.', 2: 'Two,', 3: 'three,', 4: 'four.', 5: 'Five.'});
      for (final v in [2, 3, 4]) {
        final w = phrasingSentenceWindow(c, v);
        expect(w.start, 2, reason: 'verse $v');
        expect(w.end, 4, reason: 'verse $v');
        expect(w.widensVerse, isTrue);
      }
      expect(phrasingSentenceWindow(c, 5).start, 5);
      expect(phrasingSentenceWindow(c, 1).end, 1);
    });

    test('a sentence running off the end of the chapter stops there', () {
      // The pane is chapter-scoped, so a sentence continuing into the
      // next chapter is clamped. Honest limit, not a rounding.
      final w = phrasingSentenceWindow(
          chapter({1: 'One.', 2: 'Two,', 3: 'three,'}), 3);
      expect(w.start, 2);
      expect(w.end, 3);
    });

    test('a text with no stops anywhere reports none and stays on the verse',
        () {
      // `assets/originals` and `assets/lxxwh.json` are exactly this.
      final w = phrasingSentenceWindow(
          chapter({1: 'εν αρχη', 2: 'εποιησεν ο θεος', 3: 'τον ουρανον'}), 2);
      expect(w.source, PhrasingWindowSource.none);
      expect(w.start, 2);
      expect(w.end, 2);
    });

    test('an empty text reports none rather than throwing', () {
      final w = phrasingSentenceWindow(const [], 7);
      expect(w.source, PhrasingWindowSource.none);
      expect(w.start, 7);
      expect(w.end, 7);
    });

    test('a verse the text does not carry reports none', () {
      final w = phrasingSentenceWindow(chapter({1: 'One.', 2: 'Two.'}), 9);
      expect(w.source, PhrasingWindowSource.none);
      expect(w.start, 9);
    });

    test('a sentence longer than the cap is NAMED, not truncated', () {
      final m = <int, String>{1: 'Opening.'};
      for (var v = 2; v <= 30; v++) {
        m[v] = 'and $v,';
      }
      m[31] = 'the end.';
      final w = phrasingSentenceWindow(chapter(m), 10);
      expect(w.capped, isTrue);
      // The window is the verse the reader is on — never half a sentence.
      expect(w.start, 10);
      expect(w.end, 10);
      // …and the sentence it is inside is still reported in full, so the
      // pane can print it and offer to open it.
      expect(w.sentenceStart, 2);
      expect(w.sentenceEnd, 31);
      expect(w.source, PhrasingWindowSource.phrased);
    });

    test('the cap counts verses PRESENT, not the numeric span', () {
      // A chapter with a hole in the tagged corpus must not be capped
      // for verses it was never going to draw.
      final m = <int, String>{1: 'Opening.', 2: 'and,'};
      m[40] = 'the end.';
      final w = phrasingSentenceWindow(chapter(m), 2);
      expect(w.capped, isFalse);
      expect(w.start, 2);
      expect(w.end, 40);
    });

    test('the last fragment of a verse decides, not the first', () {
      // A tagged edition arrives as runs, and the stop is on the last
      // one. Feeding the runs in must not let an earlier run close the
      // verse on behalf of the ones after it.
      final w = phrasingSentenceWindow([
        (verse: 1, text: 'Alpha.'),
        (verse: 2, text: 'He said.'),
        (verse: 2, text: 'and then,'),
        (verse: 3, text: 'the rest.'),
      ], 2);
      expect(w.start, 2);
      expect(w.end, 3);
    });
  });

  group('the real corpus — Ephesians 1, the passage the request is about', () {
    test('LEB makes 1:3-14 one sentence and every verse in it agrees', () {
      final c = _chapter('leb', 'Ephesians', 1);
      for (final v in [3, 4, 8, 11, 14]) {
        final w = phrasingSentenceWindow(c, v);
        expect(w.start, 3, reason: 'LEB Eph 1:$v');
        expect(w.end, 14, reason: 'LEB Eph 1:$v');
        expect(w.capped, isFalse,
            reason: 'twelve verses is exactly the cap and must survive it');
      }
      expect(phrasingSentenceWindow(c, 1).end, 2);
      expect(phrasingSentenceWindow(c, 20).start, 15);
      expect(phrasingSentenceWindow(c, 20).end, 23);
    });

    test('the KJV makes the same passage three sentences, and that is a fact '
        'about the KJV', () {
      // 1:3 ends on a colon and 1:7 on a semicolon; if either counted as
      // a stop this would come out as five sentences instead of three.
      final c = _chapter('kjv', 'Ephesians', 1);
      expect(phrasingSentenceWindow(c, 4).start, 3);
      expect(phrasingSentenceWindow(c, 4).end, 6);
      expect(phrasingSentenceWindow(c, 8).start, 7);
      expect(phrasingSentenceWindow(c, 8).end, 12);
      expect(phrasingSentenceWindow(c, 13).end, 14);
    });

    test('the BSB cuts it finer still — three editions, three judgements', () {
      final c = _chapter('bsb', 'Ephesians', 1);
      final w = phrasingSentenceWindow(c, 4);
      expect(w.start, 4);
      expect(w.end, 6);
    });
  });

  group('the real corpus — where the cap earns its place', () {
    test("Joshua 15's 42-verse town list is named, not opened", () {
      final c = _chapter('kjv', 'Joshua', 15);
      final w = phrasingSentenceWindow(c, 30);
      expect(w.capped, isTrue);
      expect(w.start, 30);
      expect(w.end, 30);
      expect(w.sentenceStart, 21);
      expect(w.sentenceEnd, 62);
    });

    test('the Septuagint carries no stops at all, so it says so', () {
      final c = _chapter('lxxwh', 'Genesis', 1);
      expect(c, isNotEmpty);
      expect(c.any((t) => phrasingEndsSentence(t.text)), isFalse);
      expect(phrasingSentenceWindow(c, 3).source, PhrasingWindowSource.none);
    });

    test('every chapter of every shipped translation punctuates somewhere', () {
      // The claim the fallback rests on. If it were ever false for a
      // translation, a reader would meet the "no stops" message on a
      // text that plainly has them.
      for (final version in ['kjv', 'leb', 'bsb', 'cuvs-yhwh']) {
        final raw =
            jsonDecode(File('assets/$version.json').readAsStringSync()) as List;
        final byChapter = <String, bool>{};
        for (final v in raw) {
          final m = v as Map<String, dynamic>;
          final key = '${m['book']}|${m['chapter']}';
          byChapter[key] = (byChapter[key] ?? false) ||
              phrasingEndsSentence(scriptureReadingText('${m['text']}'));
        }
        final silent = byChapter.entries.where((e) => !e.value).toList();
        expect(silent, isEmpty, reason: '$version: ${silent.map((e) => e.key)}');
      }
    });
  });
}
