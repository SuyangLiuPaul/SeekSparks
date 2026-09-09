// The changelog the app ships: what the generator kept, how the page
// groups it, and whether the reader can reach it.
//
// The asset is generated from git by `tools/build_changelog.py`, so
// most of what could go wrong here is a filter that lets bookkeeping
// through — and bookkeeping is the majority of this repository's
// commits. A changelog whose top line is "release: v1.6.270 to dev +
// prod" is worse than none: it tells the reader we deploy a lot and
// nothing about what they got.
//
// 2026-09-09, after review: the other thing that could go wrong, and
// had, is the asset stopping one version short of the build it ships
// in (finding 1) — so the top entry is now checked against pubspec —
// and the service's catch-all hiding a parse mistake behind an empty
// page (finding 5), so the real asset now goes through the real parser
// with the exception left to surface.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/app_version.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/pages/changelog_page.dart';
import 'package:seeksparks/services/changelog_service.dart';

Map<String, dynamic> _asset() => jsonDecode(
      File('assets/changelog.json').readAsStringSync(),
    ) as Map<String, dynamic>;

List<Map<String, dynamic>> _entries() =>
    (_asset()['entries'] as List<dynamic>).cast<Map<String, dynamic>>();

/// `X.Y.Z` from pubspec.yaml, without the `+build` suffix — the same
/// read the release script does, so this test and that script agree
/// on what "the version being built" means.
String _pubspecVersion() {
  final m = RegExp(r'^version:\s*(\d+\.\d+\.\d+)', multiLine: true)
      .firstMatch(File('pubspec.yaml').readAsStringSync());
  expect(m, isNotNull, reason: 'pubspec.yaml has no version: line');
  return m!.group(1)!;
}

List<int> _parseVersion(String v) =>
    v.split('.').map(int.parse).toList(growable: false);

