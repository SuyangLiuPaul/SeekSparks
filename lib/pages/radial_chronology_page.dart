import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show PointerDeviceKind, kTouchSlop;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/strip_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/biblical_person.dart';
import 'package:seeksparks/models/chronology.dart'
    show ChronologyData, Patriarch;
import 'package:seeksparks/models/hebrew_king.dart';
import 'package:seeksparks/models/strip_lanes.dart'
    show StripLane, StripLaneKind, buildStripLanes, stripLineageCohorts;
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/chronology_page.dart';
import 'package:seeksparks/pages/family_tree_page.dart';
import 'package:seeksparks/pages/hebrew_kings_page.dart';
import 'package:seeksparks/pages/strip_chronology_page.dart';
import 'package:seeksparks/pages/wheel_sheets.dart';
import 'package:seeksparks/services/chronology_service.dart';
import 'package:seeksparks/services/family_tree_service.dart';
import 'package:seeksparks/services/hebrew_kings_service.dart';
import 'package:seeksparks/services/url_sync_service.dart';
import 'package:seeksparks/utils/date_hedge.dart';
import 'package:seeksparks/utils/font_catalog.dart';
import 'package:seeksparks/utils/radial_chronology_layout.dart';
import 'package:seeksparks/utils/strip_chronology_layout.dart'
    show kStripZoomSteps;
import 'package:seeksparks/utils/version_mapper.dart'
    show localizedReferenceLabel;
import 'package:seeksparks/utils/wheel_search.dart';
import 'package:seeksparks/widgets/chart_hover_plate.dart';
import 'package:seeksparks/widgets/localized_back_button.dart';
import 'package:seeksparks/utils/year_digest.dart'
    show buildYearDigest, YearDigestItem, YearMoment;
import 'package:seeksparks/widgets/wheel_chrome_bar.dart';
import 'package:seeksparks/widgets/year_digest_bar.dart';
import 'package:seeksparks/utils/wheel_text_metrics.dart';
import 'package:seeksparks/services/chart_symbol_service.dart';
import 'package:seeksparks/utils/chronology_palette.dart';
import 'package:seeksparks/utils/chronology_symbols.dart';
import 'package:seeksparks/utils/wheel_default_streams.dart';
import 'package:seeksparks/utils/wheel_view_layout.dart';
import 'package:seeksparks/utils/chronology_explorer.dart';
import 'package:seeksparks/widgets/chronology_explorer.dart';
import 'package:seeksparks/widgets/chronology_filter_sheet.dart';
import 'package:seeksparks/widgets/stacked_chronology_wheel.dart';
import 'package:seeksparks/widgets/chronology_depth_toggle.dart';
import 'package:seeksparks/utils/chronology_depth_view.dart';
import 'package:seeksparks/utils/wheel_stack_layout.dart';

/// The default stacked view gives concurrent spans separate heights and
/// keeps every enabled ring in place. StackedChronologyWheel owns its projection;
/// the event explorer and detail sheets are shared with the flat view.
/// The geometry notes below describe the retained flat view.
///
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
  const RadialChronologyPage(
      {super.key,
      this.initialPeriod,
      this.initialHiddenStreams,
      this.initialStacked = false});

  /// Switching forms keeps the reader's range and layer choices. Each
  /// route still owns its controller, so replacing one cannot dispose
  /// the incoming page's navigation state.
  final ChronologyPeriod? initialPeriod;
  final Set<String>? initialHiddenStreams;
  /// 2026-09-16 「sword wheel default应该是平面图」. The depth view is the
  /// more striking picture and the flat one is the readable chart, so
  /// the chart is what a reader is handed; the toggle is right there.
  final bool initialStacked;

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

/// How far in the wheel will go.
///
/// WHY IT MOVED FROM 14 TO 40. The owner reported 「zoom in max 也有
/// 上限 这个还有很多没有显示出来」 with the wheel sitting at its old
/// ceiling of 1400%, and that was a fair reading of what was on screen:
/// the 22 stream rings share `side x 0.17`, so at 1400% on a 390 px
/// phone a ring is about 42 px and the events crowded onto the busiest
/// stretch of the rim still overlap. 40x is 4000%, which is where the
/// 140 post-1900 events — 8.06x their share of the axis — finally have
/// room to print their own titles.
///
/// This is NOT the same fix the strip got, and the difference is the
/// whole reason both forms exist. `InteractiveViewer` scales both axes
/// together, so raising this ceiling magnifies Methuselah's 969 years
/// along with Zimri's seven days: the crowding gets pushed off the
/// screen rather than resolved. The strip's ladder separates the two
/// axes and actually resolves it. Raising this is worth doing because a
/// reader who is on the wheel should not hit a wall; it does not make
/// the wheel the right instrument for a dense century.
/// 2026-09-15: 40 → 120, on 「另外zoom in应该可以有更大Zoom in 看更多
/// 细节」.
///
/// The paragraph above is still true and still the reason the strip
/// exists — magnifying a circle magnifies Methuselah along with Zimri
/// and pushes crowding off screen rather than resolving it. What
/// changed is that hitting a wall while the crowding is still visible
/// is worse than either. At 120x a single year spans about 6 px of
/// screen at 900 px, which is the point past which the wheel's own
/// angular resolution stops adding anything: `angleForSpan` is linear
/// in the year, so two events in the same year sit at the same bearing
/// at any magnification whatever, and no further zoom will separate
/// them. 120 is where the reader runs out of chart rather than out of
/// permission.
///
/// Label sizes use [wheelLabelScale]: type grows through the first 4x,
/// then holds at twice its resting size as more detail becomes visible.
const double kWheelMaxScale = 120;

// Wheel geometry as fractions of the square's side.
//   hub  .. bands   the stream bands, one ring each
//   bands .. rim    radial event labels
//   beyond rim      century years
const double _kHubFrac = 0.115;

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

/// The chronology's hues now live in `utils/chronology_palette.dart`.
///
/// They were moved there on 2026-09-15 so that they could take the
/// GROUND they are painted on as an input 「可以跟着变吧 dark ligjt
/// mode」. The arcs, the family assignment and the lightness zigzag are
/// unchanged and carry their original reasoning with them; what is new
/// is that every one of these entry points now demands a `dark`, so a
/// call site that has not thought about the ground does not compile.
///
/// Why `required` rather than a default: the failure a default hides is
/// invisible in the light mode the work is done in. It only shows up on
/// a reader's night screen, as a band at 2:1 against #0B1320.

/// The family's own colour, for the legend — the middle of its arc.
Color lineColor(String line, {required bool dark}) =>
    familyColor(line, dark: dark);

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
Color kingdomArcColor(Kingdom kingdom, {required bool dark}) =>
    switch (kingdom) {
      Kingdom.israel => bandColor('shem', 1, 1, dark: dark),
      // Saul, David and Solomon reigned over both houses; they are
      // drawn in Judah's shade because the throne they held is the one
      // Judah kept, not because the united monarchy was Judah.
      Kingdom.judah || Kingdom.united => bandColor('shem', 0, 0, dark: dark),
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
Color ministryArcColor({required bool dark}) =>
    lineColor('institution', dark: dark);

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
  return [for (final y in years) LineageCohort(year: y, people: byYear[y]!)];
}

/// The selection id a rail mark answers to. A year, not a person: the
/// mark stands for everybody in it.
const String kLineageArcPrefix = 'lineage:';

/// The genealogy rail's own shade: the no-descent grey, because a
/// conventional placement belongs to no claim the chart makes.
Color lineageRailColor({required bool dark}) => noDescentColor(dark: dark);

