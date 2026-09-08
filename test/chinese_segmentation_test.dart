/// 2026-09-08: where a Chinese query's words begin and end, checked
/// against real verses rather than against invented strings.
///
/// Every text in this file is loaded out of `assets/cuvs-yhwh.json` by
/// verse id. A segmenter tested on hand-typed Chinese is a segmenter
/// tested on what its author expected the Bible to say.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/chinese_segmentation.dart';
import 'package:seeksparks/utils/fuzzy_search.dart' show synonymVocabulary;
import 'package:seeksparks/utils/related_verses.dart' show isCjkChar;

void main() {
  late Map<String, String> verses;

  setUpAll(() {
    final list =
        jsonDecode(File('assets/cuvs-yhwh.json').readAsStringSync()) as List;
    verses = {
      for (final v in list) v['id'] as String: v['text'] as String,
    };
  });

  String verse(String id) {
    final text = verses[id];
    expect(text, isNotNull, reason: 'verse $id is missing from the edition');
    return text!;
  }

  group('the predicate this file keeps a second copy of', () {
    test('agrees with related_verses across every code point it claims', () {
      // The duplication is deliberate — `chinese_segmentation.dart` says
      // why — and this is the guard that stops it becoming a
      // disagreement. Checking the boundaries either side of each range
      // catches an off-by-one, which is the only way two copies of four
      // comparisons realistically drift.
      for (var c = 0; c <= 0xFFFF; c++) {
        expect(isHanChar(c), isCjkChar(c), reason: 'U+${c.toRadixString(16)}');
      }
    });
  });

  group('segmenting a verse with no vocabulary at all', () {
    test('falls back to one token per character, and says so by doing it',
        () {
      // 创世纪 1:1. With nothing in the dictionary there is no honest
      // word boundary to report, so the segmenter reports none.
      expect(
        segmentHan(verse('001001001')),
        ['起', '初', '神', '创', '造', '天', '地', '。'],
      );
    });

    test('keeps a run of anything that is not Han as one untouched token',
        () {
      expect(segmentHan('神 loves 世人'), ['神', ' loves ', '世', '人']);
    });
  });

  group('segmenting with the vocabulary this app owns', () {
    test('keeps the divine name whole where a character-wise split would '
        'have shredded it', () {
      // 出埃及记 33:21 opens with 雅伟说. Longest-match is the whole
      // point: 雅 and 伟 are both plausible single characters, and the
      // one thing a reader searching this app never means is 雅 alone.
      final segments =
          segmentHan(verse('002033021'), vocabulary: synonymVocabulary());
      expect(segments.first, '雅伟');
      expect(segments.contains('雅'), isFalse);
    });

    test('finds the name the verse itself defines', () {
      // 约翰福音 1:42 — 「矶法翻出来就是彼得」 — is the verse that
      // licenses the 彼得 / 矶法 synonym group, and it holds both forms.
      final segments =
          segmentHan(verse('043001042'), vocabulary: synonymVocabulary());
      expect(segments, contains('矶法'));
      expect(segments, contains('彼得'));
    });
  });

  group('the conjuncts a segmented query is allowed to ask for', () {
    test('drops the characters too common to narrow anything', () {
      // 的 is in 24,525 of the 31,102 verses. Requiring it requires
      // nothing while making the search look narrower than it is.
      expect(
        segmentedConjuncts('神的爱', commonChars: '的'),
        ['神', '爱'],
      );
    });

    test('drops a common character only when it stands alone', () {
      // 雅 is on the common list precisely because 雅伟 is everywhere.
      // The vocabulary match happens first, so the name survives whole.
      expect(
        segmentedConjuncts('雅伟的话',
            vocabulary: {'雅伟'}, commonChars: '的雅'),
        ['雅伟', '话'],
      );
    });

    test('returns nothing that is not Han, and never the same twice', () {
      expect(segmentedConjuncts('爱 love 爱'), ['爱']);
    });

    test('leaves a one-word query with fewer than two conjuncts, which the '
        'caller must read as no segmented reading at all', () {
      // One fragment of a query is not a looser reading of it, and a
      // caller treating this as a match would answer 神的 with every
      // verse that says 神.
      expect(segmentedConjuncts('神的', commonChars: '的').length, lessThan(2));
    });
  });
}
