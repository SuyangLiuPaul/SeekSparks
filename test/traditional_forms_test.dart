/// The Traditional edition's characters, and the words they have to be.
///
/// `assets/cuvs-yhwh-tr.json` was produced from the Simplified edition by
/// a conversion that resolved each ambiguous character once instead of
/// per word, so where Simplified writes one character for two Traditional
/// words it chose wrong every time. `tools/repair_cuvs_yhwh_tr.py` fixed
/// it; these tests are what stop a re-import from undoing that.
///
/// The refutation cases matter as much as the fixes. A blanket
/// `opencc -c s2t` over this file repairs most of it and INVENTS a new
/// defect at 以賽亞書 29:17, so the test asserts both directions: the
/// words that had to change, and the ones that had to stay.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<Map<String, dynamic>> _load(String name) =>
    (jsonDecode(File('assets/$name.json').readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();

String _verse(List<Map<String, dynamic>> d, String b, int c, int v) =>
    d.firstWhere((x) =>
        x['book'] == b && x['chapter'] == '$c' && x['verse'] == '$v')['text']
        as String;

void main() {
  late List<Map<String, dynamic>> tr;
  late String all;

  setUpAll(() {
    tr = _load('cuvs-yhwh-tr');
    all = tr.map((v) => v['text'] as String).join();
  });

  group('雅偉繁體 — the words the conversion got wrong', () {
    test('只 is the adverb; 隻 is the classifier', () {
      // The verse the owner reported.
      expect(_verse(tr, '以賽亞書', 2, 16), contains('船隻'));
      expect(all, isNot(contains('船只')));
      // A numeral in front makes it a classifier, and the whole verse
      // has to agree with itself.
      expect(_verse(tr, '列王紀上', 7, 25), contains('十二隻銅牛'));
      expect(_verse(tr, '列王紀上', 7, 25), contains('三隻向北'));
    });

    test('余 is the archaic pronoun "I"; 餘 is "remaining"', () {
      // All 230 were read: none is a pronoun and none is a name, which
      // is why this one is unconditional where the others are not.
      expect(all, isNot(contains('余')));
      expect(all, contains('其餘'));
      expect(_verse(tr, '出埃及記', 26, 12), contains('所餘'));
    });

    test('乾 is dry; 干 is to offend; 幹 is a trunk', () {
      // Exodus 14 — the sea crossing. 幹 also carries a coarse slang
      // reading in Taiwan, so this one was never merely a typo.
      expect(_verse(tr, '出埃及記', 14, 22), contains('走乾地'));
      expect(all, isNot(contains('走幹地')));
      expect(all, contains('枯乾'));

      // 干犯 and 亞干 are plain 干 — a "幹 → 乾" rule would have printed
      // 乾犯 and 亞乾, which is why the repair is three-way.
      expect(all, isNot(contains('幹犯')));
      expect(all, isNot(contains('乾犯')));
      expect(all, contains('干犯'));
      expect(all, isNot(contains('亞幹')));
      expect(all, isNot(contains('亞乾')));

      // …and the nine genuine 幹 survive both conversions.
      expect(_verse(tr, '馬太福音', 25, 15), contains('才幹'));
      expect(_verse(tr, '以西結書', 19, 11), contains('枝幹'));
      expect(_verse(tr, '出埃及記', 25, 31), contains('座和幹'));
      expect(_verse(tr, '約伯記', 14, 8), contains('幹也死在土中'));
    });

    test('淨 is the standard form; 凈 is the variant it shipped with', () {
      // Not a meaning error — recorded separately for that reason. It is
      // converted because 幹凈 has to reach 乾淨 rather than 乾凈, and
      // because the edition already uses standard forms elsewhere.
      expect(all, isNot(contains('凈')));
      expect(all, contains('乾淨'));
    });
  });

  group('雅偉繁體 — what a blanket conversion would have broken', () {
    test('以賽亞書 29:17 still reads 只有, not 隻有', () {
      // `opencc -c s2t` turns this into 隻有. It is the single case that
      // rules out running a converter over the file, so it is asserted
      // by name rather than left to the aggregate counts.
      expect(_verse(tr, '以賽亞書', 29, 17), contains('不是只有一點點時候'));
    });

    test('the adverbial 只 is left alone wherever it stands', () {
      for (final w in ['只是', '只要', '只有', '只管', '只剩', '只因']) {
        expect(all, contains(w), reason: '$w must survive');
      }
      // …and never acquires a classifier it cannot have.
      for (final w in ['隻是', '隻管', '隻剩', '隻因']) {
        expect(all, isNot(contains(w)), reason: '$w is not a word');
      }
    });

    test('隻有 and 隻要 occur only where a numeral put them there', () {
      // Nine of them, and every one is a classifier followed by a
      // separate word: 兩隻有乳的母牛, 每隻要獻, 每第十隻要歸給雅偉為聖.
      final odd = <String>[];
      for (final v in tr) {
        final t = v['text'] as String;
        for (final m in RegExp('.?隻(有|要)').allMatches(t)) {
          final before = m.group(0)![0];
          if (!'一二三四五六七八九十百千萬兩幾每那船'.contains(before)) {
            odd.add('${v['book']} ${v['chapter']}:${v['verse']} ${m.group(0)}');
          }
        }
      }
      expect(odd, isEmpty);
    });
  });

  test('梁家鏗繁體 was converted correctly and is not to be "fixed"', () {
    // The sibling Traditional asset. Its 幹 are all genuine (幹活, 才幹,
    // 幹掉), it already writes 隻/餘/淨, and it uses 裡 where the 和合本
    // uses 裏 — a different but internally consistent house style.
    // Asserted so that a future pass at this defect does not go looking
    // for it here and convert something that was never wrong.
    final xg = _load('biblexg-v2-tr').map((v) => v['text'] as String).join();
    expect(xg, isNot(contains('余')));
    expect(xg, isNot(contains('凈')));
    expect(xg, contains('隻'));
    expect(xg, contains('餘'));
    expect(xg, contains('淨'));
  });
}
