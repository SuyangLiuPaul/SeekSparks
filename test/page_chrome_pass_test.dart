// 2026-08-08 (task #279): a ratchet for the thirteen-page chrome pass.
//
// #279 is not one change, it is thirteen — and the failure mode of a
// long pass is not that a page is missed, it is that a page already
// done quietly grows a rounded card back a week later. No widget test
// catches that: a `BorderRadius.circular(10)` renders perfectly, passes
// every assertion about behaviour, and is wrong only against a rule
// that lives in prose (`workbench_theme.dart`: *square corners and 1px
// hairline borders, no shadows, no cards*).
//
// So the rule is asserted about the SOURCE, the same species of
// invariant as `page_reachability_test.dart`. [_passed] is the pass's
// progress bar: a page joins it in the iteration that converts it, and
// can never silently leave.
//
// What this deliberately does NOT check is density. Padding, type size
// and line height are out of scope for #279 by the brief's own words —
// a page that wants to be read is allowed to breathe. Only the chrome
// (corners, borders, shadows) must match.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Files that have been through the chrome pass. Add, never remove.
const List<String> _passed = <String>[
  'lib/pages/stats_page.dart',
  'lib/pages/settings_page.dart',
  'lib/pages/evidence_page.dart',
  'lib/pages/evidence_detail_page.dart',
  'lib/pages/family_tree_page.dart',
  'lib/widgets/wb_surfaces.dart',
  // The family tree is not one file. `person_detail_sheet` is where the
  // tree round-trips to a verse, and `floating_toast` is the feedback it
  // shows on the way — a converted page behind an unconverted sheet is a
  // page that still has a rounded card in it.
  'lib/widgets/person_detail_sheet.dart',
  'lib/utils/floating_toast.dart',
  // The trivia page carries its own reader-side sheet
  // (`showBibleTriviaSheet`) and book-filter sheet in the same file, so
  // one entry covers all three surfaces.
  'lib/pages/bible_trivia_page.dart',
];

/// Strips `//` and `/* */` comments so prose about the rule — including
/// this file's own vocabulary — cannot fail the check it describes.
String _stripComments(String src) {
  final noBlock = src.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  return noBlock
      .split('\n')
      .map((line) {
        final i = line.indexOf('//');
        // Leave anything inside a string literal alone; a URL is the
        // realistic case ('https://…'), and a false strip there could
        // mask a real offender on the same line.
        if (i < 0) return line;
        final before = line.substring(0, i);
        final quotes = "'".allMatches(before).length +
            '"'.allMatches(before).length;
        return quotes.isEven ? before : line;
      })
      .join('\n');
}

void main() {
  group('#279 chrome pass', () {
    test('every page listed as passed still is', () {
      final offences = <String>[];

      for (final path in _passed) {
        final file = File(path);
        expect(file.existsSync(), isTrue,
            reason: '$path is on the passed list but does not exist. '
                'If it was deleted, remove it from _passed.');
        final src = _stripComments(file.readAsStringSync());
        final lines = src.split('\n');

        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final where = '$path:${i + 1}';
          if (line.contains('BorderRadius.circular(')) {
            offences.add('$where — rounded corner');
          }
          if (line.contains('BoxShadow(')) {
            offences.add('$where — shadow');
          }
          // `elevation: 0` is the rule being stated, not broken.
          final elev = RegExp(r'elevation:\s*([0-9.]+)').firstMatch(line);
          if (elev != null && double.parse(elev.group(1)!) > 0) {
            offences.add('$where — elevation ${elev.group(1)}');
          }
        }
      }

      expect(
        offences,
        isEmpty,
        reason: 'workbench_theme.dart: "Square corners and 1px hairline '
            'borders. No shadows, no cards." These pages have already '
            'been converted:\n  ${offences.join('\n  ')}',
      );
    });

    test('the list is a ratchet, not a snapshot', () {
      // Guards against the cheapest way to make the test above pass:
      // emptying the list. If a page is genuinely deleted, the sibling
      // test's existsSync assertion says so by name.
      expect(_passed.length, greaterThanOrEqualTo(3));
      expect(_passed.toSet().length, _passed.length,
          reason: 'duplicate entries');
    });
  });
}
