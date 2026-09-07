/// One search: what the standalone search page brought with it.
///
/// SeekSparks had two searches with different feature sets — the
/// command line had the grammar, Strong's booleans and the `l` limit;
/// the standalone page had AI passage search and a persisted recents
/// list. These prove the survivor kept what was worth keeping, because
/// the merge is only worth doing if nothing was quietly dropped.
///
/// 2026-09-07: the AI half is gone — removed at the owner's request,
/// not lost. What is left of that group is the one assertion that was
/// never about AI: `ai` is a Canaanite city and has to stay findable.
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
import 'package:seeksparks/services/concordance_service.dart';
import 'package:seeksparks/services/recent_searches_service.dart';
import 'package:seeksparks/widgets/command_pane.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _seed = [
  Verse(book: 'Genesis', chapter: 1, verse: 1, text: 'In the beginning God'),
  Verse(
      book: 'Philippians',
      chapter: 4,
      verse: 6,
      text: 'Be careful for nothing; but in every thing by prayer'),
  Verse(
      book: 'Philippians',
      chapter: 4,
      verse: 7,
      text: 'And the peace of God, which passeth all understanding'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `testWidgets` runs its body in a fake-async zone, where a Future
  // waiting on real disk I/O never completes — the same hazard
  // `naves_pane_test.dart:30-45` documents for `NavesService`. So the
  // 6.9 MB concordance is warmed HERE, outside that zone. Afterwards
  // `ConcordanceService.lookup` hits its static `_cache` and resolves
  // as a microtask, which `pump` can drive.
  setUpAll(() async {
    await ConcordanceService.lookup('G25');
  });

  Future<WorkbenchProvider> pump(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(500, 900);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(Map<String, Object>.from(prefs));
    RecentSearchesService.resetWriteLock();
    final mp = MainProvider()
      ..setVerses(_seed)
      ..currentVersion = 'kjv';
    final wb = WorkbenchProvider(mainProvider: mp);
    addTearDown(wb.dispose);
    final settings = AppSettings();
    await settings.setLocale('en');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: mp),
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

  Future<void> submit(WidgetTester tester, String line) async {
    await tester.enterText(find.byType(TextField), line);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    // Durations, not bare frames: submitting now awaits the search and
    // then a SharedPreferences write before the pane settles.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('ai is a city, and always was', () {
    testWidgets('Ai the city is still findable', (tester) async {
      // Joshua 7-8. This used to guard against the `ai` VERB stealing
      // the lookup; with the verb gone it guards against the removal
      // having left anything behind that still intercepts those two
      // letters.
      final wb = await pump(tester);
      await submit(tester, 'ai');
      expect(wb.searchPerformed, isTrue);
    });
  });

  group('recents — the other thing the standalone page had', () {
    testWidgets('a search that ran is remembered and re-runnable',
        (tester) async {
      final wb = await pump(tester);
      await submit(tester, 'beginning');
      expect(await RecentSearchesService.list(), ['beginning']);

      // Clearing the results returns the pane to the empty state, which
      // is where the history lives.
      wb.clearResults();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      // Scoped to the row: the command line still holds the query too,
      // and `find.text` matches an EditableText.
      final row = find.ancestor(
          of: find.byIcon(Icons.history), matching: find.byType(Row));
      expect(find.descendant(of: row.first, matching: find.text('beginning')),
          findsOneWidget);

      await tester.tap(row.first);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(wb.textResults, isNotEmpty);
    });

    testWidgets('a query the grammar refused is not remembered',
        (tester) async {
      // bwh09: "Entries are not added to this list until they are
      // executed without any error messages." The ↑ history is the
      // opposite and keeps everything — that is what makes a typo
      // fixable.
      await pump(tester);
      await submit(tester, '.');
      expect(await RecentSearchesService.list(), isEmpty);
    });

    testWidgets('nor is one that ran as something else entirely',
        (tester) async {
      // 2026-08-11 (task #299). This is where `yahweh NEAR5` was
      // reported from. It raises no `commandIssue` at all: it is not a
      // command and not a Strong's expression, so it reaches
      // `SearchService` and is matched as the literal string
      // "yahwehnear5god" — nothing found, nothing said, and then filed
      // as a search that worked. Recents is a list you re-run, so the
      // gate has to be "will this do what it says", not "did anything
      // complain".
      await pump(tester);
      await submit(tester, 'yahweh NEAR5 god');
      expect(await RecentSearchesService.list(), isEmpty);
      // The ↑ history still has it — that is the list for fixing what
      // you just mistyped.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'yahweh NEAR5 god');
    });

    testWidgets('a stored history greets the reader before any search',
        (tester) async {
      await pump(tester, prefs: {
        'profile.guest.recentSearches': <String>[
          '.love god',
          "'in the beginning",
        ],
      });
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('.love god'), findsOneWidget);
      expect(find.text("'in the beginning"), findsOneWidget);
    });
  });

  group("a Strong's number with nothing to show", () {
    testWidgets('an unknown number says so instead of "No results found"',
        (tester) async {
      // G9999 is past the last number greek.json holds (G5624), so this
      // is the `unknownNumber` case: not a word we lack, a number that
      // does not exist. The concordance is warm from `setUpAll`.
      await pump(tester);
      await submit(tester, 'G9999');
      expect(find.textContaining("outside Strong's numbering"), findsOneWidget);
      expect(find.textContaining('G1–G5624'), findsOneWidget);
    });
  });
}
