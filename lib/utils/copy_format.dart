/// 2026-08-07 (SeekSparks): the Copy Center — BibleWorks bwh28
/// ("Copying Results") together with the Output Format Options pane of
/// bwh29, which is where the actual specification lives.
///
/// The name invites the wrong build. "Copy" sounds like a button that
/// puts the verse on the clipboard, and BibleWorks devotes a whole
/// module plus a settings pane to it. Four things a naive reading
/// misses, all of them from the help file:
///
///   * **A reference list with no text is a separate artifact.** "Copy
///     Verse List (No Text)" produces `Gen 1:1-2; 2:1` — the thing you
///     paste into a footnote or an index. It has its own merging rules
///     and its own separators, and it is not a degenerate case of
///     copying text. It gets [renderReferenceList].
///   * **Merging is real logic, not string joining.** Consecutive
///     verses collapse; the book name is printed once per book and the
///     chapter is re-stated after a `;`. On top of that sits the `f` /
///     `ff` convention with a *threshold*: "Consecutive verses more
///     than this number will be replaced with the ff abbreviation …
///     if this setting is greater than zero and the range only covers
///     two verses, an f will be used instead of an ff."
///   * **Separators are configurable because the world is not the USA.**
///     bwh29 says so in as many words: "This is useful for European
///     users because outside the United States different delimiters are
///     normally used than the colon and semi-colon." `Gen 1,1` is not a
///     typo, it is German.
///   * **Multiple versions have two shapes, not one.** "Interleave
///     Versions" copies every version of verse 1, then every version of
///     verse 2. Off, it copies all of version A, then all of version B.
///     Those are different documents for different purposes.
///
/// Two things BibleWorks does NOT have that this needs, both forced by
/// what SeekSparks actually ships:
///
///   * **The apparatus has to be a choice.** Verse text here carries
///     `<note: …>` footnotes and `[supplied]` words inline — 48% of LEB
///     verses have a note (see `scripture_markup.dart`). Copying raw
///     text into a sermon pastes the footnotes into the sermon. So
///     notes and brackets are explicit options, both defaulting to the
///     reading shape.
///   * **Attribution.** BibleWorks' texts are licensed to the user's
///     desktop. SeekSparks bundles editions whose own licences range
///     from public domain to "used with permission" and
///     CC-BY-NC-SA — and pasting a passage into a handout is
///     redistribution. The attribution line is therefore part of the
///     output, defaulting to on, sourced from the same reviewed strings
///     the About page prints. It is not decoration.
///
/// Deliberately PLAIN TEXT ONLY. Rich text is the single most-reported
/// copy complaint in every Bible program — pasted scripture arrives in
/// the source app's font and fights the document — and Flutter's
/// `Clipboard.setData` is `text/plain` anyway. A `text/html` flavour
/// would need a JS-interop path around the hardened `ClipboardHelper`,
/// which exists because of a real iOS Safari crash. Not worth it here.
///
/// Pure: no Flutter, no assets, no I/O. Names and verse text arrive as
/// injected callbacks so this file can be tested with a three-verse
/// fake. The dialog is `widgets/copy_center_sheet.dart`.
library;

import 'package:seeksparks/utils/scripture_markup.dart';
import 'package:seeksparks/utils/verse_list.dart'
    show VerseRef, canonicalBookIndex;

// ── Injected naming ─────────────────────────────────────────────────

/// How much of the book name to print.
enum CopyBookStyle {
  /// "Genesis" / "创世记".
  full,

  /// "Gen" / "创" — [shortBookName] in the app, whatever the caller
  /// supplies here in tests.
  abbreviated,
}

/// Canonical English book name + style → what to print.
typedef BookNamer = String Function(String englishBook, CopyBookStyle style);

/// Version code → its short display label ("BSB", "CUVS").
typedef VersionNamer = String Function(String versionCode);

/// Version code + reference → that version's RAW verse text (still
/// carrying `<note:>` / `[supplied]` markup), or null when the version
/// does not have the verse. Missing verses are skipped silently:
/// versification differs between editions and a copy that shouted
/// about it would be unusable across a chapter boundary.
typedef VerseTextLookup = String? Function(String versionCode, VerseRef ref);

/// Version code → the one-line rights statement to print in the
/// attribution block, or null for a version that needs none.
typedef AttributionLookup = String? Function(String versionCode);

