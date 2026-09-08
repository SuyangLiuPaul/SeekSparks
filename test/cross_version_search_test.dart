/// Cross-version search — bwh16, `docs/PARITY-BACKLOG.md` §3.1.
///
/// The entry this closes described the wrong feature, so the first thing
/// worth pinning is what the feature IS: a same-language **broadcast**
/// of one query, not a cross-language conjunction of two.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/bible_versions.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/utils/cross_version_search.dart';

void main() {
  group('which editions a search covers', () {
    test('the default covers exactly one, and it is the one being read', () {
      expect(
        crossVersionTargets(
          mode: CrossVersionSearchMode.currentOnly,
          reading: 'kjv',
          stack: const ['bsb', 'csb', 'cuvs-yhwh'],
        ),
        ['kjv'],
      );
    });

    test('the reading version is first and is never dropped', () {
      // bwh16: "The search version however is never removed even if it
      // has no hits." Every mode, every stack.
      for (final mode in CrossVersionSearchMode.values) {
        // 2026-09-08: the reading version was `'bsb'`, which is hidden
        // now. `crossVersionTargets` resolves what it is given, so a
        // hidden code would have made this assert about the successor
        // table rather than about "first and never dropped".
        final targets = crossVersionTargets(
          mode: mode,
          reading: 'bsb-yhwh',
          stack: const ['kjv'],
        );
        expect(targets.first, 'bsb-yhwh', reason: '$mode');
      }
    });

    test('the stack mode takes the stack, in the reader\'s order', () {
      // Not registry order. The Browse stack is an ordered list the
      // reader arranges by hand (#288), and a report that re-sorted it
      // would be describing a different arrangement from the one on
      // screen.
      // 2026-09-08: the stack was `['csb', 'bsb']` and is now
      // `['bsb-yhwh', 'csb']` — FLIPPED as well as renamed, and the flip
      // is the whole point. `bsb` sat BEFORE `csb` in the catalog, so
      // asking for csb-then-bsb was the reader contradicting registry
      // order. `bsb-yhwh` sits AFTER `csb`, so the old pair would have
      // matched registry order and this test would have gone on passing
      // against an implementation that re-sorted.
      expect(
        crossVersionTargets(
          mode: CrossVersionSearchMode.displayStack,
          reading: 'kjv',
          stack: const ['bsb-yhwh', 'csb'],
        ),
        ['kjv', 'bsb-yhwh', 'csb'],
      );
    });

    test('a different language is left out of the stack mode', () {
      // The whole feature is same-language. A Chinese column in an
      // English reader's stack would contribute a confident zero to
      // every English query.
      final targets = crossVersionTargets(
        mode: CrossVersionSearchMode.displayStack,
        reading: 'kjv',
        stack: const ['bsb-yhwh', 'cuvs-yhwh', 'lxxwh', 'csb'],
      );
      // 2026-09-08: was `bsb`. Only the code changed — the claim is
      // that the Chinese and Greek columns drop out and the English
      // ones survive in the reader's order.
      expect(targets, ['kjv', 'bsb-yhwh', 'csb']);
    });

    test('简体 and 繁體 are different corpora unless asked otherwise', () {
      // Documented divergence from BibleWorks, where "language" is one
      // attribute. Here the picker's language IS the script, and 雅伟 is
      // not a substring of 雅偉 — so broadcasting across the boundary
      // reports zeros that mean nothing about the text.
      //
      // 2026-09-08: the second 简体 edition in these stacks used to be
      // `cuvs-plus`, which is now hidden. It was only ever a stand-in
      // for "another edition in the same script" — the subject is the
      // script boundary — so `biblexg-v2` takes its place and the claim
      // is unchanged. (That `cuvs-plus` is now dropped from a stack is
      // covered by the hidden-edition test below, which reads
      // `disabledVersions` rather than naming a code.)
      expect(
        crossVersionTargets(
          mode: CrossVersionSearchMode.displayStack,
          reading: 'cuvs-yhwh',
          stack: const ['cuvs-yhwh-tr', 'biblexg-v2'],
        ),
        ['cuvs-yhwh', 'biblexg-v2'],
      );
      expect(
        crossVersionTargets(
          mode: CrossVersionSearchMode.displayStack,
          reading: 'cuvs-yhwh',
          stack: const ['cuvs-yhwh-tr', 'biblexg-v2'],
          searchAcrossScripts: true,
        ),
        ['cuvs-yhwh', 'cuvs-yhwh-tr', 'biblexg-v2'],
      );
    });

    test('the whole-language mode reaches every English edition offered',
        () {
      final targets = crossVersionTargets(
        mode: CrossVersionSearchMode.sameLanguage,
        reading: 'kjv',
      );
      final english =
          versionsForLanguage('en').map((v) => v.value).toSet();
      expect(targets.toSet(), english);
      expect(targets, contains('csb'),
          reason: 'the CSB shipped 2026-09-07 and is an English edition');
    });

    test('a hidden edition is not reached through the side door', () {
      // `disabledVersions` holds the NASB and, since 2026-09-08,
      // `cuvs-plus`: the owner took each off every surface a reader
      // picks from and left the assets bundled. A broadcast that
      // searched one would put it back on screen with a hit count beside
      // its name. Deliberately written against `disabledVersions` rather
      // than a list of codes, which is why it kept passing when the set
      // grew.
      final targets = crossVersionTargets(
        mode: CrossVersionSearchMode.sameLanguage,
        reading: 'kjv',
      );
      for (final hidden in disabledVersions) {
        expect(targets, isNot(contains(hidden)), reason: hidden);
      }
      expect(disabledVersions, isNotEmpty,
          reason: 'if nothing is hidden this test proves nothing');
    });

    test('a retired code resolves instead of asking for a missing asset',
        () {
      // The failure `loadableVersions` exists to stop: a stale code in
      // SharedPreferences reaches FetchVerses, Netlify answers the SPA
      // fallback, and json.decode dies on `<!DOCTYPE`.
      final targets = crossVersionTargets(
        mode: CrossVersionSearchMode.displayStack,
        reading: 'cuvs-yhwh',
        stack: const ['cuv-yhwd', 'biblexg-v2'],
      );
      expect(targets, isNot(contains('cuv-yhwd')));
      // It maps onto the reading version, so it collapses rather than
      // producing a column comparing a text against itself.
      expect(targets, ['cuvs-yhwh', 'biblexg-v2']);
    });

    test('an unknown reading version searches nothing at all', () {
      expect(
        crossVersionTargets(
          mode: CrossVersionSearchMode.sameLanguage,
          reading: 'not-a-version',
        ),
        isEmpty,
      );
    });
  });

  group('the report', () {
    CrossVersionHits report(List<VersionHits> rows) => CrossVersionHits(
          mode: CrossVersionSearchMode.sameLanguage,
          reading: rows.first.version,
          perVersion: rows,
        );

    test('an unread edition is not a zero', () {
      // The distinction the strip draws with an em dash. "This edition
      // does not say it" and "we could not read this edition" are
      // different facts, and reporting the second as the first is how a
      // search tells a confident lie.
      final r = report(const [
        VersionHits(version: 'kjv', count: 3),
        VersionHits(version: 'bsb', count: 0),
        VersionHits(version: 'csb', count: 0, searched: false),
      ]);
      expect(r.hitting.map((v) => v.version), ['kjv']);
      expect(r.empty.map((v) => v.version), ['bsb']);
      expect(r.unread.map((v) => v.version), ['csb']);
      expect(const VersionHits(version: 'csb', count: 0, searched: false)
          .isEmpty, isFalse);
    });

    test('one edition is not a broadcast', () {
      // The gate the strip uses: a `currentOnly` search must draw
      // nothing at all, not a strip saying "found in 1 of 1".
      expect(
        report(const [VersionHits(version: 'kjv', count: 3)]).isBroadcast,
        isFalse,
      );
    });

    test('the total counts hits, not verses, and says so', () {
      // The same verse matching in four editions is four rows of one
      // verse. Pinned because a caller that showed this as "results"
      // would be inflating the answer fourfold.
      final r = report(const [
        VersionHits(version: 'kjv', count: 3),
        VersionHits(version: 'bsb', count: 3),
      ]);
      expect(r.totalHits, 6);
    });
  });

  group('the stored preference', () {
    test('round-trips by name', () {
      for (final m in CrossVersionSearchMode.values) {
        expect(crossVersionModeFromName(m.name), m);
      }
    });

    test('anything else is the default', () {
      // Persisted by name and not by index precisely so that an unknown
      // value is recognisable as unknown. A stored index would silently
      // become whichever mode now sits at that position.
      expect(crossVersionModeFromName(null),
          CrossVersionSearchMode.currentOnly);
      expect(crossVersionModeFromName(''),
          CrossVersionSearchMode.currentOnly);
      expect(crossVersionModeFromName('searchAndPrune'),
          CrossVersionSearchMode.currentOnly);
      expect(crossVersionModeFromName('0'),
          CrossVersionSearchMode.currentOnly);
    });
  });

  group('what the reader is told', () {
    test('every string exists in all three locales', () {
      const keys = [
        'crossVersionSearchMode',
        'crossVersionSearchModeSubtitle',
        'crossVersionModeCurrentOnly',
        'crossVersionModeDisplayStack',
        'crossVersionModeSameLanguage',
        'crossVersionSummary',
        'crossVersionUnread',
      ];
      for (final k in keys) {
        for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
          final v = uiStrings[k]?[locale];
          expect(v, isNotNull, reason: '$k [$locale]');
          expect((v as String).trim(), isNotEmpty, reason: '$k [$locale]');
        }
      }
    });

    test('the summary carries both placeholders in every locale', () {
      // It is built by replacement, so a locale that dropped one would
      // print the brace to the reader.
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        final v = uiStrings['crossVersionSummary']![locale]!;
        expect(v, contains('{hit}'), reason: locale);
        expect(v, contains('{total}'), reason: locale);
      }
    });

    test('every mode has a label, and no two modes share one', () {
      // A mode added without a string would fall back to `m.name` in the
      // dropdown and show the reader a Dart identifier.
      final seen = <String>{};
      for (final m in CrossVersionSearchMode.values) {
        final key = switch (m) {
          CrossVersionSearchMode.currentOnly => 'crossVersionModeCurrentOnly',
          CrossVersionSearchMode.displayStack =>
            'crossVersionModeDisplayStack',
          CrossVersionSearchMode.sameLanguage =>
            'crossVersionModeSameLanguage',
        };
        final label = uiStrings[key]?['en'];
        expect(label, isNotNull, reason: '${m.name} has no English label');
        expect(seen.add(label!), isTrue, reason: 'duplicate label $label');
      }
    });
  });
}
