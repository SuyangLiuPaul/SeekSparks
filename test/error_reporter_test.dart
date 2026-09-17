/// 2026-05-24 (v1.3.23): regression tests for ErrorReporter's
library;
//
/// in-memory state. The reporter is mostly side-effects (HTTP POST,
/// global hooks) but the breadcrumb ring + route/locale tracking +
/// payload-cap helper are pure logic and worth locking in so a
/// future refactor can't silently break the visibility we just
/// shipped in v1.3.21.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/services/error_reporter.dart';
import 'package:seeksparks/services/error_reporter_platform_io.dart'
    as platform;

void main() {
  setUp(() {
    ErrorReporter.resetForTest();
  });

  group('breadcrumb ring buffer', () {
    test('starts empty after reset', () {
      expect(ErrorReporter.breadcrumbsForTest, isEmpty);
    });

    test('breadcrumb() appends one entry', () {
      ErrorReporter.breadcrumb('nav:push', data: 'Dashboard');
      final crumbs = ErrorReporter.breadcrumbsForTest;
      expect(crumbs, hasLength(1));
      expect(crumbs.first.action, 'nav:push');
      expect(crumbs.first.data, 'Dashboard');
      expect(crumbs.first.timestamp, isA<DateTime>());
    });

    test('breadcrumb() preserves insertion order', () {
      ErrorReporter.breadcrumb('one');
      ErrorReporter.breadcrumb('two');
      ErrorReporter.breadcrumb('three');
      final actions =
          ErrorReporter.breadcrumbsForTest.map((b) => b.action).toList();
      expect(actions, ['one', 'two', 'three']);
    });

    test('breadcrumb() caps the ring at 10 entries (oldest evicted)', () {
      // Push 15 entries; expect only the last 10 to remain.
      for (var i = 0; i < 15; i++) {
        ErrorReporter.breadcrumb('action $i');
      }
      final crumbs = ErrorReporter.breadcrumbsForTest;
      expect(crumbs, hasLength(10));
      // The FIRST surviving entry should be the 6th push (index 5)
      // since 0..4 were evicted.
      expect(crumbs.first.action, 'action 5');
      expect(crumbs.last.action, 'action 14');
    });

    test('breadcrumb() accepts null data (and stores null, not "")', () {
      ErrorReporter.breadcrumb('memory:pressure');
      expect(ErrorReporter.breadcrumbsForTest.single.data, isNull);
    });

    test('breadcrumb timestamps are UTC + monotonically non-decreasing', () {
      ErrorReporter.breadcrumb('one');
      ErrorReporter.breadcrumb('two');
      final crumbs = ErrorReporter.breadcrumbsForTest;
      expect(crumbs[0].timestamp.isUtc, isTrue);
      expect(crumbs[1].timestamp.isUtc, isTrue);
      expect(
        crumbs[1].timestamp.isAtSameMomentAs(crumbs[0].timestamp) ||
            crumbs[1].timestamp.isAfter(crumbs[0].timestamp),
        isTrue,
      );
    });
  });

  group('route tracking', () {
    test('starts empty after reset', () {
      expect(ErrorReporter.currentRouteForTest, isEmpty);
    });

    test('setCurrentRoute() stores the value', () {
      ErrorReporter.setCurrentRoute('/HomePage');
      expect(ErrorReporter.currentRouteForTest, '/HomePage');
    });

    test('setCurrentRoute(null) clears to empty string', () {
      ErrorReporter.setCurrentRoute('/HomePage');
      ErrorReporter.setCurrentRoute(null);
      expect(ErrorReporter.currentRouteForTest, isEmpty);
    });

    test('setCurrentRoute() overwrites previous value', () {
      ErrorReporter.setCurrentRoute('/A');
      ErrorReporter.setCurrentRoute('/B');
      expect(ErrorReporter.currentRouteForTest, '/B');
    });
  });

  group('locale tracking', () {
    test('defaults to "en" after reset', () {
      expect(ErrorReporter.appLocaleForTest, 'en');
    });

    test('setLocale() stores the value', () {
      ErrorReporter.setLocale('zh-Hans');
      expect(ErrorReporter.appLocaleForTest, 'zh-Hans');
    });

    test('setLocale() round-trips both supported variants', () {
      ErrorReporter.setLocale('zh-Hant');
      expect(ErrorReporter.appLocaleForTest, 'zh-Hant');
      ErrorReporter.setLocale('en');
      expect(ErrorReporter.appLocaleForTest, 'en');
    });
  });

  group('payload-cap helper (_trim via trimForTest)', () {
    test('passes through strings shorter than the cap', () {
      expect(ErrorReporter.trimForTest('abc', 10), 'abc');
    });

    test('passes through strings exactly at the cap', () {
      expect(ErrorReporter.trimForTest('abcdefghij', 10), 'abcdefghij');
    });

    test('truncates strings longer than the cap', () {
      expect(
          ErrorReporter.trimForTest('abcdefghijklmno', 10), 'abcdefghij');
    });

    test('handles empty string', () {
      expect(ErrorReporter.trimForTest('', 10), '');
    });

    test('handles cap of 0', () {
      expect(ErrorReporter.trimForTest('abc', 0), '');
    });

    test('handles unicode (counts code units, matches Dart .length)', () {
      // Each CJK BMP character is 1 UTF-16 code unit in Dart, so
      // '你好世界'.length == 4. With cap=2 we expect the first two
      // characters '你好' (not '你' — see issue if we ever try to
      // store a 4-byte emoji that takes 2 code units; today the
      // reporter doesn't care).
      expect(ErrorReporter.trimForTest('你好世界', 2), '你好');
      // 4-byte emoji ("🎉" is U+1F389 = 2 code units). With cap=1
      // we'd cleave the surrogate pair — Dart strings tolerate
      // that but the resulting char is invalid. The reporter
      // doesn't try to be smart here; it documents the behavior.
      // We just check the length is correct.
      expect(ErrorReporter.trimForTest('🎉🎊', 2).length, 2);
    });
  });

  group('report() best-effort guarantee', () {
    test('does not throw when network is unavailable / no endpoint', () {
      // The reporter's contract: NEVER throw back into the caller.
      // With no init() / overrideEndpoint, the POST will time out
      // and the catch swallows it silently. We just verify no
      // exception escapes.
      expect(
        () => ErrorReporter.report(
          Exception('test'),
          StackTrace.current,
          source: 'test',
        ),
        returnsNormally,
      );
    });
  });

  group('benign-noise filter (v1.3.x)', () {
    test('drops CanvasKit getParameter WebGL failure on iOS Chrome', () {
      // Real reported shape (v1.3.49 web, CriOS): a TypeError thrown
      // from canvaskit.js MakeWebGLContext. App falls back to CPU
      // rendering — nothing to fix, so it must not be reported.
      const err = 'TypeError: getParameter is not a function';
      const stack = 'at WebGLRenderingContext.getParameter\n'
          'at canvaskit.js … MakeWebGLContext';
      expect(ErrorReporter.isIgnorableNoiseForTest(err, stack), isTrue);
    });

    test('drops match found only in the stack, not the message', () {
      expect(
        ErrorReporter.isIgnorableNoiseForTest(
            'Error', 'a.MakeWebGLContext (canvaskit.js:16)'),
        isTrue,
      );
    });

    test('reports a font-load failure instead of dropping it', () {
      // v1.6.62 removed `google_fonts`, and with it the two patterns
      // that swallowed fonts.gstatic.com failures. Every face the app
      // can select is now a bundled asset, so a font that fails to
      // load is a broken build, not an unreachable CDN — it must
      // reach the inbox.
      const err = 'Exception: Failed to load font with url '
          'https://fonts.gstatic.com/s/a/5ced104582: '
          'ClientException with SocketException';
      const stack = '#0 _httpFetchFontAndSaveToDevice '
          '(package:google_fonts/src/google_fonts_base.dart:268)';
      expect(ErrorReporter.isIgnorableNoiseForTest(err, stack), isFalse);
    });

    test('keeps genuine app errors', () {
      expect(
        ErrorReporter.isIgnorableNoiseForTest(
            'RangeError: index out of range', '#0 List.[] dart:core'),
        isFalse,
      );
      expect(
        ErrorReporter.isIgnorableNoiseForTest(
            'set failed: value argument contains an invalid key', ''),
        isFalse,
      );
    });
  });

  // 2026-08-08: two prod reports from v1.6.65 the same day — an iPhone on
  // iOS Safari and a Mac on Chrome — both `source: Zone`, both "Null check
  // operator used on a null value", the second carrying the JS beneath it:
  // `TypeError: Cannot read properties of null (reading 'toString')`.
  //
  // `runZonedGuarded`'s handler is typed `(Object, StackTrace)`, so Dart
  // says neither can be null; dart2js elides that check in release and a
  // null stack reached `.toString()`. The reporter then threw WHILE
  // reporting, which destroyed the original error and replaced it with its
  // own — so every Zone error carrying a null stack arrived as the same
  // meaningless message.
  //
  // These cannot fail on the VM the way they failed on the web, because
  // the VM enforces the types. What they pin is that the signature STAYS
  // nullable and that nothing here throws: tightening `report` back to
  // non-nullable parameters would not compile against them.
  group('report() survives what the web actually hands it', () {
    test('a null stack does not throw', () {
      expect(
          () => ErrorReporter.report(Exception('boom'), null), returnsNormally);
    });

    test('a null error does not throw', () {
      expect(() => ErrorReporter.report(null, StackTrace.current),
          returnsNormally);
    });

    test('both null does not throw', () {
      expect(
          () => ErrorReporter.report(null, null, source: 'Zone'),
          returnsNormally);
    });

    test('an object whose toString() throws does not take the reporter with it',
        () {
      expect(() => ErrorReporter.report(_HostileToString(), null),
          returnsNormally);
    });
  });

  group('a test run never reaches the network', () {
    // 2026-09-18, in the owner's inbox: "Exception: boom", source
    // `manual`, version 1.6.314, platform linux, screen 800x600, an
    // Azure IP — a GitHub runner. That is the group above, proving
    // `report()` survives a null stack by mailing the proof to a human.
    //
    // The endpoint resolves to the production host on native, so every
    // CI run that touched the reporter sent a real email. The guard
    // lives in `_postSafely`, not in these tests, because the next test
    // to call `report()` would not know to opt out — and would not fail
    // when it forgot.
    test('the native shim knows it is being tested', () {
      expect(platform.isTestRun, isTrue,
          reason: 'this IS a test run; if the shim cannot tell, the '
              'reporter posts from CI again');
    });

    test('the guard is in the poster, before the request is built', () {
      final src = File('lib/services/error_reporter.dart').readAsStringSync();
      final poster = src.substring(src.indexOf('_postSafely('));
      expect(poster.contains('if (platform.isTestRun) return;'), isTrue,
          reason: 'the reporter can post from a test again');
      expect(poster.indexOf('if (platform.isTestRun) return;'),
          lessThan(poster.indexOf('http')),
          reason: 'the guard must come before the request');
    });
  });
}

/// The reporter receives arbitrary thrown objects, and one whose own
/// `toString()` fails is exactly the kind that ends up there.
class _HostileToString {
  @override
  String toString() => throw StateError('toString() itself throws');
}