/// The tradition the arc band is drawn on. Top-level because
/// [packWheelBand] defaults to it and the tests read it.
///
/// The other one is printed on every sheet; see the class comment for
/// why it is not an axis toggle.
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
  // 2026-09-05: the Genesis lifespans are a LAYER, like the reigns and
  // the ministries, and turning one layer off must not take the other
  // two with it. Until this parameter existed the page's builder
  // returned early when the lifespan layer was hidden — before it had
  // even gathered the kings — so unchecking "Genesis lifespans" also
  // erased 42 reign arcs, 44 ministry arcs and the genealogy rail,
  // while all three of their checkboxes went on showing as ticked.
  // Defaulted true so every other caller is unchanged.
  bool includePatriarchs = true,
}) {
  final packed = buildLifeArcs(
    patriarchs: includePatriarchs ? chron.patriarchs : const [],
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
Color streamColor(String line, int index, int count, {required bool dark}) =>
    streamBandColor(line, index, count, dark: dark);

/// Strings this page owns. Kept local rather than appended to
/// ui_strings.dart because the unattended loop shares this checkout and
/// edits that file; fold these in on a quiet merge.
const Map<String, Map<String, String>> wheelStrings = {
  // ── the year cursor, shared by both forms ─────────────────────────
  //
  // The wheel and the strip draw the same corpus and now answer the
  // same question — "which year is this, and what happened in it" —
  // so they share one vocabulary for the answer. Splitting these into
  // two tables is how two views of one corpus start telling a reader
  // two different things about the same year.
  'chronoYearHappened': {
    'zh-Hans': '当年发生',
    'zh-Hant': '當年發生',
    'en': 'This year',
  },
  'chronoYearOngoing': {
    'zh-Hans': '正在进行',
    'zh-Hant': '正在進行',
    'en': 'Under way',
  },
  // A beginning and an end, as marks rather than words: they sit
  // INSIDE a chip beside a name, where a word would double its width.
  'chronoYearBegins': {'zh-Hans': '起', 'zh-Hant': '起', 'en': 'begins'},
  'chronoYearEnds': {'zh-Hans': '止', 'zh-Hant': '止', 'en': 'ends'},
  'chronoYearAlive': {
    'zh-Hans': '{n} 人在世',
    'zh-Hant': '{n} 人在世',
    'en': '{n} alive',
  },
  'chronoYearReigning': {
    'zh-Hans': '{n} 位在位',
    'zh-Hant': '{n} 位在位',
    'en': '{n} reigning',
  },
  'chronoYearUnderWay': {
    'zh-Hans': '{n} 项进行中',
    'zh-Hant': '{n} 項進行中',
    'en': '{n} under way',
  },
  // Said when the year holds nothing at all. NOT "nothing happened in
  // this year" — the corpus is a selection, and the chart may not
  // claim history was empty because its own asset is.
  'chronoYearNothing': {
    'zh-Hans': '本表未收录这一年',
    'zh-Hant': '本表未收錄這一年',
    'en': 'nothing dated here',
  },
  'chronoYearEmpty': {
    'zh-Hans': '本表没有记录定在这一年。',
    'zh-Hant': '本表沒有記錄定在這一年。',
    'en': 'No record in this chart is dated to this year.',
  },
  'chronoYearClear': {
    'zh-Hans': '清除年份线',
    'zh-Hant': '清除年份線',
    'en': 'Clear the year line',
  },
  'chronoYearExpand': {'zh-Hans': '展开', 'zh-Hant': '展開', 'en': 'More'},
  'chronoYearCollapse': {'zh-Hans': '收起', 'zh-Hant': '收起', 'en': 'Less'},
  'chronoYearHint': {
    'zh-Hans': '点一下图表，读出那一年',
    'zh-Hant': '點一下圖表，讀出那一年',
    'en': 'Tap the chart to read off a year',
  },
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
    'zh-Hans': '事奉',
    'zh-Hant': '事奉',
    'en': 'ministry',
  },
  'wheelRegionEgypt': {'zh-Hans': '埃及', 'zh-Hant': '埃及', 'en': 'Egypt'},
  'wheelRegionMesopotamia': {
    'zh-Hans': '美索不达米亚',
    'zh-Hant': '美索不達米亞',
    'en': 'Mesopotamia',
  },
  'wheelRegionAnatolia': {
    'zh-Hans': '安纳托利亚',
    'zh-Hant': '安納托利亞',
    'en': 'Anatolia',
  },
  'wheelRegionLevant': {
    'zh-Hans': '黎凡特',
    'zh-Hant': '黎凡特',
    'en': 'The Levant',
  },
  'wheelRegionPersia': {'zh-Hans': '波斯', 'zh-Hant': '波斯', 'en': 'Persia'},
  'wheelRegionGreece': {'zh-Hans': '希腊', 'zh-Hant': '希臘', 'en': 'Greece'},
  'wheelRegionRome': {'zh-Hans': '罗马', 'zh-Hant': '羅馬', 'en': 'Rome'},
  'wheelRegionIslamic': {
    'zh-Hans': '伊斯兰世界',
    'zh-Hant': '伊斯蘭世界',
    'en': 'The Islamic world',
  },
  'wheelRegionEurope': {'zh-Hans': '欧洲', 'zh-Hant': '歐洲', 'en': 'Europe'},
  'wheelRegionAsia': {'zh-Hans': '亚洲', 'zh-Hant': '亞洲', 'en': 'Asia'},
  'wheelRegionAmericas': {
    'zh-Hans': '美洲',
    'zh-Hant': '美洲',
    'en': 'The Americas',
  },
  'wheelRegionModern': {
    'zh-Hans': '现代世界',
    'zh-Hant': '現代世界',
    'en': 'The modern world',
  },
  'wheelRefs': {
    'zh-Hans': '经文出处',
    'zh-Hant': '經文出處',
    'en': 'References',
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
    'zh-Hans': '{n} 位',
    'zh-Hant': '{n} 位',
    'en': '{n} people',
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
    'zh-Hans': '关于本图',
    'zh-Hant': '關於本圖',
    'en': 'About this chart',
  },
  'wheelAboutProvenance': {
    'zh-Hans': '年份的来源',
    'zh-Hant': '年份的來源',
    'en': 'Where the dates come from',
  },
  'wheelAboutCoverage': {
    'zh-Hans': '本图收录什么',
    'zh-Hant': '本圖收錄什麼',
    'en': 'What is on the chart',
  },
  'wheelAboutScope': {
    'zh-Hans': '民族表止于何处',
    'zh-Hant': '民族表止於何處',
    'en': 'Where the table of nations stops',
  },
  'wheelAboutAxis': {
    'zh-Hans': '年代轴止于何处',
    'zh-Hant': '年代軸止於何處',
    'en': 'Where the axis stops',
  },
  // The hub's two lines, 2026-09-15. The hub used to repeat the page
  // title, which the AppBar already carries two rows above it.
  'wheelHubCovers': {
    'zh-Hans': '本图涵盖',
    'zh-Hant': '本圖涵蓋',
    'en': 'this chart covers',
  },
  'wheelHubYear': {
    'zh-Hans': '点中的年份',
    'zh-Hant': '點中的年份',
    'en': 'the year you tapped',
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
  // 2026-09-16 「还有这个strip或者wheel应该有一个max screen把这个全屏模式」
  'wheelFullScreen': {
    'zh-Hans': '全屏',
    'zh-Hant': '全螢幕',
    'en': 'Full screen',
  },
  'wheelExitFullScreen': {
    'zh-Hans': '退出全屏',
    'zh-Hant': '退出全螢幕',
    'en': 'Exit full screen',
  },
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
    'zh-Hans': '这组包含多项事件。点按任一事件可查看详情。',
    'zh-Hant': '這組包含多項事件。點按任一事件可查看詳情。',
    'en': 'This group contains several events. Tap an event for its details.',
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
  // 2026-09-15. Deliberately not 「通行年份」: for 黃帝, 夏朝 and 檀君
  // there is no conventional date to be had, only a tradition, and the
  // note beneath names the text it comes from — 《史記·五帝本紀》,
  // 《竹書紀年》, 《三國遺事》.
  'wheelBasisTraditional': {
    'zh-Hans': '传说纪年 · 非信史',
    'zh-Hant': '傳說紀年 · 非信史',
    'en': 'traditional date, not established history',
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
/// The wheel's canvas type, at the reader's default scale.
///
/// 2026-09-15: 10.5 → 12.5, and every call site below now takes a
/// floor. 「字体感觉太小不是很responsive」, and both halves of that were
/// true. `WbType.scaledChrome` multiplies and does not clamp, so a
/// reader whose Menu Size sits below the default was getting 8.4 px of
/// canvas text — under this app's own [WbMetrics.smallPrintFloor],
/// which every other small label in the app is held to. The wheel was
/// simply not asking for the floor.
///
/// The extra two points are affordable now for a reason that is part of
/// the same change: with the ring count capped and the disc given a
/// margin, there is somewhere for larger type to go.
const double _kLabelPx = 12.5;

/// The wheel's canvas type on the reader's scale, never under the
/// app's own small-print floor.
double _wheelFont(WbType t, double atDefault) =>
    math.max(t.scaledChrome(atDefault), WbMetrics.smallPrintFloor);

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
double _measureLabel(String text, double size) =>
    WheelTextMetrics.shapedWidth(text, canvasTextStyle(fontSize: size));

/// Curved labels measure the same individual graphemes they paint.
/// Sharing this cache with the painter removes the duplicate layout
/// pass that remained after glyph painting was first cached.
double _measureChars(String text, double size) =>
    WheelTextMetrics.runWidth(text, canvasTextStyle(fontSize: size));

double _labelScale(double zoom) => wheelLabelScale(zoom);

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

/// A power's arc on its band, and — the same treatment
/// [_RadialChronologyPageState._buildLifespans] gives the lives — the
/// stretch of its own name the band can honestly carry.
///
/// [name] is empty when no legible placement was found for this power at
/// this size, exactly the rule the rim and the lifespans already live by:
/// the arc keeps its colour and its tap target, and loses only its word.
/// See [_RadialChronologyPageState._buildArcs] for how [name]/[nameA0]/
/// [nameSweep]/[nameSize] are decided.
/// WHO IS UNDER A POINT, AND WHAT OPENING THEM DOES.
///
/// 2026-09-17 「when hovering over the line or strip can you have
/// hovering pop up label or something and when click then pop up
/// window?」. The hover label and the tap MUST answer with the same
/// record or the feature is worse than not having it: a name that
/// floats up for one band while the click underneath opens another is
/// a chart that lies about itself.
///
/// So there is one resolver — [_RadialChronologyPageState._resolveAt] —
/// and it returns this instead of acting. The tap calls [open]; the
/// hover reads [label] and calls nothing. Neither can drift from the
/// other, because there is nothing to keep in step.
///
/// [label] is the record's OWN name, never the name as drawn: the arc
/// and the spoke both carry a display string that is empty exactly when
/// there was no room to print it, which is exactly when a reader needs
/// to hover. That is the 亚们 defect (see [_Life.fullName]) and it is
/// the reason this hands back `fullName` and `event.titleFor`.
typedef _WheelHit = ({
  String id,
  String label,
  void Function() open,

  /// THE REGION THIS ANSWER IS A CLAIM ABOUT, in canvas polar
  /// coordinates, so the reader can be shown it.
  ///
  /// 2026-09-17. A resolver answer is a claim about a region, and at
  /// 4050% a band is three hundred pixels deep and thousands long, with
  /// its name painted once somewhere along it. A word beside the cursor
  /// is feedback about IDENTITY; identity with no visible extent cannot
  /// be checked, so a correct answer and a wrong one look the same to
  /// the reader. Drawing the claimed shape is the only honest feedback
  /// for a claim about a shape — and it is the same four numbers the
  /// accuracy probe already needed, so the plate, the outline and the
  /// tap all consume ONE result and cannot disagree.
  _HitShape shape,
});

/// The region a [_WheelHit] claims: an annular sector, in canvas units.
typedef _HitShape = ({double a0, double a1, double centre, double halfDepth});

class _Arc {
  const _Arc(
    this.power,
    this.ring,
    this.a0,
    this.a1,
    this.color, {
    this.tier = 0,
    this.tiers = 1,
    this.name = '',
    this.nameA0 = 0,
    this.nameSweep = 0,
    this.nameSize = 0,
  });
  final WheelPower power;
  final int ring;
  final double a0;
  final double a1;
  final Color color;

  /// Which layer of its stream's ring this arc sits in, and how many
  /// layers that ring was divided into.
  ///
  /// 2026-09-16 「一个圈圈 但是那个每个条可以细一些多层这样 ... 这样就知道
  /// 同一时代同时发生事情」. One ring per stream, and the powers that ran
  /// AT THE SAME TIME stacked inside it instead of sharing a radius and
  /// printing over each other. [tiers] is 1 wherever the ring is too
  /// thin to divide — see [streamTierCount], which asks per chart.
  final int tier;
  final int tiers;

  final String name;
  final double nameA0;
  final double nameSweep;
  final double nameSize;
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
    required this.fullName,
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

  /// THE RECORD'S OWN NAME, whether or not [name] could carry it.
  ///
  /// 2026-09-16 「亚们还是没有解决」. The callout beside a record too
  /// narrow to hold its own name was written to read [name] — which is
  /// the name AS DRAWN ALONG THE ARC, and is set only when the planner
  /// found room for it. So the branch that exists for the records with
  /// no room was guarded on the one field that is empty exactly then:
  /// dead code from the day it was written, and 亚们 (主前643-641, with
  /// 玛拿西 one side and 约西亚 the other) was never so much as asked
  /// for a label. This field is what the record is called; [name] stays
  /// what the arc can print.
  final String fullName;
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

/// A scene survives cursor moves and widget rebuilds. Only a change to
/// its geometry, content, locale or label size repeats the fitting work.
class _WheelScene {
  const _WheelScene(
      this.streams, this.colors, this.arcs, this.spokes, this.lives, this.rail);

  final List<WheelStream> streams;
  final Map<String, Color> colors;
  final List<_Arc> arcs;
  final List<_Spoke> spokes;
  final List<_Life> lives;
  final List<_Rail> rail;
}

class _RadialChronologyPageState extends State<RadialChronologyPage>
    with WheelSheets<RadialChronologyPage> {
  Future<WheelHistoryData>? _future;
  final _viewer = TransformationController();
  final _explorer = ChronologyExplorerController();
  late bool _stacked;
  int _stackRevealRevision = 0;
  ChronologyDepthCamera? _depthCamera;
  ChronologyDepthCamera? _enterDepthCamera;
  ChronologyDepthCamera? _enterFlatCamera;
  double _depthYaw = 0;
  double _depthTilt = .70;
  double _depthLift = 4;
  Object? _stackGroupsKey;
  List<StackedChronologyGroup> _stackGroups = const [];

  /// Which ground the chart is being painted on, read once per build.
  ///
  /// A field rather than a lookup at each call site because the scene
  /// and the stack groups are CACHED, and a cache keyed on everything
  /// except the ground is how a reader who switches to dark mode keeps
  /// the light palette until something else happens to invalidate it.
  /// Both cache keys below carry this value for that reason.
  bool _dark = false;

  /// Streams the reader has switched off.
  ///
  /// 2026-09-15: this is no longer empty on arrival. 「一开始filter不要
  /// 全部都有 这样loading很慢」 — and the geometry agrees, because a ring
  /// has to remain distinguishable and a 360 px phone's annulus gives
  /// four streams 13.95 px each, rather than twenty-two thin shares. [_applyDefaultHidden] fills it
  /// once, the first time the page knows how big it is; after that it is
  /// the reader's.
  final Set<String> _hidden = {};

  /// Whether the viewport-sized default has been applied. One-shot: a
  /// rotation or a window resize must not silently switch the reader's
  /// own choices back on.
  bool _defaultsApplied = false;

  /// Fill [_hidden] with everything the wheel has no room for.
  void _applyDefaultHidden(WheelHistoryData data, Set<String>? kept,
      double side) {
    if (_defaultsApplied) return;
    _defaultsApplied = true;
    // WHAT THE READER CHOSE BEATS WHAT THE CHART OPENS WITH. An empty
    // set is a choice — every lane on — and is not the same as never
    // having opened Filter, which is why this is nullable.
    if (kept != null) {
      _hidden
        ..clear()
        ..addAll(kept);
      return;
    }
    // Two bounds, and the smaller wins. The geometry says how many
    // rings this canvas can draw at a readable thickness; the opening
    // count says how many the reader should meet, which is four on
    // every canvas so that the fifth slot is always free for the
    // comparison they came to make.
    // The opening set is the owner's, not the geometry's — see
    // [openingStreamCount]. On a 390 dp phone `ringCapacity` is four,
    // which is how 全世界 came to be missing from a chart that is
    // supposed to open with it.
    final capacity = openingStreamCount(side,
        hubFraction: _kHubFrac, bandsFraction: bandsFractionFor(side));
    final keep =
        defaultVisibleStreams(data.streams.map((s) => s.id), capacity).toSet();
    for (final s in data.streams) {
      if (!keep.contains(s.id)) _hidden.add(s.id);
    }
  }

  /// The chart with the page's own chrome built away.
  ///
  /// 2026-09-16 「还有这个strip或者wheel应该有一个max screen把这个全屏
  /// 模式」 — see [ChronologyExplorer.fullScreen].
  bool _fullScreen = false;

  String? _selectedId;

  /// WHAT THE POINTER IS OVER, for the floating name. Null on every
  /// touch device, which has no hover and loses nothing: this exists
  /// because a mouse can ask a question without committing to it, and
  /// at the zoom levels these bands are read at, most of them are too
  /// thin to carry their own name.
  ///
  /// [at] is in the OUTER viewport's coordinates, not the wheel's. The
  /// wheel lives inside an InteractiveViewer, so a plate positioned in
  /// its space would be scaled by the zoom with it — 36x at the zoom
  /// the owner reported this from.
  ({Offset at, String label, String year, _HitShape? shape})? _hover;

  /// The outer Stack, so a global pointer position can be turned into
  /// that Stack's own coordinates whatever the viewer has done to the
  /// wheel underneath.
  final GlobalKey _viewportKey = GlobalKey();

  int? _rangeStart;
  int? _rangeEnd;
  Object? _sceneKey;
  _WheelScene? _scene;

  _WheelScene _sceneFor(
      WheelHistoryData data, double side, String locale, double labelSize) {
    final hiddenKey = (_hidden.toList()..sort()).join(',');
    final key = (
      data,
      side,
      locale,
      labelSize,
      _zoom,
      // The ground. Every arc, life and spoke in this scene carries a
      // colour chosen for it, so a scene built on paper is wrong at
      // night even though nothing else about it changed.
      _dark,
      hiddenKey,
      _selectedId,
      ChronologyService.instance.cached,
      HebrewKingsService.instance.cached,
      FamilyTreeService.instance.cached,
    );
    if (_sceneKey == key && _scene != null) return _scene!;
    final streams = _visible(data);
    final ringOf = {for (var i = 0; i < streams.length; i++) streams[i].id: i};
    final colors = colorsFor(data, dark: _dark);
    final rHub = side * _kHubFrac;
    final rBands = side * bandsFractionFor(side);
    final rRim = side * rimFractionFor(side);
    final arcs = _buildArcs(
        data, ringOf, colors, streams.length, rHub, rBands, locale, labelSize);
    final spokes =
        _buildSpokes(data, ringOf, rBands, rRim, colors, locale, labelSize);
    final lives = _buildLifespans(rBands, rRim, spokes, locale, labelSize);
    final rail = _buildRail(rBands, rRim, lives);
    _sceneKey = key;
    WheelRenderStats.sceneBuilds++;
    return _scene = _WheelScene(streams, colors, arcs, spokes, lives, rail);
  }

  void _showRange(int start, int end) {
    final full = start <= kMinYear && end >= kMaxYear;
    setState(() {
      _rangeStart = full ? null : start.clamp(kMinYear, kMaxYear);
      _rangeEnd = full ? null : end.clamp(kMinYear, kMaxYear);
      _cursorYear = full ? null : ((start + end) / 2).round();
      _selectedId = null;
    });
    // A period is a sector of the overview. Keep the entire wheel in
    // view so the coloured sector answers where the period belongs;
    // its readable event list is beside the chart, at the same scale.
    if (!_stacked) _resetViewMatrix();
  }

  void _openExplorerEvent(BuildContext context, WheelHistoryEvent event,
      WheelHistoryData data, String locale) {
    _placeCursor(event.year);
    _reveal(
        context,
        WheelHit(
          kind: WheelHitKind.event,
          via: WheelHitVia.title,
          id: event.id,
          streamId: event.stream,
          title: event.titleFor(locale),
          year: event.year,
          matched: '',
          rank: 0,
          streamHidden: _hidden.contains(event.stream),
        ),
        data,
        locale);
  }

  /// The viewer's current scale.
  ///
  /// InteractiveViewer magnifies the whole canvas. Label sizing uses
  /// wheelLabelScale so the first 4x can enlarge type, while higher zoom
  /// reveals more detail without continuing to enlarge the letters.
  double _zoom = 1;

  @override
  void initState() {
    super.initState();
    _stacked = widget.initialStacked;
    if (widget.initialPeriod case final period?) {
      _explorer.selectPeriod(period);
      if (period.start > kMinYear || period.end < kMaxYear) {
        _rangeStart = period.start;
        _rangeEnd = period.end;
        _cursorYear = ((period.start + period.end) / 2).round();
      }
    }
    if (widget.initialHiddenStreams case final hidden?) {
      _hidden.addAll(hidden);
      _defaultsApplied = true;
    }

    _future = WheelHistoryService.instance.load();
    // Fire and forget, and repaint if it lands after the first frame.
    // The chart is complete without the symbols — they are an aid to
    // reading it, not part of the claim it makes — so nothing waits on
    // this and a failure here costs a decoration, not a page.
    if (ChartSymbolService.instance.cached.isEmpty) {
      ChartSymbolService.instance.load().then((_) {
        if (mounted) setState(() {});
      });
    }
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

  void _setDepth(bool depth) {
    if (depth == _stacked) return;
    if (depth) {
      final size = _viewportSize;
      if (size != null && _side > 0) {
        final m = _viewer.value;
        _enterDepthCamera = ChronologyDepthCamera.fromProjection(
          projection:
              WheelStackProjection(centre: size.center(Offset.zero), squash: 1),
          groundRadius: _side * rimFractionFor(_side),
          viewport: Offset.zero & size,
          scale: m.getMaxScaleOnAxis(),
          translation: Offset(m.storage[12], m.storage[13]),
        );
      }
    } else {
      _enterFlatCamera = _depthCamera ?? const ChronologyDepthCamera();
    }
    setState(() => _stacked = depth);
  }

  void _restoreFlatCamera(Size size, double radius) {
    final camera = _enterFlatCamera;
    if (camera == null) return;
    _enterFlatCamera = null;
    final transform = camera.toProjection(
      projection:
          WheelStackProjection(centre: size.center(Offset.zero), squash: 1),
      groundRadius: radius,
      viewport: Offset.zero & size,
    );
    // InteractiveViewer is laid out before restoring its transform. Its
    // centre may change because 3D reserves a second row of camera controls.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _stacked) return;
      _viewer.value = Matrix4.identity()
        ..translateByDouble(
            transform.translation.dx, transform.translation.dy, 0, 1)
        ..scaleByDouble(transform.scale, transform.scale, transform.scale, 1);
    });
  }

  /// Run [go] only if the pointer that just lifted never travelled.
  ///
  /// The `Listener` this serves is deliberately NOT a `GestureDetector`
  /// with `onTapDown`: a `TapGestureRecognizer` fires `onTapDown` when
  /// it wins the arena or when 100 ms elapse, so on the sibling chart a
  /// quick tap did nothing while press-and-hold worked, and no widget
  /// test could see the difference (`tapAt` sends down and up with
  /// nothing between). A `Listener` is not in the arena, so the wheel's
  /// own tap handler and the year cursor both get the press: tapping an
  /// event opens its sheet AND lands the cursor on its year.
  ///
  /// The slop is measured in global coordinates — the frame the
  /// question "did the finger travel" is actually about, and the one
  /// that survives whatever the `InteractiveViewer` has done to the
  /// transform in between.
  void _commitPress(PointerUpEvent e, VoidCallback go) {
    final origin = _pressOrigin;
    _pressOrigin = null;
    if (origin == null) return;
    if ((e.position - origin).distance > kTouchSlop) return;
    go();
  }

  /// The year at a point on the square canvas, or null if the point is
  /// outside the 320-degree sweep.
  ///
  /// The inverse of [angleForSpan] and nothing else — no radius term,
  /// because on this wheel radius is the LAYER and angle alone is the
  /// year. That is the claim the chart makes, so a cursor placed on the
  /// hub and one placed on the rim at the same angle name the same
  /// year, which is exactly right.
  int? _yearAt(Offset local, double side) {
    final c = side / 2;
    var a = math.atan2(local.dy - c, local.dx - c);
    while (a < startRad) {
      a += 2 * math.pi;
    }
    if (a - startRad > sweepRad) return null;
    final t = (a - startRad) / sweepRad;
    return (kMinYear + t * (kMaxYear - kMinYear)).round();
  }

  /// Put the cursor on a year without moving the view. Ported from the
  /// strip's own `_placeCursor`, for the same reason: moving the wheel
  /// out from under the thing the reader just pointed at is how a
  /// crosshair becomes unusable.
  void _placeCursor(int year) =>
      setState(() => _cursorYear = year.clamp(kMinYear, kMaxYear));

  /// The lanes behind the year readout, rebuilt when the filter changes
  /// and not otherwise — see [_digestLanes].
  List<StripLane> _lanesFor(WheelHistoryData data) {
    final key = (_hidden.toList()..sort()).join(',');
    final cached = _digestLanes;
    if (cached != null && _digestLanesKey == key) return cached;
    final creation = creationYear;
    // The digest describes the visible chart. Its old unfiltered input
    // still listed Japan and the Americas while those rings were off.
    // Match the strip's _visibleInputs: streams own powers and events,
    // while ministries have their own switch, independent of streams.
    // Detail sheets keep the original corpus and all its provenance.
    final visible = _hidden.isEmpty
        ? data
        : WheelHistoryData(
            streams:
                data.streams.where((s) => !_hidden.contains(s.id)).toList(),
            nations: data.nations,
            powers:
                data.powers.where((p) => !_hidden.contains(p.stream)).toList(),
            ministries:
                _hidden.contains(kMinistryLayerId) ? const [] : data.ministries,
            omissions: data.omissions,
            events:
                data.events.where((e) => !_hidden.contains(e.stream)).toList(),
            meta: data.meta,
          );
    final lanes = buildStripLanes(
      wheel: visible,
      kings: _hidden.contains(kReignLayerId)
          ? const <HebrewKing>[]
          : (HebrewKingsService.instance.cached?.kings ?? const <HebrewKing>[]),
      // The wheel's own honest fallback: with no creation anchor the
      // lifespans are not drawn, so they must not be counted either.
      patriarchs: (_hidden.contains(kLifespanLayerId) || creation == null)
          ? const <Patriarch>[]
          : (ChronologyService.instance.cached?.patriarchs ?? const []),
      familyTreePeople: _hidden.contains(kLineageLayerId)
          ? const <BiblicalPerson>[]
          : (FamilyTreeService.instance.cached ?? const <BiblicalPerson>[]),
      tradition: kDrawnTradition,
      creationYear: creation ?? 0,
      // The densest step on the ladder, so the packer merges nothing:
      // this list is read for its RECORDS, never painted, and a digest
      // that dropped a record because two of them would have collided
      // at some pixel width would be answering a question nobody asked.
      pxPerYear: kStripZoomSteps.last,
    );
    _digestLanes = lanes;
    _digestLanesKey = key;
    return lanes;
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
    final applied = (z * factor).clamp(0.8, kWheelMaxScale) / z;
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

  /// The year the cursor rests on, or null before the reader has put it
  /// anywhere — the wheel's half of the answer to 「没有线根本不知道
  /// 哪一年」. On a wheel the line is a SPOKE: year is angle here, so
  /// the rule that means "this year" runs hub to rim, not top to
  /// bottom.
  int? _cursorYear;

  /// Where the current press started, in global coordinates. See
  /// [_commitPress] and the `Listener` in [_body] for why the cursor
  /// commits on UP rather than DOWN.
  Offset? _pressOrigin;

  /// The strip's lanes, built once per corpus and kept only to answer
  /// "what happened in this year".
  ///
  /// The wheel has no lanes of its own, and it does not need them to
  /// PAINT — it needs them so that the year readout it shows and the
  /// year readout the strip shows are the same list. `buildStripLanes`
  /// is a pure function of a corpus this page already holds, so the
  /// alternative was a second traversal of events, reigns, lifespans
  /// and bands written against the same records — which is how the two
  /// forms would start disagreeing about a year.
  List<StripLane>? _digestLanes;
  String? _digestLanesKey;

  /// The side of the square canvas at the last layout — what turns a
  /// year into a point search can pan to.
  double _side = 0;

  void _resetViewMatrix() => _viewer.value = Matrix4.identity();

  void _resetZoom() => _explorer.showAll();

  @override
  void dispose() {
    UrlSyncService.claimUrl(null, owner: this);
    _viewer.removeListener(_onZoom);
    _viewer.dispose();
    _explorer.dispose();
    _findCtl.dispose();
    super.dispose();
  }

  void _select(String? id) => setState(() => _selectedId = id);

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    final wb = WbColors.of(context);
    // The ground, read once and remembered, because the scene and the
    // palette below are cached: a cache keyed on everything EXCEPT the
    // ground is how a reader who switches to dark mode keeps the light
    // palette until something unrelated happens to invalidate it.
    _dark = wb.isDark;

    return Scaffold(
      backgroundColor: wb.paneBg,
      appBar: _fullScreen
          ? null
          : AppBar(
        leading: const LocalizedBackButton(),
        title: wheelChromeTitle(
            context,
            s('wheelTitle', 'World History Wheel', locale),
            MediaQuery.sizeOf(context).width),
        titleSpacing: wheelChromeTitleSpacing(MediaQuery.sizeOf(context).width),
        // Six actions plus the back button used to be typed out here
        // unconditionally, and measured on the real page at 375 px —
        // reachable at any width since `#/wheel` stopped being gated by
        // `SmallScreenGate` on 2026-09-03 — the title above renders at
        // 0.0 px wide: `AppBar` gives it a `Flexible` and the six
        // actions spent the whole toolbar before the title got a
        // pixel. `wheelChromeActions` (`widgets/wheel_chrome_bar.dart`)
        // folds Find/Filter/About into one sheet below
        // `kWheelNarrowPaneWidth` and keeps the view-switch itself
        // direct — see that file's doc for the full reasoning, and
        // `strip_chronology_page.dart`'s own AppBar for why this is a
        // shared function and not a second copy of the same decision.
        actions: wheelChromeActions(
          context: context,
          locale: locale,
          paneWidth: MediaQuery.sizeOf(context).width,
          s: (key, fallback) => s(key, fallback, locale),
          onFind: () => _showSearch(context, locale),
          onFilter: () => _showFilter(context, locale),
          onAbout: () => _showAbout(context, locale),
          // The wheel and the strip are one chart in two forms, so this
          // is a SWITCH between the two rather than a second "open the
          // strip" button — tapping the already-selected 'wheel'
          // segment is a no-op. `stripStrings` (not `wheelStrings`)
          // because the two option labels belong with the control's own
          // name (`stripViewSwitch`), which the strip's own AppBar
          // reads too.
          viewSwitch: wheelViewSwitch(
            locale: locale,
            narrow: MediaQuery.sizeOf(context).width < kWheelNarrowPaneWidth,
            ss: (key, fallback) => stripStrings[key]?[locale] ?? fallback,
            selected: const {'wheel'},
            onSelectionChanged: (selected) {
              if (selected.first != 'strip') return;
              context.read<AppSettings>().setChronologyView('strip');
              // The strip is the RIGHT segment, so the page arrives
              // from the right. See `chartFormRoute`.
              Navigator.of(context).pushReplacement(chartFormRoute<void>(
                toRight: true,
                builder: (_) => StripChronologyPage(
                  initialPeriod: _explorer.period,
                  initialStacked: _stacked,
                  initialHiddenStreams: Set.unmodifiable(_hidden),
                ),
              ));
            },
          ),
        ),
      ),
      body: FutureBuilder<WheelHistoryData>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${snap.error}',
                    style: TextStyle(color: wb.mutedText)),
              ),
            );
          }
          final data = snap.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return LayoutBuilder(builder: (context, box) {
            final available =
                chronologyExplorerChartSize(Size(box.maxWidth, box.maxHeight));
            // Apply defaults before either the explorer or the scene
            // reads them. The old post-frame callback first built all
            // streams, then built the intended four-stream phone view.
            // YearDigestBar's collapsed height: 6 px padding, a 24 px
            // header, 16 px scrubber, 30 px chip lane and a 1 px border.
            // Keep the estimate on the same body scale and safe inset;
            // the page test compares it with the rendered bar.
            final digestHeight = WbType.of(context).scaled(76) +
                1 +
                MediaQuery.viewPaddingOf(context).bottom;
            final side = math.min(
                available.width,
                math.max(
                    0.0,
                    available.height -
                        digestHeight -
                        48 -
                        wheelControlsFooterHeight));
            _applyDefaultHidden(
                data, context.read<AppSettings>().chronologyHiddenStreams, side);
            return ChronologyExplorer(
              controller: _explorer,
              fullScreen: _fullScreen,
              // The two halves of the screen tell the same time.
              // 2026-09-17 「这两边是不是时间需要一致」.
              focusYear: _cursorYear,
              chart: _body(context, data, locale),
              data: data,
              locale: locale,
              hiddenStreams: _hidden,
              streamColors: colorsFor(data, dark: _dark),
              selectedId: _selectedId,
              onEvent: (event) =>
                  _openExplorerEvent(context, event, data, locale),
              onRange: _showRange,
              onFind: () => _showSearch(context, locale),
              onFilter: () => _showFilter(context, locale),
            );
          });
        },
      ),
    );
  }

  /// The bands actually drawn, outermost first. A hidden stream is
  /// dropped entirely rather than left as a gap, so switching one off
  /// gives the rest more room instead of leaving a hole.
  List<WheelStream> _visible(WheelHistoryData d) =>
      d.streams.where((s) => !_hidden.contains(s.id)).toList();

  List<StackedChronologyGroup> _stackGroupsFor(
      WheelHistoryData data, String locale) {
    final lanes = _lanesFor(data);
    final key = (lanes, locale, _dark);
    if (_stackGroupsKey == key) return _stackGroups;
    _stackGroupsKey = key;
    final colors = colorsFor(data, dark: _dark);
    final grouped = <String, List<YearDigestItem>>{};
    for (final lane in lanes) {
      final id = switch (lane.kind) {
        StripLaneKind.stream => lane.ownerId!,
        StripLaneKind.lives => kLifespanLayerId,
        StripLaneKind.kings => kReignLayerId,
        StripLaneKind.ministries => kMinistryLayerId,
        StripLaneKind.rail => kLineageLayerId,
        StripLaneKind.events => 'events',
        _ => null,
      };
      if (id == null) continue;
      final records = grouped.putIfAbsent(id, () => []);
      for (final span in lane.spans) {
        records.add(YearDigestItem(
            id: span.id,
            kind: span.kind,
            moment: YearMoment.ongoing,
            startYear: span.startYear,
            endYear: span.endYear,
            line: span.line,
            openEnded: span.ongoing));
      }
    }
    final names = {
      for (final stream in _visible(data)) stream.id: stream.nameFor(locale),
      kLifespanLayerId: s('wheelLifespans', 'Genesis lifespans', locale),
      kReignLayerId: s('wheelReigns', 'Kings of Israel & Judah', locale),
      kMinistryLayerId: s('wheelMinistries', 'Ministries', locale),
      kLineageLayerId: s('wheelLineage', 'Genealogy', locale),
      'events': s('wheelEvents', 'Events', locale),
    };
    colors.addAll({
      kLifespanLayerId: lineColor('shem', dark: _dark),
      kReignLayerId: kingdomArcColor(Kingdom.judah, dark: _dark),
      kMinistryLayerId: ministryArcColor(dark: _dark),
      kLineageLayerId: lineageRailColor(dark: _dark),
      'events': const Color(0xFFA64E72),
    });
    return _stackGroups = [
      for (final id in names.keys)
        if ((grouped[id]?.isNotEmpty ?? false) ||
            _visible(data).any((stream) => stream.id == id))
          StackedChronologyGroup(
              id: id,
              name: names[id]!,
              color: colors[id]!,
              records: grouped[id] ?? const [],
              outerLane: !_visible(data).any((stream) => stream.id == id),
              symbol: id == 'egypt'
                  ? 5
                  : id == 'china' || id == 'world'
                      ? 3
                      : id == 'rome' || id == 'church'
                          ? 2
                          : id == kLifespanLayerId || id == kLineageLayerId
                              ? 4
                              : id == kMinistryLayerId || id == 'scripture'
                                  ? 0
                                  : 1),
    ];
  }

  Widget _yearDigest(
          BuildContext context, WheelHistoryData data, String locale) =>
      YearDigestBar(
        digest: _cursorYear == null
            ? null
            : buildYearDigest(year: _cursorYear!, lanes: _lanesFor(data)),
        yearText: _cursorYear == null ? '' : yearLabel(_cursorYear!, locale),
        hint: s('chronoYearHint', 'Tap the chart to read off a year', locale),
        label: (item) => digestLabel(
            item,
            data,
            HebrewKingsService.instance.cached?.kings ?? const <HebrewKing>[],
            ChronologyService.instance.cached?.patriarchs ??
                const <Patriarch>[],
            locale),
        onOpen: (item) {
          // The year scrubber spans the full axis. Its chosen record can
          // therefore lie outside the current event-browser period.
          // Synchronize the actual projected range before selecting it.
          final period = _explorer.period;
          if (item.endYear < period.start || item.startYear > period.end) {
            _explorer.selectPeriod(chronologyPeriods.skip(1).firstWhere(
                (period) => period.contains(item.startYear),
                orElse: () => chronologyPeriods.first));
          }
          _stackRevealRevision++;
          _openChartRecord(context, item, data, locale);
        },
        onClear: () => setState(() => _cursorYear = null),
        s: (key, fallback) => s(key, fallback, locale),
        fill: (key, fallback, values) => fill(key, fallback, locale, values),
        onYear: _scrubToYear,
        minYear: kMinYear,
        maxYear: kMaxYear,
      );

  void _openChartRecord(BuildContext context, YearDigestItem item,
      WheelHistoryData data, String locale) {
    final kings =
        HebrewKingsService.instance.cached?.kings ?? const <HebrewKing>[];
    final patriarchs =
        ChronologyService.instance.cached?.patriarchs ?? const <Patriarch>[];
    _placeCursor(item.startYear);
    if (item.kind == StripLaneKind.rail) {
      final people =
          FamilyTreeService.instance.cached ?? const <BiblicalPerson>[];
      // Both chart forms and the digest open the same visible cohort.
      // A person named in a hidden layer must still be recoverable here.
      final drawn = <String>{
        if (!_hidden.contains(kLifespanLayerId) && creationYear != null)
          for (final p in patriarchs) p.id,
        if (!_hidden.contains(kReignLayerId))
          for (final k in kings) k.id,
        for (final event in data.events)
          if (!_hidden.contains(event.stream))
            for (final person in event.people) person.id,
      };
      final cohort = find(stripLineageCohorts(people: people, drawnIds: drawn),
          (c) => c.year == item.startYear);
      if (cohort != null) {
        _select(item.id);
        showCohort(context,
            LineageCohort(year: cohort.year, people: cohort.people), locale);
      }
    } else {
      openDigestRecord(context, item, data, kings, patriarchs, locale, _select);
    }
  }

  Widget _body(BuildContext context, WheelHistoryData data, String locale) =>
      Column(children: [
        SizedBox(
            height: 48,
            child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: kDepthViewOffered
                      ? ChronologyDepthToggle(
                          is3D: _stacked,
                          onChanged: _setDepth,
                          locale: locale,
                          keyPrefix: 'wheelDepth')
                      : const SizedBox.shrink(),
                ))),
        Expanded(child: _chartBody(context, data, locale)),
        _yearDigest(context, data, locale),
      ]);

  Widget _chartBody(
      BuildContext context, WheelHistoryData data, String locale) {
    if (_stacked) {
      final kings =
          HebrewKingsService.instance.cached?.kings ?? const <HebrewKing>[];
      final patriarchs =
          ChronologyService.instance.cached?.patriarchs ?? const <Patriarch>[];
      return StackedChronologyWheel(
        controller: _viewer,
        initialCamera: _enterDepthCamera,
        onCameraChanged: (camera) => _depthCamera = camera,
        onYear: _scrubToYear,
        initialYaw: _depthYaw,
        cursorYear: _cursorYear,
        initialTilt: _depthTilt,
        initialLift: _depthLift,
        onLiftChanged: (lift) => _depthLift = lift,
        onAnglesChanged: (yaw, tilt) {
          _depthYaw = yaw;
          _depthTilt = tilt;
        },
        groups: _stackGroupsFor(data, locale),
        locale: locale,
        startYear: _rangeStart ?? kMinYear,
        endYear: _rangeEnd ?? kMaxYear,
        selectedId: _selectedId,
        revealRevision: _stackRevealRevision,
        label: (item) => digestLabel(item, data, kings, patriarchs, locale),
        dateLabel: (item) {
          final approximate = switch (item.kind) {
            StripLaneKind.stream =>
              data.powers.firstWhere((p) => p.id == item.id).approximate,
            StripLaneKind.rail => true,
            StripLaneKind.events => data.events
                .firstWhere((event) => event.id == item.id)
                .approximate,
            StripLaneKind.ministries => data.ministries
                .firstWhere((m) => '$kMinistryArcPrefix${m.id}' == item.id)
                .approximate,
            _ => false,
          };
          return '${approximate ? approximatePrefix(locale) : ''}${yearLabel(item.startYear, locale)}'
              '${item.startYear == item.endYear ? '' : ' — ${item.openEnded ? s('wheelPresent', 'present', locale) : yearLabel(item.endYear, locale)}'}';
        },
        onFlat: () => _setDepth(false),
        onOpen: (item) => _openChartRecord(context, item, data, locale),
      );
    }
    final wb = WbColors.of(context);
    final t = WbType.of(context);

    // Controls and readout occupy layout rows below the wheel. The old
    // corner controls covered the bottom axis when their touch targets
    // grew to 44 px. Both rows sit outside this LayoutBuilder, so the
    // wheel measures only the unobstructed area it can actually use.
    return Column(children: [
      Expanded(
        child: LayoutBuilder(builder: (context, box) {
          _viewportSize = Size(box.maxWidth, box.maxHeight);
          final side = math.min(box.maxWidth, box.maxHeight);
          _side = side;
          final hubD = side * _kHubFrac * 2;
          final rHub = side * _kHubFrac;
          final rRim = side * rimFractionFor(side);
          _restoreFlatCamera(_viewportSize!, rRim);

          final scene = _sceneFor(data, side, locale, _wheelFont(t, _kLabelPx));
          final streams = scene.streams;
          final colors = scene.colors;
          final arcs = scene.arcs;
          final spokes = scene.spokes;
          final lives = scene.lives;
          final rail = scene.rail;

          return Stack(key: _viewportKey, children: [
            Positioned.fill(
              child: InteractiveViewer(
                // A TRACKPAD'S TWO FINGERS ZOOM, like the wheel's.
                // 2026-09-16 「wheel strip可以鼠标上下滑zoom in out吗
                // 然后ipad可以两个手指zoom in out这样」. A mouse wheel
                // already scaled; a trackpad's two-finger scroll
                // arrives as a pan gesture instead and was panning a
                // chart nobody wanted to pan. A pinch on a touch
                // screen was always a scale and is unaffected.
                trackpadScrollCausesScale: true,
                transformationController: _viewer,
                maxScale: kWheelMaxScale,
                minScale: 0.8,
                child: Center(
                  child: SizedBox(
                    width: side,
                    height: side,
                    child: Listener(
                      onPointerDown: (e) => _pressOrigin = e.position,
                      onPointerUp: (e) => _commitPress(e, () {
                        final year = _yearAt(e.localPosition, side);
                        // Outside the 320-degree sweep is blank paper, and
                        // blank paper names no year — the same rule
                        // `_handleTap` already applies to the empty wedge.
                        if (year != null) _placeCursor(year);
                      }),
                      onPointerCancel: (_) => _pressOrigin = null,
                      // A MOUSE CAN ASK WITHOUT COMMITTING, and until
                      // now it could not. 2026-09-17 「when hovering over
                      // the line or strip can you have hovering pop up
                      // label or something and when click then pop up
                      // window?」 — reported from the wheel at 3614%,
                      // where the bands under the pointer are a few
                      // pixels deep and carry no name at all.
                      //
                      // The SAME resolver the tap uses answers here, so
                      // the name that floats up is the record the click
                      // would open. The cursor changes with it: a plate
                      // appearing is also the only signal that there is
                      // anything here to press.
                      child: MouseRegion(
                        cursor: _hover == null
                            ? MouseCursor.defer
                            : SystemMouseCursors.click,
                        onHover: (e) {
                          final hit = _resolveAt(
                              context,
                              e.localPosition,
                              side,
                              data,
                              streams,
                              arcs,
                              spokes,
                              lives,
                              rail,
                              locale,
                              e.kind);
                          final y = _yearAt(e.localPosition, side);
                          _setHover(hit, y == null ? '' : yearLabel(y, locale),
                              e.position);
                        },
                        onExit: (_) => _setHover(null, '', null),
                        child: GestureDetector(
                          // The wheel is one square canvas and every band, arc
                          // and spoke is painted, not laid out, so a test can
                          // only reach a detail sheet by tapping a computed
                          // point. This key is how it finds the square and its
                          // centre — same reason as `chronologyAxis` on the
                          // sibling page.
                          key: const ValueKey('chronologyWheel'),
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (e) => _handleTap(
                              context,
                              e.localPosition,
                              side,
                              data,
                              streams,
                              arcs,
                              spokes,
                              lives,
                              rail,
                              locale,
                              // A finger is twice a cursor, and the
                              // event says which this was.
                              e.kind),
                          child: Stack(children: [
                            RepaintBoundary(
                              key: const ValueKey('wheelSceneBoundary'),
                              child: CustomPaint(
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
                                  rangeStart: _rangeStart,
                                  rangeEnd: _rangeEnd,
                                  wb: wb,
                                  zoom: _zoom,
                                  symbols: ChartSymbolService.instance.cached,
                                  rimFont: _wheelFont(t, _kLabelPx),
                                  endFont: _wheelFont(t, 13),
                                  bandFont: _wheelFont(t, 12),
                                  visible: _visibleCanvasRect(side),
                                ),
                              ),
                            ),
                            // WHAT THE ANSWER IS A CLAIM ABOUT, drawn.
                            //
                            // 2026-09-17. At 4050% a band is three
                            // hundred pixels deep and thousands long,
                            // and its name is painted once somewhere
                            // along it — so a word beside the cursor is
                            // unverifiable, and a correct answer looks
                            // exactly like a wrong one. 「hover over那个
                            // 不准确」 was partly a real defect (fixed in
                            // the resolver) and partly this: no evidence.
                            //
                            // In the TRANSFORMED child, because the
                            // shape is in canvas coordinates; its own
                            // CustomPaint rather than the scene's, so a
                            // mouse crossing the chart never repaints a
                            // 4000% wheel; and hit-transparent, like
                            // the year rule below it.
                            if (_hover?.shape case final claim?)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    key: const ValueKey('wheelClaimOutline'),
                                    painter: _ClaimOutlinePainter(
                                      claim: claim,
                                      side: side,
                                      zoom: _zoom,
                                      color: wb.accent,
                                      halo: wb.paneBg,
                                    ),
                                  ),
                                ),
                              ),
                            // THE LINE, and on a wheel it is a spoke: year is
                            // angle here, so the rule that says "this year"
                            // runs hub to rim. Hit-transparent, because a rule
                            // that swallowed taps would answer 「没有线根本不
                            // 知道哪一年」 by breaking the chart underneath it.
                            if (_cursorYear case final int y)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    key: const ValueKey('wheelYearCursor'),
                                    painter: _YearSpokePainter(
                                      year: y,
                                      side: side,
                                      rHub: rHub,
                                      rRim: rRim,
                                      color: wb.accent,
                                      zoom: _zoom,
                                    ),
                                  ),
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
                                  child: _hubCaption(context, locale, t, wb, hubD,
                                      streams, data, lives),
                                ),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // THE NAME, in the viewport's coordinates rather than the
            // wheel's — see [_hover]. Hit-transparent, because a plate
            // that took the pointer would move itself out from under
            // the pointer and flicker between two answers.
            if (_hover case final h?)
              Positioned.fill(
                key: const ValueKey('wheelHoverLabel'),
                child: IgnorePointer(
                  child: CustomSingleChildLayout(
                    delegate: ChartHoverPlateLayout(h.at),
                    child: ChartHoverPlate(h.label, year: h.year),
                  ),
                ),
              ),
          ]);
        }),
      ),
      SizedBox(
        key: const ValueKey('wheelControlsFooter'),
        height: wheelControlsFooterHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: LayoutBuilder(
              builder: (context, constraints) => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _legendChip(context, locale, t, wb),
                      _zoomControls(locale, t, wb,
                          showPercentage: constraints.maxWidth >= 420),
                    ],
                  )),
        ),
      ),
    ]);
  }

  /// The hub identifies the chart; readable records and counts belong to
  /// the explorer. Removing the four-block caption also keeps a small
  /// wheel's centre inside its circle instead of wrapping into the bands.
  Widget _hubCaption(
      BuildContext context,
      String locale,
      WbType t,
      WbColors wb,
      double hubD,
      List<WheelStream> streams,
      WheelHistoryData data,
      List<_Life> lives) {
    // THE YEAR, NOT THE TITLE. The page's own AppBar already says
    // "World History Wheel" two rows above this, so the hub was
    // spending the calmest circle on the chart repeating it.
    //
    // What goes there instead is the thing the chart is being asked
    // for. The footer says 「点一下图表，读出那一年」 and the answer used to
    // appear in the digest bar below the wheel — so a reader tapping
    // around the rim had to look away from the point of the finger to
    // read the result. It is now under the finger's own circle.
    //
    // With no cursor yet, the hub says what the chart COVERS, which is
    // the other question a reader asks of a chronology before they
    // touch it. That line used to sit in small grey type above the
    // chart; it is the same fact, in the place the eye already is.
    final year = _cursorYear;
    // A 390 px phone gives this circle about 83 px across, and at that
    // size the range plus its caption clipped to 「主前4200 − 主后20…」.
    // The hub is a readout, so a readout that cannot finish its own
    // sentence is worse than a shorter one: below the threshold the
    // caption goes and the range breaks onto its own two lines.
    final roomy = hubD >= 110;
    final hint = !roomy
        ? ''
        : year == null
            ? s('wheelHubCovers', 'this chart covers', locale)
            : s('wheelHubYear', 'the year you tapped', locale);
    return SizedBox(
      key: const ValueKey('wheelHubCaption'),
      width: hubD * 0.82,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            year == null
                ? '${yearLabel(_rangeStart ?? kMinYear, locale)}'
                    '${roomy ? ' — ' : '\n'}'
                    '${yearLabel(_rangeEnd ?? kMaxYear, locale)}'
                : yearLabel(year, locale),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: year == null ? wb.mutedText : wb.text,
              fontSize: math.max(
                  t.scaledChrome(year == null ? 11 : (roomy ? 16 : 13)),
                  WbMetrics.smallPrintFloor),
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          if (hint.isNotEmpty)
            Text(
              hint,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: wb.mutedText,
                // The app's own small-print floor, not a size chosen to
                // make this line fit. `font_size_reach_ratchet_test`
                // caught 9.5 here within minutes of it being written —
                // which is the same defect, in a widget, that the
                // canvas type had in `scaledChrome` an hour earlier.
                fontSize:
                    math.max(t.scaledChrome(11), WbMetrics.smallPrintFloor),
                height: 1.25,
              ),
            ),
        ],
      ),
    );
  }

  /// The full legend lives behind this named footer control at every
  /// width. It remains one tap away without covering the wheel or axis.
  Widget _legendChip(
      BuildContext context, String locale, WbType t, WbColors wb) {
    final label = switch (locale) {
      'zh-Hans' => '图例',
      'zh-Hant' => '圖例',
      _ => 'Legend',
    };
    void openLegend() => showModalBottomSheet<void>(
          context: context,
          backgroundColor: wb.paneBg,
          isScrollControlled: true,
          builder: (sheet) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
              child: SingleChildScrollView(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _legend(locale, t, wb),
                ),
              ),
            ),
          ),
        );
    // Square, not rounded — task #279's rule (`workbench_theme.dart`:
    // "square corners and 1px hairline borders, no shadows, no cards")
    // and `page_chrome_pass_test.dart`'s own ratchet catch a rounded
    // corner appearing in a file the pass had left clean, which a
    // `BorderRadius.circular(...)` here was. The full legend and the
    // adjacent zoom controls use bare rectangles for the same reason.
    return Semantics(
      key: const ValueKey('wheelLegendControl'),
      label: label,
      button: true,
      onTap: openLegend,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Material(
          color: wb.paneBg.withValues(alpha: 0.92),
          shape: RoundedRectangleBorder(side: BorderSide(color: wb.border)),
          child: InkWell(
            onTap: openLegend,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.legend_toggle,
                      size: t.scaledChrome(18), color: wb.text),
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(
                          color: wb.text, fontSize: t.scaledChrome(11))),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Zoom controls, because a desktop reader has no pinch.
  ///
  /// InteractiveViewer answers a trackpad and a scroll wheel, but
  /// neither is discoverable and a mouse-only reader was left with a
  /// wheel they could not enlarge — which is what made the labels
  /// unreadable rather than merely dense. The percentage is shown
  /// because at 300% the reader should know why more labels appeared.
  Widget _zoomControls(String locale, WbType t, WbColors wb,
      {required bool showPercentage}) {
    final (zoomOut, zoomIn) = switch (locale) {
      'zh-Hans' => ('缩小', '放大'),
      'zh-Hant' => ('縮小', '放大'),
      _ => ('Zoom out', 'Zoom in'),
    };
    Widget btn(String key, IconData icon, String tip, VoidCallback go) =>
        Semantics(
          key: ValueKey(key),
          label: tip,
          button: true,
          onTap: go,
          excludeSemantics: true,
          child: Tooltip(
            message: showPercentage ? tip : '$tip · ${(_zoom * 100).round()}%',
            child: SizedBox(
              width: 44,
              height: 44,
              child: InkWell(
                onTap: go,
                child: Icon(icon, size: t.scaledChrome(18), color: wb.text),
              ),
            ),
          ),
        );
    return Container(
      key: const ValueKey('wheelZoomControls'),
      decoration: BoxDecoration(
        color: wb.paneBg.withValues(alpha: 0.94),
        border: Border.all(color: wb.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        btn('wheelZoomOutControl', Icons.remove, zoomOut,
            () => _zoomBy(1 / 1.4)),
        Container(width: 1, height: t.scaledChrome(18), color: wb.border),
        // The 3D switch adds a 44 px target. At 360 px and maximum menu
        // scale the previous footer overflowed in the regression fixture.
        // Drop the 64 px percentage first; each zoom tooltip still
        // reports it, and all actions retain their 44 px touch areas.
        if (showPercentage)
          SizedBox(
            width: 64,
            child: Text('${(_zoom * 100).round()}%',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: wb.mutedText, fontSize: t.scaledChrome(11))),
          ),
        Container(width: 1, height: t.scaledChrome(18), color: wb.border),
        btn('wheelZoomInControl', Icons.add, zoomIn, () => _zoomBy(1.4)),
        Container(width: 1, height: t.scaledChrome(18), color: wb.border),
        btn('wheelResetControl', Icons.center_focus_strong,
            s('wheelReset', 'Reset', locale), _resetZoom),
        Container(width: 1, height: t.scaledChrome(18), color: wb.border),
        btn(
            'wheelFullScreenControl',
            _fullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
            s(_fullScreen ? 'wheelExitFullScreen' : 'wheelFullScreen',
                _fullScreen ? 'Exit full screen' : 'Full screen', locale),
            () => setState(() => _fullScreen = !_fullScreen)),
      ]),
    );
  }

  /// Every power's arc, and the stretch of its own name the band can
  /// honestly carry.
  ///
  /// The geometry and the packing both live in [planArcNames]
  /// (`radial_chronology_layout.dart`) — NO SUB-RINGING, and the name is
  /// set in the widest FREE stretch of its own arc rather than centred
  /// on the whole arc regardless of who else is drawn across it. See
  /// that function's own doc comment for the measured reasons (a stream
  /// ring is 6.95 canvas units at 900 px and europe alone nests eight
  /// powers deep) and for why the sort below — ring ascending, span
  /// descending — is done HERE rather than inside it: this same order is
  /// also `_paintArcs`'s paint order, and [planArcNames] deliberately
  /// does not re-sort, so there is exactly one sort for both.
  ///
  /// A power whose name loses the draw is not lost outright: tapping its
  /// own stretch of the band opens [showPower] (`wheel_sheets.dart`)
  /// exactly as it always did — hit testing runs on `arc.a0`/`arc.a1`,
  /// not on whether the label drew — and `showStream`'s sheet lists
  /// every power on the stream by name and span whether or not its ring
  /// label made it onto the wheel.
  List<_Arc> _buildArcs(
    WheelHistoryData data,
    Map<String, int> ringOf,
    Map<String, Color> colors,
    int ringCount,
    double rHub,
    double rBands,
    String locale,
    double rimFont,
  ) {
    final geo = <({WheelPower power, int ring, double a0, double a1})>[];
    for (final p in data.powers) {
      final ring = ringOf[p.stream];
      if (ring == null) continue;
      geo.add((
        power: p,
        ring: ring,
        a0: angleForSpan(p.start, kMinYear, kMaxYear),
        a1: angleForSpan(p.endFor(kMaxYear), kMinYear, kMaxYear),
      ));
    }
    // Ring ascending, then span descending within the ring — see the
    // doc comment above and [planArcNames]'s for why the second key is
    // the one that matters, and why it is fixed here rather than there.
    geo.sort((a, b) {
      if (a.ring != b.ring) return a.ring.compareTo(b.ring);
      return (b.a1 - b.a0).compareTo(a.a1 - a.a0);
    });
    if (geo.isEmpty) return const [];

    // ── one ring per stream, divided into layers ──────────────────
    //
    // 2026-09-16 「一个圈圈 但是那个每个条可以细一些多层这样 ... 这样就知
    // 道同一时代同时发生事情」. Powers that ran at the same time used to
    // share one radius and print across each other; each gets its own
    // layer of the stream's ring now, as deep as the ring can carry
    // (see [streamTierCount]) and no deeper. What will not fit keeps
    // the old behaviour and shares the last layer, which is what every
    // power on the ring did before.
    final tierOf = List<int>.filled(geo.length, 0);
    final tiersOf = List<int>.filled(geo.length, 1);
    final byRing = <int, List<int>>{};
    for (var i = 0; i < geo.length; i++) {
      byRing.putIfAbsent(geo[i].ring, () => []).add(i);
    }
    for (final entry in byRing.entries) {
      // The packer is first-fit IN START ORDER, so a container takes
      // the outer layer and what nests inside it steps in — which is
      // the reading a reader expects and the one the depth view
      // already gives.
      final idx = entry.value.toList()
        ..sort((a, b) => geo[a].a0.compareTo(geo[b].a0));
      final starts = [for (final i in idx) geo[i].a0];
      final ends = [for (final i in idx) geo[i].a1];
      final deep = packIntoRings(starts, ends, idx.length, minGap: 0);
      var wanted = 1;
      for (final t in deep) {
        if (t + 1 > wanted) wanted = t + 1;
      }
      final tiers = streamTierCount(
          wanted: wanted, ringCount: ringCount, rHub: rHub, rMax: rBands);
      final packed = tiers >= wanted
          ? deep
          : packIntoRings(starts, ends, tiers, minGap: 0);
      for (var k = 0; k < idx.length; k++) {
        tierOf[idx[k]] = packed[k];
        tiersOf[idx[k]] = tiers;
      }
    }
    // A composite so `planArcNames` keeps its own meaning of `ring` —
    // the number things sharing a RADIUS share — without learning what
    // a stream is.
    var spread = 1;
    for (final t in tiersOf) {
      if (t > spread) spread = t;
    }
    int keyFor(int i) => geo[i].ring * spread + tierOf[i];
    final tiersByRing = {
      for (final entry in byRing.entries)
        entry.key: tiersOf[entry.value.first],
    };

    final planned = planArcNames(
      requests: [
        for (var i = 0; i < geo.length; i++)
          (
            ring: keyFor(i),
            a0: geo[i].a0,
            a1: geo[i].a1,
            name: geo[i].power.nameFor(locale)
          )
      ],
      ringCount: ringCount,
      rHub: rHub,
      rBands: rBands,
      desiredSize: rimFont / _labelScale(_zoom),
      zoom: _zoom,
      floorPx: kArcLabelFloorPx,
      measure: _measureChars,
      bandOf: (key) {
        final ring = key ~/ spread;
        final band = tierRadii(ring, ringCount, rHub, rBands,
            tier: key % spread, tiers: tiersByRing[ring] ?? 1);
        return (centre: band.centre, width: band.width);
      },
    );

    return [
      for (var i = 0; i < geo.length; i++)
        _Arc(
          geo[i].power,
          geo[i].ring,
          geo[i].a0,
          geo[i].a1,
          colors[geo[i].power.stream] ?? lineColor('none', dark: _dark),
          tier: tierOf[i],
          tiers: tiersOf[i],
          name: planned[i].name,
          nameA0: planned[i].a0,
          nameSweep: planned[i].sweep,
          nameSize: planned[i].size,
        )
    ];
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
    // Events that cannot each have a label are grouped. At overview
    // a filled tick indicates the cluster; zooming exposes its +n
    // badge. Tapping either opens all members, and the explorer lists
    // the individual events in readable rows at every magnification.
    final onScreenPx = _kLabelPx * 1.35;
    // 2026-09-15: divided by a FIXED reference radius, not by the live
    // `rBands`.
    //
    // The band annulus became responsive on this date — the data had 17%
    // of the radius and its annotation had 55% — and dividing by it made
    // the declutter a function of that proportion: a wider band annulus
    // produced a SMALLER angular gap, so more spokes were attempted, so
    // more of them carried a `+n` badge, so more titles were starved of
    // room by it. None of that is about the bands. This gap is about
    // whether two labels in the outer annulus collide, so it is computed
    // against the proportion it was tuned at and stays put when the
    // rings are re-proportioned.
    final declutterRadius = _side * kBandsFracWide;
    final minGap = (onScreenPx / _labelScale(_zoom)) / declutterRadius;

    final angles = [
      for (final e in all) angleForSpan(e.year, kMinYear, kMaxYear)
    ];
    // ── THINNED PER RING, NOT ACROSS THE WHOLE CHART ───────────────
    //
    // Every event used to be clustered together against one reference
    // radius, and while all 291 ticks shared a single circle that was
    // right — two marks on that circle really could collide however far
    // apart their streams were.
    //
    // Since the ticks moved onto their own streams' rings (2026-09-15)
    // it is wrong twice over:
    //
    //   * ACROSS STREAMS. A church event and an Israel event five years
    //     apart were merged into one spoke, so tapping opened a cluster
    //     mixing two streams — for marks that are no longer anywhere
    //     near each other, being a whole ring apart.
    //   * AT THE WRONG RADIUS. The gap was computed at the OUTER band
    //     radius for every ring. An inner ring has less arc per degree,
    //     so the same angle there is a shorter run of pixels, and its
    //     marks were being thinned as though they had the outermost
    //     ring's room.
    //
    // Each ring is now thinned against its own radius, which is also
    // what finally answers the density complaint honestly: the church
    // ring carries 188 of the corpus's records and gets thinned on its
    // own crowding, not on the average of four rings.
    //
    // Selection always survives the thinning: hiding the thing the
    // reader just tapped would be indefensible. It represents its
    // cluster instead of being added beside it.
    final rings = ringOf.length;
    final rHub = _side * _kHubFrac;
    final byRing = <int, List<int>>{};
    for (var i = 0; i < all.length; i++) {
      byRing.putIfAbsent(ringOf[all[i].stream]!, () => []).add(i);
    }
    final clusters = <SpokeCluster>[];
    for (final entry in byRing.entries) {
      final radius =
          math.max(ringRadii(entry.key, rings, rHub, rBands).centre, 1.0);
      final gap = (onScreenPx / _labelScale(_zoom)) / radius;
      final idx = entry.value;
      final pinned = idx.indexWhere((i) => all[i].id == _selectedId);
      for (final c in clusterByAngle([for (final i in idx) angles[i]], gap,
          pinned: pinned)) {
        clusters.add(SpokeCluster(
          members: [for (final m in c.members) idx[m]],
          representative: idx[c.representative],
        ));
      }
    }
    // `planRadialSpokes` needs its requests in ascending angle.
    clusters.sort(
        (a, b) => angles[a.representative].compareTo(angles[b.representative]));
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
      // ITS OTHER PRECONDITION NO LONGER HOLDS GLOBALLY, and that is a
      // deliberate consequence rather than an oversight.
      //
      // `planRadialSpokes` asks that no two requests be closer than
      // this, and the page's declutter used to guarantee it across the
      // whole chart. Thinning per ring guarantees it only WITHIN a
      // ring, so two requests from different rings can now arrive
      // closer than `minGap`.
      //
      // What that precondition buys is labels that cannot collide — and
      // at most one label is drawn now, the selected record's. Two
      // labels cannot overlap when there is never a second one. The
      // radii it hands back are still used, and those are per-request.
      minGap: minGap,
      lineHeight: titleSize * 1.35,
    );
    return [
      for (final p in planned)
        _Spoke(
          [for (final m in clusters[p.index].members) all[m]],
          kept[p.index],
          p.label,
          colors[kept[p.index].stream] ?? lineColor('none', dark: _dark),
          p.title,
          p.ref,
          badge: p.badge,
        )
    ];
  }

  // ── the lifespans ──────────────────────────────────────────────────

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
    List<WheelMinistry> ministries, {
    bool includePatriarchs = true,
  }) =>
      packWheelBand(
        chron: chron,
        creationYear: creation,
        kings: kings,
        ministries: ministries,
        reservedInnerRings: _reservedRings,
        includePatriarchs: includePatriarchs,
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
      for (final k
          in HebrewKingsService.instance.cached?.kings ?? const <HebrewKing>[])
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
    final chron = ChronologyService.instance.cached;
    final creation = creationYear;
    if (chron == null || creation == null) return const [];

    // Each layer answers for itself. Hiding the patriarchs drops the
    // patriarch arcs and nothing else — see the note on
    // `packWheelBand`'s `includePatriarchs` for what this used to do.
    final showPatriarchs = !_hidden.contains(kLifespanLayerId);

    final kings = _hidden.contains(kReignLayerId)
        ? const <HebrewKing>[]
        : (HebrewKingsService.instance.cached?.kings ?? const <HebrewKing>[]);
    final ministries = _hidden.contains(kMinistryLayerId)
        ? const <WheelMinistry>[]
        : (WheelHistoryService.instance.cached?.ministries ??
            const <WheelMinistry>[]);
    final byKingId = {for (final k in kings) '$kKingArcPrefix${k.id}': k};
    final byMinistryId = {
      for (final m in ministries) '$kMinistryArcPrefix${m.id}': m
    };
    final arcs = _packBand(chron, creation, kings, ministries,
        includePatriarchs: showPatriarchs);
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
              wheelShowsEventText(
                  zoom: _zoom, selected: s.event.id == _selectedId) &&
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
        // rings are wider, which determines the space their names can
        // use once selection or zoom makes the text visible.
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
          'seth' => lineColor('none', dark: _dark),
          'judah' => kingdomArcColor(Kingdom.judah, dark: _dark),
          'israel' => kingdomArcColor(Kingdom.israel, dark: _dark),
          'ministry' => ministryArcColor(dark: _dark),
          _ => lineColor('shem', dark: _dark),
        },
        name: drawn,
        fullName: name,
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
                color: lineColor(line, dark: wb.isDark)),
            SizedBox(width: t.scaled(6)),
            Text(s(key, fallback, locale),
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
          // THE RINGS THAT ARE ACTUALLY ON THE CHART, first.
          //
          // This sheet is what a reader opens when they want to know
          // what they are looking at, and until now it answered a
          // question they had not asked: which Genesis 10 family each
          // HUE belongs to. That is real and it stays below — but the
          // thing on screen is four named rings carrying four symbols,
          // and the legend said nothing about either.
          //
          // The symbol is drawn here at the size and in the colour the
          // canvas draws it, from the same map, so this row is a
          // specimen of the mark rather than a description of it.
          if (_scene case final scene?) ...[
            for (var i = 0; i < scene.streams.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    width: t.scaled(16),
                    height: t.scaled(16),
                    child: () {
                      final colour = scene.colors[scene.streams[i].id] ??
                          lineColor(scene.streams[i].line, dark: wb.isDark);
                      final image = ChartSymbolService.instance
                          .cached[symbolForStream(scene.streams[i].id)];
                      return image == null
                          ? Center(
                              child: Container(
                                  width: t.scaled(10),
                                  height: t.scaled(10),
                                  color: colour))
                          : RawImage(
                              image: image,
                              color: colour,
                              colorBlendMode: BlendMode.srcIn,
                              fit: BoxFit.contain);
                    }(),
                  ),
                  SizedBox(width: t.scaled(6)),
                  Text(scene.streams[i].nameFor(locale),
                      style: TextStyle(
                          color: wb.text,
                          fontSize: t.scaled(11.5),
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: t.scaled(4)),
              child: SizedBox(
                  width: t.scaled(150),
                  child: Divider(height: 1, color: wb.border)),
            ),
          ],
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
                  color: lineColor('shem', dark: wb.isDark)
                      .withValues(alpha: 0.5)),
              SizedBox(width: t.scaled(6)),
              Text(
                '${s('wheelLifespans', 'Genesis lifespans', locale)} · '
                '${s('wheelLifespansTradition', 'Masoretic', locale)}',
                style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11)),
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
                        color: kingdomArcColor(kingdom, dark: wb.isDark)
                            .withValues(alpha: 0.5)),
                    SizedBox(width: t.scaled(6)),
                    Text(
                      '${kingdomLabel(locale, kingdom)} · '
                      '${s('wheelKingsThiele', 'reigns (Thiele)', locale)}',
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
                      color: ministryArcColor(dark: wb.isDark)
                          .withValues(alpha: 0.5)),
                  SizedBox(width: t.scaled(6)),
                  Text(
                    s('wheelMinistries', 'Prophets & apostles', locale),
                    style:
                        TextStyle(color: wb.mutedText, fontSize: t.scaled(11)),
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
                      color: lineageRailColor(dark: wb.isDark)
                          .withValues(alpha: 0.6)),
                  SizedBox(width: t.scaled(14)),
                  Text(
                    s('wheelLineage', 'Genealogy (approximate)', locale),
                    style:
                        TextStyle(color: wb.mutedText, fontSize: t.scaled(11)),
                  ),
                ]),
              ),
          ],
          SizedBox(height: t.scaled(3)),
          Text(s('wheelShadeNote', '', locale),
              style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11))),
          Text(s('wheelClusterLegend', '', locale),
              style: TextStyle(color: wb.mutedText, fontSize: t.scaled(11))),
        ],
      ),
    );
  }

  Future<void> _showFilter(BuildContext context, String locale) async {
    final settings = context.read<AppSettings>();
    final data = await _future;
    if (data == null || !mounted || !context.mounted) return;
    final result = await showChronologyFilterSheet(
      context: context,
      locale: locale,
      data: data,
      hidden: _hidden,
      streamColors: colorsFor(data, dark: _dark),
      layerColors: {
        kLifespanLayerId: lineColor('shem', dark: _dark),
        kReignLayerId: kingdomArcColor(Kingdom.judah, dark: _dark),
        kMinistryLayerId: ministryArcColor(dark: _dark),
        kLineageLayerId: lineageRailColor(dark: _dark)
      },
      text: (key, fallback) => s(key, fallback, locale),
      keyPrefix: 'wheelFilter',
      streamCeiling: kMaxVisibleStreams,
    );
    if (result == null || !mounted) return;
    setState(() {
      _hidden
        ..clear()
        ..addAll(result);
    });
    // KEPT, not just applied. 2026-09-16 「filter我选了之后换strip或者
    // wheel或者离开那个界面，那个filter就reset了」 — the two charts hand
    // the set to each other, so flipping between them held; leaving the
    // chart and coming back did not, because the set lived only here.
    await settings.setChronologyHiddenStreams(_hidden);
  }

  void _showAbout(BuildContext context, String locale) {
    final wb = WbColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      isScrollControlled: true,
      builder: (sheet) => FutureBuilder<WheelHistoryData>(
        future: _future,
        builder: (c, snap) {
          final t = WbType.of(c);
          final data = snap.data;
          if (data == null) return const SizedBox(height: 120);
          final meta = data.meta;
          Widget section(
                  String headingKey, String headingFallback, String body) =>
              body.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: EdgeInsets.only(bottom: t.scaled(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s(headingKey, headingFallback, locale),
                              style: TextStyle(
                                  color: wb.mutedText,
                                  fontSize: t.scaled(12),
                                  fontWeight: FontWeight.w600)),
                          SizedBox(height: t.scaled(4)),
                          Text(body,
                              style: TextStyle(
                                  color: wb.mutedText, fontSize: t.scaled(12))),
                        ],
                      ),
                    );
          return buildSheet(c, [
            Text(s('wheelAbout', 'About this chart', locale),
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
            section(
                'wheelAboutAxis', 'Where the axis stops', meta.axisFor(locale)),
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

  String _kindLabel(WheelHitKind kind, String locale) => switch (kind) {
        WheelHitKind.event => s('wheelKindEvent', 'event', locale),
        WheelHitKind.power => s('wheelKindPower', 'power', locale),
        WheelHitKind.nation => s('wheelKindNation', 'nation', locale),
        WheelHitKind.stream => s('wheelKindBand', 'band', locale),
        WheelHitKind.patriarch => s('wheelKindLife', 'life', locale),
        WheelHitKind.ministry => s('wheelKindMinistry', 'ministry', locale),
        // The one label in this switch that names a NON-record. It sits
        // in the same column as "event" and "ministry" so the reader
        // can see at a glance that this row is a different kind of
        // answer before they open it — and the year column beside it is
        // empty, which is the same statement said twice.
        WheelHitKind.omission => s('wheelKindOmission', 'no date', locale),
      };

  /// The year column of a result row.
  ///
  /// A power gets its whole span, not just its start: half the reason
  /// to search a year is to see what was standing at the time, and
  /// "Babylon 626 BC" answers a different question from
  /// "Babylon 626–539 BC".
  String _hitYears(WheelHit hit, WheelHistoryData data, String locale) {
    if (hit.kind == WheelHitKind.power) {
      final p = find(data.powers, (p) => p.id == hit.id);
      if (p != null) {
        final end = p.ongoing
            ? s('wheelPresent', 'present', locale)
            : yearLabel(p.end!, locale);
        return '${yearLabel(p.start, locale)} – $end';
      }
    }
    return hit.year == null ? '' : yearLabel(hit.year!, locale);
  }

  /// Why this row is in the list, when the title alone does not show it.
  String _hitVia(WheelHit hit, String locale) => switch (hit.via) {
        WheelHitVia.otherLocale => hit.matched,
        WheelHitVia.otherSpelling => fill('wheelNameKjv',
            'King James Version: {name}', locale, {'name': hit.matched}),
        WheelHitVia.description =>
          s('wheelFindInDesc', 'in the description', locale),
        WheelHitVia.person => s('wheelFindPerson', 'names {name}', locale)
            .replaceFirst('{name}', hit.matched),
        WheelHitVia.reference => localizedReferenceLabel(hit.matched, locale),
        WheelHitVia.yearSpan => s('wheelFindSpan', 'spans it', locale),
        WheelHitVia.yearNear => s('wheelFindNear', 'nearby', locale),
        _ => '',
      };

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
      isScrollControlled: true,
      builder: (sheet) => FutureBuilder<WheelHistoryData>(
        future: _future,
        builder: (c, snap) {
          final data = snap.data;
          if (data == null) return const SizedBox(height: 120);
          final t = WbType.of(c);
          final colors = colorsFor(data, dark: _dark);
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
              creationYear: creationYear,
              tradition: kDrawnTradition,
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
                        prefixIcon: Icon(Icons.search, size: t.scaled(17)),
                        prefixIconConstraints: BoxConstraints(
                            minWidth: t.scaled(34), minHeight: t.scaled(20)),
                        hintText: s('wheelFindHint',
                            'A name, a verse or a year', locale),
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
                      final noYears = person == null
                          ? _amPersonWithoutFigures(query)
                          : null;
                      final king = person == null && noYears == null
                          ? _kingFor(query)
                          : null;
                      if (person == null && noYears == null && king == null) {
                        return const SizedBox.shrink();
                      }
                      final line = person != null
                          ? fill('wheelFindAmElsewhere', '', locale,
                              {'name': person.localizedName(locale)})
                          : noYears != null
                              ? fill('wheelFindNoYears', '', locale,
                                  {'name': noYears.localizedName(locale)})
                              : fill('wheelFindKingElsewhere', '', locale,
                                  {'name': king!.nameFor(locale)});
                      final label = person != null
                          ? s('timelineOpenChronology', 'Open Bible Chronology',
                              locale)
                          : noYears != null
                              ? s('familyTree', 'Family Tree', locale)
                              : s('hebrewKings', 'Kings of Judah & Israel',
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
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
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
                                  child: swatch(
                                      t,
                                      colors[hit.streamId] ??
                                          lineColor('none', dark: _dark)),
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
                                              s(
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
  /// The lookup is synchronous for the same reason `showPerson`'s is —
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
    for (final k
        in HebrewKingsService.instance.cached?.kings ?? const <HebrewKing>[]) {
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
      return fill('wheelFindTeach', '', locale, {
        'e': data.events.length,
        'p': data.powers.length,
        'm': data.ministries.length,
        'n': data.nations.length,
        'b': data.streams.length,
        'o': data.omissions.length,
      });
    }
    if (result.isEmpty) {
      return fill('wheelFindNone', 'Nothing here matches “{q}”.', locale,
          {'q': query.trim()});
    }
    final parts = <String>[
      if (result.hits.length == 1)
        fill('wheelFindCountOne', '{n} result', locale, {'n': 1})
      else
        fill(
            'wheelFindCount', '{n} results', locale, {'n': result.hits.length}),
      if (result.years.isNotEmpty)
        result.years.map((y) => yearLabel(y, locale)).join(' · '),
      if (result.nearestShown > 0)
        fill('wheelFindNearNote', '', locale, {'n': result.nearestShown}),
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
      if (o != null) showOmission(context, o, locale);
      return;
    }
    // Repeating a search is still a request to reveal its record, even
    // after the reader has switched groups or panned away from it.
    _stackRevealRevision++;
    final year = hit.year;
    if (year != null && !_explorer.period.contains(year)) {
      final period = chronologyPeriods.skip(1).firstWhere(
            (period) => period.contains(year),
            orElse: () => chronologyPeriods.first,
          );
      // The controller updates the menu, list and projected range together.
      // Its range callback clears selection and resets the flat view, so
      // preserve that view here and set the found record after the callback.
      final view = Matrix4.copy(_viewer.value);
      _explorer.selectPeriod(period);
      _viewer.value = view;
    }
    setState(() {
      _hidden.remove(hit.streamId);
      // A nation of Genesis 10 is not drawn on the axis — it is the
      // descent behind a band — so what gets selected is that band.
      _selectedId = switch (hit.kind) {
        WheelHitKind.nation => hit.streamId,
        WheelHitKind.ministry => '$kMinistryArcPrefix${hit.id}',
        _ => hit.id,
      };
      if (year != null) _cursorYear = year;
    });
    _panTo(hit, data);
    switch (hit.kind) {
      case WheelHitKind.event:
        final e = find(data.events, (e) => e.id == hit.id);
        if (e != null) showEvent(context, e, data, locale);
      case WheelHitKind.power:
        final p = find(data.powers, (p) => p.id == hit.id);
        if (p != null) showPower(context, p, data, locale, _select);
      case WheelHitKind.nation:
      case WheelHitKind.stream:
        final s = find(data.streams, (s) => s.id == hit.streamId);
        if (s != null) showStream(context, s, data, locale, _select);
      case WheelHitKind.patriarch:
        final man = ChronologyService.instance.cached?.byId(hit.id);
        if (man != null) showPatriarch(context, man, locale);
      case WheelHitKind.ministry:
        final m = data.ministryById(hit.id);
        if (m != null) showMinistry(context, m, locale);
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
  /// The scrubber moves the CHART, not only the cursor.
  ///
  /// 2026-09-16 「我往后面拽的时候应该整个图跟着往后面移动」, of the strip —
  /// and the same is true here once the reader has zoomed in, where the
  /// year they are scrubbing to can be off the side of the viewport. At
  /// the resting zoom the whole wheel is on screen and nothing moves,
  /// which is correct rather than a special case.
  ///
  /// A press on the chart is deliberately NOT this: the year is already
  /// under the finger there, and recentring would move what is being
  /// pointed at.
  void _scrubToYear(int year) {
    _placeCursor(year);
    final view = _viewportSize;
    if (view == null || _zoom <= 1.02) return;
    final side = math.min(view.width, view.height);
    final rBands = side * bandsFractionFor(side);
    final rHub = side * _kHubFrac;
    final angle = angleForSpan(
        year.clamp(kMinYear, kMaxYear), kMinYear, kMaxYear);
    final radius = (rHub + rBands) / 2;
    final t = focusTranslation(
      px: view.width / 2 + radius * math.cos(angle),
      py: view.height / 2 + radius * math.sin(angle),
      scale: _zoom,
      viewW: view.width,
      viewH: view.height,
    );
    _viewer.value = Matrix4.identity()
      ..translateByDouble(t.dx, t.dy, 0, 1)
      ..scaleByDouble(_zoom, _zoom, 1, 1);
  }

  void _panTo(WheelHit hit, WheelHistoryData data) {
    if (_stacked) return;
    final view = _viewportSize;
    if (view == null || _side <= 0) return;
    final scale = _viewer.value.getMaxScaleOnAxis();
    if (scale <= 1.0) return;

    final streams = _visible(data);
    final rHub = _side * _kHubFrac;
    final rBands = _side * bandsFractionFor(_side);
    final rRim = _side * rimFractionFor(_side);

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
      final creation = creationYear;
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
      final arc = find(all, (a) => a.id == wanted);
      if (arc == null) return;
      lifeRadius = lifeArcRadii(
              arc.ring, lifeArcRingCount(all), scriptureLabelBase(rBands), rRim)
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
        final e = find(data.events, (e) => e.id == hit.id);
        if (e == null) return;
        angle = angleForSpan(e.year, kMinYear, kMaxYear);
        radius = (rBands + rRim) / 2;
      case WheelHitKind.power:
        final p = find(data.powers, (p) => p.id == hit.id);
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
    PointerDeviceKind kind,
  ) {
    // Kept here as well as in the resolver: with no data at all there
    // is nothing to select OR deselect, and routing that case through
    // the "nothing under the finger" branch below would clear a
    // selection the reader made before the streams were filtered away.
    if (streams.isEmpty) return;
    final hit = _resolveAt(context, local, side, data, streams, arcs, spokes,
        lives, rail, locale, kind);
    // NOTHING UNDER THE FINGER MEANS DESELECT, and that rule lives here
    // rather than in the resolver: the resolver is also asked by the
    // hover, which must be able to say "nothing" without changing what
    // the reader has selected.
    if (hit == null) {
      if (_selectedId != null) _select(null);
      return;
    }
    hit.open();
  }

  /// A FINGER IS NINE PIXELS ON THE SCREEN, NOT ON THE CANVAS.
  ///
  /// `fingerHalfWidth` and `nearestArcAt` default to 9, and every call
  /// here used the default — which is nine CANVAS units, a length the
  /// zoom then multiplies. The spoke branch above never had this bug:
  /// it writes its own tolerance as `9.0 / (_zoom * r)` and so has
  /// always meant nine pixels of screen.
  ///
  /// What that cost, measured at the zoom it was reported from
  /// (2026-09-17, 3660% on a 900 px canvas): a half-width of 4.5 canvas
  /// units becomes **165 screen pixels** of slack past each end of every
  /// band. So a point sitting in plainly empty paper, a finger's width
  /// away at 100% and a hand's width away at 3660%, still counted as
  /// inside the nearest band — which is why hovering blank space beside
  /// 大韩帝国 named 大韩帝国, and why tapping there had been opening it
  /// all along without anyone being able to see why.
  ///
  /// Dividing by the zoom keeps the target exactly nine screen pixels
  /// at every scale, which is what the padding was for: it rescues a
  /// hairline arc at 100%, where a hairline is genuinely unhittable,
  /// and stops pretending a band is 330 px wide at 3660%, where it is
  /// already enormous.
  double get _fingerPx => 9 / _zoom;

  /// WHAT IS ON SCREEN, in the wheel's own coordinates.
  ///
  /// The painter draws in canvas units and has never known where the
  /// reader is looking, which is why a ring's name could be painted two
  /// thousand pixels off the side of the window while the reader stared
  /// at that very ring.
  ///
  /// The viewer's matrix maps the child's coordinates to the viewport;
  /// inverting it maps back. The `Center` between the two is why the
  /// half-difference is subtracted: the square canvas sits in the
  /// middle of a viewport that is usually wider than it is.
  Rect? _visibleCanvasRect(double side) {
    final vp = _viewportSize;
    if (vp == null) return null;
    final inv = Matrix4.tryInvert(_viewer.value);
    if (inv == null) return null;
    final dx = (vp.width - side) / 2;
    final dy = (vp.height - side) / 2;
    Offset toCanvas(Offset p) =>
        MatrixUtils.transformPoint(inv, p) - Offset(dx, dy);
    // No rotation is ever applied, so two opposite corners are the rect.
    return Rect.fromPoints(
        toCanvas(Offset.zero), toCanvas(Offset(vp.width, vp.height)));
  }

  /// HOW DEEP A RADIAL TARGET MAY BE, in canvas units.
  ///
  /// 2026-09-17, and it is one rule where there were four: the target is
  /// the record's own INK, never smaller than a pointer, never larger
  /// than its own share of the annulus.
  ///
  ///     min(share, max(ink, K / zoom))
  ///
  /// Every radial tolerance on this wheel used to be a FRACTION OF THE
  /// GEOMETRY — half a ring's pitch, half a layer's — which the zoom
  /// then magnified without limit, while the angular tolerance beside
  /// it was already nine screen pixels and shrank correctly. Measured at
  /// 4050%: more than half of every answer came from air the reader
  /// cannot see, and a point could be 175 screen pixels past the edge of
  /// a band's ink and still be told it was on that band. That is the
  /// 「hover over那个不准确」 report, and it is the same defect a tap has
  /// always had.
  ///
  /// The two ends of the formula each rescue a different case, and both
  /// are load-bearing:
  ///
  ///   * `max(ink, K/zoom)` is why a hairline stays reachable. Seven
  ///     arcs on this chart are 0.00 px wide; at 100% a ring is 7 px and
  ///     a layer of it 1 px.
  ///   * `min(share, …)` is why zooming OUT changes nothing. At 100%,
  ///     K/zoom is 12 canvas units against a share of 3.5, so the share
  ///     wins and the behaviour is exactly what it was.
  ///
  /// K comes from the pointer, not from the gesture: a mouse is precise
  /// and a finger is not. Hover and tap read the same K for the same
  /// device, so the plate cannot name one thing while the tap opens
  /// another.
  double _radialTarget(
          {required double ink,
          required double share,
          required PointerDeviceKind kind}) =>
      math.min(share, math.max(ink, _pointerPx(kind) / _zoom));

  /// A pointer's own size, in screen pixels. 24 for a finger, 12 for
  /// anything with a cursor.
  static double _pointerPx(PointerDeviceKind kind) =>
      kind == PointerDeviceKind.touch || kind == PointerDeviceKind.stylus
          ? 24
          : 12;

  /// The angular slack the spoke branch allowed on the last resolve,
  /// for the probe only — the branch computes it from the radius under
  /// the pointer, which the recorder cannot recompute.
  double _probeSpokeTol = 0;

  /// Remember what the pointer is over, cheaply.
  ///
  /// [global] is a screen position and is converted here rather than by
  /// the caller, because only this method knows which box the plate is
  /// positioned in.
  ///
  /// The early return is not an optimisation to be trimmed later: a
  /// mouse crossing the wheel delivers a hover event every few pixels,
  /// and each `setState` rebuilds this page's whole subtree. Repainting
  /// is spared by the scene cache and the RepaintBoundary, but the
  /// rebuild is not, so the state only moves when the ANSWER moves.
  void _setHover(_WheelHit? hit, String year, Offset? global) {
    // THE YEAR ALONE IS STILL AN ANSWER. With nothing under the pointer
    // the plate used to vanish, which reads as a dead hover; on a
    // timeline "you are at 主后1204, between two bands" is exactly what
    // the reader wants to know, and it is also what tells them the
    // silence is deliberate.
    final label = hit?.label ?? '';
    if (global == null || (label.isEmpty && year.isEmpty)) {
      if (_hover != null) setState(() => _hover = null);
      return;
    }
    final box = _viewportKey.currentContext?.findRenderObject();
    if (box is! RenderBox) return;
    final at = box.globalToLocal(global);
    final was = _hover;
    if (was != null &&
        was.label == label &&
        was.year == year &&
        (was.at - at).distance < 2) {
      return;
    }
    setState(() =>
        _hover = (at: at, label: label, year: year, shape: hit?.shape));
  }

  /// Resolve the point [local] to a record, WITHOUT touching selection
  /// or opening anything. See [_WheelHit] for why this is one method.
  _WheelHit? _resolveAt(
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
    PointerDeviceKind kind,
  ) {
    if (streams.isEmpty) return null;

    final c = side / 2;
    final dx = local.dx - c, dy = local.dy - c;
    final r = math.sqrt(dx * dx + dy * dy);
    var a = math.atan2(dy, dx);
    while (a < startRad) {
      a += 2 * math.pi;
    }
    // EVERY ANSWER IS RECORDED WITH THE SHAPE IT CAME FROM, so that
    // "the hit test is inaccurate" can be a number instead of an
    // opinion. See [WheelHitProbe]. Off in every shipped build.
    _WheelHit answer(
      ({String id, String label, void Function() open}) hit, {
      required String kind,
      required double a0,
      required double a1,
      required double centre,
      required double halfDepth,
      required double halfAngle,
      required double inkHalf,
    }) {
      WheelRenderStats.noteHit((
        r: r,
        a: a,
        zoom: _zoom,
        id: hit.id,
        label: hit.label,
        kind: kind,
        a0: a0,
        a1: a1,
        centre: centre,
        halfDepth: halfDepth,
        halfAngle: halfAngle,
        inkHalf: inkHalf,
      ));
      return (
        id: hit.id,
        label: hit.label,
        open: hit.open,
        // The INK, not the target: the outline is drawn for the reader,
        // and a reader cannot be shown the slack they were allowed.
        shape: (a0: a0, a1: a1, centre: centre, halfDepth: inkHalf),
      );
    }

    _WheelHit? nothing(String why) {
      WheelRenderStats.noteHit((
        r: r,
        a: a,
        zoom: _zoom,
        id: '',
        label: '',
        kind: why,
        a0: 0,
        a1: 0,
        centre: 0,
        halfDepth: 0,
        halfAngle: 0,
        inkHalf: 0,
      ));
      return null;
    }


    // OUTSIDE THE SWEEP IS BLANK PAPER, AND BLANK PAPER DESELECTS.
    //
    // The wheel sweeps 320 degrees, so a 40-degree wedge carries no
    // band, no arc and no label — and on a phone at deep zoom that
    // wedge is most of what is on the screen. This used to `return`
    // outright, which meant the one part of the chart a reader would
    // naturally tap to say "never mind" was the one part that could not
    // say it: the selection stayed, and everything else on the wheel
    // stayed dimmed to 0.35 with no way back short of the reset button.
    // Reported from an iPhone at 1049%: 「这个可以选中，但是按空白地方
    // 不能取消选中」.
    //
    // The fall-through at the end of this method has always cleared the
    // selection for a tap that hit nothing — inside the hub, or outside
    // the rim. This makes the empty wedge the same kind of nothing,
    // rather than a hole the gesture fell into before it could get
    // there.
    if (a - startRad > sweepRad) return nothing('outsideSweep');

    final rHub = side * _kHubFrac;
    final rBands = side * bandsFractionFor(side);
    final rRim = side * rimFractionFor(side);

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
    // THE RADIAL GATE THAT ADMITTED THE WINNING SPOKE, for the probe.
    //
    // A spoke has two ways in and they are not the same shape: the tick
    // (nine screen pixels around its own ring) or, once the label is
    // being drawn, the whole radial run of that label. Recording only
    // the tick reported every label-claimed answer as a mistake — 35 of
    // them at 196% on the first run — which is the instrument lying
    // about the code rather than measuring it.
    var bestSpokeCentre = 0.0;
    var bestSpokeHalfDepth = 0.0;
    // From the hub outward, not from the bands outward. The gate used
    // to start at `rBands - 6` because every tick was outside the band
    // stack; with the ticks moved onto their own rings, that gate
    // excluded the exact radii they now occupy and the spoke loop
    // never ran for them.
    if (r >= rHub - 6 && r <= rRim + 8) {
      final tol = r > 0 ? (9.0 / (_zoom * r)) : 0.05;
      _probeSpokeTol = tol;
      final ringOf = {
        for (var i = 0; i < streams.length; i++) streams[i].id: i
      };
      for (final s in spokes) {
        // The same radius the painter used. A tap rule that still
        // looked for every tick on one circle would have gone on
        // answering for marks that moved onto the rings — and the arcs
        // under those marks would have kept losing taps to a target
        // nothing is drawn at.
        final ring = ringOf[s.event.stream];
        final rOwn = ring == null
            ? scriptureLabelBase(rBands)
            : ringRadii(ring, streams.length, rHub, rBands).centre;
        final tickHalf = _pointerPx(kind) / _zoom;
        final atTick = (r - rOwn).abs() <= tickHalf;
        // THE TAP FOLLOWS THE INK. `s.label.rStart..rEnd` is the radial
        // run a spoke's TEXT occupies, and claiming it was right while
        // that text was on screen: the reader was aiming at a word.
        //
        // Once the names came off the canvas (2026-09-15) this became a
        // live defect rather than a stale line — an invisible bar
        // across the annulus, taking taps from the arcs under it, for a
        // label nobody can see. The arcs were already the smaller
        // target; that is the complaint 「我要按那个环而不是字」 that set
        // the precedence rule in the first place.
        final drawsName = wheelShowsEventText(
            zoom: _zoom, selected: s.event.id == _selectedId);
        final atLabel = drawsName &&
            r >= s.label.rStart - 6 / _zoom &&
            r <= s.label.rEnd + 6 / _zoom;
        if (!atTick && !atLabel) continue;
        // NORMALISED, not absolute: how far into its own target the
        // finger fell, 0 dead centre and 1 at the edge. That is what
        // makes it comparable with an arc's, whose target is a
        // different shape and a different size.
        final d = (a - s.label.angle).abs() / tol;
        if (d <= 1 && d < spokeScore) {
          bestSpoke = s;
          spokeScore = d;
          // Whichever gate let it in is the target it should be judged
          // against. When both do, the tick is the tighter claim and
          // the one the reader was aiming at.
          if (atTick) {
            bestSpokeCentre = rOwn;
            bestSpokeHalfDepth = tickHalf;
          } else {
            final lo = s.label.rStart - 6 / _zoom;
            final hi = s.label.rEnd + 6 / _zoom;
            bestSpokeCentre = (lo + hi) / 2;
            bestSpokeHalfDepth = (hi - lo).abs() / 2;
          }
        }
      }
    }

    // `s.title` is NOT the label. It is the string the painter drew,
    // and it is empty whenever the label would not have been legible —
    // which is precisely the spoke a reader hovers to ask about.
    _WheelHit spokeHit(_Spoke s) => answer(
          (
            id: s.event.id,
            label: s.event.titleFor(locale),
            open: () {
              _select(s.event.id);
              if (s.members.length > 1) {
                showCluster(context, s.members, data, locale, _select);
              } else {
                showEvent(context, s.event, data, locale);
              }
            },
          ),
          kind: 'spoke',
          a0: s.label.angle,
          a1: s.label.angle,
          centre: bestSpokeCentre,
          halfDepth: bestSpokeHalfDepth,
          halfAngle: _probeSpokeTol,
          inkHalf: bestSpokeHalfDepth,
        );

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
        // A rail mark has no drawn depth of its own, so its target is
        // the pointer, clipped to its share.
        if ((r - m.centre).abs() >
            _radialTarget(ink: 0, share: m.pitch / 2, kind: kind)) {
          continue;
        }
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
            return spokeHit(s);
          }
          final cohortId = '$kLineageArcPrefix${m.cohort.year}';
          return answer(
            (
              id: cohortId,
              label: yearLabel(m.cohort.year, locale),
              open: () {
                _select(cohortId);
                showCohort(context, m.cohort, locale);
              },
            ),
            kind: 'rail',
            a0: m.angle,
            a1: m.angle,
            centre: m.centre,
            halfDepth: _radialTarget(ink: 0, share: m.pitch / 2, kind: kind),
            halfAngle: math.max(9 / m.centre, 0.004),
            inkHalf: m.pitch / 2,
          );
        }
      }
    }

    if (r >= scriptureLabelBase(rBands) && r <= rRim && lives.isNotEmpty) {
      // RING FIRST, then angle — the ring the finger is in is the only
      // ring it can mean, and that has always been true here. What
      // changed on 2026-09-03 is the angle: it asked `a >= a0 && a <= a1`,
      // exact containment with no slack, while spokes and rail marks
      // both convert a finger into radians at the tapped radius.
      //
      // Measured, that was not a rounding matter. 61 of 86 arcs are
      // painted thinner than a 9 px finger at 700 px, 55 at 900, 39 even
      // at 1400 — and Zimri, Huldah, Ahaziah of Judah and Jehoahaz of
      // Judah are 0.00 px, each beginning and ending in the same year.
      // Those four could not be opened by tapping at any zoom on any
      // canvas. Reported as 「按也很难按到，打也打不开」, which is what half
      // a pixel of target feels like. `nearestArcAt` gives every arc at
      // least a finger and resolves overlaps by the nearer centre.
      final inRing = [
        for (final l in lives)
          if ((r - l.centre).abs() <=
              _radialTarget(
                  ink: l.stroke / 2, share: l.pitch / 2, kind: kind))
            l
      ];
      final pick = nearestArcAt(
          a, r, [for (final l in inRing) (a0: l.arc.a0, a1: l.arc.a1)],
          fingerPx: _fingerPx);
      if (pick != null) {
        final l = inRing[pick.index];
        {
          final into = pick.score;
          // The one place the two shapes are compared.
          if (bestSpoke case final s? when spokeScore < into) {
            return spokeHit(s);
          }
          return answer(
            (
              id: l.id,
              // `l.name` is what the arc could print; `l.fullName` is
              // what the record is called. 亚们 has the second and not
              // the first — see [_Life.fullName].
              label: l.fullName,
              open: () {
                _select(l.id);
                final man = l.man;
                final king = l.king;
                final ministry = l.ministry;
                if (man != null) {
                  showPatriarch(context, man, locale);
                } else if (king != null) {
                  showKing(context, king, locale);
                } else if (ministry != null) {
                  showMinistry(context, ministry, locale);
                }
              },
            ),
            kind: 'life',
            a0: l.arc.a0,
            a1: l.arc.a1,
            centre: l.centre,
            halfDepth: _radialTarget(
                ink: l.stroke / 2, share: l.pitch / 2, kind: kind),
            halfAngle: fingerHalfWidth(r, fingerPx: _fingerPx),
            inkHalf: l.stroke / 2,
          );
        }
      }
    }

    // No arc took it, so a spoke that was in range does.
    if (bestSpoke case final s?) {
      return spokeHit(s);
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
      // Same change as the life arcs above, for the same reason: a power
      // band's angular extent is its span, and plenty of spans on this
      // chart are a few years inside six thousand. Exact containment
      // made those unreachable too.
      // Against the arc's own LAYER, and with a tolerance that is
      // still a whole ring's pitch: the layers are thinner than a
      // finger, so a tap near one has to reach it. Which of the
      // candidates wins is `nearestArcAt`'s question, and it answers it
      // by containment first — see its doc.
      // EACH ARC IS ASKED ABOUT ITS OWN LAYER, and only that.
      //
      // This was two pools. The first held the arcs whose own layer the
      // finger was in; the second, consulted when the first had nothing
      // at this angle, held every arc within HALF A RING — which is how
      // a point in the gap between two layers came to be handed a band
      // from some other layer entirely. Measured at 4050%: more than
      // half of every answer came from air, up to 175 screen pixels past
      // the edge of the ink it named.
      //
      // The second pool existed for a good reason — 「the layers are
      // thinner than a finger, so a tap near one has to reach it」 — and
      // [_radialTarget] now serves that reason directly by never letting
      // a target be thinner than the pointer. With it, the pools
      // collapse into one: a layer's target is at most its own share, so
      // adjacent layers tile the ring exactly and at most one of them
      // can contain any point. There is nothing left for a fallback to
      // resolve.
      //
      // The 2026-09-16 defect this replaces — 「tapping 以拦 opened
      // whatever short span happened to be nested three layers away」 —
      // cannot recur for the same reason: an arc three layers away is
      // three shares away, and no share reaches past its own.
      double targetOf(_Arc arc) {
        final tier = tierRadii(arc.ring, streams.length, rHub, rBands,
            tier: arc.tier, tiers: arc.tiers);
        return _radialTarget(
          ink: tier.width / 2,
          share: pitch / (2 * math.max(1, arc.tiers)),
          kind: kind,
        );
      }

      double offRing(_Arc arc) => (r -
              tierRadii(arc.ring, streams.length, rHub, rBands,
                      tier: arc.tier, tiers: arc.tiers)
                  .centre)
          .abs();
      final candidates = [
        for (final arc in arcs)
          if (offRing(arc) <= targetOf(arc)) arc
      ];
      final pick = nearestArcAt(
          a, r, [for (final arc in candidates) (a0: arc.a0, a1: arc.a1)],
          fingerPx: _fingerPx);
      if (pick != null) {
        final arc = candidates[pick.index];
        // A TICK ON THIS BAND IS A SMALLER TARGET THAN THE BAND.
        //
        // A conflict that could not exist until 2026-09-15: event ticks
        // sat at one radius outside the whole band stack, so nothing
        // was ever under one. They are on their own stream's ring now,
        // which means a finger inside a power's arc can also be inside
        // one of that power's ticks.
        //
        // NESTED TARGETS, so the smaller one wins inside itself.
        //
        // Not the "whichever the finger fell further into" comparison
        // the lifespan and rail branches use, and the difference is
        // structural rather than a preference. Those compare targets at
        // DIFFERENT RADII — a mark on one sub-ring against an arc on
        // another — where asking which the finger is deeper inside is
        // the only fair question, and where a written-down precedence
        // was what sent the arcs' taps to the labels 「我要按那个环而不是
        // 字」.
        //
        // A tick and its band are not like that. The tick sits ON the
        // arc, at the same radius, strictly inside it. Scoring the arc
        // by distance from its own angular centre — the first thing
        // tried here — reads a tap near the end of a long span as
        // barely on target at all, and handed the Hospitallers' band to
        // a Wycliffe tick three hundred years away.
        //
        // The band stays reachable because a tick's claim is only the
        // nine pixels around it, and because that claim is measured in
        // SCREEN pixels: zooming pulls the ticks apart and opens the
        // band between them.
        if (bestSpoke case final s? when spokeScore <= 1) {
          return spokeHit(s);
        }
        return answer(
          (
            id: arc.power.id,
            label: arc.power.nameFor(locale),
            open: () {
              _select(arc.power.id);
              showPower(context, arc.power, data, locale, _select);
            },
          ),
          kind: 'power',
          a0: arc.a0,
          a1: arc.a1,
          centre: tierRadii(arc.ring, streams.length, rHub, rBands,
                  tier: arc.tier, tiers: arc.tiers)
              .centre,
          halfDepth: targetOf(arc),
          halfAngle: fingerHalfWidth(r, fingerPx: _fingerPx),
          inkHalf: tierRadii(arc.ring, streams.length, rHub, rBands,
                      tier: arc.tier, tiers: arc.tiers)
                  .width /
              2,
        );
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
      // AND ONLY IF THAT STREAM IS ACTUALLY THERE.
      //
      // 2026-09-16 「我要按这空白处，却显示这个，experience就很不好」 — a
      // press on an empty part of the disc opened 犹大 with five powers
      // and forty-seven events in it. The radius rounds into SOME ring
      // wherever it lands between the hub and the bands, so a tap on
      // blank paper was being read as a question about whichever ring
      // happened to be nearest, and answered with everything that ring
      // has ever held.
      //
      // A ring is a thing to ask about where it HAS something at the
      // year under the finger. Where it does not, the press is what the
      // page already says it is — 「点一下图表，读出那一年」 — and the
      // year cursor, which the Listener has already placed, is the
      // whole answer.
      // A finger's worth of padding at this radius, the same allowance
      // `nearestArcAt` gives every arc, so a hairline span is still
      // something a reader can be asking about.
      final pad = fingerHalfWidth(math.max(r, 1), fingerPx: _fingerPx);
      // AND ONLY IF THE POINT IS ON THAT RING, not merely nearest to it.
      //
      // `best` is the nearest ring centre and nothing more — the loop
      // above has no radial bound at all, by design, so that the
      // outermost and innermost edges of the annulus round INTO their
      // band. At 100% that rounds over a pixel or two. At 4050% it
      // rounds over two hundred, and every one of those pixels answered
      // with a stream the reader was nowhere near.
      final onRing = best >= 0 &&
          (r - ringRadii(best, streams.length, rHub, rBands).centre).abs() <=
              _radialTarget(
                ink: ringRadii(best, streams.length, rHub, rBands).width / 2,
                share: ringPitch(streams.length, rHub, rBands) / 2,
                kind: kind,
              );
      // STANDING ON THE BAND IS ENOUGH. It did not use to be: this
      // also required a power arc within `pad` of the angle, and that
      // requirement was right when it was written (2026-09-16, 「我要按
      // 这空白处，却显示这个，experience就很不好」 — a press on an empty
      // part of the disc opening 犹大 with forty-seven events) because
      // there was then NO radial bound at all. Any point between the
      // hub and the bands rounded into the nearest ring, so "is there
      // an arc at this angle" was the only thing standing between blank
      // paper and an answer.
      //
      // `onRing` is that bound now, and it is the better one: it asks
      // whether the point is on the ring's own INK. So the angular
      // requirement had stopped guarding anything and had started
      // costing. Measured at 4050% across eight camera positions: 144
      // of 193 silent points in one, 269 of 325 in another, were
      // standing on a band that is plainly painted under the pointer.
      // 「有时候在这根线上却不会出现圈圈」 — that is this, and it is most
      // of the silence at that zoom.
      //
      // A stream's band is drawn across the whole sweep whether or not
      // a power sits there. If it is painted, it can be asked about.
      final under = !onRing || best < 0
          ? null
          : arcs
              .where((arc) =>
                  arc.ring == best && a >= arc.a0 - pad && a <= arc.a1 + pad)
              .firstOrNull;
      if (onRing && best >= 0) {
        final stream = streams[best];
        return answer(
          (
            id: stream.id,
            label: stream.nameFor(locale),
            open: () {
              _select(stream.id);
              showStream(context, stream, data, locale, _select);
            },
          ),
          kind: 'stream',
          // The shape claimed is the arc under the pointer when there
          // is one — that is the more specific truth and the better
          // outline — and otherwise the band itself, which is what is
          // painted there and what the answer is actually about.
          a0: under?.a0 ?? startRad,
          a1: under?.a1 ?? startRad + sweepRad,
          centre: ringRadii(best, streams.length, rHub, rBands).centre,
          halfDepth: _radialTarget(
            ink: ringRadii(best, streams.length, rHub, rBands).width / 2,
            share: ringPitch(streams.length, rHub, rBands) / 2,
            kind: kind,
          ),
          halfAngle: pad,
          inkHalf: ringRadii(best, streams.length, rHub, rBands).width / 2,
        );
      }
    }
    // WAS THE POINTER ON INK WHEN THIS SAID NOTHING?
    //
    // 2026-09-17 「有时候在这根线上却不会出现圈圈」. Silence is the right
    // answer over air and the wrong one over a painted band, and the
    // two are indistinguishable from the outside — which is why this
    // asks the question at the moment it gives up, rather than leaving
    // it to be argued about later.
    final onArcInk = arcs.any((arc) {
      final tier = tierRadii(arc.ring, streams.length, rHub, rBands,
          tier: arc.tier, tiers: arc.tiers);
      return (r - tier.centre).abs() <= tier.width / 2 &&
          a >= arc.a0 &&
          a <= arc.a1;
    });
    // And the second kind of ink, which is the one the report is most
    // likely about: a STREAM's own band is painted across the whole
    // sweep — the hatched stretches — whether or not it has a power
    // there. Standing on that and being told nothing is the same
    // surprise, from a different rule.
    var onRingInk = false;
    for (var i = 0; i < streams.length; i++) {
      final ring = ringRadii(i, streams.length, rHub, rBands);
      if ((r - ring.centre).abs() <= ring.width / 2) {
        onRingInk = true;
        break;
      }
    }
    return nothing(onArcInk
        ? 'nothingButOnArcInk'
        : onRingInk
            ? 'nothingButOnRingInk'
            : 'nothingUnderIt');
  }
}

/// A cached single-line paragraph with the small interface the painter
/// needs. Width is the shaped intrinsic width, because the paragraph is
/// laid out without wrapping and its constraint width is infinite.
class _WheelText {
  _WheelText(String text, TextStyle style)
      : paragraph = WheelTextMetrics.paragraphOf(text, style);

  final ui.Paragraph paragraph;
  double get width => paragraph.maxIntrinsicWidth;
  double get height => paragraph.height;
  void paint(Canvas canvas, Offset offset) =>
      canvas.drawParagraph(paragraph, offset);
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
    required this.rangeStart,
    required this.rangeEnd,
    required this.wb,
    required this.zoom,
    required this.symbols,
    required this.rimFont,
    required this.endFont,
    required this.bandFont,
    required this.visible,
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
  final int? rangeStart;
  final int? rangeEnd;
  final WbColors wb;

  /// Decoded silhouettes by asset name, empty until they load.
  final Map<String, ui.Image> symbols;

  /// What the reader can see, in canvas units; null before the first
  /// layout. See [_RadialChronologyPageState._visibleCanvasRect].
  final Rect? visible;

  /// Passed through wheelLabelScale: screen type grows to twice its
  /// resting size, then further zoom buys additional detail.
  final double zoom;

  final double rimFont;
  final double endFont;
  final double bandFont;

  /// Every level label already inked, this frame.
  ///
  /// ONE list for the arc names, the ring names and the record names,
  /// because they are all rectangles on the same canvas and the reader
  /// does not care which method drew which. Keeping three separate
  /// declutters would let a power's name land squarely on a record's.
  final List<Rect> _inked = [];

  /// The canvas edge, in scene units, as of this frame.
  ///
  /// `_side / zoom` is therefore what the reader can SEE, and that is
  /// the number a label placement has to answer to: a name moved a
  /// quarter of a screen from its arc is still findable, and a name
  /// moved two screens is a name about something else.
  double _side = 0;

  bool _claim(Rect box) {
    final claim = box.inflate(math.max(2 / zoom, box.height * 0.3));
    if (_inked.any(claim.overlaps)) return false;
    _inked.add(claim);
    return true;
  }

  @override
  void paint(Canvas canvas, Size size) {
    WheelRenderStats.paints++;
    _inked.clear();
    if (streams.isEmpty) return;
    final side = math.min(size.width, size.height);
    _side = side;
    final c = Offset(size.width / 2, size.height / 2);
    final rHub = side * _kHubFrac;
    final rBands = side * bandsFractionFor(side);
    final rRim = side * rimFractionFor(side);

    _paintSurface(canvas, c, rHub, rRim);
    _paintCenturies(canvas, c, rHub, rRim);
    _paintGrooves(canvas, c, rHub, rBands);
    // BEFORE THE ARCS' OWN NAMES, and only once zoomed in.
    //
    // The declutter list is first-come-first-served, and when this ran
    // last the power names had already taken every free plate on a busy
    // ring — so 教会 went unnamed at 384% while the pointer was
    // answering 教会. Which name matters more is a real question and it
    // has a zoom-dependent answer: at rest the ring is obvious from the
    // anchored label at the side and a power's name is the useful one;
    // zoomed in, the ring has become the thing the reader has lost
    // track of. There is at most one of these per ring per viewport, so
    // what it costs the arcs is about twenty small plates.
    // BOTH KINDS OF RING NAME BEFORE THE ARCS' OWN, for one reason:
    // whichever way a ring is named, that name is the reader's answer
    // to "where am I", and the declutter list is first-come-first-
    // served. Measured at 196%: with the arcs claiming first, NOT ONE
    // ring was named anywhere on the screen — every anchored label had
    // lost its plate to a power name — while the pointer was by then
    // answering 犹大 and 圣经.
    _repeatBandNames(canvas, c, rHub, rBands);
    _paintArcs(canvas, c, rHub, rBands);
    _paintBandNames(canvas, c, rHub, rBands, rRim);
    _paintStreamSymbols(canvas, c, rHub, rBands);
    // Lifespans remain a lighter layer than power bands. At overview
    // the explorer carries event titles; zooming restores radial text
    // over this same tint without changing its meaning.
    _paintLifespans(canvas, c, rBands, rRim);
    _paintRail(canvas, c);
    _paintSpokes(canvas, c, rHub, rBands);
    _paintRim(canvas, c, rBands, rRim);
    _paintHub(canvas, c, rHub);
    _paintAxisEnds(canvas, c, rHub, rRim);
    WheelRenderStats.labelsDrawn = _inked.length;
  }

  void _paintSurface(Canvas canvas, Offset c, double rHub, double rRim) {
    final surface = Rect.fromCircle(center: c, radius: rRim);
    // One soft surface gives the rings a common ground without adding
    // live 3D, image assets or an extra rendering dependency.
    canvas.drawCircle(
        c,
        rRim,
        Paint()
          ..shader = ui.Gradient.radial(c, rRim, [
            wb.paneBg,
            Color.lerp(wb.paneBg, wb.paneAltBg, 0.65)!,
          ]));
    final from = rangeStart;
    final to = rangeEnd;
    if (from == null || to == null) return;
    final a0 = angleForSpan(from, kMinYear, kMaxYear);
    final a1 = angleForSpan(to, kMinYear, kMaxYear);
    canvas.drawArc(surface, a0, a1 - a0, true,
        Paint()..color = wb.accent.withValues(alpha: 0.09));
    for (final angle in [a0, a1]) {
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
          c + direction * rHub,
          c + direction * rRim,
          Paint()
            ..color = wb.accent.withValues(alpha: 0.5)
            ..strokeWidth = 1 / zoom);
    }
  }

  void _paintCenturies(Canvas canvas, Offset c, double rHub, double rRim) {
    final minor = Paint()
      ..color = wb.border.withValues(alpha: 0.10)
      ..strokeWidth = 0.5 / zoom;
    final major = Paint()
      ..color = wb.border.withValues(alpha: 0.35)
      ..strokeWidth = 0.8 / zoom;
    for (var y = kMinYear; y <= kMaxYear; y += 100) {
      if (y == kMinYear) continue;
      final isMajor = y % 500 == 0;
      if (!isMajor && zoom < 1.6) continue;
      final a = angleForSpan(y, kMinYear, kMaxYear);
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * rHub, c + dir * rRim, isMajor ? major : minor);
    }
    // Tick labels remain outside the rim. On a phone the first one can
    // meet the opening-year label, even when both fit inside the canvas;
    // the shared bounds check keeps the range ends and drops only words
    // that cannot clear them. The actual tick lines above remain intact.
    for (final l
        in _axisLabels(rRim, math.min(c.dx, c.dy)).where((l) => l.onRing)) {
      _ringLabel(canvas, c, l.text, l.angle, rRim, wb.mutedText,
          rimFont / _labelScale(zoom), math.min(c.dx, c.dy));
    }
  }

  List<AxisLabel> _axisLabels(double rRim, double halfSide) =>
      retainSeparatedWheelAxisLabels(
          canvasBounds: Rect.fromLTRB(-halfSide, -halfSide, halfSide, halfSide),
          labels: planAxisLabels(
            minYear: kMinYear,
            maxYear: kMaxYear,
            tickLabel: (y) => centuryTickLabel(y, locale),
            endLabel: (y) => yearLabel(y, locale),
            endSwing: kAxisEndSwing,
          ),
          gap: 4 / zoom,
          maxOnRing: axisLabelBudget(halfSide * 2),
          boundsOf: (label) {
            final tp = _painter(
                label.text,
                label.onRing ? wb.mutedText : wb.text,
                (label.onRing ? rimFont : endFont) / _labelScale(zoom));
            return placeWheelAxisLabel(
              angle: label.angle,
              width: tp.width,
              height: tp.height,
              rimRadius: rRim,
              clearance: kAxisLabelClearance,
              onRing: label.onRing,
              canvasHalf: halfSide,
              endpointGap: 4 / zoom,
            ).bounds;
          });

  /// A label lying along the ring outside the rim, centred on [angle],
  /// its inner edge on [innerEdge].
  ///
  /// Drawn as one straight run rather than character by character. The
  /// arc labels inside the wheel are bent glyph by glyph because they
  /// span whole eras; a year label spans six degrees, where bending
  /// would buy 0.6 canvas units of fidelity and cost every kerning pair
  /// in the string.
  void _ringLabel(Canvas canvas, Offset c, String text, double angle,
      double innerEdge, Color color, double size, double canvasHalf) {
    if (text.isEmpty) return;
    final tp = _painter(text, color, size);
    final placement = placeWheelAxisLabel(
      angle: angle,
      width: tp.width,
      height: tp.height,
      rimRadius: innerEdge,
      // The SAME clearance `_axisLabels` measured with. It used to pass
      // the clearance baked into `innerEdge` and 0 here; splitting them
      // meant the painter and the bounds check could disagree about
      // where a label is, which is how a label gets admitted at one
      // radius and drawn at another.
      clearance: kAxisLabelClearance,
      onRing: true,
      canvasHalf: canvasHalf,
    );
    final at = c + placement.centre;
    // A plate, because on a small wheel this label steps INSIDE the rim
    // and lands on the annulus rather than on clear paper. Only then —
    // outside the rim there is nothing under it to win against, and a
    // plate would be a box drawn for no reason.
    final box = Rect.fromCenter(
        center: at, width: tp.width + 6 / zoom, height: tp.height + 1 / zoom);
    if (placement.centre.distance < innerEdge) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              box, Radius.circular(WbMetrics.radiusControl / zoom)),
          Paint()..color = wb.paneBg.withValues(alpha: 0.86));
    }
    tp.paint(canvas, box.center - Offset(tp.width / 2, tp.height / 2));
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
            ..color = (colors[streams[i].id] ??
                    lineColor(streams[i].line, dark: wb.isDark))
                .withValues(alpha: 0.06));
    }
  }

  /// Paints [arcs] in the order `_buildArcs` already put them in: ring
  /// ascending, span descending within the ring.
  ///
  /// THE SAME ORDER SERVES TWO PURPOSES. Painted in the file's own data
  /// order, a long span painted after a short one buried it completely
  /// — every one of these arcs shared the same opacity, so
  /// whichever is drawn LAST wins the pixels underneath it, and the data
  /// is mostly containment: New Kingdom Egypt holds the Eighteenth
  /// Dynasty, Rome's empire holds its emperors. Painting longest-span
  /// first means the container goes down first and the short span
  /// nested inside it is drawn afterwards, on top, where it can be seen
  /// — which is also the order `_buildArcs` already needed for the
  /// names, so there is one sort instead of two.
  void _paintArcs(Canvas canvas, Offset c, double rHub, double rBands) {
    final has = selectedId != null;
    for (final arc in arcs) {
      // The arc's own LAYER of its stream's ring. `tiers` is 1 wherever
      // the ring was too thin to divide, and then this is exactly the
      // ring band it always was.
      final band = tierRadii(arc.ring, streams.length, rHub, rBands,
          tier: arc.tier, tiers: arc.tiers);
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
          ..color = arc.color.withValues(alpha: 0.64 * dim),
      );
      // Hairlines at the boundaries so adjacent spans read as separate.
      final edge = Paint()
        ..strokeWidth = 0.7 / zoom
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
              ..strokeWidth = 1 / zoom
              ..color = wb.text.withValues(alpha: 0.85));
      }
      // THE SELECTED POWER, AND NO OTHER. Every power used to print its
      // name along its own arc, which put text at every angle on a
      // circle: the owner's screenshot of `The Judges of Israel` bent
      // around the rim beside a fan of rotated `+N` badges is what that
      // looked like in practice. The names are all in the list beside
      // the chart; the one the list cannot answer for is "which arc did
      // I just tap", so that one is drawn — upright.
      if (wheelShowsEventText(zoom: zoom, selected: sel)) {
        // THE POWER'S OWN NAME, AT THE CANVAS SIZE — not `arc.name` at
        // `arc.nameSize`. Those two come from `planArcNames`, which
        // sizes a name to fit INSIDE its own arc without touching its
        // neighbours', and returns nothing when it cannot. That was the
        // right rule while every power printed its name at once; for a
        // single selected callout it is the wrong one, and measurably
        // so — at 900 px only 2 of the drawn powers in English clear
        // that fit, so tapping almost any arc would have lit it up and
        // told the reader nothing.
        //
        // A callout is allowed to be longer than the thing it points
        // at. There is exactly one on screen, so it cannot collide with
        // another, and it carries its own plate.
        _uprightArcLabel(canvas, c, band.centre, arc.power.nameFor(locale),
            arc.a0, arc.a1 - arc.a0, rimFont / _labelScale(zoom), dim);
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
      final fill =
          (0.34 + 0.66 * ((r.cohort.people.length - 1) / 7)).clamp(0.34, 1.0);
      final half = r.pitch * 0.5 * fill;
      final dir = Offset(math.cos(r.angle), math.sin(r.angle));
      canvas.drawLine(
        c + dir * (r.centre - half),
        c + dir * (r.centre + half),
        Paint()
          ..strokeWidth = (sel ? 1.8 : 1.0) / zoom
          ..color = lineageRailColor(dark: wb.isDark).withValues(alpha: alpha),
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
        ..strokeWidth = (sel ? 1.4 : 0.7) / zoom
        ..color = l.color.withValues(alpha: (alpha * 2).clamp(0.0, 1.0));
      for (final a in [l.arc.a0, l.arc.a1]) {
        final dir = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(c + dir * (l.centre - l.stroke * 0.62),
            c + dir * (l.centre + l.stroke * 0.62), tick);
      }
      // At fit size these short names read as texture around the rim.
      // As with events, selection or 1.6x zoom reveals the canvas name;
      // tap/search and the year digest keep the record and evidence
      // reachable at fit size, alongside its true duration and dot.
      if (l.name.isNotEmpty &&
          l.nameSize > 0 &&
          wheelShowsEventText(zoom: zoom, selected: sel)) {
        _uprightArcLabel(canvas, c, l.centre, l.name, l.nameA0, l.nameSweep,
            l.nameSize, sel ? 1.0 : 0.75);
      } else {
        // A NAMELESS ARC STILL SAYS IT IS SOMETHING. Reported with a
        // screenshot of two of these: 「很多就像一个线一样，按也很难按到，
        // 打也打不开」. The tap half is fixed (`nearestArcAt` gives every
        // arc at least a finger), but a target the reader cannot see is
        // not a target either — a bare two-tick bar reads as noise, not
        // as a record with a sheet behind it.
        //
        // A dot at the arc's own centre, NOT a widened arc. Painting a
        // seven-day reign as wide as a finger would make Zimri look like
        // twenty years on a chart whose whole claim is that width means
        // duration. The dot says "there is something here" without
        // saying anything false about how long it lasted, which is the
        // same bargain the spokes' `+n` badge already strikes.
        final mid = l.arc.a0 + l.arc.sweep / 2;
        canvas.drawCircle(
          c + Offset(math.cos(mid), math.sin(mid)) * l.centre,
          math.min(1.6 / zoom, l.stroke * 0.28),
          Paint()
            ..color = l.color.withValues(alpha: (alpha * 2.6).clamp(0.0, 1.0)),
        );
        // AND ITS NAME BESIDE THE DOT. 2026-09-16 「你看这个可以在后面显示
        // 而不是在那个框框内的是不是」, of 哈该 — 主前520 to 主前520, one
        // year wide, whose name lived only inside the panel a tap opened.
        //
        // `nameSize` is 0 here because the planner sizes a name to fit
        // INSIDE its own arc and this arc has no width to fit inside.
        // That is the right rule for a name printed along an arc and the
        // wrong one for a callout, which is what this is: it is set at
        // the canvas size, upright, and the walk in `_uprightArcLabel`
        // finds it somewhere free and draws a leader back to the mark.
        if (l.fullName.isNotEmpty &&
            wheelShowsEventText(zoom: zoom, selected: sel)) {
          _uprightArcLabel(canvas, c, l.centre, l.fullName, l.arc.a0,
              l.arc.sweep, rimFont / _labelScale(zoom), sel ? 1.0 : 0.7);
        }
      }
    }
    final chosen = _find(lives, (l) => l.id == selectedId);
    if (chosen == null) return;
    final rule = Paint()
      ..strokeWidth = 0.9 / zoom
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
  /// The bearing the ring names hang off, in radians.
  ///
  /// Left and a little up. Two reasons, and the second is the one that
  /// makes it work: the labels read left-to-right so they want to sit
  /// to the LEFT of what they point at, and the upper-left quadrant of
  /// this chart is empty in practice — the corpus begins at 4200 BC at
  /// twelve o'clock and fills clockwise, so the last quadrant a reader
  /// reaches is the one with the most room in it.
  static const double _kBandNameBearing = math.pi * 200 / 180;

  /// Each ring's name, beside ITS OWN RING, on a leader.
  ///
  /// What this replaces: all four names right-aligned against the
  /// vertical axis at `c.dy - band.centre`, which drew them as a
  /// stacked list floating near the hub. The owner's screenshots show
  /// the result — 以色列 / 犹大 / 教会 / 圣经 in a little column in the
  /// middle of the chart, naming four rings without saying which name
  /// belongs to which one. A legend that has to be decoded by counting
  /// inwards is not a legend.
  ///
  /// So each name now hangs off its own ring on a short leader, the way
  /// a callout on a printed diagram does. The natural y for each is
  /// where the bearing crosses that ring, which fans them apart — but
  /// only by `|sin| x pitch`, about 7 px at a 900 px canvas, so they
  /// are then pushed apart to a readable pitch. Pushed UPWARD, away
  /// from the data: the leader stretches instead, which is exactly what
  /// a leader is for.
  void _paintBandNames(
      Canvas canvas, Offset c, double rHub, double rBands, double rRim) {
    if (streams.isEmpty) return;
    // The disc's own left edge. A 390 px phone puts the outer ring's
    // anchor at about `c.dx - 85` and 以色列 is 38 px wide, so the plate
    // started 13 px OUTSIDE the rim — the labels were hanging off the
    // chart. Clamped here rather than by shrinking the type: the type
    // was just raised because it was too small, and a label that has to
    // shrink to fit is the defect coming back in another form. The
    // leader stretches instead, which is what a leader is for.
    final leftEdge = c.dx - rRim + 2 / zoom;
    final dir =
        Offset(math.cos(_kBandNameBearing), math.sin(_kBandNameBearing));
    final gap = 3 / zoom;
    var ceiling = double.infinity;
    // Outermost first, so the push upward accumulates in one direction
    // and the ring closest to the rim keeps the y it was born with.
    for (var i = streams.length - 1; i >= 0; i--) {
      final band = ringRadii(i, streams.length, rHub, rBands);
      final colour =
          (colors[streams[i].id] ?? lineColor(streams[i].line, dark: wb.isDark))
              .withValues(alpha: 0.98);
      final tp = _WheelText(
        streams[i].nameFor(locale),
        canvasTextStyle(
          color: colour,
          fontSize: bandFont / _labelScale(zoom),
          fontWeight: FontWeight.w600,
        ),
      );
      final anchor = c + dir * band.centre;
      var y = anchor.dy;
      final pitch = tp.height + 4 / zoom;
      if (ceiling.isFinite && y > ceiling - pitch) y = ceiling - pitch;
      ceiling = y;
      final right = math.max(anchor.dx - 9 / zoom, leftEdge + tp.width);
      final box = Rect.fromLTWH(
          right - tp.width, y - tp.height / 2, tp.width, tp.height);
      // A plate, for the same reason the selected callout has one: a
      // level label crosses whatever it is over instead of following
      // it, and the quadrant is usually but not always empty.
      if (!_claim(box.inflate(gap))) continue;
      canvas.drawRRect(
          RRect.fromRectAndRadius(box.inflate(gap),
              Radius.circular(WbMetrics.radiusControl / zoom)),
          Paint()..color = wb.paneBg.withValues(alpha: 0.82));
      tp.paint(canvas, box.topLeft);
      // Recorded like the sticky copies, and for the same reason: an
      // audit of what the reader can see must see every place a ring is
      // named, or it reports a gap the chart does not have.
      WheelRenderStats.noteBandName(streams[i].nameFor(locale),
          box.center.dx - c.dx, box.center.dy - c.dy);
      // The leader: out to the label, then across to the ring. Two
      // segments rather than one diagonal, so it reads as a pointer and
      // not as another piece of data drawn on the chart.
      final elbow = Offset(right - 3 / zoom, y);
      canvas.drawLine(
          elbow,
          Offset(anchor.dx - 3 / zoom, y),
          Paint()
            ..strokeWidth = 0.8 / zoom
            ..color = colour.withValues(alpha: 0.55));
      canvas.drawLine(
          Offset(anchor.dx - 3 / zoom, y),
          anchor,
          Paint()
            ..strokeWidth = 0.8 / zoom
            ..color = colour.withValues(alpha: 0.55));
      canvas.drawCircle(anchor, 1.6 / zoom, Paint()..color = colour);
    }
  }

  /// The ring's name again, further round it, once the reader has zoomed
  /// past the point where the one anchored label is still on screen.
  ///
  /// 2026-09-16 「另外这里没有说是代表的什么像中国 之类的了」, of a ring
  /// filling the view with nothing to say whose it was. Every ring IS
  /// named — once, at a fixed bearing near the left of the disc, which
  /// at 574% is somewhere off the side of the window. A reader looking
  /// at a band cannot be asked to pan across the chart to find out what
  /// they are looking at.
  ///
  /// So the name repeats around its own ring, quietly, and only when
  /// zoomed in: at the resting zoom the single anchored label with its
  /// leader is right, and twelve copies of 教会 would be noise. The
  /// declutter list keeps each copy off everything else, so where a
  /// ring is busy the copy simply does not appear — the reader loses
  /// nothing they had.
  void _repeatBandNames(Canvas canvas, Offset c, double rHub, double rBands) {
    final v = visible;
    // WHEN THE ANCHORED LABEL HAS LEFT THE SCREEN, and not at some
    // number of percent.
    //
    // This used to open at `zoom < 2`, which was a guess at when the
    // one anchored label with its leader stops being enough. The guess
    // was wrong in a way a test found: at 196% nothing was named at
    // all, and the pointer was by then answering with rings. The real
    // condition is not a zoom, it is whether the reader can still see
    // the anchored label — so ask that, per ring, and the rest follows.
    // At rest the whole chart is visible, every anchor is on screen,
    // and no copy is drawn: exactly the behaviour this had before.
    final dir =
        Offset(math.cos(_kBandNameBearing), math.sin(_kBandNameBearing));
    for (var i = 0; i < streams.length; i++) {
      final band = ringRadii(i, streams.length, rHub, rBands);
      if (v != null && v.contains(c + dir * band.centre)) continue;
      final arc = _visibleArc(c, band.centre, v);
      if (arc == null) continue;
      final colour =
          (colors[streams[i].id] ?? lineColor(streams[i].line, dark: wb.isDark))
              .withValues(alpha: 0.75);
      final tp = _WheelText(
        streams[i].nameFor(locale),
        canvasTextStyle(
          color: colour,
          fontSize: bandFont / _labelScale(zoom),
          fontWeight: FontWeight.w600,
        ),
      );
      // WALK THE VISIBLE ARC UNTIL THERE IS ROOM.
      //
      // The midpoint alone is not enough, and the reason is geometric:
      // concentric rings share a centre, so every one of them computes
      // the SAME midpoint bearing, their labels stack up along one
      // radius, and the declutter list drops all but the first. Measured
      // at 753% on the five opening rings: two were named, and neither
      // was the ring the pointer was actually answering with.
      //
      // So the midpoint is the preference, not the demand. Candidates
      // spiral outward from it along the ring's own visible stretch, and
      // the first with room wins — which keeps every label inside the
      // viewport, keeps it on its own ring, and lets neighbours settle
      // side by side instead of on top of each other.
      Rect? placed;
      for (var step = 0; step <= 8 && placed == null; step++) {
        for (final dir in step == 0 ? const [0.0] : const [-1.0, 1.0]) {
          final t = (0.5 + dir * step / 18).clamp(0.0, 1.0);
          final at = arc.a0 + (arc.a1 - arc.a0) * t;
          final p = c + Offset(math.cos(at), math.sin(at)) * band.centre;
          final box = Rect.fromCenter(
              center: p,
              width: tp.width + 6 / zoom,
              height: tp.height + 2 / zoom);
          if (v != null && !v.contains(box.center)) continue;
          if (_claim(box)) {
            placed = box;
            break;
          }
        }
      }
      // Where a ring is genuinely too busy the copy still does not
      // appear, and the reader loses nothing they had.
      if (placed == null) continue;
      final box = placed;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              box, Radius.circular(WbMetrics.radiusControl / zoom)),
          Paint()..color = wb.paneBg.withValues(alpha: 0.7));
      tp.paint(canvas, box.center - Offset(tp.width / 2, tp.height / 2));
      // Recorded RELATIVE TO THE WHEEL'S CENTRE, which is the frame the
      // hit probe reports in. Absolute canvas coordinates here made the
      // first audit compare two different origins and report every name
      // as thousands of pixels away.
      WheelRenderStats.noteBandName(streams[i].nameFor(locale),
          box.center.dx - c.dx, box.center.dy - c.dy);
    }
  }

  /// The LONGEST STRETCH OF THIS RING THE READER CAN SEE, or null when
  /// they can see none of it.
  ///
  /// This is the whole of the sticky-label idea, and it is deliberately
  /// not a bearing from the eye to the ring. At every zoom level the
  /// controls produce, the camera is centred on the hub — so the eye IS
  /// the wheel's centre, every bearing from it is equally "where the
  /// reader is looking", and a label placed that way lands at an
  /// arbitrary angle that is usually off screen. Measured: it painted
  /// one ring name at 384% and none at 753%, worse than the twelve
  /// fixed bearings it replaced.
  ///
  /// A ring crosses the viewport in up to two stretches. Sampling finds
  /// them without the four-edge circle-rectangle algebra, and 512 steps
  /// across a 320-degree sweep is one sample every 0.6 degrees — finer
  /// than any label is wide. It runs once per repaint of a scene that
  /// only repaints when the camera moves, not per pointer event.
  ({double a0, double a1})? _visibleArc(Offset c, double radius, Rect? v) {
    if (v == null) {
      return (a0: startRad, a1: startRad + sweepRad);
    }
    const steps = 512;
    var bestStart = -1;
    var bestLen = 0;
    var runStart = -1;
    var runLen = 0;
    for (var k = 0; k <= steps; k++) {
      final a = startRad + sweepRad * k / steps;
      final p = c + Offset(math.cos(a), math.sin(a)) * radius;
      if (v.contains(p)) {
        if (runStart < 0) runStart = k;
        runLen++;
        if (runLen > bestLen) {
          bestLen = runLen;
          bestStart = runStart;
        }
      } else {
        runStart = -1;
        runLen = 0;
      }
    }
    if (bestLen == 0) return null;
    return (
      a0: startRad + sweepRad * bestStart / steps,
      a1: startRad + sweepRad * (bestStart + bestLen - 1) / steps,
    );
  }

  /// One silhouette per ring, at the year that ring begins.
  ///
  /// WHERE, and why not somewhere more convenient. The symbol sits at
  /// the FIRST year the stream has a record for, inside its own band —
  /// so it marks an entry onto the chart rather than floating over the
  /// middle of a span. A reader scanning for "when does Egypt start"
  /// gets an answer from the mark itself.
  ///
  /// ONE PER RING. At most five rings are drawn, so at most five of
  /// these are ever on screen. The temptation is a symbol per power or
  /// per event; the corpus holds 1,039 marks and that would be the
  /// crowding complaint again in pictures instead of words.
  ///
  /// Tinted with the ring's own colour through `BlendMode.srcIn`: the
  /// assets are white-on-transparent silhouettes precisely so the one
  /// palette that already follows the reader's theme keeps deciding
  /// every colour on this canvas.
  void _paintStreamSymbols(
      Canvas canvas, Offset c, double rHub, double rBands) {
    if (symbols.isEmpty) return;
    for (var i = 0; i < streams.length; i++) {
      final image = symbols[symbolForStream(streams[i].id)];
      if (image == null) continue;
      final band = ringRadii(i, streams.length, rHub, rBands);
      // The earliest arc this ring actually draws. A ring with nothing
      // on it in the current range gets no symbol, which is right: the
      // mark would be pointing at an absence.
      double? first;
      for (final arc in arcs) {
        if (arc.ring != i) continue;
        if (first == null || arc.a0 < first) first = arc.a0;
      }
      if (first == null) continue;
      // Kept inside the band and off the hairline, and never larger
      // than it would be at rest: a silhouette blown up to 40 px at
      // 4000% zoom is an obstruction, not a label.
      final size = math.min(band.width * 0.78, 22 / zoom);
      if (size <= 1) continue;
      final dir = Offset(math.cos(first), math.sin(first));
      final centre = c + dir * band.centre;
      final colour =
          colors[streams[i].id] ?? lineColor(streams[i].line, dark: wb.isDark);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromCenter(center: centre, width: size, height: size),
        Paint()
          ..isAntiAlias = true
          ..filterQuality = FilterQuality.medium
          ..colorFilter = ColorFilter.mode(colour, BlendMode.srcIn),
      );
    }
  }

  void _paintSpokes(Canvas canvas, Offset c, double rHub, double rBands) {
    final has = selectedId != null;
    final ringOf = {for (var i = 0; i < streams.length; i++) streams[i].id: i};
    // The tick sits ON THE BAND, for every event, whichever end of the
    // annulus its words are flush with. That is what it is for — the
    // year's mark on its own stream — and it is now the only thing
    // drawn for an event whose title could not be set legibly at this
    // size, so it must be where the event belongs rather than where its
    // text happens to start.
    // A record's mark belongs ON THE STREAM IT BELONGS TO.
    //
    // Every event tick used to sit at `scriptureLabelBase(rBands)` —
    // one radius, just outside the whole band stack — so 291 of them
    // were threaded onto a single circle and the only thing saying
    // which stream a mark came from was its colour. That is the
    // colour-matching problem the ring cap was meant to reduce, being
    // reintroduced by the densest element on the chart.
    //
    // On its own ring, POSITION carries the stream and colour only
    // confirms it, and the marks spread across four rings instead of
    // crowding one circle.
    //
    // The fallback is for a spoke whose stream is not drawn — a
    // clustered event borrowed from a hidden layer. It keeps the old
    // radius rather than guessing a ring.
    final fallbackTick = scriptureLabelBase(rBands);
    // The selected record first, so it is never the one that loses a
    // collision with a neighbour the reader did not choose.
    final ordered = [
      for (final s in spokes)
        if (s.event.id == selectedId) s,
      for (final s in spokes)
        if (s.event.id != selectedId) s,
    ];
    for (final s in ordered) {
      final ring = ringOf[s.event.stream];
      final band =
          ring == null ? null : ringRadii(ring, streams.length, rHub, rBands);
      final rTick = band?.centre ?? fallbackTick;
      final sel = s.event.id == selectedId;
      final lit = selectionCovers(
        selectedId: selectedId,
        ownId: s.event.id,
        streamId: s.event.stream,
      );
      final dim = has && !lit ? 0.28 : 1.0;
      final a = s.label.angle;
      final dir = Offset(math.cos(a), math.sin(a));
      // A NOTCH ACROSS ITS OWN BAND, not a stub beside it. On its own
      // ring the tick now sits on a fill of its own hue, so the old
      // `s.color at 0.8` had almost nothing to carry against — the
      // band is that colour at 0.64. Pulling the tick toward the
      // page's ink gives it a darker edge on a lighter band, which is
      // the same device the selected arc's outline uses.
      final half = (band?.width ?? 10) * 0.42;
      canvas.drawLine(
        c + dir * (rTick - half),
        c + dir * (rTick + half),
        Paint()
          ..strokeWidth = (sel ? 1.8 : 0.9) / zoom
          ..color = Color.lerp(s.color, wb.text, sel ? 0.7 : 0.45)!
              .withValues(alpha: (sel ? 1.0 : 0.85) * dim),
      );
      if (s.hidden > 0 && !wheelShowsEventText(zoom: zoom, selected: sel)) {
        // The "and more here" dot, moved out past its own band so it
        // reads as a count beside the mark rather than as another mark.
        canvas.drawCircle(c + dir * (rTick + half + 3 / zoom), 2 / zoom,
            Paint()..color = s.color.withValues(alpha: 0.85 * dim));
      }
      if (wheelShowsEventText(zoom: zoom, selected: sel)) {
        _uprightSpokeLabel(canvas, c, s, dim, sel, rTick + half);
      }
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
  /// One record's name, LEVEL, just outside its tick.
  ///
  /// 2026-09-16. What this replaces rotated every label to its own
  /// bearing, so a circle ended up with words pointing in every
  /// direction — the thing the owner photographed at 381% and 2474%.
  /// My first answer was to stop drawing them at all except for the
  /// selection, and the owner found what that costs within a day:
  /// 「你label没有的时候我都看不了对比了」, at 888% zoom, on a chart with no
  /// text on it anywhere. Zooming in is how a reader asks "what is
  /// this one", and the list beside the chart cannot answer it because
  /// it does not know where the finger is.
  ///
  /// So: the words are back, and they stand up.
  ///
  /// Placed the same way the year scale is — the box's near edge clears
  /// the tick, and its half-extent ALONG THE BEARING is what decides
  /// the radius, so a label at nine o'clock is pushed out by half its
  /// width and one at twelve by half its height. A plate, because a
  /// level label crosses the rings it is over instead of following one.
  ///
  /// And it may be refused. Level labels claim rectangles, and two
  /// rectangles can overlap at angles where two radial runs never
  /// would, so the last word on what gets ink is [occupied] — first
  /// come, selection first.
  void _uprightSpokeLabel(Canvas canvas, Offset c, _Spoke s, double dim,
      bool sel, double fromRadius) {
    if (s.title.isEmpty && s.badge.isEmpty) return;
    final size = rimFont / _labelScale(zoom);
    final style = canvasTextStyle(
      color: sel ? wb.text : wb.text.withValues(alpha: 0.95 * dim),
      fontSize: size,
      fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
    );
    final refStyle = canvasTextStyle(
      color: wb.link.withValues(alpha: 0.95 * dim),
      fontSize: size * _kRefSizeRatio,
    );
    // Muted ink and the verse's size, so it reads as a count of things
    // rather than as part of the name it follows: `+65` after *Boxer
    // Uprising Martyrdoms* must not look like a title.
    final badgeStyle = canvasTextStyle(
      color: wb.mutedText.withValues(alpha: 0.95 * dim),
      fontSize: size * _kRefSizeRatio,
    );
    final tp = s.title.isEmpty ? null : _WheelText(s.title, style);
    final refTp = s.ref.isEmpty ? null : _WheelText(' ${s.ref}', refStyle);
    final badgeTp =
        s.badge.isEmpty ? null : _WheelText(' ${s.badge}', badgeStyle);
    final width =
        (tp?.width ?? 0) + (refTp?.width ?? 0) + (badgeTp?.width ?? 0);
    final height = math.max(
        tp?.height ?? 0, math.max(refTp?.height ?? 0, badgeTp?.height ?? 0));
    if (width <= 0 || height <= 0) return;

    final a = s.label.angle;
    final dir = Offset(math.cos(a), math.sin(a));
    final reach = (width / 2) * dir.dx.abs() + (height / 2) * dir.dy.abs();
    final centre = c + dir * (fromRadius + 5 / zoom + reach);
    final box = Rect.fromCenter(
        center: centre, width: width + 6 / zoom, height: height + 2 / zoom);
    if (!_claim(box)) return;

    canvas.drawRRect(
        RRect.fromRectAndRadius(
            box, Radius.circular(WbMetrics.radiusControl / zoom)),
        Paint()..color = wb.paneBg.withValues(alpha: sel ? 0.94 : 0.86));
    var x = centre.dx - width / 2;
    final top = centre.dy;
    if (tp != null) {
      tp.paint(canvas, Offset(x, top - tp.height / 2));
      x += tp.width;
    }
    if (refTp != null) {
      refTp.paint(canvas, Offset(x, top - refTp.height / 2));
      x += refTp.width;
    }
    badgeTp?.paint(canvas, Offset(x, top - badgeTp.height / 2));
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
            ..strokeWidth = w / zoom
            ..color = wb.border.withValues(alpha: alpha));
    }
  }

  /// The name of ONE arc, set level, centred on the arc it belongs to.
  ///
  /// What this replaces: `_charsOnArc`, which laid every name out one
  /// character at a time around the ring, each glyph rotated to its own
  /// tangent. That is why the chart had words running in four
  /// directions at once, and it is also where its frames went — the
  /// per-character path ran on the order of 8,000 times a frame across
  /// the powers, the lifespans and the reigns.
  ///
  /// Only the SELECTED arc reaches here now, so one level line of text
  /// replaces thousands of rotated glyphs. It is drawn on a soft plate
  /// of the pane's own colour, because a level label crosses its band
  /// rather than following it and has to win against the fill beneath.
  void _uprightArcLabel(Canvas canvas, Offset c, double radius, String text,
      double a0, double sweep, double fontSize, double dim) {
    // A SPAN OF ZERO IS STILL A RECORD. 2026-09-16 「你看这个可以在后面显
    // 示而不是在那个框框内的是不是」, of 哈该 — 主前520 to 主前520, one
    // year, drawn as a mark with no width. `sweep <= 0` sent it home
    // with no name at all, so the only way to learn what the mark was
    // was to tap it and read the panel. It gets a name like everything
    // else now; the walk below finds it somewhere free.
    if (sweep < 0 || fontSize <= 0 || text.isEmpty) return;
    WheelRenderStats.noteLabelAsked(text);
    final tp = _painter(text, wb.text.withValues(alpha: 0.98 * dim), fontSize);
    final mid = a0 + sweep / 2;
    final centre = c + Offset(math.cos(mid), math.sin(mid)) * radius;
    final w = tp.width + 8 / zoom;
    final h = tp.height + 3 / zoom;
    var box = Rect.fromCenter(center: centre, width: w, height: h);
    Offset? leader;
    if (!_claim(box)) {
      // ALONG THE RING, RATHER THAN NOT AT ALL.
      //
      // 2026-09-16 「这种也是后面有位置就应该可以放label」 and 「这个后面
      // 应该可以有label的吧」, both of short reigns with a screenful of
      // empty chart beside them. A name centred on a three-year span
      // lands on its neighbour's name and this used to give up — so the
      // short records, which are the ones a reader most needs named,
      // were the ones that lost their names.
      //
      // It walks its OWN ring, forward first, because 「后面」 is where
      // the reader is looking, and it draws a leader back to the arc
      // whenever it had to move: a name away from the thing it names
      // is only honest if it says which thing.
      // And OUT OF the ring when the lane itself is full, which is the
      // case the ring walk could not answer: 亚们 has 玛拿西 against one
      // end and 约西亚 against the other, so six box-widths either way
      // is still inside somebody else's name. See [arcLabelDetours] for
      // why outward is the safer of the two moves.
      // HOW FAR A LEADER MAY REACH. 2026-09-16, from a phone at 235%:
      // 「手机上看就很恐怖了」 — names standing over the empty middle of
      // the disc with a hairline running off to something near the rim.
      // The walk was six box-widths either way, and a box-width is the
      // NAME's width: 「Joshua son of Nun」 at the canvas size is about
      // 120 px, so six of them is 720 px — nearly twice the width of a
      // phone. A leader is only honest if the reader can follow it, so
      // the reach is a fraction of what is actually on screen.
      final reach = _side > 0 ? _side / zoom * 0.14 : double.infinity;
      final step = w / (radius > 1 ? radius : 1);
      final along = reach.isFinite ? (reach / w).floor().clamp(1, 6) : 6;
      final out = reach.isFinite
          ? (reach / (h * 1.25)).floor().clamp(1, 3)
          : 3;
      var moved = false;
      for (final m in arcLabelDetours(
          step: step, rowStep: h * 1.25, along: along, out: out)) {
        final at = mid + m.dAngle;
        if (at < startRad || at > startRad + sweepRad) continue;
        final r = radius + m.dRadius;
        if (r <= 0) continue;
        final p = c + Offset(math.cos(at), math.sin(at)) * r;
        final candidate = Rect.fromCenter(center: p, width: w, height: h);
        if (_claim(candidate)) {
          box = candidate;
          leader = centre;
          moved = true;
          break;
        }
      }
      if (!moved) {
        WheelRenderStats.noteLabelLost(text);
        return;
      }
    }
    if (leader case final from?) {
      canvas.drawLine(
          from,
          box.center,
          Paint()
            ..strokeWidth = 0.7 / zoom
            ..color = wb.mutedText.withValues(alpha: 0.5 * dim));
    }
    canvas.drawRRect(
        // The app's own control radius, divided by the zoom for the same
        // reason every stroke width on this canvas is: a 5-unit corner
        // at 4000% would be a 200 px bubble.
        RRect.fromRectAndRadius(
            box, Radius.circular(WbMetrics.radiusControl / zoom)),
        Paint()..color = wb.paneBg.withValues(alpha: 0.86 * dim));
    tp.paint(canvas, box.center - Offset(tp.width / 2, tp.height / 2));
  }

  void _paintHub(Canvas canvas, Offset c, double rHub) {
    canvas.drawCircle(c, rHub, Paint()..color = wb.paneAltBg);
    canvas.drawCircle(
        c,
        rHub,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 / zoom
          ..color = wb.border);
  }

  void _paintAxisEnds(Canvas canvas, Offset c, double rHub, double rRim) {
    final paint = Paint()
      ..color = wb.border
      ..strokeWidth = 1 / zoom;
    for (final l
        in _axisLabels(rRim, math.min(c.dx, c.dy)).where((l) => !l.onRing)) {
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
      final placement = placeWheelAxisLabel(
        angle: la,
        width: tp.width,
        height: tp.height,
        rimRadius: rRim,
        clearance: kAxisLabelClearance,
        onRing: false,
        endpointGap: 4 / zoom,
        canvasHalf: math.min(c.dx, c.dy),
      );
      tp.paint(
          canvas, c + placement.centre - Offset(tp.width / 2, tp.height / 2));
    }
  }

  /// A laid-out run. Everything outside the hub now needs the SIZE of
  /// its text before it can decide where the text goes, so measuring
  /// and painting are two steps rather than one.
  _WheelText _painter(String text, Color color, double size) {
    WheelRenderStats.noteLabelSize(size);
    return _WheelText(text, canvasTextStyle(color: color, fontSize: size));
  }

  /// Scene lists are reused until their inputs change. Identity catches
  /// same-count stream swaps and costs one comparison per list; counting
  /// entries alone once left the genealogy toggle visually unchanged.
  /// Every field stays explicit for wheel_repaint_coverage_test.dart.
  @override
  bool shouldRepaint(_WorldWheelPainter old) =>
      old.selectedId != selectedId ||
      old.locale != locale ||
      old.rangeStart != rangeStart ||
      old.rangeEnd != rangeEnd ||
      old.streams != streams ||
      old.arcs != arcs ||
      old.spokes != spokes ||
      old.lives != lives ||
      old.rail != rail ||
      old.colors != colors ||
      old.wb != wb ||
      old.zoom != zoom ||
      old.symbols != symbols ||
      old.rimFont != rimFont ||
      old.endFont != endFont ||
      old.bandFont != bandFont ||
      // THE CAMERA MOVING IS A REASON TO REPAINT, now that a label's
      // position depends on where the reader is looking. Without this
      // the ring names would be laid out once and then slide off with
      // the chart on every pan — the exact defect the sticky label was
      // written to remove, reintroduced by omission.
      //
      // `wheel_repaint_coverage_test` caught it, which is what that
      // test is for: a painter field that nothing compares is a stale
      // frame waiting to happen, and it never throws.
      old.visible != visible;
}

