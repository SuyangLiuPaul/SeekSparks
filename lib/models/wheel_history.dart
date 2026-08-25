/// `assets/wheel_history.json` — world history for the chronology
/// wheel, plus the powers of the biblical world drawn as bands.
///
/// It is HALF the wheel's dataset. An earlier version of this comment
/// described the file as "the stretch the wheel covers after
/// `bible_timeline.json` ends (AD 95)", which described a division of
/// labour that was never implemented: the page loaded this file and
/// only this file, so the wheel drew Hammurabi and Confucius and the
/// First Olympiad while the Exodus, the divided kingdom, the fall of
/// Jerusalem and the whole New Testament were missing from it. The
/// `israel` and `judah` bands held 18 records between them, none of
/// them the story the bands are named for. [bibleNarrativeEvents] is
/// the missing half — the 98 events of `assets/bible_timeline.json`
/// mapped onto these bands and merged at load — and it exists so that
/// the wheel's whole point, synchronism, works in the direction that
/// matters: the reader sees Hammurabi BESIDE the patriarchs.
///
/// Most of the file is a well-known historical fact at its conventional
/// date, selected and worded by this project. But NOT all of it, and an
/// earlier version of this comment said otherwise — "nothing is read out
/// of scripture, so nothing here carries a verse". That was false when it
/// was written: all 82 nations are read out of Genesis 10, 55 event
/// references cite scripture, and 24 of the 62 powers carry the verses
/// their span was read from. The comment was not merely stale, it was
/// load-bearing — [WheelPower] was written to match it and so parsed
/// neither `basis` nor `ref`/`refs`, which left the three Israelite
/// kingdoms telling the reader their dates were "not stated in
/// scripture" while the asset held the very verses. A wrong comment
/// about the data becomes a wrong claim to the reader.
///
/// So: every record says what its date rests on, in [WheelPower.basis]
/// and [WheelHistoryEvent.basis], and the wheel prints that rather than
/// assuming. Model and loader share a file because the payload is flat
/// lists.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:seeksparks/models/timeline_event.dart';
import 'package:seeksparks/services/timeline_service.dart';


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
    required this.basis,
    required this.approximate,
    required this.refs,
    required this.names,
    required this.notes,
  });

  final String id;

  /// The band this power is drawn on.
  final String stream;

  /// What the SPAN rests on: 'scripture', 'scripture+thiele' or
  /// 'conventional' — the same three values, and the same reason, as
  /// [WheelHistoryEvent.basis]. Stored on all 62 powers since the asset
  /// was compiled; 3 of them are `scripture+thiele` (the united
  /// monarchy, and the kingdoms of Israel and Judah), and until this
  /// field existed the wheel printed "conventional date, not stated in
  /// scripture" over all three.
  final String basis;

  /// True when references genuinely differ on the span, or it is a
  /// rounded century. Written explicitly in the data on every entry —
  /// an absent flag must not be the way "settled" is expressed.
  final bool approximate;

  /// The verses the span was read from, empty for a power dated only by
  /// convention. The asset spells this `ref` on the 10 records with one
  /// verse and `refs` on the 14 with several; both are read here into
  /// one list, because two spellings for one idea is how 42 references
  /// came to be stored and never shown.
  final List<String> refs;

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
        basis: (j['basis'] as String?) ?? 'conventional',
        approximate: j['approximate'] == true,
        refs: [
          if (j['ref'] is String && (j['ref'] as String).isNotEmpty)
            j['ref'] as String,
          ...((j['refs'] as List?) ?? const []).whereType<String>(),
        ],
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
    this.datingRefs = const [],
    this.septuagintYear,
    this.timelineEra,
  });

  final String id;
  final int year;

  /// `church`, `bible` or `world` — which of the three threads the
  /// event belongs to.
  final String era;

  /// The band this event is drawn on.
  final String stream;

  /// What the year rests on: 'scripture', 'scripture+thiele',
  /// 'thiele' or 'conventional'. The wheel says so on every detail
  /// sheet, because
  /// a date the text states and a date a reference supplies are not
  /// equally strong and the reader is entitled to know which is which.
  final String basis;

  final bool approximate;
  final List<String> refs;
  final Map<String, String> titles;
  final Map<String, String> descs;

  /// The three fields below arrive only from [bibleNarrativeEvents];
  /// `wheel_history.json` has no record carrying any of them, so
  /// [fromJson] does not look for them. They are the apparatus that
  /// makes a derived year checkable, and the wheel inherited the years
  /// without it: 18 of the merged events state an interval the reader
  /// could not see the verses for, and 8 printed one year where the
  /// timeline page prints two.

  /// The verses whose intervals the year was counted along — NOT
  /// [refs], which is where the event is narrated. See
  /// [TimelineEvent.datingRefs]: on nine of them the two sets name no
  /// chapter in common.
  final List<String> datingRefs;

  /// Where the year falls if Exodus 12:40 is read as the Septuagint
  /// reads it. Null unless the chain runs through that verse.
  final int? septuagintYear;

  /// The era of `bible_timeline.json` this came from, or null for the
  /// wheel's own records. Carried for one reason: `antediluvian` marks
  /// the eight events that are NOT counted back from the Thiele
  /// anchor, and a wheel that draws them on the same axis as the ones
  /// that are owes the reader the same seam note the timeline page
  /// gives. [era] cannot answer this — the merge sets it to `bible`.
  final String? timelineEra;

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

