// 2026-08-04 (Workbench): width-aware reader navigation. On pad-landscape
// / desktop widths the "reader" is the three-pane Workbench; below that
// it stays the classic single-pane HomePage reader.

import 'package:flutter/widgets.dart';
import 'package:seeksparks/utils/app_nav.dart';

import 'package:seeksparks/pages/home_page.dart';
import 'package:seeksparks/pages/workbench_page.dart';
import 'package:seeksparks/utils/navigate_to_reader.dart'
    show kHomePageRouteName, kWorkbenchRouteName;
import 'package:seeksparks/utils/responsive.dart';

/// Push the Bible reader appropriate for the current screen width:
/// [WorkbenchPage] (three-pane study workspace) at desktop / iPad-
/// landscape widths, the classic [HomePage] reader below that.
///
/// Callers setting up a verse jump must still call
/// `jumper.prepareJumpToVerse` BEFORE this — the workbench's center
/// pane is a BibleReadingPane on the same primary MainProvider, so the
/// pendingJump handshake fires identically in either target.
void openReader(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (ResponsiveBreakpoints.isDesktopOrWider(width)) {
    pushPage(const WorkbenchPage(),
        routeName: kWorkbenchRouteName);
    return;
  }
  pushPage(const HomePage(),
      routeName: kHomePageRouteName);
}
