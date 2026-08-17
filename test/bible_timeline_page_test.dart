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
import 'package:seeksparks/services/timeline_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<TimelineEvent> events;
  setUpAll(() async {
    events = await TimelineService.instance.loadAll();
  });

  Future<AppSettings> pump(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1440, 900);
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

    // The creation and Eden share the year, so this is two rows.
    expect(find.text('约 公元前 4000 年'), findsNWidgets(2));
    expect(find.text('公元前 4000 年'), findsNothing);

    // Six events sit on -1446 and only the exodus is derived, so the
    // two voices end up in adjacent rows: 1 Kings 6:1's 480 years
    // counted back from Solomon's fourth reads 「公元前 1446 年」, while
    // the burning bush, the plagues, the Red Sea, the manna and Sinai —
    // placed in that year rather than counted into it — keep the hedge.
    await tester.dragUntilVisible(
      find.text('公元前 1446 年'),
      find.byType(Scrollable).last,
      const Offset(0, -400),
    );
    await settle(tester);
    expect(find.text('公元前 1446 年'), findsOneWidget);
    expect(find.text('约 公元前 1446 年'), findsWidgets);

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
      // 4000 年」 too, and it is a wrapping paragraph whose intrinsic
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
    final full = laneOf('约 公元前 4000 年');

    // Filter down to the exodus, whose year is the narrowest kind the
    // page has — unhedged, four digits — and whose match set contains
    // nothing dated to the creation. Under a filtered measurement the
    // lane would shrink to fit these matches alone.
    await tester.enterText(find.byType(TextField), '出埃及');
    await settle(tester);
    expect(find.text('约 公元前 4000 年'), findsNothing);
    expect(laneOf('公元前 1446 年'), full);

    await unmount(tester);
  });

  testWidgets('an open row says what its year rests on', (tester) async {
    await pump(tester);

    await tester.tap(find.text('创造'));
    await settle(tester);

    // The creation is `conventional`, so the open row must say so in
    // words and not only by the 「约」 in the column.
    expect(find.textContaining('经文并未为此事定年'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('the antediluvian seam is disclosed once, with a door out',
      (tester) async {
    await pump(tester);

    // Genesis 5 and 7:6 put 1,656 years between the creation and the
    // flood; these eight events leave 1,652, because the years above
    // Abraham come from Ussher and the ones below him are counted back
    // from Solomon. Said once, on the era header where it happens.
    expect(find.textContaining('1652'), findsOneWidget);

    await tester.tap(find.text('打开「圣经年代」'));
    await settle(tester);
    expect(find.byType(ChronologyPage), findsOneWidget);

    await unmount(tester);
  });
}
