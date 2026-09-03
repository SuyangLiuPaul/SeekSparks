import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/biblical_person.dart';
import 'package:seeksparks/models/chronology.dart'
    show ChronologyData, Patriarch;
import 'package:seeksparks/models/hebrew_king.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/chronology_page.dart';
import 'package:seeksparks/pages/family_tree_page.dart';
import 'package:seeksparks/pages/hebrew_kings_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/chronology_service.dart';
import 'package:seeksparks/services/family_tree_service.dart';
import 'package:seeksparks/services/hebrew_kings_service.dart';
import 'package:seeksparks/services/timeline_service.dart';
import 'package:seeksparks/services/url_sync_service.dart';
import 'package:seeksparks/utils/date_hedge.dart';
import 'package:seeksparks/utils/font_catalog.dart';
import 'package:seeksparks/utils/jump_to_reference.dart' as jumper;
import 'package:seeksparks/utils/navigate_to_reader.dart';
import 'package:seeksparks/utils/radial_chronology_layout.dart';
import 'package:seeksparks/utils/reference_parser.dart';
import 'package:seeksparks/utils/version_mapper.dart'
    show localizedReferenceLabel;
import 'package:seeksparks/utils/wheel_search.dart';
import 'package:seeksparks/widgets/home_icon_button.dart';
import 'package:seeksparks/widgets/language_switcher_button.dart';
import 'package:seeksparks/widgets/localized_back_button.dart';
import 'package:seeksparks/widgets/person_detail_sheet.dart';
import 'package:seeksparks/widgets/verse_popup_sheet.dart' show showVersePopup;

/// World history on one wheel: 4200 BC at twelve o'clock, time sweeping
/// clockwise to the present, one concentric band per people or
/// institution, every dated thing drawn on the band it belongs to.
///
/// WHY BANDS AND NOT ONE STREAM OF DATES. The engraved chronologies
/// organise by NATION, not by kind-of-event: Israel is a band, Rome is
/// a band, the church is a band. That is what lets a reader follow one
/// people down the centuries instead of reading an undifferentiated
/// queue of years, and it is why such charts can carry a thousand
/// entries and still be read.
///
/// WHY THE EVENT TEXT RUNS OUTWARD. Angular space is scarce — every
/// degree of the rim is contested, and two events a decade apart fight
/// for the same arc. Radial space is nearly free: a label running
/// outward occupies an angle no wider than its type, so a crowded
/// century spreads along the radius instead of overprinting. Tangential
/// labels can only be resolved by dropping one, which loses the entry
/// and still looks crowded. Several events in one year stack outward
/// along the same spoke — see `stackRadialLabels`.
///
/// WHY THE COLOURS ARE THE LINES OF GENESIS 10. The bands are coloured
/// by descent from Shem, Ham and Japheth. That organising idea is the
/// table of nations itself, which this app reads out of its own
/// scripture asset and cites verse by verse — so a reader who wonders
/// why Egypt is one colour and Greece another can open the band and be
/// sent to Genesis 10:6 or 10:2. Two bands are not descents at all and
/// are coloured apart: the church, and the text of scripture.
///
/// WHAT IS HERE, AND ON WHAT AXIS. Two kinds of mark, and the
/// difference between them is the whole design.
///
/// A SPOKE SAYS WHEN. Every event is a moment: a tick on its own band
/// and text running outward. Adam, Seth, Enosh, Kenan, Mahalalel,
/// Jared, Enoch, Methuselah, Lamech and Shelah have birth spokes like
/// anything else, because a birth is a moment.
///
/// AN ARC SAYS HOW LONG, AND ALONGSIDE WHOM. The lifespans of Genesis 5
/// and 11 — Adam to Moses, 25 men — are drawn in the label annulus,
/// eleven sub-rings deep, each life running from its birth year to its
/// death year. This is what a spoke cannot do and must not try to: an
/// arc shows Methuselah's years ending in the year of the flood, which
/// the text nowhere states and the arithmetic does, and it shows the
/// eleven lives that overlap between Noah and Abraham. No death events
/// were added for the same reason — fourteen more spokes in a sector
/// that already holds fifty would be redundancy, and the arc's end IS
/// the death.
///
/// THEY ARE ON ONE AXIS, NOT TWO. Anno Mundi figures reach BC years
/// through `bible_timeline.json`'s `_meta.creation.year` (4114 BC),
/// derived once by `tools/audit_dates.py` as Thiele's Solomon counted
/// back along twenty-five stated intervals, and every Abraham-to-Moses
/// arc lands exactly on the spoke this wheel already drew for him. If
/// that field cannot be read, the layer draws NOTHING — a fallback
/// constant here is how one man ends up with two years.
///
/// MASORETIC IS DRAWN; THE SEPTUAGINT IS PRINTED. The Greek chain puts
/// the creation 1,366 years earlier, and carrying it on the axis would
/// cost about a fifth of the angular resolution of every event on the
/// wheel for the sake of nineteen arcs. So the arcs are Masoretic, the
/// layer's own row says so, and every arc's sheet prints BOTH
/// traditions' figures with their verses — so no tradition is chosen in
/// silence.
///
/// HONESTY. Every event carries a `basis` — the text states it, or
/// Thiele's reconstruction supplies the year, or it is the date any
/// general reference gives — and the detail sheet says which. Every
/// entry carries `approximate` explicitly, so an absent flag never has
/// to be read as a claim. A power that has not ended carries no end
/// year and is drawn to the axis end, labelled "present": writing this
/// year in would read as though it had ended, and would go stale every
/// January.
class RadialChronologyPage extends StatefulWidget {
  const RadialChronologyPage({super.key});

  @override
  State<RadialChronologyPage> createState() => _RadialChronologyPageState();
}

// ── the axis ─────────────────────────────────────────────────────────

/// The share link for this page. A reader who sends this address
/// sends the wheel, not the chapter behind it.
const String kWheelUrlPath = '/wheel';

// THE AXIS STARTS BEFORE THE CREATION, AND HAS TO.
// `bible_timeline.json` now counts its pre-Abraham years back from the
// same anchor as everything else (`_meta.creation`, -4114) instead of
// from Ussher's rounded 4000. -4000 would put the creation and Eden off
// the start of the axis, where `angleForSpan` clamps them onto the rim
// and states a year nobody claims. -4200 is round, so the century loop
// and the %500 label rule need no change, and it leaves 86 years of
// room before Adam. The cost is 3.2% of angular resolution everywhere.
const int kMinYear = -4200;
const int kMaxYear = 2026;

// Wheel geometry as fractions of the square's side.
//   hub  .. bands   the stream bands, one ring each
//   bands .. rim    radial event labels
//   beyond rim      century years
const double _kHubFrac = 0.115;
const double _kBandsFrac = 0.285;
const double _kRimFrac = 0.445;

/// The outermost hairline `_paintRim` draws, as an offset from the rim.
/// Named because two things depend on it and they must not drift: the
/// ring itself, and the clearance every axis label is placed against.
const double kRimOuterRing = 6.0;

/// How far outside the rim the axis may start printing.
///
/// This is the whole collision argument, and it is short: every event
/// label ends at `rRim` or inside it — `planRadialSpokes` drops the
/// words of any label that would overrun, keeping only its tick — so a
/// scale label whose box begins here cannot reach one. The three units
/// past [kRimOuterRing] are so the type does not sit on the hairline.
const double kAxisLabelClearance = kRimOuterRing + 3.0;

/// How far off its own axis line each end label is swung, in radians.
///
/// It swings so as not to print on the line it names. It swings THIS
/// far — 5.7°, up from the 3.15° it carried until 2026-08-26 — because
/// the last century tick, AD 2000, is only 26 years from the AD 2026
/// end, which on this axis is 1.4°: the two labels were fighting for
/// the same arc. Both ends swing into the wheel's 40° gap, which is
/// empty by construction, so the room costs nothing.
const double kAxisEndSwing = 0.10;

/// The arc of the colour wheel each Genesis 10 family occupies.
///
/// (start hue, end hue) in degrees. A family's bands spread across its
/// own arc, so no two bands share a colour, while the arcs stay far
/// enough apart that a family still reads as one.
///
/// The first attempt kept every family inside a narrow swing around a
/// single hue. That was faithful to the idea and useless in practice:
/// ten Japhethite bands came out as ten near-identical blues and a
/// reader could not tell Rome from Japan. The bands are ALREADY
/// contiguous by family on the wheel — Israel through the Islamic
/// world sit together, Persia through India sit together — so
/// adjacency is already saying "these belong together", which frees
/// hue to spend itself on telling them apart. Japheth gets the widest
/// arc because it carries ten of the twenty-two.
///
/// Kept literal: a reader learns what a colour means, and that must
/// hold whatever accent the app is themed with.
const Map<String, (double, double)> _lineHueArcs = {
  'shem': (10, 64), // red through amber to olive
  'ham': (88, 150), // yellow-green through green
  'japheth': (178, 300), // teal, cyan, blue, indigo, violet
  'institution': (312, 342), // magenta through rose
  'none': (0, 0), // grey: belongs to no descent
};

const Color _noDescentColor = Color(0xFF828282);

/// A colour for ONE band: its family's arc, at position [t] (0..1),
/// with [index] deciding which way its lightness steps.
///
/// Three things had to be true at once, and each was learned by a test
/// failing rather than by eye:
///
///  * NEIGHBOURS MUST DIFFER. Hue alone was not enough — six Semitic
///    bands inside a 34° swing left Arabia and the Islamic world 35
///    apart, which reads as the same colour. So lightness ZIGZAGS with
///    the index: two adjacent bands differ in hue AND in lightness,
///    never in one channel only.
///  * NOTHING MAY GO NEAR BLACK OR WHITE. A smooth lightness ramp
///    across a ten-band family drove its ends to #612218 and #E69DE6 —
///    separable, and unreadable on the page. The zigzag keeps every
///    band between 0.37 and 0.57.
///  * FAMILIES MUST NOT TOUCH. Ham's arc ended at 165° where Japheth's
///    began, so Philistia and Persia came out the SAME colour; the
///    test measured 0.0 between them. The arcs now leave a gap.
Color _bandColor(String line, double t, int index) {
  final arc = _lineHueArcs[line];
  if (arc == null || line == 'none') return _noDescentColor;
  final (h0, h1) = arc;
  return HSLColor.fromAHSL(
    1,
    (h0 + (h1 - h0) * t) % 360,
    // Saturation peaks mid-arc so the ends do not turn to mud.
    (0.60 + 0.12 * math.sin(math.pi * t)).clamp(0.0, 1.0),
    (0.47 + (index.isEven ? -0.10 : 0.10)).clamp(0.0, 1.0),
  ).toColor();
}

/// The family's own colour, for the legend — the middle of its arc.
Color _lineColor(String line) => _bandColor(line, 0.5, 0);

/// Arc ids for the reign band carry this, because [buildSpanArcs] packs
/// every span in ONE id space and a king and a patriarch could
/// otherwise answer to the same name. Nothing in `chronology.json`
/// reaches past Joseph today, so no id actually collides — which is
/// exactly why a prefix is worth having: the collision that would break
/// this is one nobody would be looking for.
const String kKingArcPrefix = 'king:';

/// Judah at one end of Shem's hue arc, Israel at the other.
///
/// Both kingdoms ARE Shem's, so borrowing a third family's hue would
/// have been a claim about descent that the table of nations does not
/// make. The two ends are 54 apart in hue and step opposite ways in
/// lightness, which is the same separation rule the stream bands are
/// held to — and the patriarch arcs sit at the middle of the same arc,
/// so the three read as three shades of one family rather than three
/// families.
Color kingdomArcColor(Kingdom kingdom) => switch (kingdom) {
      Kingdom.israel => _bandColor('shem', 1, 1),
      // Saul, David and Solomon reigned over both houses; they are
      // drawn in Judah's shade because the throne they held is the one
      // Judah kept, not because the united monarchy was Judah.
      Kingdom.judah || Kingdom.united => _bandColor('shem', 0, 0),
    };

/// Arc ids for the ministry band, for the same reason as
/// [kKingArcPrefix]: one id space, and `daniel_prophet` must never be
/// mistaken for a patriarch or a king.
const String kMinistryArcPrefix = 'ministry:';

/// The ministries' own shade — the middle of the church line's arc.
///
/// NOT one of Shem's three. A prophet's years are a third kind of claim
/// again: not a stated age (the lifespans), not a synchronised reign
/// (the kings), but the window a text places a man's work in. Giving it
/// a Semitic shade would have said it was the same sort of number as
/// the two beside it.
Color ministryArcColor() => _lineColor('institution');

/// The ministries as spans for the arc band.
List<SpanInput> ministrySpans(List<WheelMinistry> ministries) => [
      for (final m in ministries)
        (
          id: '$kMinistryArcPrefix${m.id}',
          line: 'ministry',
          startYear: m.start,
          endYear: m.end,
        )
    ];

/// One year of the genealogy, and everybody the tree places in it.
///
/// A COHORT, NOT A PERSON, and that is the whole design. The 198
/// family-tree people this layer draws share only 107 distinct years,
/// and one of those years holds 44 of them — the sons and grandsons of
/// Jacob who went down into Egypt, whom `family_tree.json` gives one
/// nominal year because Genesis 46 lists them together and dates none
/// of them. Drawing 198 marks would print 198 datings; drawing 107
/// marks, each saying how many people stand behind it, prints what the
/// asset actually contains.
///
/// EVERY ONE OF THESE YEARS HAS AN EMPTY `datingRefs`. Measured, all
/// 198: 197 are `approximate` and one is a reign, and not one carries
/// a verse. So this layer is drawn in its own muted style, switched
/// separately, and its sheet says the year is the genealogy's placement
/// with no verse behind it — before it says anything else.
class LineageCohort {
  const LineageCohort({required this.year, required this.people});

  final int year;

  /// In `family_tree.json` order, which is the tree's own generational
  /// order — not sorted here, because a re-sort would be an opinion
  /// about who matters.
  final List<BiblicalPerson> people;
}

/// The genealogy's people who are on no other layer, grouped by year.
///
/// [drawnIds] is every id the wheel already draws — patriarchs, kings,
/// and anyone an event names through `personIds`. Excluding BY ID and
/// not by name is deliberate: a person whose name merely occurs in an
/// event's prose has no record on the wheel to reach, and dropping him
/// here would remove the only way to reach him at all.
@visibleForTesting
List<LineageCohort> lineageCohorts({
  required List<BiblicalPerson> people,
  required Set<String> drawnIds,
}) {
  final byYear = <int, List<BiblicalPerson>>{};
  for (final p in people) {
    if (p.yearSystem != 'bc') continue;
    final y = p.birthYear;
    if (y == null) continue;
    if (drawnIds.contains(p.id)) continue;
    byYear.putIfAbsent(y, () => []).add(p);
  }
  final years = byYear.keys.toList()..sort();
  return [
    for (final y in years) LineageCohort(year: y, people: byYear[y]!)
  ];
}

/// The selection id a rail mark answers to. A year, not a person: the
/// mark stands for everybody in it.
const String kLineageArcPrefix = 'lineage:';

/// The genealogy rail's own shade: the no-descent grey, because a
/// conventional placement belongs to no claim the chart makes.
Color lineageRailColor() => _noDescentColor;

/// The tradition the arc band is drawn on. Top-level because
/// [packWheelBand] defaults to it and the tests read it.
const String kDrawnTradition = 'mt';

/// THE BAND'S PACKING, IN ONE PLACE — and the reason it is top-level
/// rather than a method is that the tests needed it too.
///
/// `packIntoRings` is first-fit over whatever list it is given, so any
/// caller that assembles its own list gets its own ring numbers. Three
/// callers need these arcs: the painter, the search pan, and
/// `wheel_lifespans_test.dart`, which taps an arc at a radius it
/// computes. The test had its own copy of this call, and the day the
/// kings and the ministries joined the band that copy started
/// describing a wheel the app no longer drew — four tests failed by
/// tapping empty annulus. They were right to fail, and the fix is not
/// to teach the copy about kings: it is to delete the copy.
///
/// So this is the only place the band is packed, and a layer added to
/// it here is added everywhere at once.
@visibleForTesting
List<LifeArc> packWheelBand({
  required ChronologyData chron,
  required int creationYear,
  required List<HebrewKing> kings,
  required List<WheelMinistry> ministries,
  String tradition = kDrawnTradition,
  int reservedInnerRings = 0,
}) {
  final packed = buildLifeArcs(
      patriarchs: chron.patriarchs,
      tradition: tradition,
      creationYear: creationYear,
      minYear: kMinYear,
      maxYear: kMaxYear,
      // STATED, not defaulted. `packIntoRings`' own 0.02 rad is 22
      // years on this axis today and would be some other number of
      // years the day `kMinYear` moved — a silent repack.
      minGap: 0.02,
      alsoPack: [
        ...kingReignSpans(kings),
        ...ministrySpans(ministries),
      ],
    );
  if (reservedInnerRings == 0) return packed;
  // THE SHIFT LIVES HERE, not at the call site. It was applied in the
  // page for about ten minutes and immediately broke the same test the
  // duplicated packing had broken an hour earlier: the arcs moved out
  // by one sub-ring and `wheel_lifespans_test.dart` went on tapping the
  // old radii. Anything that changes where an arc is drawn belongs to
  // this function, because this function is what every caller shares.
  return [
    for (final a in packed)
      LifeArc(
        id: a.id,
        ring: a.ring + reservedInnerRings,
        a0: a.a0,
        a1: a.a1,
        line: a.line,
        birthYear: a.birthYear,
        deathYear: a.deathYear,
      )
  ];
}

/// The 42 reigns as spans for the arc band.
///
/// Uses `reignStart`/`reignEnd`, which is the OUTER hull of a king's
/// `spans` — a co-regency and the sole reign that follows it are one
/// arc here, and the sheet is where the parts are named. Drawing each
/// `ReignSpan` separately would put Jotham on the wheel twice with no
/// way to see that the two arcs are one man.
@visibleForTesting
List<SpanInput> kingReignSpans(List<HebrewKing> kings) => [
      for (final k in kings)
        (
          id: '$kKingArcPrefix${k.id}',
          line: k.kingdom == Kingdom.israel ? 'israel' : 'judah',
          startYear: k.reignStart,
          endYear: k.reignEnd,
        )
    ];

/// The colour of one band, given its position among its own family.
Color streamColor(String line, int index, int count) =>
    _bandColor(line, count <= 1 ? 0.5 : index / (count - 1), index);

