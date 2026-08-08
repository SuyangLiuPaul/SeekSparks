/// The splash has to hand over. This file exists because it stopped
/// doing so, in prod, on phones — the v1.6.56 report was "the app sits
/// on the splash forever" — and 1400-odd green tests said nothing.
///
/// The trap is a one-shot flag. `LoadingPage` arms a 3 s timer that
/// hands control to the app, and it may only arm it once the verses are
/// actually loaded. v1.2.28 added a build-time safety net that marked
/// the one shot as spent BEFORE checking whether there was anything to
/// hand over, so the ordering below — first build with the boot still in
/// flight, verses arriving afterwards — burned the shot on a no-op and
/// nothing ever re-armed it.
///
/// That ordering is the NORMAL one on a phone: `main.dart`'s 4 s splash
/// watchdog mounts this page whether or not the active version has
/// finished downloading, so a cold cache or a slow connection lands here
/// every time. On a warm desktop the verses are already in hand when the
/// page mounts, which is why no test and no screenshot ever caught it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/pages/loading_page.dart';
import 'package:seeksparks/providers/main_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const someVerses = <Verse>[
    Verse(book: 'John', chapter: 1, verse: 1, text: 'In the beginning'),
  ];

  /// Mounts the splash the way `main.dart` does, with whatever the
  /// provider happens to hold at that moment.
  Future<void> pumpSplash(
    WidgetTester tester,
    MainProvider mp, {
    required VoidCallback onAdvance,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppSettings>(create: (_) => AppSettings()),
          ChangeNotifierProvider<MainProvider>.value(value: mp),
        ],
        child: MaterialApp(
          home: LoadingPage(verses: mp.verses, onAdvance: onAdvance),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('verses arriving AFTER the first build still hand over',
      (tester) async {
    addTearDown(tester.view.reset);
    final mp = MainProvider();
    addTearDown(mp.dispose);
    // The state the 4 s watchdog produces: page mounted, boot still
    // running, nothing loaded yet.
    mp.setBootInFlight(true);
    var advanced = false;
    await pumpSplash(tester, mp, onAdvance: () => advanced = true);
    expect(advanced, isFalse, reason: 'nothing to advance to yet');

    // The boot finishes normally, a whole second later.
    await tester.pump(const Duration(seconds: 1));
    mp.setVerses(someVerses);
    mp.setBootInFlight(false);
    await tester.pump();

    // The 3 s hand-off must have been armed by that build.
    await tester.pump(const Duration(seconds: 4));
    expect(advanced, isTrue,
        reason: 'the splash never handed over — this is the v1.6.56 hang');
  });

  testWidgets('the ordinary warm boot still hands over exactly once',
      (tester) async {
    addTearDown(tester.view.reset);
    final mp = MainProvider();
    addTearDown(mp.dispose);
    mp.setVerses(someVerses);
    mp.setBootInFlight(false);
    var advanceCount = 0;
    await pumpSplash(tester, mp, onAdvance: () => advanceCount++);

    await tester.pump(const Duration(seconds: 4));
    expect(advanceCount, 1);

    // The eager version pre-load fires notifyListeners once per bundled
    // version after this point; none of them may re-arm the timer.
    for (var i = 0; i < 12; i++) {
      mp.setVerses(someVerses);
      await tester.pump();
    }
    await tester.pump(const Duration(seconds: 4));
    expect(advanceCount, 1, reason: 'the hand-off must not repeat');
  });

  testWidgets('a boot that genuinely loaded nothing does not hand over',
      (tester) async {
    // The complement, and the reason the flag cannot simply be dropped:
    // handing over to an empty app is worse than staying put, because
    // the splash owns the retry UI.
    addTearDown(tester.view.reset);
    final mp = MainProvider();
    addTearDown(mp.dispose);
    mp.setBootInFlight(true);
    var advanced = false;
    await pumpSplash(tester, mp, onAdvance: () => advanced = true);
    await tester.pump(const Duration(seconds: 4));
    expect(advanced, isFalse);
  });
}
