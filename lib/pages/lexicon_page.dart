/// 2026-08-23 (SeekSparks): the Lexicon Browser, opened from Resources —
/// BibleWorks help topic bwh35.
///
/// **Why it exists.** We have carried 5,523 Greek and 8,674 Hebrew
/// Strong's entries since the first release, and there has only ever
/// been one door into them: tap a word in the text and
/// `strongs_entry_page.dart` shows you that word. It opens one way. You
/// must already have the word in front of you to ask what it means, and
/// there is no way at all to ask what sits either side of it, or which
/// entries talk about a covenant. bwh35 states the missing half plainly:
/// look up an entry "by typing in the word or entry, **or by scrolling
/// through a complete list of entries**", and search "on both the list
/// of entries **and on the entire text of the databases**".
///
/// **What this page is NOT.** It is not a second entry renderer. Tapping
/// a row pushes the [StrongsEntryPage] that already exists, with its
/// word family, its cross-references and its concordance. The browser is
/// the LIST; the entry is the ENTRY. One of those was missing.
///
/// **The two searches are two.** bwh35 separates them and so does this
/// page: the box filters HEADWORDS (`*ew` → every Greek word ending in
/// `ew`), the toggle beside it searches the ARTICLE TEXT. They answer
/// different questions and return different things, and blurring them
/// into one box would mean a reader could never ask the first one
/// cleanly — searching `love` would drown ἀγάπη in the four hundred
/// articles that mention love.
///
/// **Hebrew first, then Greek**, because bwh35's own Lexicons menu is in
/// that order and so is the canon.
///
/// The ordering, the collation key, the wildcard rule and both searches
/// live in `utils/lexicon_browse.dart`, pure and under test — including
/// the measurement that made this page worth building carefully: a plain
/// `sort()` of the Greek lemmas puts ἀγάπη at index 3,528 of 5,516,
/// because 36% of them begin with a precomposed polytonic codepoint that
/// sorts after the whole Greek block. This file is layout, and holds
/// `workbench_theme.dart`'s rule: square corners, 1px hairlines, no
/// shadows, no cards.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/strongs.dart';
import 'package:seeksparks/pages/strongs_entry_page.dart';
import 'package:seeksparks/services/chinese_lexicon_service.dart';
import 'package:seeksparks/services/strongs_service.dart';
import 'package:seeksparks/services/thayer_service.dart';
import 'package:seeksparks/utils/app_nav.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/lexicon_browse.dart';
import 'package:seeksparks/utils/thayer_parse.dart' show parseThayerEntry;
import 'package:seeksparks/widgets/home_icon_button.dart';
import 'package:seeksparks/widgets/language_switcher_button.dart';
import 'package:seeksparks/widgets/localized_back_button.dart';
import 'package:seeksparks/widgets/wb_surfaces.dart' show WbTag;

/// Article hits rendered at once. The header always names the true
/// total: a cap on a sorted list is a silent WHERE clause.
const int _textHitCap = 200;

/// Below this the controls stop sharing one row.
const double _controlsOneRowMin = 620;

/// Everything loaded for one lexicon, folded once.
class _Lexicon {
  _Lexicon(this.id, List<StrongsEntry> entries, String locale)
      : byNumber = {for (final e in entries) e.number: e},
        heads = sortHeads(
          [
            for (final e in entries)
              LexiconHead(
                number: e.number,
                lemma: e.lemma,
                translit: e.translit,
                gloss: e.localizedGloss(locale),
              ),
          ],
          LexiconOrder.alphabetical,
        ),
        articleLocale = locale;

  final LexiconId id;
  final Map<String, StrongsEntry> byNumber;
  final List<LexiconHead> heads;

  /// The locale the glosses and the fold cache were built for. A reader
  /// who switches language mid-browse must not go on searching the
  /// English text while reading Chinese rows.
  final String articleLocale;

