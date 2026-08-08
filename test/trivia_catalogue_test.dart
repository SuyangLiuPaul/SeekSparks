// 2026-08-09 (task #279, `bible_trivia_page`): the catalogue is data,
// and data in a Dart list gets no schema check from the compiler.
//
// The defect this was written for: one entry read `reference:
// 'Philemon 16'`. Philemon has a single chapter, so the parser took 16
// as the CHAPTER, the canonical sort put the entry at Philemon 16, and
// "Read in Bible" jumped to a chapter that does not exist. Nothing in
// the analyzer, the widget tree or the existing suite could see it —
// the string is well-formed, it just names nothing.
//
// So every reference in the catalogue is resolved against the bundled
// KJV, which is the same corpus the reader jumps into. A reference that
// cannot be resolved here is a link that is already broken in the app.
//
// The second group guards the display side. The tile prints the
// reference through `localizedReferenceLabel`; before #283-class fixes
// it printed the raw English string, which is invisible in an English
// test run and wrong in the two locales most of this app's readers use.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/pages/bible_trivia_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/utils/reference_parser.dart';
import 'package:seeksparks/utils/version_mapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('trivia catalogue references resolve', () {
    // book → chapter → set of verse numbers, from the bundled KJV.
    late Map<String, Map<int, Set<int>>> kjv;

    setUpAll(() async {
      final raw = await rootBundle.loadString('assets/kjv.json');
      kjv = <String, Map<int, Set<int>>>{};
      for (final v in json.decode(raw) as List<dynamic>) {
        final m = v as Map<String, dynamic>;
        // `chapter`/`verse` are strings in the bundled asset, not ints.
        final book = m['book'] as String;
        final chapter = int.parse('${m['chapter']}');
        (kjv[book] ??= <int, Set<int>>{})
            .putIfAbsent(chapter, () => <int>{})
            .add(int.parse('${m['verse']}'));
      }
    });

    test('every reference parses', () {
      final unparseable = <String>[];
      for (final e in bibleTriviaEntries) {
        final ref = e.reference;
        if (ref == null || ref.trim().isEmpty) continue;
        if (parseReference(ref) == null) unparseable.add(ref);
      }
      expect(unparseable, isEmpty,
          reason: 'a reference the parser cannot read is an entry that '
              'silently drops out of the book/testament filters and out '
              'of the canonical sort');
    });

    test('every reference names a book, chapter and verse that exist', () {
      final broken = <String>[];
      for (final e in bibleTriviaEntries) {
        final raw = e.reference;
        if (raw == null || raw.trim().isEmpty) continue;
        final ref = parseReference(raw);
        if (ref == null) continue; // reported by the test above

        final chapters = kjv[ref.englishBook];
        if (chapters == null) {
          broken.add('$raw — no such book "${ref.englishBook}"');
          continue;
        }
        final verses = chapters[ref.chapter];
        if (verses == null) {
          broken.add('$raw — ${ref.englishBook} has '
              '${chapters.length} chapters, not ${ref.chapter}');
          continue;
        }
        for (final v in <int>{
          if (ref.verseStart != null) ref.verseStart!,
          if (ref.verseEnd != null) ref.verseEnd!,
          ...ref.verses,
        }) {
          if (!verses.contains(v)) {
            broken.add('$raw — ${ref.englishBook} ${ref.chapter} has '
                '${verses.length} verses, no verse $v');
          }
        }
      }
      expect(broken, isEmpty,
          reason: 'these entries link to a passage that is not in the '
              'bundled text:\n  ${broken.join('\n  ')}');
    });

    test('single-chapter books carry an explicit chapter', () {
      // The `Philemon 16` shape specifically: in a one-chapter book the
      // bare number is read as a chapter, so the reference has to be
      // written `1:16`. Asserted separately from the resolution test
      // because a one-chapter book with a plausible chapter number
      // (Jude 1, 2 John 1) resolves fine and is still ambiguous to
      // read.
      const singleChapter = <String>{
        'Obadiah', 'Philemon', '2 John', '3 John', 'Jude',
      };
      final bare = <String>[];
      for (final e in bibleTriviaEntries) {
        final raw = e.reference;
        if (raw == null) continue;
        final ref = parseReference(raw);
        if (ref == null) continue;
        if (singleChapter.contains(ref.englishBook) && !raw.contains(':')) {
          bare.add(raw);
        }
      }
      expect(bare, isEmpty,
          reason: 'write these as "Book 1:verse" — a bare number after a '
              'one-chapter book parses as a chapter: $bare');
    });
  });

  group('the reference badge is localized', () {
    // The tile renders `localizedReferenceLabel(entry.reference, locale)`.
    // If a book name ever fails to map, the badge falls back to the raw
    // English, which is exactly the defect being guarded — so assert on
    // the absence of Latin letters rather than on one hand-picked book.
    final latin = RegExp(r'[A-Za-z]');

    for (final locale in const <String>['zh-Hans', 'zh-Hant']) {
      test('no catalogue reference stays English under $locale', () {
        final english = <String>[];
        for (final e in bibleTriviaEntries) {
          final raw = e.reference;
          if (raw == null || raw.trim().isEmpty) continue;
          final label = localizedReferenceLabel(raw, locale);
          if (latin.hasMatch(label)) english.add('$raw → $label');
        }
        expect(english, isEmpty,
            reason: 'these references print as English in a Chinese '
                'locale:\n  ${english.join('\n  ')}');
      });
    }
  });

  group('diagrams survive the narrowest pane', () {
    // The four diagram kinds only build once a tile is EXPANDED, so the
    // existing collapsed-page smoke test at 320px never reaches them —
    // and they are the densest thing on the page (a 22-cell alphabet
    // grid, a row of `Expanded` bars). Search-filter down to one entry
    // per diagram kind, expand it, and let any RenderFlex overflow
    // surface as a layout exception.
    const withDiagrams = <String, String>{
      'Psalm 119': 'Hebrew alphabet grid, 8 verses per letter',
      'Proverbs 31:10': 'Hebrew alphabet grid, 1 verse per letter',
      'Genesis 1:1': 'numbered original-language words',
      'Matthew 1:17': 'sequence with arrows',
    };

    for (final entry in withDiagrams.entries) {
      testWidgets('${entry.key} (${entry.value}) @ 320px', (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        addTearDown(tester.view.reset);
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(320, 900);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => MainProvider()),
              ChangeNotifierProvider(create: (_) => AppSettings()),
            ],
            child: const MaterialApp(home: BibleTriviaPage()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 400));

        await tester.enterText(find.byType(TextField).first, entry.key);
        await tester.pump(const Duration(milliseconds: 300));

        // The query matches the reference, so exactly the entries on
        // that passage remain; expanding the first is enough to build
        // the diagram.
        final tiles = find.byType(InkWell);
        expect(tiles, findsWidgets,
            reason: 'searching "${entry.key}" matched no trivia entry — '
                'the catalogue reference changed and this test is now '
                'checking nothing');
        await tester.tap(tiles.first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 400));

        expect(tester.takeException(), isNull,
            reason: '${entry.value} overflowed at 320px');

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 250));
      });
    }
  });
}
