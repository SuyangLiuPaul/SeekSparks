/// Nave's as a Resource, mounted against the real bundled assets.
///
/// `naves_browse_test.dart` pins the logic and `naves_test.dart` pins the
/// data. Neither can tell you the page reaches the screen — and this one
/// had never been built even once before these tests existed.
///
/// The three claims worth asserting are the three the page was shaped
/// around: the whole index is reachable, the 801-line entry arrives
/// collapsed rather than as a wall, and a word Nave does not use gets a
/// sentence instead of a blank list.
///
/// Asserted in CHINESE on purpose. `AppSettings` defaults to `zh-Hans`,
/// so that is what a default reader sees, and it is the locale whose
/// defects survive a green suite — the page's strings were all written
/// this iteration and an English-only assertion would never touch them.
/// The headwords and line text stay English because Nave's is an
/// English work; only the chrome is translated.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/pages/naves_page.dart';
import 'package:seeksparks/services/naves_service.dart';

/// JESUS, THE CHRIST — 801 lines, 3,828 references, the largest entry in
/// the work and the reason the outline collapses at all.
const int kJesusTopicId = 2779;

/// ABADDON — one line, one reference. The commonest shape in the work:
/// 2,413 of the 5,322 topics are a single line and 1,153 of those cite a
/// single verse, so this entry's header is the one an English reader
/// sees most often.
const int kAbaddonTopicId = 1;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `testWidgets` runs in a fake-async zone where a Future waiting on
  // real disk I/O never completes, so the page would sit on its spinner.
  // Warm the static caches here; afterwards the page's awaits resolve as
  // microtasks that `pumpAndSettle` can drive.
  setUpAll(() async {
    await NavesService.heads();
    await NavesService.topic(kJesusTopicId);
    await NavesService.topic(kAbaddonTopicId);
    await NavesService.lineTexts();
  });

  Widget host({int? topicId}) => ChangeNotifierProvider(
        create: (_) => AppSettings(),
        child: MaterialApp(
          home: NavesPage(initialTopicId: topicId),
        ),
      );

  /// The same page in English. Only worth building for the counts:
  /// Chinese has no singular, so a zh assertion cannot see a plural
  /// defect and the shipped build read "1 lines · 1 references".
  ///
  /// `setLocale` arms `AppSettings`' 600 ms user-prefs write debounce,
  /// which outlives `pumpAndSettle` — that only runs the clock while
  /// frames are scheduled — and then fails the test on a pending timer.
  Future<void> pumpEnglish(WidgetTester t, {int? topicId}) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings();
    await settings.setLocale('en');
    await t.pumpWidget(ChangeNotifierProvider.value(
      value: settings,
      child: MaterialApp(home: NavesPage(initialTopicId: topicId)),
    ));
    await t.pumpAndSettle();
    await t.pump(const Duration(milliseconds: 700));
  }

  testWidgets('the index opens on the whole work and names its size',
      (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();

    expect(find.text('5322 个主题'), findsOneWidget);
    expect(find.text('AARON'), findsOneWidget);
  });

  testWidgets('a headword search says what it counted', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField), 'love');
    await t.pumpAndSettle();

    // LOVE, LOVEFEASTS, LOVERS. The header names the tier — these are
    // topics NAMED for the word, not topics that mention it.
    expect(find.text('3 个主题以此为名'), findsOneWidget);
    expect(find.text('LOVE'), findsOneWidget);
  });

  testWidgets('a word Nave never uses gets a sentence, not a blank list',
      (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();

    // Zero headwords AND zero lines. The entry-text tier arms itself
    // because the headwords came back empty, finds nothing either, and
    // the page has to say so — an empty list would read as broken.
    await t.enterText(find.byType(TextField), 'depression');
    await t.pumpAndSettle();

    expect(find.text('0 行条目正文提到它'), findsOneWidget);
    expect(find.textContaining('内夫没有以'), findsOneWidget);
  });

  // The test above would pass just as happily if `lines.json` were not
  // in the bundle at all — an unloaded index and an index with nothing
  // in it both total zero. This one cannot: it needs a real hit out of
  // the real file. `assets/nave/` reached pubspec only in c99b54f, after
  // CI went red twice on exactly that omission.
  testWidgets('the entry-text tier is reading the bundled file',
      (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();

    // Zero headwords, one line — and it is SIDON living without a
    // worry, which is its own argument for showing the reader the line
    // rather than just a topic name.
    await t.enterText(find.byType(TextField), 'worry');
    await t.pumpAndSettle();

    expect(find.text('1 行条目正文提到它'), findsOneWidget);
    expect(find.text('SIDON'), findsOneWidget);
    expect(
      find.text('Inhabitants of, lived in security and without a worry'),
      findsOneWidget,
    );
  });

  testWidgets('the 801-line entry arrives collapsed, not as a wall',
      (t) async {
    await t.pumpWidget(host(topicId: kJesusTopicId));
    await t.pumpAndSettle();

    expect(find.text('JESUS, THE CHRIST'), findsOneWidget);
    // The header states the true size even though the outline is
    // showing 87 rows of it.
    expect(find.text('801 行 · 3828 处经文'), findsOneWidget);
    // A depth-1 line is on screen; the line hanging beneath it is not.
    expect(find.text('HISTORY OF'), findsOneWidget);
    expect(find.text('Genealogy of'), findsNothing);
  });

  testWidgets('expanding a line reveals what the count promised',
      (t) async {
    await t.pumpWidget(host(topicId: kJesusTopicId));
    await t.pumpAndSettle();

    // Targeted at the row rather than by icon: the history trail's
    // forward step is also a `chevron_right`, and `.first` finds that
    // one instead of the outline's expander.
    final row = find
        .ancestor(of: find.text('HISTORY OF'), matching: find.byType(Row))
        .first;
    await t.tap(find.descendant(of: row, matching: find.byIcon(Icons.chevron_right)));
    await t.pumpAndSettle();

    expect(find.text('Genealogy of'), findsOneWidget);
  });

  // Found by looking at the deployed page rather than by a number: the
  // English header read "1 topics named" / "1 lines · 1 references".
  // Chinese has no singular, so every zh assertion above stayed green
  // through it.
  testWidgets('English counts have a singular form', (t) async {
    await pumpEnglish(t, topicId: kAbaddonTopicId);

    expect(find.text('1 line · 1 reference'), findsOneWidget);
  });

  testWidgets('a single headword hit is "1 topic", not "1 topics"',
      (t) async {
    await pumpEnglish(t);

    // ABADDON is the only headword beginning with these letters.
    await t.enterText(find.byType(TextField), 'abaddon');
    await t.pumpAndSettle();

    expect(find.text('1 topic named'), findsOneWidget);
  });

  testWidgets('a single entry-text hit agrees with its verb', (t) async {
    await pumpEnglish(t);

    await t.enterText(find.byType(TextField), 'worry');
    await t.pumpAndSettle();

    expect(find.text('1 line mentions it'), findsOneWidget);
  });
}
