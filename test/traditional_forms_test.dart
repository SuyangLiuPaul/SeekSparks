/// The Traditional editions' characters, and the words they have to be.
///
/// `assets/cuvs-yhwh-tr.json` was produced from the Simplified edition by
/// a conversion that resolved each ambiguous character once instead of
/// per word, so where Simplified writes one character for two Traditional
/// words it chose wrong every time. `tools/repair_cuvs_yhwh_tr.py` fixed
/// it; these tests are what stop a re-import from undoing that.
///
/// `assets/biblexg-v2-tr.json` has a different, much smaller defect: it
/// ships alongside its own Simplified twin, so where the conversion
/// turned 说 into 說 1,898 times and into 説 4 times, the 4 are the
/// defect. `tools/repair_biblexg_v2_tr.py` fixed 30 such characters.
///
/// The refutation cases matter as much as the fixes. A blanket
/// `opencc -c s2t` over cuvs-yhwh-tr repairs most of it and INVENTS a new
/// defect at 以賽亞書 29:17; over biblexg-v2-tr it would print 佔星, 僕倒,
/// 幹犯, 遊泳 and 公裡. So every test here asserts both directions: the
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

  group('梁家鏗繁體 — free of the 雅偉 defect, and of its own 30', () {
    late List<Map<String, dynamic>> xg;
    late String all;

    setUpAll(() {
      xg = _load('biblexg-v2-tr');
      all = xg.map((v) => v['text'] as String).join();
    });

    test('it never had the 雅偉 defect and is not to be "fixed" for it', () {
      // Its 幹 are all genuine (幹活, 才幹, 幹掉), it already writes
      // 隻/餘/淨, and it uses 裡 where the 和合本 uses 裏 — a different
      // but internally consistent house style.
      expect(all, isNot(contains('余')));
      expect(all, isNot(contains('凈')));
      expect(all, contains('隻'));
      expect(all, contains('餘'));
      expect(all, contains('淨'));
    });

    test('the Simplified twin is missing exactly 馬可福音 6:8-11', () {
      // Check 41f. Four verses are absent from biblexg-v2.json and its
      // 6:7 stops mid-clause. Not repaired: the editions agree only
      // 78% under t2s, so converting the Traditional text back would
      // invent house-style spellings in a translator's own Bible.
      //
      // Pinned rather than asserted-away for two reasons: a NEW gap in
      // either edition fails this test, and repairing the known one
      // fails it too — at which point update check 41f rather than the
      // expectation.
      final s = _load('biblexg-v2').map((v) => v['id'] as String).toSet();
      final t = xg.map((v) => v['id'] as String).toSet();
      expect(t.difference(s).toList()..sort(),
          ['41006008', '41006009', '41006010', '41006011']);
      expect(s.difference(t), isEmpty);
      // The recoverable text has to stay recoverable.
      expect(_verse(xg, '馬可福音', 6, 8), contains('上路只帶一根手杖'));
      expect(_verse(xg, '馬可福音', 6, 7), contains('制服不潔的靈'));
    });

    test('every 隻 is accounted for, 46 of them by a numeral', () {
      // Positional, the rule that made 只 tractable in the 雅偉 repair.
      // 46 follow a numeral outright; the set also carries 船 for the
      // compound 船隻 ×3 and 隻 for 一隻隻 (約翰福音 10:3, a classifier
      // reduplication), so this asserts "none is unexplained" rather
      // than "all are classifiers".
      const det = '一二三四五六七八九十百千萬兩幾每那船隻';
      final odd = <String>[];
      var seen = 0;
      for (final v in xg) {
        final t = v['text'] as String;
        for (var i = t.indexOf('隻'); i >= 0; i = t.indexOf('隻', i + 1)) {
          seen++;
          if (i == 0 || !det.contains(t[i - 1])) {
            odd.add('${v['book']} ${v['chapter']}:${v['verse']} '
                '${t.substring(i - 1 < 0 ? 0 : i - 1, i + 1)}');
          }
        }
      }
      expect(seen, 50, reason: 'the assertion is vacuous if 隻 disappears');
      expect(odd, isEmpty);
    });

    test('class A — the Simplified characters that survived the conversion',
        () {
      // The file converts 稣→穌 1,123×, 话→話 468×, 满→滿 167× … and
      // missed one each. Twelve sites, every one asserted by name.
      expect(_verse(xg, '馬可福音', 14, 58), contains('我要拆毀這座'));
      expect(_verse(xg, '馬可福音', 14, 58), contains('三天之內，另起'));
      expect(_verse(xg, '使徒行傳', 18, 16), contains('從審判臺前趕'));
      expect(_verse(xg, '使徒行傳', 20, 32), contains('已經分別為聖'));
      expect(_verse(xg, '羅馬書', 10, 8), contains('這話就在眼前'));
      expect(_verse(xg, '哥林多前書', 14, 14), contains('大腦是沒有運作'));
      expect(_verse(xg, '歌羅西書', 1, 9), contains('旨意充滿深刻'));
      expect(_verse(xg, '歌羅西書', 3, 9), contains('你們已經脫掉了'));
      expect(_verse(xg, '歌羅西書', 4, 6), contains('常常要溫和'));
      expect(_verse(xg, '提多書', 2, 3), contains('上了年紀的婦女'));
      expect(_verse(xg, '提多書', 3, 15), contains('在信仰內愛我們'));
      // A note, not verse text — the screen has to reach inside those too.
      expect(_verse(xg, '啟示錄', 1, 1), contains('<note:指耶穌基督>'));

      for (final w in [
        '拆毁', '三天之内', '审判臺', '分别為聖', '這话', '是没有',
        '充满', '脱掉', '温和', '年纪', '信仰内', '耶稣基督',
      ]) {
        expect(all, isNot(contains(w)), reason: '$w is Simplified');
      }
    });

    test('class B — 馬可福音 1:23 wants 裡, and the other 45 里 are right',
        () {
      expect(_verse(xg, '馬可福音', 1, 23), contains('在他們的會堂裡有一個'));
      expect(all, isNot(contains('會堂里')));
      // 里 itself is not the problem and must not be swept: a unit, an
      // instrument, and eight proper names.
      for (final w in ['公里', '里拉琴', '提比里亞', '克里特', '堅革里']) {
        expect(all, contains(w), reason: '$w is correct Traditional');
      }
      for (final w in ['公裡', '裡拉琴', '提比裡亞', '克裡特', '堅革裡']) {
        expect(all, isNot(contains(w)), reason: '$w is a swept 里');
      }
    });

    test('class C — where the conversion went TOO FAR', () {
      // Invisible to a "Simplified survivor" screen, because the output
      // is a real Traditional character. 准 is to permit; 準 is accurate.
      // The file itself writes 准許 6× and all nine sources read 准许.
      expect(_verse(xg, '馬可福音', 5, 13), contains('耶穌准許了他們'));
      expect(_verse(xg, '馬可福音', 8, 30), contains('不准許他們告訴'));
      expect(_verse(xg, '馬可福音', 10, 4), contains('摩西准許，寫休書'));
      expect(all, isNot(contains('準許')));
      // 矇 is for eyes and deception; a covered face is 蒙.
      expect(_verse(xg, '馬可福音', 14, 65), contains('吐唾沫，蒙住他的臉'));
      expect(all, isNot(contains('矇')));
    });

    test('class D — 舊字形 stragglers are a SEARCH defect, not a meaning one',
        () {
      // 説 and 說 are the same character, but a reader who types 開啟
      // finds 1 of this file's 4, and 他說過 misses 馬可福音 14:58.
      expect(_verse(xg, '馬可福音', 14, 58), contains('我們聽見他說過'));
      expect(_verse(xg, '路加福音', 7, 31), contains('耶穌又說：'));
      expect(_verse(xg, '使徒行傳', 1, 10), contains('站在旁邊說：'));
      expect(_verse(xg, '使徒行傳', 18, 12), contains('拉到審判臺前說：'));
      expect(_verse(xg, '哥林多前書', 15, 3), contains('所記，為我們的罪'));
      expect(_verse(xg, '約翰福音', 8, 46), contains('誰能指證我有罪'));
      expect(_verse(xg, '路加福音', 24, 32), contains('給我們開啟的時候'));
      expect(_verse(xg, '使徒行傳', 14, 27), contains('為外族開啟了'));
      expect(_verse(xg, '使徒行傳', 17, 3), contains('將經文逐一開啟，'));
      expect(_verse(xg, '使徒行傳', 20, 6), contains('由腓立比啟航'));
      expect(_verse(xg, '使徒行傳', 21, 2), contains('便上船啟程。'));
      expect(_verse(xg, '哥林多前書', 16, 11), contains('送他平安啟程'));

      for (final c in ['説', '爲', '啓', '証']) {
        expect(all, isNot(contains(c)), reason: '$c is the old glyph form');
      }
    });

    test('class E — 使徒行傳 7:32 is settled by the file against itself', () {
      // 颤斗 is an upstream typo in BOTH editions, but this same file
      // already writes 顫抖 at 馬可福音 16:8 from the identical Simplified
      // string. Repaired on its own precedent, not on an outside source.
      expect(_verse(xg, '使徒行傳', 7, 32), contains('摩西渾身顫抖，'));
      expect(_verse(xg, '馬可福音', 16, 8), contains('顫抖'));
      expect(all, isNot(contains('顫斗')));
    });

    test('the 舊字形 opencc calls wrong are left alone', () {
      // opencc maps 吃→喫, 群→羣, 秘→祕, 床→牀, 唇→脣, 岳→嶽, 熏→燻.
      // This file converts none of them, 499 times over, so the file is
      // the authority and opencc's output is what would be the defect.
      for (final w in ['吃', '群', '秘', '床', '唇', '岳', '熏']) {
        expect(all, contains(w));
      }
      for (final w in ['喫', '羣', '祕', '牀', '脣', '嶽', '燻']) {
        expect(all, isNot(contains(w)), reason: '$w is opencc over-reaching');
      }
    });

    test('the homograph pairs opencc would flip are correct as they stand',
        () {
      // Each of these is a character opencc reports as convertible, read
      // one word at a time against the Simplified twin. Frozen so a
      // future sweep cannot "repair" a word that was never wrong.
      const keep = {
        '占星': '佔星', '占卜': '佔卜', // to divine, not to occupy
        '仆倒': '僕倒', // to fall prostrate, not a servant
        '干犯': '幹犯', '王干大基': '王幹大基', // to offend; Candace
        '征服': '徵服', // to conquer, not to levy
        '采烈': '採烈', '風采': '風採', // demeanour, not to pick
        '游泳': '遊泳', // in water, not to wander
        '斗篷': '鬥篷', '三斗麵': '三鬥麵', // a measure, not to fight
        '模仿': '模倣',
      };
      keep.forEach((good, bad) {
        expect(all, contains(good), reason: '$good must survive');
        expect(all, isNot(contains(bad)), reason: '$bad is a bad conversion');
      });
    });
  });
}
