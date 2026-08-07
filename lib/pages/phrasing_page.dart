/// 2026-08-07 (SeekSparks): the Phrasing surface — SeekSparks' answer
/// to BibleWorks' Diagramming Module (bwh25). See `utils/phrasing.dart`
/// for why this is an indented text structure and not a vector canvas.
///
/// Interaction grammar, deliberately the same one v1.6.28 established
/// in the Browse window: **hover previews, click commits.** Pointing at
/// a word parses it in the footer and changes nothing; clicking it
/// breaks the line. A reader who has learned one surface has learned
/// both.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:seeksparks/constants/book_names.dart' show bookNameToEnglish;
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/services/originals_service.dart';
import 'package:seeksparks/services/phrasing_store.dart';
import 'package:seeksparks/utils/morphology.dart';
import 'package:seeksparks/utils/phrasing.dart';
import 'package:seeksparks/utils/version_mapper.dart' show localeAwareBookName;

/// Reader-facing label for a relation, in [locale].
String phrasingRelationLabel(PhrasingRelation r, String locale) {
  const fallbacks = <PhrasingRelation, String>{
    PhrasingRelation.series: 'series',
    PhrasingRelation.progression: 'progression',
    PhrasingRelation.contrast: 'contrast',
    PhrasingRelation.alternative: 'alternative',
    PhrasingRelation.comparison: 'comparison',
    PhrasingRelation.purpose: 'purpose',
    PhrasingRelation.result: 'result',
    PhrasingRelation.ground: 'ground',
    PhrasingRelation.inference: 'inference',
    PhrasingRelation.means: 'means',
    PhrasingRelation.manner: 'manner',
    PhrasingRelation.condition: 'condition',
    PhrasingRelation.concession: 'concession',
    PhrasingRelation.temporal: 'time',
    PhrasingRelation.place: 'place',
    PhrasingRelation.content: 'content',
    PhrasingRelation.apposition: 'apposition',
    PhrasingRelation.relative: 'relative',
  };
  final key = 'phrasingRel${r.name[0].toUpperCase()}${r.name.substring(1)}';
  return uiStrings[key]?[locale] ?? fallbacks[r] ?? r.name;
}

class PhrasingPage extends StatefulWidget {
  const PhrasingPage({
    super.key,
    required this.book,
    required this.chapter,
    required this.verse,
    required this.locale,
    required this.version,
  });

  /// Book as the reader sees it; mapped to English for the lookup.
  final String book;
  final int chapter;

  /// Where the workbench cursor was. Seeds the verse window.
  final int verse;
  final String locale;
  final String version;

  @override
  State<PhrasingPage> createState() => _PhrasingPageState();
}

class _PhrasingPageState extends State<PhrasingPage> {
  List<PhrasingWord> _words = const [];
  Phrasing? _p;
  bool _loading = true;
  int? _hover;

  String get _englishBook => bookNameToEnglish[widget.book] ?? widget.book;

  /// Every verse number present in the chapter, ascending. Drives the
  /// window steppers, so a chapter with a gap in the tagged corpus
  /// cannot offer a verse that is not there.
  List<int> get _verseNumbers {
    final seen = <int>{};
    for (final w in _words) {
      seen.add(w.verse);
    }
    return seen.toList()..sort();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final words = <PhrasingWord>[];
    // The word list is the WHOLE chapter, always — see
    // [visiblePhrasingLines] for why the window must not affect indices.
    var verse = 0;
    final byVerse =
        await OriginalsService.versesOfBook(_englishBook);
    final keys = byVerse.keys
        .where((k) => k.split(':').first == '${widget.chapter}')
        .toList()
      ..sort((a, b) => (int.tryParse(a.split(':').last) ?? 0)
          .compareTo(int.tryParse(b.split(':').last) ?? 0));
    for (final k in keys) {
      verse = int.tryParse(k.split(':').last) ?? verse;
      for (final w in byVerse[k] ?? const []) {
        words.add(PhrasingWord(
          text: w.text,
          strongs: w.strongs,
          verse: verse,
          morph: w.morph,
          translit: w.translit,
        ));
      }
    }
    final stored = await PhrasingStore.load(
        widget.version, _englishBook, widget.chapter);
    if (!mounted) return;
    final present = {for (final w in words) w.verse}.toList()..sort();
    setState(() {
      _words = words;
      _p = stored ??
          Phrasing(
            version: widget.version,
            book: _englishBook,
            chapter: widget.chapter,
            startVerse: present.contains(widget.verse)
                ? widget.verse
                : (present.isEmpty ? 1 : present.first),
            endVerse: present.contains(widget.verse)
                ? widget.verse
                : (present.isEmpty ? 1 : present.first),
          );
      _loading = false;
    });
  }

  void _update(Phrasing next) {
    setState(() => _p = next);
    PhrasingStore.save(next);
  }

  String _s(String k, String fallback) =>
      uiStrings[k]?[widget.locale] ?? fallback;

  bool get _rtl => _words.any((w) => w.strongs.startsWith('H'));

