// 2026-09-08: every abbreviation can say what it stands for.
//
// Reported as 「BGT BSB 雅简这些别人看简写不知道什么意思，怎么有方式帮助
// users知道到底是什么版本呢全称」. The Browse gutter prints four-character
// tags because that is what a parallel view has room for — BGT, BSB,
// 雅简+, LXX+WH — and a reader who has not memorised the catalog had no
// way in from there. The full name was in `bibleVersions` the whole
// time; nothing put it within reach.
//
// Two halves, and the second is the one that matters on a tablet:
// `WbVersionTag` now carries a `Tooltip`, and it triggers on TAP as
// well as hover. A hover-only tooltip answers the question on a desktop
// and leaves it unanswered exactly where an unfamiliar reader is.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/bible_versions.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/widgets/workbench_chrome.dart';

void main() {
  group('fullBibleVersionLabel', () {
    test('every offered edition can name itself', () {
      // The point of the whole change: no edition a reader can pick may
      // answer with its own code, because the code is the thing they
      // could not read.
      for (final v in availableVersions) {
        final full = fullBibleVersionLabel(v.value);
        expect(full, isNot(v.value),
            reason: '${v.value} has no full name to show');
        expect(full.trim(), isNotEmpty);
        expect(full, isNot(shortBibleVersionLabel(v.value)),
            reason: '${v.value}: the long form repeats the short one, '
                'so the tooltip tells the reader nothing new');
      }
    });

    test('the year comes along when the catalog states one', () {
      // KJV is the case that has one; it is what makes "1611 / 1769
      // revision" reachable from a three-letter tag.
      expect(fullBibleVersionLabel('kjv'), contains('1611'));
      expect(fullBibleVersionLabel('kjv'), contains(menuBibleVersionLabel('kjv')));
    });

    test('an edition with no year is just its name', () {
      // Read from the catalog rather than named: the first version of
      // this test asserted it about the BSB, which turns out to carry
      // "2020 / public domain". Picking the subject by the property
      // under test cannot go stale when a row gains or loses a year.
      final yearless =
          availableVersions.where((v) => v.editionYear.isEmpty).toList();
      expect(yearless, isNotEmpty,
          reason: 'no offered edition lacks a year, so this test is '
              'asserting about an empty set');
      for (final v in yearless) {
        expect(fullBibleVersionLabel(v.value), v.menuLabel,
            reason: '${v.value} has no year, so the full name is the '
                'menu label and nothing else — no stray separator');
      }
    });

    test('an unknown code answers with itself rather than throwing', () {
      // An imported edition is not in the catalog and its code IS its
      // name — `user-xyz`. Falling through is right; throwing inside a
      // tooltip builder would take the pane down.
      expect(fullBibleVersionLabel('user-anything'), 'user-anything');
    });
  });

  testWidgets('the tag explains itself, by tap as well as hover',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppSettings(),
        child: MaterialApp(
          theme: workbenchTheme(ThemeData.light(useMaterial3: true)),
          home: const Scaffold(body: Center(child: WbVersionTag(code: 'bgt'))),
        ),
      ),
    );

    final tip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tip.message, fullBibleVersionLabel('bgt'));
    expect(tip.triggerMode, TooltipTriggerMode.tap,
        reason: 'hover-only would answer the question on a desktop and '
            'leave it unanswered on the iPad and the phone, which is '
            'where the reader who needs it actually is');

    // And the tag still prints the short form — the gutter is four
    // characters wide and this change must not have widened it.
    expect(find.text(shortBibleVersionLabel('bgt').toUpperCase()),
        findsOneWidget);
  });
}
