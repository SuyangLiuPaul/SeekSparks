/// `SynopsisService.byVerse` had no caller in `lib/` until 2026-09-06.
///
/// `data_surface_reachability_test.dart` found it orphaned on the day
/// that test was written, and that test is a wiring check: it proves a
/// symbol is NAMED outside its own service, which is exactly the kind
/// of instrument AGENTS.md warns is not a legible screen. So this file
/// asserts the other half — that the parallels covering the focused
/// verse are TEXT A READER CAN SEE in the pane, and that the ones which
/// do not cover it are not.
///
/// The numbers that make the feature worth having, read out of
/// `assets/ot_synopsis.json` rather than asserted from memory:
///
///   2 Kings 24        3 groups  Jehoiachin's, Jehoiakim's, Zedekiah's
///   2 Kings 24:17     1 group   Jehoiachin's Reign
///   2 Kings 24:18     1 group   Zedekiah's Reign
///
/// A reader sitting on 24:18 was shown all three by the chapter sheet,
/// two of which say nothing about the verse under the cursor, and had
/// no way to tell which was which. Two adjacent verses resolving to
/// DIFFERENT single events is the whole of what `byVerse` adds.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/services/synopsis_service.dart';
import 'package:seeksparks/utils/reference_parser.dart' show BibleReference;
import 'package:seeksparks/widgets/analysis_tabs.dart';
import 'package:seeksparks/widgets/synopsis_parallels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The credit Eagle's View's permission is conditional on. Matched by
  /// a distinctive fragment rather than the whole sentence so a
  /// re-worded notice does not fail this for the wrong reason — but it
  /// MUST name the source, which is the condition.
  const creditFragment = "Eagle's View";

  Future<void> pumpPane(
    WidgetTester tester, {
    required String book,
    required int chapter,
    required int verse,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(560, 900);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // THE PUMP HAPPENS INSIDE `runAsync`, and that is load-bearing.
    // Both of the pane's futures end in `rootBundle.loadString`, which
    // is real file I/O, and `CrossReferenceService.forVerseOrNearby`
    // does not cache — it re-reads on every call. Under the fake async
    // zone `tester.pump` drives, that I/O never completes and the pane
    // is still showing its `CircularProgressIndicator` when the
    // assertions run. Measured before this was fixed: the spinner
    // finder found 1 and EVERY text finder found 0, so the first draft
    // of these tests failed for a reason that had nothing to do with
    // the synopsis. `analysis_tabs_test.dart` names the same hazard as
    // its "fixed-pump pattern ... whose spinners never settle" — fine
    // for asserting a pane was SWAPPED, useless for asserting what it
    // says.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppSettings()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CrossRefsPane(
                englishBook: book,
                chapter: chapter,
                verse: verse,
                locale: 'en',
                version: 'KJV',
                verseByRef: const <String, Verse>{},
                onOpenRef: (_) {},
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await tester.pump();
    });
    await tester.pump();
  }

  testWidgets('the verse under the cursor names its own parallel',
      (tester) async {
    addTearDown(tester.view.reset);
    await pumpPane(tester, book: '2 Kings', chapter: 24, verse: 18);
    expect(tester.takeException(), isNull);

    expect(find.textContaining("Zedekiah's Reign"), findsOneWidget,
        reason: 'the group that actually covers 2 Kings 24:18');
    // The two the chapter carries and this verse does not. These are
    // the assertion: without them the test would pass on a pane that
    // simply printed every parallel in the chapter, which is the
    // surface that already existed.
    expect(find.textContaining("Jehoiachin's Reign"), findsNothing);
    expect(find.textContaining("Jehoiakim's Reign"), findsNothing);

    // The chip labels, which is where `_shortLabel` lives — the
    // arithmetic that used to split at the first space and turned
    // "2 Chronicles 26:3-15" into "Chronicles 26:3-15". It moved out of
    // `bible_reading_pane.dart` into a shared widget with this work, so
    // it is pinned here rather than trusted to survive the move.
    expect(find.text('2Ch 36:11-21'), findsOneWidget);
    expect(find.text('2Ki 24:18-25:30'), findsOneWidget);
    expect(find.text('Jer 52:1-34'), findsOneWidget);
  });

  testWidgets('the verse before it names a different one', (tester) async {
    addTearDown(tester.view.reset);
    await pumpPane(tester, book: '2 Kings', chapter: 24, verse: 17);
    expect(tester.takeException(), isNull);
    expect(find.textContaining("Jehoiachin's Reign"), findsOneWidget);
    expect(find.textContaining("Zedekiah's Reign"), findsNothing,
        reason: '24:17 is outside the Zedekiah span; 24:18 is inside it, '
            'and a pane that could not tell them apart would be the '
            'chapter surface again');
  });

  testWidgets("the parallels carry Eagle's View's credit", (tester) async {
    addTearDown(tester.view.reset);
    await pumpPane(tester, book: '2 Kings', chapter: 24, verse: 18);
    expect(find.textContaining(creditFragment), findsOneWidget,
        reason: 'the permission is conditional on naming the source, and '
            'until this pane existed nothing in lib/ printed '
            'SynopsisService.otAttribution at all');
  });

  testWidgets('a verse with no parallel prints no denial and no credit',
      (tester) async {
    addTearDown(tester.view.reset);
    // 2 Kings 8 carries two groups; 8:1 is inside neither. The section
    // must be ABSENT, not empty — the synopsis covers a minority of the
    // Bible's verses and a "no parallels here" line would print on most
    // of them.
    await pumpPane(tester, book: '2 Kings', chapter: 8, verse: 1);
    expect(tester.takeException(), isNull);
    expect(find.byType(SynopsisRow), findsNothing);
    expect(find.textContaining(creditFragment), findsNothing);
    expect(find.textContaining('Parallel Passages'), findsNothing);
    expect(find.textContaining("Ahaziah's Reign"), findsNothing);
  });

  test('the chapter carries more than the verse — the reason this exists',
      () async {
    final chapter = await SynopsisService.byChapter('2 Kings', 24);
    final v18 = await SynopsisService.byVerse('2 Kings', 24, 18);
    final v17 = await SynopsisService.byVerse('2 Kings', 24, 17);

    expect(chapter.length, greaterThan(v18.length),
        reason: 'if the chapter and the verse answered alike there would '
            'be nothing for byVerse to add');
    expect(v18.map((e) => e.localizedTitle('en')), ["Zedekiah's Reign"]);
    expect(v17.map((e) => e.localizedTitle('en')), ["Jehoiachin's Reign"]);
    // Both verse answers are drawn from the chapter's set, so the new
    // surface narrows the old one rather than disagreeing with it.
    final chapterIds = chapter.map((e) => e.id).toSet();
    expect(chapterIds.containsAll(v18.map((e) => e.id)), isTrue);
    expect(chapterIds.containsAll(v17.map((e) => e.id)), isTrue);
  });

  test('the credit the pane prints is the one the asset ships', () async {
    await SynopsisService.preload();
    expect(SynopsisService.otAttribution, contains(creditFragment));
  });

  testWidgets('a Gospel verse is not credited to Eagle\'s View',
      (tester) async {
    addTearDown(tester.view.reset);
    // The Gospel harmony is a different work with no attribution field.
    // Printing the OT credit over a Matthew row would be a FALSE
    // credit, which is worse than the missing one this replaced.
    await pumpPane(tester, book: 'John', chapter: 19, verse: 16);
    expect(tester.takeException(), isNull);
    expect(find.byType(SynopsisRow), findsWidgets,
        reason: 'John 19:16 is in the harmony — see ot_synopsis_test.dart');
    expect(find.textContaining(creditFragment), findsNothing);
  });

  test('BibleReference is what a chip hands back to the reader', () {
    // Guards the navigation contract the row depends on: a passage
    // whose reference did not parse must not be offered as a target.
    const p = SynopsisPassage(book: 'Isaiah', raw: 'Isaiah 7:14', reference: null);
    expect(p.reference, isNull);
    const q = SynopsisPassage(
      book: 'Isaiah',
      raw: 'Isaiah 7:14',
      reference: BibleReference(englishBook: 'Isaiah', chapter: 7, verseStart: 14),
    );
    expect(q.reference?.chapter, 7);
  });
}
