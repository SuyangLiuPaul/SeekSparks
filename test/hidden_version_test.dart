/// 2026-09-02: the NASB is hidden from the interface.
///
/// The owner's instruction was 只从界面藏掉 — take it off the interface,
/// not out of the build.
///
/// **The LEB was hidden alongside it for a few hours the same day and is
/// visible again.** The owner checked its licence and it permits what
/// this app does; only the NASB's permission is still an open question,
/// and it is open with the publisher rather than here. The pair were
/// hidden together because the question had not been asked, not because
/// the answers matched — so the LEB is not in [_hidden] and appears
/// below only as the control that proves the hiding is narrow. That is a
/// narrower change than a removal and it has a narrower failure mode,
/// which is what this file is for.
///
/// [_hidden] has grown twice since, both on 2026-09-08 and both for the
/// superseded-by-a-divine-name-edition reason rather than the NASB's
/// licensing one: `cuvs-plus` in the morning and `bsb` in the
/// afternoon. Their notes are on [_hidden] itself. The two halves below
/// are unchanged and are what every entry has to satisfy.
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
import 'package:seeksparks/services/profile_service.dart';
import 'package:seeksparks/services/workbench_warmup.dart'
    show defaultParallelVersions, sanitiseParallelVersions;
import 'package:seeksparks/utils/version_abbreviation.dart';

/// The editions this file is about.
///
/// 2026-09-08: `cuvs-plus` joins the NASB, for an unrelated reason and
/// with the same mechanism. The owner's instruction was 「有雅+ 就不用
/// 和合本+了」 — the picker was offering 和合本+Strong's beside
/// 和合本雅伟版, which is one base text listed twice, differing mostly by
/// the 4,857 places the successor restores the divine name.
///
/// 2026-09-08, later the same day: `bsb` joins them, on the owner's
/// extension of that same ruling to the English pair — 「bsbs 不用，就
/// bsb yahweh 版本导入」. The relation is identical: one base text
/// (`bsb`), one row restoring the divine name (`bsb-yhwh`), and after
/// the app's render-time LORD → Yahweh rewrite the two differ in 636
/// verses of 31,086 (2.0%). It is explicitly NOT a licensing question —
/// the BSB has been public domain outright since 2023 — which is why
/// `unrestrictedCopyVersions` still names it and why the assertions
/// below about the asset shipping are the ones that matter most here.
///
/// The three entries are NOT the same decision and should not be
/// collapsed into one: the NASB is hidden pending a licensing answer
/// from its publisher and could come back, while `cuvs-plus` and `bsb`
/// are superseded and are not expected to. What they share is the
/// requirement below — nothing offers them, and nobody is stranded on
/// them.
const _hidden = <String>['nasb', 'cuvs-plus', 'bsb'];

