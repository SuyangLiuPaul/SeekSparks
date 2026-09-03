import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/url_claim.dart';

/// The two rules pulled out of `url_sync_service_web.dart`, which no
/// test can import (`dart:js_interop`). Both were written from a defect
/// reproduced in a browser on dev v1.6.220; the reproduction is below.
void main() {
  group('urlMayDriveReader', () {
    test('a page path is never a passage, at boot or after it', () {
      for (final boot in [true, false]) {
        expect(
            urlMayDriveReader(
                path: '/wheel', isBoot: boot, claimedPath: null),
            isFalse);
        // Matched by PAGE, not by the literal `/wheel` this used to
        // compare against, so a query string is still the wheel.
        expect(
            urlMayDriveReader(
                path: '/wheel?year=-4000', isBoot: boot, claimedPath: null),
            isFalse);
      }
    });

    test('an ordinary reader link drives the reader', () {
      expect(
          urlMayDriveReader(
              path: '/genesis/1?v=bsb', isBoot: false, claimedPath: null),
          isTrue);
    });

    test('but not while a page owns the address bar', () {
      // THE BROWSER REPRODUCTION, dev v1.6.220, in one line. Wheel open
      // (claim `/wheel`), reader pressed Back: popstate arrives with the
      // history entry from UNDERNEATH the wheel. Applying it moved the
      // reader behind a page still on screen, on a Back whose only job
      // was to close that page.
      expect(
          urlMayDriveReader(
              path: '/genesis/1?v=bsb', isBoot: false, claimedPath: '/wheel'),
          isFalse);
    });

    test('a BOOT deep link is never refused by a claim', () {
      // Nothing has claimed at boot, so this cannot happen today. It is
      // asserted because the boot apply is the one apply that must not
      // become droppable if that ever stops being true: a dropped boot
      // link is a shared link that opens on the wrong chapter.
      expect(
          urlMayDriveReader(
              path: '/genesis/1?v=bsb', isBoot: true, claimedPath: '/wheel'),
          isTrue);
    });
  });

  group('UrlClaim', () {
    test('claim and release, one owner', () {
      final c = UrlClaim();
      final page = Object();
      expect(c.set('/wheel', owner: page), isTrue);
      expect(c.path, '/wheel');
      // Re-claiming what it already holds is not a change, so the caller
      // does not rewrite the URL for it.
      expect(c.set('/wheel', owner: page), isFalse);
      expect(c.set(null, owner: page), isTrue);
      expect(c.path, isNull);
      expect(c.set(null, owner: page), isFalse);
    });

    test('a superseded page cannot release the claim it no longer holds',
        () {
      // THE ORDERING THIS CLASS EXISTS FOR. Flutter disposes a closing
      // route AFTER the next route's initState, so Back-then-forward on
      // the wheel runs: B claims, then A's dispose releases. Before the
      // owner check that left the claim null with a wheel on screen, and
      // the next debounced write put `#/genesis/1?v=bsb` in the address
      // bar underneath the open wheel — which is what the browser showed
      // on dev v1.6.220.
      final c = UrlClaim();
      final wheelA = Object();
      final wheelB = Object();
      c.set('/wheel', owner: wheelA);
      expect(c.set('/wheel', owner: wheelB), isTrue,
          reason: 'a hand-off moves the owner even at the same path');
      expect(c.set(null, owner: wheelA), isFalse,
          reason: 'A is gone; its release must not clear B\'s claim');
      expect(c.path, '/wheel');
      // And B can still release its own.
      expect(c.set(null, owner: wheelB), isTrue);
      expect(c.path, isNull);
    });

    test('an unscoped release still clears, as it always did', () {
      final c = UrlClaim();
      c.set('/wheel', owner: Object());
      expect(c.set(null), isTrue);
      expect(c.path, isNull);
    });
  });

  group('urlNeedsRewrite', () {
    test('an address bar that already says it is not written again', () {
      expect(
          urlNeedsRewrite(
              want: '#/john/3?v=bsb', liveHash: '#/john/3?v=bsb'),
          isFalse);
    });

    test('a blanked fragment is always rewritten', () {
      // THE BROWSER REPRODUCTION, dev v1.6.223. The engine reports the
      // framework's initial route as `/`, and
      // `HashUrlStrategy.prepareExternalUrl('/')` returns the path and
      // query with NO `#`, so `replaceState({flutter: true}, '/')`
      // strips a shared link's fragment at 1.5 s — before the splash
      // clears. Traced again 1 ms after browser Back, when
      // `BrowserRouteObserver` answers it with `maybePop()` and the
      // Navigator reports the root route underneath.
      expect(urlNeedsRewrite(want: '#/john/3?v=bsb', liveHash: ''), isTrue);
    });

    test('THE R1 REGRESSION: the memory said written, the address bar '
        'said empty', () {
      // What the old gate compared, spelled out so reverting to it fails
      // here and only here. `_applyHashToState` recorded the boot hash
      // as written; the engine then blanked the fragment; the next write
      // computed the very same string — so under `want != lastWritten`
      // this was FALSE and the write was skipped, leaving the address
      // bar empty for the rest of the session. Measured at 40 s and
      // counting after a cold `#/john/3?v=bsb`, three runs.
      const want = '#/john/3?v=bsb';
      const lastWritten = '#/john/3?v=bsb';
      expect(want != lastWritten, isFalse,
          reason: 'the memory is why this used to be skipped');
      expect(urlNeedsRewrite(want: want, liveHash: ''), isTrue,
          reason: 'the address bar is why it must not be');
    });

    test('the engine\'s minified route name is not the share link', () {
      // What `onRouteChanged` exists to repair: the engine writes the
      // pushed route's minified name into the fragment.
      expect(
          urlNeedsRewrite(want: '#/john/3?v=bsb', liveHash: '#/minified:A7'),
          isTrue);
    });

    test('a claimed page path is compared the same way', () {
      expect(urlNeedsRewrite(want: '#/wheel', liveHash: '#/wheel'), isFalse,
          reason: 'the forced writes used to push a duplicate entry here');
      expect(
          urlNeedsRewrite(want: '#/wheel', liveHash: '#/john/3?v=bsb'),
          isTrue);
    });
  });
}
