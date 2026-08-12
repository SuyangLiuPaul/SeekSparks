import 'package:flutter/material.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/utils/build_verse_content_spans.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/responsive.dart';

/// 2026-08-12 (docs/DATA-INTEGRITY.md check 31): the psalm title an
/// edition prints above verse 1 — *"A Psalm of David, when Nathan the
/// prophet came to him…"*.
///
/// Rendered ABOVE the verse, unnumbered, italic and a little smaller,
/// which is how print Bibles set it. It is not a [BlockNoteCard]: a
/// block note is an editor's commentary about the verse, and this is
/// scripture — Hebrew verse 1 — so it gets no card, no tint and no
/// left rule, only the type distinction the publisher uses.
///
/// The markup goes through [buildAnnotatedSpans], not `Text`, because
/// every one of the LEB's 116 superscriptions ends in `<note: The
/// Hebrew Bible counts the superscription as the first verse of the
/// psalm; the English verse number is reduced by one>`. Printed raw
/// that footnote is longer than most of the titles it follows.
class SuperscriptionLine extends StatelessWidget {
  final String text;
  final AppSettings settings;

  /// Extra left inset, so the title lines up with the verse it sits
  /// above rather than with the page edge.
  final double? leftIndent;

  const SuperscriptionLine({
    super.key,
    required this.text,
    required this.settings,
    this.leftIndent,
  });

  @override
  Widget build(BuildContext context) {
    final dc = ResponsiveBreakpoints.classOf(MediaQuery.of(context).size.width);
    final baseIndent = ResponsiveBreakpoints.verseIndent(dc);
    final fs = settings.fontSize * 0.88;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        leftIndent ?? baseIndent,
        settings.fontSize * 0.35,
        baseIndent,
        settings.fontSize * 0.15,
      ),
      child: RichText(
        textAlign: TextAlign.start,
        text: TextSpan(
          style: TextStyle(
            fontSize: fs,
            fontFamily: settings.fontFamily,
            fontFamilyFallback: kCjkFontFallback,
            height: settings.lineSpacing,
            fontStyle: FontStyle.italic,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          children: buildAnnotatedSpans(
            raw: text,
            context: context,
            settings: settings,
            locale: settings.locale,
            isSelected: false,
            italic: true,
            fontSize: fs,
          ),
        ),
      ),
    );
  }
}
