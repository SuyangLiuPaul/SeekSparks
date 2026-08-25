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
import 'package:seeksparks/utils/wheel_search.dart' show kWheelNearestPerYear;

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

  /// THE EVENTS BEHIND A SPOKE ARE REACHABLE, AND THE COUNT IS HONEST.
  ///
  /// Until 2026-08-25 a tap could only ever reach the 55 events the rim
  /// happened to draw, because `_handleTap` iterates the drawn spokes:
  /// the other 436 had no hit target anywhere on the page, at any zoom.
  /// A spoke now stands for its whole cluster, so this asks the page for
  /// the one thing the pure geometry cannot answer — that the tap opens
  /// the list, and that the number in its header is the number of rows
  /// under it. A header that says 66 over 12 rows would be the old
  /// silent narrowing wearing a count.
  testWidgets('a spoke standing for several events lists all of them',
      (tester) async {
    await pump(tester, const Size(1440, 900));
    final rect = tester.getRect(find.byKey(const ValueKey('chronologyWheel')));
    final side = rect.width;
    final centre = rect.center;
    const startRad = -math.pi / 2;
    const sweepRad = 320 * math.pi / 180;

    // '大事 · 66' — the sheet's own header, in the shipped default
    // locale. A stream's sheet prints the identical header over its own
    // event list, so the cluster sheet is identified by the note only it
    // carries. Matching on the header alone found the stream sheet and
    // measured the wrong list.
    final header = RegExp(r'^大事 · (\d+)$');
    const note = '此处轮缘只容得下一个名称。点按任一大事可打开。';
    var listsOpened = 0;
    var biggest = 0;

    // The event spokes live between the bands at 0.285 and the rim at
    // 0.445, so sweep that annulus rather than the whole disc.
    for (var ri = 0; ri < 4; ri++) {
      final r = side * (0.30 + (0.44 - 0.30) * ri / 3);
      for (var ai = 0; ai < 40; ai++) {
        final a = startRad + sweepRad * ai / 39;
        await tester.tapAt(centre + Offset(r * math.cos(a), r * math.sin(a)));
        await tester.pump(const Duration(milliseconds: 400));
        if (find.byType(BottomSheet).evaluate().isEmpty) continue;

        int? stated;
        var isCluster = false;
        for (final para in tester
            .renderObjectList<RenderParagraph>(find.byType(RichText))) {
          final plain = para.text.toPlainText().trim();
          final m = header.firstMatch(plain);
          if (m != null) stated = int.parse(m.group(1)!);
          if (plain == note) isCluster = true;
        }
        if (isCluster && stated != null && stated > 1) {
          listsOpened++;
          if (stated > biggest) biggest = stated;
          // One tappable row per member is what makes them reachable.
          //
          // Counting the `InkWell`s in the tree does NOT answer this:
          // the sheet is a `ListView`, which builds only what its
          // viewport needs, so a complete list of 47 shows 22 elements
          // and a truncated list of 22 shows the same 22. The instrument
          // has to do what the reader does — go to the bottom — and
          // count what it passes.
          //
          // Rows are identified by where they sit in the list, not by
          // what they say. `nero_persecution` and `great_fire_rome` are
          // two records for one fire — same year, same title in all
          // three locales — so a set keyed on the words would silently
          // count 46 of 47 and blame the page for it. They are the only
          // such pair in the 491.
          final pos = tester
              .state<ScrollableState>(find.descendant(
                  of: find.byType(BottomSheet),
                  matching: find.byType(Scrollable)))
              .position;
          final seen = <int>{};
          void harvest() {
            for (final ink in find
                .descendant(
                    of: find.byType(BottomSheet),
                    matching: find.byType(InkWell))
                .evaluate()) {
              final box = ink.renderObject as RenderBox?;
              if (box == null || !box.hasSize) continue;
              seen.add(
                  (box.localToGlobal(Offset.zero).dy + pos.pixels).round());
            }
          }

          harvest();
          // Driven through the scroll position rather than by dragging.
          // A drag on this sheet never moves it — the modal's own
          // drag-to-dismiss recogniser takes the gesture, so `pixels`
          // stays at 0.0 and the list looks truncated when it is not.
          // That is an arena question, and this test is not asking it.
          var at = 0.0;
          while (seen.length < stated && at < pos.maxScrollExtent) {
            at = math.min(at + pos.viewportDimension * 0.8,
                pos.maxScrollExtent);
            pos.jumpTo(at);
            await tester.pump();
            harvest();
          }
          expect(seen.length, equals(stated),
              reason: 'the sheet said $stated events and a reader who '
                  'went to the bottom of it could open ${seen.length}');
        }
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    expect(tester.takeException(), isNull);
    expect(listsOpened, greaterThan(3),
        reason: 'the sweep never landed on a clustered spoke, so it '
            'checked nothing — 49 of the 55 spokes drawn at rest stand '
            'for more than one event');
    expect(biggest, greaterThan(5),
        reason: 'the crowded stretches are the whole point; a sweep that '
            'only found pairs is not reaching them');
    await unmount(tester);
  });

  /// FIND — the half of BibleWorks' Timeline command line this page did
  /// not have.
  ///
  /// `wheel_search_test.dart` pins the search itself, exhaustively and
  /// against the real asset. What it cannot answer is whether the box
  /// on the page is WIRED to it, and that is where this feature can
  /// still be wholly broken with every other test green: the sheet has
  /// to open, the rows have to be tappable, and the tap has to land on
  /// the right record's detail sheet.
  ///
  /// Rendered in the shipped default (zh-Hans), so "Magna Carta" also
  /// exercises the cross-locale path end to end — the query is English,
  /// every string on screen is Chinese, and the row still has to be
  /// there and still has to open the right thing.
  /// Several frames, not one, and both reasons bit while this was
  /// written. The find sheet is opened from the AppBar, OUTSIDE the
  /// page's own `FutureBuilder`, so it resolves the data again: frame
  /// one builds the route with nothing yet and the already-completed
  /// future arrives in a microtask after it. And a route that has been
  /// popped is only taken out of the tree once its exit animation has
  /// finished AND the frame after that has run — so a single pump sees
  /// the old sheet still there and reads it as "the tap did nothing".
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> openFind(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.search));
    await settle(tester);
  }

  String sheetText(WidgetTester tester) => tester
      .renderObjectList<RenderParagraph>(find.byType(RichText))
      .map((p) => p.text.toPlainText())
      .join('\n');

  testWidgets('the find box opens and teaches what it can be asked',
      (tester) async {
    await pump(tester, const Size(1440, 900));
    await openFind(tester);
    expect(tester.takeException(), isNull,
        reason: 'opening the box threw — `WbType.of` watches, and the '
            'AppBar action is a tap handler, not a build');
    expect(find.byKey(const ValueKey('wheelFindField')), findsOneWidget);

    // The status line always says something, and with nothing typed it
    // says what is searchable. The counts are read from the asset so
    // this cannot drift into a hardcoded advertisement.
    final text = sheetText(tester);
    for (final n in [
      data.events.length,
      data.powers.length,
      data.nations.length,
      data.streams.length,
    ]) {
      expect(text, contains('$n'),
          reason: 'the box does not tell the reader it can search $n of '
              'something');
    }
    await unmount(tester);
  });

  testWidgets('an English query opens the Chinese record it found',
      (tester) async {
    await pump(tester, const Size(1440, 900));
    await openFind(tester);

    final event =
        data.events.firstWhere((e) => e.id == 'magna_carta', orElse: () {
      // Identified by its English title rather than its id, so a data
      // edit that renames the record fails loudly here instead of
      // quietly selecting a different one.
      return data.events.firstWhere(
          (e) => (e.titles['en'] ?? '').contains('Magna Carta'));
    });
    final zh = event.titles['zh-Hans']!;
    expect(zh, isNotEmpty);

    await tester.enterText(
        find.byKey(const ValueKey('wheelFindField')), 'Magna Carta');
    await settle(tester);

    // The row prints the title the reader is shown, and the English
    // string it actually matched — a row whose words do not contain
    // what was typed reads as a wrong result unless it explains itself.
    final listed = sheetText(tester);
    expect(listed, contains(zh));
    expect(listed, contains('Magna Carta'));
    expect(listed, contains(yearLabel(event.year, 'zh-Hans')));

    await tester.tap(find.text(zh).first);
    await settle(tester);
    expect(tester.takeException(), isNull);

    // The search sheet is gone and the record's own sheet is open. The
    // field is the search sheet's, so its absence is what proves the
    // swap rather than the mere presence of some bottom sheet.
    expect(find.byKey(const ValueKey('wheelFindField')), findsNothing);
    expect(find.byType(BottomSheet), findsOneWidget);
    final opened = sheetText(tester);
    expect(opened, contains(zh));
    expect(opened, contains(yearLabel(event.year, 'zh-Hans')),
        reason: 'the sheet that opened is not the record that was tapped');
    await unmount(tester);
  });

  testWidgets('a year finds what happened in it, and says what is only near',
      (tester) async {
    await pump(tester, const Size(1440, 900));
    await openFind(tester);
    await tester.enterText(
        find.byKey(const ValueKey('wheelFindField')), '主前586');
    await settle(tester);

    final text = sheetText(tester);
    // The year the query was read as, echoed back. A search box that
    // reads "主前586" as a year and does not say so leaves the reader
    // unable to tell a year query from a word query.
    expect(text, contains('主前586'));
    // The near-miss rows are labelled and their number is disclosed —
    // a cap on a sorted list is a silent WHERE clause otherwise.
    expect(text, contains('年份相近'));
    expect(text, contains('$kWheelNearestPerYear'));
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('a query nothing matches says so, in the reader\'s words',
      (tester) async {
    await pump(tester, const Size(1440, 900));
    await openFind(tester);
    await tester.enterText(
        find.byKey(const ValueKey('wheelFindField')), 'qqzzxx');
    await settle(tester);
    expect(sheetText(tester), contains('没有找到「qqzzxx」'));
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  /// Found on the deployed build, not here: one hit sat at the top of an
  /// otherwise empty half-page, because a `ListView` inside a `Flexible`
  /// takes every pixel it is offered and the sheet offers 70% of the
  /// screen. Every other test was green — they all read text, and the
  /// text was right. A list's height is not something reading its rows
  /// can see.
  testWidgets('the result list is as tall as its results, not as tall as '
      'it is allowed', (tester) async {
    const height = 900.0;
    await pump(tester, const Size(1440, height));
    await openFind(tester);
    final list = find.byKey(const ValueKey('wheelFindList'));
    // The sheet's own ceiling, which is what the list used to take
    // whatever it held.
    const allowance = height * 0.7;

    expect(tester.getSize(list).height, lessThan(allowance / 2),
        reason: 'with nothing typed there are no rows at all');

    await tester.enterText(
        find.byKey(const ValueKey('wheelFindField')), 'Magna Carta');
    await settle(tester);
    expect(sheetText(tester), contains('1 项'));
    final one = tester.getSize(list).height;
    expect(one, lessThan(allowance / 2),
        reason: 'one result must not reserve half the screen');

    // And the shrink-wrap must not have turned into a cap: a long list
    // still fills the allowance and scrolls.
    await tester.enterText(find.byKey(const ValueKey('wheelFindField')), '*');
    await settle(tester);
    final many = tester.getSize(list).height;
    expect(many, greaterThan(one * 3));
    expect(many, lessThanOrEqualTo(allowance + 0.5));
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  /// English inflects and Chinese does not, so a single count string
  /// cannot serve both. "1 results" shipped to the dev build and no
  /// assertion anywhere could see it, because every widget test here
  /// renders the zh-Hans default where the two forms are identical.
  test('the count line has an English singular', () {
    final one = wheelStrings['wheelFindCountOne']!;
    final many = wheelStrings['wheelFindCount']!;
    expect(one['en'], '{n} result');
    expect(many['en'], '{n} results');
    for (final locale in ['zh-Hans', 'zh-Hant']) {
      expect(one[locale], many[locale],
          reason: 'Chinese does not inflect for number, so inventing a '
              'second form here would only be a place to diverge');
    }
  });
}
