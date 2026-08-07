// 2026-08-08 (task #279): two things are pinned here.
//
// 1. The COMPONENT THEMES. `workbenchTheme()` builds from a fresh
//    `ThemeData.light/dark`, so anything it does not name falls through
//    to the stock Material 3 defaults — and those are stadium-shaped
//    and elevated. That is where the app's pills actually came from:
//    not from the pages, but from the components the theme forgot to
//    mention. The guard below walks every component the theme claims
//    and asserts a zero corner radius, so a future `copyWith` that
//    drops one is a red test rather than a re-rounded button somebody
//    notices in a screenshot six weeks later.
//
// 2. The PAGE SURFACES in `wb_surfaces.dart` — that they honour
//    workbench_theme.dart:16 ("square corners and 1px hairline
//    borders, no shadows, no cards") and that they read their colours
//    from the WbColors extension, so all three palettes work.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/widgets/wb_surfaces.dart';

/// Every shape the theme sets must be a rectangle with square corners.
/// `StadiumBorder` and `CircleBorder` are failures by construction; a
/// `RoundedRectangleBorder` is only acceptable at radius zero.
void _expectSquare(ShapeBorder? shape, String what) {
  expect(shape, isNotNull, reason: '$what should set an explicit shape');
  expect(shape, isA<RoundedRectangleBorder>(),
      reason: '$what should be a rectangle, not a pill or a circle');
  final r = (shape! as RoundedRectangleBorder).borderRadius;
  expect(r, BorderRadius.zero, reason: '$what should have square corners');
}

OutlinedBorder? _buttonShape(ButtonStyle? style) =>
    style?.shape?.resolve(<WidgetState>{});

