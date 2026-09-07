/// The workbench's keyboard shortcuts — bwh44, and the half of it that
/// matters: *"a shortcut nobody can find is not a feature."*
///
/// `docs/PARITY-BACKLOG.md` §3.7 asked for "a shortcut sheet and the
/// handful worth having, plus a discoverable list". This file is the
/// list, and it is the SAME list the handler dispatches from — one
/// table, read twice. A sheet maintained separately from the handler
/// starts true and stops being true the first time somebody adds a key,
/// and the reader is the last to know.
///
/// [WbShortcutId] is an enum for the same reason: the handler switches
/// over it exhaustively, so adding a row here does not compile until
/// something does it.
///
/// ## Why not BibleWorks' function keys
///
/// bwh44 is a full F1–F12 set, which is a Windows-desktop idiom. This
/// app runs in a browser tab, where F3, F5, F6, F11 and F12 belong to
/// the browser and taking them is either impossible or rude, and on a
/// tablet where there is no function row at all. F1 survives because
/// help is what F1 means everywhere and browsers leave it alone.
///
/// F2 and F4 join it for the same reason, and the reason is a
/// correction. The first version of this table put "jump to the command
/// line" on **Ctrl/Cmd+K** and the passage report on
/// **Ctrl/Cmd+Shift+R** — and both are the browser's: Cmd/Ctrl+K
/// focuses the address bar for a search, and Cmd/Ctrl+Shift+R is a hard
/// reload. Neither shows up as an error; the app simply never sees the
/// key, or worse, the reader loses a browser function they use daily.
/// Caught the first time these were pressed in a real browser, which is
/// the only place a shortcut can be tested at all.
///
/// So the rule this file already stated for `?` — plain Ctrl+C stays
/// the browser's copy, which is why the Copy Center has always carried
/// Shift as well — is applied to the whole table, and the reserved set
/// is pinned by `test/keyboard_shortcuts_test.dart` rather than left to
/// whoever adds the next row to remember.
///
/// F2 and F4 are unclaimed in page context by Chrome, Firefox and
/// Safari, where F3 is find, F5 reload, F6 the address bar, F11
/// fullscreen and F12 the developer tools. Using function keys here is
/// also the one place bwh44's own idiom survives the move to a browser.
///
/// Flutter-free apart from the key constants, so the table can be
/// asserted against the handler in a plain test.
library;

import 'package:flutter/services.dart'
    show HardwareKeyboard, KeyEvent, LogicalKeyboardKey;

enum WbShortcutId {
  /// Put the caret on the command line, wherever the reader is.
  focusCommandLine,

  /// The Copy Center (bwh28 + bwh29's Output Format Options).
  copyCenter,

  /// The Report Generator (bwh28).
  passageReport,

  /// This list.
  shortcutSheet,
}

class WbShortcut {
  const WbShortcut({
    required this.id,
    required this.key,
    required this.labelKey,
    this.ctrlOrMeta = false,
    this.shift = false,
  });

  final WbShortcutId id;
  final LogicalKeyboardKey key;

  /// The `ui_strings` key naming what it does.
  final String labelKey;

  /// Ctrl on Windows/Linux, Cmd on a Mac. One flag, because a shortcut
  /// that needed them told apart would be two shortcuts.
  final bool ctrlOrMeta;
  final bool shift;

  bool matches(KeyEvent e, HardwareKeyboard keys) {
    if (e.logicalKey != key) return false;
    final mod = keys.isControlPressed || keys.isMetaPressed;
    if (ctrlOrMeta != mod) return false;
    if (shift != keys.isShiftPressed) return false;
    return true;
  }

  /// How it is printed, with [mac] deciding ⌘ against Ctrl.
  ///
  /// Built here rather than in the sheet so the printed form and the
  /// matched form cannot disagree — the defect this whole file exists to
  /// prevent, one level down.
  String label({required bool mac}) {
    final parts = <String>[
      if (ctrlOrMeta) mac ? '⌘' : 'Ctrl',
      if (shift) mac ? '⇧' : 'Shift',
      _keyName(key),
    ];
    return parts.join(mac ? '' : '+');
  }
}

String _keyName(LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.f1) return 'F1';
  if (key == LogicalKeyboardKey.f2) return 'F2';
  if (key == LogicalKeyboardKey.f4) return 'F4';
  if (key == LogicalKeyboardKey.escape) return 'Esc';
  final label = key.keyLabel;
  return label.isEmpty ? key.debugName ?? '?' : label.toUpperCase();
}

/// Every shortcut the workbench answers to, in the order the sheet
/// prints them: the two a reader uses constantly, then the two they use
/// on purpose.
const List<WbShortcut> kWorkbenchShortcuts = [
  WbShortcut(
    id: WbShortcutId.focusCommandLine,
    key: LogicalKeyboardKey.f2,
    labelKey: 'shortcutFocusCommand',
  ),
  WbShortcut(
    id: WbShortcutId.copyCenter,
    key: LogicalKeyboardKey.keyC,
    ctrlOrMeta: true,
    shift: true,
    labelKey: 'shortcutCopyCenter',
  ),
  WbShortcut(
    id: WbShortcutId.passageReport,
    key: LogicalKeyboardKey.f4,
    labelKey: 'shortcutPassageReport',
  ),
  WbShortcut(
    id: WbShortcutId.shortcutSheet,
    key: LogicalKeyboardKey.f1,
    labelKey: 'shortcutSheet',
  ),
];

/// Esc is documented but NOT in the table, and the distinction is real.
///
/// Everything above is a shortcut that DOES something; Esc unpins the
/// Analysis pane and otherwise gets out of the way, deliberately without
/// consuming the key, so a dialog, a text field and the browser all keep
/// their own Esc. Putting it in the table would make the handler claim
/// it. It still belongs on the sheet, because a reader looking for "how
/// do I un-stick this pane" is looking at the sheet.
const String kEscapeLabelKey = 'shortcutEscape';

/// Chords a page may not take, because the browser answers them first.
///
/// Declared here and asserted by the test so the next row added to
/// `kWorkbenchShortcuts` meets the list rather than the reader.
/// Function keys the browser owns, then the Ctrl/Cmd letters — the two
/// at the end are the ones this table actually had to give back.
const List<LogicalKeyboardKey> kBrowserOwnedFunctionKeys = [
  LogicalKeyboardKey.f3, // find
  LogicalKeyboardKey.f5, // reload
  LogicalKeyboardKey.f6, // address bar
  LogicalKeyboardKey.f11, // fullscreen
  LogicalKeyboardKey.f12, // developer tools
];

/// `(key, shift)` pairs that Ctrl/Cmd already means something with.
const List<(LogicalKeyboardKey, bool)> kBrowserOwnedChords = [
  (LogicalKeyboardKey.keyC, false), // copy — the reader's selection
  (LogicalKeyboardKey.keyV, false), // paste
  (LogicalKeyboardKey.keyX, false), // cut
  (LogicalKeyboardKey.keyF, false), // find
  (LogicalKeyboardKey.keyP, false), // print
  (LogicalKeyboardKey.keyS, false), // save
  (LogicalKeyboardKey.keyT, false), // new tab
  (LogicalKeyboardKey.keyW, false), // close tab
  (LogicalKeyboardKey.keyN, false), // new window
  (LogicalKeyboardKey.keyL, false), // address bar
  (LogicalKeyboardKey.keyK, false), // address-bar search
  (LogicalKeyboardKey.keyR, false), // reload
  (LogicalKeyboardKey.keyR, true), // hard reload
];
