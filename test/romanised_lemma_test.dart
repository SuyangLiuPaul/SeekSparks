import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/romanised_lemma.dart';
import 'package:seeksparks/utils/vocabulary.dart';

/// The mechanics of the romanised fold, on input small enough to read.
/// `romanised_lemma_corpus_test.dart` runs the same core against the
/// real 13,964-entry lexicon, which is where the claims live.
void main() {
  VocabWord word(String strongs, String translit, {int count = 10}) =>
      VocabWord(
        strongs: strongs,
        lemma: '—',
        translit: translit,
        gloss: '',
        corpusCount: count,
      );

  group('romanisedKey', () {
    test('strips the accents Strong\'s prints', () {
      expect(romanisedKey('agápē'), 'agape');
      expect(romanisedKey('shâlôwm'), 'shalowm');
      // Cedilla folds to `c`, not to `s` — the strict key is the
      // romanisation as printed, and `çâmek` really is written with a
      // `c`. Turning it into `s` is the loose tier's job.
      expect(romanisedKey('chêçêd'), 'checed');
    });

    test('folds the two modifier letters, which are not marks', () {
      // U+1D49 and U+02E2 are letters in their own right, so
      // `foldDiacritics` leaves them alone and this has to name them.
      expect(romanisedKey('Yᵉhôvâh'), 'yehovah');
      expect(romanisedKey('bᵉrîyth'), 'beriyth');
    });

    test('drops aleph and ayin', () {
      expect(romanisedKey('ʼĕlôhîym'), 'elohiym');
      expect(romanisedKey('shâmaʻ'), 'shama');
    });

    test('refuses what is not a single romanised word', () {
      expect(romanisedKey('agape pistis'), isNull, reason: 'a phrase');
      expect(romanisedKey('G26'), isNull, reason: 'a Strong\'s number');
      expect(romanisedKey('.love god'), isNull, reason: 'a command line');
      expect(romanisedKey("'in the beginning"), isNull);
      expect(romanisedKey('faith*'), isNull);
      expect(romanisedKey('ἀγάπη'), isNull, reason: 'Greek script');
      expect(romanisedKey('אהבה'), isNull, reason: 'Hebrew script');
      expect(romanisedKey('慈爱'), isNull, reason: 'CJK');
      expect(romanisedKey('el'), isNull, reason: 'under three letters');
    });

    test('a lexicon headword may be two words; a reader\'s line may not',
        () {
      expect(romanisedKey('ʼĕlôhîym ʼăchêrîym', fromLexicon: true),
          'elohiymacheriym');
      expect(romanisedKey('ʼĕlôhîym ʼăchêrîym'), isNull);
    });
  });

  group('collapse rules', () {
    test('Hebrew: the mater lectionis goes before the consonant rules', () {
      // `ow` must become `o` before `w` becomes `b`, or shalom is lost.
      expect(collapseHebrew('shalowm'), 'shalom');
      expect(collapseHebrew('shalom'), 'shalom');
      expect(collapseHebrew('elohiym'), 'elohim');
      expect(collapseHebrew('ruwach'), 'ruah');
      expect(collapseHebrew('ruach'), 'ruah');
    });

    test('Hebrew: the three spellings of heth meet', () {
      expect(collapseHebrew('chesed'), 'hesed');
      expect(collapseHebrew('khesed'), 'hesed');
      expect(collapseHebrew('hesed'), 'hesed');
    });

    test('Hebrew: samekh, tsade, qoph, tav, pe, bet, yod', () {
      expect(collapseHebrew('cuwph'), 'suf');
      expect(collapseHebrew('mitzvah'), 'misbah');
      expect(collapseHebrew('mitsvah'), 'misbah');
      expect(collapseHebrew('qadowsh'), 'kadosh');
      expect(collapseHebrew('kadosh'), 'kadosh');
      expect(collapseHebrew('nephesh'), 'nefesh');
      expect(collapseHebrew('dabar'), 'dabar');
      expect(collapseHebrew('davar'), 'dabar');
      expect(collapseHebrew('adonay'), 'adonai');
    });

    test('Greek stays close to the modern spelling', () {
      expect(collapseGreek('euaggelion'), 'euangelion');
      expect(collapseGreek('psuche'), 'psuche');
      expect(collapseGreek('psyche'), 'psuche');
      expect(collapseGreek('kurios'), 'kurios');
      expect(collapseGreek('kyrios'), 'kurios');
      expect(collapseGreek('prophetes'), 'profetes');
    });
  });

  group('resolve', () {
    final index = RomanisedLemmaIndex.fromWords(<VocabWord>[
      word('G26', 'agápē', count: 116),
      word('G25', 'agapáō', count: 143),
      word('H2617', 'chêçêd', count: 251),
      word('H7965', 'shâlôwm', count: 237),
      word('H8451', 'tôwrâh', count: 222),
      word('H8452', 'tôwrâh', count: 1),
      word('H3068', 'Yᵉhôvâh', count: 6521),
    ]);

    test('the printed romanisation is a strict hit', () {
      final hits = index.resolve('agape');
      expect(hits.single.strongs, 'G26');
      expect(hits.single.exact, isTrue);
    });

    test('a modern spelling is a loose hit', () {
      final hits = index.resolve('shalom');
      expect(hits.single.strongs, 'H7965');
      expect(hits.single.exact, isFalse);
      expect(index.resolve('hesed').single.strongs, 'H2617');
    });

    test('collisions are kept, and ranked by corpus frequency', () {
      final hits = index.resolve('torah');
      expect(hits.map((h) => h.strongs), <String>['H8451', 'H8452']);
    });

    test('the tetragrammaton is pinned, because its spelling is a '
        'convention rather than a romanisation', () {
      expect(index.resolve('yhwh').single.strongs, 'H3068');
      expect(index.resolve('yahweh').single.strongs, 'H3068');
      expect(index.resolve('jehovah').single.strongs, 'H3068');
      // And the fold still reaches it by what the lexicon prints.
      expect(index.resolve('yehovah').single.strongs, 'H3068');
    });

    test('the shewa alternate is a second key, not a replacement', () {
      final index = RomanisedLemmaIndex.fromWords(<VocabWord>[
        word('H1285', 'bᵉrîyth', count: 284),
      ]);
      expect(index.resolve('berit').single.strongs, 'H1285');
      expect(index.resolve('brit').single.strongs, 'H1285');
    });

    test('a line that is not a romanised word resolves to nothing', () {
      expect(index.resolve('G26'), isEmpty);
      expect(index.resolve('love'), isEmpty);
      expect(index.resolve(''), isEmpty);
    });

    test('no entry appears twice, however many keys reached it', () {
      // `chêçêd` files under `chesed` strict and `hesed` loose; a query
      // of either must not report the entry once per key.
      expect(index.resolve('chesed').length, 1);
    });
  });
}
