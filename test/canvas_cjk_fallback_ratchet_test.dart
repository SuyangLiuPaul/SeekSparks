import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/utils/font_catalog.dart';

void main() {
  test('canvasTextStyle carries the bundled CJK face', () {
    final st = canvasTextStyle(fontSize: 12);
    expect(st.fontFamilyFallback, kCjkFontFallback);
    expect(st.fontFamilyFallback, contains('NotoSansSC-Sub'));
    expect(st.fontFamily, isNull); // the chain, never a pinned family
    expect(st.fontSize, 12);
  });

  test('canvasTextStyle passes colour and weight through', () {
    final st = canvasTextStyle(
        color: const Color(0xFF123456), fontSize: 9, fontWeight: FontWeight.w600);
    expect(st.color, const Color(0xFF123456));
    expect(st.fontWeight, FontWeight.w600);
    expect(st.fontFamilyFallback, kCjkFontFallback);
  });

  /// Every `TextPainter(` call site in `lib/`, as `path:line` (path using
  /// `/` so the keys are platform-stable), with the +/-30/+20-line window
  /// around it. A forward-only 15-line window (the shape this test used to
  /// have, scoped to one file) reports 11 sites repo-wide, 7 of them false
  /// — a `final style = canvasTextStyle(...)` commonly sits ABOVE its
  /// painter. This asymmetric window is the shape measured to report
  /// exactly the real offenders and nothing else.
  Map<String, String> painterWindows() {
    final out = <String, String>{};
    for (final entity
        in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('TextPainter(')) continue;
        final window = lines
            .sublist(max(0, i - 30), min(i + 20, lines.length))
            .join('\n');
        out['$path:${i + 1}'] = window;
      }
    }
    return out;
  }

  test('every TextPainter in lib/ has a CJK face in reach', () {
    final windows = painterWindows();
    final fails = windows.entries
        .where((e) =>
            !e.value.contains('canvasTextStyle(') &&
            !e.value.contains('fontFamilyFallback:') &&
            !e.value.contains('.merge('))
        .map((e) => e.key)
        .toList();
    expect(fails, isEmpty,
        reason:
            'a TextPainter inherits no theme — on the web build NotoSansSC-Sub '
            'is the only face that can resolve Chinese, so a bare TextStyle '
            'here draws Chinese as nothing, not tofu. Use canvasTextStyle (or '
            'fontFamilyFallback: kCjkFontFallback, or .merge onto the ambient '
            'DefaultTextStyle) at:\n${fails.join('\n')}');
  });

  test('the census of canvas painters is pinned', () {
    final windows = painterWindows();
    final census = <String, int>{};
    for (final key in windows.keys) {
      final path = key.substring(0, key.lastIndexOf(':'));
      census[path] = (census[path] ?? 0) + 1;
    }
    expect(census, {
      'lib/pages/bible_timeline_page.dart': 1,
      'lib/pages/chronology_page.dart': 3,
      'lib/pages/lexicon_page.dart': 1,
      'lib/pages/radial_chronology_page.dart': 9,
      'lib/utils/fitted_label_metrics.dart': 1,
      'lib/widgets/analysis_tabs.dart': 1,
      'lib/widgets/place_map.dart': 2,
    },
        reason:
            'a new canvas TextPainter appeared (or one vanished) without this '
            'ratchet being updated — read the rule above before raising the '
            'number');
  });

  test('only two painters rely on the inherited chain, and they are named',
      () {
    // `.merge(` removed from the accepted routes: this isolates the sites
    // that rely on it, so the escape hatch is enumerated rather than able
    // to spread silently. Both build their style as
    // `DefaultTextStyle.of(context).style.merge(...)` ON PURPOSE —
    // `lexicon_page.dart`'s own doc comment records that measuring
    // WITHOUT the inherited `letterSpacing` clipped every Greek row, and
    // `bible_timeline_page.dart:116-122` records the same 0.25px-a-character
    // finding. Converting either to `canvasTextStyle` would re-break a
    // fixed bug.
    final windows = painterWindows();
    final fails = windows.entries
        .where((e) =>
            !e.value.contains('canvasTextStyle(') &&
            !e.value.contains('fontFamilyFallback:'))
        .map((e) => e.key)
        .toList()
      ..sort();
    expect(fails,
        ['lib/pages/bible_timeline_page.dart:132', 'lib/pages/lexicon_page.dart:698']);
  });

  testWidgets('the ambient DefaultTextStyle carries the bundled CJK face',
      (tester) async {
    // Licenses the `.merge(` route above: a call-site audit cannot see an
    // inherited value, so assert it is actually there rather than assuming
    // it. This is a characterisation test — expected to pass both before
    // and after this change. If it FAILS, that is a larger finding than
    // this file's subject: it would mean the two `.merge(` sites above are
    // real defects, not licensed exceptions. Report it; do not delete the
    // `.merge(` route to make this green.
    for (final brightness in [Brightness.light, Brightness.dark]) {
      late TextStyle captured;
      await tester.pumpWidget(MaterialApp(
        theme: workbenchTheme(
          ThemeData(
            brightness: brightness,
            fontFamilyFallback: kCjkFontFallback,
          ),
        ),
        home: Scaffold(
          body: Builder(builder: (ctx) {
            captured = DefaultTextStyle.of(ctx).style;
            return const SizedBox();
          }),
        ),
      ));
      expect(captured.fontFamilyFallback, contains('NotoSansSC-Sub'),
          reason: '$brightness: the ambient DefaultTextStyle has no bundled '
              'CJK face, so the two .merge( sites in lib/ are not actually '
              'licensed by inheritance');
    }
  });

  test("the wheel's canvas styles all come from canvasTextStyle", () {
    final src = File('lib/pages/radial_chronology_page.dart').readAsStringSync();
    final count = 'canvasTextStyle('.allMatches(src).length;
    expect(count, 8,
        reason:
            'expected 8 canvasTextStyle( call sites (measure, measure-chars, '
            'band name, spoke title, spoke ref, spoke badge, arc text, shared '
            'painter) — a genuine new canvas label should raise this number '
            'in the same commit that adds it');
  });
}