/// Strings this page owns. Kept local rather than appended to
/// ui_strings.dart because the unattended loop shares this checkout and
/// edits that file; fold these in on a quiet merge.
const Map<String, Map<String, String>> wheelStrings = {
  // WHERE A POWER WAS, in the asset's own twelve-value vocabulary.
  //
  // `region` used to be excused as unread on the grounds that it was
  // "very nearly a function of stream" — 20 of 22 streams mapped to one
  // region. Adding 42 pontificates and five crusades broke that: the
  // church band now runs through both `europe` and `levant`, and it
  // does so because the papacy and the crusades genuinely happened in
  // different places. A field that carries information and is never
  // shown is information held back, so it is shown.
  'wheelKindMinistry': {
    'zh-Hans': '事奉', 'zh-Hant': '事奉', 'en': 'ministry',
  },
  'wheelRegionEgypt': {'zh-Hans': '埃及', 'zh-Hant': '埃及', 'en': 'Egypt'},
  'wheelRegionMesopotamia': {
    'zh-Hans': '美索不达米亚', 'zh-Hant': '美索不達米亞', 'en': 'Mesopotamia',
  },
  'wheelRegionAnatolia': {
    'zh-Hans': '安纳托利亚', 'zh-Hant': '安納托利亞', 'en': 'Anatolia',
  },
  'wheelRegionLevant': {
    'zh-Hans': '黎凡特', 'zh-Hant': '黎凡特', 'en': 'The Levant',
  },
  'wheelRegionPersia': {'zh-Hans': '波斯', 'zh-Hant': '波斯', 'en': 'Persia'},
  'wheelRegionGreece': {'zh-Hans': '希腊', 'zh-Hant': '希臘', 'en': 'Greece'},
  'wheelRegionRome': {'zh-Hans': '罗马', 'zh-Hant': '羅馬', 'en': 'Rome'},
  'wheelRegionIslamic': {
    'zh-Hans': '伊斯兰世界', 'zh-Hant': '伊斯蘭世界', 'en': 'The Islamic world',
  },
  'wheelRegionEurope': {'zh-Hans': '欧洲', 'zh-Hant': '歐洲', 'en': 'Europe'},
  'wheelRegionAsia': {'zh-Hans': '亚洲', 'zh-Hant': '亞洲', 'en': 'Asia'},
  'wheelRegionAmericas': {
    'zh-Hans': '美洲', 'zh-Hant': '美洲', 'en': 'The Americas',
  },
  'wheelRegionModern': {
    'zh-Hans': '现代世界', 'zh-Hant': '現代世界', 'en': 'The modern world',
  },
  'wheelRefs': {
    'zh-Hans': '经文出处', 'zh-Hant': '經文出處', 'en': 'References',
  },
  'wheelMinistryAnchors': {
    'zh-Hans': '所据王年',
    'zh-Hant': '所據王年',
    'en': 'Anchored on the reigns of',
  },
  'wheelLineage': {
    'zh-Hans': '家谱人物（约）',
    'zh-Hant': '家譜人物（約）',
    'en': 'Genealogy (approximate)',
  },
  'wheelLineageNote': {
    'zh-Hans': '此年份是家谱为排布世代所定的位置，并无经文可据；'
        '本图所收这一层的每一位，其年份都没有经文出处。',
    'zh-Hant': '此年份是家譜為排布世代所定的位置，並無經文可據；'
        '本圖所收這一層的每一位，其年份都沒有經文出處。',
    'en': 'This year is where the genealogy places these people so a '
        'tree can be drawn. It rests on no verse — not one person in '
        'this layer carries a reference for their year.',
  },
  'wheelLineageCount': {
    'zh-Hans': '{n} 位', 'zh-Hant': '{n} 位', 'en': '{n} people',
  },
  'wheelReigns': {
    'zh-Hans': '犹大与以色列列王',
    'zh-Hant': '猶大與以色列列王',
    'en': 'Reigns of Judah & Israel',
  },
  'wheelMinistriesNote': {
    'zh-Hans': '事奉年间；多为通用年代，非经文所载',
    'zh-Hant': '事奉年間；多為通用年代，非經文所載',
    'en': 'ministry spans; most are conventional, not stated in scripture',
  },
  'wheelMinistries': {
    'zh-Hans': '先知与使徒的年间',
    'zh-Hant': '先知與使徒的年間',
    'en': 'Prophets & apostles',
  },
  'wheelKingsThiele': {
    'zh-Hans': '列王在位（Thiele）',
    'zh-Hant': '列王在位（Thiele）',
    'en': 'reigns (Thiele)',
  },
  'wheelAbout': {
    'zh-Hans': '关于本图', 'zh-Hant': '關於本圖', 'en': 'About this chart',
  },
  'wheelAboutProvenance': {
    'zh-Hans': '年份的来源', 'zh-Hant': '年份的來源',
    'en': 'Where the dates come from',
  },
  'wheelAboutCoverage': {
    'zh-Hans': '本图收录什么', 'zh-Hant': '本圖收錄什麼',
    'en': 'What is on the chart',
  },
  'wheelAboutScope': {
    'zh-Hans': '民族表止于何处', 'zh-Hant': '民族表止於何處',
    'en': 'Where the table of nations stops',
  },
  'wheelAboutAxis': {
    'zh-Hans': '年代轴止于何处', 'zh-Hant': '年代軸止於何處',
    'en': 'Where the axis stops',
  },
  'wheelTitle': {
    'zh-Hans': '世界史轮盘',
    'zh-Hant': '世界史輪盤',
    'en': 'World History Wheel',
  },
  'wheelHint': {
    'zh-Hans': '双指缩放 · 点按带或事件',
    'zh-Hant': '雙指縮放 · 點按帶或事件',
    'en': 'Pinch to zoom · tap a band or an event',
  },
  'wheelPresent': {'zh-Hans': '至今', 'zh-Hant': '至今', 'en': 'present'},
  // The one tick on the axis that names a boundary instead of a year —
  // see `centuryTickLabel`. 主前/主后 rather than 公元前/公元 because that
  // is this chart's own register throughout; `ui_strings.dart` uses the
  // other one elsewhere and the two are not being mixed here.
  'wheelEraBoundary': {
    'zh-Hans': '主前｜主后',
    'zh-Hant': '主前｜主後',
    'en': 'BC | AD',
  },
  'wheelFilter': {'zh-Hans': '筛选', 'zh-Hant': '篩選', 'en': 'Filter'},
  'wheelReset': {'zh-Hans': '复位', 'zh-Hant': '復位', 'en': 'Reset'},
  'wheelShadeNote': {
    'zh-Hans': '同一血统内，每条带一个色阶',
    'zh-Hant': '同一血統內，每條帶一個色階',
    'en': 'each band is its own shade of its line',
  },
  // The rim cannot carry 588 names at once, so a spoke often stands for
  // several events. `+65` is the mark that says so, and this is the one
  // place on screen that says what the mark means — the control has to
  // teach, or a reader reads `+65` as part of the title beside it.
  'wheelClusterLegend': {
    'zh-Hans': '＋n：此处另有 n 件大事，点按可列出',
    'zh-Hant': '＋n：此處另有 n 件大事，點按可列出',
    'en': '+n — n more events here; tap to list them',
  },
  'wheelClusterNote': {
    'zh-Hans': '此处轮缘只容得下一个名称。点按任一大事可打开。',
    'zh-Hant': '此處輪緣只容得下一個名稱。點按任一大事可開啟。',
    'en': 'The rim has room for one name here. Tap any event to open it.',
  },
  'wheelAll': {'zh-Hans': '全选', 'zh-Hant': '全選', 'en': 'All'},
  'wheelNone': {'zh-Hans': '全不选', 'zh-Hant': '全不選', 'en': 'None'},
  'wheelLineShem': {'zh-Hans': '闪族', 'zh-Hant': '閃族', 'en': 'Shem'},
  'wheelLineHam': {'zh-Hans': '含族', 'zh-Hant': '含族', 'en': 'Ham'},
  'wheelLineJapheth': {
    'zh-Hans': '雅弗族',
    'zh-Hant': '雅弗族',
    'en': 'Japheth',
  },
  'wheelLineInstitution': {
    'zh-Hans': '教会与圣经',
    'zh-Hant': '教會與聖經',
    'en': 'Church & Scripture',
  },
  'wheelDescent': {
    'zh-Hans': '创世记 10 章的世系',
    'zh-Hant': '創世記 10 章的世系',
    'en': 'Descent in Genesis 10',
  },
  'wheelPowers': {'zh-Hans': '政权', 'zh-Hant': '政權', 'en': 'Powers'},
  'wheelEvents': {'zh-Hans': '大事', 'zh-Hant': '大事', 'en': 'Events'},
  'wheelApprox': {
    'zh-Hans': '约数 · 各家不一',
    'zh-Hant': '約數 · 各家不一',
    'en': 'approximate — references differ',
  },
  'wheelBasisScripture': {
    'zh-Hans': '经文所载',
    'zh-Hant': '經文所載',
    'en': 'stated in scripture',
  },
  'wheelBasisThiele': {
    'zh-Hans': '经文所载间隔 · 年份按 Thiele',
    'zh-Hant': '經文所載間隔 · 年份按 Thiele',
    'en': 'interval from scripture, year from Thiele',
  },
  // The kings' own years rest on Thiele without an interval stated
  // from the anchor. Before the Bible narrative was merged onto the
  // wheel no record used this basis, and `thiele` fell through
  // _basisText's default to "conventional date, not stated in
  // scripture" — which of David's accession is simply untrue.
  'wheelBasisThieleOnly': {
    'zh-Hans': '年份按 Thiele 列王年代',
    'zh-Hant': '年份按 Thiele 列王年代',
    'en': 'year from Thiele’s chronology of the kings',
  },
  'wheelBasisConventional': {
    'zh-Hans': '通行年份 · 非经文所载',
    'zh-Hant': '通行年份 · 非經文所載',
    'en': 'conventional date, not stated in scripture',
  },
  // ── find ────────────────────────────────────────────────────────────
  'wheelFind': {'zh-Hans': '查找', 'zh-Hant': '查找', 'en': 'Find'},
  'wheelFindHint': {
    'zh-Hans': '名称、经文或年份',
    'zh-Hant': '名稱、經文或年份',
    'en': 'A name, a verse or a year',
  },
  // The empty box has to teach what the box can answer, or a reader
  // types one word, gets nothing, and concludes the wheel is thin.
  // {e} {p} {n} {b} are the corpus's own counts, read from the asset.
  // 2026-09-03: this line used to promise events, powers, nations and
  // bands, and the box searched MINISTRY spans too — 44 of them, every
  // prophet and reign on the arc band — so the line undersold the box by
  // a whole kind of record. It now also counts the records that exist to
  // say the chart draws NOTHING, which is the one kind a reader would
  // never think to look for. Deliberately "{o} records this chart cannot
  // date" and not "{o} prophets": all three are prophets today, and a
  // fourth need not be.
  'wheelFindTeach': {
    'zh-Hans': '可查 {e} 件大事、{p} 个政权、{m} 段事奉与在位、创世记 10 章的 {n} 族、'
        '{b} 条带，以及 {o} 条本图无从定年的记录。'
        '年份可输入「主前586」「586 BC」或「-586」；只输数字则两个纪元都查。',
    'zh-Hant': '可查 {e} 件大事、{p} 個政權、{m} 段事奉與在位、創世記 10 章的 {n} 族、'
        '{b} 條帶，以及 {o} 條本圖無從定年的記錄。'
        '年份可輸入「主前586」「586 BC」或「-586」；只輸數字則兩個紀元都查。',
    // The Chinese forms are accepted in every locale, but naming them
    // here would offer an English reader a keyboard they do not have.
    'en': 'Searches {e} events, {p} powers, {m} ministries and reigns, the '
        '{n} nations of Genesis 10, {b} bands, and {o} records this chart '
        'cannot date. For a year type 586 BC or -586; a bare number '
        'searches both eras.',
  },
  'wheelFindNone': {
    'zh-Hans': '没有找到「{q}」。',
    'zh-Hant': '沒有找到「{q}」。',
    'en': 'Nothing here matches “{q}”.',
  },
  // WHEN THE APP KNOWS THE NAME AND THIS WHEEL CANNOT CARRY IT.
  //
  // Methuselah is in the app: his years are in `family_tree.json` and
  // his life is drawn on the Bible Chronology page. He is not on this
  // wheel and cannot be — the text gives him an interval, not a date,
  // so there is no BC year to draw him at (the reason is set out under
  // WHAT IS NOT HERE at the top of this file). Without this line the
  // reader is told "Nothing here matches Methuselah", which reads as
  // the app never having heard of him.
  //
  // NO NUMBER IN THIS SENTENCE. Eight of these men are given different
  // lifespans by the Masoretic text and the Septuagint, and this page
  // has no way to let a reader choose between them. The Chronology
  // page does. Printing "969 years" here would pick one silently.
  //
  // No pronoun either — the same sentence has to serve whoever the
  // reader typed.
  // The heading over the reigns inside a kingdom's sheet. {n} is read
  // from `hebrew_kings.json`, never written here: twenty and twenty is
  // Thiele's count, not a fact about the world, and a number typed into
  // a heading is a number that goes stale silently.
  // The events falling inside a power's own span.
  //
  // Deliberately NOT the wheel's `wheelEvents` heading ("Events · n"),
  // which the band's sheet uses. That one means "this band's events";
  // this one means "events that happened while this stood", which is a
  // weaker and different claim — the Fire of Rome is not an event OF
  // the Roman Empire in the sense that its founding is. The heading
  // says span, not ownership, so the list cannot be read as a claim
  // about what belonged to whom.
  'wheelWithinSpan': {
    'zh-Hans': '此期间 · {n}',
    'zh-Hant': '此期間 · {n}',
    'en': 'Within this span · {n}',
  },
  'wheelKings': {
    'zh-Hans': '列王 · {n}',
    'zh-Hant': '列王 · {n}',
    'en': 'Kings · {n}',
  },
  // WHY A KING THE APP CHARTS IS NOT ON THIS WHEEL.
  //
  // The wheel's unit is the polity: it draws the Kingdom of Judah, not
  // Ahab. About half the forty-two return nothing here, and "Nothing
  // here matches Baasha" reads as the app never having heard of him
  // when it has a whole page for him.
  //
  // The sentence differs from `wheelFindAmElsewhere` in what it claims.
  // Baasha has a year this app prints, from Thiele, and what is missing
  // is not the year but the RESOLUTION: the wheel is drawn at the scale
  // of kingdoms. Methuselah's problem was a different one and is now
  // solved — his life is an arc — so that sentence has been rewritten
  // and this one has not.
  //
  // No year in this sentence either, and for a reason of this page's
  // own: on the wheel a year never appears without the line that says
  // what it rests on, and a search status line has no room for one.
  'wheelFindKingElsewhere': {
    'zh-Hans': '{name}不在这个轮盘上：轮盘画的是列国，不是列王。'
        '这段在位记在「犹大与以色列列王」，与另一个王座并排。',
    'zh-Hant': '{name}不在這個輪盤上：輪盤畫的是列國，不是列王。'
        '這段在位記在「猶大與以色列列王」，與另一個王座並排。',
    'en': '{name} is not on this wheel: it draws kingdoms, not reigns. '
        'That reign is charted beside the other throne in Kings of '
        'Judah & Israel.',
  },
  // THIS SENTENCE USED TO SAY THE OPPOSITE, and had to stop. It read
  // "{name} is not on this wheel: the text gives a lifespan, not a
  // date" — true while the wheel drew no lifespans, and false the
  // moment it drew them. Every man this branch can reach has an arc on
  // the chart; the one thing the search could not do was recognise the
  // name, because the family tree spelled one of them longer than the
  // chart did (Nahor the elder). So the sentence reports the spelling,
  // which was the real gap, and never an absence that is not there.
  //
  // AND THE ONE MAN IT SPOKE FOR NO LONGER NEEDS IT: the Israel band
  // displays "Nahor (the elder)" now, so that name reaches a record.
  // Kept because it is a guard on the data rather than a case for a
  // person — see `_amPersonFor` — and because a string deleted the day
  // its last caller went quiet is a string someone has to write again.
  'wheelFindAmElsewhere': {
    'zh-Hans': '{name}的生平已画在本图上，只是本图所用的名字略短。'
        '同一组年数，自创世起算，另绘于「圣经年代」。',
    'zh-Hant': '{name}的生平已畫在本圖上，只是本圖所用的名字略短。'
        '同一組年數，自創世起算，另繪於「聖經年代」。',
    'en': "{name}'s life is drawn on this wheel; the chart spells the "
        'name more briefly than the family tree does. The same figures, '
        'counted from the creation, are charted in Bible Chronology.',
  },
  'wheelFindCount': {
    'zh-Hans': '{n} 项',
    'zh-Hant': '{n} 項',
    'en': '{n} results',
  },
  // English needs its own singular; Chinese does not inflect, so both
  // scripts reuse the plural form and the caller picks by count.
  'wheelFindCountOne': {
    'zh-Hans': '{n} 项',
    'zh-Hant': '{n} 項',
    'en': '{n} result',
  },
  // The one cap in the search, said out loud. A sorted list that stops
  // without saying so is a hidden filter.
  'wheelFindNearNote': {
    'zh-Hans': '含年份最接近的 {n} 件大事，各自年份如下。',
    'zh-Hant': '含年份最接近的 {n} 件大事，各自年份如下。',
    'en': 'Includes the {n} events nearest that year; each row shows its own.',
  },
  'wheelFindNear': {'zh-Hans': '年份相近', 'zh-Hant': '年份相近', 'en': 'nearby'},
  // The spelling the app does NOT print, named as what it is rather
  // than offered as a bare second name. Four men on this wheel are
  // drawn under the form the modern versions read and the Authorised
  // Version — which this app also ships, and which is the only English
  // text some readers have in front of them — spells them otherwise.
  // Printing the edition's name is the difference between "this is also
  // him" and "your Bible calls him this".
  'wheelNameKjv': {
    'zh-Hans': '英王钦定本作 {name}',
    'zh-Hant': '英王欽定本作 {name}',
    'en': 'King James Version: {name}',
  },
  'wheelFindSpan': {'zh-Hans': '横跨该年', 'zh-Hant': '橫跨該年', 'en': 'spans it'},
  'wheelFindInDesc': {
    'zh-Hans': '见于说明',
    'zh-Hant': '見於說明',
    'en': 'in the description',
  },
  // The name is substituted rather than left to stand alone, because
  // the reader typed it: a row whose reason simply echoes the query
  // explains nothing. Five of the 37 people the wheel's records name
  // appear in no title or description in the whole corpus, so for
  // those this line is the only thing on screen connecting what was
  // typed to what came back.
  'wheelFindPerson': {
    'zh-Hans': '记有{name}',
    'zh-Hant': '記有{name}',
    'en': 'names {name}',
  },
  'wheelFindHiddenBand': {
    'zh-Hans': '该带已隐藏 · 打开即显示',
    'zh-Hant': '該帶已隱藏 · 開啟即顯示',
    'en': 'band hidden — opening this shows it again',
  },
  'wheelKindEvent': {'zh-Hans': '大事', 'zh-Hant': '大事', 'en': 'event'},
  'wheelKindPower': {'zh-Hans': '政权', 'zh-Hant': '政權', 'en': 'power'},
  'wheelKindNation': {'zh-Hans': '列族', 'zh-Hant': '列族', 'en': 'nation'},
  'wheelKindBand': {'zh-Hans': '带', 'zh-Hant': '帶', 'en': 'band'},
  'wheelKindLife': {'zh-Hans': '生平', 'zh-Hant': '生平', 'en': 'life'},
  // The kind column of a row that is not a record OF anything on the
  // chart. It has to read as a fact about the TEXT rather than about
  // this app — "no date" says the date does not exist to be had, where
  // "not on the chart" would say we left it out. The year column beside
  // it is empty, so the two columns of the row say the same thing in
  // two ways, which is deliberate: the year column being blank is
  // otherwise indistinguishable from a bug.
  'wheelKindOmission': {
    'zh-Hans': '无从定年',
    'zh-Hant': '無從定年',
    'en': 'no date',
  },
  // The line where a ministry sheet prints its years. Says what is
  // missing AND whose silence it is, in one sentence, because the
  // reader arrives here from rows that all had a year and needs to know
  // within a second that this one is not a loading state.
  'wheelOmissionNoSpan': {
    'zh-Hans': '本图未画：经文没有给出可据以落笔的年份。',
    'zh-Hant': '本圖未畫：經文沒有給出可據以落筆的年份。',
    'en': 'Not drawn on this chart: the text gives no year to draw it at.',
  },

  // ── the lifespan layer ─────────────────────────────────────────────

  'wheelLifespans': {
    'zh-Hans': '列祖寿数',
    'zh-Hant': '列祖壽數',
    'en': 'Genesis lifespans',
  },
  // The filter row's second line, and the only place on screen that
  // says which text the ARCS are drawn from. Both traditions are
  // printed on every arc's own sheet; this says which one has the
  // geometry, because a reader looking at a length is looking at a
  // claim and is owed the source of it without a tap.
  'wheelLifespansNote': {
    'zh-Hans': '亚当至摩西 · 创世记 5、11 章 · 按马所拉经文绘制',
    'zh-Hant': '亞當至摩西 · 創世記 5、11 章 · 按馬所拉經文繪製',
    'en': 'Adam to Moses · Genesis 5 and 11 · drawn on the Masoretic text',
  },
  // Kept as a string rather than read from `chronology.json`'s
  // `traditions[0].name` on purpose: the legend is drawn at rest, on
  // every frame, from a synchronous read, and a legend that goes blank
  // for the first frame after a cold load is a legend that says nothing
  // about the arcs already on screen. The SHEET reads the asset.
  'wheelLifespansTradition': {
    'zh-Hans': '马所拉经文',
    'zh-Hant': '馬所拉經文',
    'en': 'Masoretic',
  },
  // Where the Greek's BC years come from. The {year} is derived, never
  // written: the two chains meet at Abram leaving Haran — the wheel's
  // own `abram_called`, from Thiele — so the Greek creation is that
  // year less the Greek's own count to it.
  'wheelLifeSeptuagintChain': {
    'zh-Hans': '希腊文经文的年数，自与马所拉同一个定点——亚伯兰离开哈兰——'
        '按其自身的年数链上溯，故其创世之年为{year}。此年数链不作绘制：'
        '若一并画上轴，全图每一件事都要让出约五分之一的余地。',
    'zh-Hant': '希臘文經文的年數，自與馬所拉同一個定點——亞伯蘭離開哈蘭——'
        '按其自身的年數鏈上溯，故其創世之年為{year}。此年數鏈不作繪製：'
        '若一併畫上軸，全圖每一件事都要讓出約五分之一的餘地。',
    'en': "The Greek text's own years, counted back from the same point "
        'the Masoretic is — Abram leaving Haran — along its own chain, '
        'which puts its creation at {year}. It is printed and not drawn: '
        'carrying it on the axis would cost every event on this chart '
        'about a fifth of its room.',
  },
  'wheelLifeYears': {
    'zh-Hans': '享年 {n} 岁',
    'zh-Hant': '享年 {n} 歲',
    'en': '{n} years',
  },
  // "Anno Mundi", the count the text itself gives. Printed beside the
  // BC years rather than instead of them: the AM figure is what
  // Genesis states and the BC year is what this app derived, and a
  // reader must be able to tell those apart.
  'wheelLifeAm': {
    'zh-Hans': '创世后 {a}–{b} 年',
    'zh-Hant': '創世後 {a}–{b} 年',
    'en': 'Anno Mundi {a}–{b}',
  },
  // What the two hairlines mean. Written because the feature is
  // invisible until it is used and unguessable when it is.
  'wheelLifeContemporaries': {
    'zh-Hans': '选中时，两条细线画出他生卒的两个年份；线间跨过的每一道弧，都是与他同世之人。',
    'zh-Hant': '選中時，兩條細線畫出他生卒的兩個年份；線間跨過的每一道弧，都是與他同世之人。',
    'en': 'Selected, two hairlines mark his birth year and his death year. '
        'Every arc they cross is a life that overlapped his.',
  },
  // The second sentence the AM hand-off never had. Genesis 4:17-24
  // names ten of Cain's line and gives not one age, interval or total,
  // so there is nothing to draw and nothing to date — and a bare
  // "nothing matches" about a man this app holds a record for is the
  // false absence this whole hand-off exists to stop.
  'wheelFindNoYears': {
    'zh-Hans': '{name}记在「圣经家谱」里。经文没有给{name}任何年岁或年数，'
        '所以本图无从落笔。',
    'zh-Hant': '{name}記在「聖經家譜」裡。經文沒有給{name}任何年歲或年數，'
        '所以本圖無從落筆。',
    'en': '{name} is in the Family Tree. The text gives no age and no '
        'interval for {name}, so there is nothing this chart could draw.',
  },
};

/// Type size ON SCREEN at rest, in logical pixels.
const double _kLabelPx = 10.5;

/// The verse beside a label is set smaller than the label itself.
const double _kRefSizeRatio = 0.86;

