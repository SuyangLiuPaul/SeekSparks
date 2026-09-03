import 'package:flutter/material.dart';

import 'package:seeksparks/constants/ui_strings.dart' show uiStrings;
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/widgets/home_icon_button.dart';
import 'package:seeksparks/widgets/language_switcher_button.dart';

/// The wheel and the strip AppBars, collapsed for a phone pane — shared
/// so the two forms cannot drift apart the way two hand-rolled copies
/// would.
///
/// WHY A SHARED FILE AND NOT TWO COPIES. `radial_chronology_page.dart`
/// and `strip_chronology_page.dart` carry the identical AppBar on
/// purpose (see the strip's own comment at its AppBar: "a reader
/// switching forms should find Find/Filter/About in the same place
/// they left them"), and until 2026-09-04 that identity was kept by
/// hand — two `actions` lists, typed out separately, that happened to
/// agree. `#/wheel` and `#/strip` became reachable at any width on
/// 2026-09-03 (`main.dart`'s `SmallScreenGate` removal), and measured
/// against the real page at 375 px — an iPhone SE / mini's logical
/// width, the narrowest this app now opens on — the title of BOTH
/// pages renders at **0.0 px wide**: `AppBar` gives the title a
/// `Flexible` and six actions (three `IconButton`s, the view-switch
/// `SegmentedButton`, `LanguageSwitcherButton`, `HomeIconButton`) ate
/// the entire toolbar before the title got a pixel. A title that is
/// there in the tree and invisible on screen is the same defect a hand
/// -rolled fix to only one of the two pages would have reintroduced in
/// the other the next time either grew a new action.
///
/// [kWheelNarrowPaneWidth] is not the wheel's own geometry — nothing
/// here scales with `side` the way `hubD`/`rBands`/`rRim` do, because
/// the AppBar is answered by the OS chrome, not the canvas. 480 sits
/// with real headroom on both sides of the phones this app is reached
/// on: every current phone's portrait width — 320 (SE), 375, 390, 393,
/// 402, 428, 430 — is under it, and the smallest tablet width this app
/// is normally opened at, 744 (iPad mini portrait), clears it by more
/// than half again. It is `WorkbenchFit.twoPaneMinWidth` (720) that
/// this page does NOT reuse: that gate answers "how many workbench
/// COLUMNS fit", an unrelated question of pane arithmetic the wheel
/// and strip do not have, since neither page is ever one of the
/// workbench's own panes.
const double kWheelNarrowPaneWidth = 480;

/// The AppBar `actions` for the wheel or the strip, in the wide form
/// (everything spelled out, exactly the six items both pages always
/// carried) or the narrow one (the three sheets folded into one menu,
/// the view-switch kept at icon size, the language switcher's existing
/// `dense` mode — built for the Workbench's own 11 px chrome — reused
/// rather than invented twice).
///
/// [s] reads the caller's OWN string table — `wheelStrings`, in both
/// pages — so this file stays free of a dependency on either page, the
/// same reason `WheelSheets`' own methods take their strings as
/// parameters rather than as an import.
List<Widget> wheelChromeActions({
  required BuildContext context,
  required String locale,
  required double paneWidth,
  required String Function(String key, String fallback) s,
  required VoidCallback onFind,
  required VoidCallback onFilter,
  required VoidCallback onAbout,
  required Widget viewSwitch,
}) {
  if (paneWidth >= kWheelNarrowPaneWidth) {
    return [
      IconButton(
        icon: const Icon(Icons.search),
        tooltip: s('wheelFind', 'Find'),
        onPressed: onFind,
      ),
      IconButton(
        icon: const Icon(Icons.filter_list),
        tooltip: s('wheelFilter', 'Filter'),
        onPressed: onFilter,
      ),
      IconButton(
        icon: const Icon(Icons.info_outline),
        tooltip: s('wheelAbout', 'About this chart'),
        onPressed: onAbout,
      ),
      viewSwitch,
      const LanguageSwitcherButton(),
      const HomeIconButton(),
    ];
  }
  // Narrow: Find/Filter/About move into one sheet behind a single
  // `more_vert` — the same three sheets, the same strings, reached in
  // two taps instead of one. The view-switch stays a direct action
  // because it is how a phone reader LEAVES this page for the form
  // that actually works at this width (see `wheelViewSwitch`'s own
  // doc); folding it in with the rest would bury the one exit this
  // pane most needs.
  return [
    IconButton(
      icon: const Icon(Icons.more_vert),
      tooltip: uiStrings['more']?[locale] ?? 'More',
      onPressed: () => _showOverflow(
        context: context,
        locale: locale,
        s: s,
        onFind: onFind,
        onFilter: onFilter,
        onAbout: onAbout,
      ),
    ),
    viewSwitch,
    const LanguageSwitcherButton(dense: true),
    const HomeIconButton(),
  ];
}

