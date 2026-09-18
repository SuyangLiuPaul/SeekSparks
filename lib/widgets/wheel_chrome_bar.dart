import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yahwehs_sword/constants/ui_strings.dart' show uiStrings;
import 'package:yahwehs_sword/constants/workbench_theme.dart';
import 'package:yahwehs_sword/widgets/home_icon_button.dart';
import 'package:yahwehs_sword/widgets/language_switcher_button.dart';
import 'package:yahwehs_sword/models/app_settings.dart';

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
  required VoidCallback onHelp,
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
      // HOW TO USE IT, beside WHAT IT IS. The two are different
      // questions and the reader who needs one rarely needs the other:
      // `info_outline` is the provenance of the dates, this is the
      // pointer, the pinch and the list. It is also the way back to a
      // card most readers will see exactly once, on their first visit.
      IconButton(
        key: const ValueKey('chartHelpButton'),
        icon: const Icon(Icons.help_outline),
        tooltip: s('wheelHelp', 'How to read this chart'),
        onPressed: onHelp,
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
        onHelp: onHelp,
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
  required VoidCallback onHelp,
}) {
  final wb = WbColors.of(context);
  // Asked BEFORE the sheet is pushed. Once it is open the sheet is
  // itself a route, so `canPop` answers true on every page including
  // the root — which would offer a Home row that pops the sheet and
  // goes nowhere.
  final canGoHome = Navigator.of(context).canPop();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: wb.paneBg,
    builder: (sheet) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: Icon(Icons.search, color: wb.text),
          title: Text(s('wheelFind', 'Find'), style: TextStyle(color: wb.text)),
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
        ListTile(
          key: const ValueKey('chartHelpRow'),
          leading: Icon(Icons.help_outline, color: wb.text),
          title: Text(s('wheelHelp', 'How to read this chart'),
              style: TextStyle(color: wb.text)),
          onTap: () {
            Navigator.of(sheet).pop();
            onHelp();
          },
        ),
        // The two the AppBar gave up so the page could keep its name.
        //
        // 2026-09-15: these carried NO `onTap`. They were placed "as
        // themselves" — a `LanguageSwitcherButton` and a
        // `HomeIconButton` in the `leading` slot — on the reasoning that
        // each already knows what it does and should not be
        // reimplemented. What that overlooked is where those widgets
        // are: in an AppBar a button IS the row, and in a `ListTile` it
        // is a 24 px icon at the left end of a 300 px row whose title
        // and whole remaining width do nothing at all. Reported as
        // 「按了没反应」, with both rows circled, which is exactly what a
        // reader gets for pressing the words.
        //
        // The row is the target now, and the icons are plain `Icon`s so
        // there is no live button inside a live row for a tap to fall
        // between.
        const Divider(height: 1),
        ListTile(
          leading: Icon(Icons.language_rounded, color: wb.text),
          title: Text(
              uiStrings['interfaceLanguage']?[locale] ?? 'Interface Language',
              style: TextStyle(color: wb.text)),
          onTap: () {
            Navigator.of(sheet).pop();
            _showLanguagePicker(context, locale);
          },
        ),
        if (canGoHome)
          ListTile(
            leading: Icon(Icons.home_rounded, color: wb.text),
            title: Text(uiStrings['home']?[locale] ?? 'Home',
                style: TextStyle(color: wb.text)),
            onTap: () {
              Navigator.of(sheet).pop();
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
      ]),
    ),
  );
}

/// The three interface languages, as a sheet.
///
/// `LanguageSwitcherButton` shows the same three through a
/// `PopupMenuButton`, which anchors its menu to the button it lives in
/// — fine in an AppBar and wrong here, because the button this row
/// would anchor to is about to be dismissed with the sheet. A second
/// sheet is the shape that survives the first one closing, and it is
/// also the bigger tap target of the two on a phone.
void _showLanguagePicker(BuildContext context, String locale) {
  final wb = WbColors.of(context);
  final settings = context.read<AppSettings>();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: wb.paneBg,
    builder: (sheet) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final (code, name) in const [
          ('zh-Hans', '简体中文'),
          ('zh-Hant', '繁體中文'),
          ('en', 'English'),
        ])
          ListTile(
            leading: Icon(
              code == locale
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: code == locale ? wb.accent : wb.mutedText,
            ),
            title: Text(name, style: TextStyle(color: wb.text)),
            onTap: () {
              Navigator.of(sheet).pop();
              settings.setLocale(code);
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
              ? [
                  ButtonSegment(
                    value: 'wheel',
                    tooltip: ss('stripViewWheel', 'Wheel'),
                    icon: const Icon(Icons.donut_large, size: 16),
                  ),
                  ButtonSegment(
                    value: 'strip',
                    tooltip: ss('stripViewStrip', 'Strip'),
                    icon: const Icon(Icons.view_week, size: 16),
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

/// The narrow title drops the redundant “World” before shrinking any
/// text. At 360 px, “World History Strip” was clipped despite the earlier
/// 375 px fix. The complete name remains on wide screens; the narrow
/// title still says both what the chart is and which form is open.
Widget wheelChromeTitle(BuildContext context, String text, double paneWidth) {
  if (paneWidth >= kWheelNarrowPaneWidth) return Text(text);
  final compact = text
      .replaceFirst('World History', 'History')
      .replaceFirst('世界历史', '历史')
      .replaceFirst('世界歷史', '歷史')
      .replaceFirst('世界史', text.contains('輪') ? '歷史' : '历史');
  return Text(
    compact,
    style: TextStyle(
        fontSize: WbType.of(context).scaledChrome(17),
        fontWeight: FontWeight.w500),
  );
}

/// The gap between the back button and [wheelChromeTitle]. See its doc.
double wheelChromeTitleSpacing(double paneWidth) =>
    paneWidth >= kWheelNarrowPaneWidth ? NavigationToolbar.kMiddleSpacing : 4;

/// The route the two chronology forms swap through.
///
/// 2026-09-16 「轮子和strip toggle的时候左右移动应该根据这两个位置决定
/// 现在都是右边往左边看起来很奇怪」, and it is. The toggle above puts the
/// two forms side by side — the wheel on the left segment, the strip on
/// the right — and a stock [MaterialPageRoute] slides in from the right
/// whichever way you went. Pressing the LEFT segment and watching the
/// page arrive from the right is the thing that reads as wrong: the
/// control says where the two views are, and then the movement
/// contradicts it.
///
/// So the page moves the way the toggle does. [toRight] is true for the
/// press that moves rightward along the control.
Route<T> chartFormRoute<T>({
  required WidgetBuilder builder,
  required bool toRight,
}) =>
    PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondary) => builder(context),
      transitionsBuilder: (context, animation, secondary, child) =>
          SlideTransition(
        position: Tween<Offset>(
          begin: Offset(toRight ? 1 : -1, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
        child: child,
      ),
    );
