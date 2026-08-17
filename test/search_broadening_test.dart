/// The rung below the query the reader ran (#299/#321).
///
/// Two halves, and the second is the one that matters. The ladder
/// itself — which lines have a looser reading and which do not — is
/// pinned on the grammar alone. The counts are pinned against the real
/// BSB and KJV, because the whole promise of this feature is that the
/// number beside the offer is measured rather than asserted, and a
/// promise about a measurement can only be tested by measuring.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:seeksparks/constants/text_patterns.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/providers/workbench_provider.dart';
import 'package:seeksparks/utils/command_query.dart';
import 'package:seeksparks/utils/search_broadening.dart';
import 'package:seeksparks/widgets/command_pane.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String? broaden(String raw) =>
      broadenedCommandLine(parsed: parseCommandQuery(raw).query, raw: raw);

  group('the ladder has exactly one rung, and it is phrase → AND', () {
    test('a phrase drops its word order', () {
      expect(broaden("'the true God"), '.the true God');
    });

    test('a plain multi-word line is a phrase in disguise', () {
      // No control character, so the scan is a substring of the
      // space-stripped verse: an exact run of words in an exact order.
      expect(broaden('the true God'), '.the true God');
    });

    test('AND is already the loosest rung offered', () {
      expect(broaden('.the true God'), isNull);
    });

    test('OR is not offered, because it answers a different question', () {
      // Measured over the BSB: `.the true God` is 18 verses and
      // `/the true God` is 23,248. That is not a broader answer.
      expect(broaden('/the true God'), isNull);
    });

    test('one word has no order to drop', () {
      expect(broaden('God'), isNull);
      expect(broaden("'God"), isNull);
    });

    test('an empty or blank line has nothing to broaden', () {
      expect(broaden(''), isNull);
      expect(broaden('   '), isNull);
    });
  });

  group('the offers that would change the meaning are refused', () {
    test('a negated phrase is not broadened', () {
      // `'!the god` fills ONE sequence position with "any word but the".
      // The same `!` in an AND excludes the whole verse, so the AND form
      // is not a superset — it is a different search sharing the words.
      expect(broaden("'!the god"), isNull);
    });

    test('a phrase whose words survive re-parsing as a control is refused',
        () {
      // The output is re-read through the grammar the reader would have
      // typed. A source that means something else in AND position dies
      // here rather than shipping as a wrong offer.
      final line = broaden("'faith !works");
      expect(line, isNull);
    });

    test('the verse window is carried across', () {
      expect(broaden("'the true God;3"), '.the true God;3');
    });
  });

  group('the corpus decides the number, not this file', () {
    late List<String> bsbTexts, bsbKeys, bsbBooks, bsbRefs;
    late List<String> kjvTexts, kjvKeys, kjvBooks, kjvRefs;

    List<List<String>> load(String path) {
      final list = jsonDecode(File(path).readAsStringSync()) as List;
      return [
        // Exactly what MainProvider.wordKeys and .searchKeys are built
        // with. A test that folds differently from the app is testing a
        // corpus the app never sees.
        [for (final v in list) sanitizeForSearchKey(v['text'] as String)],
        [for (final v in list) searchCorpusKey(v['text'] as String)],
        [for (final v in list) v['book'] as String],
        [for (final v in list) '${v['book']} ${v['chapter']}:${v['verse']}'],
      ];
    }

    setUpAll(() {
      final bsb = load('assets/bsb.json');
      bsbTexts = bsb[0];
      bsbKeys = bsb[1];
      bsbBooks = bsb[2];
      bsbRefs = bsb[3];
      final kjv = load('assets/kjv.json');
      kjvTexts = kjv[0];
      kjvKeys = kjv[1];
      kjvBooks = kjv[2];
      kjvRefs = kjv[3];
    });

    List<String> hits(String raw, List<String> texts, List<String> keys,
        List<String> books, List<String> refs) {
      final parse = parseCommandQuery(raw);
      expect(parse.query, isNotNull, reason: '"$raw": ${parse.issue}');
      final result = runCommandQuery(
          query: parse.query!, texts: texts, searchKeys: keys, books: books);
      return [for (final i in result.indices) refs[i]];
    }

    int literal(String raw, List<String> keys) {
      final needle = searchCorpusKey(raw);
      var n = 0;
      for (final k in keys) {
        if (k.contains(needle)) n++;
      }
      return n;
    }

    test('the reader\'s own query: the search that started this', () {
      // She typed `the true God`, got a short list, and could not find
      // John 17:3 — "the only true God" — which the order-free reading
      // does hold.
      expect(literal('the true God', bsbKeys), 3);
      final and =
          hits('.the true God', bsbTexts, bsbKeys, bsbBooks, bsbRefs);
      expect(and, hasLength(18));
      expect(and, contains('John 17:3'));
    });

    test('the same query in the KJV, where the number is different', () {
      // The count is a property of the edition. It is measured per
      // search for exactly this reason; nothing in the app may carry a
      // remembered one.
      expect(literal('the true God', kjvKeys), 3);
      final and =
          hits('.the true God', kjvTexts, kjvKeys, kjvBooks, kjvRefs);
      expect(and, hasLength(17));
      expect(and, contains('John 17:3'));
    });

    test('the looser reading is a superset, never merely a different set',
        () {
      final phrase =
          hits("'in the beginning", kjvTexts, kjvKeys, kjvBooks, kjvRefs);
      final and =
          hits('.in the beginning', kjvTexts, kjvKeys, kjvBooks, kjvRefs);
      expect(and, containsAll(phrase));
      expect(and.length, greaterThan(phrase.length));
    });

    test('some phrases have no looser reading at all, and must stay silent',
        () {
      // The words only ever occur together, so the AND finds the same
      // verses. An offer here would be a row that changes nothing.
      for (final q in ["gnashing of teeth", 'the only true God']) {
        final phrase = hits("'$q", bsbTexts, bsbKeys, bsbBooks, bsbRefs);
        final and = hits('.$q', bsbTexts, bsbKeys, bsbBooks, bsbRefs);
        expect(and.length, phrase.length,
            reason: '"$q" is the suppression case this feature needs');
      }
    });
  });

  group('termPresence names the word, not the query', () {
    const seed = [
      Verse(
          book: 'Genesis',
          chapter: 1,
          verse: 1,
          text: 'In the beginning God created the heavens'),
      Verse(
          book: 'John',
          chapter: 3,
          verse: 16,
          text: 'For God so loved the world'),
    ];

    final texts = [for (final v in seed) sanitizeForSearchKey(v.text)];
    final keys = [for (final v in seed) searchCorpusKey(v.text)];
    final books = [for (final v in seed) v.book];

    TermPresence probe(String raw) => termPresence(
          query: parseCommandQuery(raw).query!,
          texts: texts,
          searchKeys: keys,
          books: books,
        );

    test('the absent word is the diagnosis', () {
      final p = probe('.God unicorn');
      expect(p.absent, ['unicorn']);
      expect(p.checked, 2);
      expect(p.allPresentApart, isFalse);
    });

    test('every word present, no verse holding them all', () {
      final p = probe('.beginning loved');
      expect(p.absent, isEmpty);
      expect(p.allPresentApart, isTrue);
    });

    test('one word is not a "they never meet" answer', () {
      final p = probe('.God');
      expect(p.absent, isEmpty);
      expect(p.allPresentApart, isFalse, reason: 'one term cannot fail to meet');
    });

    test('negated terms are not probed — absence is what they ask for', () {
      final p = probe('.God !unicorn');
      expect(p.checked, 1);
      expect(p.absent, isEmpty);
    });
  });

  group('the provider never offers a query it has not measured', () {
    const seed = [
      Verse(
          book: 'Genesis',
          chapter: 1,
          verse: 1,
          text: 'In the beginning God created the heavens'),
      Verse(
          book: 'Genesis',
          chapter: 1,
          verse: 2,
          text: 'God moved over the face of the deep in the beginning'),
      Verse(
          book: 'John',
          chapter: 3,
          verse: 16,
          text: 'For God so loved the world'),
    ];

    WorkbenchProvider make() {
      final mp = MainProvider();
      mp.setVerses(seed);
      return WorkbenchProvider(mainProvider: mp);
    }

    test('a thin phrase result gets the offer, with its real count',
        () async {
      final wb = make();
      await wb.runSearch("'in the beginning God");
      expect(wb.textResults, hasLength(1));
      final b = wb.broadening;
      expect(b, isNotNull);
      expect(b!.line, '.in the beginning God');
      // The count is the number of verses the offer really returns —
      // both Genesis verses hold all four words in some order.
      expect(b.verses, 2);
      expect(b.verses, greaterThan(wb.textResults.length));
      wb.dispose();
    });

    test('an offer that cannot beat the current list is withheld', () async {
      final wb = make();
      // Both verses already; dropping the order finds no more.
      await wb.runSearch("'God");
      expect(wb.broadening, isNull);
      wb.dispose();
    });

    test('an empty result with an absent word names the word', () async {
      final wb = make();
      await wb.runSearch('God unicorn');
      expect(wb.textResults, isEmpty);
      expect(wb.broadening, isNull);
      expect(wb.termsMissing?.absent, ['unicorn']);
      wb.dispose();
    });

    test('a Strong’s query has no rung below it', () async {
      final wb = make();
      await wb.runSearch('G25');
      expect(wb.broadening, isNull);
      expect(wb.termsMissing, isNull);
      wb.dispose();
    });

    test('clearing the search clears the offer', () async {
      final wb = make();
      await wb.runSearch("'in the beginning God");
      expect(wb.broadening, isNotNull);
      await wb.runSearch('   ');
      expect(wb.broadening, isNull);
      expect(wb.termsMissing, isNull);
      wb.dispose();
    });
  });

  group('the offer reaches the screen on a SHORT list, not only an empty one',
      () {
    // The defect, exactly: three verses is not zero, so the old hint
    // said nothing and the reader never learned the operator.
    const seed = [
      Verse(
          book: 'Genesis',
          chapter: 1,
          verse: 1,
          text: 'In the beginning God created the heaven and the earth.'),
      // The words in the other order, which is the only thing the
      // looser query adds. If both verses held them adjacent there
      // would be nothing to offer and the test would prove nothing.
      Verse(
          book: 'Genesis',
          chapter: 1,
          verse: 31,
          text: 'And God saw every thing that he had created, and it was good.'),
    ];

    Future<WorkbenchProvider> pump(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(500, 900);
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final wb =
          WorkbenchProvider(mainProvider: MainProvider()..setVerses(seed));
      addTearDown(wb.dispose);
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
      await tester.pump(const Duration(seconds: 1));
      return wb;
    }

    Future<void> submit(WidgetTester tester, String query) async {
      await tester.enterText(find.byType(TextField), query);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump();
    }

    testWidgets('a short phrase result carries the looser query and its count',
        (tester) async {
      final wb = await pump(tester);
      await submit(tester, "'god created");
      // One verse found — a list, not a dead end, which is why the old
      // hint stayed silent here.
      expect(wb.textResults, hasLength(1));
      expect(find.textContaining('The same words in one verse'), findsOneWidget);
      // The count beside it is measured, so it is the number of verses
      // the tap really lands on.
      expect(find.textContaining('.god created'), findsOneWidget);
      expect(find.textContaining('2'), findsWidgets);
    });

    testWidgets('tapping the offer runs it — the box and the list agree',
        (tester) async {
      final wb = await pump(tester);
      await submit(tester, "'god created");
      await tester.tap(find.textContaining('.god created'));
      await tester.pump();
      await tester.pump();
      expect(wb.lastQuery, '.god created');
      expect(wb.textResults, hasLength(2));
      // Nothing looser left to offer, so the row is gone rather than
      // repeating itself.
      expect(wb.broadening, isNull);
      expect(find.textContaining('The same words in one verse'), findsNothing);
    });

    testWidgets('a long result gets no offer at all', (tester) async {
      final wb = await pump(tester);
      await submit(tester, 'god');
      // Both verses, and above the threshold there is nothing to rescue.
      expect(wb.textResults, hasLength(2));
      expect(wb.broadening, isNull);
      expect(find.textContaining('The same words in one verse'), findsNothing);
    });
  });
}
