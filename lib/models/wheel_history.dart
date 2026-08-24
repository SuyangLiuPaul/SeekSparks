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


/// One concentric band of the wheel.
///
/// The engraved chronologies organise by NATION and INSTITUTION rather
/// than by kind-of-event: Israel is a band, Rome is a band, the church
/// is a band, and every dated thing is drawn on the band it belongs to.
/// That is what lets a reader follow one people down the centuries
/// instead of reading a single undifferentiated stream of dates.
///
/// [line] is the Genesis 10 descent the band is coloured by — the same
/// organising idea, and one this app can take because its root is
/// scripture (Genesis 10) rather than anyone's compiled chart. Two
/// values are not descents: 'institution' (the church, the text of
/// scripture) and 'none'.
class WheelStream {
  const WheelStream({
    required this.id,
    required this.line,
    required this.names,
  });

  final String id;
  final String line;
  final Map<String, String> names;

  String nameFor(String locale) => names[locale] ?? names['en'] ?? id;

  static WheelStream fromJson(Map<String, dynamic> j) => WheelStream(
        id: j['id'] as String,
        line: (j['line'] as String?) ?? 'none',
        names: _localised(j['name']),
      );
}

/// One name from the table of nations, Genesis 10 (and the line of Shem
/// through Genesis 11).
///
/// These are not dated — the text gives no years for them — so the
/// wheel draws them as the descent behind a band rather than as points
/// on the axis. Every one carries [ref], the verse it was read from,
/// which is the whole reason this table is worth shipping: a reader who
/// doubts a name can be sent straight to it.
class WheelNation {
  const WheelNation({
    required this.id,
    required this.line,
    required this.father,
    required this.generation,
    required this.stream,
    required this.ref,
    required this.names,
    required this.notes,
  });

  final String id;
  final String line;

  /// Empty for Shem, Ham and Japheth themselves.
  final String father;
  final int generation;
  final String stream;
  final String ref;
  final Map<String, String> names;
  final Map<String, String> notes;

  String nameFor(String locale) => names[locale] ?? names['en'] ?? id;
  String noteFor(String locale) => notes[locale] ?? notes['en'] ?? '';

  static WheelNation fromJson(Map<String, dynamic> j) => WheelNation(
        id: j['id'] as String,
        line: (j['line'] as String?) ?? 'none',
        father: (j['father'] as String?) ?? '',
        generation: (j['generation'] as num?)?.toInt() ?? 0,
        stream: (j['stream'] as String?) ?? 'world',
        ref: (j['ref'] as String?) ?? '',
        names: _localised(j['name']),
        notes: _localised(j['note']),
      );
}

/// One power of the biblical world, drawn as an arc band.
class WheelPower {
  const WheelPower({
    required this.id,
    required this.start,
    required this.end,
    required this.stream,
    required this.approximate,
    required this.names,
    required this.notes,
  });

  final String id;

  /// The band this power is drawn on.
  final String stream;

  /// True when references genuinely differ on the span, or it is a
  /// rounded century. Written explicitly in the data on every entry —
  /// an absent flag must not be the way "settled" is expressed.
  final bool approximate;

  /// Astronomical years: negative is BC, and there is no year zero to
  /// worry about at this resolution — every span here is conventional
  /// and rounded already.
  final int start;

  /// Null for a power that has not ended. The alternative was to write
  /// this year into the data, which reads as "the state of Israel ended
  /// in 2026" and silently becomes a lie every January — an invented
  /// date in all but name. A band with no end is drawn to the axis end
  /// and labelled "present".
  final int? end;
  final Map<String, String> names;
  final Map<String, String> notes;

  bool get ongoing => end == null;

  /// The year to DRAW the band's end at, given where the axis stops.
  int endFor(int axisEnd) => end ?? axisEnd;

  String nameFor(String locale) => names[locale] ?? names['en'] ?? id;
  String noteFor(String locale) => notes[locale] ?? notes['en'] ?? '';

  static WheelPower fromJson(Map<String, dynamic> j) => WheelPower(
        id: j['id'] as String,
        start: (j['start'] as num).toInt(),
        end: (j['end'] as num?)?.toInt(),
        stream: (j['stream'] as String?) ?? 'world',
        approximate: j['approximate'] == true,
        names: _localised(j['name']),
        notes: _localised(j['note']),
      );
}

/// One dated event, drawn on the band of the stream it belongs to.
class WheelHistoryEvent {
  const WheelHistoryEvent({
    required this.id,
    required this.year,
    required this.era,
    required this.stream,
    required this.basis,
    required this.approximate,
    required this.refs,
    required this.titles,
    required this.descs,
  });

  final String id;
  final int year;

  /// `church`, `bible` or `world` — which of the three threads the
  /// event belongs to.
  final String era;

  /// The band this event is drawn on.
  final String stream;

  /// What the year rests on: 'scripture', 'scripture+thiele', or
  /// 'conventional'. The wheel says so on every detail sheet, because
  /// a date the text states and a date a reference supplies are not
  /// equally strong and the reader is entitled to know which is which.
  final String basis;

  final bool approximate;
  final List<String> refs;
  final Map<String, String> titles;
  final Map<String, String> descs;

  String titleFor(String locale) => titles[locale] ?? titles['en'] ?? id;
  String descFor(String locale) => descs[locale] ?? descs['en'] ?? '';

  static WheelHistoryEvent fromJson(Map<String, dynamic> j) =>
      WheelHistoryEvent(
        id: j['id'] as String,
        year: (j['year'] as num).toInt(),
        era: (j['era'] as String?) ?? 'church',
        stream: (j['stream'] as String?) ?? 'world',
        basis: (j['basis'] as String?) ?? 'conventional',
        approximate: j['approximate'] == true,
        refs: ((j['refs'] as List?) ?? const []).whereType<String>().toList(),
        titles: _localised(j['title']),
        descs: _localised(j['desc']),
      );
}

class WheelHistoryData {
  const WheelHistoryData({
    required this.streams,
    required this.nations,
    required this.powers,
    required this.events,
  });

  final List<WheelStream> streams;
  final List<WheelNation> nations;
  final List<WheelPower> powers;
  final List<WheelHistoryEvent> events;

  /// The nations whose descent feeds one band, in generational order —
  /// what a reader sees when they open a band and ask "who is this?"
  List<WheelNation> nationsOf(String streamId) =>
      nations.where((n) => n.stream == streamId).toList()
        ..sort((a, b) => a.generation.compareTo(b.generation));

  List<WheelPower> powersOf(String streamId) =>
      powers.where((p) => p.stream == streamId).toList();

  List<WheelHistoryEvent> eventsOf(String streamId) =>
      events.where((e) => e.stream == streamId).toList();

  static WheelHistoryData fromJson(Map<String, dynamic> j) =>
      WheelHistoryData(
        streams: ((j['streams'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(WheelStream.fromJson)
            .toList(),
        nations: ((j['nations'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(WheelNation.fromJson)
            .toList(),
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
