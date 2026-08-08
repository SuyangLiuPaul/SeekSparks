/// 2026-08-08 (task #294): the operator strip under the command line.
///
/// The report was "What is the NEAR5? I clicked on it and nothing
/// happens." The button is not dead — the first test here pins that, and
/// pinning it matters because the obvious fix would have been to rewrite
/// working insertion code. What was actually wrong was that the strip
/// carries TWO grammars with nothing saying so, that the `?` card
/// documented only one of them, that no button had a tooltip, and that
/// two buttons really did emit queries the Strong's parser rejects:
///
///   `G25` + ✶ → `G25 * `   which does not parse, so it fell through to
///                          a text search for the literal string
///   `G25` + ! → `G25 !G26` which did not parse either
///
/// Both of those are "nothing happens" as the reader experiences it, and
/// both are pinned below.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/providers/workbench_provider.dart';
import 'package:seeksparks/utils/command_draft.dart';
import 'package:seeksparks/utils/strongs_boolean_search.dart';
import 'package:seeksparks/widgets/command_pane.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _seed = [
  Verse(
      book: 'Genesis',
      chapter: 1,
      verse: 1,
      text: 'In the beginning God created the heaven and the earth.'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('reading the half-typed line', () {
    test('an empty line is in no grammar and asks for nothing', () {
      final d = analyseCommandDraft('   ');
      expect(d.mode, CommandDraftMode.empty);
      expect(d.hint, isNull);
      expect(d.combinersApply, isFalse);
    });

    test("a Strong's number turns the combining operators on", () {
      final d = analyseCommandDraft('G25');
      expect(d.mode, CommandDraftMode.strongs);
      expect(d.combinersApply, isTrue);
      expect(d.hint, isNull);
    });

    test('a leading control character keeps them off', () {
      // `.G25 love` is a TEXT search that happens to mention a number,
      // and AND/OR/NOT would do nothing there.
      final d = analyseCommandDraft('.G25 love');
      expect(d.mode, CommandDraftMode.text);
      expect(d.combinersApply, isFalse);
    });

    test('prose containing the word "and" is not a dangling operator', () {
      // The trap in this analyser: uppercasing every token and looking
      // for AND turns `.love and god` — an ordinary English search — into
      // a nag about Strong's numbers. Only a line made of NOTHING BUT
      // operators is read as a button press.
      for (final line in ['.love and god', 'love and god', '/faith or works']) {
        expect(analyseCommandDraft(line).hint, isNull, reason: line);
      }
    });

    test('a trailing operator says what is still missing', () {
      final d = analyseCommandDraft('G25 NEAR5 ');
      expect(d.hint, CommandDraftHint.needsSecondNumber);
      expect(d.combiner, 'NEAR5');
      expect(describeCommandDraft(d, 'en'), contains('G26'));
      expect(describeCommandDraft(d, 'zh-Hans'), contains('NEAR5'));
    });

    test('an operator with nothing to combine explains the shape', () {
      // Exactly the reported case: tap the button on an empty line.
      for (final line in ['NEAR5 ', 'AND ', 'OR']) {
        final d = analyseCommandDraft(line);
        expect(d.hint, CommandDraftHint.combinerWithoutNumber, reason: line);
        expect(describeCommandDraft(d, 'en'), contains('G25'), reason: line);
      }
    });

    test('a complete window says what the number means', () {
      final d = analyseCommandDraft('G25 NEAR5 G26');
      expect(d.hint, CommandDraftHint.nearWindow);
      expect(d.near?.distance, 5);
      // NEAR5 is a word DISTANCE, so it admits four words in between —
      // i.e. it is BibleWorks' `*4`, not its `*5`. That off-by-one is the
      // reason `*n` was not adopted as an alias, and the hint states it
      // rather than leaving the reader to infer it from a hit count.
      final en = describeCommandDraft(d, 'en')!;
      expect(en, contains('5 words'));
      expect(en, contains('4 words'));
      expect(en, contains('either order'));
    });

    test('the last NEAR on the line is the one the stepper edits', () {
      final d = analyseCommandDraft('G25 NEAR3 G26 NEAR7 G27');
      expect(d.near?.distance, 7);
      expect(withNearDistance('G25 NEAR3 G26 NEAR7 G27', d.near!, 9),
          'G25 NEAR3 G26 NEAR9 G27');
    });

    test('the reader\'s own spelling of the keyword survives an edit', () {
      final d = analyseCommandDraft('G25 within4 G26');
      expect(d.near?.keyword, 'within');
      expect(withNearDistance('G25 within4 G26', d.near!, 6), 'G25 within6 G26');
    });

    test('the distance is clamped to what the parser accepts', () {
      final d = analyseCommandDraft('G25 NEAR5 G26').near!;
      expect(withNearDistance('G25 NEAR5 G26', d, 0), 'G25 NEAR1 G26');
      expect(withNearDistance('G25 NEAR5 G26', d, 999), 'G25 NEAR50 G26');
      // …and the parser really does reject anything outside it, so the
      // clamp is not a guess about someone else's rule.
      expect(parseStrongsBoolean('G25 NEAR51 G26'), isNull);
      expect(parseStrongsBoolean('G25 NEAR50 G26'), isNotNull);
    });
  });

  group('the queries the buttons emit actually parse', () {
    test('a glued ! is the NOT it looks like', () {
      // The `!` button glues deliberately (in a TEXT search `! word` is a
      // stray character the phrase parser drops), so the same keystrokes
      // have to mean NOT here too. Before this they parsed to null and
      // the whole query silently became a text search.
      final glued = parseStrongsBoolean('G25 !G26');
      expect(glued, isNotNull);
      expect(glued!.ops, [StrongsOp.not]);
      expect(glued.terms.map((t) => t.number), ['G25', 'G26']);
      expect(glued.ops, parseStrongsBoolean('G25 NOT G26')!.ops);
    });

    test('a leading ! is still not a term', () {
      expect(parseStrongsBoolean('!G26'), isNull);
    });

    test('the glued wildcard is what the help documents', () {
      expect(parseStrongsBoolean('G25*'), isNotNull);
      expect(parseStrongsBoolean('G25 * '), isNull,
          reason: 'the spaced form the ✶ button used to produce');
    });
  });

  group('the strip on screen', () {
    Future<AppSettings> pump(WidgetTester tester, {String locale = 'en'}) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(500, 1100);
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final mp = MainProvider()..setVerses(_seed);
      final wb = WorkbenchProvider(mainProvider: mp);
      addTearDown(wb.dispose);
      final settings = AppSettings();
      await settings.setLocale(locale);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: mp),
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: wb),
          ],
          child: Builder(
            builder: (context) => MaterialApp(
              theme: workbenchTheme(Theme.of(context)),
              home: const Scaffold(body: CommandPane()),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      return settings;
    }

    String lineOf(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField)).controller!.text;

    testWidgets('the NEAR button is not dead — it inserts', (tester) async {
      // The report said clicking it did nothing. It does not do nothing;
      // this is the regression pin that keeps a future run from
      // "fixing" insertion code that was never broken.
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'G25');
      await tester.pump();
      await tester.tap(find.text('NEAR5'));
      await tester.pump();
      expect(lineOf(tester), 'G25 NEAR5 ');
    });

    testWidgets('the second number does not eat the first', (tester) async {
      // The real "nothing happens", found by driving the deployed build
      // over CDP: tapping a chip blurs the browser's hidden <input>, and
      // putting the focus back makes the browser select ALL of it. The
      // DOM reported selection (0, 10) over "G25 NEAR5 " — so the next
      // character the reader types replaces the whole query and Enter
      // runs a plain `G26` lexicon lookup. Invisible to a widget test
      // unless the echo is replayed through the platform channel, which
      // is what updateEditingValue does here.
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'G25');
      await tester.pump();
      await tester.tap(find.text('NEAR5'));
      await tester.pump();
      tester.testTextInput.updateEditingValue(const TextEditingValue(
        text: 'G25 NEAR5 ',
        selection: TextSelection(baseOffset: 0, extentOffset: 10),
      ));
      await tester.pump();
      final sel = tester
          .widget<TextField>(find.byType(TextField))
          .controller!
          .selection;
      expect(sel.isCollapsed, isTrue);
      expect(sel.baseOffset, 10);
    });

    testWidgets('a selection the reader made is left alone', (tester) async {
      // The guard is spent after one echo and only ever matches the exact
      // line a button wrote, so an ordinary select-all still works.
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'G25 NEAR5 G26');
      await tester.pump();
      tester.testTextInput.updateEditingValue(const TextEditingValue(
        text: 'G25 NEAR5 G26',
        selection: TextSelection(baseOffset: 0, extentOffset: 13),
      ));
      await tester.pump();
      expect(
          tester
              .widget<TextField>(find.byType(TextField))
              .controller!
              .selection
              .isCollapsed,
          isFalse);
    });

    testWidgets('tapping it with nothing to combine explains itself',
        (tester) async {
      await pump(tester);
      await tester.tap(find.text('NEAR5'));
      await tester.pump();
      expect(lineOf(tester), 'NEAR5 ');
      expect(find.textContaining('joins two'), findsOneWidget);
    });

    testWidgets('the ✶ button now makes the query the help documents',
        (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'G25');
      await tester.pump();
      await tester.tap(find.text('*'));
      await tester.pump();
      expect(lineOf(tester), 'G25*');
      expect(parseStrongsBoolean(lineOf(tester)), isNotNull);
    });

    testWidgets('…and still makes a word gap when it stands alone',
        (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), "'faith ");
      await tester.pump();
      await tester.tap(find.text('*'));
      await tester.pump();
      expect(lineOf(tester), "'faith * ");
    });

    testWidgets('the word distance is adjustable, and the button follows',
        (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'G25 NEAR5 G26');
      await tester.pump();
      expect(find.textContaining('Within 5 words'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(lineOf(tester), 'G25 NEAR6 G26');
      expect(find.text('NEAR6'), findsOneWidget,
          reason: 'the button shows the distance it will insert');
      await tester.tap(find.byIcon(Icons.remove));
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      expect(lineOf(tester), 'G25 NEAR4 G26');
    });

    testWidgets('the hint stays out of the way of an ordinary search',
        (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), '.love god');
      await tester.pump();
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.textContaining('joins two'), findsNothing);
    });

    testWidgets("the ? card documents the Strong's grammar too",
        (tester) async {
      // It listed only the text rules, which is how a reader could press
      // `?` to ask what NEAR5 was and be told about `.love god`.
      await pump(tester);
      await tester.tap(find.text('?'));
      await tester.pump();
      expect(find.text(uiStrings['cmdSyntaxSectionStrongs']!['en']!),
          findsOneWidget);
      expect(find.textContaining('G25 NEAR5 G26 —'), findsOneWidget);
      expect(find.textContaining('G25✶ —'), findsOneWidget);
    });

    testWidgets('every operator button carries a tooltip', (tester) async {
      await pump(tester);
      final tips = tester
          .widgetList<Tooltip>(find.byType(Tooltip))
          .map((t) => t.message)
          .toList();
      // Ten buttons plus the field's own search icon; the strip had none
      // of these before, which is how a word-shaped token like NEAR5
      // could sit on it unexplained.
      expect(tips.where((m) => m != null && m.isNotEmpty).length,
          greaterThanOrEqualTo(10));
    });

    testWidgets('the hint speaks the reader\'s language', (tester) async {
      await pump(tester, locale: 'zh-Hant');
      await tester.enterText(find.byType(TextField), 'G25 NEAR5 G26');
      await tester.pump();
      expect(find.textContaining('不分先後'), findsOneWidget);
    });
  });
}