/// The width of one rim label, in canvas units.
///
/// The planner and the painter must agree to the pixel about what a
/// string measures, so both go through this. A style that differs here
/// from the one `_radialLabel` paints with would decide "it fits" about
/// a string nobody draws. The one deliberate exception is the selected
/// label, which is painted semibold and so runs a little wider than it
/// was measured — it is the one the reader just tapped, and its whole
/// purpose is to stand out.
// 2026-08-31 (#318): every style on this page's canvas is built by
// `canvasTextStyle`, not `TextStyle`. A TextPainter inherits no theme,
// and on the web build a style with no `fontFamilyFallback` has no face
// that can render Chinese at all — the label goes absent, not tofu. This
// one is a MEASUREMENT, and it must use the same face as the paint or
// `fitRadialLabel` is reserving room for a string nobody draws.
double _measureLabel(String text, double size) => (TextPainter(
      text: TextSpan(text: text, style: canvasTextStyle(fontSize: size)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout())
    .width;

/// A tangential label's width: the sum of its characters, because
/// `_charsOnArc` sets them one at a time along the curve. Shaping the
/// whole string would measure a line nobody draws.
double _measureChars(String text, double size) {
  var total = 0.0;
  for (final ch in text.characters) {
    total += (TextPainter(
      text: TextSpan(text: ch, style: canvasTextStyle(fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout())
        .width;
  }
  return total;
}

/// How type responds to zoom.
///
/// Dividing the canvas size by the full zoom holds letters at a
/// constant size on screen — mathematically tidy, and wrong: a reader
/// who zooms to 500% has asked to see this part BETTER, and type that
/// refuses to grow reads as a chart that ignored them. Dividing by
/// `sqrt(zoom)` instead means the on-screen size grows as `sqrt(zoom)`:
/// at 500% the letters are a bit over twice the size they were, while
/// the wheel buys real angular room, so more labels appear as well.
/// Legibility and density both improve, which is what zooming is for.
double _labelScale(double zoom) => math.pow(zoom, 0.5).toDouble();

/// A year as this page prints it: `586 BC` / `主前586` / `AD 33` / `主後33`.
///
/// 后 and 後 ARE NOT THE SAME CHARACTER outside Simplified — 后 is a
/// queen, 後 is "after" — so one `startsWith('zh')` test printed
/// Simplified 主后 to Traditional readers on 382 of the 491 events, on
/// the 27 powers whose span touches AD, and on the axis range in the
/// hub. The app's own `ui_strings.dart` already distinguishes them
/// (主后 7-10 世紀 against 主後 7-10 世紀 at :1045/:1047), so this was a
/// slip and not a house style. Same defect, same fix, for 约 / 約 —
/// [approximatePrefix], on the 161 events the references do not
/// settle. That one had been made in two more places, so it now lives
/// once, in `date_hedge.dart`.
///
/// [parseWheelYears] accepts everything this function emits, in every
/// locale, and a test round-trips all 588 events through both — the
/// search box must never fail to find a year the chart is showing.
String yearLabel(int year, String locale) {
  final zh = locale.startsWith('zh');
  if (year < 0) return zh ? '主前${-year}' : '${-year} BC';
  if (!zh) return 'AD $year';
  return locale == 'zh-Hant' ? '主後$year' : '主后$year';
}

/// What a 500-year tick prints, which is [yearLabel] everywhere except
/// at zero.
///
/// **There is no year zero in the era this chart counts in.** The
/// Dionysian reckoning runs 1 BC → AD 1 with nothing between, so the
/// `AD 0` / `主后0` this tick printed until 2026-08-26 named a year that
/// has never existed — the app stating something untrue on a scholarly
/// surface, which is the one class of defect that outranks everything
/// else here.
///
/// The internal numbering is astronomical, where 0 does exist and is
/// 1 BC. That does not rescue the label; it makes it worse, because the
/// two systems disagree by exactly one year over the whole BC half and
/// `-586` is printed as `586 BC` throughout, which is the Dionysian
/// reading. One asset cannot be read both ways.
///
/// What the tick actually marks is the boundary. Its neighbours are one
/// unit either side of it, and on an axis where a degree is 19 years the
/// half-year the two conventions differ by is not a distance anything
/// here can express. So it is named as a boundary rather than as a date,
/// and the two ticks beside it — 500 BC and AD 500 — already say which
/// way each half runs.
String centuryTickLabel(int year, String locale) => year == 0
    ? (wheelStrings['wheelEraBoundary']?[locale] ??
        wheelStrings['wheelEraBoundary']!['en']!)
    : yearLabel(year, locale);

// ── what gets drawn ──────────────────────────────────────────────────

/// A power's arc on its band.
class _Arc {
  const _Arc(this.power, this.ring, this.a0, this.a1, this.color);
  final WheelPower power;
  final int ring;
  final double a0;
  final double a1;
  final Color color;
}

/// One patriarch's life, placed and fitted.
///
/// Everything the painter needs and nothing it has to decide. The name
/// is what [fitArcLabel] and [placeArcName] between them agreed this
/// arc can honestly carry at this size, in the stretch of it no spoke
/// title crosses — so an empty [name] means the arc keeps its ink and
/// loses its word, the rule the rim already lives by. Same reason the
/// spoke's text is resolved outside the painter: canvas text leaves no
/// widget for a test to find, and a decision taken inside `paint` is a
/// decision nothing can read.
class _Life {
  const _Life({
    required this.man,
    required this.king,
    required this.ministry,
    required this.id,
    required this.arc,
    required this.centre,
    required this.stroke,
    required this.pitch,
    required this.color,
    required this.name,
    required this.nameA0,
    required this.nameSweep,
    required this.nameSize,
  });

  /// Exactly one of these is non-null, and [id] is what both answer to.
  /// A record type would have been tidier and would also have made the
  /// tap handler's two branches look optional; they are not.
  final Patriarch? man;
  final HebrewKing? king;
  final WheelMinistry? ministry;
  final String id;
  final LifeArc arc;

  /// The radius of this life's sub-ring, ring 0 innermost.
  final double centre;
  final double stroke;

  /// Centre-to-centre spacing of the sub-rings, which is the TAP
  /// target: the whole of a sub-ring's share of the annulus belongs to
  /// the life in it, not merely the width of the stroke. At 700 px
  /// eleven rings in the annulus are 9.7 units apart, which clears the
  /// nine the spokes use as a finger target; at 1400 px it is 19.9.
  final double pitch;

  final Color color;

  /// Empty when no legible name would fit the free part of the arc.
  final String name;
  final double nameA0;
  final double nameSweep;
  final double nameSize;
}

/// A cohort placed on the rail: its angle, and the radius of the rail.
class _Rail {
  const _Rail({
    required this.cohort,
    required this.angle,
    required this.centre,
    required this.pitch,
  });

  final LineageCohort cohort;
  final double angle;

  /// The rail's own radius — the innermost sub-ring of the arc annulus,
  /// reserved for it. See [_RadialChronologyPageState._reservedRings].
  final double centre;

  /// The sub-ring's depth, which is the tap target: a mark on the rail
  /// owns its share of the annulus the same way an arc owns its own.
  final double pitch;
}

/// An event's radial label: a tick at the band, then text running out.
///
/// [title] and [ref] are what `planRadialSpokes` decided this label can
/// honestly say at this size — already localised, already fitted. The
/// painter draws them and makes no judgement of its own, which is the
/// only way anything can test canvas text: nothing in the suite can
/// read a `TextPainter`, but every one of these strings is reachable.
class _Spoke {
  const _Spoke(
      this.members, this.event, this.label, this.color, this.title, this.ref,
      {this.badge = ''});

  /// Every event this spoke stands for, in year order, including
  /// [event]. A spoke is never empty and is usually one event long.
  final List<WheelHistoryEvent> members;

  /// The one whose title is drawn and whose year the tick marks.
  final WheelHistoryEvent event;
  final RadialLabel label;
  final Color color;

  /// Empty when the label would not have been legible and only the tick
  /// is drawn.
  final String title;
  final String ref;

  /// `+65` when this spoke stands for more than itself.
  final String badge;

  int get hidden => members.length - 1;
}

class _RadialChronologyPageState extends State<RadialChronologyPage> {
  Future<WheelHistoryData>? _future;
  final _viewer = TransformationController();

  /// Streams the reader has switched off. Empty means all on.
  final Set<String> _hidden = {};
  String? _selectedId;

  /// The viewer's current scale.
  ///
  /// Everything about legibility hangs off this. InteractiveViewer
  /// magnifies the whole canvas, so type drawn at a fixed canvas size
  /// grows on screen as you zoom — which is backwards. What a reader
  /// wants is type that stays the SAME size on screen while more of it
  /// fits as they zoom in, the way a map behaves. So the painter is
  /// given the zoom and divides by it, and the label thinning uses the
  /// resulting on-screen size to decide how many labels can fit
  /// without touching.
  double _zoom = 1;

  @override
  void initState() {
    super.initState();
    _future = WheelHistoryService.instance.load();
    _viewer.addListener(_onZoom);
    // Own the address bar while this page is up, so a reader who
    // shares the link sends people to the wheel and not to whatever
    // chapter they happened to have open behind it.
    // `owner: this` so this State's own release cannot clear a claim a
    // LATER wheel has taken over — see `UrlClaim`.
    UrlSyncService.claimUrl(kWheelUrlPath, owner: this);
  }

  void _onZoom() {
    final z = _viewer.value.getMaxScaleOnAxis();
    // Repaint only on a change worth repainting for.
    if ((z - _zoom).abs() > 0.02) setState(() => _zoom = z);
  }

  /// Zoom about the centre of what the reader is LOOKING AT.
  ///
  /// A bare `scale()` multiplies the matrix about the child's own
  /// origin — its top-left — so every press throws the wheel off
  /// towards a corner and the reader has to drag it back. The fix is
  /// the standard one: translate the viewport centre to the origin,
  /// scale there, translate back. Whatever is in the middle of the
  /// screen stays in the middle.
  void _zoomBy(double factor) {
    final size = _viewportSize;
    if (size == null) return;
    final m = _viewer.value.clone();
    final z = m.getMaxScaleOnAxis();
    final applied = (z * factor).clamp(0.8, 14.0) / z;
    if ((applied - 1).abs() < 0.001) return;

    // The scene point currently under the middle of the viewport.
    final focal = Offset(size.width / 2, size.height / 2);
    final scene = _toScene(m, focal);

    _viewer.value = m
      ..translateByDouble(scene.dx, scene.dy, 0, 1)
      ..scaleByDouble(applied, applied, 1, 1)
      ..translateByDouble(-scene.dx, -scene.dy, 0, 1);
  }

  /// Inverse-transform a viewport point into scene coordinates.
  ///
  /// MatrixUtils rather than a Vector3, so this needs no dependency
  /// beyond Flutter itself — vector_math is only a transitive one.
  Offset _toScene(Matrix4 m, Offset viewportPoint) =>
      MatrixUtils.transformPoint(Matrix4.inverted(m), viewportPoint);

  Size? _viewportSize;

  /// The side of the square canvas at the last layout — what turns a
  /// year into a point search can pan to.
  double _side = 0;

  void _resetZoom() => _viewer.value = Matrix4.identity();

  @override
  void dispose() {
    UrlSyncService.claimUrl(null, owner: this);
    _viewer.removeListener(_onZoom);
    _viewer.dispose();
    _findCtl.dispose();
    super.dispose();
  }

  String _s(String key, String fallback, String locale) =>
      uiStrings[key]?[locale] ?? wheelStrings[key]?[locale] ?? fallback;

  void _select(String? id) => setState(() => _selectedId = id);

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    final wb = WbColors.of(context);

    return Scaffold(
      backgroundColor: wb.paneBg,
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(_s('wheelTitle', 'World History Wheel', locale)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: _s('wheelFind', 'Find', locale),
            onPressed: () => _showSearch(context, locale),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: _s('wheelFilter', 'Filter', locale),
            onPressed: () => _showFilter(context, locale),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: _s('wheelAbout', 'About this chart', locale),
            onPressed: () => _showAbout(context, locale),
          ),
          const LanguageSwitcherButton(),
          const HomeIconButton(),
        ],
      ),
      body: FutureBuilder<WheelHistoryData>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child:
                    Text('${snap.error}', style: TextStyle(color: wb.mutedText)),
              ),
            );
          }
          final data = snap.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _body(context, data, locale);
        },
      ),
    );
  }

  /// The bands actually drawn, outermost first. A hidden stream is
  /// dropped entirely rather than left as a gap, so switching one off
  /// gives the rest more room instead of leaving a hole.
  List<WheelStream> _visible(WheelHistoryData d) =>
      d.streams.where((s) => !_hidden.contains(s.id)).toList();

  /// Per-band colours, computed from the FULL stream list rather than
  /// the visible one — hiding a band must not recolour the rest.
  Map<String, Color> _colorsFor(WheelHistoryData data) {
    final byLine = <String, List<String>>{};
    for (final s in data.streams) {
      byLine.putIfAbsent(s.line, () => []).add(s.id);
    }
    final out = <String, Color>{};
    for (final s in data.streams) {
      final family = byLine[s.line]!;
      out[s.id] = streamColor(s.line, family.indexOf(s.id), family.length);
    }
    return out;
  }

  Widget _body(BuildContext context, WheelHistoryData data, String locale) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final streams = _visible(data);
    final ringOf = {for (var i = 0; i < streams.length; i++) streams[i].id: i};
    final colors = _colorsFor(data);

    return LayoutBuilder(builder: (context, box) {
      _viewportSize = Size(box.maxWidth, box.maxHeight);
      final side = math.min(box.maxWidth, box.maxHeight);
      _side = side;
      final hubD = side * _kHubFrac * 2;
      final rBands = side * _kBandsFrac;
      final rRim = side * _kRimFrac;

      final arcs = _buildArcs(data, ringOf, colors);
      final spokes = _buildSpokes(data, ringOf, rBands, rRim, colors, locale,
          t.scaledChrome(_kLabelPx));
      // AFTER the spokes, because the arc names have to dodge the spoke
      // titles and cannot know where they are until they are planned.
      final lives = _buildLifespans(
          rBands, rRim, spokes, locale, t.scaledChrome(_kLabelPx));
      final rail = _buildRail(rBands, rRim, lives);

      return Stack(children: [
        Positioned.fill(
          child: InteractiveViewer(
            transformationController: _viewer,
            maxScale: 14,
            minScale: 0.8,
            child: Center(
              child: SizedBox(
                width: side,
                height: side,
                child: GestureDetector(
                  // The wheel is one square canvas and every band, arc
                  // and spoke is painted, not laid out, so a test can
                  // only reach a detail sheet by tapping a computed
                  // point. This key is how it finds the square and its
                  // centre — same reason as `chronologyAxis` on the
                  // sibling page.
                  key: const ValueKey('chronologyWheel'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (e) => _handleTap(context, e.localPosition, side,
                      data, streams, arcs, spokes, lives, rail, locale),
                  child: Stack(children: [
                    CustomPaint(
                      size: Size(side, side),
                      painter: _WorldWheelPainter(
                        streams: streams,
                        colors: colors,
                        arcs: arcs,
                        spokes: spokes,
                        lives: lives,
                        rail: rail,
                        locale: locale,
                        selectedId: _selectedId,
                        wb: wb,
                        zoom: _zoom,
                        rimFont: t.scaledChrome(_kLabelPx),
                        endFont: t.scaledChrome(11),
                        bandFont: t.scaledChrome(10),
                      ),
                    ),
                    // The hub says where you are; it is not part of the
                    // chart. Inside the zoomable child it was magnified
                    // with everything else and swallowed the middle of
                    // the screen at 384%. It now shrinks against the
                    // zoom and fades out entirely once the reader has
                    // zoomed in to read — by then they know what they
                    // are looking at, and the space is worth more than
                    // the caption.
                    Center(
                      child: Opacity(
                        opacity: (1.6 - _zoom).clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 1 / _zoom,
                      child: SizedBox(
                        width: hubD * 0.94,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _s('wheelTitle', 'World History Wheel', locale),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: wb.text,
                                fontSize: t.scaled(12),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: t.scaled(4)),
                            Text(
                              '${yearLabel(kMinYear, locale)} – '
                              '${yearLabel(kMaxYear, locale)}',
                              style: TextStyle(
                                  color: wb.mutedText,
                                  fontSize: t.scaled(11)),
                            ),
                            SizedBox(height: t.scaled(3)),
                            Text(
                              // Bands, powers, events — and the lives,
                              // last and only when the layer is on, so
                              // the count is of what is actually drawn
                              // rather than of what the file holds.
                              '${streams.length} · ${data.powers.length} · '
                              '${data.events.length}'
                              '${lives.isEmpty ? '' : ' · ${lives.length}'}',
                              style: TextStyle(
                                  color: wb.mutedText,
                                  fontSize: t.scaled(11)),
                            ),
                            SizedBox(height: t.scaled(3)),
                            Text(
                              _s('wheelHint', '', locale),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: wb.mutedText,
                                  fontSize: t.scaled(11)),
                            ),
                          ],
                        ),
                      ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
        Positioned(left: 10, bottom: 10, child: _legend(locale, t, wb)),
        Positioned(right: 10, bottom: 10, child: _zoomControls(locale, t, wb)),
      ]);
    });
  }

  /// Zoom controls, because a desktop reader has no pinch.
  ///
  /// InteractiveViewer answers a trackpad and a scroll wheel, but
  /// neither is discoverable and a mouse-only reader was left with a
  /// wheel they could not enlarge — which is what made the labels
  /// unreadable rather than merely dense. The percentage is shown
  /// because at 300% the reader should know why more labels appeared.
  Widget _zoomControls(String locale, WbType t, WbColors wb) {
    Widget btn(IconData icon, String tip, VoidCallback go) => InkWell(
          onTap: go,
          child: Padding(
            padding: EdgeInsets.all(t.scaled(6)),
            child: Tooltip(
              message: tip,
              child: Icon(icon, size: t.scaled(17), color: wb.text),
            ),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        color: wb.paneBg.withValues(alpha: 0.94),
        border: Border.all(color: wb.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        btn(Icons.remove, '−', () => _zoomBy(1 / 1.4)),
        Container(width: 1, height: t.scaled(18), color: wb.border),
        SizedBox(
          width: t.scaled(46),
          child: Text('${(_zoom * 100).round()}%',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: wb.mutedText, fontSize: t.scaled(11))),
        ),
        Container(width: 1, height: t.scaled(18), color: wb.border),
        btn(Icons.add, '+', () => _zoomBy(1.4)),
        Container(width: 1, height: t.scaled(18), color: wb.border),
        btn(Icons.center_focus_strong,
            _s('wheelReset', 'Reset', locale), _resetZoom),
      ]),
    );
  }

  List<_Arc> _buildArcs(WheelHistoryData data, Map<String, int> ringOf,
      Map<String, Color> colors) {
    final out = <_Arc>[];
    for (final p in data.powers) {
      final ring = ringOf[p.stream];
      if (ring == null) continue;
      out.add(_Arc(
        p,
        ring,
        angleForSpan(p.start, kMinYear, kMaxYear),
        angleForSpan(p.endFor(kMaxYear), kMinYear, kMaxYear),
        colors[p.stream] ?? _lineColor('none'),
      ));
    }
    return out;
  }

  /// Events become radial labels in the annulus outside the bands.
  ///
  /// Sorted by angle so the stacker can see neighbours: several events
  /// in one year step outward along the same spoke instead of printing
  /// on top of each other. In practice that almost never happens on
  /// this corpus and the page comment used to claim otherwise — the
  /// declutter below keeps consecutive labels at least `minGap` apart
  /// and the stacker only stacks within `minGap / 2`, so the two are
  /// arranged so that stacking is unreachable except for a selected
  /// event forced back in. `wheel_label_legibility_test.dart` pins that
  /// relationship rather than leaving it as a belief.
  List<_Spoke> _buildSpokes(
    WheelHistoryData data,
    Map<String, int> ringOf,
    double rBands,
    double rRim,
    Map<String, Color> colors,
    String locale,
    double rimFont,
  ) {
    final all = data.events.where((e) => ringOf.containsKey(e.stream)).toList()
      ..sort((a, b) => a.year.compareTo(b.year));
    if (all.isEmpty) return const [];

    // ── DECLUTTER, the way a map does ──────────────────────────────
    //
    // 588 labels round 320° is one every 0.54° — far past shoulder to
    // shoulder, and the reader's complaint was exactly that: too dense
    // to read. (This comment used to say 189, the corpus size when it
    // was written; the figure below was derived from that one and is
    // wrong by the same neglect.) Drawing them all and letting them
    // touch is the one thing that must not happen.
    //
    // So: a label needs about 1.35 line-heights of angular room at the
    // radius it sits on. That room is measured ON SCREEN, so zooming in
    // buys real space and more labels appear.
    //
    // WHAT THIS COMMENT USED TO SAY, and why it mattered: "at 1x
    // roughly half the corpus is drawn, by 3x all of it. Nothing is
    // lost." Measured through this very arithmetic over the shipped 491
    // events on a 900 px canvas, it is 55 at 1x — 11%, not half — and
    // 136 at the `InteractiveViewer`'s maximum 14x, so about 72% of the
    // corpus can be seen at NO magnification this app permits. Zoom
    // cannot in principle rescue the worst of it: angle is linear in
    // the year, so the 125 events sharing a year with another event sit
    // at identical angles for ever. A false belief about the data
    // became a design that shipped a silent 89% cut with the figure 491
    // printed in the hub two inches away.
    //
    // Nothing is DROPPED now. Events that cannot each have a label are
    // grouped, and the spoke that survives says how many it stands for
    // and lists them when tapped — see [clusterByAngle]. The grouping
    // rule is the old keep-rule read the other way round, so every
    // label that used to be drawn is still drawn, at the same angle.
    final onScreenPx = _kLabelPx * 1.35;
    final minGap = (onScreenPx / _labelScale(_zoom)) / rBands;

    final angles = [
      for (final e in all) angleForSpan(e.year, kMinYear, kMaxYear)
    ];
    // Selection always survives the thinning: hiding the thing the
    // reader just tapped would be indefensible. It now represents its
    // cluster instead of being added beside it.
    final clusters = clusterByAngle(angles, minGap,
        pinned: all.indexWhere((e) => e.id == _selectedId));
    final kept = [for (final c in clusters) all[c.representative]];

    // ── THE SCRIPTURE BASELINE ────────────────────────────────────
    //
    // Events the text itself dates start on one shared radius; events
    // that rest on a general reference start outside it. Two groups,
    // one boundary — so a reader can see at a glance which claims the
    // Bible makes and which the world's chronologies make, without
    // opening anything.
    //
    // This ADDS ORDER rather than ornament: it is the same labels,
    // aligned rather than scattered, plus a single hairline arc to
    // mark where the line is. Nothing new competes for attention.
    //
    // Which radius each group starts from, how much room each label
    // gets, and what it can legibly say are all `planRadialSpokes` —
    // kept out of the painter because the painter cannot be tested.
    final titleSize = rimFont / _labelScale(_zoom);
    final planned = planRadialSpokes(
      requests: [
        for (var i = 0; i < kept.length; i++)
          SpokeRequest(
            angle: angles[clusters[i].representative],
            // `thiele` counts as the scripture side: the reign lengths
            // it is counted along are the text's own.
            scripture: kept[i].basis != 'conventional',
            title: kept[i].titleFor(locale),
            ref: kept[i].refs.isEmpty
                ? ''
                : localizedReferenceLabel(kept[i].refs.first, locale),
            badge: clusters[i].hidden == 0 ? '' : '+${clusters[i].hidden}',
          )
      ],
      rBands: rBands,
      rRim: rRim,
      titleSize: titleSize,
      refSize: titleSize * _kRefSizeRatio,
      measure: _measureLabel,
      minGap: minGap,
      lineHeight: titleSize * 1.35,
    );
    return [
      for (final p in planned)
        _Spoke(
          [for (final m in clusters[p.index].members) all[m]],
          kept[p.index],
          p.label,
          colors[kept[p.index].stream] ?? _lineColor('none'),
          p.title,
          p.ref,
          badge: p.badge,
        )
    ];
  }

  // ── the lifespans ──────────────────────────────────────────────────

  /// The tradition the ARCS are drawn on. The other one is printed on
  /// every sheet; see the class comment for why it is not an axis
  /// toggle.
  static const String _kDrawnTradition = kDrawnTradition;

  /// The creation year, or null when the asset does not carry it.
  ///
  /// One field, read in one place. `TimelineService` has parsed it by
  /// the time any wheel data exists (`WheelHistoryService.load` awaits
  /// it), and a null here means the layer draws nothing — never a
  /// literal. A silent -4000 is the calendar this anchor replaced, and
  /// it would put Methuselah's death four years after the flood spoke.
  int? get _creationYear => TimelineService.instance.meta.creation?.year;

  /// The 25 Masoretic lives, packed into sub-rings of the annulus and
  /// fitted with whatever name each can legibly carry.
  ///
  /// [spokes] is passed in — already planned — because the names have
  /// to dodge them. A tangential name laid across a radial title is two
  /// illegible strings, so a name goes in the widest stretch of its own
  /// arc that no spoke TITLE crosses, and a life with no such stretch
  /// keeps its ink and loses its word.
  ///
  List<LifeArc> _packBand(
    ChronologyData chron,
    int creation,
    List<HebrewKing> kings,
    List<WheelMinistry> ministries,
  ) =>
      packWheelBand(
        chron: chron,
        creationYear: creation,
        kings: kings,
        ministries: ministries,
        reservedInnerRings: _reservedRings,
      );

  /// How many innermost sub-rings the arcs must give up.
  ///
  /// One, when the genealogy rail is on. It is a RESERVED ring rather
  /// than a share of ring 0, because a cohort has no angular width and
  /// `packIntoRings` would have put every one of the 102 in ring 0
  /// beside the arcs — 102 marks printed over Adam, Seth and Enosh.
  ///
  /// It costs: with all three arc layers on the band goes from fifteen
  /// sub-rings to sixteen, and at the smallest canvas a sub-ring from
  /// 7.13 px to 6.69. That is why this layer has its own switch, and
  /// why `wheel_lifespans_test.dart` pins all three states.
  int get _reservedRings => _hidden.contains(kLineageLayerId) ? 0 : 1;

  /// The genealogy rail: 107 year-marks, and the people behind each.
  List<_Rail> _buildRail(double rBands, double rRim, List<_Life> lives) {
    if (_hidden.contains(kLineageLayerId)) return const [];
    final people = FamilyTreeService.instance.cached;
    if (people == null || people.isEmpty) return const [];
    final chron = ChronologyService.instance.cached;
    final data = WheelHistoryService.instance.cached;
    if (chron == null || data == null) return const [];

    // Everything the wheel ALREADY draws, by id. A person on another
    // layer must not also be a mark on the rail — he would be the same
    // man twice, in two styles, saying two different kinds of thing.
    final drawn = <String>{
      for (final p in chron.patriarchs) p.id,
      for (final k in HebrewKingsService.instance.cached?.kings ??
          const <HebrewKing>[])
        k.id,
      for (final e in data.events)
        for (final link in e.people) link.id,
    };
    final cohorts = lineageCohorts(people: people, drawnIds: drawn);
    if (cohorts.isEmpty) return const [];

    final inner = scriptureLabelBase(rBands);
    final rings = lifeArcRingCount(
        lives.isEmpty ? const <LifeArc>[] : [for (final l in lives) l.arc]);
    if (rings == 0) return const [];
    final band = lifeArcRadii(0, rings, inner, rRim);
    return [
      for (final c in cohorts)
        _Rail(
          cohort: c,
          angle: angleForSpan(c.year, kMinYear, kMaxYear),
          centre: band.centre,
          pitch: ringPitch(rings, inner, rRim),
        )
    ];
  }

  /// Returns empty for any of three honest reasons: the layer is
  /// switched off, the chronology asset has not loaded, or the creation
  /// anchor could not be read.
  List<_Life> _buildLifespans(
    double rBands,
    double rRim,
    List<_Spoke> spokes,
    String locale,
    double rimFont,
  ) {
    if (_hidden.contains(kLifespanLayerId)) return const [];
    final chron = ChronologyService.instance.cached;
    final creation = _creationYear;
    if (chron == null || creation == null) return const [];

    final kings = _hidden.contains(kReignLayerId)
        ? const <HebrewKing>[]
        : (HebrewKingsService.instance.cached?.kings ??
            const <HebrewKing>[]);
    final ministries = _hidden.contains(kMinistryLayerId)
        ? const <WheelMinistry>[]
        : (WheelHistoryService.instance.cached?.ministries ??
            const <WheelMinistry>[]);
    final byKingId = {for (final k in kings) '$kKingArcPrefix${k.id}': k};
    final byMinistryId = {
      for (final m in ministries) '$kMinistryArcPrefix${m.id}': m
    };
    final arcs = _packBand(chron, creation, kings, ministries);
    if (arcs.isEmpty) return const [];
    // `packWheelBand` has already shifted the arcs off the reserved
    // ring, so the count it yields is the whole annulus.
    final rings = lifeArcRingCount(arcs);
    final inner = scriptureLabelBase(rBands);

    final titleSize = rimFont / _labelScale(_zoom);
    // What a spoke's TITLE occupies in angle at a given radius. A tick
    // alone is a hairline and not worth dodging; a title is a column of
    // type one line-height wide.
    final lineHeight = titleSize * 1.35;

    final out = <_Life>[];
    for (final arc in arcs) {
      final man = chron.byId(arc.id);
      final king = byKingId[arc.id];
      final ministry = byMinistryId[arc.id];
      if (man == null && king == null && ministry == null) continue;
      final band = lifeArcRadii(arc.ring, rings, inner, rRim);
      final occupied = <ArcSpan>[
        for (final s in spokes)
          if (s.title.isNotEmpty &&
              s.label.rStart - 2 <= band.centre &&
              s.label.rEnd + 2 >= band.centre)
            (
              start: s.label.angle - (lineHeight / 2) / band.centre,
              end: s.label.angle + (lineHeight / 2) / band.centre,
            )
      ];
      final room = arcNameRoom(arc.a0, arc.a1, occupied);
      final name = man?.nameFor(locale) ??
          king?.nameFor(locale) ??
          ministry!.nameFor(locale);
      final size = fitArcLabel(
        text: name,
        radius: band.centre,
        sweep: room,
        // The sub-ring's own pitch, not the stream bands' — these
        // rings are wider, which is exactly why the names survive at
        // rest here and would not survive on a band.
        maxEm: ringPitch(rings, inner, rRim) * kArcLabelPitchFraction,
        desiredSize: titleSize,
        zoom: _zoom,
        floorPx: kArcLabelFloorPx,
        measure: _measureChars,
      );
      var a0 = 0.0;
      var sweep = 0.0;
      var drawn = '';
      if (size > 0) {
        final needed = _measureChars(name, size) / band.centre;
        final at = placeArcName(arc.a0, arc.a1, occupied, needed);
        if (at != null) {
          drawn = name;
          a0 = at;
          sweep = needed;
        }
      }
      out.add(_Life(
        man: man,
        king: king,
        ministry: ministry,
        id: arc.id,
        arc: arc,
        centre: band.centre,
        // Just over half the pitch, so two neighbouring sub-rings read
        // as two arcs with air between them rather than as a solid
        // annulus — the same reason `ringRadii` leaves a fifth of each
        // stream band unpainted.
        stroke: ringPitch(rings, inner, rRim) * 0.55,
        pitch: ringPitch(rings, inner, rRim),
        // Adam to Noah in the unaffiliated hue and Shem onward in
        // Israel's, because Genesis 10's descent BEGINS with Noah's
        // sons: painting Adam in Shem's colour would be a claim the
        // table of nations does not make. Read off the asset's own
        // `line` field rather than off a list of ids kept here — and
        // the two reign lines the same way, from the `line` that
        // `kingReignSpans` derived from the king's own `kingdom`.
        color: switch (arc.line) {
          'seth' => _lineColor('none'),
          'judah' => kingdomArcColor(Kingdom.judah),
          'israel' => kingdomArcColor(Kingdom.israel),
          'ministry' => ministryArcColor(),
          _ => _lineColor('shem'),
        },
        name: drawn,
        nameA0: a0,
        nameSweep: sweep,
        nameSize: size,
      ));
    }
    return out;
  }

  // ── legend and filter ──────────────────────────────────────────────

  Widget _legend(String locale, WbType t, WbColors wb) {
    Widget row(String line, String key, String fallback) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: t.scaled(10),
                height: t.scaled(10),
                color: _lineColor(line)),
            SizedBox(width: t.scaled(6)),
            Text(_s(key, fallback, locale),
                style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11))),
          ]),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
      decoration: BoxDecoration(
        color: wb.paneBg.withValues(alpha: 0.92),
        border: Border.all(color: wb.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row('shem', 'wheelLineShem', 'Shem'),
          row('ham', 'wheelLineHam', 'Ham'),
          row('japheth', 'wheelLineJapheth', 'Japheth'),
          row('institution', 'wheelLineInstitution', 'Church & Scripture'),
          // WHICH TEXT THE ARCS ARE DRAWN ON, on screen and not behind
          // a tap. The lengths in the annulus are a claim, and a chart
          // that draws one tradition of a disputed figure has to name
          // it where the figure is visible — the sheet says it too,
          // and says the other one's numbers as well. Absent when the
          // layer is off, because then it describes nothing.
          if (!_hidden.contains(kLifespanLayerId)) ...[
            SizedBox(height: t.scaled(3)),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: t.scaled(10),
                  height: t.scaled(4),
                  color: _lineColor('shem').withValues(alpha: 0.5)),
              SizedBox(width: t.scaled(6)),
              Text(
                '${_s('wheelLifespans', 'Genesis lifespans', locale)} · '
                '${_s('wheelLifespansTradition', 'Masoretic', locale)}',
                style: TextStyle(
                    color: wb.mutedText, fontSize: t.scaled(11)),
              ),
            ]),
            // THE REIGNS SHARE THE BAND AND ARE NOT THE SAME CLAIM.
            // A Genesis lifespan is a stated age turned into a year
            // against one anchor; a reign is Thiele's reconstruction of
            // a synchronism. They are drawn in one annulus because they
            // are both spans on one axis, so the legend has to be the
            // place a reader learns they rest on different things —
            // named by kingdom, because that is what the two hues mean.
            if (!_hidden.contains(kReignLayerId))
              for (final kingdom in const [Kingdom.judah, Kingdom.israel])
              Padding(
                padding: EdgeInsets.only(top: t.scaled(2)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: t.scaled(10),
                      height: t.scaled(4),
                      color: kingdomArcColor(kingdom).withValues(alpha: 0.5)),
                  SizedBox(width: t.scaled(6)),
                  Text(
                    '${kingdomLabel(locale, kingdom)} · '
                    '${_s('wheelKingsThiele', 'reigns (Thiele)', locale)}',
                    style: TextStyle(
                        color: wb.mutedText, fontSize: t.scaled(11)),
                  ),
                ]),
              ),
            // A THIRD KIND OF CLAIM IN THE SAME ANNULUS. A lifespan is a
            // stated age; a reign is a synchronised reconstruction; a
            // ministry is the window a text places a man's work in, and
            // twenty-five of the thirty-nine rest on nothing stronger
            // than convention. Its own hue and its own row, because a
            // reader who cannot tell the three apart has been told the
            // weakest of them in the voice of the strongest.
            if (!_hidden.contains(kMinistryLayerId))
              Padding(
                padding: EdgeInsets.only(top: t.scaled(2)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: t.scaled(10),
                      height: t.scaled(4),
                      color: ministryArcColor().withValues(alpha: 0.5)),
                  SizedBox(width: t.scaled(6)),
                  Text(
                    _s('wheelMinistries', 'Prophets & apostles', locale),
                    style: TextStyle(
                        color: wb.mutedText, fontSize: t.scaled(11)),
                  ),
                ]),
              ),
            // A TICK, NOT A BAR, and the swatch says so: these are
            // marks on a rail, not spans, because a birth year is a
            // point and none of these people has a death year the tree
            // is willing to state. The word 「约」/"approximate" is in
            // the label itself — this is the one layer on the wheel
            // whose every year rests on no verse at all.
            if (!_hidden.contains(kLineageLayerId))
              Padding(
                padding: EdgeInsets.only(top: t.scaled(2)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: t.scaled(2),
                      height: t.scaled(9),
                      color: lineageRailColor().withValues(alpha: 0.6)),
                  SizedBox(width: t.scaled(14)),
                  Text(
                    _s('wheelLineage', 'Genealogy (approximate)', locale),
                    style: TextStyle(
                        color: wb.mutedText, fontSize: t.scaled(11)),
                  ),
                ]),
              ),
          ],
          SizedBox(height: t.scaled(3)),
          Text(_s('wheelShadeNote', '', locale),
              style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11))),
          Text(_s('wheelClusterLegend', '', locale),
              style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11))),
        ],
      ),
    );
  }

  void _showFilter(BuildContext context, String locale) {
    final wb = WbColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      isScrollControlled: true,
      builder: (sheet) => FutureBuilder<WheelHistoryData>(
        future: _future,
        builder: (c, snap) {
          final t = WbType.of(c);
          final data = snap.data;
          if (data == null) return const SizedBox(height: 120);
          final colors = _colorsFor(data);
          return StatefulBuilder(builder: (c, setSheet) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheet).size.height * 0.7),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(_s('wheelFilter', 'Filter', locale),
                          style: TextStyle(
                              color: wb.text,
                              fontSize: t.scaled(15),
                              fontWeight: FontWeight.w600)),
                    ),
                    TextButton(
                      onPressed: () =>
                          setSheet(() => setState(() => _hidden.clear())),
                      child: Text(_s('wheelAll', 'All', locale)),
                    ),
                    TextButton(
                      onPressed: () => setSheet(() => setState(() {
                            _hidden.addAll(data.streams.map((s) => s.id));
                            _hidden.add(kLifespanLayerId);
                            _hidden.add(kReignLayerId);
                            _hidden.add(kMinistryLayerId);
                            _hidden.add(kLineageLayerId);
                          })),
                      child: Text(_s('wheelNone', 'None', locale)),
                    ),
                  ]),
                  // The lifespans are a LAYER, not a band: they belong
                  // to no stream, they live in the annulus rather than
                  // on a ring, and their id is deliberately not a
                  // stream id (the stream set is pinned by tests, and a
                  // collision would switch a band off with the arcs).
                  // First in the list because it is the one row here
                  // that is not a people.
                  CheckboxListTile(
                    key: const ValueKey('wheelFilterLifespans'),
                    dense: true,
                    value: !_hidden.contains(kLifespanLayerId),
                    onChanged: (_) => setSheet(() => setState(() {
                          if (!_hidden.remove(kLifespanLayerId)) {
                            _hidden.add(kLifespanLayerId);
                          }
                        })),
                    title: Text(
                        _s('wheelLifespans', 'Genesis lifespans', locale),
                        style: TextStyle(
                            color: wb.text, fontSize: t.scaled(12.5))),
                    subtitle: Text(
                      _s('wheelLifespansNote', '', locale),
                      style: TextStyle(
                          color: wb.mutedText, fontSize: t.scaled(11)),
                    ),
                    secondary: Container(
                        width: t.scaled(12),
                        height: t.scaled(12),
                        color: _lineColor('shem')),
                  ),
                  // The other two layers in the same annulus. Separate
                  // switches because they are separate kinds of claim,
                  // and because only one of them costs anything: the
                  // reigns fit in the sub-rings the patriarchs already
                  // demand, while the ministries take the band from
                  // eleven to fifteen. A reader on a small canvas who
                  // wants a bigger target turns this one off.
                  CheckboxListTile(
                    key: const ValueKey('wheelFilterReigns'),
                    dense: true,
                    value: !_hidden.contains(kReignLayerId),
                    onChanged: (_) => setSheet(() => setState(() {
                          if (!_hidden.remove(kReignLayerId)) {
                            _hidden.add(kReignLayerId);
                          }
                        })),
                    title: Text(
                        _s('wheelReigns', 'Reigns of Judah & Israel', locale),
                        style: TextStyle(
                            color: wb.text, fontSize: t.scaled(12.5))),
                    subtitle: Text(
                      _s('wheelKingsThiele', 'reigns (Thiele)', locale),
                      style: TextStyle(
                          color: wb.mutedText, fontSize: t.scaled(11)),
                    ),
                    secondary: Container(
                        width: t.scaled(12),
                        height: t.scaled(12),
                        color: kingdomArcColor(Kingdom.judah)),
                  ),
                  CheckboxListTile(
                    key: const ValueKey('wheelFilterMinistries'),
                    dense: true,
                    value: !_hidden.contains(kMinistryLayerId),
                    onChanged: (_) => setSheet(() => setState(() {
                          if (!_hidden.remove(kMinistryLayerId)) {
                            _hidden.add(kMinistryLayerId);
                          }
                        })),
                    title: Text(
                        _s('wheelMinistries', 'Prophets & apostles', locale),
                        style: TextStyle(
                            color: wb.text, fontSize: t.scaled(12.5))),
                    subtitle: Text(
                      _s('wheelMinistriesNote', '', locale),
                      style: TextStyle(
                          color: wb.mutedText, fontSize: t.scaled(11)),
                    ),
                    secondary: Container(
                        width: t.scaled(12),
                        height: t.scaled(12),
                        color: ministryArcColor()),
                  ),
                  CheckboxListTile(
                    key: const ValueKey('wheelFilterLineage'),
                    dense: true,
                    value: !_hidden.contains(kLineageLayerId),
                    onChanged: (_) => setSheet(() => setState(() {
                          if (!_hidden.remove(kLineageLayerId)) {
                            _hidden.add(kLineageLayerId);
                          }
                        })),
                    title: Text(
                        _s('wheelLineage', 'Genealogy (approximate)', locale),
                        style: TextStyle(
                            color: wb.text, fontSize: t.scaled(12.5))),
                    subtitle: Text(
                      _s('wheelLineageNote', '', locale),
                      style: TextStyle(
                          color: wb.mutedText, fontSize: t.scaled(11)),
                    ),
                    secondary: Container(
                        width: t.scaled(3),
                        height: t.scaled(12),
                        color: lineageRailColor()),
                  ),
                  for (final s in data.streams)
                    CheckboxListTile(
                      dense: true,
                      value: !_hidden.contains(s.id),
                      onChanged: (_) => setSheet(() => setState(() {
                            if (!_hidden.remove(s.id)) _hidden.add(s.id);
                          })),
                      title: Text(s.nameFor(locale),
                          style: TextStyle(
                              color: wb.text, fontSize: t.scaled(12.5))),
                      subtitle: Text(
                        '${_s('wheelPowers', 'Powers', locale)} '
                        '${data.powersOf(s.id).length} · '
                        '${_s('wheelEvents', 'Events', locale)} '
                        '${data.eventsOf(s.id).length}',
                        style: TextStyle(
                            color: wb.mutedText, fontSize: t.scaled(11)),
                      ),
                      secondary: Container(
                          width: t.scaled(12),
                          height: t.scaled(12),
                          color: colors[s.id] ?? _lineColor(s.line)),
                    ),
                ],
              ),
            );
          });
        },
      ),
    );
  }

  void _showAbout(BuildContext context, String locale) {
    final wb = WbColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      isScrollControlled: true,
      builder: (sheet) => FutureBuilder<WheelHistoryData>(
        future: _future,
        builder: (c, snap) {
          final t = WbType.of(c);
          final data = snap.data;
          if (data == null) return const SizedBox(height: 120);
          final meta = data.meta;
          Widget section(String headingKey, String headingFallback,
                  String body) =>
              body.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: EdgeInsets.only(bottom: t.scaled(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_s(headingKey, headingFallback, locale),
                              style: TextStyle(
                                  color: wb.mutedText,
                                  fontSize: t.scaled(12),
                                  fontWeight: FontWeight.w600)),
                          SizedBox(height: t.scaled(4)),
                          Text(body,
                              style: TextStyle(
                                  color: wb.mutedText,
                                  fontSize: t.scaled(12))),
                        ],
                      ),
                    );
          return _sheet(c, [
            Text(_s('wheelAbout', 'About this chart', locale),
                style: TextStyle(
                    color: wb.text,
                    fontSize: t.scaled(15),
                    fontWeight: FontWeight.w600)),
            SizedBox(height: t.scaled(8)),
            section('wheelAboutProvenance', 'Where the dates come from',
                meta.provenanceFor(locale)),
            section('wheelAboutCoverage', 'What is on the chart',
                meta.coverageFor(locale)),
            section('wheelAboutScope', 'Where the table of nations stops',
                meta.scopeFor(locale)),
            section('wheelAboutAxis', 'Where the axis stops',
                meta.axisFor(locale)),
          ]);
        },
      ),
    );
  }

  // ── find ───────────────────────────────────────────────────────────

  /// Kept on the state, not on the sheet, so a reader who closes the
  /// box to look at what it found still has their query when they
  /// reopen it.
  final _findCtl = TextEditingController();

  String _fill(String key, String fallback, String locale,
      Map<String, Object> values) {
    var out = _s(key, fallback, locale);
    for (final e in values.entries) {
      out = out.replaceAll('{${e.key}}', '${e.value}');
    }
    return out;
  }

  String _kindLabel(WheelHitKind kind, String locale) => switch (kind) {
        WheelHitKind.event => _s('wheelKindEvent', 'event', locale),
        WheelHitKind.power => _s('wheelKindPower', 'power', locale),
        WheelHitKind.nation => _s('wheelKindNation', 'nation', locale),
        WheelHitKind.stream => _s('wheelKindBand', 'band', locale),
        WheelHitKind.patriarch => _s('wheelKindLife', 'life', locale),
        WheelHitKind.ministry =>
          _s('wheelKindMinistry', 'ministry', locale),
        // The one label in this switch that names a NON-record. It sits
        // in the same column as "event" and "ministry" so the reader
        // can see at a glance that this row is a different kind of
        // answer before they open it — and the year column beside it is
        // empty, which is the same statement said twice.
        WheelHitKind.omission =>
          _s('wheelKindOmission', 'no date', locale),
      };

  /// The year column of a result row.
  ///
  /// A power gets its whole span, not just its start: half the reason
  /// to search a year is to see what was standing at the time, and
  /// "Babylon 626 BC" answers a different question from
  /// "Babylon 626–539 BC".
  String _hitYears(WheelHit hit, WheelHistoryData data, String locale) {
    if (hit.kind == WheelHitKind.power) {
      final p = _find(data.powers, (p) => p.id == hit.id);
      if (p != null) {
        final end = p.ongoing
            ? _s('wheelPresent', 'present', locale)
            : yearLabel(p.end!, locale);
        return '${yearLabel(p.start, locale)} – $end';
      }
    }
    return hit.year == null ? '' : yearLabel(hit.year!, locale);
  }

  /// Why this row is in the list, when the title alone does not show it.
  String _hitVia(WheelHit hit, String locale) => switch (hit.via) {
        WheelHitVia.otherLocale => hit.matched,
        WheelHitVia.otherSpelling => _fill(
            'wheelNameKjv', 'King James Version: {name}', locale,
            {'name': hit.matched}),
        WheelHitVia.description => _s('wheelFindInDesc', 'in the description',
            locale),
        WheelHitVia.person => _s('wheelFindPerson', 'names {name}', locale)
            .replaceFirst('{name}', hit.matched),
        WheelHitVia.reference => localizedReferenceLabel(hit.matched, locale),
        WheelHitVia.yearSpan => _s('wheelFindSpan', 'spans it', locale),
        WheelHitVia.yearNear => _s('wheelFindNear', 'nearby', locale),
        _ => '',
      };

  static T? _find<T>(List<T> xs, bool Function(T) test) {
    for (final x in xs) {
      if (test(x)) return x;
    }
    return null;
  }

  /// The command line BibleWorks' Timeline has and this wheel did not.
  ///
  /// 64 of 588 events carry a label at rest, so before this there was
  /// no way to reach a record you could not already see. The search
  /// itself is `searchWheel`, kept pure and tested; everything here is
  /// presentation and the one thing presentation must get right — a
  /// row has to say WHY it matched when the title does not show it.
  void _showSearch(BuildContext context, String locale) {
    final wb = WbColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      isScrollControlled: true,
      builder: (sheet) => FutureBuilder<WheelHistoryData>(
        future: _future,
        builder: (c, snap) {
          final data = snap.data;
          if (data == null) return const SizedBox(height: 120);
          final t = WbType.of(c);
          final colors = _colorsFor(data);
          return StatefulBuilder(builder: (c, setSheet) {
            final query = _findCtl.text;
            final result = searchWheel(
              data: data,
              query: query,
              locale: locale,
              axisEnd: kMaxYear,
              hiddenStreams: _hidden,
              // The 25 lives, so a reader typing "Methuselah" reaches
              // the arc as well as the birth spoke — and so a reader
              // typing a year is told who was alive in it, which on
              // this stretch of the axis is often the only question
              // the text can answer.
              patriarchs:
                  ChronologyService.instance.cached?.patriarchs ?? const [],
              creationYear: _creationYear,
              tradition: _kDrawnTradition,
            );
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(sheet).bottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(sheet).size.height * 0.7),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: TextField(
                      key: const ValueKey('wheelFindField'),
                      controller: _findCtl,
                      autofocus: true,
                      style:
                          TextStyle(color: wb.text, fontSize: t.scaled(13.5)),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon:
                            Icon(Icons.search, size: t.scaled(17)),
                        prefixIconConstraints: BoxConstraints(
                            minWidth: t.scaled(34), minHeight: t.scaled(20)),
                        hintText:
                            _s('wheelFindHint', 'A name, a verse or a year',
                                locale),
                        hintStyle: TextStyle(
                            color: wb.mutedText, fontSize: t.scaled(13)),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                icon: Icon(Icons.close, size: t.scaled(16)),
                                onPressed: () => setSheet(_findCtl.clear),
                              ),
                        border: const OutlineInputBorder(
                            borderRadius: BorderRadius.zero),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(color: wb.border)),
                      ),
                      onChanged: (_) => setSheet(() {}),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        _searchStatus(query, result, data, locale),
                        style: TextStyle(
                            color: wb.mutedText, fontSize: t.scaled(11)),
                      ),
                    ),
                  ),
                  // A "nothing matches" that is not the whole truth is
                  // the worst answer a search box gives: it reads as
                  // ignorance rather than as a boundary. Only reached
                  // when the index really is empty, so it can never
                  // stand in front of a result.
                  if (result.isEmpty)
                    Builder(builder: (_) {
                      // Two AM sentences now, not one. The text gives
                      // the Sethite line ages and intervals, so those
                      // men have arcs and a search finds them; the ten
                      // of Cain's line in Genesis 4:17-24 are given a
                      // wife, a trade and a boast and not one number,
                      // so they have no arc, no spoke and no year —
                      // and a bare "nothing matches" about a man this
                      // app holds a record for is exactly the false
                      // absence this hand-off exists to stop.
                      final person = _amPersonFor(query);
                      final noYears =
                          person == null ? _amPersonWithoutFigures(query) : null;
                      final king = person == null && noYears == null
                          ? _kingFor(query)
                          : null;
                      if (person == null && noYears == null && king == null) {
                        return const SizedBox.shrink();
                      }
                      final line = person != null
                          ? _fill('wheelFindAmElsewhere', '', locale,
                              {'name': person.localizedName(locale)})
                          : noYears != null
                              ? _fill('wheelFindNoYears', '', locale,
                                  {'name': noYears.localizedName(locale)})
                              : _fill('wheelFindKingElsewhere', '', locale,
                                  {'name': king!.nameFor(locale)});
                      final label = person != null
                          ? _s('timelineOpenChronology',
                              'Open Bible Chronology', locale)
                          : noYears != null
                              ? _s('familyTree', 'Family Tree', locale)
                              : _s('hebrewKings', 'Kings of Judah & Israel',
                                  locale);
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line,
                              style: TextStyle(
                                  color: wb.mutedText,
                                  fontSize: t.scaled(11),
                                  height: 1.5),
                            ),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.of(sheet).pop();
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => person != null
                                          ? const ChronologyPage()
                                          : noYears != null
                                              ? const FamilyTreePage()
                                              : const HebrewKingsPage(),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  foregroundColor: wb.link,
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                      fontSize: t.scaled(11.5),
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  Flexible(
                    child: ListView.builder(
                      key: const ValueKey('wheelFindList'),
                      // Without this the list takes the whole 70% of
                      // the screen the sheet is allowed, so one hit
                      // sits at the top of an otherwise empty half
                      // page and the box reads as broken. Shrink-wrap
                      // is safe under a bounded maxHeight: the
                      // viewport still only builds as far as it fills.
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: result.hits.length,
                      itemBuilder: (c, i) {
                        final hit = result.hits[i];
                        final via = _hitVia(hit, locale);
                        return InkWell(
                          onTap: () {
                            Navigator.of(sheet).pop();
                            _reveal(context, hit, data, locale);
                          },
                          child: Padding(
                            padding:
                                EdgeInsets.symmetric(vertical: t.scaled(5)),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(top: t.scaled(3)),
                                  child: _swatch(
                                      t,
                                      colors[hit.streamId] ??
                                          _lineColor('none')),
                                ),
                                SizedBox(width: t.scaled(8)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(hit.title,
                                          style: TextStyle(
                                              color: wb.text,
                                              fontSize: t.scaled(12.5))),
                                      if (via.isNotEmpty ||
                                          hit.streamHidden) ...[
                                        SizedBox(height: t.scaled(1)),
                                        Text(
                                          [
                                            if (via.isNotEmpty) via,
                                            if (hit.streamHidden)
                                              _s(
                                                  'wheelFindHiddenBand',
                                                  'band hidden — opening '
                                                      'this shows it again',
                                                  locale),
                                          ].join(' · '),
                                          // 11 rather than 10.5: the app's
                                          // own small-print floor, which a
                                          // subordinate line may reach but
                                          // never go under.
                                          style: TextStyle(
                                              color: wb.mutedText,
                                              fontSize: t.scaled(11)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                SizedBox(width: t.scaled(8)),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(_hitYears(hit, data, locale),
                                        style: TextStyle(
                                            color: wb.mutedText,
                                            fontSize: t.scaled(11))),
                                    Text(_kindLabel(hit.kind, locale),
                                        style: TextStyle(
                                            color: wb.mutedText,
                                            fontSize: t.scaled(11))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ]),
              ),
            );
          });
        },
      ),
    );
  }

  /// The Anno Mundi person a reader asked for whose LIFE this wheel
  /// draws, under a name the wheel does not answer to.
  ///
  /// The test is the data's own: a record whose years are counted in
  /// Anno Mundi has no BC year of its own, because the text gave it
  /// none. No hand-written list of patriarchs to fall out of step with
  /// the asset.
  ///
  /// NINETEEN RECORDS QUALIFY AND NINETEEN ARE NOW FOUND BY NAME, so as
  /// of today this never runs. Ten stand on the wheel as nations of
  /// Genesis 10 and 11 (Noah, Shem, Arphaxad, Shelah, Eber, Peleg, Reu,
  /// Serug, Nahor and Terah), the whole Genesis 5 line stands on it as
  /// birth events, and since the lifespans went back on, every one of
  /// them is also an arc. Shelah used to be an exception — the table of
  /// nations spelled him Salah while everything else spelled him
  /// Shelah — and is not any more: all five surfaces agree on the
  /// modern form and the KJV's is carried as `nameKjv`.
  ///
  /// THE LAST MAN IT ANSWERED FOR WAS NAHOR THE ELDER, and his case is
  /// closed too. The sentence used to read "not on this wheel: the text
  /// gives a lifespan, not a date" — true while no lifespan was drawn,
  /// false the moment one was — and was rewritten to report the real
  /// gap, which was a SPELLING: the chart called him Nahor, the family
  /// tree called him Nahor (the elder), and nothing indexed answered to
  /// the longer name. The Israel band now DISPLAYS "Nahor (the elder)",
  /// because the band sheet was printing two rows both labelled "Nahor"
  /// — Genesis 11:22 and Genesis 11:26 — so the longer name is a real
  /// record and the reader gets the record instead of a sentence about
  /// one.
  ///
  /// KEPT ANYWAY, and deliberately. This is a guard on the DATA, not a
  /// special case for a man: the family tree can gain a record tomorrow
  /// whose name no wheel record displays, and the failure it prevents —
  /// "nothing matches" about someone the app charts — is one this page
  /// has already shipped twice. It costs one lookup on an empty result
  /// and it is what `test/radial_chronology_page_test.dart` tells apart
  /// from a real hit.
  ///
  /// The men with no figures at all — Cain's line, and Eve, Cain, Abel,
  /// Ham and Japheth — are [_amPersonWithoutFigures]' business, and get
  /// a different sentence, because a promise of a charted life is not
  /// one to make about a man the text gives no number for.
  ///
  /// Matching is equality on the folded name, in each of the three
  /// scripts and in the KJV's spelling where the record carries one,
  /// not a substring: this replaces a "found nothing" with a definite
  /// claim about one man, and a loose match would make that claim about
  /// the wrong one.
  ///
  /// The lookup is synchronous for the same reason `_showPerson`'s is —
  /// [WheelHistoryService.load] awaits the family tree before it
  /// returns, so a page drawing the wheel is a page past that await.
  BiblicalPerson? _amPersonFor(String query) {
    final q = foldForWheelSearch(query);
    if (q.isEmpty) return null;
    for (final p in FamilyTreeService.instance.allOrEmpty()) {
      if (p.yearSystem != 'am') continue;
      if (p.lifespan == null || p.birthYear == null || p.deathYear == null) {
        continue;
      }
      for (final n in [
        p.name,
        p.nameZhHans ?? '',
        p.nameZhHant ?? '',
        p.nameKjv,
      ]) {
        if (n.isNotEmpty && foldForWheelSearch(n) == q) return p;
      }
    }
    return null;
  }

  /// The person a reader asked for whom the text gives no number at
  /// all.
  ///
  /// GENESIS 4:17-24 STATES NO FIGURE. Cain's line is given a city, a
  /// wife, two more wives, three trades and a boast, and not one age,
  /// interval or total. So there is no year to put on this axis, no
  /// span to draw as an arc, and nothing this chart could honestly
  /// show — and the family tree's own 100, 200 … 545 for them are
  /// marked `conventional / approximate` placeholders, which is exactly
  /// why the guard below is on the FIGURES and not on the years.
  ///
  /// Sixteen records qualify: the ten of Cain's line plus Adah,
  /// Zillah and Naamah who stand in the same passage, and Eve, Cain,
  /// Abel, Ham and Japheth, whom the text places but does not measure.
  /// Before this they got a bare "nothing matches" about people this
  /// app holds a record for, which is the false absence
  /// [_amPersonFor] was built to stop, half-built.
  ///
  /// Equality on the folded name in each of the three scripts and in
  /// the KJV's spelling, for the same reason: this replaces "found
  /// nothing" with a definite claim about one person, and a loose match
  /// would make the claim about the wrong one.
  BiblicalPerson? _amPersonWithoutFigures(String query) {
    final q = foldForWheelSearch(query);
    if (q.isEmpty) return null;
    for (final p in FamilyTreeService.instance.allOrEmpty()) {
      if (p.yearSystem != 'am') continue;
      if (p.lifespan != null && p.birthYear != null && p.deathYear != null) {
        continue;
      }
      for (final n in [
        p.name,
        p.nameZhHans ?? '',
        p.nameZhHant ?? '',
        p.nameKjv,
      ]) {
        if (n.isNotEmpty && foldForWheelSearch(n) == q) return p;
      }
    }
    return null;
  }

  /// The king a reader asked for who IS charted by this app and is not
  /// drawn on this wheel.
  ///
  /// The wheel's unit is the polity — it draws the Kingdom of Judah,
  /// not Ahab — so about half of Thiele's forty-two return nothing
  /// here, and a bare "nothing matches" reads as the app never having
  /// heard of a man it gives a whole page to.
  ///
  /// Only ever consulted when the index is genuinely empty, which is
  /// what keeps it from answering over a real hit. That guard is doing
  /// specific work, not being careful in general: Zechariah is a king
  /// of Israel AND the father of John the Baptist, who is on the wheel;
  /// Hezekiah and Josiah have their reforms drawn. For those the wheel
  /// answers first and this never runs.
  ///
  /// Equality on the folded name, in each script and including the
  /// alternative names the file carries — never a substring, because
  /// this replaces "found nothing" with a claim about one man.
  ///
  /// `altNames` holds several names in one string where scripture gives
  /// several ("Jeconiah, Coniah" for Jehoiachin, "Azariah" for Uzziah),
  /// so it is split: a reader types one of them, not the list.
  HebrewKing? _kingFor(String query) {
    final q = foldForWheelSearch(query);
    if (q.isEmpty) return null;
    for (final k in HebrewKingsService.instance.cached?.kings ??
        const <HebrewKing>[]) {
      for (final field in [...k.names.values, ...?k.altNames?.values]) {
        for (final n in field.split(',')) {
          if (n.trim().isNotEmpty && foldForWheelSearch(n) == q) return k;
        }
      }
    }
    return null;
  }

  /// The one line under the box. It always says something: what can be
  /// searched when nothing is typed, what was found when something is,
  /// and — when a year was read out of the query — which years, and
  /// that some of the rows are neighbours rather than hits.
  String _searchStatus(String query, WheelSearchResult result,
      WheelHistoryData data, String locale) {
    if (query.trim().isEmpty) {
      return _fill('wheelFindTeach', '', locale, {
        'e': data.events.length,
        'p': data.powers.length,
        'm': data.ministries.length,
        'n': data.nations.length,
        'b': data.streams.length,
        'o': data.omissions.length,
      });
    }
    if (result.isEmpty) {
      return _fill('wheelFindNone', 'Nothing here matches “{q}”.', locale,
          {'q': query.trim()});
    }
    final parts = <String>[
      if (result.hits.length == 1)
        _fill('wheelFindCountOne', '{n} result', locale, {'n': 1})
      else
        _fill('wheelFindCount', '{n} results', locale,
            {'n': result.hits.length}),
      if (result.years.isNotEmpty)
        result.years.map((y) => yearLabel(y, locale)).join(' · '),
      if (result.nearestShown > 0)
        _fill('wheelFindNearNote', '', locale, {'n': result.nearestShown}),
    ];
    return parts.join(' · ');
  }

  /// Take the reader to what they found.
  ///
  /// Three things, in this order, and each is load-bearing. UN-HIDE the
  /// band, because a result whose band is switched off is not on the
  /// wheel at all and selecting it would do nothing visible. SELECT it,
  /// which is also what forces it through the declutter — a selected
  /// event always represents its own cluster, so a record that had no
  /// label a moment ago now has one. PAN it to the middle, but only if
  /// the reader is zoomed in; at rest the whole wheel is on screen and
  /// moving it would be motion for its own sake.
  void _reveal(BuildContext context, WheelHit hit, WheelHistoryData data,
      String locale) {
    // An omission takes NONE of the three steps, because all three
    // would be lies about the canvas. There is no band to un-hide, no
    // arc to select, and panning would carry the reader to whatever
    // happens to sit at angle zero and present it as the thing they
    // asked for. The sheet is the entire answer; the wheel does not
    // move, which is itself the point being made.
    if (hit.kind == WheelHitKind.omission) {
      final o = data.omissionById(hit.id);
      if (o != null) _showOmission(context, o, locale);
      return;
    }
    setState(() {
      _hidden.remove(hit.streamId);
      // A nation of Genesis 10 is not drawn on the axis — it is the
      // descent behind a band — so what gets selected is that band.
      _selectedId =
          hit.kind == WheelHitKind.nation ? hit.streamId : hit.id;
    });
    _panTo(hit, data);
    switch (hit.kind) {
      case WheelHitKind.event:
        final e = _find(data.events, (e) => e.id == hit.id);
        if (e != null) _showEvent(context, e, data, locale);
      case WheelHitKind.power:
        final p = _find(data.powers, (p) => p.id == hit.id);
        if (p != null) _showPower(context, p, data, locale);
      case WheelHitKind.nation:
      case WheelHitKind.stream:
        final s = _find(data.streams, (s) => s.id == hit.streamId);
        if (s != null) _showStream(context, s, data, locale);
      case WheelHitKind.patriarch:
        final man = ChronologyService.instance.cached?.byId(hit.id);
        if (man != null) _showPatriarch(context, man, locale);
      case WheelHitKind.ministry:
        final m = data.ministryById(hit.id);
        if (m != null) _showMinistry(context, m, locale);
      // Unreachable — the early return above owns this kind. Written
      // out rather than left to a default so that a kind added later
      // fails at compile time here, which is how the ministry kind was
      // caught when it was added and the search box had not been told.
      case WheelHitKind.omission:
        break;
    }
  }

  /// A DELIBERATE DEPARTURE FROM BibleWorks, recorded because the next
  /// reader of `bwh39_Timeline` will notice it. There, typing a date
  /// scrolls the timeline to it unconditionally, because that timeline
  /// is a strip far wider than the window and the year you asked for is
  /// almost never on screen.
  ///
  /// This chart is a disc, and at rest all 4000 BC – AD 2026 of it is in
  /// the viewport. Scrolling would move a target that is already visible
  /// and cost the reader the surrounding centuries — the thing a wheel
  /// is for. So panning happens only once the reader has zoomed in and
  /// the year genuinely can be off-screen. Selection, which forces the
  /// record through the angular declutter and gives it a label, is what
  /// does the finding at rest.
  void _panTo(WheelHit hit, WheelHistoryData data) {
    final view = _viewportSize;
    if (view == null || _side <= 0) return;
    final scale = _viewer.value.getMaxScaleOnAxis();
    if (scale <= 1.0) return;

    final streams = _visible(data);
    final rHub = _side * _kHubFrac;
    final rBands = _side * _kBandsFrac;
    final rRim = _side * _kRimFrac;

    // A life belongs to no band, so its sub-ring is resolved before the
    // ring lookup below — which would fail, `lifespans` being a layer id
    // and not a stream id, and leave a search result unpanned in
    // silence. The geometry is recomputed rather than held because it
    // depends on the canvas size and the pan can run before the frame
    // that laid the arcs out.
    double? lifeRadius;
    double? lifeAngle;
    // A ministry lives in the same annulus as a life and belongs to no
    // band either, so it takes the same branch: the arc id is prefixed
    // (`ministry:`) exactly so that one lookup can serve both.
    if (hit.kind == WheelHitKind.patriarch ||
        hit.kind == WheelHitKind.ministry) {
      final chron = ChronologyService.instance.cached;
      final creation = _creationYear;
      if (chron == null || creation == null) return;
      // The SAME layer set the painter used, hidden layers included:
      // a pan computed over arcs the reader has switched off would
      // land in the wrong sub-ring.
      final all = _packBand(
        chron,
        creation,
        _hidden.contains(kReignLayerId)
            ? const <HebrewKing>[]
            : (HebrewKingsService.instance.cached?.kings ??
                const <HebrewKing>[]),
        _hidden.contains(kMinistryLayerId)
            ? const <WheelMinistry>[]
            : (WheelHistoryService.instance.cached?.ministries ??
                const <WheelMinistry>[]),
      );
      final wanted = hit.kind == WheelHitKind.ministry
          ? '$kMinistryArcPrefix${hit.id}'
          : hit.id;
      final arc = _find(all, (a) => a.id == wanted);
      if (arc == null) return;
      lifeRadius = lifeArcRadii(arc.ring, lifeArcRingCount(all),
              scriptureLabelBase(rBands), rRim)
          .centre;
      lifeAngle = (arc.a0 + arc.a1) / 2;
    }

    final ring = streams.indexWhere((s) => s.id == hit.streamId);
    if (lifeAngle == null && ring < 0) return;
    final band = ringRadii(ring < 0 ? 0 : ring, streams.length, rHub, rBands);

    double angle;
    double radius;
    switch (hit.kind) {
      case WheelHitKind.patriarch:
      case WheelHitKind.ministry:
        angle = lifeAngle!;
        radius = lifeRadius!;
      case WheelHitKind.event:
        final e = _find(data.events, (e) => e.id == hit.id);
        if (e == null) return;
        angle = angleForSpan(e.year, kMinYear, kMaxYear);
        radius = (rBands + rRim) / 2;
      case WheelHitKind.power:
        final p = _find(data.powers, (p) => p.id == hit.id);
        if (p == null) return;
        angle = (angleForSpan(p.start, kMinYear, kMaxYear) +
                angleForSpan(p.endFor(kMaxYear), kMinYear, kMaxYear)) /
            2;
        radius = band.centre;
      case WheelHitKind.nation:
      case WheelHitKind.stream:
        angle = startRad + sweepRad / 2;
        radius = band.centre;
      // A record with no year has no angle, and the ring lookup above
      // already returned for it (`streamId` is empty, so no band
      // matches). Never reached in practice — `_reveal` returns before
      // calling this for an omission — and written out anyway so the
      // next kind added has to answer the question here.
      case WheelHitKind.omission:
        return;
    }

    final t = focusTranslation(
      px: view.width / 2 + radius * math.cos(angle),
      py: view.height / 2 + radius * math.sin(angle),
      scale: scale,
      viewW: view.width,
      viewH: view.height,
    );
    _viewer.value = Matrix4.identity()
      ..translateByDouble(t.dx, t.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  // ── taps ───────────────────────────────────────────────────────────

  void _handleTap(
    BuildContext context,
    Offset local,
    double side,
    WheelHistoryData data,
    List<WheelStream> streams,
    List<_Arc> arcs,
    List<_Spoke> spokes,
    List<_Life> lives,
    List<_Rail> rail,
    String locale,
  ) {
    if (streams.isEmpty) return;
    final c = side / 2;
    final dx = local.dx - c, dy = local.dy - c;
    final r = math.sqrt(dx * dx + dy * dy);
    var a = math.atan2(dy, dx);
    while (a < startRad) {
      a += 2 * math.pi;
    }
    if (a - startRad > sweepRad) return;

    final rHub = side * _kHubFrac;
    final rBands = side * _kBandsFrac;
    final rRim = side * _kRimFrac;

    // An event spoke, if the tap is out in the label annulus.
    //
    // The tolerance is an ARC LENGTH, not a fixed angle: at this radius
    // a fixed 0.012 rad is under a pixel of slack near the bands and
    // nobody can hit it. Converting a comfortable finger target (about
    // 9 logical pixels) into radians at the tapped radius gives the
    // same physical target everywhere on the wheel, and the nearest
    // spoke within it wins.
    _Spoke? bestSpoke;
    var spokeScore = double.infinity;
    if (r >= rBands - 6 && r <= rRim + 8) {
      final tol = r > 0 ? (9.0 / r) : 0.05;
      for (final s in spokes) {
        if (r < s.label.rStart - 6 || r > s.label.rEnd + 6) continue;
        // NORMALISED, not absolute: how far into its own target the
        // finger fell, 0 dead centre and 1 at the edge. That is what
        // makes it comparable with an arc's, whose target is a
        // different shape and a different size.
        final d = (a - s.label.angle).abs() / tol;
        if (d <= 1 && d < spokeScore) {
          bestSpoke = s;
          spokeScore = d;
        }
      }
    }

    void openSpoke(_Spoke s) {
      _select(s.event.id);
      if (s.members.length > 1) {
        _showCluster(context, s.members, data, locale);
      } else {
        _showEvent(context, s.event, data, locale);
      }
    }

    // A life, and THE SMALLER NORMALISED DISTANCE WINS — not the spoke.
    //
    // This used to read "SPOKES WIN TIES, and that is the right way
    // round: a spoke's target is one tick and about nine pixels of arc,
    // a life's is a whole sub-ring. The smaller target has to be
    // reachable or it is not a target at all." The reasoning was right
    // and its premise stopped being true on 2026-09-02, when the reigns,
    // the ministries and the genealogy rail took the band from eleven
    // sub-rings to sixteen: a sub-ring went from 9.73 px deep to 6.69,
    // so the ARC is now the smaller target and the fixed precedence was
    // pointing the wrong way. In the Genesis stretch, where every birth
    // is a spoke, the labels were taking almost every tap meant for an
    // arc — the owner reported exactly that: 「我要按那个环而不是字」.
    //
    // So the rule is derived rather than written down: each candidate
    // reports how far into ITS OWN target the finger fell, 0 at the
    // centre and 1 at the edge, and the nearer one opens. A reader who
    // aims at a tick still gets the tick; a reader who aims at the band
    // between two ticks now gets the band. It re-derives itself the day
    // the geometry moves again, which is the property the old rule
    // lacked.
    //
    // Within the arcs it is still resolved by RING then by angle, not
    // by distance, because these arcs are butt-jointed rings: the ring
    // the finger is in is the only ring it can mean.
    // The rail first, because it owns the innermost sub-ring outright
    // and no arc is drawn there — checking the arcs first would let a
    // ring-1 arc claim a tap that fell in ring 0.
    if (rail.isNotEmpty) {
      for (final m in rail) {
        if ((r - m.centre).abs() > m.pitch / 2) continue;
        // A mark has no width, so the target is angular: half the
        // gap to a neighbour, floored at what a finger needs. Scored
        // the same way as everything else here, and compared with the
        // spoke for the same reason — a mark is a small target too,
        // and precedence written down rather than measured is what
        // sent the arcs' taps to the labels.
        final tolerance = math.max(9 / m.centre, 0.004);
        final into = (a - m.angle).abs() / tolerance;
        if (into <= 1) {
          if (bestSpoke case final s? when spokeScore < into) {
            openSpoke(s);
            return;
          }
          _select('$kLineageArcPrefix${m.cohort.year}');
          _showCohort(context, m.cohort, locale);
          return;
        }
      }
    }

    if (r >= scriptureLabelBase(rBands) && r <= rRim && lives.isNotEmpty) {
      for (final l in lives) {
        final into = (r - l.centre).abs() / (l.pitch / 2);
        if (into > 1) continue;
        if (a >= l.arc.a0 && a <= l.arc.a1) {
          // The one place the two shapes are compared.
          if (bestSpoke case final s? when spokeScore < into) {
            openSpoke(s);
            return;
          }
          _select(l.id);
          final man = l.man;
          final king = l.king;
          final ministry = l.ministry;
          if (man != null) {
            _showPatriarch(context, man, locale);
          } else if (king != null) {
            _showKing(context, king, locale);
          } else if (ministry != null) {
            _showMinistry(context, ministry, locale);
          }
          return;
        }
      }
    }

    // No arc took it, so a spoke that was in range does.
    if (bestSpoke case final s?) {
      openSpoke(s);
      return;
    }

    // Otherwise a band: a power arc if one is under the tap, else the
    // stream itself.
    //
    // BY PITCH, NOT BY INK. `ringRadii` paints four fifths of each
    // band's share of the annulus and leaves a fifth as air, so that
    // neighbouring bands read as two rings rather than one solid
    // disc — and this test used to ask whether the finger was inside
    // the PAINTED part. A tap in the air between two bands therefore
    // hit nothing at all and the sheet did not open, which at 900 px is
    // one pixel of dead space in every seven.
    //
    // The band's whole share belongs to the band, exactly as a
    // sub-ring's whole share belongs to the life in it — the arcs have
    // worked that way since they were written and the bands never did.
    // It matters more here: 22 bands share a smaller annulus, so a band
    // is 6.95 px deep at 900 px and 5.41 at 700, against the nine a
    // finger wants. Ink is even thinner — 5.56 and 4.33.
    if (r >= rHub && r <= rBands) {
      final pitch = ringPitch(streams.length, rHub, rBands);
      for (final arc in arcs) {
        final band = ringRadii(arc.ring, streams.length, rHub, rBands);
        if ((r - band.centre).abs() > pitch / 2) continue;
        if (a >= arc.a0 && a <= arc.a1) {
          _select(arc.power.id);
          _showPower(context, arc.power, data, locale);
          return;
        }
      }
      // Nearest band centre, so the outermost and innermost edges of
      // the annulus round INTO their band rather than falling through.
      var best = -1;
      var bestD = double.infinity;
      for (var i = 0; i < streams.length; i++) {
        final d = (r - ringRadii(i, streams.length, rHub, rBands).centre).abs();
        if (d < bestD) {
          bestD = d;
          best = i;
        }
      }
      if (best >= 0) {
        _select(streams[best].id);
        _showStream(context, streams[best], data, locale);
        return;
      }
    }
    if (_selectedId != null) _select(null);
  }

  /// Read the verse without leaving the wheel.
  ///
  /// The app already has a verse sheet the rest of the pages use, so
  /// this reuses it rather than inventing a second way to show a
  /// verse: same type, same versions, same behaviour, and nothing new
  /// on screen. A chart that asserts something about scripture should
  /// let the reader check the text in one tap, not send them away and
  /// lose their place on the wheel.
  Future<void> _readVerse(BuildContext context, String raw) async {
    final ref = parseReference(raw);
    if (ref == null) return;
    await showVersePopup(context, ref);
  }

  /// Leave the wheel and open the reader at the verse — the long way,
  /// for when the reader wants the surrounding chapter.
  Future<void> _jump(BuildContext context, String raw) async {
    final ref = parseReference(raw);
    if (ref == null) return;
    final mp = context.read<MainProvider>();
    final result = await jumper.resolveAndPrepareJump(reference: ref, mp: mp);
    if (!context.mounted) return;
    final ok = await jumper.showJumpResultSnackBar(context, result);
    if (!ok || !context.mounted) return;
    navigateToReader(context);
  }

  // ── detail sheets ──────────────────────────────────────────────────

  Widget _sheet(BuildContext sheet, List<Widget> children) => ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(sheet).size.height * 0.7),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: children,
        ),
      );

  Widget _swatch(WbType t, Color c) =>
      Container(width: t.scaled(10), height: t.scaled(10), color: c);

  /// Tap reads the verse in place; long-press opens the reader at it.
  ///
  /// The reference is STORED in English — that is the form
  /// [parseReference] reads on the way back — and localised only here,
  /// at the print site. So `r` goes to the handlers and
  /// [localizedReferenceLabel] goes on screen; passing the localised
  /// string to either handler would break the tap.
  Widget _refRow(BuildContext context, List<String> refs, WbColors wb,
          WbType t, String locale) =>
      Wrap(spacing: 10, runSpacing: 4, children: [
        for (final r in refs)
          InkWell(
            onTap: () => _readVerse(context, r),
            onLongPress: () => _jump(context, r),
            child: Text(localizedReferenceLabel(r, locale),
                style: TextStyle(color: wb.link, fontSize: t.scaled(11))),
          ),
      ]);

  /// The people a record names, as tappable names in the page's own
  /// idiom — a `Wrap` of plain text, like [_refRow], and not a boxed
  /// chip. Two reasons: `workbench_theme.dart:16` forbids rounded
  /// corners and a copied chip carried two of them into the timeline
  /// page one phase ago; and the sheet already has a reference row that
  /// looks like this, so a second visual language here would suggest a
  /// difference in kind that does not exist.
  ///
  /// They are deliberately NOT [WbColors.link]. On this page that
  /// colour means "this leaves for the reader", which a verse chip does
  /// and a person does not — tapping a person opens their record
  /// without moving the wheel. The underline says tappable; the colour
  /// says where it goes.
  Widget _personRow(BuildContext context, List<WheelPersonLink> people,
          WbColors wb, WbType t, String locale) =>
      Wrap(spacing: 10, runSpacing: 4, children: [
        for (final p in people)
          InkWell(
            onTap: () => _showPerson(context, p.id, locale),
            child: Text(
              p.nameFor(locale),
              style: TextStyle(
                color: wb.text,
                fontSize: t.scaled(11),
                decoration: TextDecoration.underline,
                decorationColor: wb.mutedText,
              ),
            ),
          ),
      ]);

  /// Open one person's family-tree record over the wheel.
  ///
  /// The lookup is synchronous and safe here because
  /// [WheelHistoryService.load] awaits the family tree before it
  /// returns any record — a page showing a person link is a page that
  /// is past that await. The null branch is a belt: the merge already
  /// drops an id the tree does not hold, so this row can only name
  /// people who resolve.
  Future<void> _showPerson(
      BuildContext context, String personId, String locale) async {
    final person = FamilyTreeService.instance.byId(personId);
    if (person == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.35,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => PersonDetailSheet(
          person: person,
          locale: locale,
          scrollController: scrollController,
          onPersonTap: (other) {
            Navigator.of(sheetCtx).maybePop();
            _showPerson(context, other.id, locale);
          },
        ),
      ),
    );
  }

  /// The asset's `region` in the reader's language.
  ///
  /// Returns empty for a value this app has no word for, which is the
  /// honest failure: a raw `mesopotamia` printed into a Chinese sheet
  /// would be worse than saying nothing, and
  /// `wheel_history_disclosure_test.dart` pins that every region in the
  /// asset has a label so the empty branch stays unreachable.
  String _regionLabel(String region, String locale) => switch (region) {
        'egypt' => _s('wheelRegionEgypt', 'Egypt', locale),
        'mesopotamia' => _s('wheelRegionMesopotamia', 'Mesopotamia', locale),
        'anatolia' => _s('wheelRegionAnatolia', 'Anatolia', locale),
        'levant' => _s('wheelRegionLevant', 'The Levant', locale),
        'persia' => _s('wheelRegionPersia', 'Persia', locale),
        'greece' => _s('wheelRegionGreece', 'Greece', locale),
        'rome' => _s('wheelRegionRome', 'Rome', locale),
        'islamic' => _s('wheelRegionIslamic', 'The Islamic world', locale),
        'europe' => _s('wheelRegionEurope', 'Europe', locale),
        'asia' => _s('wheelRegionAsia', 'Asia', locale),
        'americas' => _s('wheelRegionAmericas', 'The Americas', locale),
        'modern' => _s('wheelRegionModern', 'The modern world', locale),
        _ => '',
      };

  String _basisText(String basis, String locale) => switch (basis) {
        'scripture' => _s('wheelBasisScripture', 'stated in scripture', locale),
        'scripture+thiele' =>
          _s('wheelBasisThiele', 'interval from scripture', locale),
        'thiele' => _s('wheelBasisThieleOnly', 'year from Thiele', locale),
        _ => _s('wheelBasisConventional', 'conventional date', locale),
      };

  void _showEvent(BuildContext context, WheelHistoryEvent e,
      WheelHistoryData data, String locale) {
    final wb = WbColors.of(context);
    final stream = data.streams.firstWhere((s) => s.id == e.stream,
        orElse: () => const WheelStream(id: '', line: 'none', names: {}));
    final approx = e.approximate ? approximatePrefix(locale) : '';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      isScrollControlled: true,
      // `WbType.of` WATCHES, and a tap handler is not a build — resolving
      // it out here threw before the sheet ever opened, so no detail sheet
      // on this page could be opened in a debug build. Resolved against
      // the sheet's own context instead, which is also what keeps an open
      // sheet responsive to the Font Size slider. `WbColors.of` reads a
      // theme extension and is safe either side of the boundary.
      builder: (sheet) {
        final t = WbType.of(sheet);
        return _sheet(sheet, [
          Row(children: [
            _swatch(t, _colorsFor(data)[stream.id] ?? _lineColor(stream.line)),
            SizedBox(width: t.scaled(8)),
            Expanded(
              child: Text(e.titleFor(locale),
                  style: TextStyle(
                      color: wb.text,
                      fontSize: t.scaled(15),
                      fontWeight: FontWeight.w600)),
            ),
            Text(stream.nameFor(locale),
                style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11))),
          ]),
          SizedBox(height: t.scaled(4)),
          Text('$approx${yearLabel(e.year, locale)}',
              style: TextStyle(color: wb.mutedText, fontSize: t.scaled(12))),
          if (e.descFor(locale).isNotEmpty) ...[
            SizedBox(height: t.scaled(8)),
            Text(e.descFor(locale),
                style: TextStyle(color: wb.text, fontSize: t.scaled(12))),
          ],
          if (e.refs.isNotEmpty) ...[
            SizedBox(height: t.scaled(8)),
            _refRow(context, e.refs, wb, t, locale),
          ],
          SizedBox(height: t.scaled(10)),
          Text(
            e.approximate
                ? '${_basisText(e.basis, locale)} · '
                    '${_s('wheelApprox', 'approximate', locale)}'
                : _basisText(e.basis, locale),
            style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11)),
          ),
          // The apparatus the merge left behind, in the timeline page's
          // own words — the same three blocks, the same shared strings,
          // so the two surfaces cannot drift into saying different
          // things about one event.
          if (e.septuagintYear != null) ...[
            SizedBox(height: t.scaled(4)),
            Text(
              _s('timelineSeptuagintYear', 'On the Septuagint: {year}.', locale)
                  .replaceFirst('{year}', yearLabel(e.septuagintYear!, locale)),
              style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11)),
            ),
          ],
          // Kept apart from the reference row above and labelled: those
          // are where the event is told, these are where its year was
          // counted from, and on nine of them the two name no chapter
          // in common.
          if (e.datingRefs.isNotEmpty) ...[
            SizedBox(height: t.scaled(8)),
            Text(
              _s('timelineDatedBy', 'Dated by', locale),
              style: TextStyle(
                  color: wb.mutedText,
                  fontSize: t.scaled(11),
                  fontWeight: FontWeight.w600),
            ),
            SizedBox(height: t.scaled(4)),
            _refRow(context, e.datingRefs, wb, t, locale),
          ],
          // The people, under the timeline page's own label, for the
          // same reason the three blocks above reuse its wording: one
          // event, two surfaces, and nothing gained by a second
          // vocabulary. Last of the record's own content and above
          // nothing, because it is the only row here that opens
          // another sheet rather than adding to this one.
          if (e.people.isNotEmpty) ...[
            SizedBox(height: t.scaled(8)),
            Text(
              uiStrings['timelinePeople']?[locale] ??
                  uiStrings['timelinePeople']?['en'] ??
                  'People',
              style: TextStyle(
                  color: wb.mutedText,
                  fontSize: t.scaled(11),
                  fontWeight: FontWeight.w600),
            ),
            SizedBox(height: t.scaled(4)),
            _personRow(context, e.people, wb, t, locale),
          ],
          // The seam. These eight are not counted back from the Thiele
          // anchor the way everything below Abraham is, and the wheel
          // draws both on one axis — which is the strongest invitation
          // in the app to read them as equally fixed. Disclosed, not
          // repaired: fixing it means fixing a year for the creation.
          if (e.timelineEra == 'antediluvian') ...[
            SizedBox(height: t.scaled(8)),
            Text(
              uiStrings['timelineAntediluvianBasis']?[locale] ??
                  uiStrings['timelineAntediluvianBasis']?['en'] ??
                  '',
              style: TextStyle(
                  color: wb.mutedText, fontSize: t.scaled(11), height: 1.5),
            ),
            SizedBox(height: t.scaled(4)),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ChronologyPage(),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: wb.link,
                ),
                child: Text(
                  _s('timelineOpenChronology', 'Open Bible Chronology', locale),
                  style: TextStyle(
                      fontSize: t.scaled(11.5), fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ]);
      },
    );
  }

  /// The epoch both chains are anchored at.
  ///
  /// Abram leaving Haran is the one year the Masoretic and the
  /// Septuagint reckonings share on this axis — the wheel's own
  /// `abram_called`, from Thiele — so it is what turns the Greek's
  /// Anno Mundi figures into BC years without a second anchor being
  /// invented here: `creationLxx = creationMt + haran.mt - haran.lxx`.
  /// An id, not a figure; the numbers are the asset's.
  static const String _kAnchorEpoch = 'haran';

  /// One life, printed — and printed in BOTH traditions.
  ///
  /// WHY BOTH. The wheel DRAWS the Masoretic, because its axis is
  /// absolute and the Greek chain puts the creation 1,366 years
  /// earlier: carrying it would cost about a fifth of the angular
  /// resolution of all ~665 events for the sake of nineteen arcs, and
  /// would put a second flood 780 years before the first. But a chart
  /// that draws one tradition and never names the other has chosen in
  /// silence, which is the objection this app has answered three times
  /// before. So the ARC is Masoretic and the SHEET is both: each
  /// tradition's own Anno Mundi years, its own total, its own verses,
  /// under its own name out of the asset.
  ///
  /// THE ARC AND THE SPOKE MUST NOT DISAGREE. The birth year here and
  /// the birth year on this man's own event spoke are the same
  /// arithmetic on the same anchor — `_meta.creation.year` plus the
  /// figure — computed from one field, never from two.
  /// A rail mark's sheet: the year, and everybody the tree places in it.
  ///
  /// THE DISCLAIMER COMES FIRST, before the year is even repeated,
  /// because it is the most important thing on the sheet. All 192 of
  /// these people have an EMPTY `datingRefs` in `family_tree.json` —
  /// 191 `conventional`, one `thiele`, and not one resting on a verse.
  /// The year is where the genealogy PLACES them so that a tree can be
  /// drawn, and a reader who takes it for a date has been misled by
  /// this app rather than by the asset, which says so plainly.
  void _showCohort(
      BuildContext context, LineageCohort cohort, String locale) {
    final wb = WbColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      isScrollControlled: true,
      builder: (sheet) {
        final t = WbType.of(sheet);
        return _sheet(sheet, [
          Text(yearLabel(cohort.year, locale),
              style: TextStyle(
                  color: wb.text,
                  fontSize: t.scaled(16),
                  fontWeight: FontWeight.w600)),
          SizedBox(height: t.scaled(4)),
          Text(
            _s('wheelLineageNote', '', locale),
            style: TextStyle(
                color: wb.mutedText, fontSize: t.scaled(11), height: 1.4),
          ),
          SizedBox(height: t.scaled(12)),
          Text(
            _fill('wheelLineageCount', '{n} people', locale,
                {'n': cohort.people.length}),
            style: TextStyle(
                color: wb.mutedText,
                fontSize: t.scaled(11),
                fontWeight: FontWeight.w600),
          ),
          SizedBox(height: t.scaled(4)),
          for (final p in cohort.people)
            InkWell(
              onTap: () {
                Navigator.of(sheet).pop();
                _showPerson(context, p.id, locale);
              },
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: t.scaled(3)),
                child: Row(children: [
                  Expanded(
                    child: Text(p.localizedName(locale),
                        style: TextStyle(
                            color: wb.link, fontSize: t.scaled(12.5))),
                  ),
                  if (p.role != null && p.role!.isNotEmpty)
                    Text(p.role!,
                        style: TextStyle(
                            color: wb.mutedText, fontSize: t.scaled(11))),
                ]),
              ),
            ),
        ]);
      },
    );
  }

  /// A ministry arc's own sheet.
  ///
  /// The note is the point of it. A reign arc can show its years and be
  /// understood; a ministry arc cannot, because the years were REACHED
  /// rather than read, and by a different route for almost every man.
  /// So the note — which says which verse fixed which end, and where
  /// the tighter window would be — is not an extra here, it is the
  /// record. Printed before the references, not after them.
  void _showMinistry(
      BuildContext context, WheelMinistry ministry, String locale) {
    final wb = WbColors.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      isScrollControlled: true,
      builder: (sheet) {
        final t = WbType.of(sheet);
        final note = ministry.noteFor(locale);
        return _sheet(sheet, [
          Text(ministry.nameFor(locale),
              style: TextStyle(
                  color: wb.text,
                  fontSize: t.scaled(16),
                  fontWeight: FontWeight.w600)),
          SizedBox(height: t.scaled(4)),
          Text(
            '${yearLabel(ministry.start, locale)} – '
            '${yearLabel(ministry.end, locale)}',
            style: TextStyle(color: wb.text, fontSize: t.scaled(12.5)),
          ),
          SizedBox(height: t.scaled(3)),
          // WHAT THE SPAN RESTS ON, unconditionally and before anything
          // else the sheet says. Twenty-five of the thirty-nine are
          // `conventional`; a reader who is not told cannot tell those
          // from the fourteen the text and Thiele fix between them.
          Text(
            ministry.approximate
                ? '${_basisText(ministry.basis, locale)} · '
                    '${_s('wheelApprox', 'approximate', locale)}'
                : _basisText(ministry.basis, locale),
            style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11)),
          ),
          if (note.isNotEmpty) ...[
            SizedBox(height: t.scaled(10)),
            Text(note,
                style: TextStyle(
                    color: wb.text, fontSize: t.scaled(12), height: 1.45)),
          ],
          if (ministry.refs.isNotEmpty) ...[
            SizedBox(height: t.scaled(12)),
            Text(_s('wheelRefs', 'References', locale),
                style: TextStyle(
                    color: wb.mutedText,
                    fontSize: t.scaled(11),
                    fontWeight: FontWeight.w600)),
            SizedBox(height: t.scaled(3)),
            Wrap(
              spacing: t.scaled(6),
              runSpacing: t.scaled(4),
              children: [
                for (final ref in ministry.refs)
                  InkWell(
                    onTap: () {
                      Navigator.of(sheet).pop();
                      _jump(context, ref);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: t.scaled(6), vertical: t.scaled(2)),
                      decoration: BoxDecoration(
                          border: Border.all(color: wb.border)),
                      child: Text(ref,
                          style: TextStyle(
                              color: wb.accent, fontSize: t.scaled(11))),
                    ),
                  ),
              ],
            ),
          ],
          // The reigns the span was reached FROM, named rather than
          // implied. They are not a formula — see `WheelMinistry` — so
          // they are labelled as what they are: the anchors, not the
          // arithmetic.
          if (ministry.anchorKings.isNotEmpty) ...[
            SizedBox(height: t.scaled(10)),
            Text(
              '${_s('wheelMinistryAnchors', 'Anchored on the reigns of', locale)}: '
              '${[
                for (final id in ministry.anchorKings)
                  HebrewKingsService.instance.cached?.byId(id)?.nameFor(locale) ??
                      id
              ].join(' · ')}',
              style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11)),
            ),
          ],
        ]);
      },
    );
  }

  /// The sheet for a record that is not on the chart, and says so.
  ///
  /// SHAPED LIKE [_showMinistry] AND MISSING ITS SECOND LINE, which is
  /// the whole design. A ministry sheet reads name / years / basis /
  /// note / references; this one reads name / "not drawn, and here is
  /// why not" / note / references. The reader who has just come from
  /// Isaiah's sheet sees the same furniture with the years taken out of
  /// it, which states the difference faster than any sentence could.
  ///
  /// THE REFERENCES ARE THE POINT OF THE SHEET, not an appendix. Every
  /// other claim on this wheel can be checked against a verse; a claim
  /// that a book supplies no anchor can only be checked by reading the
  /// verse that would have supplied one. So Joel 1:1 is tappable here
  /// for exactly the reason Isaiah 1:1 is tappable there — except that
  /// opening it is what proves the record right.
  ///
  /// No basis line, deliberately. `_basisText` answers "what does this
  /// year rest on", and there is no year; printing `conventional` over
  /// a record whose content is that no date can be reached would be the
  /// contradiction this sheet exists to remove.
  void _showOmission(
      BuildContext context, WheelOmission omission, String locale) {
    final wb = WbColors.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      isScrollControlled: true,
      builder: (sheet) {
        final t = WbType.of(sheet);
        final note = omission.noteFor(locale);
        return _sheet(sheet, [
          Text(omission.nameFor(locale),
              style: TextStyle(
                  color: wb.text,
                  fontSize: t.scaled(16),
                  fontWeight: FontWeight.w600)),
          SizedBox(height: t.scaled(4)),
          Text(
            _s('wheelOmissionNoSpan',
                'Not drawn on this chart: the text gives no year to draw it '
                    'at.',
                locale),
            style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11.5)),
          ),
          if (note.isNotEmpty) ...[
            SizedBox(height: t.scaled(10)),
            Text(note,
                style: TextStyle(
                    color: wb.text, fontSize: t.scaled(12), height: 1.45)),
          ],
          if (omission.refs.isNotEmpty) ...[
            SizedBox(height: t.scaled(12)),
            Text(_s('wheelRefs', 'References', locale),
                style: TextStyle(
                    color: wb.mutedText,
                    fontSize: t.scaled(11),
                    fontWeight: FontWeight.w600)),
            SizedBox(height: t.scaled(3)),
            Wrap(
              spacing: t.scaled(6),
              runSpacing: t.scaled(4),
              children: [
                for (final ref in omission.refs)
                  InkWell(
                    onTap: () {
                      Navigator.of(sheet).pop();
                      _jump(context, ref);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: t.scaled(6), vertical: t.scaled(2)),
                      decoration: BoxDecoration(
                          border: Border.all(color: wb.border)),
                      child: Text(localizedReferenceLabel(ref, locale),
                          style: TextStyle(
                              color: wb.accent, fontSize: t.scaled(11))),
                    ),
                  ),
              ],
            ),
          ],
        ]);
      },
    );
  }

  /// A reign arc's own sheet.
  ///
  /// NOT a push to [HebrewKingsPage]. That page cannot be opened on a
  /// particular king — `_showPower` already says so where it lists a
  /// kingdom's kings, and it declines to make its rows tappable for
  /// exactly that reason. A tap that landed the reader at the top of a
  /// 42-king chart would be a worse answer than none, so the arc
  /// answers here and offers the chart as a next step rather than as
  /// the destination.
  ///
  /// The years are `formatReignYears`, shared with that page, so the
  /// wheel and the chart cannot come to word the same reign differently.
  void _showKing(BuildContext context, HebrewKing king, String locale) {
    final wb = WbColors.of(context);
    final houseKing = HebrewKingsService.instance.cached?.byId(king.house);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      isScrollControlled: true,
      builder: (sheet) {
        final t = WbType.of(sheet);
        final alt = king.altNames?[locale];
        final note = king.notes?[locale];

        Widget refRow(String label, String ref) => Padding(
              padding: EdgeInsets.symmetric(vertical: t.scaled(2)),
              child: InkWell(
                onTap: () {
                  Navigator.of(sheet).pop();
                  _jump(context, ref);
                },
                child: Row(children: [
                  Expanded(
                    child: Text(label,
                        style: TextStyle(
                            color: wb.mutedText, fontSize: t.scaled(11))),
                  ),
                  Text(ref,
                      style: TextStyle(
                          color: wb.accent, fontSize: t.scaled(11.5))),
                ]),
              ),
            );

        return _sheet(sheet, [
          Text(king.nameFor(locale),
              style: TextStyle(
                  color: wb.text,
                  fontSize: t.scaled(16),
                  fontWeight: FontWeight.w600)),
          if (alt != null && alt.isNotEmpty)
            Text(alt,
                style:
                    TextStyle(color: wb.mutedText, fontSize: t.scaled(11))),
          SizedBox(height: t.scaled(4)),
          Text(
            [
              kingdomLabel(locale, king.kingdom),
              if (houseKing != null)
                (uiStrings['kingsHouseOf']?[locale] ?? 'House of {name}')
                    .replaceAll('{name}', houseKing.nameFor(locale)),
              formatReignYears(locale, king.reignStart, king.reignEnd),
            ].join(' · '),
            style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11.5)),
          ),
          // THE ARC IS THE HULL, THE SPANS ARE THE REIGN. A co-regency
          // and the sole reign after it are drawn as one arc, because
          // two arcs for one man cannot be read as one man. So the
          // parts are named here — and for the seven kings who have
          // more than one span, this is the only place the wheel says
          // that their arc is not a single interval.
          if (king.spans.length > 1 ||
              king.spans.first.kind != SpanKind.sole) ...[
            SizedBox(height: t.scaled(10)),
            Text(_s('kingsReign', 'Reign', locale),
                style: TextStyle(
                    color: wb.mutedText,
                    fontSize: t.scaled(11),
                    fontWeight: FontWeight.w600)),
            SizedBox(height: t.scaled(3)),
            for (final span in king.spans)
              Text(
                '${spanKindLabel(locale, span.kind)} · '
                '${formatReignYears(locale, span.start, span.end)}',
                style: TextStyle(color: wb.text, fontSize: t.scaled(12)),
              ),
          ],
          if (note != null && note.isNotEmpty) ...[
            SizedBox(height: t.scaled(8)),
            Text(note,
                style: TextStyle(
                    color: wb.mutedText,
                    fontSize: t.scaled(11),
                    height: 1.4)),
          ],
          SizedBox(height: t.scaled(12)),
          Text(_s('kingsPassages', 'Where it is told', locale),
              style: TextStyle(
                  color: wb.mutedText,
                  fontSize: t.scaled(11),
                  fontWeight: FontWeight.w600)),
          if (king.accessionRef != null)
            refRow(_s('kingsAccession', 'Accession synchronism', locale),
                king.accessionRef!),
          if (king.kingsRef != null)
            refRow(_s('kingsInKings', 'In Kings', locale), king.kingsRef!),
          if (king.chroniclesRef != null)
            refRow(_s('kingsInChronicles', 'In Chronicles', locale),
                king.chroniclesRef!)
          // The absence is information, and the kings page says so in
          // the same words. A northern king with no Chronicles row and
          // no sentence would read as a gap in this app.
          else if (king.kingdom == Kingdom.israel)
            Padding(
              padding: EdgeInsets.only(top: t.scaled(2)),
              child: Text(
                _s(
                    'kingsNoChronicles',
                    'Chronicles follows the line of David and gives the '
                        'northern kings no parallel account.',
                    locale),
                style: TextStyle(
                    color: wb.mutedText,
                    fontSize: t.scaled(11),
                    height: 1.4),
              ),
            ),
          SizedBox(height: t.scaled(8)),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () {
                Navigator.of(sheet).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const HebrewKingsPage(),
                  ),
                );
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              // `hebrewKings`, the key the wheel already opens this
              // page under from the power sheet — one label for one
              // destination, in one place.
              child: Text(
                  _s('hebrewKings', 'Kings of Judah & Israel', locale)),
            ),
          ),
        ]);
      },
    );
  }

  void _showPatriarch(BuildContext context, Patriarch man, String locale) {
    final wb = WbColors.of(context);
    final chron = ChronologyService.instance.cached;
    final creation = _creationYear;
    if (chron == null || creation == null) return;
    final anchor = _find(chron.epochs, (e) => e.id == _kAnchorEpoch);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      isScrollControlled: true,
      builder: (sheet) {
        final t = WbType.of(sheet);
        final mt = man.figures[_kDrawnTradition];

        /// One tradition's block: its name, the years it counts, the
        /// total it states, and the verses each figure rests on.
        List<Widget> tradition(String id, {required bool drawn}) {
          final f = man.figures[id];
          if (f == null) return const [];
          final name = chron.traditionById(id).nameFor(locale);
          // The BC year only where this app can honestly compute one:
          // the Masoretic from the derived anchor, the Septuagint from
          // the same anchor shifted by the one epoch both chains share.
          final shift = id == _kDrawnTradition
              ? 0
              : (anchor == null
                  ? null
                  : (anchor.years[_kDrawnTradition] ?? 0) -
                      (anchor.years[id] ?? 0));
          final bc = shift == null ? null : creation + shift + f.birthAm;
          final bcEnd = shift == null ? null : creation + shift + f.deathAm;
          final refs = f.refs.values.toSet().toList();
          return [
            SizedBox(height: t.scaled(8)),
            Text(
              drawn
                  ? '$name · ${_s('wheelLifespansNote', '', locale)}'
                  : name,
              style: TextStyle(
                  color: wb.mutedText,
                  fontSize: t.scaled(11),
                  fontWeight: FontWeight.w600),
            ),
            SizedBox(height: t.scaled(3)),
            Text(
              [
                _fill('wheelLifeAm', 'Anno Mundi {a}–{b}', locale,
                    {'a': f.birthAm, 'b': f.deathAm}),
                _fill('wheelLifeYears', '{n} years', locale,
                    {'n': f.lifespan}),
                if (bc != null && bcEnd != null)
                  '${yearLabel(bc, locale)} – ${yearLabel(bcEnd, locale)}',
              ].join(' · '),
              style: TextStyle(color: wb.text, fontSize: t.scaled(12)),
            ),
            // NOT `timelineSeptuagintYear`, and the reason is the
            // asset's own. That string's body is about Exodus 12:40 —
            // the Greek counting its 430 years in Egypt AND Canaan,
            // which shifts the exodus block by 215 — and
            // `bible_timeline.json`'s `_meta.septuagintYear` states
            // plainly that the pre-Abraham years are "not this shift
            // but a different number for each of them", and declines
            // to print one under that sentence for exactly this
            // reason. Printing 4193 BC under a paragraph about the
            // sojourn would be a figure the sentence does not
            // describe. So this block says what is actually true of a
            // Genesis 5 figure, and the year in it is derived.
            if (!drawn && bc != null) ...[
              SizedBox(height: t.scaled(3)),
              Text(
                _fill('wheelLifeSeptuagintChain', '', locale,
                    {'year': yearLabel(creation + shift!, locale)}),
                style: TextStyle(
                    color: wb.mutedText, fontSize: t.scaled(11), height: 1.4),
              ),
            ],
            if (refs.isNotEmpty) ...[
              SizedBox(height: t.scaled(4)),
              _refRow(context, refs, wb, t, locale),
            ],
          ];
        }

        final person = FamilyTreeService.instance.byId(man.id);
        return _sheet(sheet, [
          Row(children: [
            _swatch(
                t,
                man.line == 'seth'
                    ? _lineColor('none')
                    : _lineColor('shem')),
            SizedBox(width: t.scaled(8)),
            Expanded(
              child: Text(man.nameFor(locale),
                  style: TextStyle(
                      color: wb.text,
                      fontSize: t.scaled(15),
                      fontWeight: FontWeight.w600)),
            ),
            Text(_s('wheelLifespans', 'Genesis lifespans', locale),
                style:
                    TextStyle(color: wb.mutedText, fontSize: t.scaled(11))),
          ]),
          if (mt != null) ...[
            SizedBox(height: t.scaled(4)),
            Text(
              '${yearLabel(creation + mt.birthAm, locale)} – '
              '${yearLabel(creation + mt.deathAm, locale)} · '
              '${_fill('wheelLifeYears', '{n} years', locale, {'n': mt.lifespan})}',
              style: TextStyle(color: wb.mutedText, fontSize: t.scaled(12)),
            ),
          ],
          // The other spelling, when there is one. The reader may have
          // arrived here from the KJV's Genesis 5 and has to be told in
          // as many words that the arc named "Kenan" is the Cainan they
          // were reading about — the app cannot leave them to infer it
          // from four letters in common.
          if (man.nameKjv.isNotEmpty) ...[
            SizedBox(height: t.scaled(2)),
            Text(
              _fill('wheelNameKjv', 'King James Version: {name}', locale,
                  {'name': man.nameKjv}),
              style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11)),
            ),
          ],
          SizedBox(height: t.scaled(8)),
          Text(
            _s('wheelLifeContemporaries', '', locale),
            style: TextStyle(
                color: wb.mutedText, fontSize: t.scaled(11), height: 1.5),
          ),
          for (final id in [
            _kDrawnTradition,
            ...chron.traditions
                .map((x) => x.id)
                .where((x) => x != _kDrawnTradition)
          ])
            ...tradition(id, drawn: id == _kDrawnTradition),
          SizedBox(height: t.scaled(10)),
          Text(_basisText('scripture+thiele', locale),
              style:
                  TextStyle(color: wb.mutedText, fontSize: t.scaled(11))),
          // The whole chain the BC years hang on — 1 Kings 6:1 down to
          // Genesis 5:3 — under the timeline page's own label. Long, and
          // that length is the honest one.
          if (TimelineService.instance.meta.creation!.datingRefs
              .isNotEmpty) ...[
            SizedBox(height: t.scaled(8)),
            Text(
              _s('timelineDatedBy', 'Dated by', locale),
              style: TextStyle(
                  color: wb.mutedText,
                  fontSize: t.scaled(11),
                  fontWeight: FontWeight.w600),
            ),
            SizedBox(height: t.scaled(4)),
            _refRow(context, TimelineService.instance.meta.creation!.datingRefs,
                wb, t, locale),
          ],
          // The family-tree record, when the tree holds this man.
          //
          // FIVE ROWS WERE MISSING HERE AND NOTHING SAID SO. The lookup
          // is by the chart's own id, and the chart used to key five of
          // the twenty-five on the Authorised Version's spelling — enos,
          // cainan, mahalaleel, salah, nahor — while the tree keys them
          // enosh, kenan, mahalalel, shelah, nahor_elder. So those five
          // sheets simply had no "People" row, by the same rule
          // `_personRow` follows, which is to link what resolves and
          // claim nothing about what does not: the rule was right and
          // the key was wrong. The ids are the tree's now and all
          // twenty-five resolve. The null branch stays, because the rule
          // is still the rule — the wheel draws men the tree may not
          // hold — but it is no longer standing in for a defect.
          if (person != null) ...[
            SizedBox(height: t.scaled(8)),
            Text(
              uiStrings['timelinePeople']?[locale] ??
                  uiStrings['timelinePeople']?['en'] ??
                  'People',
              style: TextStyle(
                  color: wb.mutedText,
                  fontSize: t.scaled(11),
                  fontWeight: FontWeight.w600),
            ),
            SizedBox(height: t.scaled(4)),
            _personRow(
              context,
              [
                WheelPersonLink(id: man.id, names: man.names),
              ],
              wb,
              t,
              locale,
            ),
          ],
          SizedBox(height: t.scaled(4)),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ChronologyPage(),
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: wb.link,
              ),
              child: Text(
                _s('timelineOpenChronology', 'Open Bible Chronology', locale),
                style: TextStyle(
                    fontSize: t.scaled(11.5), fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ]);
      },
    );
  }

  /// Everything one spoke stands for, when it stands for more than one
  /// event.
  ///
  /// This is the other half of the `+65` badge and the reason the badge
  /// can be told the truth: the events a rim has no room to name are
  /// not lost, they are one tap away, in year order, each opening its
  /// own sheet. Which one the rim names is stated here rather than left
  /// to be inferred — it is the earliest in the stretch, which is an
  /// arbitrary choice among the members and should read as one.
  void _showCluster(BuildContext context, List<WheelHistoryEvent> events,
      WheelHistoryData data, String locale) {
    final wb = WbColors.of(context);
    final colors = _colorsFor(data);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      isScrollControlled: true,
      builder: (sheet) {
        final t = WbType.of(sheet);
        return _sheet(sheet, [
          Text(
            '${_s('wheelEvents', 'Events', locale)} · ${events.length}',
            style: TextStyle(
                color: wb.text,
                fontSize: t.scaled(15),
                fontWeight: FontWeight.w600),
          ),
          SizedBox(height: t.scaled(2)),
          Text(
            '${yearLabel(events.first.year, locale)} – '
            '${yearLabel(events.last.year, locale)}',
            style: TextStyle(color: wb.mutedText, fontSize: t.scaled(12)),
          ),
          SizedBox(height: t.scaled(6)),
          Text(
            _s('wheelClusterNote',
                'The rim has room for one name here. Tap any event to open it.',
                locale),
            style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11)),
          ),
          SizedBox(height: t.scaled(8)),
          for (final e in events)
            InkWell(
              onTap: () {
                Navigator.of(sheet).pop();
                _select(e.id);
                _showEvent(context, e, data, locale);
              },
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: t.scaled(4)),
                child: Row(children: [
                  _swatch(t, colors[e.stream] ?? _lineColor('none')),
                  SizedBox(width: t.scaled(8)),
                  Expanded(
                    child: Text(e.titleFor(locale),
                        style: TextStyle(
                            color: wb.text, fontSize: t.scaled(12))),
                  ),
                  SizedBox(width: t.scaled(8)),
                  Text(yearLabel(e.year, locale),
                      style: TextStyle(
                          color: wb.mutedText, fontSize: t.scaled(11))),
                ]),
              ),
            ),
        ]);
      },
    );
  }

  void _showPower(BuildContext context, WheelPower p, WheelHistoryData data,
      String locale) {
    final wb = WbColors.of(context);
    final stream = data.streams.firstWhere((s) => s.id == p.stream,
        orElse: () => const WheelStream(id: '', line: 'none', names: {}));
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      isScrollControlled: true,
      builder: (sheet) {
        final t = WbType.of(sheet);
        return _sheet(sheet, [
          Row(children: [
            _swatch(t, _colorsFor(data)[stream.id] ?? _lineColor(stream.line)),
            SizedBox(width: t.scaled(8)),
            Expanded(
              child: Text(p.nameFor(locale),
                  style: TextStyle(
                      color: wb.text,
                      fontSize: t.scaled(15),
                      fontWeight: FontWeight.w600)),
            ),
          ]),
          SizedBox(height: t.scaled(4)),
          Text(
              [
                '${yearLabel(p.start, locale)} – '
                    '${p.ongoing ? _s('wheelPresent', 'present', locale) : yearLabel(p.end!, locale)}',
                // The place, beside the years. See `wheelRegion*`.
                if (_regionLabel(p.region, locale) case final where
                    when where.isNotEmpty)
                  where,
              ].join(' · '),
              style: TextStyle(color: wb.mutedText, fontSize: t.scaled(12))),
          if (p.noteFor(locale).isNotEmpty) ...[
            SizedBox(height: t.scaled(8)),
            Text(p.noteFor(locale),
                style: TextStyle(color: wb.text, fontSize: t.scaled(12))),
          ],
          if (p.refs.isNotEmpty) ...[
            SizedBox(height: t.scaled(8)),
            _refRow(context, p.refs, wb, t, locale),
          ],
          SizedBox(height: t.scaled(10)),
          // Ask the record, do not assume. This line used to be a constant
          // "conventional date, not stated in scripture" — which the three
          // Israelite kingdoms contradict, and whose verses sit two lines
          // above it.
          Text(
            p.approximate
                ? '${_basisText(p.basis, locale)} · '
                    '${_s('wheelApprox', 'approximate', locale)}'
                : _basisText(p.basis, locale),
            style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11)),
          ),
          // WHO REIGNED IN IT.
          //
          // A reader who taps the Kingdom of Judah is asking who, and
          // until now the sheet answered with two names in the note —
          // "from Rehoboam to Zedekiah" — and no way to reach the other
          // eighteen. The app charts all forty-two, on its own page,
          // and nothing on this wheel led there.
          //
          // Read live from `hebrew_kings.json`, never copied into the
          // wheel's asset: that file IS this app's Thiele chart, and a
          // copy would drift from it.
          //
          // The basis line sits directly above and covers these years —
          // for these three powers it already reads "interval from
          // scripture, year from Thiele" — which is why no reign here
          // carries a second disclosure of its own.
          //
          // Rows do not open anything. A king's record lives on a page
          // this sheet cannot select into, and a row that looks
          // tappable and merely closes the sheet is worse than a row
          // that plainly is not. The one tappable thing is the way out.
          ...(() {
            final kingdom = kWheelPowerKingdoms[p.id];
            if (kingdom == null) return const <Widget>[];
            final kings = HebrewKingsService.instance.cached
                    ?.ofKingdom(kingdom) ??
                const <HebrewKing>[];
            if (kings.isEmpty) return const <Widget>[];
            return <Widget>[
              SizedBox(height: t.scaled(12)),
              Text(
                _fill('wheelKings', 'Kings · {n}', locale, {'n': kings.length}),
                style: TextStyle(
                    color: wb.mutedText,
                    fontSize: t.scaled(11),
                    fontWeight: FontWeight.w600),
              ),
              SizedBox(height: t.scaled(4)),
              for (final k in kings)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: t.scaled(3)),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        k.spans.length > 1
                            ? '${k.nameFor(locale)} · '
                                '${_s('kingsCoregency', 'co-regency', locale)}'
                            : k.nameFor(locale),
                        style: TextStyle(
                            color: wb.text, fontSize: t.scaled(11.5)),
                      ),
                    ),
                    Text(
                      '${yearLabel(k.reignStart, locale)} – '
                      '${yearLabel(k.reignEnd, locale)}',
                      style: TextStyle(
                          color: wb.mutedText, fontSize: t.scaled(11)),
                    ),
                  ]),
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HebrewKingsPage(),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: wb.link,
                  ),
                  child: Text(
                    _s('hebrewKings', 'Kings of Judah & Israel', locale),
                    style: TextStyle(
                        fontSize: t.scaled(11.5),
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ];
          })(),
          // WHAT STOOD AT THE SAME TIME AS IT.
          //
          // The wheel draws a power as an arc and its events as spokes
          // on the same ring, and nothing said the two were related.
          // That relation is the one thing the printed chart carries
          // that this app did not — it nests a reign inside a kingdom
          // inside a people, so the geometry states the parentage.
          // Stated here in a heading instead, which is the form this
          // app has always used for containment (a band's sheet lists
          // its powers; the family tree indents; a book holds its
          // chapters).
          //
          // The heading says SPAN, not ownership, and that wording is
          // load-bearing: an event on this band inside these years is
          // not thereby an event of this power.
          ...(() {
            final end = p.ongoing ? kMaxYear : p.end!;
            final within = data
                .eventsOf(p.stream)
                .where((e) => e.year >= p.start && e.year <= end)
                .toList()
              ..sort((a, b) => a.year.compareTo(b.year));
            if (within.isEmpty) return const <Widget>[];
            return <Widget>[
              SizedBox(height: t.scaled(12)),
              Text(
                _fill('wheelWithinSpan', 'Within this span · {n}', locale,
                    {'n': within.length}),
                style: TextStyle(
                    color: wb.mutedText,
                    fontSize: t.scaled(11),
                    fontWeight: FontWeight.w600),
              ),
              SizedBox(height: t.scaled(4)),
              for (final e in within)
                InkWell(
                  onTap: () {
                    Navigator.of(sheet).pop();
                    _select(e.id);
                    _showEvent(context, e, data, locale);
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: t.scaled(3)),
                    child: Row(children: [
                      Expanded(
                        child: Text(e.titleFor(locale),
                            style: TextStyle(
                                color: wb.text, fontSize: t.scaled(11.5))),
                      ),
                      Text(yearLabel(e.year, locale),
                          style: TextStyle(
                              color: wb.mutedText, fontSize: t.scaled(11))),
                    ]),
                  ),
                ),
            ];
          })(),
        ]);
      },
    );
  }

  /// A band, opened: what it is, whom it descends from in Genesis 10 —
  /// every name a tappable verse — and everything it carries.
  void _showStream(BuildContext context, WheelStream s, WheelHistoryData data,
      String locale) {
    final wb = WbColors.of(context);
    final nations = data.nationsOf(s.id);
    final powers = data.powersOf(s.id)
      ..sort((a, b) => a.start.compareTo(b.start));
    final events = data.eventsOf(s.id)
      ..sort((a, b) => a.year.compareTo(b.year));

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      isScrollControlled: true,
      builder: (sheet) {
        final t = WbType.of(sheet);
        return _sheet(sheet, [
          Row(children: [
            _swatch(t, _colorsFor(data)[s.id] ?? _lineColor(s.line)),
            SizedBox(width: t.scaled(8)),
            Expanded(
              child: Text(s.nameFor(locale),
                  style: TextStyle(
                      color: wb.text,
                      fontSize: t.scaled(16),
                      fontWeight: FontWeight.w600)),
            ),
          ]),
          if (nations.isNotEmpty) ...[
            SizedBox(height: t.scaled(10)),
            Text(_s('wheelDescent', 'Descent in Genesis 10', locale),
                style: TextStyle(
                    color: wb.text,
                    fontSize: t.scaled(12),
                    fontWeight: FontWeight.w600)),
            for (final n in nations)
              Padding(
                padding: EdgeInsets.only(top: t.scaled(4)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.nameFor(locale),
                              style: TextStyle(
                                  color: wb.text, fontSize: t.scaled(12))),
                          if (n.noteFor(locale).isNotEmpty)
                            Text(n.noteFor(locale),
                                style: TextStyle(
                                    color: wb.mutedText,
                                    fontSize: t.scaled(11))),
                        ],
                      ),
                    ),
                    SizedBox(width: t.scaled(8)),
                    InkWell(
                      onTap: () => _readVerse(context, n.ref),
                      onLongPress: () => _jump(context, n.ref),
                      child: Text(localizedReferenceLabel(n.ref, locale),
                          style: TextStyle(
                              color: wb.link, fontSize: t.scaled(11))),
                    ),
                  ],
                ),
              ),
          ],
          if (powers.isNotEmpty) ...[
            SizedBox(height: t.scaled(12)),
            Text('${_s('wheelPowers', 'Powers', locale)} · ${powers.length}',
                style: TextStyle(
                    color: wb.text,
                    fontSize: t.scaled(12),
                    fontWeight: FontWeight.w600)),
            for (final p in powers)
              Padding(
                padding: EdgeInsets.only(top: t.scaled(3)),
                child: Row(children: [
                  Expanded(
                    child: Text(p.nameFor(locale),
                        style: TextStyle(
                            color: wb.text, fontSize: t.scaled(11.5))),
                  ),
                  Text(
                      '${yearLabel(p.start, locale)} – '
                      '${p.ongoing ? _s('wheelPresent', 'present', locale) : yearLabel(p.end!, locale)}',
                      style: TextStyle(
                          color: wb.mutedText, fontSize: t.scaled(11))),
                ]),
              ),
          ],
          if (events.isNotEmpty) ...[
            SizedBox(height: t.scaled(12)),
            Text('${_s('wheelEvents', 'Events', locale)} · ${events.length}',
                style: TextStyle(
                    color: wb.text,
                    fontSize: t.scaled(12),
                    fontWeight: FontWeight.w600)),
            // These rows open. They did not until 2026-08-25: a stream's
            // sheet named every event on it and offered no way to reach
            // one, so a reader who found what they were looking for here
            // had to go back and hunt the rim for a tick. That is the
            // same defect the `+n` badge exists to end — an event the
            // wheel names and the reader cannot open — and the powers
            // above are left alone precisely because they do NOT have
            // it: a power occupies a band, and tapping the band opens it.
            for (final e in events)
              InkWell(
                onTap: () {
                  Navigator.of(sheet).pop();
                  _select(e.id);
                  _showEvent(context, e, data, locale);
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: t.scaled(3)),
                  child: Row(children: [
                    Expanded(
                      child: Text(e.titleFor(locale),
                          style: TextStyle(
                              color: wb.text, fontSize: t.scaled(11.5))),
                    ),
                    Text(yearLabel(e.year, locale),
                        style: TextStyle(
                            color: wb.mutedText, fontSize: t.scaled(11))),
                  ]),
                ),
              ),
          ],
        ]);
      },
    );
  }
}

