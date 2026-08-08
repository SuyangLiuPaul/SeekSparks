// 2026-08-09 (task #284): source ratchets on the Word Study tab.
//
// `OriginalsSheet` is 2700 lines with ~30 independent styling sites.
// A widget test can only reach the handful of them the fixture data
// happens to render, so the guarantee "the docked pane has no rounded
// corners" is not something a widget test can actually assert. Reading
// the source can: a literal `BorderRadius.circular` is, by construction,
// a corner that stays rounded in the workbench no matter which
// presentation is being built.
//
// The same argument applies to the header. The defect #284 fixed was
// that `workbench_page.dart` skipped `WbPaneTitle` for the word-study
// tab — so the pane's title and collapse chevron appeared and vanished
// as the pointer moved between a word and a verse. That the title is
// now unconditional is a property of one `if`, and pinning the `if` is
// cheaper and clearer than pumping the whole workbench.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('originals_sheet.dart resolves its style rather than hardcoding it',
      () {
    final String source =
        File('lib/widgets/originals_sheet.dart').readAsStringSync();

    test('the file under test is the one we think it is', () {
      expect(source.length, greaterThan(60000));
      expect(source, contains('WordStudyStyle.resolve('));
    });

    test('no literal corner radius survives outside the modal-only sheet', () {
      // The one permitted exception is marked `modal-only:` in the
      // comment block directly above it, because the distribution table
      // is always a bottom sheet and never the docked pane.
      final lines = source.split('\n');
      final offenders = <String>[];
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('BorderRadius.circular(')) continue;
        var exempt = false;
        for (var j = i - 1; j >= 0 && lines[j].trimLeft().startsWith('//'); j--) {
          if (lines[j].contains('modal-only:')) exempt = true;
        }
        if (!exempt) offenders.add('${i + 1}: ${lines[i].trim()}');
      }
      expect(offenders, isEmpty,
          reason: 'workbench_theme.dart:16 asks for square corners. Route '
              'these through WordStudyStyle.r(), which returns '
              'BorderRadius.zero when docked:\n${offenders.join('\n')}');
    });

    test('the CBOL attribution the licence requires is still printed', () {
      // CC-BY-NC-SA 4.0. Losing this in a restyle is a licence breach,
      // not a cosmetic regression, so it gets its own guard.
      expect(source, contains('bible.fhl.net (CC-BY-NC-SA 4.0)'));
      expect(source, contains('中文释义来源'));
      expect(source, contains('中文釋義來源'));
    });

    test('the docked pane no longer draws its own sheet header', () {
      // The pane owns the title strip now; a second header inside the
      // scroll body is the double-chrome #284 removed.
      expect(source.contains('onCollapse'), isFalse,
          reason: 'collapse belongs to WbPaneTitle, not to the sheet');
    });
  });

  group('workbench_page.dart gives the analysis pane a permanent title', () {
    final String source =
        File('lib/pages/workbench_page.dart').readAsStringSync();

    test('the file under test is the one we think it is', () {
      expect(source, contains('AnalysisTabStrip('));
      expect(source, contains('OriginalsSheet('));
    });

    test('the title strip is not conditional on the selected tab', () {
      expect(source.contains('needsHeader'), isFalse,
          reason: 'the pane title and its collapse chevron must not appear '
              'and vanish as the pointer moves between a word and a verse');
    });

    test('the word study is still embedded, not a modal', () {
      expect(source, contains('embedded: true'));
    });
  });
}
