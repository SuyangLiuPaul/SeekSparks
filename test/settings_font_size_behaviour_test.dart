// 2026-08-24 (#315): the Settings page obeys the slider it carries.
//
// `font_size_reach_ratchet_test.dart` measured 28 saturating ceilings
// in `settings_page.dart` — the largest concentration in the app, on
// the one page where the reader can see the control and the result at
// the same time. Dragging Font Size to 40 pt left every hint, subtitle
// and section header on it exactly where it was.
//
// Source alone cannot close that. The ratchet next door proves a size
// is not a literal, not a deaf Material role and not a clamp; it cannot
// prove the size MOVES, which is the whole report. This file drives the
// real page across the real slider and reads back what the widget tree
// resolved, the same instrument `reader_font_size_behaviour_test.dart`
// uses for the reading pane.
//
// Three properties, and the middle one is the only one that failed
// before the repair:
//
//   * at the DEFAULT the sizes are unchanged — 18 and 13, exactly what
//     `(fontSize - 2).clamp(11, 22)` and `(fontSize - 4).clamp(11, 13)`
//     already produced. A repair a reader can see is a redesign, and
//     this is not one.
//   * at the TOP they are proportional — 36 and 26. Before: 22 and 13.
//   * at the BOTTOM they stop at 11 rather than falling to 10.8 and
//     7.8. A clamp has two bounds and only the ceiling was the bug;
//     `WbMetrics.smallPrintFloor` is the floor kept, named once instead
//     of as the thirty slightly different numbers that were in use.
//
// The labels are looked up through `uiStrings` rather than typed in, so
// an editor rewording a hint does not fail a type test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/pages/settings_page.dart';
import 'package:seeksparks/providers/main_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppSettings> pumpSettings(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.reset);

    late AppSettings settings;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) {
            settings = AppSettings();
            return settings;
          }),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);
    return settings;
  }

  // A `Text` resolves into a `RichText` whose root style carries the
  // size actually used, so this reads what was painted rather than what
  // some `TextStyle` in the source says.
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

  // The settings debounce leaves a pending timer if the tree is torn
  // down inside it, so every move pumps past it.
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

  testWidgets('the page carrying the Font Size slider follows it',
      (tester) async {
    final settings = await pumpSettings(tester);
    final locale = settings.locale;

    // Two anchors, both visible on the first screen at 1280x900 with
    // empty preferences: a section header and a card's small print.
    // They are the two sizes `_SettingsSmallPrint` resolves most often.
    final header =
        (uiStrings['settingsSectionDisplay']?[locale] ?? 'Display')
            .toUpperCase();
    final note = uiStrings['localOnlyDataNotice']?[locale] ?? '';
    expect(note, isNotEmpty,
        reason: 'the account note is the small-print anchor; if its key '
            'moved, pick another and say which');

    final low = await at(tester, settings, kFontSizeMin);
    final mid = await at(tester, settings, kFontSizeDefault);
    final high = await at(tester, settings, kFontSizeMax);

    // At 40 pt every size on the page is twice its design value, which
    // is where a RenderFlex overflow would appear if one were going to.
    expect(tester.takeException(), isNull,
        reason: 'Settings overflowed somewhere between the bottom and the '
            'top of the Font Size slider');

    for (final anchor in [header, note]) {
      expect(mid[anchor], isNotNull,
          reason: '"$anchor" is not on the first screen any more — this '
              'test measures nothing until an anchor that is replaces it');
    }

    // Unchanged at the default: the repair is invisible to a reader who
    // never moved the slider.
    expect(mid[header], 18.0);
    expect(mid[note], 13.0);

    // Proportional at the top. These read 22.0 and 13.0 before the fix.
    const topScale = kFontSizeMax / kFontSizeDefault;
    expect(high[header], closeTo(18.0 * topScale, 1e-9),
        reason: 'the section header stops growing before the top of the '
            'slider — a ceiling inside the range the reader can reach');
    expect(high[note], closeTo(13.0 * topScale, 1e-9),
        reason: 'the card\'s small print stops growing before the top of '
            'the slider');

    // Floored at the bottom, and floored to one shared number rather
    // than to whichever bound the site happened to carry.
    expect(low[header], WbMetrics.smallPrintFloor);
    expect(low[note], WbMetrics.smallPrintFloor);

    await disposeTree(tester);
  });

  // `responsive_overflow_smoke_test.dart` pumps this page at four
  // widths and the DEFAULT font size, which is the state a frozen size
  // could never leave. Now that thirty of them travel to 2x, the
  // narrow-and-huge corner is new ground and is where a RenderFlex
  // would give way — a settings row is a `Row` of icon, label and
  // control, and only the label grew.
  //
  // 992 is the narrowest the app admits (`workbench_fit.dart:82`), so
  // it is the narrowest this can be asked about honestly. The smoke
  // test's 320 and 390 are pumped directly, bypassing the gate, and at
  // 40 pt the page overflows by 7.3 px there — measured against the
  // commit BEFORE this change as well, so it is the unbounded
  // `fontSize + 2` card titles that were already free to grow, not
  // anything repaired here. Reported rather than fixed: it is a layout
  // the reader cannot reach, and widening the ratchet to cover
  // unreachable states is how a suite starts failing for reasons
  // nobody can act on.
  for (final width in [992.0, 1280.0]) {
    testWidgets('Settings survives ${width.toInt()} px at the top of the '
        'slider', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.reset);

      late AppSettings settings;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MainProvider()),
            ChangeNotifierProvider(create: (_) {
              settings = AppSettings();
              return settings;
            }),
          ],
          child: const MaterialApp(home: SettingsPage()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 700));
      await at(tester, settings, kFontSizeMax);

      expect(tester.takeException(), isNull,
          reason: 'Settings overflowed at ${width.toInt()} px with the Font '
              'Size slider at its top');

      await disposeTree(tester);
    });
  }

  test('scaledSmall drops the ceiling and keeps the floor', () {
    WbType scale(double fontSize) =>
        WbType.resolve(fontSize: fontSize, lineSpacing: 1.5, menuScale: 1.0);

    // The property the additive `(fontSize - k)` shape could not hold:
    // two sizes keep their proportion at every stop of the slider. With
    // offsets, 13 and 18 at the default become 6 and 11 at 12 pt — a
    // ratio of 1.83 where the design was 1.38.
    for (final fs in [20.0, 28.0, kFontSizeMax]) {
      final t = scale(fs);
      expect(t.scaledSmall(18) / t.scaledSmall(13), closeTo(18 / 13, 1e-9));
    }

    // No ceiling: every stop above the default moves.
    var previous = scale(kFontSizeDefault).scaledSmall(13);
    for (var fs = kFontSizeDefault + 1; fs <= kFontSizeMax; fs++) {
      final next = scale(fs).scaledSmall(13);
      expect(next, greaterThan(previous),
          reason: 'scaledSmall(13) froze at $fs pt');
      previous = next;
    }

    // A floor, not a second ceiling: it is reached and never crossed.
    expect(scale(kFontSizeMin).scaledSmall(13), WbMetrics.smallPrintFloor);
    expect(scale(kFontSizeMin).scaledSmall(18), WbMetrics.smallPrintFloor);
    expect(scale(kFontSizeDefault).scaledSmall(13), 13.0);
  });
}
