/// The Analysis strip's label rule, in a locale whose glyphs are
/// full-width (task #297).
///
/// The defect this guards: `_kMinLabelledTabWidth` was a single Latin
/// constant, 66 px, described in its own comment as "about six
/// characters of 11.5 px text". CJK labels are four FULL-WIDTH glyphs —
/// 原文研读 is ~46 px of text before the icon, the gap and the padding —
/// so the rule answered "the labels fit", and Flutter then ellipsised
/// them to 原文…, 相关…, 经文…. Invisible in English, invisible to the
/// suite, and shipped.
///
/// So the width a labelled tab needs is now MEASURED from the labels
/// actually being drawn, and the layout rule takes it as a parameter.
/// These tests pin both halves, plus the reader's override.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/widgets/analysis_tabs.dart';

void main() {
  // The twelve labels as they actually are, in the two scripts that
  // showed the defect and the one that hid it.
  const zhHans = [
    '原文研读',
    '互参',
    '统计',
    '上下文',
    '相关经文',
    '经文列表',
    '短语',
    '生词',
    '词形',
    '主题',
    '语境',
    '地名',
  ];
  const zhHant = [
    '原文研讀',
    '互參',
    '統計',
    '上下文',
    '相關經文',
    '經文列表',
    '短語',
    '生詞',
    '詞形',
    '主題',
    '語境',
    '地名',
  ];
  const en = [
    'Word Study',
    'X-Refs',
    'Stats',
    'KWIC',
    'Related',
    'Lists',
    'Phrases',
    'Vocab',
    'Forms',
    'Topics',
    'Context',
    'Places',
  ];

  group('analysisStripMinLabelledWidth', () {
    test('a four-glyph CJK label needs more than the old 66 px constant',
        () {
      // The measurement is what the constant guessed at. If this ever
      // drops back under 66 the guess would have been safe and this
      // whole change is unnecessary — so assert the premise, not just
      // the fix.
      expect(analysisStripMinLabelledWidth(zhHans), greaterThan(66));
      expect(analysisStripMinLabelledWidth(zhHant), greaterThan(66));
    });

    test('it answers for the WIDEST label, not the first or the average',
        () {
      final widest = analysisStripMinLabelledWidth(zhHans);
      for (final one in zhHans) {
        expect(analysisStripMinLabelledWidth([one]),
            lessThanOrEqualTo(widest + 0.001),
            reason: '"$one" measured wider than the whole set');
      }
      expect(analysisStripMinLabelledWidth(['原文研读']), widest);
    });

    test('a larger reader text scale needs a wider tab', () {
      expect(
        analysisStripMinLabelledWidth(zhHans,
            textScaler: const TextScaler.linear(1.5)),
        greaterThan(analysisStripMinLabelledWidth(zhHans)),
      );
    });

    test('no labels is just the chrome, not a crash', () {
      expect(analysisStripMinLabelledWidth(const []), greaterThan(0));
    });
  });

  group('analysisStripLayout with a measured width', () {
    test('the 420 px default pane will not claim CJK labels fit', () {
      // Two rows of six is 70 px a tab. The old rule compared that with
      // 66 and said yes; the measurement says a Chinese label needs
      // more, so the strip shows icons instead of cutting words.
      final min = analysisStripMinLabelledWidth(zhHans);
      final l = analysisStripLayout(420, 12, minLabelledTabWidth: min);
      expect(70, lessThan(min), reason: 'the premise of this test');
      expect(l.showLabels, isFalse);
    });

    test('a wide pane still labels, in every locale', () {
      for (final labels in [zhHans, zhHant, en]) {
        final min = analysisStripMinLabelledWidth(labels);
        final l = analysisStripLayout(1200, 12, minLabelledTabWidth: min);
        expect(l.showLabels, isTrue);
        expect(1200 / l.perRow, greaterThanOrEqualTo(min));
      }
    });

    test('whenever it claims labels, the tab really is wide enough', () {
      for (final labels in [zhHans, zhHant, en]) {
        final min = analysisStripMinLabelledWidth(labels);
        for (var w = 60.0; w <= 1400.0; w += 3) {
          for (final prefer in [false, true]) {
            final l = analysisStripLayout(w, 12,
                minLabelledTabWidth: min, preferLabels: prefer);
            if (l.showLabels) {
              expect(w / l.perRow, greaterThanOrEqualTo(min - 0.001),
                  reason: 'label cut at ${w}px, prefer=$prefer');
            }
          }
        }
      }
    });

    test('the reader asking for names is always honoured at any width '
        'the app can reach', () {
      // The pane floor is 256 px (task #287). Above it, spending rows
      // always beats refusing: one tab a row is far wider than any
      // label, so the icon fallback is unreachable here.
      for (final labels in [zhHans, zhHant, en]) {
        final min = analysisStripMinLabelledWidth(labels);
        for (var w = 256.0; w <= 1400.0; w += 8) {
          final l =
              analysisStripLayout(w, 12, minLabelledTabWidth: min,
                  preferLabels: true);
          expect(l.showLabels, isTrue,
              reason: 'names refused at ${w}px for ${labels.first}');
        }
      }
    });

    test('deciding for itself, the strip never spends more than two rows',
        () {
      for (final labels in [zhHans, zhHant, en]) {
        final min = analysisStripMinLabelledWidth(labels);
        for (var w = 60.0; w <= 1400.0; w += 3) {
          final l = analysisStripLayout(w, 12, minLabelledTabWidth: min);
          if (l.showLabels) {
            expect((12 / l.perRow).ceil(), lessThanOrEqualTo(2),
                reason: 'the strip took ${(12 / l.perRow).ceil()} rows '
                    'at ${w}px unasked');
          }
        }
      }
    });
  });

  group('AnalysisTabStrip', () {
    Future<void> pumpStrip(
      WidgetTester tester, {
      required String locale,
      required double width,
      bool preferLabels = false,
    }) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: AnalysisTabStrip(
              current: AnalysisTab.wordStudy,
              locale: locale,
              preferLabels: preferLabels,
              onChanged: (_) {},
            ),
          ),
        ),
      ));
    }

    testWidgets('at the default pane width a Chinese strip shows icons, '
        'not cut words', (tester) async {
      await pumpStrip(tester, locale: 'zh-Hans', width: 420);
      expect(find.text('原文研读'), findsNothing);
      expect(find.text('相关经文'), findsNothing);
    });

    testWidgets('asking for names gets whole names, in Simplified',
        (tester) async {
      await pumpStrip(tester,
          locale: 'zh-Hans', width: 420, preferLabels: true);
      for (final label in zhHans) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('asking for names gets whole names in Traditional too, '
        'at the 256 px pane floor', (tester) async {
      await pumpStrip(tester,
          locale: 'zh-Hant', width: 256, preferLabels: true);
      for (final label in zhHant) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('no label is ever laid out wider than its tab',
        (tester) async {
      // The ellipsis in `_TabButton` is a backstop; this asserts it is
      // never reached, which `find.text` alone cannot show — an
      // ellipsised label is still findable by its full text.
      for (final locale in ['zh-Hans', 'zh-Hant', 'en']) {
        for (final width in [256.0, 420.0, 1200.0]) {
          await pumpStrip(tester,
              locale: locale, width: width, preferLabels: true);
          for (final element in find.byType(Text).evaluate()) {
            final box = element.renderObject as RenderBox;
            final text = (element.widget as Text).data ?? '';
            final painter = TextPainter(
              text: TextSpan(
                text: text,
                style: (element.widget as Text).style,
              ),
              textDirection: TextDirection.ltr,
              maxLines: 1,
            )..layout();
            expect(painter.width, lessThanOrEqualTo(box.size.width + 0.5),
                reason: '"$text" is cut at $locale/${width}px');
            painter.dispose();
          }
        }
      }
    });
  });
}
