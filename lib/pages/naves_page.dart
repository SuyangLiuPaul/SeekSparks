/// 2026-08-19 (SeekSparks): Nave's Topical Bible, opened from Resources.
///
/// **Why it exists.** `assets/nave/` has held all 5,322 topics, 29,379
/// lines and 77,974 references since v1.6.149, and there was exactly one
/// door into them: sit on a verse and read the Topics tab. That answers
/// "what is THIS verse about" and nothing else. A reader who wants to
/// know what Nave filed under REPENTANCE has to guess a verse that might
/// be under it first — which is the same shape of defect the
/// Illustrations archive had, and the same one bwh07 files under
/// Resources: a database you CONSULT needs a door of its own.
///
/// **Why it is shaped like this.** Three measurements, taken before any
/// widget was written:
///
/// 1. JESUS, THE CHRIST is 801 lines and 3,828 references. Printed flat
///    it is not a page, it is a wall. Its depth-1 skeleton is 87 lines,
///    and the MEDIAN topic's depth-1 count is 2 — so one rule serves
///    both ends: render the top level, collapse each subtree, and say
///    how many lines are inside it. No size threshold, no special case
///    for the big entry.
/// 2. QUOTATIONS AND ALLUSIONS is a single line carrying 642 references,
///    and 113 lines carry more than 80. A line prints its first
///    [_refChipCap] and then offers the rest BY NUMBER. Nothing is
///    dropped silently; a cap on a sorted list is a WHERE clause and the
///    reader is told its size.
/// 3. The headwords are an 1896 vocabulary and a reader's is not:
///    "worry" and "depression" match zero of them. The entry text is a
///    different index — "divorce" is 2 headwords but 37 lines — so there
///    are two tiers: headwords, instant off the 90 KB index, and entry
///    text, which pulls one 790 KB file, and pulls it BY ITSELF when the
///    headword tier came back empty, because that is exactly the moment
///    a reader would otherwise be shown a blank page.
///    The second tier is not a cure and this page does not pretend it
///    is: "depression" is zero in the lines as well, and that case gets
///    a sentence saying so rather than an empty list.
///
/// **History is not a nicety here.** Nave's cross-references are the
/// work: 4,365 "See ALSO" links, and following them is the research act.
/// Back/forward keeps that trail, so a reader can wander out to
/// PRIESTHOOD and come home to AARON.
///
/// The ordering, matching and outline collapsing are in
/// `utils/naves_browse.dart`, pure and under test. This file is layout,
/// and holds `workbench_theme.dart`'s rule: square corners, 1px
/// hairlines, no shadows, no cards.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/naves_service.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/jump_to_reference.dart';
import 'package:seeksparks/utils/naves_browse.dart';
import 'package:seeksparks/utils/navigate_to_reader.dart';
import 'package:seeksparks/utils/reference_parser.dart' show BibleReference;
import 'package:seeksparks/widgets/home_icon_button.dart';
import 'package:seeksparks/widgets/language_switcher_button.dart';
import 'package:seeksparks/widgets/localized_back_button.dart';
import 'package:seeksparks/widgets/wb_surfaces.dart' show WbTag;

/// References printed on one line before the rest are offered by count.
const int _refChipCap = 24;

/// Entry-text hits rendered at once. 29,379 lines mean a two-letter
/// query can match thousands; the header always names the true total.
const int _textHitCap = 200;

/// Below this the search field stops sharing a row with the tier button.
const double _controlsOneRowMin = 560;

class NavesPage extends StatefulWidget {
  const NavesPage({super.key, this.initialTopicId, this.initialLine});

  /// Opened on a topic rather than on the index.
  ///
  /// The Topics pane in the Analysis window already knows the topic id
  /// behind every citation it prints, so handing a reader straight
  /// through to the full entry is the obvious next step — it is NOT
  /// wired yet, and nothing in the app passes this today.
  final int? initialTopicId;

  /// The line within [initialTopicId] to open to and mark. Its ancestors
  /// are expanded so it is on screen, not folded away.
  final int? initialLine;

  @override
  State<NavesPage> createState() => _NavesPageState();
}