// ── Options ─────────────────────────────────────────────────────────

/// Where the reference sits relative to the text.
enum CopyRefPlacement { before, after }

/// How many references the output carries.
///
/// BibleWorks expresses this as a pile of independent checkboxes
/// ("Place reference before text", "Superscript verse numbers
/// (internal)", …). It is really one choice with three answers, and
/// splitting it into checkboxes lets a reader select combinations that
/// mean nothing. The three answers map onto three real documents:
enum CopyRefScope {
  /// No reference at all. The passage as bare prose — a slide.
  none,

  /// One reference per verse. A proof-text list: every line stands on
  /// its own and can be quoted out of order.
  perVerse,

  /// One merged reference for the whole selection. A sermon or a paper:
  /// `John 3:16-18 (BSB)` once, then running text with inline verse
  /// numbers.
  passage,
}

/// The punctuation of a compact reference list.
///
/// Three knobs, exactly the three bwh29 names: "the separators that
/// will appear between verses, between chapter and verse, and between
/// references."
class CopySeparators {
  const CopySeparators({
    this.chapterVerse = ':',
    this.verseList = ', ',
    this.reference = '; ',
    this.verseRange = '–',
  });

  /// Between chapter and verse. `:` in the anglophone world, `,` in
  /// much of Europe.
  final String chapterVerse;

  /// Between non-adjacent verses inside one chapter — `1:1, 3`.
  final String verseList;

  /// Between one reference and the next — `Gen 1:1; 2:1`.
  final String reference;

  /// Between the ends of a run — `1:1–4`.
  ///
  /// An EN DASH by default, not a hyphen. Both style guides consulted
  /// say so for scripture ranges — a divinity-school SBL guide: "For a
  /// range of verses use an en dash with no spaces either side of the
  /// dash." It is a text box, so anyone who wants a hyphen types one.
  final String verseRange;

  CopySeparators copyWith({
    String? chapterVerse,
    String? verseList,
    String? reference,
    String? verseRange,
  }) =>
      CopySeparators(
        chapterVerse: chapterVerse ?? this.chapterVerse,
        verseList: verseList ?? this.verseList,
        reference: reference ?? this.reference,
        verseRange: verseRange ?? this.verseRange,
      );

  Map<String, dynamic> toJson() => {
        'cv': chapterVerse,
        'vl': verseList,
        'rf': reference,
        'vr': verseRange,
      };

  static CopySeparators fromJson(Map<String, dynamic> j) => CopySeparators(
        chapterVerse: j['cv'] as String? ?? ':',
        verseList: j['vl'] as String? ?? ', ',
        reference: j['rf'] as String? ?? '; ',
        verseRange: j['vr'] as String? ?? '–',
      );

  @override
  bool operator ==(Object other) =>
      other is CopySeparators &&
      other.chapterVerse == chapterVerse &&
      other.verseList == verseList &&
      other.reference == reference &&
      other.verseRange == verseRange;

  @override
  int get hashCode =>
      Object.hash(chapterVerse, verseList, reference, verseRange);
}

/// Everything the formatter needs that is not the verses themselves.
class CopyOptions {
  const CopyOptions({
    this.includeText = true,
    this.versions = const [],
    this.interleave = true,
    this.refScope = CopyRefScope.passage,
    this.refPlacement = CopyRefPlacement.before,
    this.refTemplate = defaultRefTemplate,
    this.bookStyle = CopyBookStyle.full,
    this.inlineVerseNumbers = true,
    this.newlinePerVerse = false,
    this.quoteText = false,
    this.includeNotes = false,
    this.keepSuppliedBrackets = false,
    this.mergeConsecutive = true,
    this.ffThreshold = 0,
    this.refListOnePerLine = false,
    this.separators = const CopySeparators(),
    this.includeAttribution = true,
  });

  /// `<ref> (<version>)`. See [renderTemplate] for the tag list.
  static const defaultRefTemplate = '<ref> (<version>)';

  /// False produces a bare reference list — bwh28's "Copy Verse List
  /// (No Text)".
  final bool includeText;

  /// Version codes in display order. Empty is legal and means "the
  /// caller only wants references".
  final List<String> versions;

  /// True: all versions of verse 1, then all versions of verse 2.
  /// False: all of version A, then all of version B.
  final bool interleave;

  final CopyRefScope refScope;
  final CopyRefPlacement refPlacement;

