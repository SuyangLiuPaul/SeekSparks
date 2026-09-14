// 2026-09-14: no chrome label is drawn narrower than the words in it.
//
// The companion to `responsive_overflow_smoke_test.dart`, and the half it
// cannot see. That file asserts nothing threw, which catches a `Row` that
// ran out of width — but a `Text` with `maxLines: 1` and
// `TextOverflow.ellipsis` does not throw when it runs out of width. It
// succeeds, quietly, by deleting words. Both files lay these pages out at
// the same sizes; only this one notices.
//
// Three labels were found this way, each on the way to something else:
//
//   * the About app bar, 142px short at 390px — 「关于与版...」, with the
//     version number gone. The version is in the app bar precisely
//     because the footer is six sections down a ListView and nobody
//     scrolls to it (v1.2.19), so the ellipsis was undoing the reason the
//     line exists. It shrinks now.
//   * the parallel pane's title, 221px short at 320px — the whole edition
//     stack gone. That title is the CONTROL for changing the stack, so
//     what was deleted is what the control is set to. It counts the stack
//     instead of naming it on a screen too narrow to name it.
//   * the header pill in the sibling Words repo, which is where this
//     started: 「和合本雅伟版」 → 「雅…」, reported four times.
//
// The measurement is a `RenderParagraph`'s laid-out width against the
// width its own text wants on one line. Both sliders are at maximum,
// because that is the configuration the whole family of defects lives in
// and the one no test had ever asked about.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/book.dart';
import 'package:seeksparks/models/chapter.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/pages/about_page.dart';
import 'package:seeksparks/pages/library_page.dart';
import 'package:seeksparks/pages/settings_page.dart';
import 'package:seeksparks/pages/workbench_page.dart';
import 'package:seeksparks/providers/main_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const seed = [
    Verse(book: 'Genesis', chapter: 1, verse: 1, text: 'seed 1'),
    Verse(book: 'Genesis', chapter: 1, verse: 2, text: 'seed 2'),
  ];

  const sizes = <String, Size>{
    'iPhone SE 320x568': Size(320, 568),
    'iPhone 390x844': Size(390, 844),
  };

  final pages = <String, Widget Function()>{
    'AboutPage': () => const AboutPage(),
    'SettingsPage': () => const SettingsPage(),
    'LibraryPage': () => const LibraryPage(),
    'WorkbenchPage': () => const WorkbenchPage(),
  };

  /// Labels allowed to truncate, with the reason each one is content
  /// rather than chrome.
  ///
  /// Deliberately tiny, and every entry is a decision rather than a
  /// convenience: the point of this file is that a clipped label is a
  /// defect until somebody argues otherwise in writing.
  bool allowed(String text) {
      // A verse is prose and belongs to the reader; a pane showing two
      // lines of Genesis 1:1 and an ellipsis is reading, not clipping.
      return text.contains('seed 1') || text.contains('seed 2');
  }

  Future<List<String>> clippedOn(
      WidgetTester tester, Widget page, Size size) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = AppSettings();
    // Both sliders at maximum. `chrome_scale`-style caps and clamps mean
    // this is not simply "bigger everywhere" — it is the one corner where
    // every fixed-size piece of chrome is as large as it can get.
    await settings.setMenuScale(1.5);
    await settings.setFontSize(40);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => MainProvider()
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
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));

    // `allRenderObjects` rather than a walk from the binding's root:
    // `renderViewElement` is deprecated, and CI analyses with infos
    // fatal, so the walk that read best locally failed the build.
    // A Set: `allRenderObjects` reaches the same paragraph through more
    // than one root, so a clipped label would otherwise be named twice in
    // the failure message.
    final out = <String>{};
    for (final o in tester.allRenderObjects) {
      if (o is RenderParagraph &&
          o.hasSize &&
          o.maxLines == 1 &&
          o.overflow == TextOverflow.ellipsis) {
        final text = o.text.toPlainText();
        final short = o.getMaxIntrinsicWidth(double.infinity) - o.size.width;
        if (short > 0.5 && !allowed(text)) {
          out.add('"$text" short by ${short.toStringAsFixed(1)}px');
        }
      }
    }
    // Drained before the tree goes: `AppSettings` debounces its notify
    // behind a timer the widget tree outlives, and the binding's
    // pending-timer guard would otherwise fail every case here for a
    // reason that has nothing to do with a label.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 700));
    return out.toList();
  }

  for (final page in pages.entries) {
    for (final size in sizes.entries) {
      testWidgets('${page.key} deletes no words at ${size.key}, both '
          'sliders at maximum', (tester) async {
        addTearDown(tester.view.reset);
        final bad = await clippedOn(tester, page.value(), size.value);
        expect(bad, isEmpty,
            reason: 'ellipsised on ${size.key}: ${bad.join(", ")}. An '
                'ellipsis is not an overflow — the layout succeeded and '
                'the reader lost the words.');
      });
    }
  }

  testWidgets('the measurement can fail — a label given no room is caught',
      (tester) async {
    // Without this, a change that stopped the walk from reaching anything
    // (a renamed binding field, a page that renders a spinner at these
    // sizes) would turn every case above green while measuring nothing.
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 20,
          child: Text('a label with far more words than twenty pixels',
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    ));
    await tester.pump();

    final found = <String>[
      for (final o in tester.allRenderObjects)
        if (o is RenderParagraph &&
            o.hasSize &&
            o.maxLines == 1 &&
            o.overflow == TextOverflow.ellipsis &&
            o.getMaxIntrinsicWidth(double.infinity) - o.size.width > 0.5)
          o.text.toPlainText(),
    ];
    expect(found.toSet(), hasLength(1),
        reason: 'the walk above no longer finds a clipped label even when '
            'one is put in front of it');
  });
}