  void _copy() {
    final p = _p;
    if (p == null) return;
    final text = exportPhrasing(
      p,
      _words,
      label: (r) => phrasingRelationLabel(r, widget.locale),
      verseMark: (v) => '$v',
    );
    final head = '${localeAwareBookName(widget.book, widget.locale, widget.version)} '
        '${widget.chapter}:${p.startVerse}-${p.endVerse}';
    Clipboard.setData(ClipboardData(text: '$head\n$text'));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_s('phrasingCopied', 'Copied')),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = _p;

    return Scaffold(
      appBar: AppBar(
        title: Text(_s('phrasingTitle', 'Phrasing')),
        actions: [
          IconButton(
            tooltip: _s('phrasingReset', 'Start over'),
            icon: const Icon(Icons.restart_alt),
            onPressed:
                p == null || !p.isTouched ? null : () => _update(resetPhrasing(p)),
          ),
          IconButton(
            tooltip: _s('kwicCopy', 'Copy all'),
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: _words.isEmpty ? null : _copy,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (p == null || _words.isEmpty)
              ? _empty(scheme)
              : Column(
                  children: [
                    _controls(p, scheme),
                    const Divider(height: 1),
                    Expanded(child: _diagram(p, scheme)),
                    const Divider(height: 1),
                    _footer(scheme),
                  ],
                ),
    );
  }

  Widget _empty(ColorScheme scheme) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _s('phrasingNone',
                'No original-language text is bundled for this chapter, so '
                    'there is nothing to phrase.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.outline),
          ),
        ),
      );

  // ── Controls ──────────────────────────────────────────────────────

  Widget _controls(Phrasing p, ColorScheme scheme) {
    final verses = _verseNumbers;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final e in const [
                (PhrasingLevel.verses, 'phrasingLevelVerses', 'Verses'),
                (PhrasingLevel.clauses, 'phrasingLevelClauses', 'Clauses'),
                (PhrasingLevel.verbals, 'phrasingLevelVerbals', '+ Verbals'),
                (PhrasingLevel.phrases, 'phrasingLevelPhrases', '+ Phrases'),
              ])
                ChoiceChip(
                  label: Text(_s(e.$2, e.$3)),
                  selected: p.level == e.$1,
                  onSelected: (_) => _update(setPhrasingLevel(p, e.$1)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(_s('phrasingRange', 'Verses'),
                  style: TextStyle(fontSize: 13, color: scheme.outline)),
              const SizedBox(width: 8),
              _verseDrop(verses, p.startVerse, (v) {
                _update(p.copyWith(
                  startVerse: v,
                  endVerse: v > p.endVerse ? v : p.endVerse,
                ));
              }),
              Text(' – ', style: TextStyle(color: scheme.outline)),
              _verseDrop(verses, p.endVerse, (v) {
                _update(p.copyWith(
                  endVerse: v,
                  startVerse: v < p.startVerse ? v : p.startVerse,
                ));
              }),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _s(
              'phrasingHint',
              'Tap a word to start a new line before it; tap the first word '
                  'of a line to join it back up. Use ◀ ▶ to indent — an '
                  'indented line is subordinate to the line above it.',
            ),
            style: TextStyle(fontSize: 12, color: scheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _verseDrop(List<int> verses, int value, ValueChanged<int> onChanged) =>
      DropdownButton<int>(
        value: verses.contains(value) ? value : (verses.isEmpty ? null : verses.first),
        isDense: true,
        underline: const SizedBox.shrink(),
        items: [
          for (final v in verses)
            DropdownMenuItem<int>(value: v, child: Text('$v')),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      );

  // ── The diagram ───────────────────────────────────────────────────

  Widget _diagram(Phrasing p, ColorScheme scheme) {
    final all = layoutPhrasing(p, _words);
    final lines =
        visiblePhrasingLines(all, _words, p.startVerse, p.endVerse);
    if (lines.isEmpty) {
      return Center(
        child: Text(_s('phrasingEmptyWindow', 'No verses in this range.'),
            style: TextStyle(color: scheme.outline)),
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
      itemCount: lines.length,
      itemBuilder: (context, i) => _lineRow(p, lines[i], scheme),
    );
  }

  Widget _lineRow(Phrasing p, PhrasingLine line, ColorScheme scheme) {
    final row = Padding(
      padding: EdgeInsetsDirectional.only(
        start: 8.0 + line.depth * 28.0,
        top: 3,
        bottom: 3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _depthButton(Icons.chevron_left, line.depth == 0,
              () => _update(outdentPhrasingLine(p, _words, line.start))),
          _depthButton(Icons.chevron_right, false,
              () => _update(indentPhrasingLine(p, _words, line.start))),
          const SizedBox(width: 4),
          _relationChip(p, line, scheme),
          const SizedBox(width: 6),
          Expanded(child: _words_(line, scheme)),
        ],
      ),
    );
    // Hebrew reads right to left, and indentation is a flow direction
    // rather than a symbol, so the whole structure mirrors for free —
    // this is the single biggest reason a text model beat a canvas.
    return _rtl
        ? Directionality(textDirection: TextDirection.rtl, child: row)
        : row;
  }

  Widget _depthButton(IconData icon, bool disabled, VoidCallback onTap) =>
      SizedBox(
        width: 24,
        height: 24,
        child: IconButton(
          padding: EdgeInsets.zero,
          iconSize: 16,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon),
          onPressed: disabled ? null : onTap,
        ),
      );

  Widget _relationChip(Phrasing p, PhrasingLine line, ColorScheme scheme) {
    final chosen = line.relation;
    final suggested = line.suggested;
    if (chosen == null && suggested == null) {
      return _chipShell(
        onTap: () => _pickRelation(p, line),
        border: scheme.outlineVariant,
        child: Icon(Icons.add, size: 12, color: scheme.outline),
      );
    }
    final label = phrasingRelationLabel((chosen ?? suggested)!, widget.locale);
    // A SUGGESTION MUST NOT LOOK LIKE A DECISION. The grammar's guess is
    // drawn muted and italic with no fill; the reader's own choice is
    // filled and upright. If those two read the same, a reader cannot
    // tell which labels in their own diagram they actually chose, and
    // the whole analysis becomes untrustworthy at exactly the point it
    // is supposed to be their work.
    return _chipShell(
      onTap: () => _pickRelation(p, line),
      border: chosen != null ? scheme.primary : scheme.outlineVariant,
      fill: chosen != null ? scheme.primaryContainer : null,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontStyle: chosen != null ? FontStyle.normal : FontStyle.italic,
          color: chosen != null
              ? scheme.onPrimaryContainer
              : scheme.outline,
        ),
      ),
    );
  }

  Widget _chipShell({
    required VoidCallback onTap,
    required Color border,
    Color? fill,
    required Widget child,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minWidth: 22),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(widthFactor: 1, child: child),
        ),
      );