  /// Template for the reference LABEL that accompanies text. The
  /// compact reference LIST is driven by [separators] instead — they
  /// are different jobs and BibleWorks separates them too.
  final String refTemplate;

  final CopyBookStyle bookStyle;

  /// Print the bare verse number before each verse. Only meaningful
  /// with [CopyRefScope.passage] — in `perVerse` the number is already
  /// in the reference, and repeating it reads as a bug.
  final bool inlineVerseNumbers;

  /// One verse per line, versus one running paragraph.
  final bool newlinePerVerse;

  /// Wrap the quoted text in typographic quotes.
  final bool quoteText;

  /// Keep translator footnotes. Off by default: a footnote is
  /// commentary ABOUT the text, and it arrives mid-sentence.
  final bool includeNotes;

  /// Keep the `[ ]` around words the translator supplied. Off by
  /// default because the common destination is a handout, where the
  /// brackets read as damage; on is the right answer for a paper.
  final bool keepSuppliedBrackets;

  final bool mergeConsecutive;

  /// Runs LONGER than this become `f` / `ff`. Zero disables the
  /// abbreviation entirely and prints explicit ranges, which is the
  /// default: `1:1-4` is unambiguous and `1:1ff` is not.
  final int ffThreshold;

  final bool refListOnePerLine;
  final CopySeparators separators;

  /// Append the rights statement for every version included. Defaults
  /// on — see the library comment.
  final bool includeAttribution;

  CopyOptions copyWith({
    bool? includeText,
    List<String>? versions,
    bool? interleave,
    CopyRefScope? refScope,
    CopyRefPlacement? refPlacement,
    String? refTemplate,
    CopyBookStyle? bookStyle,
    bool? inlineVerseNumbers,
    bool? newlinePerVerse,
    bool? quoteText,
    bool? includeNotes,
    bool? keepSuppliedBrackets,
    bool? mergeConsecutive,
    int? ffThreshold,
    bool? refListOnePerLine,
    CopySeparators? separators,
    bool? includeAttribution,
  }) =>
      CopyOptions(
        includeText: includeText ?? this.includeText,
        versions: versions ?? this.versions,
        interleave: interleave ?? this.interleave,
        refScope: refScope ?? this.refScope,
        refPlacement: refPlacement ?? this.refPlacement,
        refTemplate: refTemplate ?? this.refTemplate,
        bookStyle: bookStyle ?? this.bookStyle,
        inlineVerseNumbers: inlineVerseNumbers ?? this.inlineVerseNumbers,
        newlinePerVerse: newlinePerVerse ?? this.newlinePerVerse,
        quoteText: quoteText ?? this.quoteText,
        includeNotes: includeNotes ?? this.includeNotes,
        keepSuppliedBrackets:
            keepSuppliedBrackets ?? this.keepSuppliedBrackets,
        mergeConsecutive: mergeConsecutive ?? this.mergeConsecutive,
        ffThreshold: ffThreshold ?? this.ffThreshold,
        refListOnePerLine: refListOnePerLine ?? this.refListOnePerLine,
        separators: separators ?? this.separators,
        includeAttribution: includeAttribution ?? this.includeAttribution,
      );

  Map<String, dynamic> toJson() => {
        'includeText': includeText,
        'versions': versions,
        'interleave': interleave,
        'refScope': refScope.name,
        'refPlacement': refPlacement.name,
        'refTemplate': refTemplate,
        'bookStyle': bookStyle.name,
        'inlineVerseNumbers': inlineVerseNumbers,
        'newlinePerVerse': newlinePerVerse,
        'quoteText': quoteText,
        'includeNotes': includeNotes,
        'keepSuppliedBrackets': keepSuppliedBrackets,
        'mergeConsecutive': mergeConsecutive,
        'ffThreshold': ffThreshold,
        'refListOnePerLine': refListOnePerLine,
        'separators': separators.toJson(),
        'includeAttribution': includeAttribution,
      };

