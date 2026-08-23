import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/era_palette.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/chronology.dart';
import 'package:seeksparks/models/hebrew_king.dart';
import 'package:seeksparks/models/timeline_event.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/chronology_service.dart';
import 'package:seeksparks/services/hebrew_kings_service.dart';
import 'package:seeksparks/services/timeline_service.dart';
import 'package:seeksparks/utils/chronology_layout.dart' show contemporaries;
import 'package:seeksparks/utils/jump_to_reference.dart' as jumper;
import 'package:seeksparks/utils/navigate_to_reader.dart';
import 'package:seeksparks/utils/radial_chronology_layout.dart';
import 'package:seeksparks/utils/reference_parser.dart';
import 'package:seeksparks/widgets/home_icon_button.dart';
import 'package:seeksparks/widgets/language_switcher_button.dart';
import 'package:seeksparks/widgets/localized_back_button.dart';

/// The same generations `chronology_page.dart` draws as bars, drawn as
/// a wheel: the creation at twelve o'clock, time sweeping clockwise
/// round the rim, one concentric ring per generation, each life an arc.
///
/// The bars page's doc comment explains why bars are *better at
/// comparison* — arcs on different radii cannot be compared by eye —
/// and that judgement stands; this page exists because the owner asked
/// for the wheel as well, and the wheel is better at the other thing: a
/// single glance that holds all twenty-six lives at once, the way the
/// engraved radial chronologies have shown them for centuries. Both
/// pages read the same `assets/chronology.json`, so neither can drift
/// from the verses.
///
/// What was taken from the printed charts is the *form* only — the
/// radial axis, rings by generation, colour by line of descent, epochs
/// as spokes. The data, palette, and every word on screen are this
/// app's own; nothing is reproduced from any publisher's artwork.
///
/// Interaction: pinch or scroll-wheel zooms (the inner rings are tight
/// at rest — that is what the zoom is for), drag pans, tapping an arc
/// opens the man's figures with their verses and highlights his years
/// as a wedge across every ring — "who was alive together", the fact
/// the whole chart exists to show. Tapping an epoch spoke opens its
/// note. The Masoretic/Septuagint choice re-lays the entire wheel, ring
/// count included: the Septuagint has Kainan and the Hebrew does not.
class RadialChronologyPage extends StatefulWidget {
  const RadialChronologyPage({super.key});

  @override
  State<RadialChronologyPage> createState() => _RadialChronologyPageState();
}

// The four lines of descent, matching chronology_page.dart exactly so a
// reader moving between the two views never re-learns the palette.
const Color _sethHue = Color(0xFF5B87C4);
const Color _shemHue = Color(0xFFC4885B);
const Color _abrahamHue = Color(0xFF4F8F6E);
const Color _leviHue = Color(0xFF8B6BA8);
const Color _epochHue = Color(0xFF3E7CB1);

Color _hueForLine(String line) => switch (line) {
      'shem' => _shemHue,
      'abraham' => _abrahamHue,
      'levi' => _leviHue,
      _ => _sethHue,
    };

// Wheel geometry as fractions of the square's side. The hub must hold
// the tradition pills; the band between hub and rim divides among the
// rings; outside the rim live the year labels and epoch names.
const double _kHubFrac = 0.145;
const double _kRimFrac = 0.455;

// Strings new to this page. Kept local rather than appended to
// ui_strings.dart because the unattended loop shares this checkout and
// that file is one it edits; fold these in on the next quiet merge.
const Map<String, Map<String, String>> wheelStrings = {
  'wheelTitle': {
    'zh-Hans': '圣经年代轮盘',
    'zh-Hant': '聖經年代輪盤',
    'en': 'Chronology Wheel',
  },
  'wheelHint': {
    'zh-Hans': '双指缩放 · 点按弧线看经文出处',
    'zh-Hant': '雙指縮放 · 點按弧線看經文出處',
    'en': 'Pinch to zoom · tap an arc for its verses',
  },
  'wheelLegendGen5': {
    'zh-Hans': '创世记 5',
    'zh-Hant': '創世記 5',
    'en': 'Genesis 5',
  },
  'wheelLegendGen11': {
    'zh-Hans': '创世记 11',
    'zh-Hant': '創世記 11',
    'en': 'Genesis 11',
  },
  'wheelLegendGen1250': {
    'zh-Hans': '创世记 12–50',
    'zh-Hant': '創世記 12–50',
    'en': 'Genesis 12–50',
  },
  'wheelLegendExodus': {
    'zh-Hans': '出埃及记–申命记',
    'zh-Hant': '出埃及記–申命記',
    'en': 'Exodus–Deuteronomy',
  },
  'wheelLegendEpoch': {
    'zh-Hans': '大事（有出处）',
    'zh-Hant': '大事（有出處）',
    'en': 'Epochs (each cited)',
  },
  'wheelModeAm': {
    'zh-Hans': '族长（AM）',
    'zh-Hant': '族長（AM）',
    'en': 'Patriarchs (AM)',
  },
  'wheelModeHistory': {
    'zh-Hans': '全史·至2026',
    'zh-Hant': '全史·至2026',
    'en': 'Full history · to 2026',
  },
  'wheelHistoryNote': {
    'zh-Hans': '主前年代按王上6:1年链（Thiele 锚点）；上古为约数，近代按通行年份。',
    'zh-Hant': '主前年代按王上6:1年鏈（Thiele 錨點）；上古為約數，近代按通行年份。',
    'en': 'BC years follow the 1 Kings 6:1 chain (Thiele anchor); the earliest '
        'are approximate, the modern ones conventional.',
  },
  'wheelLegendBibleEvents': {
    'zh-Hans': '圣经大事（98 件，各有出处）',
    'zh-Hant': '聖經大事（98 件，各有出處）',
    'en': 'Bible events (98, each cited)',
  },
  'wheelLegendJudah': {
    'zh-Hans': '犹大诸王',
    'zh-Hant': '猶大諸王',
    'en': 'Kings of Judah',
  },
  'wheelLegendIsrael': {
    'zh-Hans': '以色列诸王',
    'zh-Hant': '以色列諸王',
    'en': 'Kings of Israel',
  },
  'wheelLegendPowers': {
    'zh-Hans': '列国政权（通行年份）',
    'zh-Hant': '列國政權（通行年份）',
    'en': 'World powers (conventional)',
  },
  'wheelLegendChurch': {
    'zh-Hans': '教会与圣经史',
    'zh-Hant': '教會與聖經史',
    'en': 'Church & scripture history',
  },
  'wheelConventional': {
    'zh-Hans': '通行年份（非经文所载）',
    'zh-Hant': '通行年份（非經文所載）',
    'en': 'Conventional date, not stated in scripture',
  },
  'wheelReign': {
    'zh-Hans': '在位',
    'zh-Hant': '在位',
    'en': 'Reigned',
  },
};

/// The three threads of the post-scripture events, coloured apart.
const Map<String, Color> _histEraColors = {
  'bible': Color(0xFFB8860B), // scripture's own gold, from era_palette
  'church': Color(0xFF3E7CB1),
  'world': Color(0xFF6B7280),
};

/// Kingdom hues, matching the app's line-of-descent palette so the two
/// wheel modes read as one family.
const Map<Kingdom, Color> _kingdomColors = {
  Kingdom.united: Color(0xFF8B6BA8),
  Kingdom.judah: Color(0xFF5B87C4),
  Kingdom.israel: Color(0xFFC4885B),
};

const Color _powerHue = Color(0xFF7A8B6F);

