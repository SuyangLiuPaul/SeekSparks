// 2026-08-08 (task #283): the family tree's verse chips name their books
// the way the READING VERSION names them, not the way the UI locale does.
//
// The person sheet is the only place the family tree round-trips to the
// text, and it used to call `localeAwareBookName(book, locale)` with the
// version argument omitted. So a reader on 和合本繁 with a Simplified UI
// tapped 创世纪 1:26 and landed on a page headed 創世紀 — one book, two
// spellings, inside a single round-trip. The rest of the app (notes,
// highlights, evidence cards, search) already keys on the version.
//
// The chip is also the sheet's one link-coloured affordance, so this
// pins that too: if a later pass sprays `WbColors.link` over the section
// labels again, the reference stops being the thing that stands out.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/biblical_person.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/widgets/person_detail_sheet.dart';

const _adam = BiblicalPerson(
  id: 'adam',
  name: 'Adam',
  nameZhHans: '亚当',
  nameZhHant: '亞當',
  yearSystem: 'am',
  summary: 'The first man.',
  summaryZhHans: '第一个人。',
  refs: <String>['Genesis 1:26'],
);

Future<void> _pump(
  WidgetTester tester, {
  required String locale,
  required String version,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final mp = MainProvider();
          mp.currentVersion = version;
          return mp;
        }),
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child: MaterialApp(
        theme: workbenchTheme(ThemeData.light()),
        home: Scaffold(
          body: PersonDetailSheet(
            person: _adam,
            locale: locale,
            scrollController: ScrollController(),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('a Traditional version prints the Traditional book name '
      'even under a Simplified UI locale', (tester) async {
    await _pump(tester, locale: 'zh-Hans', version: 'cuv-tr');
    expect(find.text('創世紀 1:26'), findsOneWidget);
    expect(find.text('创世纪 1:26'), findsNothing);
  });

  testWidgets('an English version prints the English book name '
      'even under a Chinese UI locale', (tester) async {
    await _pump(tester, locale: 'zh-Hans', version: 'kjv');
    expect(find.text('Genesis 1:26'), findsOneWidget);
  });

  testWidgets('a Simplified version prints the Simplified book name',
      (tester) async {
    await _pump(tester, locale: 'en', version: 'cuvs-yhwh');
    expect(find.text('创世纪 1:26'), findsOneWidget);
  });

  testWidgets('the reference chip is the sheet\'s one link-coloured thing',
      (tester) async {
    await _pump(tester, locale: 'en', version: 'kjv');
    final wb = WbColors.light;

    final refLabel = tester.widget<Text>(find.text('Genesis 1:26'));
    expect(refLabel.style?.color, wb.link,
        reason: 'the verse reference is the affordance that leaves the '
            'family tree, so it wears the link hue');

    // "Verse references" is a heading, not a destination.
    final heading = tester.widget<Text>(find.text('Verse references'));
    expect(heading.style?.color, wb.mutedText);
  });
}