  /// Tolerant by design: a stored blob from an older build is missing
  /// keys, and a reader whose Copy Center forgot every setting because
  /// one field was added would reasonably call that a bug.
  static CopyOptions fromJson(Map<String, dynamic> j) {
    T pick<T extends Enum>(List<T> values, Object? raw, T fallback) {
      for (final v in values) {
        if (v.name == raw) return v;
      }
      return fallback;
    }

    const d = CopyOptions();
    return CopyOptions(
      includeText: j['includeText'] as bool? ?? d.includeText,
      versions: (j['versions'] as List?)?.whereType<String>().toList() ??
          const [],
      interleave: j['interleave'] as bool? ?? d.interleave,
      refScope: pick(CopyRefScope.values, j['refScope'], d.refScope),
      refPlacement:
          pick(CopyRefPlacement.values, j['refPlacement'], d.refPlacement),
      refTemplate: j['refTemplate'] as String? ?? d.refTemplate,
      bookStyle: pick(CopyBookStyle.values, j['bookStyle'], d.bookStyle),
      inlineVerseNumbers:
          j['inlineVerseNumbers'] as bool? ?? d.inlineVerseNumbers,
      newlinePerVerse: j['newlinePerVerse'] as bool? ?? d.newlinePerVerse,
      quoteText: j['quoteText'] as bool? ?? d.quoteText,
      includeNotes: j['includeNotes'] as bool? ?? d.includeNotes,
      keepSuppliedBrackets:
          j['keepSuppliedBrackets'] as bool? ?? d.keepSuppliedBrackets,
      mergeConsecutive: j['mergeConsecutive'] as bool? ?? d.mergeConsecutive,
      ffThreshold: (j['ffThreshold'] as num?)?.toInt() ?? d.ffThreshold,
      refListOnePerLine:
          j['refListOnePerLine'] as bool? ?? d.refListOnePerLine,
      separators: j['separators'] is Map
          ? CopySeparators.fromJson(
              (j['separators'] as Map).cast<String, dynamic>())
          : d.separators,
      includeAttribution:
          j['includeAttribution'] as bool? ?? d.includeAttribution,
    );
  }
}

// ── Presets ─────────────────────────────────────────────────────────

/// bwh29 offers "up to 20 preset copy configurations" with user-typed
/// names. That is the right idea and the wrong amount of it: nobody has
/// twenty destinations. These four are the destinations, and the fifth
/// value exists so the UI can say honestly that the settings on screen
/// are no longer any of them.
enum CopyPreset { sermon, citation, referenceList, plain, custom }

/// The options a preset stands for, with [versions] left to the caller
/// — which versions to include is a property of the moment, not of the
/// destination.
CopyOptions optionsForPreset(CopyPreset preset) {
  switch (preset) {
    // A handout or slide deck: one heading, running text with verse
    // numbers, no apparatus of any kind.
    case CopyPreset.sermon:
      return const CopyOptions(
        refScope: CopyRefScope.passage,
        refPlacement: CopyRefPlacement.before,
        inlineVerseNumbers: true,
        newlinePerVerse: false,
        keepSuppliedBrackets: false,
        includeNotes: false,
        quoteText: false,
      );
    // A paper: the quotation, then the reference after it in
    // parentheses, brackets preserved because supplied words are a
    // scholarly claim about the source.
    case CopyPreset.citation:
      return const CopyOptions(
        refScope: CopyRefScope.passage,
        refPlacement: CopyRefPlacement.after,
        inlineVerseNumbers: false,
        newlinePerVerse: false,
        quoteText: true,
        keepSuppliedBrackets: true,
        includeNotes: false,
      );
    // The footnote / index artifact. No text at all.
    case CopyPreset.referenceList:
      return const CopyOptions(
        includeText: false,
        mergeConsecutive: true,
        includeAttribution: false,
      );
    // Bare prose. Nothing but the words.
    case CopyPreset.plain:
      return const CopyOptions(
        refScope: CopyRefScope.none,
        inlineVerseNumbers: false,
        newlinePerVerse: false,
        includeAttribution: false,
      );
    case CopyPreset.custom:
      return const CopyOptions();
  }
}

/// Which preset [o] currently *is*, ignoring [CopyOptions.versions].
/// Returns [CopyPreset.custom] when it matches none — that is what
/// makes the preset row honest after the reader touches a switch.
CopyPreset presetOf(CopyOptions o) {
  for (final p in CopyPreset.values) {
    if (p == CopyPreset.custom) continue;
    if (_sameShape(optionsForPreset(p), o)) return p;
  }
  return CopyPreset.custom;
}

