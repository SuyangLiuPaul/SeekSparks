// 2026-05-24 (v1.3.7): single canonical helper for navigating to the
// Bible Reader (HomePage) from anywhere in the app.
//
// Why a helper: navigation to the reader happens from 5+ different
// places (Library tile, verse-ref popup "Open in Reader", trivia
// answer link, timeline event link, deep-link URL handler, ...).
// All of them MUST avoid creating a duplicate HomePage in the
// navigator stack — the previous bug was Library tile tap →
// `Get.off(HomePage)` only replaced Library and left a stale
// HomePage(reader) underneath, so backing out of the new HomePage
// surfaced the original one. User reported "bible duplicate了".
//
// The helper:
//   1. Pops EVERY route above an existing HomePage (if one exists
//      in the stack — identified by route.settings.name ==
//      '/HomePage'; that name is set explicitly by every push site
//      in v1.3.6).
//   2. If an existing HomePage is found, pendingJump (set by the
//      caller via jumper.prepareJumpToVerse / resolveAndPrepareJump
//      etc.) fires on it during the next build.
//   3. If no HomePage is in the stack at all, popUntil stops at
//      root (Dashboard) and a fresh HomePage is Get.to'd on top.
//
// Either way the stack ends with EXACTLY ONE HomePage.

import 'package:flutter/material.dart';
import 'package:seeksparks/utils/app_nav.dart';

import 'package:seeksparks/pages/home_page.dart';

/// The canonical route name for HomePage. All Get.to / Get.off
/// pushes of HomePage MUST pass this as `routeName:` so popUntil
/// can detect existing instances reliably.
const String kHomePageRouteName = '/HomePage';

/// 2026-08-04 (Workbench): the three-pane Workbench IS a reader on
/// wide screens — its center pane is a BibleReadingPane on the same
/// primary MainProvider, so a pendingJump fires in it identically.
/// It must count as "an existing reader" for the dedupe logic below,
/// otherwise "Open in Reader" from a popup while the Workbench is on
/// the stack would pop the Workbench away.
const String kWorkbenchRouteName = '/Workbench';

/// Navigate to the Bible Reader, re-using an existing reader route if
/// one is already in the navigator stack — that means HomePage OR, on
/// wide screens, the three-pane Workbench (which IS a reader: same
/// primary MainProvider, same pendingJump handshake); otherwise push
/// a fresh HomePage. Idempotent — calling multiple times in a row
/// never produces duplicates.
///
/// Callers are responsible for setting `mainProvider.pendingJump`
/// (or equivalent) BEFORE invoking this helper. The reader's
/// build sees the jump request and scrolls + highlights the
/// target verse on its next frame.
void navigateToReader(BuildContext context) {
  final navigator = Navigator.of(context, rootNavigator: true);
  bool foundExistingHome = false;
  navigator.popUntil((route) {
    final name = route.settings.name ?? '';
    // Match the canonical reader route names (classic reader AND the
    // wide-screen Workbench) AND any future variant ending in
    // "HomePage"/"WorkbenchPage" (defensive — if some future push site
    // forgets the explicit routeName and Get happens to produce
    // something ending in either, we still detect it).
    if (name == kHomePageRouteName ||
        name == kWorkbenchRouteName ||
        name.endsWith('HomePage') ||
        name.endsWith('WorkbenchPage')) {
      foundExistingHome = true;
      return true;
    }
    if (route.isFirst) return true; // root (Dashboard) reached
    return false;
  });
  if (!foundExistingHome) {
    pushPage(const HomePage(),
        routeName: kHomePageRouteName);
  }
}
