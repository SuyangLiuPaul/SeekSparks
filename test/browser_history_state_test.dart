/// 2026-08-08, task #296: the production "Null check operator used on a
/// null value".
///
/// Reported by a reader on prod v1.6.65 (iOS 18.7 Safari, 440x956,
/// zh-Hans, route `/`, top frame `main.dart.js:49661:2`) and reproduced
/// against the deployed bundle: line 49661 of prod's `main.dart.js` is
/// `n.toString`, dart2js's null-assert, inside
/// `MultiEntriesBrowserHistory.tearDown` — `currentState! as Map` at
/// `flutter_web_sdk/lib/_engine/engine/navigation/history.dart:225`.
///
/// The engine's teardown rewinds the browser `serialCount` entries and
/// then reads the state of whatever entry it landed on, asserting
/// non-null. `serialCount` survives a page load, so a count inherited
/// from a *previous* document sends the rewind into entries the engine
/// never tagged. The engine's own assert two lines up calls this
/// "unexpected null history state" — in a release build the assert is
/// stripped and the `!` is what the reader sees.
///
/// Nothing in `flutter test` can reach this: the code lives in
/// `url_sync_service_web.dart` behind a `dart.library.js_interop`
/// import, and 1,879 green tests ran alongside the bug for months. So
/// the decisions are pulled out into a pure function that a VM test can
/// drive, and the one line that cannot be is held by a source ratchet.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/utils/history_state_repair.dart';

