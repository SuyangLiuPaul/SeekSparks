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

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/chronology.dart';
import 'package:seeksparks/pages/chronology_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/chronology_service.dart';

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
    expect(find.textContaining('187'), findsWidgets);
    expect(find.text('Genesis 5:25'), findsOneWidget);
    expect(find.text('Genesis 5:27'), findsOneWidget);

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

    expect(find.text('Genesis 50:26'), findsOneWidget);
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

    expect(find.text('Deuteronomy 34:7'), findsOneWidget);
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
}
