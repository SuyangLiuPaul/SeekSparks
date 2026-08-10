// Regression guard for the 梁家鏗譯本 verse boundaries.
//
// `assets/biblexg-v2.json` (简) and `assets/biblexg-v2-tr.json` (繁) are one
// NT-only edition whose converter lost verse boundaries in seven places —
// filing 馬太福音 16:13 under 16:3 where it collided with the real 16:3,
// splitting 使徒行傳 15:16 across two rows, swallowing 以弗所書 3:16's verse
// number into a footnote, and leaving five further verse numbers sitting
// inline in the text where they printed as scripture. `tools/repair_biblexg.py`
// repaired all seven; this test holds them repaired.
//
// It also freezes the two defects that were NOT repaired, at their measured
// size, so neither can grow while a witness is sought:
//   * 馬可福音 6:8-11 are absent from the simplified file only, and restoring
//     them would need a 繁→简 conversion this repository will not invent.
//   * Twenty-one records carry a range label (`1-4`, `18-19`) because the
//     publisher printed those verses merged. That is the publisher's own
//     honest labelling, not a defect — but a range that overlaps a verse
//     which also exists as its own record is a contradiction, and there are
//     exactly two.
//
// The suite passed for the project's whole life with all seven defects live,
// so every assertion here is on the asset bytes rather than on any code path.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

const _simplified = 'assets/biblexg-v2.json';
const _traditional = 'assets/biblexg-v2-tr.json';

Future<List<Map<String, dynamic>>> _load(String asset) async {
  final raw = await rootBundle.loadString(asset);
  return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
}

