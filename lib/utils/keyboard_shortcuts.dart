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
/// Flutter-free apart from the key constants and `SingleActivator`, so
/// every table can be asserted against its handler in a plain test.
///
/// ## The other tables (2026-09-18)
///
/// The workbench table below was always one list read twice. The keys
/// bound anywhere else — the reading column's `[` `]` `/` `?`, the
/// command line's ↑ ↓ Esc, the plate viewer's arrows, a sheet's Enter —
/// were typed straight into each widget's `CallbackShortcuts`, and the
/// reading column kept a second shortcut dialog of its own that listed
/// four of its ten bindings. Two shortcut lists, neither complete,
/// and the menu printed `Ctrl+L` beside "Command line" a month after
/// the key had moved to F2 because Ctrl+L is the browser's.
///
/// 「sword所有的shortcut……是不是应该有一个page教我们怎么用」. The Help
/// page prints every key in the app, so every key in the app now lives
/// in a table here, and each widget builds its bindings FROM the table:
/// the rule the workbench table already followed, applied to the rest.
library;

import 'package:flutter/services.dart'
    show HardwareKeyboard, KeyEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart' show SingleActivator;

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

/// The row for [id]. Every id has exactly one — the test pins it.
WbShortcut workbenchShortcut(WbShortcutId id) =>
    kWorkbenchShortcuts.singleWhere((s) => s.id == id);

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

// ── Keys bound inside one surface ──────────────────────────────────

/// A key and the modifiers it needs, spelled the way `SingleActivator`
/// takes them — [meta] is ⌘ on a Mac and the Windows key elsewhere,
/// [control] is Ctrl everywhere. Unlike [WbShortcut.ctrlOrMeta] the two
/// are kept apart, because the reading column binds BOTH `⌘[` and
/// `Ctrl+[` and a reader should be shown the one their keyboard means.
class KeyChord {
  const KeyChord(
    this.key, {
    this.meta = false,
    this.control = false,
    this.shift = false,
  });

  final LogicalKeyboardKey key;
  final bool meta;
  final bool control;
  final bool shift;

  SingleActivator get activator =>
      SingleActivator(key, meta: meta, control: control, shift: shift);

  /// Whether a reader on [apple] hardware should be SHOWN this chord.
  ///
  /// Every chord is bound on every platform; this only decides what the
  /// Help page prints. A ⌘ chord is the Windows key on a PC — it works,
  /// and nobody reaches for it — and a Ctrl chord on a Mac is the one
  /// the ⌘ row beside it already covers.
  bool shownOn({required bool apple}) {
    if (meta) return apple;
    if (control) return !apple;
    return true;
  }

  String label({required bool mac}) {
    // `?` is Shift+/ on every layout this app is read on; printing
    // "Shift+?" would describe a key nobody can find.
    final showShift = shift && key != LogicalKeyboardKey.question;
    final parts = <String>[
      if (meta) mac ? '⌘' : 'Win',
      if (control) mac ? '⌃' : 'Ctrl',
      if (showShift) mac ? '⇧' : 'Shift',
      keyCapLabel(key),
    ];
    return parts.join(mac ? '' : '+');
  }
}

/// How one key is printed on the Help page — a key cap, not a debug
/// name. Public because the projection's keymap, which lives with the
/// projection, prints through it too.
String keyCapLabel(LogicalKeyboardKey key) {
  final fixed = <LogicalKeyboardKey, String>{
    LogicalKeyboardKey.escape: 'Esc',
    LogicalKeyboardKey.enter: 'Enter',
    LogicalKeyboardKey.numpadEnter: 'Enter',
    LogicalKeyboardKey.space: 'Space',
    LogicalKeyboardKey.backspace: '⌫',
    LogicalKeyboardKey.pageUp: 'PgUp',
    LogicalKeyboardKey.pageDown: 'PgDn',
    LogicalKeyboardKey.arrowUp: '↑',
    LogicalKeyboardKey.arrowDown: '↓',
    LogicalKeyboardKey.arrowLeft: '←',
    LogicalKeyboardKey.arrowRight: '→',
    LogicalKeyboardKey.bracketLeft: '[',
    LogicalKeyboardKey.bracketRight: ']',
    LogicalKeyboardKey.slash: '/',
    LogicalKeyboardKey.question: '?',
    LogicalKeyboardKey.comma: ',',
    LogicalKeyboardKey.period: '.',
    // `=` is the key that prints `+`; see the projection's keymap.
    LogicalKeyboardKey.equal: '+',
    LogicalKeyboardKey.add: '+',
    LogicalKeyboardKey.numpadAdd: '+',
    LogicalKeyboardKey.minus: '−',
    LogicalKeyboardKey.numpadSubtract: '−',
  };
  return fixed[key] ?? _keyName(key);
}

