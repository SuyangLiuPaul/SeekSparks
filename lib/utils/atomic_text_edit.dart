import 'package:flutter/widgets.dart';

/// Set a text field's content and caret in ONE assignment.
///
/// `controller.text = x` is not a plain setter: it publishes a value
/// whose selection is `TextSelection.collapsed(offset: -1)`. A following
/// `controller.selection = …` is a *second* publication. On iOS the
/// platform text input is asynchronous, so the engine can latch that
/// first, caret-less state and echo it back after the framework has
/// already moved on — leaving the field holding a selection that no
/// longer describes its text. The next keystroke is then applied against
/// that stale range and takes the whole line with it. One assignment
/// leaves no window for the two to disagree.
///
/// `composing` is cleared deliberately rather than incidentally. The
/// command line is an IME surface — BibleWorks gave Chinese, Japanese
/// and Korean input its own command-line mode for exactly this reason —
/// and a composing range measured against the *old* text can point past
/// the end of the new text.
extension AtomicTextEdit on TextEditingController {
  /// Replace the whole field. [caret] defaults to the end of [text] and
  /// is clamped into range: publishing an out-of-range selection is the
  /// failure this helper exists to make unrepresentable.
  void setTextAtomic(String text, {int? caret}) {
    value = TextEditingValue(
      text: text,
      selection:
          TextSelection.collapsed(offset: (caret ?? text.length).clamp(0, text.length)),
      composing: TextRange.empty,
    );
  }
}
