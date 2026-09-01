/// 2026-08-08 (SeekSparks): a place in the biblical gazetteer.
library;

import 'package:seeksparks/constants/book_name_mapping.dart' show BookScript;
import 'package:seeksparks/utils/place_geo.dart';

/// One scripture reference on a place, already resolved to the canonical
/// English book name the rest of the app indexes on.
class PlaceRef {
  const PlaceRef(this.englishBook, this.chapter, this.verse);

  final String englishBook;
  final int chapter;
  final int verse;

  String get key => '$englishBook|$chapter|$verse';

  @override
  bool operator ==(Object other) =>
      other is PlaceRef &&
      other.englishBook == englishBook &&
      other.chapter == chapter &&
      other.verse == verse;

  @override
  int get hashCode => Object.hash(englishBook, chapter, verse);
}

/// A named place, its coordinates if anyone knows them, and every verse
/// that names it.
class BiblePlace {
  const BiblePlace({
    required this.id,
    required this.name,
    required this.ordinal,
    required this.simplified,
    required this.traditional,
    required this.lat,
    required this.lon,
    required this.refs,
  });

  /// The gazetteer's own key, ordinal included (`Antioch 2`). Stable
  /// across sessions, so it is what gets persisted and passed around.
  final String id;

  /// Display name, ordinal stripped and the `eph` damage repaired.
  final String name;

  /// The disambiguating numeral, when the gazetteer supplied one. See
  /// [splitPlaceOrdinal] — it separates two genuinely different cities
  /// that share a name.
  final int? ordinal;

  final String? simplified;
  final String? traditional;

  /// Null for the 43 places nobody has identified on the ground.
  ///
  /// Not a data gap to be papered over: Eden, Nod, Pishon and the Gihon
  /// are unlocated because their location is genuinely unknown, and a
  /// study tool that invented coordinates for them would be lying. The
  /// UI lists them and says so.
  final double? lat;
  final double? lon;

  final List<PlaceRef> refs;

  bool get located => lat != null && lon != null;

  /// The name to print, following the reading version's script.
  ///
  /// Same rule as book names (task #283): the script follows the text on
  /// screen, so a reader in CUVS gets 耶路撒冷 next to 耶路撒冷. Falls
  /// back to English where the gazetteer has no Chinese name — three
  /// entries do not.
  String displayName(BookScript script) => switch (script) {
        BookScript.english => name,
        BookScript.traditional => traditional ?? simplified ?? name,
        BookScript.simplified => simplified ?? traditional ?? name,
      };

  /// Kilometres to another place, or null if either is unlocated.
  double? distanceKmTo(BiblePlace other) =>
      (located && other.located) ? haversineKm(lat!, lon!, other.lat!, other.lon!) : null;
}

/// Read the gazetteer document into repaired [BiblePlace]s.
///
/// Every repair `place_geo.dart` documents is applied here, in one place,
/// so no caller can accidentally index the raw form: the `eph`
/// case-replace is undone in the names, the eight damaged book codes are
/// resolved, unknown codes are dropped rather than guessed at, the
/// disambiguating ordinal is split out, and the six possessive entries
/// are folded into their base city, and the five ordinal pairs that differ
/// in no field at all are folded into the lower ordinal.
List<BiblePlace> parseGazetteer(Map<String, dynamic> doc) {
  final rows = (doc['places'] as List<dynamic>? ?? const <dynamic>[]);
  final out = <BiblePlace>[];

  for (final row in rows) {
    if (row is! Map<String, dynamic>) continue;
    final raw = (row['n'] as String?)?.trim() ?? '';
    if (raw.isEmpty) continue;

    final id = repairPlaceName(raw);
    final (name, ordinal) = splitPlaceOrdinal(id);

    final ll = row['ll'];
    double? lat, lon;
    if (ll is List && ll.length >= 2) {
      lat = (ll[0] as num?)?.toDouble();
      lon = (ll[1] as num?)?.toDouble();
    }

    final refs = <PlaceRef>[];
    for (final r in (row['refs'] as List<dynamic>? ?? const <dynamic>[])) {
      if (r is! Map<String, dynamic>) continue;
      final book = bookForPlaceCode((r['book'] as String?) ?? '');
      final chapter = (r['chapter'] as num?)?.toInt();
      final verse = (r['verse'] as num?)?.toInt();
      // An unrecognised code is dropped, not guessed at — a reference
      // filed under the wrong book is worse than a missing one, because
      // the reader has no way to see that it is wrong.
      if (book == null || chapter == null || verse == null) continue;
      refs.add(PlaceRef(book, chapter, verse));
    }

    out.add(BiblePlace(
      id: id,
      name: name,
      ordinal: ordinal,
      simplified: (row['s'] as String?)?.trim(),
      traditional: (row['t'] as String?)?.trim(),
      lat: lat,
      lon: lon,
      refs: refs,
    ));
  }

  return mergeIdenticalPlaces(mergePossessives(out));
}

