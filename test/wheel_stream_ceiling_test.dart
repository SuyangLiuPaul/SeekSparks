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

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart' show wheelStrings;
import 'package:seeksparks/utils/wheel_default_streams.dart';
import 'package:seeksparks/utils/wheel_search.dart' show kLifespanLayerId;
import 'package:seeksparks/widgets/chronology_filter_sheet.dart';

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
                    streamColors: const {},
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

  test('the opening set leaves exactly one slot free', () {
    // Not "four is a nice number". Four IS the spine — the line this
    // application follows — and the free slot is the comparison the
    // reader opened the chart to make. Collapse the gap and the wheel
    // becomes a poster: you cannot add Egypt without first deleting
    // something you did not choose to delete.
    expect(kOpeningStreams, lessThan(kMaxVisibleStreams));
    expect(kMaxVisibleStreams - kOpeningStreams, 1);
    expect(defaultVisibleStreams(data.streams.map((s) => s.id), kOpeningStreams),
        spine,
        reason: 'the opening rings are meant to BE the spine, in order');
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

  testWidgets('at five, the sixth stream goes quiet and the sheet says why',
      (tester) async {
    await pumpSheet(tester,
        hidden: hiddenExcept([...spine, 'egypt']));

    expect(find.byKey(const ValueKey('chronologyFilterStreamCount')),
        findsOneWidget);
    expect(find.text('Streams 5 of 5'), findsOneWidget);
    expect(find.byKey(const ValueKey('chronologyFilterCeilingHint')),
        findsOneWidget);

    // A stream that is OFF cannot be turned on...
    expect(enabled(tester, row('rome')), isFalse);
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
        hidden: {...hiddenExcept([...spine, 'egypt']), kLifespanLayerId});
    final lifespans = find.byKey(const ValueKey('wheelFilterLifespans'));
    expect(enabled(tester, lifespans), isTrue);
  });

  testWidgets('taking one off makes room, and the count follows',
      (tester) async {
    await pumpSheet(tester, hidden: hiddenExcept([...spine, 'egypt']));
    await tester.tap(row('egypt'));
    await tester.pumpAndSettle();

    expect(find.text('Streams 4 of 5'), findsOneWidget);
    expect(find.byKey(const ValueKey('chronologyFilterCeilingHint')),
        findsNothing);
    final rome = row('rome');
    expect(enabled(tester, rome), isTrue);

    await tester.tap(rome);
    await tester.pumpAndSettle();
    expect(find.text('Streams 5 of 5'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chronologyFilterApply')));
    await tester.pumpAndSettle();
    final shown = data.streams
        .map((s) => s.id)
        .where((id) => !applied!.contains(id))
        .toSet();
    expect(shown, {...spine, 'rome'});
  });

  testWidgets('All stops meaning all, and stops at the ceiling',
      (tester) async {
    // The button cleared the whole hidden set, which would have put
    // twenty-two rings back on the wheel in one tap and made the
    // ceiling a suggestion.
    await pumpSheet(tester, hidden: hiddenExcept(spine));
    await tester.tap(find.byKey(const ValueKey('chronologyFilterAll')));
    await tester.pumpAndSettle();
    expect(find.text('Streams 5 of 5'), findsOneWidget);

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

  testWidgets('the strip keeps every lane — this ceiling is the wheel’s',
      (tester) async {
    // Its lanes stack vertically and each prints its own name, so a
    // reader there reads labels instead of matching hues. Passing no
    // ceiling has to leave the sheet exactly as it was.
    await pumpSheet(tester, hidden: hiddenExcept(spine), ceiling: null);
    expect(find.byKey(const ValueKey('chronologyFilterStreamCount')),
        findsNothing);
    expect(enabled(tester, row('rome')), isTrue);
    await tester.tap(find.byKey(const ValueKey('chronologyFilterAll')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chronologyFilterApply')));
    await tester.pumpAndSettle();
    expect(applied, isEmpty, reason: 'All still means all without a ceiling');
  });
}
