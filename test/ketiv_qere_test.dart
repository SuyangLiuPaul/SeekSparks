// The Ketiv/Qere repair, frozen on the shipped bytes.
//
// `tools/build_originals.py` read the Westminster Leningrad Codex with
// `verse.iter(w)` — a DESCENDANT walk — and the WLC hides the Qere in an
// apparatus note. So the marginal reading was lifted into the running
// text with nothing to say where it came from, and 1,103 verses shipped
// a word printed twice: 2 Samuel 18:20 as `כי על על כן`, Genesis 30:11
// as `בגד בא גד` — three words where the text has one written and two
// read. `docs/DATA-INTEGRITY.md` had recorded the scope as four verses;
// it was four verses whose two readings happen to be spelled the SAME,
// so a repeated-word scan could see them. The other ~1,100 were spelled
// differently and were invisible to that instrument.
//
// Both readings are kept, as BibleWorks keeps both (help topic bwh17:
// a wildcard matches "all forms … including Qere, Kethib, and neither").
// What is asserted here is that every one is LABELLED, because the
// labelling is the whole repair: unlabelled, the app states that the
// Hebrew text has a word it does not have.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/original_word.dart';
import 'package:seeksparks/utils/ketiv_qere.dart';
import 'package:seeksparks/utils/word_list.dart';

Map<String, List<dynamic>> _book(String slug) {
  final file = File('assets/originals/$slug.json');
  expect(file.existsSync(), isTrue,
      reason: 'missing assets/originals/$slug.json');
  return (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)
      .map((k, v) => MapEntry(k, v as List<dynamic>));
}

/// The 39 Hebrew books, by asset slug.
const _hebrew = <String>[
  'genesis', 'exodus', 'leviticus', 'numbers', 'deuteronomy', 'joshua',
  'judges', 'ruth', '1_samuel', '2_samuel', '1_kings', '2_kings',
  '1_chronicles', '2_chronicles', 'ezra', 'nehemiah', 'esther', 'job',
  'psalms', 'proverbs', 'ecclesiastes', 'song_of_solomon', 'isaiah',
  'jeremiah', 'lamentations', 'ezekiel', 'daniel', 'hosea', 'joel',
  'amos', 'obadiah', 'jonah', 'micah', 'nahum', 'habakkuk', 'zephaniah',
  'haggai', 'zechariah', 'malachi',
];

/// Hebrew points and accents: niqqud, cantillation, and the
/// sof-pasuq/paseq block. A Ketiv is unpointed by construction — its
/// vowels were lent to the Qere in the margin — so this range is the
/// independent witness that the marks landed on the right words.
final _pointed = RegExp(r'[֑-ֽֿ-ׇ]');

