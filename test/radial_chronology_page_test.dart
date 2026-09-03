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

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/services/hebrew_kings_service.dart';
import 'package:seeksparks/models/hebrew_king.dart';
import 'package:seeksparks/pages/chronology_page.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/chronology_service.dart';
import 'package:seeksparks/utils/version_mapper.dart'
    show localizedReferenceLabel;
import 'package:seeksparks/utils/wheel_search.dart' show kWheelNearestPerYear;
import 'package:seeksparks/widgets/person_detail_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WheelHistoryData data;
  setUpAll(() async {
    // Loaded out here on purpose. `rootBundle.loadString` is real I/O and
    // never completes inside a widget test's fake-async zone; the service
    // caches, so the page's own `load()` in `initState` resolves from the
    // cache and the wheel builds.
    data = await WheelHistoryService.instance.load();
    // The seam note's door opens ChronologyPage, whose own asset load
    // would never resolve inside a widget test's fake-async zone. Warm
    // the same cache for the same reason.
    await ChronologyService.instance.load();
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
          // what they say. When this was written `nero_persecution` and
          // `great_fire_rome` were two records for one fire, carrying
          // the SAME title in all three locales, so a set keyed on the
          // words would silently count 46 of 47 and blame the page for
          // it — the only such pair in the corpus.
          //
          // 2026-09-03: they are two events now, the fire and the
          // persecution, with different titles — and their ids had been
          // left CROSSED, each carrying the other's headline, which is
          // how that split was found. Keying by position is kept
          // anyway: it is the reader's own way through a lazy list, and
          // it does not need the corpus to stay free of duplicate
          // titles to keep working.
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
      // 2026-09-03: ministries and omissions joined the line. The box
      // had always searched the 44 ministry spans without saying so,
      // and the omissions are the one kind of record a reader would
      // never think to look for — a row that exists to say the chart
      // draws NOTHING for that prophet.
      data.ministries.length,
      data.nations.length,
      data.streams.length,
      data.omissions.length,
    ]) {
      expect(text, contains('$n'),
          reason: 'the box does not tell the reader it can search $n of '
              'something');
    }
    // And every placeholder was filled. A `{m}` with no value in the
    // map does not throw and does not fail any count check above — it
    // prints itself, and the reader is shown a template.
    expect(text, isNot(contains('{')),
        reason: 'an unfilled placeholder reached the screen: $text');
    await unmount(tester);
  });

  testWidgets('the About sheet says where the dates come from',
      (tester) async {
    await pump(tester, const Size(1440, 900));
    await tester.tap(find.byIcon(Icons.info_outline));
    await settle(tester);
    expect(tester.takeException(), isNull,
        reason: 'opening the sheet threw — `WbType.of` watches, and the '
            'AppBar action is a tap handler, not a build');
    final text = sheetText(tester);
    // Read from the asset, never hardcoded: the sheet must be showing the
    // file's own header, not a sentence written in the page. This page's
    // shipped default is zh-Hans, so assert the Chinese strings.
    expect(text, contains('创世记'));       // provenance, zh-Hans
    expect(text, contains('版权保护'));     // provenance, zh-Hans
    // The axis moved to 4200 BC when the creation anchor was derived
    // and the lifespans went back on it as arcs. Read from the asset,
    // so this catches the sheet and the file drifting apart.
    expect(text, contains('公元前4200年')); // axis, zh-Hans
    expect(text, contains('4114'),
        reason: 'the About sheet must name the creation year that the arcs '
            'and the pre-Abraham spokes are both counted from');
    expect(text, contains('马所拉'),
        reason: 'the arcs are drawn on ONE tradition and the chart has to '
            'say which, in words, where the axis is disclosed');
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
    // The near-miss rows' number is disclosed — a cap on a sorted list
    // is a silent WHERE clause otherwise.
    //
    // 2026-09-02: this used to assert the per-ROW badge 「年份相近」 as
    // well. That stopped rendering, and for a good reason: 586 BC now
    // has so many EXACT answers — 39 ministries and 57 more spans went
    // in, and every year from 3000 BC to AD 1900 is covered by
    // something — that the nearby rows fall below the fold. The badge
    // was never the disclosure; the sentence at the top of the sheet
    // is, and it is what a reader actually reads. So the sentence is
    // what is pinned, and the count with it.
    expect(text, contains('含年份最接近的'));
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

  /// THE SENTENCE ABOVE, ABOUT A PROPHET. Until 2026-09-03 a reader who
  /// typed 约珥 got "没有找到「约珥」" — the wheel reporting an oversight
  /// where it had actually made a decision, because Joel's book names no
  /// king, no regnal year and no dated event, so any span would be
  /// invented. `wheel_omissions_test.dart` owns the data and the claim
  /// that Joel, Obadiah and Habakkuk are the whole set; this is the one
  /// place that proves a reader can SEE it — the row, the sheet, and the
  /// one thing the sheet must never do.
  testWidgets('a prophet the chart cannot date says so instead of nothing',
      (tester) async {
    await pump(tester, const Size(1440, 900));
    await openFind(tester);
    await tester.enterText(
        find.byKey(const ValueKey('wheelFindField')), '约珥');
    await settle(tester);

    final listed = sheetText(tester);
    expect(listed, isNot(contains('没有找到')),
        reason: 'the search still reports an absence it has an answer for');
    expect(listed, contains('约珥'));
    // The kind column. It is what tells the reader, before they open
    // anything, that this row is a different kind of answer from the
    // dated ones — and it is why the empty year column beside it does
    // not read as a rendering bug.
    expect(listed, contains('无从定年'));

    // Scoped to the result list, not `find.text` on the page. The query
    // and the record's name are the SAME STRING here — unlike the Magna
    // Carta case above, where an English query finds a Chinese title —
    // so an unscoped finder returns the search field's own contents
    // first and the test taps the box it just typed into.
    await tester.tap(find
        .descendant(
          of: find.byKey(const ValueKey('wheelFindList')),
          matching: find.text('约珥'),
        )
        .first);
    await settle(tester);
    expect(tester.takeException(), isNull);

    // The search sheet has been replaced by the record's own, as with
    // every other kind of hit.
    expect(find.byKey(const ValueKey('wheelFindField')), findsNothing);
    expect(find.byType(BottomSheet), findsOneWidget);
    // SCOPED TO THE SHEET, unlike `sheetText`, which sweeps the whole
    // page. The wheel's own header behind the sheet reads
    // "主前4200 – 主后2026", so a page-wide sweep contains both era words
    // no matter what the sheet says — and the assertion below is
    // precisely that this sheet prints no year.
    final opened = tester
        .renderObjectList<RenderParagraph>(find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(RichText),
        ))
        .map((p) => p.text.toPlainText())
        .join('\n');
    expect(opened, contains('本图未画'));
    expect(opened, contains('毗土珥'),
        reason: 'the sheet opened without the note that is its whole point');
    // The verse the claim rests on is on the sheet and localised, so a
    // reader can go and check that Joel 1:1 really does name no king.
    expect(opened, contains(localizedReferenceLabel('Joel 1:1', 'zh-Hans')));
    // AND NO YEAR. Not a hedged one, not a rounded one. If a BC label
    // ever appears on this sheet the record has begun asserting the very
    // thing it exists to refuse.
    expect(opened, isNot(contains('主后')));
    expect(RegExp(r'主前\d').hasMatch(opened), isFalse,
        reason: 'the sheet that says it has no date printed one');
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
    // Two, not one, since 2026-09-03: `kingdom-of-england`'s note
    // mentions Magna Carta, so the phrase legitimately reaches the event
    // and the band. What this test measures is that the list's HEIGHT
    // tracks its row count, and a short list proves that as well as a
    // single row does.
    expect(sheetText(tester), contains('2 项'));
    final one = tester.getSize(list).height;
    expect(one, lessThan(allowance / 2),
        reason: 'a couple of results must not reserve half the screen');

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

  /// THE APPARATUS, AS THE READER MEETS IT (#318 phase 19).
  ///
  /// `wheel_bible_narrative_test.dart` proves the three fields survive
  /// the merge, and that is not the same claim as "a reader can see
  /// them" — the sheet could carry every field and print none of it,
  /// which is exactly the state phase 18 shipped in. So these open the
  /// real sheet on the real record and read what is on it.
  ///
  /// Opened by YEAR rather than by title: typing a title puts that
  /// title into the search field, and `find.text` matches an
  /// `EditableText` too, so the tap could land on the box instead of on
  /// the row and prove nothing.
  Future<void> openByYear(WidgetTester tester, WheelHistoryEvent e) async {
    expect(e.year, lessThan(0));
    await openFind(tester);
    await tester.enterText(
        find.byKey(const ValueKey('wheelFindField')), '主前${-e.year}');
    await settle(tester);
    await tester.tap(find.text(e.titles['zh-Hans']!).first);
    await settle(tester);
    expect(find.byKey(const ValueKey('wheelFindField')), findsNothing,
        reason: 'the search sheet did not give way to the record sheet');
    expect(sheetText(tester), contains(e.titles['zh-Hans']!));
  }

  WheelHistoryEvent injected(String id) =>
      data.events.firstWhere((e) => e.id == '$kBibleEventIdPrefix$id');

  testWidgets('a derived year shows the verses it was counted along',
      (tester) async {
    final e = data.events.firstWhere(
        (x) => x.datingRefs.isNotEmpty && x.year < 0 && x.basis != 'thiele');
    await pump(tester, const Size(1440, 900));
    await openByYear(tester, e);

    final sheet = sheetText(tester);
    // Labelled, because these are not the chapters the event is told
    // in and an unlabelled second row of verses reads as more of the
    // same.
    expect(sheet, contains(uiStrings['timelineDatedBy']!['zh-Hans']!),
        reason: 'the wheel states an interval and hides the verses that '
            'state it');
    for (final r in e.datingRefs) {
      expect(sheet, contains(localizedReferenceLabel(r, 'zh-Hans')),
          reason: '${e.id}: $r');
    }
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('the Septuagint alternative is printed, not dropped',
      (tester) async {
    final e = injected('abram_called');
    expect(e.septuagintYear, isNotNull);
    await pump(tester, const Size(1440, 900));
    await openByYear(tester, e);

    final sheet = sheetText(tester);
    expect(sheet, contains(yearLabel(e.year, 'zh-Hans')));
    expect(sheet, contains(yearLabel(e.septuagintYear!, 'zh-Hans')),
        reason: 'the timeline page prints two years here and the wheel '
            'printed one');
    // The reason, not just the number: a bare second year is a
    // contradiction until the reader is told which text it comes from.
    expect(sheet, contains('出埃及记 12:40'));
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('the era note on the wheel says what the years rest on, with '
      'a door out', (tester) async {
    final e = injected('flood');
    await pump(tester, const Size(1440, 900));
    await openByYear(tester, e);

    // THIS USED TO ASSERT A SEAM AND NOW ASSERTS ITS ABSENCE. The eight
    // records above Abraham were Ussher's, drawn on the same axis as
    // dates counted back from Solomon and 1,652 years from creation to
    // flood where Genesis 5 and 7:6 give 1,656. The chain reaches them
    // now, so the note names the anchor instead — and the door stays,
    // because Bible Chronology counts from the creation rather than
    // towards it and still shows the reader something this wheel cannot.
    expect(sheetText(tester), isNot(contains('1652')));
    expect(sheetText(tester), isNot(contains('Ussher')));
    expect(sheetText(tester), contains('4114'),
        reason: 'the wheel draws the flood on a chain and says nothing '
            'about where that chain starts');

    final door = find.text(uiStrings['timelineOpenChronology']!['zh-Hans']!);
    expect(door, findsOneWidget);
    await tester.tap(door);
    await settle(tester);
    expect(find.byType(ChronologyPage), findsOneWidget,
        reason: 'the door has to reach the chart that does count the '
            'text\'s own numbers');
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  // The block is fifteen records, and the note is worth nothing on
  // fourteen of them if it is wired to one. Read at the data layer what
  // the three tests above read at the widget layer.
  test('all fifteen antediluvian records are marked for the note', () {
    final ante =
        data.events.where((e) => e.timelineEra == 'antediluvian').toList();
    expect(ante, hasLength(15));
    expect(ante.every((e) => e.id.startsWith(kBibleEventIdPrefix)), isTrue);
  });

  /// THE PEOPLE ON THE RECORD (#318 phase 21).
  ///
  /// `wheel_bible_narrative_test.dart` proves the names arrive on the
  /// event and `wheel_search_test.dart` proves the box can find them.
  /// Neither can see the two ways this feature is still wholly broken
  /// with both of them green: the sheet may never print the row, and
  /// the row's tap may throw.
  ///
  /// The tap is the one worth pumping. `WbType.of` and `WbColors.of`
  /// WATCH, and `context.watch` asserts outside `build` — a tap handler
  /// is not a build. That exact mistake once meant no detail sheet on
  /// this page could open at all in a debug build, and it is invisible
  /// to `flutter analyze`, invisible in release, and invisible to any
  /// test that only reads the page at rest.
  testWidgets('an event names its people, and the name opens the person',
      (tester) async {
    final e = injected('moses_born');
    expect(e.people, isNotEmpty,
        reason: 'the record chosen for this test no longer links anyone');
    await pump(tester, const Size(1440, 900));
    await openByYear(tester, e);

    // Labelled, and reusing the timeline page's own heading rather than
    // inventing a second word for the same thing.
    final sheet = sheetText(tester);
    expect(sheet, contains(uiStrings['timelinePeople']!['zh-Hans']!));
    for (final p in e.people) {
      expect(sheet, contains(p.nameFor('zh-Hans')), reason: p.id);
    }

    final name = e.people.first.nameFor('zh-Hans');
    await tester.tap(find.text(name).first);
    await settle(tester);
    expect(tester.takeException(), isNull,
        reason: 'tapping a person threw — a tap handler is not a build, so '
            'a `WbType.of`/`WbColors.of` watch in it asserts');
    expect(find.byType(PersonDetailSheet), findsOneWidget,
        reason: 'the name is underlined and does nothing');
    await unmount(tester);
  });

  /// A NAME THE APP KNOWS AND WHERE THE WHEEL NOW ANSWERS FROM.
  ///
  /// THIS TEST HAS BEEN INVERTED, AND THAT INVERSION IS THE FEATURE.
  /// It used to assert that typing "Methuselah" produced the hand-off
  /// sentence — "he is not on this wheel: the text gives a lifespan,
  /// not a date" — because the wheel held no record naming him. It
  /// holds one now: `bible:methuselah_born`, counted along the same
  /// chain as the exodus. So the hand-off must NOT fire for him, and
  /// the wheel must answer with his own record instead.
  ///
  /// What the hand-off is still for has narrowed to the men whose name
  /// the wheel spells differently: Nahor the elder, whom the table of
  /// nations calls plain Nahor. The three assertions that made the old
  /// version mean anything are kept and pointed at him — it fires, it
  /// does not fire for a name near his, and it can never stand in front
  /// of a real result.
  ///
  /// The no-figure rule survives intact and is asserted twice over: 969
  /// is the same in the Masoretic and the Greek, but eight of these men
  /// differ between the two and this page gives a reader no way to
  /// choose, so no lifespan figure is printed for any of them — not by
  /// the hand-off, and not by the new record either.
  testWidgets('a patriarch the wheel once could not carry is on it now',
      (tester) async {
    await pump(tester, const Size(1440, 900));
    await openFind(tester);

    // Typed in English; this page's shipped default is zh-Hans, so a
    // hit proves the fold reaches every script the record carries and
    // that the answer is shown in the reader's own language.
    await tester.enterText(
        find.byKey(const ValueKey('wheelFindField')), 'Methuselah');
    await settle(tester);
    final found = sheetText(tester);
    expect(found, contains('玛土撒拉'),
        reason: 'the box knows this man and said nothing about him');
    expect(found, isNot(contains('不在这个轮盘上')),
        reason: 'the wheel carries his birth and must not disown him');
    expect(found, isNot(contains('969')),
        reason: 'the two traditions differ across these men and this '
            'page cannot let a reader choose');

    // THE HAND-OFF'S LAST CASE, AND HOW IT WAS CLOSED. It used to say
    // "not on this wheel: the text gives a lifespan, not a date" —
    // false the moment the lifespans were drawn — and the one case left
    // to it after that was a SPELLING: the chart called him Nahor, the
    // family tree called him Nahor (the elder), and nothing indexed
    // answered to the longer name, so a reader typing it was told
    // nothing matched.
    //
    // The Israel band now DISPLAYS "Nahor (the elder)", the tree's own
    // string, because the sheet was printing two rows both labelled
    // "Nahor" — Genesis 11:22 and Genesis 11:26 — with nothing on
    // screen telling them apart. So the longer name is a real record
    // now and the reader gets the record instead of a sentence about
    // one. That is the better answer, and this is where it is pinned:
    // an index that stops carrying the name would fall back to the
    // hand-off, and the two assertions below tell those apart.
    await tester.enterText(
        find.byKey(const ValueKey('wheelFindField')), 'Nahor (the elder)');
    await settle(tester);
    final shown = sheetText(tester);
    expect(shown, isNot(contains('不在这个轮盘上')),
        reason: 'his life IS drawn on this wheel — the sentence may not go '
            'on disowning a man the chart carries');
    expect(shown, contains('拿鹤(亚伯拉罕祖父)'),
        reason: 'the band answers to the tree\'s own name for him now, so a '
            'reader typing it must reach the band and not a hand-off');
    expect(shown, isNot(contains('已画在本图上')),
        reason: 'the hand-off is for an empty index; standing it in front of '
            'a record that exists is the false absence it was built to stop');
    expect(shown, isNot(contains('148')),
        reason: 'no lifespan figure in a search status line, for any of them');

    // AND THE OTHER NAHOR IS STILL HIS OWN ROW. Genesis 11:26, Abram's
    // brother, keeps the bare name — searching it reaches both, and the
    // two are told apart by the label rather than by the note under it.
    await tester.enterText(
        find.byKey(const ValueKey('wheelFindField')), 'Nahor');
    await settle(tester);
    final bothNahors = sheetText(tester);
    expect(bothNahors, contains('拿鹤(亚伯拉罕祖父)'));
    expect(bothNahors, contains('Nahor (the elder)'));
    // The younger keeps the bare name, so the plain form is still on
    // two rows of its own — his band, and the elder's lifespan arc,
    // which the chart spells briefly. Two men, three rows, and the one
    // label that used to be ambiguous is not any more.
    expect(RegExp(r'拿鹤\nNahor\n').allMatches(bothNahors).length, 2,
        reason: 'the plain name must still reach the arc and the younger '
            'Nahor\'s band\n$bothNahors');

    // A name one letter off is a different question, and answering it
    // with either man would be worse than answering nothing.
    await tester.enterText(
        find.byKey(const ValueKey('wheelFindField')), 'Nahor (the elderx)');
    await settle(tester);
    final off = sheetText(tester);
    expect(off, isNot(contains('已画在本图上')),
        reason: 'a loose match makes a definite claim about the wrong man');
    expect(off, isNot(contains('拿鹤(亚伯拉罕祖父)')),
        reason: 'and it must not reach the band either');

    // THE SECOND SENTENCE, which the hand-off never had. Genesis
    // 4:17-24 gives Cain's line a city, wives, trades and a boast and
    // not one number, so Jabal has no arc, no spoke and no year — and
    // a bare "nothing matches" about a man this app holds a record for
    // is the false absence the whole hand-off exists to stop.
    await tester.enterText(
        find.byKey(const ValueKey('wheelFindField')), 'Jabal');
    await settle(tester);
    final jabal = sheetText(tester);
    expect(jabal, contains('圣经家谱'),
        reason: 'Jabal is in the family tree and the box said nothing');
    expect(jabal, contains('雅八'));
    expect(jabal, isNot(contains('已画在本图上')),
        reason: 'the promise of a charted life must not be made about a man '
            'the text gives no figure for');
    // NO YEAR FOR A CAINITE, and the two that could leak are named:
    // `family_tree.json` carries him an Anno Mundi 540 as a
    // conventional placeholder, and 540 on this anchor would be
    // 3574 BC. Neither number may reach the reader from this page,
    // because Genesis 4:17-24 states neither.
    expect(jabal, isNot(contains('540')));
    expect(jabal, isNot(contains('3574')));
    expect(find.text('圣经家谱'), findsWidgets);

    // Shem carries AM years too, and is ALSO a nation of Genesis 10, so
    // the wheel can answer for him. The hand-off must never stand in
    // front of a record that exists.
    await tester.enterText(
        find.byKey(const ValueKey('wheelFindField')), 'Shem');
    await settle(tester);
    final shem = sheetText(tester);
    expect(shem, contains('闪'), reason: 'the wheel lost its own record');
    expect(shem, isNot(contains('不在这个轮盘上')));

    await unmount(tester);
  });

  /// WHO REIGNED IN IT.
  ///
  /// The wheel draws the Kingdom of Judah, not Ahab, and until now a
  /// reader who opened that kingdom got two names out of its note —
  /// "from Rehoboam to Zedekiah" — and no route to the other eighteen,
  /// though this app charts all forty-two on its own page. There was no
  /// link from the wheel to that page anywhere in the app.
  ///
  /// The counts are read from `hebrew_kings.json`, never written here.
  /// Twenty and twenty is Thiele's arrangement, not a fact about the
  /// world, and a literal in a test is a literal that outlives the data
  /// it was copied from.
  group('a kingdom says who reigned in it', () {
    late HebrewKingsData kings;
    setUpAll(() async {
      kings = await HebrewKingsService.instance.load();
    });

    /// Reach a power's sheet the way a reader can: find it by name.
    ///
    /// Typed in English and tapped in Chinese on purpose. Entering the
    /// same string the row prints makes `find.text` ambiguous — the
    /// search field holds it too — and the tap lands on the box instead
    /// of the result, which is a silent no-op that leaves every later
    /// assertion reading the wrong widget tree.
    Future<void> openPower(WidgetTester tester, String en, String zh) async {
      await openFind(tester);
      await tester.enterText(find.byKey(const ValueKey('wheelFindField')), en);
      await settle(tester);
      final row = find.descendant(
          of: find.byKey(const ValueKey('wheelFindList')),
          matching: find.text(zh));
      expect(row, findsWidgets, reason: 'the box could not find $en');
      await tester.tap(row.first);
      await settle(tester);
    }

    testWidgets('Judah lists its twenty, in order, under the Thiele line',
        (tester) async {
      await pump(tester, const Size(1440, 900));
      await openPower(tester, 'Kingdom of Judah', '南国犹大');
      final text = sheetText(tester);

      final judah = kings.ofKingdom(Kingdom.judah);
      expect(text, contains('列王 · ${judah.length}'));
      for (final k in judah) {
        expect(text, contains(k.nameFor('zh-Hans')),
            reason: '${k.id} is charted by this app and missing here');
      }
      // The order is the file's, which is reign order.
      expect(text.indexOf(judah.first.nameFor('zh-Hans')),
          lessThan(text.indexOf(judah.last.nameFor('zh-Hans'))));

      // The years are covered by the basis line already on this sheet;
      // no reign carries a disclosure of its own, so that line has to
      // actually be there.
      // The line reads "interval from scripture · year by Thiele ·
      // approximate · authorities differ". It sits directly above the
      // list and is the only disclosure these twenty reign years get,
      // so it has to actually be on screen — and it carries the
      // systems caveat too, which is why no row repeats it.
      expect(text, contains('Thiele'),
          reason: 'reign years are printed with nothing saying what they '
              'rest on');
      expect(text, contains('各家不一'),
          reason: 'the reader is not told the authorities disagree');
      expect(find.text('犹大与以色列列王'), findsOneWidget,
          reason: 'the wheel still has no route to the page that charts '
              'these reigns');
      await unmount(tester);
    });

    testWidgets('Israel lists its own twenty, not Judah\'s', (tester) async {
      await pump(tester, const Size(1440, 900));
      await openPower(tester, 'Kingdom of Israel (Northern)', '北国以色列');
      final text = sheetText(tester);

      final israel = kings.ofKingdom(Kingdom.israel);
      expect(text, contains('列王 · ${israel.length}'));
      expect(text, contains(israel.first.nameFor('zh-Hans')));
      expect(text, contains(israel.last.nameFor('zh-Hans')));
      // Judah's kings reigned at the same time and are NOT here: this
      // sheet answers who reigned in this kingdom, not who reigned
      // alongside. That question has its own page, and the link row is
      // how the reader gets to it.
      //
      // Checked name by name rather than by one example, and the
      // exclusion is the point of the exercise: 罗波安 (Rehoboam of
      // Judah) is a SUBSTRING of 耶罗波安 (Jeroboam of Israel), so the
      // obvious assertion fails on a list that is perfectly correct.
      // Only the names that cannot collide are asked about.
      final israelNames =
          israel.map((k) => k.nameFor('zh-Hans')).toList();
      var asked = 0;
      for (final k in kings.ofKingdom(Kingdom.judah)) {
        final n = k.nameFor('zh-Hans');
        if (israelNames.any((i) => i.contains(n) || n.contains(i))) continue;
        expect(text, isNot(contains(n)), reason: '${k.id} reigned in Judah');
        asked++;
      }
      expect(asked, greaterThan(10),
          reason: 'too many collisions to have tested anything');
      await unmount(tester);
    });

    /// THE ONE THAT KEEPS THIS HONEST.
    ///
    /// The united monarchy runs from 1050 BC, which is Saul. Thiele's
    /// chart is of the divided monarchy and begins at David in 1010 BC
    /// with no Saul in it at all. So "list the kings of every
    /// scripture+thiele power" would drop Saul from the one power whose
    /// own note names him — and an absence reads as a claim. The join is
    /// a written map for exactly this reason.
    testWidgets('the united monarchy lists none, because Saul is not there',
        (tester) async {
      expect(kings.kings.any((k) => k.id == 'saul'), isFalse,
          reason: 'if Saul has landed, this exclusion should be revisited');
      await pump(tester, const Size(1440, 900));
      await openPower(tester, 'United Monarchy of Israel', '以色列联合王国');
      final text = sheetText(tester);
      // Its own span, which nothing but this sheet prints — the name
      // alone would also match the query still sitting in the box, and
      // a test that passes on a sheet that never opened proves nothing.
      expect(text, contains('主前1050'), reason: 'the sheet did not open');
      expect(text, isNot(contains('列王 ·')));
      await unmount(tester);
    });

    /// A rename on either side of a hand-written join is a silent loss.
    test('every power the map names is a power the wheel has', () {
      expect(kWheelPowerKingdoms, isNotEmpty);
      for (final id in kWheelPowerKingdoms.keys) {
        expect(data.powers.map((p) => p.id), contains(id));
      }
      expect(kWheelPowerKingdoms.containsKey('israel-united-monarchy'), isFalse,
          reason: 'listing kings there would drop Saul without saying so');
    });

    /// The sheet is a `ListView` and builds lazily, so a section under
    /// twenty king rows is not in the widget tree until it is scrolled
    /// to. Reading it without this would be testing the viewport.
    Future<void> scrollSheet(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.drag(find.byType(ListView).last, const Offset(0, -260));
        await settle(tester);
      }
    }

    /// WHAT STOOD AT THE SAME TIME AS IT.
    ///
    /// The wheel draws a power as an arc and its events as spokes on
    /// the same ring, and until now nothing said the two were related.
    /// That relation is the one thing the printed chart carries that
    /// this app did not — it nests a reign inside a kingdom inside a
    /// people, so the geometry states the parentage. The app states it
    /// in a heading instead, which is the form it has always used.
    testWidgets('a power lists what fell inside its own span',
        (tester) async {
      await pump(tester, const Size(1440, 900));
      await openPower(tester, 'Kingdom of Judah', '南国犹大');
      await scrollSheet(tester);
      final text = sheetText(tester);

      // Computed from the merged corpus the page actually draws, not
      // written down: the merge injects narrative events at load, so a
      // literal here would be a number copied out of one asset and
      // asserted about another.
      final judah = data.powers.firstWhere((p) => p.id == 'kingdom-of-judah');
      final within = data
          .eventsOf(judah.stream)
          .where((e) => e.year >= judah.start && e.year <= judah.end!)
          .toList();
      expect(within, isNotEmpty, reason: 'nothing to list, so nothing tested');
      // The COUNT is the claim, and it is the thing worth pinning: it
      // is computed here from the same merged corpus the page draws
      // from, so a filter that quietly drops a record fails here.
      expect(text, contains('此期间 · ${within.length}'));

      // Only the head of the list is asserted present, and the reason
      // is mechanical rather than editorial: the sheet is a `ListView`,
      // which builds lazily, so rows below the fold are not in the
      // widget tree at all and a "every one of them is on screen"
      // assertion would be testing the viewport, not the list.
      within.sort((a, b) => a.year.compareTo(b.year));
      for (final e in within.take(3)) {
        expect(text, contains(e.titleFor('zh-Hans')), reason: e.id);
      }

      // The heading says span, not ownership. An event inside these
      // years is not thereby an event OF this kingdom, and the wheel's
      // own "Events · n" heading — which does mean ownership — must not
      // be what this list is filed under.
      expect(text, isNot(contains('大事 · ${within.length}')));
      await unmount(tester);
    });

    /// The list is a claim about a span, so it has to end where the
    /// span does.
    testWidgets('and nothing that fell outside it', (tester) async {
      await pump(tester, const Size(1440, 900));
      await openPower(tester, 'Kingdom of Judah', '南国犹大');
      await scrollSheet(tester);
      final text = sheetText(tester);

      final judah = data.powers.firstWhere((p) => p.id == 'kingdom-of-judah');
      final outside = data
          .eventsOf(judah.stream)
          .where((e) => e.year < judah.start || e.year > judah.end!)
          .toList();
      expect(outside, isNotEmpty,
          reason: 'the band holds nothing outside this span, so the '
              'boundary is untested');
      var asked = 0;
      for (final e in outside) {
        final title = e.titleFor('zh-Hans');
        // The note above the list is prose and may legitimately name
        // something later; only titles that cannot appear there are
        // asked about.
        if (judah.noteFor('zh-Hans').contains(title)) continue;
        expect(text, isNot(contains(title)), reason: '${e.id} at ${e.year}');
        asked++;
      }
      expect(asked, greaterThan(3),
          reason: 'too little left to have tested the boundary');
      await unmount(tester);
    });

    testWidgets('a king the wheel cannot draw is sent where he is charted',
        (tester) async {
      await pump(tester, const Size(1440, 900));
      await openFind(tester);

      // 2026-09-03: this asked about JEHU, and the answer changed —
      // correctly. `jehu_revolt_jezreel` went onto the wheel with the
      // Israel section, so Jehu is now a record the wheel draws and the
      // hand-off must stand aside for him, exactly as the Hezekiah case
      // below has always demanded. Baasha is the question now: 24 years
      // over Israel, named nowhere on the chart, and one of 14 kings
      // still in that position.
      await tester.enterText(
          find.byKey(const ValueKey('wheelFindField')), 'Baasha');
      await settle(tester);
      final shown = sheetText(tester);
      expect(shown, contains('巴沙'));
      expect(shown, contains('轮盘画的是列国，不是列王'));
      expect(find.text('犹大与以色列列王'), findsOneWidget);

      // The king who moved, checked from the other side: Jehu now gets
      // the wheel's own record and not the hand-off.
      await tester.enterText(
          find.byKey(const ValueKey('wheelFindField')), 'Jehu');
      await settle(tester);
      expect(sheetText(tester), isNot(contains('轮盘画的是列国')));

      // A name one letter off is a different question.
      await tester.enterText(
          find.byKey(const ValueKey('wheelFindField')), 'Baashax');
      await settle(tester);
      expect(sheetText(tester), isNot(contains('轮盘画的是列国')));

      // Hezekiah's reform IS drawn on the wheel. The hand-off must never
      // stand in front of a record that exists.
      await tester.enterText(
          find.byKey(const ValueKey('wheelFindField')), 'Hezekiah');
      await settle(tester);
      expect(sheetText(tester), isNot(contains('轮盘画的是列国')));

      // And the one that matters most: Zechariah is a king of Israel
      // AND the father of John the Baptist, who is on the wheel. The
      // wheel answers first.
      await tester.enterText(
          find.byKey(const ValueKey('wheelFindField')), 'Zechariah');
      await settle(tester);
      expect(sheetText(tester), isNot(contains('轮盘画的是列国')),
          reason: 'the wheel had an answer and this spoke over it');

      await unmount(tester);
    });
  });
}
