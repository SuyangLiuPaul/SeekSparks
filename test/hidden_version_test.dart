/// 2026-09-02: NASB and LEB are hidden from the interface.
///
/// The owner's instruction was 只从界面藏掉 — take them off the interface,
/// not out of the build. That is a narrower change than a removal and it
/// has a narrower failure mode, which is what this file is for.
///
/// Two halves, and both have to hold:
///
///   1. Nothing OFFERS them. The picker, the Browse stack sheet, the
///      Browse nav strip, the command line's version verb, the Copy
///      Center, the split-pane seed, the first-run Browse stack and every
///      locale default all read `availableVersions`, so hiding is one
///      line — but only as long as no surface reaches past it to the raw
///      catalog. Two did (`command_pane`, `browse_nav_strip`), which is
///      why this is pinned rather than assumed.
///
///   2. Nobody is STRANDED on them. A version code outlives the reader's
///      choice of it: `nasb` is in SharedPreferences, in synced `lastRead`
///      blobs, in persisted Browse stacks, in saved Copy Center options
///      and in every `?v=nasb` link ever shared. Every one of those has to
///      land on a Bible the reader can also find in the picker — and,
///      where the reader chose English on purpose, an English one.
///
/// The assets themselves are untouched and still ship;
/// `test/data_integrity_test.dart` is what pins that, and this file
/// deliberately re-states it so the two halves of the decision cannot
/// drift apart without one of them failing.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/bible_versions.dart';
import 'package:seeksparks/constants/version_attribution.dart';
import 'package:seeksparks/constants/workbench_theme.dart'
    show kVersionTagColors;
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/workbench_warmup.dart'
    show defaultParallelVersions, sanitiseParallelVersions;
import 'package:seeksparks/utils/version_abbreviation.dart';

