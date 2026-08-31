// `assets/section_titles.json` carries an app-written `note` inside `_meta`
// stating that the 1,443 headings per title set (and their background
// notes) are original to this app, not taken from any published edition.
// Third instance of the class #318 phase 24 and the #292 disclosure pass
// each fixed once by hand: a stamped asset whose own provenance block
// nothing parses. This file guards the header itself and its call sites.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/services/section_title_service.dart';

void main() {
  final raw =
      json.decode(File('assets/section_titles.json').readAsStringSync())
          as Map<String, dynamic>;
  final metaJson = raw['_meta'] as Map<String, dynamic>;

  test('the asset\'s provenance note is trilingual and reaches the model',
      () {
    final meta = SectionTitleMeta.fromJson(metaJson);
    expect(meta.source, 'app-curated');
    expect(meta.notPublishedHeadings, isTrue);
    final en = meta.noteFor('en');
    final hans = meta.noteFor('zh-Hans');
    final hant = meta.noteFor('zh-Hant');
    expect(en, isNotEmpty);
    expect(hans, isNotEmpty);
    expect(hant, isNotEmpty);
    expect(en, isNot(equals(hans)));
    expect(en, isNot(equals(hant)));
    expect(hans, isNot(equals(hant)));
  });

  test('noteFor falls back to English on an unknown locale', () {
    final meta = SectionTitleMeta.fromJson(metaJson);
    expect(meta.noteFor('fr'), meta.noteFor('en'));

    final empty = SectionTitleMeta.fromJson(const {});
    expect(empty.noteFor('en'), '');
  });

  test('the header keys are exactly the seven named', () {
    expect(
      metaJson.keys.toSet(),
      {
        'version',
        'books',
        'generatedAt',
        'description',
        'source',
        'notPublishedHeadings',
        'note',
      },
    );
  });

  test('every heading carries a background note, in all three sets', () {
    final sets = raw['sets'] as Map<String, dynamic>;
    for (final setId in ['cuv', 'cuv-tr', 'english-classic']) {
      final books = sets[setId] as Map<String, dynamic>;
      var n = 0;
      var ctx = 0;
      for (final chapters in books.values) {
        for (final entries in (chapters as Map<String, dynamic>).values) {
          for (final e in entries as List) {
            n++;
            final c = (e as Map)['context'];
            if (c is String && c.isNotEmpty) ctx++;
          }
        }
      }
      expect(n, 1443, reason: '$setId heading count moved');
      expect(books.length, 66, reason: '$setId book count moved');
      expect(ctx, 1443, reason: '$setId not every heading carries a context');
    }
  });

  test('the provenance note has a call site outside the model', () {
    final readingPane = File('lib/widgets/bible_reading_pane.dart')
        .readAsStringSync();
    expect(readingPane, contains('SectionTitleService.provenanceNote('),
        reason: 'the reading pane never renders the provenance note');

    final aboutPage = File('lib/pages/about_page.dart').readAsStringSync();
    expect(aboutPage, contains('aboutLicenseSectionHeadings'),
        reason: 'the About page never credits the section headings');
  });
}