  Future<void> _pickRelation(Phrasing p, PhrasingLine line) async {
    final suggestions = line.start < _words.length
        ? suggestRelations(_words[line.start])
        : const <PhrasingRelation>[];
    final rest = [
      for (final r in PhrasingRelation.values)
        if (!suggestions.contains(r)) r,
    ];
    final picked = await showModalBottomSheet<Object>(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                dense: true,
                leading: const Icon(Icons.clear, size: 18),
                title: Text(_s('phrasingRelNone', 'No label')),
                onTap: () => Navigator.pop(context, 'none'),
              ),
              if (suggestions.isNotEmpty) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      _s('phrasingSuggested', 'Suggested by the grammar'),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                for (final r in suggestions)
                  ListTile(
                    dense: true,
                    title: Text(phrasingRelationLabel(r, widget.locale)),
                    onTap: () => Navigator.pop(context, r),
                  ),
              ],
              const Divider(height: 1),
              for (final r in rest)
                ListTile(
                  dense: true,
                  title: Text(phrasingRelationLabel(r, widget.locale)),
                  onTap: () => Navigator.pop(context, r),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    _update(setPhrasingRelation(
      p,
      line.start,
      picked is PhrasingRelation ? picked : null,
    ));
  }

  Widget _words_(PhrasingLine line, ColorScheme scheme) {
    final spans = <Widget>[];
    var lastVerse = line.start > 0 ? _words[line.start - 1].verse : -1;
    for (var i = line.start; i < line.end && i < _words.length; i++) {
      final w = _words[i];
      if (w.verse != lastVerse) {
        spans.add(Padding(
          padding: const EdgeInsetsDirectional.only(end: 3),
          child: Text('${w.verse}',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary)),
        ));
        lastVerse = w.verse;
      }
      spans.add(_word(i, w, i == line.start, scheme));
    }
    return Wrap(
      spacing: 5,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: spans,
    );
  }

  Widget _word(int i, PhrasingWord w, bool isLineStart, ColorScheme scheme) {
    final hovered = _hover == i;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = i),
      onExit: (_) => setState(() => _hover = _hover == i ? null : _hover),
      child: GestureDetector(
        onTap: () {
          final p = _p;
          if (p != null) _update(togglePhrasingBreak(p, _words, i));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          decoration: BoxDecoration(
            color: hovered ? scheme.surfaceContainerHighest : null,
            borderRadius: BorderRadius.circular(3),
            // The first word of a line carries the break it stands on,
            // so the reader can see what their next tap would undo.
            border: BorderDirectional(
              start: isLineStart
                  ? BorderSide(color: scheme.primary, width: 2)
                  : BorderSide.none,
            ),
          ),
          child: Text(w.text, style: const TextStyle(fontSize: 17)),
        ),
      ),
    );
  }

  // ── Footer: the parse of whatever the pointer is on ───────────────

  Widget _footer(ColorScheme scheme) {
    final i = _hover;
    final w = (i != null && i < _words.length) ? _words[i] : null;
    final parse = w == null ? null : describeMorphology(w.morph, widget.locale);
    return Container(
      width: double.infinity,
      height: 30,
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: scheme.surfaceContainerHighest,
      child: Text(
        w == null
            ? _s('phrasingFooterIdle', 'Point at a word to parse it.')
            : [
                w.text,
                if (w.translit != null && w.translit!.isNotEmpty) w.translit!,
                if (w.strongs.isNotEmpty) w.strongs,
                if (parse != null) parse,
              ].join('  ·  '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
