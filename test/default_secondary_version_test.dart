import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/bible_versions.dart';
import 'package:seeksparks/utils/responsive.dart';

/// Split View used to seed its second pane with the primary's version,
/// so it rendered the same chapter twice. These pin the replacement
/// rule down: never the same version, and prefer one the reader can
/// actually read.
void main() {
  group('defaultSecondaryVersion', () {
    test('never returns the primary version', () {
      for (final v in availableVersions) {
        expect(defaultSecondaryVersion(v.value), isNot(v.value),
            reason: '${v.value} would duplicate the primary pane');
      }
    });

    test('always returns a version that exists in the catalog', () {
      for (final v in availableVersions) {
        final secondary = defaultSecondaryVersion(v.value);
        expect(availableVersions.any((c) => c.value == secondary), isTrue,
            reason: '$secondary is not a real version');
      }
    });

    test('prefers a sibling in the same language', () {
      for (final v in availableVersions) {
        final siblings =
            versionsForLanguage(v.language).where((c) => c.value != v.value);
        if (siblings.isEmpty) continue;
        expect(bibleVersionLanguage(defaultSecondaryVersion(v.value)),
            v.language,
            reason: '${v.value} has a same-language sibling to pair with');
      }
    });

    test('pairs the concrete cases the catalog actually holds', () {
      // BSB against KJV, 和合本 against 梁家铿译本 — a real comparison,
      // in a script the reader already has open.
      //
      // 2026-09-02: was `nasb → kjv` and `kjv → leb`. Both named an
      // edition that is hidden now, and `kjv → leb` in particular was
      // asserting that Split View seeds a column a reader cannot pick.
      expect(defaultSecondaryVersion('bsb'), 'kjv');
      expect(defaultSecondaryVersion('kjv'), 'bsb');
      expect(defaultSecondaryVersion('cuvs-yhwh'), 'biblexg-v2');
      expect(defaultSecondaryVersion('cuvs-yhwh-tr'), 'biblexg-v2-tr');
    });

    test('an unknown version code still yields something readable', () {
      // bibleVersionLanguage falls back to zh-Hans for unknown codes, so
      // a stale saved version from an old build lands on a Chinese
      // edition rather than crashing or duplicating.
      final secondary = defaultSecondaryVersion('some-retired-code');
      expect(availableVersions.any((c) => c.value == secondary), isTrue);
      expect(bibleVersionLanguage(secondary), 'zh-Hans');
    });
  });

  group('resolveSecondaryVersion', () {
    // The split pane and the boot warm-up both call this. If they
    // disagreed about what a stale preference resolves to, the warm-up
    // would load one Bible and the pane would then fetch a different one.
    test('keeps a stored version that still exists', () {
      expect(
        resolveSecondaryVersion(primaryVersion: 'bsb', stored: 'kjv'),
        'kjv',
      );
    });

    test('a stored version that has been HIDDEN is not kept', () {
      // The reader's own pick normally wins over any default. It cannot
      // win when the edition has been taken off the interface: keeping
      // `leb` here would reopen the split column on a Bible with no row
      // in the picker, which is the one place the reader would go to
      // change it back. It lands on the successor instead — BSB, which
      // is the primary here, so the pairing rule takes over from there.
      final got =
          resolveSecondaryVersion(primaryVersion: 'bsb', stored: 'leb');
      expect(got, isNot('leb'));
      expect(got, isNot('bsb'), reason: 'a column comparing BSB to BSB');
      expect(availableVersions.any((v) => v.value == got), isTrue);
    });

    test('falls back when nothing is stored', () {
      expect(
        resolveSecondaryVersion(primaryVersion: 'bsb'),
        defaultSecondaryVersion('bsb'),
      );
    });

    test('falls back when the stored version was retired', () {
      expect(
        resolveSecondaryVersion(
            primaryVersion: 'bsb', stored: 'some-retired-code'),
        defaultSecondaryVersion('bsb'),
      );
      expect(
        resolveSecondaryVersion(primaryVersion: 'bsb', stored: ''),
        defaultSecondaryVersion('bsb'),
      );
    });

    test('always resolves to a version in the catalog', () {
      for (final v in availableVersions) {
        final secondary =
            resolveSecondaryVersion(primaryVersion: v.value, stored: null);
        expect(availableVersions.any((c) => c.value == secondary), isTrue);
      }
    });
  });

  group('shouldAutoSplit', () {
    test('does not split a screen too narrow for two readable columns', () {
      // The width from the report: two ~440px columns, 6-7 words a line.
      expect(ResponsiveBreakpoints.shouldAutoSplit(880), isFalse);
      expect(ResponsiveBreakpoints.shouldAutoSplit(600), isFalse);
      expect(ResponsiveBreakpoints.shouldAutoSplit(390), isFalse);
    });

    test('splits once both columns clear the readable minimum', () {
      expect(ResponsiveBreakpoints.shouldAutoSplit(960), isTrue);
      expect(ResponsiveBreakpoints.shouldAutoSplit(1400), isTrue);
    });

    test('is stricter than the sidebar breakpoint it used to share', () {
      // The bug: both defaults keyed off isTabletOrWider (>=600).
      expect(ResponsiveBreakpoints.isTabletOrWider(880), isTrue);
      expect(ResponsiveBreakpoints.shouldAutoSplit(880), isFalse);
    });
  });
}
