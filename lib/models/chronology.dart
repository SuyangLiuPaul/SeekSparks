/// The Genesis 5 and Genesis 11 lifespans, in Anno Mundi.
///
/// Backing data: `assets/chronology.json`, built by
/// `scripts/build_chronology.py`, which reads every figure out of
/// `assets/kjv.json` and `assets/lxxwh.json` rather than holding a table
/// of its own. Each figure therefore carries the verse it was read from,
/// and the app can send a doubting reader straight to it.
///
/// Years are Anno Mundi — counted from the creation — and never BC.
/// `assets/hebrew_kings.json` and `assets/bible_timeline.json` use
/// negative years for BC, and these do not convert into those: fixing AM
/// against a Julian year takes an absolute anchor the text never
/// supplies. Ussher's 4004 BC is one such anchor, and one reconstruction
/// among several.
library;

/// One tradition's figures for one man.
///
/// [checked] records whether the parse that produced these numbers could
/// be verified against a third number the text states. Genesis 5 gives
/// the age at begetting, the years after, *and* the total, so a
/// mis-parse there cannot hide. Genesis 11 gives only the first two, so
/// its lifespans are sums and carry no such check. The distinction is
/// kept because a number that was verified and a number that was merely
/// added are not equally trustworthy, and the surface should be able to
/// say which is which.
class ChronologyFigures {
  const ChronologyFigures({
    required this.begatAt,
    required this.livedAfter,
    required this.lifespan,
    required this.birthAm,
    required this.deathAm,
    required this.checked,
    required this.refs,
  });

  /// His age when the next man in the line was born.
  final int begatAt;

  /// Years he lived after that.
  final int livedAfter;
  final int lifespan;
  final int birthAm;
  final int deathAm;
  final bool checked;

  /// Verse per figure, keyed `begatAt` / `livedAfter` / `lifespan`. A key
  /// is absent when the text states no such number and it was derived —
  /// absent means derived, and that is deliberately distinguishable from
  /// a verse that happens to be unknown.
  final Map<String, String> refs;

  static ChronologyFigures fromJson(Map<String, dynamic> j) =>
      ChronologyFigures(
        begatAt: (j['begatAt'] as num).toInt(),
        livedAfter: (j['livedAfter'] as num).toInt(),
        lifespan: (j['lifespan'] as num).toInt(),
        birthAm: (j['birthAm'] as num).toInt(),
        deathAm: (j['deathAm'] as num).toInt(),
        checked: j['checked'] == true,
        refs: {
          for (final e in ((j['refs'] as Map?) ?? const {}).entries)
            if (e.value is String) e.key.toString(): e.value as String,
        },
      );
}

class Patriarch {
  const Patriarch({
    required this.id,
    required this.line,
    required this.names,
    required this.figures,
  });

  final String id;

  /// `seth` for Genesis 5, `shem` for Genesis 11. The printed
  /// chronologies have coloured by line of descent since the 17th
  /// century and it is the one grouping the text itself draws.
  final String line;
  final Map<String, String> names;

  /// Keyed by tradition id. Not every man is in every tradition —
  /// Kainan is in the Septuagint's Genesis 11 and not in the Hebrew's —
  /// so a missing entry means the tradition does not have him, which is
  /// itself worth showing.
  final Map<String, ChronologyFigures> figures;

  String nameFor(String locale) => names[locale] ?? names['en'] ?? id;

  static Patriarch fromJson(Map<String, dynamic> j) => Patriarch(
        id: j['id'] as String,
        line: (j['line'] as String?) ?? 'seth',
        names: _localised(j['name']),
        figures: {
          for (final e in ((j['figures'] as Map?) ?? const {}).entries)
            if (e.value is Map)
              e.key.toString(): ChronologyFigures.fromJson(
                  (e.value as Map).cast<String, dynamic>()),
        },
      );
}

class ChronologyTradition {
  const ChronologyTradition({
    required this.id,
    required this.names,
    required this.longNames,
    required this.floodAm,
    required this.endAm,
  });

  final String id;
  final Map<String, String> names;
  final Map<String, String> longNames;
  final int floodAm;
  final int endAm;

  String nameFor(String locale) => names[locale] ?? names['en'] ?? id;
  String longNameFor(String locale) =>
      longNames[locale] ?? longNames['en'] ?? nameFor(locale);

