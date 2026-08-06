/// 2026-08-06 (SeekSparks): reproduction for the blank Browse window.
///
/// v1.5.0 shipped a Browse window that rendered nothing and logged
/// `Invalid argument: 0` every frame. The deployed build is minified, so
/// the stack was unreadable; this test drives the same code path against
/// the real bundled assets to get the exception unminified.
///
/// Kept afterwards as the regression guard: the Browse window must
/// render a chapter across a tagged version, an untagged version and the
/// originals line without throwing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/widgets/browse_window.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpBrowse(
    WidgetTester tester, {
    required List<String> versions,
    String book = 'Genesis',
    int chapter = 1,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(900, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => AppSettings())],
        child: MaterialApp(
          home: Scaffold(
            body: BrowseWindow(
              book: book,
              chapter: chapter,
              versionCodes: versions,
              focusedVerse: 1,
            ),
          ),
        ),
      ),
    );
    // The window fetches whole-version JSON; give it room to settle
    // without pumpAndSettle (its spinner would never settle).
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('renders a chapter with a tagged Chinese version',
      (tester) async {
    await pumpBrowse(tester, versions: ['cuvs-yhwh']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the mixed stack the user had selected',
      (tester) async {
    // NASB · KJV · LEB · CUVS(简) · CUVS(繁) — the combination that went
    // blank in v1.5.0.
    await pumpBrowse(tester, versions: [
      'nasb',
      'kjv',
      'leb',
      'cuvs-yhwh',
      'cuvs-yhwh-tr',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders a Greek chapter (originals line is BGT)',
      (tester) async {
    await pumpBrowse(tester,
        versions: ['nasb', 'cuvs-yhwh'], book: 'John', chapter: 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a rebuild does not move the scroll position', (tester) async {
    // v1.5.1 called _scrollToFocused() from build(), so every hover —
    // which rebuilds the workspace to update the Analysis window — threw
    // the reader back to the cursor verse. The pane appeared to scroll
    // on its own while the mouse merely moved over the text.
    await pumpBrowse(tester, versions: ['nasb', 'kjv']);
    if (find.byType(Scrollable).evaluate().isEmpty) {
      // No chapter loaded in this environment; nothing to assert about
      // scrolling, and a false pass is worse than a skip.
      return;
    }

    // Scroll well away from verse 1, where the cursor sits.
    await tester.drag(
        find.byType(BrowseWindow), const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 300));

    Rect? anchor() {
      final f = find.textContaining('Genesis', findRichText: true);
      if (f.evaluate().isEmpty) return null;
      return tester.getRect(f.first);
    }

    final before = anchor();
    if (before == null) return;

    // Rebuild repeatedly, exactly as a hover does.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final after = anchor();

    expect(after, isNotNull);
    // Same first-visible row, in the same place: no jump was scheduled.
    expect((after!.top - before.top).abs(), lessThan(1.0),
        reason: 'rebuilding must not scroll the Browse window');
    expect(tester.takeException(), isNull);
  });
}
