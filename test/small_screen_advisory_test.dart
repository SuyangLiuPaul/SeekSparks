/// Widget tests for the small-screen advisory — the screen that tells
/// a phone reader SeekSparks is a workbench rather than quietly
/// degrading into a one-column reader (which is YsWords, the app this
/// one was forked from).
///
/// Two halves, deliberately: `SmallScreenGate` decides *whether* to
/// show it and is tested with a stand-in child rather than the real
/// WorkbenchPage. `SmallScreenAdvisory` only renders copy, takes its
/// locale as a parameter like every other pane here, and so needs no
/// providers at all.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/app_version.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/utils/workbench_fit.dart';
import 'package:seeksparks/widgets/small_screen_advisory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const workbenchMarker = Key('stand-in-workbench');

  String s(String key, String locale) => uiStrings[key]![locale]!;

  /// Builds the gate and pumps EXACTLY ONE frame. Every assertion below
  /// therefore also asserts that the answer needed no second frame — no
  /// disk read, no timer, no boot. See the "answered on the first frame"
  /// group for why that is the point rather than a convenience.
  Future<void> pumpGate(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
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
      await pumpGate(tester, const Size(1400, 900));
      expect(find.byKey(workbenchMarker), findsOneWidget);
    });
  });

  group('answered on the first frame — nothing may be waited on', () {
    // 2026-08-08, the v1.6.56 prod bug: phones sat on the splash. The
    // gate used to be mounted INSIDE the post-splash router and to hold
    // on a blank Scaffold while SharedPreferences loaded, so the answer
    // arrived only after the whole cold boot — every bundled Bible
    // parsed — and a boot that never advanced meant it never arrived at
    // all. The viewport is the only input the decision has, and it is
    // known immediately, so these tests pump ONE frame and no timers.

    testWidgets('the advisory is painted on the very first frame',
        (tester) async {
      addTearDown(tester.view.reset);
      await pumpGate(tester, const Size(375, 812));
      expect(find.byType(SmallScreenAdvisory), findsOneWidget);
    });

    testWidgets('no blank frame stands between the reader and the answer',
        (tester) async {
      // The old gate returned a bare `Scaffold` with no children while
      // it waited. Whatever this widget shows on frame one, it must be
      // the advisory or the app — never an empty holding screen.
      addTearDown(tester.view.reset);
      await pumpGate(tester, const Size(375, 812));
      expect(find.byKey(workbenchMarker), findsNothing);
      expect(find.byType(SmallScreenAdvisory), findsOneWidget);
    });

    testWidgets('the gate settles with no pending timers or async work',
        (tester) async {
      // `pumpAndSettle` throws if the frame scheduler never goes quiet,
      // and a pending SharedPreferences round-trip would leave work
      // behind. Nothing to settle is exactly the property wanted.
      addTearDown(tester.view.reset);
      await pumpGate(tester, const Size(375, 812));
      await tester.pumpAndSettle();
      expect(find.byType(SmallScreenAdvisory), findsOneWidget);
      expect(tester.takeException(), isNull);
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

    testWidgets('a dismissal saved by an older build cannot exempt anyone',
        (tester) async {
      // Readers who tapped "Continue anyway" in v1.6.20 are exactly the
      // ones who saw the self-contradicting advisory, so honouring that
      // stale bit would leave them permanently past a gate that is now
      // meant to hold. v1.6.60 made that unreachable by construction:
      // the gate reads no persisted state at all. This test runs with no
      // SharedPreferences mock configured — a gate that still tried to
      // read one would throw a MissingPluginException here.
      addTearDown(tester.view.reset);
      await pumpGate(tester, const Size(390, 844));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
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
      // The full recommendation belongs to the branch where this
      // display genuinely cannot carry the workbench.
      addTearDown(tester.view.reset);
      await pumpAdvisory(tester, const Size(844, 390));
      expect(find.text(s('fitYsWords', 'en')), findsOneWidget);
    });

    testWidgets('a device that only needs turning is not sent to YsWords',
        (tester) async {
      // #316: on the rotate branch the device in the reader's hands
      // works — "SeekSparks needs a tablet or a laptop" would be false,
      // and the big Open YsWords button argued the reader out of a
      // one-gesture fix. The sibling app stays reachable, quietly.
      addTearDown(tester.view.reset);
      await pumpAdvisory(tester, const Size(949, 1375));
      expect(find.text(s('fitYsWords', 'en')), findsNothing);
      expect(find.text(s('fitYsWordsAside', 'en')), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('the rotate branch proves the claim with the long edge',
        (tester) async {
      // 949 × 1375 is the owner's Mi Pad, the device that reported this.
      addTearDown(tester.view.reset);
      await pumpAdvisory(tester, const Size(949, 1375));
      final needs = find.textContaining('949 × 1375');
      expect(needs, findsOneWidget);
      expect(tester.widget<Text>(needs).data!, contains('1375 px'));
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

    testWidgets('fits the smallest phone without overflowing', (tester) async {
      addTearDown(tester.view.reset);
      await pumpAdvisory(tester, const Size(320, 568));
      expect(tester.takeException(), isNull);
      expect(find.byType(SmallScreenAdvisory), findsOneWidget);
    });

    testWidgets('the build identity is legible from behind the gate',
        (tester) async {
      // #316, the owner's second ask: the gate is a hard block, so
      // Settings and About are both unreachable from here. A reader
      // stopped by this screen is exactly the reader being asked which
      // build they are on, and until now had no way to find out.
      addTearDown(tester.view.reset);
      await pumpAdvisory(tester, const Size(949, 1375));
      expect(find.textContaining('v$kAppVersion'), findsOneWidget);
    });
  });

  group('the diagram is a picture, not three hairlines', () {
    Finder bars() => find.descendant(
          of: find.byKey(const Key('fit-pane-diagram')),
          matching: find.byType(DecoratedBox),
        );

    testWidgets('every bar has real height', (tester) async {
      // Found by screenshot on dev v1.6.131, not by any test. A
      // childless DecoratedBox takes the smallest size its constraints
      // allow, and a Row's default `center` cross-axis alignment passes
      // a LOOSE constraint down — so all three bars were 0 px tall and
      // the diagram drew as three grey dashes. The SizedBox around them
      // measured its full 56 px the whole time, which is why asserting
      // on the widget rather than the paint proved nothing.
      addTearDown(tester.view.reset);
      await pumpAdvisory(tester, const Size(949, 1375));
      expect(bars(), findsNWidgets(3));
      for (var i = 0; i < 3; i++) {
        expect(tester.getSize(bars().at(i)).height, 56,
            reason: 'bar $i collapsed');
        expect(tester.getSize(bars().at(i)).width, greaterThan(20));
      }
    });

    testWidgets('a rotation is drawn as all three columns, not two',
        (tester) async {
      // The copy said "three" and the picture said "two" — and the
      // picture is read first. `rotate` is returned only when the long
      // edge clears the three-pane threshold, so anything less than
      // three filled bars here contradicts the branch that selected it.
      addTearDown(tester.view.reset);
      await pumpAdvisory(tester, const Size(949, 1375));
      var filled = 0;
      for (var i = 0; i < 3; i++) {
        final d = tester.widget<DecoratedBox>(bars().at(i)).decoration
            as BoxDecoration;
        if (d.color != null) filled++;
      }
      expect(filled, 3);
    });

    testWidgets('a display that cannot grow is drawn as one column',
        (tester) async {
      addTearDown(tester.view.reset);
      await pumpAdvisory(tester, const Size(844, 390));
      var filled = 0;
      for (var i = 0; i < 3; i++) {
        final d = tester.widget<DecoratedBox>(bars().at(i)).decoration
            as BoxDecoration;
        if (d.color != null) filled++;
      }
      expect(filled, 1);
    });
  });

  group('the three locales must not drift apart again', () {
    // HOW #316 SURVIVED. The copy was written for the two-column rule.
    // When the bar rose to three columns on 2026-08-07 (46bc7e5) only
    // the English was rewritten, so `fitRotate` went on telling a
    // Chinese reader 「把设备横过来即可显示三栏。手机横放也不够宽，请改用
    // 平板或电脑。」 — rotate and you get three columns, and also go and
    // find another device, in one sentence. Every test above passed
    // throughout: they assert a string is PRESENT in three locales,
    // never that the three say the same thing.
    //
    // Prose cannot be diffed for meaning, but this particular failure
    // can be named exactly. `rotate` is returned only when the long
    // edge carries all three columns, so the rotate copy must never
    // reach for the go-elsewhere vocabulary, in any language.

    const sendAway = [
      '平板', '电脑', '電腦', 'YsWords', 'tablet', 'laptop',
    ];

    for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
      test('fitRotate does not send $locale readers away', () {
        final v = uiStrings['fitRotate']![locale]!;
        for (final w in sendAway) {
          expect(v.toLowerCase(), isNot(contains(w.toLowerCase())),
              reason: 'fitRotate ($locale) offers a rotation and then '
                  'undercuts it with "$w": $v');
        }
      });

      test('fitRotate promises three columns in $locale, not two', () {
        // The English used to read "gets you two: search beside the
        // text", which was the old rule surviving verbatim.
        final v = uiStrings['fitRotate']![locale]!;
        expect(
          v.contains('three') || v.contains('三栏') || v.contains('三欄'),
          isTrue,
          reason: 'fitRotate ($locale) must name the full three: $v',
        );
        expect(v.contains('two columns'), isFalse, reason: v);
      });
    }

    test('every advisory string exists in all three locales', () {
      for (final key in const [
        'fitTitle',
        'fitLead',
        'fitNeeds',
        'fitRotateNeeds',
        'fitRotate',
        'fitLarger',
        'fitYsWords',
        'fitYsWordsAside',
        'fitOpenYsWords',
      ]) {
        for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
          expect(uiStrings[key]?[locale], isNotNull,
              reason: '$key missing $locale');
        }
      }
    });

    test('every locale of fitRotateNeeds carries all three placeholders', () {
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        final v = uiStrings['fitRotateNeeds']![locale]!;
        for (final p in const ['{three}', '{w}', '{h}', '{long}']) {
          expect(v, contains(p), reason: '$p missing from $locale');
        }
      }
    });
  });

  group('turning the device clears the gate by itself', () {
    testWidgets('the same tree switches to the workbench on rotation',
        (tester) async {
      // #316(3). The gate reads `MediaQuery.sizeOf`, so it should
      // dissolve the moment the device is turned, with no relaunch and
      // no navigation. Asserted rather than assumed: a reader who
      // follows the instruction and still sees the wall has been told
      // to do something that does not work.
      addTearDown(tester.view.reset);
      await pumpGate(tester, const Size(949, 1375));
      expect(find.byType(SmallScreenAdvisory), findsOneWidget);
      // Locale-independent: the gate builds AppSettings with its own
      // default language, and this icon is drawn on the rotate branch
      // and nowhere else.
      expect(find.byIcon(Icons.screen_rotation), findsOneWidget);

      tester.view.physicalSize = const Size(1375, 949);
      await tester.pump();

      expect(find.byType(SmallScreenAdvisory), findsNothing);
      expect(find.byKey(workbenchMarker), findsOneWidget);

      // And back again, so the gate is not a one-way door.
      tester.view.physicalSize = const Size(949, 1375);
      await tester.pump();
      expect(find.byType(SmallScreenAdvisory), findsOneWidget);
    });
  });

  group('every word on the wall is legible, in both brightnesses', () {
    // #316 asks for light AND dark. Light is verified by screenshot on
    // the deploy; dark is verified here, because Chrome's
    // `Emulation.setEmulatedMedia` does not reach Flutter's
    // platformBrightness through the CDP harness — `matchMedia` flips to
    // dark and the app keeps painting light, so a "dark screenshot" from
    // that harness would be a light screenshot with a false label.
    //
    // `RichText` is the hook rather than `Text`: by the time a Text has
    // become a RichText its style is FULLY resolved — theme defaults,
    // DefaultTextStyle and the widget's own copyWith all folded in. That
    // is the colour the reader actually sees, and it is the only one
    // worth asserting on. A `Text.style` assertion would have passed
    // through the whole tofu defect.
    Future<void> pumpThemed(WidgetTester tester, Brightness b) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(949, 1375);
      const size = Size(949, 1375);
      await tester.pumpWidget(
        MaterialApp(
          theme: workbenchTheme(ThemeData(brightness: b)),
          home: SmallScreenAdvisory(
            advice: WorkbenchFit.adviceFor(
              width: size.width,
              height: size.height,
              dismissed: false,
            ),
            size: size,
            locale: 'zh-Hans',
            onLocale: (_) {},
            onContinue: () {},
          ),
        ),
      );
      await tester.pump();
    }

    for (final (label, brightness) in const [
      ('light', Brightness.light),
      ('dark', Brightness.dark),
    ]) {
      testWidgets('$label: nothing is painted onto its own colour',
          (tester) async {
        addTearDown(tester.view.reset);
        await pumpThemed(tester, brightness);

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        final bg = scaffold.backgroundColor!;
        final faint = <String>[];
        var judged = 0;

        for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
          final span = rt.text as TextSpan;
          final text = span.toPlainText();
          if (text.trim().isEmpty) continue;
          final colour = span.style?.color;
          if (colour == null) continue;
          judged++;
          final ratio = _contrast(_over(colour, bg), bg);
          // 3:1 — the WCAG floor for large text and for UI components.
          // Deliberately not 4.5: the muted aside, the inactive language
          // buttons and the version footer are all meant to recede, and
          // a rule that forbids that would be a rule about taste. 3:1
          // still forbids the failure this guards against, which is text
          // that has effectively vanished.
          if (ratio < 3.0) {
            faint.add('"${text.length > 24 ? '${text.substring(0, 24)}…' : text}"'
                ' at ${ratio.toStringAsFixed(2)}:1');
          }
        }

        // Without this the group is a tautology: if the walk ever finds
        // nothing — a refactor to SelectableText, a colour left to the
        // theme — `faint` is empty and the test reports success having
        // looked at nothing. The wall carries the instruction, the
        // numbers, the title, the lead, the aside, the button, the
        // version and three language labels.
        expect(judged, greaterThanOrEqualTo(8),
            reason: 'the contrast walk found only $judged coloured strings; '
                'it is no longer reading the screen it claims to check');

        expect(faint, isEmpty,
            reason: 'this is a HARD GATE — the reader cannot reach Settings '
                'from here to fix the contrast, so anything they cannot '
                'read on this screen they cannot read at all:\n'
                '${faint.join('\n')}');
      });
    }
  });
}

/// [fg] composited over [bg], so a colour carrying an alpha is judged as
/// it is seen rather than as it is written.
Color _over(Color fg, Color bg) {
  final a = fg.a;
  return Color.from(
    alpha: 1.0,
    red: fg.r * a + bg.r * (1 - a),
    green: fg.g * a + bg.g * (1 - a),
    blue: fg.b * a + bg.b * (1 - a),
  );
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