void _showOverflow({
  required BuildContext context,
  required String locale,
  required String Function(String key, String fallback) s,
  required VoidCallback onFind,
  required VoidCallback onFilter,
  required VoidCallback onAbout,
}) {
  final wb = WbColors.of(context);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: wb.paneBg,
    shape: const RoundedRectangleBorder(),
    builder: (sheet) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: Icon(Icons.search, color: wb.text),
          title: Text(s('wheelFind', 'Find'),
              style: TextStyle(color: wb.text)),
          onTap: () {
            Navigator.of(sheet).pop();
            onFind();
          },
        ),
        ListTile(
          leading: Icon(Icons.filter_list, color: wb.text),
          title: Text(s('wheelFilter', 'Filter'),
              style: TextStyle(color: wb.text)),
          onTap: () {
            Navigator.of(sheet).pop();
            onFilter();
          },
        ),
        ListTile(
          leading: Icon(Icons.info_outline, color: wb.text),
          title: Text(s('wheelAbout', 'About this chart'),
              style: TextStyle(color: wb.text)),
          onTap: () {
            Navigator.of(sheet).pop();
            onAbout();
          },
        ),
      ]),
    ),
  );
}

/// The wheel<->strip `SegmentedButton`, built once so the wide two-word
/// form and the narrow icon-only form live in one place instead of
/// two — see this file's own class doc for what happens when they
/// don't.
///
/// Icon-only rather than a shrunk copy of the words: the labels are
/// "Wheel"/"Strip" or "轮盘"/"长条", and #297 (the wheel's own rule,
/// restated in `fitRadialLabel`'s doc) is that a label this app ships
/// is whole or absent, never a clipped fragment — the same reason an
/// ellipsis is not an option here either. An icon carries the two
/// shapes wordlessly instead: a ring for the wheel, a horizontal band
/// for the strip.
Widget wheelViewSwitch({
  required String locale,
  required bool narrow,
  required String Function(String key, String fallback) ss,
  required Set<String> selected,
  required ValueChanged<Set<String>> onSelectionChanged,
}) =>
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: ss('stripViewSwitch', 'Chart view'),
        child: SegmentedButton<String>(
          showSelectedIcon: false,
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          segments: narrow
              ? const [
                  ButtonSegment(
                    value: 'wheel',
                    icon: Icon(Icons.donut_large, size: 16),
                  ),
                  ButtonSegment(
                    value: 'strip',
                    icon: Icon(Icons.view_week, size: 16),
                  ),
                ]
              : [
                  ButtonSegment(
                    value: 'wheel',
                    label: Text(ss('stripViewWheel', 'Wheel')),
                  ),
                  ButtonSegment(
                    value: 'strip',
                    label: Text(ss('stripViewStrip', 'Strip')),
                  ),
                ],
          selected: selected,
          onSelectionChanged: onSelectionChanged,
        ),
      ),
    );
