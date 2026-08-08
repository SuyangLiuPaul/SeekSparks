/// The kings of Judah and Israel on Thiele's chronology.
///
/// Backing data: `assets/hebrew_kings.json`, built by
/// `scripts/build_hebrew_kings.py`, which carries the citation for
/// every figure. Years are negative for BC, matching
/// `assets/bible_timeline.json` and `assets/family_tree.json`.
library;

enum Kingdom { united, judah, israel }

/// A reign is not one interval. Thiele's whole reconstruction turns on
/// reigns that run *alongside* each other, so a king carries a list of
/// spans rather than a single start and end:
///
///   [sole]       reigning alone
///   [coregency]  reigning with his father — six in Judah, one in
///                Israel, on Thiele's reckoning
///   [rival]      a contested parallel claim: Tibni against Omri, and
///                Pekah in Gilead against Menahem and Pekahiah
enum SpanKind { sole, coregency, rival }

class ReignSpan {
  const ReignSpan({required this.kind, required this.start, required this.end});

  final SpanKind kind;
  final int start;
  final int end;

  int get years => end - start;

  static ReignSpan fromJson(Map<String, dynamic> j) => ReignSpan(
        kind: switch (j['kind'] as String?) {
          'coregency' => SpanKind.coregency,
          'rival' => SpanKind.rival,
          _ => SpanKind.sole,
        },
        start: (j['start'] as num).toInt(),
        end: (j['end'] as num).toInt(),
      );
}

class HebrewKing {
  const HebrewKing({
    required this.id,
    required this.kingdom,
    required this.house,
    required this.names,
    required this.spans,
    required this.reignStart,
    required this.reignEnd,
    this.altNames,
    this.notes,
    this.kingsRef,
    this.chroniclesRef,
    this.accessionRef,
  });

  final String id;
  final Kingdom kingdom;

  /// Dynasty, given as the id of the king who founded it (`david`,
  /// `omri`, `jehu`…). Storing an id rather than a display string means
  /// "House of Omri" localises through the king's own name and adds no
  /// second translation surface to drift.
  final String house;

  final Map<String, String> names;
  final Map<String, String>? altNames;
  final Map<String, String>? notes;

  final List<ReignSpan> spans;
  final int reignStart;
  final int reignEnd;

  /// The passage in Kings, and — for Judah only — the parallel account
  /// in Chronicles. Chronicles tells the story of the southern kingdom,
  /// so [chroniclesRef] is null for every northern king. That absence
  /// is information, and the detail panel says so rather than hiding
  /// the row.
  final String? kingsRef;
  final String? chroniclesRef;

  /// The verse that dates this king's accession by the regnal year of
  /// his contemporary in the other kingdom — "in the twentieth year of
  /// Jeroboam king of Israel, Asa began to reign over Judah". These
  /// synchronisms are the raw material of Thiele's system, not
  /// decoration.
  final String? accessionRef;

  bool get isRival => spans.every((s) => s.kind == SpanKind.rival);

  ReignSpan? get soleReign {
    for (final s in spans) {
      if (s.kind == SpanKind.sole) return s;
    }
    return null;
  }

  ReignSpan? get overlapSpan {
    for (final s in spans) {
      if (s.kind != SpanKind.sole) return s;
    }
    return null;
  }

  int get totalYears => reignEnd - reignStart;

  String nameFor(String locale) =>
      names[locale] ?? names['en'] ?? id;

  String? altNameFor(String locale) =>
      altNames?[locale] ?? altNames?['en'];

  String? noteFor(String locale) => notes?[locale] ?? notes?['en'];

  static Map<String, String>? _strings(dynamic v) {
    if (v is! Map) return null;
    return {
      for (final e in v.entries)
        if (e.value is String) e.key.toString(): e.value as String,
    };
  }

  static HebrewKing fromJson(Map<String, dynamic> j) => HebrewKing(
        id: j['id'] as String,
        kingdom: switch (j['kingdom'] as String?) {
          'judah' => Kingdom.judah,
          'israel' => Kingdom.israel,
          _ => Kingdom.united,
        },
        house: (j['house'] as String?) ?? '',
        names: _strings(j['name']) ?? const {},
        altNames: _strings(j['altName']),
        notes: _strings(j['note']),
        spans: ((j['spans'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ReignSpan.fromJson)
            .toList(),
        reignStart: (j['reignStart'] as num).toInt(),
        reignEnd: (j['reignEnd'] as num).toInt(),
        kingsRef: j['kingsRef'] as String?,
        chroniclesRef: j['chroniclesRef'] as String?,
        accessionRef: j['accessionRef'] as String?,
      );
}

class KingsEpoch {
  const KingsEpoch({
    required this.id,
    required this.year,
    required this.names,
    this.ref,
  });

  final String id;
  final int year;
  final Map<String, String> names;
  final String? ref;

  String nameFor(String locale) => names[locale] ?? names['en'] ?? id;

  static KingsEpoch fromJson(Map<String, dynamic> j) => KingsEpoch(
        id: j['id'] as String,
        year: (j['year'] as num).toInt(),
        names: HebrewKing._strings(j['name']) ?? const {},
        ref: j['ref'] as String?,
      );
}

/// Two kings are contemporaries when their reigns share any year.
///
/// The comparison is over CLOSED intervals, and that is deliberate.
/// Ahaziah of Judah reigned only in 841 BC and Jehu of Israel came to
/// the throne in 841 BC — Jehu killed him — so a half-open test would
/// report the two men who met that year as never having overlapped.
/// Several reigns here are a single year or less (Zimri's seven days,
/// Shallum's month), and a half-open rule erases them.
bool reignsOverlap(HebrewKing a, HebrewKing b) =>
    a.reignStart <= b.reignEnd && b.reignStart <= a.reignEnd;
