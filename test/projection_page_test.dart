/// The projection view, driven the way an operator drives it.
///
/// `projection_cursor_test.dart` pins the arithmetic. These pin the
/// things only a pumped widget can see: that a key actually REACHES the
/// handler (a page whose `Focus` never takes focus answers nothing and
/// looks identical in source), that blanking removes the text from the
/// tree rather than merely recolouring it, that the room's type scale is
/// deaf to the reader's Font Size in both the declared size and the
/// painted one, and that leaving gives the reader back exactly the
/// reference they came in on.
///
/// The surface is set to 1280x800 rather than the test default of
/// 800x600. At the default the passage's own `BoxFit.scaleDown` starts
/// shrinking a two-line verse, and a test that cannot tell a shrunk
/// verse from a smaller one measures the fit instead of the setting.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yahwehs_sword/constants/bible_versions.dart'
    show
        isKnownVersion,
        kSecondaryVersionKey,
        menuBibleVersionLabel,
        resolveSecondaryVersion;
import 'package:yahwehs_sword/constants/projection_strings.dart';
import 'package:yahwehs_sword/models/app_settings.dart';
import 'package:yahwehs_sword/models/verse.dart';
import 'package:yahwehs_sword/pages/projection_page.dart';
import 'package:yahwehs_sword/pages/radial_chronology_page.dart'
    show kWheelUrlPath;
import 'package:yahwehs_sword/providers/main_provider.dart';
import 'package:yahwehs_sword/utils/page_links.dart';

Verse _v(String book, int chapter, int verse) => Verse(
      book: book,
      chapter: chapter,
      verse: verse,
      text: '$book wall $chapter $verse',
    );

/// Two chapters of two verses and a second book, so a key press can
/// cross a chapter boundary and the corpus still has an end to refuse
/// to run off.
final _corpus = <Verse>[
  _v('Genesis', 1, 1),
  _v('Genesis', 1, 2),
  _v('Genesis', 2, 1),
  _v('Genesis', 2, 2),
  _v('John', 3, 16),
];

String _text(String book, int chapter, int verse) =>
    '$book wall $chapter $verse';

MainProvider _reader() {
  final mp = MainProvider();
  mp.setVerses(List<Verse>.from(_corpus));
  mp.setCurrentChapter(book: 'Genesis', chapter: 1);
  mp.updateCurrentVerse(verse: _corpus.first);
  return mp;
}

Widget _app(MainProvider mp, AppSettings settings, {Widget? home}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MainProvider>.value(value: mp),
        ChangeNotifierProvider<AppSettings>.value(value: settings),
      ],
      child: MaterialApp(home: home ?? const ProjectionPage()),
    );

/// Unmount the page so its auto-hide timer is cancelled by `dispose`
/// rather than left pending at teardown.
///
/// The extra second is for `AppSettings`, not for the page: every
/// setup control writes a setting now, and `notifyListeners` arms a
/// 600 ms debounce for the user-prefs blob that no widget owns and
/// `dispose` therefore cannot cancel. Nothing here is testing that
/// write; it simply has to be let run. (The sibling `pump` of one
/// second in the Font Size test predates this and is the same
/// mechanism.)
Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// A settings object as a real launch produces one: loaded from
/// whatever is in SharedPreferences.
///
/// Reopening the projection with one of these is the only honest test
/// of persistence — a field kept on the object in memory would pass a
/// test that reused the same instance and fail the operator on Sunday.
Future<AppSettings> _loaded() async {
  final settings = AppSettings();
  await settings.loadSettings();
  return settings;
}