bool _sameShape(CopyOptions a, CopyOptions b) =>
    a.includeText == b.includeText &&
    a.interleave == b.interleave &&
    a.refScope == b.refScope &&
    a.refPlacement == b.refPlacement &&
    a.refTemplate == b.refTemplate &&
    a.bookStyle == b.bookStyle &&
    a.inlineVerseNumbers == b.inlineVerseNumbers &&
    a.newlinePerVerse == b.newlinePerVerse &&
    a.quoteText == b.quoteText &&
    a.includeNotes == b.includeNotes &&
    a.keepSuppliedBrackets == b.keepSuppliedBrackets &&
    a.mergeConsecutive == b.mergeConsecutive &&
    a.ffThreshold == b.ffThreshold &&
    a.refListOnePerLine == b.refListOnePerLine &&
    a.separators == b.separators &&
    a.includeAttribution == b.includeAttribution;

// ── Reference merging ───────────────────────────────────────────────

/// Sort into canonical order and drop duplicates.
///
/// Exposed because both renderers need it and because a search result
/// list genuinely can contain the same verse twice (two hits in one
/// verse), which would otherwise print as `1:1; 1:1`.
List<VerseRef> normaliseRefs(Iterable<VerseRef> refs) {
  final seen = <String>{};
  final out = <VerseRef>[];
  for (final r in refs) {
    final key = '${r.englishBook}|${r.chapter}|${r.verse}';
    if (seen.add(key)) out.add(r);
  }
  out.sort((a, b) {
    final ab = canonicalBookIndex(a.englishBook);
    final bb = canonicalBookIndex(b.englishBook);
    if (ab != bb) return ab.compareTo(bb);
    if (a.chapter != b.chapter) return a.chapter.compareTo(b.chapter);
    return a.verse.compareTo(b.verse);
  });
  return out;
}

/// Render one run of consecutive verses starting at [start] of length
/// [length].
///
/// The `f` / `ff` rule, quoted from bwh29 so the next reader does not
/// have to re-derive it: "Consecutive verses more than this number will
/// be replaced with the 'ff' abbreviation … If this setting is greater
/// than zero and the range only covers two verses, an 'f' will be used
/// instead of an 'ff'. If you wish to merge references but not use the
/// 'f' or 'ff' abbreviations, enter a large number in the box."
///
/// So the threshold is a *floor on explicitness*: runs of `threshold`
/// or fewer print their real end, longer ones abbreviate.
///
/// Zero — never abbreviate — is the default, and the reason is that
/// `ff` is INDETERMINATE. It means "and at least two more", not a
/// count; Chicago's own Q&A glosses `173ff.` as "an indeterminate range
/// expressed as 173–". This app knows the exact verse list, so emitting
/// `ff` would throw away information it has. Chicago "discourage[s] the
/// singular f. because it's always more helpful simply to include the
/// following page"; a divinity-school SBL guide is blunter — "Do not
/// use ff." It stays available because published sources use it and
/// some supervisors ask for it, but it is opt-in legacy style.
String renderRun(int start, int length, CopySeparators sep, int threshold) {
  if (length <= 1) return '$start';
  if (threshold > 0 && length > threshold) {
    return length == 2 ? '${start}f' : '${start}ff';
  }
  return '$start${sep.verseRange}${start + length - 1}';
}

/// A compact reference list — bwh28's "Copy Verse List (No Text)".
///
/// `[Gen 1:1, Gen 1:2, Gen 2:1]` → `Gen 1:1-2; 2:1`, exactly the
/// example bwh29 gives. The book name is printed once per book run and
/// the chapter is restated after each separator, which is the standard
/// compact citation shape and also the reason this cannot be a join().
String renderReferenceList(
  Iterable<VerseRef> refs,
  CopyOptions o,
  BookNamer bookName,
) {
  final list = normaliseRefs(refs);
  if (list.isEmpty) return '';
  final joiner = o.refListOnePerLine ? '\n' : o.separators.reference;

  if (!o.mergeConsecutive) {
    return [
      for (final r in list)
        '${bookName(r.englishBook, o.bookStyle)} '
            '${r.chapter}${o.separators.chapterVerse}${r.verse}',
    ].join(joiner);
  }

  final pieces = <String>[];
  var i = 0;
  while (i < list.length) {
    final book = list[i].englishBook;
    // All refs for this book, as chapter → verses.
    final chapters = <int, List<int>>{};
    final chapterOrder = <int>[];
    while (i < list.length && list[i].englishBook == book) {
      final r = list[i];
      final bucket = chapters[r.chapter];
      if (bucket == null) {
        chapters[r.chapter] = <int>[r.verse];
        chapterOrder.add(r.chapter);
      } else {
        bucket.add(r.verse);
      }
      i++;
    }
    final chapterParts = <String>[];
    for (final c in chapterOrder) {
      final verses = chapters[c]!;
      final runs = <String>[];
      var k = 0;
      while (k < verses.length) {
        var len = 1;
        while (k + len < verses.length && verses[k + len] == verses[k] + len) {
          len++;
        }
        runs.add(renderRun(verses[k], len, o.separators, o.ffThreshold));
        k += len;
      }
      chapterParts.add(
          '$c${o.separators.chapterVerse}${runs.join(o.separators.verseList)}');
    }
    pieces.add('${bookName(book, o.bookStyle)} '
        '${chapterParts.join(o.separators.reference)}');
  }
  return pieces.join(joiner);
}

