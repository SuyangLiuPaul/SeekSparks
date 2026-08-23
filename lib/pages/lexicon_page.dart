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
import 'package:seeksparks/services/strongs_service.dart';
import 'package:seeksparks/utils/app_nav.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/lexicon_browse.dart';
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
    final searching = _query.trim().isNotEmpty;
    final heads = lex.ordered(_order);
    final hits = searching ? matchHeadwords(heads, _query) : heads;
    final text = (_textTier && searching)
        ? searchDefinitions(
            heads,
            _query,
            textOf: lex.articleOf,
            foldedTextOf: lex.foldedOf,
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
            searching
                // Named, not "found": this tier matched the headword, and
                // the article tier below it did something else.
                ? _sn('lexiconEntriesNamed', '{n} entries named',
                    '1 entry named', hits.length, locale)
                : _s('lexiconEntriesAll', '{n} entries', locale)
                    .replaceAll('{n}', '${heads.length}'),
            // bwh35's Reload, by its effect: the entry list is REPLACED
            // by results, so something has to put it back.
            note: searching ? _s('lexiconShowAll', 'Show all', locale) : null,
            onNote: searching ? _clear : null,
          ),
          if (!searching && _order == LexiconOrder.alphabetical)
            _letterStrip(c, heads),
          Divider(height: WbMetrics.hairline, color: c.border),
          Expanded(
              child: _list(context, c, lex, hits, text, locale, searching)),
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
        itemBuilder: (context, i) => _row(c, t, hits[i], numWidth),
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
            (context, i) => _row(c, t, hits[i], numWidth),
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

  Widget _row(WbColors c, WbType t, LexiconHead h, double numWidth) {
    final settings = context.read<AppSettings>();
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
                h.gloss,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: t.chrome,
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
