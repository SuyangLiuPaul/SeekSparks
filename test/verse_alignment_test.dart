// Regression guard for the two references that answered with the verse
// next door.
//
// `docs/DATA-INTEGRITY.md` check 20 asked a question no key-set check can
// ask: not "does this edition have a record for every reference" — every
// check before it asked that — but "does the record hold the RIGHT verse".
// An edition can carry all 31,102 references, every one of them numbered
// correctly, and still print verse 43's second half under 44. Nothing
// counts wrong. Nothing is missing. The reader is simply told something
// untrue about where a sentence sits in the text, which is the one class
// of defect this project ranks above every feature.
//
// The sweep ran three passes over 152,440 English, 108,754 Chinese, 7,910
// Greek-NT and 130,152 cross-language Strong's-pivoted comparisons and
// found exactly two. Both are frozen here, on the asset bytes, because
// both survived every existing check and the suite stayed green through
// them for the project's whole life.
//
//   * 和简+ 馬可福音 9:43 and 9:45 each stopped at the semicolon, and the
//     half that follows was filed as 9:44 and 9:46 — references the
//     critical text does not contain, so 和简+ was the only edition we
//     ship that answered them with scripture. `assets/tagged/cuvs-plus/
//     mark.json` carried the same split, so Word Study, search, KWIC and
//     the concordance all agreed with it.
//   * 梁家鏗譯本 腓立比書 1:1 was printed as two blocks, senders then
//     addressees, and the second was numbered 2. Philippians names its
//     readers inside verse 1; the real verse 2, the grace, is in neither
//     file. So the edition answered 1:2 with the address, and never with
//     「願恩惠平安⋯」.
//
// Neither repair invented a character. The Mark halves were rejoined and
// the emptied references left to `VerseAbsence.blank`; the Philippians
// blocks were merged and 1:2 left absent, joining the gaps the edition
// already has.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/verse_text_absence.dart';

Future<List<Map<String, dynamic>>> _verses(String asset) async {
  final raw = await rootBundle.loadString('assets/$asset.json');
  return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
}

