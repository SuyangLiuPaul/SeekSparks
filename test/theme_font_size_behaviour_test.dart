// 2026-08-24 (#315, fourth mechanism). The reader's Font Size, measured
// where the reader meets it: on painted Material widgets.
//
// The first three mechanisms #315 chased are all source patterns — a
// `fontSize: 12` literal, a bare Material role, a saturating clamp — and
// `test/font_size_reach_ratchet_test.dart` grep for them. The fourth is
// invisible to grep, because it is not written at the call site at all:
// `workbenchTheme` is the app's only theme (`main.dart` wraps both
// `theme:` and `darkTheme:` with it), it builds from a fresh
// `ThemeData.light/dark`, and it sized every Material text role from
// constants. Every widget below therefore painted at exactly the same
// number at 12 pt and at 40 pt, and no source rule could have said so.
//
// Measured on the pre-fix tree (b6d9859) with this file's probe: all
// fifteen roles, the Scaffold's `DefaultTextStyle`, and a bare `Text`
// were identical at 12 / 20 / 40 pt — a bare `Text` painted at 12.0 px
// at both ends of a 12–40 pt slider.
//
// TRAP, paid for once: `MaterialApp` wraps its theme in `AnimatedTheme`.
// A single `pump()` after changing `theme:` reads the theme MID-LERP,
// which at t=0 is the OLD theme — so an earlier version of this probe
// reported everything still deaf after the fix was already working, and
// would equally have reported a broken fix as fine. Every pump here
// settles.
//
// SCOPE, stated because it is a real gap: these tests build the theme by
// calling `workbenchTheme` directly, not by booting `main.dart` (whose
// two `ThemeData` literals are ~120 lines each and inline in the
// `GetMaterialApp`). What ties them to the app is the source test in
// `font_size_reach_ratchet_test.dart` — 'every workbenchTheme call
// passes the reader's scale' — which fails if any call site in `lib/`
// drops `textScale:`. A behaviour claim resting partly on a source check
// is weaker than one that boots the app; it is recorded here rather than
// implied.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';

ThemeData themeAt(double fontSize, {Brightness brightness = Brightness.light}) =>
    workbenchTheme(
      textScale: WbType.scaleFor(fontSize),
      ThemeData(brightness: brightness),
    );

/// The font size a widget's text is actually painted at.
double paintedSize(WidgetTester t, String text) {
  final rich = t
      .widgetList<RichText>(find.byType(RichText))
      .firstWhere((r) => r.text.toPlainText().contains(text));
  final size = rich.text.style?.fontSize;
  expect(size, isNotNull, reason: '"$text" painted with no font size');
  return size!;
}

const roleNames = <String>[
  'displayLarge', 'displayMedium', 'displaySmall',
  'headlineLarge', 'headlineMedium', 'headlineSmall',
  'titleLarge', 'titleMedium', 'titleSmall',
  'bodyLarge', 'bodyMedium', 'bodySmall',
  'labelLarge', 'labelMedium', 'labelSmall',
];

Map<String, double?> rolesOf(TextTheme t) => {
      'displayLarge': t.displayLarge?.fontSize,
      'displayMedium': t.displayMedium?.fontSize,
      'displaySmall': t.displaySmall?.fontSize,
      'headlineLarge': t.headlineLarge?.fontSize,
      'headlineMedium': t.headlineMedium?.fontSize,
      'headlineSmall': t.headlineSmall?.fontSize,
      'titleLarge': t.titleLarge?.fontSize,
      'titleMedium': t.titleMedium?.fontSize,
      'titleSmall': t.titleSmall?.fontSize,
      'bodyLarge': t.bodyLarge?.fontSize,
      'bodyMedium': t.bodyMedium?.fontSize,
      'bodySmall': t.bodySmall?.fontSize,
      'labelLarge': t.labelLarge?.fontSize,
      'labelMedium': t.labelMedium?.fontSize,
      'labelSmall': t.labelSmall?.fontSize,
    };

/// Resolves the theme the way a widget does: through `ThemeData.localize`,
/// which merges the [Typography] geometry in. Reading `theme.textTheme`
/// off the raw [ThemeData] does NOT do this — ten of the fifteen roles
/// still have a null `fontSize` at that point, which is why the fix had
/// to go on the typography and not on the text theme.
Future<TextTheme> resolvedRoles(WidgetTester t, ThemeData theme) async {
  late TextTheme out;
  await t.pumpWidget(MaterialApp(
    theme: theme,
    home: Builder(builder: (c) {
      out = Theme.of(c).textTheme;
      return const SizedBox.shrink();
    }),
  ));
  await t.pumpAndSettle();
  return out;
}