/// The two editions this change is about.
const _hidden = <String>['nasb', 'leb'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('hidden, not removed', () {
    test('both are still in the catalog, with their rows intact', () {
      // Hiding is not deleting. The row is what `shortBibleVersionLabel`,
      // `menuBibleVersionLabel`, `bibleVersionLanguage` and the notice
      // SnackBar all read, and a reader arriving on a stale `?v=nasb`
      // link is owed a message that can name what they asked for.
      for (final code in _hidden) {
        expect(bibleVersions.any((v) => v.value == code), isTrue,
            reason: '$code was removed from the catalog — that is a bigger '
                'change than the one that was asked for');
        expect(bibleVersionLanguage(code), 'en');
        expect(menuBibleVersionLabel(code), isNot(code),
            reason: '$code has no menuLabel left to print');
        expect(kVersionTagColors.containsKey(code), isTrue);
        expect(attributionKeyFor(code), isNotNull,
            reason: 'the licence line for $code is not something to drop '
                'while the asset still ships');
      }
    });

    test('both assets still ship, exactly as before', () {
      // The same pin as data_integrity_test, restated from the other
      // side: if hiding an edition ever starts taking its asset with it,
      // one of these two files says so.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final code in _hidden) {
        expect(pubspec, contains('assets/$code.json'),
            reason: 'assets/$code.json left pubspec — this was a visibility '
                'change, not a removal');
        expect(File('assets/$code.json').existsSync(), isTrue);
      }
    });

    test('the hidden set is exactly these two', () {
      expect(disabledVersions, _hidden.toSet());
    });
  });

  group('nothing offers them', () {
    test('they are not available versions', () {
      for (final code in _hidden) {
        expect(availableVersions.any((v) => v.value == code), isFalse);
        expect(isKnownVersion(code), isFalse,
            reason: 'isKnownVersion is the guard every caller shares');
        expect(isKnownVersion(code.toUpperCase()), isFalse);
      }
    });

    test('no language tab in the picker lists them', () {
      // `versionsForLanguage` fills both the version picker and the
      // Browse stack sheet, which are the two places a reader taps to
      // choose an edition.
      for (final lang in bibleLanguageOrder) {
        for (final v in versionsForLanguage(lang)) {
          expect(_hidden.contains(v.value), isFalse,
              reason: '${v.value} is on the $lang tab');
        }
      }
      expect(versionsForLanguage('en').map((v) => v.value),
          <String>['kjv', 'bsb', 'kjvs']);
    });

    test('the command line cannot summon them by abbreviation', () {
      // `d nas` used to stack NASB. The verb grammar is a way of picking
      // an edition, so it has to offer what the picker offers — matched
      // against `availableVersions`, the way command_pane now builds it.
      final live = {for (final v in availableVersions) v.value: v.shortLabel};
      for (final q in const [
        'nas',
        'nasb',
        'NASB',
        'leb',
        'LEB',
        'lex',
        'lexham',
      ]) {
        final hit = matchVersionAbbreviation(q, live);
        expect(_hidden.contains(hit), isFalse,
            reason: 'typing "$q" reached $hit');
      }
      // The abbreviations that still belong to somebody keep working —
      // narrowing the candidate set must not have cost a live edition.
      expect(matchVersionAbbreviation('kjv', live), 'kjv');
      expect(matchVersionAbbreviation('bsb', live), 'bsb');
      expect(matchVersionAbbreviation('lxx', live), 'lxxwh');
    });

    test('no locale opens on one', () {
      for (final locale in const ['en', 'zh-Hant', 'zh-Hans', 'fr', '']) {
        final v = localeDefaultVersion(locale);
        expect(_hidden.contains(v), isFalse, reason: '$locale defaults to $v');
        expect(isKnownVersion(v), isTrue);
      }
    });

    test('the English default is BSB', () {
      expect(localeDefaultVersion('en'), 'bsb');
    });

    test('no first-run Browse stack contains one', () {
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant', 'fr']) {
        final stack = defaultParallelVersions(locale);
        for (final code in stack) {
          expect(_hidden.contains(code), isFalse,
              reason: '$locale seeds its Browse stack with $code');
        }
        // And the stack survives the sanitiser unchanged. A default that
        // sanitising would rewrite is a default that quietly loses a
        // column: `nasb` collapsed onto the `bsb` already in the English
        // stack and left it two wide.
        expect(loadableVersions(stack), stack,
            reason: '$locale seeds a stack sanitising would change');
      }
    });

    test('no split-pane seed is one', () {
      for (final v in availableVersions) {
        final secondary = defaultSecondaryVersion(v.value);
        expect(_hidden.contains(secondary), isFalse,
            reason: '${v.value} opens a second column on $secondary');
      }
    });
  });

  group('nobody is stranded on one', () {
    test('a saved reading version resolves to BSB, not to the locale', () {
      // The substitution has to preserve LANGUAGE. A zh-Hans-locale
      // reader who deliberately chose an English Bible must not be handed
      // 和合本 because the fallback happened to be their UI locale.
      for (final code in _hidden) {
        expect(
          resolveReadingVersion(
              stored: code, fallback: localeDefaultVersion('zh-Hans')),
          'bsb',
        );
        expect(
          resolveReadingVersion(
              stored: ' ${code.toUpperCase()} ',
              fallback: localeDefaultVersion('zh-Hant')),
          'bsb',
        );
        expect(bibleVersionLanguage('bsb'), bibleVersionLanguage(code),
            reason: '$code -> bsb crosses languages');
      }
    });

    test('a shared ?v=nasb link lands on BSB and says so', () {
      // What `UrlSyncService` does with a link's version: resolve it,
      // and raise a notice when the answer differs from what was asked
      // for. The fallback there is the version already on screen, never
      // a locale default — a stale link is a reason to ignore the link,
      // not to move someone off the Bible they were reading.
      for (final code in _hidden) {
        final onScreen = 'cuvs-yhwh';
        final resolved =
            resolveReadingVersion(stored: code, fallback: onScreen);
        expect(resolved, 'bsb');
        expect(resolved, isNot(code),
            reason: 'differing from the request is what raises the notice');
        expect(isKnownVersion(resolved), isTrue);
      }
    });

    test('a persisted Browse stack keeps its live columns', () {
      // Retired/hidden codes are mapped rather than dropped, so a reader
      // who arranged columns still has columns — and the two that both
      // land on BSB collapse into one rather than comparing a text
      // against itself.
      expect(loadableVersions(['kjv', 'nasb', 'leb']), ['kjv', 'bsb']);
      expect(loadableVersions(['nasb', 'kjvs']), ['bsb', 'kjvs']);
      // A stack made only of hidden editions still yields a stack.
      expect(loadableVersions(['nasb', 'leb']), ['bsb']);
      expect(sanitiseParallelVersions(['nasb', 'leb'], 'en'), ['bsb']);
    });

    test('a stored split-pane pick does not reopen on a hidden edition', () {
      for (final code in _hidden) {
        for (final primary in const ['bsb', 'kjv', 'cuvs-yhwh']) {
          final got =
              resolveSecondaryVersion(primaryVersion: primary, stored: code);
          expect(_hidden.contains(got), isFalse);
          expect(got, isNot(primary),
              reason: 'a second column comparing $primary against itself');
          expect(availableVersions.any((v) => v.value == got), isTrue);
        }
      }
    });

    test('boot moves a saved NASB reader to BSB and tells them', () async {
      SharedPreferences.setMockInitialValues({
        'version': 'nasb',
        'locale': 'en',
        // Already migrated, so the v1.3.46 nudge is out of the picture
        // and this is purely the saved-version path.
        'migrated_locale_default_v1346': true,
      });

      final mp = MainProvider();
      await mp.restoreState();

      expect(mp.currentVersion, 'bsb');
      expect(isKnownVersion(mp.currentVersion), isTrue);
      expect(mp.retiredVersionNotice, isNotNull,
          reason: 'a silent swap reads as the app forgetting their choice');
      expect(mp.retiredVersionNotice!.requested, 'nasb');
      expect(mp.retiredVersionNotice!.substituted, 'bsb');
    });

    test('a saved LEB reader on a Chinese locale still gets English',
        () async {
      SharedPreferences.setMockInitialValues({
        'version': 'leb',
        'locale': 'zh-Hans',
        'migrated_locale_default_v1346': true,
      });

      final mp = MainProvider();
      await mp.restoreState();

      expect(mp.currentVersion, 'bsb',
          reason: 'they chose an English Bible; the UI locale is not that '
              'choice being revoked');
    });

    test('the v1.3.46 English migration no longer lands on a hidden edition',
        () async {
      // This migration actively MOVED English-locale readers onto NASB.
      // It fires once, on readers still sitting on the old class-level
      // `cuvs-yhwh` default, and it used to hard-code its target.
      SharedPreferences.setMockInitialValues({
        'version': 'cuvs-yhwh',
        'locale': 'en',
      });

      final mp = MainProvider();
      await mp.restoreState();

      expect(mp.currentVersion, localeDefaultVersion('en'));
      expect(mp.currentVersion, 'bsb');
      expect(availableVersions.any((v) => v.value == mp.currentVersion), isTrue,
          reason: 'the migration would strand the reader on an edition the '
              'picker does not offer');
    });

    test('the successor table covers both, and to a live edition', () {
      for (final code in _hidden) {
        expect(retiredVersionSuccessors.containsKey(code), isTrue,
            reason: '$code has no successor — its readers fall through to '
                'the LOCALE default, which for a Chinese-locale reader '
                'means losing English entirely');
        expect(isKnownVersion(retiredVersionSuccessors[code]), isTrue);
      }
    });
  });
}
