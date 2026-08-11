// 2026-08-11 (task #299): the `?` card's examples, treated as queries
// rather than as decoration.
//
// Every line on that card is a WORKING query printed as dead text —
// `.love god`, `G25 NEAR5 G26` — and the reader's only way to use one was
// to retype it into the field two centimetres above. This file is the
// pure part of making them tappable: where the example ends and the
// prose begins, and which language the example should be written in.
//
// No Flutter, no assets.

/// The em-dash separator the card's strings use between a query and its
/// explanation, in all three locales: `.love god — both words in one
/// verse`.
const String kSyntaxExampleSeparator = ' — ';

/// One card line, split into the part that can be run and the part that
/// explains it.
class SyntaxLine {
  const SyntaxLine({required this.example, required this.prose});

  /// The query, AS PRINTED, or null when the line is not a single query.
  ///
  /// Two of the card's lines are deliberately not: the verb summary and
  /// the history line are `·`-separated lists of several commands, and
  /// offering to prefill one of those would have to pick a member
  /// arbitrarily. They stay as prose, and so stay untappable.
  ///
  /// Printed, not runnable — see [runnable].
  final String? example;

  /// [example] as the parser wants it. What a tap puts on the line.
  String? get runnable =>
      example == null ? null : normaliseExample(example!);

  /// Everything the reader reads. Never empty — a line with no separator
  /// is all prose.
  final String prose;
}

/// The card's `✶` is a printing character chosen to be legible at chrome
/// size; the parser wants an ASCII `*`. The card keeps printing the
/// glyph — that was a deliberate legibility choice and a bare asterisk
/// is nearly invisible at 11px — and the substitution happens on the way
/// to the command line, where the parser is the reader.
String normaliseExample(String text) => text.replaceAll('✶', '*');

/// Read one card string as `<example> — <prose>`.
SyntaxLine splitSyntaxLine(String line) {
  final at = line.indexOf(kSyntaxExampleSeparator);
  if (at <= 0) return SyntaxLine(example: null, prose: line);
  return SyntaxLine(
    example: line.substring(0, at).trim(),
    prose: line.substring(at + kSyntaxExampleSeparator.length).trim(),
  );
}

/// Which locale's EXAMPLE belongs on the card while reading
/// [versionLanguage], given a reader whose interface is in [uiLocale].
///
/// The two are not the same question. A Chinese reader studying the BSB
/// who taps `.爱 神` gets zero hits and learns that the feature is
/// broken; the example has to be in the language of the text being
/// searched, while the explanation beside it stays in the reader's own.
///
/// `grc` (the LXX and WH editions) has no vernacular examples on the
/// card at all, so it falls back to the interface locale — the reader at
/// least gets a line they can read, and the Strong's-number examples,
/// which are the ones that actually apply to a Greek text, are the same
/// in every locale.
String exampleLocaleFor({
  required String versionLanguage,
  required String uiLocale,
}) {
  const known = {'en', 'zh-Hans', 'zh-Hant'};
  if (known.contains(versionLanguage)) return versionLanguage;
  return known.contains(uiLocale) ? uiLocale : 'en';
}
