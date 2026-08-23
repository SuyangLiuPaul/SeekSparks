// Regression guard for the bundled 和合本雅伟版 (CUVS-YHWH) text assets.
//
// 2026-08: 士师记 13:7 and 18:10 (and the mirrored traditional verses in
// 士師記) carried a stray `□` (U+25A1) between 归/歸 and 神. The defect
// is a corruption of the reverence space CUV prints before 神 — every
// other occurrence in the same file is normalised away (0 hits for
// `。 神`, 258 for `。神`), so the □ was a stale leftover. Removed it.
//
// This test prevents the corruption from coming back, and verifies the
// two verses carry exactly the text the canonical source
// (`assets/tagged/cuvs-yhwh/judges.json`, 孙树民 / yahwehdehua.net)
// reconstructs — not a guess.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

class _Spec {
  const _Spec(this.asset, this.label, this.expected);
  final String asset;
  final String label;
  final Map<String, String> expected; // verse-id → verified text
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const specs = <_Spec>[
    _Spec(
      'assets/cuvs-yhwh.json',
      '士师记 13:7 / 18:10',
      {
        '007013007':
            '却对我说：你要怀孕生一个儿子，所以清酒浓酒都不可喝，一切不洁之物也'
            '不可吃；因为这孩子从出胎一直到死，必归神作拿细耳人。',
        '007018010':
            '你们到了那里，必看见安居无虑的民，地也宽阔。神已将那地交在你们手'
            '中；那地百物俱全，一无所缺。',
      },
    ),
    _Spec(
      'assets/cuvs-yhwh-tr.json',
      '士師記 13:7 / 18:10',
      {
        '007013007':
            '卻對我說：你要懷孕生一個兒子，所以清酒濃酒都不可喝，一切不潔之物'
            '也不可吃；因為這孩子從出胎一直到死，必歸神作拿細耳人。',
        '007018010':
            '你們到了那裏，必看見安居無慮的民，地也寬闊。神已將那地交在你們手'
            '中；那地百物俱全，一無所缺。',
      },
    ),
    // Check 47. Five of the 27 single-character sites check 46 left as a
    // residue, re-read against two witnesses that do not descend from our
    // line (ebible.org cmn-cu89s, 信望愛 unv) — neither reproduces any of
    // the twelve defects check 46 repaired. Three of the five need no
    // external witness at all: our own text contradicts itself at 耶利米書
    // 7:10/7:11/7:30 (稱為我名下的殿), at 希伯來書 1:12 (which quotes 詩篇
    // 102:26 and keeps the 都), and at 約翰二書 1:7 (the same confession
    // formula, with its 的).
    _Spec(
      'assets/cuvs-yhwh.json',
      '检 47',
      {
        '019102026': '天地都要灭没，你却要长存；天地都要如外衣渐渐旧了。你要将天'
            '地如里衣更换，天地就都改变了。',
        '024007014': '所以我要向这称为我名下、你们所倚靠的殿，与我所赐给你们和你'
            '们列祖的地施行，照我从前向示罗所行的一样。',
        '031001005': '盗贼若来在你那里，或强盗夜间而来，（你何竟被剪除）岂不偷窃'
            '直到够了呢？摘葡萄的若来到你那里，岂不剩下些葡萄呢？',
        '044026016': '你起来站着，我特意向你显现，要派你作执事，作见证，将你所看'
            '见的事和我将要指示你的事证明出来；',
        '062004002': '凡灵认耶稣基督是成了肉身来的，就是出于神的；从此你们可以认'
            '出神的灵来。',
      },
    ),
    _Spec(
      'assets/cuvs-yhwh-tr.json',
      '檢 47',
      {
        '019102026': '天地都要滅沒，你卻要長存；天地都要如外衣漸漸舊了。你要將天'
            '地如裏衣更換，天地就都改變了。',
        '024007014': '所以我要向這稱為我名下、你們所倚靠的殿，與我所賜給你們和你'
            '們列祖的地施行，照我從前向示羅所行的一樣。',
        '031001005': '盜賊若來在你那裏，或強盜夜間而來，（你何竟被剪除）豈不偷竊'
            '直到夠了呢？摘葡萄的若來到你那裏，豈不剩下些葡萄呢？',
        '044026016': '你起來站著，我特意向你顯現，要派你作執事，作見證，將你所看'
            '見的事和我將要指示你的事證明出來；',
        '062004002': '凡靈認耶穌基督是成了肉身來的，就是出於神的；從此你們可以認'
            '出神的靈來。',
      },
    ),
  ];

