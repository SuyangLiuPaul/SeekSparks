// 2026-08-17 (#316): every style in the theme can render Chinese.
//
// Found by screenshotting the rotate advisory in 简体 on the deployed
// v1.6.132: the title and the one instruction the reader needs drew as
// □□□, while the two paragraphs around them were fine. The difference
// was not the weight and not the string — it was WHICH text style.
//
// `workbenchTheme` rebuilt the text theme from `ThemeData.light()` and
// then restated five styles with the parent's `fontFamilyFallback`.
// The other ten kept Roboto and no fallback. Roboto has no CJK; on web
// the engine's last resort is a download from fonts.gstatic.com, which
// `--no-web-resources-cdn` removes. So `headlineSmall`, `titleMedium`,
// `titleLarge` (AppBar titles) and `labelLarge` (every Material button
// label) drew notdef boxes for any Chinese that reached them.
//
// That hole is why `lib/` is littered with per-call-site
// `fontFamilyFallback: kCjkFontFallback` — each is a local patch of
// this one omission, applied wherever someone happened to notice.
//
// A fallback list costs nothing on a glyph the primary face already
// has, so there is no style that should be without one.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/utils/font_catalog.dart';

void main() {
  /// Every style `TextTheme` carries, by name, so the test fails when
  /// Flutter adds one rather than silently ignoring it.
  Map<String, TextStyle?> stylesOf(TextTheme t) => {
        'displayLarge': t.displayLarge,
        'displayMedium': t.displayMedium,
        'displaySmall': t.displaySmall,
        'headlineLarge': t.headlineLarge,
        'headlineMedium': t.headlineMedium,
        'headlineSmall': t.headlineSmall,
        'titleLarge': t.titleLarge,
        'titleMedium': t.titleMedium,
        'titleSmall': t.titleSmall,
        'bodyLarge': t.bodyLarge,
        'bodyMedium': t.bodyMedium,
        'bodySmall': t.bodySmall,
        'labelLarge': t.labelLarge,
        'labelMedium': t.labelMedium,
        'labelSmall': t.labelSmall,
      };

  /// The app's real parent theme, reduced to the part that matters:
  /// `workbenchTheme` reads the chain off `parent.textTheme.bodyMedium`.
  ThemeData parentFor(Brightness b) => ThemeData(
        brightness: b,
        fontFamilyFallback: kCjkFontFallback,
        textTheme: (b == Brightness.dark
                ? ThemeData.dark().textTheme
                : ThemeData.light().textTheme)
            .copyWith(
          bodyMedium: (b == Brightness.dark
                  ? ThemeData.dark().textTheme.bodyMedium
                  : ThemeData.light().textTheme.bodyMedium)
              ?.copyWith(fontFamilyFallback: kCjkFontFallback),
        ),
      );

  for (final (label, brightness, paper) in const [
    ('light', Brightness.light, false),
    ('dark', Brightness.dark, false),
    ('paper', Brightness.light, true),
  ]) {
    test('$label: no text style can render Chinese only by luck', () {
      final theme = workbenchTheme(parentFor(brightness), paper: paper);
      final bare = <String>[];
      stylesOf(theme.textTheme).forEach((name, style) {
        final chain = style?.fontFamilyFallback ?? const [];
        if (!chain.contains('NotoSansSC-Sub')) bare.add(name);
      });
      expect(bare, isEmpty,
          reason: 'these styles have no bundled CJK face in reach, so any '
              'Chinese that lands on them draws as □ on web:\n'
              '${bare.join(', ')}\n'
              'Carry the parent chain across the WHOLE text theme in '
              '`workbenchTheme` — do not restate it style by style.');
    });
  }

  test('the bundled CJK face is actually in the shared chain', () {
    // The assertion above is only worth anything if this is the name
    // `pubspec.yaml` registers. If the family is ever renamed, this
    // fails here rather than turning the checks above into a tautology
    // that passes on a font nothing can resolve.
    expect(kCjkFontFallback, contains('NotoSansSC-Sub'));
  });

  testWidgets('a button label in Chinese has a CJK face in reach',
      (tester) async {
    // The style that no `textTheme.labelLarge` grep finds: Material
    // buttons pull it from the theme themselves, so the ~90 button call
    // sites in `lib/` inherit whatever the theme hands them.
    late TextStyle resolved;
    await tester.pumpWidget(MaterialApp(
      theme: workbenchTheme(parentFor(Brightness.light)),
      home: Builder(builder: (context) {
        resolved = Theme.of(context).textTheme.labelLarge!;
        return Scaffold(
          body: TextButton(onPressed: () {}, child: const Text('打开 YsWords')),
        );
      }),
    ));
    expect(resolved.fontFamilyFallback, contains('NotoSansSC-Sub'));
  });
}
