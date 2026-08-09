/// 2026-08-09 (SeekSparks): task #303 — the word list romanised the
/// wrong word.
///
/// A word list row is a LEMMA: every inflection of ἔρχομαι counts into
/// one row. But the romanisation printed on that row was taken from the
/// row's FIRST occurrence in the passage, while the Greek printed beside
/// it was the row's MOST FREQUENT form. In John those are different
/// words 193 times out of 1,013, and the row for G2064 read
/// `ἔρχεται · ēlthen` — a form and the romanisation of a different form.
///
/// Measured across `assets/originals/` before the fix: 8,030 of 58,447
/// rows (13.7%) printed a romanisation of a form other than the one
/// shown, worst in Leviticus (24.6%) and Exodus (23.1%); and of the
/// 18,872 rows whose first occurrence carried a romanisation at all,
/// 13,924 (73.8%) did not match the lemma's. The remaining 39,575 rows
/// are the Hebrew Bible, which carries no per-occurrence romanisation
/// in the corpus — those rows showed none at all.
///
/// The lexicon is keyed by Strong's number and so answers for the lemma.
/// These tests hold the list to it.
library;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/original_word.dart';
import 'package:seeksparks/models/strongs.dart';
import 'package:seeksparks/services/strongs_service.dart';
import 'package:seeksparks/utils/word_list.dart';
import 'package:seeksparks/widgets/word_analysis_pane.dart' show buildLemmaLine;

import 'dart:convert';

OriginalWord w(String text, String strongs, {String? translit}) =>
    OriginalWord(text: text, strongs: strongs, translit: translit);

