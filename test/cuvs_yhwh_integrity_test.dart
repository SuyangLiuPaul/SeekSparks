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
  ];

  for (final spec in specs) {
    group('${spec.asset} integrity', () {
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
