/// bwh44 — `docs/PARITY-BACKLOG.md` §3.7, whose whole requirement was
/// one sentence: *"a shortcut nobody can find is not a feature."*
///
/// So the guards are not about whether a key works. They are about the
/// LIST and the HANDLER being the same list, and about the sheet
/// printing what the handler actually matches — the drift that turns a
/// help page into a lie.
library;

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/utils/keyboard_shortcuts.dart';

void main() {
  group('one table, read twice', () {
    test('every id in the enum has exactly one row', () {
      // The handler switches over the enum exhaustively, so an id with
      // no row is a shortcut nothing can trigger and an id with two is
      // a key whose behaviour depends on list order.
      for (final id in WbShortcutId.values) {
        expect(kWorkbenchShortcuts.where((s) => s.id == id), hasLength(1),
            reason: id.name);
      }
      expect(kWorkbenchShortcuts, hasLength(WbShortcutId.values.length));
    });

    test('no two shortcuts share a chord', () {
      // Two rows on one chord means the earlier one wins and the later
      // one is dead — and the sheet would print both as if they worked.
      final seen = <String>{};
      for (final s in kWorkbenchShortcuts) {
        final chord = '${s.key.keyId}/${s.ctrlOrMeta}/${s.shift}';
        expect(seen.add(chord), isTrue, reason: s.id.name);
      }
    });

    test('every row has a label in all three locales', () {
      for (final s in kWorkbenchShortcuts) {
        for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
          final v = uiStrings[s.labelKey]?[locale];
          expect(v, isNotNull, reason: '${s.labelKey} [$locale]');
          expect((v as String).trim(), isNotEmpty,
              reason: '${s.labelKey} [$locale]');
        }
      }
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        expect(uiStrings[kEscapeLabelKey]?[locale], isNotNull,
            reason: locale);
        expect(uiStrings['shortcutSheetTitle']?[locale], isNotNull,
            reason: locale);
      }
    });
  });

  group('what the sheet prints is what the handler matches', () {
    test('a modifier in the label is a modifier in the match', () {
      for (final s in kWorkbenchShortcuts) {
        final win = s.label(mac: false);
        expect(win.contains('Ctrl'), s.ctrlOrMeta, reason: s.id.name);
        expect(win.contains('Shift'), s.shift, reason: s.id.name);
        final mac = s.label(mac: true);
        expect(mac.contains('⌘'), s.ctrlOrMeta, reason: s.id.name);
        expect(mac.contains('⇧'), s.shift, reason: s.id.name);
      }
    });

    test('the key itself is named, not left as a debug string', () {
      for (final s in kWorkbenchShortcuts) {
        final label = s.label(mac: false);
        expect(label, isNot(contains('?')), reason: s.id.name);
        expect(label.trim(), isNotEmpty, reason: s.id.name);
      }
      // The two that are not plain letters, spelled the way a reader
      // expects to see them.
      final sheet = kWorkbenchShortcuts
          .firstWhere((s) => s.id == WbShortcutId.shortcutSheet);
      expect(sheet.label(mac: false), 'F1');
    });
  });

  group('what this app may not take from the browser', () {
    test('plain Ctrl+C is left alone', () {
      // Taking it for a dialog would break copying a selection the
      // reader made with the mouse — which is why the Copy Center has
      // always carried Shift as well.
      final bare = kWorkbenchShortcuts.where((s) =>
          s.key == LogicalKeyboardKey.keyC && s.ctrlOrMeta && !s.shift);
      expect(bare, isEmpty);
    });

    test('no function key the browser owns', () {
      // bwh44 is an F1–F12 set, which is a Windows-desktop idiom. F3,
      // F5, F6, F11 and F12 belong to the browser; F1 survives because
      // help is what F1 means and browsers leave it alone.
      const takenByBrowser = [
        LogicalKeyboardKey.f3,
        LogicalKeyboardKey.f5,
        LogicalKeyboardKey.f6,
        LogicalKeyboardKey.f11,
        LogicalKeyboardKey.f12,
      ];
      for (final s in kWorkbenchShortcuts) {
        expect(takenByBrowser.contains(s.key), isFalse, reason: s.id.name);
      }
    });

    test('Esc is documented but not claimed', () {
      // It unpins and otherwise gets out of the way WITHOUT consuming
      // the key, so a dialog, a text field and the browser all keep
      // their own Esc. A row in this table would make the handler claim
      // it.
      expect(
        kWorkbenchShortcuts
            .where((s) => s.key == LogicalKeyboardKey.escape),
        isEmpty,
      );
    });
  });
}
