// URL paths that name a full-screen PAGE rather than a passage.
//
// Most of the app's URLs are reader links — `#/<book>/<chapter>` — and
// `UrlSyncService` parses those into a book/chapter/verse and applies
// them to `MainProvider`. A handful of pages instead OWN the address bar
// while they are open (see `UrlSyncService.claimUrl`), and their paths
// are not passages at all. `#/wheel` is the first of them.
//
// A page path reaches the app by two different doors, and before this
// file existed only one of them knew about it:
//
//   • COLD OPEN. On the web the engine's boot route name IS the hash
//     path, so `Navigator.defaultGenerateInitialRoutes` asks
//     `onGenerateRoute` for it while it builds the first frame, and the
//     page is on the initial stack above the app root. (It used to be
//     PUSHED instead, from the root router's first post-splash frame —
//     which is why a shared wheel link showed a splash, then a
//     workbench, then a transition, and only then started loading the
//     wheel's own data.)
//
//   • A LIVE TAB. Editing the fragment in the address bar, or pressing
//     Back / Forward onto a `#/wheel` history entry, is a same-document
//     navigation: the web engine hands the framework `pushRoute('/wheel')`
//     instead of restarting the app. `/wheel` is not a registered route,
//     so that lands in `onUnknownRoute` — which used to answer every
//     unknown name with the app root, i.e. it pushed a SECOND workbench
//     at Genesis 1 on top of whatever was showing while the address bar
//     read `#/wheel`. The page link was a real page the whole time; the
//     fallback simply had no way to know that.
//
// Both doors now ask the same question here, so a page can never be a
// page through one and a stray URL through the other.
//
// 2026-09-02, one constraint the cold door imposes: the boot answer is
// given to `Navigator.defaultGenerateInitialRoutes`, which splits the
// boot path on `/` and asks for EVERY prefix. A page path with a
// sub-path — `/wheel/x` — would therefore generate `/wheel` AND
// `/wheel/x`, i.e. two wheels on the initial stack. Nothing emits a
// sub-path today (`claimUrl` writes `/wheel`, optionally with a query).
// If one is ever added, the boot door must match only the last segment.

import 'package:flutter/widgets.dart';

import 'package:seeksparks/pages/radial_chronology_page.dart'
    show RadialChronologyPage, kWheelUrlPath;
import 'package:seeksparks/pages/strip_chronology_page.dart'
    show StripChronologyPage, kStripUrlPath;

/// The page [path] names, or null when it names no page.
///
/// Accepts the path with or without its leading `#`, and matches by
/// prefix so a future `#/wheel?year=-4000` still resolves to the wheel
/// (and `#/strip?year=-4000` the strip, the same chart's second form —
/// see `chronologyChartEntryPage` for why there are two).
Widget? pageForUrlPath(String? path) {
  if (path == null || path.isEmpty) return null;
  final p = path.startsWith('#') ? path.substring(1) : path;
  if (p == kWheelUrlPath || p.startsWith('$kWheelUrlPath/') ||
      p.startsWith('$kWheelUrlPath?')) {
    return const RadialChronologyPage();
  }
  if (p == kStripUrlPath || p.startsWith('$kStripUrlPath/') ||
      p.startsWith('$kStripUrlPath?')) {
    return const StripChronologyPage();
  }
  return null;
}

/// True when [a] and [b] name the SAME page.
///
/// False whenever either names no page at all — two passages are not
/// "the same page", they are not pages.
///
/// 2026-09-02: this exists for one question, asked by `browserRouteAction`
/// in `main.dart`. When the browser hands the app a page path, the app
/// has to know whether that page is the thing already on screen, because
/// the two answers are opposite: open it, or go back off it. The URL a
/// page has claimed (`UrlSyncService.claimedPath`) is what it is compared
/// against, and the two are not textually equal in general — a claim is
/// written without its `#`, and a page path matches by prefix, so
/// `/wheel` and `/wheel?year=-4000` are the same page and must compare
/// equal here.
bool samePageUrlPath(String? a, String? b) {
  final pageA = pageForUrlPath(a);
  if (pageA == null) return false;
  final pageB = pageForUrlPath(b);
  return pageB != null && pageA.runtimeType == pageB.runtimeType;
}