/// Prefix on every id [bibleNarrativeEvents] produces. The two assets
/// were compiled separately and share no id today, but nothing stops
/// one of them adding `exile` or `jonah` tomorrow, and a collision
/// would show as the wrong detail sheet rather than as a crash.
const String kBibleEventIdPrefix = 'bible:';

/// Which band each timeline era is drawn on. The wheel organises by
/// PEOPLE, not by kind-of-event, so the mapping is a question about
/// whose history the event belongs to, not about its subject.
///
/// `antediluvian` goes to `world` — the residual band, the one whose
/// Genesis 10 line is `none` and which already carries the Iron Age
/// and the Bantu expansion. Creation, the Flood and Babel belong to
/// no one people for the same reason those do: they are before the
/// peoples, and Babel is where the peoples the other bands are named
/// for begin. Its English label reads "Elsewhere", which fits a
/// migration better than it fits the Creation; renaming a band that
/// 54 existing events are correctly on is a bigger change than this
/// merge, so it is left alone and noted here.
const Map<String, String> kTimelineEraStream = {
  'antediluvian': 'world',
  'patriarchs': 'israel',
  'mosaic': 'israel',
  'conquest': 'israel',
  'monarchy': 'israel',
  'exile': 'judah',
  'intertestamental': 'judah',
  'nt': 'judah',
};

/// The records whose era answers the question wrongly.
///
/// Two boundaries the era key cannot see. After 931 BC `monarchy`
/// covers two kingdoms, and Hezekiah, Isaiah, Jeremiah and Josiah are
/// southern — leaving them on `israel` would draw Josiah's reform on a
/// band whose kingdom had fallen a century earlier. (The four are the
/// whole southern set: the other post-931 `monarchy` records — Elijah,
/// Elisha, Jonah, the fall of Samaria — are northern and stay.) And
/// `nt` spans Pentecost: everything up to the Ascension happened to
/// Judea and is drawn there, everything from Acts 2 onward is the
/// church's own history, which is why the wheel's church band
/// otherwise began in AD 64 with the fire of Rome.
///
/// Two records the era describes correctly and the band would not.
/// Job is dated to the patriarchal era but the record's own text puts
/// him outside the family — "a righteous man from Uz … no Mosaic law,
/// Tabernacle, or Levitical priesthood in view" — so drawing him on
/// Israel's band would be the app contradicting its own description.
/// And the Septuagint is not an event in Judah's history but in the
/// text's: the `scripture` band is where Qumran, P52 and the Vulgate
/// already are, and it had no record of the Greek Old Testament at all.
const Map<String, String> kTimelineStreamOverrides = {
  'job_trial': 'world',
  'hezekiah_reform': 'judah',
  'isaiah': 'judah',
  'jeremiah': 'judah',
  'josiah_reform': 'judah',
  'septuagint': 'scripture',
  'pentecost': 'church',
  'stephen_martyred': 'church',
  'paul_converted': 'church',
  'paul_journeys': 'church',
  'jerusalem_council': 'church',
  'paul_rome': 'church',
  'john_patmos': 'church',
};

