/// Four things the owner asked for on 2026-09-16, each pinned by the
/// thing that was actually wrong.
///
///   「另外world应该的default tick」
///   「另外filter那边应该有个搜索」
///   「还有这个strip或者wheel应该有一个max screen把这个全屏模式」
///   「我记得之前版本是类似于中国环里面几个环如果是同时发生的事情这个不
///    见了 其他的也是 这个要恢复」
///
/// The first and the last were the same defect twice: GEOMETRY, not
/// data. On a 390 dp phone the whole stream annulus is 60 px, so
/// `ringCapacity` answered four and trimmed 全世界 off an opening set of
/// five, and a ring was 9.7 px, which at the old 6.6 px layer floor is
/// one layer at every ring count the chart can draw.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/chronology_filter_strings.dart';
import 'package:seeksparks/constants/strip_strings.dart';
import 'package:seeksparks/utils/radial_chronology_layout.dart';
import 'package:seeksparks/utils/wheel_default_streams.dart';

const _hub = 0.115;

void main() {
  group('the opening set is the owner\'s, not the geometry\'s', () {
    test('every phone this app runs on opens with 全世界', () {
      // 430 dp is left out on purpose: its geometry already answers
      // five, so it would prove nothing about the trim.
      for (final side in [320.0, 360.0, 390.0]) {
        final bands = bandsFractionFor(side);
        expect(ringCapacity(side, hubFraction: _hub, bandsFraction: bands),
            lessThan(kOpeningStreams),
            reason: 'if the geometry stopped being the binding constraint '
                'at $side this test is no longer about anything');
        expect(
            openingStreamCount(side,
                hubFraction: _hub, bandsFraction: bands),
            kOpeningStreams,
            reason: 'the fifth lane is 全世界 and the owner asked for it '
                'ticked by default');
      }
    });

    test('and a canvas too small for five rings still refuses', () {
      // The floor is a floor, not a suggestion — but since it became
      // the genealogy's own 1.70 px it takes an absurd canvas to reach.
      // 50 dp is not a device; it is the proof that the guard exists.
      const side = 50.0;
      final bands = bandsFractionFor(side);
      expect(
          openingStreamCount(side, hubFraction: _hub, bandsFraction: bands),
          lessThan(kOpeningStreams));
    });

    test('the opening ids are the spine and then the world', () {
      const ids = [
        'scripture', 'israel', 'judah', 'church', 'world', 'egypt', 'china'
      ];
      expect(defaultVisibleStreams(ids, kOpeningStreams),
          ['scripture', 'israel', 'judah', 'church', 'world']);
    });
  });

  group('layers inside a ring', () {
    test('a ring gives the overlaps their own lanes, as the genealogy does',
        () {
      // The floor is the genealogy annulus's own stroke on the narrowest
      // canvas — 1.70 px — 「很多overlap的圈圈环里面的可以学习这种啊」. So
      // the answer is the CORPUS's depth almost everywhere, not the
      // geometry's patience.
      int tiers(double side, int rings, int want) => streamTierCount(
          wanted: want,
          ringCount: rings,
          rHub: side * _hub,
          rMax: side * bandsFractionFor(side));

      // Every canvas from 600 dp up gives eight overlaps eight lanes.
      for (final side in [600.0, 900.0, 1440.0]) {
        expect(tiers(side, 5, 8), 8, reason: '$side');
      }
      // 12 rings at 1440: 2 before this change, the full depth now.
      expect(tiers(1440, 12, 6), 6);
    });

    test('a phone at five lanes gets five layers, not one', () {
      // The measurement the owner's photograph is about: a 390 dp phone
      // at the opening five lanes. One layer before 2026-09-16, two
      // after the first correction, five now.
      final n = streamTierCount(
          wanted: 8,
          ringCount: 5,
          rHub: 390 * _hub,
          rMax: 390 * bandsFractionFor(390));
      expect(n, 5);
      // And a stream that wants more than fits still shares its last
      // lane, which is what every stream did before layers existed.
      expect(n, lessThan(8));
    });

    test('nothing is divided below the floor', () {
      // The guarantee the floor IS: whatever the answer, every layer it
      // yields clears it.
      for (final side in [320.0, 390.0, 600.0, 900.0, 1440.0]) {
        for (final rings in [4, 5, 8, 12]) {
          final n = streamTierCount(
              wanted: 8,
              ringCount: rings,
              rHub: side * _hub,
              rMax: side * bandsFractionFor(side));
          final band = tierRadii(0, rings, side * _hub,
              side * bandsFractionFor(side),
              tier: 0, tiers: n);
          if (n > 1) {
            expect(band.width, greaterThan(0),
                reason: '$side/$rings divided into $n');
          }
        }
      }
    });
  });

  group('the strings the new controls need', () {
    test('the filter find box is worded in all three', () {
      for (final key in ['findHint', 'findNothing']) {
        for (final locale in ['zh-Hans', 'zh-Hant', 'en']) {
          expect(chronologyFilterText(key, locale), isNotEmpty,
              reason: '$key/$locale');
        }
      }
    });

    test('full screen is worded in all three, on both charts', () {
      for (final key in ['stripFullScreen', 'stripExitFullScreen']) {
        for (final locale in ['zh-Hans', 'zh-Hant', 'en']) {
          expect(stripStrings[key]?[locale], isNotEmpty,
              reason: '$key/$locale');
        }
      }
    });
  });
}
