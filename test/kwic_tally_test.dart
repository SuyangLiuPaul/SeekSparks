// #304 / docs/DATA-INTEGRITY.md "Next, in order": the KWIC footer counted
// references FETCHED, not references DRAWN, and its header called a verse
// count "hits". This tests the tally that fixes both.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/utils/kwic.dart';

KwicLine _line(String reference, {int hitIndex = 0}) => KwicLine(
      reference: reference,
      left: 'left',
      keyword: 'keyword',
      right: 'right',
      hitIndex: hitIndex,
    );

void main() {
  group('KwicTally', () {
    test('counts distinct references, not lines', () {
      final tally = KwicTally.of(
        referencesFetched: 5,
        lines: [
          _line('John 3:16'),
          _line('John 3:16', hitIndex: 1),
          _line('Romans 5:8'),
        ],
      );
      expect(tally.referencesShown, 2);
      expect(tally.lines, 3);
      expect(tally.referencesDropped, 3);
    });

    test('a reference that drew nothing is dropped, not shown', () {
      final tally = KwicTally.of(
        referencesFetched: 110,
        lines: [_line('John 3:16')],
      );
      expect(tally.referencesShown, 1);
      expect(tally.referencesDropped, 109);
    });

    test('nothing drawn is all dropped', () {
      final tally = KwicTally.of(referencesFetched: 4, lines: const []);
      expect(tally.referencesShown, 0);
      expect(tally.lines, 0);
      expect(tally.referencesDropped, 4);
    });

    test('nothing fetched is not a negative drop', () {
      final tally = KwicTally.of(referencesFetched: 0, lines: const []);
      expect(tally.referencesDropped, 0);
    });

    test('a verse counted once however many times it carries the number',
        () {
      final tally = KwicTally.of(
        referencesFetched: 1,
        lines: [
          _line('John 3:16', hitIndex: 0),
          _line('John 3:16', hitIndex: 1),
          _line('John 3:16', hitIndex: 2),
        ],
      );
      expect(tally.referencesShown, 1);
      expect(tally.lines, 3);
      expect(tally.referencesDropped, 0);
    });
  });

  group('the pane no longer reports what it fetched', () {
    test('the completed footer does not print _totalRefs', () {
      final source =
          File('lib/widgets/kwic_pane.dart').readAsStringSync();
      expect(source.contains('KwicTally.of('), isTrue);
      expect(source.contains('kwicNotTagged'), isTrue);
      expect(source.contains('kwicLines'), isTrue);
      expect(source.contains('kwicHits'), isFalse);
      expect(source.contains(r'$_totalRefs '), isFalse);
    });

    test('kwicLines and kwicNotTagged carry all three locales', () {
      for (final key in ['kwicLines', 'kwicNotTagged']) {
        final entry = uiStrings[key];
        expect(entry, isNotNull, reason: '$key missing from uiStrings');
        for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
          expect(entry![locale], isNotNull, reason: '$key/$locale missing');
          expect(entry[locale], isNotEmpty, reason: '$key/$locale empty');
        }
      }
      expect(uiStrings.containsKey('kwicHits'), isFalse);
    });
  });
}
