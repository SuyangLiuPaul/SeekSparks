import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #314: the build version was printed twice on one screen — once in the
/// menu bar's trailing slot above 1200 px, once in the status bar.
///
/// A source-level ratchet rather than a widget test, and deliberately:
/// mounting `WorkbenchPage` needs the whole provider stack, and the
/// defect is not "a wrong pixel" but "a second call site exists". The
/// status bar's copy is the one that survives because it is tappable —
/// it opens `AboutPage` — where the menu bar's was inert text.
void main() {
  test('the workbench renders the build version in one place only', () {
    final src =
        File('lib/pages/workbench_page.dart').readAsStringSync().split('\n');

    final renders = <int>[];
    for (var i = 0; i < src.length; i++) {
      if (src[i].contains(r'v$kAppVersion') ||
          src[i].contains(r'SeekSparks $kAppVersion')) {
        renders.add(i + 1);
      }
    }

    // Two, and only two: the status bar, and the Help menu's line pairing
    // the Bible version with the build. A menu you deliberately open is
    // not a duplicate of a bar that is always on screen.
    expect(renders.length, 2,
        reason: 'expected the status bar and the Help menu entry only, '
            'found renders at lines $renders');
  });
}