Future<Map<String, String>> _chapter(
    String asset, String book, String chapter) async {
  return {
    for (final v in await _verses(asset))
      if (v['book'] == book && '${v['chapter']}' == chapter)
        '${v['verse']}': v['text'] as String,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('馬可福音 9:43-46 in all three 和合本 editions', () {
    // 43 and 45 are one sentence each — "if thy hand offend thee, cut it
    // off: it is better for thee to enter into life maimed, than having
    // two hands to go into hell" is a single KJV verse — and 44 and 46
    // are among the sixteen references the critical text omits.
    const clauses = {
      'cuvs-plus': {
        '43': '倘若你一只手叫你跌倒，就把它砍下来；'
            '你缺了肢体进入永生，强如有两只手落到地狱，入那不灭的火里去。',
        '45': '倘若你一只脚叫你跌倒，就把它砍下来；'
            '你瘸腿进入永生，强如有两只脚被丢在地狱里。',
      },
    };

    test('cuvs-plus holds each verse whole', () async {
      final mark = await _chapter('cuvs-plus', '马可福音', '9');
      expect(mark['43'], clauses['cuvs-plus']!['43']);
      expect(mark['45'], clauses['cuvs-plus']!['45']);
    });

    test('the omitted references carry no scripture in any edition',
        () async {
      // The point of the whole repair: whatever the three editions put in
      // 9:44 and 9:46, none of it may read as the verse. Two print their
      // own editorial note; 和简+ has nothing to print and says so.
      for (final asset in const ['cuvs-yhwh', 'cuvs-plus', 'cuvs-yhwh-tr']) {
        final book = asset == 'cuvs-yhwh-tr' ? '馬可福音' : '马可福音';
        final mark = await _chapter(asset, book, '9');
        for (final n in const ['44', '46']) {
          final text = mark[n];
          expect(text, isNotNull, reason: '$asset lost 9:$n');
          final scripture = verseAbsenceOf(text!) == null &&
              !(text.startsWith('<note:') && text.endsWith('>'));
          expect(scripture, isFalse,
              reason: '$asset 9:$n reads as scripture: $text');
        }
      }
    });

    test('the tagged layer stopped agreeing with the split', () async {
      // The defect was in two assets, not one. A repair that fixed only
      // the text would leave Word Study, search and the concordance
      // reporting 和简+ hits at 9:44.
      final raw = await rootBundle
          .loadString('assets/tagged/cuvs-plus/mark.json');
      final tagged = (jsonDecode(raw) as Map<String, dynamic>);
      expect(tagged.containsKey('9:44'), isFalse);
      expect(tagged.containsKey('9:46'), isFalse);

      String spell(String ref) => ((tagged[ref] as List)
              .cast<Map<String, dynamic>>())
          .map((r) => r['w'] as String)
          .join();
      expect(spell('9:43'), clauses['cuvs-plus']!['43']);
      expect(spell('9:45'), clauses['cuvs-plus']!['45']);
    });

    test('every 和简+ reference with words has runs, and no others',
        () async {
      // The general invariant the repair had to preserve. Tagging
      // describes words; a reference with no words must have no runs, and
      // a reference with runs must have words — otherwise the two layers
      // can drift apart again and only one of them will be noticed.
      final worded = <String>{};
      for (final v in await _verses('cuvs-plus')) {
        if (v['book'] != '马可福音') continue;
        if ((v['text'] as String).trim().isEmpty) continue;
        worded.add('${v['chapter']}:${v['verse']}');
      }
      final raw = await rootBundle
          .loadString('assets/tagged/cuvs-plus/mark.json');
      final tagged = (jsonDecode(raw) as Map<String, dynamic>).keys.toSet();
      expect(tagged, worded);
    });
  });

  group('腓立比書 1:1 in the 梁家鏗譯本', () {
    const opening = {
      'biblexg-v2': [
        '腓立比书',
        '保罗和提摩太，基督耶稣的奴仆——致在腓立比在基督耶稣里的全体圣徒、各位监督及执事：',
        '我每次想起你们就感谢我的神，',
      ],
      'biblexg-v2-tr': [
        '腓立比書',
        '保羅和提摩太，基督耶穌的奴僕——致在腓立比在基督耶穌裡的全體聖徒、各位監督及執事：',
        '我每次想起你們就感謝我的神，',
      ],
    };

    for (final entry in opening.entries) {
      test('${entry.key} carries the whole of verse 1 at 1:1', () async {
        final chapter = await _chapter(entry.key, entry.value[0], '1');
        expect(chapter['1'], entry.value[1]);
        expect(chapter['3'], entry.value[2]);
      });

      test('${entry.key} leaves 1:2 absent rather than wrong', () async {
        // The grace greeting is nowhere in the book. Writing it in from
        // another edition would be putting a sentence in this
        // translator's mouth — the two 梁家鏗譯本 scripts were
        // independently revised, so even the sibling file is a witness to
        // structure only. Under-coverage, not a false statement.
        final chapter = await _chapter(entry.key, entry.value[0], '1');
        expect(chapter.containsKey('2'), isFalse);
        expect(chapter.values.any((t) => t.contains('恩惠平安')), isFalse);
      });
    }

    test('the five letters with the same typography are untouched',
        () async {
      // 羅馬書, 哥林多前書, 歌羅西書, 提摩太前書 and 提摩太後書 all open
      // with the senders block ending in ——, and in every one of them the
      // block numbered 2 really is verse 2. The em-dash was never the
      // signal; Philippians is the only letter that names its readers
      // inside verse 1.
      final chapters = {
        for (final book in const [
          '罗马书',
          '哥林多前书',
          '歌罗西书',
          '提摩太前书',
          '提摩太后书',
        ])
          book: await _chapter('biblexg-v2', book, '1'),
      };
      for (final entry in chapters.entries) {
        expect(entry.value['1'], endsWith('——'), reason: entry.key);
        expect(entry.value.containsKey('2'), isTrue, reason: entry.key);
      }
    });
  });
}
