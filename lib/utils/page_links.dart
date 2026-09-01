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
//   • COLD OPEN. `main()` snapshots the boot fragment and the root
//     router opens the page on the first post-splash frame.
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

import 'package:flutter/widgets.dart';

import 'package:seeksparks/pages/radial_chronology_page.dart'
    show RadialChronologyPage, kWheelUrlPath;

/// The page [path] names, or null when it names no page.
///
/// Accepts the path with or without its leading `#`, and matches by
/// prefix so a future `#/wheel?year=-4000` still resolves to the wheel.
Widget? pageForUrlPath(String? path) {
  if (path == null || path.isEmpty) return null;
  final p = path.startsWith('#') ? path.substring(1) : path;
  if (p == kWheelUrlPath || p.startsWith('$kWheelUrlPath/') ||
      p.startsWith('$kWheelUrlPath?')) {
    return const RadialChronologyPage();
  }
  return null;
}
