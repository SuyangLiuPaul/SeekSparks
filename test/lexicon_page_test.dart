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
import 'package:seeksparks/services/chinese_lexicon_service.dart';
import 'package:seeksparks/services/strongs_service.dart';
import 'package:seeksparks/services/thayer_service.dart';
import 'package:seeksparks/utils/lexicon_browse.dart';

/// The one-line summary in the row whose headword is [lemma]. Last of the
/// row's three Texts: the number tag, the lemma, then the summary.
String _rowSummary(WidgetTester t, String lemma) {
  final row =
      find.ancestor(of: find.text(lemma), matching: find.byType(InkWell)).first;
  return t
          .widget<Text>(find.descendant(of: row, matching: find.byType(Text))
              .last)
          .data ??
      '';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `testWidgets` runs in a fake-async zone where a Future waiting on
  // real disk I/O never completes, so the page would sit on its spinner.
  // Warm the static caches here; afterwards the page's awaits resolve as
  // microtasks `pumpAndSettle` can drive.
  setUpAll(() async {
    await StrongsService.allEntries('H');
    await StrongsService.allEntries('G');
    // The other two works are lazy megabyte assets, warmed for the same
    // reason: inside the fake-async zone a real disk read never lands.
    await ThayerService.rawArticles();
    await ChineseLexiconService.allEntries('H');
    await ChineseLexiconService.allEntries('G');
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

    expect(find.text("8674 个词条 · Strong's"), findsOneWidget);
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

    expect(find.text("5523 个词条 · Strong's"), findsOneWidget);
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

    expect(find.text("1 个词条如此拼写 · Strong's"), findsOneWidget);
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

    expect(find.text("0 个词条如此拼写 · Strong's"), findsOneWidget);
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

    expect(find.text("0 entries named · Strong's"), findsOneWidget);
    expect(find.text('5 articles mention it'), findsOneWidget);
  });

  testWidgets('the filtered list offers the way back to all of it',
      (t) async {
    await pump(t);
    await t.enterText(find.byType(TextField), 'elohim');
    await t.pumpAndSettle();
    expect(find.text("8674 个词条 · Strong's"), findsNothing);

    // bwh35's Reload button, by its effect: the entry list is REPLACED
    // by results, so something has to put it back.
    await t.tap(find.text('显示全部'));
    await t.pumpAndSettle();

    expect(find.text("8674 个词条 · Strong's"), findsOneWidget);
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

    expect(find.text("1 entry named · Strong's"), findsOneWidget);
  });

  testWidgets('a single article hit agrees with its verb', (t) async {
    await pump(t, locale: 'en', initial: LexiconId.greek);

    // G5440 φυλακτήριον is the only Greek article using the word.
    await t.enterText(find.byType(TextField), 'phylactery');
    await t.pumpAndSettle();

    expect(find.text('1 article mentions it'), findsOneWidget);
  });

  // ── The second lexicon (bwh35, backlog 1a) ──────────────────────────

  testWidgets('picking a work changes the rows, and says whose they are',
      (t) async {
    await pump(t, initial: LexiconId.greek);
    // G76 Ἀδάμ, and the choice of word is the whole test.
    //
    // This was written against G26 ἀγάπη and passed — on a defect. The
    // Chinese module's usage line had been truncated, so Thayer 中文's
    // first "sense" was the KJV fragment `feast of charity 1; 116`,
    // which of course differed from Strong's. Repairing the import
    // (check 44) put the real sense back and the two works turned out
    // to say the same thing: **4,875 of 5,514 Greek headwords, 88.4%,
    // carry a Chinese summary identical to Strong's but for
    // punctuation.** The two Chinese texts share a lineage, so a
    // difference here has to be CHOSEN, not assumed.
    //
    // Proper names are where they genuinely part: Strong's Chinese
    // describes the person, the module gives the name's meaning.
    await t.enterText(find.byType(TextField), 'G76');
    await t.pumpAndSettle();
    expect(find.text("1 个词条如此拼写 · Strong's"), findsOneWidget);
    final underStrongs = _rowSummary(t, 'Ἀδάμ');
    expect(underStrongs, contains('第一个被造之人'));

    await t.tap(find.widgetWithText(InkWell, 'Thayer 中文'));
    await t.pumpAndSettle();

    // A different lexicographer writes a different sentence about the
    // same word — and the header now names him, so a reader quoting the
    // row knows whose words she is quoting.
    expect(find.text('1 个词条如此拼写 · Thayer 中文'), findsOneWidget);
    expect(find.text('Ἀδάμ'), findsOneWidget);
    expect(_rowSummary(t, 'Ἀδάμ'), contains('红土'));
    expect(_rowSummary(t, 'Ἀδάμ'), isNot(underStrongs));
  });

  testWidgets("Thayer under Hebrew is refused out loud, not hidden",
      (t) async {
    await pump(t, locale: 'en', initial: LexiconId.greek);
    await t.tap(find.widgetWithText(InkWell, "Thayer's"));
    await t.pumpAndSettle();
    expect(find.text("5523 entries · Thayer's"), findsOneWidget);

    await t.tap(find.widgetWithText(InkWell, 'Hebrew'));
    await t.pumpAndSettle();

    // The reader asked for a work that has no Hebrew side. She gets
    // Strong's — and is told so, because a page answering out of a
    // different book than the one she picked is the same defect as a
    // count that will not say what it counted.
    expect(find.text("8674 entries · Strong's"), findsOneWidget);
    expect(
        find.textContaining('has no Hebrew side'), findsOneWidget);
  });

  testWidgets('a headword the chosen work never defines says so',
      (t) async {
    await pump(t, locale: 'en');
    await t.tap(find.widgetWithText(InkWell, 'BDB (Chinese)'));
    await t.pumpAndSettle();

    // One of four in 8,674: the module keys H2775 and never defines it.
    // Blank would be indistinguishable from a failed load, and Strong's
    // gloss in its place would credit the wrong lexicographer.
    await t.enterText(find.byType(TextField), 'H2775');
    await t.pumpAndSettle();
    expect(find.text('no definition in this work'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'H1');
    await t.pumpAndSettle();
    expect(find.text('no definition in this work'), findsNothing);
  });

  testWidgets('the article tier searches the work that is open', (t) async {
    await pump(t, locale: 'en', initial: LexiconId.greek);
    await t.tap(find.widgetWithText(InkWell, "Thayer's"));
    await t.pumpAndSettle();

    // 'Vulgate' appears in Strong's Greek definitions and nowhere in
    // Thayer's 5,523 articles. Answered from the wrong book, the two
    // counts would be identical.
    await t.enterText(find.byType(TextField), 'Vulgate');
    await t.pumpAndSettle();
    expect(find.text("0 entries named · Thayer's"), findsOneWidget);
    expect(find.text('No entry is spelled “Vulgate”, and no article '
        'mentions it.'), findsOneWidget);

    await t.tap(find.widgetWithText(InkWell, "Strong's"));
    await t.pumpAndSettle();
    expect(find.text("0 entries named · Strong's"), findsOneWidget);
    expect(find.textContaining('mention'), findsOneWidget);
    expect(t.widget<Text>(find.textContaining('mention')).data,
        isNot('0 articles mention it'));
  });
}
