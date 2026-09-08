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

import 'package:seeksparks/constants/projection_strings.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/pages/projection_page.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart'
    show kWheelUrlPath;
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/utils/page_links.dart';

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
Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
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

  testWidgets('the control bar shrinks to a phone instead of overflowing',
      (tester) async {
    // Ten buttons are wider than 375 px. The failure mode this guards is
    // not an ugly bar, it is the framework's yellow-and-black overflow
    // stripe — on a church wall.
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(_reader(), AppSettings()));
    await tester.pump();
    expect(tester.takeException(), isNull);
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
