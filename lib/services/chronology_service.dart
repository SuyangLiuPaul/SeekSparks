import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:seeksparks/models/chronology.dart';

/// Loads `assets/chronology.json` — the Genesis 5 and 11 lifespans read
/// out of the Bible texts this app ships.
class ChronologyService {
  ChronologyService._();
  static final ChronologyService instance = ChronologyService._();

  ChronologyData? _cache;

  Future<ChronologyData> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/chronology.json');
    final data =
        ChronologyData.fromJson(json.decode(raw) as Map<String, dynamic>);
    _cache = data;
    return data;
  }
}
