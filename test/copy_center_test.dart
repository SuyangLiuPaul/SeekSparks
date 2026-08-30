/// Widget tests for the Copy Center — the dialog behind bwh28's "Copy
/// Verses" and bwh29's Output Format Options.
///
/// The formatting itself is covered by `copy_format_test.dart` against
/// the pure core. What is only testable here is the wiring: that the
/// dialog finds real verse text without touching an asset, that the
/// preview is genuinely live, and that the licence ceiling is enforced
/// where the reader can see it rather than only in the constant.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/version_attribution.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/pages/workbench_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/providers/workbench_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 'cuvs-yhwh' is MainProvider's default currentVersion, so seeding the
  // cache under that code is what lets the dialog resolve text through
  // `peekCachedVersion` instead of reading assets/*.json — which does
  // not exist in a unit test and would leave every preview empty.
  const version = 'cuvs-yhwh';

  List<Verse> chapterOf(int count) => [
        for (var i = 1; i <= count; i++)
          Verse(
            book: 'Genesis',
            chapter: 1,
            verse: i,
            text: 'verse text $i',
          ),
      ];

  Future<MainProvider> pump(
    WidgetTester tester, {
    int verseCount = 3,
    String locale = 'en',
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 900);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final seed = chapterOf(verseCount);
    late MainProvider mp;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) {
            mp = MainProvider();
            mp.setVerses(seed);
            mp.cacheVersionForTest(version, seed);
            mp.currentBook = 'Genesis';
            mp.currentChapter = 1;
            return mp;
          }),
          ChangeNotifierProvider(create: (_) {
            final settings = AppSettings();
            // ignore: unawaited_futures
            settings.setLocale(locale);
            return settings;
          }),
        ],
        child: const MaterialApp(home: WorkbenchPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    return mp;
  }

  Future<void> openCopyCenter(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.copy_all_outlined).first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// The preview text, read out of the dialog rather than recomputed —
  /// a test that recomputed it would pass even if the preview were
  /// wired to nothing.
  String previewText(WidgetTester tester) {
    final widgets = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .toList();
    return widgets.isEmpty ? '' : (widgets.first.data ?? '');
  }

  testWidgets('opens from the toolbar and previews the real verse text',
      (tester) async {
    addTearDown(tester.view.reset);
    await pump(tester);
    await openCopyCenter(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Copy Center'), findsOneWidget);
    final preview = previewText(tester);
    expect(preview, contains('verse text 1'));
    expect(preview, contains('verse text 3'));
    // The reference heading, and the rights line the licence obliges.
    expect(preview, contains('Genesis 1'));
    expect(preview, contains('used with permission'));
  });

  testWidgets('the preview is live — flipping a switch rewrites it',
      (tester) async {
    addTearDown(tester.view.reset);
    await pump(tester);
    await openCopyCenter(tester);
    expect(previewText(tester), contains('verse text 1'));

    // "References only" is the preset that drops the text entirely, so
    // it is the one whose effect cannot be faked by a stale preview.
    await tester.tap(find.text('References only'));
    await tester.pump(const Duration(milliseconds: 300));

    final after = previewText(tester);
    expect(after, isNot(contains('verse text 1')));
    // Three consecutive verses collapse to a range, per bwh29.
    expect(after, contains('Genesis 1:1'));
    expect(after, contains('3'));
  });

  testWidgets('turning off the copyright line removes it', (tester) async {
    addTearDown(tester.view.reset);
    await pump(tester);
    await openCopyCenter(tester);
    expect(previewText(tester), contains('used with permission'));

    // Last switch in the options column, so it starts below the fold.
    final toggle = find.text('Append the copyright line');
    await tester.ensureVisible(toggle);
    await tester.pump();
    await tester.tap(toggle);
    await tester.pump(const Duration(milliseconds: 300));

    expect(previewText(tester), isNot(contains('used with permission')));
  });

  testWidgets('a licensed edition stops at the publisher quotation limit',
      (tester) async {
    addTearDown(tester.view.reset);
    // One more verse than the ceiling, so the trim is by one and cannot
    // be an off-by-one in the fixture.
    await pump(tester, verseCount: kLicensedCopyVerseLimit + 1);
    await openCopyCenter(tester);

    expect(tester.takeException(), isNull);
    // The reader is told, in the dialog, what was left behind and why.
    expect(
      find.textContaining('Copying $kLicensedCopyVerseLimit of'),
      findsOneWidget,
    );
    final preview = previewText(tester);
    expect(preview, contains('verse text $kLicensedCopyVerseLimit'));
    expect(
      preview,
      isNot(contains('verse text ${kLicensedCopyVerseLimit + 1}')),
    );
  });

  testWidgets('no overflow at a desktop width', (tester) async {
    addTearDown(tester.view.reset);
    await pump(tester);
    await openCopyCenter(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no overflow in a narrow workspace', (tester) async {
    addTearDown(tester.view.reset);
    await pump(tester);
    tester.view.physicalSize = const Size(760, 900);
    await tester.pump(const Duration(milliseconds: 100));
    await openCopyCenter(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders in Chinese without falling back to English',
      (tester) async {
    addTearDown(tester.view.reset);
    await pump(tester, locale: 'zh-Hans');
    await openCopyCenter(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('复制中心'), findsOneWidget);
    expect(find.text('Copy Center'), findsNothing);
  });

  // ── Marking the search hit (2026-08-31) ─────────────────────────

  /// Put a query on the workbench without running a search: the search
  /// itself reads assets this test has none of, and what is under test
  /// is what the Copy Center does with a query, not how one is found.
  void setQuery(WidgetTester tester, String query) {
    final ctx = tester.element(find.byIcon(Icons.copy_all_outlined).first);
    Provider.of<WorkbenchProvider>(ctx, listen: false).lastQuery = query;
  }

  /// The preview's rich text, which is where a marked preview lives —
  /// `SelectableText.data` is null once it is built from spans.
  InlineSpan? previewSpan(WidgetTester tester) => tester
      .widgetList<SelectableText>(find.byType(SelectableText))
      .first
      .textSpan;

  testWidgets('with no search running the switch is not offered',
      (tester) async {
    addTearDown(tester.view.reset);
    await pump(tester);
    await openCopyCenter(tester);
    expect(find.text('Mark search hits'), findsNothing);
    expect(previewText(tester), contains('verse text 1'));
  });

  testWidgets('a running search offers the switch and marks the preview',
      (tester) async {
    addTearDown(tester.view.reset);
    await pump(tester);
    setQuery(tester, 'text');
    await openCopyCenter(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Mark search hits'), findsOneWidget);

    final span = previewSpan(tester);
    expect(span, isNotNull);
    // Same words, and the searched one carries weight the rest does not.
    expect(span!.toPlainText(), contains('verse text 1'));
    final marked = <String>[];
    span.visitChildren((s) {
      if (s is TextSpan && s.style?.fontWeight == FontWeight.w700) {
        marked.add(s.text ?? '');
      }
      return true;
    });
    expect(marked, isNotEmpty);
    expect(marked.every((m) => m.toLowerCase() == 'text'), isTrue,
        reason: 'only the query term should be marked, got $marked');
  });

  testWidgets('turning the switch off puts the plain preview back',
      (tester) async {
    addTearDown(tester.view.reset);
    await pump(tester);
    setQuery(tester, 'text');
    await openCopyCenter(tester);
    expect(previewSpan(tester), isNotNull);

    // The options column scrolls; the switch sits below the fold at
    // this height, so it has to be brought into view before it can be
    // tapped — the same thing the reader does.
    await tester.ensureVisible(find.text('Mark search hits'));
    await tester.pump();
    await tester.tap(find.text('Mark search hits'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(previewText(tester), contains('verse text 1'));
  });
}
