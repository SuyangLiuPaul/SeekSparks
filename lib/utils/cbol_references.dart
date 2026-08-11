/// CBOL scripture-reference markup, parsed into typed runs.
///
/// The Chinese lexicon columns bundled with the app — CBOL's `glossZh` /
/// `defZh` on [StrongsEntry], and the BDB/Thayer senses behind
/// `ChineseLexiconService` — cite scripture in a delimiter notation that
/// was never meant to reach a reader:
///
///     结束, 完成 (#路 14:19-30|)
///     1) 犹大境内地方 #代上 2:51 |
///     (在#代上8:3 |是便雅悯家的一员)
///     (#徒 25:15; 帖后 1:9; 犹7)
///
/// A `#` opens a citation list; a `|` closes it; the surrounding
/// parentheses are optional and so is the space after `#`. Measured over
/// the four bundled assets: 39,106 `#` sites carrying 44,304 citations,
/// in 11,337 of 28,893 entries. Before this parser every one of those
/// delimiters printed verbatim — for the median Greek gloss, 62% of the
/// characters on screen were markup rather than meaning.
///
/// Three things the grammar does that a naive reader of it would miss,
/// all established by measuring the corpus rather than assumed:
///
///  * **The book token is inherited.** `(#提后 1:16-18; 4:19|)` cites
///    2 Timothy twice. A citation with no book belongs to the previous
///    citation's book, and a block that opens without one is malformed.
///  * **A hyphen is a passage span, not a pair.** `路 14:19-30` is the
///    whole parable, so a link must open its FIRST verse and must never
///    be expanded into a verse list.
///  * **A comma stays inside one chapter; a semicolon starts a new
///    citation.** `太 1:13, 14` is one reference; `徒 25:15; 帖后 1:9`
///    is two.
///
/// Everything this parser cannot read is passed through as plain text,
/// `#` and all. That is deliberate: a reference the app cannot resolve
/// must look unresolved, not silently vanish and not link somewhere
/// plausible. 673 of the 39,106 sites take that path (1.7%) — mostly
/// genuine typos in the source data, catalogued in
/// `docs/DATA-INTEGRITY.md` check 28.
library;

import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/painting.dart';

import 'reference_parser.dart' show parseReference, resolveBookName;

enum CbolRunKind {
  /// Ordinary text, printed as-is.
  text,

  /// A scripture citation. [CbolRun.text] is exactly as the lexicon
  /// wrote it; [CbolRun.reference] is a resolvable English form.
  reference,
}

class CbolRun {
  const CbolRun.text(this.text)
      : kind = CbolRunKind.text,
        englishBook = null,
        chapter = null,
        verse = null;

  const CbolRun.reference(
    this.text, {
    required String this.englishBook,
    required int this.chapter,
    required this.verse,
  }) : kind = CbolRunKind.reference;

  final CbolRunKind kind;

  /// The source characters, minus the `#` and `|` delimiters.
  final String text;

  /// Canonical English book for a [CbolRunKind.reference] run, so the
  /// span resolves the same way whatever script the entry is written
  /// in. Null for text runs.
  final String? englishBook;
  final int? chapter;

  /// The FIRST verse of the citation — a span opens where it begins.
  /// Null when the lexicon cited a whole chapter (`士 4`).
  final int? verse;

  /// `Luke 14:19`, for logging and tests.
  String? get reference => englishBook == null
      ? null
      : verse == null
          ? '$englishBook $chapter'
          : '$englishBook $chapter:$verse';

  @override
  String toString() => kind == CbolRunKind.text
      ? 'text(${text.replaceAll('\n', r'\n')})'
      : 'ref($text -> $reference)';
}

// A CJK book token, then either `chapter:verses` or a bare number that
// means a whole chapter (`士 4`, `徒 10章`) — or, in a single-chapter
// book, a verse (`犹 7`, which `parseReference` re-reads as Jude 1:7).
const String _halfVerse = r'(?:[ ]?[a-z](?![a-zA-Z]))?';

