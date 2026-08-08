import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:seeksparks/models/hebrew_king.dart';

/// Loads `assets/hebrew_kings.json` — the kings of Judah and Israel on
/// Thiele's chronology — and answers the one question the chart exists
/// to answer: who was on the other throne at the same time.
class HebrewKingsData {
  const HebrewKingsData({
    required this.kings,
    required this.epochs,
    required this.systemNames,
    required this.sources,
  });

  final List<HebrewKing> kings;
  final List<KingsEpoch> epochs;
  final Map<String, String> systemNames;
  final List<String> sources;

  String systemNameFor(String locale) =>
      systemNames[locale] ?? systemNames['en'] ?? 'Thiele';

  List<HebrewKing> ofKingdom(Kingdom k) =>
      kings.where((e) => e.kingdom == k).toList();

  HebrewKing? byId(String id) {
    for (final k in kings) {
      if (k.id == id) return k;
    }
    return null;
  }

  /// Kings of the *other* kingdom whose reigns shared a year with [k],
  /// in chronological order.
  ///
  /// This is the synchronism the books of Kings themselves supply, and
  /// it is computed rather than stored: a hand-written contemporaries
  /// list would be a second copy of the dates, free to drift from the
  /// first.
  List<HebrewKing> contemporariesOf(HebrewKing k) {
    if (k.kingdom == Kingdom.united) return const [];
    final other = k.kingdom == Kingdom.judah ? Kingdom.israel : Kingdom.judah;
    final out = kings
        .where((e) => e.kingdom == other && reignsOverlap(e, k))
        .toList();
    out.sort((a, b) => a.reignStart.compareTo(b.reignStart));
    return out;
  }

  /// The earliest and latest year any king in the file touches, used to
  /// scale the chart axis.
  (int, int) get extent {
    var lo = kings.first.reignStart;
    var hi = kings.first.reignEnd;
    for (final k in kings) {
      if (k.reignStart < lo) lo = k.reignStart;
      if (k.reignEnd > hi) hi = k.reignEnd;
    }
    return (lo, hi);
  }

  static HebrewKingsData fromJson(Map<String, dynamic> j) {
    final meta = (j['_meta'] as Map?)?.cast<String, dynamic>();
    return HebrewKingsData(
      kings: ((j['kings'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(HebrewKing.fromJson)
          .toList(),
      epochs: ((j['epochs'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(KingsEpoch.fromJson)
          .toList(),
      systemNames: {
        for (final e in ((j['systemName'] as Map?) ?? const {}).entries)
          if (e.value is String) e.key.toString(): e.value as String,
      },
      sources: ((meta?['sources'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
    );
  }
}

class HebrewKingsService {
  HebrewKingsService._();
  static final HebrewKingsService instance = HebrewKingsService._();

  HebrewKingsData? _cache;

  Future<HebrewKingsData> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/hebrew_kings.json');
    final data =
        HebrewKingsData.fromJson(json.decode(raw) as Map<String, dynamic>);
    _cache = data;
    return data;
  }
}
