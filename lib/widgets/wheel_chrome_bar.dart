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
/// is normally opened at, 744 (iPad mini portrait), clears it.
///
/// IT WAS 480 FOR HALF A DAY AND 480 WAS MEASURED WRONG. The number has
/// to be the width at which the WIDE bar stops crushing the title, not
/// the width at which a phone stops being a phone, and the wide bar is
/// expensive: back 56, three `IconButton`s 144, the two-word switch
/// about 110, language 48, home 48 — 406 before the title is offered a
/// pixel. Read on the shipped page at a 500 px viewport, the title got
/// 40 px and rendered as `世···`: one glyph and an ellipsis, which is
/// the very thing `wheelViewSwitch` below refuses to do to a two-word
/// label. A title wants about 110 px in 简体中文 and about 170 for the
/// strip's own longer name, so the wide bar needs roughly 570 before it
/// is honest, and 600 is that with room. It is `WorkbenchFit.twoPaneMinWidth` (720) that
/// this page does NOT reuse: that gate answers "how many workbench
/// COLUMNS fit", an unrelated question of pane arithmetic the wheel
/// and strip do not have, since neither page is ever one of the
/// workbench's own panes.
const double kWheelNarrowPaneWidth = 600;

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
  // Narrow: EVERYTHING except the view switch moves into one sheet
  // behind a single `more_vert` — Find, Filter, About, and the language
  // and home buttons too. Folding only the first three left four
  // actions on the bar, and measured at 375 px that still spent the
  // whole toolbar: the title rendered NOTHING AT ALL, laid out at its
  // natural 71 px and clipped away to nothing, which a widget test
  // asserting `getSize(title).width > 0` cannot see, because Flutter
  // lays a `Flexible` title out at its natural size and then clips it.
  //
  // Language and home are not more important than the name of the page
  // a reader is standing on. They are one tap further into the sheet;
  // the title is the only thing on this bar that answers "where am I",
  // and the back button already answers "how do I leave".
  //
  // The view-switch alone stays a direct action, because it is how a
  // phone reader LEAVES the wheel for the form that actually works at
  // this width (see `wheelViewSwitch`'s own doc); burying the one exit
  // this pane most needs would be the wrong economy. That leaves back
  // 56 + overflow 48 + switch about 90 = 194, so at 375 the title has
  // 181 px against the 110 简体中文 wants and the 170 the strip's
  // longer name wants — whole, at both widths this app is reached on.
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
        // The two the AppBar gave up so the page could keep its name.
        // Both are their own widgets with their own behaviour — the
        // language switcher opens its own menu, the home button
        // navigates — so they are placed here AS THEMSELVES rather
        // than re-implemented as two more `ListTile`s that would have
        // to duplicate what each already does.
        const Divider(height: 1),
        ListTile(
          leading: const LanguageSwitcherButton(),
          title: Text(
              uiStrings['interfaceLanguage']?[locale] ?? 'Interface Language',
              style: TextStyle(color: wb.text)),
        ),
        ListTile(
          leading: const HomeIconButton(),
          title: Text(uiStrings['home']?[locale] ?? 'Home',
              style: TextStyle(color: wb.text)),
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
      padding: EdgeInsets.symmetric(horizontal: narrow ? 2 : 4),
      child: Tooltip(
        message: ss('stripViewSwitch', 'Chart view'),
        child: SegmentedButton<String>(
          showSelectedIcon: false,
          // A narrower `padding` was tried here and DOES NOTHING: the
          // icon-only pair measures 112 px with or without it, because
          // SegmentedButton takes its segment padding from the theme
          // and not from this `ButtonStyle`. Left at the stock value
          // rather than carrying a property that has no effect — the
          // 34 px the title needed came from `wheelChromeTitle`
          // instead, and honestly.
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

/// The AppBar title for either page, and the `titleSpacing` that goes
/// with it — narrow-aware, because the title is the one thing on this
/// bar that answers "where am I" and it was the first thing the bar
/// spent.
///
/// MEASURED, at 375 px, after Find/Filter/About/language/home had
/// already gone into the overflow sheet: the strip's own name — the
/// longer of the two, 世界历史时间条 at seven Han characters, and
/// `World History Strip` in English — wanted 153.5 px and was given
/// 119, so it still rendered clipped. Two levers, neither of which
/// drops a word: `titleSpacing` 16 -> 4, since Material's default gap
/// is generous for a bar this empty, and the title set at 17 px rather
/// than the stock 22, which takes the same name from 153.5 px to 119
/// and puts it inside the 139 the bar can now offer. That is the move
/// a chart makes when a label will not fit its arc — except that here
/// the TYPE shrinks and every word survives, which is the whole
/// difference between this and the `世···` the bar rendered before.
/// (A third lever, padding the switch's segments in, was tried and
/// does nothing — see `wheelViewSwitch`.)
///
/// Below 375 px — an iPhone SE at 320 — the longer English name does
/// not fit even so, and will ellipsize. That is stated rather than
/// hidden: 375 is the narrowest width this app is actually reached on
/// today, and buying 320 as well would cost either the view switch or
/// the type a reader can still read.
Widget wheelChromeTitle(BuildContext context, String text, double paneWidth) {
  if (paneWidth >= kWheelNarrowPaneWidth) return Text(text);
  // `scaledChrome`, not a bare 17: #315's rule is that a hardcoded
  // fontSize is a size the reader's Font Size setting cannot move, and
  // an AppBar title is frame furniture. 17 is the size at the default
  // scale; a reader who has enlarged the app's type gets a larger title
  // and, past some setting, an ellipsis — which is the correct order of
  // sacrifice, since they asked for the larger type.
  return Text(
    text,
    style: TextStyle(
        fontSize: WbType.of(context).scaledChrome(17),
        fontWeight: FontWeight.w500),
  );
}

/// The gap between the back button and [wheelChromeTitle]. See its doc.
double wheelChromeTitleSpacing(double paneWidth) =>
    paneWidth >= kWheelNarrowPaneWidth ? NavigationToolbar.kMiddleSpacing : 4;
