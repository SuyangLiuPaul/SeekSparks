/// The full-screen plate viewer for the illustration archive.
///
/// 2026-08-09 (task #279): converted to `workbench_theme.dart`'s rule —
/// square corners, 1px hairlines, no shadows, no cards — and the two
/// floating blurred capsules it used to draw became a title bar and a
/// filmstrip, which is what a picture viewer's chrome is.
///
/// The same pass took a functional defect out with it. The strip used to
/// show [relatedMaps] and then lazy-append **the entire 1,192-plate
/// library** underneath, all of it beneath a header reading "Related
/// illustrations". Browsing the archive now has its own window
/// (`pages/illustrations_page.dart`, under Resources), so the strip is
/// exactly the list the reader arrived with and [stripTitle] says which
/// list that is. A viewer that quietly hands you the whole corpus and
/// calls it "related" is the same species of ambiguity #280 fixed in the
/// result headers.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/bible_map.dart';
import 'package:seeksparks/models/map_provenance.dart';
import 'package:seeksparks/services/map_service.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/widgets/illustration_image.dart';

/// Thumbnail geometry in the filmstrip, and the arithmetic that centres
/// the current plate in it.
const double _thumbWidth = 104;
const double _thumbGap = 6;
const double _stripImageHeight = 62;

class MapViewerPage extends StatefulWidget {
  const MapViewerPage({
    super.key,
    required this.map,
    required this.locale,
    this.relatedMaps = const [],
    this.stripTitle,
  });

  final BibleMap map;
  final String locale;

  /// The plates the reader can move between without leaving the viewer:
  /// the chapter/book matches when they came from the reading pane, the
  /// current result set when they came from the Illustrations window.
  final List<BibleMap> relatedMaps;

  /// What that list IS, printed over the strip. Defaults to "Related
  /// illustrations", which is true of the reading pane's list and was
  /// not true of the old whole-library one.
  final String? stripTitle;

  @override
  State<MapViewerPage> createState() => _MapViewerPageState();
}

class _MapViewerPageState extends State<MapViewerPage> {
  final ScrollController _strip = ScrollController();
  late BibleMap _current;

