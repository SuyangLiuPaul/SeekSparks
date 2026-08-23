// 2026-08-24 (#315): the behavioural half of the Font Size work.
//
// `font_size_reach_ratchet_test.dart` next door reads SOURCE. It can
// prove a size is not a literal, not a deaf Material role and not a
// saturated clamp — but it cannot prove the size MOVES, and moving is
// the entire complaint. Its own header says a widget test is useless
// here, and for a single `TextStyle` assertion that is true: the number
// is real whatever its provenance. A DELTA across two slider positions
// is a different instrument, and it is the one that answers the report.
//
// So: pump the real reader, drive the two sliders, and read back the
// sizes the widget tree resolved.
//
// Reach of this file, stated up front because it is small. The pane
// renders a spinner until MainProvider has data — which is why the
// responsive smoke test skips it — so it is pumped with two seeded
// verses. That state shows exactly five sized labels: the verse bodies,
// the verse numbers, the chapter reference, the version chip and the
// scroll-progress counter. The reader's sheets, popups, section
// headings and intro cards are NOT reachable this way and are covered
// only by the source ratchet. This file proves the five, not the file.
//
// Run against the commit before the repair, exactly one of the three
// tests below fails — 'the persistent bar does not shrink', at 12.0
// against an expected 19.0. The other two passed already and are
// characterisation, kept because they pin the proportionality that #311
// bought and that a future clamp could quietly take back.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/widgets/bible_reading_pane.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppSettings> pumpReader(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.reset);

    late AppSettings settings;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) {
            final mp = MainProvider();
            mp.setVerses(const [
              Verse(book: 'Genesis', chapter: 1, verse: 1, text: 'seed 1'),
              Verse(book: 'Genesis', chapter: 1, verse: 2, text: 'seed 2'),
            ]);
            mp.setCurrentChapter(book: 'Genesis', chapter: 1);
            return mp;
          }),
          ChangeNotifierProvider(create: (_) {
            settings = AppSettings();
            return settings;
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: BibleReadingPane())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);
    return settings;
  }

  // Both `Text` and `RichText` are read: the verse body is a span tree,
  // and a `Text` resolves into a `RichText` whose root style carries the
  // size actually used. Keyed by plain text, which is unique enough in
  // the seeded chapter.
  Map<String, double> sizes(WidgetTester tester) {
    final out = <String, double>{};
    for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
      final label = w.text.toPlainText();
      final size = w.text.style?.fontSize;
      if (label.trim().isEmpty || size == null) continue;
      out[label] = size;
    }
    return out;
  }

  // The 600 ms settings debounce leaves a pending timer if the tree is
  // torn down inside it, so every drag pumps past it.
  Future<Map<String, double>> at(
    WidgetTester tester,
    AppSettings settings,
    double fontSize,
  ) async {
    settings.setFontSize(fontSize);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 700));
    return sizes(tester);
  }

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 700));
  }

  const verseBody = '￼seed 1 ￼seed 2';
  const verseNumber = '1';
  const chapterRef = 'Genesis 1';

  testWidgets('verse text and verse numbers are proportional to the slider '
      'across its whole range', (tester) async {
    final settings = await pumpReader(tester);

    final low = await at(tester, settings, kFontSizeMin);
    final mid = await at(tester, settings, kFontSizeDefault);
    final high = await at(tester, settings, kFontSizeMax);

    // #315 turned 41 literals into scaled sizes, and a literal could not
    // overflow because it never grew. At 40 pt they are twice their
    // design value, so the top of the slider is where new RenderFlex
    // overflows would appear. Only the pane's own surface is covered —
    // its sheets and popups need live data to open.
    expect(tester.takeException(), isNull,
        reason: 'the reader overflowed somewhere between the bottom and '
            'the top of the Font Size slider');

    for (final label in [verseBody, verseNumber]) {
      final l = low[label], m = mid[label], h = high[label];
      expect(l, isNotNull, reason: '$label not rendered at $kFontSizeMin pt');
      expect(m, isNotNull, reason: '$label not rendered at $kFontSizeDefault');
      expect(h, isNotNull, reason: '$label not rendered at $kFontSizeMax pt');

      // Same size-per-point at all three stops: no ceiling, no floor,
      // no dead zone anywhere in between.
      expect(l! / kFontSizeMin, closeTo(m! / kFontSizeDefault, 1e-9),
          reason: '$label is not proportional between the bottom of the '
              'slider and its default');
      expect(h! / kFontSizeMax, closeTo(m / kFontSizeDefault, 1e-9),
          reason: '$label stops growing before the top of the slider — a '
              'ceiling inside the range the reader can reach');
    }

    await disposeTree(tester);
  });

  // The report was two photographs taken at the BOTTOM of the slider,
  // 「这些字很难看清楚」 — hard to make out. Before #315 the chapter
  // reference in the persistent bar was
  // `(fontSize.clamp(12, 19) * menuScale)`, so dragging Font Size to 12
  // pt shrank the bar's own label to 12 px along with the body text the
  // reader was trying to shrink. Chrome is not body text: it is the
  // furniture you navigate by, and it has no business following the
  // reading size down.
  testWidgets('the persistent bar does not shrink with the reading size',
      (tester) async {
    final settings = await pumpReader(tester);

    final low = await at(tester, settings, kFontSizeMin);
    final mid = await at(tester, settings, kFontSizeDefault);
    final high = await at(tester, settings, kFontSizeMax);

    expect(low[chapterRef], isNotNull);
    expect(low[chapterRef], mid[chapterRef],
        reason: 'the chapter reference shrank when the reader shrank the '
            'body text — the #315 photograph, exactly');
    expect(high[chapterRef], mid[chapterRef],
        reason: 'the chapter reference grew with the body text, which is '
            'new overflow risk in a bar that cannot wrap');

    await disposeTree(tester);
  });

  // Holding chrome off the Font Size slider is only defensible if the
  // reader has some other way to enlarge it. That way is Menu Scale, and
  // this asserts the travel is real rather than nominal.
  testWidgets('the persistent bar tracks Menu Scale instead',
      (tester) async {
    final settings = await pumpReader(tester);

    final base = sizes(tester)[chapterRef];
    expect(base, isNotNull);

    await settings.setMenuScale(kMenuScaleMax);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 700));

    expect(sizes(tester)[chapterRef], closeTo(base! * kMenuScaleMax, 1e-9),
        reason: 'chrome is off the Font Size slider, so Menu Scale is the '
            'only control it has left; it must actually move it');

    await disposeTree(tester);
  });
}