class _NavesPageState extends State<NavesPage> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _indexScroll = ScrollController();

  List<String>? _heads;
  String _query = '';

  /// The trail through the see-also graph. `_cursor` of -1 is the index.
  final List<int> _stack = <int>[];
  int _cursor = -1;

  NaveTopic? _topic;
  bool _topicLoading = false;
  Set<int> _expanded = <int>{};
  final Set<int> _allRefs = <int>{};
  int? _focusLine;

  Map<int, List<String>>? _lineTexts;
  bool _textLoading = false;
  bool _textTier = false;

  int? get _topicId =>
      _cursor >= 0 && _cursor < _stack.length ? _stack[_cursor] : null;

  @override
  void initState() {
    super.initState();
    NavesService.heads().then((h) {
      if (!mounted) return;
      setState(() => _heads = h);
      final id = widget.initialTopicId;
      if (id != null) _open(id, focusLine: widget.initialLine);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _indexScroll.dispose();
    super.dispose();
  }

  String _s(String key, String fallback, String locale) =>
      uiStrings[key]?[locale] ?? fallback;

  // English needs a singular; Chinese does not, and carries one anyway so
  // a lookup never falls through to the English form. Not a nicety: 2,413
  // of the 5,322 topics are one line long and 1,153 are one line and one
  // reference, so "1 lines · 1 references" is the commonest header here.
  String _sn(String key, String many, String one, int n, String locale) =>
      n == 1
          ? _s('${key}One', one, locale)
          : _s(key, many, locale).replaceAll('{n}', '$n');

  // ── Navigation ────────────────────────────────────────────────────

  void _open(int id, {int? focusLine}) {
    if (_cursor < _stack.length - 1) {
      _stack.removeRange(_cursor + 1, _stack.length);
    }
    _stack.add(id);
    _show(_stack.length - 1, focusLine: focusLine);
  }

  void _show(int cursor, {int? focusLine}) {
    setState(() {
      _cursor = cursor;
      _topic = null;
      _expanded = <int>{};
      _allRefs.clear();
      _focusLine = focusLine;
      _topicLoading = cursor >= 0;
    });
    final id = _topicId;
    if (id == null) return;
    NavesService.topic(id).then((t) {
      if (!mounted || _topicId != id) return;
      setState(() {
        _topic = t;
        _topicLoading = false;
        if (t != null && focusLine != null) {
          _expanded = expandedForLine(
            [for (final l in t.lines) l.depth],
            focusLine,
          );
        }
      });
    });
  }

  Future<void> _ensureLineTexts() async {
    if (_lineTexts != null || _textLoading) return;
    setState(() => _textLoading = true);
    final texts = await NavesService.lineTexts();
    if (!mounted) return;
    setState(() {
      _lineTexts = texts;
      _textLoading = false;
    });
  }

  Future<void> _openRef(NaveRef ref) async {
    final mp = context.read<MainProvider>();
    final result = await resolveAndPrepareJump(
      reference: BibleReference(
        englishBook: ref.book,
        chapter: ref.chapter,
        verseStart: ref.verse,
        verseEnd: ref.endVerse ?? ref.verse,
      ),
      mp: mp,
    );
    if (!mounted) return;
    if (!await showJumpResultSnackBar(context, result)) return;
    if (!mounted) return;
    navigateToReader(context);
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    final c = WbColors.of(context);
    final heads = _heads;

    return Scaffold(
      backgroundColor: c.paneBg,
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(_s('navesTitle', "Nave's Topical Bible", locale)),
        actions: const [LanguageSwitcherButton(), HomeIconButton()],
      ),
      body: heads == null
          ? const Center(child: CircularProgressIndicator())
          : heads.isEmpty
              ? _message(c, _s('navesUnavailable',
                  "Nave's Topical Bible is not bundled in this build.", locale))
              : _topicId == null
                  ? _indexView(context, c, heads, locale)
                  : _topicView(context, c, locale),
    );
  }

  // ── The index ─────────────────────────────────────────────────────

  Widget _indexView(
      BuildContext context, WbColors c, List<String> heads, String locale) {
    final hits = matchHeadwords(heads, _query);
    final searching = _query.trim().isNotEmpty;
    final texts = _lineTexts;
    final textResult = (_textTier && texts != null)
        ? searchLineText(texts, _query, limit: _textHitCap)
        : null;

    return LayoutBuilder(
      builder: (context, box) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _controls(c, locale, oneRow: box.maxWidth >= _controlsOneRowMin),
          _countHeader(
            c,
            searching
                ? _sn('navesTopicsMatching', '{n} topics named',
                    '1 topic named', hits.length, locale)
                : _s('navesTopicsAll', '{n} topics', locale)
                    .replaceAll('{n}', '${heads.length}'),
          ),
          if (!searching) _letterStrip(c, heads),
          Divider(height: WbMetrics.hairline, color: c.border),
          Expanded(
            child: !searching
                ? _allTopicsList(context, c, heads, locale)
                : _resultsList(context, c, heads, hits, textResult, locale),
          ),
        ],
      ),
    );
  }

  Widget _controls(WbColors c, String locale, {required bool oneRow}) {
    final t = WbType.of(context);
    final field = _searchField(c, t, locale);
    final tier = _flatButton(
      c,
      t,
      icon: Icons.subject,
      label: _s('navesSearchText', 'Search entry text', locale),
      active: _textTier,
      onTap: () {
        setState(() => _textTier = !_textTier);
        if (_textTier) _ensureLineTexts();
      },
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: oneRow
          ? Row(children: [
              Expanded(child: field),
              const SizedBox(width: 6),
              tier,
            ])
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field,
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerLeft, child: tier),
              ],
            ),
    );
  }

  Widget _searchField(WbColors c, WbType t, String locale) => TextField(
        controller: _search,
        style: TextStyle(
          fontSize: t.text,
          color: c.text,
          fontFamilyFallback: kCjkFontFallback,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: c.paneAltBg,
          hintText: _s('navesSearchHint', 'Search topics', locale),
          hintStyle: TextStyle(
            fontSize: t.text,
            color: c.mutedText,
            fontFamilyFallback: kCjkFontFallback,
          ),
          prefixIcon: Icon(Icons.search, size: t.text + 3, color: c.mutedText),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 30, minHeight: 30),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close, size: t.text + 1, color: c.mutedText),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    _search.clear();
                    setState(() {
                      _query = '';
                      _textTier = false;
                    });
                  },
                ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: c.border, width: WbMetrics.hairline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: c.border, width: WbMetrics.hairline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: c.text, width: WbMetrics.hairline),
          ),
        ),
        onChanged: _onQuery,
      );

  /// A query that matches no headword turns the second tier on by
  /// itself. Making the reader discover a button in order to not be
  /// shown a blank page is the defect, not the cure.
  void _onQuery(String v) {
    final heads = _heads ?? const <String>[];
    final empty = v.trim().length >= 2 && matchHeadwords(heads, v).isEmpty;
    setState(() {
      _query = v;
      if (empty) _textTier = true;
    });
    if (_textTier) _ensureLineTexts();
  }

  /// A–Z, showing only the letters the work actually uses.
  Widget _letterStrip(WbColors c, List<String> heads) {
    final t = WbType.of(context);
    final starts = letterStarts(heads);
    final keys = starts.keys.toList()..sort();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: Wrap(
        spacing: 3,
        runSpacing: 3,
        children: [
          for (final k in keys)
            _flatButton(
              c,
              t,
              label: k,
              active: false,
              onTap: () {
                if (!_indexScroll.hasClients) return;
                final target = starts[k]! * _rowExtent(t);
                _indexScroll.jumpTo(
                  target.clamp(0.0, _indexScroll.position.maxScrollExtent),
                );
              },
            ),
        ],
      ),
    );
  }

  double _rowExtent(WbType t) => t.text * 2.0 + 14;

  Widget _allTopicsList(
      BuildContext context, WbColors c, List<String> heads, String locale) {
    final t = WbType.of(context);
    return ListView.builder(
      controller: _indexScroll,
      itemCount: heads.length,
      itemExtent: _rowExtent(t),
      itemBuilder: (context, i) => _topicRow(c, t, heads, i, locale),
    );
  }

  Widget _resultsList(
    BuildContext context,
    WbColors c,
    List<String> heads,
    List<NaveHeadHit> hits,
    NaveTextResult? textResult,
    String locale,
  ) {
    final t = WbType.of(context);
    if (hits.isEmpty && !_textTier && !_textLoading) {
      return _message(
          c, _s('navesNoTopic', 'No topic is named “{q}”.', locale)
              .replaceAll('{q}', _query.trim()));
    }
    return CustomScrollView(
      slivers: [
        SliverFixedExtentList(
          itemExtent: _rowExtent(t),
          delegate: SliverChildBuilderDelegate(
            (context, i) => _topicRow(c, t, heads, hits[i].topicId, locale),
            childCount: hits.length,
          ),
        ),
        if (_textLoading)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _s('navesLoadingText', 'Reading the entries…', locale),
                    style: TextStyle(fontSize: t.chrome, color: c.mutedText),
                  ),
                ],
              ),
            ),
          ),
        if (textResult != null) ...[
          SliverToBoxAdapter(
            child: _sectionHeader(
              c,
              t,
              // The total, never the number shown: 200 rows out of 1,400
              // that says "200" is a lie the reader cannot see.
              _sn('navesTextHits', '{n} lines mention it',
                  '1 line mentions it', textResult.total, locale),
              note: textResult.truncated
                  ? _s('navesTextShowing', 'first {n} shown', locale)
                      .replaceAll('{n}', '${textResult.hits.length}')
                  : null,
            ),
          ),
          if (textResult.total == 0)
            SliverToBoxAdapter(
              child: _message(
                c,
                _s('navesNothingAnywhere',
                        'Nave files nothing under “{q}”, and no entry mentions it.',
                        locale)
                    .replaceAll('{q}', _query.trim()),
              ),
            ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _textHitRow(
                  c, t, heads, textResult.hits[i], locale),
              childCount: textResult.hits.length,
            ),
          ),
        ],
        SliverToBoxAdapter(child: _attribution(c, t)),
      ],
    );
  }

  Widget _topicRow(
      WbColors c, WbType t, List<String> heads, int id, String locale) {
    final refs = NavesService.refCountOf(id);
    return InkWell(
      onTap: () => _open(id),
      hoverColor: c.hoverBg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                heads[id],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: t.text, color: c.text),
              ),
            ),
            const SizedBox(width: 6),
            // 649 topics carry no references at all — they exist only to
            // send the reader somewhere else. A bare "0" would read as a
            // broken entry, so those rows say what they are.
            WbTag(
              text: refs == 0
                  ? _s('navesCrossRefOnly', 'cross-reference', locale)
                  : '$refs',
              color: c.mutedText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _textHitRow(WbColors c, WbType t, List<String> heads, NaveTextHit hit,
      String locale) {
    final text = _lineTexts?[hit.topicId]?[hit.lineIndex] ?? '';
    return InkWell(
      onTap: () => _open(hit.topicId, focusLine: hit.lineIndex),
      hoverColor: c.hoverBg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              heads[hit.topicId],
              style: TextStyle(
                fontSize: t.chrome,
                fontWeight: FontWeight.w700,
                color: c.mutedText,
                letterSpacing: 0.4,
              ),
            ),
            Text(
              text,
              style: TextStyle(fontSize: t.text, color: c.text, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  // ── One topic ─────────────────────────────────────────────────────

  Widget _topicView(BuildContext context, WbColors c, String locale) {
    final t = WbType.of(context);
    final topic = _topic;
    final id = _topicId!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _trail(c, t, locale),
        Divider(height: WbMetrics.hairline, color: c.border),
        if (topic != null)
          _countHeader(
            c,
            // Two independently pluralised counts, so they are two
            // strings joined rather than one template with two slots —
            // a single template would need four forms for the 2×2.
            '${_sn('navesLineCount', '{n} lines', '1 line', topic.lines.length, locale)}'
            ' · '
            '${_sn('navesRefCount', '{n} references', '1 reference', NavesService.refCountOf(id), locale)}',
          ),
        Expanded(
          child: _topicLoading || topic == null
              ? const Center(child: CircularProgressIndicator())
              : _outline(c, t, topic, locale),
        ),
      ],
    );
  }

  Widget _trail(WbColors c, WbType t, String locale) {
    final head = _heads?[_topicId!] ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
      child: Row(
        children: [
          _iconStep(c, t, Icons.chevron_left,
              _cursor >= 0 ? () => _show(_cursor - 1) : null),
          _iconStep(c, t, Icons.chevron_right,
              _cursor < _stack.length - 1 ? () => _show(_cursor + 1) : null),
          const SizedBox(width: 4),
          _flatButton(
            c,
            t,
            icon: Icons.list,
            label: _s('navesAllTopics', 'All topics', locale),
            active: false,
            onTap: () => _show(-1),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              head,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: t.text + 1,
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconStep(
          WbColors c, WbType t, IconData icon, VoidCallback? onTap) =>
      InkWell(
        onTap: onTap,
        hoverColor: c.hoverBg,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: t.text + 6,
            color: onTap == null ? c.border : c.text,
          ),
        ),
      );

  Widget _outline(WbColors c, WbType t, NaveTopic topic, String locale) {
    final depths = [for (final l in topic.lines) l.depth];
    final rows = outlineRows(depths, _expanded);
    return ListView.builder(
      itemCount: rows.length + 1,
      itemBuilder: (context, i) {
        if (i == rows.length) return _attribution(c, t);
        return _lineRow(c, t, topic, rows[i], locale);
      },
    );
  }

  Widget _lineRow(WbColors c, WbType t, NaveTopic topic, NaveOutlineRow row,
      String locale) {
    final line = topic.lines[row.lineIndex];
    final showAll = _allRefs.contains(row.lineIndex);
    final refs = showAll ? line.refs : line.refs.take(_refChipCap).toList();
    final hiddenRefs = line.refs.length - refs.length;
    final focused = _focusLine == row.lineIndex;

    return Container(
      color: focused ? c.selectionBg : null,
      padding: EdgeInsets.fromLTRB(6 + (row.depth - 1).clamp(0, 3) * 14.0,
          5, 10, 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (row.hasChildren)
                InkWell(
                  onTap: () => setState(() {
                    if (!_expanded.remove(row.lineIndex)) {
                      _expanded.add(row.lineIndex);
                    }
                  }),
                  hoverColor: c.hoverBg,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 3, top: 1),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          row.expanded
                              ? Icons.expand_more
                              : Icons.chevron_right,
                          size: t.text + 3,
                          color: c.mutedText,
                        ),
                        if (row.hidden > 0)
                          Text(
                            '${row.hidden}',
                            style: TextStyle(
                              fontSize: t.chrome,
                              color: c.mutedText,
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(width: t.text + 6),
              Expanded(
                child: Text(
                  line.text.isEmpty ? '—' : line.text,
                  style: TextStyle(
                    fontSize: t.text,
                    height: 1.35,
                    color: c.text,
                    fontWeight:
                        row.depth <= 1 ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
          if (refs.isNotEmpty || line.see.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: t.text + 6, top: 2),
              child: Wrap(
                spacing: 8,
                runSpacing: 3,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final ref in refs)
                    InkWell(
                      onTap: () => _openRef(ref),
                      hoverColor: c.hoverBg,
                      child: Text(
                        ref.label(locale),
                        style: TextStyle(
                          fontSize: t.chrome,
                          color: c.link,
                          fontFamilyFallback: kCjkFontFallback,
                        ),
                      ),
                    ),
                  if (hiddenRefs > 0)
                    WbTag(
                      text: _s('navesMoreRefs', '+{n} more', locale)
                          .replaceAll('{n}', '$hiddenRefs'),
                      color: c.mutedText,
                      onTap: () =>
                          setState(() => _allRefs.add(row.lineIndex)),
                    ),
                  // 1,047 of Nave's 4,365 cross-references name a target
                  // in a form that is not one of our headwords. Those
                  // still print — Nave wrote them — but they do not
                  // pretend to be tappable.
                  for (final see in line.see)
                    see.topicId == null
                        ? Text(
                            '${_s('navesSee', 'See', locale)} ${see.name}',
                            style: TextStyle(
                              fontSize: t.chrome,
                              color: c.mutedText,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        : WbTag(
                            text:
                                '${_s('navesSee', 'See', locale)} ${see.name}',
                            color: c.link,
                            icon: Icons.arrow_forward,
                            onTap: () => _open(see.topicId!),
                          ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Shared chrome ─────────────────────────────────────────────────

  Widget _countHeader(WbColors c, String text) {
    final t = WbType.of(context);
    return Container(
      width: double.infinity,
      color: c.chromeBg,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: t.chrome,
          fontWeight: FontWeight.w700,
          color: c.mutedText,
          fontFamilyFallback: kCjkFontFallback,
        ),
      ),
    );
  }

  Widget _sectionHeader(WbColors c, WbType t, String text, {String? note}) =>
      Container(
        width: double.infinity,
        color: c.chromeBg,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: t.chrome,
                  fontWeight: FontWeight.w700,
                  color: c.mutedText,
                  fontFamilyFallback: kCjkFontFallback,
                ),
              ),
            ),
            if (note != null)
              Text(
                note,
                style: TextStyle(
                  fontSize: t.chrome,
                  color: c.mutedText,
                  fontFamilyFallback: kCjkFontFallback,
                ),
              ),
          ],
        ),
      );

  Widget _message(WbColors c, String text) {
    final t = WbType.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: t.text,
            color: c.mutedText,
            height: 1.5,
            fontFamilyFallback: kCjkFontFallback,
          ),
        ),
      ),
    );
  }

  /// The permission this data ships under is conditional on naming its
  /// source, so the credit travels with the page.
  Widget _attribution(WbColors c, WbType t) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 20),
        child: Text(
          NavesService.attribution,
          style: TextStyle(
            fontSize: t.chrome,
            height: 1.35,
            color: c.mutedText,
          ),
        ),
      );

  Widget _flatButton(
    WbColors c,
    WbType t, {
    required String label,
    required bool active,
    required VoidCallback onTap,
    IconData? icon,
  }) =>
      Material(
        color: active ? c.selectionBg : c.paneBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(
            color: active ? c.text : c.border,
            width: WbMetrics.hairline,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          hoverColor: c.hoverBg,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon,
                      size: t.chrome + 1, color: active ? c.text : c.mutedText),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: t.chrome,
                      height: 1.0,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      color: active ? c.text : c.mutedText,
                      fontFamilyFallback: kCjkFontFallback,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
