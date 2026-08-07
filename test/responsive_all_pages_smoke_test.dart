import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/pages/bible_timeline_page.dart';
import 'package:seeksparks/pages/bible_trivia_page.dart';
import 'package:seeksparks/pages/books_page.dart';
import 'package:seeksparks/models/bible_evidence.dart';
import 'package:seeksparks/pages/evidence_detail_page.dart';
import 'package:seeksparks/pages/evidence_page.dart';
import 'package:seeksparks/pages/family_tree_page.dart';
import 'package:seeksparks/pages/highlights_page.dart';
import 'package:seeksparks/pages/profile_edit_page.dart';
import 'package:seeksparks/pages/profiles_page.dart';
import 'package:seeksparks/pages/search_page.dart';
import 'package:seeksparks/pages/sermons_page.dart';
import 'package:seeksparks/pages/stats_page.dart';
import 'package:seeksparks/pages/strongs_entry_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/widgets/onboarding_dialog.dart';

/// 2026-06-12 (v1.3.66 audit): responsive overflow smoke tests for the
/// remaining top-level pages not already covered by
/// responsive_overflow_smoke_test.dart (About/Settings/Library).
/// Pumps each at the four widths bracketing supported
/// devices — iPhone SE (320), iPhone 14/15 (390), iPad portrait (768),
/// desktop (1280) — and asserts the layout pass throws nothing. A
/// RenderFlex "OVERFLOWED BY N PIXELS" surfaces as a test exception,
/// so any responsive regression on these pages fails CI instead of
/// shipping.
/// The detail page's metadata chips sit in a `Wrap`, so one chip wider
/// than the viewport overflows rather than wrapping. Real entries carry
/// a museum's full postal name in `location` — long enough to do it at
/// 320px — so the fixture uses one, and `images` stays empty to keep
/// `Image.network` out of the test.
const BibleEvidence _wideEvidence = BibleEvidence(
  id: 'test-wide',
  category: 'Manuscripts',
  bibleBooks: <String>['Isaiah'],
  timeline: '3rd Century BCE - 1st Century CE',
  discoveryDate: '1946-1956',
  location: 'Shrine of the Book, Israel Museum, Jerusalem',
  scriptureReference: 'Isaiah 40:8',
  images: <String>[],
  academicSources: <String>['Tov, Textual Criticism of the Hebrew Bible'],
  confidenceLevel: 'Definitive',
  icon: 'x',
  title: <String, String>{'en': 'Dead Sea Scrolls'},
  summary: <String, String>{'en': 'summary'},
  description: <String, String>{'en': 'description'},
  scripturalCorrelation: <String, String>{'en': 'correlation'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sizes = <String, Size>{
    'SE 320': Size(320, 568),
    'phone 390': Size(390, 844),
    'tablet 768': Size(768, 1024),
    'desktop 1280': Size(1280, 800),
  };

  // Pages constructible with no domain args (fresh providers + empty
  // prefs = cold-install state, the most likely to show empty/
  // placeholder layouts that overflow).
  final pages = <String, Widget Function()>{
    'StatsPage': () => const StatsPage(),
    'SearchPage': () => const SearchPage(),
    'FamilyTreePage': () => const FamilyTreePage(),
    'BibleTriviaPage': () => const BibleTriviaPage(),
    'EvidencePage': () => const EvidencePage(),
    'EvidenceDetailPage': () =>
        const EvidenceDetailPage(evidence: _wideEvidence),
    'SermonsPage': () => const SermonsPage(),
    'HighlightsPage': () => const HighlightsPage(),
    'ProfilesPage': () => const ProfilesPage(),
    'ProfileEditPage': () => const ProfileEditPage(),
    'BibleTimelinePage': () => const BibleTimelinePage(),
    'BooksPage': () => const BooksPage(chapterIdx: 0, bookIdx: 'Genesis'),
    'StrongsEntryPage': () => const StrongsEntryPage(number: 'H430'),
  };

  Future<void> pumpAt(
    WidgetTester tester,
    Widget page,
    Size logicalSize,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = logicalSize;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) {
            final mp = MainProvider();
            // Seed a couple verses so pages that gate on a loaded
            // corpus (e.g. SearchPage kicks off _ensureVersesLoaded
            // when verses are empty) render their populated layout
            // instead of starting an async load — both more realistic
            // for overflow and free of an init-time pending fetch.
            mp.setVerses(const [
              Verse(book: 'Genesis', chapter: 1, verse: 1, text: 'seed 1'),
              Verse(book: 'Genesis', chapter: 1, verse: 2, text: 'seed 2'),
            ]);
            return mp;
          }),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: MaterialApp(home: page),
      ),
    );
    // Fixed frames instead of pumpAndSettle — pages kick off async
    // loads (prefs, asset JSON, network) whose spinners would keep
    // pumpAndSettle waiting forever.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
  }

  for (final pageEntry in pages.entries) {
    for (final sizeEntry in sizes.entries) {
      testWidgets('${pageEntry.key} @ ${sizeEntry.key} no overflow',
          (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        addTearDown(tester.view.reset);

        await pumpAt(tester, pageEntry.value(), sizeEntry.value);
        expect(
          tester.takeException(),
          isNull,
          reason: '${pageEntry.key} threw during layout at '
              '${sizeEntry.key}',
        );

        // Dispose so initState timers/listeners are cancelled before
        // the test ends, then drain any final in-flight Future.delayed
        // (e.g. SearchPage's verse-load poll tick, which now stops on
        // dispose via `&& mounted`).
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 250));
      });
    }
  }

  // 2026-06-16 (v1.3.83 follow-up): first-run onboarding dialog
  // (OnboardingDialog) overflowed its content column by ~4px on tall
  // phones (iPhone 17 Pro, ~402×874) — the fixed-height illustration/
  // text PageView could not contain a long slide body at the default
  // font size — and overflowed badly on short viewports because the
  // 240px illustration area plus dots plus buttons exceeded the dialog
  // height. We pump the dialog directly (it is a plain Dialog widget,
  // not pushed via the overlay) at the real device height and at a
  // range of deliberately short heights; any RenderFlex overflow
  // surfaces as a layout exception and fails here.
  //
  // Heights bracket: 360 (well below any real device — pure stress),
  // 568 (iPhone SE), 600, and 874 (iPhone 17 Pro, where the original
  // 4px stripe was reproduced). Width is held at a typical phone
  // logical width since the dialog caps itself at maxWidth 420.
  const onboardingHeights = <int>[360, 480, 568, 600, 700, 874];
  for (final h in onboardingHeights) {
    testWidgets('OnboardingDialog @ 402x$h no overflow', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      addTearDown(tester.view.reset);

      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(402, h.toDouble());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppSettings()),
          ],
          child: const MaterialApp(home: OnboardingDialog()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        tester.takeException(),
        isNull,
        reason: 'OnboardingDialog threw during layout at 402x$h',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 250));
    });
  }
}
