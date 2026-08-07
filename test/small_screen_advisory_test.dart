/// Widget tests for the small-screen advisory — the screen that tells
/// a phone reader SeekSparks is a workbench rather than quietly
/// degrading into a one-column reader (which is YsWords, the app this
/// one was forked from).
///
/// Two halves, deliberately: `SmallScreenGate` decides *whether* to
/// show it and owns the persisted "no", and is tested with a stand-in
/// child rather than the real WorkbenchPage. `SmallScreenAdvisory`
/// only renders copy, takes its locale as a parameter like every other
/// pane here, and so needs no providers at all.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/utils/workbench_fit.dart';
import 'package:seeksparks/widgets/small_screen_advisory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const workbenchMarker = Key('stand-in-workbench');

  String s(String key, String locale) => uiStrings[key]![locale]!;

  Future<void> pumpGate(
    WidgetTester tester,
    Size size, {
    Map<String, Object> prefs = const <String, Object>{},
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    SharedPreferences.setMockInitialValues(prefs);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppSettings>(
        create: (_) => AppSettings(),
        child: const MaterialApp(
          home: SmallScreenGate(
            child: Scaffold(body: SizedBox.shrink(key: workbenchMarker)),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> pumpAdvisory(
    WidgetTester tester,
    Size size, {
    String locale = 'en',
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    await tester.pumpWidget(
      MaterialApp(
        home: SmallScreenAdvisory(
          advice: WorkbenchFit.adviceFor(
            width: size.width,
            height: size.height,
            dismissed: false,
          ),
          size: size,
          locale: locale,
          onLocale: (_) {},
          onContinue: () {},
        ),
      ),
    );
    await tester.pump();
  }

  group('who sees it', () {
    testWidgets('phone portrait gets the advisory, not the workbench',
        (tester) async {
      addTearDown(tester.view.reset);
      await pumpGate(tester, const Size(390, 844));
      expect(find.byType(SmallScreenAdvisory), findsOneWidget);
      expect(find.byKey(workbenchMarker), findsNothing);
    });

    testWidgets('a phone gets it in BOTH orientations — two columns is not it',
        (tester) async {
      addTearDown(tester.view.reset);
      await pumpGate(tester, const Size(844, 390));
      expect(find.byType(SmallScreenAdvisory), findsOneWidget);
      expect(find.byKey(workbenchMarker), findsNothing);
    });

    testWidgets('a screen too narrow even sideways still gets it',
        (tester) async {
      addTearDown(tester.view.reset);
      await pumpGate(tester, const Size(700, 400));
      expect(find.byType(SmallScreenAdvisory), findsOneWidget);
    });

    testWidgets('iPad mini portrait is one column, so it is advised',
        (tester) async {
      // 744 wide carries one column. Landscape (1133) carries three.
      addTearDown(tester.view.reset);
      await pumpGate(tester, const Size(744, 1133));
      expect(find.byType(SmallScreenAdvisory), findsOneWidget);
    });

    testWidgets('a desktop never pays a frame for it', (tester) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1400, 900);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.pumpWidget(
        ChangeNotifierProvider<AppSettings>(
          create: (_) => AppSettings(),
          child: const MaterialApp(
            home: SmallScreenGate(
              child: Scaffold(body: SizedBox.shrink(key: workbenchMarker)),
            ),
          ),
        ),
      );
      // First frame, before any SharedPreferences read could complete.
      expect(find.byKey(workbenchMarker), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));
    });
  });

  group('the gate is hard — there is no way past it', () {
    testWidgets('no "continue anyway" escape is offered', (tester) async {
      // 2026-08-07: removed at the owner's instruction —
      // 「不要有仍然继续，就一直是block住」. A one-column workbench is not a
      // product they want shipped, and every reader let past the gate
      // judges the app on it.
      addTearDown(tester.view.reset);
      await pumpGate(tester, const Size(390, 844));
      expect(find.text(s('fitContinue', 'zh-Hans')), findsNothing);
      expect(find.byType(SmallScreenAdvisory), findsOneWidget);
      expect(find.byKey(workbenchMarker), findsNothing);
    });

    testWidgets('a dismissal saved by an older build no longer exempts anyone',
        (tester) async {
      // Readers who tapped "Continue anyway" in v1.6.20 are exactly the
      // ones who saw the self-contradicting advisory. Honouring that
      // stale bit would leave them permanently past a gate that is now
      // meant to hold.
      addTearDown(tester.view.reset);
      await pumpGate(
        tester,
        const Size(390, 844),
        prefs: const {kSmallScreenDismissedKey: true},
      );
      expect(find.byType(SmallScreenAdvisory), findsOneWidget);
      expect(find.byKey(workbenchMarker), findsNothing);
    });

    testWidgets('a display that carries all three columns goes straight in',
        (tester) async {
      addTearDown(tester.view.reset);
      await pumpGate(tester, const Size(1280, 800));
      expect(find.byType(SmallScreenAdvisory), findsNothing);
      expect(find.byKey(workbenchMarker), findsOneWidget);
    });
  });

  group('the language switch is the only way out of the wrong language', () {
    testWidgets('all three languages are offered, in their own script',
        (tester) async {
      addTearDown(tester.view.reset);
      await pumpAdvisory(tester, const Size(390, 844), locale: 'en');
      expect(find.text('EN'), findsOneWidget);
      expect(find.text('简'), findsOneWidget);
      expect(find.text('繁'), findsOneWidget);
    });

    testWidgets('tapping one reports the code the app settings expect',
        (tester) async {
      addTearDown(tester.view.reset);
      String? picked;
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpWidget(
        MaterialApp(
          home: SmallScreenAdvisory(
            advice: WorkbenchAdvice.rotate,
            size: const Size(390, 844),
            locale: 'en',
            onContinue: () {},
            onLocale: (c) => picked = c,
          ),
        ),
      );
      await tester.tap(find.text('简'));
      expect(picked, 'zh-Hans');
    });

    testWidgets('the language already showing is not offered as a change',
        (tester) async {
      addTearDown(tester.view.reset);
      await pumpAdvisory(tester, const Size(390, 844), locale: 'zh-Hans');
      final current = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('简'),
          matching: find.byType(TextButton),
        ),
      );
      expect(current.onPressed, isNull);
    });
  });

  group('what it says', () {
    testWidgets('portrait is told to rotate', (tester) async {
      addTearDown(tester.view.reset);
      await pumpAdvisory(tester, const Size(834, 1194));
      expect(find.text(s('fitRotate', 'en')), findsOneWidget);
      expect(find.text(s('fitLarger', 'en')), findsNothing);
    });

    testWidgets('landscape is never told to rotate a phone already rotated',
        (tester) async {
      addTearDown(tester.view.reset);
      await pumpAdvisory(tester, const Size(844, 390));
      expect(find.text(s('fitLarger', 'en')), findsOneWidget);
      expect(find.text(s('fitRotate', 'en')), findsNothing);
    });

    testWidgets('quotes the real viewport and the real pane minimums',
        (tester) async {
      addTearDown(tester.view.reset);
      await pumpAdvisory(tester, const Size(834, 1194));
      final needs = find.textContaining('834 × 1194');
      expect(needs, findsOneWidget);
      expect(
        tester.widget<Text>(needs).data!,
        // Only the THREE-pane figure is quoted now. The two-pane number
        // was dropped from the copy with the gate: mentioning a
        // threshold the app no longer honours just invites the reader to
        // aim for it.
        contains(WorkbenchFit.threePaneMinWidth.round().toString()),
      );
    });

    testWidgets('points at YsWords rather than pretending to be it',
        (tester) async {
      addTearDown(tester.view.reset);
      await pumpAdvisory(tester, const Size(834, 1194));
      expect(find.text(s('fitYsWords', 'en')), findsOneWidget);
    });

    testWidgets('is information, not an error — no error iconography',
        (tester) async {
      addTearDown(tester.view.reset);
      await pumpAdvisory(tester, const Size(834, 1194));
      for (final icon in [
        Icons.error,
        Icons.error_outline,
        Icons.warning,
        Icons.warning_amber,
        Icons.block,
      ]) {
        expect(find.byIcon(icon), findsNothing, reason: '$icon is a scolding');
      }
    });

    testWidgets('renders in Chinese without falling back to English',
        (tester) async {
      addTearDown(tester.view.reset);
      await pumpAdvisory(tester, const Size(834, 1194), locale: 'zh-Hant');
      expect(find.text(s('fitTitle', 'zh-Hant')), findsOneWidget);
      expect(find.text(s('fitRotate', 'zh-Hant')), findsOneWidget);
      expect(find.text(s('fitTitle', 'en')), findsNothing);
    });

    testWidgets('every string is translated in all three locales',
        (tester) async {
      for (final key in const [
        'fitTitle',
        'fitLead',
        'fitNeeds',
        'fitRotate',
        'fitLarger',
        'fitYsWords',
        'fitOpenYsWords',
        'fitContinue',
        'fitContinueNote',
      ]) {
        for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
          expect(uiStrings[key]?[locale], isNotNull,
              reason: '$key missing $locale');
        }
      }
    });

    testWidgets('fits the smallest phone without overflowing', (tester) async {
      addTearDown(tester.view.reset);
      await pumpAdvisory(tester, const Size(320, 568));
      expect(tester.takeException(), isNull);
      expect(find.byType(SmallScreenAdvisory), findsOneWidget);
    });
  });
}