const String _verseItem = r'(?:\d{1,3}[ ]*[:：][ ]*)?\d{1,3}' + _halfVerse +
    r'(?:[ ]*[-–—－~][ ]*(?:\d{1,3}[ ]*[:：][ ]*)?\d{1,3}' + _halfVerse + r')?';

const String _verseList =
    '$_verseItem(?:[ ]*,[ ]*$_verseItem)*';

final RegExp _citation = RegExp(
  r'([㐀-鿿]{1,5})?[ 　]*'
  '(?:(\\d{1,3})[ ]*[:：][ ]*($_verseList)'
  r'|(\d{1,3})[ ]*(?:[-–—][ ]*\d{1,3})?[ ]*章?)',
);

// A `|` may appear BETWEEN citations as well as at the end of a block:
// `(#罗 9:20|; 提前 2:13|)` closes the first citation before the second.
final RegExp _separator = RegExp(r'[ 　]*\|?[ 　]*[,;，；、][ 　]*');
final RegExp _leadingDigits = RegExp(r'\d{1,3}');

// 643 blocks in 627 entries kept their closing `|` but lost the opening
// `#`: `持有人 (徒 4:34|)`. Without the opener the citation is inert and
// the pipe prints.
final RegExp _lostOpener = RegExp(r'\(([^()\n#|]{1,60})\)?\|');

/// Puts back an opener the import dropped — but only when the
/// parenthesis holds nothing except a citation list, so a note that
/// happens to sit beside a pipe is never promoted to a reference.
String _restoreLostOpeners(String source) {
  if (!source.contains('|')) return source;
  return source.replaceAllMapped(_lostOpener, (m) {
    final body = m.group(1)!;
    final probe = _readBlock('#$body|', 0);
    if (probe == null || probe.citationsEnd < body.trimRight().length + 1) {
      return m.group(0)!;
    }
    return m.group(0)!.replaceFirst('(', '(#');
  });
}

class _Citation {
  _Citation(this.start, this.end, this.book, this.chapter, this.verse);
  final int start;
  final int end;
  final String book;
  final int chapter;
  final int? verse;
}

/// Splits [source] into text and citation runs. Concatenating every
/// run's `text` reproduces [source] minus the `#`/`|` delimiters.
List<CbolRun> parseCbolRuns(String rawSource) {
  final source = _restoreLostOpeners(rawSource);
  if (!source.contains('#')) return [CbolRun.text(source)];

  final runs = <CbolRun>[];
  final buf = StringBuffer();
  void flush() {
    if (buf.isNotEmpty) {
      runs.add(CbolRun.text(buf.toString()));
      buf.clear();
    }
  }

  var i = 0;
  while (true) {
    final hash = source.indexOf('#', i);
    if (hash < 0) break;
    final block = _readBlock(source, hash);
    if (block == null) {
      // Not a citation — keep the '#' so an unreadable reference looks
      // unreadable instead of disappearing.
      buf.write(source.substring(i, hash + 1));
      i = hash + 1;
      continue;
    }
    buf.write(source.substring(i, hash));
    flush();
    var prev = block.contentStart;
    for (final c in block.citations) {
      if (c.start > prev) {
        // Any `|` in here separated two citations — a delimiter, not text.
        runs.add(CbolRun.text(source.substring(prev, c.start).replaceAll('|', '')));
      }
      runs.add(CbolRun.reference(
        source.substring(c.start, c.end),
        englishBook: c.book,
        chapter: c.chapter,
        verse: c.verse,
      ));
      prev = c.end;
    }
    // Whatever sat between the last readable citation and the closer is
    // text — never dropped, or a defective reference would vanish.
    if (block.closerStart > prev) {
      buf.write(source.substring(prev, block.closerStart));
    }
    i = block.end;
    // Dropping `|` must not weld a note onto the reference before it:
    // `(#代上 3:5|译作 拔书亚)` has to keep a gap.
    if (block.hadCloser &&
        i < source.length &&
        !' 　\n)）'.contains(source[i])) {
      buf.write(' ');
    }
  }
  buf.write(source.substring(i));
  flush();
  return runs;
}

