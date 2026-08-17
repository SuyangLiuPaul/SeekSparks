import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/chronology.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/chronology_service.dart';
import 'package:seeksparks/utils/chronology_layout.dart';
import 'package:seeksparks/utils/jump_to_reference.dart' as jumper;
import 'package:seeksparks/utils/navigate_to_reader.dart';
import 'package:seeksparks/utils/reference_parser.dart';
import 'package:seeksparks/widgets/home_icon_button.dart';
import 'package:seeksparks/widgets/language_switcher_button.dart';
import 'package:seeksparks/widgets/localized_back_button.dart';

/// The generations from Adam to Abraham, drawn as lifespans on one axis.
///
/// WHAT THIS IS FOR. Genesis 5 and 11 read as a list of strangers: a
/// name, a number, "and he died", forty times over. Every printed
/// chronology since the 17th century has been an attempt to fix that,
/// and they all do it the same way — draw each life as a bar on a shared
/// axis, and the generations stop being a list and become a crowd.
/// Adam turns out to be still alive when Lamech, Noah's father, is born.
/// Methuselah turns out to die in the year of the flood. Shem turns out
/// to outlive Abraham. **None of those sentences is in the Bible.** Each
/// is a consequence of adding up ages that are, and no reader gets there
/// from the list.
///
/// WHY THE BARS AND NOT A FAN. The chart this was asked for is radial,
/// time fanning out from a centre, and it is beautiful. It is also worse
/// at the one job here: bars set on different angles cannot be compared
/// by eye, and comparing durations is the entire exercise. A horizontal
/// axis makes "who was alive together" a vertical scan, which is why
/// selecting a man draws his life as a band down every other row. The
/// visual grammar is kept — duration as a bar, colour by line of
/// descent, every figure carrying its verse — because that grammar is
/// centuries old and belongs to nobody; the artwork it was seen in is
/// under copyright and is not.
///
/// WHY IT SAYS MASORETIC OR SEPTUAGINT AND NEVER JUST "BC". The two
/// texts state different ages. The Hebrew has Adam fathering Seth at
/// 130, the Greek at 230, and the difference compounds down the chapter
/// until the flood sits 586 years apart between them. Both texts ship
/// with this app, so both are charted and the reader picks. The axis is
/// Anno Mundi because that is the only frame the text supplies; turning
/// it into BC needs an absolute anchor the text never gives, and
/// Ussher's 4004 BC is one such anchor, not a fact.
///
/// Chrome follows workbench_theme.dart: square corners, 1px hairlines,
/// no shadows, no cards.
class ChronologyPage extends StatefulWidget {
  const ChronologyPage({super.key});

  @override
  State<ChronologyPage> createState() => _ChronologyPageState();
}

/// The lane, the row and the panel are measured in the reader's own text
/// size, not in fixed pixels, because all three hold text the font-size
/// slider scales by 0.6×–2×. A fixed 132 px lane is right at the default
/// 20 pt and wrong at 40 pt, where the longest name here needs about
/// twice that and — being deliberately un-ellipsised, per #297 — would
/// paint straight across the bars instead of being cut. The numbers are
/// the values at the default setting, so the chart as most readers see
/// it is unchanged.
double _nameLane(WbType t) => t.scaled(132);
double _rowHeight(WbType t) => t.scaled(30);

/// Chrome scale, not text: the only thing in the axis strip is the tick
/// labels and the unit, both of which the Menu Size slider owns.
double _axisHeight(WbType t) => t.scaledChrome(30);
double _detailPanelWidth(WbType t) => t.scaled(320);

/// The narrowest strip of bars worth drawing. A chart of 3,449 years in
/// less than this puts a whole generation inside 20 px.
const double _minBarsForPanel = 448;

/// The chart scrolls sideways rather than compressing below this. Under
/// it a 148-year life — Nahor's, the shortest here — falls under 6 px
/// and stops being a bar at all.
const double _minChartWidth = 520;

/// Below this the detail moves to a sheet. Derived rather than declared:
/// the old 900 was exactly this sum at the default setting, and writing
/// it as a literal let the threshold drift away from the two widths it
/// exists to protect once either of them started scaling.
double _sideBySideMinWidth(WbType t) =>
    _detailPanelWidth(t) + _nameLane(t) + _minBarsForPanel;

/// Seth's line in Genesis 5, Shem's in Genesis 11. Two hues, far enough
/// apart to survive the wash used for "contemporary" without either
/// reading as the other.
const Color _sethHue = Color(0xFF5B87C4);
const Color _shemHue = Color(0xFFC4885B);