/// BC 586 / 主前586 — the year label for the full-history axis.
String yearLabel(int year, String locale) {
  final zh = locale.startsWith('zh');
  if (year < 0) return zh ? '主前${-year}' : '${-year} BC';
  return zh ? '主后$year' : 'AD $year';
}

/// Everything both wheel modes need, loaded once. The three history
/// datasets are small (about 120 KB together) and loading them up
/// front means the mode toggle is instant.
class _WheelBundle {
  const _WheelBundle(this.chronology, this.timeline, this.kings, this.history);
  final ChronologyData chronology;
  final List<TimelineEvent> timeline;
  final HebrewKingsData kings;
  final WheelHistoryData history;
}

class _RadialChronologyPageState extends State<RadialChronologyPage> {
  Future<_WheelBundle>? _future;
  String _tradition = 'mt';
  bool _historyMode = false;
  String? _selectedId;
  final _viewerController = TransformationController();

  @override
  void initState() {
    super.initState();
    _future = () async {
      final results = await Future.wait([
        ChronologyService.instance.load(),
        TimelineService.instance.loadAll(),
        HebrewKingsService.instance.load(),
        WheelHistoryService.instance.load(),
      ]);
      return _WheelBundle(
        results[0] as ChronologyData,
        results[1] as List<TimelineEvent>,
        results[2] as HebrewKingsData,
        results[3] as WheelHistoryData,
      );
    }();
  }

  @override
  void dispose() {
    _viewerController.dispose();
    super.dispose();
  }

  String _s(String key, String fallback, String locale) =>
      uiStrings[key]?[locale] ?? wheelStrings[key]?[locale] ?? fallback;

  /// setState is protected, and the full-history tap handling lives in
  /// an extension for file layout; it selects through this instead.
  void _setSelected(String? id) => setState(() => _selectedId = id);

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    final wb = WbColors.of(context);