/// The reference for a whole selection, merged, with no version label
/// — `John 3:16-18`. Used as the `<ref>` tag of a passage heading.
String renderPassageReference(
  Iterable<VerseRef> refs,
  CopyOptions o,
  BookNamer bookName,
) =>
    renderReferenceList(
      refs,
      o.copyWith(mergeConsecutive: true, refListOnePerLine: false),
      bookName,
    );

// ── The reference template ──────────────────────────────────────────

/// Substitute the bwh29 reference tags.
///
/// Supported: `<ref>` (the whole merged reference), `<book>`,
/// `<chapter>`, `<verse>`, `<version>`, `<p>` (line break), `<tab>`.
///
/// bwh29 also lists `<b>`, `<i>` and `<sup>`. They are deliberately
/// absent: this formatter emits plain text, and a literal `<b>` landing
/// in someone's sermon would be worse than not offering it. Unknown
/// tags are left alone for the same reason — silently deleting text a
/// reader typed is the one thing a template engine must not do.
String renderTemplate(
  String template, {
  required String ref,
  required String book,
  required String chapter,
  required String verse,
  required String version,
}) =>
    template
        .replaceAll('<ref>', ref)
        .replaceAll('<book>', book)
        .replaceAll('<chapter>', chapter)
        .replaceAll('<verse>', verse)
        .replaceAll('<version>', version)
        .replaceAll('<p>', '\n')
        .replaceAll('<tab>', '\t')
        // A template of `<ref> (<version>)` with no version selected
        // would otherwise emit a bare `()`.
        .replaceAll(RegExp(r'\(\s*\)'), '')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .trim();

// ── Verse text ──────────────────────────────────────────────────────

/// The verse as it should be pasted: notes and supplied brackets
/// resolved per [o].
///
/// Built on [parseScripture] rather than [scriptureReadingText] because
/// that helper hard-codes one answer (notes gone, brackets gone) and
/// the whole point here is that the answer belongs to the destination.
String copyVerseText(String raw, CopyOptions o) {
  final buf = StringBuffer();
  for (final s in parseScripture(raw)) {
    switch (s.kind) {
      case ScriptureSpanKind.plain:
        buf.write(s.text);
      case ScriptureSpanKind.supplied:
        buf.write(o.keepSuppliedBrackets ? '[${s.text}]' : s.text);
      case ScriptureSpanKind.note:
        // The leading space matters: a note attaches to the word it
        // annotates with no space in the source (`Now<note: Or "And">`),
        // so inlining it verbatim yields `Now(Or "And")`. The collapse
        // pass below removes the double space when there already was
        // one, and `trim` handles a verse that opens with a note.
        if (o.includeNotes) buf.write(' (${s.text})');
    }
  }
  return buf
      .toString()
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .replaceAllMapped(RegExp(r' ([,.;:!?])'), (m) => m.group(1)!)
      .trim();
}

// ── The whole output ────────────────────────────────────────────────

/// Curly quotes. Correct English typography and correct Simplified
/// Chinese; Traditional Chinese prefers 「」, which is a real
/// imperfection and a smaller one than shipping a quote-character
/// setting nobody would find.
const _openQuote = '“';
const _closeQuote = '”';

