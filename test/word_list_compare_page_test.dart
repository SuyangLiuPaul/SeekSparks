/// The compare mode of the Word List Manager, mounted against the real
/// assets.
///
/// `word_list_compare_test.dart` pins the arithmetic. What that cannot
/// catch is the row itself: three numeric columns and a wrapping meta
/// line inside a `Row`, where a name too long for its box overflows
/// rather than failing, and where a book with no second book chosen must
/// show an invitation rather than an empty table that reads as a result.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/pages/word_list_page.dart';
import 'package:seeksparks/providers/main_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Pump until the load finishes.
  ///
  /// `pumpAndSettle` cannot be used — the loading state is a
  /// `CircularProgressIndicator`, which never settles. Nor can pumping
  /// alone: the page reads two books and a 6.9 MB concordance off the
  /// real bundle, and fake time never lets that I/O run. Hence
  /// `runAsync` between pumps.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)));
    }
    await tester.pump();
  }

  Future<void> pump(WidgetTester tester,
      {Size size = const Size(420, 900), double fontSize = 20}) async {
    // The type scale is seeded through preferences rather than set on a
    // live AppSettings: `setFontSize` notifies listeners, one of which
    // reschedules notifications on a timer that outlives the tree and
    // fails teardown.
    SharedPreferences.setMockInitialValues(
        <String, Object>{'fontSize': fontSize});
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: const MaterialApp(
          home: WordListPage(
            book: 'Jude',
            chapter: 1,
            locale: 'en',
            version: 'kjv',
          ),
        ),
      ),
    );
    await settle(tester);
  }

  /// Drive the second picker without opening its 66-item menu: the
  /// callback under test is the page's, not the dropdown's.
  Future<void> chooseB(WidgetTester tester, String book) async {
    final pickers = tester.widgetList<DropdownButton<String>>(
        find.byType(DropdownButton<String>));
    pickers.last.onChanged!(book);
    await settle(tester);
  }

  Future<void> enterCompare(WidgetTester tester) async {
    await tester.tap(find.text('Compare two books'));
    await settle(tester);
  }

  testWidgets(
      'with no second book chosen it invites rather than showing '
      'an empty table', (tester) async {
    await pump(tester);
    await enterCompare(tester);
    expect(find.textContaining('Pick two books'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the same book twice is refused, not answered with zero',
      (tester) async {
    await pump(tester);
    await enterCompare(tester);
    await chooseB(tester, 'Jude');
    expect(find.textContaining('same book'), findsOneWidget);
  });

  testWidgets('Jude against 2 Peter renders, headed by both sizes',
      (tester) async {
    await pump(tester);
    await enterCompare(tester);
    await chooseB(tester, '2 Peter');
    expect(tester.takeException(), isNull);

    // Both denominators on screen: a pair of row counts is unreadable
    // without them, since Jude is a quarter the length of 2 Peter.
    expect(
        find.textContaining('Jude 227 distinct / 458 words'), findsOneWidget);
    expect(find.textContaining('2 Peter'), findsWidgets);

    // The default bucket is the shared words, and it is not empty.
    expect(find.text('In both 112'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);

    // Opening the pair puts the answer on the FIRST screen: the default
    // sort is rarest-in-the-Bible, so the three words the commentaries
    // cite for the relationship between these two letters are the top
    // three rows. Asserted by number, not by headword — the row is
    // headed by the lexicon's lemma, συνευωχέω rather than the
    // συνευωχέομαι a commentary prints.
    for (final n in ['G1703', 'G4910', 'G5246']) {
      expect(find.textContaining('$n · '), findsOneWidget, reason: n);
    }
    // Carried in WORDS, not colour alone (#317).
    expect(find.textContaining('· Nowhere else'), findsWidgets);
  });

  testWidgets('nowhere-else narrows the open bucket instead of replacing it',
      (tester) async {
    await pump(tester);
    await enterCompare(tester);
    await chooseB(tester, '2 Peter');

    // The modifier, which carries its own count — not the marker on a
    // row. 74 words occur in Jude or 2 Peter and nowhere else in the
    // Bible.
    await tester.tap(find.text('Nowhere else 74'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Every occurrence'), findsOneWidget);

    // Every bucket is now counted within those 74, so a chip's number
    // still matches the list it opens. Three of the 74 are shared —
    // the finding — and 71 belong to one letter or the other.
    expect(find.text('In both 3'), findsOneWidget);
    expect(find.text('All 74'), findsOneWidget);

    // bwh26's own example query: words in one book and nowhere else.
    await tester.tap(find.textContaining('Only in Jud '));
    await settle(tester);
    // 16 + 55 + 3 = 74: the modifier partitions, it does not double-count.
    expect(find.text('Only in Jud 16'), findsOneWidget);
    expect(find.text('Only in 2Pe 55'), findsOneWidget);
  });

  testWidgets(
      'a Hebrew book against a Greek one says why, and does not '
      'print the empty intersection as a finding', (tester) async {
    await pump(tester);
    await enterCompare(tester);
    await chooseB(tester, 'Obadiah');
    expect(tester.takeException(), isNull);
    expect(find.textContaining('not in the same'), findsOneWidget);
    expect(find.text('In both 0'), findsOneWidget);
  });

  testWidgets('a narrow screen at the largest type does not overflow',
      (tester) async {
    // Two failure modes meet here, and both threw before they were
    // bounded: three numeric cells that scale with the type until they
    // are wider than the row, and a pinned control block — two pickers,
    // five filter chips, four sort chips — 505 px taller than the phone.
    await pump(tester, size: const Size(320, 640), fontSize: 40);
    await enterCompare(tester);
    await chooseB(tester, '2 Peter');
    expect(tester.takeException(), isNull);
  });
}