class _Block {
  _Block(this.contentStart, this.closerStart, this.end, this.citations);

  /// First character after the `#` and any spaces.
  final int contentStart;

  /// Where the closing `|` sits. Equal to [end] when the block had no
  /// closer — some are terminated by a `)` or by the end of the line.
  final int closerStart;

  /// One past the block, closer consumed.
  final int end;
  final List<_Citation> citations;

  bool get hadCloser => closerStart != end;

  /// One past the last citation the parser could read.
  int get citationsEnd => citations.last.end;
}

/// Reads the citation list opened by the `#` at [hash]. Null when
/// nothing there parses as a reference.
_Block? _readBlock(String source, int hash) {
  var k = hash + 1;
  while (k < source.length && (source[k] == ' ' || source[k] == '　')) {
    k++;
  }
  final contentStart = k;
  final citations = <_Citation>[];
  String? book;

  while (true) {
    var resume = k;
    if (citations.isNotEmpty) {
      final sep = _separator.matchAsPrefix(source, k);
      if (sep == null) break;
      k = sep.end;
    }
    final m = _citation.matchAsPrefix(source, k);
    if (m == null || m.end == m.start) {
      k = resume;
      break;
    }
    final token = m.group(1);
    if (token != null) {
      final canonical = resolveBookName(token);
      if (canonical == null) {
        k = resume;
        break;
      }
      book = canonical;
    }
    if (book == null) {
      k = resume;
      break;
    }
    if (m.group(2) != null) {
      final first = _leadingDigits.firstMatch(m.group(3)!)!.group(0)!;
      citations.add(_Citation(
          k, m.end, book, int.parse(m.group(2)!), int.parse(first)));
    } else {
      // A bare number after a single-chapter book is a VERSE — `犹7`
      // is Jude 1:7, not chapter 7. `parseReference` already knows
      // which five books those are, so ask it rather than keeping a
      // second copy of the list here.
      final whole = parseReference('$book ${m.group(4)}');
      if (whole == null) {
        k = resume;
        break;
      }
      citations.add(_Citation(
          k, m.end, book, whole.chapter, whole.verseStart));
    }
    k = m.end;
  }

  if (citations.isEmpty) return null;

  // The `|` terminates the block whether or not every citation inside
  // it parsed: `(#提前 3:3, 多:1:7|)` has a typo in its second citation,
  // and leaving the closer behind would print a bare pipe. Look past
  // whatever the parser could not read, but not past the end of the
  // line, the parenthesis, or the next block.
  int? closerAt;
  final limit = (k + 40).clamp(0, source.length);
  for (var probe = k; probe < limit; probe++) {
    final c = source[probe];
    if (c == '|') {
      closerAt = probe;
      break;
    }
    // `(#箴6:28)|` — one entry closes the parenthesis before the
    // pipe. Step over the bracket; it stays in the text either way.
    if ((c == ')' || c == '）') &&
        probe + 1 < source.length &&
        source[probe + 1] == '|') {
      continue;
    }
    if ('\n#()（）'.contains(c)) break;
  }
  if (closerAt == null) return _Block(contentStart, k, k, citations);
  var end = closerAt + 1;
  while (end < source.length && source[end] == '|') {
    end++; // `(#弗 2:5; 西 3:13||)` — one entry doubles the closer.
  }
  return _Block(contentStart, closerAt, end, citations);
}

/// [source] with the `#`/`|` delimiters removed but every citation
/// still readable — what a plain-text surface should print.
String cbolPlainText(String source) {
  if (!source.contains('#') && !source.contains('|')) return source;
  return _tidy(parseCbolRuns(source).map((r) => r.text).join());
}