  /// The longest number in this lexicon — `H8674`, `G5624`. The number
  /// column is sized from it rather than from a multiple of the font
  /// size, which is how the first draft of this page clipped every
  /// four-digit Hebrew entry: a fixed box holding text is a defect that
  /// only shows up at the widest row, and 8,674 rows in it always does.
  late final String widestNumber = heads.fold(
      '', (w, h) => h.number.length > w.length ? h.number : w);

  List<LexiconHead>? _byNumberOrder;

  /// Both orders are kept, because a build must not re-sort 8,674 rows
  /// to answer a keystroke.
  List<LexiconHead> ordered(LexiconOrder order) => order ==
          LexiconOrder.alphabetical
      ? heads
      : (_byNumberOrder ??= sortHeads(heads, LexiconOrder.number));

  Map<String, String>? _folded;

  String articleOf(String number) {
    final e = byNumber[number];
    if (e == null) return '';
    final gloss = e.localizedGloss(articleLocale);
    final def = e.localizedDefinition(articleLocale);
    return def.isEmpty ? gloss : '$gloss\n$def';
  }

  /// The whole lexicon's article text folded once — 845,000 characters
  /// for Hebrew, which is a keystroke's worth of work exactly once.
  String foldedOf(String number) {
    final cache = _folded ??= {
      for (final n in byNumber.keys) n: lexiconCollationKey(articleOf(n)),
    };
    return cache[number] ?? '';
  }
}

/// What one WORK says about the numbers in [_Lexicon]'s list.
///
/// Deliberately not a subclass of [_Lexicon]: the headword list, its
/// order, its alphabet and the widest-number measurement belong to the
/// canon and are identical whichever work is open. Only these three
/// functions change, which is why switching works costs no re-sort of
/// 8,674 rows and why the headword search returns the same entries
/// either way — the same word, described by a different lexicographer.
class _Articles {
  _Articles({
    required this.id,
    required this.source,
    required this.locale,
    required this.summaryOf,
    required this.articleOf,
  });

  final LexiconId id;
  final LexiconSource source;
  final String locale;

  /// The row's single line.
  final String Function(String number) summaryOf;

  /// Everything the article search reads.
  final String Function(String number) articleOf;

  final Map<String, String> _fold = {};

  /// Folded on first ask and kept. A keystroke must not re-fold a
  /// megabyte of Thayer.
  String foldedOf(String number) =>
      _fold[number] ??= lexiconCollationKey(articleOf(number));
}

class LexiconPage extends StatefulWidget {
  const LexiconPage({super.key, this.initial = LexiconId.hebrew});

  final LexiconId initial;

  @override
  State<LexiconPage> createState() => _LexiconPageState();
}

class _LexiconPageState extends State<LexiconPage> {
  final TextEditingController _search = TextEditingController();
  final ScrollController _listScroll = ScrollController();

  late LexiconId _id = widget.initial;
  final Map<LexiconId, _Lexicon> _loaded = {};
  bool _loading = false;

  String _query = '';
  LexiconOrder _order = LexiconOrder.alphabetical;
  bool _textTier = false;

  /// The work the reader picked. What they actually get is
  /// [_effectiveSource], which differs only for Thayer under Hebrew.
  LexiconSource _source = LexiconSource.strongs;
  final Map<String, _Articles> _articles = {};
  bool _loadingArticles = false;

  /// Thayer has no Hebrew side, so under Hebrew the reader reads
  /// Strong's. The substitution is announced in the count header rather
  /// than made quietly: a page that answers from a different book than
  /// the one named is the same defect as a count that will not say what
  /// it counted.
  LexiconSource get _effectiveSource =>
      _source.covers(_id) ? _source : LexiconSource.strongs;

