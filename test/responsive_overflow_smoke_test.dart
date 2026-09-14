import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/pages/about_page.dart';
import 'package:seeksparks/pages/library_page.dart';
import 'package:seeksparks/pages/settings_page.dart';
import 'package:seeksparks/pages/workbench_page.dart';
import 'package:seeksparks/models/book.dart';
import 'package:seeksparks/models/chapter.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/widgets/workbench_chrome.dart';

/// 2026-06-11 audit: responsive overflow smoke tests.
///
/// Pumps real pages at the four widths that bracket the supported
/// devices — iPhone SE (320), iPhone 14/15 (390), iPad portrait (768)
/// and desktop (1280) — and asserts the layout pass throws nothing.
/// RenderFlex overflows surface as test exceptions, so any future
/// "RIGHT OVERFLOWED BY N PIXELS" regression on these pages fails CI
/// instead of shipping.
///
/// Pages covered: About, Settings, Library — and, since 2026-09-14, the
/// Workbench, which is the screen the app actually opens on and was the
/// one page excluded here. The note this replaces said "the reading pane
/// needs loaded bible data and is covered by the on-device flows"; the
/// first half is true and the second was a hope. Seeding two verses into
/// the provider is enough to lay the whole workspace out — every pane,
/// the top strip, the tab strip — and that is what the four widths below
/// are for. 320px is the interesting one: a workspace designed for a
/// 1280px desktop still has to survive an iPhone SE, because the same
/// build ships there.
///
/// Each page is pumped with fresh providers and empty SharedPreferences
/// (the cold-install state, which is also the state most likely to show
/// placeholder/empty layouts that overflow).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sizes = <String, Size>{
    'iPhone SE 320x568': Size(320, 568),
    'iPhone 390x844': Size(390, 844),
    'iPad portrait 768x1024': Size(768, 1024),
    'desktop 1280x800': Size(1280, 800),
  };

  final pages = <String, Widget Function()>{
    'AboutPage': () => const AboutPage(),
    'SettingsPage': () => const SettingsPage(),
    'LibraryPage': () => const LibraryPage(),
    'WorkbenchPage': () => const WorkbenchPage(),
  };

  /// Enough scripture for the panes to have something to lay out. An
  /// empty provider would let the workspace render placeholders and pass
  /// for the wrong reason.
  const seed = [
    Verse(book: 'Genesis', chapter: 1, verse: 1, text: 'seed 1'),
    Verse(book: 'Genesis', chapter: 1, verse: 2, text: 'seed 2'),
  ];

  Future<void> pumpAt(
    WidgetTester tester,
    Widget page,
    Size logicalSize, {
    double menuScale = 1.0,
    double fontSize = 20.0,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = logicalSize;
    final settings = AppSettings();
    await settings.setMenuScale(menuScale);
    await settings.setFontSize(fontSize);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()
            // Book, chapter and `books` as well as the verses: the
            // reading pane pages through CHAPTERS and needs `books` to
            // know which page it is on, and filters the verse list by
            // book and chapter to fill it. Seeding `verses` alone leaves
            // it with nothing to draw. It is seeded properly here so
            // that a future change which DOES open the workspace on the
            // reading column gets a real one — from a cold install the
            // Workbench opens on the search surface, which the guard at
            // the foot of this file says plainly rather than leaving to
            // be discovered.
            ..currentBook = 'Genesis'
            ..currentChapter = 1
            ..setBooks([
              Book(title: 'Genesis',
                  chapters: [Chapter(title: 1, verses: seed)]),
            ])
            ..setVerses(seed)),
          ChangeNotifierProvider<AppSettings>.value(value: settings),
        ],
        child: MaterialApp(home: page),
      ),
    );
    // A handful of fixed frames instead of pumpAndSettle: pages kick
    // off async loads (prefs, asset JSON) whose spinners would keep
    // pumpAndSettle waiting forever.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
  }

  // 2026-09-14: the second axis, added after the sibling file in the
  // Words repo found what it had been missing. Every case here ran at
  // menu scale 1.0 and reader size 20, and both sliders go higher —
  // Menu Size to 1.5x, the reader's own text to 40. Chrome takes its
  // sizes from both, so the largest interface the app can draw was the
  // one configuration never laid out. In Words that corner held a
  // 64-pixel overflow in the reading page's bottom bar, on the screen
  // the reader spends every minute on.
  //
  // Paired rather than crossed: 1.0x/20pt is what the app ships as,
  // 1.5x/40pt is both sliders at maximum, and the mixed combinations sit
  // between them.
  const configs = <String, (double, double)>{
    'default 1.0x / 20pt': (1.0, 20.0),
    'largest 1.5x / 40pt': (1.5, 40.0),
  };

  for (final pageEntry in pages.entries) {
    for (final sizeEntry in sizes.entries) {
      for (final config in configs.entries) {
        final (menuScale, fontSize) = config.value;
        testWidgets('${pageEntry.key} lays out at ${sizeEntry.key} '
            'at ${config.key} without overflow', (tester) async {
          SharedPreferences.setMockInitialValues(<String, Object>{});
          addTearDown(tester.view.reset);

          await pumpAt(tester, pageEntry.value(), sizeEntry.value,
              menuScale: menuScale, fontSize: fontSize);
          expect(
            tester.takeException(),
            isNull,
            reason: '${pageEntry.key} threw during layout at '
                '${sizeEntry.key} at ${config.key}',
          );

          // Dispose the page so timers/listeners registered in initState
          // are cancelled before the test ends (pending-timer guard).
          await tester.pump(const Duration(milliseconds: 700));
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 700));
        });
      }
    }
  }

  testWidgets('WorkbenchPage really builds its chrome — the width tests '
      'above are not measuring a blank screen', (tester) async {
    // Every assertion above is "nothing threw", which a screen that
    // rendered nothing also satisfies. This is what says otherwise.
    //
    // And it asserts the CHROME, not the scripture, because that is what
    // this harness actually exercises: from a cold install the Workbench
    // opens on the search surface, so the reading column is not on screen
    // at any of the four widths above. That is a real limit of these
    // tests and it is better written down than assumed away — the
    // sibling repo's HomePage covers a rendered reading column, this one
    // covers the menu bar, the toolbar and the tab strip. The toolbar is
    // where the 18px overflow at 320 was, so the coverage is not
    // incidental.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);

    await pumpAt(tester, const WorkbenchPage(), const Size(1280, 800));

    expect(find.byType(WorkbenchToolbar), findsOneWidget,
        reason: 'the toolbar — the widget that overflowed at 320px — is '
            'not in the tree, so the width tests above are not '
            'measuring it');
    expect(find.byType(WbToolIcon), findsWidgets,
        reason: 'the toolbar is empty, so its width cannot overflow and '
            'these tests would pass on a screen with no commands');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
