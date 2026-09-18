import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:yahwehs_sword/models/app_settings.dart';

import 'package:yahwehs_sword/constants/ui_strings.dart';
import 'package:yahwehs_sword/models/verse.dart';
import 'package:yahwehs_sword/widgets/browse_nav_strip.dart';

/// The Browse window's book menu has a table of contents.
///
/// 2026-09-13, owner-reported against this strip: 「为什么这个不是两行
/// 新约旧约」. The sidebar picker has grouped the canon since the
/// 2026-09-03 report; this menu — the `约翰福音 ▾` dropdown in the
/// Browse toolbar — was still 66 undivided rows, so the same complaint
/// was true of it a fortnight later.
///
/// It uses the same `kBibleDivisions` table and the same `toEnglish`
/// matcher the picker does. One answer to "where does this book sit",
/// not two that can drift.
void main() {
  const locale = 'zh-Hans';

  List<Verse> corpus(List<String> books) => [
        for (final b in books)
          Verse(book: b, chapter: 1, verse: 1, text: '$b 1:1'),
      ];

  Future<void> open(WidgetTester tester, List<String> books) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<AppSettings>.value(
      value: AppSettings(),
      child: MaterialApp(
      home: Scaffold(
        body: BrowseNavStrip(
          corpus: corpus(books),
          version: 'kjv',
          localBook: books.first,
          chapter: 1,
          verse: 1,
          bookLabel: (b) => b,
          locale: locale,
          onVersion: (_) {},
          onBook: (_) {},
          onChapter: (_) {},
          onVerse: (_) {},
        ),
      ),
    )));
    await tester.pumpAndSettle();
    // The book dropdown is the second one in the strip.
    await tester.tap(find.text(books.first).first);
    await tester.pumpAndSettle();
  }

  String label(String id) => uiStrings[id]![locale]!;

  testWidgets('the menu is divided, not 66 rows in a row', (tester) async {
    await open(tester, const [
      '创世纪', '出埃及记', // Law
      '约书亚记', // History
      '诗篇', // Wisdom
      '以赛亚书', // Major prophets
      '何西阿书', // Minor prophets
      '马太福音', // Gospels
      '使徒行传', // Acts
      '罗马书', // Pauline
      '雅各书', // General
      '启示录', // Revelation
    ]);

    for (final id in [
      'divLaw',
      'divHistory',
      'divWisdom',
      'divMajorProphets',
      'divMinorProphets',
      'divGospels',
      'divActs',
      'divPauline',
      'divGeneralEpistles',
      'divRevelation',
    ]) {
      expect(find.text(label(id)), findsOneWidget, reason: id);
    }
  });

  testWidgets('a header names its division once, not once per book',
      (tester) async {
    await open(tester, const ['创世纪', '出埃及记', '利未记', '民数记']);
    expect(find.text(label('divLaw')), findsOneWidget);
  });

  testWidgets('a header cannot be chosen', (tester) async {
    // A menu row that closes the menu and changes nothing is a trap.
    await open(tester, const ['创世纪', '马太福音']);
    final header = tester.widget<PopupMenuItem<String>>(
      find
          .ancestor(
            of: find.text(label('divLaw')),
            matching: find.byType(PopupMenuItem<String>),
          )
          .first,
    );
    expect(header.enabled, isFalse);
  });

  testWidgets('every book is still in the menu, divisions or not',
      (tester) async {
    // An edition with a title the table does not know keeps its place
    // and simply carries no header. A menu that loses a book is worse
    // than an undivided one.
    await open(tester, const ['创世纪', '次经某书', '马太福音']);
    expect(find.text('次经某书'), findsOneWidget);
    expect(find.text('创世纪'), findsWidgets);
    expect(find.text('马太福音'), findsOneWidget);
  });

  // ── The shape, not just the content ──────────────────────────────
  //
  // 2026-09-14: 「这个sword很难看的 能不能就清晰两竖行新约旧约分开」. The
  // division headers added the day before were the right information in
  // a shape you still had to scroll 1,300px to read. Everything below
  // pins the TWO-COLUMN layout, because the four tests above all passed
  // while the menu was one tall list and would pass again if it went
  // back to being one.
  group('two standing columns, not one tall list', () {
    /// Left edge of the row that prints [book], in the menu overlay.
    double left(WidgetTester tester, String book) =>
        tester.getTopLeft(find.text(book).last).dx;

    testWidgets('the Greek column stands to the right of the Hebrew one',
        (tester) async {
      await open(tester, const ['创世纪', '诗篇', '马太福音', '启示录']);
      // Within a column, books share an x; across columns they do not.
      expect(left(tester, '诗篇'), left(tester, '创世纪'));
      expect(left(tester, '启示录'), left(tester, '马太福音'));
      expect(left(tester, '马太福音'), greaterThan(left(tester, '创世纪')));
    });

    testWidgets('each column is headed by the corpus it holds',
        (tester) async {
      await open(tester, const ['创世纪', '马太福音']);
      // 希伯来 / 希腊, not 旧约 / 新约 — the #280 ruling, which is
      // terminological and not per-screen.
      expect(find.text(label('oldTestamentShort')), findsOneWidget);
      expect(find.text(label('newTestamentShort')), findsOneWidget);
      expect(left(tester, label('newTestamentShort')),
          greaterThan(left(tester, label('oldTestamentShort'))));
    });

    testWidgets('an NT-only edition gets ONE column, not one empty one',
        (tester) async {
      // 梁家铿译本 is the real case. A two-column menu with an empty
      // column is worse than a single column.
      await open(tester, const ['马太福音', '罗马书', '启示录']);
      expect(find.text(label('oldTestamentShort')), findsNothing);
      expect(find.text(label('newTestamentShort')), findsOneWidget);
      expect(left(tester, '罗马书'), left(tester, '马太福音'));
    });

    testWidgets('a book row is a 24px target and reports the book it prints',
        (tester) async {
      // WCAG 2.5.8 is 24×24, and the old rows were 22px — which also
      // made them easy to mis-click in a list this dense.
      String? picked;
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ChangeNotifierProvider<AppSettings>.value(
        value: AppSettings(),
        child: MaterialApp(
          home: Scaffold(
            body: BrowseNavStrip(
              corpus: corpus(const ['创世纪', '诗篇', '马太福音']),
              version: 'kjv',
              localBook: '创世纪',
              chapter: 1,
              verse: 1,
              bookLabel: (b) => b,
              locale: locale,
              onVersion: (_) {},
              onBook: (b) => picked = b,
              onChapter: (_) {},
              onVerse: (_) {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('创世纪').first);
      await tester.pumpAndSettle();

      expect(tester.getSize(find.text('马太福音').last).height, lessThan(24));
      final row = find
          .ancestor(
              of: find.text('马太福音').last, matching: find.byType(InkWell))
          .first;
      expect(tester.getSize(row).height, greaterThanOrEqualTo(24));

      await tester.tap(find.text('马太福音').last);
      await tester.pumpAndSettle();
      expect(picked, '马太福音');
    });
  });
}
