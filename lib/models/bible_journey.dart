/// 2026-08-17 (SeekSparks): a journey overlay for the Atlas — an ordered
/// itinerary of stops, each one carrying the verse that puts it there.
///
/// **A route is an interpretation, and the schema is built to keep that
/// visible.** Scripture names the stops; it almost never names the road
/// between them. So nothing here stores a path, and nothing here stores a
/// coordinate: a stop is a *reference into the gazetteer*, which means a
/// route can never invent a location — the worst thing a map can do. If a
/// place is missing or unlocated, [resolveJourney] reports it rather than
/// drawing a guess.
///
/// Three fields exist only to stop the drawing from asserting more than
/// the text does:
///
///   * [JourneyStop.ref] — the verse. Every stop has one, and it is the
///     stop's warrant, not a decoration.
///   * [JourneyStop.leg] — how they reached THIS stop from the previous
///     one, taken from the verb the text uses. Acts distinguishes sailing
///     from going, and a line that drew Paphos→Perga the same way it drew
///     Lystra→Derbe would be flattening something the text is explicit
///     about.
///   * [JourneyStop.attested] — false where the text does not place the
///     travellers at the stop at all. Two of the shipped stops are false
///     and both say why on their own row; they are drawn provisionally
///     rather than dropped, because a reader comparing this against a
///     printed atlas needs to see where the printed atlas got its stop.
///
/// **A place may appear more than once.** These itineraries double back —
/// Paul's first journey touches Lystra twice and Syrian Antioch at both
/// ends — so the stop list is a sequence, never a set. Collapsing it to
/// unique places would silently delete the return leg, which is half of
/// Acts 14.
library;

/// How the travellers reached a stop from the one before it.
///
/// Read off the verb, not assumed: `ἀπέπλευσαν` (sailed away) gives
/// [sea], a verb of going gives [land], and [unknown] is used where the
/// text will not say — Berea to Athens, where 17:14 says only that the
/// brothers sent Paul "as far as the sea".
enum JourneyLeg {
  /// The first stop. Nothing precedes it, so no line is drawn into it.
  start,
  land,
  sea,
  unknown;

  static JourneyLeg parse(String? raw) => switch (raw) {
        'start' => JourneyLeg.start,
        'land' => JourneyLeg.land,
        'sea' => JourneyLeg.sea,
        _ => JourneyLeg.unknown,
      };
}

/// One stop on an itinerary.
class JourneyStop {
  const JourneyStop({
    required this.placeId,
    required this.englishBook,
    required this.chapter,
    required this.verse,
    required this.leg,
    required this.attested,
    required this.note,
  });

  /// The gazetteer key, ordinal included — `Antioch 1` is Syrian Antioch
  /// and `Antioch 2` is Pisidian. Both are on Paul's first journey, 500 km
  /// apart, so a route that dropped the ordinal would draw a nonsense.
  final String placeId;

  final String englishBook;
  final int chapter;
  final int verse;

  final JourneyLeg leg;

  /// Whether the text places the travellers HERE. False is a real
  /// verdict, not missing data, and [note] carries the reason.
  final bool attested;

  /// Localised, keyed as `en` / `zh-Hans` / `zh-Hant`. Present only where
  /// there is something to say — an ambiguity, a mode the text refuses to
  /// give, a region crossed with no town named.
  final Map<String, String>? note;

  String get reference => '$englishBook $chapter:$verse';

  String? localizedNote(String locale) =>
      note == null ? null : (note![locale] ?? note!['en']);
}

/// One journey: a name, the passage it is read out of, and its stops.
class BibleJourney {
  const BibleJourney({
    required this.id,
    required this.style,
    required this.name,
    required this.range,
    required this.basis,
    required this.stops,
  });

  final String id;

  /// Which slot in the drawing palette this route takes. In the DATA
  /// rather than derived from list position so that adding a journey in
  /// the middle of the file cannot silently recolour the ones after it —
  /// a reader who has learned that the first journey is amber should not
  /// find it green after an update.
  final int style;

  final Map<String, String> name;
  final Map<String, String> range;

  /// Where the itinerary comes from and what is provisional in it. The
  /// per-route half of provenance; the standing caution that a line is
  /// not a road is the same for every route and lives in `ui_strings`.
  final Map<String, String> basis;

  final List<JourneyStop> stops;

  String localizedName(String locale) => name[locale] ?? name['en'] ?? id;
  String localizedRange(String locale) => range[locale] ?? range['en'] ?? '';
  String localizedBasis(String locale) => basis[locale] ?? basis['en'] ?? '';

  /// Stops the text does not actually place the travellers at.
  int get provisionalCount => stops.where((s) => !s.attested).length;
}

/// Read the journeys document.
///
/// Silently skips a malformed journey rather than throwing: this asset is
/// hand-maintained, and one bad entry should cost one route, not the
/// Atlas. `test/journey_asset_test.dart` is what makes the skipping safe
/// — it fails the build if a stop does not resolve, so a typo cannot
/// reach a reader as a quietly missing route.
List<BibleJourney> parseJourneys(Map<String, dynamic> doc) {
  final out = <BibleJourney>[];
  for (final raw in (doc['journeys'] as List<dynamic>? ?? const <dynamic>[])) {
    if (raw is! Map<String, dynamic>) continue;
    final id = (raw['id'] as String?)?.trim();
    if (id == null || id.isEmpty) continue;

    final stops = <JourneyStop>[];
    for (final s in (raw['stops'] as List<dynamic>? ?? const <dynamic>[])) {
      if (s is! Map<String, dynamic>) continue;
      final place = (s['place'] as String?)?.trim();
      final chapter = (s['chapter'] as num?)?.toInt();
      final verse = (s['verse'] as num?)?.toInt();
      final book = (s['book'] as String?)?.trim();
      if (place == null || place.isEmpty || chapter == null ||
          verse == null || book == null || book.isEmpty) {
        continue;
      }
      stops.add(JourneyStop(
        placeId: place,
        englishBook: book,
        chapter: chapter,
        verse: verse,
        leg: JourneyLeg.parse(s['leg'] as String?),
        // Absent means attested. The asset only writes the field where
        // the answer is the surprising one, so the common case cannot be
        // got wrong by omission.
        attested: (s['attested'] as bool?) ?? true,
        note: _strings(s['note']),
      ));
    }
    if (stops.isEmpty) continue;

    out.add(BibleJourney(
      id: id,
      style: (raw['style'] as num?)?.toInt() ?? out.length,
      name: _strings(raw['name']) ?? <String, String>{'en': id},
      range: _strings(raw['range']) ?? const <String, String>{},
      basis: _strings(raw['basis']) ?? const <String, String>{},
      stops: stops,
    ));
  }
  return out;
}

Map<String, String>? _strings(Object? raw) {
  if (raw is! Map) return null;
  final out = <String, String>{};
  raw.forEach((k, v) {
    if (k is String && v is String) out[k] = v;
  });
  return out.isEmpty ? null : out;
}