void main() {
  testWidgets('every Material text role moves with the Font Size slider',
      (t) async {
    final small = rolesOf(await resolvedRoles(t, themeAt(kFontSizeMin)));
    final big = rolesOf(await resolvedRoles(t, themeAt(kFontSizeMax)));

    final deaf = <String>[];
    for (final r in roleNames) {
      expect(small[r], isNotNull, reason: '$r has no size at the low end');
      expect(big[r], isNotNull, reason: '$r has no size at the high end');
      if (small[r] == big[r]) deaf.add('$r stuck at ${small[r]}');
    }
    expect(deaf, isEmpty,
        reason: 'these roles paint the same at ${kFontSizeMin.toInt()} pt and '
            '${kFontSizeMax.toInt()} pt, so the slider does nothing to any '
            'widget that uses them:\n${deaf.join('\n')}');
  });

  testWidgets('the default setting is unchanged, to the byte', (t) async {
    // The repair must open the range the slider could not reach WITHOUT
    // redesigning the app for the reader who never touched the slider.
    // At the default the scale is exactly 1.0, so every role must still
    // be the number the design chose. These are the values the pre-fix
    // tree painted, transcribed from its own measurement.
    final at20 = rolesOf(await resolvedRoles(t, themeAt(kFontSizeDefault)));
    expect(at20, {
      'displayLarge': 57.0,
      'displayMedium': 45.0,
      'displaySmall': 36.0,
      'headlineLarge': 32.0,
      'headlineMedium': 28.0,
      'headlineSmall': 24.0,
      'titleLarge': 22.0,
      'titleMedium': 16.0,
      'titleSmall': WbMetrics.chrome,
      'bodyLarge': WbMetrics.text,
      'bodyMedium': WbMetrics.text,
      'bodySmall': WbMetrics.chrome,
      'labelLarge': 14.0,
      'labelMedium': 12.0,
      'labelSmall': WbMetrics.chrome,
    });
  });

  testWidgets('no role is driven below the small-print floor', (t) async {
    // `WbMetrics.smallPrintFloor` is the policy `WbType.scaledSmall`
    // already applies: a reader who drags Font Size to the minimum is
    // asking for dense scripture in the reading pane, not for a 7 px
    // button label in the chrome around it.
    final small = rolesOf(await resolvedRoles(t, themeAt(kFontSizeMin)));
    for (final r in roleNames) {
      expect(small[r], greaterThanOrEqualTo(WbMetrics.smallPrintFloor),
          reason: '$r falls under the floor at the minimum setting');
    }
  });

  testWidgets('real widgets, painted, move with the slider', (t) async {
    Future<Map<String, double>> painted(double fs) async {
      await t.pumpWidget(MaterialApp(
        theme: themeAt(fs),
        home: Scaffold(
          appBar: AppBar(title: const Text('APPBAR')),
          body: ListView(children: [
            const Text('BARE'),
            ElevatedButton(onPressed: () {}, child: const Text('BUTTON')),
            TextButton(onPressed: () {}, child: const Text('TEXTBUTTON')),
            const Chip(label: Text('CHIP')),
            const ListTile(
              title: Text('TILETITLE'),
              subtitle: Text('TILESUB'),
            ),
          ]),
        ),
      ));
      await t.pumpAndSettle();
      return {
        for (final m in const [
          'APPBAR',
          'BARE',
          'BUTTON',
          'TEXTBUTTON',
          'CHIP',
          'TILETITLE',
          'TILESUB',
        ])
          m: paintedSize(t, m),
      };
    }

    final small = await painted(kFontSizeMin);
    final big = await painted(kFontSizeMax);

    final deaf = <String>[];
    small.forEach((widget, size) {
      if (size == big[widget]) deaf.add('$widget painted at $size at both ends');
      if (size > big[widget]!) {
        deaf.add('$widget SHRANK as the slider grew: $size -> ${big[widget]}');
      }
    });
    expect(deaf, isEmpty, reason: deaf.join('\n'));
  });

  testWidgets('the dark theme is on the same scale', (t) async {
    // The fix has to be made twice in `main.dart` — `theme:` and
    // `darkTheme:` are separate `workbenchTheme` calls — so a
    // half-applied repair is a real shape this could take.
    final small = rolesOf(await resolvedRoles(
        t, themeAt(kFontSizeMin, brightness: Brightness.dark)));
    final big = rolesOf(await resolvedRoles(
        t, themeAt(kFontSizeMax, brightness: Brightness.dark)));
    for (final r in roleNames) {
      expect(small[r], isNot(equals(big[r])),
          reason: 'dark theme: $r is stuck at ${small[r]}');
    }
  });

  test('the scale is the reader\'s setting over the default, clamped', () {
    expect(WbType.scaleFor(kFontSizeDefault), 1.0);
    expect(WbType.scaleFor(kFontSizeMin), kFontSizeMin / kFontSizeDefault);
    expect(WbType.scaleFor(kFontSizeMax), kFontSizeMax / kFontSizeDefault);
    // A setting outside the slider's own range cannot escape it.
    expect(WbType.scaleFor(0), kFontSizeMin / kFontSizeDefault);
    expect(WbType.scaleFor(9999), kFontSizeMax / kFontSizeDefault);
  });
}
