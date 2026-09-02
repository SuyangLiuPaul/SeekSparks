/// The Bible Timeline, mounted against the real asset.
///
/// `person_dating_test.dart` pins the asset and the formatter. What
/// neither can see is the page, and the page is where check 32 actually
/// failed: the asset had carried a `basis` on all 98 events since
/// v1.6.120 and an asset test had been passing on it the whole time,
/// while the reader was still shown "4000 BC" for the creation in the
/// same voice as "1446 BC" for the exodus.
///
/// The hedge that fixes that makes the year string half again as long
/// (「约 公元前 4000 年」 against 「公元前 4000 年」) inside a lane that
/// was a fixed 90 px, and nothing in that lane ellipsises — an overflow
/// would have wrapped the year onto two lines and thrown nothing. So the
/// lane is measured rather than eyeballed, the same way
/// `chronology_page_test.dart` measures its name lane.
///
/// Rendered in the app's shipped default (zh-Hans): it is the widest of
/// the three, and `AppSettings.setLocale` leaves a
/// notification-rescheduling timer pending that fails teardown.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/timeline_event.dart';
import 'package:seeksparks/pages/bible_timeline_page.dart';
import 'package:seeksparks/pages/chronology_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/family_tree_service.dart';
import 'package:seeksparks/services/timeline_service.dart';
import 'package:seeksparks/widgets/person_detail_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<TimelineEvent> events;
  setUpAll(() async {
    events = await TimelineService.instance.loadAll();
    // Both, and both HERE. `rootBundle.loadString` on an asset that is
    // not already cached does not complete under the fake clock inside
    // `testWidgets` — no number of `tester.pump(Duration)` calls
    // delivers it — so a page awaiting a cold asset renders its
    // spinner forever and every finder in this file matches nothing.
    // The page has awaited the family tree since #318 phase 20.
    await FamilyTreeService.instance.loadAll();
  });

  Future<AppSettings> pump(
    WidgetTester tester, {
    Size size = const Size(1440, 900),
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    final settings = AppSettings();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: const MaterialApp(home: BibleTimelinePage()),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return settings;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('a reconstructed year is hedged and a derived one is not',
      (tester) async {
    await pump(tester);
    expect(tester.takeException(), isNull);

    // The creation and Eden share the year and no longer share a
    // confidence: the chain reaches the creation (Genesis 5 up to
    // Genesis 11 and on to Solomon) and states no interval at all for
    // the placing in the garden, so one row is exact and the other is
    // hedged on the same year.
    expect(find.text('公元前 4114 年'), findsOneWidget);
    expect(find.text('约 公元前 4114 年'), findsOneWidget);
    expect(find.text('约 公元前 4000 年'), findsNothing);

    // Six events sit on -1446 and the two voices end up in adjacent
    // rows. Three are counted into the year: the exodus by 1 Kings 6:1's
    // 480 years back from Solomon's fourth, and the manna and Sinai by
    // Exodus 16:1 and 19:1, which date them by month inside the year of
    // the departure. The burning bush, the plagues and the Red Sea are
    // placed in it by narrative order instead, and keep the hedge.
    await tester.dragUntilVisible(
      // The burning bush opens the run of six and is the only row with
      // that title, so it can be the drag target; 「公元前 1446 年」 now
      // matches three rows and cannot be.
      find.text('荆棘焚烧'),
      find.byType(Scrollable).last,
      const Offset(0, -400),
    );
    await settle(tester);
    expect(find.text('公元前 1446 年'), findsNWidgets(3));
    expect(find.text('约 公元前 1446 年'), findsNWidgets(3));

    await unmount(tester);
  });

  // The regression this file exists for. The lane held a fixed 90 px
  // while the year inside it is drawn at `t.scaled(11.5)`, which the
  // font slider moves 0.6×-2×. Un-ellipsised text does not clip, so only
  // a measurement catches the overflow.
  testWidgets('the year lane holds the hedged year at every font size',
      (tester) async {
    for (final fontSize in [12.0, 20.0, 40.0]) {
      final settings = await pump(tester);
      settings.setFontSize(fontSize);
      await settle(tester);
      expect(tester.takeException(), isNull, reason: '$fontSize pt');

      // Matched against the strings the model actually produces rather
      // than by pattern: the era header's disclosure note names 「公元前
      // 4114 年」 too, and it is a wrapping paragraph whose intrinsic
      // width is meant to exceed the width it is granted.
      final years = {for (final e in events) e.displayYear('zh-Hans')};
      var measured = 0;
      for (final para
          in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
        final text = para.text.toPlainText();
        if (!years.contains(text)) continue;
        measured++;
        // `size.width` is what the lane grants; the intrinsic width is
        // what the glyphs need on one line.
        expect(para.getMaxIntrinsicWidth(double.infinity),
            lessThanOrEqualTo(para.size.width),
            reason: '"$text" at $fontSize pt');
      }
      // The first screenful is never empty; if the finder stopped
      // matching, the assertion above would pass vacuously.
      expect(measured, greaterThan(3), reason: '$fontSize pt');
      await unmount(tester);
    }
  });

  // A lane measured from the search results narrows whenever the search
  // does, so the rail and every card on it slide left as the reader
  // types. The column was a fixed 90 px before it was measured, so this
  // would be a regression introduced by the fix rather than one it
  // inherited.
  testWidgets('the lane does not move while the reader searches',
      (tester) async {
    await pump(tester);

    double laneOf(String year) => tester
        .renderObjectList<RenderParagraph>(find.byType(RichText))
        .firstWhere((p) => p.text.toPlainText() == year)
        .size
        .width;

    // Unfiltered, the widest year is on screen, so the lane it is
    // granted is the whole corpus's lane.
    final full = laneOf('约 公元前 4114 年');

    // Filter down to the exodus, whose year is the narrowest kind the
    // page has — unhedged, four digits — and whose match set contains
    // nothing dated to the creation. Under a filtered measurement the
    // lane would shrink to fit these matches alone.
    await tester.enterText(find.byType(TextField), '出埃及');
    await settle(tester);
    expect(find.text('约 公元前 4114 年'), findsNothing);
    expect(laneOf('公元前 1446 年'), full);

    await unmount(tester);
  });

  testWidgets('an open row says what its year rests on', (tester) async {
    await pump(tester);

    // THIS ROW HAS CHANGED ITS ANSWER, WHICH IS THE POINT OF IT. The
    // creation was `conventional` — Ussher's 4004 rounded — and this
    // asserted the row said so. The same chain that dates the exodus
    // now reaches it, so the row must state the intervals instead, and
    // Eden beside it must still say the text fixes nothing.
    await tester.tap(find.text('创造'));
    await settle(tester);
    expect(find.textContaining('并无一串经文自述的年数可推至此事'), findsNothing);
    expect(find.text('定年所据'), findsOneWidget,
        reason: 'the chain that reaches the creation is not labelled');
    expect(find.textContaining('5:3'), findsWidgets,
        reason: 'the last link of the chain, Genesis 5:3, is not shown');

    await tester.tap(find.text('创造'));
    await settle(tester);
    await tester.tap(find.text('亚当夏娃在伊甸园'));
    await settle(tester);
    expect(find.textContaining('并无一串经文自述的年数可推至此事'), findsOneWidget,
        reason: 'Eden rests on no stated interval and must still say so');

    await unmount(tester);
  });

  // THE NINE THAT WERE CALLED RECONSTRUCTIONS. Ishmael's birth is one of
  // them: Genesis 16:16 states Abram's age outright, and until v1.6.146
  // this row printed 「约 公元前 2080 年」 above a sentence saying the text
  // fixes no year for it. Both halves of that were false, and only the
  // page can show that they are fixed now.
  testWidgets('a promoted event drops the hedge and names its verses',
      (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), '以实玛利');
    await settle(tester);
    await tester.tap(find.text('以实玛利出生'));
    await settle(tester);

    expect(find.text('公元前 2080 年'), findsOneWidget);
    expect(find.text('约 公元前 2080 年'), findsNothing);
    expect(find.textContaining('并无一串经文自述的年数可推至此事'), findsNothing);

    // The verses that fix the year, labelled and kept apart from the
    // chapter the event is narrated in — which states no number.
    expect(find.text('定年所据'), findsOneWidget);
    expect(find.textContaining('16:16'), findsOneWidget);

    // And the Greek reading of Exodus 12:40, which moves it 215 years.
    expect(find.textContaining('公元前 1865 年'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('the antediluvian seam is disclosed once, with a door out',
      (tester) async {
    await pump(tester);

    // THE SEAM IS CLOSED AND THE NOTE NOW SAYS WHAT REPLACED IT. It
    // used to disclose a 1,652-year creation-to-flood span against the
    // 1,656 Genesis 5 and 7:6 give, because the years above Abraham
    // were Ussher's and the ones below him were counted back from
    // Solomon. One chain now reaches both, so the note names the
    // creation year that chain lands on and the four records in the era
    // it still does not reach. Said once, on the era header, and the
    // door to Bible Chronology stays: that page counts from the
    // creation instead of towards it.
    expect(find.textContaining('1652'), findsNothing);
    expect(find.textContaining('Ussher'), findsNothing);
    // Once on the era header — the year labels beside it carry 4114 too,
    // so the note is matched by a phrase only it has.
    expect(find.textContaining('共二十五段经文自述的年数'), findsOneWidget);

    await tester.tap(find.text('打开「圣经年代」'));
    await settle(tester);
    expect(find.byType(ChronologyPage), findsOneWidget);

    await unmount(tester);
  });

  // ── #318 phase 20: the people the record files ────────────────

  // `personIds` shipped in the asset and was parsed by [TimelineEvent],
  // and appeared at three lines in all of `lib/` — all three inside the
  // model. 88 links on 61 events rendered nowhere. The value the row
  // adds is exactly the part the reader cannot get from the text: this
  // event's title and description name Moses, and say nothing at all
  // about the parents who are also filed under it.
  testWidgets('an open row names the people the text does not', (tester) async {
    await pump(tester);

    // Filtered by id, not by title: `enterText` puts the query into an
    // EditableText, so a query equal to the title makes `find.text`
    // ambiguous between the search box and the row.
    await tester.enterText(find.byType(TextField), 'moses_born');
    await settle(tester);
    await tester.tap(find.text('摩西出生'));
    await settle(tester);

    expect(find.text('相关人物'), findsOneWidget);
    for (final name in ['摩西', '约基别', '暗兰']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    // The parents are named nowhere else on the row — the chips are the
    // only place this page has ever said Moses had any.
    expect(find.textContaining('约基别'), findsOneWidget);
    expect(find.textContaining('暗兰'), findsOneWidget);

    await unmount(tester);
  });

  // The chip is a door, so it has to open. The years it opens onto are
  // the ones the repair produced: the tree shipped -1525..-1405 against
  // a timeline that stated -1526 and -1406 exactly, on the same basis,
  // citing the same two verses.
  testWidgets('a person chip opens the sheet, at the corrected years',
      (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'moses_born');
    await settle(tester);
    await tester.tap(find.text('摩西出生'));
    await settle(tester);

    await tester.tap(find.text('摩西'));
    await settle(tester);
    expect(find.byType(PersonDetailSheet), findsOneWidget);
    expect(find.text('公元前 1526 年 – 公元前 1406 年'), findsOneWidget);
    expect(find.textContaining('1525'), findsNothing);

    await unmount(tester);
  });

  // THE FALSE ABSENCE THIS FEATURE WOULD HAVE SHIPPED. 17 of the 88
  // links name someone the event's own title and description never
  // mention, and the filter read titles, descriptions and ids only.
  // Jeconiah is the sharpest case: the string 耶哥尼雅 appears in no
  // event's text in the whole asset, so before the row was searched the
  // page would have printed his chip and then answered "0 events" to a
  // reader who typed what it had just shown them.
  testWidgets('a person the event text never names is still findable',
      (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), '耶哥尼雅');
    await settle(tester);

    expect(find.text('1 项事件'), findsOneWidget);
    expect(find.text('犹大亡国；圣殿被毁'), findsOneWidget);

    await unmount(tester);
  });

  // Nothing in the chip ellipsises, so an over-wide name does not clip —
  // the Row inside it overflows and paints a stripe. Worst case is the
  // narrowest window the app admits (992 px, `SmallScreenGate`) at the
  // top of the Font Size slider, on the longest name in the corpus:
  // 「约瑟(马利亚之夫)」, ten glyphs and two brackets.
  testWidgets('the person chips fit at 2x font in the narrowest window',
      (tester) async {
    final settings = await pump(tester, size: const Size(992, 900));
    settings.setFontSize(40.0);
    await settle(tester);

    await tester.enterText(find.byType(TextField), 'jesus_born');
    await settle(tester);
    await tester.tap(find.textContaining('耶稣').first);
    await settle(tester);
    expect(tester.takeException(), isNull);

    const names = {'耶稣', '马利亚', '约瑟(马利亚之夫)'};
    final measured = <String>{};
    for (final para
        in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
      final text = para.text.toPlainText();
      if (!names.contains(text)) continue;
      measured.add(text);
      expect(para.getMaxIntrinsicWidth(double.infinity),
          lessThanOrEqualTo(para.size.width),
          reason: '"$text" at 40 pt on 992 px');
    }
    // Without this the loop above passes by matching nothing.
    expect(measured, names);

    await unmount(tester);
  });
}
