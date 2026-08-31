// `assets/book_introductions.json` states an AUTHOR and a DATE for all 66
// books, trilingually, rendered by default at the top of chapter 1. Its
// `_meta` carried no `source` key at all until this change, and nothing in
// lib/ parsed `_meta`. Fourth instance of the class #318 phase 24, the #292
// pass and v1.6.195's section-titles pass each fixed once: a stamped asset
// whose own provenance block nothing parses. This file guards the header
// itself, its call sites, and the one measured disagreement against
// `bible_timeline.json` (Jonah).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/services/book_intro_service.dart';

void main() {
  final raw =
      json.decode(File('assets/book_introductions.json').readAsStringSync())
          as Map<String, dynamic>;
  final metaJson = raw['_meta'] as Map<String, dynamic>;

  test('the asset header names its source and its dating system', () {
    expect(metaJson['source'], 'app-curated');
    expect(metaJson['notFromAnyEdition'], isTrue);
    final datingSystem = metaJson['datingSystem'] as String;
    expect(datingSystem, isNotEmpty);
    expect(datingSystem, contains('1446'));
  });

  test('the header note is trilingual and says what it must', () {
    final note = metaJson['note'] as Map<String, dynamic>;
    final en = note['en'] as String;
    final hans = note['zh-Hans'] as String;
    final hant = note['zh-Hant'] as String;
    expect(en, isNotEmpty);
    expect(hans, isNotEmpty);
    expect(hant, isNotEmpty);
    expect(en, contains('written for this app'));
    expect(en, contains('1446'));
    expect(en, contains('date several of these books differently'));
  });

  test('BookIntroMeta parses the shipped header and falls back to English',
      () {
    final meta = BookIntroMeta.fromJson(metaJson);
    expect(meta.source, 'app-curated');
    expect(meta.notFromAnyEdition, isTrue);
    expect(meta.datingSystem, contains('1446'));
    expect(meta.note.keys.toSet(), {'en', 'zh-Hans', 'zh-Hant'});
    expect(meta.noteFor('fr'), meta.noteFor('en'));
    expect(meta.noteFor('zh-Hant'), isNot(equals(meta.noteFor('zh-Hans'))));
  });

  test('all 66 introductions still parse, in all three locales', () {
    final intros = raw['intros'] as Map<String, dynamic>;
    expect(intros.length, 66);
    const locales = ['en', 'zh-Hans', 'zh-Hant'];
    for (final entry in intros.entries) {
      final data = entry.value as Map<String, dynamic>;
      for (final field in [
        'author',
        'date',
        'subtitle',
        'summary',
        'audience',
        'keyPassageDescription',
      ]) {
        final localized = data[field] as Map<String, dynamic>;
        for (final locale in locales) {
          final s = localized[locale] as String?;
          expect(s, isNotNull, reason: '${entry.key}.$field.$locale');
          expect(s, isNotEmpty, reason: '${entry.key}.$field.$locale');
        }
      }
      final themes = data['themes'] as Map<String, dynamic>;
      for (final locale in locales) {
        final list = themes[locale] as List?;
        expect(list, isNotNull, reason: '${entry.key}.themes.$locale');
        expect(list, isNotEmpty, reason: '${entry.key}.themes.$locale');
      }
    }
  });

  test(
      'the introductions agree with bible_timeline.json where both name '
      'the same event', () {
    final timeline =
        json.decode(File('assets/bible_timeline.json').readAsStringSync())
            as Map<String, dynamic>;
    final events = {
      for (final e in (timeline['events'] as List))
        (e as Map<String, dynamic>)['id'] as String: e,
    };
    final intros = raw['intros'] as Map<String, dynamic>;

    const pairs = {
      'exodus': 'Exodus',
      'moses_dies': 'Deuteronomy',
      'david_king': '2 Samuel',
      'solomon_king': '1 Kings',
      'judah_falls': '2 Kings',
      'malachi': 'Malachi',
      'jeremiah': 'Jeremiah',
      'nehemiah_walls': 'Nehemiah',
      'ezra_returns': 'Ezra',
      'john_patmos': 'Revelation',
    };

    for (final entry in pairs.entries) {
      final year = (events[entry.key]!['year'] as num).abs();
      final intro = intros[entry.value] as Map<String, dynamic>;
      final dateEn = (intro['date'] as Map<String, dynamic>)['en'] as String;
      expect(dateEn, contains(year.toInt().toString()),
          reason: '${entry.key} / ${entry.value}');
    }
  });

  test('the one measured disagreement is recorded, not silently carried', () {
    // Both sides are hedged (timeline: approximate=true; intro: "ca."), so by
    // this repo's rule (both exact -> repair; either hedged -> name and
    // leave) neither number is changed; this test exists so the
    // disagreement is on the record rather than forgotten.
    final timeline =
        json.decode(File('assets/bible_timeline.json').readAsStringSync())
            as Map<String, dynamic>;
    final events = {
      for (final e in (timeline['events'] as List))
        (e as Map<String, dynamic>)['id'] as String: e,
    };
    final jonahEvent = events['jonah']!;
    expect(jonahEvent['year'], -780);
    expect(jonahEvent['approximate'], isTrue);

    final intros = raw['intros'] as Map<String, dynamic>;
    final jonahIntro = intros['Jonah'] as Map<String, dynamic>;
    final dateEn =
        (jonahIntro['date'] as Map<String, dynamic>)['en'] as String;
    expect(dateEn, 'ca. 760 BCE');
    expect(dateEn, isNot(contains('780')));
  });

  test('the reading pane actually calls provenanceNote', () {
    final readingPane =
        File('lib/widgets/bible_reading_pane.dart').readAsStringSync();
    expect(readingPane, contains('BookIntroService.provenanceNote('),
        reason: 'the reading pane never renders the provenance note');
  });
}