/// [source] with whole citation blocks deleted.
///
/// Only for one-line glosses, where a reference is noise: measured
/// across the bundled lexicon, every citation in a `glossZh` also
/// appears in that entry's `defZh` (Greek 3,542/3,542; Hebrew
/// 3,440/3,441), so dropping it here loses nothing a reader can
/// no longer reach.
String stripCbolReferences(String rawSource) {
  if (!rawSource.contains('#') && !rawSource.contains('|')) return rawSource;
  final source = _restoreLostOpeners(rawSource);
  final out = StringBuffer();
  var i = 0;
  while (true) {
    final hash = source.indexOf('#', i);
    if (hash < 0) break;
    final block = _readBlock(source, hash);
    if (block == null) {
      out.write(source.substring(i, hash + 1));
      i = hash + 1;
      continue;
    }
    // A citation wrapped in its own parentheses takes them with it,
    // along with any note the `|` introduces.
    var cut = hash;
    while (cut > i && (source[cut - 1] == ' ' || source[cut - 1] == '　')) {
      cut--;
    }
    var end = block.end;
    if (cut > i && (source[cut - 1] == '(' || source[cut - 1] == '（')) {
      final close = source.indexOf(RegExp(r'[)）]'), block.citationsEnd);
      if (close >= 0 && !source.substring(block.citationsEnd, close).contains('\n')) {
        cut -= 1;
        end = close + 1;
      }
    }
    out.write(source.substring(i, cut));
    i = end;
  }
  out.write(source.substring(i));
  return _tidy(out.toString());
}

final RegExp _runOfSpaces = RegExp(r'[ 　]{2,}');
final RegExp _spaceBeforeClose = RegExp(r'[ 　]+([)）,，;；])');
final RegExp _danglingTail = RegExp(r'[ 　]*[,，;；、]+[ 　]*$', multiLine: true);
final RegExp _emptyParens = RegExp(r'[(（][ 　]*[)）]');

final RegExp _indent = RegExp(r'^[ 　]*');

/// Closes the gaps that removing a delimiter opens, without touching
/// the leading indentation — the numbered senses of a definition are
/// laid out with it (`   1a) (Qal)`).
String _tidy(String s) {
  final indent = _indent.firstMatch(s)!.group(0)!;
  final body = s
      .substring(indent.length)
      .replaceAll(_emptyParens, '')
      .replaceAll(_runOfSpaces, ' ')
      .replaceAllMapped(_spaceBeforeClose, (m) => m.group(1)!)
      .replaceAll(_danglingTail, '')
      .trimRight();
  return body.isEmpty ? '' : '$indent$body';
}

/// Renders [source] with every citation the parser could resolve as a
/// link, and everything else as plain text.
///
/// Parity note (BibleWorks 10 help, "Resource windows"): a scripture
/// reference inside a resource is live — hovering previews it, clicking
/// moves the browse window there. This is that rule applied to the
/// Chinese lexicon, which is the deepest resource the app bundles for a
/// Chinese reader and until now the only one whose references were
/// inert punctuation.
///
/// [onRefTap] is optional; pass null for read-only rendering. When it is
/// null no [TapGestureRecognizer] is built, so nothing needs disposing.
/// When it is not, pass [recognizers] so the caller can dispose them —
/// a pane that rebuilds on every mouse move leaks one per citation
/// otherwise.
List<InlineSpan> buildCbolSpans({
  required String source,
  required TextStyle baseStyle,
  required Color refColor,
  void Function(CbolRun ref)? onRefTap,
  List<TapGestureRecognizer>? recognizers,
}) {
  final linkStyle = baseStyle.copyWith(
    color: refColor,
    decoration: TextDecoration.underline,
    decorationStyle: TextDecorationStyle.dotted,
    decorationColor: refColor.withValues(alpha: 0.7),
    decorationThickness: 1.2,
  );
  final spans = <InlineSpan>[];
  for (final run in parseCbolRuns(source)) {
    if (run.kind == CbolRunKind.text) {
      spans.add(TextSpan(text: run.text, style: baseStyle));
      continue;
    }
    TapGestureRecognizer? tap;
    if (onRefTap != null) {
      tap = TapGestureRecognizer()..onTap = () => onRefTap(run);
      recognizers?.add(tap);
    }
    spans.add(TextSpan(text: run.text, style: linkStyle, recognizer: tap));
  }
  return spans;
}
