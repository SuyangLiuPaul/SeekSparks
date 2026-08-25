/// The chronology wheel, mounted against the real asset and TAPPED.
///
/// Nothing had ever pumped this page. `radial_chronology_layout_test.dart`
/// pins the geometry as pure arithmetic and `wheel_history_asset_test.dart`
/// pins the data, and between them they left the widget itself untested —
/// which is how a `CustomPainter` change and four call-site edits could
/// have shipped on the strength of `flutter analyze` alone.
///
/// Rendered in the app's shipped default (zh-Hans), for the same reason
/// `chronology_page_test.dart` is: `AppSettings.setLocale` leaves a
/// notification-rescheduling timer pending that fails teardown.
///
/// THE PAGE AT REST SHOWS NO REFERENCE. Its resting state is four
/// `RichText` nodes, of which one holds the title and three are empty;
/// every verse is behind a tap. A sweep of the page as pumped therefore
/// passes whatever the references say, which is a green light for the
/// defect it exists to catch — so the sweep below TAPS its way across the
/// wheel and reads the detail sheets, and asserts a floor on both the
/// sheets it opened and the references it found in them.
///
/// WHAT IT STILL CANNOT SEE. The wheel draws its band names, its spoke
/// labels and the verse beside each spoke ON A CANVAS, through
/// `TextPainter`. None of those is a `RichText`, so this is structurally
/// blind to them — a span sweep is not a screen sweep. The canvas ring
/// label is covered by `wheel_history_disclosure_test.dart` at the data
/// layer and by eye on the deployed build.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart';
import 'package:seeksparks/providers/main_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WheelHistoryData data;
  setUpAll(() async {
    // Loaded out here on purpose. `rootBundle.loadString` is real I/O and
    // never completes inside a widget test's fake-async zone; the service
    // caches, so the page's own `load()` in `initState` resolves from the
    // cache and the wheel builds.
    data = await WheelHistoryService.instance.load();
  });

  Future<void> pump(WidgetTester tester, Size size) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: const MaterialApp(home: RadialChronologyPage()),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('the wheel builds and paints against the real asset',
      (tester) async {
    await pump(tester, const Size(1440, 900));
    expect(tester.takeException(), isNull);
    // The key, not `findsWidgets` on CustomPaint — Material paints plenty
    // of its own, so the loose finder is satisfied by a page stuck on its
    // loading spinner.
    expect(find.byKey(const ValueKey('chronologyWheel')), findsOneWidget);
    await unmount(tester);
  });

  /// The reference the reader taps has to stay the ENGLISH string, because
  /// that is what `parseReference` reads on the way back. Only the printed
  /// form is localised. If a future edit ever localises at the source
  /// instead of at the print site, the model's refs stop parsing and every
  /// tap on this page dies silently — so pin the storage form too.
  test('references are stored in English and localised only for display',
      () {
    final stored = <String>[
      for (final e in data.events) ...e.refs,
      for (final n in data.nations)
        if (n.ref.isNotEmpty) n.ref,
      for (final p in data.powers) ...p.refs,
    ];
    expect(stored, isNotEmpty);
    for (final r in stored) {
      expect(RegExp(r'^[1-3]?\s?[A-Za-z]').hasMatch(r), isTrue,
          reason: '"$r" is not stored in the English form the parser needs');
    }
  });

  testWidgets('no English scripture reference reaches the Chinese reader',
      (tester) async {
    await pump(tester, const Size(1440, 900));
    final rect = tester.getRect(find.byKey(const ValueKey('chronologyWheel')));
    final side = rect.width;
    final centre = rect.center;

    // The wheel's own frame, restated rather than imported because the
    // fractions are private to the page: it starts at twelve o'clock and
    // sweeps 320°, the bands sit between 0.115 and 0.285 of the side and
    // the event spokes between there and 0.445.
    const startRad = -math.pi / 2;
    const sweepRad = 320 * math.pi / 180;

    // A reference is a book name followed by chapter:verse. Matching the
    // SHAPE rather than a book list is deliberate — pinning "Genesis"
    // finds one member of a class of 111.
    final englishRef = RegExp(r'\b[1-3]?\s?[A-Z][a-z]+\s+\d+:\d+');
    // And the shape with the book name taken off, which every localised
    // reference still has. This is the floor: it counts the references the
    // sweep actually reached, so a sweep that reached none cannot pass.
    final anyRef = RegExp(r'\d+:\d+');

    var sheets = 0;
    var refsSeen = 0;
    final offenders = <String>{};
    for (var ri = 0; ri < 8; ri++) {
      final r = side * (0.13 + (0.43 - 0.13) * ri / 7);
      for (var ai = 0; ai < 16; ai++) {
        final a = startRad + sweepRad * ai / 15;
        await tester.tapAt(centre + Offset(r * math.cos(a), r * math.sin(a)));
        await tester.pump(const Duration(milliseconds: 400));
        // A tap that opened nothing landed in a gap between bands; that is
        // the wheel behaving, not a failure.
        if (find.byType(BottomSheet).evaluate().isEmpty) continue;
        sheets++;
        for (final para
            in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
          final plain = para.text.toPlainText();
          refsSeen += anyRef.allMatches(plain).length;
          offenders.addAll(englishRef.allMatches(plain).map((m) => m.group(0)!));
        }
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    // Opening a detail sheet used to throw before it opened: `WbType.of`
    // WATCHES the settings, and a tap handler is not a build. Nothing else
    // in this file would notice, because a sweep over a page that never
    // opened a sheet passes.
    expect(tester.takeException(), isNull);
    // Measured at 56 sheets and 34 references on a 1440×900 view; floored
    // well under both, because these are a FLOOR ON THE INSTRUMENT and not
    // a pin on the data. A sheet is a scroll view, so the sweep sees the
    // references that are on screen and not the ones below the fold —
    // which is the right reach for a test asking what a reader is shown.
    expect(sheets, greaterThan(40),
        reason: 'the sweep opened almost nothing, so it proved almost nothing');
    expect(refsSeen, greaterThan(25),
        reason: 'the sweep opened $sheets sheets and found next to no verse in '
            'any of them — it is not reading the text it exists to check');
    expect(offenders, isEmpty,
        reason: 'the wheel shows a Chinese reader an English reference');
    await unmount(tester);
  });
}
