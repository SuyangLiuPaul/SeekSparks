/// 2026-08-07 (SeekSparks): the bwh44 command verbs as the reader meets
/// them — typed into the command line, landing on workbench state.
///
/// `command_verb_test.dart` proves the grammar reads correctly against a
/// stand-in registry. These prove three things it cannot: that the verbs
/// reach the real state they claim to change, that they say so when the
/// change lands somewhere off screen, and — the regression that would be
/// silent — that putting them FIRST in `_submit` did not steal a single
/// line that used to search or navigate.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/models/wb_centre_mode.dart';
import 'package:seeksparks/providers/workbench_provider.dart';
import 'package:seeksparks/widgets/command_pane.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _seed = [
  Verse(
      book: 'Genesis',
      chapter: 1,
      verse: 1,
      text: 'In the beginning God created the heaven and the earth.'),
  Verse(
      book: 'Genesis',
      chapter: 2,
      verse: 1,
      text: 'Thus the heavens and the earth were finished.'),
  Verse(
      book: 'John',
      chapter: 3,
      verse: 16,
      text: 'For God so loved the world, that he gave his only begotten Son.'),
  Verse(
      book: 'John',
      chapter: 3,
      verse: 17,
      text: 'For God sent not his Son into the world to condemn the world.'),
];

