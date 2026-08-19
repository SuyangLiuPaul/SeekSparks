import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/romanised_lemma.dart';
import 'package:seeksparks/utils/vocabulary.dart';

/// The romanised-input core against the real bundled lexicons.
///
/// `romanised_lemma_test.dart` pins the mechanics on seven hand-written
/// entries; it cannot tell you whether the feature works, because seven
/// words never collide. These are the claims: that the words a student
/// of either language would actually type reach the right Strong's
/// number, that the collapse rules did not turn the index to mush, and
/// that nothing is offered which leads to an empty verse list.
///
/// Every number below was measured through this code, not carried over
/// from the script that found the rules. If a lexicon or the
/// concordance is regenerated these break, which is the point.
void main() {
  late RomanisedLemmaIndex index;
  late Map<String, dynamic> concordance;
  late List<VocabWord> words;

  Map<String, dynamic> readJson(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  setUpAll(() {
    concordance = readJson('assets/strongs/concordance.json');
    words = vocabularyFromAssets(
      concordance: concordance,
      hebrewLexicon: readJson('assets/strongs/hebrew.json'),
      greekLexicon: readJson('assets/strongs/greek.json'),
    );
    index = RomanisedLemmaIndex.fromWords(words);
  });

  /// The Strong's number a reader typing [query] lands on.
  String? top(String query) {
    final hits = index.resolve(query);
    return hits.isEmpty ? null : hits.first.strongs;
  }

  test('the index is the join, and the join is 13,964 entries', () {
    // 14,197 lexicon entries; 233 of them occur nowhere in the bundled
    // text and are dropped, because a candidate leading to an empty
    // verse list is the dead end this whole ladder exists to prevent.
    // 76 concordance numbers have no lexicon entry and so no
    // romanisation — the extended G6xxx/G9xxx tagging numbers. They are
    // unreachable by typing, and that is a stated limit, not a bug.
    expect(words.length, 13964);
    expect(index.strictKeyCount, 13935);
    expect(index.looseKeyCount, 13353);
  });

  test('every entry romanises — nothing is silently unreachable', () {
    final unkeyed = <String>[
      for (final w in words)
        if (romanisedKey(w.translit, fromLexicon: true) == null) w.strongs,
    ];
    expect(unkeyed, isEmpty);
  });

  /// Thirty-three words a first-year Greek student would type, in the
  /// spelling a modern textbook uses rather than the one Strong's
  /// prints.
  test('Greek: the words a student types reach the right number', () {
    const expected = <String, String>{
      'agape': 'G26',
      'agapao': 'G25',
      'logos': 'G3056',
      'theos': 'G2316',
      'pistis': 'G4102',
      'charis': 'G5485',
      'ekklesia': 'G1577',
      'christos': 'G5547',
      'kyrios': 'G2962',
      'pneuma': 'G4151',
      'doxa': 'G1391',
      'zoe': 'G2222',
      'psyche': 'G5590',
      'soma': 'G4983',
      'hamartia': 'G266',
      'dikaiosyne': 'G1343',
      'eirene': 'G1515',
      'elpis': 'G1680',
      'nomos': 'G3551',
      'sarx': 'G4561',
      'huios': 'G5207',
      'angelos': 'G32',
      'baptizo': 'G907',
      'euangelion': 'G2098',
      'koinonia': 'G2842',
      'metanoia': 'G3341',
      'parousia': 'G3952',
      'splanchnon': 'G4698',
      'hagios': 'G40',
      'aletheia': 'G225',
      'anthropos': 'G444',
      'prophetes': 'G4396',
      'graphe': 'G1124',
    };
    final wrong = <String, String?>{};
    expected.forEach((query, number) {
      final got = top(query);
      if (got != number) wrong[query] = got;
    });
    expect(wrong, isEmpty);
  });

  /// Twenty-nine Hebrew words, the same way. These are the ones the
  /// 1890 romanisation is furthest from: `shâlôwm`, `chêçêd`,
  /// `ʼĕlôhîym`, `ʼĂdônây`.
  test('Hebrew: the words a student types reach the right number', () {
    const expected = <String, String>{
      'shalom': 'H7965',
      'hesed': 'H2617',
      'chesed': 'H2617',
      'elohim': 'H430',
      'torah': 'H8451',
      'ruach': 'H7307',
      'nephesh': 'H5315',
      'nefesh': 'H5315',
      'davar': 'H1697',
      'adonai': 'H136',
      'kohen': 'H3548',
      'melek': 'H4428',
      'tsedeq': 'H6664',
      'mishpat': 'H4941',
      'emet': 'H571',
      'berit': 'H1285',
      'qadosh': 'H6918',
      'ahavah': 'H160',
      'bara': 'H1254',
      'shabbat': 'H7676',
      'goy': 'H1471',
      'olam': 'H5769',
      'nabi': 'H5030',
      'tehillah': 'H8416',
      'hokmah': 'H2451',
      'yare': 'H3372',
      'avon': 'H5771',
      'sefer': 'H5612',
      'mitzvah': 'H4687',
    };
    final wrong = <String, String?>{};
    expected.forEach((query, number) {
      final got = top(query);
      if (got != number) wrong[query] = got;
    });
    expect(wrong, isEmpty);
  });

  test('the tetragrammaton, by every spelling English uses', () {
    for (final q in <String>['yhwh', 'YHWH', 'Yahweh', 'jehovah', 'yehovah']) {
      expect(top(q), 'H3068', reason: q);
    }
  });

  test('a strict hit outranks a loose one across languages', () {
    // `charis` is χάρις as printed AND, collapsed, H2757 chârîyts —
    // "a sharp threshing instrument", three occurrences. Frequency
    // alone would still get this right; the tier is what makes it
    // right by construction rather than by luck.
    final hits = index.resolve('charis');
    expect(hits.first.strongs, 'G5485');
    expect(hits.first.exact, isTrue);
    expect(hits.any((h) => h.strongs == 'H2757' && !h.exact), isTrue);
  });

  test('collisions are shown, not resolved', () {
    // Three entries print `rûwach`/`ṭôrach`; the reader picks.
    expect(index.resolve('ruach').map((h) => h.strongs),
        <String>['H7307', 'H7306', 'H7308']);
    expect(index.resolve('torah').map((h) => h.strongs),
        <String>['H8451', 'H2960', 'H8452']);
  });

  test('the loose tier did not turn the index to mush', () {
    // Counted the way the reader meets it: one row per spelling she
    // could type, not one per tier. `strictKeyCount + looseKeyCount` is
    // 27,288 and would be the flattering number — thousands of strings
    // are filed in both tiers, and a spelling in both reaches the UNION
    // of what they hold, which is more candidates rather than fewer.
    // So the honest denominator is the union, and the honest numerator
    // counts a spelling ambiguous if `resolve` would return more than
    // one row for it.
    expect(index.typableKeyCount, lessThan(index.strictKeyCount + index.looseKeyCount));
    expect(index.typableKeyCount, 21147);
    expect(index.ambiguousKeyCount, 2757);
    // Eight, and the pane shows the first four: `resolve` takes a limit
    // and the offer uses its default. The full number is still the one
    // to watch — a regenerated lexicon that pushed it into the dozens
    // would mean the collapse rules had started guessing.
    expect(index.worstCollision, 8);
  });

  test('every candidate leads somewhere — no offer is a dead end', () {
    // All 13,964, not a sample: the provider drops a candidate whose
    // scoped verse list is empty, but unscoped it should never have to,
    // and "no dead end" is a claim about the index rather than about
    // the eight words the tests above happen to type.
    final dead = <String>[
      for (final w in words)
        if ((concordance[w.strongs] as Map<String, dynamic>?)?['r']
                is! List ||
            ((concordance[w.strongs] as Map<String, dynamic>)['r'] as List)
                .isEmpty)
          w.strongs,
    ];
    expect(dead, isEmpty);
  });

  test('a query in the original script is refused, not mishandled', () {
    // Typing ἀγάπη already works — the text scan finds it in a Greek
    // edition, and #321 fixed the fold that used to stop it. This file
    // must stay out of the way rather than offering a second answer.
    for (final q in <String>['ἀγάπη', 'אהבה', '慈爱', 'G26', '.love god']) {
      expect(index.resolve(q), isEmpty, reason: q);
    }
  });

  test('an ordinary English word reaches nothing it should not', () {
    // The index does not try to tell an English word from a romanised
    // one, and could not: `bad` is also H905 בַּד. What removes the
    // homograph class is the gate on the OFFER — the word must occur in
    // no verse of the edition, read as a word — and
    // `romanised_gate_corpus_test.dart` measures that every one of the
    // 1,814 KJV words this index resolves is a word the KJV contains,
    // so none of them can reach the reader. Recorded here so the cost
    // of ever loosening that gate stays visible.
    expect(top('bad'), 'H905');
    expect(top('den'), 'H1836');
    expect(top('dove'), 'H1679');
  });
}
