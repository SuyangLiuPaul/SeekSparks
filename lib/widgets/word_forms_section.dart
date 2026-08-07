/// 2026-08-07 (SeekSparks): the Forms readout — BibleWorks bwh10q, as a
/// section of the Analysis pane rather than an eleventh tab.
///
/// Why not a tab: the strip already carries ten, and at the Analysis
/// pane's 288 px minimum each one is down to an icon in 26 px. An
/// eleventh would overflow. More to the point, the half of bwh10q that
/// matters is a *qualifier on the parsing line* — it says how certain
/// that line is — and a qualifier that lives one tab away from the claim
/// it qualifies will not be read. So it sits directly under the box.
///
/// Two blocks, in the order a reader needs them:
///
///   1. **Ambiguity**, shown only when the corpus disagrees with itself
///      about this form. Silent otherwise: 96.4% of forms have exactly
///      one parse and a badge saying "unambiguous" on every one of them
///      would train the reader to stop seeing the block that matters.
///   2. **The paradigm** — every form of this lemma, frequency first,
///      collapsed by default because a Hebrew verb can run to 80 rows.
///
/// The section never renders a spinner. The Analysis pane follows the
/// pointer, so a per-word spinner would strobe across a line of text;
/// instead the last result stays up until the next one resolves, which
/// is the same rule the surrounding pane uses for its lexicon entry.
library;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/original_word.dart';
import 'package:seeksparks/services/word_forms_service.dart';
import 'package:seeksparks/utils/morphology.dart' show describeMorphology;
import 'package:seeksparks/utils/word_forms.dart';

class WordFormsSection extends StatefulWidget {
  const WordFormsSection({
    super.key,
    required this.word,
    required this.locale,
    this.onOpenRef,
  });

  final OriginalWord word;
  final String locale;

  /// Navigate to one of the example occurrences. When null the refs are
  /// still printed — they locate the form — but are not interactive.
  final void Function(String englishBook, int chapter, int verse)? onOpenRef;

  @override
  State<WordFormsSection> createState() => _WordFormsSectionState();
}

class _WordFormsSectionState extends State<WordFormsSection> {
  List<WordForm> _forms = const [];
  FormAmbiguity _ambiguity = const FormAmbiguity.unambiguous('');
  Map<String, List<FormRef>> _refs = const {};
  String? _loadedFor;
  bool _expanded = false;
  FormSort _sort = FormSort.frequency;