void main() {
  // All three palettes, because `paper` is a separate WbColors instance
  // and a component wired to `scheme.primary` instead of a WbColors
  // field only misbehaves in one of them.
  final themes = <String, ThemeData>{
    'light': workbenchTheme(ThemeData.light(useMaterial3: true)),
    'dark': workbenchTheme(ThemeData.dark(useMaterial3: true)),
    'paper': workbenchTheme(ThemeData.light(useMaterial3: true), paper: true),
  };

  themes.forEach((name, theme) {
    group('workbenchTheme($name) component chrome', () {
      test('every button family is square', () {
        _expectSquare(
            _buttonShape(theme.filledButtonTheme.style), 'FilledButton');
        _expectSquare(
            _buttonShape(theme.outlinedButtonTheme.style), 'OutlinedButton');
        _expectSquare(
            _buttonShape(theme.elevatedButtonTheme.style), 'ElevatedButton');
        _expectSquare(_buttonShape(theme.textButtonTheme.style), 'TextButton');
        _expectSquare(
            _buttonShape(theme.segmentedButtonTheme.style), 'SegmentedButton');
        expect(theme.toggleButtonsTheme.borderRadius, BorderRadius.zero);
      });

      test('chips are square boxes, not pills', () {
        _expectSquare(theme.chipTheme.shape, 'Chip');
        // A chip that signalled selection by fill alone would be a
        // colour-only cue. The tick has to survive the flattening.
        expect(theme.chipTheme.showCheckmark, isTrue);
      });

      test('containers — card, sheet, dialog, menus — are square', () {
        _expectSquare(theme.cardTheme.shape, 'Card');
        _expectSquare(theme.bottomSheetTheme.shape, 'BottomSheet');
        _expectSquare(theme.dialogTheme.shape, 'Dialog');
        _expectSquare(theme.popupMenuTheme.shape, 'PopupMenu');
        _expectSquare(theme.menuTheme.style?.shape?.resolve(<WidgetState>{}),
            'MenuAnchor');
        _expectSquare(theme.snackBarTheme.shape, 'SnackBar');
        _expectSquare(theme.listTileTheme.shape, 'ListTile');
        _expectSquare(theme.expansionTileTheme.shape, 'ExpansionTile');
        _expectSquare(theme.expansionTileTheme.collapsedShape,
            'ExpansionTile (collapsed)');
      });

      test('nothing casts a shadow', () {
        expect(theme.cardTheme.elevation, 0);
        expect(theme.dialogTheme.elevation, 0);
        expect(theme.bottomSheetTheme.elevation, 0);
        expect(theme.bottomSheetTheme.modalElevation, 0);
        expect(theme.popupMenuTheme.elevation, 0);
        expect(theme.snackBarTheme.elevation, 0);
        expect(theme.chipTheme.elevation, 0);
        expect(theme.appBarTheme.elevation, 0);
        // The one that actually bit: an AppBar with a scrolled-under
        // elevation grows a shadow the moment the page scrolls, so a
        // static screenshot of the top of the page looks fine.
        expect(theme.appBarTheme.scrolledUnderElevation, 0);
      });

      test('the bottom sheet has no drag handle', () {
        // A drag handle is a phone affordance. On a desktop workbench
        // it is a grey pill sitting on top of the content.
        expect(theme.bottomSheetTheme.showDragHandle, isFalse);
      });

      test('text fields are hairline boxes, not filled pills', () {
        final border = theme.inputDecorationTheme.enabledBorder;
        expect(border, isA<OutlineInputBorder>());
        expect((border! as OutlineInputBorder).borderRadius, BorderRadius.zero);
      });

      test('the progress indicator has square ends', () {
        expect(theme.progressIndicatorTheme.borderRadius, BorderRadius.zero);
      });

      test('chrome colours come from WbColors, not the ColorScheme', () {
        final wb = theme.extension<WbColors>();
        expect(wb, isNotNull);
        expect(theme.scaffoldBackgroundColor, wb!.chromeBg);
        expect(theme.appBarTheme.backgroundColor, wb.chromeBg);
        expect(theme.dividerColor, wb.border);
      });
    });
  });

  group('WbColors.isDark', () {
    test('answers by palette, not by ThemeMode', () {
      expect(WbColors.light.isDark, isFalse);
      expect(WbColors.dark.isDark, isTrue);
      // The whole reason this getter exists: paper is a LIGHT surface
      // even when the app's ThemeMode is dark, so a hue picked off
      // `Theme.of(context).brightness` came out inverted on cream.
      expect(WbColors.paper.isDark, isFalse);
    });
  });

  // AppSettings is required: WbType.of() resolves the type scale from
  // the user's font-size / line-spacing settings.
  Widget host(Widget child, {bool paper = false}) => ChangeNotifierProvider(
        create: (_) => AppSettings(),
        child: MaterialApp(
          theme:
              workbenchTheme(ThemeData.light(useMaterial3: true), paper: paper),
          home: Scaffold(body: Center(child: child)),
        ),
      );

  /// The decoration of the outermost Container inside [finder].
  BoxDecoration decorationOf(WidgetTester tester, Finder finder) {
    final container = tester.widget<Container>(
      find.descendant(of: finder, matching: find.byType(Container)).first,
    );
    return container.decoration! as BoxDecoration;
  }

  group('WbPanel', () {
    testWidgets('is a square hairline box on the pane background',
        (tester) async {
      await tester.pumpWidget(host(const WbPanel(child: Text('body'))));
      final d = decorationOf(tester, find.byType(WbPanel));
      expect(d.borderRadius, isNull, reason: 'square corners');
      expect(d.boxShadow, anyOf(isNull, isEmpty), reason: 'no shadows');
      expect(d.color, WbColors.light.paneBg);
      expect((d.border! as Border).top.width, WbMetrics.hairline);
      expect((d.border! as Border).top.color, WbColors.light.border);
    });

    testWidgets('`alt` is a step in value, not a tint', (tester) async {
      await tester
          .pumpWidget(host(const WbPanel(alt: true, child: Text('body'))));
      // paneAltBg, NOT a wash of the seed colour — the distinction the
      // primaryContainer tints used to blur.
      expect(decorationOf(tester, find.byType(WbPanel)).color,
          WbColors.light.paneAltBg);
    });

    testWidgets('renders title, subtitle and trailing when titled',
        (tester) async {
      await tester.pumpWidget(host(const WbPanel(
        icon: Icons.translate_rounded,
        title: 'Languages',
        subtitle: 'Hebrew, Aramaic, Greek',
        trailing: Text('3'),
        child: Text('body'),
      )));
      expect(find.text('Languages'), findsOneWidget);
      expect(find.text('Hebrew, Aramaic, Greek'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(Icons.translate_rounded), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('follows the paper palette', (tester) async {
      await tester
          .pumpWidget(host(const WbPanel(child: Text('body')), paper: true));
      expect(decorationOf(tester, find.byType(WbPanel)).color,
          WbColors.paper.paneBg);
    });
  });

  group('WbTag', () {
    testWidgets('carries its distinction in the TEXT, not the fill',
        (tester) async {
      // A Material `shade100` pastel loses its edge entirely on paper's
      // cream; the hue has to be in the ink for all three palettes to
      // read the same tag.
      const hue = Color(0xFF9C1F1F);
      await tester.pumpWidget(host(const WbTag(text: 'H3068', color: hue)));
      expect(tester.widget<Text>(find.text('H3068')).style!.color, hue);
      final d = decorationOf(tester, find.byType(WbTag));
      expect(d.color, WbColors.light.paneAltBg);
      expect(d.borderRadius, isNull);
    });

    testWidgets('defaults to muted when it is only a label', (tester) async {
      await tester.pumpWidget(host(const WbTag(text: 'OT')));
      expect(tester.widget<Text>(find.text('OT')).style!.color,
          WbColors.light.mutedText);
    });
  });

  group('WbTile', () {
    testWidgets('is a plain square box when it does not tap', (tester) async {
      await tester.pumpWidget(host(const WbTile(child: Text('row'))));
      expect(find.byType(InkWell), findsNothing);
      expect(decorationOf(tester, find.byType(WbTile)).borderRadius, isNull);
    });

    testWidgets('taps, and says so by lighting up rather than by a card',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
          host(WbTile(onTap: () => taps++, child: const Text('row'))));
      final ink = tester.widget<InkWell>(find.byType(InkWell));
      expect(ink.hoverColor, WbColors.light.hoverBg);
      expect(ink.splashColor, Colors.transparent);
      final material = tester.widget<Material>(
        find.descendant(
            of: find.byType(WbTile), matching: find.byType(Material)),
      );
      _expectSquare(material.shape, 'WbTile');
      await tester.tap(find.text('row'));
      expect(taps, 1);
    });
  });
}
