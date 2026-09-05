/// The Modern Concordance as a Resource, mounted against the real
/// bundled assets.
///
/// `concordance_browse_test.dart` pins the matching logic and
/// `modern_concordance_test.dart` pins the data. Neither can tell you
/// the page reaches the screen — and until this iteration the browse
/// side had never been built once, because
/// `ModernConcordanceService.topics()` had no caller in `lib/` at all.
///
/// Asserted in CHINESE by default on purpose. `AppSettings` defaults to
/// `zh-Hans`, so that is what a default reader sees, and it is the
/// locale whose defects survive a green suite — every string on this
/// page was written this iteration and an English-only assertion would
/// never touch the Chinese ones.
///
/// The claim that most needs an instrument is the third test. The
/// verse-entered path in `analysis_tabs.dart` deliberately narrows a
/// topic to the ONE Greek word that cited the reader's verse; the whole
/// argument for this page is that the other words become reachable.
/// That is a difference no unit test can see, because both paths call
/// the same `sections()`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/pages/modern_concordance_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/modern_concordance_service.dart';

/// Abomination / 亵渎 — topic 1, one section, four entries across three
/// Strong's numbers (G946 twice, G947, G948). The smallest shape in the
/// work and the one the Topics tab filters hardest: a reader arriving
/// from Matthew 24:15 sees only the G946 rows.
const int kAbominationTopicId = 1;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `testWidgets` runs in a fake-async zone where a Future waiting on
  // real disk I/O never completes, so the page would sit on its
  // spinner forever. Warm the static caches here; afterwards the
  // page's awaits resolve as microtasks that `pumpAndSettle` drives.
  setUpAll(() async {
    await ModernConcordanceService.topics();
    await ModernConcordanceService.sections(kAbominationTopicId);
    // Every transliteration the topic asks for, so the per-entry
    // lookups inside `_open` are cache hits too.
    for (final s in await ModernConcordanceService.sections(
        kAbominationTopicId)) {
      for (final e in s.entries) {
        await ModernConcordanceService.transliteration(e.strongs);
      }
    }
  });

  Widget host({int? topicId}) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppSettings()),
          ChangeNotifierProvider(create: (_) => MainProvider()),
        ],
        child: MaterialApp(
          home: ModernConcordancePage(initialTopicId: topicId),
        ),
      );

  /// The same page in English. Worth building only for the counts:
  /// Chinese has no singular, so a zh assertion cannot see a plural
  /// defect.
  ///
  /// `setLocale` arms `AppSettings`' 600 ms user-prefs write debounce,
  /// which outlives `pumpAndSettle` — that only runs the clock while
  /// frames are scheduled — and would then fail the test on a pending
  /// timer.
  Future<void> pumpEnglish(WidgetTester t, {int? topicId}) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    await settings.setLocale('en');
    await t.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettings>.value(value: settings),
        ChangeNotifierProvider(create: (_) => MainProvider()),
      ],
      child: MaterialApp(
        home: ModernConcordancePage(initialTopicId: topicId),
      ),
    ));
    await t.pumpAndSettle();
    await t.pump(const Duration(milliseconds: 700));
  }

  testWidgets('the index opens on the whole work and names its size',
      (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();

    expect(find.text('341 个主题'), findsOneWidget);
    // Sorted by English name, so Abomination leads; a zh-Hans reader
    // sees its Chinese gloss.
    expect(find.text('亵渎'), findsOneWidget);
    // The permission this data ships under is conditional on the credit.
    expect(find.textContaining('Modern Concordance'), findsWidgets);
  });

  testWidgets('an English query reaches a Chinese reader, and says why',
      (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();

    // The case Nave's whole-headword rule answers with nothing: `seize`
    // is the middle segment of a compound name. 239 of the 341 names
    // are compounds.
    await t.enterText(find.byType(TextField), 'seize');
    await t.pumpAndSettle();

    expect(find.text('1 个主题匹配'), findsOneWidget);
    // The row is labelled in the reader's language...
    expect(find.text('捕 - 抓 - 偷'), findsOneWidget);
    // ...and carries the English name, because English is what matched
    // and the row is otherwise unexplainable.
    expect(find.text('Catch - Seize - Steal'), findsOneWidget);
  });

  testWidgets('a topic opens unfiltered — the words the verse path hides',
      (t) async {
    await t.pumpWidget(host(topicId: kAbominationTopicId));
    await t.pumpAndSettle();

    expect(find.text('亵渎'), findsOneWidget);
    expect(find.text('1 组希腊原文词'), findsOneWidget);
    expect(find.text('亵渎：BDELUGMA'), findsOneWidget);

    // G946 is the word that cites Matthew 24:15, and the only one the
    // Topics tab shows a reader arriving from that verse. The other two
    // are the reason this page exists.
    expect(find.text('BDELUGMA'), findsWidgets);
    expect(find.text('G947'), findsOneWidget);
    expect(find.text('BDELUKTOS'), findsOneWidget);
    expect(find.text('G948'), findsOneWidget);
    expect(find.text('BDELUSSO'), findsOneWidget);
  });

  testWidgets('a word the concordance does not carry gets a sentence',
      (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField), 'photosynthesis');
    await t.pumpAndSettle();

    expect(find.text('0 个主题匹配'), findsOneWidget);
    expect(find.textContaining('没有名为'), findsOneWidget);
  });

  // Guards the three tests above against passing on an empty bundle.
  // An index that failed to load and an index with nothing in it both
  // render "0 topics" and an empty list; only a real hit out of the
  // real file separates them. `assets/concordance/` reaching
  // `pubspec.yaml` is exactly the kind of omission that has gone
  // unnoticed here before.
  testWidgets('the page is reading the bundled index, not an empty one',
      (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();

    // A single Chinese character that is NOT the whole row label: the
    // search field renders the query too, so querying '亵渎' would find
    // the same string twice and prove nothing about the list.
    await t.enterText(find.byType(TextField), '阴间');
    await t.pumpAndSettle();

    expect(find.text('1 个主题匹配'), findsOneWidget);
    expect(find.text('无底坑 - 阴间 - 地狱'), findsOneWidget);
  });

  testWidgets('English counts have a singular form', (t) async {
    await pumpEnglish(t);

    await t.enterText(find.byType(TextField), 'seize');
    await t.pumpAndSettle();

    expect(find.text('1 topic matches'), findsOneWidget);
    expect(find.text('Catch - Seize - Steal'), findsOneWidget);
  });

  testWidgets('a one-section topic does not say "1 sections"', (t) async {
    await pumpEnglish(t, topicId: kAbominationTopicId);

    expect(find.text('1 section'), findsOneWidget);
  });
}
