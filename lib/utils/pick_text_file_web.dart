/// Web half of the file picker — see `pick_text_file.dart`.
///
/// One `<input type=file>`, clicked, read with a `FileReader`. The
/// element is never added to the document: it exists for the length of
/// one dialog and is collected with the closure.
///
/// Resolves to null on cancel AND on a read error, and the two are the
/// same to the caller on purpose — a reader who cancelled wants nothing
/// said, and one whose file could not be read is better served by the
/// importer's own message than by a second one from here.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

typedef PickedTextFile = ({String name, String text});

bool get canPickTextFile => true;

Future<PickedTextFile?> pickTextFile() {
  final done = Completer<PickedTextFile?>();
  try {
    final input =
        web.document.createElement('input') as web.HTMLInputElement;
    input.type = 'file';
    // A hint, not a gate: the browser still lets the reader pick
    // anything, and the validator is what actually decides. Narrowing
    // the dialog is a courtesy to the reader, never a check.
    input.accept = '.json,application/json,text/plain';
    input.onchange = (web.Event _) {
      final files = input.files;
      if (files == null || files.length == 0) {
        if (!done.isCompleted) done.complete(null);
        return;
      }
      final file = files.item(0)!;
      final reader = web.FileReader();
      reader.onload = (web.Event _) {
        final r = reader.result;
        if (!done.isCompleted) {
          done.complete(r == null || r.isUndefinedOrNull
              ? null
              : (name: file.name, text: (r as JSString).toDart));
        }
      }.toJS;
      reader.onerror = (web.Event _) {
        if (!done.isCompleted) done.complete(null);
      }.toJS;
      reader.readAsText(file);
    }.toJS;
    // Cancel fires no event in every browser, so the future would hang
    // for a reader who changed their mind. `oncancel` is supported where
    // it matters and harmless where it is not.
    input.oncancel = (web.Event _) {
      if (!done.isCompleted) done.complete(null);
    }.toJS;
    input.click();
  } catch (_) {
    if (!done.isCompleted) done.complete(null);
  }
  return done.future;
}
