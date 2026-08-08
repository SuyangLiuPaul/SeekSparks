/// 2026-08-08: the production crash on a retired version code.
///
/// `https://seeksparks.netlify.app/#/genesis/1?v=cuv-yhwd` died on
/// `FormatException: Unexpected token '<', "<!DOCTYPE "...`. The chain:
/// `cuv-yhwd` was removed from the catalog with its asset, boot restored
/// it from SharedPreferences without checking, `FetchVerses` asked for
/// `assets/cuv-yhwd.json`, Netlify answered an unknown path with the SPA
/// fallback (`index.html`, status 200), `rootBundle.loadString` returned
/// that HTML quite happily, and `json.decode` choked on the first `<`.
///
/// Every assertion here would have failed on the day of the removal,
/// which is the point: a version code outlives the version, and nothing
/// in the app was checking.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/bible_versions.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/providers/workbench_provider.dart';
import 'package:seeksparks/services/fetch_verses.dart'
    show VerseAssetNotJsonException, assertJsonPayload;
import 'package:seeksparks/services/workbench_warmup.dart'
    show defaultParallelVersions, sanitiseParallelVersions;
import 'package:seeksparks/widgets/retired_version_notice.dart';

Widget _harness(MainProvider mp, AppSettings settings) => MultiProvider(
      providers: [
        ChangeNotifierProvider<MainProvider>.value(value: mp),
        ChangeNotifierProvider<AppSettings>.value(value: settings),
      ],
      child: MaterialApp(
        home: RetiredVersionNotice(
          child: const Scaffold(body: Text('reader')),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the retired-version table itself', () {
    test('every successor is an edition this build can actually load', () {
      // The failure mode this guards is a table that rots: retire an
      // edition that is itself somebody's successor, and the mapping
      // starts pointing at a missing asset — reintroducing exactly the
      // crash it exists to prevent, on a path nobody would think to
      // re-test.
      for (final entry in retiredVersionSuccessors.entries) {
        expect(isKnownVersion(entry.value), isTrue,
            reason: '${entry.key} maps to ${entry.value}, which is not in '
                'the catalog — the fallback would fail to load too');
      }
    });

    test('no retired code is also a live one', () {
      for (final code in retiredVersionSuccessors.keys) {
        expect(isKnownVersion(code), isFalse,
            reason: '$code is listed as retired but is still in the '
                'catalog — one of the two is wrong');
      }
    });

    test('a Chinese edition is never replaced by the other script', () {
      // The substitution a reader is least likely to forgive: handing a
      // 繁體 reader 简体 text is not a smaller version of the right
      // answer, it is an unreadable one.
      for (final entry in retiredVersionSuccessors.entries) {
        final from = entry.key;
        if (!from.startsWith('cuv') && !from.startsWith('cnv')) continue;
        final wantsTraditional = from.endsWith('-tr');
        final got = bibleVersionLanguage(entry.value);
        expect(got, wantsTraditional ? 'zh-Hant' : 'zh-Hans',
            reason: '$from -> ${entry.value} crosses scripts');
      }
    });

    test('the codes removed in 2026-08 are all covered', () {
      // Pinned individually rather than derived, so deleting a row from
      // the table fails here instead of silently going back to a crash.
      for (final code in const [
        'cuv',
        'cuv-tr',
        'cnv',
        'cnv-tr',
        'cuv-yhwd',
        'biblexg',
        'biblexg-tr',
        'niv',
      ]) {
        expect(retiredVersionSuccessors.containsKey(code), isTrue,
            reason: '$code was removed from the catalog and has no '
                'successor mapping — its readers hit the SPA fallback');
      }
    });
  });

  group('resolveReadingVersion', () {
    test('the code that took production down resolves to the same text', () {
      // cuv-yhwd and cuvs-yhwh share all 31,102 references, so this
      // reader loses nothing at all.
      expect(
        resolveReadingVersion(stored: 'cuv-yhwd', fallback: 'nasb'),
        'cuvs-yhwh',
      );
    });

    test('a live code is returned untouched', () {
      expect(resolveReadingVersion(stored: 'bsb', fallback: 'nasb'), 'bsb');
    });

    test('an unrecognisable code lands on the fallback, never throws', () {
      expect(
        resolveReadingVersion(stored: 'not-a-bible', fallback: 'kjv'),
        'kjv',
      );
    });

    test('null and empty mean "no opinion", so the fallback wins', () {
      expect(resolveReadingVersion(stored: null, fallback: 'kjv'), 'kjv');
      expect(resolveReadingVersion(stored: '', fallback: 'kjv'), 'kjv');
      expect(resolveReadingVersion(stored: '   ', fallback: 'kjv'), 'kjv');
    });

    test('case and stray whitespace do not defeat the lookup', () {
      // A code reaches this from a hand-edited URL as readily as from
      // prefs, and `?v=CUV-YHWD` is the same request.
      expect(
        resolveReadingVersion(stored: '  CUV-YHWD ', fallback: 'nasb'),
        'cuvs-yhwh',
      );
      expect(resolveReadingVersion(stored: 'BSB', fallback: 'nasb'), 'bsb');
    });

    test('every retired code resolves to something loadable', () {
      for (final code in retiredVersionSuccessors.keys) {
        final got = resolveReadingVersion(stored: code, fallback: 'kjv');
        expect(isKnownVersion(got), isTrue, reason: '$code -> $got');
      }
    });
  });

  group('localeDefaultVersion', () {
    test('each locale opens on an edition that exists', () {
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant', '', 'fr']) {
        expect(isKnownVersion(localeDefaultVersion(locale)), isTrue,
            reason: 'locale "$locale" defaults to an unloadable edition');
      }
    });

    test('an unknown locale falls to Simplified, the primary audience', () {
      expect(localeDefaultVersion('fr'), 'cuvs-yhwh');
    });
  });

  group('MainProvider.restoreState', () {
    test('a persisted retired code boots on its successor, not a crash',
        () async {
      // The regression test the removal should have shipped with. Before
      // the fix this left currentVersion == 'cuv-yhwd', and the very next
      // thing boot does is hand that to FetchVerses.
      SharedPreferences.setMockInitialValues({
        'version': 'cuv-yhwd',
        'locale': 'zh-Hans',
      });

      final mp = MainProvider();
      await mp.restoreState();

      expect(mp.currentVersion, 'cuvs-yhwh');
      expect(isKnownVersion(mp.currentVersion), isTrue);
    });

    test('the reader is told the substitution happened', () async {
      SharedPreferences.setMockInitialValues({
        'version': 'cuv-yhwd',
        'locale': 'zh-Hans',
      });

      final mp = MainProvider();
      await mp.restoreState();

      expect(mp.retiredVersionNotice, isNotNull,
          reason: 'a silent swap reads as the app forgetting their choice');
      expect(mp.retiredVersionNotice!.requested, 'cuv-yhwd');
      expect(mp.retiredVersionNotice!.substituted, 'cuvs-yhwh');
    });

    test('a code with no successor at all still boots', () async {
      SharedPreferences.setMockInitialValues({
        'version': 'never-existed',
        'locale': 'en',
      });

      final mp = MainProvider();
      await mp.restoreState();

      expect(mp.currentVersion, 'nasb');
      expect(isKnownVersion(mp.currentVersion), isTrue);
    });

    test('a live saved version is left alone and raises no notice',
        () async {
      SharedPreferences.setMockInitialValues({
        'version': 'bsb',
        'locale': 'en',
      });

      final mp = MainProvider();
      await mp.restoreState();

      expect(mp.currentVersion, 'bsb');
      expect(mp.retiredVersionNotice, isNull,
          reason: 'nothing was substituted, so there is nothing to say');
    });

    test('a fresh install still gets its locale default', () async {
      SharedPreferences.setMockInitialValues({'locale': 'zh-Hant'});

      final mp = MainProvider();
      await mp.restoreState();

      expect(mp.currentVersion, 'cuvs-yhwh-tr');
      expect(mp.retiredVersionNotice, isNull);
    });
  });

  group('assertJsonPayload', () {
    test('the exact payload that crashed production is rejected', () {
      expect(
        () => assertJsonPayload(
            '<!DOCTYPE html><html><head>', 'assets/cuv-yhwd.json'),
        throwsA(isA<VerseAssetNotJsonException>()),
      );
    });

    test('the message names the asset, which the FormatException did not',
        () {
      // The whole cost of this bug was diagnostic: `Unexpected token '<'`
      // named neither the file nor the version, so it read like a corrupt
      // Bible rather than an absent one.
      expect(
        const VerseAssetNotJsonException('assets/cuv-yhwd.json').toString(),
        contains('assets/cuv-yhwd.json'),
      );
    });

    test('a leading newline does not smuggle HTML past the check', () {
      expect(
        () => assertJsonPayload('\n\n  <html>', 'assets/x.json'),
        throwsA(isA<VerseAssetNotJsonException>()),
      );
    });

    test('real verse JSON passes, in both shapes the loader accepts', () {
      expect(() => assertJsonPayload('[{"book":"John"}]', 'a.json'),
          returnsNormally);
      expect(() => assertJsonPayload('  {"passages":{}}', 'a.json'),
          returnsNormally);
    });
  });

  group('the Browse stack', () {
    test('loadableVersions maps retired codes instead of dropping them', () {
      // A reader who arranged four columns should still have four.
      expect(
        loadableVersions(['kjv', 'biblexg', 'bsb']),
        ['kjv', 'biblexg-v2', 'bsb'],
      );
    });

    test('order is preserved — the stack is a layout, not a set', () {
      expect(loadableVersions(['bsb', 'kjv', 'nasb']), ['bsb', 'kjv', 'nasb']);
    });

    test('codes that collapse onto one edition are deduplicated', () {
      // cuv and cuv-yhwd both resolve to cuvs-yhwh; a Browse stack
      // comparing a text against itself is worse than a missing column.
      expect(
        loadableVersions(['cuv', 'cuv-yhwd', 'cuvs-yhwh', 'bsb']),
        ['cuvs-yhwh', 'bsb'],
      );
    });

    test('unrecognisable entries are discarded, not passed through', () {
      expect(loadableVersions(['kjv', 'garbage', '']), ['kjv']);
    });

    test('a stack that loses everything falls back to the defaults', () {
      expect(
        sanitiseParallelVersions(['garbage', 'also-garbage'], 'zh-Hans'),
        defaultParallelVersions('zh-Hans'),
      );
    });

    test('an absent stack still gets the locale defaults', () {
      expect(sanitiseParallelVersions(null, 'en'), defaultParallelVersions('en'));
    });

    test('the provider refuses an unloadable code however it is set', () {
      // The chokepoint: the page assigns this field directly from
      // SharedPreferences, so filtering only at the restore site would
      // leave the command line and the version picker unguarded.
      final wb = WorkbenchProvider(mainProvider: MainProvider());
      wb.parallelVersions = ['kjv', 'cuv-yhwd', 'not-a-version'];
      expect(wb.parallelVersions, ['kjv', 'cuvs-yhwh']);

      wb.setParallelVersions(['biblexg-tr', 'nope']);
      expect(wb.parallelVersions, ['biblexg-v2-tr']);
    });

    test('every default Browse stack is loadable in every locale', () {
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        final stack = defaultParallelVersions(locale);
        expect(loadableVersions(stack), stack,
            reason: 'the $locale default stack names an edition that is '
                'not in the catalog');
      }
    });
  });

  group('the notice widget', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('names the substituted edition the reader is now reading',
        (tester) async {
      final mp = MainProvider()
        ..retiredVersionNotice =
            (requested: 'cuv-yhwd', substituted: 'cuvs-yhwh');

      await tester.pumpWidget(_harness(mp, AppSettings()));
      await tester.pumpAndSettle();

      final label = bibleVersions
          .firstWhere((v) => v.value == 'cuvs-yhwh')
          .menuLabel;
      expect(find.textContaining('cuv-yhwd'), findsOneWidget);
      expect(find.textContaining(label), findsOneWidget);

      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('survives a successor that has itself been retired',
        (tester) async {
      // The crash this replaced: `firstWhere` with no `orElse` throws a
      // StateError, so a notice about one missing edition would take the
      // whole first frame down. The catalog row is the nice-to-have; the
      // code is the fact the reader actually needs.
      final mp = MainProvider()
        ..retiredVersionNotice =
            (requested: 'cuv-yhwd', substituted: 'gone-too');

      await tester.pumpWidget(_harness(mp, AppSettings()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('gone-too'), findsOneWidget,
          reason: 'with no catalog row the bare code is all there is to '
              'show, and it beats a blank screen');
      expect(find.text('reader'), findsOneWidget);

      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('is said once — the provider is cleared', (tester) async {
      final mp = MainProvider()
        ..retiredVersionNotice =
            (requested: 'cuv-yhwd', substituted: 'cuvs-yhwh');

      await tester.pumpWidget(_harness(mp, AppSettings()));
      await tester.pumpAndSettle();

      expect(mp.retiredVersionNotice, isNull,
          reason: 'a substitution is news exactly once');

      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('renders the child untouched when there is nothing to say',
        (tester) async {
      await tester.pumpWidget(_harness(MainProvider(), AppSettings()));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('reader'), findsOneWidget);
    });
  });
}
