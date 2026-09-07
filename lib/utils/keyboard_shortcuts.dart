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
/// The rest are Ctrl/Cmd combinations chosen to avoid what the browser
/// and the page already own: plain Ctrl+C stays the browser's copy —
/// taking it for a dialog would break copying a selection the reader
/// made with the mouse, which is why the Copy Center has always been on
/// Shift as well.
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
    key: LogicalKeyboardKey.keyK,
    ctrlOrMeta: true,
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
    key: LogicalKeyboardKey.keyR,
    ctrlOrMeta: true,
    shift: true,
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