/// The year spoke — the wheel's own year cursor.
///
/// A LINE FROM HUB TO RIM, because on this chart year is angle and
/// nothing else: a cursor placed near the hub and one placed at the rim
/// on the same bearing name the same year, which is exactly the claim
/// `angleForSpan` makes. There is no radial component to a year here,
/// so there is none in the rule that marks one.
///
/// Its width divides by the zoom, the same way every label on this
/// chart divides by `_labelScale`. A 2 px rule at 4000% would be an
/// 80 px wedge covering about eight centuries — a mark claiming to be
/// exactly one year has to hold its ON-SCREEN width as the reader zooms
/// in, or it stops being true the further in they go.
class _YearSpokePainter extends CustomPainter {
  const _YearSpokePainter({
    required this.year,
    required this.side,
    required this.rHub,
    required this.rRim,
    required this.color,
    required this.zoom,
  });

  final int year;
  final double side;
  final double rHub;
  final double rRim;
  final Color color;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(side / 2, side / 2);
    final a = angleForSpan(year, kMinYear, kMaxYear);
    final dir = Offset(math.cos(a), math.sin(a));
    canvas.drawLine(
      c + dir * rHub,
      c + dir * (rRim + kAxisLabelClearance),
      Paint()
        ..color = color
        ..strokeWidth = 2 / zoom,
    );
    // A dot on the rim end. The line alone reads as one more century
    // tick at low zoom — `_paintCenturies` draws 62 of those — and the
    // dot is what says "this one is yours".
    canvas.drawCircle(
      c + dir * (rRim + kAxisLabelClearance),
      3 / zoom,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_YearSpokePainter old) =>
      old.year != year ||
      old.side != side ||
      old.rHub != rHub ||
      old.rRim != rRim ||
      old.color != color ||
      old.zoom != zoom;
}