void main() {
  group('the corpus', () {
    test('carries exactly the roles the WLC apparatus has', () {
      final counts = <String, int>{'k': 0, 'q': 0, 'kx': 0, 'qx': 0};
      var verses = 0;
      for (final slug in _hebrew) {
        for (final words in _book(slug).values) {
          var marked = false;
          for (final w in words) {
            final kq = (w as Map)['kq'] as String?;
            if (kq == null) continue;
            expect(counts.containsKey(kq), isTrue,
                reason: '$slug: unknown kq value "$kq"');
            counts[kq] = counts[kq]! + 1;
            marked = true;
          }
          if (marked) verses++;
        }
      }
      // Frozen on `tools/repair_originals_qere.py`, which aligned the
      // shipped asset against the WLC in 23,213 of 23,213 verses, word
      // for word, before it wrote a single mark.
      expect(verses, 1103);
      expect(counts, {'k': 1251, 'q': 1244, 'kx': 6, 'qx': 8});
    });

    test('every Ketiv is unpointed, and no Qere is', () {
      var ketiv = 0;
      for (final slug in _hebrew) {
        for (final entry in _book(slug).entries) {
          for (final w in entry.value) {
            final kq = ((w as Map)['kq'] as String?) ?? '';
            final text = w['w'] as String;
            if (kq == 'k' || kq == 'kx') {
              ketiv++;
              expect(_pointed.hasMatch(text), isFalse,
                  reason: '$slug ${entry.key}: Ketiv "$text" is pointed — '
                      'the mark is on the wrong word');
            } else if (kq == 'q' || kq == 'qx') {
              expect(_pointed.hasMatch(text), isTrue,
                  reason: '$slug ${entry.key}: Qere "$text" is unpointed');
            }
          }
        }
      }
      expect(ketiv, 1257);
    });

    test('the Greek NT carries no Ketiv/Qere', () {
      for (final slug in ['matthew', 'romans', 'revelation']) {
        for (final words in _book(slug).values) {
          for (final w in words) {
            expect((w as Map).containsKey('kq'), isFalse);
          }
        }
      }
    });
  });

  group('the verses this repair was written for', () {
    // Each of these printed a doubled word with nothing to explain it.
    // Frozen individually because a rebuild from a stale generator would
    // revert them silently, and because each is a specific claim about
    // what a verse says — the kind of thing a general count cannot hold.
    test('the doubled words are marked, in order', () {
      const cases = <List<String>>[
        // slug, ref, surface, expected role
        // Leah names Gad: one word written, two read, all three printed.
        ['genesis', '30:11', 'בגד', 'k'],
        // Abraham's servant: H3455 written, H7760 read — different words.
        ['genesis', '24:33', 'ויישם', 'k'],
        ['exodus', '4:2', 'מזה', 'k'],
        // The four DATA-INTEGRITY could see, because both readings are
        // spelled alike and so looked like a repeated word.
        ['2_samuel', '18:20', 'על', 'k'],
        ['proverbs', '8:35', 'מצאי', 'k'],
      ];
      for (final c in cases) {
        final words = _book(c[0])[c[1]];
        expect(words, isNotNull, reason: '${c[0]} ${c[1]} is missing');
        final roles = <String?>[
          for (final w in words!)
            if ((w as Map)['w'] == c[2]) w['kq'] as String?,
        ];
        expect(roles, contains(c[3]),
            reason: '${c[0]} ${c[1]}: "${c[2]}" should be marked ${c[3]}');
      }
    });

    test('Ketiv velo Qere is not called an ordinary Ketiv', () {
      // Six words the Masoretes wrote and directed NOT be read, with no
      // reading offered in place. Calling these `k` would make the app
      // promise a Qere that does not exist.
      const refs = <List<String>>[
        ['2_kings', '5:18'],
        ['jeremiah', '38:16'],
        ['jeremiah', '39:12'],
        ['jeremiah', '51:3'],
        ['ezekiel', '48:16'],
        ['ruth', '3:12'],
      ];
      for (final r in refs) {
        final words = _book(r[0])[r[1]];
        expect(words, isNotNull, reason: '${r[0]} ${r[1]} is missing');
        final roles = [for (final w in words!) (w as Map)['kq']];
        expect(roles, contains('kx'),
            reason: '${r[0]} ${r[1]} carries no Ketiv velo Qere');
      }
    });

    test('Qere velo Ketiv is not called an ordinary Qere', () {
      // Read though the text writes nothing. Jeremiah 50:29 is the ninth
      // such site in the WLC and is deliberately absent here: its lemma
      // carries no Strong's number, and this corpus drops those for
      // every word, not only this one.
      const refs = <List<String>>[
        ['2_samuel', '8:3'],
        ['2_samuel', '16:23'],
        ['2_kings', '19:31'],
        ['2_kings', '19:37'],
        ['judges', '20:13'],
        ['jeremiah', '31:38'],
        ['ruth', '3:5'],
        ['ruth', '3:17'],
      ];
      for (final r in refs) {
        final words = _book(r[0])[r[1]];
        expect(words, isNotNull, reason: '${r[0]} ${r[1]} is missing');
        final roles = [for (final w in words!) (w as Map)['kq']];
        expect(roles, contains('qx'),
            reason: '${r[0]} ${r[1]} carries no Qere velo Ketiv');
      }
    });
  });

  group('the reader gets told', () {
    test('fromJson keeps the role, and refuses anything else', () {
      OriginalWord parse(Object? kq) => OriginalWord.fromJson(
          {'w': 'x', 's': 'H1', if (kq != null) 'kq': kq});
      expect(parse('k').ketivQere, 'k');
      expect(parse('qx').ketivQere, 'qx');
      expect(parse('k').isKetiv, isTrue);
      expect(parse('kx').isKetiv, isTrue);
      expect(parse('qx').isQere, isTrue);
      expect(parse(null).ketivQere, isNull);
      expect(parse('K').ketivQere, isNull);
      expect(parse('ketiv').ketivQere, isNull);
      expect(parse(null).isKetiv, isFalse);
    });

    test('every role has a mark, a name and a sentence, in every locale',
        () {
      for (final kq in ['k', 'q', 'kx', 'qx']) {
        expect(ketivQereMark(kq), isNotNull);
        for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
          expect(ketivQereLabel(kq, locale), isNotEmpty,
              reason: '$kq has no name in $locale');
          expect(ketivQereNote(kq, locale), isNotEmpty,
              reason: '$kq has no explanation in $locale');
        }
      }
      expect(ketivQereMark('k'), 'K');
      expect(ketivQereMark('kx'), 'K');
      expect(ketivQereMark('q'), 'Q');
      expect(ketivQereMark('qx'), 'Q');
      expect(ketivQereMark(null), isNull);
      expect(ketivQereLabel(null, 'en'), isNull);
      expect(ketivQereNote(null, 'en'), isNull);
    });

    test('a word list headed by a tie prefers the form that is read', () {
      // Both forms count 1, so the old `>` kept whichever the verse put
      // first — always the Ketiv, because the Qere follows it. 1
      // Chronicles 1:11 headed H3866 with the unpointed `לודיים`, the
      // form the Masoretes direct NOT be read. 360 rows at book scope.
      const ketiv = 'לודיים';
      const qere = 'לוּדִ֧ים';
      final rows = buildWordList([
        const OriginalWord(text: ketiv, strongs: 'H3866', ketivQere: 'k'),
        const OriginalWord(text: qere, strongs: 'H3866', ketivQere: 'q'),
      ]);
      expect(rows.single.form, qere);
      // Both still count. BibleWorks counts both too — a wildcard
      // "will [match] all forms … including Qere, Kethib, and neither"
      // (bwh17) — so dropping one would be the deviation, not the fix.
      expect(rows.single.count, 2);
    });

    test('a number met only as a Ketiv still shows the Ketiv', () {
      // 1 Chronicles 3:24 H1939 occurs once in the book and that once is
      // a Ketiv. There is no read form to prefer, and inventing one, or
      // hiding the row, would be worse than printing what is there.
      final rows = buildWordList([
        const OriginalWord(
            text: 'הדיוהו', strongs: 'H1939', ketivQere: 'k'),
      ]);
      expect(rows.single.form, 'הדיוהו');
    });

    test('a Ketiv velo Qere is never told to read a Qere', () {
      // The whole reason the role is four-valued. If this sentence ever
      // promises a counterpart, six verses start lying.
      for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
        expect(ketivQereNote('kx', locale)!.contains('Qere'), isFalse,
            reason: 'kx note names a Qere that does not exist ($locale)');
      }
    });
  });
}
