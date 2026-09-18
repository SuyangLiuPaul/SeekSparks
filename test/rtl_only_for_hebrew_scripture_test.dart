// A Chinese verse that quotes a Hebrew word is still a Chinese verse.
//
// 2026-09-15, reported from the reader: 「Sword全部right aligned了」.
// 罗马书 8 in 梁简 was set flush right — every line of it — while the
// paragraph immediately below was normal.
//
// The paragraph asked `group.any((v) => isRtlText(v.text))`: is there
// ANY Hebrew character ANYWHERE in this block, in the RAW record,
// `<note:…>` markup included. 梁简 carries 109 verses whose translator's
// notes cite a Hebrew word. 罗马书 8:9 and 8:11 are two of them, and
// they sit in the first paragraph — which is exactly why that block
// flipped and the next one did not.
//
// Two separate mistakes, and this file pins both:
//
//   1. **The apparatus is not the scripture.** A note is not on screen
//      as scripture and must not decide how the scripture around it is
//      laid out.
//   2. **Presence is not dominance.** `verse_widget.dart` defended the
//      old rule as the one that "survives a Hebrew quotation inside an
//      English verse". It did the opposite: one quoted word overthrew
//      the whole verse.
//
// The Masoretic text must still lay out right to left, so the test that
// matters most is the one that would pass if someone simply deleted the
// feature.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_sword/utils/phrasing.dart' show scriptIsRtl, isRtlText;

List<Map<String, dynamic>> _load(String code) =>
    (jsonDecode(File('assets/$code.json').readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();

void main() {
  test('Hebrew scripture still reads right to left', () {
    // The whole point of the feature. If this ever fails, the fix above
    // went too far and the Masoretic text is being drawn backwards.
    expect(scriptIsRtl(['בְּרֵאשִׁ֖ית בָּרָ֣א אֱלֹהִ֑ים']), isTrue);
  });

  test('a Chinese verse quoting one Hebrew word is not', () {
    expect(
      scriptIsRtl(['神差派自己的儿子来。<note:2:23 节注：נצר 与拿撒勒谐音。>']),
      isFalse,
      reason: 'one quoted word set a whole Chinese chapter flush right',
    );
  });

  test('an English verse quoting one Hebrew word is not either', () {
    expect(
      scriptIsRtl([
        'In the beginning God created the heavens and the earth. '
            '<note:בָּרָא is the verb used only of God.>',
      ]),
      isFalse,
    );
  });

  test('the apparatus does not vote at all', () {
    // Sharpest form of rule 1: identical scripture, and a note long
    // enough in Hebrew to outweigh it if it were counted.
    const scripture = '神就是爱。';
    final bare = scriptIsRtl([scripture]);
    final noted = scriptIsRtl([
      '$scripture<note:${'אלוהים ' * 40}>',
    ]);
    expect(noted, bare,
        reason: 'the note changed the layout of the verse beside it');
  });

  test('a paragraph is judged whole, not verse by verse', () {
    // The `group.any` half of the defect: ten Chinese verses and one
    // Hebrew quotation must not make a Hebrew paragraph.
    final group = <String>[
      for (var i = 0; i < 10; i++) '因为生命之灵的规律在基督耶稣里使你获得释放。',
      '倘若人没有基督的灵。<note:参 רוח。>',
    ];
    expect(scriptIsRtl(group), isFalse);
  });

  group('the edition that was actually reported', () {
    late List<Map<String, dynamic>> ljk;

    setUpAll(() => ljk = _load('biblexg-v3'));

    test('罗马书 8 is not right-aligned, notes and all', () {
      final chapter = [
        for (final v in ljk)
          if ((v['book'] == '罗马书' || v['book'] == '羅馬書') &&
              '${v['chapter']}' == '8')
            v['text'] as String,
      ];
      expect(chapter, isNotEmpty, reason: 'the fixture chapter is missing');
      // The two verses that caused it are still there — if they are not,
      // this test has stopped exercising the bug.
      expect(chapter.where(isRtlText), isNotEmpty,
          reason: 'no verse in 罗马书 8 carries Hebrew any more, so this '
              'no longer reproduces the report');
      expect(scriptIsRtl(chapter), isFalse);
    });

    test('no chapter of this Chinese edition lays out right to left', () {
      // The general form. 109 verses carry Hebrew; not one of them may
      // turn its chapter around.
      final byChapter = <String, List<String>>{};
      for (final v in ljk) {
        byChapter
            .putIfAbsent('${v['book']}|${v['chapter']}', () => <String>[])
            .add(v['text'] as String);
      }
      final flipped = [
        for (final e in byChapter.entries)
          if (scriptIsRtl(e.value)) e.key,
      ];
      expect(flipped, isEmpty,
          reason: 'these chapters would be set flush right: '
              '${flipped.take(8).join(", ")}');
    });
  });
}
