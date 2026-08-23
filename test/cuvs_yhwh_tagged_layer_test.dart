// The 和合本雅伟版 tagged layer was printing its source's alignment codes
// as scripture.
//
// `assets/tagged/cuvs-yhwh/` is what the Browse pane draws and what a word
// tap answers with. The MySword module it is built from is hand-edited, and
// 133 of its 533,914 codes are damaged — a dropped bracket, a doubled
// prefix, a character typed into the middle of the code. The importer's
// regex knew only the well-formed shape, so it did not skip the damaged
// ones, it treated them as TEXT: 「他若<H518>行恶」 drew the code on screen,
// and because the code never split the run, 他若 carried H4672 — the number
// belonging to a different word.
//
// The suite stayed green through all of it, because nothing had ever asked
// this asset whether it contains anything that is not Chinese. That is the
// question these tests ask, and it is nearly free: a Chinese verse has no
// Latin letters and no angle brackets, so any that survive are the source's
// markup rather than the translation.
//
// Jeremiah 34:8 is why the Latin test earns its place alongside the bracket
// one. Its code had lost BOTH brackets — `的仆人WH853x<WH5650>` — so a scan
// for `<…>` could never have seen it.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

const _books = <String>[
  'genesis', 'exodus', 'leviticus', 'numbers', 'deuteronomy', 'joshua',
  'judges', 'ruth', '1_samuel', '2_samuel', '1_kings', '2_kings',
  '1_chronicles', '2_chronicles', 'ezra', 'nehemiah', 'esther', 'job',
  'psalms', 'proverbs', 'ecclesiastes', 'song_of_solomon', 'isaiah',
  'jeremiah', 'lamentations', 'ezekiel', 'daniel', 'hosea', 'joel', 'amos',
  'obadiah', 'jonah', 'micah', 'nahum', 'habakkuk', 'zephaniah', 'haggai',
  'zechariah', 'malachi', 'matthew', 'mark', 'luke', 'john', 'acts',
  'romans', '1_corinthians', '2_corinthians', 'galatians', 'ephesians',
  'philippians', 'colossians', '1_thessalonians', '2_thessalonians',
  '1_timothy', '2_timothy', 'titus', 'philemon', 'hebrews', 'james',
  '1_peter', '2_peter', '1_john', '2_john', '3_john', 'jude', 'revelation',
];