/// Fold `Jerusalem's` into `Jerusalem`.
///
/// The gazetteer indexes six possessive forms as separate places, all
/// sharing their base's coordinates. `Jerusalem's` carries a byte-identical
/// reference list to `Jerusalem`, so left alone it would print the same
/// city twice in every list of what a verse mentions. The refs are unioned
/// rather than dropped because `Egypt's` is *not* identical to `Egypt` —
/// it holds three references the base entry lacks.
///
/// `Solomon's` survives the merge and should: it is 所罗门廊, Solomon's
/// Porch, and there is no base entry called `Solomon` because Solomon is
/// a person.
List<BiblePlace> mergePossessives(List<BiblePlace> places) {
  final byId = <String, BiblePlace>{for (final p in places) p.id: p};
  final absorbed = <String>{};
  final extra = <String, List<PlaceRef>>{};

  for (final p in places) {
    if (!p.id.endsWith("'s")) continue;
    final base = p.id.substring(0, p.id.length - 2);
    if (!byId.containsKey(base)) continue;
    absorbed.add(p.id);
    (extra[base] ??= <PlaceRef>[]).addAll(p.refs);
  }

  if (absorbed.isEmpty) return places;

  return <BiblePlace>[
    for (final p in places)
      if (!absorbed.contains(p.id))
        if (extra[p.id] == null)
          p
        else
          BiblePlace(
            id: p.id,
            name: p.name,
            ordinal: p.ordinal,
            simplified: p.simplified,
            traditional: p.traditional,
            lat: p.lat,
            lon: p.lon,
            refs: <PlaceRef>{...p.refs, ...extra[p.id]!}.toList()
              ..sort((a, b) => a.key.compareTo(b.key)),
          ),
  ];
}

/// Fold an ordinal pair that differs in no field at all.
///
/// The gazetteer's ordinal usually separates two genuinely different cities
/// that share a name — `Antioch 1` is Syrian, `Antioch 2` Pisidian — and
/// `atlas_index_test.dart`'s check 38 pins the fact that 66 of its 80
/// ordinal groups nonetheless carry byte-identical reference lists, because
/// the source never partitioned the verses. **That is a gap to disclose,
/// not to merge:** Antioch's two entries sit at different coordinates, so
/// something real is being distinguished even though our references cannot
/// see it.
///
/// Five groups go further and agree on *everything* — name, both Chinese
/// scripts, coordinate, and every reference: `Baalath`, `Cabul`,
/// `Chinnereth`, `Jezreel` (its 2 and 3, not the ordinal-less Judean town)
/// and `Zin`. Two records carrying one place's worth of information are one
/// place. Left alone they put 巴拉 twice in Joshua 19:44's list and stack
/// two markers on one point, which is exactly the defect `mergePossessives`
/// above exists to prevent — the same fault arriving by a second route.
///
/// The **lower** ordinal survives, keeping its id, so `Jezreel 2` — cited by
/// id as a stop on Elijah's journey in `bible_journeys.json`, whose own
/// basis note says "the ordinal is load-bearing" — is the record that
/// remains. The ordinal is deliberately NOT stripped from the survivor: it
/// records that the gazetteer filed more than one, and dropping it would
/// move check 38's pinned group count, which measures the DATA and must not
/// move because our merge policy changed.
List<BiblePlace> mergeIdenticalPlaces(List<BiblePlace> places) {
  String key(BiblePlace p) => '${p.name}|${p.lat}|${p.lon}|'
      '${p.simplified}|${p.traditional}|'
      '${(<String>[for (final r in p.refs) r.key]..sort()).join(',')}';

  final groups = <String, List<BiblePlace>>{};
  for (final p in places) {
    (groups[key(p)] ??= <BiblePlace>[]).add(p);
  }

  final absorbed = <String>{};
  for (final members in groups.values) {
    if (members.length < 2) continue;
    // Lowest ordinal wins; an ordinal-less member would sort first and
    // win, which is right — it is the least qualified name for a place
    // nothing distinguishes.
    final sorted = <BiblePlace>[...members]
      ..sort((a, b) => (a.ordinal ?? -1).compareTo(b.ordinal ?? -1));
    for (final p in sorted.skip(1)) {
      absorbed.add(p.id);
    }
  }

  if (absorbed.isEmpty) return places;
  return <BiblePlace>[
    for (final p in places)
      if (!absorbed.contains(p.id)) p,
  ];
}
