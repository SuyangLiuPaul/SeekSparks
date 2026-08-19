/// The Topics pane, mounted, against the real bundled assets.
///
/// `naves_test.dart` pins the data and the core. Neither one can tell you
/// that the pane reaches the screen: an index can be perfect while the
/// tab renders an empty list, and a licence statement can sit in the
/// asset without ever being drawn. So these tests assert on rendered
/// text — the headword and the path a reader needs to read a line, the
/// mark on a chapter-level citation, and the attribution both works ship
/// under.
///
/// The pane hosts two works now, and the ORDER is a claim: Nave's covers
/// the whole Bible, the Modern Concordance is New Testament Greek only,
/// so on an Old Testament verse the concordance section must be absent
/// rather than present and empty.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/services/modern_concordance_service.dart';
import 'package:seeksparks/services/naves_service.dart';
import 'package:seeksparks/utils/reference_parser.dart' show BibleReference;
import 'package:seeksparks/widgets/analysis_tabs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `testWidgets` runs in a fake-async zone where a Future waiting on real
  // disk I/O never completes, so the pane would sit on its spinner. Warm
  // the static caches here; afterwards the pane's awaits resolve as
  // microtasks that `pumpAndSettle` can drive.
  setUpAll(() async {
    for (final (book, ch, vs) in const [
      ('2 Chronicles', 34, 20),
      ('Matthew', 24, 15),
      ('Numbers', 17, 8),
      ('Obadiah', 1, 2),
    ]) {
      await NavesService.forVerse(englishBook: book, chapter: ch, verse: vs);
      await ModernConcordanceService.forVerse(
          englishBook: book, chapter: ch, verse: vs);
    }
  });

  final opened = <BibleReference>[];

  setUp(opened.clear);

  // The section ORDER and the attribution that closes each section sit
  // below the fold on a real verse, and a lazy ListView never builds what
  // it cannot show. Growing the SizedBox is not enough — the Scaffold
  // hands it the surface's constraints — so the surface itself grows.
  Future<void> tall(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(500, 3600));
    addTearDown(() => t.binding.setSurfaceSize(null));
  }

  Widget host(String book, int chapter, int verse) => ChangeNotifierProvider(
        create: (_) => AppSettings(),
        child: MaterialApp(
          home: Scaffold(
            body: TopicsPane(
              englishBook: book,
              chapter: chapter,
              verse: verse,
              locale: 'en',
              onOpenRef: opened.add,
            ),
          ),
        ),
      );

  testWidgets('an OT verse shows Nave\'s alone, with its credit', (t) async {
    await tall(t);
    await t.pumpWidget(host('2 Chronicles', 34, 20));
    await t.pumpAndSettle();

    expect(find.text("NAVE'S TOPICAL BIBLE"), findsOneWidget);
    expect(find.text('MODERN CONCORDANCE (NT)'), findsNothing);
    expect(find.text('MICAH'), findsOneWidget);
    expect(
      find.textContaining('Public domain', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('a NT verse shows both works, Nave\'s first', (t) async {
    await tall(t);
    await t.pumpWidget(host('Matthew', 24, 15));
    await t.pumpAndSettle();

    final naves = t.getTopLeft(find.text("NAVE'S TOPICAL BIBLE")).dy;
    final modern = t.getTopLeft(find.text('MODERN CONCORDANCE (NT)')).dy;
    expect(naves, lessThan(modern),
        reason: 'the work that covers the whole Bible leads');
    expect(find.textContaining('DANIEL ›'), findsOneWidget);
  });

  testWidgets('a row prints the path, not just the headword', (t) async {
    await t.pumpWidget(host('Matthew', 24, 15));
    await t.pumpAndSettle();

    // Nave files this verse under DANIEL beneath "PROPHECIES OF"; the
    // bare headword would not say which of Daniel's many lines it is.
    expect(
      find.textContaining('DANIEL ›', findRichText: true),
      findsWidgets,
    );
  });

  testWidgets('expanding a citation reveals its verses and navigates',
      (t) async {
    await t.pumpWidget(host('2 Chronicles', 34, 20));
    await t.pumpAndSettle();

    expect(find.text('2 Chronicles 34:20'), findsNothing);
    await t.tap(find.text('MICAH'));
    await t.pumpAndSettle();

    // The verse we came from stays in the list rather than being hidden,
    // so the count in the header stays honest.
    expect(find.text('2 Chronicles 34:20'), findsOneWidget);
    await t.tap(find.text('2 Chronicles 34:20'));
    expect(opened.single.englishBook, '2 Chronicles');
    expect(opened.single.chapter, 34);
    expect(opened.single.verseStart, 20);
  });

  testWidgets('a chapter citation is marked as one', (t) async {
    await t.pumpWidget(host('Numbers', 17, 8));
    await t.pumpAndSettle();

    // Nave wrote "Rod of, buds — Nu 17". He did not file verse 8, and the
    // pane has to say so or it invents a claim.
    expect(find.text('whole chapter'), findsWidgets);
  });

  testWidgets('a verse neither work files says exactly that', (t) async {
    await t.pumpWidget(host('Obadiah', 1, 2));
    await t.pumpAndSettle();

    expect(find.text('Neither topical index files this verse.'),
        findsOneWidget);
    expect(find.text("NAVE'S TOPICAL BIBLE"), findsNothing);
  });
}
