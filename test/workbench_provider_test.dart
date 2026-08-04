/// 2026-08-04 (Workbench): unit tests for `WorkbenchProvider` — the
/// state glue of the three-pane workspace. Covers the
/// selection→analysis mirroring (the "tap a verse, analysis follows"
/// wiring), focusVerse, the ref→verse lookup, and the command-line
/// search paths (text scan in-memory; Strong's paths asset-backed,
/// same pattern as cross_references_test.dart).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/providers/workbench_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const seed = [
    Verse(
        book: 'Genesis',
        chapter: 1,
        verse: 1,
        text: 'In the beginning God created the heavens'),
    Verse(book: 'Genesis', chapter: 1, verse: 2, text: 'The earth was formless'),
    Verse(book: 'John', chapter: 3, verse: 16, text: 'For God so loved the world'),
  ];

  MainProvider makeMp() {
    final mp = MainProvider();
    mp.setVerses(seed);
    return mp;
  }

  group('selection → analysis mirroring', () {
    test('selecting a verse in the reader updates analysisVerses', () {
      final wb = WorkbenchProvider(mainProvider: makeMp());
      expect(wb.analysisVerses, isEmpty);

      wb.mainProvider.toggleVerse(verse: seed[0]);

      expect(wb.analysisVerses.map((v) => v.id), [seed[0].id]);
      wb.dispose();
    });

    test('unrelated MainProvider notifications do NOT churn analysisVerses',
        () {
      final wb = WorkbenchProvider(mainProvider: makeMp());
      wb.mainProvider.toggleVerse(verse: seed[0]);
      final before = wb.analysisVerses;

      // Notifies listeners but leaves the selection untouched — the
      // O(k) selection-ids snapshot must short-circuit the sync.
      wb.mainProvider.updateCurrentVerse(verse: seed[1]);

      expect(identical(wb.analysisVerses, before), isTrue);
      wb.dispose();
    });

    test('pre-existing selection is picked up at construction', () {
      final mp = makeMp();
      mp.toggleVerse(verse: seed[1]);
      final wb = WorkbenchProvider(mainProvider: mp);
      expect(wb.analysisVerses.single.id, seed[1].id);
      wb.dispose();
    });
  });

  group('focusVerse / clearAnalysis', () {
    test('focusVerse makes the verse the ONLY reader selection', () {
      final wb = WorkbenchProvider(mainProvider: makeMp());
      wb.mainProvider.toggleVerse(verse: seed[0]);
      wb.mainProvider.toggleVerse(verse: seed[1]);

      wb.focusVerse(seed[2]);

      expect(wb.mainProvider.selectedIds, {seed[2].id});
      expect(wb.analysisVerses.single.id, seed[2].id);
      wb.dispose();
    });

    test('clearAnalysis empties the analysis pane', () {
      final wb = WorkbenchProvider(mainProvider: makeMp());
      wb.focusVerse(seed[0]);
      expect(wb.analysisVerses, isNotEmpty);

      wb.clearAnalysis();

      expect(wb.analysisVerses, isEmpty);
      wb.dispose();
    });
  });

  group('verseByRef', () {
    test('maps EnglishBook-chapter-verse to the corpus verse', () {
      final wb = WorkbenchProvider(mainProvider: makeMp());
      final v = wb.verseByRef['John-3-16'];
      expect(v, isNotNull);
      expect(v!.book, 'John');
      expect(v.verse, 16);
      wb.dispose();
    });
  });

  group('runSearch — text path', () {
    test('plain query scans the corpus (case/space-normalized)', () async {
      final wb = WorkbenchProvider(mainProvider: makeMp());
      await wb.runSearch('god');
      expect(wb.searchPerformed, isTrue);
      expect(wb.searching, isFalse);
      expect(wb.strongsRefs, isNull);
      // Genesis 1:1 ('God') + John 3:16 ('God').
      expect(wb.textResults, hasLength(2));
      wb.dispose();
    });

    test('empty query clears the result state', () async {
      final wb = WorkbenchProvider(mainProvider: makeMp());
      await wb.runSearch('god');
      await wb.runSearch('   ');
      expect(wb.searchPerformed, isFalse);
      expect(wb.textResults, isEmpty);
      wb.dispose();
    });
  });

  group('runSearch — Strong\u2019s paths (asset-backed)', () {
    test('bare Strong\u2019s number returns its concordance refs', () async {
      final wb = WorkbenchProvider(mainProvider: makeMp());
      await wb.runSearch('G25');
      expect(wb.strongsQueryLabel, 'G25');
      expect(wb.strongsRefs, isNotNull);
      expect(wb.strongsRefs!, isNotEmpty);
      expect(wb.textResults, isEmpty);
      wb.dispose();
    });

    test('structured AND query narrows via the concordance', () async {
      final wb = WorkbenchProvider(mainProvider: makeMp());
      await wb.runSearch('G25 AND G26');
      final refs = wb.strongsRefs!;
      expect(refs, isNotEmpty);
      // README documents 1 John 4:7 for the stricter NEAR5 query, so
      // the looser AND must contain it too.
      expect(
        refs.any((r) =>
            r.englishBook == '1 John' && r.chapter == 4 && r.verse == 7),
        isTrue,
      );
      // Canonical order: Matthew precedes 1 John.
      final first = refs.first;
      expect(first.englishBook, isNot('1 John'));
      wb.dispose();
    });
  });
}