  for (final spec in specs) {
    group('${spec.asset} integrity (${spec.label})', () {
      late List<dynamic> verses;

      setUpAll(() async {
        final raw = await rootBundle.loadString(spec.asset);
        verses = json.decode(raw) as List<dynamic>;
      });

      test('has the canonical 31,102 verses', () {
        expect(verses, hasLength(31102));
      });

      test('no verse carries the U+25A1 missing-glyph marker', () {
        // The 2026-08 fix removed two such glyphs; this guards against
        // any source re-import silently re-introducing them — or
        // introducing them anywhere else.
        final offenders = verses
            .whereType<Map<String, dynamic>>()
            .where((v) => (v['text'] as String?)?.contains('□') ?? false)
            .map((v) => v['id'])
            .toList();
        expect(offenders, isEmpty,
            reason: 'U+25A1 in Bible text means a character was lost in '
                'conversion; offenders: $offenders');
      });

      for (final entry in spec.expected.entries) {
        test('${spec.label} (${entry.key}) carries the verified text', () {
          final match = verses.firstWhere(
            (v) => (v as Map<String, dynamic>)['id'] == entry.key,
            orElse: () => fail('${entry.key} missing from ${spec.asset}'),
          ) as Map<String, dynamic>;
          expect(match['text'], entry.value);
        });
      }
    });
  }

  // 2026-08-12 (check 26): lookalike characters. Unlike □ these render
  // perfectly and sit in the same Unicode block as the text around them,
  // so neither a glyph-coverage check nor a repertoire check can see them
  // — only reading the words can. Repaired by
  // `tools/repair_cuvs_defects.py` against three witnesses; see
  // docs/DATA-INTEGRITY.md.
  const chineseAssets = <String>[
    'assets/cuvs-yhwh.json',
    'assets/cuvs-yhwh-tr.json',
    'assets/cuvs-plus.json',
  ];

