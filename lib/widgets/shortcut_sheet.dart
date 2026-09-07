/// The shortcut list — bwh44's other half.
///
/// §3.7 put the requirement in one line: *"a shortcut nobody can find is
/// not a feature."* So the list is on the Help menu AND on F1, and it is
/// printed from `kWorkbenchShortcuts` — the same table the handler
/// dispatches from, including the key names, which are built by
/// `WbShortcut.label` rather than typed here.
library;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/utils/keyboard_shortcuts.dart';

Future<void> showShortcutSheet(BuildContext context, String locale) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ShortcutSheet(locale: locale),
  );
}

class _ShortcutSheet extends StatelessWidget {
  const _ShortcutSheet({required this.locale});

  final String locale;

  String _s(String key, String fallback) =>
      uiStrings[key]?[locale] ?? fallback;

  @override
  Widget build(BuildContext context) {
    final c = WbColors.of(context);
    final t = WbType.of(context);
    // ⌘ on a Mac and on iOS, Ctrl everywhere else — including the web,
    // where the platform reported is the one the browser runs on, which
    // is the one whose keyboard the reader is looking at.
    final mac = defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS;

    Widget row(String keys, String what) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 96,
                child: Text(
                  keys,
                  style: TextStyle(
                    fontSize: t.chrome,
                    color: c.link,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  what,
                  style: TextStyle(fontSize: t.chrome, color: c.text),
                ),
              ),
            ],
          ),
        );

    return AlertDialog(
      backgroundColor: c.paneBg,
      title: Text(
        _s('shortcutSheetTitle', 'Keyboard shortcuts'),
        style: TextStyle(fontSize: t.text, color: c.text),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final sc in kWorkbenchShortcuts)
              row(sc.label(mac: mac), _s(sc.labelKey, sc.id.name)),
            // Esc is documented but not dispatched — see the note on
            // `kEscapeLabelKey`. It belongs here because a reader
            // looking for "how do I un-stick this pane" looks here.
            row('Esc', _s(kEscapeLabelKey, 'Unpin the Analysis pane')),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_s('close', 'Close'),
              style: TextStyle(fontSize: t.chrome, color: c.link)),
        ),
      ],
    );
  }
}
