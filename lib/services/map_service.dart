import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:seeksparks/models/bible_map.dart';
import 'package:seeksparks/models/map_provenance.dart';

class MapService {
  static List<BibleMap>? _cache;
  static Future<List<BibleMap>>? _loading;
  static Map<String, MapProvenance>? _provenance;
  static Future<Map<String, MapProvenance>>? _provenanceLoading;

  static Future<List<BibleMap>> loadMaps() {
    if (_cache != null) return Future.value(_cache!);
    _loading ??= _doLoad();
    return _loading!;
  }

  static Future<List<BibleMap>> _doLoad() async {
    final jsonString = await rootBundle.loadString('assets/maps_index.json');
    final list = jsonDecode(jsonString) as List;
    _cache = list
        .map((e) => BibleMap.fromJson(e as Map<String, dynamic>))
        .toList();
    return _cache!;
  }

  static List<BibleMap> get cached => _cache ?? [];

  static Future<List<BibleMap>> mapsForBookChapter(
      String englishBook, int chapter) async {
    final all = await loadMaps();
    return all.where((m) => m.matchesBookChapter(englishBook, chapter)).toList();
  }

  /// All maps that mention the given book, regardless of chapter range.
  /// Used as a fallback when no chapter-specific map matches — e.g. on
  /// Acts 22 we still want to surface Paul's journeys / NT World.
  static Future<List<BibleMap>> mapsForBook(String englishBook) async {
    final all = await loadMaps();
    return all.where((m) => m.books.containsKey(englishBook)).toList();
  }

  /// Where the plates came from (task #300), keyed by
  /// [BibleMap.collection].
  static Future<Map<String, MapProvenance>> loadProvenance() {
    final cached = _provenance;
    if (cached != null) return Future.value(cached);
    return _provenanceLoading ??= _doLoadProvenance();
  }

  static Future<Map<String, MapProvenance>> _doLoadProvenance() async {
    final raw =
        await rootBundle.loadString('assets/maps_provenance.json');
    final records = (jsonDecode(raw) as Map<String, dynamic>)['collections']
        as List;
    return _provenance = {
      for (final r in records)
        (r as Map<String, dynamic>)['id'] as String:
            MapProvenance.fromJson(r),
    };
  }

  /// False until [loadProvenance] resolves. A caller must check this
  /// before drawing: [provenanceOf] answers `unrecorded` for a plate it
  /// has no records for at all, which before the load is every plate,
  /// and a credit bar that says "source not recorded" for two frames
  /// and then corrects itself has told the reader something untrue.
  static bool get provenanceLoaded => _provenance != null;

  /// Never null. A plate naming a collection nobody recorded still gets
  /// a record saying exactly that, because the viewer's honest line and
  /// its empty line must not be the same line.
  static MapProvenance provenanceOf(BibleMap map) =>
      _provenance?[map.collection] ?? MapProvenance.unrecorded;

  static void clearCache() {
    _cache = null;
    _provenance = null;
    _provenanceLoading = null;
  }
}
