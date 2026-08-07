/// 2026-08-07 (SeekSparks): a parser for Thayer's Greek-English Lexicon.
///
/// `assets/thayer.json` stores each entry as one flat block of text, the
/// shape the 1889 lexicon has had in every electronic edition since:
///
/// ```
/// agape
///
///  from 25; TDNT - 1:21,5; n f
///
///  AV - love 86, charity 27, dear 1, charitably+2596 1,
///  feast of charity 1; 116
///
///  1) brotherly love, affection, good will, love, benevolence
///  2) love feasts
/// ```
///
/// A pane cannot render that. It needs the AV counts as a table, the
/// senses as a tree, and the commentary paragraphs separated from the
/// senses they follow. Hence this file: pure Dart, no Flutter, so the
/// rules below are testable against the real 5,799-entry corpus rather
/// than eyeballed in a screenshot.
///
/// The two rules that took the longest to get right:
///
///  * **The AV block does not end at a newline.** It ends at `; <total>`.
///    The Chinese sibling (`assets/strongs/thayer_zh.json`) splits on the
///    newline instead, which is why G26 shows Chinese readers a first
///    "sense" reading `feast of charity 1; 116`. Terminating on the total
///    keeps the wrapped renderings where they belong.
///
///  * **Indentation does not distinguish a commentary note from a
///    sense.** G20 indents "At feasts, people were anointed…" by exactly
///    the one space its `1)` sibling uses. Notes are instead recognised
///    by following a blank line, opening with a capital or a quote, and
///    *not* continuing an unfinished clause ([_opensMidClause]).
library;

/// One numbered sense. [level] is 1 for `1)`, 2 for `1a)`, 3 for `1b1)`,
/// 4 for `1b2a)` — the outline nests up to four deep.
class ThayerSense {
  const ThayerSense({
    required this.marker,
    required this.level,
    required this.text,
  });

  final String marker;
  final int level;
  final String text;
}

/// One `AV - ` rendering: how the KJV translated this word, and how often.
class AvCount {
  const AvCount({required this.rendering, required this.count});

  final String rendering;
  final int count;
}

class ThayerEntry {
  const ThayerEntry({
    required this.number,
    required this.headword,
    this.etymology = '',
    this.partOfSpeech = '',
    this.tdnt = '',
    this.nameMeaning = '',
    this.avCounts = const [],
    this.avTotal = 0,
    this.senses = const [],
    this.notes = const [],
    this.synonymRefs = const [],
    this.grammarLines = const [],
    this.isNotUsed = false,
  });

  final String number;

  /// The transliterated head line. May carry alternates, e.g. G2736
  /// `kato  also (cf) katotero  [cf 2737]`.
  final String headword;

  final String etymology;

  /// `n f`, `v`, `adv` … Thayer's own abbreviation, kept verbatim;
  /// [decodePartOfSpeech] expands it for display.
  final String partOfSpeech;

  /// Kittel's *Theological Dictionary*, as `volume:page,entry`.
  final String tdnt;

  /// For proper nouns Thayer prints `Aaron = "light-bringer"`. Hitchcock
  /// often disagrees, so the pane shows both, labelled.
  final String nameMeaning;

  final List<AvCount> avCounts;
  final int avTotal;
  final List<ThayerSense> senses;

  /// Unnumbered commentary paragraphs — Thayer's asides on usage,
  /// classical parallels and textual variants.
  final List<String> notes;

  /// `For Synonyms see entry 5941` → `['5941']`.
  final List<String> synonymRefs;

  /// G5627–G5798 are not words at all but the parsing codes a tagged
  /// line carries. They have no senses, so they are kept raw.
  final List<String> grammarLines;

  bool get isGrammarCode => grammarLines.isNotEmpty;

  /// 101 entries read `'Not Used'` — numbers Strong assigned that Thayer
  /// declined to treat.
  final bool isNotUsed;

  bool get isEmpty =>
      headword.isEmpty &&
      senses.isEmpty &&
      notes.isEmpty &&
      grammarLines.isEmpty;
}

final _tdntRe = RegExp(r'TDNT\s*-\s*([\d:,\*]+)');
final _markerRe = RegExp(r'^(\s*)(\d+[a-z0-9]*)\)\s*(.*)$');
/// The AV block ends at its total. Most entries separate the total with
/// a semicolon; a few hundred use the same comma as the renderings, so
/// both are accepted — a bare number after the separator is never itself
/// a rendering.
final _avEndRe = RegExp(r'[;,]\s*(\d+)\s*$');
final _avItemRe = RegExp(r'^(.*?)\s+(\d+)$');
final _synonymRe = RegExp(r'For\s+Synonyms\s+see\s+entr(?:y|ies)\s+([\d,\s]+)');
final _noteOpenRe = RegExp(r'^["“\(A-Z]');

