/// 2026-08-06 (SeekSparks): the Word Analysis pane — a live readout of
/// whatever the mouse is over in the Browse window.
///
/// From the BibleWorks 10 manual, on the Analysis window:
///
/// > "When you move the mouse over a word in the Browse Window,
/// > information about the word or verse being examined will be shown
/// > in this window."
///
/// and on the Word Analysis tab specifically:
///
/// > "displays lexical and other verse-specific information
/// > automatically as you move the mouse cursor over text in the Browse
/// > Window … If you hold down the Shift key as you move the mouse
/// > cursor the content of the Word Analysis Window will not change."
///
/// That is the product. The Analysis window is not a click target; it
/// is the pointer's readout, and Shift is the brake. SeekSparks had it
/// as a click target with a hover *tooltip* bolted on — the right idea
/// at a tenth of the value, because you had to interrupt reading to see
/// a full entry.
///
/// The pane deliberately does NOT blank when the pointer leaves the
/// text: BibleWorks keeps the last word up, so you can move the mouse
/// to the pane itself and read it.
library;

import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/material.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/original_word.dart';
import 'package:seeksparks/models/strongs.dart';
import 'package:seeksparks/services/bible_names_service.dart';
import 'package:seeksparks/services/chinese_lexicon_service.dart';
import 'package:seeksparks/services/strongs_service.dart';
import 'package:seeksparks/services/thayer_service.dart';
import 'package:seeksparks/utils/cbol_references.dart';
import 'package:seeksparks/utils/ketiv_qere.dart'
    show ketivQereLabel, ketivQereNote;
import 'package:seeksparks/utils/morphology.dart' show describeMorphology;
import 'package:seeksparks/utils/thayer_parse.dart';
import 'package:seeksparks/widgets/word_forms_section.dart';

class WordAnalysisPane extends StatefulWidget {
  const WordAnalysisPane({
    super.key,
    required this.word,
    required this.reference,
    required this.locale,
    required this.version,
    required this.frozen,
    this.grammar = const [],
    this.onOpenFullEntry,
    this.onOpenRef,
  });

  final OriginalWord word;

  /// "Genesis 1:1" — printed in the header the way BibleWorks does.
  final String reference;
  final String locale;

  /// The reading version, so references sourced from the English-keyed
  /// original-language corpus print in the language on screen.
  final String version;

  /// True while Shift is held. Shown as a badge so the reader knows why
  /// the pane stopped following the mouse.
  final bool frozen;

  /// Grammar / TVM codes carried by this word on a tagged line. Decoded
  /// via the Chinese module, which is the only source that has them.
  final List<String> grammar;

  final VoidCallback? onOpenFullEntry;

  /// Jump to one of the example occurrences printed by the Forms
  /// section. Optional so the pane still renders outside the workbench.
  final void Function(String englishBook, int chapter, int verse)? onOpenRef;

  @override
  State<WordAnalysisPane> createState() => _WordAnalysisPaneState();
}

/// The line printed under the word: what lemma this occurrence is an
/// inflection of, and how that LEMMA is romanised and pronounced.
///
/// The lexicon is keyed by Strong's number, so every value it returns
/// answers for the lemma and for no particular occurrence. [form] is
/// passed only so the lemma glyph can be dropped when it would repeat
/// the word already printed above; nothing about the form is romanised
/// here, because the corpus carries a per-occurrence romanisation for
/// the Greek NT only and none at all for the Hebrew Bible.
String buildLemmaLine({
  required String form,
  String? lemma,
  String? translit,
  String? pronunciation,
}) {
  final parts = <String>[
    if ((lemma ?? '').isNotEmpty && lemma != form) lemma!,
    if ((translit ?? '').isNotEmpty) translit!,
  ];
  final head = parts.join(' · ');
  if ((pronunciation ?? '').isEmpty) return head;
  return head.isEmpty ? '/$pronunciation/' : '$head  /$pronunciation/';
}