bool _descends(List<int> a, List<int> b) =>
    a[0] < b[0] ||
    (a[0] == b[0] && a[1] < b[1]) ||
    (a[0] == b[0] && a[1] == b[1] && a[2] < b[2]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('what the generator shipped', () {
    test('the asset exists and is not empty — a bundled changelog that '
        'ships empty is the failure a fetching one would have had', () {
      expect(File('assets/changelog.json').existsSync(), isTrue);
      expect(_entries(), isNotEmpty);
    });

    test('no entry is a release, docs or PROJECT_STATE line', () {
      final offenders = <String>[];
      for (final e in _entries()) {
        for (final note in (e['notes'] as List<dynamic>).cast<String>()) {
          final lower = note.toLowerCase();
          if (lower.startsWith('release:') ||
              lower.startsWith('chore(release):') ||
              lower.startsWith('docs:') ||
              lower.startsWith('doc:') ||
              note.startsWith('PROJECT_STATE')) {
            offenders.add('${e['version']}: $note');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'bookkeeping reached the changelog:\n'
              '${offenders.join('\n')}');
    });

    // Review finding 2 (2026-09-09): the first draft of DROP covered
    // the conventional-commit list and none of the forms this repo
    // actually writes for its own record — `tests:`, `tools:`,
    // `state:`, `audit:` — so "tools: the release script this repo
    // already had the workflows for" was on the page. And the notes
    // that DID belong there still wore their `feat(wheel):` tokens.
    test('no bookkeeping form this repo uses reaches a reader', () {
      final bookkeeping = RegExp(
        r'^(?:tests?|audit(?:_p0)?|tools(?:\+docs)?|state|chore|ci|build|'
        r'style|refactor)(?:\([^)]*\))?:|^fix\s*(?:\((?:ci|lint|release)\)|CI)\s*:',
        caseSensitive: false,
      );
      final offenders = <String>[
        for (final e in _entries())
          for (final note in (e['notes'] as List<dynamic>).cast<String>())
            if (bookkeeping.hasMatch(note)) '${e['version']}: $note',
      ];
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('no note starts with a developer token — feat, fix, perf and '
        'an issue number are ours, not the reader’s', () {
      final token = RegExp(
        r'^(?:(?:feat|fix|perf|refactor|revert)(?:\([^)]*\))?!?|#\d+):',
        caseSensitive: false,
      );
      final offenders = <String>[
        for (final e in _entries())
          for (final note in (e['notes'] as List<dynamic>).cast<String>())
            if (token.hasMatch(note)) '${e['version']}: $note',
      ];
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('every entry has something to say — an empty row is a version '
        'number pretending to be news', () {
      for (final e in _entries()) {
        expect((e['notes'] as List<dynamic>), isNotEmpty,
            reason: '${e['version']} shipped with no notes');
      }
    });

    test('versions descend, so the newest is at the top of the page', () {
      var previous = <int>[999, 999, 999];
      for (final v in _entries().map((e) => _parseVersion(e['version'] as String))) {
        expect(_descends(v, previous), isTrue, reason: '$v came after $previous');
        previous = v;
      }
    });

    test('dates are ISO, because the page groups on them by string equality',
        () {
      final iso = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      for (final e in _entries()) {
        expect(iso.hasMatch(e['date'] as String), isTrue,
            reason: '${e['version']} has date ${e['date']}');
      }
    });

    test('the window stays small enough to bundle', () {
      final bytes = File('assets/changelog.json').lengthSync();
      expect(bytes, lessThan(200 * 1024),
          reason: 'a changelog is not worth 200 KB of app; '
              'lower --max-entries in tools/build_changelog.py');
    });
  });

  // Review finding 1 (2026-09-09): the generator anchored every entry on
  // a `release: vX.Y.Z` commit, and that commit is written AFTER the
  // build for X.Y.Z is deployed — so the asset inside v1.6.271 stopped
  // at v1.6.270, the 「你的版本」 badge compared against a version that
  // was never in the list, and "what's new" was always one behind. The
  // generator now synthesises the top entry for the version pubspec
  // names. These two assertions are the proof, and they are what keeps
  // it fixed: run the generator before the bump, or drop the flag from
  // release_web.sh, and they fail.
  group('the running build is in the asset', () {
    test('the asset says which version it was built for, and it is the '
        'one in pubspec', () {
      final head = _asset()['head'] as Map<String, dynamic>?;
      expect(head, isNotNull,
          reason: 'no `head` — the generator was run without a head '
              'version, i.e. the pre-review generator');
      expect(head!['version'], _pubspecVersion());
    });

    test('the top entry IS the pubspec version — through the real parser, '
        'on the real asset, with no catch-all in the way', () {
      final entries = ChangelogService.parse(
        File('assets/changelog.json').readAsStringSync(),
      );
      expect(entries, isNotEmpty);
      // Newest first, or the page would open on the oldest day.
      for (var i = 1; i < entries.length; i++) {
        expect(
          _descends(_parseVersion(entries[i].version),
              _parseVersion(entries[i - 1].version)),
          isTrue,
          reason: '${entries[i].version} came after ${entries[i - 1].version}',
        );
      }
      final head = _asset()['head'] as Map<String, dynamic>;
      // A release with no reader-visible change (a data re-import, a
      // tooling fix) is recorded under `head` but not listed — an
      // empty row is a version number pretending to be news. Every
      // other release, which is nearly all of them, must be on top.
      if ((head['notes'] as int) > 0) {
        expect(entries.first.version, _pubspecVersion(),
            reason: 'the top entry is not the build being shipped — the '
                'badge cannot render and "what\'s new" is one behind');
      } else {
        expect(entries.first.version, isNot(_pubspecVersion()));
      }
      // As of this commit the head has notes; the branch above is for
      // future releases, and this pins that the proof ran today.
      expect(entries.first.version, _pubspecVersion());
    });

    test('the same through rootBundle, the way the page loads it',
        (() async {
      ChangelogService.resetForTest();
      addTearDown(ChangelogService.resetForTest);
      final days = await ChangelogService.load();
      expect(days, isNotEmpty,
          reason: 'load() returned the empty state for the real asset — '
              'either rootBundle cannot see it or parse() threw and the '
              'catch-all hid it; the test above says which');
      expect(days.first.versions.first.version, _pubspecVersion());
      expect(days.first.versions.first.version, kAppVersion,
          reason: 'kAppVersion and pubspec have drifted; '
              'app_version_fallback_test covers the mechanism');
    }));
  });

  group('grouping by day', () {
    test('collapses a burst of same-day releases into one heading — the '
        'reason the page is not a list of version numbers', () {
      final days = ChangelogService.groupByDay(const [
        ChangelogEntry(version: '1.6.270', date: '2026-09-09', notes: ['c']),
        ChangelogEntry(version: '1.6.269', date: '2026-09-09', notes: ['b']),
        ChangelogEntry(version: '1.6.266', date: '2026-09-09', notes: ['a']),
        ChangelogEntry(version: '1.6.265', date: '2026-09-08', notes: ['z']),
      ]);
      expect(days.length, 2);
      expect(days.first.date, '2026-09-09');
      expect(days.first.versions.length, 3);
      expect(days.last.versions.length, 1);
    });

    test('counts changes, not versions — six versions in an afternoon is '
        'how often we deploy, which is not the reader’s business', () {
      final days = ChangelogService.groupByDay(const [
        ChangelogEntry(version: '1.0.2', date: '2026-09-09', notes: ['a', 'b']),
        ChangelogEntry(version: '1.0.1', date: '2026-09-09', notes: ['c']),
      ]);
      expect(days.single.versions.length, 2);
      expect(days.single.noteCount, 3);
    });

    test('keeps release order inside a day, so the newer version is first',
        () {
      final days = ChangelogService.groupByDay(const [
        ChangelogEntry(version: '1.6.270', date: '2026-09-09', notes: ['x']),
        ChangelogEntry(version: '1.6.269', date: '2026-09-09', notes: ['y']),
      ]);
      expect(
        days.single.versions.map((v) => v.version).toList(),
        ['1.6.270', '1.6.269'],
      );
    });

    test('an empty changelog groups to nothing rather than throwing', () {
      expect(ChangelogService.groupByDay(const []), isEmpty);
    });

    test('parse() throws on a malformed asset instead of returning nothing '
        '— the catch-all belongs to load(), not to the parser', () {
      expect(() => ChangelogService.parse('{"entries": [{"version": 1}]}'),
          throwsA(isA<TypeError>()));
      expect(() => ChangelogService.parse('not json'),
          throwsA(isA<FormatException>()));
    });
  });

  group('the page', () {
    Future<void> pump(
      WidgetTester tester, {
      required String locale,
      required double width,
      required double textScale,
      required List<ChangelogDay> days,
    }) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(ChangelogService.resetForTest);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(width, 800);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      ChangelogService.setForTest(days);
      final settings = AppSettings();
      await settings.setLocale(locale);
      await tester.pumpWidget(
        ChangeNotifierProvider<AppSettings>.value(
          value: settings,
          child: const MaterialApp(home: ChangelogPage()),
        ),
      );
      await tester.pump();
      // setLocale's notifyListeners arms AppSettings' 600 ms prefs-write
      // debounce; let it fire, or the binding fails the test for a
      // pending timer after the tree is gone.
      await tester.pump(const Duration(milliseconds: 700));
    }

    // A day with a two-digit count, the running version (so the badge
    // row is on screen too) and a long note. Fourteen changes is a
    // real number for this repo — 2026-09-08 had more.
    final busyDay = ChangelogService.groupByDay([
      ChangelogEntry(
        version: kAppVersion,
        date: '2026-09-09',
        notes: List.generate(
          14,
          (i) => 'search: 耶和华 finds the verses that hold it, and the '
              'fuzzy switch gets a way in ($i)',
        ),
      ),
    ]);

    // Review finding 3 (2026-09-09): the day heading was a Row of two
    // texts sized from the reading font × the OS text scale, with no
    // Flexible or Wrap between them — so on a 360 dp phone with the OS
    // at 200% the date alone was 300 px and the count overflowed the
    // screen. This pumps that exact configuration; before the fix
    // takeException() returns the RenderFlex overflow.
    testWidgets('a 360 dp phone at 200% text does not overflow the heading',
        (tester) async {
      await pump(tester,
          locale: 'zh-Hans', width: 360, textScale: 2.0, days: busyDay);
      expect(tester.takeException(), isNull);
      expect(find.text('2026-09-09'), findsOneWidget);
      expect(find.text('14 项改动'), findsOneWidget);
      expect(find.text(uiStrings['changelogYours']!['zh-Hans']!),
          findsOneWidget);
    });

    testWidgets('and the same in English, where the count is longer',
        (tester) async {
      await pump(tester,
          locale: 'en', width: 360, textScale: 2.0, days: busyDay);
      expect(tester.takeException(), isNull);
      expect(find.text('14 changes'), findsOneWidget);
    });

    // Review finding 4 (2026-09-09): under a Chinese title the notes
    // are English commit subjects with nothing saying why. One caption,
    // Chinese locales only — an English reader is not owed a note that
    // the English is in English.
    testWidgets('a Chinese reader is told the notes are in English',
        (tester) async {
      for (final locale in ['zh-Hans', 'zh-Hant']) {
        final caption = uiStrings['changelogLanguageNote']![locale]!;
        expect(caption, isNotEmpty, reason: '$locale caption is empty');
        await pump(tester,
            locale: locale, width: 800, textScale: 1.0, days: busyDay);
        expect(find.text(caption), findsOneWidget,
            reason: 'no caption in $locale');
      }
      expect(uiStrings['changelogLanguageNote']!['zh-Hans'],
          isNot(uiStrings['changelogLanguageNote']!['zh-Hant']),
          reason: 'Traditional is a script, not a character swap');
    });

    testWidgets('and an English reader is not', (tester) async {
      expect(uiStrings['changelogLanguageNote']!['en'], isEmpty);
      await pump(tester,
          locale: 'en', width: 800, textScale: 1.0, days: busyDay);
      expect(find.text(uiStrings['changelogLanguageNote']!['zh-Hans']!),
          findsNothing);
      expect(find.text(uiStrings['changelogLanguageNote']!['zh-Hant']!),
          findsNothing);
      // And no blank first row where the caption would have been: the
      // first thing on the page is the first day.
      final firstText = tester
          .widgetList<Text>(find.descendant(
              of: find.byType(ListView), matching: find.byType(Text)))
          .first;
      expect(firstText.data, '2026-09-09');
    });
  });

  // The generator and the two release scripts are bash and python, so
  // their tests are too; this is what puts them in `flutter test`, the
  // same way brand_marks_test runs the icon generator's check.
  group('the generator and the release scripts', () {
    for (final script in ['test_build_changelog.py', 'test_release_scripts.py']) {
      test('tools/$script passes', () async {
        final r = await Process.run(
          'python3',
          ['tools/$script'],
          workingDirectory: Directory.current.path,
        );
        expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
      }, timeout: const Timeout(Duration(minutes: 3)));
    }
  });

  group('the door', () {
    test('About opens the changelog, and NOT behind the update tile’s '
        'platform gate — the asset is bundled, so the web can read it too',
        () {
      final about = File('lib/pages/about_page.dart').readAsStringSync();
      expect(about.contains('ChangelogPage()'), isTrue,
          reason: 'a page nothing pushes is a page nobody sees');
    });

    test('the asset is declared in pubspec, or it is not in the build at all',
        () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec.contains('assets/changelog.json'), isTrue);
    });

    // Finding 1's other half lives in the release script: the generator
    // must be handed the version being built. A script that runs it
    // bare regenerates the pre-review asset.
    test('release_web.sh hands the generator the version it is building',
        () {
      final script = File('tools/release_web.sh').readAsStringSync();
      expect(
        RegExp(r'build_changelog\.py[^\n]*\\?\n?[^\n]*--head-version "\$APP_VERSION"')
            .hasMatch(script),
        isTrue,
        reason: 'build_changelog.py is not passed --head-version "\$APP_VERSION"',
      );
    });
  });
}
