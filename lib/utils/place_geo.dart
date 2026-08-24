/// 2026-08-08 (SeekSparks): the geometry and the data repair behind the
/// Places tab and the map. Pure — no Flutter, no asset loading — so the
/// parts that are easy to get quietly wrong are the parts under test.
///
/// Two separate jobs live here because both are prerequisites for
/// drawing a place on a map and neither belongs in a widget:
///
///   1. **Repairing `assets/bible_places.json`.** The gazetteer is good
///      data that went through a bad transform. A global case-replace of
///      the substring `eph` ran over the whole file, which is provable
///      from the wreckage it left in two different fields: eleven place
///      names carry a capital mid-word (`Baal-zEphon`, `Kiriath-sEpher`,
///      `HakkEphirim`), and eight book codes are truncated (`eph`, `ccl`,
///      `hil`, `ude`, `tus`, `hum`, `nah`, `Hah`). The codes matter far
///      more than the names: a reference filed under an unknown book is
///      a reference that never reaches the reader.
///
///   2. **Projecting latitude/longitude onto a pane.** Equirectangular
///      with a standard parallel — see [MapProjection] for why that is
///      the right projection for this map and not merely the easy one.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

// ---------------------------------------------------------------------------
// Book codes
// ---------------------------------------------------------------------------

/// The gazetteer's three-letter book codes, mapped to the canonical
/// English book names the rest of the app indexes on.
///
/// Eight of these are damaged, and they are marked below. They were not
/// guessed: every corrected code was checked against the bundled KJV by
/// confirming (a) that each of its references resolves to a verse that
/// actually exists in the proposed book, and (b) that the place named is
/// present in that verse's text. `nah` is the one that would have been
/// easy to get wrong — it reads like Nahum and it is **Jonah**, because
/// its references are Nineveh 1:2 and Joppa 1:3.
const Map<String, String> kPlaceBookCodes = <String, String>{
  'Gen': 'Genesis',
  'Exo': 'Exodus',
  'Lev': 'Leviticus',
  'Num': 'Numbers',
  'Deu': 'Deuteronomy',
  'Jos': 'Joshua',
  'Jdg': 'Judges',
  'Rut': 'Ruth',
  '1Sa': '1 Samuel',
  '2Sa': '2 Samuel',
  '1Ki': '1 Kings',
  '2Ki': '2 Kings',
  '1Ch': '1 Chronicles',
  '2Ch': '2 Chronicles',
  'Ezr': 'Ezra',
  'Neh': 'Nehemiah',
  'Est': 'Esther',
  'Job': 'Job',
  'Psa': 'Psalms',
  'Pro': 'Proverbs',
  'Ecc': 'Ecclesiastes',
  'Sng': 'Song of Solomon',
  'Isa': 'Isaiah',
  'Jer': 'Jeremiah',
  'Lam': 'Lamentations',
  'Eze': 'Ezekiel',
  'Dan': 'Daniel',
  'Hos': 'Hosea',
  'Joe': 'Joel',
  'Amo': 'Amos',
  'Oba': 'Obadiah',
  'Jon': 'Jonah',
  'Mic': 'Micah',
  'Nam': 'Nahum',
  'Hab': 'Habakkuk',
  'Zep': 'Zephaniah',
  'Hag': 'Haggai',
  'Zec': 'Zechariah',
  'Mal': 'Malachi',
  'Mat': 'Matthew',
  'Mar': 'Mark',
  'Luk': 'Luke',
  'Joh': 'John',
  'Act': 'Acts',
  'Rom': 'Romans',
  '1Co': '1 Corinthians',
  '2Co': '2 Corinthians',
  'Gal': 'Galatians',
  'Eph': 'Ephesians',
  'Php': 'Philippians',
  'Col': 'Colossians',
  '1Th': '1 Thessalonians',
  '2Th': '2 Thessalonians',
  '1Ti': '1 Timothy',
  '2Ti': '2 Timothy',
  'Tit': 'Titus',
  'Phm': 'Philemon',
  'Heb': 'Hebrews',
  'Jas': 'James',
  '1Pe': '1 Peter',
  '2Pe': '2 Peter',
  '1Jo': '1 John',
  '2Jo': '2 John',
  '3Jo': '3 John',
  'Jud': 'Jude',
  'Rev': 'Revelation',

  // Damaged by the `eph` case-replace. Verified against the bundled KJV,
  // reference by reference, before being written down here.
  'eph': 'Zephaniah', //  26 refs — Ashkelon 2:4, Assyria 2:13
  'hum': 'Nahum', //      13 refs — Bashan 1:4, Carmel 1:4
  'nah': 'Jonah', //      11 refs — Nineveh 1:2, Joppa 1:3
  'ccl': 'Ecclesiastes', // 10 refs — Jerusalem 1:1, 1:12, 1:16
  'ude': 'Jude', //         4 refs — Gomorrah 1:7
  'hil': 'Philippians', //  3 refs — Philippi 1:1, Thessalonica 4:16
  'tus': 'Titus', //        1 ref  — Crete 1:5
  'Hah': 'Nahum', //        1 ref  — Elkosh 1:1, which is Nahum's town
};

