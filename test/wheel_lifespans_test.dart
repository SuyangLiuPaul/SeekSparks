/// THE GENESIS LIFESPANS, BACK ON THE WHEEL AS ARCS.
///
/// Twenty-five lives, Adam to Moses, drawn in the label annulus from a
/// birth year to a death year. What this file exists to stop is not a
/// rendering fault; it is the ONE THING A READER MUST NEVER SEE, which
/// is the same man carrying two years. The arc and the birth spoke are
/// the same arithmetic — `_meta.creation.year` plus the Anno Mundi
/// figure — and if they are ever computed twice they will drift, so
/// they are joined here across all three assets.
///
/// The second thing it stops is a year appearing where scripture states
/// none. Genesis 4:17-24 gives Cain's line a city, wives, trades and a
/// boast, and not one age, interval or total. Nothing in this layer may
/// place any of them.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/chronology.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/models/hebrew_king.dart';
import 'package:seeksparks/pages/radial_chronology_page.dart'
    show RadialChronologyPage, kMinYear, kMaxYear, packWheelBand;
import 'package:seeksparks/services/hebrew_kings_service.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/chronology_service.dart';
import 'package:seeksparks/services/timeline_service.dart';
import 'package:seeksparks/utils/radial_chronology_layout.dart';
import 'package:seeksparks/utils/version_mapper.dart'
    show localizedReferenceLabel;
import 'package:seeksparks/utils/wheel_search.dart';

// The page's own geometry, restated because the fractions are private
// to it. `wheel_arc_label_behaviour_test.dart` does the same.
const double _bandsFrac = 0.285;
const double _rimFrac = 0.445;
const double _rimFontPx = 10.5;

/// The tradition the ARCS are drawn on. The Septuagint is printed on
/// every sheet and never drawn — see §5 of the ruling.
const String _drawn = 'mt';

const _family = 'Roboto';
const _fallback = ['NotoSansSC-Sub'];

Future<void> _loadFace(String family, String path) async {
  final loader = FontLoader(family)..addFont(rootBundle.load(path));
  await loader.load();
}

double _measureChars(String text, double size) {
  var total = 0.0;
  for (final ch in text.characters) {
    total += (TextPainter(
      text: TextSpan(
          text: ch,
          style: TextStyle(
              fontSize: size,
              color: const Color(0xFFFFFFFF),
              fontFamily: _family,
              fontFamilyFallback: _fallback)),
      textDirection: TextDirection.ltr,
    )..layout())
        .width;
  }
  return total;
}

