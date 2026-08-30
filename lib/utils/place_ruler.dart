/// 2026-08-30 (SeekSparks): what the ruler is entitled to say.
///
/// BibleWorks' Ruler (bwh33) measures between two points the reader
/// picked. Ours measures from the selected place to the others the
/// passage itself names, which is the better question — and it inherited
/// a worse hazard, because the reader did not pick these points and
/// cannot see that two of them are the same point.
///
/// `assets/bible_places.json` gives 1,233 located records far fewer
/// distinct coordinates than that: a region carries some city's point
/// (Galilee's is Nazareth's), and Nehemiah 3's nineteen gates, towers and
/// pools all carry Jerusalem's `[31.77, 35.23]`. Measured over the
/// gazetteer's own chapter index, **620 of the 739 chapters that name two
/// or more located places contain at least one pair of distinct names on
/// one point.** The old ruler sorted by distance and took three, so those
/// pairs did not merely appear — they *won*, and printed as `0 km`.
///
/// `0 km` is a measurement, and this is not one. Splitting the two apart
/// is the whole of this file. The wording that goes with it is #317's,
/// already settled on the journey panel: we say the gazetteer has one
/// point for them, and we do NOT say they are one place or that either
/// is unlocated — Jerusalem's gates really are adjacent, and an
/// unidentified site really is unknown, and this data cannot tell them
/// apart.
library;

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/bible_place.dart';
import 'package:seeksparks/utils/journey_route.dart' show markerKeyFor;

/// One measured neighbour.
class RulerLeg {
  const RulerLeg(this.place, this.km);
  final BiblePlace place;
  final double km;
}

/// What the footer may print about [selected].
class RulerReading {
  const RulerReading({required this.measured, required this.samePoint});

  /// Neighbours at a real distance, nearest first, capped.
  final List<RulerLeg> measured;

  /// Places the gazetteer puts on [selected]'s own coordinate. NOT a
  /// distance of zero; the absence of a distance.
  final List<BiblePlace> samePoint;

  bool get isEmpty => measured.isEmpty && samePoint.isEmpty;
}

/// At most this many measured neighbours, because a chapter can name a
/// dozen places and the far end of that list is noise. Unchanged from
/// what shipped.
const int kRulerNeighbours = 3;

/// Split [candidates] around [selected].
///
/// Keyed on [markerKeyFor] — the coordinate — and not on a distance
/// threshold. A threshold would call two genuinely distinct places 400 m
/// apart "the same map point", which is a claim the gazetteer does not
/// make. Coordinate identity is the claim the gazetteer *does* make.
RulerReading rulerReadingFor(
  BiblePlace? selected,
  Iterable<BiblePlace> candidates,
) {
  if (selected == null || !selected.located) {
    return const RulerReading(measured: [], samePoint: []);
  }
  final key = markerKeyFor(selected);
  final measured = <RulerLeg>[];
  final same = <BiblePlace>[];
  for (final p in candidates) {
    if (p.id == selected.id || !p.located) continue;
    if (markerKeyFor(p) == key) {
      same.add(p);
      continue;
    }
    final d = selected.distanceKmTo(p);
    if (d == null) continue;
    measured.add(RulerLeg(p, d));
  }
  measured.sort((a, b) => a.km.compareTo(b.km));
  return RulerReading(
    measured: measured.take(kRulerNeighbours).toList(growable: false),
    samePoint: same,
  );
}

/// A distance as the ruler prints it.
///
/// One decimal below 10 km. `round()` printed `0 km` for anything under
/// 500 m, which collided with the co-located case above and made one
/// string mean two different things; and "Bethphage to Bethany, 0 km" is
/// wrong about a real, walkable, non-zero distance.
String rulerKmLabel(double km) =>
    km < 10 ? km.toStringAsFixed(1) : '${km.round()}';

/// At most this many names are printed before the count carries the
/// rest. The footer is two lines and Nehemiah 3 has nineteen.
const int kSamePointNames = 4;

/// The list separator a reader of [locale] expects.
///
/// The first version of this sentence joined with the ideographic comma
/// unconditionally, so an English reader was shown
/// `Dung Gate、Broad Wall`. #297 settled the mirror of this rule for
/// CJK; a CJK convention pasted into English is the same defect facing
/// the other way.
String nameListSeparator(String locale) =>
    locale.startsWith('zh') ? '、' : ', ';

/// The footer's co-location sentence for [names], or null when there is
/// nothing to say.
///
/// Two strings, not one with a count substituted, because **the
/// singular is the common case, not the edge case**: measured over the
/// gazetteer's own chapter index, 1,620 of the 2,539 occasions this
/// sentence can appear — 63.8% — have exactly ONE co-located place, and
/// the plural template rendered that as
/// `Dung Gate — 1 in all — sit on the same map point`.
String? samePointSentence(List<String> names, String locale) {
  if (names.isEmpty) return null;
  String s(String key, String fallback) => uiStrings[key]?[locale] ?? fallback;
  if (names.length == 1) {
    return s('placesMapSamePointOne', '')
        .replaceAll('{name}', names.first);
  }
  return s('placesMapSamePoint', '')
      .replaceAll('{n}', '${names.length}')
      .replaceAll(
        '{names}',
        names.take(kSamePointNames).join(nameListSeparator(locale)),
      );
}
