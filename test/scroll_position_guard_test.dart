/// `isAttached` IS NOT "CAN BE SCROLLED", and the difference is a live
/// prod crash.
///
///     Bad state: No element
///     Version 1.6.204   Platform web   Route /wheel
///
/// deobfuscated to `ScrollController.position` — `_positions.single` on
/// an empty list — reached from `ItemScrollController.scrollTo`. In
/// debug the framework asserts `_positions.isNotEmpty`; release
/// compiles the assertion out and `.single` throws instead, which is
/// the message the reader saw.
///
/// `isAttached` says only that a `ScrollablePositionedList` reached
/// `initState` and registered its controller. The scroll POSITION is
/// created by the `Scrollable` inside it, which lives under a
/// `LayoutBuilder` — so it exists only after LAYOUT. Between those two
/// moments there was normally no frame in which anything could call.
/// There is one now: a cold `#/wheel` boots the stack `[home, wheel]`,
/// the Overlay lays out only the entries above the last opaque one, and
/// the workbench underneath is BUILT — and keeps building, since a
/// descendant's `setState` needs no layout — while never being laid out.
///
/// `browse_window_offstage_scroll_test.dart` reproduces that state end
/// to end and pins the fix in `browse_window.dart`. What it cannot see
/// is the OTHER four call sites, which reach the same `scrollTo`
/// through `MainProvider`. This file pins those: that `canScrollList`
/// asks both halves of the question, and that every `scrollTo` in the
/// provider is behind it.
///
/// It reads the source rather than driving a widget on purpose. A
/// widget reproduction was written first and hung the runner — an
/// offstage `ScrollablePositionedList` never settles — and a test that
/// has to be killed is worth less than one that states the invariant
/// and runs in a millisecond. The behavioural half is already covered
/// by the file named above.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

late final String src;

void main() {
  setUpAll(() {
    src = File('lib/providers/main_provider.dart').readAsStringSync();
  });

  test('canScrollList asks both halves, not isAttached wearing a new name',
      () {
    expect(src, contains('bool get canScrollList'));
    final body = src.substring(src.indexOf('bool get canScrollList'));
    final decl = body.substring(0, body.indexOf(';'));
    expect(decl, contains('itemScrollController.isAttached'));
    expect(decl, contains('itemPositions.value.isNotEmpty'),
        reason: 'the guard no longer asks whether the list was laid out, '
            'which is the only half that would have caught the crash');
  });

  test('every scrollTo in the provider is behind that guard', () {
    // `scrollTo` is the throwing call. `jumpTo` is not — it iterates
    // `_positions` and no-ops on an empty one — which is exactly why
    // only some call sites ever crashed, and why the fix had to be a
    // shared question rather than a try/catch at each one.
    final calls =
        RegExp(r'itemScrollController\.scrollTo').allMatches(src).toList();
    expect(calls, isNotEmpty, reason: 'the calls this guards are gone; '
        'if that is deliberate, delete this test with them');
    for (final call in calls) {
      final before = src.substring(0, call.start);
      final guard = before.lastIndexOf('canScrollList');
      final bare = before.lastIndexOf('itemScrollController.isAttached)');
      expect(guard, greaterThan(bare),
          reason: 'a scrollTo at offset ${call.start} is guarded by '
              'isAttached alone');
    }
  });

  test('the reading pane goes through the same door', () {
    // Two call sites there reach `ItemScrollController.scrollTo`
    // directly rather than through the provider's helpers, so they need
    // the guard by name.
    final pane =
        File('lib/widgets/bible_reading_pane.dart').readAsStringSync();
    final direct =
        RegExp(r'itemScrollController\.scrollTo').allMatches(pane).toList();
    for (final call in direct) {
      final before = pane.substring(0, call.start);
      expect(before.lastIndexOf('canScrollList'),
          greaterThan(before.lastIndexOf('itemScrollController.isAttached')),
          reason: 'a scrollTo at offset ${call.start} in the reading pane '
              'is guarded by isAttached alone');
    }
  });
}