/// Everything up to and including the quote that opens a name gloss:
/// `Aaron = "`, `Aenon meaning "`, `[Porcius] Festus = "`. The closing
/// quote is found separately by [_nameMeaningOf], because the corpus
/// mismatches them (`Antioch = 'driven against"`) and the meaning itself
/// may contain an apostrophe (`Attalia = "Jah's due season"`).
final _nameMeaningOpenRe = RegExp(
  '''^\\s*\\[?[A-Z][A-Za-z'’ \\-\\[\\]]*?\\s*(?:=\\s*(?:meaning\\s*)?|\\s+meaning\\s+)["'“]''',
);

/// What may follow the gloss on the same line: a question mark where
/// Thayer was unsure, or one parenthetical aside. Anything longer means
/// the line is prose that happens to contain a quotation, not a gloss.
final _nameMeaningTailRe = RegExp(r'^[?!.]*\s*(\([^)]*\))?[?!.]*$');

/// The meaning in `Aaron = "light-bringer"`, or null if [line] is not a
/// name gloss standing on its own.
String? _nameMeaningOf(String line) {
  final open = _nameMeaningOpenRe.firstMatch(line);
  if (open == null) return null;
  final close = line.lastIndexOf(RegExp('''["'”]'''));
  if (close <= open.end) return null;
  if (!_nameMeaningTailRe.hasMatch(line.substring(close + 1).trim())) {
    return null;
  }
  final meaning = line.substring(open.end, close).trim();
  return meaning.isEmpty ? null : meaning;
}

/// Words that cannot end a finished clause. If the previous line ends in
/// one of these, the next line is a continuation however it is
/// capitalised — the guard that stopped G5207's wrapped lines from being
/// read as fresh commentary paragraphs.
const _danglingWords = {
  'a', 'an', 'the', 'of', 'to', 'in', 'on', 'at', 'by', 'for', 'from',
  'with', 'and', 'or', 'but', 'as', 'is', 'are', 'was', 'were', 'be',
  'that', 'which', 'who', 'whom', 'whose', 'this', 'these', 'those',
  'not', 'no', 'so', 'than', 'then', 'when', 'where', 'while', 'into',
  'upon', 'about', 'after', 'before', 'over', 'under', 'through', 'its',
  'his', 'her', 'their', 'our', 'your', 'it', 'he', 'they', 'we', 'i',
  'cf', 'see', 'e.g.', 'i.e.', 'viz.',
};

bool _opensMidClause(String prev) {
  final t = prev.trimRight();
  if (t.isEmpty) return false;
  if (t.endsWith(',') || t.endsWith('-') || t.endsWith('(')) return true;
  if ('('.allMatches(t).length > ')'.allMatches(t).length) return true;
  final last = t.split(RegExp(r'\s+')).last.toLowerCase();
  return _danglingWords.contains(last);
}