Color _hueFor(String? line) => line == 'shem' ? _shemHue : _sethHue;

class _ChronologyPageState extends State<ChronologyPage> {
  Future<ChronologyData>? _future;
  String _tradition = 'mt';
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _future = ChronologyService.instance.load();
  }

  void _select(String? id) =>
      setState(() => _selectedId = _selectedId == id ? null : id);

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    final wb = WbColors.of(context);
    String s(String key, String fallback) =>
        uiStrings[key]?[locale] ?? fallback;

    return Scaffold(
      backgroundColor: wb.paneBg,
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(s('chronology', 'Bible Chronology')),
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

    // The axis always starts at the creation and runs to the last death
    // in the tradition on show, so switching tradition visibly rescales
    // the whole chart. That rescaling is the point: the Septuagint's
    // world is 1,262 years longer than the Masoretic one by Terah's
    // death, and a fixed axis would hide it.
    const firstYear = 0;
    final lastYear = tradition.endAm;

    final selected =
        _selectedId == null ? null : data.byId(_selectedId!);
    final selectedFigures =
        selected == null ? null : selected.figures[tradition.id];

    return LayoutBuilder(builder: (context, box) {
      final sideBySide = box.maxWidth >= _sideBySideMinWidth(t);
      final chartOuter =
          sideBySide && selectedFigures != null
              ? box.maxWidth - _detailPanelWidth(t)
              : box.maxWidth;

      final chart = _Chart(
        data: data,
        tradition: tradition,
        people: people,
        firstYear: firstYear,
        lastYear: lastYear,
        available: chartOuter,
        locale: locale,
        selectedId: _selectedId,
        onSelect: (id) {
          _select(id);
          if (!sideBySide && id != null) {
            final p = data.byId(id);
            final f = p?.figures[tradition.id];
            if (p != null && f != null) {
              _showDetailSheet(data, p, f, tradition, locale);
            }
          }
        },
      );

      final left = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            data: data,
            tradition: tradition,
            locale: locale,
            onTradition: (id) => setState(() => _tradition = id),
          ),
          Expanded(child: chart),
        ],
      );

      if (!sideBySide || selectedFigures == null) return left;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          Container(width: 1, color: wb.border),
          SizedBox(
            width: _detailPanelWidth(t),
            child: _DetailPanel(
              data: data,
              person: selected!,
              figures: selectedFigures,
              tradition: tradition,
              locale: locale,
              onSelect: _select,
              onClose: () => _select(null),
            ),
          ),
        ],
      );
    });
  }

  Future<void> _showDetailSheet(
    ChronologyData data,
    Patriarch person,
    ChronologyFigures figures,
    ChronologyTradition tradition,
    String locale,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => _DetailPanel(
          data: data,
          person: person,
          figures: figures,
          tradition: tradition,
          locale: locale,
          scrollController: controller,
          onSelect: (id) {
            final other = id == null ? null : data.byId(id);
            final f = other?.figures[tradition.id];
            Navigator.of(sheetCtx).maybePop();
            if (other == null || f == null) return;
            setState(() => _selectedId = other.id);
            _showDetailSheet(data, other, f, tradition, locale);
          },
          onClose: () => Navigator.of(sheetCtx).maybePop(),
        ),
      ),
    );
  }
}

/// Tradition switch, and the two sentences that keep the chart honest.
class _Header extends StatelessWidget {
  const _Header({
    required this.data,
    required this.tradition,
    required this.locale,
    required this.onTradition,
  });

  final ChronologyData data;
  final ChronologyTradition tradition;
  final String locale;
  final ValueChanged<String> onTradition;

  String _s(String key, String fallback) =>
      uiStrings[key]?[locale] ?? fallback;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final flood = data.epochs.where((e) => e.id == 'flood').firstOrNull;
    final floodYear = flood?.years[tradition.id];

