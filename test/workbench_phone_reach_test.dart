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

  /// The body of `_closePhoneOverlays`, which is what the bottom bar
  /// clears before it moves.
  String closeOverlays() {
    final start = src.indexOf('void _closePhoneOverlays() {');
    expect(start, isNot(-1),
        reason: 'the phone bar has nothing to clear the screen with');
    final end = src.indexOf('\n  }', start);
    return src.substring(start, end == -1 ? src.length : end);
  }

  test('choosing a destination clears what is standing in front of the '
      'panes', () {
    // 2026-09-14, from an iPhone with the chart open: 「手机上按这个按道理
    // 应该自动关闭这个画面」. The chart wins over the current tab — the
    // test above says it must — so without this the bottom bar is a dead
    // control while it is up: the tap moves `_phonePane` and the screen
    // does not change.
    expect(src, contains('_closePhoneOverlays();'),
        reason: 'the phone tab handler does not clear the screen');
    final tap = src.indexOf('onTap: () => setState(() {');
    expect(tap, isNot(-1));
    final handler = src.substring(tap, tap + 200);
    expect(handler.indexOf('_closePhoneOverlays()'),
        lessThan(handler.indexOf('_phonePane = pane')),
        reason: 'clear first, then move — the other order reads the same '
            'but invites a later edit to return between them');
  });

  test('everything that outranks the switch is something the bar can '
      'close', () {
    // The pairing, rather than one named field: any state that
    // short-circuits `_buildPhonePane` ahead of the three-way switch is
    // a screen the bottom bar cannot otherwise escape. Add a second one
    // and this fails until it joins `_closePhoneOverlays`.
    final body = phonePane();
    // Comments stripped first: this method's own note names `_openChart`
    // and `_closeChart` while explaining the history, and a rule that
    // reads prose cannot tell a mention from a use.
    final code = body
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    final head = code.substring(0, code.indexOf('switch (_phonePane)'));
    final fields = <String>{
      for (final m in RegExp(r'\b(_[a-z]\w*)\b').allMatches(head))
        m.group(1)!,
    }..removeWhere((f) =>
        // The frame builders it dispatches to, the width rule, and the
        // tab field itself — none of them are a screen to clear.
        f.startsWith('_build') || f == '_isThreePane' || f == '_phonePane');
    final cleared = closeOverlays();
    final missing = <String>[
      for (final f in fields)
        if (!cleared.contains(f)) f,
    ];
    expect(missing, isEmpty,
        reason: 'these decide what a phone shows before the tab does, and '
            'the bottom bar cannot clear them: ${missing.join(", ")}');
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