/// Turns one raw Thayer block into something a pane can lay out.
///
/// Never throws: a malformed entry degrades to a headword plus whatever
/// lines could be classified, because a lexicon that fails closed on one
/// odd entry is worse than one that shows a partial article.
ThayerEntry parseThayerEntry(String number, String raw) {
  final lines = raw.split('\n');
  var i = 0;
  while (i < lines.length && lines[i].trim().isEmpty) {
    i++;
  }
  if (i >= lines.length) return ThayerEntry(number: number, headword: '');

  final headword = lines[i].trim();
  i++;

  if (headword.replaceAll("'", '').toLowerCase() == 'not used') {
    return ThayerEntry(number: number, headword: headword, isNotUsed: true);
  }

  // Grammar codes carry no lexical structure at all.
  final code = int.tryParse(number.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  if (number.startsWith('G') && code >= 5627 && code <= 5798) {
    final body = lines
        .skip(i)
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    return ThayerEntry(
      number: number,
      headword: headword,
      grammarLines: body,
    );
  }

  final etymology = StringBuffer();
  var tdnt = '';
  var partOfSpeech = '';
  var avTotal = 0;
  final avCounts = <AvCount>[];
  final senses = <ThayerSense>[];
  final notes = <String>[];
  final synonymRefs = <String>[];
  var nameMeaning = '';

  var sawAv = false;
  var inNote = false;
  var prevBlank = true;
  var prev = '';

  final avBuf = StringBuffer();
  var inAv = false;

  void flushAv() {
    if (avBuf.isEmpty) return;
    var text = avBuf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    final end = _avEndRe.firstMatch(text);
    if (end != null) {
      avTotal = int.tryParse(end.group(1)!) ?? 0;
      text = text.substring(0, end.start);
    }
    for (final part in text.split(',')) {
      final item = part.trim();
      if (item.isEmpty) continue;
      final m = _avItemRe.firstMatch(item);
      if (m == null) continue;
      final rendering = m.group(1)!.trim();
      if (rendering.endsWith('+')) {
        // `to enjoy + 1519` — the source dropped this item's count, and
        // the number is the Strong's it combines with. Guessing a count
        // would be inventing data, so it is left at zero and the pane
        // prints the rendering alone.
        avCounts.add(AvCount(rendering: item, count: 0));
        continue;
      }
      avCounts.add(AvCount(
        rendering: rendering,
        count: int.tryParse(m.group(2)!) ?? 0,
      ));
    }
    avBuf.clear();
  }

  for (; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      if (inAv) {
        // A blank never ends the AV block; only the total does. But an
        // unterminated block must not swallow the senses either.
        flushAv();
        inAv = false;
      }
      prevBlank = true;
      prev = '';
      continue;
    }

    if (inAv) {
      avBuf.write(' $trimmed');
      if (_avEndRe.hasMatch(avBuf.toString().trim())) {
        flushAv();
        inAv = false;
      }
      prevBlank = false;
      prev = trimmed;
      continue;
    }

    if (!sawAv && trimmed.startsWith('AV -')) {
      sawAv = true;
      inAv = true;
      avBuf.write(trimmed.substring(4));
      if (_avEndRe.hasMatch(avBuf.toString().trim())) {
        flushAv();
        inAv = false;
      }
      prevBlank = false;
      prev = trimmed;
      continue;
    }

    final syn = _synonymRe.firstMatch(trimmed);
    if (syn != null) {
      for (final n in syn.group(1)!.split(',')) {
        final v = n.trim();
        if (v.isNotEmpty) synonymRefs.add(v);
      }
      prevBlank = false;
      prev = trimmed;
      continue;
    }

    final marker = _markerRe.firstMatch(line);
    if (marker != null) {
      final tag = marker.group(2)!;
      senses.add(ThayerSense(
        marker: tag,
        level: _levelOf(tag),
        text: marker.group(3)!.trim(),
      ));
      inNote = false;
      prevBlank = false;
      prev = trimmed;
      continue;
    }

    final nm = _nameMeaningOf(trimmed);
    if (nm != null) {
      // A whole line that is just `Aaron = "light-bringer"` is a gloss,
      // not commentary. It gets its own slot in the pane, so leaving it
      // in [notes] as well would print it twice.
      if (nameMeaning.isEmpty) nameMeaning = nm;
      inNote = false;
      prevBlank = false;
      prev = trimmed;
      continue;
    }

    if (!sawAv && senses.isEmpty && notes.isEmpty) {
      if (tdnt.isEmpty) {
        final m = _tdntRe.firstMatch(trimmed);
        if (m != null) tdnt = m.group(1)!;
      }
      if (partOfSpeech.isEmpty) {
        final segs = trimmed.split(';').map((s) => s.trim()).toList();
        final last = segs.last;
        if (segs.length > 1 && last.isNotEmpty && last.length <= 14) {
          partOfSpeech = last;
        }
      }
      if (etymology.isNotEmpty) etymology.write(' ');
      etymology.write(trimmed);
      prevBlank = false;
      prev = trimmed;
      continue;
    }

    final startsNote = prevBlank &&
        _noteOpenRe.hasMatch(trimmed) &&
        !_opensMidClause(prev);

    if (startsNote) {
      notes.add(trimmed);
      inNote = true;
    } else if (inNote && notes.isNotEmpty) {
      notes[notes.length - 1] = '${notes.last} $trimmed';
    } else if (senses.isNotEmpty) {
      final last = senses.removeLast();
      senses.add(ThayerSense(
        marker: last.marker,
        level: last.level,
        text: '${last.text} $trimmed',
      ));
    } else {
      notes.add(trimmed);
      inNote = true;
    }
    prevBlank = false;
    prev = trimmed;
  }
  flushAv();

  return ThayerEntry(
    number: number,
    headword: headword,
    etymology: _trimEtymology(etymology.toString()),
    partOfSpeech: partOfSpeech,
    tdnt: tdnt,
    nameMeaning: nameMeaning,
    avCounts: avCounts,
    avTotal: avTotal,
    senses: senses,
    notes: notes,
    synonymRefs: synonymRefs,
  );
}

/// The etymology line carries the TDNT reference and the POS code, both
/// of which get their own slot in the pane. Printing them twice makes
/// the header look like a parse failure.
String _trimEtymology(String raw) {
  var out = raw.replaceAll(_tdntRe, '').trim();
  final segs = out
      .split(';')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (segs.length > 1 && segs.last.length <= 14) segs.removeLast();
  out = segs.join('; ');
  return out.replaceAll(RegExp(r'\s+'), ' ').trim();
}

int _levelOf(String marker) {
  final rest = marker.replaceFirst(RegExp(r'^\d+'), '');
  return 1 + RegExp(r'[a-z]|\d+').allMatches(rest).length;
}

const _posNames = <String, String>{
  'n m': 'noun masculine',
  'n f': 'noun feminine',
  'n n': 'noun neuter',
  'n pr m': 'noun proper masculine',
  'n pr f': 'noun proper feminine',
  'n pr loc': 'proper locative noun',
  'n': 'noun',
  'v': 'verb',
  'adj': 'adjective',
  'adv': 'adverb',
  'prep': 'preposition',
  'conj': 'conjunction',
  'particle': 'particle',
  'interj': 'interjection',
  'pron': 'pronoun',
  'a adj': 'adjective',
};

/// Expands Thayer's POS abbreviation, or returns null when the code is
/// not one we can vouch for — a wrong expansion is worse than none.
String? decodePartOfSpeech(String code) => _posNames[code.trim().toLowerCase()];
