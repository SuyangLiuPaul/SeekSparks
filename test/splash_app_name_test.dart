/// The splash names the app ONCE, in the reader's own language.
///
/// It used to print `Yahweh's Sword` and `雅伟之剑` stacked on top of
/// each other, so every reader was shown one name they could read and
/// one they could not. The owner's call on 2026-08-31 was one name,
/// chosen by language.
///
/// The stacked version also hardcoded the SIMPLIFIED 雅伟之剑 with no
/// 繁體 branch at all, so a Traditional reader got a script they never
/// chose — that is why these tests check the exact string per locale
/// and not merely "something is shown".
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/pages/loading_page.dart';
import 'package:seeksparks/providers/main_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  const someVerses = <Verse>[
    Verse(book: 'John', chapter: 1, verse: 1, text: 'In the beginning'),
  ];

  /// Every name the app answers to. Whichever locale is active, exactly
  /// one of these may be on screen — the other two must be absent.
  const names = <String, String>{
    'en': "Yahweh's Sword",
    'zh-Hans': '雅伟之剑',
    'zh-Hant': '雅偉之劍',
  };

  Future<void> pumpSplash(
    WidgetTester tester, {
    required String locale,
    required bool booting,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final mp = MainProvider();
    addTearDown(mp.dispose);
    // `booting` picks which of the two scaffolds renders. Both draw the
    // name, and the fix had to land on both.
    mp.setBootInFlight(booting);
    if (!booting) mp.setVerses(someVerses);

    final settings = AppSettings();
    await settings.setLocale(locale);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppSettings>.value(value: settings),
          ChangeNotifierProvider<MainProvider>.value(value: mp),
        ],
        child: MaterialApp(
          home: LoadingPage(verses: mp.verses, onAdvance: () {}),
        ),
      ),
    );
    await tester.pump();
  }

  for (final booting in [true, false]) {
    final which = booting ? 'booting' : 'settled';
    group('the $which splash', () {
      for (final entry in names.entries) {
        testWidgets('${entry.key} sees ${entry.value}, and it alone',
            (tester) async {
          await pumpSplash(tester, locale: entry.key, booting: booting);

          expect(find.text(entry.value), findsOneWidget,
              reason: 'the ${entry.key} reader should see ${entry.value}');

          for (final other in names.entries) {
            if (other.key == entry.key) continue;
            expect(find.text(other.value), findsNothing,
                reason: 'the ${entry.key} reader was also shown '
                    '${other.value} — the splash is naming the app twice');
          }

          // Drain, or the test fails on pending timers rather than on
          // anything it set out to check: `setLocale` arms a 600 ms
          // cloud-prefs write debounce, and the splash arms its own
          // 3 s hand-off the moment it has verses to hand over.
          await tester.pump(const Duration(seconds: 4));
        });
      }
    });
  }
}
