/// 2026-08-26 (SeekSparks): turning a distance into a time on the road.
///
/// BibleWorks' ruler does this and it is worth borrowing: "Nineveh is
/// 1,100 km from Joppa" means very little, and "about seven weeks' walk in
/// the wrong direction" means a great deal. Its Travel Speed Window
/// (bwh33) converts a drawn distance into a MIN AND A MAX — distance ÷
/// speed ÷ hours-per-day at both ends of two reader-set ranges — and the
/// pair, not the point, is the part worth copying.
///
/// This file exists because the app had it exactly backwards. It printed
/// one confident figure, `ceil(km / 32)`, beside two arbitrary points
/// picked off the gazetteer with a ruler, and printed NOTHING on the
/// journeys, where every leg carries the mode of travel the text itself
/// uses. It estimated where it knew least and refused where it knew most.
///
/// **The band, and where both ends come from.** ORBIS: The Stanford
/// Geospatial Network Model of the Roman World (Scheidel, Meeks and
/// Weiland, Stanford University, v1.0 documentation, May 2012) sets its
/// land speeds in one sentence: "Mean daily travel distances have been set
/// at 12 kilometers per day for ox carts, 20km/day for porters or heavily
/// loaded mules, 30km/day for foot travelers including armies on the
/// march, pack animals with moderate loads, mule carts, and camel
/// caravans, 36km/day for routine private vehicular travel with convenient
/// rest stops". Both of our numbers are people walking in that sentence,
/// so the band is one citation wide rather than two authorities stitched
/// together. **It is a band of LOAD, not of pace**: 30 is a party on the
/// march, 20 is a party carrying its own baggage. Saying it the other way
/// — "slow walker to fast walker" — would misdescribe the source.
///
/// **32 was not folklore; it was the other convention, and scripture
/// decides between them.** The figure this replaces is almost certainly
/// ISBE's day's journey, 32–40 km, and that is a real published number —
/// but it is derived from a pack mule at three miles an hour for eight
/// hours, where ORBIS's are mean daily distances actually sustained over
/// multi-day journeys, which is the quantity a journey of dozens of days
/// needs. That is an argument from method, and this app can do better than
/// an argument from method, because the text prices one stretch of country
/// in days itself. Deuteronomy 1:2 gives eleven days from Horeb to
/// Kadesh-barnea; our gazetteer puts 244 km between them. The ISBE
/// convention makes that 7–8 days and so contradicts the verse; ORBIS
/// makes it 9–13 and contains it. `travel_time_test.dart` holds both
/// arithmetics so the choice cannot quietly be reversed.
///
/// Note what that also says about what shipped: `ceil(km / 32)` would have
/// answered "about 8 days" for a stretch scripture calls eleven. And since
/// 32 is above the top of this band, the old figure was never the midpoint
/// its "about" implied — it was a floor wearing an estimate's clothes.
/// Both ends here are floors too, for a second and independent reason —
/// see below — but they are floors that say so.
///
/// **Every distance we can compute is a chord.** A route stores gazetteer
/// ids and the map joins them with great circles, so the kilometres going
/// into these functions are the shortest line a bird could take between
/// two points. Roads bend, passes are where the mountains allow, and
/// ORBIS's own land network is a road graph. So the real journey is always
/// at least this long and the day counts are always at least this many.
/// The strings say so; this is not a caveat that can be dropped when it
/// gets inconvenient.
///
/// **Days on the road, not elapsed time.** Acts 18:11 has Paul at Corinth
/// for eighteen months, and Acts 19:10 gives two years in the hall of
/// Tyrannus at Ephesus while Acts 20:31 puts the whole stay at three. The
/// elapsed span of the second and third journeys is dominated by stays,
/// not by walking, and a reader who reads "63–94 days" as the length of
/// the journey has been misled by us. The strings name the unit.
///
/// **Sea legs get no number at all, on purpose.** See [JourneyTravel].
library;

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/bible_journey.dart';
import 'package:seeksparks/utils/journey_route.dart';

/// A day's walk for an unencumbered party, ORBIS's "foot travelers
/// including armies on the march". The fast end, so it yields the FEWEST
/// days.
const double kFootFastKmPerDay = 30.0;

/// A day's walk for "porters" — a party carrying its own loads. The slow
/// end, so it yields the MOST days.
const double kFootSlowKmPerDay = 20.0;

/// A pace the reader can choose, both ends quoted from ORBIS's one
/// sentence about land speeds.
///
/// **Three bands, not a text box.** BibleWorks' Travel Speed Window
/// (bwh33) lets a reader type any speed and any hours-per-day, and
/// copying that would have cost the only thing that makes this estimate
/// worth printing: every figure here is a QUOTATION. `travelDaysBasis`
/// prints ORBIS beside the number, and a reader-typed speed would leave
/// that citation vouching for an arithmetic it never made. So the choice
/// offered is a choice BETWEEN ORBIS's own categories — the sentence
/// gives four daily distances and these are its three adjacent pairs.
class TravelBand {
  const TravelBand({
    required this.id,
    required this.slowKmPerDay,
    required this.fastKmPerDay,
  });

