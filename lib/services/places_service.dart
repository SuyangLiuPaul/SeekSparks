/// 2026-08-08 (SeekSparks): the biblical gazetteer, indexed by verse.
///
/// **What BibleWorks does, and what it does not.** BibleWorks ships a
/// map module (help topic bwh33) that is a cartography suite: hundreds of
/// megabytes of raster data, stacked editable overlays, a polyline
/// editor, a ruler with travel-time estimates. Its only connection to the
/// text is one line in bwh33 — right-click an English word in the Browse
/// Window, choose "Lookup in BibleWorks Maps", and the Find Place window
/// opens with that word typed into it.
///
/// That is a *manual, one-word, English-only* lookup that leaves the text
/// behind. It requires the reader to already know that the word under the
/// cursor is a place at all, which is exactly the knowledge a gazetteer
/// is supposed to supply. A reader in Chinese gets nothing from it, since
/// the maps database is indexed in English.
///
/// bwh33 also ships "66 maps depicting the sites mentioned in each book
/// of the Bible" — so the question *is* answered, once per book, by a
/// static file the reader opens by hand from File | Open in a separate
/// module. A book is not a passage; Genesis' map is a map of the ancient
/// world.
///
/// So the gap is not cartography, which BibleWorks does far better than
/// this app ever will. The gap is that nothing follows the verse the
/// reader is actually on and answers **"what places does the passage in
/// front of me name?"** That question needs no overlays and no satellite
/// imagery — it needs the gazetteer turned inside out, from place→verses
/// into verse→places. This file is that inversion.
///
/// **The data needed repair before it could be indexed.** See
/// `utils/place_geo.dart`: a global case-replace of the substring `eph`
/// ran over the source file at some point, and it damaged eight of the
/// three-letter book codes. Those eight carry 69 references between
/// them — every one of which would otherwise be silently dropped or,
/// worse, filed under the wrong book.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:seeksparks/models/bible_place.dart';
import 'package:seeksparks/utils/place_geo.dart';

/// The gazetteer, its verse index, and the base map beneath it.
///
/// Loaded once and held. The gazetteer is 460 KB and the base map 110 KB,
/// which is small enough that paging it would cost more than it saves —
/// unlike the concordance, where lazy loading is the whole design.
abstract final class PlacesService {
  static const String _placesAsset = 'assets/bible_places.json';
  static const String _geoAsset = 'assets/bible_geo.json';

  static List<BiblePlace>? _places;
  static Map<String, List<BiblePlace>>? _byVerse;
  static Map<String, List<BiblePlace>>? _byChapter;
  static String _attribution = '';
  static BaseMap? _baseMap;
  static String _geoAttribution = '';

  static Future<void>? _placesLoad;
  static Future<void>? _geoLoad;

  /// The permission this data ships under is conditional on naming its
  /// source, so the credit has to reach a surface the reader sees.
  static String get attribution => _attribution;
  static String get geoAttribution => _geoAttribution;

  @visibleForTesting
  static void resetForTest() {
    _places = null;
    _byVerse = null;
    _byChapter = null;
    _baseMap = null;
    _placesLoad = null;
    _geoLoad = null;
    _attribution = '';
    _geoAttribution = '';
  }

  static Future<void> _ensurePlaces() {
    if (_places != null) return Future<void>.value();
    return _placesLoad ??= _loadPlaces();
  }

  static Future<void> _loadPlaces() async {
    try {
      final raw = await rootBundle.loadString(_placesAsset);
      final doc = json.decode(raw) as Map<String, dynamic>;
      _attribution = (doc['attribution'] as String?) ?? '';
      _places = parseGazetteer(doc);
    } catch (e) {
      debugPrint('PlacesService: gazetteer unavailable ($e)');
      _places = const <BiblePlace>[];
    }
    _index(_places!);
  }

  static void _index(List<BiblePlace> places) {
    final byVerse = <String, List<BiblePlace>>{};
    final byChapter = <String, List<BiblePlace>>{};
    for (final p in places) {
      for (final r in p.refs) {
        (byVerse[r.key] ??= <BiblePlace>[]).add(p);
        final ck = '${r.englishBook}|${r.chapter}';
        final chapter = byChapter[ck] ??= <BiblePlace>[];
        // A place named three times in a chapter is still one place in
        // the chapter's list.
        if (chapter.isEmpty || !identical(chapter.last, p)) {
          if (!chapter.contains(p)) chapter.add(p);
        }
      }
    }
    _byVerse = byVerse;
    _byChapter = byChapter;
  }

  /// Every place the gazetteer knows, repaired and merged.
  static Future<List<BiblePlace>> all() async {
    await _ensurePlaces();
    return _places ?? const <BiblePlace>[];
  }

  /// The places named in one verse, in the order the gazetteer lists
  /// them (alphabetical), or empty.
  static Future<List<BiblePlace>> forVerse(
      String englishBook, int chapter, int verse) async {
    await _ensurePlaces();
    return _byVerse?['$englishBook|$chapter|$verse'] ?? const <BiblePlace>[];
  }

  /// The places named anywhere in one chapter.
  ///
  /// This is what makes the pane useful rather than merely correct. Most
  /// verses name no place at all — a pane that showed only the focused
  /// verse's places would be empty most of the time and would read as
  /// broken. The chapter is the context the reader is already in, so it
  /// is the honest second tier: "here, and here is the rest of what this
  /// chapter walks through".
  static Future<List<BiblePlace>> forChapter(
      String englishBook, int chapter) async {
    await _ensurePlaces();
    return _byChapter?['$englishBook|$chapter'] ?? const <BiblePlace>[];
  }

  /// Both tiers at once, with the verse's own places lifted out of the
  /// chapter list so nothing is listed twice.
  static Future<PassagePlaces> forPassage(
      String englishBook, int chapter, int verse) async {
    final here = await forVerse(englishBook, chapter, verse);
    final all = await forChapter(englishBook, chapter);
    final hereIds = <String>{for (final p in here) p.id};
    return PassagePlaces(
      verse: here,
      chapter: <BiblePlace>[
        for (final p in all)
          if (!hereIds.contains(p.id)) p,
      ],
    );
  }

  /// The base map — coastlines, lakes, rivers and land.
  static Future<BaseMap> baseMap() async {
    if (_baseMap != null) return _baseMap!;
    await (_geoLoad ??= _loadGeo());
    return _baseMap ?? const BaseMap.empty();
  }

  static Future<void> _loadGeo() async {
    try {
      final raw = await rootBundle.loadString(_geoAsset);
      final doc = json.decode(raw) as Map<String, dynamic>;
      _geoAttribution = (doc['attribution'] as String?) ?? '';
      _baseMap = parseBaseMap(doc);
    } catch (e) {
      debugPrint('PlacesService: base map unavailable ($e)');
      _baseMap = const BaseMap.empty();
    }
  }
}

/// What a passage names, split into the focused verse and its chapter.
@immutable
class PassagePlaces {
  const PassagePlaces({required this.verse, required this.chapter});

  /// Places named in the focused verse itself.
  final List<BiblePlace> verse;

  /// Places named elsewhere in the same chapter.
  final List<BiblePlace> chapter;

  bool get isEmpty => verse.isEmpty && chapter.isEmpty;

  /// Everything, focused verse first — what the map draws.
  List<BiblePlace> get all => <BiblePlace>[...verse, ...chapter];
}
