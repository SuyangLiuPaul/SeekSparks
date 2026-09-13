import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Everything the wide workbench can show, a phone can show too.
///
/// 2026-09-14, owner-reported from an iPhone: 「手机上按了这些没有反应，
/// 不像 iPad browser 看到中间那一部分」, said of the word-distribution
/// strips in the Analysis pane. Tapping one called `_openChart`, which
/// set `_chartStrongs` and rebuilt the page — and `_buildPhonePane` did
/// not read that field. The state changed, the screen did not.
///
/// The reader's own words locate the defect exactly: on a wide screen
/// the chart opens in the CENTRE pane, and a phone draws no centre
/// pane. Five of the six `_build*Frame` surfaces were reachable from
/// the phone's three-way switch; the chart was the one that was not.
///
/// This is the ratchet for the next one. A frame is a whole surface of
/// the app, and "the phone layout forgot it" is not a thing anybody
/// notices until a reader on a phone taps something and nothing
/// happens.
void main() {
  final src = File('lib/pages/workbench_page.dart').readAsStringSync();

  /// Every `_build…Frame` method the page declares.
  Set<String> declaredFrames() => {
        for (final m in RegExp(r'Widget (_build\w*Frame)\(').allMatches(src))
          m.group(1)!,
      };

  /// The body of `_buildPhonePane`, which is the whole of what a narrow
  /// screen can reach.
  String phonePane() {
    final start = src.indexOf('Widget _buildPhonePane(');
    expect(start, isNot(-1), reason: 'the phone layout has been renamed');
    // To the next method declaration at the same indent.
    final end = src.indexOf('\n  /// ', start);
    return src.substring(start, end == -1 ? src.length : end);
  }

  test('the page still has the frames this rule is about', () {
    // If this drops to nothing the rest of the file is vacuously true.
    expect(declaredFrames(), hasLength(greaterThanOrEqualTo(6)));
    expect(declaredFrames(), contains('_buildChartFrame'));
  });

  test('every frame is reachable from a phone', () {
    final body = phonePane();
    final unreachable = <String>[
      for (final frame in declaredFrames())
        if (!body.contains(frame)) frame,
    ];
    expect(unreachable, isEmpty,
        reason: 'a phone cannot reach ${unreachable.join(", ")}. A reader '
            'on that screen taps the control that opens it and nothing '
            'happens — which is how the word chart was lost.');
  });

  test('the chart is checked BEFORE the three-way switch', () {
    // Same order the wide layout uses: the chart replaces the centre
    // rather than living inside one of the three tabs. Checking it
    // after the switch would mean the Analyse tab keeps drawing itself
    // over the chart the reader just asked for.
    final body = phonePane();
    expect(body.indexOf('_buildChartFrame'),
        lessThan(body.indexOf('switch (_phonePane)')),
        reason: 'the chart must win over the current phone tab');
  });
}
