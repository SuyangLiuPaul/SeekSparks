import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/utils/font_catalog.dart';
import 'package:seeksparks/widgets/chronology_depth_toggle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    for (final (family, path) in [
      ('Roboto', 'assets/fonts/Roboto-VariableFont_wdth,wght.ttf'),
      ('NotoSansSC-Sub', 'assets/fonts/NotoSansSC-Sub.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(path))).load();
    }
  });

  Future<void> pumpToggle(
    WidgetTester tester, {
    String locale = 'en',
    String prefix = 'chronologyDepth',
    double width = 140,
    bool is3D = false,
    bool maximumSettings = false,
    double systemScale = 1,
    ValueChanged<bool>? onChanged,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    await settings.setFontFamily('Roboto');
    if (maximumSettings) {
      await settings.setFontSize(kFontSizeMax);
      await settings.setMenuScale(kMenuScaleMax);
    }
    // Settings persists its user snapshot after 600 ms. Complete that
    // real path before interaction tests that do not advance the clock.
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => settings,
      child: MaterialApp(
        theme: ThemeData(
            fontFamily: 'Roboto', fontFamilyFallback: kCjkFontFallback),
        home: Scaffold(
          body: Center(
            child: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(systemScale)),
              child: SizedBox(
                width: width,
                child: StatefulBuilder(builder: (context, setState) {
                  return ChronologyDepthToggle(
                    is3D: is3D,
                    locale: locale,
                    keyPrefix: prefix,
                    onChanged: (value) {
                      onChanged?.call(value);
                      setState(() => is3D = value);
                    },
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    ));
  }

  Finder choice(String suffix, {String prefix = 'chronologyDepth'}) =>
      find.byKey(ValueKey('$prefix-$suffix'));

  void expectVisibleLabel(WidgetTester tester, Finder button, String label) {
    final text = find.descendant(of: button, matching: find.text(label));
    final paragraph = tester.renderObject<RenderParagraph>(text);
    final box = tester.getRect(button);
    expect(paragraph.didExceedMaxLines, isFalse);
    final glyphs = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: label.length));
    expect(glyphs, isNotEmpty);
    for (final glyph in glyphs) {
      final first = paragraph.localToGlobal(Offset(glyph.left, glyph.top));
      final last = paragraph.localToGlobal(Offset(glyph.right, glyph.bottom));
      expect(first.dx, greaterThanOrEqualTo(box.left));
      expect(first.dy, greaterThanOrEqualTo(box.top));
      expect(last.dx, lessThanOrEqualTo(box.right));
      expect(last.dy, lessThanOrEqualTo(box.bottom));
    }
    expect(button.hitTestable(), findsOneWidget);
  }

  for (final (locale, flat, depth) in [
    ('en', 'Flat', '3D'),
    ('zh-Hans', '平面', '立体'),
    ('zh-Hant', '平面', '立體'),
  ]) {
    testWidgets('$locale exposes one selected choice and emits only changes',
        (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final values = <bool>[];
        await pumpToggle(tester, locale: locale, onChanged: values.add);
        final flatData = tester.getSemantics(choice('flat')).getSemanticsData();
        final depthData = tester.getSemantics(choice('3d')).getSemanticsData();
        expect(flatData.label, flat);
        expect(depthData.label, depth);
        expect(flatData.flagsCollection.isSelected, ui.Tristate.isTrue);
        expect(depthData.flagsCollection.isSelected, ui.Tristate.isFalse);
        expect(flatData.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
        expect(depthData.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
        await tester.tap(choice('flat'));
        expect(values, isEmpty);
        await tester.tap(choice('3d'));
        await tester.pump();
        expect(values, [true]);
        expect(
            tester
                .getSemantics(choice('3d'))
                .getSemanticsData()
                .flagsCollection
                .isSelected,
            ui.Tristate.isTrue);
        await tester.tap(choice('3d'));
        expect(values, [true]);
        await tester.tap(choice('flat'));
        await tester.pump();
        expect(values, [true, false]);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });

    for (final width in [140.0, 360.0]) {
      testWidgets('$locale stays readable at maximum settings in $width px',
          (tester) async {
        await pumpToggle(tester,
            locale: locale, width: width, maximumSettings: true);
        final left = tester.getRect(choice('flat'));
        final right = tester.getRect(choice('3d'));
        expect(left.width, greaterThanOrEqualTo(44));
        expect(right.width, greaterThanOrEqualTo(44));
        expect(left.height, greaterThanOrEqualTo(44));
        expect(right.height, greaterThanOrEqualTo(44));
        expect(left.top, right.top);
        expect(left.overlaps(right), isFalse);
        expect(right.right - left.left, lessThanOrEqualTo(width));
        expect(left.height, lessThanOrEqualTo(48),
            reason: 'Both chart pages reserve a 48 px mode row.');
        expectVisibleLabel(tester, choice('flat'), flat);
        expectVisibleLabel(tester, choice('3d'), depth);
        await tester.tap(choice('3d'));
        await tester.pump();
        expectVisibleLabel(tester, choice('3d'), depth);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('an extremely narrow host keeps both names and touch targets',
      (tester) async {
    await pumpToggle(tester,
        locale: 'zh-Hant', width: 92, maximumSettings: true);
    final flat = tester.getRect(choice('flat'));
    final depth = tester.getRect(choice('3d'));
    expect(flat.bottom, lessThanOrEqualTo(depth.top));
    expect(flat.width, 92);
    expect(depth.width, 92);
    expect(flat.height, greaterThanOrEqualTo(44));
    expect(depth.height, greaterThanOrEqualTo(44));
    expectVisibleLabel(tester, choice('flat'), '平面');
    expectVisibleLabel(tester, choice('3d'), '立體');
    expect(tester.takeException(), isNull);
  });

  testWidgets('system text scaling retains the complete names', (tester) async {
    await pumpToggle(tester,
        locale: 'zh-Hant', width: 140, maximumSettings: true, systemScale: 2);
    expectVisibleLabel(tester, choice('flat'), '平面');
    expectVisibleLabel(tester, choice('3d'), '立體');
    expect(
        tester.getRect(choice('flat')).overlaps(tester.getRect(choice('3d'))),
        isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom prefixes retain keyboard access to both choices',
      (tester) async {
    final values = <bool>[];
    await pumpToggle(tester, prefix: 'stripDepth', onChanged: values.add);
    expect(find.byKey(const ValueKey('stripDepth')), findsOneWidget);
    expect(choice('flat'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(values, [true]);
    expect(choice('3d', prefix: 'stripDepth'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
