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
