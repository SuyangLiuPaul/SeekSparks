// 2026-08-25 (task #322): source ratchets on the Browse pane's three
// render paths.
//
// The ticket's complaint was that an untagged edition, a tagged edition
// and an originals row printed the verse reference three different ways,
// so a screen of five stacked editions had three different left edges
// for the verse text. `72a618f` fixed it by giving all three ONE row —
// `BrowseVerseRow` — and `440084e` fixed the width it is measured with.
//
// Neither fix has a test, and a widget test cannot supply one:
// `FetchVerses.loadVerseList` does not resolve under `flutter test`, so
// `browse_window_tagged_test.dart` never gets past the spinner and no
// verse text is ever laid out there. What made the defect possible is a
// property of the SOURCE — three call sites where there should be one —
// and reading the source can pin that.
//
// These are shape assertions and they are only worth what they claim:
// they prove the reference is built in exactly one place and measured
// with the same tracking it is painted with. They do not prove the
// column is straight on screen. `browse_reference_real_font_test.dart`
// measures that in the shipped faces; a human looked at it on
// 2026-08-25 (v1.6.177, Traditional Chinese + Hebrew, the thinnest
// margin the model has).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final String source =
      File('lib/widgets/browse_window.dart').readAsStringSync();

  int count(String needle) => needle.allMatches(source).length;

  /// The file with its comment lines removed, for assertions about what
  /// the code does rather than what it says about itself.
  final String code = source
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  group('browse_window.dart keeps one reference column', () {
    test('the file under test is the one we think it is', () {
      expect(source.length, greaterThan(40000));
      expect(source, contains('class BrowseVerseRow extends StatelessWidget'));
      expect(source, contains('const double kBrowseReferenceLetterSpacing'));
    });

    test('every render path is built by the same row widget', () {
      // One constructor declaration plus exactly one construction. A
      // second construction means a path has grown its own row again,
      // which is the shape the ticket reported.
      final constructions =
          count('BrowseVerseRow(') - count('const BrowseVerseRow({');
      expect(constructions, 1,
          reason: 'the untagged, tagged and originals paths share one '
              'BrowseVerseRow; a second call site is a fourth left edge');
    });

    test('the reference is never a span of the verse line', () {
      // Before 72a618f the untagged path made the reference the first
      // span of a single `Text.rich`, so it took part in line-breaking:
      // line one began after the reference and every wrapped line began
      // under it. Interpolating or spanning it puts it back inside the
      // text flow.
      expect(source.contains(r'${row.reference}'), isFalse);
      expect(source.contains('TextSpan(text: row.reference'), isFalse);
      expect(source.contains('text: row.reference'), isFalse);
    });

    test('the two fixed columns are each measured exactly once', () {
      // Per chapter, from the editions actually on screen, and handed
      // down to every row. A second call is a row measuring itself.
      expect(count('referenceGutterWidth('), 1);
      expect(count('versionGutterWidth('), 1);
    });

    test('the reference is measured with the tracking it is painted with',
        () {
      // 440084e. The reference `Text` inherited `bodyMedium`'s 0.25 while
      // the width model charged none, so the painted string ran
      // `runes.length * 0.25` px wider than its box — absorbed by the
      // 8 px gap, one constant covering another's mistake. Both sides now
      // name the same constant, and neither may go back to a literal.
      final spacingArgs =
          count('letterSpacing: kBrowseReferenceLetterSpacing');
      expect(spacingArgs, 2,
          reason: 'one for referenceGutterWidth (measure), one for '
              'referenceStyle (paint)');
      expect(RegExp(r'letterSpacing:\s*[\d.]').hasMatch(code), isFalse,
          reason: 'a literal here is a number that can drift from the '
              'other side of the pair');
    });

    test('the superscription is indented by the same measured width', () {
      // A psalm title is text, and it sits in the same text column. It
      // is the one thing outside BrowseVerseRow that has to agree with
      // it, so it reads the identical value rather than a copy.
      expect(source, contains('EdgeInsets.only(left: referenceWidth)'));
    });

    test('the row is built by _RowView, above every RTL scope', () {
      // A Hebrew row wraps its words in `Directionality`. With the
      // reference inside that scope it flies to the right-hand edge and
      // the column of references stops being a column. The row is
      // therefore built by the shared `_RowView` and handed the line
      // widget as a child — never built by the line widget itself.
      final site = source.indexOf('BrowseVerseRow(\n');
      expect(site, greaterThan(0));
      final owner = source.lastIndexOf(RegExp(r'^class \w+', multiLine: true),
          site);
      expect(source.substring(owner).split('\n').first, 'class _RowView '
          'extends StatelessWidget {');
      expect(source.indexOf('TextDirection.rtl'), greaterThan(site),
          reason: 'every Directionality scope in this file must come '
              'after the one row that owns the reference');
    });
  });
}