MainProvider _mp() => MainProvider()
  ..setVerses(_seed)
  ..currentVersion = 'kjv';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<WorkbenchProvider> pump(WidgetTester tester,
      {String? book, int? chapter}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(500, 900);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final mp = _mp();
    mp.currentBook = book;
    mp.currentChapter = chapter;
    final wb = WorkbenchProvider(mainProvider: mp);
    addTearDown(wb.dispose);
    // AppSettings boots in zh-Hans; these assertions read English.
    final settings = AppSettings();
    await settings.setLocale('en');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: mp),
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: wb),
        ],
        child: Builder(builder: (context) {
          return MaterialApp(
            theme: workbenchTheme(Theme.of(context)),
            home: const Scaffold(body: CommandPane()),
          );
        }),
      ),
    );
    // setLocale schedules a save debounce; drain it or the binding
    // reports a pending timer.
    await tester.pump(const Duration(seconds: 1));
    return wb;
  }

  Future<void> submit(WidgetTester tester, String line) async {
    await tester.enterText(find.byType(TextField), line);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump();
  }

  group('d — the display stack', () {
    testWidgets('adds an edition and says what you are now looking at',
        (tester) async {
      final wb = await pump(tester);
      await submit(tester, 'd bsb');
      expect(wb.parallelVersions, ['bsb']);
      expect(wb.centreMode, WbCentreMode.browse);
      // The stack lands in the centre pane, which is not on screen in
      // this test and is collapsed away on a phone — so the command has
      // to report itself or it looks unimplemented.
      expect(find.textContaining('Browse stack: KJV · BSB'), findsOneWidget);
    });

    testWidgets('d c leaves the search version, which can never leave',
        (tester) async {
      final wb = await pump(tester);
      await submit(tester, 'd bsb');
      await submit(tester, 'd c');
      expect(wb.parallelVersions, isEmpty);
      expect(find.textContaining('Browse stack: KJV'), findsOneWidget);
    });

    testWidgets('refuses to remove the edition you are reading',
        (tester) async {
      final wb = await pump(tester);
      await submit(tester, 'd -kjv');
      expect(wb.parallelVersions, isEmpty);
      expect(find.textContaining('always shown'), findsOneWidget);
    });

    testWidgets('an edition we do not bundle is named, and so are the ones '
        'we do', (tester) async {
      // `d niv` is what a BibleWorks reader types on their first day
      // here. Falling through to a text search for "d niv" would find
      // nothing and teach them the verb does not exist.
      await pump(tester);
      await submit(tester, 'd niv');
      expect(find.textContaining('No edition called "niv"'), findsOneWidget);
      expect(find.textContaining('KJV'), findsWidgets);
    });

    testWidgets('a language stacks every edition in it', (tester) async {
      final wb = await pump(tester);
      await submit(tester, 'd english');
      expect(wb.parallelVersions, contains('bsb'));
      expect(wb.parallelVersions, isNot(contains('kjv')),
          reason: 'the search version is implicit, never doubled');
    });
  });

  group('p — restack, in the order given', () {
    testWidgets('order is the point; the checkbox dialog cannot express it',
        (tester) async {
      final wb = await pump(tester);
      await submit(tester, 'p bsb lxxwh');
      expect(wb.parallelVersions, ['bsb', 'lxxwh']);
      await submit(tester, 'p lxxwh bsb');
      expect(wb.parallelVersions, ['lxxwh', 'bsb']);
    });

    testWidgets('bare p just turns Browse on', (tester) async {
      final wb = await pump(tester);
      wb.setCentreMode(WbCentreMode.reader);
      await submit(tester, 'p');
      expect(wb.centreMode, WbCentreMode.browse);
      expect(find.textContaining('Browse stack'), findsOneWidget);
    });
  });

  group('l — scope the search', () {
    testWidgets('a book limits the hits and shows the banner', (tester) async {
      final wb = await pump(tester);
      await submit(tester, 'l gen');
      expect(wb.hasSearchLimit, isTrue);
      expect(wb.searchLimitLabel, 'Genesis');
      await submit(tester, 'god');
      expect([for (final v in wb.textResults) v.book], ['Genesis']);
    });

    testWidgets('a chapter range is finer than a book', (tester) async {
      final wb = await pump(tester);
      await submit(tester, 'l gen 2');
      expect(wb.searchLimit, {'Genesis-2-1'});
    });

    testWidgets('a corpus is a scope too', (tester) async {
      final wb = await pump(tester);
      await submit(tester, 'l nt');
      // #280: `nt` is still what you TYPE, but the scope names itself
      // with the terminology the rest of the app uses.
      expect(wb.searchLimitLabel, 'Greek Bible');
      expect(wb.searchLimit, hasLength(2));
    });

    testWidgets('bare l lifts it', (tester) async {
      final wb = await pump(tester);
      await submit(tester, 'l gen');
      await submit(tester, 'l');
      expect(wb.hasSearchLimit, isFalse);
    });

    testWidgets('a scope with no verses is refused, not applied silently',
        (tester) async {
      // Applying an empty limit would leave every later search returning
      // nothing, with a banner that looks like it is working.
      final wb = await pump(tester);
      await submit(tester, 'l rev');
      expect(wb.hasSearchLimit, isFalse);
      expect(find.textContaining('no verses'), findsOneWidget);
    });

    testWidgets('a verse-list file points at the tab that does read one',
        (tester) async {
      await pump(tester);
      await submit(tester, 'l notes.vls');
      expect(find.textContaining('Verse Lists'), findsOneWidget);
    });
  });

  group('relative references', () {
    testWidgets('a bare number needs a chapter to be a verse in',
        (tester) async {
      await pump(tester);
      await submit(tester, '17');
      expect(find.textContaining('Open a chapter first'), findsOneWidget);
    });

    testWidgets('with a chapter open it navigates rather than searching',
        (tester) async {
      final wb = await pump(tester, book: 'John', chapter: 3);
      await submit(tester, '17');
      expect(wb.searchPerformed, isFalse,
          reason: 'a bare number is a verse, never a full-text search');
      expect(wb.mainProvider.currentVerse?.verse, 17);
    });

    testWidgets('chapter:verse completes from the book you are in',
        (tester) async {
      final wb = await pump(tester, book: 'Genesis', chapter: 1);
      await submit(tester, '2:1');
      expect(wb.mainProvider.currentBook, 'Genesis');
      expect(wb.mainProvider.currentChapter, 2);
    });
  });

  group('the verbs took nothing away', () {
    testWidgets('a word starting with d is still a search', (tester) async {
      final wb = await pump(tester);
      await submit(tester, 'god');
      expect(wb.searchPerformed, isTrue);
      expect(wb.textResults, isNotEmpty);
    });

    testWidgets('a bare version abbreviation still reaches the version branch',
        (tester) async {
      // Submitted as the version already loaded, so `_submit` short-
      // circuits before the fetch — this is about routing, and a real
      // switch would arm a retry timer no asset can satisfy in a test.
      final wb = await pump(tester);
      await submit(tester, 'kjv');
      expect(wb.mainProvider.currentVersion, 'kjv');
      expect(wb.searchPerformed, isFalse,
          reason: 'not swallowed by the search');
      expect(wb.verbNotice, isNull, reason: 'and not read as a verb');
    });

    testWidgets('a full reference still navigates', (tester) async {
      final wb = await pump(tester);
      await submit(tester, 'John 3:16');
      expect(wb.searchPerformed, isFalse);
      expect(wb.mainProvider.currentBook, 'John');
    });

    testWidgets('the command grammar still runs', (tester) async {
      final wb = await pump(tester);
      await submit(tester, '.god world');
      expect(wb.commandQuery, isNotNull);
      expect(wb.textResults, hasLength(2));
    });
  });

  group('the notice', () {
    testWidgets('sits above the results rather than replacing them',
        (tester) async {
      // `d bsb` must not throw away a hit list that took three commands
      // to build.
      final wb = await pump(tester);
      await submit(tester, 'god');
      expect(wb.textResults, isNotEmpty);
      await submit(tester, 'd bsb');
      expect(wb.textResults, isNotEmpty);
      expect(find.textContaining('Browse stack'), findsOneWidget);
      expect(find.textContaining('John 3:16'), findsWidgets);
    });

    testWidgets('a new search clears it', (tester) async {
      await pump(tester);
      await submit(tester, 'd niv');
      expect(find.textContaining('No edition called'), findsOneWidget);
      await submit(tester, 'god');
      expect(find.textContaining('No edition called'), findsNothing);
    });

    testWidgets('the syntax card advertises the verbs', (tester) async {
      // A grammar nobody can discover is a grammar nobody uses — the
      // single most common complaint about the BibleWorks command line.
      await pump(tester);
      await tester.tap(find.text('?'));
      await tester.pump();
      expect(find.textContaining('d c stack editions'), findsOneWidget);
    });
  });
}
