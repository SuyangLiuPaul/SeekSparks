/// The legend names the rings that are on the chart.
///
/// 2026-09-15. It listed the four Genesis 10 families and the four
/// layers, which is real and stays — but the thing on screen is a
/// handful of named rings carrying symbols, and the sheet a reader
/// opens to ask "what am I looking at" said nothing about either.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/chart_symbol_service.dart';
import 'package:seeksparks/services/chronology_service.dart';
import 'package:seeksparks/widgets/chronology_explorer.dart';
import 'package:seeksparks/utils/chronology_symbols.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WheelHistoryData data;

  setUpAll(() async {
    data = await WheelHistoryService.instance.load();
    await ChronologyService.instance.load();
    await (FontLoader('Roboto')
          ..addFont(rootBundle
              .load('assets/fonts/Roboto-VariableFont_wdth,wght.ttf')))
        .load();
  });

  testWidgets('every drawn ring is named in the legend, with its mark',
      (tester) async {
    await tester.runAsync(() => ChartSymbolService.instance.load());
    addTearDown(ChartSymbolService.instance.resetForTest);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MainProvider()),
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child: MaterialApp(
        theme: ThemeData(
            fontFamily: 'Roboto', fontFamilyFallback: kCjkFontFallback),
        home: const RadialChronologyPage(initialStacked: false),
      ),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // The rings the page decided to draw, read off the page rather than
    // recomputed — a legend that agreed with a copy of the rule while
    // the chart drew something else would be the exact failure this
    // guards.
    final explorer =
        tester.widget<ChronologyExplorer>(find.byType(ChronologyExplorer));
    final drawn = [
      for (final stream in explorer.data.streams)
        if (!explorer.hiddenStreams.contains(stream.id)) stream
    ];
    expect(drawn, isNotEmpty);

    await tester.tap(find.byKey(const ValueKey('wheelLegendControl')));
    await tester.pumpAndSettle();

    for (final stream in drawn) {
      expect(find.text(stream.nameFor('zh-Hans')), findsWidgets,
          reason: '${stream.id} is on the chart and not in the legend');
    }
    // And its mark, for every ring whose stream has one — otherwise a
    // reader meets a crown on the chart with no way to look it up.
    final withSymbol =
        drawn.where((s) => symbolForStream(s.id) != null).toList();
    expect(withSymbol, isNotEmpty);
    expect(find.byType(RawImage), findsNWidgets(withSymbol.length),
        reason: 'the legend drew a different number of marks than the '
            '${withSymbol.length} rings that have one');

    // The families stay. They answer a different question — which
    // descent a hue belongs to — and removing them to make room would
    // be trading one omission for another.
    expect(find.text(wheelStrings['wheelLineShem']!['zh-Hans']!), findsOneWidget);
    expect(data.streams.length, greaterThan(drawn.length),
        reason: 'every stream is drawn, so this test is not exercising '
            'the "legend lists only what is on the chart" claim');
  });
}
