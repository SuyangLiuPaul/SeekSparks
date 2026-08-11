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
import 'package:seeksparks/utils/command_examples.dart';
import 'package:seeksparks/utils/command_query.dart' show parseCommandQuery;
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

  // 2026-08-11 (task #299): the lines that RAN but ran as something else.
  //
  // Round one dimmed the combining buttons until a Strong's number was
  // present and explained a dangling operator. It said nothing about a
  // line that already carries one, and there is a whole family of those:
  // `yahweh NEAR5 god` was reported from the Recent list, where it had
  // been filed as a successful search. It is not one. It parses as
  // nothing at all, so `runSearch` falls through to `SearchService`,
  // which strips the whitespace and looks for the literal substring
  // "yahwehnear5god". Zero hits, no error, and an invitation in Recents
  // to run it again tomorrow.
  //
  // The fix does not enumerate the failing shapes — that is how
  // `G25 NEAR G26` and `G25 AND god` were both missed the first time.
  // It asks the SHARED PARSER whether the line will run, and every case
  // below is a line the parser refuses.
  group('lines that silently become a literal text scan', () {
    test('an operator between WORDS is caught, not run', () {
      final d = analyseCommandDraft('yahweh NEAR5 god');
      expect(d.hint, CommandDraftHint.combinerOnWords);
      expect(d.combiner, 'NEAR5');
      expect(d.willNotRunAsWritten, isTrue);
      // The parser really does refuse it, which is why it reached the
      // literal scan.
      expect(parseStrongsBoolean('yahweh NEAR5 god'), isNull);
    });

    test('…and is offered the word grammar that means the same thing', () {
      // NEAR5 is a word DISTANCE and admits four words in between
      // (`strongs_proximity.dart` tests `(a - b).abs() <= n`), while `*n`
      // in a phrase is the number of words BETWEEN (`GapElement(0, n)`).
      // So the number drops by one on the way across. The brief asked
      // for `*5`; `*5` would be a wider search than the reader asked for.
      expect(analyseCommandDraft('yahweh NEAR5 god').suggestion,
          "'yahweh *4 god");
      expect(analyseCommandDraft('yahweh AND god').suggestion, '.yahweh god');
      expect(analyseCommandDraft('faith OR works').suggestion, '/faith works');
      expect(analyseCommandDraft('jesus NOT christ').suggestion,
          '.jesus !christ');
    });

    test('the offered rewrite is a query the app can actually run', () {
      for (final line in [
        'yahweh NEAR5 god',
        'yahweh AND god',
        'faith OR works',
        'jesus NOT christ',
      ]) {
        final fix = analyseCommandDraft(line).suggestion!;
        expect(parseCommandQuery(fix), isNotNull, reason: '$line → $fix');
      }
    });

    test('a bare NEAR takes the distance from the strip', () {
      final d = analyseCommandDraft('yahweh NEAR god', nearDistance: 3);
      expect(d.hint, CommandDraftHint.combinerOnWords);
      expect(d.suggestion, "'yahweh *2 god");
    });

    test('mixed operators are refused rather than guessed at', () {
      // `a AND b OR c` has a precedence the text grammar does not
      // express. Inventing one would answer a different question and say
      // nothing about having done so.
      final d = analyseCommandDraft('a AND b OR c');
      expect(d.hint, CommandDraftHint.combinerOnWords);
      expect(d.suggestion, isNull);
      expect(describeCommandDraft(d, 'en'), contains('literal'));
    });

    test('lowercase operators stay ordinary English', () {
      // "abide near god" and "faith and works" are searches, not broken
      // queries, and putting an error under them would be worse than the
      // bug being fixed. Only the spelling the BUTTONS write — uppercase,
      // exactly — is read as operator intent.
      for (final line in ['abide near god', 'faith and works', 'life or death']) {
        expect(analyseCommandDraft(line).hint, isNull, reason: line);
      }
    });

    test('NEAR with no distance is filled in, not just refused', () {
      final d = analyseCommandDraft('G25 NEAR G26', nearDistance: 7);
      expect(d.hint, CommandDraftHint.nearWithoutDistance);
      expect(d.suggestion, 'G25 NEAR7 G26');
      expect(parseStrongsBoolean(d.suggestion!), isNotNull);
      expect(describeCommandDraft(d, 'en'), contains('NEAR'));
    });

    test('a non-number in a Strong\'s expression is named', () {
      final d = analyseCommandDraft('G25 AND god');
      expect(d.hint, CommandDraftHint.notAStrongsExpression);
      expect(d.offender, 'god');
      expect(describeCommandDraft(d, 'en'), contains('"god"'));
      expect(describeCommandDraft(d, 'zh-Hans'), contains('god'));
    });

    test('the shapes that already worked are left alone', () {
      // The parser-as-oracle test fires on ANY line it refuses, so the
      // things it accepts have to stay silent — including the glued `!`
      // alias and the wildcard, both of which task #294 had to repair.
      for (final line in [
        'G25 AND G26',
        'G25 NEAR5 G26',
        'G25 !G26',
        'G25* OR G26',
        'G25',
        '.love god',
        "'and god said",
      ]) {
        expect(analyseCommandDraft(line).willNotRunAsWritten, isFalse,
            reason: line);
      }
    });

    test('a bare number is not treated as a broken expression', () {
      // `parseStrongsBoolean` refuses `G25` on purpose — a single number
      // belongs to the lexicon path — so a one-token line must be exempt
      // from the oracle or every lexicon lookup grows an error.
      expect(parseStrongsBoolean('G25'), isNull);
      expect(analyseCommandDraft('G25').hint, isNull);
    });
  });

  group('the syntax card as queries', () {
    test('an example is separated from its explanation', () {
      final line = splitSyntaxLine(uiStrings['cmdSyntaxAnd']!['en']!);
      expect(line.example, '.love god');
      expect(line.prose, 'both words in one verse');
    });

    test('the printing glyph is turned back into the operator', () {
      // The card prints `G25✶` because a bare asterisk is nearly
      // invisible at chrome size, and it goes on printing it. The parser
      // wants `*`, and prefilling the glyph would put an unrunnable query
      // on the line — the exact failure this task is about — so the
      // substitution happens between the card and the command line.
      final line = splitSyntaxLine(uiStrings['cmdSyntaxStrongsWild']!['en']!);
      expect(line.example, 'G25✶', reason: 'what the card shows');
      expect(line.runnable, 'G25*', reason: 'what a tap types');
      expect(parseStrongsBoolean(line.runnable!), isNotNull);
    });

    test('every tappable example on the card actually runs', () {
      const runnable = [
        'cmdSyntaxAnd',
        'cmdSyntaxOr',
        'cmdSyntaxPhrase',
        'cmdSyntaxNot',
        'cmdSyntaxWild',
        'cmdSyntaxGap',
        'cmdSyntaxContext',
      ];
      for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
        for (final k in runnable) {
          final ex = splitSyntaxLine(uiStrings[k]![locale]!).runnable!;
          expect(parseCommandQuery(ex), isNotNull, reason: '$k/$locale: $ex');
        }
        for (final k in [
          'cmdSyntaxStrongsBool',
          'cmdSyntaxStrongsNear',
          'cmdSyntaxStrongsWild',
        ]) {
          final ex = splitSyntaxLine(uiStrings[k]![locale]!).runnable!;
          expect(parseStrongsBoolean(ex), isNotNull, reason: '$k/$locale: $ex');
        }
      }
    });

    test('a line that is several commands at once offers no prefill', () {
      // The verb summary and the ↑/↓ line are `·`-separated lists. There
      // is nothing single to fill in, so they stay prose.
      for (final k in ['cmdSyntaxVerbs', 'cmdSyntaxHistory']) {
        expect(splitSyntaxLine(uiStrings[k]!['en']!).example, isNull,
            reason: k);
      }
    });

    test('the example follows the text, the explanation follows the reader',
        () {
      // A Chinese interface over the BSB that offers `.爱 神` teaches that
      // the card is broken: the query is well-formed and cannot match.
      expect(
          exampleLocaleFor(versionLanguage: 'en', uiLocale: 'zh-Hans'), 'en');
      expect(exampleLocaleFor(versionLanguage: 'zh-Hant', uiLocale: 'en'),
          'zh-Hant');
      // Greek has no vernacular examples on the card at all, so it keeps
      // the reader's own — the Strong's lines, which are the ones that
      // apply to the LXX, read the same in every locale.
      expect(
          exampleLocaleFor(versionLanguage: 'grc', uiLocale: 'zh-Hans'),
          'zh-Hans');
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
    Future<AppSettings> pump(
      WidgetTester tester, {
      String locale = 'en',
      double width = 500,
      String version = 'bsb',
      VoidCallback? onOpenWordList,
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(width, 1100);
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final mp = MainProvider()
        ..currentVersion = version
        ..setVerses(_seed);
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
              home: Scaffold(
                  body: CommandPane(onOpenWordList: onOpenWordList)),
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

    // ── Task #299 ──────────────────────────────────────────────────
    testWidgets('a card example is a query, not a picture of one',
        (tester) async {
      await pump(tester);
      await tester.tap(find.text('?'));
      await tester.pump();
      await tester.tap(find.textContaining('.love god —'));
      await tester.pump();
      expect(lineOf(tester), '.love god');
    });

    testWidgets('the glyph on the card becomes the operator on the line',
        (tester) async {
      // Tapping `G25✶ — …` must not type `G25✶`, which parses as nothing
      // and would land the reader in the very failure this task removes.
      await pump(tester);
      await tester.tap(find.text('?'));
      await tester.pump();
      await tester.tap(find.textContaining('G25✶ —'));
      await tester.pump();
      expect(lineOf(tester), 'G25*');
      expect(parseStrongsBoolean(lineOf(tester)), isNotNull);
    });

    testWidgets('tapping fills the line and does not run it', (tester) async {
      // `ai …` is the only command that leaves the device, and nobody
      // should send it by reading the help. The whole card therefore
      // prefills rather than runs — one rule, no exceptions to remember.
      await pump(tester);
      await tester.tap(find.text('?'));
      await tester.pump();
      await tester.tap(find.textContaining('.love god —'));
      await tester.pump();
      final wb = tester
          .element(find.byType(CommandPane))
          .read<WorkbenchProvider>();
      expect(wb.lastQuery, isEmpty, reason: 'nothing was submitted');
      expect(wb.searching, isFalse);
    });

    testWidgets('tapping an operator says what it did, without a hover',
        (tester) async {
      // The reports come from a tablet. Task #294's tooltips are a hover
      // affordance, so on the device where the strip is most confusing
      // they were unreachable. The tap itself now answers the question.
      await pump(tester);
      await tester.tap(find.text('/'));
      await tester.pump();
      expect(find.text(uiStrings['cmdOpTipAny']!['en']!), findsWidgets);
      // …and it is about the token just inserted, so it expires when the
      // line stops being that.
      await tester.enterText(find.byType(TextField), '/faith works');
      await tester.pump();
      expect(find.text(uiStrings['cmdOpTipAny']!['en']!), findsNothing);
    });

    testWidgets('an operator between words is caught before it runs',
        (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'yahweh NEAR5 god');
      await tester.pump();
      expect(find.textContaining('not words'), findsOneWidget);
      // The rewrite is offered as something to tap, not as prose to
      // retype.
      await tester.tap(find.text("'yahweh *4 god"));
      await tester.pump();
      expect(lineOf(tester), "'yahweh *4 god");
    });

    testWidgets('the hint says where a Strong\'s number comes from',
        (tester) async {
      var opened = 0;
      await pump(tester, onOpenWordList: () => opened++);
      await tester.enterText(find.byType(TextField), 'G25 AND ');
      await tester.pump();
      await tester.tap(find.text(uiStrings['cmdDraftFindNumber']!['en']!));
      await tester.pump();
      expect(opened, 1);
    });

    testWidgets('…and so does the card', (tester) async {
      var opened = 0;
      await pump(tester, onOpenWordList: () => opened++);
      await tester.tap(find.text('?'));
      await tester.pump();
      await tester.tap(find.text(uiStrings['cmdSyntaxFindNumber']!['en']!));
      await tester.pump();
      expect(opened, 1);
    });

    testWidgets('the example follows the text being searched', (tester) async {
      // An English interface over a Chinese edition. The explanation is
      // the reader's; the query has to be the text's, or tapping it
      // returns zero hits and teaches that the card is broken.
      await pump(tester, version: 'cuvs-yhwh');
      await tester.tap(find.text('?'));
      await tester.pump();
      expect(find.textContaining('.爱 神 — both words'), findsOneWidget);
      await tester.tap(find.textContaining('.爱 神 —'));
      await tester.pump();
      expect(lineOf(tester), '.爱 神');
    });

    testWidgets('the card fits the narrowest the pane is allowed to be',
        (tester) async {
      // The Workbench's left pane bottoms out at 256px and the card is
      // long. In Chinese every line is longer still, and a tappable row
      // that overflows is a target you cannot see the end of.
      await pump(tester, locale: 'zh-Hans', width: 256);
      await tester.tap(find.text('?'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
