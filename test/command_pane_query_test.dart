/// 2026-08-07 (SeekSparks): the command-line grammar as the reader meets
/// it — routing in `WorkbenchProvider`, and the pane that shows it.
///
/// `command_query_test.dart` proves the engine answers correctly. These
/// prove the answer reaches the screen, and — the part that would break
/// silently — that adding a grammar did not take anything away. A reader
/// who has never heard of a control character must still get the
/// substring search, the reference jump and the Strong's query they had
/// before, and the only thing standing between them and that is the
/// order of the branches in `runSearch`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/providers/workbench_provider.dart';
import 'package:seeksparks/utils/command_query.dart';
import 'package:seeksparks/utils/romanised_lemma.dart';
import 'package:seeksparks/utils/search_highlight.dart';
import 'package:seeksparks/utils/vocabulary.dart';
import 'package:seeksparks/widgets/command_pane.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _seed = [
  Verse(
      book: 'Genesis',
      chapter: 1,
      verse: 1,
      text: 'In the beginning God created the heaven and the earth.'),
  Verse(
      book: 'Genesis',
      chapter: 1,
      verse: 2,
      text: 'And the earth was without form, and void.'),
  Verse(
      book: 'John',
      chapter: 3,
      verse: 16,
      text: 'For God so loved the world, that he gave his only begotten Son.'),
  Verse(
      book: 'John',
      chapter: 3,
      verse: 17,
      text: 'For God sent not his Son into the world to condemn the world.'),
];