    return Scaffold(
      backgroundColor: wb.paneBg,
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(_s('wheelTitle', 'Chronology Wheel', locale)),
        actions: const [LanguageSwitcherButton(), HomeIconButton()],
      ),
      body: FutureBuilder<_WheelBundle>(
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
          final bundle = snap.data;
          if (bundle == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _body(context, bundle, locale);
        },
      ),
    );
  }

  Widget _body(BuildContext context, _WheelBundle bundle, String locale) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final data = bundle.chronology;
    final tradition = data.traditionById(_tradition);
    final people = data.inTradition(tradition.id);
    final endAm = tradition.endAm;
    final arcs =
        _historyMode ? <WheelArc>[] : buildWheelArcs(people, tradition.id, endAm);
    final items = _historyMode ? _buildHistoryItems(bundle, locale) : null;

    return LayoutBuilder(builder: (context, box) {
      // The wheel wants a square; give it the largest one the pane
      // holds, and let InteractiveViewer supply what the pane cannot.
      final side = math.min(box.maxWidth, box.maxHeight);
      final square = Size(side, side);
      final hubD = side * _kHubFrac * 2;

      final painter = _historyMode
          ? _HistoryWheelPainter(
              items: items!,
              locale: locale,
              selectedId: _selectedId,
              wb: wb,
              rimFont: t.scaledChrome(9),
              endFont: t.scaledChrome(10),
            ) as CustomPainter
          : _WheelPainter(
              data: data,
              traditionId: tradition.id,
              arcs: arcs,
              endAm: endAm,
              locale: locale,
              selectedId: _selectedId,
              wb: wb,
              rimFont: t.scaledChrome(9),
              endFont: t.scaledChrome(10),
            );

      return Stack(children: [
        Positioned.fill(
          child: InteractiveViewer(
            transformationController: _viewerController,
            maxScale: 10,
            minScale: 0.8,
            child: Center(
              child: SizedBox(
                width: side,
                height: side,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _historyMode
                      ? _handleHistoryTap(
                          context, d.localPosition, side, bundle, items!,
                          locale)
                      : _handleTap(
                          context, d.localPosition, side, data, arcs, locale),
                  child: Stack(children: [
                    CustomPaint(size: square, painter: painter),
                    // The hub is real widgets, not paint, so the mode
                    // and tradition choices stay real tappable controls
                    // at any zoom.
                    Center(
                      child: SizedBox(
                        width: hubD * 0.92,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _s('wheelTitle', 'Chronology Wheel', locale),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: wb.text,
                                fontSize: t.scaled(13),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: t.scaled(5)),
                            _modePills(locale, t, wb),
                            SizedBox(height: t.scaled(5)),
                            if (!_historyMode) ...[
                              _traditionPills(data, locale, t, wb),
                              SizedBox(height: t.scaled(5)),
                              Text(
                                '${_s('chronologyAm', 'AM', locale)} 0 – $endAm',
                                style: TextStyle(
                                    color: wb.mutedText,
                                    fontSize: t.scaled(10)),
                              ),
                            ] else ...[
                              Text(
                                '${yearLabel(-4000, locale)} – '
                                '${yearLabel(2026, locale)}',
                                style: TextStyle(
                                    color: wb.mutedText,
                                    fontSize: t.scaled(10)),
                              ),
                              SizedBox(height: t.scaled(3)),
                              Text(
                                _s('wheelHistoryNote', '', locale),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: wb.mutedText,
                                    fontSize: t.scaled(7.5)),
                              ),
                            ],
                            SizedBox(height: t.scaled(4)),
                            Text(
                              _s('wheelHint',
                                  'Pinch to zoom · tap an arc for its verses',
                                  locale),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: wb.mutedText,
                                  fontSize: t.scaled(8.5)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
        Positioned(
            left: 10,
            bottom: 10,
            child: _historyMode
                ? _historyLegend(locale, t, wb)
                : _legend(locale, t, wb)),
      ]);
    });
  }

  Widget _modePills(String locale, WbType t, WbColors wb) {
    Widget pill(String key, String fallback, bool active, VoidCallback go) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: InkWell(
            onTap: go,
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: t.scaled(7), vertical: t.scaled(3)),
              decoration: BoxDecoration(
                color: active ? wb.selectionBg : null,
                border: Border.all(color: wb.border),
              ),
              child: Text(
                _s(key, fallback, locale),
                style: TextStyle(
                  color: wb.text,
                  fontSize: t.scaled(10),
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      pill('wheelModeAm', 'Patriarchs (AM)', !_historyMode, () {
        setState(() {
          _historyMode = false;
          _selectedId = null;
        });
      }),
      pill('wheelModeHistory', 'Full history · to 2026', _historyMode, () {
        setState(() {
          _historyMode = true;
          _selectedId = null;
        });
      }),
    ]);
  }

  Widget _historyLegend(String locale, WbType t, WbColors wb) {
    Widget row(Color c, String label, {bool line = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: t.scaled(line ? 14 : 10),
                height: t.scaled(line ? 2 : 10),
                color: c),
            SizedBox(width: t.scaled(6)),
            Text(label,
                style:
                    TextStyle(color: wb.mutedText, fontSize: t.scaled(10))),
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
          row(eraColor('monarchy'),
              _s('wheelLegendBibleEvents', 'Bible events (98)', locale)),
          row(_kingdomColors[Kingdom.judah]!,
              _s('wheelLegendJudah', 'Kings of Judah', locale)),
          row(_kingdomColors[Kingdom.israel]!,
              _s('wheelLegendIsrael', 'Kings of Israel', locale)),
          row(_powerHue, _s('wheelLegendPowers', 'World powers', locale)),
          row(_histEraColors['church']!,
              _s('wheelLegendChurch', 'Church & scripture history', locale)),
        ],
      ),
    );
  }

  /// Lay the four datasets onto rings. Out to in: three rings of Bible
  /// events, two of kings, two of powers, two of church history —
  /// nine rings, the same radial budget the patriarch mode spends on
  /// twenty-six.
  List<_HistItem> _buildHistoryItems(_WheelBundle bundle, String locale) {
    const minY = -4000, maxY = 2026;
    final items = <_HistItem>[];

    // Bible events: dots, packed over rings 0-2 so neighbours in a
    // crowded decade spread instead of overprinting.
    final ev = bundle.timeline;
    final starts = [for (final e in ev) angleForSpan(e.year, minY, maxY)];
    final rings = packIntoRings(starts, starts, 3, minGap: 0.045);
    for (var i = 0; i < ev.length; i++) {
      items.add(_HistItem(
        kind: _HistKind.bibleEvent,
        id: ev[i].id,
        ring: rings[i],
        a0: starts[i],
        a1: starts[i],
        color: eraColor(ev[i].era),
        label: _timelineTitle(ev[i], locale),
        index: i,
      ));
    }

    // Kings: Judah (with the united kingdom) ring 3, Israel ring 4.
    final kings = bundle.kings.kings;
    for (var i = 0; i < kings.length; i++) {
      final k = kings[i];
      items.add(_HistItem(
        kind: _HistKind.king,
        id: k.id,
        ring: k.kingdom == Kingdom.israel ? 4 : 3,
        a0: angleForSpan(k.reignStart, minY, maxY),
        a1: angleForSpan(k.reignEnd, minY, maxY),
        color: _kingdomColors[k.kingdom]!,
        label: k.nameFor(locale),
        index: i,
      ));
    }

    // Powers: bands, packed over rings 5-6 by overlap.
    final powers = bundle.history.powers;
    final pStarts = [
      for (final p in powers) angleForSpan(p.start, minY, maxY)
    ];
    final pEnds = [for (final p in powers) angleForSpan(p.end, minY, maxY)];
    final pRings = packIntoRings(pStarts, pEnds, 2, minGap: 0.01);
    for (var i = 0; i < powers.length; i++) {
      items.add(_HistItem(
        kind: _HistKind.power,
        id: powers[i].id,
        ring: 5 + pRings[i],
        a0: pStarts[i],
        a1: pEnds[i],
        color: _powerHue,
        label: powers[i].nameFor(locale),
        index: i,
      ));
    }

    // Church and scripture history: dots, rings 7-8.
    final ch = bundle.history.events;
    final cStarts = [for (final e in ch) angleForSpan(e.year, minY, maxY)];
    final cRings = packIntoRings(cStarts, cStarts, 2, minGap: 0.045);
    for (var i = 0; i < ch.length; i++) {
      items.add(_HistItem(
        kind: _HistKind.churchEvent,
        id: ch[i].id,
        ring: 7 + cRings[i],
        a0: cStarts[i],
        a1: cStarts[i],
        color: _histEraColors[ch[i].era] ?? _histEraColors['church']!,
        label: ch[i].titleFor(locale),
        index: i,
      ));
    }

    return items;
  }

  String _timelineTitle(TimelineEvent e, String locale) {
    switch (locale) {
      case 'zh-Hans':
        return e.titleZhHans;
      case 'zh-Hant':
        return e.titleZhHant;
      default:
        return e.titleEn;
    }
  }

  String _timelineDesc(TimelineEvent e, String locale) {
    switch (locale) {
      case 'zh-Hans':
        return e.descZhHans;
      case 'zh-Hant':
        return e.descZhHant;
      default:
        return e.descEn;
    }
  }

  Widget _traditionPills(
      ChronologyData data, String locale, WbType t, WbColors wb) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final tr in data.traditions)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              onTap: () => setState(() {
                _tradition = tr.id;
                _selectedId = null;
              }),
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: t.scaled(8), vertical: t.scaled(3)),
                decoration: BoxDecoration(
                  color: _tradition == tr.id ? wb.selectionBg : null,
                  border: Border.all(color: wb.border),
                ),
                child: Text(
                  tr.nameFor(locale),
                  style: TextStyle(
                    color: wb.text,
                    fontSize: t.scaled(10.5),
                    fontWeight: _tradition == tr.id
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _legend(String locale, WbType t, WbColors wb) {
    Widget row(Color c, String label, {bool line = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: t.scaled(line ? 14 : 10),
                height: t.scaled(line ? 2 : 10),
                color: c),
            SizedBox(width: t.scaled(6)),
            Text(label,
                style:
                    TextStyle(color: wb.mutedText, fontSize: t.scaled(10))),
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
          row(_sethHue, _s('wheelLegendGen5', 'Genesis 5', locale)),
          row(_shemHue, _s('wheelLegendGen11', 'Genesis 11', locale)),
          row(_abrahamHue, _s('wheelLegendGen1250', 'Genesis 12–50', locale)),
          row(_leviHue,
              _s('wheelLegendExodus', 'Exodus–Deuteronomy', locale)),
          row(_epochHue, _s('wheelLegendEpoch', 'Epochs (each cited)', locale),
              line: true),
        ],
      ),
    );
  }

  // ── taps ────────────────────────────────────────────────────────────

  void _handleTap(BuildContext context, Offset local, double side,
      ChronologyData data, List<WheelArc> arcs, String locale) {
    final c = side / 2;
    final dx = local.dx - c, dy = local.dy - c;
    final r = math.sqrt(dx * dx + dy * dy);
    final angle = math.atan2(dy, dx);
    final rHub = side * _kHubFrac, rMax = side * _kRimFrac;
    final tradition = data.traditionById(_tradition);

    final hit = hitTest(r, angle, arcs, arcs.length, rHub, rMax);
    if (hit != null) {
      setState(() => _selectedId = hit.personId);
      _showPerson(context, data, hit.personId, locale);
      return;
    }

    // An epoch spoke: anywhere along the line or its rim label, within
    // about a degree and a half of it.
    if (r >= rHub && r <= rMax * 1.18) {
      for (final e in data.epochs) {
        final year = e.years[tradition.id];
        if (year == null) continue;
        var d = (angle - angleForYear(year, tradition.endAm)).abs();
        d = math.min(d, 2 * math.pi - d);
        if (d < 0.026) {
          _showEpoch(context, e, year, locale);
          return;
        }
      }
    }

    if (_selectedId != null) setState(() => _selectedId = null);
  }

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

  // ── detail sheets ───────────────────────────────────────────────────

  void _showEpoch(
      BuildContext context, ChronologyEpoch epoch, int year, String locale) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(epoch.nameFor(locale),
                style: TextStyle(
                    color: wb.text,
                    fontSize: t.scaled(15),
                    fontWeight: FontWeight.w600)),
            SizedBox(height: t.scaled(4)),
            Text('${_s('chronologyAm', 'AM', locale)} $year',
                style:
                    TextStyle(color: wb.mutedText, fontSize: t.scaled(12))),
            if (epoch.ref != null) ...[
              SizedBox(height: t.scaled(6)),
              InkWell(
                onTap: () => _jump(context, epoch.ref!),
                child: Text(epoch.ref!,
                    style:
                        TextStyle(color: wb.link, fontSize: t.scaled(12))),
              ),
            ],
            if ((epoch.noteFor(locale) ?? '').isNotEmpty) ...[
              SizedBox(height: t.scaled(8)),
              Text(epoch.noteFor(locale)!,
                  style:
                      TextStyle(color: wb.text, fontSize: t.scaled(12))),
            ],
          ],
        ),
      ),
    );
  }

  void _showPerson(BuildContext context, ChronologyData data, String personId,
      String locale) {
    final person = data.byId(personId);
    final tradition = data.traditionById(_tradition);
    final figures = person?.figures[tradition.id];
    if (person == null || figures == null) return;
    final wb = WbColors.of(context);
    final t = WbType.of(context);

    final lives = <String, (int, int)>{
      for (final p in data.inTradition(tradition.id))
        p.id: (
          p.figures[tradition.id]!.birthAm,
          p.figures[tradition.id]!.deathAm
        ),
    };
    final others = contemporaries(
        person.id, figures.birthAm, figures.deathAm, lives);
    final notes = data.notesForPerson(tradition.id, person.id);

    Widget fact(String label, String value, String? ref) => Padding(
          padding: EdgeInsets.only(top: t.scaled(6)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: wb.mutedText, fontSize: t.scaled(11.5))),
              ),
              Text(value,
                  style: TextStyle(color: wb.text, fontSize: t.scaled(12))),
              if (ref != null) ...[
                SizedBox(width: t.scaled(8)),
                InkWell(
                  onTap: () => _jump(context, ref),
                  child: Text(ref,
                      style: TextStyle(
                          color: wb.link, fontSize: t.scaled(11))),
                ),
              ],
            ],
          ),
        );

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      isScrollControlled: true,
      builder: (sheet) => ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheet).size.height * 0.62),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            Row(children: [
              Container(
                  width: t.scaled(10),
                  height: t.scaled(10),
                  color: _hueForLine(person.line)),
              SizedBox(width: t.scaled(8)),
              Expanded(
                child: Text(person.nameFor(locale),
                    style: TextStyle(
                        color: wb.text,
                        fontSize: t.scaled(16),
                        fontWeight: FontWeight.w600)),
              ),
              Text(tradition.nameFor(locale),
                  style: TextStyle(
                      color: wb.mutedText, fontSize: t.scaled(11))),
            ]),
            SizedBox(height: t.scaled(4)),
            Text(
              '${_s('chronologyAm', 'AM', locale)} ${figures.birthAm} – '
              '${figures.deathAm} · ${figures.lifespan} '
              '${_s('chronologyYears', 'years', locale)}',
              style: TextStyle(color: wb.mutedText, fontSize: t.scaled(12)),
            ),
            if (figures.begatAt != null)
              fact(
                _s('chronologyBegatAt', 'Fathered the next generation at',
                    locale),
                '${figures.begatAt} ${_s('chronologyYears', 'years', locale)}',
                figures.refs['begatAt'],
              ),
            if (figures.livedAfter != null)
              fact(
                _s('chronologyLivedAfter', 'Lived after that', locale),
                '${figures.livedAfter} '
                '${_s('chronologyYears', 'years', locale)}',
                figures.refs['livedAfter'],
              ),
            fact(
              _s('chronologyLifespan', 'Lifespan', locale),
              '${figures.lifespan} ${_s('chronologyYears', 'years', locale)}',
              figures.refs['lifespan'],
            ),
            for (final n in notes) ...[
              SizedBox(height: t.scaled(8)),
              Text(n.textFor(locale),
                  style: TextStyle(
                      color: wb.mutedText, fontSize: t.scaled(11))),
            ],
            if (others.isNotEmpty) ...[
              SizedBox(height: t.scaled(12)),
              Text(
                '${_s('chronologyContemporaries', 'Alive at the same time', locale)}'
                ' · ${others.length}',
                style: TextStyle(
                    color: wb.text,
                    fontSize: t.scaled(12),
                    fontWeight: FontWeight.w600),
              ),
              for (final c in others.take(8))
                Padding(
                  padding: EdgeInsets.only(top: t.scaled(3)),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                          data.byId(c.id)?.nameFor(locale) ?? c.id,
                          style: TextStyle(
                              color: wb.text, fontSize: t.scaled(11.5))),
                    ),
                    Text(
                        '${c.years} '
                        '${_s('chronologyYears', 'years', locale)}',
                        style: TextStyle(
                            color: wb.mutedText, fontSize: t.scaled(11))),
                  ]),
                ),
            ],
          ],
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }
}

