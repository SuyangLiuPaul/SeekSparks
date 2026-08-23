import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/chronology.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/chronology_service.dart';
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
};

class _RadialChronologyPageState extends State<RadialChronologyPage> {
  Future<ChronologyData>? _future;
  String _tradition = 'mt';
  String? _selectedId;
  final _viewerController = TransformationController();

  @override
  void initState() {
    super.initState();
    _future = ChronologyService.instance.load();
  }

  @override
  void dispose() {
    _viewerController.dispose();
    super.dispose();
  }

  String _s(String key, String fallback, String locale) =>
      uiStrings[key]?[locale] ?? wheelStrings[key]?[locale] ?? fallback;

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
      body: FutureBuilder<ChronologyData>(
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
          return _body(context, data, locale);
        },
      ),
    );
  }

  Widget _body(BuildContext context, ChronologyData data, String locale) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final tradition = data.traditionById(_tradition);
    final people = data.inTradition(tradition.id);
    final endAm = tradition.endAm;
    final arcs = buildWheelArcs(people, tradition.id, endAm);

    return LayoutBuilder(builder: (context, box) {
      // The wheel wants a square; give it the largest one the pane
      // holds, and let InteractiveViewer supply what the pane cannot.
      final side = math.min(box.maxWidth, box.maxHeight);
      final square = Size(side, side);
      final hubD = side * _kHubFrac * 2;

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
                  onTapUp: (d) => _handleTap(
                      context, d.localPosition, side, data, arcs, locale),
                  child: Stack(children: [
                    CustomPaint(
                      size: square,
                      painter: _WheelPainter(
                        data: data,
                        traditionId: tradition.id,
                        arcs: arcs,
                        endAm: endAm,
                        locale: locale,
                        selectedId: _selectedId,
                        wb: wb,
                        rimFont: t.scaledChrome(9),
                        endFont: t.scaledChrome(10),
                      ),
                    ),
                    // The hub is real widgets, not paint, so the
                    // tradition choice stays a real tappable control at
                    // any zoom.
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
                            SizedBox(height: t.scaled(6)),
                            _traditionPills(data, locale, t, wb),
                            SizedBox(height: t.scaled(6)),
                            Text(
                              '${_s('chronologyAm', 'AM', locale)} 0 – $endAm',
                              style: TextStyle(
                                  color: wb.mutedText,
                                  fontSize: t.scaled(10)),
                            ),
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
        Positioned(left: 10, bottom: 10, child: _legend(locale, t, wb)),
      ]);
    });
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
  }

  void _paintNameOnArc(Canvas canvas, Offset c,
      ({double inner, double outer, double centre, double width}) band,
      WheelArc arc, double dim) {
    final name = data.byId(arc.personId)?.nameFor(locale) ?? arc.personId;
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
      if (fontSize < 6.5) return; // too tight — the tap reveals the name
    }
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