/// Timeline events the wheel already tells, listed by name so a test
/// fails if either asset moves.
///
/// One entry: `temple_destroyed` (AD 70) is `jerusalem_destroyed` on
/// the wheel's `judah` band, same year, and the wheel's record carries
/// the surrounding revolt (AD 66) and Masada (AD 73) with it. Reading
/// the wheel's 133 records in −2400…AD 150 against all 98 timeline
/// records turned up no other pair naming one fact.
const Set<String> kTimelineIdsAlreadyOnWheel = {'temple_destroyed'};

/// The Bible's own narrative, shaped for the wheel.
///
/// Pure so it can be measured without a binding. [refs] carries only
/// where the event is NARRATED — [TimelineEvent.datingRefs], the
/// verses a derived year was counted along, is a different claim and
/// belongs beside the year rather than in the wheel's jump list. It
/// travels in [WheelHistoryEvent.datingRefs] and is printed under its
/// own label; for three phases it did not travel at all, which left
/// the wheel saying "interval from scripture" over a chip list that
/// states no interval.
List<WheelHistoryEvent> bibleNarrativeEvents(List<TimelineEvent> events) => [
      for (final e in events)
        if (!kTimelineIdsAlreadyOnWheel.contains(e.id))
          WheelHistoryEvent(
            id: '$kBibleEventIdPrefix${e.id}',
            year: e.year,
            era: 'bible',
            stream: kTimelineStreamOverrides[e.id] ??
                kTimelineEraStream[e.era] ??
                'world',
            basis: e.basis,
            approximate: e.approximate,
            refs: e.refs,
            datingRefs: e.datingRefs,
            septuagintYear: e.septuagintYear,
            timelineEra: e.era,
            titles: {
              'en': e.titleEn,
              if (e.titleZhHans.isNotEmpty) 'zh-Hans': e.titleZhHans,
              if (e.titleZhHant.isNotEmpty) 'zh-Hant': e.titleZhHant,
            },
            descs: {
              if (e.descEn.isNotEmpty) 'en': e.descEn,
              if (e.descZhHans.isNotEmpty) 'zh-Hans': e.descZhHans,
              if (e.descZhHant.isNotEmpty) 'zh-Hant': e.descZhHant,
            },
          )
    ];

class WheelHistoryService {
  WheelHistoryService._();
  static final WheelHistoryService instance = WheelHistoryService._();

  WheelHistoryData? _cache;

  /// Merged at load rather than written into the asset, so the two
  /// files stay single sources: `bible_timeline.json` is audited by
  /// `tools/audit_dates.py` and read by the timeline page, and a copy
  /// of it inside `wheel_history.json` would drift out of step with
  /// the audit the first time a year moved. Everything downstream —
  /// the hub counts, the stream filter, the declutter, the search
  /// box, the detail sheets — sees one list and needs no special case.
  Future<WheelHistoryData> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/wheel_history.json');
    final base =
        WheelHistoryData.fromJson(json.decode(raw) as Map<String, dynamic>);
    final data = WheelHistoryData(
      streams: base.streams,
      nations: base.nations,
      powers: base.powers,
      events: [
        ...base.events,
        ...bibleNarrativeEvents(await TimelineService.instance.loadAll()),
      ]..sort((a, b) => a.year.compareTo(b.year)),
    );
    _cache = data;
    return data;
  }
}
