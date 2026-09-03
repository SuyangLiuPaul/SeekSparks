// Who owns the address bar, when the address bar may own the reader,
// and when the address bar has to be written at all.
//
// These rules live here rather than inside `url_sync_service_web.dart`,
// for the reason `sermonAudioControl` and `browserRouteAction` do: the
// web implementation imports `dart:js_interop` and so cannot be reached
// by a test at all. Each was written from a defect reproduced in a real
// browser — the first two on dev v1.6.220, the third on dev v1.6.223 —
// and each is pure, so the reproduction is a unit test rather than a
// paragraph.

import 'package:seeksparks/utils/page_links.dart';

/// Whether the address bar has to be written so that it reads [want].
///
/// THE ENGINE WRITES THE FRAGMENT TOO, AND IT WRITES IT AWAY. This
/// used to be `want != _lastWrittenUrl` — a memory of what the app
/// itself last wrote. That is a proxy for "what the address bar says",
/// and the proxy is wrong in exactly the case that matters, because the
/// app is not the only writer:
///
///     SingleEntryBrowserHistory.setRouteName('/')
///       → _setupFlutterEntry(replace: true)
///         → HashUrlStrategy.replaceState(state, 'flutter', '/')
///           → prepareExternalUrl('/') == '<pathname><search>'
///
/// `prepareExternalUrl` drops the `#` deliberately ("Let's not add the
/// hash at all when the app is in the home page", flutter#127608), so
/// every engine route report of `/` REPLACES the current entry's URL
/// with a fragment-less one. Two of those are ordinary:
///
///   • at boot, when the framework reports its initial route. Traced on
///     dev v1.6.223 in an unthrottled Chrome: `replaceState({flutter:
///     true}, '/')` at 1.5 s, i.e. a shared link's `#/john/3?v=bsb` is
///     gone before the splash clears.
///   • after browser Back, when `BrowserRouteObserver` answers it with
///     `maybePop()` and the Navigator reports the root route that is
///     left. Traced in the same run: `replaceState({flutter: true},
///     '/')` 1 ms after the popstate that landed on the engine's
///     flutter entry.
///
/// With the old gate the boot case never healed. `_applyHashToState`
/// remembered the boot hash as "written", the engine then blanked the
/// fragment, and the next write computed the same string, compared it
/// against the memory, matched, and returned — so the address bar stayed
/// EMPTY for the whole session until the reader turned a page. A reader
/// who opened a shared link and copied the URL shared the app root.
/// Measured: 40 s of `location.hash === ''` after a cold
/// `#/john/3?v=bsb`, in three runs.
///
/// So ask the address bar instead of remembering. [liveHash] is
/// `window.location.hash`, which is `''` when there is no fragment at
/// all — never equal to a [want] that always carries its `#` — so a
/// blanked fragment always reads as "needs writing", and a correct one
/// never does.
///
/// The de-duplication the memory was there for survives, and is
/// stricter: the forced writes (`claimUrl`, `onRouteChanged`) used to
/// zero the memory to defeat the gate, which pushed a duplicate history
/// entry even when the address bar was already right — visible in the
/// same trace as two identical `#/john/3:2?v=bsb` pushes in one
/// millisecond, and two identical `#/wheel` pushes. They no longer can:
/// a write that would not change the address bar is not a write.
bool urlNeedsRewrite({required String want, required String liveHash}) =>
    want != liveHash;

/// Whether a hash arriving from the browser may drive reader state.
///
/// TWO REASONS IT MAY NOT, and they are different reasons.
///
///   • IT IS NOT A PASSAGE. `#/wheel` names a page, not a book and
///     chapter, and parsing it as one is what used to drop shared page
///     links on Genesis 1. This check was written as
///     `path.startsWith('/wheel')`; it asks [pageForUrlPath] now, so a
///     second page added to `page_links.dart` is covered on the day it
///     is added rather than the day someone remembers this line.
///
///   • A PAGE OWNS THE URL. While the wheel is open the address bar
///     says `#/wheel`, so any OTHER hash the browser hands us is a
///     history entry from underneath the wheel — pressing Back off the
///     wheel delivers exactly that. Applying it would move the reader
///     behind a page the reader is still looking at, on a Back whose
///     only job was to close that page. The state under the wheel is
///     already the state that hash describes, because opening the wheel
///     never changed it, so refusing costs nothing and skips nothing.
///
/// [isBoot] is exempt from the second rule and cannot trip it anyway —
/// nothing has claimed at boot — but the exemption is explicit because
/// a boot deep link is the one apply that MUST NOT be droppable.
bool urlMayDriveReader({
  required String path,
  required bool isBoot,
  required String? claimedPath,
}) {
  if (pageForUrlPath(path) != null) return false;
  if (!isBoot && claimedPath != null) return false;
  return true;
}

/// The URL claim: which page owns the address bar, and which page said so.
///
/// WHY AN OWNER AND NOT JUST A PATH. Release used to be
/// `claimUrl(null)` — an unconditional global clear, called from the
/// claiming page's `dispose`. Flutter disposes a closing route AFTER
/// the next route's `initState`, so closing the wheel and reopening it
/// quickly runs, in this order: wheel B claims `/wheel`, then wheel A's
/// dispose clears it. The claim is then null with a wheel on screen,
/// and the next debounced write puts the reader's own link in the
/// address bar underneath the open wheel — reproduced on dev v1.6.220
/// by Back-then-forward, where the URL read `#/genesis/1?v=bsb` while
/// the wheel was up. Two wheels have the same PATH, so only identity
/// can tell them apart.
class UrlClaim {
  String? _path;
  Object? _owner;

  /// The claimed path, or null when the reader link owns the URL.
  String? get path => _path;

  /// Claim [path] (non-null) or release it (null).
  ///
  /// Returns true when the claim actually CHANGED, which is the
  /// caller's signal to rewrite the URL; false means nothing happened
  /// and nothing should be written. A release from an [owner] that no
  /// longer holds the claim is exactly that: refused, and false.
  ///
  /// A null [owner] is unscoped and always wins, so the pre-ownership
  /// call shape still behaves as it did.
  bool set(String? path, {Object? owner}) {
    if (path == null) {
      if (_path == null) return false;
      if (owner != null && _owner != null && !identical(_owner, owner)) {
        return false;
      }
      _path = null;
      _owner = null;
      return true;
    }
    // A re-claim by a DIFFERENT owner is a hand-off, not a no-op: the
    // owner has to move or the outgoing page's release would still be
    // honoured against the incoming page's claim.
    final sameOwner = identical(_owner, owner);
    if (_path == path && sameOwner) return false;
    _path = path;
    _owner = owner;
    return true;
  }
}