/// Format [refs] into the text that goes on the clipboard.
///
/// Returns the empty string when there is nothing to say — an empty
/// selection, or versions that carry none of the requested verses. The
/// caller shows the empty state; this does not invent one.
String formatCopy(
  Iterable<VerseRef> refs,
  CopyOptions o, {
  required BookNamer bookName,
  required VersionNamer versionName,
  required VerseTextLookup verseText,
  AttributionLookup? attribution,
}) {
  final list = normaliseRefs(refs);
  if (list.isEmpty) return '';

  if (!o.includeText) {
    final body = renderReferenceList(list, o, bookName);
    return o.includeAttribution
        ? _withAttribution(body, o, versionName, attribution)
        : body;
  }

  final versions = o.versions.isEmpty ? const <String>[] : o.versions;
  if (versions.isEmpty) return renderReferenceList(list, o, bookName);

  final multi = versions.length > 1;
  final verseJoin = o.newlinePerVerse ? '\n' : ' ';

  // One verse in one version, as it will appear on its own line.
  String? line(String code, VerseRef r) {
    final raw = verseText(code, r);
    if (raw == null || raw.trim().isEmpty) return null;
    var text = copyVerseText(raw, o);
    if (text.isEmpty) return null;
    if (o.refScope == CopyRefScope.perVerse) {
      final label = renderTemplate(
        o.refTemplate,
        ref: '${bookName(r.englishBook, o.bookStyle)} '
            '${r.chapter}${o.separators.chapterVerse}${r.verse}',
        book: bookName(r.englishBook, o.bookStyle),
        chapter: '${r.chapter}',
        verse: '${r.verse}',
        version: versionName(code),
      );
      if (o.quoteText) text = '$_openQuote$text$_closeQuote';
      return o.refPlacement == CopyRefPlacement.before
          ? '$label $text'
          : '$text $label';
    }
    // passage / none: an inline verse number is the only marker, and
    // in interleaved multi-version output the version has to be named
    // on every line or the block is unreadable.
    final prefix = <String>[
      if (multi && o.interleave) versionName(code),
      if (o.inlineVerseNumbers) '${r.verse}',
    ].join(' ');
    return prefix.isEmpty ? text : '$prefix $text';
  }

  final blocks = <String>[];
  if (o.interleave || !multi) {
    final lines = <String>[];
    for (final r in list) {
      for (final code in versions) {
        final l = line(code, r);
        if (l != null) lines.add(l);
      }
    }
    if (lines.isEmpty) return '';
    // Interleaving without a line break per verse would run four
    // translations of the same verse into one paragraph, which is not
    // a document anyone wants.
    blocks.add(lines.join(multi ? '\n' : verseJoin));
  } else {
    for (final code in versions) {
      final lines = <String>[];
      for (final r in list) {
        final l = line(code, r);
        if (l != null) lines.add(l);
      }
      if (lines.isEmpty) continue;
      blocks.add('${versionName(code)}\n${lines.join(verseJoin)}');
    }
    if (blocks.isEmpty) return '';
  }

  var body = blocks.join('\n\n');

  if (o.refScope == CopyRefScope.passage) {
    if (o.quoteText) body = '$_openQuote$body$_closeQuote';
    final heading = renderTemplate(
      o.refTemplate,
      ref: renderPassageReference(list, o, bookName),
      book: bookName(list.first.englishBook, o.bookStyle),
      chapter: '${list.first.chapter}',
      verse: '${list.first.verse}',
      // With several versions the heading cannot name one, and naming
      // the first would be a false citation.
      version: multi ? '' : versionName(versions.first),
    );
    body = o.refPlacement == CopyRefPlacement.before
        ? '$heading\n$body'
        : '$body\n$heading';
  } else if (o.refScope == CopyRefScope.none && o.quoteText) {
    body = '$_openQuote$body$_closeQuote';
  }

  return o.includeAttribution
      ? _withAttribution(body, o, versionName, attribution)
      : body;
}

String _withAttribution(
  String body,
  CopyOptions o,
  VersionNamer versionName,
  AttributionLookup? attribution,
) {
  if (attribution == null || o.versions.isEmpty) return body;
  final lines = <String>[];
  final seen = <String>{};
  for (final code in o.versions) {
    final rights = attribution(code);
    if (rights == null || rights.isEmpty) continue;
    final line = '${versionName(code)} — $rights';
    if (seen.add(line)) lines.add(line);
  }
  if (lines.isEmpty) return body;
  return '$body\n\n${lines.join('\n')}';
}