/// One row of a surface's key table: what it does, which key does it.
///
/// Generic over the surface's own action enum so each widget can switch
/// over its ids exhaustively — adding a row does not compile until the
/// widget answers it, the rule [WbShortcutId] set for the workbench.
class BoundKey<T extends Enum> {
  const BoundKey(this.id, this.chord, this.labelKey);

  final T id;
  final KeyChord chord;

  /// The `ui_strings` key naming what it does.
  final String labelKey;
}

/// The reading column. Active while it has focus and no text field
/// does — the column is wrapped in a `Focus`, so clicking a verse is
/// what arms these.
enum ReaderKey { previousChapter, nextChapter, search, help, settings }

const List<BoundKey<ReaderKey>> kReaderShortcuts = [
  BoundKey(ReaderKey.previousChapter,
      KeyChord(LogicalKeyboardKey.bracketLeft), 'previousChapter'),
  BoundKey(ReaderKey.nextChapter, KeyChord(LogicalKeyboardKey.bracketRight),
      'nextChapter'),
  BoundKey(ReaderKey.search, KeyChord(LogicalKeyboardKey.slash),
      'keySearchFromReader'),
  BoundKey(ReaderKey.help,
      KeyChord(LogicalKeyboardKey.question, shift: true), 'keyOpenHelp'),
  // ⌘ for a Mac and an iPad with a keyboard (2026-05-24, v1.3.17)…
  BoundKey(ReaderKey.previousChapter,
      KeyChord(LogicalKeyboardKey.bracketLeft, meta: true), 'previousChapter'),
  BoundKey(ReaderKey.nextChapter,
      KeyChord(LogicalKeyboardKey.bracketRight, meta: true), 'nextChapter'),
  BoundKey(ReaderKey.search, KeyChord(LogicalKeyboardKey.keyF, meta: true),
      'keySearchFromReader'),
  BoundKey(ReaderKey.settings, KeyChord(LogicalKeyboardKey.comma, meta: true),
      'settings'),
  // …and Ctrl for Windows and Linux, which have no ⌘. Deliberately no
  // Ctrl+F: that is the browser's find, and on a Mac it is line-start.
  BoundKey(ReaderKey.previousChapter,
      KeyChord(LogicalKeyboardKey.bracketLeft, control: true),
      'previousChapter'),
  BoundKey(ReaderKey.nextChapter,
      KeyChord(LogicalKeyboardKey.bracketRight, control: true), 'nextChapter'),
];

/// The command line, while the caret is in it.
enum CommandLineKey { clear, older, newer }

const List<BoundKey<CommandLineKey>> kCommandLineShortcuts = [
  BoundKey(CommandLineKey.older, KeyChord(LogicalKeyboardKey.arrowUp),
      'keyRecallOlder'),
  BoundKey(CommandLineKey.newer, KeyChord(LogicalKeyboardKey.arrowDown),
      'keyRecallNewer'),
  BoundKey(CommandLineKey.clear, KeyChord(LogicalKeyboardKey.escape),
      'keyClearLine'),
];

/// The full-screen illustration viewer.
enum PlateViewerKey { close, previous, next }

const List<BoundKey<PlateViewerKey>> kPlateViewerShortcuts = [
  BoundKey(PlateViewerKey.previous, KeyChord(LogicalKeyboardKey.arrowLeft),
      'keyPreviousPlate'),
  BoundKey(PlateViewerKey.next, KeyChord(LogicalKeyboardKey.arrowRight),
      'keyNextPlate'),
  BoundKey(PlateViewerKey.close, KeyChord(LogicalKeyboardKey.escape), 'close'),
];

/// The two pickers that edit a setting and then apply it — Search
/// scope and the version stack.
enum PickerSheetKey { apply, close }

const List<BoundKey<PickerSheetKey>> kPickerSheetShortcuts = [
  BoundKey(PickerSheetKey.apply, KeyChord(LogicalKeyboardKey.enter),
      'keyApplyPicker'),
  BoundKey(PickerSheetKey.close, KeyChord(LogicalKeyboardKey.escape), 'close'),
];