/// Let the second-edition load finish: `build` schedules it after the
/// frame, and it awaits SharedPreferences and the corpus before it can
/// paint.
Future<void> _settleSecond(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

/// One verse of another edition, cached so `preloadVersion` is a hit
/// and no asset is read — a real multi-megabyte load never completes
/// inside a widget test's fake-async zone.
void _seedSecondEdition(MainProvider mp, String code, String text) {
  mp.cacheVersionForTest(code, <Verse>[
    Verse(book: 'Genesis', chapter: 1, verse: 1, text: text),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, MainProvider mp,
      {AppSettings? settings}) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(mp, settings ?? AppSettings()));
    await tester.pump();
  }

  group('the keyboard walks the passage', () {
    testWidgets('the arrow keys advance and retreat ACROSS a chapter boundary',
        (tester) async {
      final mp = _reader();
      await pump(tester, mp);
      expect(find.text(_text('Genesis', 1, 1)), findsOneWidget,
          reason: 'the projection opens on the reference the reader is on');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.text(_text('Genesis', 1, 2)), findsOneWidget);

      // The boundary. Genesis 1 has two verses in this corpus, so the
      // next press has to leave the chapter rather than stop.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.text(_text('Genesis', 2, 1)), findsOneWidget,
          reason: 'advancing off the last verse of a chapter must enter '
              'the next one');

      // And back over it in the other direction, onto the previous
      // chapter's LAST verse rather than its first.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(find.text(_text('Genesis', 1, 2)), findsOneWidget);

      await _leave(tester);
    });

    testWidgets('space advances too, because that is the key a hand finds',
        (tester) async {
      final mp = _reader();
      await pump(tester, mp);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(find.text(_text('Genesis', 1, 2)), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('PageDown moves a whole chapter and lands at its top',
        (tester) async {
      final mp = _reader();
      await pump(tester, mp);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();
      expect(find.text(_text('Genesis', 2, 1)), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pump();
      expect(find.text(_text('Genesis', 1, 1)), findsOneWidget,
          reason: 'back a chapter is the top of that chapter, not its end');
      await _leave(tester);
    });
  });

  group('the blank key', () {
    testWidgets('takes the wall down and puts it back, without leaving',
        (tester) async {
      final mp = _reader();
      await pump(tester, mp);
      expect(find.text(_text('Genesis', 1, 1)), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.pump();
      expect(find.text(_text('Genesis', 1, 1)), findsNothing,
          reason: 'blank means the passage is GONE — a recoloured verse '
              'is still a verse on a projector');
      expect(find.byType(ProjectionPage), findsOneWidget,
          reason: 'blanking must not be a way out of the view');

      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.pump();
      expect(find.text(_text('Genesis', 1, 1)), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('takes the corner reference down with it', (tester) async {
      final mp = _reader();
      await pump(tester, mp);
      expect(find.textContaining('Genesis 1:1'), findsOneWidget,
          reason: 'the reference is what the room follows along by');

      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.pump();
      expect(find.textContaining('Genesis 1:1'), findsNothing,
          reason: 'a blank screen still naming a verse tells the room '
              'where the sermon is while the preacher is elsewhere');
      await _leave(tester);
    });

    testWidgets('does not lose the place the operator had reached',
        (tester) async {
      final mp = _reader();
      await pump(tester, mp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.pump();

      expect(find.text(_text('Genesis', 1, 2)), findsOneWidget,
          reason: 'blanking is a shutter, not a reset');
      await _leave(tester);
    });
  });

  group('the projection type scale', () {
    double declaredSize(WidgetTester tester, String text) =>
        tester.widget<Text>(find.text(text)).style!.fontSize!;

    testWidgets('does not move when the reading Font Size does',
        (tester) async {
      final small = AppSettings();
      await small.setFontSize(kFontSizeMin);
      final mp = _reader();
      await pump(tester, mp, settings: small);
      final atMin = declaredSize(tester, _text('Genesis', 1, 1));
      final paintedAtMin =
          tester.getRect(find.text(_text('Genesis', 1, 1))).height;
      await _leave(tester);

      final large = AppSettings();
      await large.setFontSize(kFontSizeMax);
      await pump(tester, _reader(), settings: large);
      final atMax = declaredSize(tester, _text('Genesis', 1, 1));
      final paintedAtMax =
          tester.getRect(find.text(_text('Genesis', 1, 1))).height;

      expect(atMax, atMin,
          reason: 'the room does not get bigger because the operator '
              'likes big text on their laptop');
      expect(paintedAtMax, closeTo(paintedAtMin, 0.01),
          reason: 'and the painted glyphs do not either — the declared '
              'size is not evidence on its own under a FittedBox');
      expect(atMin, kProjectionTypeSteps[kProjectionTypeDefaultStep]);
      await _leave(tester);
      // `AppSettings.notifyListeners` arms a 600 ms debounce to write
      // the user-prefs blob. Nothing here is testing that, and it is not
      // owned by a widget, so it has to be let run rather than disposed.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('DOES move when the operator asks, in the tree and in pixels',
        (tester) async {
      final mp = _reader();
      await pump(tester, mp);
      final before = declaredSize(tester, _text('Genesis', 1, 1));
      final paintedBefore =
          tester.getRect(find.text(_text('Genesis', 1, 1))).height;

      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.pump();
      final after = declaredSize(tester, _text('Genesis', 1, 1));
      final paintedAfter =
          tester.getRect(find.text(_text('Genesis', 1, 1))).height;

      expect(after, greaterThan(before));
      expect(paintedAfter, greaterThan(paintedBefore),
          reason: 'a control that changes a number and not the wall is '
              'the defect fitted_label_reach_test.dart exists for');

      await tester.sendKeyEvent(LogicalKeyboardKey.minus);
      await tester.pump();
      expect(declaredSize(tester, _text('Genesis', 1, 1)), before);
      await _leave(tester);
    });
  });

  // ── 2026-09-09 ────────────────────────────────────────────────────
  //
  // 「projector setting怎么没做好 背景也不能set或者preset两个经文也不能
  // 调整这个功能要完整」. Everything below is one of those three
  // complaints, driven the way the operator drives it.
  //
  // Every one of these reopens the page against a FRESH `AppSettings`
  // built by `loadSettings()`, because that is the difference between a
  // setting and a field: an object reused across the two pumps would
  // pass while the operator lost their setup every Sunday.

  group('the operator\'s setup outlives the page', () {
    testWidgets('the type size is where they left it, and the blank is not',
        (tester) async {
      final settings = await _loaded();
      await pump(tester, _reader(), settings: settings);
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.pump();
      // ...and black the wall out on the way out the door.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.pump();
      expect(find.text(_text('Genesis', 1, 1)), findsNothing,
          reason: 'precondition: the wall really is blanked');
      await _leave(tester);

      final reopened = await _loaded();
      expect(reopened.projectionTypeStep, kProjectionTypeDefaultStep + 2,
          reason: 'two presses of the size key are two rungs, and they '
              'went to disk');
      await pump(tester, _reader(), settings: reopened);
      expect(
        tester.widget<Text>(find.text(_text('Genesis', 1, 1))).style!.fontSize,
        kProjectionTypeSteps[kProjectionTypeDefaultStep + 2],
        reason: 'and the WALL is at that size, not just the setting',
      );
      expect(find.text(_text('Genesis', 1, 1)), findsOneWidget,
          reason: 'the blank does NOT come back: nobody is looking at a '
              'dark wall to notice it is stale, and reopening onto one '
              'is a fault the operator has to diagnose mid-service');
      await _leave(tester);
    });

    testWidgets('the ground they chose is still the ground', (tester) async {
      final settings = await _loaded();
      await pump(tester, _reader(), settings: settings);
      expect(settings.projectionGround, ProjectionGround.deep,
          reason: 'the default is what shipped, so an existing operator '
              'sees no change at all');

      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.pump();
      final chosen = settings.projectionGround;
      expect(chosen, isNot(ProjectionGround.deep));
      await _leave(tester);

      final reopened = await _loaded();
      expect(reopened.projectionGround, chosen);
      await pump(tester, _reader(), settings: reopened);
      final wall = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .map((b) => b.color)
          .toSet();
      expect(wall, contains(projectionGroundPaintFor(chosen).base),
          reason: 'the ground has to be PAINTED on reopening, not merely '
              'remembered');
      await _leave(tester);
    });

    testWidgets('the second edition is back on, and is the same edition',
        (tester) async {
      SharedPreferences.setMockInitialValues({kSecondaryVersionKey: 'kjv'});
      final settings = await _loaded();
      final mp = _reader();
      _seedSecondEdition(mp, 'kjv', 'a second edition on the wall');
      await pump(tester, mp, settings: settings);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pump();
      await _settleSecond(tester);
      expect(find.text('a second edition on the wall'), findsOneWidget,
          reason: 'precondition: the second block is really loaded');
      await _leave(tester);

      final reopened = await _loaded();
      expect(reopened.projectionSecondOn, isTrue);
      final mp2 = _reader();
      _seedSecondEdition(mp2, 'kjv', 'a second edition on the wall');
      await pump(tester, mp2, settings: reopened);
      await _settleSecond(tester);
      expect(find.text('a second edition on the wall'), findsOneWidget,
          reason: 'the wall opens with two editions because that is how '
              'the operator left it — the old page needed the P key '
              'pressed again every single service');
      await _leave(tester);
    });
  });

  group('the second edition is the projection\'s own', () {
    testWidgets('it is seeded from Split View once and then stops following',
        (tester) async {
      // The borrow this replaces was invisible from both ends: the
      // projection read `secondary_version`, which is the READER's
      // split column, so changing one silently changed the other and
      // no control on either surface said so.
      SharedPreferences.setMockInitialValues({kSecondaryVersionKey: 'kjv'});
      final settings = await _loaded();
      final mp = _reader();
      _seedSecondEdition(mp, 'kjv', 'the borrowed edition');
      _seedSecondEdition(mp, 'leb', 'the reader changed their split view');
      await pump(tester, mp, settings: settings);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pump();
      await _settleSecond(tester);
      expect(find.text('the borrowed edition'), findsOneWidget,
          reason: 'the seed: an operator who already had the pairing they '
              'wanted must see no change on the day this shipped');
      expect(settings.projectionSecondVersion, 'kjv',
          reason: 'and the projection now owns that answer');

      // The reader goes back to their desk and changes the split view.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kSecondaryVersionKey, 'leb');
      await _leave(tester);

      final reopened = await _loaded();
      expect(reopened.projectionSecondVersion, 'kjv',
          reason: 'the two are different jobs; the wall does not move '
              'because someone rearranged a reading pane');
      final mp2 = _reader();
      _seedSecondEdition(mp2, 'kjv', 'the borrowed edition');
      _seedSecondEdition(mp2, 'leb', 'the reader changed their split view');
      await pump(tester, mp2, settings: reopened);
      await _settleSecond(tester);
      expect(find.text('the borrowed edition'), findsOneWidget);
      expect(find.text('the reader changed their split view'), findsNothing);
      await _leave(tester);
    });

    testWidgets('and the operator can pick it, from the projection page',
        (tester) async {
      final settings = await _loaded();
      final mp = _reader();
      _seedSecondEdition(mp, 'kjv', 'the edition the operator picked');
      await pump(tester, mp, settings: settings);

      // V opens the strip. Before this there was no way in at all.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.pump();
      final label = find.text(menuBibleVersionLabel('kjv'));
      expect(label, findsOneWidget,
          reason: 'the strip names editions in full — a room reading '
              '「BGT BSB 雅简」 from forty feet cannot decode a tag');
      await tester.ensureVisible(label);
      await tester.pumpAndSettle();
      await tester.tap(label);
      await tester.pump();
      await _settleSecond(tester);

      expect(settings.projectionSecondVersion, 'kjv');
      expect(settings.projectionSecondOn, isTrue,
          reason: 'picking an edition is asking to see it; a second press '
              'to turn it on is the feature being unfinished again');
      expect(find.text('the edition the operator picked'), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('the picker does not offer the edition already on the wall',
        (tester) async {
      final mp = _reader();
      await pump(tester, mp, settings: await _loaded());
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.pump();
      expect(find.text(menuBibleVersionLabel(mp.currentVersion)), findsNothing,
          reason: 'a wall carrying the same text twice is the one outcome '
              'worse than a wall carrying it once');
      await _leave(tester);
    });
  });

  group('presets', () {
    const morning = ProjectionPreset(
      name: 'morning service',
      setup: ProjectionSetup(
        typeStep: 8,
        secondOn: false,
        secondVersion: 'kjv',
        ground: ProjectionGround.black,
      ),
    );

    testWidgets('a saved setup is on the strip and puts itself back',
        (tester) async {
      final settings = await _loaded();
      await settings.setProjectionPresets(const [morning]);
      await pump(tester, _reader(), settings: settings);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pump();
      final chip = find.text('morning service');
      expect(chip, findsOneWidget);
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pump();

      expect(settings.projectionTypeStep, 8);
      expect(settings.projectionGround, ProjectionGround.black);
      expect(settings.projectionSecondVersion, 'kjv');
      expect(
        tester.widget<Text>(find.text(_text('Genesis', 1, 1))).style!.fontSize,
        kProjectionTypeSteps[8],
        reason: 'recalled onto the WALL, not just into the settings object',
      );
      await _leave(tester);
    });

    testWidgets('one that names an edition this build no longer has lands '
        'on one it does', (tester) async {
      // `nasb` is in the catalog and hidden by `disabledVersions`, so
      // `isKnownVersion` is false for it — exactly the shape of a
      // preset saved two releases ago. The wall must not go blank over
      // it, and the resolver that answers is the SAME one the loader
      // uses, not a second opinion.
      const stale = ProjectionPreset(
        name: 'from an older build',
        setup: ProjectionSetup(
          typeStep: 5,
          secondOn: true,
          secondVersion: 'nasb',
          ground: ProjectionGround.deep,
        ),
      );
      final settings = await _loaded();
      await settings.setProjectionPresets(const [stale]);
      final mp = _reader();
      await pump(tester, mp, settings: settings);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pump();
      final chip = find.text('from an older build');
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pump();
      await _settleSecond(tester);

      expect(settings.projectionSecondVersion, isNot('nasb'));
      expect(isKnownVersion(settings.projectionSecondVersion), isTrue,
          reason: 'a retired code must land on an edition this build can '
              'actually load');
      expect(
          settings.projectionSecondVersion,
          resolveSecondaryVersion(
              primaryVersion: mp.currentVersion, stored: 'nasb'),
          reason: 'and it must land where the second-edition loader would '
              'have put it — one resolver, not two');
      expect(tester.takeException(), isNull);
      await _leave(tester);
    });

    testWidgets('saving one names it, and it survives the page',
        (tester) async {
      final settings = await _loaded();
      await pump(tester, _reader(), settings: settings);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.pump();
      final ground = settings.projectionGround;

      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pump();
      final save = find.text(projectionStrings['projectionPresetSave']!['en']!);
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'youth night');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await _leave(tester);
      final reopened = await _loaded();
      expect(reopened.projectionPresets.map((p) => p.name), ['youth night']);
      expect(reopened.projectionPresets.single.setup.ground, ground,
          reason: 'a preset stores the setup that was on the wall when it '
              'was saved');
      // `loadSettings` notifies, which arms the blob debounce; this test
      // is the one that ends on a fresh AppSettings with no pump after
      // it. See `_leave`.
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('leaving', () {
    testWidgets('puts the reader back exactly where they were',
        (tester) async {
      final mp = _reader();
      final settings = AppSettings();
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(mp, settings,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const ProjectionPage()),
                  ),
                  child: const Text('open the projection'),
                ),
              ),
            ),
          )));
      await tester.tap(find.text('open the projection'));
      await tester.pumpAndSettle();
      expect(find.byType(ProjectionPage), findsOneWidget);

      // Drive the wall a long way from where the reader is sitting,
      // including across a chapter boundary.
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
      }
      expect(find.text(_text('Genesis', 2, 2)), findsOneWidget,
          reason: 'precondition: the projection really did move');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(ProjectionPage), findsNothing);
      expect(find.text('open the projection'), findsOneWidget);
      expect(mp.currentBook, 'Genesis');
      expect(mp.currentChapter, 1);
      expect(mp.currentVerse?.verse, 1,
          reason: 'the operator advanced the WALL, not anybody\'s study — '
              'a projection that dragged the reader with it would leave '
              'a reader who lent their laptop to the AV desk somewhere '
              'they never navigated to');
    });
  });

  group('the URL', () {
    test('names the projection through both of a page path\'s doors', () {
      // `page_links.dart` is asked by `appGenerateRoute` (cold open, and
      // the initial route stack) and by `appUnknownRoute` (a live tab, a
      // browser Back onto a `#/project` entry). One lookup answers both.
      expect(pageForUrlPath(kProjectionUrlPath), isA<ProjectionPage>());
      expect(pageForUrlPath('#$kProjectionUrlPath'), isA<ProjectionPage>());
      expect(pageForUrlPath('$kProjectionUrlPath?v=bsb'),
          isA<ProjectionPage>(),
          reason: 'matched by prefix, so a future query on the path still '
              'resolves to the page rather than falling through to a '
              'passage');
    });

    test('is not a passage, and is not a prefix of a different word', () {
      expect(pageForUrlPath('/genesis/1:1'), isNull);
      expect(pageForUrlPath('/projector'), isNull);
    });

    test('is the same page as itself and not as the chart', () {
      expect(samePageUrlPath(kProjectionUrlPath, '$kProjectionUrlPath?x=1'),
          isTrue,
          reason: 'browserRouteAction asks this to decide between opening '
              'the page and going back off it');
      expect(samePageUrlPath(kProjectionUrlPath, kWheelUrlPath), isFalse);
    });
  });

  testWidgets('a corpus that has not loaded says so instead of showing '
      'a blank wall', (tester) async {
    // The cold-open case: `#/project` puts this page on the initial
    // route stack (see `page_links.dart`) before boot has parsed a
    // Bible, so the first frames genuinely have nothing to project.
    final settings = AppSettings();
    await pump(tester, MainProvider(), settings: settings);
    expect(
      find.text(projectionStrings['projectionNoPassage']![settings.locale]!),
      findsOneWidget,
      reason: 'an empty wall and a loading wall look identical, and one '
          'of them is a fault the operator needs to know about',
    );
    await _leave(tester);
  });

  testWidgets('the control bar scrolls on a phone, and SAYS it scrolls',
      (tester) async {
    // Fourteen buttons are far wider than 375 px, and a projection
    // driven from a phone is a real if unusual configuration. The
    // failure mode this has always guarded is the framework's
    // yellow-and-black overflow stripe on a church wall.
    //
    // 2026-09-09 it guards a second one. The bar used to answer the
    // narrow case with `FittedBox(scaleDown)`, which was fine at ten
    // icons and is not at fourteen: shrink-to-fit on a strip whose
    // premise is "hit it without looking" takes the targets under a
    // fingertip. It scrolls now — and an edge with more behind it has
    // to say so, because a row that ends at the screen edge looking
    // complete is a row nobody swipes (`overflow_hint_scroll.dart`:
    // 「不往右划根本不知道」).
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(_reader(), AppSettings()));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets,
        reason: 'the operator has to be told the rest of the bar is there');
    await _leave(tester);
  });

  testWidgets('a key press before the corpus arrives moves nothing and '
      'throws nothing', (tester) async {
    await pump(tester, MainProvider());
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await _leave(tester);
  });
}
