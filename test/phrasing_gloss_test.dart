/// The gloss line: pairing two renderings of one verse by Strong's
/// number, so a reader phrasing the Hebrew can see what it says.
///
/// Every fixture below is real corpus data, copied from
/// `assets/originals/1_kings.json` and `assets/tagged/cuvs-yhwh/1_kings.json`
/// rather than invented, because the whole risk in this function is that
/// it produces a well-formed pairing of the WRONG words — which reads
/// exactly like a right one.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/utils/phrasing.dart';

/// 1 Kings 21:1 — fifteen Hebrew words.
const _hebrew = <String>[
  'H1961', // וַיְהִי
  'H310', // אַחַר
  'H1697', // הַדְּבָרִים
  'H428', // הָאֵלֶּה
  'H3754', // כֶּרֶם
  'H1961', // הָיָה
  'H5022', // לְנָבוֹת
  'H3158', // הַיִּזְרְעֵאלִי
  'H834', // אֲשֶׁר
  'H3157', // בְּיִזְרְעֶאל
  'H681', // אֵצֶל
  'H1964', // הֵיכַל
  'H256', // אַחְאָב
  'H4428', // מֶלֶךְ
  'H8111', // שֹׁמְרוֹן
];

/// The same verse in 和合本【雅伟】版＋, fourteen tagged runs. Note the
/// order: the Chinese opens with 这事以后 where the Hebrew has
/// וַיְהִי אַחַר הַדְּבָרִים הָאֵלֶּה.
const _chinese = <({String strongs, String text})>[
  (strongs: 'H428', text: '这'),
  (strongs: 'H1697', text: '事'),
  (strongs: 'H310', text: '以后，'),
  (strongs: 'H3158', text: '又有一事。耶斯列人'),
  (strongs: 'H5022', text: '拿伯'),
  (strongs: 'H834', text: '在'),
  (strongs: 'H3157', text: '耶斯列'),
  (strongs: 'H1961', text: '有'),
  (strongs: 'H3754', text: '一个葡萄园，'),
  (strongs: 'H681', text: '靠近'),
  (strongs: 'H8111', text: '撒玛利亚'),
  (strongs: 'H4428', text: '王'),
  (strongs: 'H256', text: '亚哈'),
  (strongs: 'H1964', text: '的宫。'),
];

void main() {
  group('alignByStrongs', () {
    test('pairs a real verse across a word order the translation changed',
        () {
      final got = alignByStrongs(_hebrew, _chinese);
      expect(got.length, _hebrew.length);
      // Position in the verse is irrelevant: אַחַר is the second Hebrew
      // word and 以后 the third Chinese run, and they still pair.
      expect(got[1], '以后，');
      expect(got[2], '事');
      expect(got[3], '这');
      expect(got[14], '撒玛利亚');
    });

    test('a surplus on the Hebrew side is left unpaired, not guessed', () {
      final got = alignByStrongs(_hebrew, _chinese);
      // H1961 stands twice in the Hebrew (וַיְהִי, הָיָה) and once in the
      // Chinese. The FIRST takes the counterpart; the second is honestly
      // blank rather than borrowing it.
      expect(got[0], '有');
      expect(got[5], isNull);
    });

    test('repeated numbers pair in order of occurrence, not at random', () {
      // John 1:1 — G3588 twice, G3056 twice, G1510 twice.
      final got = alignByStrongs(
        const ['G1722', 'G746', 'G1510', 'G3588', 'G3056', 'G2532', 'G3588',
            'G3056', 'G1510'],
        const [
          (strongs: 'G1722', text: 'In'),
          (strongs: 'G746', text: 'the beginning'),
          (strongs: 'G1510', text: 'was'),
          (strongs: 'G3588', text: 'the'),
          (strongs: 'G3056', text: 'Word'),
          (strongs: 'G2532', text: 'and'),
          (strongs: 'G3588', text: 'the'),
          (strongs: 'G3056', text: 'Word'),
          (strongs: 'G1510', text: 'was'),
        ],
      );
      expect(got, const [
        'In', 'the beginning', 'was', 'the', 'Word', 'and', 'the', 'Word',
        'was',
      ]);
    });

    test('an untagged word asks for nothing and gets nothing', () {
      final got = alignByStrongs(
        const ['', 'H430', ''],
        const [(strongs: 'H430', text: '神')],
      );
      expect(got, const [null, '神', null]);
    });

    test('an empty counterpart yields no glosses rather than throwing', () {
      expect(alignByStrongs(_hebrew, const []),
          List<String?>.filled(_hebrew.length, null));
    });

    test('case and whitespace in a number do not break the pairing', () {
      final got = alignByStrongs(
        const [' h430 '],
        const [(strongs: 'H430', text: '神')],
      );
      expect(got, const ['神']);
    });

    test('a blank counterpart text is not offered as a gloss', () {
      // A tagged run can be whitespace the tagger carried through; an
      // empty gloss box under a word reads as a rendering that is not
      // there.
      final got = alignByStrongs(
        const ['H430', 'H430'],
        const [
          (strongs: 'H430', text: '   '),
          (strongs: 'H430', text: '神'),
        ],
      );
      expect(got, const ['神', null]);
    });
  });

  group('PhrasingWord.withGloss', () {
    test('keeps everything else and records where the gloss came from', () {
      const w = PhrasingWord(
          text: 'וַיְהִי',
          strongs: 'H1961',
          verse: 1,
          morph: 'HC/Vqw3ms',
          translit: 'way·hî');
      final ctx = w.withGloss('有');
      expect(ctx.text, 'וַיְהִי');
      expect(ctx.morph, 'HC/Vqw3ms');
      expect(ctx.translit, 'way·hî');
      expect(ctx.gloss, '有');
      expect(ctx.glossFromLexicon, isFalse);

      final lex = w.withGloss('to be', fromLexicon: true);
      expect(lex.glossFromLexicon, isTrue);
    });

    test('no gloss cannot be marked as coming from the lexicon', () {
      const w = PhrasingWord(text: 'x', strongs: 'H1', verse: 1);
      expect(w.withGloss(null, fromLexicon: true).glossFromLexicon, isFalse);
    });
  });
}
