/// The teachings page, and the promises its dataset makes.
///
/// 2026-09-16. Three of these are about HONESTY rather than about
/// rendering, because that is where this feature can go wrong quietly:
/// a page that silently upgraded a cross-reference into a claim of
/// dependence would look exactly like one that did not.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/pages/jesus_teachings_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/jesus_teachings_service.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/reference_parser.dart' show parseReference;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late JesusTeachingsData data;

  setUpAll(() async {
    data = await JesusTeachingsService.instance.load();
    await (FontLoader('Roboto')
          ..addFont(rootBundle
              .load('assets/fonts/Roboto-VariableFont_wdth,wght.ttf')))
        .load();
  });

  test('every reference the page prints can actually be opened', () {
    // The page turns each of these into a tap that calls
    // `parseReference`. One that does not parse is a dead chip, and
    // there are thousands of them — a spot check would miss it.
    var checked = 0;
    for (final t in data.teachings) {
      for (final raw in [
        for (final r in t.refs) r.label,
        ...t.oldTestament,
        for (final a in t.apostles) a.ref,
      ]) {
        expect(parseReference(raw), isNotNull,
            reason: '${t.id}: "$raw" does not parse, so its chip is dead');
        checked++;
      }
    }
    expect(checked, greaterThan(1000),
        reason: 'only $checked references were checked — the dataset is '
            'not carrying what this test assumes');
  });

  test('a teaching never reaches outside the gospels', () {
    // The defect this caught while the generator was being written:
    // Nave's outline lines carry the PARALLEL references for one
    // teaching, and a merge that took them wholesale gave the parable
    // of the lost sheep a claim on Mark 15 — the crucifixion.
    const gospels = {'Matthew', 'Mark', 'Luke', 'John'};
    for (final t in data.teachings) {
      for (final r in t.refs) {
        expect(gospels, contains(r.book),
            reason: '${t.id} cites ${r.label}, which is not a gospel');
      }
    }
  });

  test('only the apostles\' own claims are marked as the Lord\'s word', () {
    // The whole honesty argument, as an assertion. A cross-reference
    // says two passages are related; it does not say one rests on the
    // other. The only links allowed to carry a claim of dependence are
    // the ones where an apostle says so himself.
    const declared = {
      '1 Corinthians 7:10', '1 Corinthians 7:11', '1 Corinthians 9:14',
      '1 Corinthians 11:23', '1 Corinthians 11:24', '1 Corinthians 11:25',
      '1 Thessalonians 4:15', 'Acts 20:35',
    };
    var marked = 0;
    for (final t in data.teachings) {
      for (final a in t.apostles) {
        if (a.lordsWord == null) continue;
        marked++;
        expect(declared, contains(a.ref.split('-').first.trim()),
            reason: '${t.id}: ${a.ref} is marked as the Lord\'s own word, '
                'and the New Testament does not say that of it');
      }
    }
    expect(marked, greaterThan(0),
        reason: 'nothing is marked, so this test is passing vacuously — '
            'the teachings the apostles cite by name are missing from '
            'the spine');
  });

  test('every entry has a Chinese title', () {
    // 「这些也没用根据语言翻译好」. Nave's outline is English in this
    // dataset, so 27 of the 87 showed an English sentence to a Chinese
    // reader. 16 take the app's own section heading, which is already
    // trilingual; the remaining 11 are translated in the generator and
    // kept literal, because translating a heading is localisation and
    // the passage it names is printed beside it.
    for (final t in data.teachings) {
      expect(RegExp(r'[\u4e00-\u9fff]').hasMatch(t.titleFor('zh-Hans')),
          isTrue,
          reason: '${t.id} shows "${t.titleFor('zh-Hans')}" in a Chinese UI');
      expect(RegExp(r'[\u4e00-\u9fff]').hasMatch(t.titleFor('zh-Hant')),
          isTrue, reason: '${t.id} has no traditional title');
    }
  });

  test('a plate chip shows a name, not a filename', () {
    // The first build printed `illus_tissot_healing_of_the_lepers_at_
    // capernaum` at the reader — an asset id wearing a chip.
    for (final t in data.teachings) {
      for (final p in t.plates) {
        expect(p.titleFor('zh-Hans'), isNot(p.id));
        expect(p.titleFor('zh-Hans'), isNotEmpty);
      }
    }
  });

  test('parallel passages are one teaching, not three', () {
    // 「有平行经文的也要放在一起」. Nave lists the synoptic parallels of a
    // teaching on one line, so the sower is Mt 13, Mk 4 and Lk 8 — one
    // entry carrying three references rather than three entries.
    final multi = data.teachings
        .where((t) => t.refs.map((r) => r.book).toSet().length > 1)
        .toList();
    expect(multi.length, greaterThan(10),
        reason: 'only ${multi.length} teachings carry parallels');
    // The parable, not the discourse that contains it: Matthew 13:1-52
    // is 天国的比喻 as a whole and also begins at 13:1.
    final sower = data.teachings.firstWhere((t) =>
        t.kind == 'parable' &&
        t.refs.any((r) =>
            r.book == 'Matthew' && r.chapter == 13 && r.start == 1));
    expect(sower.refs.map((r) => r.book).toSet(),
        containsAll(<String>{'Matthew', 'Mark', 'Luke'}),
        reason: 'the sower lost its parallels: ${sower.label}');
  });

  test('the discourses contain their parts, and nothing contains itself', () {
    final byId = {for (final t in data.teachings) t.id: t};
    var nested = 0;
    for (final t in data.teachings) {
      final parent = t.partOf;
      if (parent == null) continue;
      nested++;
      expect(byId[parent], isNotNull, reason: '${t.id} points at a missing '
          'discourse $parent');
      expect(byId[parent]!.isDiscourse, isTrue,
          reason: '${t.id} is filed under $parent, which is not a discourse');
      expect(parent, isNot(t.id));
    }
    expect(nested, greaterThan(10),
        reason: 'only $nested teachings are nested; the Beatitudes alone '
            'should account for more');
  });

  testWidgets('the page says the arrangement is its own', (tester) async {
    // An editorial list that will not admit to being editorial is the
    // thing to avoid here. The claim comes out of the dataset rather
    // than being retyped in the UI, so this also pins that the two
    // cannot drift apart.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1200);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MainProvider()),
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child: MaterialApp(
        theme: ThemeData(
            fontFamily: 'Roboto', fontFamilyFallback: kCjkFontFallback),
        home: const JesusTeachingsPage(),
      ),
    ));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('jesusTeachingsList')), findsOneWidget);
    expect(find.textContaining('从主领受的'), findsOneWidget,
        reason: 'the preface, which is where the conviction lives');
    expect(find.textContaining('RELATED'), findsOneWidget,
        reason: 'the page must state what a cross-reference does and does '
            'not claim');

    // 「类似于比喻可以放在一起」 — the parables in one tap, and still in
    // the order the gospels put them.
    await tester.tap(find.byKey(const ValueKey('teachingKind-parable')));
    await tester.pumpAndSettle();
    final parables = data.teachings.where((t) => t.kind == 'parable');
    expect(parables.length, greaterThan(20),
        reason: 'only ${parables.length} parables were classified; the '
            'sermon corpus alone has 34 on them');
    expect(find.text(parables.first.titleFor('zh-Hans')), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('teachingKind-all')));
    await tester.pumpAndSettle();

    // And a teaching opens.
    final first = data.topLevel.first;
    await tester.tap(find.byKey(ValueKey('teaching-${first.id}')));
    await tester.pumpAndSettle();
    expect(find.text(first.refs.first.label), findsWidgets);
  });
}