  // Each entry is a reading that cannot be read in Chinese. 丶 U+4E36 is
  // the dot *stroke*, the character that names a piece of a glyph; it is
  // not punctuation and cannot occur in prose, and it stood where the
  // enumeration comma 、 U+3001 belongs.
  const unreadable = <String, String>{
    '丶': 'U+4E36 dot stroke standing in for the enumeration comma 、',
    '恉': '恉 (purport) standing in for 腮 (jaw) — 士師記 15:16',
    '逿': '逿 standing in for 趟 (to wade) — it differs only in the radical',
    '承巡': '承巡 standing in for 承受 — 耶利米書 12:14',
    '扔菏': '扔菏 standing in for 凶淫 — 士師記 20:6',
    '暇疵': '暇疵 (leisure-flaw) standing in for 瑕疵 — 撒母耳記下 14:25',
    // 2026-08-23 (check 46): twelve word-level defects in the *reading
    // text* — the layer the app actually prints — repaired by
    // `tools/repair_cuvs_yhwh_reading_text.py`. Each fragment below is
    // the corrupt state, and each is unreadable rather than merely odd:
    // a bound plural suffix with nothing to bind to, a doubled
    // character, a preposition dropped, a place name cut in half.
    '归到们': '们 is a bound plural suffix and cannot stand alone — 士師記 9:57',
    '歸到們': '们 is a bound plural suffix and cannot stand alone — 士師記 9:57',
    '的士师年': '"judged Israel ___ years" lost its numeral (H8337 שֵׁשׁ) — 士師記 12:7',
    '的士師年': '"judged Israel ___ years" lost its numeral (H8337 שֵׁשׁ) — 士師記 12:7',
    '因为罗变为': '推罗 (H6865 צֹר) cut to 罗, which names nothing — 以賽亞書 23:1',
    '因為羅變為': '推羅 (H6865 צֹר) cut to 羅, which names nothing — 以賽亞書 23:1',
    '地着的出产': '地着 is not Chinese; H6529+H127 is the fruit of the ground — 耶利米書 7:20',
    '地著的出產': '地著 is not Chinese; H6529+H127 is the fruit of the ground — 耶利米書 7:20',
    '城邑中里': '中里 doubles the locative — 耶利米書 50:32',
    '城邑中裏': '中裏 doubles the locative — 耶利米書 50:32',
    '记纪念碑': '记 and 纪 both survive where the word is two characters — 撒母耳記上 15:12',
    '記紀念碑': '記 and 紀 both survive where the word is two characters — 撒母耳記上 15:12',
    // 瑪拉基書 2:3 粪抹你们 was drafted as a guard here and WITHDRAWN. The
    // draft said 抹 cannot take a location without 在 and that H5921 עַל
    // was missing; this edition writes 抹 with a bare object eight times
    // (抹他的舌头, 抹我的脚, 抹墙), and the tagged layer already puts
    // H5921 on 你们的脸上 — the 上 *is* עַל. A published 和合本 reads it
    // as we ship it. See the repair script for the full retraction.
    //
    // Six more the adjudicator structurally could not see: it only
    // reported where the reading text stood alone, and in five of these
    // our own tagged layer had inherited the same loss. Found instead by
    // diffing the two flat editions on Han characters alone.
    '像烧碎一样': 'the object of the simile (H7179 קַשׁ, stubble) is gone — 出埃及記 15:7',
    '像燒碎一樣': 'the object of the simile (H7179 קַשׁ, stubble) is gone — 出埃及記 15:7',
    '作以色的': '以色 names nothing; H3478 יִשְׂרָאֵל — 士師記 12:13',
    '站玛他提雅': '站 is stranded subjectless before a name list — 尼希米記 8:4',
    '站瑪他提雅': '站 is stranded subjectless before a name list — 尼希米記 8:4',
    // NOT because 上友 is impossible — 尚友 is attested in 孟子 — but
    // because the 上 it is made of belongs to 嘴上, H8193 שְׂפָתָיו, lips.
    '为上友': 'the 上 of 嘴上 (H8193, lips) was displaced to here — 箴言 22:11',
    '為上友': 'the 上 of 嘴上 (H8193, lips) was displaced to here — 箴言 22:11',
    '江河并河的': '江河并河 repeats without naming anything new — 詩篇 78:44',
    '江河並河的': '江河并河 repeats without naming anything new — 詩篇 78:44',
    '愚昧人所用': 'H7462 רֹעֶה is a shepherd; the chapter is about the '
        'foolish SHEPHERD, and the run tagged H7462 holds only 人 '
        '— 撒迦利亞書 11:15',
  };

  for (final asset in chineseAssets) {
    group('$asset lookalike characters', () {
      late List<dynamic> verses;

      setUpAll(() async {
        verses = json.decode(await rootBundle.loadString(asset)) as List<dynamic>;
      });

      unreadable.forEach((bad, why) {
        test('carries no $bad', () {
          final offenders = verses
              .whereType<Map<String, dynamic>>()
              .where((v) => (v['text'] as String? ?? '').contains(bad))
              .map((v) => v['id'])
              .toList();
          expect(offenders, isEmpty, reason: '$why; offenders: $offenders');
        });
      });

      // 2026-08-12: every 歷代志上/下 record in the traditional file
      // carried id `000CCCVVV`, colliding with 創世記 and with each other
      // — 562 collisions over 1,764 records. Nothing rendered wrong,
      // because `Verse.fromJson` never reads this field and `Verse.id` is
      // computed from the book name. It is guarded because the field is
      // the join key any future cross-edition work would reach for, and a
      // silently duplicated key is the kind of defect that only surfaces
      // once something depends on it.
      test('every id is a well-formed, unique BBBCCCVVV', () {
        final seen = <String>{};
        final malformed = <String>[];
        final duplicated = <String>[];
        for (final v in verses.whereType<Map<String, dynamic>>()) {
          final id = v['id'] as String? ?? '';
          if (id.length != 9 ||
              int.tryParse(id) == null ||
              id.substring(0, 3) == '000') {
            malformed.add('$id (${v['book']} ${v['chapter']}:${v['verse']})');
          }
          if (!seen.add(id)) duplicated.add(id);
        }
        expect(malformed, isEmpty,
            reason: 'a zero or non-numeric book ordinal is not a verse key');
        expect(duplicated, isEmpty,
            reason: 'two verses cannot share one key');
      });
    });
  }
}
