// A reader tapping 「γην」 in Genesis 1:1 — the earth, in the verse that
// names it — was told the word means "indeed, at least".
//
// `assets/tagged/lxxwh/` holds two alignments in one asset: the Greek Old
// Testament and the Westcott-Hort New Testament, tagged by two different
// processes. The Septuagint half's Strong's numbers came from a lookup
// that could not see accent, breathing or vowel length, so it answered
// with whatever word survives folding η to ε and ω to ο: γῆ "earth"
// G1093 as γέ G1065, μή "not" G3361 as μέ G3165, ὡς "as" G5613 as ὅς
// G3739, εἷς "one" G1520 as εἰς "into" G1519. 12,099 runs.
//
// Nothing caught it because every one of those numbers is real and has a
// lexicon entry to show. The check that catches it is that the two halves
// are the same language, so a word common to both is tagged twice — and
// each half is therefore a witness to the other. `tools/fix_lxx_strongs.py`
// moved a number only where the New Testament half was unanimous AND
// `assets/originals/` (MorphGNT, made by other people from another
// source) named the same number, and only where the run's own part of
// speech agreed. The same witness filled 8,295 runs that carried no
// number and did not have to.
//
// These tests hold the outcome down. The aggregate is the one that would
// see a corruption nobody has thought of yet; the named verses are the
// ones that pin the specific judgements the repair had to make.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

const _oldTestament = <String>[
  'genesis', 'exodus', 'leviticus', 'numbers', 'deuteronomy', 'joshua',
  'judges', 'ruth', '1_samuel', '2_samuel', '1_kings', '2_kings',
  '1_chronicles', '2_chronicles', 'ezra', 'nehemiah', 'esther', 'job',
  'psalms', 'proverbs', 'ecclesiastes', 'song_of_solomon', 'isaiah',
  'jeremiah', 'lamentations', 'ezekiel', 'daniel', 'hosea', 'joel',
  'amos', 'obadiah', 'jonah', 'micah', 'nahum', 'habakkuk', 'zephaniah',
  'haggai', 'zechariah', 'malachi',
];

const _newTestament = <String>[
  'matthew', 'mark', 'luke', 'john', 'acts', 'romans', '1_corinthians',
  '2_corinthians', 'galatians', 'ephesians', 'philippians', 'colossians',
  '1_thessalonians', '2_thessalonians', '1_timothy', '2_timothy', 'titus',
  'philemon', 'hebrews', 'james', '1_peter', '2_peter', '1_john', '2_john',
  '3_john', 'jude', 'revelation',
];

// Both halves of this asset are unaccented — 24 lowercase letters and a
// final sigma, and nothing else — so folding a surface form to its
// comparison key needs only the sigma. Vowel length is deliberately kept:
// confusing η with ε is the defect being guarded against, and a key that
// folded them could not tell the repair from the damage.
String _key(String w) => w.trim().toLowerCase().replaceAll('ς', 'σ');

