/// The AOSurvey credit under the Greek statistics.
///
/// Five reference sets came in from Eagle's View. Four of them —
/// Thayer, Hitchcock's names, the gazetteer, the Modern Concordance —
/// render `Service.attribution` in the pane that shows their data. The
/// fifth, the Greek New Testament corpus statistics, put its numbers on
/// screen from `34bef43` (2026-08-07) with no credit anywhere, and it is
/// the ONE of the five that is not public domain: the database states
/// "© 2007 AOSurvey Co., Ltd." and ships under permission the ministry
/// was granted. The About page credits the three Eagle's View text
/// editions and none of the reference sets, so the in-pane line is the
/// only place the statement can appear.
///
/// The mechanism is worth stating because it is invisible from a call
/// site: `GreekStatsService` fills `_attribution` inside `books()`,
/// which reads `index.json`. The Stats pane only ever called
/// `lookup()`, which reads a per-thousand bucket file and never touches
/// `index.json` — so `attribution` was not merely unread, it was the
/// empty string. Both halves are pinned below, because fixing only the
/// render would have shipped a blank line.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/original_word.dart';
import 'package:seeksparks/services/greek_stats_service.dart';
import 'package:seeksparks/services/concordance_service.dart';
import 'package:seeksparks/services/strongs_service.dart';
import 'package:seeksparks/widgets/analysis_tabs.dart';

/// ἀγάπη — a Greek word the corpus profile certainly carries.
const String kAgape = 'G26';

/// שָׁמַיִם — Hebrew, so the Westcott-Hort profile is silent about it and
/// is right to be.
const String kShamayim = 'H8064';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Warm every static cache the pane awaits: `testWidgets` runs in a
    // fake-async zone where real disk I/O never completes.
    await GreekStatsService.books();
    await GreekStatsService.lookup(kAgape);
    await ConcordanceService.lookup(kAgape);
    await ConcordanceService.lookup(kShamayim);
    await StrongsService.lookup(kAgape);
    await StrongsService.lookup(kShamayim);
  });

  group('the asset carries the statement', () {
    test('index.json names AOSurvey, and books() is what loads it', () async {
      final books = await GreekStatsService.books();
      expect(books.length, 27,
          reason: 'the 27-book profile is what index.json is for');
      expect(GreekStatsService.attribution, isNotEmpty);
      expect(GreekStatsService.attribution, contains('AOSurvey'));
      expect(GreekStatsService.attribution, contains("Eagle's View"));
    });

    // The trap itself, stated from a cold cache. `lookup()` reads a
    // per-thousand bucket and never opens `index.json`, so a pane that
    // called only `lookup()` read the empty string — not a missing
    // credit it could notice, an empty one it could not.
    test('lookup() alone leaves the attribution empty', () async {
      GreekStatsService.resetForTest();
      final hit = await GreekStatsService.lookup(kAgape);
      expect(hit, isNotNull, reason: 'the bucket did load');
      expect(GreekStatsService.attribution, isEmpty);

      await GreekStatsService.books();
      expect(GreekStatsService.attribution, contains('AOSurvey'));
    });
  });

  // A source assertion, and it has to be one. The widget tests below
  // cannot see this: `GreekStatsService`'s caches are static and
  // process-wide, so once ANY test in the file has called `books()` the
  // attribution is populated for every later pump — the pane renders
  // the credit whether or not it loaded the index itself. Removing the
  // await from the pane was tried and every widget test stayed green.
  // Warming the caches cannot be dropped either: `testWidgets` runs in
  // a fake-async zone where real bundle I/O does not complete.
  //
  // So the load is pinned where it is visible — in the source of the
  // one method that has to do it.
  test('the Stats pane load path opens index.json, not only a bucket', () {
    final src = File('lib/widgets/analysis_tabs.dart').readAsStringSync();
    const signature = 'Future<List<_StatRow>> _load() async {';
    final start = src.indexOf(signature);
    expect(start, isNot(-1),
        reason: 'the Stats pane loader was renamed — move this assertion '
            'with it rather than deleting it');
    final body = src.substring(start, src.indexOf('\n  }', start));
    expect(body, contains('GreekStatsService.books()'),
        reason: 'the pane must load index.json for its attribution; '
            'lookup() alone leaves GreekStatsService.attribution empty '
            'and the AOSurvey credit silently disappears');
  });

  group('the pane shows it', () {
    // `WbType.of` reads the reader's font size off `AppSettings`, so
    // the pane cannot be built without it.
    Widget host(List<OriginalWord> words) => ChangeNotifierProvider(
          create: (_) => AppSettings(),
          child: MaterialApp(
            home: Scaffold(
              body: WordStatsPane(
                words: words,
                locale: 'zh-Hans',
                onOpenStrongs: (_) {},
              ),
            ),
          ),
        );

    testWidgets('a Greek row carries the AOSurvey credit beneath it',
        (t) async {
      await t.pumpWidget(host(const [
        OriginalWord(text: 'ἀγάπη', strongs: kAgape),
      ]));
      await t.pumpAndSettle();

      expect(find.textContaining('AOSurvey'), findsOneWidget);
    });

    // The converse, and the reason the credit is conditional: the
    // Westcott-Hort profile answers nothing about a Hebrew word, and
    // crediting a source that did not answer is its own kind of wrong.
    testWidgets('a Hebrew-only verse is not credited to AOSurvey',
        (t) async {
      await t.pumpWidget(host(const [
        OriginalWord(text: 'שָׁמַיִם', strongs: kShamayim),
      ]));
      await t.pumpAndSettle();

      expect(find.textContaining('AOSurvey'), findsNothing);
    });
  });
}
