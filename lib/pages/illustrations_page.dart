/// 2026-08-09 (SeekSparks): Illustrations — the picture database, opened
/// from Resources.
///
/// **Why it exists.** `assets/maps_index.json` has held 1,192 plates for
/// months — 55 bundled Bible-history maps and 1,137 public-domain
/// engravings and paintings — with trilingual titles and captions and a
/// book/chapter filing for all 66 books. None of it was in a menu. The
/// only route in was a tile that appears in the reading pane when the
/// open chapter happens to match, so a reader could use the app for a
/// year and never learn the archive was there. `mapsBrowseLibrary`
/// ("Browse all illustrations") has been sitting in `ui_strings` unused
/// the whole time: the door was designed and never hung.
///
/// bwh07 is what settles where it goes. Its Resources menu gives the
/// picture database a paragraph of its own — *"One item that deserves
/// special mention here is the option 'Bible Views' … This opens up a
/// picture database"* — and files it beside Maps and the dictionaries,
/// on the same test that put the Atlas and the Family Tree there: is
/// this a reference you CONSULT, or a tool that operates on the verse in
/// front of you? A picture archive is the first. The verse-linked half —
/// "what goes with this chapter?" — stays in the reading pane, because
/// that half genuinely does operate on the open text.
///
/// **What this has that Bible Views does not.** BibleWorks' archive is
/// photographs of the Holy Land, browsed by place, with no idea which
/// passage a picture belongs to. Every plate here is book- and
/// chapter-scoped, so the index is ordered CANONICALLY and takes the
/// #280 book scope: narrow it to Acts and it stops being a bag of
/// pictures and becomes Acts, in order. Search runs over all three
/// locales at once so 光的创造 and "Doré" find the same plate.
///
/// The ordering, filtering and counting are in
/// `utils/illustration_index.dart`, pure and under test. This file is
/// layout, and holds `workbench_theme.dart`'s rule: square corners, 1px
/// hairlines, no shadows, no cards.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/bible_map.dart';
import 'package:seeksparks/pages/map_viewer_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/map_service.dart';
import 'package:seeksparks/utils/app_nav.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/illustration_index.dart';
import 'package:seeksparks/utils/search_scope.dart'
    show limitSpecForBooks, scopeDisplayName, scopedCountLabel;
import 'package:seeksparks/utils/version_mapper.dart' show localeAwareBookName;
import 'package:seeksparks/widgets/home_icon_button.dart';
import 'package:seeksparks/widgets/illustration_image.dart';
import 'package:seeksparks/widgets/language_switcher_button.dart';
import 'package:seeksparks/widgets/localized_back_button.dart';
import 'package:seeksparks/widgets/search_scope_sheet.dart';

/// Below this the search field and the filters stop sharing a row.
///
/// A scope button that has ellipsised its own label ("摩西五经" → "摩…")
/// is worse than one on its own line, and 620 is where the label starts
/// to go.
const double _controlsOneRowMin = 620;

/// Grid tile geometry. 210 is a plate you can recognise — below about
/// 150 a Doré engraving is a grey smudge and the grid stops being a
/// picture index at all — and 196 is that plus two lines of title and
/// one of reference.
const double _tileMaxWidth = 210;
const double _tileHeight = 196;

class IllustrationsPage extends StatefulWidget {
  const IllustrationsPage({super.key});

  @override
  State<IllustrationsPage> createState() => _IllustrationsPageState();
}

class _IllustrationsPageState extends State<IllustrationsPage> {
  final TextEditingController _search = TextEditingController();

  List<BibleMap>? _all;
  String _query = '';
  final Set<String> _kinds = <String>{};
  Set<String>? _scopeBooks;