// ── full-history mode: items, taps, sheets ────────────────────────────

enum _HistKind { bibleEvent, king, power, churchEvent }

/// One drawable, tappable thing on the full-history wheel — a Bible
/// event dot, a reign segment, a power band or a church-history dot —
/// reduced to ring + angles so drawing and hit-testing share one shape.
class _HistItem {
  const _HistItem({
    required this.kind,
    required this.id,
    required this.ring,
    required this.a0,
    required this.a1,
    required this.color,
    required this.label,
    required this.index,
  });

  final _HistKind kind;
  final String id;
  final int ring;
  final double a0;
  final double a1;
  final Color color;
  final String label;

  /// Position in the dataset the kind names, so the tap sheet can get
  /// back to the full record.
  final int index;

  bool get isDot => a1 <= a0;
}

const int _histRingCount = 9;

extension _HistoryTaps on _RadialChronologyPageState {
  void _handleHistoryTap(BuildContext context, Offset local, double side,
      _WheelBundle bundle, List<_HistItem> items, String locale) {
    final c = side / 2;
    final dx = local.dx - c, dy = local.dy - c;
    final r = math.sqrt(dx * dx + dy * dy);
    var angle = math.atan2(dy, dx);
    final rHub = side * _kHubFrac, rMax = side * _kRimFrac;
    if (r < rHub || r > rMax * 1.05) {
      if (_selectedId != null) _setSelected(null);
      return;
    }
    while (angle < startRad) {
      angle += 2 * math.pi;
    }
    if (angle - startRad > sweepRad) return;

    // Dots get a slightly forgiving angular window; bands are exact.
    _HistItem? best;
    var bestDist = double.infinity;
    for (final it in items) {
      final band = ringRadii(it.ring, _histRingCount, rHub, rMax);
      if (r < band.inner - band.width * 0.3 ||
          r > band.outer + band.width * 0.3) {
        continue;
      }
      if (it.isDot) {
        final d = (angle - it.a0).abs();
        if (d < 0.03 && d < bestDist) {
          best = it;
          bestDist = d;
        }
      } else if (angle >= it.a0 && angle <= it.a1) {
        if (bestDist == double.infinity) best = it;
        bestDist = 0;
      }
    }
    if (best == null) {
      if (_selectedId != null) _setSelected(null);
      return;
    }
    _setSelected(best.id);
    switch (best.kind) {
      case _HistKind.bibleEvent:
        _showTimelineEvent(context, bundle.timeline[best.index], locale);
      case _HistKind.king:
        _showKing(context, bundle.kings.kings[best.index], locale);
      case _HistKind.power:
        _showPower(context, bundle.history.powers[best.index], locale);
      case _HistKind.churchEvent:
        _showHistoryEvent(context, bundle.history.events[best.index], locale);
    }
  }