/// The edition that was hidden with it and is visible again. Every place
/// `_hidden` is asserted absent, this is asserted PRESENT, so a re-hide
/// cannot slip through as a passing test.
const _restored = 'leb';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('hidden, not removed', () {
    test('all three are still in the catalog, with their rows intact', () {
      // Hiding is not deleting. The row is what `shortBibleVersionLabel`,
      // `menuBibleVersionLabel`, `bibleVersionLanguage` and the notice
      // SnackBar all read, and a reader arriving on a stale `?v=nasb`
      // link is owed a message that can name what they asked for.
      for (final code in _hidden) {
        expect(bibleVersions.any((v) => v.value == code), isTrue,
            reason: '$code was removed from the catalog — that is a bigger '
                'change than the one that was asked for');
        // The language is asserted to be the row's OWN, not a literal.
        // It used to read `'en'`, which was true only while the NASB was
        // the only entry; `cuvs-plus` is zh-Hans, and a successor that
        // crossed languages is the failure the stranding group below
        // checks for.
        expect(bibleVersionLanguage(code),
            bibleVersions.firstWhere((v) => v.value == code).language);
        expect(menuBibleVersionLabel(code), isNot(code),
            reason: '$code has no menuLabel left to print');
        expect(kVersionTagColors.containsKey(code), isTrue);
        expect(attributionKeyFor(code), isNotNull,
            reason: 'the licence line for $code is not something to drop '
                'while the asset still ships');
      }
    });

    // 2026-09-08: the load-bearing one for `bsb`. Hiding it was
    // explicitly NOT a licensing decision — the BSB is public domain
    // outright since 2023 — and `assets/bsb.json` is read as a
    // cross-check corpus by `test/yahwehdehua_editions_test.dart`,
    // which compares `bsb-yhwh` reference-by-reference against it. If
    // hiding ever starts taking the asset with it, that comparison
    // loses its baseline and this line is where it is caught.
    test('all three assets still ship, exactly as before', () {
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

    // 2026-09-08: was "these two" (nasb, cuvs-plus); `bsb` makes three,
    // on 「bsbs 不用，就 bsb yahweh 版本导入」. Pinned as an exact set
    // rather than a containment so that hiding a fourth edition cannot
    // happen without this line, and this file's [_hidden] list, both
    // being edited.
    test('the hidden set is exactly these three', () {
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
      // 2026-09-08: `bsb-yhwh` and `asv-yhwh` appended after `kjvs`.
      // The list is still written out in full rather than filtered,
      // because its job here is to say that the hidden codes are absent
      // AND that nothing else moved when they were hidden — a `where`
      // over the catalog would assert neither.
      //
      // 2026-09-08, same day: `bsb` removed from this list (it stood
      // third, between the LEB and the CSB) when it joined [_hidden].
      // Seven English rows became six. `bsb-yhwh` does NOT take the
      // vacated position — it stays where it was appended, after
      // `kjvs`, because `defaultSecondaryVersion` seeds a split pane
      // from the first other row in the language and moving it up would
      // change that answer for every English reader.
      expect(versionsForLanguage('en').map((v) => v.value), <String>[
        'kjv',
        _restored,
        'csb',
        'kjvs',
        'bsb-yhwh',
        'asv-yhwh',
      ]);
    });

    test('the command line cannot summon them by abbreviation', () {
      // `d nas` used to stack NASB. The verb grammar is a way of picking
      // an edition, so it has to offer what the picker offers — matched
      // against `availableVersions`, the way command_pane now builds it.
      final live = {for (final v in availableVersions) v.value: v.shortLabel};
      for (final q in const ['nas', 'nasb', 'NASB']) {
        final hit = matchVersionAbbreviation(q, live);
        expect(_hidden.contains(hit), isFalse,
            reason: 'typing "$q" reached $hit');
      }
      // ...and the LEB's abbreviations resolve again, which is the half
      // of this test that would still pass if the restore were undone.
      for (final q in const ['leb', 'LEB']) {
        expect(matchVersionAbbreviation(q, live), _restored,
            reason: 'typing "$q" no longer reaches the LEB');
      }
      // The abbreviations that still belong to somebody keep working —
      // narrowing the candidate set must not have cost a live edition.
      expect(matchVersionAbbreviation('kjv', live), 'kjv');
      // 2026-09-08: was `'bsb'`. Typing `bsb` no longer matches a code
      // exactly — `bsb` is hidden — so it falls to the prefix rule and
      // lands on the only live candidate that starts with it, which is
      // the successor. That is the right answer and it is worth
      // asserting rather than deleting: a reader with `d bsb` in their
      // fingers gets the edition that replaced it instead of "no
      // version named bsb".
      expect(matchVersionAbbreviation('bsb', live), 'bsb-yhwh');
      expect(matchVersionAbbreviation('lxx', live), 'lxxwh');
    });

    test('no locale opens on one', () {
      for (final locale in const ['en', 'zh-Hant', 'zh-Hans', 'fr', '']) {
        final v = localeDefaultVersion(locale);
        expect(_hidden.contains(v), isFalse, reason: '$locale defaults to $v');
        expect(isKnownVersion(v), isTrue);
      }
    });

    // 2026-09-08: was `'bsb'`, and before 2026-09-02 `'nasb'`. Each
    // move happened because the previous answer was hidden; the
    // assertion above ("no locale opens on one") is the rule and this
    // is the ledger of where the rule has landed.
    test('the English default is BSB (Yahweh)', () {
      expect(localeDefaultVersion('en'), 'bsb-yhwh');
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
    test('a saved reading version resolves to the successor, not the locale',
        () {
      // The substitution has to preserve LANGUAGE, and the fallback
      // offered here is deliberately the WRONG language in both cases —
      // a zh-Hans-locale reader who chose the NASB on purpose must not
      // be handed 和合本 just because the fallback happened to be their
      // UI locale, and the same in reverse for `cuvs-plus`.
      //
      // 2026-09-08: expected against `retiredVersionSuccessors` rather
      // than the literal 'bsb'. With two hidden editions in two
      // languages there is no single right answer, and writing one in
      // would have made this test assert the NASB's answer about a
      // Chinese edition.
      for (final code in _hidden) {
        final successor = retiredVersionSuccessors[code];
        expect(successor, isNotNull,
            reason: '$code is hidden with no recorded successor');
        for (final locale in const ['zh-Hans', 'zh-Hant', 'en']) {
          expect(
            resolveReadingVersion(
                stored: code, fallback: localeDefaultVersion(locale)),
            successor,
            reason: '$code under a $locale fallback',
          );
        }
        expect(
          resolveReadingVersion(
              stored: ' ${code.toUpperCase()} ',
              fallback: localeDefaultVersion('zh-Hant')),
          successor,
          reason: 'padding and case must not defeat the substitution',
        );
        expect(bibleVersionLanguage(successor!), bibleVersionLanguage(code),
            reason: '$code -> $successor crosses languages');
        expect(disabledVersions.contains(successor), isFalse,
            reason: '$code lands on another hidden edition');
      }
    });

    test('a shared ?v=<hidden> link lands on the successor and says so', () {
      // What `UrlSyncService` does with a link's version: resolve it,
      // and raise a notice when the answer differs from what was asked
      // for. The fallback there is the version already on screen, never
      // a locale default — a stale link is a reason to ignore the link,
      // not to move someone off the Bible they were reading.
      for (final code in _hidden) {
        // Deliberately a fallback that is NOT the successor, so the
        // assertion below proves the successor table was consulted
        // rather than the fallback being echoed back.
        const onScreen = 'kjv';
        final resolved =
            resolveReadingVersion(stored: code, fallback: onScreen);
        expect(resolved, retiredVersionSuccessors[code]);
        expect(resolved, isNot(code),
            reason: 'differing from the request is what raises the notice');
        expect(isKnownVersion(resolved), isTrue);
      }
    });

    test('a persisted Browse stack keeps its live columns', () {
      // Retired/hidden codes are mapped rather than dropped, so a reader
      // who arranged columns still has columns — and the two that both
      // land on the same edition collapse into one rather than comparing
      // a text against itself.
      //
      // 2026-09-08: every expected `'bsb'` below became `'bsb-yhwh'`.
      // `nasb`'s successor row was repointed past `bsb` when `bsb` was
      // hidden, rather than left to chain through it — see the note on
      // `'nasb'` in [retiredVersionSuccessors]. The line below is what
      // proves the repoint happened, because a chain that this map does
      // not actually walk would land a saved NASB reader on a hidden
      // edition.
      expect(
          loadableVersions(['kjv', 'nasb', 'leb']), ['kjv', 'bsb-yhwh', 'leb']);
      expect(loadableVersions(['nasb', 'kjvs']), ['bsb-yhwh', 'kjvs']);
      // A stack made only of the hidden edition still yields a stack.
      expect(loadableVersions(['nasb']), ['bsb-yhwh']);
      expect(sanitiseParallelVersions(['nasb'], 'en'), ['bsb-yhwh']);
      // ...and the newly hidden one collapses onto the same successor,
      // so a reader who had both columns ends with one rather than two
      // renderings of the same 31,086 verses.
      expect(loadableVersions(['nasb', 'bsb']), ['bsb-yhwh']);
      // The restored edition passes through untouched — no successor
      // row, no substitution, no collapse.
      expect(loadableVersions(['leb']), ['leb']);
      expect(sanitiseParallelVersions(['leb'], 'en'), ['leb']);
    });

    test('a stored split-pane pick does not reopen on a hidden edition', () {
      for (final code in _hidden) {
        // 2026-09-08: the first primary was `'bsb'`; it is hidden now,
        // and a primary that is not on offer is not a case this test
        // has any business asserting about. `bsb-yhwh` is the English
        // edition that replaced it.
        for (final primary in const ['bsb-yhwh', 'kjv', 'cuvs-yhwh']) {
          final got =
              resolveSecondaryVersion(primaryVersion: primary, stored: code);
          expect(_hidden.contains(got), isFalse);
          expect(got, isNot(primary),
              reason: 'a second column comparing $primary against itself');
          expect(availableVersions.any((v) => v.value == got), isTrue);
        }
      }
    });

    // 2026-09-08: the destination was `bsb` until `bsb` was hidden in
    // its turn; it is `bsb-yhwh` now, straight from the NASB's own
    // successor row rather than by chaining.
    test('boot moves a saved NASB reader to BSB (Yahweh) and tells them',
        () async {
      SharedPreferences.setMockInitialValues({
        'version': 'nasb',
        'locale': 'en',
        // Already migrated, so the v1.3.46 nudge is out of the picture
        // and this is purely the saved-version path.
        'migrated_locale_default_v1346': true,
      });

      final mp = MainProvider();
      await mp.restoreState();

      expect(mp.currentVersion, 'bsb-yhwh');
      expect(isKnownVersion(mp.currentVersion), isTrue);
      expect(mp.retiredVersionNotice, isNotNull,
          reason: 'a silent swap reads as the app forgetting their choice');
      expect(mp.retiredVersionNotice!.requested, 'nasb');
      expect(mp.retiredVersionNotice!.substituted, 'bsb-yhwh');
    });

    // 2026-09-09. `retiredVersionNotice`'s own docstring promises "a
    // substitution is news exactly once, and a notice that reappears on
    // every launch is a nag about a decision the reader cannot change",
    // and until today it only kept that promise WITHIN a session. It
    // cleared the field and left the stored preference alone, so the
    // next launch re-read the retired code, re-resolved it, and said the
    // same sentence again — forever.
    //
    // Reported as a black bar at the bottom of the loading screen every
    // time Sword opened: 「为什么有提示 BSB Y 不能提供？不应该有这个任何
    // popup 啊」. The reader was right twice — they had not asked for
    // anything, and BSB-Y is the edition being GIVEN, not the one being
    // refused. `bsb` went into `disabledVersions` on 2026-09-08, and
    // anyone whose saved preference was `bsb` has been told about it on
    // every launch since.
    test('a retired edition is announced once, not on every launch',
        () async {
      // THE CONDITION THAT ACTUALLY REPRODUCES IT. Rewriting the local
      // preference is not enough and was tried first: `restoreState`
      // reads the synced `lastRead` blob BEFORE it falls back to the
      // per-key pref, so a cloud copy still naming the retired edition
      // re-supplies it on every launch however many times this device
      // writes its own. That is why the reader saw the bar every time
      // rather than once.
      final lastRead = ProfileService.instance.scopedKey('lastRead');
      const blob = '{"version":"bsb","book":"John","chapter":1}';
      SharedPreferences.setMockInitialValues({
        lastRead: blob,
        'version': 'bsb',
        'locale': 'en',
        'migrated_locale_default_v1346': true,
      });

      final first = MainProvider();
      await first.restoreState();
      expect(first.currentVersion, 'bsb-yhwh');
      expect(first.retiredVersionNotice, isNotNull,
          reason: 'the first launch after the retirement owes them the '
              'truth about which Bible they are looking at');
      expect(first.retiredVersionNotice!.requested, 'bsb');

      // The blob still says `bsb` — this device cannot make the cloud
      // forget, and that is the point.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(lastRead, blob);

      final second = MainProvider();
      await second.restoreState();
      expect(second.currentVersion, 'bsb-yhwh');
      expect(second.retiredVersionNotice, isNull,
          reason: 'this is the nag the docstring forbids — 「为什么有提示 '
              'BSB Y 不能提供？不应该有这个任何 popup 啊」');
    });

    test('a saved LEB reader keeps the LEB, and is told nothing', () async {
      // While the LEB was hidden this asserted the reader landed on BSB.
      // It is visible again, so the honest outcome is that NOTHING
      // happens to them — and a notice would be worse than a silent
      // swap, because it would announce a change that did not occur.
      SharedPreferences.setMockInitialValues({
        'version': 'leb',
        'locale': 'zh-Hans',
        'migrated_locale_default_v1346': true,
      });

      final mp = MainProvider();
      await mp.restoreState();

      expect(mp.currentVersion, _restored);
      expect(mp.retiredVersionNotice, isNull);
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
      // 2026-09-08: was 'bsb'. Both lines are kept deliberately — the
      // first says the migration reads the locale default rather than a
      // hard-coded target (which is the bug it was written for), and
      // this one says what that default currently IS, so a silent move
      // of the English default still shows up in a diff.
      expect(mp.currentVersion, 'bsb-yhwh');
      expect(availableVersions.any((v) => v.value == mp.currentVersion), isTrue,
          reason: 'the migration would strand the reader on an edition the '
              'picker does not offer');
    });

    test('the successor table covers the hidden one, to a live edition', () {
      expect(retiredVersionSuccessors.containsKey(_restored), isFalse,
          reason: 'a successor row would move readers off an edition the '
              'picker is offering them');
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
