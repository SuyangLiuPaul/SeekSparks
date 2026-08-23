/// `assets/wheel_history.json` — the stretch the chronology wheel's
/// full-history mode covers after `bible_timeline.json` ends (AD 95),
/// carried to the present, plus the powers of the biblical world drawn
/// as bands.
///
/// Everything in the file is a well-known historical fact at its
/// conventional date, selected and worded by this project. Nothing is
/// read out of scripture, so nothing here carries a verse; the wheel
/// says "conventional" for these the way the timeline marks its own
/// approximations. Model and loader share a file because the payload
/// is two flat lists.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;


/// One power of the biblical world, drawn as an arc band.
class WheelPower {
  const WheelPower({
    required this.id,
    required this.start,
    required this.end,
    required this.names,
    required this.notes,
  });

  final String id;

  /// Astronomical years: negative is BC, and there is no year zero to
  /// worry about at this resolution — every span here is conventional
  /// and rounded already.
  final int start;
  final int end;
  final Map<String, String> names;
  final Map<String, String> notes;

  String nameFor(String locale) => names[locale] ?? names['en'] ?? id;
  String noteFor(String locale) => notes[locale] ?? notes['en'] ?? '';

  static WheelPower fromJson(Map<String, dynamic> j) => WheelPower(
        id: j['id'] as String,
        start: (j['start'] as num).toInt(),
        end: (j['end'] as num).toInt(),
        names: _localised(j['name']),
        notes: _localised(j['note']),
      );
}

/// One event after the scripture record closes, drawn as a dot.
class WheelHistoryEvent {
  const WheelHistoryEvent({
    required this.id,
    required this.year,
    required this.era,
    required this.approximate,
    required this.titles,
    required this.descs,
  });

  final String id;
  final int year;

  /// `church`, `bible` or `world` — which of the three threads the
  /// event belongs to. Colour keys off this.
  final String era;
  final bool approximate;
  final Map<String, String> titles;
  final Map<String, String> descs;

  String titleFor(String locale) => titles[locale] ?? titles['en'] ?? id;
  String descFor(String locale) => descs[locale] ?? descs['en'] ?? '';

  static WheelHistoryEvent fromJson(Map<String, dynamic> j) =>
      WheelHistoryEvent(
        id: j['id'] as String,
        year: (j['year'] as num).toInt(),
        era: (j['era'] as String?) ?? 'church',
        approximate: j['approximate'] == true,
        titles: _localised(j['title']),
        descs: _localised(j['desc']),
      );
}

class WheelHistoryData {
  const WheelHistoryData({required this.powers, required this.events});

  final List<WheelPower> powers;
  final List<WheelHistoryEvent> events;

  static WheelHistoryData fromJson(Map<String, dynamic> j) =>
      WheelHistoryData(
        powers: ((j['powers'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(WheelPower.fromJson)
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start)),
        events: ((j['events'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(WheelHistoryEvent.fromJson)
            .toList()
          ..sort((a, b) => a.year.compareTo(b.year)),
      );
}

Map<String, String> _localised(Object? raw) => {
      for (final e in ((raw as Map?) ?? const {}).entries)
        if (e.value is String) e.key.toString(): e.value as String,
    };

class WheelHistoryService {
  WheelHistoryService._();
  static final WheelHistoryService instance = WheelHistoryService._();

  WheelHistoryData? _cache;

  Future<WheelHistoryData> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/wheel_history.json');
    final data =
        WheelHistoryData.fromJson(json.decode(raw) as Map<String, dynamic>);
    _cache = data;
    return data;
  }
}