  /// Stable, and the suffix of this band's `ui_strings` keys.
  final String id;

  /// The ORBIS figure that yields the MOST days.
  final double slowKmPerDay;

  /// The ORBIS figure that yields the FEWEST days.
  final double fastKmPerDay;

  /// The `ui_strings` key naming this band on the control.
  String get labelKey => 'travelBand${_cap(id)}';

  /// The `ui_strings` key for the citation printed under the estimate.
  String get basisKey =>
      this == kBandOnFoot ? 'travelDaysBasis' : 'travelDaysBasis${_cap(id)}';

  static String _cap(String s) => s[0].toUpperCase() + s.substring(1);

  @override
  bool operator ==(Object other) => other is TravelBand && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// ORBIS's "ox carts" up to its "porters or heavily loaded mules".
const TravelBand kBandCarts =
    TravelBand(id: 'carts', slowKmPerDay: 12.0, fastKmPerDay: 20.0);

/// ORBIS's "porters or heavily loaded mules" up to its "foot travelers
/// including armies on the march".
///
/// **The default, and not arbitrarily.** Deuteronomy 1:2 gives eleven
/// days from Horeb to Kadesh-barnea; our own gazetteer puts 244.3 km
/// between them. This band makes that 9–13 days and so contains the
/// verse. The other two do not — carts give 13–21 and vehicular travel
/// 7–9 — which is why they are offered as the reader's estimate and this
/// one is offered as ours. `travel_time_test.dart` pins all three.
const TravelBand kBandOnFoot =
    TravelBand(id: 'onFoot', slowKmPerDay: 20.0, fastKmPerDay: 30.0);

/// ORBIS's "foot travelers including armies on the march" up to its
/// "routine private vehicular travel with convenient rest stops".
const TravelBand kBandVehicle =
    TravelBand(id: 'vehicle', slowKmPerDay: 30.0, fastKmPerDay: 36.0);

/// Slowest first, so the control reads as a scale rather than a menu.
const List<TravelBand> kTravelBands = [kBandCarts, kBandOnFoot, kBandVehicle];

const TravelBand kDefaultTravelBand = kBandOnFoot;

/// A number of days as a range, because a single number would be a claim
/// we cannot support.
class TravelDays {
  const TravelDays(this.fewest, this.most);

  /// At [kFootFastKmPerDay], rounded up. A part-day on the road is a day.
  final int fewest;

  /// At [kFootSlowKmPerDay], rounded up.
  final int most;

  /// True when rounding has closed the band — 40 km is 2–2 days, and
  /// printing it as a range would invent a precision the arithmetic does
  /// not have. The surface prints one number and keeps the hedge in the
  /// caption.
  bool get single => fewest == most;

  @override
  bool operator ==(Object other) =>
      other is TravelDays && other.fewest == fewest && other.most == most;

  @override
  int get hashCode => Object.hash(fewest, most);

