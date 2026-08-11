/// Where an illustration CAME FROM, as distinct from where its bytes load.
///
/// 2026-08-11 (task #300). `BibleMap.source` has only ever answered the
/// second question — asset / cdn / legacy_url — and the archive carried no
/// field at all for the first. The gap was not cosmetic: 40 of the 1,192
/// plates are Sweet Publishing images whose upstream release is CC BY-SA
/// 3.0 with `AttributionRequired = true`, so they were shipping in breach
/// of a licence that is otherwise perfectly happy to be used for free.
/// "Free to use" and "no credit needed" are different things, and only the
/// first was ever checked.
///
/// Provenance is recorded per COLLECTION rather than per plate. One credit
/// per source is the unit that carries truth; 1,192 copies of a string is
/// 1,192 places for it to drift out of agreement.
library;

import 'package:flutter/foundation.dart';

/// How confident the licence claim is — and it is the whole point of the
/// record. Without it "public domain because the artist died in 1902" and
/// "public domain because the description said so and nobody looked" read
/// identically, and the second is not a check.
enum LicenseBasis {
  /// The artist's death date puts the work out of copyright everywhere.
  authorDeath,

  /// The upstream host states the licence. Queried, not inferred.
  upstreamDeclared,

  /// The archive's own description claims it; not re-verified upstream.
  entryDescription,

  /// Nothing was recorded. This is a finding, not an empty field.
  notRecorded,
}

LicenseBasis _basisFromJson(String? raw) {
  switch (raw) {
    case 'author-death':
      return LicenseBasis.authorDeath;
    case 'upstream-declared':
      return LicenseBasis.upstreamDeclared;
    case 'entry-description':
      return LicenseBasis.entryDescription;
    default:
      return LicenseBasis.notRecorded;
  }
}

@immutable
class MapProvenance {
  const MapProvenance({
    required this.id,
    required this.name,
    required this.license,
    required this.licenseBasis,
    this.artist,
    this.work,
    this.years,
    this.holder,
    this.licenseNote,
    this.attributionRequired,
    this.credit,
    this.licenseUrl,
    this.sourceUrl,
  });

  final String id;
  final Map<String, String> name;

  /// `public-domain`, `cc-by-sa-3.0`, or `unknown`. Never empty — an
  /// absent licence and an unknown one are different states and the
  /// asset writes the second explicitly.
  final String license;
  final LicenseBasis licenseBasis;

  final String? artist;
  final String? work;
  final String? years;
  final String? holder;
  final String? licenseNote;

  /// Null when the licence itself is unknown, so nobody can say. `true`
  /// means the credit line below is a condition of shipping the plate.
  final bool? attributionRequired;

  final String? credit;
  final String? licenseUrl;
  final String? sourceUrl;

  /// The record a lookup returns when a plate names no collection. It
  /// exists so the viewer always has an honest line to draw rather than
  /// a null to hide behind.
  static const MapProvenance unrecorded = MapProvenance(
    id: 'unrecorded',
    name: {
      'en': 'Origin not recorded',
      'zh-Hans': '来源未记录',
      'zh-Hant': '來源未記錄',
    },
    license: 'unknown',
    licenseBasis: LicenseBasis.notRecorded,
  );

  bool get isKnown => license != 'unknown';

  /// True when the licence obliges us to name the author. Distinct from
  /// [isKnown]: a public-domain plate is known and needs no credit.
  bool get mustCredit => attributionRequired == true;

  factory MapProvenance.fromJson(Map<String, dynamic> json) {
    final rawName = json['name'] as Map<String, dynamic>? ?? const {};
    return MapProvenance(
      id: json['id'] as String? ?? 'unrecorded',
      name: rawName.map((k, v) => MapEntry(k, v as String? ?? '')),
      license: json['license'] as String? ?? 'unknown',
      licenseBasis: _basisFromJson(json['licenseBasis'] as String?),
      artist: json['artist'] as String?,
      work: json['work'] as String?,
      years: json['years'] as String?,
      holder: json['holder'] as String?,
      licenseNote: json['licenseNote'] as String?,
      attributionRequired: json['attributionRequired'] as bool?,
      credit: json['credit'] as String?,
      licenseUrl: json['licenseUrl'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
    );
  }

  String localizedName(String locale) =>
      name[locale] ?? name['en'] ?? id;
}

/// The one credit the archive is legally obliged to print, spelled once.
///
/// It is deliberately NOT localised: it is the wording the upstream
/// release asks for, and a translated attribution is a different
/// attribution. `assets/maps_provenance.json` carries the same string and
/// `test/map_provenance_test.dart` holds the two to it, because the About
/// page reads this constant while the viewer reads the asset and a
/// licence satisfied on one screen and not the other is not satisfied.
const String kSweetCredit =
    'Biblical illustrations by Jim Padgett, courtesy of Sweet Publishing, '
    'Ft. Worth, TX, and Gospel Light, Ventura, CA. Copyright 1984. '
    'Released under CC BY-SA 3.0.';

/// The one line a plate viewer prints under a picture.
///
/// Pure so it can be asserted directly. The rule it encodes is the
/// finding of #300 stated once: a plate whose origin nobody recorded
/// must SAY so. Printing nothing there is indistinguishable from a
/// public-domain plate that needs no credit, and the two are the
/// opposite of each other.
String mapCreditLine(MapProvenance provenance, String locale,
    {required String unknownLabel}) {
  if (!provenance.isKnown) return unknownLabel;
  final credit = provenance.credit;
  if (credit != null && credit.isNotEmpty) return credit;
  return provenance.localizedName(locale);
}