  @override
  void initState() {
    super.initState();
    MapService.loadMaps().then((all) {
      if (mounted) setState(() => _all = all);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _s(String key, String fallback, String locale) =>
      uiStrings[key]?[locale] ?? fallback;

  Future<void> _pickScope(BuildContext context, String locale) async {
    final books = _scopeBooks;
    final chosen = await showSearchScopeSheet(
      context: context,
      locale: locale,
      version: context.read<MainProvider>().currentVersion,
      activeSpec: (books == null || books.isEmpty)
          ? null
          : limitSpecForBooks(books),
      activeFallbackLabel: null,
    );
    // Null is a cancel; an EMPTY set means "no limit". Same contract the
    // Atlas and the command pane read.
    if (chosen == null || !mounted) return;
    setState(() => _scopeBooks = chosen.isEmpty ? null : chosen);
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    final version =
        context.select<MainProvider, String>((m) => m.currentVersion);
    final c = WbColors.of(context);
    final all = _all;

    return Scaffold(
      backgroundColor: c.paneBg,
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(_s('maps', 'Illustrations', locale)),
        actions: const [LanguageSwitcherButton(), HomeIconButton()],
      ),
      body: all == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, box) {
                final results = filterIllustrations(
                  all,
                  query: _query,
                  kinds: _kinds,
                  scopeBooks: _scopeBooks,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _controls(context, c, locale, version,
                        oneRow: box.maxWidth >= _controlsOneRowMin),
                    _kindChips(context, c, all, locale),
                    _countHeader(c, locale, results.length, all.length),
                    Divider(height: WbMetrics.hairline, color: c.border),
                    Expanded(
                      child: results.isEmpty
                          ? _empty(c, locale)
                          : _grid(context, c, results, locale, version),
                    ),
                  ],
                );
              },
            ),
    );
  }

  // ── Controls ──────────────────────────────────────────────────────

  Widget _controls(
    BuildContext context,
    WbColors c,
    String locale,
    String version, {
    required bool oneRow,
  }) {
    final t = WbType.of(context);
    final books = _scopeBooks;
    final scopeLabel = (books == null || books.isEmpty)
        ? _s('scopeWholeBible', 'Whole Bible', locale)
        : scopeDisplayName(spec: limitSpecForBooks(books), locale: locale,
            version: version);
    final scope = _flatButton(
      c,
      t,
      icon: Icons.filter_alt_outlined,
      label: scopeLabel,
      active: books != null && books.isNotEmpty,
      onTap: () => _pickScope(context, locale),
    );

    if (oneRow) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
        child: Row(
          children: [
            Expanded(child: _searchField(c, t, locale)),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: scope,
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _searchField(c, t, locale),
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerLeft, child: scope),
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
          hintText: _s('illustrationsSearchHint', 'Search titles and captions',
              locale),
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
                    setState(() => _query = '');
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
        onChanged: (v) => setState(() => _query = v),
      );

  /// One toggle per category present in the data.
  ///
  /// The counts are what the chip WOULD give, not what is showing: a
  /// chip reading 0 because it is merely unselected would say the
  /// category is empty.
  Widget _kindChips(
      BuildContext context, WbColors c, List<BibleMap> all, String locale) {
    final t = WbType.of(context);
    final kinds = illustrationKinds(all);
    if (kinds.length < 2) return const SizedBox.shrink();
    final counts = illustrationKindCounts(all,
        query: _query, scopeBooks: _scopeBooks);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final kind in kinds)
            _flatButton(
              c,
              t,
              label: '${_kindLabel(kind, locale)} ${counts[kind] ?? 0}',
              active: _kinds.contains(kind),
              onTap: () => setState(() {
                if (!_kinds.remove(kind)) _kinds.add(kind);
              }),
            ),
        ],
      ),
    );
  }

  String _kindLabel(String kind, String locale) {
    final key = illustrationKindLabelKey(kind);
    if (key == null) return kind;
    return _s(key, kind, locale);
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
                      size: t.chrome + 1,
                      color: active ? c.text : c.mutedText),
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

  /// bwh23's parenthesised denominator: "48 张插图" cannot say whether a
  /// filter removed anything, so the total travels with it whenever one
  /// did.
  Widget _countHeader(WbColors c, String locale, int shown, int total) {
    final t = WbType.of(context);
    return Container(
      width: double.infinity,
      color: c.chromeBg,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        _s('illustrationsCount', '{n} illustrations', locale)
            .replaceAll('{n}', scopedCountLabel(shown, total)),
        style: TextStyle(
          fontSize: t.chrome,
          fontWeight: FontWeight.w700,
          color: c.mutedText,
          fontFamilyFallback: kCjkFontFallback,
        ),
      ),
    );
  }

  Widget _empty(WbColors c, String locale) {
    final t = WbType.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          _s('illustrationsNoMatch', 'No illustration matches.', locale),
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

  // ── The grid ──────────────────────────────────────────────────────

  Widget _grid(BuildContext context, WbColors c, List<BibleMap> results,
      String locale, String version) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _tileMaxWidth,
        mainAxisExtent: _tileHeight,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: results.length,
      itemBuilder: (context, i) => _IllustrationTile(
        map: results[i],
        locale: locale,
        version: version,
        onTap: () => pushPage(MapViewerPage(
          map: results[i],
          locale: locale,
          // The strip is the result set the reader is browsing, so the
          // arrow keys walk the same list the grid showed — and the
          // title says which list that is rather than claiming they are
          // all "related".
          relatedMaps: results,
          stripTitle: _s('illustrationsCount', '{n} illustrations', locale)
              .replaceAll('{n}', '${results.length}'),
        )),
      ),
    );
  }
}

