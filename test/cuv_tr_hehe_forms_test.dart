/// 和合本雅偉版 繁體, at the 128 character classes the published 和合本
/// settles — and at the places where it settles them two different ways.
///
/// This edition has never had a Traditional master. Ours and the
/// publisher's are two conversions of the same Simplified text, so where
/// they disagree at a character neither side's own consistency is
/// evidence. 和合本雅偉版 is the 和合本 with the divine name restored, so
/// the printed 和合本 is the same sentence and answers the question;
/// every position below was read verse by verse at 信望愛
/// (bible.fhl.net, `VERSION4=unv`) on 2026-09-14, 922 chapters of it,
/// and applied by `tools/apply_cuv_tr_hehe_verdicts.py` from
/// `tools/cuv-2026-09-14-hehe-verdicts.tsv`.
///
/// **The reason this file exists is the per-occurrence rule.** 和合本 is
/// not internally consistent, and the temptation on a list of 128
/// "classes" is to settle each class once and sweep. It writes 槓 for
/// the poles at 出埃及記 25:13 and 杆 for the same poles at 27:10; it
/// writes 茍合 and then 苟合 inside one verse of 以西結書; three verses
/// carry a pair the other way round from every other verse in the Bible.
/// A class-level verdict would have corrupted every one of those, so
/// each is pinned here by the words around it.
///
/// The refutations matter as much as the repairs: the Hong Kong glyph
/// ruling below this, and the three verses the back-conversion still
/// cannot see, are both things a later sweep would "fix" wrongly.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, String> tr;
  late String all;

  setUpAll(() {
    final rows =
        (jsonDecode(File('assets/cuvs-yhwh-tr.json').readAsStringSync())
                as List)
            .cast<Map<String, dynamic>>();
    tr = {for (final r in rows) r['id'] as String: r['text'] as String};
    all = rows.map((r) => r['text'] as String).join('\n');
  });

  group('one verdict per occurrence, never per class', () {
    test('出埃及記 writes 槓 at 25:13 and 杆 at 27:10, for the same poles',
        () {
      // The example the owner raised to refuse a sweep in the first
      // place. Both readings are the 和合本's own.
      expect(tr['002025013'], contains('兩根槓'));
      expect(tr['002027010'], contains('和杆子都要用銀子'));
    });

    test('以西結書 23:44 prints 茍合 and then 苟合, in that order', () {
      // The single place in the Bible where one pair takes both forms
      // inside one verse, so the position and not the verse is what the
      // verdict attaches to.
      final v = tr['026023044']!;
      expect(v, contains('二淫婦茍合'));
      expect(v, contains('與妓女苟合'));
      expect(v.indexOf('茍'), lessThan(v.indexOf('苟')));
    });

    test('the three verses where the pair is the other way round', () {
      // Both positions differed from ours, in opposite directions, so
      // either half of a class verdict would have been wrong here.
      expect(tr['009021013'], contains('門扇上胡寫亂畫'));
      expect(tr['009021013'], contains('唾沫流在鬍子上'));
      expect(tr['018041032'], contains('隨後發光'));
      expect(tr['018041032'], contains('如同白髮'));
      expect(tr['019065013'], contains('谷中也長滿了五穀'));
    });

    test('歌羅西書 4:10 keeps 里 in 亞里達古, a name and not a place-word',
        () {
      // The edition writes 那裏 for "there" in the same verse. A class
      // verdict on 裏/里 would have spelt the man 亞裏達古.
      final v = tr['051004010']!;
      expect(v, contains('亞里達古'));
      expect(v, contains('到了你們那裏'));
    });
  });

  group('the classes the 和合本 settled against us', () {
    test('the five 凋 sites, left alone for six days and then read', () {
      // These stood in test/edition_script_purity_test.dart as the
      // traditional edition's "own orthography", 雕 83 times against the
      // simplified 凋. The published 和合本 prints 凋殘 and 凋謝, so the
      // house style was a conversion error.
      expect(tr['023033009'], contains('樹林凋殘'));
      expect(tr['023040007'], contains('花必凋殘'));
      expect(tr['023040008'], contains('草必枯乾'));
      expect(tr['059001011'], contains('花也凋謝'));
      expect(tr['060001024'], contains('花必凋謝'));
      expect(all, isNot(contains('雕殘')));
      expect(all, isNot(contains('雕謝')));
    });

    test('a sample of the word-level moves, each at the verse it was read at',
        () {
      expect(tr['002027010'], contains('柱子上的鈎子'));   // 鈎, Hong Kong
      expect(tr['047001017'], contains('從情慾起的'));     // 欲 → 慾
      expect(tr['042002019'], contains('存在心裏'));       // 裏 kept
    });

    test('麽 is gone, because no conversion profile produces it', () {
      // OpenCC's base STCharacters maps 么 → 麼 outright and neither
      // HKVariants nor TWVariants introduces 麽. The 和合本 writes 甚麼.
      expect(all, isNot(contains('麽')));
      expect(all, contains('什麼'));
    });

    test('耶利米書 4:22 says who the people do not know', () {
      // The 我 sat one clause late, in both scripts, so the sentence
      // read 「不認識；他們是愚昧無知的我兒女」. The publisher's own text
      // has it right in both.
      expect(tr['024004022'], contains('不認識我；他們是愚昧無知的兒女'));
      final s = (jsonDecode(File('assets/cuvs-yhwh.json').readAsStringSync())
              as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((r) => r['id'] == '024004022')['text'] as String;
      expect(s, contains('不认识我；他们是愚昧无知的儿女'));
    });
  });

  group('what was deliberately NOT changed', () {
    test('the seven positions where 和合本 prints a third form are ours still',
        () {
      // Recorded as 都不是 rather than guessed at: adopting a form
      // neither conversion produced would be inventing text.
      expect(tr['023029018'], contains('迷蒙黑暗'));       // 和合本 迷矇
      expect(tr['044008027'], contains('女王干大基'));     // 和合本 甘大基
      expect(tr['038008004'], contains('手拿拐杖'));       // 和合本 柺杖
      expect(all, isNot(contains('柺')));
      expect(all, isNot(contains('矇')));
    });

    test('使徒行傳 27:33 is a wording difference, not a character one', () {
      // 和合本 reads 懸望忍餓; this edition reads 懸望一直挨餓. The 挨/捱
      // position has no counterpart to compare against, so it was left.
      expect(tr['044027033'], contains('懸望一直挨餓'));
    });

    test('the Hong Kong glyph ruling is untouched by any of this', () {
      // 「按照香港和合本的繁体字吧」. None of the 128 classes was a glyph
      // pair, and none of the 1,111 moved characters may become one.
      for (final hk in ['説', '着', '衞', '羣', '牀', '户', '悦', '卧']) {
        expect(all, contains(hk), reason: '$hk is the Hong Kong form');
      }
      for (final tw in ['說', '著', '衛', '群', '床', '戶', '悅', '臥']) {
        expect(all, isNot(contains(tw)), reason: '$tw is the Taiwan form');
      }
    });
  });
}
