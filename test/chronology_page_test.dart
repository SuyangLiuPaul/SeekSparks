/// The chronology chart, mounted against the real asset.
///
/// `chronology_test.dart` pins the arithmetic and the asset. What that
/// cannot catch is the thing this page is most likely to get wrong, and
/// did: the name lane is the only place in the app where a label is
/// deliberately **not** ellipsised (a CJK name cut mid-character is
/// unreadable, #297), so a lane too narrow for its text does not clip and
/// does not throw — it paints the name straight across the bars. A
/// suite that only asserts "no exception" passes happily through that.
///
/// Rendered in the app's shipped default (zh-Hans), for the same reason
/// `atlas_page_test.dart` and `hebrew_kings_test.dart` are:
/// `AppSettings.setLocale` leaves a notification-rescheduling timer
/// pending that fails teardown.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/chronology.dart';
import 'package:seeksparks/pages/chronology_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/chronology_service.dart';
import 'package:seeksparks/utils/version_mapper.dart'
    show localizedReferenceLabel;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChronologyData data;
  setUpAll(() async {
    data = await ChronologyService.instance.load();
  });

  Future<AppSettings> pump(WidgetTester tester, Size size) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    final settings = AppSettings();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: const MaterialApp(home: ChronologyPage()),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return settings;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('opens on the Hebrew figures, every generation on one axis',
      (tester) async {
    await pump(tester, const Size(1440, 900));
    expect(tester.takeException(), isNull);

    // 19 in the Masoretic list, and the chart draws all of them rather
    // than a first screenful — the whole point is comparing lives that
    // are twenty rows apart.
    for (final p in data.inTradition('mt')) {
      expect(find.text(p.nameFor('zh-Hans')), findsOneWidget,
          reason: p.id);
    }
    // The flood is the one dated event on the chart, and its year is
    // stated rather than left to be read off the axis.
    expect(find.textContaining('1656'), findsWidgets);

    await unmount(tester);
  });

  testWidgets('switching to the Greek text adds Kainan and moves the flood',
      (tester) async {
    await pump(tester, const Size(1440, 900));

    // Kainan stands in the Septuagint's Genesis 11 and not the Hebrew's,
    // so he is the visible tell that the switch changed the source and
    // not just the scale. He shares a name with Genesis 5's Cainan —
    // 该南 in the CUV for both, and the very resemblance that makes his
    // presence in Genesis 11 a textual crux — so the count goes from one
    // to two rather than from none to one. The two are told apart by the
    // line colour, by 1,754 years of axis, and by the verse each figure
    // carries in the panel.
    expect(find.text('该南'), findsOneWidget);

    await tester.tap(find.text('七十士'));
    await settle(tester);
    expect(tester.takeException(), isNull);

    expect(find.text('该南'), findsNWidgets(2));
    expect(find.textContaining('2242'), findsWidgets);

    await unmount(tester);
  });

  testWidgets('selecting a man opens his figures with the verses they came '
      'from', (tester) async {
    await pump(tester, const Size(1440, 900));

    await tester.tap(find.text('玛土撒拉'));
    await settle(tester);
    expect(tester.takeException(), isNull);

    // 187 / 782 / 969 are Genesis 5:25-27. Each is shown beside the
    // verse it was read from, because a number without its verse is an
    // assertion and a number with one is a citation.
    //
    // In the reader's own script. The refs are stored English because
    // that is what `parseReference` takes back when the citation is
    // tapped; what is PRINTED goes through the same localiser as every
    // other reference in the app. This page used to print the stored
    // form, so a Chinese reader got 创世纪 in the prose of a note and
    // `Genesis 5:25` in the citation directly under it.
    expect(find.textContaining('187'), findsWidgets);
    expect(find.text('创世纪 5:25'), findsOneWidget);
    expect(find.text('创世纪 5:27'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('a narrow viewport keeps the chart and sheds the panel',
      (tester) async {
    await pump(tester, const Size(820, 900));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('玛土撒拉'));
    await settle(tester);
    expect(tester.takeException(), isNull);

    // Below the threshold the detail arrives as a sheet, so the chart
    // never gets squeezed under a strip of bars too narrow to read.
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);

    await tester.tap(find.byTooltip('关闭'));
    await settle(tester);
    await unmount(tester);
  });

  testWidgets('Joseph shows only the figure the text gives him',
      (tester) async {
    await pump(tester, const Size(1440, 900));

    await tester.dragUntilVisible(find.text('约瑟'),
        find.byType(Scrollable).first, const Offset(0, -80));
    await settle(tester);
    await tester.tap(find.text('约瑟'));
    await settle(tester);
    expect(tester.takeException(), isNull);

    expect(find.text('创世纪 50:26'), findsOneWidget);
    // He ends the chain, so there is no age at begetting and no "lived
    // after that". An empty row would say the text was asked and stayed
    // silent; no row says the question does not arise.
    expect(find.text('生下一代时的年岁'), findsNothing);
    expect(find.text('此后又活了'), findsNothing);

    await unmount(tester);
  });

  // A caveat about one man belongs where a reader looking at that man
  // is. The header is a layout sibling of the chart rather than an
  // overlay, so printing these there too costs chart height — with the
  // axis carried to Moses there are six of them, and six paragraphs
  // would push the bars they are about off the screen. So the header
  // names the man and his panel carries the words.
  testWidgets('the Terah/Abram conflict is on Abraham\'s own panel, and the '
      'header only points at it', (tester) async {
    await pump(tester, const Size(1440, 900));

    final note = data
        .notesForPerson('mt', 'abraham')
        .firstWhere((n) => n.id == 'abram_birth')
        .textFor('zh-Hans');
    // Nobody selected: the words are nowhere, but his name is offered.
    expect(find.text(note), findsNothing);
    expect(
        find.textContaining('亚伯拉罕', findRichText: true), findsWidgets);

    await tester.tap(find.text('亚伯拉罕'));
    await settle(tester);
    expect(tester.takeException(), isNull);

    expect(find.text(note), findsOneWidget);

    await unmount(tester);
  });

  // The flood's second dating lives in the asset, and the asset carrying
  // it is not the same claim as a reader being able to read it — the
  // epoch notes shipped for eight months with no call site at all. So
  // this pins the rendered path, and pins that Noah is named in the
  // header where a reader who has selected nobody will see that there is
  // something to open.
  testWidgets('the flood\'s second dating is on Noah\'s panel, and the header '
      'names him', (tester) async {
    await pump(tester, const Size(1440, 900));

    final note = data
        .notesForPerson('mt', 'noah')
        .firstWhere((n) => n.id == 'flood_two_datings')
        .textFor('zh-Hans');
    expect(find.text(note), findsNothing);
    expect(find.textContaining('挪亚', findRichText: true), findsWidgets);

    await tester.tap(find.text('挪亚'));
    await settle(tester);
    expect(tester.takeException(), isNull);

    expect(find.text(note), findsOneWidget);
    // The whole point of the sentence is the pair of years; a panel that
    // showed the note but clipped it to one of them would pass a
    // findsOneWidget on the string and still tell the reader nothing.
    expect(note, contains('1656'));
    expect(note, contains('1655'));

    await unmount(tester);
  });

  // Every epoch carries a `note` saying how its verse yields its year —
  // the derivation the whole chart rests on — and until this was written
  // `ChronologyEpoch.noteFor` had no call site in `lib/` at all. The
  // paragraphs were built, translated into three scripts, shipped in the
  // asset, and unreachable. `find.text(note)` on every one of them is
  // the assertion that would have caught it.
  testWidgets('every epoch opens, and its derivation is on the sheet',
      (tester) async {
    for (final epoch in data.epochs) {
      await pump(tester, const Size(1440, 900));
      final note = epoch.noteFor('zh-Hans')!;
      expect(note, isNotEmpty, reason: epoch.id);

      // Not on the page until it is asked for: the header is a layout
      // sibling of the chart, so five paragraphs there would cost five
      // rows of the bars they are about.
      expect(find.text(note), findsNothing, reason: epoch.id);

      await tester.tap(find.byKey(ValueKey('chronologyEpoch_${epoch.id}')));
      await settle(tester);
      expect(tester.takeException(), isNull, reason: epoch.id);

      expect(find.text(note), findsOneWidget, reason: epoch.id);
      // And the verse it was read from, in the reader's script.
      if (epoch.ref != null) {
        expect(find.text(localizedReferenceLabel(epoch.ref!, 'zh-Hans')),
            findsWidgets,
            reason: epoch.id);
      }

      await unmount(tester);
    }
  });

  // The sheet's reason for existing beyond the note: the year is this
  // reconstruction's, not the text's, and the two texts disagree by
  // amounts that are the single most surprising thing on the chart.
  // Both figures are derived here from the asset rather than typed, so a
  // regenerated asset that moved a date fails this instead of quietly
  // disagreeing with a literal.
  testWidgets('an epoch sheet shows both texts and the gap between them',
      (tester) async {
    await pump(tester, const Size(1440, 900));

    final flood = data.epochs.firstWhere((e) => e.id == 'flood');
    final mt = flood.years['mt']!;
    final lxx = flood.years['lxx']!;
    expect(mt, isNot(lxx));

    await tester.tap(find.byKey(const ValueKey('chronologyEpoch_flood')));
    await settle(tester);
    expect(tester.takeException(), isNull);

    final am = uiStrings['chronologyAm']!['zh-Hans']!;
    expect(find.text('$am $mt'), findsWidgets);
    expect(find.text('$am $lxx'), findsWidgets);
    expect(
        find.text(uiStrings['chronologyEpochApart']!['zh-Hans']!
            .replaceAll('{n}', '${(mt - lxx).abs()}')),
        findsOneWidget);

    await unmount(tester);
  });

  // Moses has no age at begetting and no years after it — the chart ends
  // on him — so the sentence about "all three figures" would be
  // describing a record he has not got.
  testWidgets('Moses is not told he has three figures', (tester) async {
    await pump(tester, const Size(1440, 900));

    await tester.dragUntilVisible(find.text('摩西'),
        find.byType(Scrollable).first, const Offset(0, -80));
    await settle(tester);
    await tester.tap(find.text('摩西'));
    await settle(tester);
    expect(tester.takeException(), isNull);

    expect(find.text('申命记 34:7'), findsOneWidget);
    expect(find.text('生下一代时的年岁'), findsNothing);
    expect(find.textContaining('三个数字'), findsNothing);

    await unmount(tester);
  });

  // The axis strip holds three rows of un-ellipsised text — two of epoch
  // names and one of years — and it is a CustomPaint, so an overrun
  // neither throws nor clips visibly in a test. Only the measurement
  // catches it, and the strip is on the chrome slider, which moves
  // independently of the font slider measured below.
  testWidgets('the axis strip holds its three rows at every menu scale',
      (tester) async {
    for (final scale in [0.7, 1.0, 1.5]) {
      final settings = await pump(tester, const Size(1440, 900));
      await settings.setMenuScale(scale);
      await settle(tester);
      expect(tester.takeException(), isNull, reason: '$scale');

      final strip = tester.getSize(find.byKey(const ValueKey('chronologyAxis')));
      final probe = TextPainter(
        text: TextSpan(
          text: '下埃及 2238',
          style: TextStyle(fontSize: 10 * scale),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      expect(strip.height, greaterThanOrEqualTo(probe.height * 3),
          reason: 'menu scale $scale');
      await unmount(tester);
    }
  });

  // The regression this file exists for. `_nameLane` used to be a fixed
  // 132 px while the name inside it is drawn at `t.text`, which the font
  // slider scales from 0.6× to 2×. At 40 pt the label outgrew the lane
  // and, being un-ellipsised on purpose, painted over the bars. Nothing
  // threw, so only a measurement catches it.
  testWidgets('the name lane holds the longest name at every font size',
      (tester) async {
    for (final fontSize in [12.0, 20.0, 40.0]) {
      final settings = await pump(tester, const Size(1440, 900));
      settings.setFontSize(fontSize);
      await settle(tester);
      expect(tester.takeException(), isNull, reason: '$fontSize pt');

      final names = {
        for (final p in data.inTradition('mt')) p.nameFor('zh-Hans')
      };
      var measured = 0;
      for (final para
          in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
        if (!names.contains(para.text.toPlainText())) continue;
        measured++;
        // `size` is what the lane grants; the intrinsic width is what
        // the glyphs actually need on one line.
        expect(para.getMaxIntrinsicWidth(double.infinity),
            lessThanOrEqualTo(para.size.width),
            reason: '"${para.text.toPlainText()}" at $fontSize pt');
      }
      expect(measured, names.length, reason: '$fontSize pt');
      await unmount(tester);
    }
  });

  // Measured above in Chinese, whose glyphs the test font advances by a
  // full em exactly as a real CJK face does. It gives Latin a full em
  // too, which is about twice a real proportional face, so the English
  // names are not asserted in absolute pixels. What makes one size
  // enough for them is this: the lane is a fixed multiple of the text it
  // holds, so if a name fits at one setting it fits at all of them.
  testWidgets('the lane tracks the text across the whole slider',
      (tester) async {
    final perEm = <double, double>{};
    for (final fontSize in [12.0, 20.0, 40.0]) {
      final settings = await pump(tester, const Size(1440, 900));
      settings.setFontSize(fontSize);
      await settle(tester);
      final para = tester
          .renderObjectList<RenderParagraph>(find.byType(RichText))
          .firstWhere((p) => p.text.toPlainText() == '玛土撒拉');
      // How many characters of the reader's own size the lane fits.
      perEm[fontSize] = para.size.width / (12.0 * (fontSize / 20.0));
      await unmount(tester);
    }
    // Not a constant: the lane's 8/6 px gutters are chrome and stay put
    // while the text moves, so the lane holds slightly fewer characters
    // at 12 pt than at 40. A narrow band is the claim — with a lane
    // fixed at 132 px this ratio ran from 16.4 down to 4.9, and the
    // margin measured at the default meant nothing at either end.
    final values = perEm.values.toList();
    expect(values.reduce((a, b) => a < b ? a : b), greaterThan(8.5));
    expect(values.reduce((a, b) => a > b ? a : b), lessThan(11.0));
    // 12 pt is the tightest end, which is where the English names — not
    // measurable here, see above — have the least room.
    expect(perEm[12.0]!, lessThan(perEm[40.0]!));
  });

  // THE LEDGER UNDER THE CHART.
  //
  // `chronology_test.dart` pins the era block in the asset. What it
  // cannot see is whether any of it reaches the screen — a ledger widget
  // that compiles and is never built looks identical from the asset's
  // side. It sits below Moses, the last bar, so every assertion here has
  // to scroll to it first, which is itself the check that a reader
  // running out of chart arrives at it rather than at nothing.
  Future<void> toLedger(WidgetTester tester, ChronologyEra era) async {
    await tester.dragUntilVisible(
      find.text(era.nameFor('zh-Hans')),
      find.byType(Scrollable).first,
      const Offset(0, -120),
    );
    await settle(tester);
  }

  testWidgets('the era is reachable below the last bar, with its totals',
      (tester) async {
    await pump(tester, const Size(1440, 900));
    final era = data.era!;
    await toLedger(tester, era);
    expect(tester.takeException(), isNull);

    // 530 counted, 479 stated, over by 51 — the three numbers the whole
    // ledger exists to put side by side. Read off the asset rather than
    // typed, so this test measures the screen and not itself.
    expect(find.text('${era.counted['mt']}'), findsOneWidget);
    expect(find.text('${era.stated['mt']!.elapsed}'), findsOneWidget);
    expect(find.text('${era.residue['mt']}'), findsOneWidget);
    expect(find.text(localizedReferenceLabel(era.stated['mt']!.ref, 'zh-Hans')),
        findsWidgets);

    // Every period is named and carries the verse it was read from.
    for (final p in era.periods) {
      expect(find.text(p.nameFor('zh-Hans')), findsOneWidget, reason: p.id);
    }

    await unmount(tester);
  });

  // The two texts disagree at the total and at two of the twenty-one
  // rows, and the ledger is the only place that disagreement is visible.
  // A ledger that showed the Hebrew figures under a Greek heading would
  // be the worst kind of wrong here: plausible and silent.
  testWidgets('switching to the Greek text moves the whole ledger',
      (tester) async {
    await pump(tester, const Size(1440, 900));
    final era = data.era!;

    await tester.tap(find.text('七十士'));
    await settle(tester);
    await toLedger(tester, era);
    expect(tester.takeException(), isNull);

    expect(find.text('${era.counted['lxx']}'), findsOneWidget);
    expect(find.text('${era.stated['lxx']!.elapsed}'), findsOneWidget);
    expect(find.text('${era.residue['lxx']}'), findsOneWidget);
    // 51 belongs to the Hebrew and must not survive the switch.
    expect(find.text('${era.residue['mt']}'), findsNothing);

    await unmount(tester);
  });

  // The other text's figure is printed on the rows where the texts
  // differ and nowhere else. Nineteen redundant asides would bury the
  // two that matter, and an aside on a row where both texts agree would
  // manufacture a disagreement.
  testWidgets('only the split rows carry the other text\'s figure',
      (tester) async {
    await pump(tester, const Size(1440, 900));
    final era = data.era!;
    await toLedger(tester, era);

    final aside = uiStrings['chronologyEraOtherText']!['zh-Hans']!;
    expect(find.textContaining(aside), findsNWidgets(era.splitIds.length));
    for (final id in era.splitIds) {
      final p = era.periods.firstWhere((e) => e.id == id);
      expect(find.text('$aside ${p.years['lxx']}'), findsOneWidget,
          reason: id);
    }

    await unmount(tester);
  });

  // The Greek reads its one total across two of the edition's own
  // verses: the 440th year in 6:1, the founding it is measured to in
  // 6:1c. The header note says so in prose, but this is the row that
  // prints the figure, and a reader who opens the Greek at the cited
  // 1 Kings 6:1 meets a date and no temple. Without the aside the
  // ledger looks like it supplied the temple itself. The Hebrew states
  // both in one clause and must not carry the aside, or the app would
  // be reporting a split that text does not have.
  testWidgets('the founding\'s own verse is named on the Greek total only',
      (tester) async {
    await pump(tester, const Size(1440, 900));
    final era = data.era!;
    final label = uiStrings['chronologyEraFoundingAt']!['zh-Hans']!;

    final note =
        data.notes.firstWhere((n) => n.id == 'era_join').textFor('zh-Hans');

    await toLedger(tester, era);
    expect(era.stated['mt']!.joined, isFalse);
    expect(find.textContaining(label), findsNothing);
    expect(find.text(note), findsNothing);

    await tester.tap(find.text('七十士'));
    await settle(tester);
    // The prose in the header and the aside on the row are two halves of
    // one disclosure. The header explains the split; the row says which
    // verse. Either alone leaves the reader with half the citation.
    expect(find.text(note), findsOneWidget);
    await toLedger(tester, era);
    expect(find.text('$label ${era.stated['lxx']!.foundingAt}'),
        findsOneWidget);

    await unmount(tester);
  });

  // The figures live in a set-width column so the ledger reads as a
  // column of numbers rather than a ragged list, and a column too narrow
  // for its widest figure would not throw — it would paint over the
  // label beside it. This is a floor, not a caught defect: run against a
  // column of 1.5 em it fails on 530 (14.9 needed, 10.8 granted), and
  // every width this file has ever shipped clears it. It is here so that
  // a later edit tightening the column has something to hit.
  testWidgets('the figure column holds three digits at every font size',
      (tester) async {
    final era = data.era!;
    final figures = {
      for (final p in era.periods) '${p.years['mt']}',
      '${era.counted['mt']}',
      '${era.stated['mt']!.elapsed}',
      '${era.residue['mt']}',
    };
    for (final fontSize in [12.0, 20.0, 40.0]) {
      final settings = await pump(tester, const Size(1440, 900));
      settings.setFontSize(fontSize);
      await settle(tester);
      await toLedger(tester, era);
      expect(tester.takeException(), isNull, reason: '$fontSize pt');

      final measured = <String>{};
      for (final para
          in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
        final plain = para.text.toPlainText();
        if (!figures.contains(plain)) continue;
        measured.add(plain);
        expect(para.getMaxIntrinsicWidth(double.infinity),
            lessThanOrEqualTo(para.size.width),
            reason: '"$plain" at $fontSize pt');
      }
      // 530 is the widest figure in the ledger, so a run that never saw
      // three digits proved nothing about the column.
      expect(measured, containsAll(figures), reason: '$fontSize pt');
      await unmount(tester);
    }
  });

  // The English that reaches a Chinese reader is never one defect, it is
  // a class, and grepping for one phrase finds one member of it. Pinning
  // `Genesis` would have passed over `data.unitNote` — the sentence that
  // keeps the axis from being read as a BC dating, printed in English on
  // this page and on the epoch sheets. So the assertion is on the shape:
  // no run of Latin letters in the rendered text at all.
  //
  // Ussher is the exception and stays one. A 17th-century Englishman's
  // surname has no CUV form, and transliterating it would make the one
  // citation on this page a reader might go and look up unlookup-able.
  testWidgets('no English prose survives into the Chinese page',
      (tester) async {
    const allowed = {'Ussher'};
    final latin = RegExp(r'[A-Za-z]{3,}');

    // A sweep over nothing passes. The counts are floors, not pins: what
    // they rule out is a finder that silently stopped matching, which
    // would turn this whole test into a green light for the defect.
    void sweep(String where, int atLeast) {
      var seen = 0;
      for (final para
          in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
        final plain = para.text.toPlainText();
        seen++;
        final found = latin
            .allMatches(plain)
            .map((m) => m.group(0)!)
            .where((w) => !allowed.contains(w))
            .toSet();
        expect(found, isEmpty, reason: '$where: "$plain"');
      }
      expect(seen, greaterThanOrEqualTo(atLeast), reason: where);
    }

    await pump(tester, const Size(1440, 900));
    sweep('the chart', 30);
    await toLedger(tester, data.era!);
    sweep('the era ledger', 30);
    await unmount(tester);

    // Moses' panel, because the longest note in the asset is on it —
    // the Exodus 6:18/6:20 ceiling — and it is the one that carried two
    // English citations in the middle of a Chinese paragraph.
    await pump(tester, const Size(1440, 900));
    await tester.dragUntilVisible(find.text('摩西'),
        find.byType(Scrollable).first, const Offset(0, -80));
    await settle(tester);
    await tester.tap(find.text('摩西'));
    await settle(tester);
    sweep('Moses\' panel', 30);
    await unmount(tester);

    for (final epoch in data.epochs) {
      await pump(tester, const Size(1440, 900));
      await tester.tap(find.byKey(ValueKey('chronologyEpoch_${epoch.id}')));
      await settle(tester);
      sweep('the ${epoch.id} sheet', 30);
      await unmount(tester);
    }

    // The provenance sheet is the longest continuous prose the module
    // has, and it scrolls — one screenful holds about two of its seven
    // paragraphs, so a sweep that did not scroll would clear the title
    // and miss every sentence the sheet exists to show.
    await pump(tester, const Size(1440, 900));
    await tester.tap(find.byKey(const ValueKey('chronologyProvenance')));
    await settle(tester);
    for (var i = 0; i < 8; i++) {
      sweep('the provenance sheet', 8);
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -260));
      await settle(tester);
    }
    await unmount(tester);
  });

  // #318 phase 9. Every sentence on this sheet was generated into the
  // asset on the day the module shipped and NOTHING IN lib/ READ ANY OF
  // THEM: which editions the figures were read out of, what "checked"
  // means, how far the two texts diverge, that a separately built
  // artefact agrees. A chart of dates is the most persuasive thing this
  // app draws and the answer to "how do you know" was in the file and
  // not on the screen. This is a call-site guard, not a wording one: it
  // asserts each string reaches a pixel, so the block cannot quietly go
  // back to being unreachable.
  testWidgets('the provenance sheet renders every sentence the asset carries',
      (tester) async {
    const locale = 'zh-Hans';
    final p = data.provenance;
    final expected = <String>{
      p.traditionsNoteFor(locale),
      p.checksNoteFor(locale),
      p.secondWitnessFor(locale),
      p.traditionAgreementFor(locale),
      for (final tr in data.traditions) p.sourceFor(tr.id, locale),
      uiStrings['chronologyProvenanceSums']![locale]!
          .replaceAll('{n}', '${p.sumsChecked}'),
      // Printed even at nought. A line that appears only on failure
      // tells a reader nothing on the run where it is absent.
      uiStrings['chronologyProvenanceDisagreements']![locale]!
          .replaceAll('{n}', '${p.disagreements.length}'),
      data.unitNoteFor(locale),
    };
    expect(expected.length, 9);

    await pump(tester, const Size(1440, 900));
    await tester.tap(find.byKey(const ValueKey('chronologyProvenance')));
    await settle(tester);
    expect(tester.takeException(), isNull);

    final seen = <String>{};
    for (var i = 0; i < 10; i++) {
      for (final para
          in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
        seen.add(para.text.toPlainText());
      }
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -260));
      await settle(tester);
    }
    for (final s in expected) {
      expect(seen, contains(s),
          reason: s.substring(0, s.length < 14 ? s.length : 14));
    }
    await unmount(tester);
  });

  // The sheet, not the side panel. `_DetailPanel` is keyed on the
  // selected man so that his band can be drawn across the rows; handing
  // it an epoch or this sheet would silently drop whoever the reader was
  // comparing. Opening provenance while a man is selected must leave him
  // selected and his panel intact underneath.
  testWidgets('provenance opens over the chart without dropping a selection',
      (tester) async {
    final noah = data.byId('noah')!;
    // The verse his lifespan was read out of is printed on his panel and
    // nowhere else, so it stands in for "the panel is open on Noah" —
    // and it is asserted absent first, or the last assertion here would
    // pass on a page that never had a panel at all.
    final ref = localizedReferenceLabel(
        noah.figures['mt']!.refs['lifespan']!, 'zh-Hans');

    await pump(tester, const Size(1440, 900));
    expect(find.text(ref), findsNothing);
    await tester.tap(find.text(noah.nameFor('zh-Hans')));
    await settle(tester);
    expect(find.text(ref), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('chronologyProvenance')));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text(data.provenance.traditionsNoteFor('zh-Hans')),
        findsOneWidget);

    await tester.tapAt(const Offset(20, 20));
    await settle(tester);
    expect(find.text(ref), findsWidgets,
        reason: 'the provenance sheet took the selection with it');
    await unmount(tester);
  });

  // Every reference in this asset is stored English, because that is
  // what `parseReference` reads when the citation is tapped, and every
  // one is printed through `localizedReferenceLabel`. A book the
  // localiser does not know passes through unchanged, silently, and the
  // reader gets one English word in a Chinese sentence — which is
  // exactly what this page did on every citation it printed. So the
  // guard is on the data, not on one rendered screen: a later slice that
  // cites a tenth book gets told here rather than in a screenshot.
  test('every reference in the asset localises', () {
    final refs = <String>{};
    for (final tr in data.traditions) {
      for (final p in data.inTradition(tr.id)) {
        p.figures[tr.id]?.refs.forEach((_, v) => refs.add(v));
      }
    }
    for (final e in data.epochs) {
      if (e.ref != null) refs.add(e.ref!);
    }
    final era = data.era!;
    for (final p in era.periods) {
      refs.add(p.ref);
    }
    for (final g in era.gaps) {
      refs.add(g.ref);
    }
    refs.add(era.stated['mt']!.ref);
    refs.add(era.stated['lxx']!.ref);

    // A sweep over an empty set passes. 85 is what the asset holds now;
    // the assertion is that the sweep saw a corpus, not that it saw
    // exactly this one.
    expect(refs.length, greaterThan(50));
    for (final locale in ['zh-Hans', 'zh-Hant']) {
      for (final ref in refs) {
        expect(localizedReferenceLabel(ref, locale), isNot(ref),
            reason: '$ref in $locale');
      }
    }
  });
}
