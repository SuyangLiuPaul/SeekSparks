import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/models/app_settings.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/widgets/browse_nav_strip.dart';

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
}
