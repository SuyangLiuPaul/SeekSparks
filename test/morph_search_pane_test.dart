/// 2026-08-07 (SeekSparks): widget tests for the morphological search
/// pane (BibleWorks bwh17 / the Graphical Search Engine).
///
/// `morph_query_test.dart` pins the matcher and
/// `morph_search_service_test.dart` pins the counts against the real
/// text. Neither mounts anything, so neither can tell you whether the
/// pane wires them together — and that wiring is where this kind of
/// feature breaks: facets computed for the wrong scheme, a query thrown
/// away on every pointer move, a stale async result overwriting a newer
/// one.
///
/// Run against the REAL bundled assets. 3 John is 15 verses of genuine
/// tagged Greek and Jude is 25 — small enough to stay quick, real enough
/// that a regression in the corpus fails here rather than shipping.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/services/originals_service.dart';
import 'package:seeksparks/widgets/analysis_tabs.dart';
import 'package:seeksparks/widgets/morph_search_pane.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `testWidgets` runs in a fake-async zone where a Future on real disk
  // I/O never completes, so the pane would sit on its spinner forever.
  // Warming the per-book cache here turns the pane's awaits into
  // microtasks that `pump` can drive.
  setUpAll(() async {
    await OriginalsService.versesOfBook('3 John');
    await OriginalsService.versesOfBook('Jude');
    await OriginalsService.versesOfBook('Obadiah');
    await OriginalsService.versesOfBook('Nonexistent Book');
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

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  /// The query builder is a bounded scroll region, so a feature further
  /// down the list is real but not yet laid out.
  Future<void> revealFacet(WidgetTester tester, Finder chip) async {
    final facets = find.byType(Scrollable).first;
    // Back to the top first: `scrollUntilVisible` only searches forward,
    // and a chip above the current offset would never be reached.
    await tester.drag(facets, const Offset(0, 2000));
    await settle(tester);
    await tester.scrollUntilVisible(chip, 60, scrollable: facets);
    await settle(tester);
  }

  group('the tab is appended, so persisted indices still resolve', () {
    test('morphology is last and nothing before it moved', () {
      // `workbench.analysisTab` persists the tab by INDEX.
      expect(AnalysisTab.values.indexOf(AnalysisTab.morphology), 8);
      expect(AnalysisTab.values.indexOf(AnalysisTab.wordStudy), 0);
      expect(AnalysisTab.values.indexOf(AnalysisTab.vocabulary), 7);
      // `topics` was appended after `morphology` for the same reason —
      // every index before it has to keep its meaning.
      expect(AnalysisTab.values.indexOf(AnalysisTab.topics), 9);
      expect(AnalysisTab.values, hasLength(10));
    });
  });

  group('opening the pane', () {
    testWidgets('offers parts of speech with live counts, not an empty '
        'form', (tester) async {
      await tester.pumpWidget(host(const MorphSearchPane(
        englishBook: '3 John',
        chapter: 1,
        locale: 'en',
      )));
      await settle(tester);
      expect(tester.takeException(), isNull);

      // Greek, because 3 John is in the NT.
      expect(find.text('verb'), findsOneWidget);
      expect(find.text('article'), findsOneWidget);
      // Semitic-only vocabulary must not leak in.
      expect(find.text('Qal'), findsNothing);

      expect(find.text('Chapter'), findsOneWidget);
      expect(find.text('Book'), findsOneWidget);
      expect(find.text('NT'), findsOneWidget);
      expect(find.text('OT'), findsNothing);
    });

    testWidgets('an OT book offers the Semitic vocabulary', (tester) async {
      await tester.pumpWidget(host(const MorphSearchPane(
        englishBook: 'Obadiah',
        chapter: 1,
        locale: 'en',
      )));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('OT'), findsOneWidget);
      expect(find.text('NT'), findsNothing);
      expect(find.text('article'), findsNothing);
    });

    testWidgets('a book with no tagged text says so rather than showing '
        'zero hits', (tester) async {
      await tester.pumpWidget(host(const MorphSearchPane(
        englishBook: 'Nonexistent Book',
        chapter: 1,
        locale: 'en',
      )));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('no tagged original text'), findsOneWidget);
    });
  });

  group('building a query', () {
    testWidgets('choosing a part of speech narrows what is offered and '
        'produces hits', (tester) async {
      await tester.pumpWidget(host(const MorphSearchPane(
        englishBook: '3 John',
        chapter: 1,
        locale: 'en',
      )));
      await settle(tester);

      // Before: nominal features are on offer alongside verbal ones.
      await revealFacet(tester, find.text('nominative'));
      expect(find.text('nominative'), findsOneWidget);

      await revealFacet(tester, find.text('verb'));
      await tester.tap(find.text('verb'));
      await settle(tester);
      expect(tester.takeException(), isNull);

      // The query line now states what is being asked.
      expect(find.text('verb'), findsWidgets);
      expect(find.text('Any form — pick a feature below'), findsNothing);
      await revealFacet(tester, find.text('indicative'));
      expect(find.text('indicative'), findsOneWidget);

      // And real 3 John verses come back.
      expect(find.textContaining(RegExp(r'3Jn \d+:\d+')), findsWidgets);
    });

    testWidgets('a second feature narrows further and Clear undoes it',
        (tester) async {
      await tester.pumpWidget(host(const MorphSearchPane(
        englishBook: 'Jude',
        chapter: 1,
        locale: 'en',
      )));
      await settle(tester);
      expect(find.text('Clear'), findsNothing);

      await tester.tap(find.text('verb'));
      await settle(tester);
      await revealFacet(tester, find.text('participle'));
      await tester.tap(find.text('participle'));
      await settle(tester);
      expect(tester.takeException(), isNull);

      // A participle carries no person, so that value must drop out of
      // the offer entirely rather than sit there returning nothing.
      expect(find.text('1st person'), findsNothing);
      await revealFacet(tester, find.text('nominative'));
      expect(find.text('nominative'), findsOneWidget);

      await tester.tap(find.text('Clear'));
      await settle(tester);
      expect(find.text('Any form — pick a feature below'), findsOneWidget);
    });

    testWidgets('a value that would return nothing is not offered',
        (tester) async {
      await tester.pumpWidget(host(const MorphSearchPane(
        englishBook: '3 John',
        chapter: 1,
        locale: 'en',
      )));
      await settle(tester);
      // 3 John has no interjection; showing a dead chip is the failure
      // the facet counts exist to prevent.
      expect(find.text('interjection'), findsNothing);
    });

    testWidgets('seeding from the pointed-at word fills the query',
        (tester) async {
      await tester.pumpWidget(host(const MorphSearchPane(
        englishBook: '3 John',
        chapter: 1,
        locale: 'en',
        seedCode: 'V-3AAI-S--',
      )));
      await settle(tester);
      expect(find.text('This word'), findsOneWidget);

      await tester.tap(find.text('This word'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Clear'), findsOneWidget);
      // The seeded parse is echoed back as the query.
      expect(find.textContaining('aorist'), findsWidgets);
    });

    testWidgets('a Semitic word is not offered as a seed for a Greek book',
        (tester) async {
      await tester.pumpWidget(host(const MorphSearchPane(
        englishBook: '3 John',
        chapter: 1,
        locale: 'en',
        seedCode: 'HVqp3ms',
      )));
      await settle(tester);
      expect(find.text('This word'), findsNothing);
    });
  });

  group('results', () {
    testWidgets('tapping a hit opens that reference', (tester) async {
      String? opened;
      await tester.pumpWidget(host(MorphSearchPane(
        englishBook: '3 John',
        chapter: 1,
        locale: 'en',
        onOpenRef: (b, c, v) => opened = '$b $c:$v',
      )));
      await settle(tester);
      await tester.tap(find.text('verb'));
      await settle(tester);

      await tester.tap(find.textContaining(RegExp(r'3Jn \d+:\d+')).first);
      await settle(tester);
      expect(opened, matches(RegExp(r'^3 John 1:\d+$')));
    });

    testWidgets('Chinese labels are used throughout', (tester) async {
      await tester.pumpWidget(host(const MorphSearchPane(
        englishBook: '3 John',
        chapter: 1,
        locale: 'zh-Hans',
      )));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('动词'), findsOneWidget);
      expect(find.text('本卷'), findsOneWidget);
      expect(find.text('新约'), findsOneWidget);
    });
  });
}
