/// 2026-08-08 (SeekSparks): the Places tab.
///
/// Answers the question BibleWorks' map module cannot be asked: **what
/// places does the passage in front of me name?** bwh33 offers only the
/// reverse — right-click an English word you have already guessed is a
/// place, and a Find Place window opens somewhere else. This is the
/// gazetteer read the other way round, and it costs the reader nothing:
/// the list is simply there, next to the verse.
///
/// Two tiers, and the second is what makes the tab worth opening. Most
/// verses name no place at all, so a pane showing only the focused
/// verse would sit empty most of the time and read as broken. The
/// chapter is the context the reader is already in, so it is the honest
/// fallback — "here, and here is the rest of what this chapter walks
/// through".
library;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/book_name_mapping.dart' show BookScript;
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/bible_place.dart';
import 'package:seeksparks/services/places_service.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;

class PlacesPane extends StatefulWidget {
  const PlacesPane({
    super.key,
    required this.englishBook,
    required this.chapter,
    required this.verse,
    required this.locale,
    required this.script,
    required this.onOpenAtlas,
  });

  final String englishBook;
  final int chapter;
  final int verse;
  final String locale;

  /// Place names follow the READING VERSION, not the UI locale — the
  /// same rule as book names (task #283). A reader in CUVS gets
  /// 耶路撒冷 beside 耶路撒冷 in the text, not "Jerusalem".
  final BookScript script;

  /// Opens the Atlas on this passage, focused on `id` when a row rather
  /// than the header button was tapped.
  ///
  /// The pane hands over the places it has ALREADY loaded rather than a
  /// reference for the Atlas to look up again. That is not an
  /// optimisation: it is what keeps the map showing the same set the
  /// list showed, even if the reader moves the verse underneath while
  /// the Atlas is open.
  final void Function(List<BiblePlace> places, String? id) onOpenAtlas;

  @override
  State<PlacesPane> createState() => _PlacesPaneState();
}

class _PlacesPaneState extends State<PlacesPane> {
  late Future<PassagePlaces> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(PlacesPane old) {
    super.didUpdateWidget(old);
    if (old.englishBook != widget.englishBook ||
        old.chapter != widget.chapter ||
        old.verse != widget.verse) {
      _future = _load();
    }
  }

  Future<PassagePlaces> _load() => PlacesService.forPassage(
      widget.englishBook, widget.chapter, widget.verse);

  String _s(String key, String fallback) =>
      uiStrings[key]?[widget.locale] ?? fallback;

  @override
  Widget build(BuildContext context) {
    final c = WbColors.of(context);
    final t = WbType.of(context);
    return FutureBuilder<PassagePlaces>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final data = snap.data;
        if (data == null || data.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _s('placesNone',
                    'This chapter names no place in the gazetteer.'),
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

        return ListView(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 16),
          physics: const BouncingScrollPhysics(),
          children: [
            _mapButton(c, t, data),
            if (data.verse.isNotEmpty) ...[
              _sectionTitle(
                  c, t, _s('placesInThisVerse', 'Named in this verse')),
              for (final p in data.verse)
                _row(c, t, p, data, emphasised: true),
            ],
            if (data.chapter.isNotEmpty) ...[
              _sectionTitle(c, t,
                  _s('placesInThisChapter', 'Elsewhere in this chapter')),
              for (final p in data.chapter)
                _row(c, t, p, data, emphasised: false),
            ],
            if (PlacesService.attribution.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  PlacesService.attribution,
                  style: TextStyle(
                    fontSize: t.chrome - 1.5,
                    color: c.mutedText,
                    height: 1.35,
                    fontFamilyFallback: kCjkFontFallback,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _mapButton(WbColors c, WbType t, PassagePlaces data) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: () => widget.onOpenAtlas(data.all, null),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: c.border, width: WbMetrics.hairline),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.public, size: t.text + 1, color: c.link),
                const SizedBox(width: 6),
                Text(
                  _s('placesShowMap', 'Show on map'),
                  style: TextStyle(
                    fontSize: t.text,
                    color: c.link,
                    fontWeight: FontWeight.w600,
                    fontFamilyFallback: kCjkFontFallback,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _sectionTitle(WbColors c, WbType t, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: t.chrome,
            fontWeight: FontWeight.w700,
            color: c.mutedText,
            letterSpacing: 0.3,
            fontFamilyFallback: kCjkFontFallback,
          ),
        ),
      );

  Widget _row(WbColors c, WbType t, BiblePlace p, PassagePlaces data,
      {required bool emphasised}) {
    final display = p.displayName(widget.script);
    // The English name is kept beside a Chinese one rather than
    // replaced by it: the gazetteer, every atlas and every commentary
    // the reader might reach for are indexed in English, so dropping it
    // would make the pane a dead end.
    final showEnglish = display != p.name;

    return InkWell(
      onTap: () => widget.onOpenAtlas(data.all, p.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2.5),
              child: Icon(
                p.located ? Icons.place : Icons.help_outline,
                size: t.text,
                color: p.located
                    ? (emphasised ? c.link : c.mutedText)
                    : c.mutedText,
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          display,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: t.text,
                            fontWeight: emphasised
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: c.text,
                            fontFamilyFallback: kCjkFontFallback,
                          ),
                        ),
                      ),
                      // The disambiguating numeral, kept visible:
                      // Antioch 1 is Syrian and Antioch 2 is Pisidian,
                      // 800 km apart, and a list that printed both as
                      // "Antioch" would be actively misleading.
                      if (p.ordinal != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 3),
                          child: Text(
                            '${p.ordinal}',
                            style: TextStyle(
                              fontSize: t.chrome - 1,
                              color: c.mutedText,
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      Text(
                        '${p.refs.length} ${_s('placesOccurrences', 'refs')}',
                        style: TextStyle(
                          fontSize: t.chrome - 1,
                          color: c.mutedText,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          fontFamilyFallback: kCjkFontFallback,
                        ),
                      ),
                    ],
                  ),
                  if (showEnglish || !p.located)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        [
                          if (showEnglish) p.name,
                          if (!p.located)
                            _s('placesUnlocated', 'location unknown'),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: t.chrome - 1,
                          color: c.mutedText,
                          fontFamilyFallback: kCjkFontFallback,
                        ),
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