  @override
  void initState() {
    super.initState();
    _current = widget.map;
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealCurrent());
    // Task #300. The credit bar draws nothing until this resolves rather
    // than drawing "Source not recorded" and then correcting itself — a
    // wrong attribution shown for two frames is still a wrong
    // attribution, and this is the surface where that matters most.
    MapService.loadProvenance().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _strip.dispose();
    super.dispose();
  }

  /// The strip, deduplicated, with the plate that was opened guaranteed
  /// to be in it — a viewer whose filmstrip does not contain the picture
  /// on screen cannot say where you are.
  List<BibleMap> get _stripMaps {
    final seen = <String>{};
    final out = <BibleMap>[];
    for (final m in [widget.map, ...widget.relatedMaps]) {
      if (seen.add(m.id)) out.add(m);
    }
    return out;
  }

  int get _index => _stripMaps.indexWhere((m) => m.id == _current.id);

  void _step(int delta) {
    final maps = _stripMaps;
    if (maps.length < 2) return;
    final next = _index + delta;
    if (next < 0 || next >= maps.length) return;
    setState(() => _current = maps[next]);
    _revealCurrent();
  }

  /// Centre the current thumbnail. With a result set that can run to
  /// four figures, a strip that does not follow the selection is a strip
  /// showing someone else's position.
  void _revealCurrent() {
    if (!_strip.hasClients) return;
    final i = _index;
    if (i < 0) return;
    const stride = _thumbWidth + _thumbGap;
    final viewport = _strip.position.viewportDimension;
    final target = (i * stride) - (viewport - _thumbWidth) / 2;
    _strip.jumpTo(target.clamp(0.0, _strip.position.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context) {
    final c = WbColors.of(context);
    final t = WbType.of(context);
    final settings = context.watch<AppSettings>();
    // Prefer the live locale so titles and captions retranslate the
    // moment the language is switched with the viewer open; fall back to
    // the launching widget's locale where there is no AppSettings
    // ancestor (tests, isolated previews).
    final locale = settings.locale.isNotEmpty ? settings.locale : widget.locale;
    final maps = _stripMaps;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _step(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _step(1),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: c.paneBg,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _titleBar(context, c, t, locale),
                Expanded(
                  child: InteractiveViewer(
                    // A unique key resets pan and zoom when the plate
                    // changes; carrying a 5x zoom across to a different
                    // picture lands the reader in a corner of it.
                    key: ValueKey('iv_${_current.id}'),
                    minScale: 0.5,
                    maxScale: 5.0,
                    child: Center(
                      child: IllustrationImage(
                        map: _current,
                        fit: BoxFit.contain,
                        errorBuilder: (_) => _imageFallback(c, t, locale),
                      ),
                    ),
                  ),
                ),
                _creditBar(c, t, locale),
                if (maps.length > 1) _filmstrip(c, t, locale, maps),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Who made this picture, under the picture (task #300).
  ///
  /// BibleWorks puts the same thing in the same relationship: bwh47 says
  /// each resource carries its own copyright file, shown in the Analysis
  /// Window beside the resource, and that **that** display — not the
  /// manual's collected chapter — "is the place to look for definitive
  /// copyright information". So the credit belongs on the plate. The
  /// About page's collected list stays, but it is the index, not the
  /// record.
  ///
  /// It is drawn for EVERY plate, including the 151 nobody recorded a
  /// source for. Printing nothing for those would make them look exactly
  /// like a public-domain plate that needs no credit, which is the
  /// opposite of what is true about them.
  Widget _creditBar(WbColors c, WbType t, String locale) {
    if (!MapService.provenanceLoaded) return const SizedBox.shrink();
    final p = MapService.provenanceOf(_current);
    final line = mapCreditLine(
      p,
      locale,
      unknownLabel: uiStrings['mapCreditUnknown']?[locale] ??
          'Source not recorded',
    );
    final heading =
        uiStrings['mapCreditHeading']?[locale] ?? 'Image source';
    return Container(
      decoration: BoxDecoration(
        color: c.chromeBg,
        border: Border(
          top: BorderSide(color: c.border, width: WbMetrics.hairline),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$heading · ',
            style: TextStyle(
              fontSize: t.chrome,
              color: c.mutedText,
              fontWeight: FontWeight.w700,
              fontFamilyFallback: kCjkFontFallback,
            ),
          ),
          Expanded(
            child: Text(
              line,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: t.chrome,
                // A required credit is a condition of shipping the
                // plate, so it gets the readable colour; a courtesy
                // credit is muted. The reader sees which is which
                // without being told.
                color: p.mustCredit ? c.text : c.mutedText,
                height: 1.35,
                fontFamilyFallback: kCjkFontFallback,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _titleBar(
      BuildContext context, WbColors c, WbType t, String locale) {
    final desc = _current.localizedDescription(locale);
    return Container(
      decoration: BoxDecoration(
        color: c.chromeBg,
        border: Border(
          bottom: BorderSide(color: c.border, width: WbMetrics.hairline),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(2, 4, 10, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back, size: t.text + 4, color: c.text),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            tooltip: uiStrings['back']?[locale] ?? 'Back',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _current.localizedTitle(locale),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: t.text + 1,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                    height: 1.25,
                    fontFamilyFallback: kCjkFontFallback,
                  ),
                ),
                if (desc.isNotEmpty)
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: t.chrome,
                      color: c.mutedText,
                      height: 1.3,
                      fontFamilyFallback: kCjkFontFallback,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filmstrip(
      WbColors c, WbType t, String locale, List<BibleMap> maps) {
    final title = widget.stripTitle ??
        uiStrings['mapsRelated']?[locale] ??
        'Related illustrations';
    return Container(
      decoration: BoxDecoration(
        color: c.chromeBg,
        border: Border(
          top: BorderSide(color: c.border, width: WbMetrics.hairline),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title · ${_index + 1}/${maps.length}',
            style: TextStyle(
              fontSize: t.chrome,
              fontWeight: FontWeight.w700,
              color: c.mutedText,
              fontFamilyFallback: kCjkFontFallback,
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: _stripImageHeight + t.chrome * 1.2 + 4,
            child: ListView.separated(
              controller: _strip,
              scrollDirection: Axis.horizontal,
              itemCount: maps.length,
              separatorBuilder: (_, __) => const SizedBox(width: _thumbGap),
              itemBuilder: (ctx, i) {
                final m = maps[i];
                return _StripCard(
                  map: m,
                  locale: locale,
                  isCurrent: m.id == _current.id,
                  onTap: () {
                    if (m.id == _current.id) return;
                    setState(() => _current = m);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageFallback(WbColors c, WbType t, String locale) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported_outlined,
                size: 40, color: c.mutedText),
            const SizedBox(height: 8),
            Text(
              uiStrings['illustrationUnavailable']?[locale] ??
                  'Illustration unavailable',
              style: TextStyle(
                color: c.mutedText,
                fontSize: t.text,
                fontFamilyFallback: kCjkFontFallback,
              ),
            ),
          ],
        ),
      );
}

class _StripCard extends StatelessWidget {
  const _StripCard({
    required this.map,
    required this.locale,
    required this.isCurrent,
    required this.onTap,
  });

  final BibleMap map;
  final String locale;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = WbColors.of(context);
    final t = WbType.of(context);
    return SizedBox(
      width: _thumbWidth,
      child: Material(
        color: isCurrent ? c.selectionBg : c.paneBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(
            color: isCurrent ? c.text : c.border,
            width: WbMetrics.hairline,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          hoverColor: c.hoverBg,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: _stripImageHeight,
                child: IllustrationImage(
                  map: map,
                  thumb: true,
                  fit: BoxFit.cover,
                  cacheWidth: 220,
                  errorBuilder: (_) => Icon(
                    Icons.image_not_supported_outlined,
                    size: 16,
                    color: c.mutedText,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(3, 2, 3, 0),
                child: Text(
                  map.localizedTitle(locale),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: t.chrome,
                    height: 1.1,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                    color: isCurrent ? c.text : c.mutedText,
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
}