// ── the painter ──────────────────────────────────────────────────────

class _WorldWheelPainter extends CustomPainter {
  _WorldWheelPainter({
    required this.streams,
    required this.colors,
    required this.arcs,
    required this.spokes,
    required this.lives,
    required this.rail,
    required this.locale,
    required this.selectedId,
    required this.wb,
    required this.zoom,
    required this.rimFont,
    required this.endFont,
    required this.bandFont,
  });

  final List<WheelStream> streams;

  /// The genealogy rail's marks, empty when the layer is off.
  final List<_Rail> rail;

  /// Band id → its own shade. See `streamColor`.
  final Map<String, Color> colors;

  final List<_Arc> arcs;
  final List<_Spoke> spokes;
  final List<_Life> lives;
  final String locale;
  final String? selectedId;
  final WbColors wb;

  /// Everything textual is divided by this, so a letter keeps the same
  /// size on the reader's screen however far in they zoom.
  final double zoom;

  final double rimFont;
  final double endFont;
  final double bandFont;

  @override
  void paint(Canvas canvas, Size size) {
    if (streams.isEmpty) return;
    final side = math.min(size.width, size.height);
    final c = Offset(size.width / 2, size.height / 2);
    final rHub = side * _kHubFrac;
    final rBands = side * _kBandsFrac;
    final rRim = side * _kRimFrac;

    _paintCenturies(canvas, c, rHub, rRim);
    _paintGrooves(canvas, c, rHub, rBands);
    _paintArcs(canvas, c, rHub, rBands);
    _paintBandNames(canvas, c, rHub, rBands);
    // BEFORE the spokes, deliberately. The lives are a tint the event
    // text prints over, the way a printed chart sets its text over its
    // bars — the wheel's own grooves are alpha 0.06 and its power arcs
    // 0.78, and this sits between at 0.22.
    _paintLifespans(canvas, c, rBands, rRim);
    _paintRail(canvas, c);
    _paintSpokes(canvas, c, rBands);
    _paintRim(canvas, c, rBands, rRim);
    _paintHub(canvas, c, rHub);
    _paintAxisEnds(canvas, c, rHub, rRim);
  }