void main() {
  group('repairedBootHistoryState leaves alone what it should', () {
    test('a document with no history state at all', () {
      expect(repairedBootHistoryState(null), isNull);
    });

    test('a state that is not a map, however odd', () {
      // `history.state` is whatever anything on the page last wrote, and
      // a structured clone can be a primitive. Reading `['serialCount']`
      // off one would throw inside the boot path, which is worse than
      // the bug being fixed.
      for (final Object weird in <Object>['flutter', 7, 3.5, true]) {
        expect(repairedBootHistoryState(weird), isNull,
            reason: '$weird is not the engine shape and must be ignored');
      }
      expect(repairedBootHistoryState(<Object?>['a', 'b']), isNull);
    });

    test('a map with no serialCount — not multi-entry bookkeeping', () {
      expect(repairedBootHistoryState(<Object?, Object?>{}), isNull);
      expect(
        repairedBootHistoryState(<Object?, Object?>{'seeksparks': true}),
        isNull,
      );
    });

    test('the engine single-entry shapes, which must not be touched', () {
      // These two select `SingleEntryBrowserHistory` in
      // `createHistoryForExistingState`, which never rewinds and never
      // reaches the null check. Rewriting them would push a healthy boot
      // into the multi-entry path — turning the fix into the bug.
      expect(
        repairedBootHistoryState(<Object?, Object?>{'flutter': true}),
        isNull,
      );
      expect(
        repairedBootHistoryState(
          <Object?, Object?>{'origin': true, 'state': null},
        ),
        isNull,
      );
    });

    test('a count of zero is already harmless', () {
      // This is what the engine writes for itself on a healthy boot.
      // Rewriting it would be a pointless `replaceState` on every load.
      expect(
        repairedBootHistoryState(
          <Object?, Object?>{'serialCount': 0, 'state': null},
        ),
        isNull,
      );
      expect(
        repairedBootHistoryState(
          <Object?, Object?>{'serialCount': 0.0, 'state': null},
        ),
        isNull,
      );
    });

    test('a negative count, which no engine writes', () {
      expect(
        repairedBootHistoryState(<Object?, Object?>{'serialCount': -2}),
        isNull,
      );
    });
  });

  group('repairedBootHistoryState disarms an inherited count', () {
    test('the count is reset, so teardown rewinds nothing', () {
      final Map<Object?, Object?>? out = repairedBootHistoryState(
        <Object?, Object?>{'serialCount': 3, 'state': null},
      );

      expect(out, isNotNull);
      expect(out!['serialCount'], 0,
          reason: 'zero is what makes `if (backCount > 0)` false, which '
              'is the single step that keeps the rewind — and therefore '
              'the null dereference — from happening at all');
    });

    test('serialCount stays PRESENT, not deleted', () {
      // Deleting the key would be the obvious "clean" move and it would
      // reintroduce the crash by a different door: `_hasSerialCount`
      // would go false, `_currentSerialCount` would return 0 without the
      // engine ever having tagged this entry, and the state the null
      // check reads would be whatever was already there — which is the
      // null we are removing.
      final Map<Object?, Object?>? out = repairedBootHistoryState(
        <Object?, Object?>{'serialCount': 5, 'state': null},
      );

      expect(out!.containsKey('serialCount'), isTrue);
      expect(out['serialCount'], isNotNull,
          reason: '_hasSerialCount tests for a non-null value, not a key');
    });

    test('a double count, which is what the engine actually writes', () {
      // `_tagWithSerialCount` stores `count.toDouble()`, and reads it
      // back with `as double`. A repair that wrote an int where a double
      // was expected would crash a different line of the same function.
      final Map<Object?, Object?>? out = repairedBootHistoryState(
        <Object?, Object?>{'serialCount': 4.0, 'state': null},
      );

      expect(out, isNotNull);
      expect(out!['serialCount'], 0);
    });

    test('the framework payload under `state` is carried across', () {
      // That key holds the route state the framework asked to store. It
      // has nothing to do with the crash, and dropping it would lose a
      // reader's restored position to fix an unrelated bug.
      final Map<Object?, Object?> payload = <Object?, Object?>{
        'location': '/john/1:3',
        'state': null,
      };

      final Map<Object?, Object?>? out = repairedBootHistoryState(
        <Object?, Object?>{'serialCount': 9, 'state': payload},
      );

      expect(out!['state'], same(payload));
    });

    test('the input is not mutated in place', () {
      // `history.state` hands back a fresh structured clone each read, so
      // mutating it would be invisible until something read the clone
      // twice and saw two different answers.
      final Map<Object?, Object?> input = <Object?, Object?>{
        'serialCount': 2,
        'state': null,
      };

      repairedBootHistoryState(input);

      expect(input['serialCount'], 2);
    });
  });

  group('the state written onto entries the app pushes itself', () {
    test('is non-null, which is the entire point', () {
      // Both teardowns dereference the state of the entry they land on.
      // An app-pushed entry carrying null is a landing spot that crashes
      // the engine, and until today every chapter change created one.
      expect(kAppHistoryEntryState, isNotNull);
      expect(kAppHistoryEntryState, isNotEmpty);
    });

    test('is a Map, because the null check is followed by a cast', () {
      // `currentState! as Map<dynamic, dynamic>` — surviving the `!` with
      // a string would only move the crash one operator to the right.
      expect(kAppHistoryEntryState, isA<Map<String, Object?>>());
    });

    test('does not impersonate the engine flutter or origin entry', () {
      // `onPopState` branches on these tags and each branch treats the
      // back button differently. Borrowing one would silently change
      // navigation while claiming to be a null-safety fix.
      expect(kAppHistoryEntryState.containsKey('flutter'), isFalse);
      expect(kAppHistoryEntryState.containsKey('origin'), isFalse);
      expect(kAppHistoryEntryState.containsKey('serialCount'), isFalse,
          reason: 'a serialCount here would make our own entries look '
              'like multi-entry bookkeeping to the next boot');
    });
  });

  group('source ratchet on the web-only file', () {
    // `url_sync_service_web.dart` imports `dart:js_interop`, so it is
    // never compiled into a VM test run and cannot be asserted on any
    // other way. These read it as text.
    final String source =
        File('lib/services/url_sync_service_web.dart').readAsStringSync();

    test('the file under test is the one we think it is', () {
      // Guards against the ratchets below passing because a rename made
      // the file empty or the path wrong.
      expect(source.length, greaterThan(4000));
      expect(source, contains('_writeStateToUrl'));
    });

    test('no history entry is pushed with a null state', () {
      expect(source.contains('pushState(null'), isFalse,
          reason: 'a null state is the crash: the engine dereferences the '
              'state of whatever entry its teardown lands on. Push '
              'kAppHistoryEntryState instead.');
    });

    test('the boot repair is wired to the shared decision', () {
      expect(source, contains('repairedBootHistoryState'));
      expect(source, contains('repairBootHistoryState'));
    });

    test('main() calls the repair before the first frame', () {
      // The engine builds its history object lazily, on the first
      // navigation message, which the root navigator sends during the
      // first frame. A repair that ran after that would read a state the
      // engine had already acted on.
      final String main = File('lib/main.dart').readAsStringSync();

      expect(main, contains('UrlSyncService.repairBootHistoryState()'));

      final int repair =
          main.indexOf('UrlSyncService.repairBootHistoryState()');
      final int runApp = main.indexOf('runApp(');
      expect(repair, greaterThan(0));
      expect(runApp, greaterThan(0));
      expect(repair, lessThan(runApp),
          reason: 'the repair has to beat the first frame');
    });

    test('every platform offers the same entry point', () {
      // The conditional import means a method missing from the stub only
      // fails on a native build, which this project does not run in CI.
      expect(
        File('lib/services/url_sync_service_stub.dart').readAsStringSync(),
        contains('void repairBootHistoryState()'),
      );
      expect(
        File('lib/services/url_sync_service.dart').readAsStringSync(),
        contains('repairBootHistoryState'),
      );
    });
  });
}