Future<Map<String, List<dynamic>>> _book(String slug) async =>
    (jsonDecode(await rootBundle.loadString('assets/tagged/lxxwh/$slug.json'))
            as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v as List<dynamic>));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, Map<String, List<dynamic>>> ot;
  late Map<String, String> witness; // form -> the New Testament's number

  setUpAll(() async {
    ot = <String, Map<String, List<dynamic>>>{};
    for (final slug in _oldTestament) {
      ot[slug] = await _book(slug);
    }

    final counts = <String, Map<String, int>>{};
    for (final slug in _newTestament) {
      for (final runs in (await _book(slug)).values) {
        for (final run in runs.cast<Map<String, dynamic>>()) {
          final s = run['s'] as String? ?? '';
          if (s.isEmpty) continue;
          counts.putIfAbsent(_key(run['w'] as String), () => <String, int>{})
              .update(s, (n) => n + 1, ifAbsent: () => 1);
        }
      }
    }
    // Only a form the New Testament half tags with one number counts as a
    // witness. Taking the commonest number instead would make the measure
    // depend on how ties happen to be ordered, and it is the same rule
    // `tools/fix_lxx_strongs.py` had to satisfy before it moved anything.
    witness = <String, String>{};
    counts.forEach((form, byCode) {
      if (byCode.length == 1) witness[form] = byCode.keys.first;
    });
  });

  test('the two halves agree about what a shared word means', () {
    // The aggregate. Every Septuagint word that the New Testament also
    // uses is tagged twice by two unrelated processes, so a systematic
    // corruption of either half collapses this number without anyone
    // having to guess the shape of the bug first.
    var same = 0;
    var compared = 0;
    for (final book in ot.values) {
      for (final runs in book.values) {
        for (final run in runs.cast<Map<String, dynamic>>()) {
          final s = run['s'] as String? ?? '';
          if (s.isEmpty) continue;
          final expected = witness[_key(run['w'] as String)];
          if (expected == null) continue;
          compared++;
          if (expected == s) same++;
        }
      }
    }
    expect(compared, greaterThan(340000));
    final agreement = 100.0 * same / compared;
    // Was 95.77% while the accent-blind numbers were in. The residue is
    // real disagreement — ἐσθίω against φάγω, ἄρχω against ἄρχομαι, and
    // the homographs below — not damage.
    expect(agreement, greaterThan(99.0),
        reason: 'the two halves agree about only '
            '${agreement.toStringAsFixed(2)}% of the shared words');
  });

  test('the Septuagint half answers for as many words as it did', () {
    var empty = 0;
    var total = 0;
    for (final book in ot.values) {
      for (final runs in book.values) {
        for (final run in runs.cast<Map<String, dynamic>>()) {
          total++;
          if ((run['s'] as String? ?? '').isEmpty) empty++;
        }
      }
    }
    // −138 in v1.6.122: check 34 corrected Proverbs 25:1–29:27's markers
    // from chapters 32–36 down to their own, which made each of them
    // repeat the reference it was attached to and say nothing. They were
    // dropped, and a marker run is a run. No Greek word was touched —
    // the six other markers the same repair removed are all in the New
    // Testament and so are not in this count.
    expect(total, 479851);
    // 10.34% before the fill, 8.61% after. The remainder is honest: some
    // 41,000 runs are words the New Testament never uses, so no Strong's
    // number exists to give and inventing one would be a guess. The bound
    // is here so a future import cannot quietly stop answering.
    final untagged = 100.0 * empty / total;
    expect(untagged, lessThan(8.7),
        reason: '$empty of $total runs answer nothing '
            '(${untagged.toStringAsFixed(2)}%)');
  });

  test('the earth in Genesis 1:1 is the earth', () {
    // The verse the app opens on, and the word that named the defect.
    final runs = ot['genesis']!['1:1']!.cast<Map<String, dynamic>>();
    expect(runs.last['w'], 'γην');
    expect(runs.last['s'], 'G1093'); // γῆ, not γέ G1065
  });

  test('the commonest verb in the Old Testament answers a tap', () {
    // εἶπεν was tagged in 612 places and left empty in 2,550 others —
    // same word, same edition, same parse. It takes λέγω G3004 because
    // that is the number this edition already uses for it, not the G2036
    // a different Strong's convention would choose.
    var empty = 0;
    var wrong = 0;
    for (final book in ot.values) {
      for (final runs in book.values) {
        for (final run in runs.cast<Map<String, dynamic>>()) {
          if (_key(run['w'] as String) != 'ειπεν') continue;
          final s = run['s'] as String? ?? '';
          if (s.isEmpty) {
            empty++;
          } else if (s != 'G3004') {
            wrong++;
          }
        }
      }
    }
    expect(empty, 0);
    expect(wrong, 0);
  });

  test('a homograph keeps its own number against the witness', () {
    // Leviticus's ἁφή "a plague-spot" is a noun, G860. It is spelled
    // exactly like ἀφῇ from ἀφίημι "to let go", which the New Testament
    // tags G863 — so the witness names a number, unanimously, and it is
    // the wrong one. The run's own parse is what refuses it: 234 runs are
    // held this way, and every one is a word-class disagreement rather
    // than a tagset naming difference.
    final run =
        ot['leviticus']!['13:57']!.cast<Map<String, dynamic>>().last;
    expect(run['w'], 'αφη');
    expect(run['g'], ['N-NSF']);
    expect(run['s'], 'G860');
    expect(witness['αφη'], 'G863');
  });

  test('a unanimous witness is still refused without a third', () {
    // The New Testament half lemmatises ἰδού under ὁράω G3708 and does so
    // unanimously, but `assets/originals/` does not confirm it and the
    // Septuagint's own G2400 is the better reading. Two independent
    // witnesses must agree before a number moves; here only one does.
    final byCode = <String, int>{};
    for (final book in ot.values) {
      for (final runs in book.values) {
        for (final run in runs.cast<Map<String, dynamic>>()) {
          if (_key(run['w'] as String) != 'ιδου') continue;
          byCode.update(run['s'] as String? ?? '', (n) => n + 1,
              ifAbsent: () => 1);
        }
      }
    }
    expect(witness['ιδου'], 'G3708');
    // 11 runs read G3708 in the Septuagint half already; the repair moved
    // none of them either way, in either direction.
    expect(byCode, {'G2400': 1018, 'G3708': 11});
  });

  test('every number the layer gives has a lexicon entry', () async {
    // This proves far less than it looks like it proves — G1065 γέ is a
    // real entry, and it was the wrong answer 2,704 times. It is here to
    // catch a fill that invents a number, nothing more.
    final lexicon = jsonDecode(
        await rootBundle.loadString('assets/strongs/greek.json'))
        as Map<String, dynamic>;
    final missing = <String>{};
    for (final book in ot.values) {
      for (final runs in book.values) {
        for (final run in runs.cast<Map<String, dynamic>>()) {
          final s = run['s'] as String? ?? '';
          if (s.isNotEmpty && !lexicon.containsKey(s)) missing.add(s);
        }
      }
    }
    expect(missing, isEmpty);
  });
}
