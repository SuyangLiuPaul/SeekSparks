// 2026-08-09 (task #279): the Analysis pane's shared controls.
//
// The chrome assertions here are the same species as `wb_surfaces_test`
// — square corners, hairline borders, colours off the WbColors
// extension so all three palettes work.
//
// The one that is not about chrome is `does not overflow a 256 px pane`,
// and it is the reason this file exists. The five hand-copied chips this
// widget replaces put their label in a `Row(mainAxisSize: MainAxisSize
// .min)`, which hands non-flex children UNBOUNDED main-axis
// constraints. Three of the five also carried `overflow: TextOverflow
// .ellipsis`, so the source read as handled; it was inert, because
// ellipsis needs a bound to measure against. Measured before the fix, a
// phrase chip overflowed a 256 px pane by 402 px. The regression test is
// therefore NOT "the ellipsis property is set" — that property was set
// while the bug was live — but "render it narrow and no overflow is
// thrown".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/widgets/wb_pane_bits.dart';

void main() {
  // AppSettings is required: WbType.of() resolves the type scale from
  // the user's font-size / line-spacing settings.
  Widget host(Widget child, {bool paper = false, double? width}) =>
      ChangeNotifierProvider(
        create: (_) => AppSettings(),
        child: MaterialApp(
          theme:
              workbenchTheme(ThemeData.light(useMaterial3: true), paper: paper),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: width == null
                  ? child
                  : SizedBox(width: width, child: child),
            ),
          ),
        ),
      );

  BoxDecoration decorationOf(WidgetTester tester, Finder finder) {
    final container = tester.widget<Container>(
      find.descendant(of: finder, matching: find.byType(Container)).first,
    );
    return container.decoration! as BoxDecoration;
  }

  group('WbPaneChip', () {
    // The pane floor. 256 px is narrower than the 320 px advisory
    // minimum because the Analysis pane can be dragged below it while
    // the window stays wide.
    const paneWidth = 256.0;
    const longLabel =
        'in the beginning was the word and the word was with god';

    testWidgets('does not overflow a 256 px pane', (tester) async {
      await tester.pumpWidget(host(
        const Wrap(
          children: [
            WbPaneChip(label: longLabel, on: true, trailing: '1234'),
          ],
        ),
        width: paneWidth,
      ));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(WbPaneChip)).width,
          lessThanOrEqualTo(paneWidth));
    });

    testWidgets('keeps the count visible when the label is what gives',
        (tester) async {
      // The label ellipsises, the count does not: a chip that truncated
      // "1234" to "1…" would be worse than one with no count at all.
      await tester.pumpWidget(host(
        const Wrap(
          children: [
            WbPaneChip(label: longLabel, on: false, trailing: '1234'),
          ],
        ),
        width: paneWidth,
      ));
      expect(tester.takeException(), isNull);
      final count = tester.getSize(find.text('1234'));
      expect(count.width, greaterThan(0));
      expect(tester.getSize(find.text(longLabel)).width,
          lessThan(paneWidth));
    });

    testWidgets('is a square hairline box, filled only when on',
        (tester) async {
      await tester
          .pumpWidget(host(const WbPaneChip(label: 'aorist', on: true)));
      final on = decorationOf(tester, find.byType(WbPaneChip));
      expect(on.borderRadius, isNull, reason: 'square corners');
      expect(on.boxShadow, anyOf(isNull, isEmpty), reason: 'no shadows');
      expect(on.color, WbColors.light.selectionBg);
      expect((on.border! as Border).top.width, WbMetrics.hairline);

      await tester
          .pumpWidget(host(const WbPaneChip(label: 'aorist', on: false)));
      final off = decorationOf(tester, find.byType(WbPaneChip));
      expect(off.color, Colors.transparent);
      expect((off.border! as Border).top.color, WbColors.light.border);
    });

    testWidgets('carries its accent in the ink and the border', (tester) async {
      await tester
          .pumpWidget(host(const WbPaneChip(label: 'aorist', on: true)));
      expect(tester.widget<Text>(find.text('aorist')).style!.color,
          WbColors.light.strongsLexical);
      expect(
          (decorationOf(tester, find.byType(WbPaneChip)).border! as Border)
              .top
              .color,
          WbColors.light.strongsLexical);
    });

    testWidgets('honours a pane that disagrees about the accent',
        (tester) async {
      // Morphology passes strongsGrammar because its chips ARE grammar.
      await tester.pumpWidget(host(WbPaneChip(
        label: 'Niphal',
        on: true,
        foreground: WbColors.light.strongsGrammar,
      )));
      expect(tester.widget<Text>(find.text('Niphal')).style!.color,
          WbColors.light.strongsGrammar);
    });

    testWidgets('strikes the label only when asked, and only when off',
        (tester) async {
      await tester.pumpWidget(host(const WbPaneChip(
          label: 'the', on: false, strikeWhenOff: true)));
      expect(tester.widget<Text>(find.text('the')).style!.decoration,
          TextDecoration.lineThrough);

      await tester.pumpWidget(host(
          const WbPaneChip(label: 'the', on: true, strikeWhenOff: true)));
      expect(tester.widget<Text>(find.text('the')).style!.decoration, isNull);

      // A sort chip that is not the current sort is not "excluded".
      await tester
          .pumpWidget(host(const WbPaneChip(label: 'the', on: false)));
      expect(tester.widget<Text>(find.text('the')).style!.decoration, isNull);
    });

    testWidgets('taps and long-presses', (tester) async {
      var taps = 0;
      var holds = 0;
      await tester.pumpWidget(host(WbPaneChip(
        label: 'word',
        on: false,
        onTap: () => taps++,
        onLongPress: () => holds++,
      )));
      final ink = tester.widget<InkWell>(find.byType(InkWell));
      expect(ink.hoverColor, WbColors.light.hoverBg);
      expect(ink.splashColor, Colors.transparent);
      await tester.tap(find.text('word'));
      await tester.longPress(find.text('word'));
      expect(taps, 1);
      expect(holds, 1);
    });

    testWidgets('follows the paper palette', (tester) async {
      await tester.pumpWidget(
          host(const WbPaneChip(label: 'word', on: true), paper: true));
      expect(decorationOf(tester, find.byType(WbPaneChip)).color,
          WbColors.paper.selectionBg);
      expect(tester.widget<Text>(find.text('word')).style!.color,
          WbColors.paper.strongsLexical);
    });
  });

  group('WbIconTap', () {
    testWidgets('a null callback is the disabled state', (tester) async {
      await tester.pumpWidget(
          host(const WbIconTap(icon: Icons.arrow_forward, onTap: null)));
      expect(tester.widget<Icon>(find.byType(Icon)).color,
          WbColors.light.border);
      expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
    });

    testWidgets('defaults to the link colour when it does something',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(
          WbIconTap(icon: Icons.arrow_forward, onTap: () => taps++)));
      expect(tester.widget<Icon>(find.byType(Icon)).color, WbColors.light.link);
      await tester.tap(find.byType(WbIconTap));
      expect(taps, 1);
    });

    testWidgets('wraps in a Tooltip only when given one', (tester) async {
      await tester.pumpWidget(host(
          WbIconTap(icon: Icons.check, onTap: () {}, tooltip: 'Learned')));
      expect(find.byType(Tooltip), findsOneWidget);

      await tester.pumpWidget(host(WbIconTap(icon: Icons.check, onTap: () {})));
      expect(find.byType(Tooltip), findsNothing);
    });
  });

  group('WbMeterBar', () {
    double widthFactorOf(WidgetTester tester) => tester
        .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
        .widthFactor!;

    testWidgets('clamps a fraction a caller got wrong', (tester) async {
      // The realistic caller error is dividing by a maximum of zero,
      // which yields NaN or infinity and would otherwise assert deep in
      // the render tree rather than at the call site.
      for (final bad in <double>[-1, 2, double.nan, double.infinity]) {
        await tester.pumpWidget(
            host(WbMeterBar(fraction: bad, color: const Color(0xFF00FF00))));
        expect(widthFactorOf(tester), inInclusiveRange(0.0, 1.0),
            reason: 'fraction $bad');
      }
    });

    testWidgets('passes a good fraction through', (tester) async {
      await tester.pumpWidget(
          host(const WbMeterBar(fraction: 0.25, color: Color(0xFF00FF00))));
      expect(widthFactorOf(tester), 0.25);
    });

    testWidgets('the track is a WbColors step, not a tint', (tester) async {
      await tester.pumpWidget(
          host(const WbMeterBar(fraction: 0.5, color: Color(0xFF00FF00))));
      final boxes = tester
          .widgetList<ColoredBox>(find.descendant(
              of: find.byType(WbMeterBar), matching: find.byType(ColoredBox)))
          .toList();
      expect(boxes.first.color, WbColors.light.paneAltBg);
      expect(boxes.last.color, const Color(0xFF00FF00));
    });

    testWidgets('is exactly as tall as it was asked to be', (tester) async {
      await tester.pumpWidget(host(
        const WbMeterBar(fraction: 0.5, color: Color(0xFF00FF00)),
        width: 100,
      ));
      expect(tester.getSize(find.byType(WbMeterBar)).height, 4);
    });
  });
}
