// A Resource is only a Resource if it brings you back to the text.
//
// The audit (task #281) settled that the test for whether a screen
// earns its place is: *does it take you to the text, or bring you back
// from it holding something?* — the property every BibleWorks module
// has. The Family Tree, Timeline, Evidence, Trivia, Highlights and
// lexicon pages all cite verses, and every one of them round-trips
// through [navigateToReader].
//
// That round-trip silently broke when the Workbench became the app
// root. `main.dart` hands the Workbench to `MaterialApp.home:`, and a
// widget passed to `home:` gets [Navigator.defaultRouteName] (`'/'`),
// which matches none of the explicit reader route names. So the walk
// fell through to the root, concluded no reader existed, and pushed the
// CLASSIC single-pane HomePage on top of the Workbench — ejecting the
// reader out of the workspace task #276 had just folded it into.
//
// Nothing behavioural caught it: a HomePage renders the verse
// correctly. It is the *workspace* that was lost.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/navigate_to_reader.dart';

void main() {
  group('routeIsReader', () {
    test('the root route is a reader even though it has no name', () {
      // The whole bug in one assertion.
      expect(routeIsReader('/', isFirst: true), isTrue);
      expect(routeIsReader(null, isFirst: true), isTrue);
    });

    test('the explicit reader route names still count', () {
      expect(routeIsReader(kHomePageRouteName, isFirst: false), isTrue);
      expect(routeIsReader(kWorkbenchRouteName, isFirst: false), isTrue);
      // pushPage derives the name from the widget's runtimeType, so a
      // push site that forgets the explicit routeName still resolves.
      expect(routeIsReader('/HomePage', isFirst: false), isTrue);
      expect(routeIsReader('/WorkbenchPage', isFirst: false), isTrue);
    });

    test('a Resource pushed on top of the reader is not itself a reader',
        () {
      for (final name in const [
        '/FamilyTreePage',
        '/BibleTimelinePage',
        '/EvidencePage',
        '/StrongsEntryPage',
        '/SettingsPage',
        '',
      ]) {
        expect(routeIsReader(name, isFirst: false), isFalse,
            reason: '$name must be popped past, not treated as the reader');
      }
    });
  });

  test('main.dart still puts a reader at the root', () {
    // `routeIsReader(isFirst: true) == true` is only sound while the
    // bottom of the navigator stack shows the Bible text. If the app
    // ever grows a non-reader root again (a home screen, an onboarding
    // wall), the predicate above starts lying and every "open in
    // reader" becomes a no-op instead of an eject.
    final src = File('lib/main.dart').readAsStringSync();
    expect(src.contains('WorkbenchPage()'), isTrue,
        reason: 'lib/main.dart no longer resolves its root to the '
            'Workbench. routeIsReader() assumes the root IS a reader — '
            'if that stopped being true, fix the predicate, not this '
            'test.');
  });

  test('there is exactly one reading surface', () {
    // 2026-09-08, at the owner's decision: 「reader 并进去吧」.
    //
    // `home_page.dart` — the classic single-pane reader — is retired.
    // Its own doc had said for a month that it "holds no capability the
    // Workbench lacks" and that retiring it was "a product decision
    // about whether the app has one reading surface or two, not
    // cleanup". The decision has now been made.
    //
    // The three things that still opened it were `open_reader.dart`'s
    // width branch, `navigate_to_reader.dart`'s no-reader fallback, and
    // the boot route in `loading_page.dart`. All three now land on the
    // Workbench, which `main.dart` has handed EVERY width since
    // 2026-08-06 and which degrades to exactly the centre reading pane
    // below 600 — so the width branch had been choosing between the
    // Workbench and a narrower copy of the Workbench.
    //
    // Asserted about the FILE, because a page nothing imports is
    // invisible to every other kind of test — the lesson
    // `page_reachability_test.dart` was written for.
    expect(File('lib/pages/home_page.dart').existsSync(), isFalse,
        reason: 'The classic reader is back. If that is deliberate, this '
            'is the test to change — but it is a product decision about '
            'having one reading surface or two, not a refactor.');
  });

  test('no page reaches the reader by pushing HomePage itself', () {
    // The ratchet, and it outlives the class it is named for: seven
    // pages had grown their own copy of "prepare the jump, then push
    // HomePage", which is what made a single wrong predicate break the
    // round-trip everywhere at once. `HomePage` is gone, so this can no
    // longer compile even if someone wrote it — but the shape it
    // forbids is "push your own reader instead of returning to the
    // one that exists", and that is still writable with WorkbenchPage.
    final offenders = <String>[];
    for (final entry in Directory('lib').listSync(recursive: true)) {
      if (entry is! File || !entry.path.endsWith('.dart')) continue;
      final path = entry.path.replaceAll(r'\', '/');
      // The helper is where the one remaining push lives, and is the
      // only legitimate fallback for a root that is not a reader.
      if (path == 'lib/utils/navigate_to_reader.dart') continue;
      // open_reader.dart is the deep-link entry point: it runs before
      // any navigator stack exists, so it has nothing to pop back to.
      if (path == 'lib/utils/open_reader.dart') continue;
      // Code only. Several files discuss the old pattern in prose, and
      // a ratchet that fires on its own explanation gets deleted rather
      // than fixed.
      final code = entry
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      if (code.contains('pushPage(const HomePage()') ||
          code.contains('Get.off(() => const HomePage()') ||
          code.contains('Get.off(() => const WorkbenchPage()')) {
        offenders.add(path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'These files push the classic single-pane reader '
            'directly, which lands it ON TOP of the Workbench instead '
            'of returning to it. Call navigateToReader(context) after '
            'preparing the jump.');
  });
}