  String _articlesKey(LexiconId id, LexiconSource s, String locale) =>
      '${id.name}/${s.name}/$locale';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensure(_id));
  }

  @override
  void dispose() {
    _search.dispose();
    _listScroll.dispose();
    super.dispose();
  }

  String get _locale => context.read<AppSettings>().locale;

  String _s(String key, String fallback, String locale) =>
      uiStrings[key]?[locale] ?? fallback;

  String _sn(String key, String many, String one, int n, String locale) =>
      n == 1
          ? _s('${key}One', one, locale)
          : _s(key, many, locale).replaceAll('{n}', '$n');

  Future<void> _ensure(LexiconId id) async {
    final locale = _locale;
    final held = _loaded[id];
    if (held != null && held.articleLocale == locale) return;
    if (_loading) return;
    setState(() => _loading = true);
    final entries = await StrongsService.allEntries(id.prefix);
    if (!mounted) return;
    setState(() {
      _loaded[id] = _Lexicon(id, entries, locale);
      _loading = false;
    });
  }

  /// Loads whichever work is showing. Strong's is already in memory once
  /// [_ensure] has run; the other two are megabyte assets and are
  /// fetched only when a reader actually asks for them.
  Future<void> _ensureArticles(
      LexiconId id, LexiconSource source, String locale) async {
    final key = _articlesKey(id, source, locale);
    if (_articles.containsKey(key) || _loadingArticles) return;
    final lex = _loaded[id];
    if (lex == null || lex.articleLocale != locale) return;
    setState(() => _loadingArticles = true);
    final built = await _buildArticles(lex, id, source, locale);
    if (!mounted) return;
    setState(() {
      _articles[key] = built;
      _loadingArticles = false;
    });
  }

  Future<_Articles> _buildArticles(
      _Lexicon lex, LexiconId id, LexiconSource source, String locale) async {
    switch (source) {
      case LexiconSource.strongs:
        return _Articles(
          id: id,
          source: source,
          locale: locale,
          summaryOf: (n) => lex.byNumber[n]?.localizedGloss(locale) ?? '',
          articleOf: lex.articleOf,
        );

      case LexiconSource.thayer:
        final raw = await ThayerService.rawArticles();
        // Parsed one row at a time and kept. Turning all 5,799 into
        // structures up front is exactly what `ThayerService` refuses to
        // do at boot, and a list only ever draws the rows on screen.
        final summaries = <String, String>{};
        return _Articles(
          id: id,
          source: source,
          locale: locale,
          articleOf: (n) => raw[ThayerService.canonicalKey(n)] ?? '',
          summaryOf: (n) => summaries[n] ??= _thayerSummary(raw, n),
        );

      case LexiconSource.chinese:
        final table = await ChineseLexiconService.allEntries(id.prefix);
        return _Articles(
          id: id,
          source: source,
          locale: locale,
          // Etymology and the 钦定本 counts are part of the article a
          // printed lexicon prints, so they are part of what "search the
          // article text" searches.
          articleOf: (n) {
            final e = table[n];
            if (e == null) return '';
            return [e.etymology, e.usage, ...e.senses]
                .where((s) => s.trim().isNotEmpty)
                .join('\n');
          },
          summaryOf: (n) => firstSenseSummary(table[n]?.senses ?? const []),
        );
    }
  }

  String _thayerSummary(Map<String, String> raw, String number) {
    final article = raw[ThayerService.canonicalKey(number)];
    if (article == null || article.trim().isEmpty) return '';
    final entry = parseThayerEntry(number, article);
    if (entry.isNotUsed) return '';
    for (final s in entry.senses) {
      if (s.text.trim().isNotEmpty) return s.text.trim();
    }
    return '';
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    final c = WbColors.of(context);
    final lex = _loaded[_id];

    // The rows are glossed in the reader's language, so a switch has to
    // rebuild them. Cheap and rare; the alternative is a Chinese page
    // that searches English.
    if (lex != null && lex.articleLocale != locale && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loaded.remove(_id);
        _ensure(_id);
      });
    }

    return Scaffold(
      backgroundColor: c.paneBg,
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(_s('lexiconBrowserTitle', 'Lexicon Browser', locale)),
        actions: const [LanguageSwitcherButton(), HomeIconButton()],
      ),
      body: lex == null || lex.articleLocale != locale
          ? const Center(child: CircularProgressIndicator())
          : lex.heads.isEmpty
              ? _message(
                  c,
                  _s('lexiconUnavailable',
                      'The lexicons are not bundled in this build.', locale))
              : _browser(c, lex, locale),
    );
  }

  Widget _browser(WbColors c, _Lexicon lex, String locale) {
    final source = _effectiveSource;
    final art = _articles[_articlesKey(_id, source, locale)];
    if (art == null) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _ensureArticles(_id, source, locale));
    }

    final searching = _query.trim().isNotEmpty;
    final heads = lex.ordered(_order);
    final hits = searching ? matchHeadwords(heads, _query) : heads;
    // The article tier reads the WORK, so it waits for the work. The
    // headword tier never does: the list of words exists before any
    // lexicographer describes them.
    final text = (_textTier && searching && art != null)
        ? searchDefinitions(
            heads,
            _query,
            textOf: art.articleOf,
            foldedTextOf: art.foldedOf,
            limit: _textHitCap,
          )
        : null;

    return LayoutBuilder(
      builder: (context, box) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _controls(c, locale, oneRow: box.maxWidth >= _controlsOneRowMin),
          _countHeader(
            c,
            // The work is named on every count. Three lexicons over one
            // headword list means "5,523 entries" alone no longer says
            // whose 5,523 they are, and a reader quoting a definition
            // needs to know which lexicographer wrote it.
            '${searching
                // Named, not "found": this tier matched the headword, and
                // the article tier below it did something else.
                ? _sn('lexiconEntriesNamed', '{n} entries named',
                    '1 entry named', hits.length, locale)
                : _s('lexiconEntriesAll', '{n} entries', locale)
                    .replaceAll('{n}', '${heads.length}')}'
            ' · ${_sourceName(source, locale)}',
            // bwh35's Reload, by its effect: the entry list is REPLACED
            // by results, so something has to put it back.
            note: searching ? _s('lexiconShowAll', 'Show all', locale) : null,
            onNote: searching ? _clear : null,
          ),
          _sourceNote(c, locale),
          if (!searching && _order == LexiconOrder.alphabetical)
            _letterStrip(c, heads),
          Divider(height: WbMetrics.hairline, color: c.border),
          Expanded(child: _list(
              context, c, lex, art, hits, text, locale, searching)),
        ],
      ),
    );
  }

  void _clear() {
    _search.clear();
    setState(() {
      _query = '';
      _textTier = false;
    });
  }

  Widget _controls(WbColors c, String locale, {required bool oneRow}) {
    final t = WbType.of(context);
    final field = _searchField(c, t, locale);
    // Both pairs are pairs and not toggles. A single button whose label
    // is the CURRENT state cannot say whether tapping it means "you are
    // in alphabetical order" or "put me in alphabetical order", and the
    // reader finds out by losing her place in 8,674 rows.
    final buttons = Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final id in LexiconId.values)
          _flatButton(
            c,
            t,
            label: id == LexiconId.hebrew
                ? _s('lexiconHebrew', 'Hebrew', locale)
                : _s('lexiconGreek', 'Greek', locale),
            active: _id == id,
            onTap: () {
              if (_id == id) return;
              setState(() => _id = id);
              _ensure(id);
              if (_listScroll.hasClients) _listScroll.jumpTo(0);
            },
          ),
        for (final s in LexiconSource.values)
          _flatButton(
            c,
            t,
            label: _sourceName(s, locale),
            // The lit button says what is on screen, not what was last
            // asked for: under Hebrew a chosen Thayer is not being read,
            // and lighting it there would caption the page with a work
            // that wrote none of it.
            active: _effectiveSource == s,
            // Thayer under Hebrew is offered and refused, not hidden.
            // Removing the button would leave a reader who knows the
            // work exists unable to tell whether we lack it or it lacks
            // Hebrew, and those are different answers.
            enabled: s.covers(_id),
            onTap: () {
              if (_source == s) return;
              setState(() => _source = s);
              _ensureArticles(_id, s, locale);
            },
          ),
        for (final order in LexiconOrder.values)
          _flatButton(
            c,
            t,
            icon: order == LexiconOrder.alphabetical
                ? Icons.sort_by_alpha
                : Icons.tag,
            label: order == LexiconOrder.alphabetical
                ? _s('lexiconOrderAlpha', 'alphabetical', locale)
                : _s('lexiconOrderNumber', "Strong's order", locale),
            active: _order == order,
            onTap: () => setState(() => _order = order),
          ),
        _flatButton(
          c,
          t,
          icon: Icons.subject,
          label: _s('lexiconSearchText', 'Search article text', locale),
          active: _textTier,
          onTap: () => setState(() => _textTier = !_textTier),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: oneRow
          ? Row(children: [
              Expanded(child: field),
              const SizedBox(width: 6),
              Flexible(child: buttons),
            ])
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field,
                const SizedBox(height: 6),
                buttons,
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
          hintText: _s('lexiconSearchHint',
              'Word, romanisation or number — * for wildcards', locale),
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
                  onPressed: _clear,
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

  /// A query that names no headword turns the article tier on by itself.
  /// Making a reader discover a button in order not to be shown a blank
  /// page is the defect, not the cure — and here the blank page is the
  /// likely one: `covenant` is nobody's headword.
  void _onQuery(String v) {
    final lex = _loaded[_id];
    final empty = lex != null &&
        v.trim().length >= 2 &&
        matchHeadwords(lex.heads, v).isEmpty;
    setState(() {
      _query = v;
      if (empty) _textTier = true;
    });
  }

  /// The alphabet of whichever script is open, derived from the data.
  Widget _letterStrip(WbColors c, List<LexiconHead> heads) {
    final t = WbType.of(context);
    final letters = alphabetOf(heads);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: Wrap(
        spacing: 3,
        runSpacing: 3,
        children: [
          for (final letter in letters)
            _flatButton(
              c,
              t,
              label: letter,
              active: false,
              onTap: () => _jumpTo(heads, letter, t),
            ),
        ],
      ),
    );
  }

  void _jumpTo(List<LexiconHead> heads, String letter, WbType t) {
    final i = heads.indexWhere((h) => h.initial == letter);
    if (i < 0 || !_listScroll.hasClients) return;
    _listScroll.jumpTo(
      (i * _rowExtent(t)).clamp(0.0, _listScroll.position.maxScrollExtent),
    );
  }

  double _rowExtent(WbType t) => t.text * 2.2 + 14;

  // ── The list ────────────────────────────────────────────────────────

  Widget _list(
    BuildContext rowContext,
    WbColors c,
    _Lexicon lex,
    _Articles? art,
    List<LexiconHead> hits,
    LexiconTextResult? text,
    String locale,
    bool searching,
  ) {
    final t = WbType.of(context);
    final numWidth = _numberColumnWidth(rowContext, t, lex.widestNumber);
    if (!searching) {
      return ListView.builder(
        controller: _listScroll,
        itemCount: hits.length,
        itemExtent: _rowExtent(t),
        itemBuilder: (context, i) => _row(c, t, hits[i], art, numWidth),
      );
    }
    if (hits.isEmpty && text == null) {
      return _message(
        c,
        _s('lexiconNoHeadword', 'No entry is spelled “{q}”.', locale)
            .replaceAll('{q}', _query.trim()),
      );
    }
    return CustomScrollView(
      controller: _listScroll,
      slivers: [
        SliverFixedExtentList(
          itemExtent: _rowExtent(t),
          delegate: SliverChildBuilderDelegate(
            (context, i) => _row(c, t, hits[i], art, numWidth),
            childCount: hits.length,
          ),
        ),
        if (text != null) ...[
          SliverToBoxAdapter(
            child: _countHeader(
              c,
              _sn('lexiconArticleHits', '{n} articles mention it',
                  '1 article mentions it', text.total, locale),
              // The total above is the whole answer; this says how much
              // of it is on screen. 200 rows out of 1,400 printed as
              // "200" is a lie the reader cannot see.
              note: text.truncated
                  ? _s('lexiconShowingFirst', 'first {n} shown', locale)
                      .replaceAll('{n}', '${text.hits.length}')
                  : null,
            ),
          ),
          if (text.total == 0)
            SliverToBoxAdapter(
              child: _message(
                c,
                _s(
                  'lexiconNothingAnywhere',
                  'No entry is spelled “{q}”, and no article mentions it.',
                  locale,
                ).replaceAll('{q}', _query.trim()),
              ),
            ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _articleRow(c, t, lex, text.hits[i], locale),
              childCount: text.hits.length,
            ),
          ),
        ],
      ],
    );
  }

  void _open(String number) =>
      pushPage(StrongsEntryPage(number: number), preventDuplicates: false);

  /// The number column, measured rather than guessed.
  ///
  /// `WbTag` adds 4px of padding and a 1px border on each side; the rest
  /// is the text itself, laid out in the tag's own style. One layout per
  /// build, against the widest string the column will ever hold.
  ///
  /// The style is merged onto the ambient [DefaultTextStyle] and scaled
  /// by the ambient [TextScaler], because that is what the `Text` inside
  /// the tag will do — and [ctx] must be a context from INSIDE the
  /// `Scaffold`, not the State's own. That distinction is the whole bug
  /// this method was rewritten for: the State's context sits *above* the
  /// Scaffold, where `bodyMedium`'s 0.25 px letter-spacing is not yet in
  /// scope, so the measurement came back 1.25 px short over five
  /// characters and every Greek row clipped.
  double _numberColumnWidth(BuildContext ctx, WbType t, String widest) {
    final tp = TextPainter(
      text: TextSpan(
        text: widest,
        style: DefaultTextStyle.of(ctx).style.merge(TextStyle(
              fontFamily: t.fontFamily,
              fontSize: t.chrome,
              height: 1.0,
              fontWeight: FontWeight.w700,
            )),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(ctx),
    )..layout();
    return tp.width.ceilToDouble() + 10;
  }

  Widget _row(
      WbColors c, WbType t, LexiconHead h, _Articles? art, double numWidth) {
    final settings = context.read<AppSettings>();
    // Null only in the frame before the chosen work has loaded; the
    // canonical gloss is what the row held a moment ago, so it does not
    // flash empty on the way in.
    final summary = art?.summaryOf(h.number) ?? h.gloss;
    final silent = summary.trim().isEmpty;
    return InkWell(
      onTap: () => _open(h.number),
      hoverColor: c.hoverBg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: numWidth,
              child: WbTag(text: h.number, color: c.mutedText),
            ),
            const SizedBox(width: 6),
            // The lemma keeps its own direction. A Hebrew headword laid
            // out left-to-right is not the word, it is the word backwards.
            Directionality(
              textDirection:
                  h.isHebrew ? TextDirection.rtl : TextDirection.ltr,
              child: Text(
                h.lemma,
                style: TextStyle(
                  fontFamily: settings.fontFamily,
                  fontFamilyFallback: kCjkFontFallback,
                  fontSize: t.text + 1,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                silent
                    ? _s('lexiconWorkSilent', 'no definition in this work',
                        settings.locale)
                    : summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: t.chrome,
                  // Italic so a reader scanning the column can see at a
                  // glance that this is our sentence about the lexicon,
                  // not the lexicon's sentence about the word.
                  fontStyle: silent ? FontStyle.italic : null,
                  color: c.mutedText,
                  fontFamilyFallback: kCjkFontFallback,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _articleRow(WbColors c, WbType t, _Lexicon lex, LexiconTextHit hit,
      String locale) {
    final settings = context.read<AppSettings>();
    final entry = lex.byNumber[hit.number];
    return InkWell(
      onTap: () => _open(hit.number),
      hoverColor: c.hoverBg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                WbTag(text: hit.number, color: c.mutedText),
                const SizedBox(width: 6),
                if (entry != null)
                  Directionality(
                    textDirection: hit.number.startsWith('H')
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    child: Text(
                      entry.lemma,
                      style: TextStyle(
                        fontFamily: settings.fontFamily,
                        fontFamilyFallback: kCjkFontFallback,
                        fontSize: t.text,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                  ),
              ],
            ),
            Text(
              hit.excerpt,
              style: TextStyle(
                fontSize: t.chrome,
                color: c.text,
                height: 1.35,
                fontFamilyFallback: kCjkFontFallback,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Chrome ──────────────────────────────────────────────────────────

  Widget _countHeader(WbColors c, String text,
      {String? note, VoidCallback? onNote}) {
    final t = WbType.of(context);
    final noteText = note == null
        ? null
        : Text(
            note,
            style: TextStyle(
              fontSize: t.chrome,
              color: onNote == null ? c.mutedText : c.text,
              decoration: onNote == null ? null : TextDecoration.underline,
              fontFamilyFallback: kCjkFontFallback,
            ),
          );
    return Container(
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
          if (noteText != null)
            onNote == null
                ? noteText
                : InkWell(onTap: onNote, child: noteText),
        ],
      ),
    );
  }

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

  Widget _flatButton(
    WbColors c,
    WbType t, {
    required String label,
    required bool active,
    required VoidCallback onTap,
    IconData? icon,
    bool enabled = true,
  }) =>
      Material(
        color: active ? c.selectionBg : c.paneBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(
            color: active
                ? c.text
                : enabled
                    ? c.border
                    : c.border.withValues(alpha: 0.5),
            width: WbMetrics.hairline,
          ),
        ),
        child: InkWell(
          onTap: enabled ? onTap : null,
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
                      color: active
                          ? c.text
                          : enabled
                              ? c.mutedText
                              : c.mutedText.withValues(alpha: 0.5),
                      fontFamilyFallback: kCjkFontFallback,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  /// What to call the work on screen.
  ///
  /// The Chinese module is BDB on the Hebrew side and Thayer on the
  /// Greek side — one file per side, two different lexicographers — so
  /// it is named for whichever one the reader is actually in. Calling it
  /// "Thayer" over a Hebrew list would credit the wrong scholar.
  String _sourceName(LexiconSource source, String locale) {
    switch (source) {
      case LexiconSource.strongs:
        return _s('lexiconSourceStrongs', "Strong's", locale);
      case LexiconSource.thayer:
        return _s('lexiconSourceThayer', "Thayer's", locale);
      case LexiconSource.chinese:
        return _id == LexiconId.hebrew
            ? _s('lexiconSourceBdbZh', 'BDB 中文', locale)
            : _s('lexiconSourceThayerZh', 'Thayer 中文', locale);
    }
  }

  /// The line under the count that says what the reader is NOT getting.
  ///
  /// Both cases are substitutions the reader did not ask for, and a
  /// substitution nobody announces is indistinguishable from a bug.
  Widget _sourceNote(WbColors c, String locale) {
    final String? note;
    if (_source != _effectiveSource) {
      note = _s(
        'lexiconThayerGreekOnly',
        "Thayer's is a New Testament lexicon and has no Hebrew side. "
            "Showing Strong's.",
        locale,
      );
    } else if (_effectiveSource == LexiconSource.chinese &&
        ChineseLexiconService.isSimplifiedOnly(locale)) {
      note = _s('lexiconChineseSimplifiedOnly',
          '這部詞典只有簡體，未經轉換。', locale);
    } else {
      note = null;
    }
    if (note == null) return const SizedBox.shrink();
    final t = WbType.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      child: Text(
        note,
        style: TextStyle(
          fontSize: t.chrome,
          color: c.mutedText,
          fontFamilyFallback: kCjkFontFallback,
        ),
      ),
    );
  }
}
