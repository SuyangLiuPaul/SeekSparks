/// The wheel draws at most five streams, and the filter says so.
///
/// 2026-09-15. 「filter in的时候我建议一次别超过3~5个 因为那么多在一起都
/// 没有用其实」 and 「一次不要load太多」.
///
/// The measurement behind the owner's instinct, taken off the shipped
/// asset: 22 streams, 263 powers and 776 events — 1,039 marks with
/// everything on. Even the four spine streams alone carry 280, and 188
/// of those sit on the church ring by itself. So the ceiling is
/// necessary and it is NOT sufficient; it is the first of the fixes,
/// not the whole of it, and nothing here should be read as claiming the
/// chart is legible merely because five rings is fewer than twelve.
///
/// What this file pins is the honest half of the promise: the ceiling
/// binds what is DRAWN, the sheet refuses rather than swapping, and the
/// refusal explains itself. It deliberately does not pin the painter.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yahwehs_sword/models/app_settings.dart';
import 'package:yahwehs_sword/services/chart_symbol_service.dart';
import 'package:yahwehs_sword/utils/chronology_palette.dart';
import 'package:yahwehs_sword/models/wheel_history.dart';
import 'package:yahwehs_sword/pages/radial_chronology_page.dart' show wheelStrings;
import 'package:yahwehs_sword/utils/wheel_default_streams.dart';
import 'package:yahwehs_sword/utils/wheel_search.dart' show kLifespanLayerId;
import 'package:yahwehs_sword/widgets/chronology_filter_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WheelHistoryData data;

  setUpAll(() async {
    data = await WheelHistoryService.instance.load();
    for (final family in ['Roboto', '-apple-system']) {
      await (FontLoader(family)
            ..addFont(rootBundle
                .load('assets/fonts/Roboto-VariableFont_wdth,wght.ttf')))
          .load();
    }
    await (FontLoader('NotoSansSC')
          ..addFont(rootBundle.load('assets/fonts/NotoSansSC-Sub.otf')))
        .load();
  });

  String text(String key, String fallback, String locale) =>
      wheelStrings[key]?[locale] ?? wheelStrings[key]?['en'] ?? fallback;

  /// Hide every stream except [show].
  Set<String> hiddenExcept(Iterable<String> show) {
    final keep = show.toSet();
    return {
      for (final stream in data.streams)
        if (!keep.contains(stream.id)) stream.id,
    };
  }

  /// The real palette, built the way `colorsFor` builds it. The sheet
  /// used to be pumped with an empty map, which made every chip the
  /// muted grey — fine while they were plain squares and useless the
  /// moment the test is about which colour a symbol comes out in.
  Map<String, Color> streamColours() {
    final byLine = <String, List<String>>{};
    for (final stream in data.streams) {
      byLine.putIfAbsent(stream.line, () => []).add(stream.id);
    }
    return {
      for (final stream in data.streams)
        stream.id: streamBandColor(stream.line,
            byLine[stream.line]!.indexOf(stream.id), byLine[stream.line]!.length,
            dark: false)
    };
  }

  Set<String>? applied;

  Future<void> pumpSheet(
    WidgetTester tester, {
    required Set<String> hidden,
    int? ceiling = kMaxVisibleStreams,
    String locale = 'en',
  }) async {
    applied = null;
    tester.view.devicePixelRatio = 1;
    // Tall enough that all four layers and all twenty-two streams are
    // laid out at once. The sheet under test is a list of checkboxes;
    // making the assertions depend on a scroll heuristic would be
    // testing `scrollUntilVisible`, not the ceiling.
    tester.view.physicalSize = const Size(900, 2600);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppSettings(),
      child: MaterialApp(
        theme: ThemeData(
            fontFamily: 'Roboto', fontFamilyFallback: const ['NotoSansSC']),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: OutlinedButton(
                key: const ValueKey('openFilter'),
                onPressed: () async {
                  final result = await showChronologyFilterSheet(
                    context: context,
                    locale: locale,
                    data: data,
                    hidden: hidden,
                    streamColors: streamColours(),
                    layerColors: const {},
                    text: (key, fallback) => text(key, fallback, locale),
                    keyPrefix: 'wheelFilter',
                    streamCeiling: ceiling,
                  );
                  if (result != null) applied = result;
                },
                child: const Text('Open filter'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('openFilter')));
    await tester.pumpAndSettle();
  }

  Finder row(String id) {
    final finder = find.byKey(ValueKey('wheelFilterStream-$id'));
    expect(finder, findsOneWidget, reason: 'no row for stream $id');
    return finder;
  }

  bool enabled(WidgetTester tester, Finder finder) =>
      tester.widget<CheckboxListTile>(finder).onChanged != null;

  const spine = ['scripture', 'israel', 'judah', 'church'];

  testWidgets('a stream with a symbol shows it in the filter, in its own '
      'colour', (tester) async {
    // WHERE THE SYMBOLS BECOME LEARNABLE. The chart draws a crown on
    // the Judah ring with 犹大 beside it, which is enough to guess from
    // and not enough to look up. This list is the only place all
    // nineteen appear at once next to the names they stand for.
    //
    // The tint is asserted too, and not for neatness: the sheet and the
    // canvas read the same palette, so a symbol that meant one colour
    // here and another on the chart would be worse than no symbol.
    await tester.runAsync(() => ChartSymbolService.instance.load());
    addTearDown(ChartSymbolService.instance.resetForTest);
    await pumpSheet(tester, hidden: hiddenExcept(spine));

    RawImage imageIn(Finder row) => tester.widget<RawImage>(
        find.descendant(of: row, matching: find.byType(RawImage)));

    for (final id in ['judah', 'israel', 'egypt', 'china']) {
      final image = imageIn(row(id));
      expect(image.image, isNotNull, reason: '$id drew no symbol');
      expect(image.colorBlendMode, BlendMode.srcIn,
          reason: '$id is not tinted through the palette');
      expect(image.color, isNotNull);
    }

    // Judah and Israel are two shades of Shem's arc and must not come
    // out as one colour here any more than they do on the chart.
    expect(imageIn(row('judah')).color, isNot(imageIn(row('israel')).color));

    // And the three with no symbol keep a plain chip rather than
    // borrowing someone else's mark.
    for (final id in ['anatolia', 'philistia', 'arabia']) {
      expect(find.descendant(of: row(id), matching: find.byType(RawImage)),
          findsNothing,
          reason: '$id was given a symbol the table does not name');
    }
  });

  test('the chart opens on the spine, and the ceiling is far above it',
      () {
    // Not "four is a nice number". Four IS the spine — the line this
    // application follows — and the free slot is the comparison the
    // reader opened the chart to make. Collapse the gap and the wheel
    // becomes a poster: you cannot add Egypt without first deleting
    // something you did not choose to delete.
    // 2026-09-16: this asserted a gap of exactly ONE, which was the
    // 「一次别超过3~5个」 reading. The owner found what a hard five costs
    // 「中国 埃及 日本全部有 为什么现在全部缺失了」 — a reader who wants three
    // of the ancient civilisations beside the spine is refused, and the
    // refusal reads as the data having been deleted.
    //
    // Re-read, the instruction was about the OPENING: 「一开始filter不要
    // 全部都有」. So the low number stays where it was asked for and the
    // ceiling goes back to what the rings can carry. What the reader
    // adds deliberately is their business.
    expect(kOpeningStreams, lessThan(kMaxVisibleStreams));
    // 2026-09-16: 4 → 5. 「有一个全世界的tick也可以在filter而且default是
    // tick的」 — see [kOpeningStreams]. The spine still opens the chart;
    // 全世界 joins it, because it is the lane that says what century the
    // reader is standing in.
    expect(kOpeningStreams, 5);
    expect(kMaxVisibleStreams, greaterThanOrEqualTo(12),
        reason: 'the ancient world has to fit beside the spine');
    expect(defaultVisibleStreams(data.streams.map((s) => s.id), kOpeningStreams),
        [...spine, 'world'],
        reason: 'the opening rings are the spine, in order, and then the '
            'lane that says what century the reader is in');
  });

  test('no canvas, however large, is given more rings than the ceiling', () {
    // The inverted belief this replaces read 4 / 8 / 12 by width. A wall
    // display does not make two similar muted hues easier to tell apart
    // half a circle away from each other.
    for (final side in [320.0, 360.0, 768.0, 1280.0, 2560.0, 4000.0]) {
      expect(
          ringCapacity(side,
              hubFraction: 0.115, bandsFraction: bandsFractionFor(side)),
          lessThanOrEqualTo(kMaxVisibleStreams),
          reason: '$side px drew past the ceiling');
    }
    expect(
        ringCapacity(1280,
            hubFraction: 0.115, bandsFraction: bandsFractionFor(1280)),
        kMaxVisibleStreams,
        reason: 'a desktop should reach the ceiling — five thick rings, '
            'not twelve thin ones');
  });

  testWidgets('at the ceiling, the next stream goes quiet and the sheet '
      'says why',
      (tester) async {
    await pumpSheet(tester,
        hidden: hiddenExcept([...spine, ...kStreamPriority.skip(4).take(8)]));

    expect(find.byKey(const ValueKey('chronologyFilterStreamCount')),
        findsOneWidget);
    expect(find.text('Streams 12 of 12'), findsOneWidget);
    expect(find.byKey(const ValueKey('chronologyFilterCeilingHint')),
        findsOneWidget);

    // A stream that is OFF cannot be turned on...
    expect(enabled(tester, row('china')), isFalse);
    // ...but one that is ON can still be turned off, or the reader is
    // trapped at the ceiling with no way down.
    expect(enabled(tester, row('egypt')), isTrue);
  });

  testWidgets('the four layers are not streams and never count against it',
      (tester) async {
    // Lifespans, reigns, ministries and genealogy are depth inside the
    // spine, not another nation competing for a ring. If the ceiling
    // ever swallowed them, turning on five streams would silently cost
    // the reader the kings of Judah.
    await pumpSheet(tester,
        hidden: {...hiddenExcept([...spine, ...kStreamPriority.skip(4).take(8)]), kLifespanLayerId});
    final lifespans = find.byKey(const ValueKey('wheelFilterLifespans'));
    expect(enabled(tester, lifespans), isTrue);
  });

  testWidgets('taking one off makes room, and the count follows',
      (tester) async {
    await pumpSheet(tester, hidden: hiddenExcept([...spine, ...kStreamPriority.skip(4).take(8)]));
    await tester.tap(row('egypt'));
    await tester.pumpAndSettle();

    expect(find.text('Streams 11 of 12'), findsOneWidget);
    expect(find.byKey(const ValueKey('chronologyFilterCeilingHint')),
        findsNothing);
    final china = row('china');
    expect(enabled(tester, china), isTrue);

    await tester.tap(china);
    await tester.pumpAndSettle();
    expect(find.text('Streams 12 of 12'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chronologyFilterApply')));
    await tester.pumpAndSettle();
    final shown = data.streams
        .map((s) => s.id)
        .where((id) => !applied!.contains(id))
        .toSet();
    // Egypt off, China on — the rest of the twelve untouched.
    expect(shown,
        {...spine, ...kStreamPriority.skip(4).take(8), 'china'}
          ..remove('egypt'));
  });

  testWidgets('All stops meaning all, and stops at the ceiling',
      (tester) async {
    // The button cleared the whole hidden set, which would have put
    // twenty-two rings back on the wheel in one tap and made the
    // ceiling a suggestion.
    await pumpSheet(tester, hidden: hiddenExcept(spine));
    await tester.tap(find.byKey(const ValueKey('chronologyFilterAll')));
    await tester.pumpAndSettle();
    expect(find.text('Streams 12 of 12'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chronologyFilterApply')));
    await tester.pumpAndSettle();
    final shown = data.streams
        .map((s) => s.id)
        .where((id) => !applied!.contains(id))
        .toList();
    expect(shown.length, kMaxVisibleStreams);
    expect(shown.toSet(), containsAll(spine),
        reason: 'All must not drop the spine to make room');
  });

  testWidgets('the strip is held to the same ceiling as the wheel',
      (tester) async {
    // 2026-09-15, and this says the opposite of what it said this
    // morning. It used to assert that passing no ceiling left the sheet
    // exactly as it was, on my argument that a strip lane stacks
    // vertically and prints its own name — labels being read rather
    // than hues being matched.
    //
    // 「filter limit应该apply strip 和 wheel上面吧一起」. The owner's
    // ground is better than mine: the two charts are one product, and a
    // limit that means five here and twelve there is one a reader has
    // to learn twice. Mine was an argument about the drawing; this is
    // an argument about the person using it.
    //
    // The sheet still TAKES a ceiling rather than assuming one, so that
    // a chart which genuinely does not need one has to say so — and the
    // second half below keeps that path honest.
    await pumpSheet(tester, hidden: hiddenExcept([...spine, ...kStreamPriority.skip(4).take(8)]));
    expect(find.text('Streams 12 of 12'), findsOneWidget);
    expect(enabled(tester, row('china')), isFalse,
        reason: 'the strip let a thirteenth lane on');
  });

  testWidgets('a sheet given no ceiling still behaves as it always did',
      (tester) async {
    // The other half of the decision above. Both charts pass a ceiling
    // today, so this path has no caller — which is exactly why it is
    // worth a test: a chart that genuinely does not need a limit should
    // be able to say so, and "no ceiling" must keep meaning no ceiling
    // rather than quietly becoming five because nothing checked.
    await pumpSheet(tester, hidden: hiddenExcept(spine), ceiling: null);
    expect(find.byKey(const ValueKey('chronologyFilterStreamCount')),
        findsNothing);
    expect(enabled(tester, row('china')), isTrue);
  });
}