  Widget _sheetShell(BuildContext sheet, WbColors wb, List<Widget> children) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );

  void _showTimelineEvent(
      BuildContext context, TimelineEvent e, String locale) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final approx = e.approximate ? (locale.startsWith('zh') ? '约' : 'c. ') : '';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      builder: (sheet) => _sheetShell(sheet, wb, [
        Row(children: [
          Container(
              width: t.scaled(10), height: t.scaled(10),
              color: eraColor(e.era)),
          SizedBox(width: t.scaled(8)),
          Expanded(
            child: Text(_timelineTitle(e, locale),
                style: TextStyle(
                    color: wb.text,
                    fontSize: t.scaled(15),
                    fontWeight: FontWeight.w600)),
          ),
        ]),
        SizedBox(height: t.scaled(4)),
        Text('$approx${yearLabel(e.year, locale)}',
            style: TextStyle(color: wb.mutedText, fontSize: t.scaled(12))),
        SizedBox(height: t.scaled(8)),
        Text(_timelineDesc(e, locale),
            style: TextStyle(color: wb.text, fontSize: t.scaled(12))),
        if (e.refs.isNotEmpty) ...[
          SizedBox(height: t.scaled(8)),
          Wrap(spacing: 10, runSpacing: 4, children: [
            for (final ref in e.refs)
              InkWell(
                onTap: () => _jump(context, ref),
                child: Text(ref,
                    style:
                        TextStyle(color: wb.link, fontSize: t.scaled(11))),
              ),
          ]),
        ],
      ]),
    );
  }

  void _showKing(BuildContext context, HebrewKing k, String locale) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final refs = [
      if (k.kingsRef != null) k.kingsRef!,
      if (k.chroniclesRef != null) k.chroniclesRef!,
      if (k.accessionRef != null) k.accessionRef!,
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      builder: (sheet) => _sheetShell(sheet, wb, [
        Row(children: [
          Container(
              width: t.scaled(10), height: t.scaled(10),
              color: _kingdomColors[k.kingdom]),
          SizedBox(width: t.scaled(8)),
          Expanded(
            child: Text(k.nameFor(locale),
                style: TextStyle(
                    color: wb.text,
                    fontSize: t.scaled(15),
                    fontWeight: FontWeight.w600)),
          ),
        ]),
        SizedBox(height: t.scaled(4)),
        Text(
            '${_s('wheelReign', 'Reigned', locale)} '
            '${yearLabel(k.reignStart, locale)} – '
            '${yearLabel(k.reignEnd, locale)}',
            style: TextStyle(color: wb.mutedText, fontSize: t.scaled(12))),
        if (refs.isNotEmpty) ...[
          SizedBox(height: t.scaled(8)),
          Wrap(spacing: 10, runSpacing: 4, children: [
            for (final ref in refs)
              InkWell(
                onTap: () => _jump(context, ref),
                child: Text(ref,
                    style:
                        TextStyle(color: wb.link, fontSize: t.scaled(11))),
              ),
          ]),
        ],
      ]),
    );
  }

  void _showPower(BuildContext context, WheelPower p, String locale) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      builder: (sheet) => _sheetShell(sheet, wb, [
        Text(p.nameFor(locale),
            style: TextStyle(
                color: wb.text,
                fontSize: t.scaled(15),
                fontWeight: FontWeight.w600)),
        SizedBox(height: t.scaled(4)),
        Text(
            '${yearLabel(p.start, locale)} – ${yearLabel(p.end, locale)}',
            style: TextStyle(color: wb.mutedText, fontSize: t.scaled(12))),
        if (p.noteFor(locale).isNotEmpty) ...[
          SizedBox(height: t.scaled(8)),
          Text(p.noteFor(locale),
              style: TextStyle(color: wb.text, fontSize: t.scaled(12))),
        ],
        SizedBox(height: t.scaled(8)),
        Text(_s('wheelConventional', 'Conventional date', locale),
            style: TextStyle(color: wb.mutedText, fontSize: t.scaled(10.5))),
      ]),
    );
  }

  void _showHistoryEvent(
      BuildContext context, WheelHistoryEvent e, String locale) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final approx = e.approximate ? (locale.startsWith('zh') ? '约' : 'c. ') : '';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: wb.paneBg,
      shape: const RoundedRectangleBorder(),
      builder: (sheet) => _sheetShell(sheet, wb, [
        Row(children: [
          Container(
              width: t.scaled(10), height: t.scaled(10),
              color: _histEraColors[e.era] ?? _histEraColors['church']!),
          SizedBox(width: t.scaled(8)),
          Expanded(
            child: Text(e.titleFor(locale),
                style: TextStyle(
                    color: wb.text,
                    fontSize: t.scaled(15),
                    fontWeight: FontWeight.w600)),
          ),
        ]),
        SizedBox(height: t.scaled(4)),
        Text('$approx${yearLabel(e.year, locale)}',
            style: TextStyle(color: wb.mutedText, fontSize: t.scaled(12))),
        SizedBox(height: t.scaled(8)),
        Text(e.descFor(locale),
            style: TextStyle(color: wb.text, fontSize: t.scaled(12))),
        SizedBox(height: t.scaled(8)),
        Text(_s('wheelConventional', 'Conventional date', locale),
            style: TextStyle(color: wb.mutedText, fontSize: t.scaled(10.5))),
      ]),
    );
  }
}

// ── the painter ───────────────────────────────────────────────────────

class _WheelPainter extends CustomPainter {
  _WheelPainter({
    required this.data,
    required this.traditionId,
    required this.arcs,
    required this.endAm,
    required this.locale,
    required this.selectedId,
    required this.wb,
    required this.rimFont,
    required this.endFont,
  });

  final ChronologyData data;
  final String traditionId;
  final List<WheelArc> arcs;
  final int endAm;
  final String locale;
  final String? selectedId;
  final WbColors wb;

  /// Rim furniture — tick years and epoch names — is chrome, so its
  /// size comes in through WbType.scaledChrome rather than a literal
  /// the reader's Font Size setting cannot move (the #315 ratchet).
  final double rimFont;
  final double endFont;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final c = Offset(size.width / 2, size.height / 2);
    final rHub = side * _kHubFrac;
    final rMax = side * _kRimFrac;
    final ringCount = arcs.length;