  /// Identity of a lookup: the lemma drives the paradigm, the surface
  /// form drives the ambiguity block, so a change in either is a new
  /// question.
  String get _key => '${widget.word.strongs}|${widget.word.text}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant WordFormsSection old) {
    super.didUpdateWidget(old);
    if (old.word.strongs != widget.word.strongs ||
        old.word.text != widget.word.text) {
      // Collapse on a new word: leaving it open would drop the reader
      // into an 80-row paradigm for a word they only glanced at.
      _expanded = false;
      _load();
    }
  }

  Future<void> _load() async {
    final key = _key;
    if (key == _loadedFor) return;
    final forms = await WordFormsService.formsFor(widget.word.strongs);
    // Only original-language strings are in the index, so a translation
    // word (English, Chinese) misses and reads as unambiguous. That is
    // the correct answer rather than a gap: the claim is about the
    // Greek or Hebrew form, and there isn't one here.
    final ambiguity = await WordFormsService.ambiguityFor(widget.word.text);
    final refs = <String, List<FormRef>>{};
    for (final f in forms) {
      refs['${f.form}|${f.morph}'] = await WordFormsService.refsOf(f);
    }
    if (!mounted || _key != key) return;
    setState(() {
      _forms = forms;
      _ambiguity = ambiguity;
      _refs = refs;
      _loadedFor = key;
    });
  }

  String _s(String key, String fallback) =>
      uiStrings[key]?[widget.locale] ?? fallback;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    if (_forms.isEmpty && !_ambiguity.isAmbiguous) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_ambiguity.isAmbiguous) _ambiguityBlock(wb, t),
        if (_forms.isNotEmpty) _paradigm(wb, t),
      ],
    );
  }

  // ── 1. How certain is the parse above? ────────────────────────────

  Widget _ambiguityBlock(WbColors wb, WbType t) {
    final others =
        _ambiguity.othersThan(widget.word.strongs, widget.word.morph ?? '');
    if (others.isEmpty) return const SizedBox.shrink();

    // Two different words is a stronger claim than two parses of one
    // word, and it is the case a reader must not miss — so it gets its
    // own sentence rather than a count they have to interpret.
    final headline = _ambiguity.spansLemmas
        ? _s('formsAmbiguousLemma',
                'This form is also a different word elsewhere.')
        : _s('formsAmbiguousParse',
            'This form is parsed more than one way elsewhere.');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: wb.strongsGrammar.withValues(alpha: 0.07),
        border: Border.all(color: wb.strongsGrammar.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.call_split_rounded,
                  size: t.text, color: wb.strongsGrammar),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  headline,
                  style: TextStyle(
                    fontSize: t.chrome,
                    fontWeight: FontWeight.w700,
                    color: wb.strongsGrammar,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          for (final p in others) _parseRow(wb, t, p),
        ],
      ),
    );
  }

  Widget _parseRow(WbColors wb, WbType t, FormParse p) {
    final parse = describeMorphology(p.morph, widget.locale) ?? p.morph;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
            text: '${p.strongs}  ',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: wb.strongsGrammar,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          TextSpan(text: parse, style: TextStyle(color: wb.text)),
          TextSpan(
            text: '  ×${p.count}',
            style: TextStyle(color: wb.mutedText),
          ),
        ]),
        style: TextStyle(fontSize: t.chrome, height: 1.4),
      ),
    );
  }

  // ── 2. Every form of this lemma ───────────────────────────────────

  Widget _paradigm(WbColors wb, WbType t) {
    final sorted = sortForms(_forms, _sort);
    final total = _forms.fold<int>(0, (sum, f) => sum + f.count);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    size: t.text + 3, color: wb.link),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    // The two numbers answer different questions: how
                    // many shapes the word takes, and how often it is
                    // used at all.
                    _s('formsHeader', 'Forms of this word')
                        .replaceFirst('{n}', '${_forms.length}')
                        .replaceFirst('{total}', '$total'),
                    style: TextStyle(
                      fontSize: t.chrome,
                      fontWeight: FontWeight.w700,
                      color: wb.link,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          _sortBar(wb, t),
          for (final f in sorted) _formRow(wb, t, f),
        ],
      ],
    );
  }

  Widget _sortBar(WbColors wb, WbType t) {
    Widget button(FormSort value, String key, String fallback) {
      final on = _sort == value;
      return InkWell(
        onTap: () => setState(() => _sort = value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          child: Text(
            _s(key, fallback),
            style: TextStyle(
              fontSize: t.chrome - 1,
              fontWeight: on ? FontWeight.w700 : FontWeight.w400,
              color: on ? wb.link : wb.mutedText,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Row(children: [
        Text(_s('formsSortBy', 'Sort:'),
            style: TextStyle(fontSize: t.chrome - 1, color: wb.mutedText)),
        button(FormSort.frequency, 'formsSortFrequency', 'frequency'),
        button(FormSort.morphCode, 'formsSortCode', 'parsing'),
        button(FormSort.alphabetical, 'formsSortAlpha', 'a–z'),
      ]),
    );
  }

  Widget _formRow(WbColors wb, WbType t, WordForm f) {
    // The form the reader is actually looking at, marked so the
    // paradigm reads as "you are here" rather than as a bare list.
    final here =
        f.form == widget.word.text && f.morph == (widget.word.morph ?? '');
    final parse = describeMorphology(f.morph, widget.locale) ?? f.morph;
    final refs = _refs['${f.form}|${f.morph}'] ?? const <FormRef>[];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: here ? wb.selectionBg : null,
        border: Border(
          left: BorderSide(
            width: 2,
            color: here ? wb.link : Colors.transparent,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  f.form,
                  style: TextStyle(
                    fontSize: t.text + 1,
                    fontWeight: here ? FontWeight.w700 : FontWeight.w500,
                    color: wb.text,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${f.count}',
                style: TextStyle(
                  fontSize: t.chrome,
                  fontWeight: FontWeight.w700,
                  color: wb.mutedText,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (parse.isNotEmpty)
            Text(
              parse,
              style: TextStyle(
                fontSize: t.chrome,
                color: wb.mutedText,
                height: 1.35,
              ),
            ),
          if (refs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final r in refs)
                    InkWell(
                      onTap: widget.onOpenRef == null
                          ? null
                          : () => widget.onOpenRef!(
                              r.englishBook, r.chapter, r.verse),
                      child: Text(
                        '${r.englishBook} ${r.chapter}:${r.verse}',
                        style: TextStyle(
                          fontSize: t.chrome - 1,
                          color: widget.onOpenRef == null
                              ? wb.mutedText
                              : wb.link,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