/// The canonical English book name for a gazetteer code, or null.
///
/// Null is deliberate and must stay reachable: an unrecognised code is
/// dropped rather than guessed at. A misfiled scripture reference is
/// worse than a missing one, because the reader has no way to see that
/// it is wrong.
String? bookForPlaceCode(String code) => kPlaceBookCodes[code];

// ---------------------------------------------------------------------------
// Names
// ---------------------------------------------------------------------------

final RegExp _midWordCapital = RegExp(r'(?<=[a-z])([A-Z])');
final RegExp _ordinalSuffix = RegExp(r'\s+(\d+)$');

/// The same damage where the letter before it is the name's own initial.
///
/// 2026-08-24 (#317): the general rule below could not reach four names,
/// because it requires a LOWERCASE letter in front and these have the
/// capital in the second position — `Rephidim` is `R` + `eph` + `idim`,
/// so the substitution landed at index 1 and left `REphidim`. Four
/// entries shipped their English name mangled, and one of them is a stop
/// on the wilderness itinerary, which is how it was found.
///
/// Deliberately narrower than "lower any capital after a letter": it
/// fires only on the `Eph` that the documented `eph` → `Eph` substitution
/// produced. The gazetteer holds two further mid-word capitals, `BEze 1`
/// and `BEze 2`, and they are NOT this damage — no `eph` is involved, and
/// their verses (Jdg 1:4-5, 1Sa 11:8) name Bezek, so the entry has lost a
/// final letter as well as gained a capital. Lowering it to `Beze` would
/// turn an obviously broken string into a plausible one that is still
/// wrong, which is the worse of the two. Left as it is and recorded in
/// `docs/DATA-INTEGRITY.md`.
final RegExp _initialEph = RegExp(r'(?<=[A-Za-z])E(?=ph)');

/// Undo the `eph` → `Eph` capitalisation in the names it hit.
///
/// Stated as a general rule — a capital that directly follows a
/// lowercase letter is lowered — rather than as a list of
/// corrections, because the rule is what is actually true of biblical
/// transliteration: no name in this gazetteer legitimately capitalises
/// mid-word. Hyphens and spaces are word boundaries and are untouched,
/// so `Baal-Hazor` and `Beth-El` keep their capitals.
String repairPlaceName(String raw) => raw
    .replaceAllMapped(_midWordCapital, (m) => m[1]!.toLowerCase())
    .replaceAll(_initialEph, 'e');

/// Split `Antioch 2` into `('Antioch', 2)`.
///
/// The trailing numeral is not noise to be stripped. 177 entries carry
/// one and it is the gazetteer's way of saying "a different place with
/// the same name" — `Antioch 1` is Syrian Antioch and `Antioch 2` is
/// Pisidian Antioch, 500 km apart and in different provinces. Losing it
/// would silently merge them.
(String, int?) splitPlaceOrdinal(String name) {
  final m = _ordinalSuffix.firstMatch(name);
  if (m == null) return (name, null);
  return (name.substring(0, m.start), int.tryParse(m[1]!));
}

// ---------------------------------------------------------------------------
// Geometry
// ---------------------------------------------------------------------------

const double _earthRadiusKm = 6371.0088;

double _rad(double deg) => deg * math.pi / 180.0;

/// Great-circle distance in kilometres.
///
/// The map's whole claim over a list is that it shows how far apart
/// things are, so the number under it has to be a real distance and not
/// a ruler held against a projection.
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return 2 * _earthRadiusKm * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// A latitude/longitude rectangle.
class GeoBounds {
  const GeoBounds(this.minLat, this.minLon, this.maxLat, this.maxLon);

  final double minLat;
  final double minLon;
  final double maxLat;
  final double maxLon;

