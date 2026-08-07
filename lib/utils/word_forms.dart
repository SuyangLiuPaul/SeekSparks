/// 2026-08-07 (SeekSparks): the Forms tab's arithmetic — BibleWorks help
/// topic bwh10q, without any Flutter in it.
///
/// bwh10q describes two lookups that run in opposite directions, and the
/// interesting one is not the one the name suggests:
///
/// > "The top section displays all the different ways that the current
/// > word is used … The bottom section looks at the actual inflected
/// > form and tells you all the different ways that form is parsed in
/// > the database."
///
/// The top section is a paradigm: given λόγος, here is λόγον 130×,
/// λόγῳ 45×, and so on. Useful, and roughly what you would guess.
///
/// The bottom section is a claim about **certainty**. The Analysis pane
/// prints one parsing in a box and nothing qualifies it, so a reader has
/// no way to know that אָדָם in front of them is tagged H120 "man" in 18
/// places and H121 "Adam" in 2, and that the tagger picked one. For 4,756
/// of the corpus's 130,950 surface forms the parse on screen is a
/// judgement, not a reading. Naming that is the point of the feature.
///
/// Why absence means "unambiguous": the asset stores only the 3.6% of
/// forms that carry more than one parse. A form with no entry has
/// exactly one, so [FormAmbiguity.unambiguous] is what a miss decodes
/// to rather than an error state. See `tools/build_forms_index.py`.
library;

import 'package:seeksparks/constants/book_slugs.dart' show slugToBook;

/// `'1_corinthians'` → `'1 Corinthians'`.
///
/// `book_slugs.dart` maps *abbreviations* (`'1co'`), but the files under
/// `assets/originals/` — and therefore the refs in the forms index — are
/// named with the full slug `OriginalsService._slug` produces. Rather
/// than carry a second 66-name table that could drift from the first,
/// this inverts the canonical names through the same rule. Verified
/// exhaustive: all 66 originals filenames resolve.
final Map<String, String> originalsSlugToBook = {
  for (final name in slugToBook.values)
    name.toLowerCase().replaceAll(' ', '_').replaceAll("'", ''): name,
};

/// One inflected form of a lemma, as it occurs in the bundled corpus.
class WordForm {
  const WordForm({
    required this.form,
    required this.morph,
    required this.count,
    this.refs = const [],
  });

  /// The surface form as it is written — accents, vowel points and all.
  final String form;

  /// Morphology code, decodable by `describeMorphology`. Empty when the
  /// token carried no tag.
  final String morph;

  /// Occurrences of this exact (lemma, form, parse) across the corpus.
  final int count;

  /// Up to three places it occurs, as `'<bookIndex> <chapter>:<verse>'`.
  /// Capped in the asset: enough to jump to, not a concordance. [count]
  /// is the honest total and is never capped.
  final List<String> refs;

  static WordForm? fromJson(Object? row) {
    if (row is! List || row.length < 3) return null;
    final form = row[0];
    final count = row[2];
    if (form is! String || form.isEmpty || count is! int) return null;
    return WordForm(
      form: form,
      morph: row[1] is String ? row[1] as String : '',
      count: count,
      refs: row.length > 3 && row[3] is List
          ? [
              for (final r in row[3] as List)
                if (r is String) r,
            ]
          : const [],
    );
  }
}

/// One way a surface form is parsed — the bottom section's row.
class FormParse {
  const FormParse({
    required this.strongs,
    required this.morph,
    required this.count,
  });

  final String strongs;
  final String morph;
  final int count;

  static FormParse? fromJson(Object? row) {
    if (row is! List || row.length < 3) return null;
    final strongs = row[0];
    final count = row[2];
    if (strongs is! String || strongs.isEmpty || count is! int) return null;
    return FormParse(
      strongs: strongs,
      morph: row[1] is String ? row[1] as String : '',
      count: count,
    );
  }
}

/// What the corpus says about how certain the parse on screen is.
class FormAmbiguity {
  const FormAmbiguity(this.form, this.parses);

  /// The verdict for a form the asset has no entry for: exactly one
  /// parse, so nothing to warn about.
  const FormAmbiguity.unambiguous(this.form) : parses = const [];

