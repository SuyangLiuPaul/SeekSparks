import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/biblical_person.dart';
import 'package:seeksparks/models/hebrew_king.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/pages/chronology_page.dart';
import 'package:seeksparks/pages/hebrew_kings_page.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/family_tree_service.dart';
import 'package:seeksparks/services/hebrew_kings_service.dart';
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

/// World history on one wheel: 4000 BC at twelve o'clock, time sweeping
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
/// WHAT IS NOT HERE. The lifespans of Genesis 5 and 11 — Adam to
/// Joseph — are not on this wheel. They have no absolute years (the
/// text gives intervals, not dates), and they belong to
/// `chronology_page.dart`, which draws them on their own Anno Mundi
/// axis in both the Masoretic and Septuagint reckonings.
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

const int kMinYear = -4000;
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

/// The colour of one band, given its position among its own family.
Color streamColor(String line, int index, int count) =>
    _bandColor(line, count <= 1 ? 0.5 : index / (count - 1), index);

/// Strings this page owns. Kept local rather than appended to
/// ui_strings.dart because the unattended loop shares this checkout and
/// edits that file; fold these in on a quiet merge.
const Map<String, Map<String, String>> wheelStrings = {
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
  'wheelFindTeach': {
    'zh-Hans': '可查 {e} 件大事、{p} 个政权、创世记 10 章的 {n} 族与 {b} 条带。'
        '年份可输入「主前586」「586 BC」或「-586」；只输数字则两个纪元都查。',
    'zh-Hant': '可查 {e} 件大事、{p} 個政權、創世記 10 章的 {n} 族與 {b} 條帶。'
        '年份可輸入「主前586」「586 BC」或「-586」；只輸數字則兩個紀元都查。',
    // The Chinese forms are accepted in every locale, but naming them
    // here would offer an English reader a keyboard they do not have.
    'en': 'Searches {e} events, {p} powers, the {n} nations of Genesis 10 '
        'and {b} bands. For a year type 586 BC or -586; a bare number '
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
  // Methuselah has no date to draw; Baasha does — this app prints it,
  // from Thiele. What is missing is not the year but the RESOLUTION:
  // the wheel is drawn at the scale of kingdoms.
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
  'wheelFindAmElsewhere': {
    'zh-Hans': '{name}不在这个轮盘上：经文给的是年数，不是年份。'
        '生平记在「圣经年代」，自创世起算。',
    'zh-Hant': '{name}不在這個輪盤上：經文給的是年數，不是年份。'
        '生平記在「聖經年代」，自創世起算。',
    'en': '{name} is not on this wheel: the text gives a lifespan, not a '
        'date. That life is charted in Bible Chronology, counted from '
        'the creation.',
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
    UrlSyncService.claimUrl(kWheelUrlPath);
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
    UrlSyncService.claimUrl(null);
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
                      data, streams, arcs, spokes, locale),
                  child: Stack(children: [
                    CustomPaint(
                      size: Size(side, side),
                      painter: _WorldWheelPainter(
                        streams: streams,
                        colors: colors,
                        arcs: arcs,
                        spokes: spokes,
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
                              '${streams.length} · ${data.powers.length} · '
                              '${data.events.length}',
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
                      onPressed: () => setSheet(() => setState(
                          () => _hidden.addAll(data.streams.map((s) => s.id)))),
                      child: Text(_s('wheelNone', 'None', locale)),
                    ),
                  ]),
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
                      final person = _amPersonFor(query);
                      final king = person == null ? _kingFor(query) : null;
                      if (person == null && king == null) {
                        return const SizedBox.shrink();
                      }
                      final line = person != null
                          ? _fill('wheelFindAmElsewhere', '', locale,
                              {'name': person.localizedName(locale)})
                          : _fill('wheelFindKingElsewhere', '', locale,
                              {'name': king!.nameFor(locale)});
                      final label = person != null
                          ? _s('timelineOpenChronology',
                              'Open Bible Chronology', locale)
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

  /// The person a reader asked for who IS in this app and CANNOT be on
  /// this wheel.
  ///
  /// The test is the data's own: a record whose years are counted in
  /// Anno Mundi has no BC year, because the text gave it none. That is
  /// exactly the condition that keeps a name off a BC/AD circle, so it
  /// is the condition asked about — no hand-written list of patriarchs
  /// to fall out of step with the asset.
  ///
  /// Nineteen records qualify. Eight of them (Noah, Shem, Arphaxad,
  /// Eber, Peleg, Reu, Serug, Terah) also stand on the wheel as nations
  /// of Genesis 10 and 11, so a search for them is never empty and this
  /// never runs. It answers for the eleven who are only here:
  /// Adam through Lamech, Nahor the elder, and Shelah — whom the wheel
  /// spells Salah.
  ///
  /// Matching is equality on the folded name, in each of the three
  /// scripts, not a substring: this replaces a "found nothing" with a
  /// definite claim about one man, and a loose match would make that
  /// claim about the wrong one.
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
      for (final n in [p.name, p.nameZhHans ?? '', p.nameZhHant ?? '']) {
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
        'n': data.nations.length,
        'b': data.streams.length,
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
    final ring = streams.indexWhere((s) => s.id == hit.streamId);
    if (ring < 0) return;
    final rHub = _side * _kHubFrac;
    final rBands = _side * _kBandsFrac;
    final rRim = _side * _kRimFrac;
    final band = ringRadii(ring, streams.length, rHub, rBands);

    double angle;
    double radius;
    switch (hit.kind) {
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
    if (r >= rBands - 6 && r <= rRim + 8) {
      final tol = r > 0 ? (9.0 / r) : 0.05;
      _Spoke? best;
      var bestD = double.infinity;
      for (final s in spokes) {
        if (r < s.label.rStart - 6 || r > s.label.rEnd + 6) continue;
        final d = (a - s.label.angle).abs();
        if (d < tol && d < bestD) {
          best = s;
          bestD = d;
        }
      }
      if (best != null) {
        _select(best.event.id);
        if (best.members.length > 1) {
          _showCluster(context, best.members, data, locale);
        } else {
          _showEvent(context, best.event, data, locale);
        }
        return;
      }
    }

    // Otherwise a band: a power arc if one is under the tap, else the
    // stream itself.
    if (r >= rHub && r <= rBands) {
      for (final arc in arcs) {
        final band = ringRadii(arc.ring, streams.length, rHub, rBands);
        if (r < band.inner || r > band.outer) continue;
        if (a >= arc.a0 && a <= arc.a1) {
          _select(arc.power.id);
          _showPower(context, arc.power, data, locale);
          return;
        }
      }
      for (var i = 0; i < streams.length; i++) {
        final band = ringRadii(i, streams.length, rHub, rBands);
        if (r >= band.inner && r <= band.outer) {
          _select(streams[i].id);
          _showStream(context, streams[i], data, locale);
          return;
        }
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
              '${yearLabel(p.start, locale)} – '
              '${p.ongoing ? _s('wheelPresent', 'present', locale) : yearLabel(p.end!, locale)}',
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
    required this.locale,
    required this.selectedId,
    required this.wb,
    required this.zoom,
    required this.rimFont,
    required this.endFont,
    required this.bandFont,
  });

  final List<WheelStream> streams;

  /// Band id → its own shade. See `streamColor`.
  final Map<String, Color> colors;

  final List<_Arc> arcs;
  final List<_Spoke> spokes;
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
      old.zoom != zoom ||
      old.rimFont != rimFont ||
      old.endFont != endFont ||
      old.bandFont != bandFont;
}
