import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/widgets/analysis_tabs.dart';
import 'package:seeksparks/widgets/related_verses_pane.dart';

/// The four verses that carry the assertions, plus enough filler to keep
/// the corpus realistic. `defaultEnabledTerms` unchecks any word found in
/// more than 20% of the corpus, so a four-verse corpus unchecks
/// everything — a word in a single verse is already 25% of it.
List<Verse> _corpusVerses() => [
      const Verse(
          book: 'Genesis',
          chapter: 1,
          verse: 1,
          text: 'In the beginning God created the heaven and the earth.'),
      const Verse(
          book: 'Genesis',
          chapter: 2,
          verse: 4,
          text: 'in the day that the LORD God made the earth and the heavens'),
      const Verse(
          book: 'Isaiah',
          chapter: 45,
          verse: 18,
          text: 'For thus saith the LORD that created the heavens; God '
              'himself that formed the earth and made it'),
      const Verse(
          book: 'Psalms',
          chapter: 23,
          verse: 1,
          text: 'The LORD is my shepherd; I shall not want.'),
      for (var i = 0; i < 60; i++)
        Verse(
          book: 'Proverbs',
          chapter: 1 + i ~/ 20,
          verse: 1 + i % 20,
          text: 'A wise son heareth instruction number$i but a scorner '
              'heareth not rebuke',
        ),
    ];

Widget _host(Widget child, {double width = 320}) => ChangeNotifierProvider(
      create: (_) => AppSettings(),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: width, height: 640, child: child),
          ),
        ),
      ),
    );

void main() {
  group('RelatedVersesPane', () {
    testWidgets('finds the verses that share the base verse\'s words',
        (tester) async {
      final verses = _corpusVerses();
      await tester.pumpWidget(_host(RelatedVersesPane(
        corpus: [for (final v in verses) v.text],
        verses: verses,
        baseIndex: 0,
        locale: 'en',
      )));
      await tester.pumpAndSettle();

      // Gen 1:1's content words are created/heaven/earth/god/beginning.
      // Gen 2:4 and Isa 45:18 share several; Ps 23:1 shares none.
      expect(find.text('Gen 2:4'), findsOneWidget);
      expect(find.text('Isa 45:18'), findsOneWidget);
      expect(find.text('Ps 23:1'), findsNothing);
    });

    testWidgets('unchecking a word drops the verses that only shared it',
        (tester) async {
      final verses = _corpusVerses();
      await tester.pumpWidget(_host(RelatedVersesPane(
        corpus: [for (final v in verses) v.text],
        verses: verses,
        baseIndex: 0,
        locale: 'en',
      )));
      await tester.pumpAndSettle();

      final before = find.text('Gen 2:4');
      expect(before, findsOneWidget);

      // Turning every word off must leave nothing to match on.
      for (final label in const ['beginning', 'god', 'created', 'heaven',
        'earth']) {
        final chip = find.textContaining(label);
        if (chip.evaluate().isEmpty) continue;
        await tester.tap(chip.first);
        await tester.pumpAndSettle();
      }
      expect(find.text('Gen 2:4'), findsNothing);
    });

    testWidgets('tapping a hit opens its text inline', (tester) async {
      final verses = _corpusVerses();
      Verse? opened;
      await tester.pumpWidget(_host(RelatedVersesPane(
        corpus: [for (final v in verses) v.text],
        verses: verses,
        baseIndex: 0,
        locale: 'en',
        onOpenVerse: (v) => opened = v,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gen 2:4'));
      await tester.pumpAndSettle();
      // The row expands rather than navigating — navigation is a
      // separate affordance, so a tap must not have jumped the reader.
      expect(opened, isNull);
      expect(find.textContaining('shepherd', findRichText: true), findsNothing);
      expect(find.textContaining('in the day that', findRichText: true),
          findsOneWidget);
    });

    testWidgets('renders without overflow at 320 and 560', (tester) async {
      final verses = _corpusVerses();
      for (final w in const [320.0, 560.0]) {
        await tester.pumpWidget(_host(
          RelatedVersesPane(
            corpus: [for (final v in verses) v.text],
            verses: verses,
            baseIndex: 0,
            locale: 'en',
          ),
          width: w,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'at $w px');
      }
    });

    testWidgets('a verse with no usable words says so', (tester) async {
      const verses = [
        Verse(book: 'Genesis', chapter: 1, verse: 1, text: '. . .'),
        Verse(book: 'Genesis', chapter: 1, verse: 2, text: 'and the earth'),
      ];
      await tester.pumpWidget(_host(RelatedVersesPane(
        corpus: [for (final v in verses) v.text],
        verses: verses,
        baseIndex: 0,
        locale: 'en',
      )));
      await tester.pumpAndSettle();
      expect(find.textContaining('no words to match'), findsOneWidget);
    });
  });

  group('AnalysisTabStrip', () {
    testWidgets('five tabs fit at 320 px by dropping their labels',
        (tester) async {
      await tester.pumpWidget(_host(
        Column(children: [
          AnalysisTabStrip(
            current: AnalysisTab.related,
            onChanged: (_) {},
            locale: 'en',
          ),
        ]),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Related'), findsNothing);
      expect(find.byIcon(Icons.linear_scale_rounded), findsOneWidget);
    });

    testWidgets('labels come back when there is room', (tester) async {
      await tester.pumpWidget(_host(
        Column(children: [
          AnalysisTabStrip(
            current: AnalysisTab.related,
            onChanged: (_) {},
            locale: 'en',
          ),
        ]),
        width: 560,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Related'), findsOneWidget);
    });
  });
}