    return Container(
      decoration: BoxDecoration(
        color: wb.chromeBg,
        border: Border(bottom: BorderSide(color: wb.border)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                _s('chronologyText', 'Text'),
                style: TextStyle(fontSize: t.chrome, color: wb.mutedText),
              ),
              for (final tr in data.traditions)
                _Pill(
                  label: tr.nameFor(locale),
                  selected: tr.id == tradition.id,
                  onTap: () => onTradition(tr.id),
                ),
              if (floodYear != null)
                Text(
                  '${flood!.nameFor(locale)} · ${_s('chronologyAm', 'AM')} $floodYear',
                  style: TextStyle(fontSize: t.chrome, color: wb.mutedText),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // The long name, so a reader is never looking at a chart whose
          // source is only identified by a three-letter pill.
          Text(
            tradition.longNameFor(locale),
            style: TextStyle(fontSize: t.chrome, color: wb.mutedText),
          ),
          for (final n in data.notesFor(tradition.id))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                n.textFor(locale),
                style: TextStyle(fontSize: t.chrome, color: wb.text),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? wb.selectionBg : Colors.transparent,
          border: Border.all(color: selected ? wb.link : wb.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: t.chrome,
            color: selected ? wb.link : wb.text,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({
    required this.data,
    required this.tradition,
    required this.people,
    required this.firstYear,
    required this.lastYear,
    required this.available,
    required this.locale,
    required this.selectedId,
    required this.onSelect,
  });

  final ChronologyData data;
  final ChronologyTradition tradition;
  final List<Patriarch> people;
  final int firstYear;
  final int lastYear;
  final double available;
  final String locale;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  String _s(String key, String fallback) =>
      uiStrings[key]?[locale] ?? fallback;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);

    final lane = _nameLane(t);
    final barsWidth =
        (available - lane).clamp(_minChartWidth, double.infinity);
    final totalWidth = lane + barsWidth;
    final ticks = axisTicks(firstYear, lastYear, barsWidth);

    final selected = selectedId == null ? null : data.byId(selectedId!);
    final selectedFigures = selected?.figures[tradition.id];

    final floodYear =
        data.epochs.where((e) => e.id == 'flood').firstOrNull?.years[tradition.id];

    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The axis stays out of the vertical scroller so the years
              // remain readable while the rows move under them.
              SizedBox(
                height: _axisHeight(t),
                child: Row(
                  children: [
                    SizedBox(
                      width: lane,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            _s('chronologyAm', 'AM'),
                            style: TextStyle(
                                fontSize: t.chrome, color: wb.mutedText),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: CustomPaint(
                        painter: _AxisPainter(
                          ticks: ticks,
                          firstYear: firstYear,
                          lastYear: lastYear,
                          border: wb.border,
                          textColor: wb.mutedText,
                          fontSize: t.scaledChrome(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: wb.border),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final p in people)
                        _Row(
                          person: p,
                          figures: p.figures[tradition.id]!,
                          firstYear: firstYear,
                          lastYear: lastYear,
                          barsWidth: barsWidth,
                          ticks: ticks,
                          floodYear: floodYear,
                          locale: locale,
                          selected: p.id == selectedId,
                          selectedSpan: selectedFigures == null
                              ? null
                              : (selectedFigures.birthAm,
                                  selectedFigures.deathAm),
                          selectedHue: _hueFor(selected?.line),
                          onTap: () => onSelect(p.id),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AxisPainter extends CustomPainter {
  _AxisPainter({
    required this.ticks,
    required this.firstYear,
    required this.lastYear,
    required this.border,
    required this.textColor,
    required this.fontSize,
  });

  final List<int> ticks;
  final int firstYear;
  final int lastYear;
  final Color border;
  final Color textColor;
  final double fontSize;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = border
      ..strokeWidth = 1;
    for (final year in ticks) {
      final x = xForYear(year, firstYear, lastYear, size.width);
      canvas.drawLine(
          Offset(x, size.height - 5), Offset(x, size.height), line);
      final tp = TextPainter(
        text: TextSpan(
          text: '$year',
          style: TextStyle(color: textColor, fontSize: fontSize),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - 6 - tp.height));
    }
  }

  @override
  bool shouldRepaint(_AxisPainter old) =>
      old.ticks != ticks ||
      old.firstYear != firstYear ||
      old.lastYear != lastYear ||
      old.fontSize != fontSize ||
      old.textColor != textColor;
}

class _Row extends StatelessWidget {
  const _Row({
    required this.person,
    required this.figures,
    required this.firstYear,
    required this.lastYear,
    required this.barsWidth,
    required this.ticks,
    required this.floodYear,
    required this.locale,
    required this.selected,
    required this.selectedSpan,
    required this.selectedHue,
    required this.onTap,
  });

  final Patriarch person;
  final ChronologyFigures figures;
  final int firstYear;
  final int lastYear;
  final double barsWidth;
  final List<int> ticks;
  final int? floodYear;
  final String locale;
  final bool selected;
  final (int, int)? selectedSpan;
  final Color selectedHue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final hue = _hueFor(person.line);

    // Overlap with whoever is selected. This is the number the chart
    // exists to produce, so it is shown on the row itself rather than
    // only in the panel — a reader comparing two lives should not have
    // to open anything.
    final overlap = selectedSpan == null
        ? 0
        : sharedYears(figures.birthAm, figures.deathAm, selectedSpan!.$1,
            selectedSpan!.$2);
    final contemporary = !selected && overlap > 0;

    return InkWell(
      onTap: onTap,
      child: Container(
        height: _rowHeight(t),
        decoration: BoxDecoration(
          color: selected ? wb.selectionBg : null,
          border: Border(bottom: BorderSide(color: wb.border, width: 0.5)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: _nameLane(t),
              child: Padding(
                padding: const EdgeInsets.only(left: 8, right: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        person.nameFor(locale),
                        maxLines: 1,
                        // Never ellipsised: a CJK label cut mid-character
                        // is unreadable, and the lane is sized for the
                        // longest of these names in all three locales.
                        overflow: TextOverflow.visible,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: t.text,
                          color: wb.text,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (contemporary)
                      Text(
                        '$overlap',
                        style: TextStyle(
                            fontSize: t.scaledChrome(10), color: wb.link),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: CustomPaint(
                painter: _BarPainter(
                  birth: figures.birthAm,
                  death: figures.deathAm,
                  begat: figures.birthAm + figures.begatAt,
                  firstYear: firstYear,
                  lastYear: lastYear,
                  ticks: ticks,
                  floodYear: floodYear,
                  selectedSpan: selectedSpan,
                  hue: hue,
                  selectedHue: selectedHue,
                  gridColor: wb.border,
                  selected: selected,
                  contemporary: contemporary,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.birth,
    required this.death,
    required this.begat,
    required this.firstYear,
    required this.lastYear,
    required this.ticks,
    required this.floodYear,
    required this.selectedSpan,
    required this.hue,
    required this.selectedHue,
    required this.gridColor,
    required this.selected,
    required this.contemporary,
  });

  final int birth;
  final int death;

  /// The year the next man in the line was born. The bar is drawn solid
  /// up to here and pale after it, so the eye can follow the descent
  /// along the chart without a second lane of marks.
  final int begat;
  final int firstYear;
  final int lastYear;
  final List<int> ticks;
  final int? floodYear;
  final (int, int)? selectedSpan;
  final Color hue;

  /// The line of descent of the man who is selected, which is not
  /// necessarily this row's.
  final Color selectedHue;
  final Color gridColor;
  final bool selected;
  final bool contemporary;

  @override
  void paint(Canvas canvas, Size size) {
    double x(int year) => xForYear(year, firstYear, lastYear, size.width);

    final grid = Paint()
      ..color = gridColor.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    for (final year in ticks) {
      canvas.drawLine(Offset(x(year), 0), Offset(x(year), size.height), grid);
    }

    // The selected man's life, drawn straight down every row. This is
    // what makes "who was alive with him" a glance instead of a
    // calculation.
    //
    // In HIS colour, not the row's. The band is one fact about one man,
    // so tinting it by the line each row belongs to made a single span
    // read as two — blue over Seth's descendants and brown over Shem's,
    // changing colour halfway down the chart for a reason that has
    // nothing to do with the man it describes.
    final span = selectedSpan;
    if (span != null) {
      canvas.drawRect(
        Rect.fromLTRB(x(span.$1), 0, x(span.$2), size.height),
        Paint()..color = selectedHue.withValues(alpha: 0.07),
      );
    }

    if (floodYear != null) {
      canvas.drawLine(
        Offset(x(floodYear!), 0),
        Offset(x(floodYear!), size.height),
        Paint()
          ..color = const Color(0xFF3E7CB1)
          ..strokeWidth = 1.5,
      );
    }

    final top = size.height / 2 - 6;
    final left = x(birth);
    final right = x(death);
    final mid = x(begat.clamp(birth, death));

    // Square corners, per workbench_theme.dart:16.
    canvas.drawRect(
      Rect.fromLTRB(left, top, mid, top + 12),
      Paint()..color = hue.withValues(alpha: selected || contemporary ? 1 : 0.75),
    );
    canvas.drawRect(
      Rect.fromLTRB(mid, top, right, top + 12),
      Paint()
        ..color =
            hue.withValues(alpha: selected || contemporary ? 0.45 : 0.3),
    );
    if (selected) {
      canvas.drawRect(
        Rect.fromLTRB(left, top, right, top + 12),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = hue,
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.birth != birth ||
      old.death != death ||
      old.begat != begat ||
      old.firstYear != firstYear ||
      old.lastYear != lastYear ||
      old.floodYear != floodYear ||
      old.selectedSpan != selectedSpan ||
      old.selected != selected ||
      old.contemporary != contemporary ||
      old.hue != hue ||
      old.selectedHue != selectedHue;
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.data,
    required this.person,
    required this.figures,
    required this.tradition,
    required this.locale,
    required this.onSelect,
    required this.onClose,
    this.scrollController,
  });

  final ChronologyData data;
  final Patriarch person;
  final ChronologyFigures figures;
  final ChronologyTradition tradition;
  final String locale;
  final ValueChanged<String?> onSelect;
  final VoidCallback onClose;
  final ScrollController? scrollController;

  String _s(String key, String fallback) =>
      uiStrings[key]?[locale] ?? fallback;

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

  @override
  Widget build(BuildContext context) {
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

    return Container(
      color: wb.paneBg,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  person.nameFor(locale),
                  style: TextStyle(
                      fontSize: t.scaled(22),
                      fontWeight: FontWeight.w600,
                      color: wb.text),
                ),
              ),
              IconButton(
                onPressed: onClose,
                iconSize: t.scaledChrome(18),
                icon: const Icon(Icons.close),
                tooltip: _s('close', 'Close'),
              ),
            ],
          ),
          Text(
            '${_s('chronologyAm', 'AM')} ${figures.birthAm} – ${figures.deathAm}'
            ' · ${figures.lifespan} ${_s('chronologyYears', 'years')}',
            style: TextStyle(fontSize: t.text, color: wb.mutedText),
          ),
          const SizedBox(height: 12),
          _Fact(
            label: _s('chronologyBegatAt', 'Fathered the next generation at'),
            value:
                '${figures.begatAt} ${_s('chronologyYears', 'years')}',
            reference: figures.refs['begatAt'],
            onTap: _jump,
          ),
          _Fact(
            label: _s('chronologyLivedAfter', 'Lived after that'),
            value:
                '${figures.livedAfter} ${_s('chronologyYears', 'years')}',
            reference: figures.refs['livedAfter'],
            onTap: _jump,
          ),
          _Fact(
            label: _s('chronologyLifespan', 'Lifespan'),
            value:
                '${figures.lifespan} ${_s('chronologyYears', 'years')}',
            reference: figures.refs['lifespan'],
            onTap: _jump,
          ),
          const SizedBox(height: 6),
          // Says which figures the text itself checked and which were
          // added up. Two numbers that look alike are not equally sure,
          // and the surface that shows them should say so.
          Text(
            figures.checked
                ? _s('chronologyChecked',
                    'The text states all three figures, and the third checks the other two.')
                : _s('chronologyDerived',
                    'The text states two of these figures; the third is their sum.'),
            style: TextStyle(fontSize: t.chrome, color: wb.mutedText),
          ),
          const SizedBox(height: 16),
          Text(
            '${_s('chronologyContemporaries', 'Alive at the same time')} · ${others.length}',
            style: TextStyle(
                fontSize: t.text,
                fontWeight: FontWeight.w600,
                color: wb.text),
          ),
          const SizedBox(height: 2),
          Text(
            _s('chronologyContemporariesNote',
                'Not stated anywhere in the text — this follows from adding up the ages it gives.'),
            style: TextStyle(fontSize: t.chrome, color: wb.mutedText),
          ),
          const SizedBox(height: 6),
          for (final c in others)
            InkWell(
              onTap: () => onSelect(c.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        data.byId(c.id)?.nameFor(locale) ?? c.id,
                        style: TextStyle(fontSize: t.text, color: wb.link),
                      ),
                    ),
                    Text(
                      '${c.years} ${_s('chronologyYears', 'years')}',
                      style:
                          TextStyle(fontSize: t.chrome, color: wb.mutedText),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            data.unitNote,
            style: TextStyle(fontSize: t.chrome, color: wb.mutedText),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.label,
    required this.value,
    required this.reference,
    required this.onTap,
  });

  final String label;
  final String value;
  final String? reference;
  final Future<void> Function(BuildContext, String) onTap;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final ref = reference;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: t.chrome, color: wb.mutedText)),
          Row(
            children: [
              Text(value, style: TextStyle(fontSize: t.text, color: wb.text)),
              const SizedBox(width: 8),
              if (ref != null)
                InkWell(
                  onTap: () => onTap(context, ref),
                  child: Text(ref,
                      style: TextStyle(fontSize: t.chrome, color: wb.link)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
