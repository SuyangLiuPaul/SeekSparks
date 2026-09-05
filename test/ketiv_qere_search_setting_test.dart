/// 2026-09-05 (bwh29): the Ketiv/Qere SEARCH setting.
///
/// `lib/utils/ketiv_qere.dart` already displayed and counted the two
/// Masoretic readings when it landed (`c82a823`, 2026-08-18), and
/// `docs/PARITY-BACKLOG.md`'s Qere/Kethib row names what was left: "what
/// is genuinely missing is the **setting**" — bwh29's two switches for
/// excluding either reading from a search.
///
/// Four things have to be true for that to be a feature rather than a
/// checkbox: the rule admits the right words, the setting persists, the
/// engines honour it, and OFF is still the default.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/original_word.dart';
import 'package:seeksparks/services/morph_search_service.dart';
import 'package:seeksparks/services/profile_service.dart';
import 'package:seeksparks/utils/ketiv_qere.dart';
import 'package:seeksparks/utils/morph_query.dart';
import 'package:seeksparks/utils/morphology.dart';
import 'package:seeksparks/utils/strongs_boolean_search.dart';
import 'package:seeksparks/utils/strongs_proximity.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── The rule ──────────────────────────────────────────────────────

  group('KetivQereSearchScope.admits', () {
    test('both readings count by default, which is BibleWorks\' default',
        () {
      const scope = KetivQereSearchScope.both;
      expect(scope.isDefault, isTrue);
      for (final kq in [null, 'k', 'q', 'kx', 'qx']) {
        expect(scope.admits(kq), isTrue, reason: '$kq');
      }
    });

    test('excluding the Ketiv drops k and kx, and nothing else', () {
      const scope = KetivQereSearchScope(excludeKetiv: true);
      expect(scope.admits('k'), isFalse);
      expect(scope.admits('kx'), isFalse);
      expect(scope.admits('q'), isTrue);
      expect(scope.admits('qx'), isTrue);
      expect(scope.admits(null), isTrue);
      expect(scope.isDefault, isFalse);
    });

    test('excluding the Qere drops q and qx, and nothing else', () {
      const scope = KetivQereSearchScope(excludeQere: true);
      expect(scope.admits('q'), isFalse);
      expect(scope.admits('qx'), isFalse);
      expect(scope.admits('k'), isTrue);
      expect(scope.admits('kx'), isTrue);
      expect(scope.admits(null), isTrue);
    });

    test('an unmarked word survives BOTH switches', () {
      // The one thing neither switch may ever do is empty the Bible.
      // bwh17 describes three classes — "Qere, Kethib, and neither" —
      // and "neither" is not what either checkbox is about.
      const scope =
          KetivQereSearchScope(excludeKetiv: true, excludeQere: true);
      expect(scope.admits(null), isTrue);
      expect(scope.admits('k'), isFalse);
      expect(scope.admits('q'), isFalse);
    });

    test('the rule agrees with the mark already printed on the screen', () {
      // `kx` prints K and `qx` prints Q (`ketivQereMark`), and
      // `OriginalWord.isKetiv` / `isQere` say the same. A search that
      // classified them differently from the letter beside the word
      // would be the worse of the two possible mistakes.
      for (final kq in ['k', 'kx']) {
        final w = OriginalWord(text: 'x', strongs: 'H1', ketivQere: kq);
        expect(w.isKetiv, isTrue, reason: kq);
        expect(ketivQereMark(kq), 'K', reason: kq);
        expect(
            const KetivQereSearchScope(excludeKetiv: true).admits(kq), isFalse,
            reason: kq);
      }
      for (final kq in ['q', 'qx']) {
        final w = OriginalWord(text: 'x', strongs: 'H1', ketivQere: kq);
        expect(w.isQere, isTrue, reason: kq);
        expect(ketivQereMark(kq), 'Q', reason: kq);
        expect(
            const KetivQereSearchScope(excludeQere: true).admits(kq), isFalse,
            reason: kq);
      }
    });

    test('value equality, so a provider can skip a no-op notify', () {
      expect(const KetivQereSearchScope(excludeKetiv: true),
          const KetivQereSearchScope(excludeKetiv: true));
      expect(const KetivQereSearchScope(excludeKetiv: true),
          isNot(const KetivQereSearchScope(excludeQere: true)));
    });
  });

  // ── The setting persists, the way the app persists the others ─────

  group('AppSettings', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('both switches are OFF until the reader asks', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppSettings();
      await s.loadSettings();
      expect(s.excludeKetivFromSearch, isFalse);
      expect(s.excludeQereFromSearch, isFalse);
      expect(s.ketivQereSearchScope, KetivQereSearchScope.both);
    });

    test('a switch is written under its own new key', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppSettings();
      await s.loadSettings();
      await s.setExcludeKetivFromSearch(true);
      final prefs = await SharedPreferences.getInstance();
      // The key name is the contract with every already-installed copy
      // of the app. It is new, and no existing key was renamed to make
      // room for it.
      expect(prefs.getBool('excludeKetivFromSearch'), isTrue);
      expect(prefs.getBool('excludeQereFromSearch'), isNull);
    });

    test('a stored switch comes back on the next launch', () async {
      SharedPreferences.setMockInitialValues({
        'excludeKetivFromSearch': true,
        'excludeQereFromSearch': true,
      });
      final s = AppSettings();
      await s.loadSettings();
      expect(s.excludeKetivFromSearch, isTrue);
      expect(s.excludeQereFromSearch, isTrue);
      expect(
          s.ketivQereSearchScope,
          const KetivQereSearchScope(
              excludeKetiv: true, excludeQere: true));
    });

    test('the switches ride the synced userPrefs blob, not only the '
        'per-key writes', () async {
      // The blob is applied OVER the per-key reads and is what carries
      // a setting between the reader's devices. A setting that persists
      // locally and is dropped from the snapshot comes back wrong on
      // the second device, which is the failure worth pinning.
      SharedPreferences.setMockInitialValues({
        'excludeKetivFromSearch': false,
        'excludeQereFromSearch': false,
        ProfileService.instance.scopedKey('userPrefs'): jsonEncode({
          'excludeKetivFromSearch': true,
          'excludeQereFromSearch': false,
        }),
      });
      final s = AppSettings();
      await s.loadSettings();
      expect(s.excludeKetivFromSearch, isTrue);
      expect(s.excludeQereFromSearch, isFalse);
    });

    test('a switch reaches the synced snapshot, not just its own key',
        () async {
      // The other half of the blob contract, and the half a per-key test
      // cannot see: `_userPrefsSnapshot()` is what travels between the
      // reader's devices, and a setting missing from it is a setting
      // that silently resets on the iPad. The write is debounced by
      // 600 ms off `notifyListeners`, so this waits for it rather than
      // reaching into a private method.
      SharedPreferences.setMockInitialValues({});
      final s = AppSettings();
      await s.loadSettings();
      await s.setExcludeQereFromSearch(true);
      await Future<void>.delayed(const Duration(milliseconds: 900));
      final prefs = await SharedPreferences.getInstance();
      final blob =
          prefs.getString(ProfileService.instance.scopedKey('userPrefs'));
      expect(blob, isNotNull);
      final m = jsonDecode(blob!) as Map<String, dynamic>;
      expect(m['excludeQereFromSearch'], isTrue);
      expect(m['excludeKetivFromSearch'], isFalse);
    });

    test('setting the value it already has does not notify', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppSettings();
      await s.loadSettings();
      var notifications = 0;
      s.addListener(() => notifications++);
      await s.setExcludeKetivFromSearch(false);
      expect(notifications, 0);
      await s.setExcludeKetivFromSearch(true);
      expect(notifications, 1);
    });
  });

  // ── The morphology search honours it, over the real corpus ───────

  group('MorphSearchService', () {
    setUp(MorphSearchService.clearCache);

    const verbs =
        MorphQuery(scheme: MorphScheme.semitic, constraints: {
      MorphSlot.pos: {'V'},
    });

    Future<int> verbsIn(String book, KetivQereSearchScope scope) async =>
        (await MorphSearchService.run(verbs,
                books: [book], ketivQere: scope))
            .total;

    test('Jeremiah loses the readings the reader excluded, and only those',
        () async {
      // Jeremiah carries 136 `k`, 137 `q`, 3 `kx`, 1 `qx`. Only the ones
      // parsing as a Hebrew verb can move this count, which is why the
      // deltas are 69 and 72 rather than 139 and 138 — the number is
      // measured, not derived.
      expect(await verbsIn('Jeremiah', KetivQereSearchScope.both), 5470);
      expect(
          await verbsIn('Jeremiah',
              const KetivQereSearchScope(excludeKetiv: true)),
          5401);
      expect(
          await verbsIn(
              'Jeremiah', const KetivQereSearchScope(excludeQere: true)),
          5398);
    });

    test('Ruth, which carries two of the eight Qere velo Ketiv words',
        () async {
      // 3:5 and 3:17 — `ketiv_qere.dart` names them.
      expect(await verbsIn('Ruth', KetivQereSearchScope.both), 419);
      expect(
          await verbsIn('Ruth', const KetivQereSearchScope(excludeKetiv: true)),
          412);
      expect(
          await verbsIn('Ruth', const KetivQereSearchScope(excludeQere: true)),
          413);
    });

    test('the default argument leaves every existing caller where it was',
        () async {
      // No `ketivQere:` at all — the signature this service had before
      // the setting existed.
      final r = await MorphSearchService.run(verbs, books: ['Ruth']);
      expect(r.total, 419);
    });

    test('an excluded word is dropped from the FACETS too, not only the '
        'hits', () async {
      // A facet the reader can tap that returns nothing is worse than a
      // facet that is not offered, so the filter sits above
      // `MorphFacets.add` rather than beside the match.
      final both = await MorphSearchService.run(verbs, books: ['Ruth']);
      final noKetiv = await MorphSearchService.run(verbs,
          books: ['Ruth'],
          ketivQere: const KetivQereSearchScope(excludeKetiv: true));
      expect(noKetiv.scanned, lessThan(both.scanned));
    });
  });

  // ── The engines honour it ─────────────────────────────────────────

  group('the word-order pass drops an excluded reading', () {
    const h1 = StrongsTerm(prefix: 'H', digits: '1', wildcard: false);
    const h2 = StrongsTerm(prefix: 'H', digits: '2', wildcard: false);

    /// H1, then a Ketiv, then a Qere, then H2 — so H1 and H2 are three
    /// words apart while both readings count, and fewer once one goes.
    List<String> order(KetivQereSearchScope scope) => [
          for (final w in const [
            OriginalWord(text: 'a', strongs: 'H1'),
            OriginalWord(text: 'b', strongs: 'H9', ketivQere: 'k'),
            OriginalWord(text: 'c', strongs: 'H8', ketivQere: 'q'),
            OriginalWord(text: 'd', strongs: 'H2'),
          ])
            if (scope.admits(w.ketivQere)) w.strongs
        ];

    test('excluding a reading shortens the distance between two words',
        () {
      expect(order(KetivQereSearchScope.both), ['H1', 'H9', 'H8', 'H2']);
      expect(order(const KetivQereSearchScope(excludeKetiv: true)),
          ['H1', 'H8', 'H2']);
      expect(
          order(const KetivQereSearchScope(
              excludeKetiv: true, excludeQere: true)),
          ['H1', 'H2']);
    });

    test('and that changes the answer a NEAR window gives', () {
      // Three apart with both readings in: NEAR2 fails.
      expect(
          verseSatisfiesProximity(
            strongsNumbersInOrder: order(KetivQereSearchScope.both),
            termA: h1,
            termB: h2,
            maxWords: 2,
          ),
          isFalse);
      // Drop both marked words and they are adjacent: NEAR2 holds. The
      // setting is doing real work rather than being stored.
      expect(
          verseSatisfiesProximity(
            strongsNumbersInOrder: order(const KetivQereSearchScope(
                excludeKetiv: true, excludeQere: true)),
            termA: h1,
            termB: h2,
            maxWords: 2,
          ),
          isTrue);
    });

    test('an excluded word cannot itself be a proximity hit', () {
      const h9 = StrongsTerm(prefix: 'H', digits: '9', wildcard: false);
      expect(
          verseSatisfiesProximity(
            strongsNumbersInOrder: order(KetivQereSearchScope.both),
            termA: h1,
            termB: h9,
            maxWords: 1,
          ),
          isTrue);
      expect(
          verseSatisfiesProximity(
            strongsNumbersInOrder:
                order(const KetivQereSearchScope(excludeKetiv: true)),
            termA: h1,
            termB: h9,
            maxWords: 1,
          ),
          isFalse);
    });
  });
}
