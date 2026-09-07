/// The Report Generator — bwh28, `docs/PARITY-BACKLOG.md` §3.5.
///
/// The entry described it exactly and said why it was worth doing:
/// *"Generates a formatted study report for a passage: text, lexicon
/// entries for each word, filtered by morphology and frequency. This is
/// a genuinely good idea we have all the parts for (word list, lexicons,
/// morphology, frequency) and no assembly."* This file is the assembly.
/// §3.6's export row folds into it — *"Done: fold into the Report
/// Generator entry above"* — which is why the report leaves by the SAME
/// door as a copy: marked text plus an HTML flavour, handed to
/// `ClipboardHelper.copyMarkedWithFeedback`. One export path, not two.
///
/// ## What a report is for, and what that makes it
///
/// It is the thing a preacher pastes into a sermon file and a student
/// pastes into an essay. So the two output forms are the two that
/// survive that paste: **HTML** for anything that accepts rich text, and
/// **Markdown** for anything that does not — a plain-text report with
/// tabs and spaces looks assembled until the first proportional font,
/// and then it is a wall.
///
/// ## The filters are the feature, not an option row
///
/// bwh28 filters by morphology and by frequency, and both are there for
/// the same reason: a report on Romans 8 that prints a lexicon entry for
/// every καί is not a study aid, it is a phone book. [ReportOptions]
/// therefore defaults to a **rare-word** report — words the corpus uses
/// [rarerThan] times or fewer — because that is the list a reader
/// actually works from, and the full list is one toggle away.
///
/// ## Nothing here invents a fact
///
/// Every field on [ReportWord] comes from an asset this app already
/// ships and already shows elsewhere: the surface form and its parse
/// from `assets/originals/`, the gloss from the Strong's lexicon, the
/// count from the bundled concordance. A word whose number the lexicon
/// does not know keeps its number and prints no gloss, rather than
/// borrowing a neighbour's — see [ReportWord.gloss] being nullable and
/// the renderers' handling of it.
///
/// Flutter-free: this shapes and renders. Gathering is the caller's job.
library;

/// What the reader asked to be in the report.
class ReportOptions {
  const ReportOptions({
    this.verseText = true,
    this.words = true,
    this.morphology = true,
    this.frequency = true,
    this.rarerThan = 50,
    this.partsOfSpeech = const <String>{},
  });

  /// The passage itself, in the reading version.
  final bool verseText;

  /// One row per original word.
  final bool words;

  /// The parse, spelled out, beside each word.
  final bool morphology;

  /// How often the corpus uses that number.
  final bool frequency;

  /// Keep only words the corpus uses this many times or fewer. `0`
  /// means keep everything.
  ///
  /// Defaulted rather than off: see the class comment. A report that
  /// glosses every καί is a phone book.
  final int rarerThan;

  /// Keep only these parts of speech, by their morphology-code letter.
  /// Empty means every part of speech.
  final Set<String> partsOfSpeech;

  bool get filtersAnything => rarerThan > 0 || partsOfSpeech.isNotEmpty;
}

/// One original-language word as the report prints it.
class ReportWord {
  const ReportWord({
    required this.surface,
    required this.strongs,
    this.lemma,
    this.transliteration,
    this.gloss,
    this.parse,
    this.pos,
    this.corpusCount,
  });

  final String surface;
  final String strongs;
  final String? lemma;
  final String? transliteration;

  /// Null when the lexicon has no entry for [strongs]. Printed as
  /// nothing rather than filled in from somewhere else.
  final String? gloss;

  /// The parse in words ("noun common masculine singular absolute"),
  /// not the raw code — the code is in the app for a reader who wants
  /// it, and a report is read by someone who may not.
  final String? parse;

  /// The morphology code's part-of-speech letter, for [ReportOptions].
  final String? pos;

  /// Occurrences of [strongs] in the whole corpus. Null when unknown,
  /// which is different from zero.
  final int? corpusCount;
}

class ReportVerse {
  const ReportVerse({
    required this.reference,
    required this.text,
    this.words = const <ReportWord>[],
  });

  final String reference;
  final String text;
  final List<ReportWord> words;
}

class PassageReport {
  const PassageReport({
    required this.title,
    required this.versionLabel,
    required this.verses,
    required this.options,
    this.licence,
    this.wordsBeforeFilter = 0,
  });

  /// "Romans 8:1-4", as the reader sees it.
  final String title;
  final String versionLabel;
  final List<ReportVerse> verses;
  final ReportOptions options;

  /// The edition's licence line. Carried because a report is the moment
  /// publisher text lands on someone else's page — the same reason
  /// `version_attribution.dart` exists for the clipboard.
  final String? licence;