    _paintTicks(canvas, c, rHub, rMax);
    _paintSelectionWedge(canvas, c, rHub, rMax);
    _paintArcs(canvas, c, rHub, rMax, ringCount);
    _paintEpochs(canvas, c, rHub, rMax);
    _paintHubRing(canvas, c, rHub);
    _paintAxisEnds(canvas, c, rHub, rMax);
  }

  void _paintTicks(Canvas canvas, Offset c, double rHub, double rMax) {
    final minor = Paint()
      ..color = wb.border.withValues(alpha: 0.35)
      ..strokeWidth = 0.5;
    final major = Paint()
      ..color = wb.border.withValues(alpha: 0.7)
      ..strokeWidth = 0.9;
    for (final tick in wheelTicks(endAm)) {
      final a = angleForYear(tick.year, endAm);
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * rHub, c + dir * rMax,
          tick.major ? major : minor);
      if (tick.major) {
        _paintLabel(canvas, '${tick.year}', c + dir * (rMax + 11),
            wb.mutedText, rimFont, center: true);
      }
    }
  }

  void _paintSelectionWedge(
      Canvas canvas, Offset c, double rHub, double rMax) {
    final id = selectedId;
    if (id == null) return;
    WheelArc? sel;
    for (final a in arcs) {
      if (a.personId == id) sel = a;
    }
    if (sel == null) return;
    final sweep = sel.deathAngle - sel.birthAngle;
    final fill = Paint()..color = _epochHue.withValues(alpha: 0.08);
    final edge = Paint()
      ..color = _epochHue.withValues(alpha: 0.5)
      ..strokeWidth = 0.7;
    final path = Path()
      ..moveTo(c.dx + math.cos(sel.birthAngle) * rHub,
          c.dy + math.sin(sel.birthAngle) * rHub)
      ..lineTo(c.dx + math.cos(sel.birthAngle) * rMax,
          c.dy + math.sin(sel.birthAngle) * rMax)
      ..arcTo(Rect.fromCircle(center: c, radius: rMax), sel.birthAngle,
          sweep, false)
      ..lineTo(c.dx + math.cos(sel.deathAngle) * rHub,
          c.dy + math.sin(sel.deathAngle) * rHub)
      ..arcTo(Rect.fromCircle(center: c, radius: rHub), sel.deathAngle,
          -sweep, false)
      ..close();
    canvas.drawPath(path, fill);
    for (final a in [sel.birthAngle, sel.deathAngle]) {
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * rHub, c + dir * rMax, edge);
    }
  }

  void _paintArcs(
      Canvas canvas, Offset c, double rHub, double rMax, int ringCount) {
    final hasSelection = selectedId != null;
    for (final arc in arcs) {
      final band = ringRadii(arc.ring, ringCount, rHub, rMax);
      final rect = Rect.fromCircle(center: c, radius: band.centre);
      final hue = _hueForLine(arc.line);
      final selected = arc.personId == selectedId;
      final dim = hasSelection && !selected ? 0.38 : 1.0;

      final darkPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = band.width
        ..color = hue.withValues(alpha: 0.95 * dim);
      final lightPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = band.width
        ..color = hue.withValues(alpha: 0.42 * dim);

      final begat = arc.begatAngle;
      if (begat != null) {
        canvas.drawArc(
            rect, arc.birthAngle, begat - arc.birthAngle, false, darkPaint);
        canvas.drawArc(
            rect, begat, arc.deathAngle - begat, false, lightPaint);
      } else {
        canvas.drawArc(rect, arc.birthAngle,
            arc.deathAngle - arc.birthAngle, false, darkPaint);
      }

      // Round the ends with markers that sit ON the birth and death
      // years rather than stroke caps that would stretch past them — a
      // chart whose rule is "never invent a date" does not get to add
      // half a stroke-width of years for looks.
      final dotR = band.width * 0.5;
      for (final (a, solid) in [
        (arc.birthAngle, true),
        (arc.deathAngle, false)
      ]) {
        final p =
            c + Offset(math.cos(a), math.sin(a)) * band.centre;
        canvas.drawCircle(
            p,
            dotR,
            Paint()
              ..color = (solid ? hue : wb.paneBg)
                  .withValues(alpha: solid ? 0.95 * dim : 1.0));
        if (!solid) {
          canvas.drawCircle(
              p,
              dotR - 0.5,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1
                ..color = hue.withValues(alpha: 0.95 * dim));
        }
      }

      if (selected) {
        canvas.drawArc(
            Rect.fromCircle(center: c, radius: band.outer),
            arc.birthAngle,
            arc.deathAngle - arc.birthAngle,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = wb.text.withValues(alpha: 0.8));
      }

      _paintNameOnArc(canvas, c, band, arc, dim);
    }

    // The chain of descent: at each man's fathering year a hairline
    // drops from his band to his son's — the same year the son's arc
    // begins, so the line and the arc meet by arithmetic, not by
    // drawing. Sons follow fathers ring by ring, so ring+1 is the son.
    final tick = Paint()
      ..color = wb.mutedText.withValues(alpha: hasSelection ? 0.25 : 0.5)
      ..strokeWidth = 0.7;
    for (final arc in arcs) {
      final begat = arc.begatAngle;
      if (begat == null || arc.ring + 1 >= ringCount) continue;
      final father = ringRadii(arc.ring, ringCount, rHub, rMax);
      final son = ringRadii(arc.ring + 1, ringCount, rHub, rMax);
      final dir = Offset(math.cos(begat), math.sin(begat));
      canvas.drawLine(c + dir * son.outer, c + dir * father.inner, tick);
    }
  }

  void _paintNameOnArc(Canvas canvas, Offset c,
      ({double inner, double outer, double centre, double width}) band,
      WheelArc arc, double dim) {
    var name = data.byId(arc.personId)?.nameFor(locale) ?? arc.personId;
    // The printed chronologies set the years right on the bar, and the
    // owner asked for that density: append the lifespan when it fits.
    final span = data.byId(arc.personId)?.figures[traditionId]?.lifespan;
    if (span != null) name = '$name · $span';
    // The dark birth→fathering segment is usually the short one, so the
    // label lives on the long light segment when there is one.
    final segStart = arc.begatAngle ?? arc.birthAngle;
    final segEnd = arc.deathAngle;
    final available = segEnd - segStart;
    if (available <= 0) return;

    var fontSize = (band.width * 0.72).clamp(7.0, 12.0);
    for (var attempt = 0; attempt < 2; attempt++) {
      final style = TextStyle(
        color: wb.text.withValues(alpha: 0.9 * dim),
        fontSize: fontSize,
      );
      final widths = <double>[];
      var total = 0.0;
      for (final ch in name.characters) {
        final tp = TextPainter(
            text: TextSpan(text: ch, style: style),
            textDirection: TextDirection.ltr)
          ..layout();
        widths.add(tp.width);
        total += tp.width;
      }
      final angular = total / band.centre;
      if (angular <= available * 0.9) {
        _drawCharsOnArc(canvas, c, band.centre, name, widths, style,
            segStart + (available - angular) / 2, angular);
        return;
      }
      fontSize *= 0.85;
      if (fontSize < 6.5) break; // too tight — the tap reveals the name
    }
    // The years did not fit; the name alone still might.
    final sep = name.lastIndexOf(' · ');
    if (sep > 0) {
      _paintBareNameOnArc(canvas, c, band, arc, dim, name.substring(0, sep));
    }
  }

  void _paintBareNameOnArc(Canvas canvas, Offset c,
      ({double inner, double outer, double centre, double width}) band,
      WheelArc arc, double dim, String name) {
    final segStart = arc.begatAngle ?? arc.birthAngle;
    final available = arc.deathAngle - segStart;
    if (available <= 0) return;
    final fontSize = (band.width * 0.72).clamp(7.0, 12.0);
    final style = TextStyle(
      color: wb.text.withValues(alpha: 0.9 * dim),
      fontSize: fontSize,
    );
    final widths = <double>[];
    var total = 0.0;
    for (final ch in name.characters) {
      final tp = TextPainter(
          text: TextSpan(text: ch, style: style),
          textDirection: TextDirection.ltr)
        ..layout();
      widths.add(tp.width);
      total += tp.width;
    }
    final angular = total / band.centre;
    if (angular > available * 0.9) return;
    _drawCharsOnArc(canvas, c, band.centre, name, widths, style,
        segStart + (available - angular) / 2, angular);
  }

  void _drawCharsOnArc(Canvas canvas, Offset c, double radius, String text,
      List<double> widths, TextStyle style, double startAngle,
      double angularLen) {
    final mid = startAngle + angularLen / 2;
    // On the lower half of the wheel a tangential baseline runs upside
    // down; flip the glyphs and walk the arc backwards so the text
    // still reads left to right.
    final flip = math.sin(mid) > 0;
    var pen = flip ? startAngle + angularLen : startAngle;
    final chars = text.characters.toList();
    for (var i = 0; i < chars.length; i++) {
      final w = widths[i];
      final da = w / radius;
      final theta = flip ? pen - da / 2 : pen + da / 2;
      final tp = TextPainter(
          text: TextSpan(text: chars[i], style: style),
          textDirection: TextDirection.ltr)
        ..layout();
      canvas.save();
      canvas.translate(c.dx + math.cos(theta) * radius,
          c.dy + math.sin(theta) * radius);
      canvas.rotate(theta + (flip ? -math.pi / 2 : math.pi / 2));
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
      pen += flip ? -da : da;
    }
  }

  void _paintEpochs(Canvas canvas, Offset c, double rHub, double rMax) {
    final paint = Paint()
      ..color = _epochHue.withValues(alpha: 0.75)
      ..strokeWidth = 1.1;
    for (final e in data.epochs) {
      final year = e.years[traditionId];
      if (year == null) continue;
      final a = angleForYear(year, endAm);
      final dir = Offset(math.cos(a), math.sin(a));
      // Dashed by hand: 5 on, 4 off, hub to rim.
      var r = rHub;
      while (r < rMax) {
        final r2 = math.min(r + 5, rMax);
        canvas.drawLine(c + dir * r, c + dir * r2, paint);
        r = r2 + 4;
      }
      canvas.drawCircle(c + dir * rMax, 2.4,
          Paint()..color = _epochHue.withValues(alpha: 0.9));
      _paintRadialLabel(
          canvas, c, '${e.nameFor(locale)} · $year', a, rMax + 20);
    }
  }

  /// A label set along the radius direction just outside the rim,
  /// flipped on the left half so it never reads upside down.
  void _paintRadialLabel(
      Canvas canvas, Offset c, String text, double angle, double radius) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: _epochHue.withValues(alpha: 0.95), fontSize: rimFont)),
      textDirection: TextDirection.ltr,
    )..layout();
    final flip = math.cos(angle) < 0;
    canvas.save();
    canvas.translate(c.dx + math.cos(angle) * radius,
        c.dy + math.sin(angle) * radius);
    canvas.rotate(angle + (flip ? math.pi : 0));
    tp.paint(canvas,
        Offset(flip ? -tp.width : 0, -tp.height / 2));
    canvas.restore();
  }

  void _paintHubRing(Canvas canvas, Offset c, double rHub) {
    canvas.drawCircle(c, rHub, Paint()..color = wb.paneAltBg);
    canvas.drawCircle(
        c,
        rHub,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = wb.border);
  }

  void _paintAxisEnds(Canvas canvas, Offset c, double rHub, double rMax) {
    final paint = Paint()
      ..color = wb.border
      ..strokeWidth = 1;
    for (final (year, a) in [
      (0, angleForYear(0, endAm)),
      (endAm, angleForYear(endAm, endAm))
    ]) {
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * rHub, c + dir * rMax, paint);
      // Push the two boundary labels into the gap wedge so they cannot
      // sit on top of each other.
      final off = year == 0 ? -0.06 : 0.06;
      final la = a + off;
      _paintLabel(
          canvas,
          'AM $year',
          c + Offset(math.cos(la), math.sin(la)) * (rMax + 14),
          wb.text,
          endFont,
          center: true);
    }
  }

  void _paintLabel(Canvas canvas, String text, Offset at, Color color,
      double fontSize,
      {bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text, style: TextStyle(color: color, fontSize: fontSize)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
        canvas,
        center
            ? at - Offset(tp.width / 2, tp.height / 2)
            : at);
  }

  @override
  bool shouldRepaint(_WheelPainter old) =>
      old.traditionId != traditionId ||
      old.selectedId != selectedId ||
      old.locale != locale ||
      old.endAm != endAm ||
      old.rimFont != rimFont ||
      old.arcs.length != arcs.length;
}

