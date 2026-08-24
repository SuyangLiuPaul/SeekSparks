// 2026-08-24 (#315): the sermon reader obeys the Font Size slider, and
// its own title stays above the text it heads.
//
// This page is the sharpest form of the ticket, because the defect here
// was not that a size failed to grow — it was that a size CHANGED RANK.
// The body is `settings.fontSize`; the title was the literal 22. At the
// default 20 pt that made the title the largest text on the page, which
// is the design. From 23 pt on — stop 12 of the slider's 29 — the title
// was SMALLER than the sermon it introduced, and by 40 pt it was just
// over half its size.
//
// Every other frozen size on the page distorted rather than inverted,
// which is the same defect measured differently: the condensed-sermon
// notice was designed at 13 against a 20 px body (1.54× contrast) and
// rendered at 13 against a 40 px body (3.08×). That notice is the line
// telling the reader the transcript below is abridged rather than the
// preaching — the one sentence a reader who raised the slider because
// they cannot see small text most needs to be able to read.
//
// Measured, not asserted from source: a source ratchet can prove a size
// is not a literal; only a pumped page can prove it moves, and only a
// pumped page can compare two sizes that are written in different files.
//
// `_MetaChip`, `_LanguageToggle` and `_CondensedNotice` are private, so
// they are reached the only way a reader reaches them — by building the
// page.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/sermon_credit.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/sermon.dart';
import 'package:seeksparks/pages/sermon_detail_page.dart';
import 'package:seeksparks/providers/main_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sermon = Sermon(
    id: '004',
    topic: 'Baptism',
    topicSlug: 'baptism',
    date: '1979-04-08',
    parts: '',
    passage: 'Luke 4:5-13',
    title: 'Temptation after baptism',
    titles: {'en': 'Temptation after baptism'},
    hasEn: true,
    hasZhCn: false,
    hasZhTw: false,
  );

  // The locale the last pump resolved to. `AppSettings` picks it up
  // from the platform, so the byline is looked up rather than typed —
  // the credit reads "Pastor Eric H.H. Chang" in English and 张熙和牧师
  // in Chinese, and `sermon_credit_test.dart` fails the build on a
  // second spelling of either.
  var locale = 'en';

  /// Every painted size on the page, keyed by the string it painted.
  ///
  /// A `Text` resolves into a `RichText` whose root style carries the
  /// size actually used, so this reads what the tree produced rather
  /// than what some `TextStyle` in the source says.
  Future<Map<String, double>> sizesAt(WidgetTester tester, double fontSize,
      {Size viewport = const Size(1280, 900)}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = viewport;
    addTearDown(tester.view.reset);

    final settings = AppSettings();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider<AppSettings>.value(value: settings),
        ],
        child: const MaterialApp(home: SermonDetailPage(sermon: sermon)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    settings.setFontSize(fontSize);
    // MaterialApp wraps its theme in an AnimatedTheme, so a single pump
    // reads the tree mid-lerp. Settle past the transition before
    // measuring — this trap reported a working fix as broken once
    // already (see `theme_font_size_behaviour_test.dart`).
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
    locale = settings.locale;

    final out = <String, double>{};
    for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
      final label = w.text.toPlainText();
      final size = w.text.style?.fontSize;
      if (label.trim().isEmpty || size == null) continue;
      out[label] = size;
    }
    return out;
  }

  double sizeOf(Map<String, double> m, String needle) {
    for (final e in m.entries) {
      if (e.key.contains(needle)) return e.value;
    }
    fail('no painted text containing "$needle" — page rendered '
        '${m.keys.toList()}');
  }

  testWidgets('the sermon title never falls below the sermon', (tester) async {
    // The rank claim, at both ends and at the stop where the old
    // literal crossed over. 22 was above the body at 20 pt and below it
    // from 23 on, so 24 is the cheapest witness to the inversion.
    for (final pt in <double>[12, 20, 24, 40]) {
      final m = await sizesAt(tester, pt);
      final title = sizeOf(m, 'Temptation after baptism');
      expect(title, greaterThanOrEqualTo(pt),
          reason: 'at $pt pt the title is $title px, under a body of $pt');
    }
  });

  testWidgets('the byline and the title both travel', (tester) async {
    final small = await sizesAt(tester, 12);
    final mid = await sizesAt(tester, 20);
    final big = await sizesAt(tester, 40);

    // The default is untouched: a repair a reader can see is a
    // redesign, and this is not one.
    expect(sizeOf(mid, 'Temptation after baptism'), 22.0);
    expect(sizeOf(mid, preacherName(locale)), 13.0);

    // The top of the slider is where the defect lived. 40/20 = 2×.
    expect(sizeOf(big, 'Temptation after baptism'), 44.0);
    expect(sizeOf(big, preacherName(locale)), 26.0);

    // The bottom floors the byline rather than letting small print stop
    // being print: 13 × 0.6 is 7.8, and the floor is 11.
    expect(sizeOf(small, 'Temptation after baptism'), closeTo(13.2, 0.01));
    expect(sizeOf(small, preacherName(locale)), WbMetrics.smallPrintFloor);
  });

  testWidgets('the metadata chips travel too', (tester) async {
    // `#004` is a `_MetaChip`, the private widget that held 11.5.
    final mid = await sizesAt(tester, 20);
    final big = await sizesAt(tester, 40);
    expect(sizeOf(mid, '#004'), 11.5);
    expect(sizeOf(big, '#004'), 23.0);
  });

  // Doubling a size is only a repair if what it grew into still fits.
  // The three tests above prove the numbers moved and would pass just as
  // happily on a page overflowing by 40 px, because an overflow is
  // painted, not measured — so it is asserted here separately.
  //
  // The narrow end of the sweep is 1000, not 320: `SmallScreenGate`
  // admits only widths >= 992, so a page pumped narrower than that is a
  // layout no reader can reach and a failure there would be a false one.
  testWidgets('nothing overflows at any width the app admits',
      (tester) async {
    // Confirmed to fire: at 120 px this same sweep reports "A RenderFlex
    // overflowed by 24 pixels on the right".
    for (final w in <double>[1000, 1280, 1600]) {
      for (final pt in <double>[12, 20, 40]) {
        await sizesAt(tester, pt, viewport: Size(w, 800));
        expect(tester.takeException(), isNull,
            reason: 'the sermon page overflows at ${w}x800 at $pt pt');
      }
    }
  });
}
