/// Tests for the Forms readout's arithmetic — BibleWorks bwh10q.
///
/// Two halves. The first exercises the pure decoders against handwritten
/// rows. The second reads the shipped asset off disk, because every
/// decoder here is a contract with `tools/build_forms_index.py` and a
/// unit test that only ever sees handwritten input would stay green
/// through a builder change that silently broke the app.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/utils/word_forms.dart';

WordForm f(String form, String morph, int count) =>
    WordForm(form: form, morph: morph, count: count);

FormParse p(String strongs, String morph, int count) =>
    FormParse(strongs: strongs, morph: morph, count: count);

void main() {
  group('formsShardFor', () {
    test('buckets by hundreds, keeping the language letter', () {
      expect(formsShardFor('G3056'), 'G30');
      expect(formsShardFor('H120'), 'H1');
      expect(formsShardFor('G1'), 'G0');
      expect(formsShardFor('G99'), 'G0');
      expect(formsShardFor('G100'), 'G1');
      expect(formsShardFor('H9999'), 'H99');
    });

    test('leading zeros do not change the bucket', () {
      expect(formsShardFor('G0100'), formsShardFor('G100'));
    });

    test('returns null rather than a wrong shard for junk', () {
      expect(formsShardFor(''), isNull);
      expect(formsShardFor('G'), isNull);
      expect(formsShardFor('Gxyz'), isNull);
      expect(formsShardFor('G-5'), isNull);
    });
  });

  group('sortForms', () {
    final forms = [
      f('βῆτα', 'N-----NSF-', 5),
      f('ἄλφα', 'V-3IAI-S--', 5),
      f('γάμμα', 'A-----NSM-', 9),
    ];

    test('frequency puts the commonest first', () {
      expect(sortForms(forms, FormSort.frequency).map((x) => x.form),
          ['γάμμα', 'βῆτα', 'ἄλφα']);
    });

    test('alphabetical orders by surface form', () {
      expect(sortForms(forms, FormSort.alphabetical).map((x) => x.form),
          ['γάμμα', 'βῆτα', 'ἄλφα']..sort());
    });

    test('morphCode orders by the parsing code, so by part of speech', () {
      expect(sortForms(forms, FormSort.morphCode).map((x) => x.morph),
          ['A-----NSM-', 'N-----NSF-', 'V-3IAI-S--']);
    });

    test('does not mutate the caller list', () {
      final original = [...forms];
      sortForms(forms, FormSort.alphabetical);
      expect(forms.map((x) => x.form), original.map((x) => x.form));
    });

    // The sort bar lets a reader flip back and forth; a list that
    // reshuffles on the return trip reads as a bug.
    test('is a total order — ties break on the form, so round trips are '
        'identical', () {
      for (final by in FormSort.values) {
        final once = sortForms(forms, by).map((x) => x.form).toList();
        final twice = sortForms(sortForms(forms, FormSort.alphabetical), by)
            .map((x) => x.form)
            .toList();
        expect(twice, once, reason: '$by is not stable across re-sorts');
      }
    });

    test('empty in, empty out', () {
      expect(sortForms(const [], FormSort.frequency), isEmpty);
    });
  });

  group('FormAmbiguity', () {
    test('a form the asset has no entry for is unambiguous, not an error', () {
      const a = FormAmbiguity.unambiguous('λόγος');
      expect(a.isAmbiguous, isFalse);
      expect(a.spansLemmas, isFalse);
      expect(a.othersThan('G3056', 'N-----NSM-'), isEmpty);
    });

    test('one parse is not an ambiguity', () {
      final a = FormAmbiguity('λόγος', [p('G3056', 'N-----NSM-', 63)]);
      expect(a.isAmbiguous, isFalse);
      expect(a.lemmaCount, 1);
    });

    test('two parses of one lemma is a parse ambiguity, not a lexical one', () {
      final a = FormAmbiguity('x', [
        p('G3056', 'N-----NSM-', 10),
        p('G3056', 'N-----ASM-', 4),
      ]);
      expect(a.isAmbiguous, isTrue);
      expect(a.lemmaCount, 1);
      expect(a.spansLemmas, isFalse);
    });

    // H120 "man" 18× vs H121 "Adam" 2× — the case a reader must not miss.
    test('two lemmas is a lexical ambiguity', () {
      final a = FormAmbiguity('אָדָ֥ם', [
        p('H120', 'HNcmsa', 18),
        p('H121', 'HNp', 2),
      ]);
      expect(a.spansLemmas, isTrue);
      expect(a.lemmaCount, 2);
    });

    test('othersThan drops the reading on screen and keeps the rest', () {
      final a = FormAmbiguity('אָדָ֥ם', [
        p('H120', 'HNcmsa', 18),
        p('H121', 'HNp', 2),
      ]);
      expect(a.othersThan('H120', 'HNcmsa').single.strongs, 'H121');
      // Same lemma, different parse: still an alternative.
      expect(a.othersThan('H120', 'HNp').length, 2);
      // A word not in the list at all sees every row.
      expect(a.othersThan('G3056', '').length, 2);
    });
  });

  group('WordForm.fromJson', () {
    test('decodes a full row', () {
      final w = WordForm.fromJson(['λόγον', 'N-----ASM-', 130, ['39 1:1']]);
      expect(w!.form, 'λόγον');
      expect(w.morph, 'N-----ASM-');
      expect(w.count, 130);
      expect(w.refs, ['39 1:1']);
    });

    test('refs are optional and an untagged token has an empty morph', () {
      final w = WordForm.fromJson(['x', '', 1]);
      expect(w!.refs, isEmpty);
      expect(w.morph, '');
    });

    test('rejects malformed rows rather than inventing a form', () {
      expect(WordForm.fromJson(null), isNull);
      expect(WordForm.fromJson('λόγον'), isNull);
      expect(WordForm.fromJson(['λόγον', 'N']), isNull);
      expect(WordForm.fromJson(['', 'N', 1]), isNull);
      expect(WordForm.fromJson(['λόγον', 'N', '130']), isNull);
    });
  });

  group('FormParse.fromJson', () {
    test('decodes a row', () {
      final q = FormParse.fromJson(['H121', 'HNp', 2]);
      expect(q!.strongs, 'H121');
      expect(q.count, 2);
    });

    test('rejects malformed rows', () {
      expect(FormParse.fromJson(['', 'HNp', 2]), isNull);
      expect(FormParse.fromJson(['H121', 'HNp']), isNull);
      expect(FormParse.fromJson(<Object?>[]), isNull);
    });
  });

  group('parseFormRef', () {
    const books = ['genesis', '1_corinthians', 'song_of_solomon'];

    test('decodes an interned ref into a navigable reference', () {
      final r = parseFormRef('1 4:19', books)!;
      expect(r.englishBook, '1 Corinthians');
      expect(r.chapter, 4);
      expect(r.verse, 19);
    });

    test('resolves a slug with an apostrophe stripped out', () {
      expect(parseFormRef('2 2:1', books)!.englishBook, 'Song of Solomon');
    });

    // These drive navigation. A ref that lands on the wrong verse is
    // worse than one that is simply not offered.
    test('returns null for anything it cannot decode exactly', () {
      expect(parseFormRef('', books), isNull);
      expect(parseFormRef('0 1', books), isNull);
      expect(parseFormRef('0:1 1', books), isNull);
      expect(parseFormRef('x 1:1', books), isNull);
      expect(parseFormRef('0 x:1', books), isNull);
      expect(parseFormRef('0 1:x', books), isNull);
      expect(parseFormRef('9 1:1', books), isNull, reason: 'book out of range');
      expect(parseFormRef('-1 1:1', books), isNull);
      expect(parseFormRef('0 0:1', books), isNull, reason: 'no chapter 0');
      expect(parseFormRef('0 1:0', books), isNull, reason: 'no verse 0');
    });
  });

  group('ui strings', () {
    test('every key the Forms section asks for exists in all three locales',
        () {
      const keys = [
        'formsAmbiguousLemma',
        'formsAmbiguousParse',
        'formsHeader',
        'formsSortBy',
        'formsSortFrequency',
        'formsSortCode',
        'formsSortAlpha',
      ];
      for (final k in keys) {
        for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
          expect(uiStrings[k]?[locale], isNotNull,
              reason: '$k is missing for $locale');
        }
      }
    });

    test('the header carries both placeholders in every locale', () {
      for (final v in uiStrings['formsHeader']!.values) {
        expect(v, contains('{n}'));
        expect(v, contains('{total}'));
      }
    });
  });

  // ── The asset itself. These guard the contract with the builder. ────

  group('assets/forms', () {
    late Map<String, dynamic> index;

    setUpAll(() {
      index = jsonDecode(File('assets/forms/index.json').readAsStringSync())
          as Map<String, dynamic>;
    });

    test('every book slug in the index resolves to a canonical name', () {
      for (final slug in (index['books'] as List).cast<String>()) {
        expect(originalsSlugToBook[slug], isNotNull,
            reason: '$slug has no English book name');
      }
    });

    test('originalsSlugToBook covers every file under assets/originals', () {
      final slugs = Directory('assets/originals')
          .listSync()
          .whereType<File>()
          .map((e) => e.uri.pathSegments.last)
          .where((n) => n.endsWith('.json'))
          .map((n) => n.substring(0, n.length - 5));
      expect(slugs, isNotEmpty);
      for (final slug in slugs) {
        expect(originalsSlugToBook[slug], isNotNull, reason: slug);
      }
    });

    test('the declared shards are the files that are actually there', () {
      final declared = (index['shards'] as List).cast<String>().toSet();
      final present = Directory('assets/forms/l')
          .listSync()
          .whereType<File>()
          .map((e) => e.uri.pathSegments.last)
          .where((n) => n.endsWith('.json'))
          .map((n) => n.substring(0, n.length - 5))
          .toSet();
      expect(present, declared);
    });

    test('G3056 λόγος parses, and its paradigm matches the corpus', () {
      final shard = jsonDecode(
              File('assets/forms/l/${formsShardFor('G3056')}.json')
                  .readAsStringSync())
          as Map<String, dynamic>;
      final forms = [
        for (final row in shard['G3056'] as List)
          if (WordForm.fromJson(row) case final w?) w,
      ];
      expect(forms.length, (shard['G3056'] as List).length,
          reason: 'a row failed to decode');
      final byFrequency = sortForms(forms, FormSort.frequency);
      expect(byFrequency.first.form, 'λόγον');
      expect(byFrequency.first.count, 130);
    });

    test('every ref in a sampled shard decodes', () {
      final books = (index['books'] as List).cast<String>();
      final shard = jsonDecode(
              File('assets/forms/l/${formsShardFor('G3056')}.json')
                  .readAsStringSync())
          as Map<String, dynamic>;
      var checked = 0;
      for (final rows in shard.values) {
        for (final row in rows as List) {
          final w = WordForm.fromJson(row);
          if (w == null) continue;
          expect(w.refs.length, lessThanOrEqualTo(index['refsPerTriple']));
          for (final raw in w.refs) {
            expect(parseFormRef(raw, books), isNotNull, reason: raw);
            checked++;
          }
        }
      }
      expect(checked, greaterThan(100));
    });

    test('the ambiguous index holds only genuinely ambiguous forms', () {
      final raw =
          jsonDecode(File('assets/forms/ambiguous.json').readAsStringSync())
              as Map<String, dynamic>;
      expect(raw.length, index['ambiguousForms']);
      for (final entry in raw.entries) {
        final parses = [
          for (final row in entry.value as List)
            if (FormParse.fromJson(row) case final q?) q,
        ];
        expect(FormAmbiguity(entry.key, parses).isAmbiguous, isTrue,
            reason: '${entry.key} is in the index with one parse');
      }
    });

    test('אָדָ֥ם is recorded as a lexical ambiguity — H120 man, H121 Adam', () {
      final raw =
          jsonDecode(File('assets/forms/ambiguous.json').readAsStringSync())
              as Map<String, dynamic>;
      final rows = raw['אָדָ֥ם'];
      expect(rows, isNotNull, reason: 'the sample form left the corpus');
      final a = FormAmbiguity('אָדָ֥ם', [
        for (final row in rows as List)
          if (FormParse.fromJson(row) case final q?) q,
      ]);
      expect(a.spansLemmas, isTrue);
      expect(a.parses.map((x) => x.strongs), containsAll(['H120', 'H121']));
    });
  });
}