  double get centreLat => (minLat + maxLat) / 2;
  double get centreLon => (minLon + maxLon) / 2;
  double get spanLat => maxLat - minLat;
  double get spanLon => maxLon - minLon;

  /// Grow by [degrees] on every side, then guarantee a minimum span.
  ///
  /// The minimum is what stops a single-place passage — and there are
  /// 565 places with exactly one reference — from projecting at infinite
  /// zoom, where the base map is one featureless polygon and the reader
  /// learns nothing.
  GeoBounds padded({double degrees = 0.35, double minSpan = 1.2}) {
    var lo = GeoBounds(
        minLat - degrees, minLon - degrees, maxLat + degrees, maxLon + degrees);
    if (lo.spanLat < minSpan) {
      final c = lo.centreLat;
      lo = GeoBounds(c - minSpan / 2, lo.minLon, c + minSpan / 2, lo.maxLon);
    }
    if (lo.spanLon < minSpan) {
      final c = lo.centreLon;
      lo = GeoBounds(lo.minLat, c - minSpan / 2, lo.maxLat, c + minSpan / 2);
    }
    return lo;
  }
}

/// The bounding box of some coordinates, or null if there are none.
GeoBounds? boundsOf(Iterable<(double, double)> latLon) {
  double? minLa, minLo, maxLa, maxLo;
  for (final (la, lo) in latLon) {
    minLa = minLa == null ? la : math.min(minLa, la);
    maxLa = maxLa == null ? la : math.max(maxLa, la);
    minLo = minLo == null ? lo : math.min(minLo, lo);
    maxLo = maxLo == null ? lo : math.max(maxLo, lo);
  }
  if (minLa == null) return null;
  return GeoBounds(minLa, minLo!, maxLa!, maxLo!);
}

/// Equirectangular projection with a standard parallel.
///
/// Chosen, not defaulted to. A plain lat/lon-to-x/y plot stretches the
/// biblical world east-west by about 18% at Jerusalem's latitude, which
/// is enough to make the Jordan valley look wrong to anyone who has seen
/// a map of it. Scaling longitude by cos(standard parallel) removes that
/// at the one latitude that matters and leaves a small, predictable
/// error elsewhere — the same trade every printed Bible atlas makes.
///
/// A conformal projection would be more correct and would also mean the
/// scale bar stops being a single number, which for a study map that is
/// mostly read at Levant scale is a worse deal.
class MapProjection {
  MapProjection({
    required this.centreLat,
    required this.centreLon,
    required this.pixelsPerDegreeLat,
    required this.size,
    double? standardParallel,
  }) : standardParallel = standardParallel ?? centreLat;

  final double centreLat;
  final double centreLon;

  /// Vertical scale. Horizontal is this times cos([standardParallel]).
  final double pixelsPerDegreeLat;

  final Size size;
  final double standardParallel;

  double get _lonScale =>
      pixelsPerDegreeLat * math.cos(_rad(standardParallel)).clamp(0.05, 1.0);

  Offset project(double lat, double lon) => Offset(
        size.width / 2 + (lon - centreLon) * _lonScale,
        size.height / 2 - (lat - centreLat) * pixelsPerDegreeLat,
      );

  /// Screen point back to latitude/longitude — hit-testing a tap.
  (double, double) unproject(Offset p) => (
        centreLat - (p.dy - size.height / 2) / pixelsPerDegreeLat,
        centreLon + (p.dx - size.width / 2) / _lonScale,
      );

  /// Kilometres per horizontal pixel at the standard parallel. Drives
  /// the scale bar.
  double get kmPerPixel =>
      haversineKm(standardParallel, 0, standardParallel, 1) / _lonScale;

  /// The projection that shows [bounds] inside [size].
  ///
  /// Fits on whichever axis is tighter, so the requested area is always
  /// fully visible rather than cropped on one side.
  static MapProjection fit(GeoBounds bounds, Size size, {double inset = 18}) {
    final w = math.max(size.width - inset * 2, 1.0);
    final h = math.max(size.height - inset * 2, 1.0);
    final parallel = bounds.centreLat;
    final lonFactor = math.cos(_rad(parallel)).clamp(0.05, 1.0);
    final byLat = h / math.max(bounds.spanLat, 1e-6);
    final byLon = w / math.max(bounds.spanLon * lonFactor, 1e-6);
    return MapProjection(
      centreLat: bounds.centreLat,
      centreLon: bounds.centreLon,
      pixelsPerDegreeLat: math.min(byLat, byLon),
      size: size,
      standardParallel: parallel,
    );
  }

