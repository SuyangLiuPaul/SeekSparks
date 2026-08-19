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

  group('runSearch — romanised lemma offer (asset-backed)', () {
    // The offer is measured after the page is on screen and is not
    // awaited, so the test waits for it the way the reader does.
    Future<void> settle(WorkbenchProvider wb) async {
      for (var i = 0; i < 400 && wb.lemmaOffer == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    MainProvider mpWith(String text) => MainProvider()
      ..setVerses([Verse(book: 'Genesis', chapter: 1, verse: 1, text: text)]);

    test('a Greek word the text does not use reaches its Strong’s number',
        () async {
      final wb = WorkbenchProvider(mainProvider: makeMp());
      await wb.runSearch('agape');
      expect(wb.textResults, isEmpty);
      await settle(wb);
      final offer = wb.lemmaOffer;
      expect(offer, isNotNull);
      expect(offer!.query, 'agape');
      expect(offer.hits.first.candidate.strongs, 'G26');
      // A count the app has actually run, in verses, not the lexicon's
      // occurrence total: the offer is a query the reader can take.
      expect(offer.hits.first.verses, greaterThan(0));
      wb.dispose();
    });

    test('a word the text DOES use gets no offer, however it resolves',
        () async {
      // `dove` folds onto H1679 dôbâh, which has nothing to do with the
      // bird. Offering it beside an English verse containing the word
      // would be a false etymology, so the gate is the word.
      final wb = WorkbenchProvider(mainProvider: mpWith('a dove and a raven'));
      await wb.runSearch('dove');
      expect(wb.textResults, hasLength(1));
      await settle(wb);
      expect(wb.lemmaOffer, isNull);
      wb.dispose();
    });

    test('a substring match is not use — the offer survives it', () async {
      // The KJV writes Jehovahshalom as one word, so a plain search for
      // `shalom` returns a verse. No verse USES the word, which is why
      // the gate reads it as a word rather than trusting the page.
      final wb =
          WorkbenchProvider(mainProvider: mpWith('called it Jehovahshalom'));
      await wb.runSearch('shalom');
      expect(wb.textResults, hasLength(1));
      await settle(wb);
      expect(wb.lemmaOffer?.hits.first.candidate.strongs, 'H7965');
      wb.dispose();
    });

    test('a scope does not make a word the edition uses look absent',
        () async {
      // The gate reads the whole edition, never the reader's scope.
      // `wen` is a KJV word (Leviticus 22:22) and folds onto H1121 bên,
      // "a son"; a Genesis-scoped probe would call it absent and offer
      // that, which is a false etymology dressed as a finding. 152 of
      // the KJV's 1,814 resolving words behaved this way under a
      // Genesis limit before the gate stopped applying the limit.
      final wb = WorkbenchProvider(
        mainProvider: MainProvider()
          ..setVerses(const [
            Verse(
                book: 'Genesis',
                chapter: 1,
                verse: 1,
                text: 'In the beginning'),
            Verse(
                book: 'Leviticus',
                chapter: 22,
                verse: 22,
                text: 'or scurvy, or scabbed, or hath a wen'),
          ]),
      );
      await wb.setSearchLimit({'Genesis-1-1'}, 'test');
      await wb.runSearch('wen');
      expect(wb.textResults, isEmpty, reason: 'the only "wen" is out of scope');
      await settle(wb);
      expect(wb.lemmaOffer, isNull);
      wb.dispose();
    });

    test('a new search clears the previous offer', () async {
      final wb = WorkbenchProvider(mainProvider: makeMp());
      await wb.runSearch('agape');
      await settle(wb);
      expect(wb.lemmaOffer, isNotNull);
      await wb.runSearch('god');
      expect(wb.lemmaOffer, isNull);
      wb.dispose();
    });
  });
}