StrongsEntry lex(String number, String lemma, String translit,
        {String pronunciation = ''}) =>
    StrongsEntry(
      number: number,
      lemma: lemma,
      translit: translit,
      pronunciation: pronunciation,
      gloss: '',
      definition: '',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buildWordList romanises the lemma', () {
    test('the lemma and its translit come from the lexicon, not the text',
        () {
      // Exactly the shape of the John G2064 defect: the commonest form
      // is ἔρχεται, the first occurrence is ἦλθεν, and the row is
      // neither — it is ἔρχομαι.
      final list = buildWordList(
        [
          w('ἦλθεν', 'G2064', translit: 'ēlthen'),
          w('ἔρχεται', 'G2064', translit: 'erchetai'),
          w('ἔρχεται', 'G2064', translit: 'erchetai'),
        ],
        lexicon: {'G2064': lex('G2064', 'ἔρχομαι', 'érchomai')},
      );
      expect(list.single.form, 'ἔρχεται', reason: 'commonest surface form');
      expect(list.single.lemma, 'ἔρχομαι');
      expect(list.single.lemmaTranslit, 'érchomai');
      expect(list.single.lemmaTranslit, isNot('ēlthen'),
          reason: 'the first occurrence must not supply the romanisation');
    });

    test('a number the lexicon does not carry gets no romanisation at all',
        () {
      // The 76 extended MorphGNT numbers (G6000+) have no Strong's
      // entry. The occurrence carries a romanisation and it is the only
      // one in reach — using it would restate the bug on exactly the
      // rows nobody can check.
      final list = buildWordList(
        [
          w('ἀγγέλλουσα', 'G6000', translit: 'angellousa'),
          w('ἀγγέλλων', 'G6000', translit: 'angellōn'),
          w('ἀγγέλλων', 'G6000', translit: 'angellōn'),
        ],
        lexicon: const {},
      );
      expect(list.single.form, 'ἀγγέλλων');
      expect(list.single.lemma, isNull);
      expect(list.single.lemmaTranslit, isNull);
    });

    test('an empty lexicon field is absent, not an empty string', () {
      final list = buildWordList(
        [w('θεός', 'G2316')],
        lexicon: {'G2316': lex('G2316', '', '')},
      );
      expect(list.single.lemma, isNull);
      expect(list.single.lemmaTranslit, isNull);
    });

    test('Hebrew rows gain a romanisation they never had', () {
      // The corpus carries `t` for the Greek NT only — 300,808 Hebrew
      // tokens have none — so before this the whole Old Testament
      // showed a bare Strong's number.
      final list = buildWordList(
        [w('אֱלֹהִים', 'H430')],
        lexicon: {'H430': lex('H430', 'אֱלֹהִים', 'ʼĕlôhîym')},
      );
      expect(list.single.lemmaTranslit, 'ʼĕlôhîym');
    });
  });

  group('buildLemmaLine', () {
    test('names the lemma when the occurrence is an inflection of it', () {
      expect(
        buildLemmaLine(form: 'ἦλθεν', lemma: 'ἔρχομαι', translit: 'érchomai'),
        'ἔρχομαι · érchomai',
      );
    });

    test('does not repeat the word already printed above it', () {
      expect(
        buildLemmaLine(form: 'ἔρχομαι', lemma: 'ἔρχομαι', translit: 'érchomai'),
        'érchomai',
      );
    });

    test('carries the pronunciation when the lexicon has one', () {
      expect(
        buildLemmaLine(
            form: 'אֱלֹהִים',
            lemma: 'אֱלֹהִים',
            translit: 'ʼĕlôhîym',
            pronunciation: 'el-o-heem'),
        'ʼĕlôhîym  /el-o-heem/',
      );
    });

    test('is empty when the lexicon knows nothing, rather than a stray dot',
        () {
      expect(buildLemmaLine(form: 'ἀγγέλλουσα'), isEmpty);
    });
  });

  group('against the shipped assets', () {
    test('the six heaviest rows in John name their own lemma', () async {
      final raw = await rootBundle.loadString('assets/originals/john.json');
      final verses = jsonDecode(raw) as Map<String, dynamic>;
      final words = <OriginalWord>[
        for (final v in verses.values)
          for (final j in v as List)
            OriginalWord.fromJson(j as Map<String, dynamic>),
      ];
      final lexicon =
          await StrongsService.lookupAll(words.map((x) => x.strongs));
      final list = buildWordList(words, lexicon: lexicon);
      final byNumber = {for (final e in list) e.strongs: e};

      // Form, lemma and romanisation for the rows a reader of John meets
      // first. Every one of these printed a different word's
      // romanisation before the fix.
      const expected = <String, (String, String, String)>{
        'G1473': ('με', 'ἐγώ', 'egṓ'),
        'G1510': ('ἐστιν', 'εἰμί', 'eimí'),
        'G4771': ('ὑμῖν', 'σύ', 'sý'),
        'G3004': ('Λέγει', 'λέγω', 'légō'),
        'G2424': ('Ἰησοῦς', 'Ἰησοῦς', 'Iēsoûs'),
        'G2064': ('ἔρχεται', 'ἔρχομαι', 'érchomai'),
      };
      for (final e in expected.entries) {
        final row = byNumber[e.key];
        expect(row, isNotNull, reason: '${e.key} missing from John');
        expect(row!.form, e.value.$1, reason: '${e.key} form');
        expect(row.lemma, e.value.$2, reason: '${e.key} lemma');
        expect(row.lemmaTranslit, e.value.$3, reason: '${e.key} translit');
      }
    });

    test('no row in John romanises a word other than its own lemma',
        () async {
      final raw = await rootBundle.loadString('assets/originals/john.json');
      final verses = jsonDecode(raw) as Map<String, dynamic>;
      final words = <OriginalWord>[
        for (final v in verses.values)
          for (final j in v as List)
            OriginalWord.fromJson(j as Map<String, dynamic>),
      ];
      final lexicon =
          await StrongsService.lookupAll(words.map((x) => x.strongs));
      final list = buildWordList(words, lexicon: lexicon);
      expect(list.length, greaterThan(900), reason: 'John has ~1,013 lemmas');

      final wrong = <String>[];
      for (final e in list) {
        final entry = lexicon[e.strongs];
        if (entry == null) {
          if (e.lemmaTranslit != null) wrong.add('${e.strongs} invented');
          continue;
        }
        if (e.lemmaTranslit != null && e.lemmaTranslit != entry.translit) {
          wrong.add('${e.strongs} ${e.lemmaTranslit} != ${entry.translit}');
        }
      }
      expect(wrong, isEmpty);
    });
  });
}
