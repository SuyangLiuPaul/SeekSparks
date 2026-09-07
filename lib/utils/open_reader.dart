// 2026-08-04 (Workbench): width-aware reader navigation.
//
// 2026-09-08 — THERE IS ONE READING SURFACE NOW, at the owner's
// decision: 「reader 并进去吧」. This file used to branch on width and
// push the classic single-pane `HomePage` below desktop, and that
// branch had already been made redundant by `main.dart`, which lands
// EVERY width on the Workbench and has since 2026-08-06. The Workbench
// degrades on its own — below 1024 it drops the Analysis pane, below
// 600 the Search pane too, leaving exactly the centre reading pane,
// which is what `HomePage` was. So the branch decided between the
// Workbench and a narrower copy of the Workbench.
//
// `open_reader.dart` is kept as the name every caller already uses
// rather than folded into its one remaining line, so this note has
// somewhere to live and the callers do not all churn.

import 'package:flutter/widgets.dart';
import 'package:seeksparks/utils/app_nav.dart';

import 'package:seeksparks/pages/workbench_page.dart';
import 'package:seeksparks/utils/navigate_to_reader.dart'
    show kWorkbenchRouteName;

/// Push the Bible reader: the Workbench, at every width.
///
/// Callers setting up a verse jump must still call
/// `jumper.prepareJumpToVerse` BEFORE this — the workbench's centre
/// pane is a BibleReadingPane on the same primary MainProvider, so the
/// pendingJump handshake fires exactly as it did in the classic reader.
void openReader(BuildContext context) {
  pushPage(const WorkbenchPage(), routeName: kWorkbenchRouteName);
}