String _ref(Map<String, dynamic> v) =>
    '${v['book']} ${v['chapter']}:${v['verse']}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final asset in const [_simplified, _traditional]) {
    group(asset, () {
      test('every reference appears exactly once', () async {
        final verses = await _load(asset);
        final seen = <String, int>{};
        for (final v in verses) {
          seen.update(_ref(v), (n) => n + 1, ifAbsent: () => 1);
        }
        final duplicated = seen.entries.where((e) => e.value > 1).toList();
        expect(duplicated, isEmpty,
            reason: 'a duplicate reference means lookup keeps one row and '
                'the reader silently loses the other');
      });

      test('no verse is empty', () async {
        final verses = await _load(asset);
        final blank = verses.where((v) => (v['text'] as String).trim().isEmpty);
        expect(blank.map(_ref), isEmpty);
      });

      test('id and verseLabel agree with the verse number', () async {
        final verses = await _load(asset);
        for (final v in verses) {
          final number = int.parse(v['verse'] as String);
          expect((v['id'] as String).substring(5), number.toString().padLeft(3, '0'),
              reason: '${_ref(v)} id does not encode its verse number');
          final label = v['verseLabel'] as String;
          // A range label is the publisher's, and is checked separately.
          if (!label.contains('-')) {
            expect(label, v['verse'], reason: '${_ref(v)} label drifted');
          }
        }
      });

      test('no verse number is left printing as scripture', () async {
        final verses = await _load(asset);
        final offenders = <String>[];
        for (final v in verses) {
          final body =
              (v['text'] as String).replaceAll(RegExp(r'<note:[^>]*>'), '');
          for (final m in RegExp(r'\d+').allMatches(body)) {
            // NA28 / UBS5 name the critical editions and are real text; they
            // are the only digits this edition prints on purpose.
            final around = body.substring(
                (m.start - 3).clamp(0, body.length), m.start);
            if (around.endsWith('NA') || around.endsWith('UBS')) continue;
            offenders.add('${_ref(v)} → ${m.group(0)}');
          }
        }
        expect(offenders, isEmpty,
            reason: 'a bare number inside verse text is a verse marker the '
                'converter failed to split out, and the reader reads it as '
                'part of the sentence');
      });

      test('a range label never overlaps a verse that also has its own row',
          () async {
        final verses = await _load(asset);
        final present = verses.map(_ref).toSet();
        final contradictions = <String>[];
        for (final v in verses) {
          final label = v['verseLabel'] as String;
          final m = RegExp(r'^(\d+)-(\d+)$').firstMatch(label);
          if (m == null) continue;
          final lo = int.parse(m.group(1)!);
          final hi = int.parse(m.group(2)!);
          for (var n = lo; n <= hi; n++) {
            if (n.toString() == v['verse']) continue;
            if (present.contains('${v['book']} ${v['chapter']}:$n')) {
              contradictions.add('${_ref(v)} labelled $label vs '
                  '${v['book']} ${v['chapter']}:$n');
            }
          }
        }
        // Both are 以弗所書, identical in the two files, and are the
        // publisher's labels rather than lost text — 2:20 genuinely pulls
        // 2:21's 「在主內的一座聖所」 forward, and 3:10 appears to carry a
        // stray label. Recorded in docs/DATA-INTEGRITY.md; frozen here so a
        // third cannot appear unnoticed.
        expect(contradictions.length, 2, reason: contradictions.join('; '));
      });
    });
  }

  test('the seven repaired boundaries hold, in the traditional file',
      () async {
    final verses = await _load(_traditional);
    final byRef = {for (final v in verses) _ref(v): v['text'] as String};

    // T1 — 16:13 exists, and 16:3 is the weather-signs saying it always was.
    expect(byRef['馬太福音 16:13'],
        startsWith('耶穌來到該撒利亞腓立比境內'));
    expect(byRef['馬太福音 16:3'], startsWith('早晨你們說'));

    // T2 — one row carrying both the prose and the Amos quotation.
    expect(byRef['使徒行傳 15:16'], startsWith('如經上所記：'));
    expect(byRef['使徒行傳 15:16'], contains('大衛傾塌的帳幕'));

    // T3 — the footnote no longer eats verse 16's number.
    expect(byRef['以弗所書 3:15'], endsWith('<note:參4.6、>'));
    expect(byRef['以弗所書 3:16'], startsWith('我求父：'));

    // T4 — the Psalm 34 quotation is three verses again.
    expect(byRef['彼得前書 3:10'], endsWith('管住嘴唇不沾詭詐。'));
    expect(byRef['彼得前書 3:11'], '還要避惡行善，覓求和睦，緊追不捨。');
    expect(byRef['彼得前書 3:12'], startsWith('因為主慈目眷顧義人'));
  });

  test('the three shared boundaries hold, in both files', () async {
    for (final asset in const [_simplified, _traditional]) {
      final verses = await _load(asset);
      final byRef = {for (final v in verses) _ref(v): v['text'] as String};
      // 路加福音 is spelt the same in both scripts.
      const luke = '路加福音';

      // B5 — the angel and the sweat like blood are their own verses.
      expect(byRef['$luke 22:43'], isNotNull, reason: asset);
      expect(byRef['$luke 22:44'], isNotNull, reason: asset);
      expect(byRef['$luke 22:42'], endsWith('。”'), reason: asset);

      // B6.
      expect(byRef['$luke 23:17'], isNotNull, reason: asset);

      // B7 — 「父親啊，赦免他們」 is at 23:34, where a reader looks for it,
      // rather than trailing 23:33 behind a `34a` marker.
      expect(byRef['$luke 23:34'],
          anyOf(contains('赦免他們'), contains('赦免他们')),
          reason: asset);
      expect(byRef['$luke 23:33'],
          anyOf(endsWith('左手一個。'), endsWith('左手一个。')),
          reason: asset);
    }
  });

  test('馬可福音 6:8-11 remain the only gap needing a script conversion',
      () async {
    final simplified = await _load(_simplified);
    final traditional = await _load(_traditional);

    // The two files use different book names, so pair them by first
    // appearance rather than by string.
    List<String> booksOf(List<Map<String, dynamic>> vs) {
      final out = <String>[];
      for (final v in vs) {
        if (out.isEmpty || out.last != v['book']) out.add(v['book'] as String);
      }
      return out;
    }

    final pairing = Map.fromIterables(
        booksOf(simplified), booksOf(traditional));
    final inSimplified = simplified
        .map((v) => '${pairing[v['book']]} ${v['chapter']}:${v['verse']}')
        .toSet();
    final inTraditional = traditional.map(_ref).toSet();

    expect(inSimplified.difference(inTraditional), isEmpty,
        reason: 'the traditional file is now complete against the simplified');
    expect(
        inTraditional.difference(inSimplified).toList()..sort(),
        ['馬可福音 6:10', '馬可福音 6:11', '馬可福音 6:8', '馬可福音 6:9'],
        reason: 'the simplified file also stops mid-clause at 6:7 — restoring '
            'these needs a 繁→简 conversion, so they stay measured, not '
            'invented');
  });
}