  /// How many words there were before [ReportOptions] narrowed them.
  /// Printed when it differs, so a short list cannot be mistaken for a
  /// short passage.
  final int wordsBeforeFilter;

  int get wordsShown =>
      verses.fold(0, (n, v) => n + v.words.length);
}

/// Keep the words [options] asks for, in order.
///
/// A word with no known frequency is KEPT by a frequency filter. The
/// filter's promise is "the rare ones"; dropping a word because we could
/// not count it would answer a different question and answer it
/// silently.
List<ReportWord> filterWords(
    List<ReportWord> words, ReportOptions options) {
  return [
    for (final w in words)
      if ((options.partsOfSpeech.isEmpty ||
              (w.pos != null && options.partsOfSpeech.contains(w.pos))) &&
          (options.rarerThan <= 0 ||
              w.corpusCount == null ||
              w.corpusCount! <= options.rarerThan))
        w,
  ];
}

String _escape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

/// The report as Markdown — the form that survives a paste into anything.
String reportToMarkdown(PassageReport r) {
  final b = StringBuffer()
    ..writeln('# ${r.title}')
    ..writeln()
    ..writeln('*${r.versionLabel}*')
    ..writeln();
  if (r.options.filtersAnything && r.wordsBeforeFilter > r.wordsShown) {
    b
      ..writeln('_${r.wordsShown} of ${r.wordsBeforeFilter} words_')
      ..writeln();
  }
  for (final v in r.verses) {
    b.writeln('## ${v.reference}');
    b.writeln();
    if (r.options.verseText) {
      b
        ..writeln(v.text)
        ..writeln();
    }
    for (final w in v.words) {
      final bits = <String>[
        '**${w.surface}**',
        if (w.lemma != null && w.lemma!.isNotEmpty) w.lemma!,
        '`${w.strongs}`',
      ];
      b.write('- ${bits.join(' · ')}');
      if (w.gloss != null && w.gloss!.isNotEmpty) b.write(' — ${w.gloss}');
      final tail = <String>[
        if (r.options.morphology && w.parse != null && w.parse!.isNotEmpty)
          w.parse!,
        if (r.options.frequency && w.corpusCount != null)
          '×${w.corpusCount}',
      ];
      if (tail.isNotEmpty) b.write(' (${tail.join(', ')})');
      b.writeln();
    }
    if (v.words.isNotEmpty) b.writeln();
  }
  if (r.licence != null && r.licence!.isNotEmpty) {
    b
      ..writeln('---')
      ..writeln()
      ..writeln(r.licence);
  }
  return b.toString().trimRight();
}

/// The report as an HTML fragment, for the clipboard's `text/html`
/// flavour.
///
/// A fragment and not a document: it is going onto the clipboard beside
/// the plain text, to be pasted INTO something that already has a head.
/// Inline styles rather than a stylesheet for the same reason — a class
/// name means nothing on the far side of a paste.
String reportToHtml(PassageReport r) {
  final b = StringBuffer()
    ..write('<h1>${_escape(r.title)}</h1>')
    ..write('<p><em>${_escape(r.versionLabel)}</em></p>');
  if (r.options.filtersAnything && r.wordsBeforeFilter > r.wordsShown) {
    b.write('<p style="color:#666">'
        '${r.wordsShown} of ${r.wordsBeforeFilter} words</p>');
  }
  for (final v in r.verses) {
    b.write('<h2>${_escape(v.reference)}</h2>');
    if (r.options.verseText) {
      b.write('<p>${_escape(v.text)}</p>');
    }
    if (v.words.isNotEmpty) {
      b.write('<ul>');
      for (final w in v.words) {
        b.write('<li><strong>${_escape(w.surface)}</strong>');
        if (w.lemma != null && w.lemma!.isNotEmpty) {
          b.write(' &middot; ${_escape(w.lemma!)}');
        }
        b.write(' <code>${_escape(w.strongs)}</code>');
        if (w.gloss != null && w.gloss!.isNotEmpty) {
          b.write(' &mdash; ${_escape(w.gloss!)}');
        }
        final tail = <String>[
          if (r.options.morphology && w.parse != null && w.parse!.isNotEmpty)
            w.parse!,
          if (r.options.frequency && w.corpusCount != null)
            '×${w.corpusCount}',
        ];
        if (tail.isNotEmpty) {
          b.write(' <span style="color:#666">('
              '${_escape(tail.join(', '))})</span>');
        }
        b.write('</li>');
      }
      b.write('</ul>');
    }
  }
  if (r.licence != null && r.licence!.isNotEmpty) {
    b.write('<hr><p style="font-size:90%;color:#666">'
        '${_escape(r.licence!)}</p>');
  }
  return b.toString();
}