  void _paintCenturies(Canvas canvas, Offset c, double rHub, double rRim) {
    final minor = Paint()
      ..color = wb.border.withValues(alpha: 0.2)
      ..strokeWidth = 0.5;
    final major = Paint()
      ..color = wb.border.withValues(alpha: 0.5)
      ..strokeWidth = 0.9;
    for (var y = kMinYear; y <= kMaxYear; y += 100) {
      if (y == kMinYear) continue;
      final isMajor = y % 500 == 0;
      final a = angleForSpan(y, kMinYear, kMaxYear);
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * rHub, c + dir * rRim, isMajor ? major : minor);
    }
    // The stagger this replaces — 11 units, then 22, alternating — was
    // there "so adjacent labels clear each other", and adjacent 500-year
    // labels are 26.5° and about 190 canvas units apart: they were never
    // in any danger from one another. What it did achieve was to put
    // half the scale INSIDE the rim, on top of the event titles that end
    // there. See `ringLabelRadius`.
    for (final l in _axisLabels().where((l) => l.onRing)) {
      _ringLabel(canvas, c, l.text, l.angle, rRim + kAxisLabelClearance,
          wb.mutedText, rimFont / _labelScale(zoom));
    }
  }

  List<AxisLabel> _axisLabels() => planAxisLabels(
        minYear: kMinYear,
        maxYear: kMaxYear,
        tickLabel: (y) => centuryTickLabel(y, locale),
        endLabel: (y) => yearLabel(y, locale),
        endSwing: kAxisEndSwing,
      );

  /// A label lying along the ring outside the rim, centred on [angle],
  /// its inner edge on [innerEdge].
  ///
  /// Drawn as one straight run rather than character by character. The
  /// arc labels inside the wheel are bent glyph by glyph because they
  /// span whole eras; a year label spans six degrees, where bending
  /// would buy 0.6 canvas units of fidelity and cost every kerning pair
  /// in the string.
  void _ringLabel(Canvas canvas, Offset c, String text, double angle,
      double innerEdge, Color color, double size) {
    if (text.isEmpty) return;
    final tp = _painter(text, color, size);
    final r =
        ringLabelRadius(rRim: innerEdge, clearance: 0, height: tp.height);
    // On the lower half the tangent would run the text upside down, so
    // it is turned the other way — the same rule `_charsOnArc` uses, so
    // every word outside the hub keeps its top pointing outward.
    final flip = math.sin(angle) > 0;
    canvas.save();
    canvas.translate(
        c.dx + math.cos(angle) * r, c.dy + math.sin(angle) * r);
    canvas.rotate(angle + (flip ? -math.pi / 2 : math.pi / 2));
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  /// A faint groove per band, so an empty stretch still reads as that
  /// band rather than as blank paper.
  void _paintGrooves(Canvas canvas, Offset c, double rHub, double rBands) {
    for (var i = 0; i < streams.length; i++) {
      final band = ringRadii(i, streams.length, rHub, rBands);
      canvas.drawArc(
          Rect.fromCircle(center: c, radius: band.centre),
          startRad,
          sweepRad,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = band.width
            ..color = (colors[streams[i].id] ?? _lineColor(streams[i].line))
                .withValues(alpha: 0.06));
    }
  }

  void _paintArcs(Canvas canvas, Offset c, double rHub, double rBands) {
    final has = selectedId != null;
    for (final arc in arcs) {
      final band = ringRadii(arc.ring, streams.length, rHub, rBands);
      // The outline marks the power itself; the dimming follows the
      // whole selection, which may be this arc's stream.
      final sel = arc.power.id == selectedId;
      final lit = selectionCovers(
        selectedId: selectedId,
        ownId: arc.power.id,
        streamId: streams[arc.ring].id,
      );
      final dim = has && !lit ? 0.35 : 1.0;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: band.centre),
        arc.a0,
        arc.a1 - arc.a0,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = band.width * 0.86
          ..color = arc.color.withValues(alpha: 0.78 * dim),
      );
      // Hairlines at the boundaries so adjacent spans read as separate.
      final edge = Paint()
        ..strokeWidth = 0.7
        ..color = wb.paneBg.withValues(alpha: 0.85);
      for (final a in [arc.a0, arc.a1]) {
        final dir = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(c + dir * (band.centre - band.width * 0.43),
            c + dir * (band.centre + band.width * 0.43), edge);
      }
      if (sel) {
        canvas.drawArc(
            Rect.fromCircle(center: c, radius: band.outer),
            arc.a0,
            arc.a1 - arc.a0,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = wb.text.withValues(alpha: 0.85));
      }
      final name = arc.power.nameFor(locale);
      final size = fitArcLabel(
        text: name,
        radius: band.centre,
        sweep: arc.a1 - arc.a0,
        maxEm: ringPitch(streams.length, rHub, rBands) *
            kArcLabelPitchFraction,
        desiredSize: rimFont / _labelScale(zoom),
        zoom: zoom,
        floorPx: kArcLabelFloorPx,
        measure: _measureChars,
      );
      if (size > 0) {
        _tangentialLabel(
            canvas, c, band.centre, name, arc.a0, arc.a1 - arc.a0, size, dim);
      }
    }
  }

  /// The Genesis lifespans, as arcs in the label annulus.
  ///
  /// TICKS ON THE YEARS, AND NOTHING PAST THEM. The stroke runs from
  /// the birth angle to the death angle with a butt cap and a hairline
  /// across the ring at each end. A round cap would put ink a pixel
  /// either side of both, which on this axis is about eleven years at
  /// rest — a chart whose rule is "never invent a date" does not
  /// stretch a life for looks.
  ///
  /// WHEN ONE IS SELECTED, two hairlines run the whole depth of the
  /// annulus at his birth year and his death year. That is the
  /// Chronology page's vertical contemporaries band, read in polar:
  /// every arc the pair crosses is a life that overlapped his.
  /// The genealogy rail: one mark per year, its height saying how many
  /// people the tree places in that year.
  ///
  /// A HEIGHT, NOT A NUMBER PRINTED. Forty-four names cannot be written
  /// at one angle, and a mark that is taller than its neighbours says
  /// "more here" without claiming to say who — which the sheet does
  /// when the mark is tapped. Drawn dashed and grey because none of
  /// these years rests on a verse.
  void _paintRail(Canvas canvas, Offset c) {
    if (rail.isEmpty) return;
    final has = selectedId != null;
    for (final r in rail) {
      final sel = selectedId == '$kLineageArcPrefix${r.cohort.year}';
      final alpha = sel ? 0.9 : (has ? 0.30 * 0.35 : 0.30);
      // 1 person is a third of the ring, 8 or more fills it. Clamped so
      // the 44-person year does not print into its neighbours.
      final fill = (0.34 + 0.66 * ((r.cohort.people.length - 1) / 7))
          .clamp(0.34, 1.0);
      final half = r.pitch * 0.5 * fill;
      final dir = Offset(math.cos(r.angle), math.sin(r.angle));
      canvas.drawLine(
        c + dir * (r.centre - half),
        c + dir * (r.centre + half),
        Paint()
          ..strokeWidth = sel ? 1.8 : 1.0
          ..color = lineageRailColor().withValues(alpha: alpha),
      );
    }
  }

  void _paintLifespans(Canvas canvas, Offset c, double rBands, double rRim) {
    if (lives.isEmpty) return;
    final has = selectedId != null;
    for (final l in lives) {
      final sel = l.id == selectedId;
      // 0.22 at rest, so spoke titles stay legible over it; 0.85 for
      // the one selected; a third for everything else once something
      // is.
      final alpha = sel ? 0.85 : (has ? 0.22 * 0.35 : 0.22);
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: l.centre),
        l.arc.a0,
        l.arc.sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt
          ..strokeWidth = l.stroke
          ..color = l.color.withValues(alpha: alpha),
      );
      final tick = Paint()
        ..strokeWidth = sel ? 1.4 : 0.7
        ..color = l.color.withValues(alpha: (alpha * 2).clamp(0.0, 1.0));
      for (final a in [l.arc.a0, l.arc.a1]) {
        final dir = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(c + dir * (l.centre - l.stroke * 0.62),
            c + dir * (l.centre + l.stroke * 0.62), tick);
      }
      if (l.name.isNotEmpty && l.nameSize > 0) {
        _tangentialLabel(canvas, c, l.centre, l.name, l.nameA0, l.nameSweep,
            l.nameSize, sel ? 1.0 : 0.75);
      }
    }
    final chosen = _find(lives, (l) => l.id == selectedId);
    if (chosen == null) return;
    final rule = Paint()
      ..strokeWidth = 0.9
      ..color = wb.text.withValues(alpha: 0.5);
    for (final a in [chosen.arc.a0, chosen.arc.a1]) {
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
          c + dir * scriptureLabelBase(rBands), c + dir * rRim, rule);
    }
  }

  static T? _find<T>(List<T> xs, bool Function(T) test) {
    for (final x in xs) {
      if (test(x)) return x;
    }
    return null;
  }

  /// The band's own name, set in the gap wedge before twelve o'clock,
  /// where no data is ever drawn.
  void _paintBandNames(Canvas canvas, Offset c, double rHub, double rBands) {
    for (var i = 0; i < streams.length; i++) {
      final band = ringRadii(i, streams.length, rHub, rBands);
      final tp = TextPainter(
        text: TextSpan(
          text: streams[i].nameFor(locale),
          style: canvasTextStyle(
            color: (colors[streams[i].id] ?? _lineColor(streams[i].line))
                .withValues(alpha: 0.98),
            fontSize: math.min(bandFont / _labelScale(zoom), band.width * 1.05),
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(c.dx, c.dy - band.centre);
      tp.paint(canvas, Offset(-tp.width - 7, -tp.height / 2));
      canvas.restore();
    }
  }

  void _paintSpokes(Canvas canvas, Offset c, double rBands) {
    final has = selectedId != null;
    // The tick sits ON THE BAND, for every event, whichever end of the
    // annulus its words are flush with. That is what it is for — the
    // year's mark on its own stream — and it is now the only thing
    // drawn for an event whose title could not be set legibly at this
    // size, so it must be where the event belongs rather than where its
    // text happens to start.
    final rTick = scriptureLabelBase(rBands);
    for (final s in spokes) {
      final sel = s.event.id == selectedId;
      final lit = selectionCovers(
        selectedId: selectedId,
        ownId: s.event.id,
        streamId: s.event.stream,
      );
      final dim = has && !lit ? 0.28 : 1.0;
      final a = s.label.angle;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        c + dir * (rTick - 5),
        c + dir * rTick,
        Paint()
          ..strokeWidth = sel ? 1.5 : 0.8
          ..color = s.color.withValues(alpha: 0.8 * dim),
      );
      _radialLabel(canvas, c, s, dim, sel);
    }
  }

  /// Event text running OUTWARD along its spoke — the whole reason this
  /// wheel can carry two hundred events without overprinting.
  ///
  /// A scripture event carries its verse right on the label once there
  /// is room for it: the reference IS the evidence, and a chart that
  /// makes a claim about scripture should show where to check it
  /// without a tap.
  ///
  /// WHAT to draw was decided by `planRadialSpokes`, not here. The
  /// painter used to fit the text itself, which put the one decision
  /// nothing can test — is this label legible? — inside the one place
  /// no test can read. An empty [_Spoke.title] means the tick alone.
  void _radialLabel(Canvas canvas, Offset c, _Spoke s, double dim, bool sel) {
    if (s.title.isEmpty && s.badge.isEmpty) return;
    final style = canvasTextStyle(
      color: sel ? wb.text : wb.text.withValues(alpha: 0.95 * dim),
      fontSize: rimFont / _labelScale(zoom),
      fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
    );
    final refStyle = canvasTextStyle(
      color: wb.link.withValues(alpha: 0.95 * dim),
      fontSize: (rimFont / _labelScale(zoom)) * _kRefSizeRatio,
    );
    // Muted ink and the verse's size, so it reads as a count of things
    // rather than as part of the name it follows: `+65` after *Boxer
    // Uprising Martyrdoms* must not look like a title. The size must
    // match what `fitRadialLabel` reserved for it, or the fitting is
    // measuring a string nobody draws.
    final badgeStyle = canvasTextStyle(
      color: wb.mutedText.withValues(alpha: 0.95 * dim),
      fontSize: (rimFont / _labelScale(zoom)) * _kRefSizeRatio,
    );
    final tp = TextPainter(
        text: TextSpan(text: s.title, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1)
      ..layout();
    final refTp = s.ref.isEmpty
        ? null
        : (TextPainter(
            text: TextSpan(text: '  ${s.ref}', style: refStyle),
            textDirection: TextDirection.ltr,
            maxLines: 1)
          ..layout());
    final badgeTp = s.badge.isEmpty
        ? null
        : (TextPainter(
            text: TextSpan(
                text: s.title.isEmpty ? s.badge : '  ${s.badge}',
                style: badgeStyle),
            textDirection: TextDirection.ltr,
            maxLines: 1)
          ..layout());

    final a = s.label.angle;
    canvas.save();
    if (s.label.flipped) {
      // On the left half, run the text from the outer end inward so it
      // still reads left to right instead of upside down.
      canvas.translate(c.dx + math.cos(a) * s.label.rEnd,
          c.dy + math.sin(a) * s.label.rEnd);
      canvas.rotate(a + math.pi);
    } else {
      canvas.translate(c.dx + math.cos(a) * s.label.rStart,
          c.dy + math.sin(a) * s.label.rStart);
      canvas.rotate(a);
    }
    if (s.title.isNotEmpty) tp.paint(canvas, Offset(0, -tp.height / 2));
    final afterTitle = s.title.isEmpty ? 0.0 : tp.width;
    refTp?.paint(canvas, Offset(afterTitle, -refTp.height / 2));
    badgeTp?.paint(
        canvas,
        Offset(afterTitle + (refTp?.width ?? 0),
            -badgeTp.height / 2));
    canvas.restore();
  }

  /// A label along the arc, centred in the span, at the size
  /// [fitArcLabel] resolved.
  ///
  /// The painter used to decide the size itself: a `clamp(6, 10)` on a
  /// geometric cap, then two attempts at 80%. The clamp's FLOOR was the
  /// binding limit — it raised a 4 px cap back to 6 — so every label on
  /// this wheel was set at exactly 6 canvas units whatever the canvas
  /// size, the locale or the zoom, which is 6 px on screen at rest and
  /// 48 px at 800%. The decision now lives in a function a test can read.
  void _tangentialLabel(Canvas canvas, Offset c, double radius, String text,
      double a0, double sweep, double fontSize, double dim) {
    if (sweep <= 0 || fontSize <= 0) return;
    final style = canvasTextStyle(
        color: wb.text.withValues(alpha: 0.98 * dim), fontSize: fontSize);
    final widths = <double>[];
    var total = 0.0;
    for (final ch in text.characters) {
      final tp = TextPainter(
          text: TextSpan(text: ch, style: style),
          textDirection: TextDirection.ltr)
        ..layout();
      widths.add(tp.width);
      total += tp.width;
    }
    final angular = total / radius;
    _charsOnArc(canvas, c, radius, text, widths, style,
        a0 + (sweep - angular) / 2, angular);
  }

  void _charsOnArc(Canvas canvas, Offset c, double radius, String text,
      List<double> widths, TextStyle style, double a0, double angular) {
    final flip = math.sin(a0 + angular / 2) > 0;
    var pen = flip ? a0 + angular : a0;
    final chars = text.characters.toList();
    for (var i = 0; i < chars.length; i++) {
      final da = widths[i] / radius;
      final th = flip ? pen - da / 2 : pen + da / 2;
      final tp = TextPainter(
          text: TextSpan(text: chars[i], style: style),
          textDirection: TextDirection.ltr)
        ..layout();
      canvas.save();
      canvas.translate(
          c.dx + math.cos(th) * radius, c.dy + math.sin(th) * radius);
      canvas.rotate(th + (flip ? -math.pi / 2 : math.pi / 2));
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
      pen += flip ? -da : da;
    }
  }

  // A hairline used to be drawn at 44% of the annulus, marking where
  // scripture-dated labels stopped and conventionally-dated ones began.
  // There is no such boundary now — see `planRadialSpokes`, which gives
  // both the whole radius and distinguishes them by which ring they are
  // flush against. The line is gone rather than left pointing at
  // nothing; the two edges it would mark are the band ring and the rim
  // ring, and both are already drawn.

  void _paintRim(Canvas canvas, Offset c, double rBands, double rRim) {
    for (final (r, w, alpha) in [
      (rBands + 1.0, 0.6, 0.45),
      (rRim + 3.0, 0.9, 0.55),
      (rRim + kRimOuterRing, 0.4, 0.3),
    ]) {
      canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          startRad,
          sweepRad,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w
            ..color = wb.border.withValues(alpha: alpha));
    }
  }

  void _paintHub(Canvas canvas, Offset c, double rHub) {
    canvas.drawCircle(c, rHub, Paint()..color = wb.paneAltBg);
    canvas.drawCircle(
        c,
        rHub,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = wb.border);
  }

  void _paintAxisEnds(Canvas canvas, Offset c, double rHub, double rRim) {
    final paint = Paint()
      ..color = wb.border
      ..strokeWidth = 1;
    for (final l in _axisLabels().where((l) => !l.onRing)) {
      final a = angleForSpan(l.year, kMinYear, kMaxYear);
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * rHub, c + dir * (rRim + kRimOuterRing), paint);
      final la = l.angle;
      final size = endFont / _labelScale(zoom);
      final tp = _painter(l.text, wb.text, size);
      // Same rule as the century ticks and for the same reason, but
      // horizontal: these two say what the chart's range IS, they are
      // the labels a reader goes to first, and at 53° and 37° off the
      // horizontal there is room for them to stay level. `rRim + 17`
      // was not enough — 主后2026 reached 3.9 units inside the rim.
      final r = axialLabelRadius(
        angle: la,
        rRim: rRim,
        width: tp.width,
        height: tp.height,
        clearance: kAxisLabelClearance,
      );
      tp.paint(
          canvas,
          c +
              Offset(math.cos(la), math.sin(la)) * r -
              Offset(tp.width / 2, tp.height / 2));
    }
  }

  /// A laid-out run. Everything outside the hub now needs the SIZE of
  /// its text before it can decide where the text goes, so measuring
  /// and painting are two steps rather than one.
  TextPainter _painter(String text, Color color, double size) => TextPainter(
        text: TextSpan(
            text: text, style: canvasTextStyle(color: color, fontSize: size)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();

  @override
  bool shouldRepaint(_WorldWheelPainter old) =>
      old.selectedId != selectedId ||
      old.locale != locale ||
      old.streams.length != streams.length ||
      old.arcs.length != arcs.length ||
      old.spokes.length != spokes.length ||
      old.lives.length != lives.length ||
      old.zoom != zoom ||
      old.rimFont != rimFont ||
      old.endFont != endFont ||
      old.bandFont != bandFont;
}