MainProvider _mp() => MainProvider()..setVerses(_seed);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('runSearch routes the grammar without taking anything away', () {
    test('a control character runs the command engine', () async {
      final wb = WorkbenchProvider(mainProvider: _mp());
      await wb.runSearch('.god world');
      expect(wb.commandQuery, isNotNull);
      expect(wb.commandIssue, isNull);
      expect([for (final v in wb.textResults) '${v.book} ${v.verse}'],
          ['John 16', 'John 17']);
      wb.dispose();
    });

    test('a phrase is not the same search as an AND', () async {
      final wb = WorkbenchProvider(mainProvider: _mp());
      await wb.runSearch("'in the beginning");
      expect(wb.textResults, hasLength(1));
      expect(wb.textResults.single.book, 'Genesis');
      wb.dispose();
    });

    test('plain text still takes the substring path it always took',
        () async {
      final wb = WorkbenchProvider(mainProvider: _mp());
      await wb.runSearch('god');
      expect(wb.commandQuery, isNull,
          reason: 'no control character, so not a command');
      expect(wb.textResults, hasLength(3));
      wb.dispose();
    });

    test('a Strong’s expression is not stolen by the grammar', () async {
      // The dangerous regression: `G25 AND G26` has no leading control
      // character, so `parseCommandQuery` must decline it and leave the
      // Strong's branch to run. Checked without touching the asset by
      // asserting the routing rather than the results.
      expect(parseCommandQuery('G25 AND G26').isCommand, isFalse);
      expect(parseCommandQuery('G25').isCommand, isFalse);
      expect(parseCommandQuery('Gen 1:1').isCommand, isFalse);
      expect(parseCommandQuery('kjv').isCommand, isFalse);
      expect(parseCommandQuery('约翰福音 3:16').isCommand,
          isFalse);
    });

    test('an unsupported operator is reported, not half-run', () async {
      final wb = WorkbenchProvider(mainProvider: _mp());
      await wb.runSearch('~And God said');
      expect(wb.commandIssue, CommandIssue.regexUnsupported);
      expect(wb.textResults, isEmpty);
      wb.dispose();
    });

    test('a parenthesised line without operators is still plain text',
        () async {
      // `(god OR world)` used to be refused as an unsupported compound.
      // It is not compound-shaped — no group opens with a control
      // character — so it falls through to the substring search a reader
      // who typed literal parentheses meant.
      final wb = WorkbenchProvider(mainProvider: _mp());
      await wb.runSearch('(god OR world)');
      expect(wb.commandIssue, isNull);
      expect(wb.compoundQuery, isNull);
      wb.dispose();
    });

    test('a compound search runs, and lists the last group', () async {
      // Genesis 1:2 holds "earth" and no "beginning"; it is listed
      // because it sits next to a verse that matched the first group.
      // That is the whole feature reaching the screen.
      final wb = WorkbenchProvider(mainProvider: _mp());
      await wb.runSearch('(.beginning).1(.earth)');
      expect(wb.compoundQuery, isNotNull);
      expect(wb.commandQuery, isNull, reason: 'set instead of, never beside');
      expect(wb.commandIssue, isNull);
      expect(wb.compoundGroupCounts, [1, 2]);
      expect([for (final v in wb.textResults) '${v.book} ${v.verse}'],
          ['Genesis 1', 'Genesis 2']);
      // A compound has no looser reading to offer.
      expect(wb.broadening, isNull);
      wb.dispose();
    });

    test("a compound's window stops at a book boundary", () async {
      // Genesis 1:2 and John 3:16 are adjacent in the corpus list and in
      // different books, so `.1` must not join them.
      final wb = WorkbenchProvider(mainProvider: _mp());
      await wb.runSearch('(.void).1(.loved)');
      expect(wb.compoundQuery, isNotNull);
      expect(wb.compoundGroupCounts, [1, 1],
          reason: 'both groups matched; only the join rejects them');
      expect(wb.textResults, isEmpty);
      wb.dispose();
    });

    test('a malformed compound is named, not half-run', () async {
      final wb = WorkbenchProvider(mainProvider: _mp());
      await wb.runSearch('(.god)(.world)');
      expect(wb.commandIssue, CommandIssue.compoundSeparator);
      expect(wb.compoundQuery, isNull);
      expect(wb.textResults, isEmpty);
      wb.dispose();
    });

    test('a new search clears the previous parse', () async {
      final wb = WorkbenchProvider(mainProvider: _mp());
      await wb.runSearch('.god');
      expect(wb.commandQuery, isNotNull);
      await wb.runSearch('god');
      expect(wb.commandQuery, isNull);
      wb.dispose();
    });

    test('the search limit applies to command results too', () async {
      // A limit that silently stopped applying to one kind of query
      // would be worse than no limit at all.
      final wb = WorkbenchProvider(mainProvider: _mp());
      await wb.setSearchLimit({'John-3-16'}, 'test');
      await wb.runSearch('.god');
      expect([for (final v in wb.textResults) '${v.book} ${v.verse}'],
          ['John 16']);
      wb.dispose();
    });
  });

  group('the hits are still marked in the text', () {
    test('a command query marks its terms, not its punctuation', () {
      final h = highlightsForQuery('.faith* god');
      expect(h.textTerms, ['faith', 'god'],
          reason: 'the wildcard is marked by its longest plain run');
    });

    test('an excluded term is not marked', () {
      expect(highlightsForQuery('.god !world').textTerms, ['god']);
    });

    test('plain text is unchanged', () {
      expect(highlightsForQuery('let there be').textTerms,
          ['let', 'there', 'be']);
    });
  });

  group('the pane', () {
    Future<WorkbenchProvider> pump(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(500, 900);
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final wb = WorkbenchProvider(mainProvider: _mp());
      addTearDown(wb.dispose);
      // AppSettings defaults to zh-Hans; these assertions read the
      // English strings, so say so rather than testing whichever locale
      // the harness happens to boot in.
      final settings = AppSettings();
      await settings.setLocale('en');
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: wb.mainProvider),
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: wb),
          ],
          child: Builder(builder: (context) {
            return MaterialApp(
              theme: workbenchTheme(Theme.of(context)),
              home: const Scaffold(body: CommandPane()),
            );
          }),
        ),
      );
      // setLocale schedules a save debounce; drain it or the widget
      // binding reports a pending timer at the end of every test.
      await tester.pump(const Duration(seconds: 1));
      return wb;
    }

    Future<void> submit(WidgetTester tester, String query) async {
      await tester.enterText(find.byType(TextField), query);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump();
    }

    testWidgets('the header says what the query was taken to mean',
        (tester) async {
      await pump(tester);
      await submit(tester, '.god world');
      // Not "«.god world» — 2 verses": the echo is the whole point, and
      // a reader who cannot see how the punctuation was read cannot
      // tell a wrong query from a wrong Bible.
      expect(find.textContaining('All of: god, world'), findsOneWidget);
      expect(find.textContaining('2'), findsWidgets);
    });

    testWidgets('a refused query explains itself', (tester) async {
      await pump(tester);
      await submit(tester, '~beginn.*');
      expect(
          find.textContaining(
              describeCommandIssue(CommandIssue.regexUnsupported, 'en')!),
          findsOneWidget);
    });

    testWidgets('a phrase that misses offers the AND that would not',
        (tester) async {
      await pump(tester);
      await submit(tester, "'god beginning");
      expect(find.textContaining('.god beginning'), findsOneWidget);
    });

    testWidgets('a plain multi-word search offers it too', (tester) async {
      // This one is the long-standing papercut: the substring scan
      // strips spaces, so "god world" could never have matched anything
      // and said only "No results found".
      await pump(tester);
      await submit(tester, 'god world');
      expect(find.textContaining('.god world'), findsOneWidget);
    });

    testWidgets('the syntax card is one tap away and starts closed',
        (tester) async {
      await pump(tester);
      expect(find.textContaining('Command line syntax'), findsNothing);
      await tester.tap(find.text('?'));
      await tester.pump();
      expect(find.textContaining('Command line syntax'), findsOneWidget);
      // The EXPLANATION follows the interface, which here is English.
      // The example beside it does not: this harness reads the default
      // Chinese edition, and since task #299 the card's examples are
      // written in the language of the text being searched, because
      // tapping `.paul silas;10` while reading 和合本 fills the line with
      // a query that cannot match. See command_operator_strip_test.dart.
      expect(find.textContaining('within 10 verses of each other'),
          findsOneWidget);
      expect(find.textContaining('.保罗 西拉;10'), findsOneWidget);
      // The compound row, on the same terms: Chinese example, English
      // explanation. Its absence is how the feature would ship unfindable.
      expect(find.textContaining('two searches, 15 verses apart'),
          findsOneWidget);
      expect(find.textContaining('(.恩典 行为).15(/耶稣 基督)'), findsOneWidget);
    });

    testWidgets('a control chip replaces the control, it does not stack',
        (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'god world');
      await tester.tap(find.text('.'));
      await tester.pump();
      expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '.god world');
      await tester.tap(find.text('/'));
      await tester.pump();
      expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '/god world',
          reason: 'switching the question, not burying a slash in it');
    });

    testWidgets('! glues to the word it negates', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), '.god');
      await tester.tap(find.text('!'));
      await tester.pump();
      final text =
          tester.widget<TextField>(find.byType(TextField)).controller!.text;
      expect(text, '.god !');
      expect(text.endsWith('! '), isFalse,
          reason: 'a trailing space would silently drop the negation');
    });

    testWidgets('Esc clears the line and the results', (tester) async {
      final wb = await pump(tester);
      await submit(tester, '.god');
      expect(wb.textResults, isNotEmpty);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty);
      expect(wb.searchPerformed, isFalse);
    });

    testWidgets('the arrows walk the history', (tester) async {
      await pump(tester);
      await submit(tester, '.god');
      await submit(tester, "'in the beginning");
      await tester.enterText(find.byType(TextField), '');

      String line() =>
          tester.widget<TextField>(find.byType(TextField)).controller!.text;

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(line(), "'in the beginning");

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(line(), '.god');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(line(), "'in the beginning");

      // Down past the newest entry leaves an empty line rather than
      // sticking on the last command.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(line(), isEmpty);
    });

    /// The romanised offer is measured from assets a beat after the
    /// search, so these set it directly: what is under test is that the
    /// pane shows it in BOTH result branches, and that a tap runs the
    /// number. Whether it is measured correctly is
    /// `workbench_provider_test.dart` and the two corpus files.
    LemmaOffer offer(String query, String strongs) => LemmaOffer(
          query: query,
          hits: [
            LemmaHit(
              candidate: LemmaCandidate(
                word: VocabWord(
                  strongs: strongs,
                  lemma: 'ἀγάπη',
                  translit: 'agápē',
                  gloss: 'love',
                  corpusCount: 116,
                ),
                exact: true,
              ),
              verses: 110,
            ),
          ],
        );

    testWidgets('a word the text does not use offers the original',
        (tester) async {
      final wb = await pump(tester);
      await submit(tester, 'agape');
      expect(wb.textResults, isEmpty);
      wb.lemmaOffer = offer('agape', 'G26');
      wb.notifyListeners();
      await tester.pump();
      expect(find.textContaining('No verse uses the word'), findsOneWidget);
      // Not just `G26`: the hint line under the field says
      // "or Strong's: G25 AND G26", and a finder that matched it would
      // pass with the offer missing.
      expect(find.textContaining('G26 · ἀγάπη'), findsOneWidget);

      await tester.tap(find.textContaining('G26 · ἀγάπη'));
      await tester.pump();
      await tester.pump();
      expect(wb.lastQuery, 'G26');
    });

    testWidgets('a substring hit does not hide the offer', (tester) async {
      // The gate is the word, so a search can put verses on screen AND
      // be offered the original — `shalom` matching Jehovahshalom is the
      // real case. The pane used to render the offer only in the empty
      // branch, which would have silently dropped it.
      final wb = await pump(tester);
      await submit(tester, 'god');
      expect(wb.textResults, isNotEmpty);
      wb.lemmaOffer = offer('shalom', 'H7965');
      wb.notifyListeners();
      await tester.pump();
      // And the lead is the one written for rows above it: a count of
      // 3 over "no verse uses the word" reads as a contradiction, so
      // beside results it explains the rows first.
      expect(find.textContaining('inside other words'), findsOneWidget);
      expect(find.textContaining('No verse uses the word'), findsNothing);
      expect(find.textContaining('H7965'), findsOneWidget);
    });
  });
}
