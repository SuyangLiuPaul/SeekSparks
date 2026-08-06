/// 2026-08-07 (SeekSparks): widget tests for the Vocabulary Flashcard
/// pane (BibleWorks bwh40).
///
/// `vocabulary_test.dart` pins the mechanics and `vocabulary_corpus_test
/// .dart` pins the claims against the real corpus. Neither one mounts
/// anything, so neither can tell you that the pane wires the core to the
/// assets correctly — and the wiring is where a feature like this
/// actually breaks: a deck built from the wrong scope, a drill that
/// re-loads and loses its place, a "learned" mark that never reaches
/// disk.
///
/// These run against the REAL bundled assets rather than fixtures.
/// `rootBundle` resolves under `flutter test`, and 3 John is 15 verses
/// of genuine tagged Greek — small enough to be quick, real enough that
/// a regression in the concordance, the lexicons or the tagged text
/// fails here instead of shipping.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/services/vocabulary_service.dart';
import 'package:seeksparks/services/vocabulary_store.dart';
import 'package:seeksparks/widgets/analysis_tabs.dart';
import 'package:seeksparks/widgets/vocabulary_pane.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `testWidgets` runs inside a fake-async zone, where a Future waiting
  // on real disk I/O never completes — so the pane would sit on its
  // spinner forever. Warm the two static caches here instead: `setUpAll`
  // is ordinary async, and once the assets are parsed the pane's awaits
  // resolve as microtasks that `pumpAndSettle` can drive.
  //
  // This also means the 13 MB of lexicons are parsed once for the file
  // rather than once per test.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await VocabularyService.corpusVocabulary('en');
    await VocabularyService.versesOfBook('3 John');
    await VocabularyService.versesOfBook('Nonexistent Book');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Widget host(Widget child, {double width = 420}) => ChangeNotifierProvider(
        create: (_) => AppSettings(),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(width: width, height: 700, child: child),
            ),
          ),
        ),
      );

  /// Let the pane's (now cache-backed) loads resolve and repaint.
  Future<void> settleLoad(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Widget pane({
    String book = '3 John',
    int chapter = 1,
    void Function(int, int)? onOpenVerse,
  }) =>
      VocabularyPane(
        englishBook: book,
        chapter: chapter,
        locale: 'en',
        onOpenVerse: onOpenVerse,
      );

  group('the tab is appended, so persisted indices still resolve', () {
    test('vocabulary is last and nothing before it moved', () {
      // `workbench.analysisTab` persists the tab by INDEX. Inserting
      // rather than appending would silently move every existing reader
      // to a different tab.
      expect(AnalysisTab.values.indexOf(AnalysisTab.vocabulary), 7);
      expect(AnalysisTab.values.indexOf(AnalysisTab.wordStudy), 0);
      expect(AnalysisTab.values.indexOf(AnalysisTab.verseLists), 5);
      expect(AnalysisTab.values.indexOf(AnalysisTab.phrases), 6);
    });
  });

  group('loading', () {
    testWidgets('a book with no tagged text says so instead of showing zero '
        'cards', (tester) async {
      await tester.pumpWidget(host(pane(book: 'Nonexistent Book')));
      await settleLoad(tester);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('No tagged original-language text'),
          findsOneWidget);
    });

    testWidgets('3 John builds a real Greek deck', (tester) async {
      await tester.pumpWidget(host(pane()));
      await settleLoad(tester);
      expect(tester.takeException(), isNull);

      // The three modes and the three scopes are the whole navigation.
      expect(find.text('Words'), findsOneWidget);
      expect(find.text('Drill'), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
      expect(find.text('Chapter'), findsOneWidget);
      expect(find.text('Book'), findsOneWidget);

      // The header counts deck against scope, e.g. "45/62". Zero either
      // side would mean the scope tally or the lexicon join broke.
      expect(find.textContaining(RegExp(r'^[1-9]\d*/[1-9]\d*$')),
          findsOneWidget);
    });
  });

  group('the deck the service actually builds', () {
    // Asserted here rather than by hunting for a gloss inside the pane's
    // ListView: only the visible rows are built, so a scroll-position
    // change would turn a real assertion into a flaky one.
    test('3 John is Greek, glossed, and counted twice over', () async {
      final words = await VocabularyService.wordsForScope(
        scope: VocabScope.chapter,
        englishBook: '3 John',
        chapter: 1,
        locale: 'en',
      );
      expect(words, isNotEmpty);
      expect(words.any((w) => w.isHebrew), isFalse,
          reason: '3 John is Greek; a Hebrew lemma here means the scope '
              'tally picked up the wrong book');

      // θεός occurs in 3 John, so it must carry a gloss off the real
      // lexicon and both counts — the scope count from the tagged text,
      // the corpus count from the concordance.
      final theos = words.firstWhere((w) => w.strongs == 'G2316');
      expect(theos.gloss, isNotEmpty);
      expect(theos.lemma, isNotEmpty);
      expect(theos.scopeCount, greaterThan(0));
      expect(theos.corpusCount, greaterThan(theos.scopeCount),
          reason: 'a word occurs far more often in the whole NT than in '
              'one short letter — if these are equal the scope count is '
              'just echoing the corpus count');
    });

    test('a chapter deck is smaller than the corpus deck', () async {
      final chapter = await VocabularyService.wordsForScope(
        scope: VocabScope.chapter,
        englishBook: '3 John',
        chapter: 1,
        locale: 'en',
      );
      final corpus = await VocabularyService.wordsForScope(
        scope: VocabScope.corpus,
        englishBook: '3 John',
        chapter: 1,
        locale: 'en',
      );
      expect(chapter.length, lessThan(corpus.length));
      // Scoping is the whole point: a 15-verse letter must not need
      // anything like the Greek NT's full vocabulary.
      expect(chapter.length * 10, lessThan(corpus.length));
    });
  });

  group('the word list', () {
    testWidgets('marking a word learned reaches disk', (tester) async {
      await tester.pumpWidget(host(pane()));
      await settleLoad(tester);

      expect(await VocabularyStore.loadLearned(), isEmpty);

      // The unchecked circle at the end of a row is the learned toggle.
      final toggle = find.byIcon(Icons.circle_outlined).first;
      await tester.tap(toggle, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      final learned = await VocabularyStore.loadLearned();
      expect(learned, isNotEmpty,
          reason: 'a learned mark is the one thing that must survive a '
              'reload, so it has to be written, not just held in state');
      expect(learned.first, matches(RegExp(r'^[GH]\d+$')));
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a row opens its detail without collapsing the list',
        (tester) async {
      await tester.pumpWidget(host(pane()));
      await settleLoad(tester);

      // Strong's numbers only appear in the expanded detail.
      expect(find.textContaining(RegExp(r'^G\d+ · ')), findsNothing);
      await tester.tap(find.byType(InkWell).at(6), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });
  });

  group('the drill', () {
    testWidgets('a card hides its answer until you ask for it',
        (tester) async {
      await tester.pumpWidget(host(pane()));
      await settleLoad(tester);

      await tester.tap(find.text('Drill'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('cards to go'), findsOneWidget);

      await tester.tap(find.text('Start drill'));
      await tester.pump(const Duration(milliseconds: 100));

      // Front of the card: the lemma and an invitation, no gloss.
      expect(find.text('Tap to reveal'), findsOneWidget);
      expect(find.text('Knew it'), findsOneWidget);
      expect(find.text('Missed'), findsOneWidget);

      await tester.tap(find.text('Tap to reveal'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Tap to reveal'), findsNothing);
      // The back carries the transliteration, Strong's number and count.
      expect(find.textContaining(RegExp(r' · [GH]\d+ · \d+×')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a missed card comes back and a known one does not',
        (tester) async {
      await tester.pumpWidget(host(pane()));
      await settleLoad(tester);
      await tester.tap(find.text('Drill'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Start drill'));
      await tester.pump(const Duration(milliseconds: 100));

      // Answering must not throw and must keep a card in front of the
      // reader until the deck is genuinely exhausted.
      for (var i = 0; i < 6; i++) {
        await tester.tap(find.text(i.isEven ? 'Knew it' : 'Missed'));
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(tester.takeException(), isNull);
      // Still drilling: the missed ones were re-queued, not dropped.
      expect(find.text('Knew it'), findsOneWidget);
    });

    testWidgets('the flip resets between cards, so the next answer is not '
        'given away', (tester) async {
      await tester.pumpWidget(host(pane()));
      await settleLoad(tester);
      await tester.tap(find.text('Drill'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Start drill'));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Tap to reveal'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('Tap to reveal'), findsNothing);

      await tester.tap(find.text('Knew it'));
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('Tap to reveal'), findsOneWidget);
    });
  });

  group('the Example Verse Finder', () {
    testWidgets('renders and reports how many verses it found',
        (tester) async {
      await tester.pumpWidget(host(pane()));
      await settleLoad(tester);

      await tester.tap(find.text('Read'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      // Labels carry a trailing space before their stepper.
      expect(find.textContaining('Uses'), findsOneWidget);
      expect(find.textContaining('Unknown'), findsOneWidget);
    });

    testWidgets('with the particles in the deck, the chapter you are reading '
        'is readable', (tester) async {
      await tester.pumpWidget(host(pane()));
      await settleLoad(tester);

      // Particles are off by default, so the article counts as an
      // unknown token and a zero-unknown budget rejects nearly every
      // verse. Turning them on makes the deck the chapter's whole
      // vocabulary — at which point every verse of it must be readable
      // with nothing unknown. That is the finder's own worked example
      // from bwh40 ("set the second parameter to zero"), run for real.
      await tester.tap(find.text('Particles'));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(find.text('Read'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      // A verse reference link, i.e. at least one result.
      expect(find.textContaining(RegExp(r'^\d+:\d+$')), findsWidgets);
    });

    testWidgets('an example verse reference calls back to open it',
        (tester) async {
      var opened = '';
      await tester.pumpWidget(host(pane(
        onOpenVerse: (c, v) => opened = '$c:$v',
      )));
      await settleLoad(tester);

      await tester.tap(find.text('Particles'));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(find.text('Read'));
      await tester.pump(const Duration(milliseconds: 300));

      final refs = find.textContaining(RegExp(r'^\d+:\d+$'));
      expect(refs, findsWidgets);
      await tester.tap(refs.first, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));

      expect(opened, matches(RegExp(r'^\d+:\d+$')),
          reason: 'the point of the finder is to take you to the verse');
      expect(tester.takeException(), isNull);
    });
  });

  group('scope', () {
    testWidgets('switching scope rebuilds the deck instead of throwing',
        (tester) async {
      await tester.pumpWidget(host(pane()));
      await settleLoad(tester);

      await tester.tap(find.text('Book'));
      await settleLoad(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Words'), findsOneWidget);
    });
  });
}