final _latin = RegExp(r'[A-Za-z]');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, Map<String, List<dynamic>>> tagged;

  setUpAll(() async {
    tagged = <String, Map<String, List<dynamic>>>{};
    for (final book in _books) {
      final raw =
          await rootBundle.loadString('assets/tagged/cuvs-yhwh/$book.json');
      tagged[book] = (jsonDecode(raw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as List<dynamic>));
    }
  });

  String joined(String book, String ref) => tagged[book]![ref]!
      .cast<Map<String, dynamic>>()
      .map((r) => r['w'] as String)
      .join();

  test('every book of the canon is present', () {
    expect(tagged.length, 66);
    for (final book in _books) {
      expect(tagged[book], isNotEmpty, reason: '$book is empty');
    }
  });

  test('no run carries an angle bracket', () {
    final offenders = <String>[];
    tagged.forEach((book, verses) {
      verses.forEach((ref, runs) {
        for (final run in runs.cast<Map<String, dynamic>>()) {
          final w = run['w'] as String;
          if (w.contains('<') || w.contains('>')) {
            offenders.add('$book $ref ${jsonEncode(w)}');
          }
        }
      });
    });
    expect(offenders, isEmpty,
        reason: 'the tagged layer is drawn as scripture; '
            '${offenders.length} runs carry the source\'s markup');
  });

  test('no run carries a Latin letter', () {
    // The translation is Chinese and the 〔…〕 notes cite chapter and verse
    // in digits, so a Latin letter can only be a leaked alignment code.
    final offenders = <String>[];
    tagged.forEach((book, verses) {
      verses.forEach((ref, runs) {
        for (final run in runs.cast<Map<String, dynamic>>()) {
          final w = run['w'] as String;
          if (_latin.hasMatch(w)) offenders.add('$book $ref ${jsonEncode(w)}');
        }
      });
    });
    expect(offenders, isEmpty,
        reason: '${offenders.length} runs carry a leaked code');
  });

  test('a damaged code no longer swallows the words around it', () {
    // `送给<WH7971><WH8799><WH5612x那些<WH834>…长老><WH413x>` — the closing
    // bracket landed after 长老, so the whole relative clause had been
    // parsed as part of a tag.
    expect(joined('1_kings', '21:8'),
        contains('送给那些与拿伯同城居住的长老贵胄'));
    // `叫各人任他希伯来的仆人WH853x<WH5650>和婢女` — brackets lost entirely.
    expect(joined('jeremiah', '34:8'), contains('的仆人和婢女自由出去'));
    // `<你们WH935>` — 你们 was typed inside the code and is scripture.
    expect(joined('numbers', '15:18'), contains('我所领你们进去的那地'));
  });

  // 2026-08-12 (check 26). The bracket and Latin tests catch markup that
  // leaked in. These catch the opposite: characters that look like
  // scripture and are not. 丶 U+4E36 is the dot *stroke*, the character
  // naming a piece of a glyph — it cannot occur in prose, and it stood
  // where the enumeration comma 、 belongs. The rest are ordinary
  // ideographs standing where a different ordinary ideograph belongs, so
  // nothing about their shape gives them away; only reading them does.
  test('no run carries a character that cannot be read here', () {
    const unreadable = <String, String>{
      '丶': 'U+4E36 dot stroke for the enumeration comma 、',
      '恉': '恉 (purport) for 腮 (jaw)',
      '逿': '逿 for 趟 (to wade)',
      '承巡': '承巡 for 承受',
      '扔菏': '扔菏 for 凶淫',
      '暇疵': '暇疵 for 瑕疵',
    };
    // A run is a word, so a two-character defect can straddle two runs;
    // the whole verse is what must be searched.
    final offenders = <String>[];
    tagged.forEach((book, verses) {
      verses.forEach((ref, runs) {
        final text = runs
            .cast<Map<String, dynamic>>()
            .map((r) => r['w'] as String)
            .join();
        unreadable.forEach((bad, why) {
          if (text.contains(bad)) offenders.add('$book $ref: $why');
        });
      });
    });
    expect(offenders, isEmpty, reason: offenders.join('; '));
  });

  test('the repaired verses read what the witnesses read', () {
    // The plain and tagged copies of Jeremiah 12:14 were corrupt to
    // DIFFERENT depths — plain read 承巡菇业, tagged read 承巡产业 — which
    // is why the two layers witnessing each other was not enough on its
    // own, and why cuvs-plus and the yahwehdehua export were consulted.
    expect(joined('jeremiah', '12:14'), contains('以色列所承受产业的'));
    expect(joined('judges', '15:16'), contains('我用驴腮骨杀人成堆'));
    expect(joined('2_samuel', '19:17'), contains('都趟过约但河迎接王'));
    expect(joined('2_samuel', '14:25'), contains('从脚底到头顶，毫无瑕疵'));
    expect(joined('psalms', '146:6'), contains('雅伟造天、地、海'));
  });

  test('check 47 moved this layer with the reading text', () {
    // The five verses check 47 repaired. This layer carried every one of
    // them, so leaving it behind would make the tagged and plain copies
    // disagree about scripture — the state check 45 was written to detect.
    expect(joined('jeremiah', '7:14'), contains('向这称为我名下、'));
    expect(joined('psalms', '102:26'), contains('天地就都改变了'));
    expect(joined('1_john', '4:2'), contains('是成了肉身来的，就是出于神的'));
    expect(joined('acts', '26:16'), contains('站着，我特意向你显现'));
    expect(joined('obadiah', '1:5'), contains('摘葡萄的若来到你那里'));
  });

  test('check 47 left the Strong\'s numbers it moved characters between', () {
    // 为 crossed from H8034 שֵׁם (name) to H7121 קרא (call) and 到 from
    // H518 אִם (if) to H935 בּוֹא (come), so that the runs divide as the
    // Hebrew does. 使徒行传 26:16 is the one place a character had to cross
    // a boundary with nowhere honest to land: 我 is carried by the person
    // of ὤφθην, not by a Greek word of its own, so it became its own run
    // with an empty number rather than being folded into G5124 τοῦτο and
    // mis-tagged.
    String runFor(String book, String ref, String word) => tagged[book]![ref]!
        .whereType<Map<String, dynamic>>()
        .firstWhere((r) => r['w'] == word,
            orElse: () => fail('$book $ref has no run $word'))['s'] as String;

    expect(runFor('jeremiah', '7:14', '所以我要向这称为'), 'H7121');
    expect(runFor('jeremiah', '7:14', '我名下、'), 'H8034');
    expect(runFor('obadiah', '1:5', '来到'), 'H935');
    expect(runFor('acts', '26:16', '我'), '');
    expect(runFor('acts', '26:16', '特意'), 'G5124');
  });

  // 2026-08-23 (check 45d). Two more classes of the source's markup, both
  // found by comparing this layer against the flat edition it tags rather
  // than by looking at it alone.
  test('no run carries a hash', () {
    // The MySword module writes `#` where the 和合本 prints a supplied word
    // in brackets. The reading text has 「主[基督]」 at all seventeen of
    // these; the tagged layer had 「主#」 and drew the hash as scripture.
    final offenders = <String>[];
    tagged.forEach((book, verses) {
      verses.forEach((ref, runs) {
        for (final run in runs.cast<Map<String, dynamic>>()) {
          final w = run['w'] as String;
          if (w.contains('#')) offenders.add('$book $ref ${jsonEncode(w)}');
        }
      });
    });
    expect(offenders, isEmpty, reason: offenders.join('; '));
  });

  test('a doubled character no longer stutters', () {
    // Seven verses repeated one character against themselves — an artefact
    // of the import, not reduplication. These are asserted by verse and not
    // by a pattern, because Chinese reduplication is ordinary prose (天天,
    // 渐渐, 人人) and a general detector would condemn thousands of correct
    // verses. The flat edition reads all seven as written here.
    // Each fragment carries the character BEFORE the stutter. Without it
    // the assertion passes on the damaged text too, because a doubled
    // character only shifts the match one place to the right.
    expect(joined('leviticus', '5:7'), contains('他的力量若不够献一只羊羔'));
    expect(joined('1_samuel', '20:37'), contains('童子说：“箭不是在你前头'));
    expect(joined('1_kings', '19:18'), contains('屈膝的，未曾与巴力亲嘴的'));
    expect(joined('2_kings', '10:5'), contains('说：“我们是你的仆人'));
    expect(joined('isaiah', '41:16'), contains('为喜乐，以色列的圣者为夸耀'));
    expect(joined('ezekiel', '36:1'), contains('你要对以色列山发预言'));
    expect(joined('matthew', '9:28'), contains('跟前。耶稣说：“你们信我'));
  });

  test('a damaged code stops stealing its neighbour\'s number', () {
    // 「他若<H518>行恶」: the code was text, so it never split the run, and
    // 他若 was left carrying H4672 — the number of a word further on.
    // H518 אִם is 若 itself.
    final run = tagged['1_kings']!['1:52']!
        .cast<Map<String, dynamic>>()
        .firstWhere((r) => (r['w'] as String).contains('若'));
    expect(run['s'], 'H518');
  });
}