/// One plate in the grid: the picture, its title, and where it is filed.
class _IllustrationTile extends StatelessWidget {
  const _IllustrationTile({
    required this.map,
    required this.locale,
    required this.version,
    required this.onTap,
  });

  final BibleMap map;
  final String locale;
  final String version;
  final VoidCallback onTap;

  /// Where the plate is filed, in the READING VERSION's script (#283) —
  /// `创世记 1–11`, and `+2` when it is filed under more books than fit.
  String get _reference {
    final books = illustrationBooks(map);
    if (books.isEmpty) return '';
    final first = books.first;
    final span = illustrationChapterSpan(map, first);
    final name = localeAwareBookName(first, locale, version);
    final head = span.isEmpty ? name : '$name $span';
    return books.length == 1 ? head : '$head +${books.length - 1}';
  }

  @override
  Widget build(BuildContext context) {
    final c = WbColors.of(context);
    final t = WbType.of(context);
    return Material(
      color: c.paneBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: c.border, width: WbMetrics.hairline),
      ),
      child: InkWell(
        onTap: onTap,
        hoverColor: c.hoverBg,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: c.paneAltBg,
                child: IllustrationImage(
                  map: map,
                  thumb: true,
                  fit: BoxFit.cover,
                  // 220, not the tile's 2x device width. The 55 bundled
                  // maps are survey plates of 1–2.4 MB (29 MB for the
                  // set), and a grid filtered to them puts ~28 on screen
                  // at once: decoding those at 420 wide never produced a
                  // frame at all — 40 s in, the page was still at 5 fps
                  // and a screenshot could not be taken. Half the
                  // resolution is a slightly soft thumbnail; the other
                  // way round is a window that does not paint.
                  cacheWidth: 220,
                  errorBuilder: (_) => Icon(Icons.image_not_supported_outlined,
                      size: 22, color: c.mutedText),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: c.border, width: WbMetrics.hairline),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(6, 5, 6, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: t.text * 2 * 1.25,
                    child: Text(
                      map.localizedTitle(locale),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: t.text,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                        fontFamilyFallback: kCjkFontFallback,
                      ),
                    ),
                  ),
                  Text(
                    _reference,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: t.chrome,
                      height: 1.1,
                      color: c.mutedText,
                      fontFamilyFallback: kCjkFontFallback,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
