/// The strip that says a word is pinned, and lets go of it.
///
/// It sits above the Analysis tab content rather than inside any one
/// pane because a pin suppresses hover for **all** of them: a reader who
/// pinned a word and then switched to KWIC would otherwise be looking at
/// a pane that had silently stopped following the mouse, with no marker
/// anywhere and no way out but guessing.
///
/// It also carries the whole affordance after the reader navigates. A
/// pin survives a chapter change (see `_pinnedKey` in workbench_page),
/// so the gold marker in the text can be off screen while the pin still
/// stands — at which point this bar is the only thing that says so.
library;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;

class AnalysisPinBar extends StatelessWidget {
  const AnalysisPinBar({
    super.key,
    required this.word,
    required this.reference,
    required this.locale,
    required this.onUnpin,
  });

  /// The pinned word as printed — Greek, Hebrew or a tagged translation
  /// run, so it needs the CJK fallback like any other scripture text.
  final String word;
  final String reference;
  final String locale;
  final VoidCallback onUnpin;

  String _s(String key, String fallback) =>
      uiStrings[key]?[locale] ?? uiStrings[key]?['en'] ?? fallback;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final label = _s('analysisPinned', 'Pinned');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: wb.selectionBg,
        border: Border(bottom: BorderSide(color: wb.pinMark, width: 1.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.push_pin, size: t.chrome, color: wb.pinMark),
          const SizedBox(width: 5),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '$label  ',
                  style: TextStyle(
                    fontSize: t.chrome,
                    fontWeight: FontWeight.w700,
                    color: wb.mutedText,
                  ),
                ),
                TextSpan(
                  text: word,
                  style: TextStyle(
                    fontSize: t.chrome,
                    fontWeight: FontWeight.w600,
                    color: wb.text,
                    fontFamilyFallback: kCjkFontFallback,
                  ),
                ),
                if (reference.isNotEmpty)
                  TextSpan(
                    text: '  $reference',
                    style: TextStyle(
                      fontSize: t.chrome,
                      color: wb.mutedText,
                      fontFamilyFallback: kCjkFontFallback,
                    ),
                  ),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // A worded button, not a bare ✕. This is the guaranteed exit
          // from a state the reader may not remember entering, and it
          // has to read as one at a glance.
          Tooltip(
            message: _s('analysisUnpinHint',
                'Release the pin — or press Esc, or click the word again'),
            child: TextButton(
              onPressed: onUnpin,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: wb.link,
              ),
              child: Text(
                _s('analysisUnpin', 'Unpin'),
                style: TextStyle(
                  fontSize: t.chrome,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