// ── the full-history painter ──────────────────────────────────────────

/// Draws the −4000..2026 wheel: nine rings of dots, reigns and bands.
///
/// Shares the geometry of [_WheelPainter] but none of its data model,
/// so it is its own class; the handful of text helpers are duplicated
/// rather than shared because each painter's label sizing is derived
/// from its own ring widths.
class _HistoryWheelPainter extends CustomPainter {
  _HistoryWheelPainter({
    required this.items,
    required this.locale,
    required this.selectedId,
    required this.wb,
    required this.rimFont,
    required this.endFont,
  });

  final List<_HistItem> items;
  final String locale;
  final String? selectedId;
  final WbColors wb;
  final double rimFont;
  final double endFont;

  static const int _minY = -4000;
  static const int _maxY = 2026;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final c = Offset(size.width / 2, size.height / 2);
    final rHub = side * _kHubFrac;
    final rMax = side * _kRimFrac;

    _paintZones(canvas, c, rHub, rMax);
    _paintTicks(canvas, c, rHub, rMax);
    _paintItems(canvas, c, rHub, rMax);
    _paintRim(canvas, c, rMax);
    _paintHubRing(canvas, c, rHub);
    _paintAxisEnds(canvas, c, rHub, rMax);
  }

  /// The four annulus zones — Bible events, kings, powers, church —
  /// washed apart the way the engraved charts band their rings, so the
  /// eye finds the register before it reads a single label. The wash
  /// is cut as a donut path (rim circle + hub circle, even-odd) and
  /// clipped to the swept sector so the gap wedge stays paper-bare.
  void _paintZones(Canvas canvas, Offset c, double rHub, double rMax) {
    const zones = [
      (0, 2, Color(0xFF2A4FB0)), // Bible events — monarchy blue
      (3, 4, Color(0xFF5B87C4)), // kings
      (5, 6, Color(0xFF7A8B6F)), // powers
      (7, 8, Color(0xFF3E7CB1)), // church & scripture
    ];
    canvas.save();
    final sector = Path()
      ..moveTo(c.dx, c.dy)
      ..arcTo(Rect.fromCircle(center: c, radius: rMax + 2), startRad,
          sweepRad, false)
      ..close();
    canvas.clipPath(sector);
    for (final (first, last, hue) in zones) {
      final outer = ringRadii(first, _histRingCount, rHub, rMax).outer;
      final inner = ringRadii(last, _histRingCount, rHub, rMax).inner;
      final donut = Path()
        ..addOval(Rect.fromCircle(center: c, radius: outer + 1))
        ..addOval(Rect.fromCircle(center: c, radius: inner - 1))
        ..fillType = PathFillType.evenOdd;
      canvas.drawPath(
          donut, Paint()..color = hue.withValues(alpha: 0.055));
      canvas.drawCircle(
          c,
          outer + 1,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.4
            ..color = hue.withValues(alpha: 0.25));
    }
    canvas.restore();
  }

  /// The rim: a double ring, the engraved charts' outer border.
  void _paintRim(Canvas canvas, Offset c, double rMax) {
    for (final (r, w, a) in [(rMax + 2.0, 0.9, 0.6), (rMax + 5.0, 0.4, 0.35)]) {
      canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          startRad,
          sweepRad,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w
            ..color = wb.border.withValues(alpha: a));
    }
  }

  void _paintTicks(Canvas canvas, Offset c, double rHub, double rMax) {
    final minor = Paint()
      ..color = wb.border.withValues(alpha: 0.3)
      ..strokeWidth = 0.5;
    final major = Paint()
      ..color = wb.border.withValues(alpha: 0.65)
      ..strokeWidth = 0.9;
    var stagger = false;
    for (var y = _minY; y <= _maxY; y += 100) {
      if (y == _minY || y == _maxY) continue; // the end spokes own these
      final isMajor = y % 500 == 0;
      final a = angleForSpan(y, _minY, _maxY);
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
          c + dir * rHub, c + dir * rMax, isMajor ? major : minor);
      if (isMajor) {
        // Alternate the label radius so adjacent centuries clear each
        // other even at rest zoom — the engraved charts stagger their
        // rim years for the same reason.
        final rr = rMax + (stagger ? 19 : 10);
        stagger = !stagger;
        _paintLabel(canvas, yearLabel(y, locale), c + dir * rr,
            wb.mutedText, rimFont,
            center: true);
      }
    }
  }

  void _paintItems(Canvas canvas, Offset c, double rHub, double rMax) {
    final hasSelection = selectedId != null;
    // Sorted by ring then angle so label collision can be decided by
    // simply remembering where the previous label on the ring ended —
    // a label that will not fit cleanly is skipped, and the tap still
    // reveals the record. Overprinted type is the one thing the
    // engraved charts never allow themselves.
    final ordered = [...items]..sort((a, b) {
      final byRing = a.ring.compareTo(b.ring);
      return byRing != 0 ? byRing : a.a0.compareTo(b.a0);
    });
    final labelEnd = List<double>.filled(_histRingCount, double.negativeInfinity);
    for (final it in ordered) {
      final band = ringRadii(it.ring, _histRingCount, rHub, rMax);
      final selected = it.id == selectedId;
      final dim = hasSelection && !selected ? 0.4 : 1.0;

      if (it.isDot) {
        final p = c +
            Offset(math.cos(it.a0), math.sin(it.a0)) * band.centre;
        final dotR = band.width * 0.38;
        canvas.drawCircle(
            p, dotR, Paint()..color = it.color.withValues(alpha: 0.95 * dim));
        if (selected) {
          canvas.drawCircle(
              p,
              dotR + 1.5,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1
                ..color = wb.text);
        }
        // The label runs along the ring just after the dot. It is
        // drawn only if it clears the previous label on this ring —
        // a skipped label stays one tap away, an overprinted one is
        // lost to everybody.
        final gap = (dotR + 2) / band.centre;
        final drawn = _labelOnArc(canvas, c, band.centre, it.label,
            it.a0 + gap, 0.22, band.width * 0.62, dim,
            notBefore: labelEnd[it.ring]);
        if (drawn > 0) labelEnd[it.ring] = drawn;
      } else {
        final rect = Rect.fromCircle(center: c, radius: band.centre);
        final w = band.width * (it.kind == _HistKind.king ? 0.88 : 0.72);
        canvas.drawArc(
            rect,
            it.a0,
            it.a1 - it.a0,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = w
              ..color = it.color.withValues(
                  alpha: (it.kind == _HistKind.king ? 0.9 : 0.55) * dim));
        if (it.kind == _HistKind.king) {
          // A hairline at each accession, so forty adjacent reigns
          // read as forty reigns and not one long ribbon.
          final sep = Paint()
            ..strokeWidth = 0.7
            ..color = wb.paneBg.withValues(alpha: 0.9);
          for (final a in [it.a0, it.a1]) {
            final dir = Offset(math.cos(a), math.sin(a));
            canvas.drawLine(c + dir * (band.centre - w / 2),
                c + dir * (band.centre + w / 2), sep);
          }
        } else {
          canvas.drawArc(
              rect,
              it.a0,
              it.a1 - it.a0,
              false,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 0.5
                ..color = it.color.withValues(alpha: 0.7 * dim));
        }
        if (selected) {
          canvas.drawArc(
              Rect.fromCircle(center: c, radius: band.outer),
              it.a0,
              it.a1 - it.a0,
              false,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1
                ..color = wb.text.withValues(alpha: 0.85));
        }
        final drawn = _labelOnArc(canvas, c, band.centre, it.label, it.a0,
            it.a1 - it.a0, band.width * 0.6, dim,
            centreIn: it.a1 - it.a0, notBefore: labelEnd[it.ring]);
        if (drawn > 0) labelEnd[it.ring] = drawn;
      }
    }
  }

  /// A tangential label along the ring, flipped upright on the lower
  /// half, skipped entirely when even the shrunken form cannot fit in
  /// [maxAngular] or would start before [notBefore] — the previous
  /// label's end on this ring. Returns the angle the label ends at,
  /// or 0 when nothing was drawn, so the caller can carry the
  /// occupancy forward.
  double _labelOnArc(Canvas canvas, Offset c, double radius, String text,
      double startAngle, double maxAngular, double fontSizeIn, double dim,
      {double? centreIn, double notBefore = double.negativeInfinity}) {
    var fontSize = fontSizeIn.clamp(6.5, 10.5);
    for (var attempt = 0; attempt < 2; attempt++) {
      final style = TextStyle(
        color: wb.text.withValues(alpha: 0.85 * dim),
        fontSize: fontSize,
      );
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
      if (angular <= maxAngular * 0.95) {
        var a0 = startAngle;
        if (centreIn != null && angular < centreIn) {
          a0 = startAngle + (centreIn - angular) / 2;
        }
        // A whisker of clearance between neighbouring labels.
        if (a0 < notBefore + 0.012) {
          a0 = notBefore + 0.012;
          // Re-centred labels may no longer fit their band once pushed.
          if (centreIn != null && a0 + angular > startAngle + centreIn) {
            return 0;
          }
        }
        // Nothing may run into the gap wedge.
        if (a0 + angular > startRad + sweepRad) return 0;
        _drawChars(canvas, c, radius, text, widths, style, a0, angular);
        return a0 + angular;
      }
      fontSize *= 0.82;
      if (fontSize < 6) return 0;
    }
    return 0;
  }

  void _drawChars(Canvas canvas, Offset c, double radius, String text,
      List<double> widths, TextStyle style, double startAngle,
      double angularLen) {
    final mid = startAngle + angularLen / 2;
    final flip = math.sin(mid) > 0;
    var pen = flip ? startAngle + angularLen : startAngle;
    final chars = text.characters.toList();
    for (var i = 0; i < chars.length; i++) {
      final w = widths[i];
      final da = w / radius;
      final theta = flip ? pen - da / 2 : pen + da / 2;
      final tp = TextPainter(
          text: TextSpan(text: chars[i], style: style),
          textDirection: TextDirection.ltr)
        ..layout();
      canvas.save();
      canvas.translate(c.dx + math.cos(theta) * radius,
          c.dy + math.sin(theta) * radius);
      canvas.rotate(theta + (flip ? -math.pi / 2 : math.pi / 2));
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
      pen += flip ? -da : da;
    }
  }

  void _paintHubRing(Canvas canvas, Offset c, double rHub) {
    canvas.drawCircle(c, rHub, Paint()..color = wb.paneAltBg);
    canvas.drawCircle(
        c,
        rHub,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = wb.border);
  }

  void _paintAxisEnds(Canvas canvas, Offset c, double rHub, double rMax) {
    final paint = Paint()
      ..color = wb.border
      ..strokeWidth = 1;
    for (final (year, off) in [(_minY, -0.06), (_maxY, 0.06)]) {
      final a = angleForSpan(year, _minY, _maxY);
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * rHub, c + dir * rMax, paint);
      final la = a + off;
      _paintLabel(
          canvas,
          yearLabel(year, locale),
          c + Offset(math.cos(la), math.sin(la)) * (rMax + 14),
          wb.text,
          endFont,
          center: true);
    }
  }

  void _paintLabel(Canvas canvas, String text, Offset at, Color color,
      double fontSize,
      {bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text, style: TextStyle(color: color, fontSize: fontSize)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
        canvas,
        center ? at - Offset(tp.width / 2, tp.height / 2) : at);
  }

  @override
  bool shouldRepaint(_HistoryWheelPainter old) =>
      old.selectedId != selectedId ||
      old.locale != locale ||
      old.rimFont != rimFont ||
      old.items.length != items.length;
}
