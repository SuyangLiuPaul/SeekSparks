import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/url_sync_service.dart';
import 'package:seeksparks/utils/jump_to_reference.dart' as jumper;
import 'package:seeksparks/utils/navigate_to_reader.dart';
import 'package:seeksparks/utils/radial_chronology_layout.dart';
import 'package:seeksparks/utils/reference_parser.dart';
import 'package:seeksparks/utils/version_mapper.dart'
    show localizedReferenceLabel;
import 'package:seeksparks/widgets/home_icon_button.dart';
import 'package:seeksparks/widgets/language_switcher_button.dart';
import 'package:seeksparks/widgets/localized_back_button.dart';
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
  'wheelFilter': {'zh-Hans': '筛选', 'zh-Hant': '篩選', 'en': 'Filter'},
  'wheelReset': {'zh-Hans': '复位', 'zh-Hant': '復位', 'en': 'Reset'},
  'wheelShadeNote': {
    'zh-Hans': '同一血统内，每条带一个色阶',
    'zh-Hant': '同一血統內，每條帶一個色階',
    'en': 'each band is its own shade of its line',
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
  'wheelBasisConventional': {
    'zh-Hans': '通行年份 · 非经文所载',
    'zh-Hant': '通行年份 · 非經文所載',
    'en': 'conventional date, not stated in scripture',
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
double _measureLabel(String text, double size) => (TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: size)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout())
    .width;

/// How type responds to zoom.
///
/// Dividing the canvas size by the full zoom holds letters at a
/// constant size on screen — mathematically tidy, and wrong: a reader
/// who zooms to 500% has asked to see this part BETTER, and type that
/// refuses to grow reads as a chart that ignored them. Dividing by
/// `zoom^0.55` instead means the on-screen size grows as `zoom^0.45`:
/// at 500% the letters are about twice the size they were, while the
/// wheel still buys real angular room, so more labels appear as well.
/// Legibility and density both improve, which is what zooming is for.
double _labelScale(double zoom) => math.pow(zoom, 0.5).toDouble();

/// BC 586 / 主前586.
String yearLabel(int year, String locale) {
  final zh = locale.startsWith('zh');
  if (year < 0) return zh ? '主前${-year}' : '${-year} BC';
  return zh ? '主后$year' : 'AD $year';
}

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
  const _Spoke(this.event, this.label, this.color, this.title, this.ref);
  final WheelHistoryEvent event;
  final RadialLabel label;
  final Color color;

  /// Empty when the label would not have been legible and only the tick
  /// is drawn.
  final String title;
  final String ref;
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

  void _resetZoom() => _viewer.value = Matrix4.identity();

  @override
  void dispose() {
    UrlSyncService.claimUrl(null);
    _viewer.removeListener(_onZoom);
    _viewer.dispose();
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
            icon: const Icon(Icons.filter_list),
            tooltip: _s('wheelFilter', 'Filter', locale),
            onPressed: () => _showFilter(context, locale),
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
    // At rest, 189 labels round 320° means one every 1.7° — shoulder
    // to shoulder, and the reader's complaint was exactly that: too
    // dense to read. Drawing them all and letting them touch is the
    // one thing that must not happen.
    //
    // So: a label needs about 1.35 line-heights of angular room at the
    // radius it sits on. That room is measured ON SCREEN, so zooming in
    // buys real space and more labels appear — at 1x roughly half the
    // corpus is drawn, by 3x all of it. Nothing is lost: what is not
    // drawn is still tappable-adjacent and always in the band's own
    // sheet, which lists every event on that stream.
    final onScreenPx = _kLabelPx * 1.35;
    final minGap = (onScreenPx / _labelScale(_zoom)) / rBands;

    // Selection always survives the thinning: hiding the thing the
    // reader just tapped would be indefensible.
    final kept = <WheelHistoryEvent>[];
    var lastAngle = double.negativeInfinity;
    for (final e in all) {
      final a = angleForSpan(e.year, kMinYear, kMaxYear);
      if (a - lastAngle >= minGap || e.id == _selectedId) {
        kept.add(e);
        lastAngle = a;
      }
    }

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
        for (final e in kept)
          SpokeRequest(
            angle: angleForSpan(e.year, kMinYear, kMaxYear),
            scripture: e.basis != 'conventional',
            title: e.titleFor(locale),
            ref: e.refs.isEmpty
                ? ''
                : localizedReferenceLabel(e.refs.first, locale),
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
        _Spoke(kept[p.index], p.label,
            colors[kept[p.index].stream] ?? _lineColor('none'), p.title, p.ref)
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
        _showEvent(context, best.event, data, locale);
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

  String _basisText(String basis, String locale) => switch (basis) {
        'scripture' => _s('wheelBasisScripture', 'stated in scripture', locale),
        'scripture+thiele' =>
          _s('wheelBasisThiele', 'interval from scripture', locale),
        _ => _s('wheelBasisConventional', 'conventional date', locale),
      };

  void _showEvent(BuildContext context, WheelHistoryEvent e,
      WheelHistoryData data, String locale) {
    final wb = WbColors.of(context);
    final stream = data.streams.firstWhere((s) => s.id == e.stream,
        orElse: () => const WheelStream(id: '', line: 'none', names: {}));
    final approx = e.approximate ? (locale.startsWith('zh') ? '约' : 'c. ') : '';
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
            for (final e in events)
              Padding(
                padding: EdgeInsets.only(top: t.scaled(3)),
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
    var stagger = false;
    for (var y = kMinYear; y <= kMaxYear; y += 100) {
      if (y == kMinYear) continue;
      final isMajor = y % 500 == 0;
      final a = angleForSpan(y, kMinYear, kMaxYear);
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * rHub, c + dir * rRim, isMajor ? major : minor);
      if (isMajor) {
        // Stagger over two radii so adjacent labels clear each other.
        final rr = rRim + (stagger ? 22 : 11);
        stagger = !stagger;
        _label(canvas, yearLabel(y, locale), c + dir * rr, wb.mutedText,
            rimFont / _labelScale(zoom),
            center: true);
      }
    }
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
      final sel = arc.power.id == selectedId;
      final dim = has && !sel ? 0.35 : 1.0;
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
      _tangentialLabel(canvas, c, band.centre, arc.power.nameFor(locale),
          arc.a0, arc.a1 - arc.a0,
          math.min(band.width * 0.72, rimFont / _labelScale(zoom)), dim);
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
          style: TextStyle(
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
      final dim = has && !sel ? 0.28 : 1.0;
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
    if (s.title.isEmpty) return;
    final style = TextStyle(
      color: sel ? wb.text : wb.text.withValues(alpha: 0.95 * dim),
      fontSize: rimFont / _labelScale(zoom),
      fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
    );
    final refStyle = TextStyle(
      color: wb.link.withValues(alpha: 0.95 * dim),
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
    tp.paint(canvas, Offset(0, -tp.height / 2));
    refTp?.paint(canvas, Offset(tp.width, -refTp.height / 2));
    canvas.restore();
  }

  /// A label along the arc, centred in the span, skipped when it cannot
  /// fit — the name is one tap away either way, and overprinted type is
  /// lost to everybody.
  void _tangentialLabel(Canvas canvas, Offset c, double radius, String text,
      double a0, double sweep, double fontSizeIn, double dim) {
    if (sweep <= 0) return;
    var fontSize = fontSizeIn.clamp(6.0, 10.0);
    for (var attempt = 0; attempt < 2; attempt++) {
      final style = TextStyle(
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
      if (angular <= sweep * 0.92) {
        _charsOnArc(canvas, c, radius, text, widths, style,
            a0 + (sweep - angular) / 2, angular);
        return;
      }
      fontSize *= 0.8;
      if (fontSize < 5.5) return;
    }
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
      (rRim + 6.0, 0.4, 0.3),
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
    for (final (year, off) in [(kMinYear, -0.055), (kMaxYear, 0.055)]) {
      final a = angleForSpan(year, kMinYear, kMaxYear);
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * rHub, c + dir * (rRim + 6), paint);
      final la = a + off;
      _label(
          canvas,
          yearLabel(year, locale),
          c + Offset(math.cos(la), math.sin(la)) * (rRim + 17),
          wb.text,
          endFont / _labelScale(zoom),
          center: true);
    }
  }

  void _label(Canvas canvas, String text, Offset at, Color color, double size,
      {bool center = false}) {
    final tp = TextPainter(
      text:
          TextSpan(text: text, style: TextStyle(color: color, fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center ? at - Offset(tp.width / 2, tp.height / 2) : at);
  }

  @override
  bool shouldRepaint(_WorldWheelPainter old) =>
      old.selectedId != selectedId ||
      old.locale != locale ||
      old.streams.length != streams.length ||
      old.arcs.length != arcs.length ||
      old.spokes.length != spokes.length ||
      old.zoom != zoom ||
      old.rimFont != rimFont;
}