  final String form;

  /// Every parse of this form, frequency-descending. Empty when the
  /// form is unambiguous — see the library comment on why a miss is an
  /// answer rather than a failure.
  final List<FormParse> parses;

  bool get isAmbiguous => parses.length > 1;

  /// Distinct Strong's numbers behind this form. More than one means the
  /// ambiguity is *lexical* — a different word, not merely a different
  /// parse of the same word — which is the case worth interrupting a
  /// reader for.
  int get lemmaCount => {for (final p in parses) p.strongs}.length;

  bool get spansLemmas => lemmaCount > 1;

  /// The alternatives to [strongs]+[morph], i.e. what the reader is
  /// *not* being shown. Returns empty when the form is unambiguous.
  List<FormParse> othersThan(String strongs, String morph) => [
        for (final p in parses)
          if (p.strongs != strongs || p.morph != morph) p,
      ];
}

/// Which shard file holds [strongs]: language letter + the Strong's
/// number divided by 100, so `G3056` lives in `G30.json`.
///
/// Sharding at all because the caller holds exactly one number at a time
/// — the word under the cursor — and the whole lemma index is 7.5 MB.
/// A hundred is the granularity that keeps a shard around 50 KB: one
/// small fetch, then cached for every neighbouring number the reader
/// hovers next, which in running text is most of them.
String? formsShardFor(String strongs) {
  if (strongs.length < 2) return null;
  final digits = int.tryParse(strongs.substring(1));
  if (digits == null || digits < 0) return null;
  return '${strongs[0]}${digits ~/ 100}';
}

/// The three orders bwh10q's Options menu offers.
enum FormSort {
  /// "Sort by frequency" — the asset's own order, and the default,
  /// because the question behind the list is usually "which form is the
  /// normal one".
  frequency,

  /// "Sort by form" — by morphology code. The code starts with the part
  /// of speech, so this is also bwh10q's "grouped in useful sections
  /// based on part of speech".
  morphCode,

  /// "Sort alphabetically" — by the surface form.
  alphabetical,
}

/// Sorts a copy of [forms]. Ties always fall back to the surface form so
/// the order is total: an unstable list that reshuffles when the reader
/// switches sort and switches back reads as a bug.
List<WordForm> sortForms(List<WordForm> forms, FormSort by) {
  final out = [...forms];
  switch (by) {
    case FormSort.frequency:
      out.sort((a, b) {
        final c = b.count.compareTo(a.count);
        return c != 0 ? c : a.form.compareTo(b.form);
      });
    case FormSort.morphCode:
      out.sort((a, b) {
        final c = a.morph.compareTo(b.morph);
        return c != 0 ? c : a.form.compareTo(b.form);
      });
    case FormSort.alphabetical:
      out.sort((a, b) {
        final c = a.form.compareTo(b.form);
        return c != 0 ? c : a.morph.compareTo(b.morph);
      });
  }
  return out;
}

/// A reference stored in the forms asset, resolved against the book
/// table in `assets/forms/index.json`.
class FormRef {
  const FormRef({
    required this.englishBook,
    required this.chapter,
    required this.verse,
  });

  /// Canonical English book name, which is what navigation takes.
  final String englishBook;
  final int chapter;
  final int verse;
}

/// Decodes `'12 10:1'` against [books]. Returns null rather than a
/// partly-filled ref: these drive navigation, and a ref that lands on
/// the wrong verse is worse than one that is simply not offered.
FormRef? parseFormRef(String raw, List<String> books) {
  final space = raw.indexOf(' ');
  final colon = raw.indexOf(':', space + 1);
  if (space <= 0 || colon <= space) return null;
  final book = int.tryParse(raw.substring(0, space));
  final chapter = int.tryParse(raw.substring(space + 1, colon));
  final verse = int.tryParse(raw.substring(colon + 1));
  if (book == null || chapter == null || verse == null) return null;
  if (book < 0 || book >= books.length) return null;
  if (chapter <= 0 || verse <= 0) return null;
  final english = originalsSlugToBook[books[book]];
  if (english == null) return null;
  return FormRef(englishBook: english, chapter: chapter, verse: verse);
}
