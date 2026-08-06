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
}
