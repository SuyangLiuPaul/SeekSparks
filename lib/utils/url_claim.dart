// Who owns the address bar, and when the address bar may own the reader.
//
// Two rules live here rather than inside `url_sync_service_web.dart`,
// for the reason `sermonAudioControl` and `browserRouteAction` do: the
// web implementation imports `dart:js_interop` and so cannot be reached
// by a test at all. Both rules below were written from a defect
// reproduced in a real browser on dev v1.6.220, and both are pure, so
// the reproduction is now a unit test instead of a paragraph.

import 'package:seeksparks/utils/page_links.dart';

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