/// The outline of the region a hover answer claims.
///
/// Drawn in canvas coordinates inside the zoomable child, so the shape
/// sits exactly on the ink it describes. Everything about its
/// APPEARANCE is divided by the zoom instead, so the line stays one
/// line however far the reader has gone in — a 1.5-unit stroke at
/// 4050% would be a sixty-pixel bar across the band it is meant to
/// outline.
///
/// The halo underneath is not decoration: these bands are twenty-two
/// different colours and a single-colour outline disappears into some
/// of them. Two strokes, the wider one in the panel's own background,
/// read on all of them.
class _ClaimOutlinePainter extends CustomPainter {
  const _ClaimOutlinePainter({
    required this.claim,
    required this.side,
    required this.zoom,
    required this.color,
    required this.halo,
  });

  final _HitShape claim;
  final double side;
  final double zoom;
  final Color color;
  final Color halo;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(side / 2, side / 2);
    final w = 1.6 / zoom;

    final path = claimOutlinePath(
      centre: c,
      a0: claim.a0,
      a1: claim.a1,
      radius: claim.centre,
      halfDepth: claim.halfDepth,
      zoom: zoom,
    );

    // LIGHT THE RECORD, DO NOT RING THE REGION.
    //
    // 2026-09-17, on Fable 5.1's reading of 「为什么很多没有做好」: a ring
    // drawn around a claim is a QA instrument. Nobody has a concept of
    // "the area this answer is about"; they have a concept of "that
    // band". An outline also reads as a NEW object on a chart that
    // already has too many, where a wash reads as the same object,
    // brighter.
    //
    // A wash and an edge, not one or the other: the wash says which
    // shape, the edge keeps it legible where the wash falls on a band
    // of a similar colour — there are twenty-two of those.
    final sector =
        claim.halfDepth >= 0.5 / zoom && (claim.a1 - claim.a0) >= 1e-4;
    if (sector) {
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.22));
    }
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = (sector ? w * 2.6 : w * 4.2)
          ..color = halo.withValues(alpha: 0.85));
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          // A mark with no area is lit by being DRAWN HEAVIER, which is
          // the only way to brighten something that has no inside.
          ..strokeWidth = sector ? w : w * 2
          ..color = color);
  }

  @override
  bool shouldRepaint(_ClaimOutlinePainter old) =>
      old.claim != claim ||
      old.side != side ||
      old.zoom != zoom ||
      old.color != color;
}