  MapProjection copyWith({
    double? centreLat,
    double? centreLon,
    double? pixelsPerDegreeLat,
    Size? size,
  }) =>
      MapProjection(
        centreLat: centreLat ?? this.centreLat,
        centreLon: centreLon ?? this.centreLon,
        pixelsPerDegreeLat: pixelsPerDegreeLat ?? this.pixelsPerDegreeLat,
        size: size ?? this.size,
        standardParallel: standardParallel,
      );
}

// ---------------------------------------------------------------------------
// The base map
// ---------------------------------------------------------------------------

/// Coastlines, lakes, rivers and land, as flat `[lon, lat, lon, lat, …]`
/// runs.
///
/// Flat lists of doubles rather than a list of point objects because a
/// painter walks all 8,178 points on every frame, and allocating an
/// object per point to do it is the difference between a map that pans
/// smoothly and one that does not.
class BaseMap {
  const BaseMap({
    required this.land,
    required this.coast,
    required this.lakes,
    required this.rivers,
  });

  const BaseMap.empty()
      : land = const <List<double>>[],
        coast = const <List<double>>[],
        lakes = const <List<double>>[],
        rivers = const <List<double>>[];

  /// Filled. Drawn first, as the ground everything else sits on.
  final List<List<double>> land;

  /// Stroked. The coastline over the land fill, so the edge stays crisp
  /// at every zoom.
  final List<List<double>> coast;

  /// Filled — the Sea of Galilee, the Dead Sea, the Nile delta lakes.
  final List<List<double>> lakes;

  /// Stroked. The Jordan, the Nile, the Euphrates and the Tigris: the
  /// rivers scripture actually names.
  final List<List<double>> rivers;

  bool get isEmpty =>
      land.isEmpty && coast.isEmpty && lakes.isEmpty && rivers.isEmpty;
}

List<List<double>> _runs(dynamic v) => <List<double>>[
      for (final run in (v as List<dynamic>? ?? const <dynamic>[]))
        if (run is List && run.length >= 4)
          <double>[for (final n in run) (n as num).toDouble()],
    ];

/// Read `assets/bible_geo.json`.
BaseMap parseBaseMap(Map<String, dynamic> doc) => BaseMap(
      land: _runs(doc['land']),
      coast: _runs(doc['coast']),
      lakes: _runs(doc['lakes']),
      rivers: _runs(doc['rivers']),
    );

/// Days on foot for a distance in kilometres.
///
/// BibleWorks' ruler converts a drawn distance into a travel time
/// (bwh33, the Travel Speed Window) and the idea is worth borrowing
/// wholesale: "Nineveh is 1,100 km from Joppa" means very little, and
/// "about seven weeks' walk in the wrong direction" means a great deal.
///
/// 32 km/day is the conventional figure for a party travelling on foot
/// over the terrain of the Levant. BibleWorks computes a min/max pair
/// instead — distance ÷ speed ÷ hours-per-day at both ends of two
/// reader-set ranges — which is more honest and needs a settings window
/// this does not have. A single rounded figure captioned "about" is
/// what fits beside a scale bar, and the caption does the hedging.
int daysOnFootFor(double km) => (km / 32.0).ceil().clamp(1, 100000);

/// The largest round number of kilometres that fits in [targetPx].
///
/// 1-2-5 steps, so the bar reads "50 km" rather than "63 km".
///
/// Largest that *fits*, not nearest: [targetPx] is the space the bar has
/// been given, and a bar drawn to a value above the target overruns that
/// space. 63 km of room therefore reads 50, not 100. `1 * mag` is always
/// at or below `raw` by construction, so the loop cannot fall through.
double niceScaleKm(double kmPerPixel, double targetPx) {
  final raw = kmPerPixel * targetPx;
  if (raw <= 0 || !raw.isFinite) return 1;
  var mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  // `log(1000) / ln10` is 2.9999999999999996, which floors a whole decade
  // low and would make a 1000 km bar read 500. Correct it by comparison
  // rather than by trusting the logarithm.
  if (mag * 10 <= raw) mag *= 10;
  if (mag > raw) mag /= 10;
  var best = mag;
  for (final step in const [1.0, 2.0, 5.0]) {
    if (step * mag <= raw) best = step * mag;
  }
  return best;
}