  static ChronologyTradition fromJson(Map<String, dynamic> j) =>
      ChronologyTradition(
        id: j['id'] as String,
        names: _localised(j['name']),
        longNames: _localised(j['longName']),
        floodAm: (j['floodAm'] as num).toInt(),
        endAm: (j['endAm'] as num).toInt(),
      );
}

class ChronologyEpoch {
  const ChronologyEpoch({
    required this.id,
    required this.names,
    required this.ref,
    required this.years,
    required this.notes,
  });

  final String id;
  final Map<String, String> names;
  final String? ref;

  /// The epoch falls in a different year in each tradition, which is the
  /// whole reason the chart offers a choice.
  final Map<String, int> years;
  final Map<String, String> notes;

  String nameFor(String locale) => names[locale] ?? names['en'] ?? id;
  String? noteFor(String locale) => notes[locale] ?? notes['en'];

  static ChronologyEpoch fromJson(Map<String, dynamic> j) => ChronologyEpoch(
        id: j['id'] as String,
        names: _localised(j['name']),
        ref: j['ref'] as String?,
        years: {
          for (final e in ((j['years'] as Map?) ?? const {}).entries)
            if (e.value is num) e.key.toString(): (e.value as num).toInt(),
        },
        notes: _localised(j['note']),
      );
}

/// A caveat the generator emitted because the numbers showed it, not
/// because anyone asserted it. See `scripts/build_chronology.py`.
class ChronologyNote {
  const ChronologyNote({
    required this.id,
    required this.tradition,
    required this.texts,
  });

  final String id;
  final String tradition;
  final Map<String, String> texts;

  String textFor(String locale) => texts[locale] ?? texts['en'] ?? '';

  static ChronologyNote fromJson(Map<String, dynamic> j) => ChronologyNote(
        id: (j['id'] as String?) ?? '',
        tradition: (j['tradition'] as String?) ?? '',
        texts: _localised(j['text']),
      );
}

class ChronologyData {
  const ChronologyData({
    required this.traditions,
    required this.epochs,
    required this.notes,
    required this.patriarchs,
    required this.unitNote,
    required this.traditionsNote,
    required this.secondWitness,
    required this.sumsChecked,
  });

  final List<ChronologyTradition> traditions;
  final List<ChronologyEpoch> epochs;
  final List<ChronologyNote> notes;
  final List<Patriarch> patriarchs;
  final String unitNote;
  final String traditionsNote;
  final String secondWitness;
  final int sumsChecked;

  ChronologyTradition traditionById(String id) =>
      traditions.firstWhere((t) => t.id == id, orElse: () => traditions.first);

  /// Everyone the given tradition actually has figures for, in
  /// generational order.
  List<Patriarch> inTradition(String traditionId) =>
      patriarchs.where((p) => p.figures.containsKey(traditionId)).toList();

  List<ChronologyNote> notesFor(String traditionId) =>
      notes.where((n) => n.tradition == traditionId).toList();

  Patriarch? byId(String id) {
    for (final p in patriarchs) {
      if (p.id == id) return p;
    }
    return null;
  }

  static ChronologyData fromJson(Map<String, dynamic> j) {
    final meta = ((j['_meta'] as Map?) ?? const {}).cast<String, dynamic>();
    final checks = ((meta['checks'] as Map?) ?? const {}).cast<String, dynamic>();
    return ChronologyData(
      traditions: ((j['traditions'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ChronologyTradition.fromJson)
          .toList(),
      epochs: ((j['epochs'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ChronologyEpoch.fromJson)
          .toList(),
      notes: ((j['notes'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ChronologyNote.fromJson)
          .toList(),
      patriarchs: ((j['patriarchs'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Patriarch.fromJson)
          .toList(),
      unitNote: (meta['unitNote'] as String?) ?? '',
      traditionsNote: (meta['traditions'] as String?) ?? '',
      secondWitness: (checks['secondWitness'] as String?) ?? '',
      sumsChecked: (checks['sumsChecked'] as num?)?.toInt() ?? 0,
    );
  }
}

Map<String, String> _localised(Object? raw) => {
      for (final e in ((raw as Map?) ?? const {}).entries)
        if (e.value is String) e.key.toString(): e.value as String,
    };
