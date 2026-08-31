import 'package:flutter/painting.dart' show TextSpan, TextStyle;

import 'package:seeksparks/utils/search_highlight.dart';

/// 2026-08-31 (owner-reported): the search results mark the hit on
/// screen, and then the copy of those same results arrives in the
/// document as undifferentiated prose — "这样 Document 就容易区分" is
/// exactly what is lost. The pane knows which word answered the query;
/// the clipboard was throwing that away.
///
/// The clipboard carries two flavours, and only one of them can hold a
/// mark. `text/html` is what Word, Pages and Google Docs paste when it
/// is offered; `text/plain` is what a code box, a search field or a
/// terminal takes, and it has no way to say "this word". So the mark
/// travels as a pair of sentinels embedded in one string, and the two
/// flavours are derived from it at the end: [hitMarkedHtml] turns the
/// sentinels into styled spans, [stripHitMarks] deletes them.
///
/// Why sentinels rather than building the HTML directly: the marking
/// has to survive everything the Copy Center does AFTER the verse text
/// is chosen — quoting, reference labels, verse numbers, interleaving,
/// the attribution block. Rendering to HTML at the verse and then
/// concatenating would mean escaping the surrounding furniture
/// separately and getting it wrong somewhere. One marked string, one
/// escape pass, two flavours out.
///
/// U+0001/U+0002 are control characters. They cannot occur in scripture
/// text, in a book name, or in a reader's reference template, so a
/// round-trip through them cannot collide with content.
const String hitOpen = '\u0001';
const String hitClose = '\u0002';

/// Whether [s] carries any mark — the caller's cue that a `text/html`
/// flavour is worth offering at all.
bool hasHitMarks(String s) => s.contains(hitOpen);

/// Wrap the hit spans of [spans] in sentinels.
///
/// Null [spans] means "nothing markable here" — an untagged edition
/// asked for a Strong's hit, or a query with no terms — and returns
/// [text] untouched, which is the honest output rather than a guess.
String markHits(String text, List<HighlightSpan>? spans) {
  if (spans == null || spans.isEmpty) return text;
  if (!spans.any((s) => s.isHit)) return text;
  final buf = StringBuffer();
  for (final s in spans) {
    if (s.isHit) {
      buf
        ..write(hitOpen)
        ..write(s.text)
        ..write(hitClose);
    } else {
      buf.write(s.text);
    }
  }
  return buf.toString();
}

/// One verse's text with whatever the active query found in it marked.
///
/// The two query kinds reach the words by different routes and this is
/// the only place that has to know it:
///
///   * A **text** query knows its own terms, so any edition can mark it.
///   * A **Strong's** query knows a NUMBER. Which word carries H430 is
///     knowable only from the tagged layer, so [runs] must be supplied
///     and an edition that ships none (NASB, 梁家铿, 雅偉版繁體 today)
///     marks nothing — the same constraint the results list works
///     under, for the same reason. Passing null [runs] is not an error.
///
/// Returns [text] unchanged when nothing is markable.
String markVerseHits(
  String text, {
  required SearchHighlight highlight,
  List<({String text, String strongs})>? runs,
}) {
  if (text.isEmpty || highlight.isEmpty) return text;
  if (highlight.strongsNumbers.isNotEmpty ||
      highlight.strongsPrefixes.isNotEmpty) {
    return markHits(
      text,
      strongsSnippetSpans(preview: text, runs: runs, highlight: highlight),
    );
  }
  return markHits(text, splitOnTerms(text, highlight.textTerms));
}

/// The brackets the plain-text flavour marks a hit with.
///
/// 2026-08-31, second round (owner-reported): "复制粘贴 txt 里面就没用了
/// format" — and, as it turned out, Word and Pages did not take the
/// rich flavour either. A mark that exists only as colour is a mark
/// that most destinations drop, so the words now say it themselves.
///
/// Lenticular brackets rather than the `[God]` first suggested, because
/// square brackets already mean something in this corpus and would be
/// read as that meaning: `[ ]` is a translator's supplied word, and the
/// divine-name glosses print it unconditionally — 主[雅伟], 主[基督].
/// Marking a hit the same way would make 主[雅伟] and a hit on 主
/// indistinguishable. 【 】 occurs nowhere in any shipped edition
/// (checked across cuvs-yhwh, bsb and kjvs: zero), reads as deliberate
/// in a Chinese handout, and is unmistakably a marker in an English one.
const String kPlainHitOpen = '【';
const String kPlainHitClose = '】';

/// The `text/plain` flavour: the hit in brackets the destination cannot
/// strip. This is what a .txt file, a code box or a mail client's
/// plain-text part receives — and, whenever the rich flavour is
/// refused, what Word and Pages receive too.
String plainHitMarks(
  String marked, {
  String open = kPlainHitOpen,
  String close = kPlainHitClose,
}) =>
    marked.replaceAll(hitOpen, open).replaceAll(hitClose, close);

/// The same words with the marking removed entirely — for a caller that
/// wants the verse as the edition prints it, and for proving that
/// marking changed nothing else.
String stripHitMarks(String marked) =>
    marked.replaceAll(hitOpen, '').replaceAll(hitClose, '');

/// The colour a marked word arrives in. A pale yellow wash plus weight,
/// not the app's own accent: the destination is somebody else's
/// document, where an unfamiliar brand colour reads as damage and a
/// highlighter does not. Both are set because a mono-colour print of
/// the handout keeps the bold once the wash is gone.
const String kHitHtmlStyle = 'background-color:#ffe9a3;font-weight:700';

/// The `text/html` flavour.
///
/// Escapes once, over the whole document, then substitutes the
/// sentinels — so a `<` in a translator's note is escaped and a mark is
/// not, without either pass having to know about the other.
///
/// Newlines become `<br>` rather than relying on `white-space:pre-wrap`,
/// which Word honours inconsistently on paste.
String hitMarkedHtml(String marked, {String hitStyle = kHitHtmlStyle}) {
  final escaped =
      _esc(marked).replaceAll('\r\n', '\n').replaceAll('\n', '<br>');
  final body = escaped
      .replaceAll(hitOpen, '<span style="$hitStyle">')
      .replaceAll(hitClose, '</span>');
  return '<div style="line-height:1.5">$body</div>';
}

/// The marked string as styled spans, for showing the reader what the
/// paste will look like before they make it.
List<TextSpan> hitMarkedSpans(
  String marked, {
  TextStyle? base,
  required TextStyle hit,
}) {
  final out = <TextSpan>[];
  var cursor = 0;
  while (cursor < marked.length) {
    final open = marked.indexOf(hitOpen, cursor);
    if (open < 0) {
      out.add(TextSpan(text: marked.substring(cursor), style: base));
      break;
    }
    if (open > cursor) {
      out.add(TextSpan(text: marked.substring(cursor, open), style: base));
    }
    final close = marked.indexOf(hitClose, open + 1);
    if (close < 0) {
      // Unbalanced: show the rest plainly rather than dropping it.
      out.add(TextSpan(text: marked.substring(open + 1), style: base));
      break;
    }
    out.add(TextSpan(text: marked.substring(open + 1, close), style: hit));
    cursor = close + 1;
  }
  return out;
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
