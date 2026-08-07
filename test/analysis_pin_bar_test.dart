/// The pin bar is the guaranteed way out of a pinned state.
///
/// It matters more than it looks: a pin survives a chapter change, so
/// the gold marker in the text can be off screen while the pin still
/// stands, and at that moment this strip is the ONLY thing telling the
/// reader why hovering stopped doing anything.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/models/app_settings.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/widgets/analysis_pin_bar.dart';

void main() {
  Future<int> pumpBar(
    WidgetTester tester, {
    String word = 'ἀγάπη',
    String reference = 'John 1:3',
    String locale = 'en',
    WbColors colors = WbColors.light,
  }) async {
    var taps = 0;
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppSettings(),
        child: MaterialApp(
          theme: ThemeData(extensions: [colors]),
          home: Scaffold(
            body: AnalysisPinBar(
              word: word,
              reference: reference,
              locale: locale,
              onUnpin: () => taps++,
            ),
          ),
        ),
      ),
    );
    return taps;
  }

  testWidgets('names the pinned word and where it is', (tester) async {
    await pumpBar(tester);
    expect(find.textContaining('ἀγάπη', findRichText: true), findsOneWidget);
    expect(find.textContaining('John 1:3', findRichText: true), findsOneWidget);
    expect(find.text('Unpin'), findsOneWidget);
  });

  testWidgets('the Unpin button releases the pin', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppSettings(),
        child: MaterialApp(
          theme: ThemeData(extensions: const [WbColors.light]),
          home: Scaffold(
            body: AnalysisPinBar(
              word: 'λόγος',
              reference: 'John 1:1',
              locale: 'en',
              onUnpin: () => taps++,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Unpin'));
    await tester.pump();
    expect(taps, 1);
  });

  // The bar is drawn in the pin's own gold, the same colour as the
  // border round the pinned word, so the strip and the marker in the
  // text read as one thing rather than two unrelated highlights.
  testWidgets('is drawn in the palette pin colour', (tester) async {
    for (final wb in [WbColors.light, WbColors.dark, WbColors.paper]) {
      await pumpBar(tester, colors: wb);
      // MaterialApp lerps a theme swap, and a half-lerped WbColors is a
      // palette that ships nowhere.
      await tester.pumpAndSettle();
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(AnalysisPinBar),
          matching: find.byType(Container),
        ).first,
      );
      final d = box.decoration as BoxDecoration;
      expect((d.border as Border).bottom.color, wb.pinMark);
      expect(d.color, wb.selectionBg);
    }
  });

  // A reader who cannot read the interface cannot be told to use it.
  // Every string on the one control that releases a state must exist in
  // all three locales the app ships.
  for (final key in ['analysisPinned', 'analysisUnpin', 'analysisUnpinHint']) {
    test('$key is translated in every shipped locale', () {
      final entry = uiStrings[key];
      expect(entry, isNotNull, reason: '$key missing from ui_strings');
      for (final loc in ['en', 'zh-Hans', 'zh-Hant']) {
        expect(entry![loc], isNotNull, reason: '$key has no $loc');
        expect(entry[loc], isNotEmpty);
      }
    });
  }

  testWidgets('renders the Chinese labels without falling back to English',
      (tester) async {
    await pumpBar(tester, locale: 'zh-Hant', word: '愛', reference: '約 1:3');
    expect(find.text('取消固定'), findsOneWidget);
    expect(find.text('Unpin'), findsNothing);
  });

  testWidgets('a long word does not overflow the strip', (tester) async {
    await pumpBar(
      tester,
      word: 'ἀ' * 200,
      reference: 'A very long localised book name 119:176',
    );
    expect(tester.takeException(), isNull);
  });
}