class _WordAnalysisPaneState extends State<WordAnalysisPane> {
  StrongsEntry? _entry;
  String? _loadedFor;

  /// BDB/Thayer in Chinese. Deeper than the CBOL gloss on [_entry], so
  /// for a Chinese reader it replaces the Meaning/Definition block
  /// rather than sitting beside it.
  ChineseLexEntry? _zh;

  /// Decoded grammar codes for this word — the blue numbers on a
  /// tagged line. Nothing else in the app could explain them.
  List<ChineseLexEntry> _zhGrammar = const [];

  /// Thayer's (1889) in English. The Chinese reader has had this article
  /// since the module import; the English reader had only Strong's
  /// one-line gloss. Loaded for non-Chinese locales only, since a
  /// Chinese reader is better served by [_zh].
  ThayerEntry? _thayer;

  /// The same, for the parsing codes G5627–G5798.
  List<ThayerEntry> _enGrammar = const [];

  /// Hitchcock's reading of the name, when this word is one. Printed
  /// beside Thayer's rather than instead of it — the two disagree often
  /// enough that picking a winner would be editorialising.
  String? _hitchcock;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant WordAnalysisPane old) {
    super.didUpdateWidget(old);
    if (old.word.strongs != widget.word.strongs ||
        old.locale != widget.locale) {
      _loadedFor = null;
      _load();
    }
  }

  /// Keeps the previous entry on screen while the next one resolves.
  /// Blanking between words would make the pane strobe as the pointer
  /// crosses a line — the opposite of a readout.
  Future<void> _load() async {
    final number = widget.word.strongs;
    if (number.isEmpty || number == _loadedFor) return;
    final e = await StrongsService.lookup(number);
    final wantZh = ChineseLexiconService.appliesTo(widget.locale);
    final zh = wantZh ? await ChineseLexiconService.lookup(number) : null;
    final grammar = <ChineseLexEntry>[];
    if (wantZh) {
      for (final code in widget.grammar) {
        final g = await ChineseLexiconService.lookup(code);
        if (g != null && g.isGrammarCode) grammar.add(g);
      }
    }
    ThayerEntry? thayer;
    var enGrammar = const <ThayerEntry>[];
    String? hitchcock;
    if (!wantZh) {
      thayer = await ThayerService.lookup(number);
      final codes = <ThayerEntry>[];
      for (final code in widget.grammar) {
        final g = await ThayerService.lookup(code);
        if (g != null && g.isGrammarCode) codes.add(g);
      }
      enGrammar = codes;
      // Hebrew names never reach Thayer's, so Hitchcock is the only
      // source for the whole Old Testament.
      if (e != null && e.isProperNoun) {
        hitchcock = await BibleNamesService.lookupFromGloss(e.gloss);
      }
    }
    if (!mounted || widget.word.strongs != number) return;
    setState(() {
      _entry = e;
      _zh = zh;
      _zhGrammar = grammar;
      _thayer = thayer;
      _enGrammar = enGrammar;
      _hitchcock = hitchcock;
      _loadedFor = number;
    });
  }

  @override
  Widget build(BuildContext context) {
    _releaseRecognizers();
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final locale = widget.locale;
    final e = _entry;
    final zh = _zh;
    final th = _thayer;
    final parse = describeMorphology(widget.word.morph, locale);
    final lemmaLine = buildLemmaLine(
      form: widget.word.text,
      lemma: e?.lemma,
      translit: e?.translit,
      pronunciation: e?.pronunciation,
    );

    String s(String key, String fallback) =>
        uiStrings[key]?[locale] ?? fallback;

    return Container(
      color: wb.paneBg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 16),
        children: [
          // ── Header: reference + Strong's number, plus the freeze badge
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.reference,
                  style: TextStyle(
                    fontSize: t.chrome,
                    color: wb.mutedText,
                  ),
                ),
              ),
              if (widget.frozen)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  color: wb.selectionBg,
                  child: Text(
                    s('analysisFrozen', 'FROZEN — Shift'),
                    style: TextStyle(
                      fontSize: t.chrome,
                      fontWeight: FontWeight.w700,
                      color: wb.text,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),

          // ── The word itself, big and red, as BibleWorks prints it
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                widget.word.strongs,
                style: TextStyle(
                  fontSize: t.chrome,
                  fontWeight: FontWeight.w700,
                  color: wb.mutedText,
                ),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  widget.word.text,
                  style: TextStyle(
                    fontSize: t.scaledOriginal(21),
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB3261E),
                  ),
                ),
              ),
            ],
          ),

          // ── The lemma, and the romanisation + pronunciation that
          // belong to IT. Until v1.6.88 the transliteration sat in
          // brackets beside the word above, which said that ἦλθεν is
          // pronounced *érchomai*; it is not, that is ἔρχομαι. The
          // lexicon is keyed by Strong's number and so answers for the
          // lemma only — printing the lemma is what makes it true.
          if (lemmaLine.isNotEmpty)
            Text(
              lemmaLine,
              style: TextStyle(
                fontSize: t.chrome,
                fontStyle: FontStyle.italic,
                color: wb.mutedText,
              ),
            ),

          // ── Parsing. The line the whole Analysis window exists for.
          if (parse != null && parse.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: wb.link.withValues(alpha: 0.08),
                border: Border.all(color: wb.link.withValues(alpha: 0.30)),
              ),
              child: Text(
                parse,
                style: TextStyle(
                  fontSize: t.text,
                  fontWeight: FontWeight.w600,
                  color: wb.link,
                  height: 1.35,
                ),
              ),
            ),
          ] else ...[
            // A word with no code is not a bug to hide. 868 of the 869
            // untagged words are received-text readings SBLGNT does not
            // carry, so the blank is information about the text — but
            // only if the pane says whose text it is measuring against.
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: wb.border),
              ),
              child: Text(
                widget.word.strongs.toUpperCase().startsWith('H')
                    ? s('analysisNoParseHebrew',
                        'No parsing. Hebrew parsing comes from the Open '
                        'Scriptures Hebrew Bible (WLC).')
                    : s('analysisNoParseGreek',
                        'No parsing. Greek parsing comes from SBLGNT, '
                        'which does not carry every reading of the text '
                        'shown here.'),
                style: TextStyle(
                  fontSize: t.chrome,
                  color: wb.mutedText,
                  height: 1.35,
                ),
              ),
            ),
          ],

          // ── Ketiv/Qere. Above the forms section because it answers a
          // question the reader asked before they got here: why the
          // verse prints two words where the text has one. The pane is
          // the only place that can answer it in a sentence.
          if (ketivQereLabel(widget.word.ketivQere, locale)
              case final kqLabel?) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(border: Border.all(color: wb.border)),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: kqLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: wb.text,
                    ),
                  ),
                  TextSpan(
                    text: '\n${ketivQereNote(widget.word.ketivQere, locale)}',
                    style: TextStyle(color: wb.mutedText),
                  ),
                ]),
                style: TextStyle(fontSize: t.chrome, height: 1.35),
              ),
            ),
          ],

          // ── bwh10q. Directly under the parsing box because its first
          // job is to say how certain that box is: for 4,756 forms the
          // corpus parses the same string more than one way, and until
          // now the pane printed one of them with nothing to say so.
          WordFormsSection(
            word: widget.word,
            locale: locale,
            version: widget.version,
            onOpenRef: widget.onOpenRef,
          ),

          // ── Grammar codes, decoded. On a tagged line these are the
          // blue numbers; without this they are unreadable.
          for (final g in _enGrammar) ...[
            const SizedBox(height: 6),
            _codeBox(
              wb,
              t,
              g.number,
              g.grammarLines.join(' · '),
            ),
          ],
          for (final g in _zhGrammar) ...[
            const SizedBox(height: 6),
            _codeBox(wb, t, g.number, g.parsing.join(' · ')),
          ],

          // ── The Chinese lexicon, when we have one. It supersedes the
          // CBOL gloss below rather than duplicating it: same number,
          // more of the entry.
          if (zh != null) ...[
            _field(wb, t, s('analysisLemma', 'Lemma'),
                [zh.lemma, if (zh.translit.isNotEmpty) zh.translit]
                    .where((x) => x.isNotEmpty)
                    .join('  ')),
            _field(wb, t, s('analysisOrigin', 'Origin'), zh.etymology),
            if (zh.senses.isNotEmpty)
              _field(wb, t, s('analysisDefinition', 'Definition'),
                  zh.senses.join('\n')),
            _field(wb, t, s('analysisUsage', 'KJV usage'), zh.usage),
            if (ChineseLexiconService.isSimplifiedOnly(locale))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  s('analysisSimplifiedOnly',
                      'This lexicon is published in Simplified Chinese only.'),
                  style: TextStyle(
                    fontSize: t.chrome,
                    fontStyle: FontStyle.italic,
                    color: wb.mutedText,
                  ),
                ),
              ),
          ] else if (e != null) ...[
            _field(wb, t, s('analysisMeaning', 'Meaning'),
                e.localizedGloss(locale)),
            _nameMeanings(wb, t, s),
            _field(wb, t, s('analysisOrigin', 'Origin'),
                th?.etymology.isNotEmpty == true
                    ? th!.etymology
                    : (e.derivation ?? '')),
            // Thayer's numbered senses supersede Strong's one-paragraph
            // definition — same word, an article instead of a line.
            if (th == null || th.senses.isEmpty)
              _field(wb, t, s('analysisDefinition', 'Definition'),
                  e.localizedDefinition(locale)),
          ],

          if (th != null) ..._thayerBlock(wb, t, s, th),

          if (e != null || zh != null) ...[
            if (widget.onOpenFullEntry != null) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: widget.onOpenFullEntry,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    s('analysisFullEntry',
                        'Full entry, word family & concordance →'),
                    style: TextStyle(
                      fontSize: t.chrome,
                      fontWeight: FontWeight.w600,
                      color: wb.link,
                    ),
                  ),
                ),
              ),
            ],
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                s('analysisNoEntry', 'No lexicon entry for this number.'),
                style: TextStyle(
                    fontSize: t.text, color: wb.mutedText),
              ),
            ),

          _attribution(wb, t),
        ],
      ),
    );
  }

  /// The tinted box used for a decoded grammar code, in either language.
  Widget _codeBox(WbColors wb, WbType t, String number, String body) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: wb.strongsGrammar.withValues(alpha: 0.08),
        border:
            Border.all(color: wb.strongsGrammar.withValues(alpha: 0.30)),
      ),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
            text: '$number  ',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: wb.strongsGrammar,
            ),
          ),
          TextSpan(text: body, style: TextStyle(color: wb.strongsGrammar)),
        ]),
        style: TextStyle(fontSize: t.text, height: 1.35),
      ),
    );
  }

  /// Thayer's and Hitchcock's readings of a proper name, side by side.
  /// They disagree constantly — Aaron is "light-bringer" to Thayer and
  /// "a teacher; lofty; mountain of strength" to Hitchcock — so both are
  /// printed with their source, and neither is presented as the answer.
  Widget _nameMeanings(
      WbColors wb, WbType t, String Function(String, String) s) {
    final thayer = _thayer?.nameMeaning ?? '';
    final hitchcock = _hitchcock ?? '';
    if (thayer.isEmpty && hitchcock.isEmpty) return const SizedBox.shrink();
    final parts = <String>[
      if (thayer.isNotEmpty)
        '${s('analysisSourceThayer', "Thayer's")}: $thayer',
      if (hitchcock.isNotEmpty)
        '${s('analysisSourceHitchcock', 'Hitchcock')}: $hitchcock',
    ];
    return _field(
        wb, t, s('analysisNameMeaning', 'Name means'), parts.join('\n'));
  }

  /// Everything Thayer's carries that Strong's does not: the KJV
  /// rendering counts, the numbered sense outline, the commentary
  /// paragraphs, and the synonym cross-references.
  List<Widget> _thayerBlock(WbColors wb, WbType t,
      String Function(String, String) s, ThayerEntry th) {
    if (th.isGrammarCode) return const [];
    if (th.isNotUsed) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            s('analysisNotUsed', "Not treated in Thayer's."),
            style: TextStyle(fontSize: t.chrome, color: wb.mutedText),
          ),
        ),
      ];
    }

    final pos = decodePartOfSpeech(th.partOfSpeech);
    final chips = <String>[
      if (pos != null) pos,
      if (th.tdnt.isNotEmpty)
        '${s('analysisTdnt', 'TDNT (Kittel)')} ${th.tdnt}',
    ];

    return [
      if (chips.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            chips.join('  ·  '),
            style: TextStyle(fontSize: t.chrome, color: wb.mutedText),
          ),
        ),
      if (th.avCounts.isNotEmpty)
        _field(
          wb,
          t,
          th.avTotal > 0
              ? '${s('analysisAvUsage', 'KJV renderings')} '
                  '(${th.avTotal})'
              : s('analysisAvUsage', 'KJV renderings'),
          th.avCounts
              .map((a) => a.count > 0 ? '${a.rendering} ${a.count}' : a.rendering)
              .join(', '),
        ),
      if (th.senses.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          s('analysisSenses', "Senses (Thayer's)"),
          style: TextStyle(
            fontSize: t.text,
            fontWeight: FontWeight.w700,
            color: wb.text,
          ),
        ),
        for (final sense in th.senses)
          Padding(
            // The outline nests four deep; the indent is what makes
            // "1b2a" legible as a sub-sense rather than a flat list.
            padding: EdgeInsets.only(left: (sense.level - 1) * 12.0, top: 3),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '${sense.marker})  ',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: wb.mutedText,
                  ),
                ),
                TextSpan(text: sense.text),
              ]),
              style: TextStyle(
                  fontSize: t.text, height: 1.4, color: wb.text),
            ),
          ),
      ],
      for (final note in th.notes) _field(wb, t, s('analysisNotes', 'Notes'), note),
      if (th.synonymRefs.isNotEmpty)
        _field(wb, t, s('analysisSynonyms', 'Synonyms — see entry'),
            th.synonymRefs.join(', ')),
    ];
  }

  /// Both sources ask to be credited, and a reader is entitled to know
  /// which edition of a 19th-century lexicon they are reading.
  Widget _attribution(WbColors wb, WbType t) {
    final lines = <String>[
      if (_thayer != null) ThayerService.attribution,
      if ((_hitchcock ?? '').isNotEmpty) BibleNamesService.attribution,
    ].where((a) => a.isNotEmpty).toList();
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        lines.join('\n'),
        style: TextStyle(
          fontSize: t.chrome,
          fontStyle: FontStyle.italic,
          color: wb.mutedText,
          height: 1.35,
        ),
      ),
    );
  }

  /// One recognizer per rendered citation, released on the next build.
  /// The pane re-renders on every mouse move over the text, so leaving
  /// them behind would leak one per word hovered.
  final List<TapGestureRecognizer> _recognizers = [];

  void _releaseRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  Widget _field(WbColors wb, WbType t, String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    final base = TextStyle(color: wb.text);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: wb.text),
          ),
          // The Chinese lexicon cites scripture inline. BibleWorks makes
          // a reference inside a resource a live target; so does this.
          ...buildCbolSpans(
            source: value,
            baseStyle: base,
            refColor: wb.accent,
            onRefTap: widget.onOpenRef == null ? null : _openCitation,
            recognizers: _recognizers,
          ),
        ]),
        style: TextStyle(fontSize: t.text, height: 1.45),
      ),
    );
  }

  @override
  void dispose() {
    _releaseRecognizers();
    super.dispose();
  }

  void _openCitation(CbolRun run) {
    widget.onOpenRef?.call(run.englishBook!, run.chapter!, run.verse ?? 1);
  }
}
