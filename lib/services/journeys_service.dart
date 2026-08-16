/// 2026-08-17 (SeekSparks): the journey overlays, joined to the gazetteer.
///
/// Its own asset and its own service rather than a section of
/// `bible_places.json`, for the reason bwh33 gives structurally: in
/// BibleWorks a route is an OVERLAY — "a transparent sheet with map
/// features printed on it", turned on and off from the Overlays window,
/// stacked with the others. It is not a property of a place. Antioch does
/// not belong to Paul's first journey; the journey passes through Antioch,
/// twice, and Antioch is also in Galatians and Revelation.
///
/// 11 KB, loaded only by the Atlas and only after the gazetteer it needs
/// to resolve against.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:seeksparks/models/bible_journey.dart';
import 'package:seeksparks/services/places_service.dart';
import 'package:seeksparks/utils/journey_route.dart';

abstract final class JourneysService {
  static const String _asset = 'assets/bible_journeys.json';

  static List<ResolvedJourney>? _cache;
  static Future<List<ResolvedJourney>>? _loading;

  static Future<List<ResolvedJourney>> all() {
    final done = _cache;
    if (done != null) return Future.value(done);
    return _loading ??= _load();
  }

  static Future<List<ResolvedJourney>> _load() async {
    final places = await PlacesService.all();
    final raw = await rootBundle.loadString(_asset);
    final doc = json.decode(raw) as Map<String, dynamic>;
    final resolved = resolveJourneys(parseJourneys(doc), places);
    _cache = resolved;
    _loading = null;
    return resolved;
  }
}