  @override
  String toString() => 'TravelDays($fewest–$most)';
}

/// Days on foot for [km], or null where there is nothing to estimate.
///
/// Null rather than zero for a distance that is absent, zero or not a
/// number: "0 days" is a statement about a journey and none of those
/// inputs is one. The caller prints nothing at all.
TravelDays? walkingDaysFor(double km,
    {TravelBand band = kDefaultTravelBand}) {
  if (!km.isFinite || km <= 0) return null;
  return TravelDays(
    (km / band.fastKmPerDay).ceil(),
    (km / band.slowKmPerDay).ceil(),
  );
}

/// [days] worded for a reader of [locale].
///
/// Here rather than at each surface so the ruler and the journey panel
/// cannot drift into wording the same band two ways, and so the plural
/// rule can be tested against the string table directly. It has to be:
/// the widget suite renders zh-Hans, which does not inflect, so an
/// English "1 days on foot" would pass every rendered test we have.
String formatTravelDays(TravelDays days, String locale) {
  String s(String key, String fallback) =>
      uiStrings[key]?[locale] ?? fallback;
  if (!days.single) {
    return s('travelDaysBand', '{a}–{b} days on foot')
        .replaceAll('{a}', '${days.fewest}')
        .replaceAll('{b}', '${days.most}');
  }
  final one = days.fewest == 1;
  return s(one ? 'travelDaysOne' : 'travelDaysMany',
          one ? '{n} day on foot' : '{n} days on foot')
      .replaceAll('{n}', '${days.fewest}');
}

/// A route's kilometres split by how the text says they were travelled,
/// with an estimate for the part that can carry one.
///
/// **The sea is left blank deliberately, and the blank must be visible.**
///
/// The claim is NOT that no ancient sailing speed is known. Speeds are
/// known: Casson gives 4–6 knots with a following wind, and the modern
/// rig studies put speed made good to windward under about 2.5, and
/// attested Alexandria-to-Rome passages run 18–25 days against far longer
/// the other way. The claim is narrower and survives: **no speed can
/// honestly be applied to a CHORD.** Which of those numbers governs
/// depends on the wind's direction relative to the course, which a
/// straight line does not carry — and a square-rigged ship could not sail
/// our straight line in the first place. Acts 27 is the proof of that in
/// our own data: they run under the lee of Cyprus and again under Crete,
/// which is not the shortest way and is why there was a voyage to write
/// about. ORBIS models the sea with monthly wind roses over real sailing
/// routes for the same reason. So we decline — and this is the one place
/// we are ahead of BibleWorks, whose ruler will happily apply a walking
/// speed to a line drawn across the Mediterranean.
///
/// **Declining silently would be worse than estimating.** [seaKm] is 93.6%
/// of the voyage to Rome and [unknownKm] is 58% of the route through Mark;
/// a panel that showed a day band and said nothing else would read as the
/// length of the whole journey. So the surface states every non-zero
/// bucket it did not estimate, with the reason, and there is no threshold
/// below which it stops mentioning it.
class JourneyTravel {
  const JourneyTravel({
    required this.landKm,
    required this.seaKm,
    required this.unknownKm,
    required this.landLegs,
    required this.seaLegs,
    required this.unknownLegs,
  });

  final double landKm;
  final double seaKm;

  /// Legs the text will not assign a mode to. [JourneyLeg.unknown] is a
  /// claim in the data — the verb does not say — not a gap in it, so it
  /// is not folded into the land total to make the estimate look fuller.
  final double unknownKm;

  final int landLegs;
  final int seaLegs;
  final int unknownLegs;

  /// The estimate over the land kilometres only, at [band]. Null where
  /// the route has no land leg at all.
  TravelDays? walk({TravelBand band = kDefaultTravelBand}) =>
      walkingDaysFor(landKm, band: band);

  double get totalKm => landKm + seaKm + unknownKm;

  /// True where some of the route was not estimated — the condition for
  /// saying so.
  bool get hasUnestimated => seaKm > 0 || unknownKm > 0;
}

/// Split [route]'s drawn segments by leg.
///
/// Reads the SEGMENTS, which are what the map draws and what
/// [ResolvedJourney.straightLineKm] totals, so the buckets always sum to
/// the figure already on screen. Reading the stop list instead would count
/// legs the resolver collapsed and legs it broke, and the panel would show
/// two different totals for one route.
JourneyTravel travelOf(ResolvedJourney route) {
  var land = 0.0;
  var sea = 0.0;
  var unknown = 0.0;
  var landLegs = 0;
  var seaLegs = 0;
  var unknownLegs = 0;
  for (final s in route.segments) {
    switch (s.leg) {
      case JourneyLeg.land:
        land += s.km;
        landLegs++;
      case JourneyLeg.sea:
        sea += s.km;
        seaLegs++;
      // A `start` leg opens a route and the resolver never emits a segment
      // for one, so this arm is unreachable as the data ships and
      // `travel_time_test.dart` fails the build if that changes. It is
      // written to the unestimated bucket rather than thrown on, because
      // the cost of being wrong here should be a missing estimate and not
      // a blank atlas.
      case JourneyLeg.start:
      case JourneyLeg.unknown:
        unknown += s.km;
        unknownLegs++;
    }
  }
  return JourneyTravel(
    landKm: land,
    seaKm: sea,
    unknownKm: unknown,
    landLegs: landLegs,
    seaLegs: seaLegs,
    unknownLegs: unknownLegs,
  );
}

/// [band] named for the control, e.g. "Porters to a party on the march
/// · 20–30 km a day".
String travelBandLabel(TravelBand band, String locale) =>
    uiStrings[band.labelKey]?[locale] ??
    uiStrings[band.labelKey]?['en'] ??
    band.id;

/// The citation printed under an estimate made at [band].
///
/// Every band has its own sentence rather than one template with the two
/// numbers substituted, because the clause that makes the citation worth
/// printing is the one naming WHICH of ORBIS's categories each end is,
/// and that clause is different for each pair. A shared template would
/// have to drop it or fake it.
String travelBandBasis(TravelBand band, String locale) =>
    uiStrings[band.basisKey]?[locale] ??
    uiStrings[band.basisKey]?['en'] ??
    '';
