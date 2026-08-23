/// The Lexicon Browser mounted against the real bundled lexicons.
///
/// `lexicon_browse_test.dart` pins the logic and the corpus. Neither can
/// tell you the page reaches the screen, and the last two Resources
/// shipped here both taught the same lesson: an asset test and a
/// formatter test never compose into a claim about a screen.
///
/// Asserted in CHINESE by default, because `AppSettings` defaults to
/// `zh-Hans` and that is what a default reader sees — an English-only
/// assertion would never touch the strings written this iteration. The
/// English pumps exist for one thing only: Chinese has no singular, so a
/// zh assertion is structurally blind to "1 entries named", which is
/// exactly the defect that shipped in Nave's a week ago.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/pages/lexicon_page.dart';
import 'package:seeksparks/services/strongs_service.dart';
import 'package:seeksparks/utils/lexicon_browse.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `testWidgets` runs in a fake-async zone where a Future waiting on
  // real disk I/O never completes, so the page would sit on its spinner.
  // Warm the static caches here; afterwards the page's awaits resolve as
  // microtasks `pumpAndSettle` can drive.
  setUpAll(() async {
    await StrongsService.allEntries('H');
    await StrongsService.allEntries('G');
  });

  Future<void> pump(WidgetTester t,
      {String? locale, LexiconId initial = LexiconId.hebrew}) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    if (locale != null) await settings.setLocale(locale);
    await t.pumpWidget(ChangeNotifierProvider.value(
      value: settings,
      child: MaterialApp(home: LexiconPage(initial: initial)),
    ));
    await t.pumpAndSettle();
    // `setLocale` arms AppSettings' 600 ms prefs-write debounce, which
    // outlives pumpAndSettle and would otherwise fail on a pending timer.
    if (locale != null) await t.pump(const Duration(milliseconds: 700));
  }

  testWidgets('opens on the whole Hebrew lexicon and names its size',
      (t) async {
    await pump(t);

    expect(find.text('8674 个词条'), findsOneWidget);
    // H1 אָב, the first word of every printed Hebrew lexicon. Under a
    // naive sort this row was אֱגוֹז, a nut.
    expect(find.text('H1'), findsOneWidget);
    expect(find.text('אָב'), findsOneWidget);
  });

  testWidgets('the alphabet strip is the Hebrew alphabet', (t) async {
    await pump(t);

    // Aleph and tav both on screen, and no final form: no Hebrew word
    // begins with one, so offering it would be a letter with no entries.
    expect(find.widgetWithText(InkWell, 'א'), findsOneWidget);
    expect(find.widgetWithText(InkWell, 'ת'), findsOneWidget);
    expect(find.widgetWithText(InkWell, 'ם'), findsNothing);
  });

  testWidgets('switching to Greek switches the list, not just the label',
      (t) async {
    await pump(t);
    await t.tap(find.widgetWithText(InkWell, '希腊文'));
    await t.pumpAndSettle();

    expect(find.text('5523 个词条'), findsOneWidget);
    expect(find.widgetWithText(InkWell, 'α'), findsOneWidget);
    expect(find.widgetWithText(InkWell, 'א'), findsNothing);
  });

  testWidgets('a romanisation a reader can type reaches the entry',
      (t) async {
    await pump(t);

    // The whole argument for reusing bwh45's index rather than folding
    // the printed transliteration: Strong's spells it `ʼĕlôhîym`, and
    // nobody types that.
    await t.enterText(find.byType(TextField), 'elohim');
    await t.pumpAndSettle();

    expect(find.text('1 个词条如此拼写'), findsOneWidget);
    expect(find.text('H430'), findsOneWidget);
  });

  testWidgets('the article tier arms itself, and reads the CHINESE text',
      (t) async {
    await pump(t);

    // 圣约 is nobody's headword — no Hebrew word is spelled with Han
    // characters — so the headword tier is empty and the reader would be
    // shown a blank page. The article tier turns itself on rather than
    // making her find a button, and it searches the articles she is
    // actually reading: the CBOL Chinese, not the English underneath it.
    await t.enterText(find.byType(TextField), '圣约');
    await t.pumpAndSettle();

    expect(find.text('0 个词条如此拼写'), findsOneWidget);
    expect(find.text('4 条释义提到它'), findsOneWidget);
    expect(find.text('H1285'), findsOneWidget);
  });

  testWidgets('the article tier finds what the headword tier cannot',
      (t) async {
    await pump(t, locale: 'en', initial: LexiconId.greek);

    // `covenant` is nobody's Greek headword either. This is the question
    // bwh35 says the entry list cannot answer and Edit ▸ Search can.
    await t.enterText(find.byType(TextField), 'covenant');
    await t.pumpAndSettle();

    expect(find.text('0 entries named'), findsOneWidget);
    expect(find.text('5 articles mention it'), findsOneWidget);
  });

  testWidgets('the filtered list offers the way back to all of it',
      (t) async {
    await pump(t);
    await t.enterText(find.byType(TextField), 'elohim');
    await t.pumpAndSettle();
    expect(find.text('8674 个词条'), findsNothing);

    // bwh35's Reload button, by its effect: the entry list is REPLACED
    // by results, so something has to put it back.
    await t.tap(find.text('显示全部'));
    await t.pumpAndSettle();

    expect(find.text('8674 个词条'), findsOneWidget);
  });

  testWidgets("Strong's order and alphabetical order are both real",
      (t) async {
    await pump(t);
    expect(find.text('H1'), findsOneWidget);

    await t.tap(find.widgetWithText(InkWell, '按编号'));
    await t.pumpAndSettle();

    // Numeric, not lexicographic. Both numbers are on screen either way —
    // what separates the two sorts is which comes first, since a string
    // sort puts H10 and H100 between H1 and H2.
    expect(t.getTopLeft(find.text('H2')).dy,
        lessThan(t.getTopLeft(find.text('H10')).dy));
    // The strip belongs to alphabetical order and goes away with it.
    expect(find.widgetWithText(InkWell, 'א'), findsNothing);
  });

  testWidgets('English counts have a singular form', (t) async {
    await pump(t, locale: 'en');
    await t.enterText(find.byType(TextField), 'elohim');
    await t.pumpAndSettle();

    expect(find.text('1 entry named'), findsOneWidget);
  });

  testWidgets('a single article hit agrees with its verb', (t) async {
    await pump(t, locale: 'en', initial: LexiconId.greek);

    // G5440 φυλακτήριον is the only Greek article using the word.
    await t.enterText(find.byType(TextField), 'phylactery');
    await t.pumpAndSettle();

    expect(find.text('1 article mentions it'), findsOneWidget);
  });
}