double _measureLabel(String text, double size) => (TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              fontSize: size,
              color: const Color(0xFFFFFFFF),
              fontFamily: _family,
              fontFamilyFallback: _fallback)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout())
    .width;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> timelineRaw;
  late Map<String, dynamic> chronRaw;
  late ChronologyData chron;
  late WheelHistoryData wheel;
  late int creation;

  setUpAll(() async {
    timelineRaw =
        json.decode(File('assets/bible_timeline.json').readAsStringSync())
            as Map<String, dynamic>;
    chronRaw = json.decode(File('assets/chronology.json').readAsStringSync())
        as Map<String, dynamic>;
    // The page's own load path, so the caches the widget tests below
    // read from are the ones the app fills.
    wheel = await WheelHistoryService.instance.load();
    chron = await ChronologyService.instance.load();
    creation = TimelineService.instance.meta.creation!.year;
    await _loadFace('Roboto', 'assets/fonts/Roboto-VariableFont_wdth,wght.ttf');
    await _loadFace('NotoSansSC-Sub', 'assets/fonts/NotoSansSC-Sub.otf');
  });

  List<Map<String, dynamic>> events() =>
      (timelineRaw['events'] as List).cast<Map<String, dynamic>>();

  Map<String, dynamic> event(String id) =>
      events().firstWhere((e) => e['id'] == id);

  /// THE PAGE'S OWN PACKING, not a copy of it.
  ///
  /// This used to call `buildLifeArcs` here with its own arguments, and
  /// on 2026-09-02 that copy went wrong in the one way a copy can: the
  /// band gained the 42 reigns and the 39 ministries, `packIntoRings`
  /// repacked everything, and four tests in this file went on tapping
  /// the radii the OLD packing had put the patriarchs at — empty
  /// annulus, four failures, and nothing wrong with the app. Calling
  /// the page's function makes that class of failure unreachable.
  List<LifeArc> arcs() => packWheelBand(
        chron: chron,
        creationYear: creation,
        kings: HebrewKingsService.instance.cached?.kings ??
            const <HebrewKing>[],
        ministries: WheelHistoryService.instance.cached?.ministries ??
            const <WheelMinistry>[],
        tradition: _drawn,
        // The genealogy rail is on out of the box and owns the
        // innermost sub-ring, so the arcs start at ring 1. Passed here
        // because this file taps arcs at radii it computes, and the
        // app's default is the state it is testing.
        reservedInnerRings: 1,
      );

  /// The patriarchs alone, for the assertions that are about the
  /// Genesis figures rather than about where they are drawn.
  List<LifeArc> patriarchArcs() =>
      arcs().where((a) => chron.byId(a.id) != null).toList();

  // ── 1. the anchor, across three assets ─────────────────────────────

  /// THE ONE NUMBER, IN ONE PLACE. `chronology.json` counts in Anno
  /// Mundi; `bible_timeline.json` counts in BC; the wheel draws both on
  /// one circle. The join is `abram_called`, which is the year both
  /// chains meet at, and there was no test anywhere joining these two
  /// files before this one — `cross_asset_year_agreement_test.dart`
  /// joins only `hebrew_kings.json`. That gap is exactly what would let
  /// the arcs and the spokes drift.
  test('the creation year is the wheel own anchor carried up Genesis', () {
    final haran = (chronRaw['epochs'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((e) => e['id'] == 'haran');
    final expected = (event('abram_called')['year'] as num).toInt() -
        ((haran['years'] as Map)[_drawn] as num).toInt();
    expect(creation, expected,
        reason: 'the anchor arithmetic has gone stale — recompute it, do '
            'not copy the number out of the ruling');
    expect(creation, -4114);
    expect(TimelineService.instance.meta.creation!.basis, 'scripture+thiele');
  });

  /// The axis has to start before Adam and not wander away from him.
  /// 4200 BC is round — the century loop and the %500 label rule need
  /// no special case — and leaves 86 years of room, which is what the
  /// creation label and the first century tick need.
  test('the axis holds the creation without clamping it to the rim', () {
    expect(creation, greaterThan(kMinYear));
    expect(creation - kMinYear, inInclusiveRange(0, 199));
    // Clamping is the failure this guards: `angleForSpan` pins anything
    // below `minYear` to the start, which would state a year nobody
    // claims.
    expect(angleForSpan(creation, kMinYear, kMaxYear),
        greaterThan(angleForSpan(kMinYear, kMinYear, kMaxYear)));
  });

  // ── 2. an arc end never contradicts a spoke ────────────────────────

  /// A SPOKE SAYS WHEN AND AN ARC SAYS HOW LONG, and they must be the
  /// same arithmetic or the chart answers one question twice.
  /// THE JOIN IS BY ID NOW, AND IT IS BOTH SIMPLER AND STRONGER.
  ///
  /// It was by year, and that was a finding rather than a convenience:
  /// `chronology.json` spelled five of these men as the Authorised
  /// Version does (enos, cainan, mahalaleel, salah, nahor) while the
  /// events' `personIds` name them as `family_tree.json` does, so the
  /// id join reached four of the eight Genesis births and proved almost
  /// nothing. Joining on the year — the thing a reader can see two of —
  /// was what could be checked at the time.
  ///
  /// The ids were unified onto the tree's, so all eight join, and the
  /// claim gets sharper rather than merely shorter. "Some arc starts in
  /// this year" cannot tell Kenan's spoke from Mahalalel's arc if the
  /// two ever collided; "THIS man's arc starts in this year" can. The
  /// year assertion is kept — it is still what must agree — and the id
  /// is now what selects the arc to assert it about.
  test('every birth spoke sits exactly on its own arc start', () {
    final arcById = {for (final a in arcs()) a.id: a};
    final abram = (event('abram_called')['year'] as num).toInt();
    var joined = 0;
    for (final e in events()) {
      if (!(e['id'] as String).endsWith('_born')) continue;
      final year = (e['year'] as num).toInt();
      // The Genesis chain only: below Abraham the wheel carries births
      // this layer draws no life for (Ishmael, Esau, John), and their
      // absence is not a disagreement.
      if (year > abram) continue;
      final ids = ((e['personIds'] as List?) ?? const []).cast<String>();
      if (ids.length != 1) continue;
      final arc = arcById[ids.single];
      expect(arc, isNotNull,
          reason: '${e['id']} links ${ids.single} and no arc carries that '
              'id — the spoke and the arc are two answers to one question '
              'and they have stopped being about the same man');
      joined++;
      expect(arc!.birthYear, year,
          reason: '${e['id']} is at $year and ${arc.id} starts at '
              '${arc.birthYear}');
    }
    // EXACTLY EIGHT, not "at least". Eight is the whole of what the
    // timeline carries above Abraham with a single person link, and it
    // was four before the ids were unified. Pinning the number is what
    // makes a link quietly dropped — the failure this join has already
    // had once — fail here instead of shrinking the loop in silence.
    expect(joined, 8,
        reason: 'the join must reach every birth spoke on the Genesis chain');
  });

  /// The five that moved, pinned so a partial revert is loud. Both files
  /// were right about their own man; what was wrong was two join keys
  /// for one person, and four separate alias tables holding them
  /// together.
  test('the two assets key these five men the same way', () {
    final chronIds = {for (final p in chron.inTradition(_drawn)) p.id};
    final personIds = <String>{
      for (final e in events())
        ...((e['personIds'] as List?) ?? const []).cast<String>()
    };
    const moved = <String>{
      'enosh',
      'kenan',
      'mahalalel',
      'shelah',
      'nahor_elder',
    };
    // `nahor_elder` has no birth event of his own, so he is checked on
    // the chart's side only — the other four must be in both.
    expect(chronIds, containsAll(moved));
    expect(personIds, containsAll(moved.difference({'nahor_elder'})));
    // And the spellings they replaced are gone, so nothing can join on
    // one and silently find nothing.
    for (final old in const ['enos', 'cainan', 'mahalaleel', 'salah',
        'nahor']) {
      expect(chronIds, isNot(contains(old)), reason: old);
      expect(personIds, isNot(contains(old)), reason: old);
    }
  });

  test('the flood, and Moses, land where the arcs end', () {
    final mt = (chronRaw['traditions'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((t) => t['id'] == _drawn);
    expect((event('flood')['year'] as num).toInt(),
        creation + (mt['floodAm'] as num).toInt());
    final byId = {for (final a in arcs()) a.id: a};
    // The claim only an arc can make: Methuselah's years run out in the
    // flood year. The text never says he died in it; the arithmetic
    // does, and the chart shows the arithmetic without asserting the
    // sentence.
    expect(byId['methuselah']!.deathYear, (event('flood')['year'] as num));
    expect(byId['moses']!.deathYear, (event('moses_dies')['year'] as num));
    expect(byId['moses']!.birthYear, (event('moses_born')['year'] as num));
  });

  // ── 3. the packing ─────────────────────────────────────────────────

  test('exactly 25 lives, in exactly these sub-rings', () {
    // The band holds 106 arcs now — 25 lives, 42 reigns, 39 ministries
    // — plus a reserved innermost ring the genealogy rail owns.
    //
    // This test is about the 25, and their RELATIVE order is unchanged
    // by the other two layers: `buildSpanArcs` sorts by start angle
    // before first-fit, and every patriarch starts earlier than every
    // king and every prophet, so the lives are placed first and keep
    // the assignment they always had. Every number below is one higher
    // than it used to be, and only because ring 0 is now the rail's —
    // `packWheelBand` applies that shift so no caller can forget it.
    final a = patriarchArcs();
    expect(a.length, 25);
    expect(
      {for (final x in a) x.id: x.ring},
      {
        'adam': 1,
        'seth': 2,
        'enosh': 3,
        'kenan': 4,
        'mahalalel': 5,
        'jared': 6,
        'enoch': 7,
        'methuselah': 8,
        'lamech': 9,
        'noah': 1,
        'shem': 2,
        'arphaxad': 3,
        'shelah': 4,
        'eber': 5,
        'peleg': 6,
        'reu': 7,
        'serug': 8,
        'nahor_elder': 9,
        'terah': 10,
        'abraham': 11,
        'isaac': 1,
        'jacob': 6,
        'joseph': 2,
        'aaron': 1,
        'moses': 2,
      },
      reason: 'greedy first-fit on the birth angle is deterministic, and a '
          'changed assignment means the figures, the axis or the gap moved',
    );
    // ELEVEN, computed. Eleven of these lives are being lived at once —
    // Noah through Abraham — so eleven is what the overlaps demand, and
    // writing the number into the builder would be a claim about the
    // data that the data already makes.
    // Twelve now: eleven the overlaps demand, plus the rail's.
    expect(lifeArcRingCount(a), 12);
    var maxAlive = 0;
    for (var y = creation; y < 0; y++) {
      final k = a.where((x) => x.birthYear <= y && y <= x.deathYear).length;
      if (k > maxAlive) maxAlive = k;
    }
    expect(lifeArcRingCount(a), maxAlive + 1,
        reason: 'the reserved rail ring is the only one no life is in');
  });

  /// [ringRadii] counts ring 0 from the RIM inward, which is right for
  /// the stream bands and wrong here. Adam is against the bands.
  test('ring 0 is the innermost, flush against the scripture baseline', () {
    const side = 900.0;
    final inner = scriptureLabelBase(side * _bandsFrac);
    final outer = side * _rimFrac;
    final a = arcs();
    final rings = lifeArcRingCount(a);
    final adam = lifeArcRadii(0, rings, inner, outer);
    final top = lifeArcRadii(rings - 1, rings, inner, outer);
    expect(adam.centre, lessThan(top.centre));
    expect(adam.inner, greaterThanOrEqualTo(inner - 0.001));
    expect(top.outer, lessThanOrEqualTo(outer + 0.001));
  });

  // ── 4. who gets no arc, and why ────────────────────────────────────

  /// GENESIS 4:17-24 STATES NO FIGURE. Not an age, not an interval, not
  /// a total. So none of Cain's line may be placed by this layer, and
  /// `family_tree.json`'s 100, 200 … 545 for them are `conventional`
  /// placeholders that must not become years on any axis.
  test('no Cainite is placed, and none carries a year of its own', () {
    const cainites = {
      'enoch_cain',
      'irad',
      'mehujael',
      'methushael',
      'lamech_cain',
      'adah',
      'zillah',
      'jabal',
      'jubal',
      'tubal_cain',
      'naamah',
    };
    final placed = {for (final a in arcs()) a.id};
    for (final id in cainites) {
      expect(placed, isNot(contains(id)));
      expect(chron.byId(id), isNull,
          reason: 'the arc builder reads chronology.json, which holds no '
              'Cainite — if one appeared there this layer would draw it');
    }
    for (final e in events()) {
      final ids = ((e['personIds'] as List?) ?? const []).cast<String>();
      for (final id in ids) {
        expect(cainites, isNot(contains(id)),
            reason: '${e['id']} carries a year and names $id, for whom '
                'Genesis 4 states none');
      }
    }
  });

  /// The others who get no arc, each for a stated reason. Eve, Cain,
  /// Abel, Ham and Japheth are placed by the text but not measured;
  /// Levi, Kohath and Amram have lifespans in Exodus 6 but no begetting
  /// ages, so nothing fixes where the span sits; and Kainan is in the
  /// Greek only, so `inTradition('mt')` excludes him structurally.
  test('no arc for a man the Masoretic gives no figures', () {
    final placed = {for (final a in arcs()) a.id};
    for (final id in ['eve', 'cain', 'abel', 'ham', 'japheth', 'levi',
      'kohath', 'amram', 'kainan2']) {
      expect(placed, isNot(contains(id)), reason: id);
    }
    // Structurally, not by a list: the record exists and is excluded
    // because it has no Masoretic figures at all.
    final kainan = chron.byId('kainan2');
    expect(kainan, isNotNull, reason: 'the record went — rewrite this test');
    expect(kainan!.figures.containsKey(_drawn), isFalse);
    expect(kainan.figures.containsKey('lxx'), isTrue);
    expect(chron.inTradition(_drawn).map((p) => p.id), isNot(contains('kainan2')));
  });

  // ── 5. the names, measured in the shipped faces ────────────────────

  /// HOW MANY NAMES SURVIVE AT REST — measured, not predicted.
  ///
  /// The ruling claimed all 25 at every canvas from 700 px up, on the
  /// arithmetic "Joseph's arc offers 27 px and 'Joseph' at the 6 px
  /// floor is about 20". That arithmetic used the arc's WHOLE sweep,
  /// and the ruling's own spoke-avoidance rule then takes most of it
  /// away: measured in the shipped faces, four English names fall off
  /// at 700 px (Isaac, Jacob, Joseph, Moses — the four shortest lives)
  /// and two at 900 px and two in Chinese, where a two-ideograph name
  /// is narrower but its em box is squarer. All 25 are back at 1400 px
  /// and, at the smaller canvases, by 2x zoom.
  ///
  /// That is not a defect and it is not adjusted away: it is the rule
  /// the whole wheel runs on — legible or absent, and zoom is the
  /// reader's lever. What is pinned here is the MEASURED count, as a
  /// ratchet: it may rise as the corpus or the fitter improves, and it
  /// must never fall.
  ///
  /// A FLOOR, NOT THE RENDER. `canvasTextStyle` declares no
  /// `fontFamily` — the wheel's canvas type is the host's own UI face —
  /// so no test can measure exactly what a given reader sees. Roboto is
  /// the stand-in, as it is in `wheel_arc_label_behaviour_test.dart`,
  /// and it is the WIDER assumption: driven in a browser at 700 px the
  /// shipped build drew Moses and Aaron, which this count says are
  /// absent. These numbers are therefore a conservative floor under a
  /// real render, which is the direction a ratchet should be wrong in.
  ///
  /// 2026-09-02, RE-MEASURED after the ministries joined the band, and
  /// two of the six cells really did fall. The ministries take the band
  /// from eleven sub-rings to fifteen — they overlap each other and the
  /// reigns through the whole divided monarchy, and `ringPitch` divides
  /// the annulus by the GLOBAL ring count, so a pile-up in one sector
  /// thins the rings everywhere — and the pitch at 700 px goes from
  /// 9.73 px to 7.13. What that costs, exactly:
  ///
  ///     700 en        21 -> 20   Abraham, Jacob, Joseph, Aaron, Moses
  ///     700 zh-Hans   24 -> 24   unchanged
  ///     900 en        23 -> 22   Jacob, Joseph, Moses
  ///     900 zh-Hans   23 -> 22   Abraham, Isaac, Moses
  ///     1400 en       25 -> 25   every name
  ///     1400 zh-Hans  25 -> 25   every name
  ///
  /// Both figures above are AFTER the genealogy rail took the sixteenth
  /// ring as well. Four names across six cells, none at 1400 px.
  ///
  /// Three names lost across six cells, all of them long, none of them
  /// at the canvas the wheel usually gets, and every one of them back
  /// at 1400 px. `900 en` rose because a thinner ring is also a shorter
  /// arc to clear, and one name that used to collide now fits.
  ///
  /// An arc that loses its label is still tappable and its sheet still
  /// names it, so what is lost is scanning, not reach. The numbers are
  /// written down rather than the floors lowered quietly, and `the
  /// strong floors still hold with the ministries off` below is what
  /// keeps this from becoming a licence to keep spending the annulus.
  const floors = <String, int>{
    '700 en': 20,
    '700 zh-Hans': 24,
    '900 en': 22,
    '900 zh-Hans': 22,
    '1400 en': 25,
    '1400 zh-Hans': 25,
  };
  test('every life can be named at rest, at every canvas the wheel gets',
      () {
    for (final side in [700.0, 900.0, 1400.0]) {
      for (final locale in ['en', 'zh-Hans']) {
        final rBands = side * _bandsFrac;
        final rRim = side * _rimFrac;
        final inner = scriptureLabelBase(rBands);
        // The 25 names, measured in the geometry the WHOLE band
        // produces: the ring count and the pitch come from every arc,
        // because that is what squeezes the annulus, and only the
        // Genesis names are then asked to fit in it.
        final a = patriarchArcs();
        final rings = lifeArcRingCount(arcs());
        final pitch = ringPitch(rings, inner, rRim);
        final titleSize = _rimFontPx; // zoom 1

        // The spoke titles the names have to dodge, planned exactly as
        // the page plans them.
        final all = wheel.events.toList()
          ..sort((x, y) => x.year.compareTo(y.year));
        final angles = [
          for (final e in all) angleForSpan(e.year, kMinYear, kMaxYear)
        ];
        final minGapLabel = (_rimFontPx * 1.35) / rBands;
        final clusters = clusterByAngle(angles, minGapLabel);
        final planned = planRadialSpokes(
          requests: [
            for (final c in clusters)
              SpokeRequest(
                angle: angles[c.representative],
                scripture: all[c.representative].basis != 'conventional',
                title: all[c.representative].titleFor(locale),
                // The page passes the localised reference, and it is
                // not cosmetic here: a label carrying its verse is
                // wider, which changes which titles survive and so
                // changes the angles a name has to dodge. Measuring
                // with an empty ref measures a wheel nobody sees.
                ref: all[c.representative].refs.isEmpty
                    ? ''
                    : localizedReferenceLabel(
                        all[c.representative].refs.first, locale),
                badge: c.hidden == 0 ? '' : '+${c.hidden}',
              )
          ],
          rBands: rBands,
          rRim: rRim,
          titleSize: titleSize,
          refSize: titleSize * 0.86,
          measure: _measureLabel,
          minGap: minGapLabel,
          lineHeight: titleSize * 1.35,
        );

        var named = 0;
        final missing = <String>[];
        for (final arc in a) {
          final band = lifeArcRadii(arc.ring, rings, inner, rRim);
          final occupied = <ArcSpan>[
            for (final p in planned)
              if (p.hasText &&
                  p.label.rStart - 2 <= band.centre &&
                  p.label.rEnd + 2 >= band.centre)
                (
                  start: p.label.angle - (titleSize * 1.35 / 2) / band.centre,
                  end: p.label.angle + (titleSize * 1.35 / 2) / band.centre,
                )
          ];
          final name = chron.byId(arc.id)!.nameFor(locale);
          final room = arcNameRoom(arc.a0, arc.a1, occupied);
          final size = fitArcLabel(
            text: name,
            radius: band.centre,
            sweep: room,
            maxEm: pitch * kArcLabelPitchFraction,
            desiredSize: titleSize,
            zoom: 1,
            floorPx: kArcLabelFloorPx,
            measure: _measureChars,
          );
          if (size <= 0) { missing.add('${arc.id}:size'); continue; }
          final needed = _measureChars(name, size) / band.centre;
          final at = placeArcName(arc.a0, arc.a1, occupied, needed);
          if (at == null) { missing.add('${arc.id}:place'); continue; }
          named++;
          // Inside its own arc, and clear of every spoke title.
          expect(at, greaterThanOrEqualTo(arc.a0 - 1e-9), reason: arc.id);
          expect(at + needed, lessThanOrEqualTo(arc.a1 + 1e-9),
              reason: arc.id);
          for (final o in occupied) {
            expect(at >= o.end - 1e-9 || at + needed <= o.start + 1e-9, isTrue,
                reason: '${arc.id} name crosses a planned spoke label at '
                    '$side px, $locale');
          }
          // And inside its sub-ring: an em wider than the pitch would
          // print into the neighbouring life's row.
          expect(size, lessThanOrEqualTo(pitch * kArcLabelPitchFraction + 1e-9),
              reason: arc.id);
        }
        final key = '${side.round()} $locale';
        expect(named, greaterThanOrEqualTo(floors[key]!),
            reason: 'only $named of 25 names could be placed at $side px in '
                '$locale, against a measured floor of ${floors[key]} — '
                'something took room away from the annulus. Missing: '
                '$missing');
        // And the falsifier the ruling set for itself: below 20 of 25
        // in Chinese at the smallest canvas, the annulus is more
        // crowded than the 50-spoke count suggested and the layer's
        // "named at rest" behaviour is withdrawn rather than tuned.
        if (locale == 'zh-Hans' && side == 700.0) {
          expect(named, greaterThanOrEqualTo(20));
        }
      }
    }
  });

  // ── 6. every arc is reachable by a finger ──────────────────────────

  /// THE COST OF THE THIRD LAYER, STATED.
  ///
  /// Nine pixels is what the spokes use as a finger target and what
  /// this band held while it carried the 25 lives alone. The 42 reigns
  /// cost NOTHING — they fall in years the patriarchs have already
  /// left, so first-fit puts them in the eleven sub-rings that existed.
  /// The 39 ministries do cost: they overlap each other and the reigns
  /// through the whole divided monarchy, the band goes to fifteen, and
  /// at the smallest canvas the wheel can get (992 px is the gate, so a
  /// short window gives a 700 px side) a sub-ring is 6.69 px — 7.13
  /// from the ministries, and 6.69 once the genealogy rail reserves the
  /// innermost ring on top of that.
  ///
  /// That is under the target and it is not tuned away. It is
  /// recorded, it is reachable only at the smallest canvas, the wheel
  /// zooms to 14x, and the reader has a switch — which the next test
  /// proves gives the nine pixels back.
  test('a sub-ring is a finger target at the smallest canvas', () {
    for (final (side, floor) in [(700.0, 6.6), (900.0, 8.6), (1400.0, 9.0)]) {
      final inner = scriptureLabelBase(side * _bandsFrac);
      final pitch = ringPitch(lifeArcRingCount(arcs()), inner, side * _rimFrac);
      expect(pitch, greaterThanOrEqualTo(floor),
          reason: 'at $side px a sub-ring is ${pitch.toStringAsFixed(2)} px '
              'deep — under the nine the spokes use as a target, so a '
              'reader could not tap an arc without zooming');
    }
  });

  test('the strong floors still hold with the ministries off', () {
    // The remedy, pinned as a remedy: with the layer the reader can
    // switch off switched off, the band is back to eleven sub-rings and
    // every canvas clears nine pixels. If this ever fails, the cost
    // above stopped being optional and the layer has to be rethought
    // rather than the floor lowered again.
    final withoutMinistries = packWheelBand(
      chron: chron,
      creationYear: creation,
      kings: HebrewKingsService.instance.cached?.kings ?? const <HebrewKing>[],
      ministries: const <WheelMinistry>[],
      tradition: _drawn,
      // ...and the rail off too, which is the state a reader reaches
      // by clearing the two switches this test is about.
      reservedInnerRings: 0,
    );
    expect(lifeArcRingCount(withoutMinistries), 11);
    for (final side in [700.0, 900.0, 1400.0]) {
      final inner = scriptureLabelBase(side * _bandsFrac);
      final pitch = ringPitch(
          lifeArcRingCount(withoutMinistries), inner, side * _rimFrac);
      expect(pitch, greaterThanOrEqualTo(9.0),
          reason: 'at $side px, ministries off, a sub-ring is '
              '${pitch.toStringAsFixed(2)} px');
    }
  });

  // ── 7 & 10. the sheet, and the switch ──────────────────────────────

  Future<void> pump(WidgetTester tester, Size size) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: const MaterialApp(home: RadialChronologyPage()),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  }

  String sheetText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
      .join('\n');

  /// Where a life sits on the canvas: its sub-ring centre, at an angle
  /// in the middle of its own span.
  Offset pointOn(LifeArc arc, double side, {double? atAngle}) {
    final inner = scriptureLabelBase(side * _bandsFrac);
    final rings = lifeArcRingCount(arcs());
    final r = lifeArcRadii(arc.ring, rings, inner, side * _rimFrac).centre;
    final a = atAngle ?? (arc.a0 + arc.a1) / 2;
    return Offset(side / 2 + r * math.cos(a), side / 2 + r * math.sin(a));
  }

  testWidgets('a tap on an arc opens the life, in both traditions',
      (tester) async {
    await pump(tester, const Size(900, 900));
    final rect = tester.getRect(find.byKey(const ValueKey('chronologyWheel')));
    final arc = arcs().firstWhere((a) => a.id == 'methuselah');
    await tester.tapAt(rect.topLeft + pointOn(arc, rect.width));
    await tester.pump(const Duration(milliseconds: 400));
    final text = sheetText(tester);
    expect(text, contains('玛土撒拉'));
    // BOTH TRADITIONS, and neither chosen in silence. 969 in the
    // Hebrew and 969 in the Greek — he is one of the men they agree on
    // — but the Anno Mundi years differ (687 against 1287) and that is
    // what proves the sheet is printing two chains and not one twice.
    expect(text, contains('969'));
    expect(text, contains('687'));
    expect(text, contains('1287'));
    expect(text, contains('马所拉'));
    expect(text, contains('七十士'));
    // The verse each figure rests on, and the chain the BC year hangs
    // on, are different lists and both are here.
    expect(text, contains('5:27'));
    // AND NOT THE EXODUS SENTENCE. `timelineSeptuagintYear` explains a
    // 215-year shift that comes out of Exodus 12:40's 430 years in
    // Egypt and Canaan; it is true of the exodus block and false of a
    // Genesis 5 figure, and `bible_timeline.json`'s own
    // `_meta.septuagintYear` declines to print a pre-Abraham year under
    // it for that reason. Reusing the label here would have printed
    // 4193 BC under a paragraph that does not describe it.
    expect(text, isNot(contains('430')),
        reason: "the sojourn's 430 years explain the exodus block's "
            'Septuagint year and not this man\'s');
    expect(find.text('打开「圣经年代」'), findsOneWidget);
    await unmount(tester);
  });

  /// THE ROW THAT WAS MISSING, AND WHO IT WAS MISSING FOR.
  ///
  /// The arc sheet ends with a "People" row linking the man's
  /// family-tree record, looked up by the chart's own id. Five of the
  /// twenty-five were keyed on the Authorised Version's spelling — enos,
  /// cainan, mahalaleel, salah, nahor — where the tree keys them enosh,
  /// kenan, mahalalel, shelah, nahor_elder, so `byId` returned null and
  /// the row was simply absent. Not an error on screen: a link the
  /// reader never saw, on the five sheets most likely to send them
  /// looking for one, because those are the men whose two spellings they
  /// have just been shown.
  ///
  /// The ids are unified, so all five are checked here by tapping the
  /// arc and reading the sheet. Adam is checked alongside them as the
  /// control — his id never moved, so if HIS row is missing too the
  /// failure is in the sheet and not in the join.
  testWidgets('the five renamed men have their family-tree row back',
      (tester) async {
    const people = '相关人物';
    for (final man in const [
      ('adam', '亚当'),
      ('enosh', '以挪士'),
      ('kenan', '该南'),
      ('mahalalel', '玛勒列'),
      ('shelah', '沙拉'),
      ('nahor_elder', '拿鹤'),
    ]) {
      await pump(tester, const Size(900, 900));
      final rect =
          tester.getRect(find.byKey(const ValueKey('chronologyWheel')));
      final arc = arcs().firstWhere((a) => a.id == man.$1);
      // SPOKES WIN TIES, on purpose — a birth tick is a much smaller
      // target than a life and must never be swallowed by one. So the
      // arc's mid-angle is not always the arc: Enosh's centre sits under
      // Methuselah's birth spoke. Walk across the span until the tap
      // lands on the life itself, and fail if none of them does.
      var text = '';
      for (final f in const [0.5, 0.35, 0.65, 0.2, 0.8]) {
        await tester.tapAt(rect.topLeft +
            pointOn(arc, rect.width,
                atAngle: arc.a0 + (arc.a1 - arc.a0) * f));
        await tester.pump(const Duration(milliseconds: 400));
        text = sheetText(tester);
        if (text.contains(man.$2) && text.contains('列祖寿数')) break;
        await unmount(tester);
        await pump(tester, const Size(900, 900));
      }
      expect(text, contains(man.$2),
          reason: '${man.$1}: no tap across his span opened his life');
      expect(text, contains(people),
          reason: '${man.$1}: no People row — the sheet could not find him '
              'in family_tree.json, which is the defect the unified ids '
              'were meant to close');
      await unmount(tester);
    }
  });

  testWidgets('Lamech prints the figures the two texts disagree on',
      (tester) async {
    await pump(tester, const Size(900, 900));
    final rect = tester.getRect(find.byKey(const ValueKey('chronologyWheel')));
    final arc = arcs().firstWhere((a) => a.id == 'lamech');
    await tester.tapAt(rect.topLeft + pointOn(arc, rect.width));
    await tester.pump(const Duration(milliseconds: 400));
    final text = sheetText(tester);
    expect(text, contains('拉麦'));
    expect(text, contains('777'), reason: 'the Masoretic total');
    expect(text, contains('753'), reason: 'the Septuagint total');
    await unmount(tester);
  });

  /// SPOKES WIN TIES. The flood spoke and Methuselah's arc end at the
  /// same angle by construction, and the smaller target has to stay
  /// reachable or it is not a target.
  testWidgets('a spoke at the same angle still opens its own event',
      (tester) async {
    await pump(tester, const Size(900, 900));
    final rect = tester.getRect(find.byKey(const ValueKey('chronologyWheel')));
    final side = rect.width;
    final floodYear = (event('flood')['year'] as num).toInt();
    final a = angleForSpan(floodYear, kMinYear, kMaxYear);
    // Out in the annulus at the flood's angle, past every sub-ring, is
    // where the spoke's own label runs.
    final r = side * _rimFrac - 4;
    await tester.tapAt(rect.topLeft +
        Offset(side / 2 + r * math.cos(a), side / 2 + r * math.sin(a)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(sheetText(tester), isNot(contains('玛土撒拉')),
        reason: 'the arc swallowed a spoke — a life is a much bigger '
            'target and must never take a tap the tick could have had');
    await unmount(tester);
  });

  testWidgets('the layer switch hides all 25 and brings them back',
      (tester) async {
    await pump(tester, const Size(900, 900));
    final rect = tester.getRect(find.byKey(const ValueKey('chronologyWheel')));
    final arc = arcs().firstWhere((a) => a.id == 'methuselah');
    final at = rect.topLeft + pointOn(arc, rect.width);

    await tester.tap(find.byIcon(Icons.filter_list));
    // The filter sheet is a `FutureBuilder` on the page's own load, and
    // shows a 120 px placeholder until it resolves.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('wheelFilterLifespans')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wheelFilterLifespans')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tapAt(const Offset(5, 5)); // dismiss the sheet
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 400));
    expect(sheetText(tester), isNot(contains('玛土撒拉')),
        reason: 'the layer is switched off and an arc still answered a tap');

    await tester.tap(find.byIcon(Icons.filter_list));
    // The filter sheet is a `FutureBuilder` on the page's own load, and
    // shows a 120 px placeholder until it resolves.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byKey(const ValueKey('wheelFilterLifespans')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tapAt(const Offset(5, 5));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 400));
    expect(sheetText(tester), contains('玛土撒拉'),
        reason: 'switched back on and the arcs did not return');
    await unmount(tester);
  });

  // ── 8. search ──────────────────────────────────────────────────────

  test('the lives are searchable by name, by verse and by year', () {
    WheelSearchResult find(String q) => searchWheel(
          data: wheel,
          query: q,
          locale: 'zh-Hans',
          axisEnd: kMaxYear,
          patriarchs: chron.patriarchs,
          creationYear: creation,
          tradition: _drawn,
        );

    final m = find('Methuselah');
    expect(m.hits.any((h) => h.kind == WheelHitKind.patriarch && h.id == 'methuselah'),
        isTrue);
    // And his birth spoke is still there: the two answer different
    // questions and a reader gets both.
    expect(m.hits.any((h) => h.kind == WheelHitKind.event), isTrue);
    // The layer id, not a stream id — this is what lets the page's
    // existing "un-hide what you found" step work with no special case.
    expect(
        m.hits.firstWhere((h) => h.kind == WheelHitKind.patriarch).streamId,
        kLifespanLayerId);
    expect(wheel.streams.map((s) => s.id), isNot(contains(kLifespanLayerId)));

    // All three scripts, because `chronology.json` carries all three.
    for (final q in ['玛土撒拉', '瑪土撒拉']) {
      expect(find(q).hits.any((h) => h.kind == WheelHitKind.patriarch), isTrue,
          reason: q);
    }

    // WHO WAS ALIVE THEN. On this stretch of the axis it is often the
    // only question the text can answer.
    final byYear = find('2100 BC');
    expect(
        byYear.hits
            .where((h) => h.kind == WheelHitKind.patriarch)
            .map((h) => h.id),
        containsAll(<String>['shem', 'abraham']));

    // A name one letter off finds nothing, so no sentence is put in
    // front of a reader about a man they did not ask for.
    expect(find('Methuselahx').hits.where((h) => h.kind == WheelHitKind.patriarch),
        isEmpty);

    // And with no anchor the lives are not indexed at all — never at a
    // year invented in the search box.
    final noAnchor = searchWheel(
      data: wheel,
      query: 'Methuselah',
      locale: 'zh-Hans',
      axisEnd: kMaxYear,
      patriarchs: chron.patriarchs,
      creationYear: null,
    );
    expect(noAnchor.hits.where((h) => h.kind == WheelHitKind.patriarch),
        isEmpty);
  });

  // ── 9. no lifespan literal in Dart ─────────────────────────────────

  /// EVERY FIGURE COMES FROM THE ASSET. The wheel page and the layout
  /// file may not carry a lifespan, a birth year or a death year of
  /// their own — the moment one is written in, it is a second source
  /// for a number the asset already holds, and the two will drift.
  test('no Genesis figure is written into the wheel source', () {
    final figures = <String>{
      for (final p in chron.patriarchs)
        for (final f in p.figures.values) ...[
          '${f.lifespan}',
          '${f.birthAm}',
          '${f.deathAm}',
        ]
    }..removeWhere((s) =>
            // 0, 65, 70 … are not distinctive, and a round hundred is a
            // layout constant everywhere in Flutter (`FontWeight.w600`,
            // `maxWidth: 720`), so this checks the figures that could
            // only have come from Genesis.
            s.length < 3 ||
            int.parse(s) % 10 == 0 ||
            // The axis ends are written in this file as constants and
            // one of them collides with a Septuagint figure (Anno Mundi
            // 2026 is Arphaxad's death in the Greek). Named rather than
            // widened away.
            int.parse(s) == kMaxYear ||
            int.parse(s) == -kMinYear);
    for (final path in [
      'lib/pages/radial_chronology_page.dart',
      'lib/utils/radial_chronology_layout.dart',
    ]) {
      final src = File(path).readAsStringSync();
      // Comments are prose about the data and may name it; code may not.
      final code = src
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//') &&
              !l.trimLeft().startsWith('///'))
          .join('\n');
      for (final f in figures) {
        expect(RegExp('(?<![0-9A-Za-z.])$f(?![0-9])').hasMatch(code), isFalse,
            reason: '$path writes the figure $f, which chronology.json '
                'already holds');
      }
    }
  });
}
