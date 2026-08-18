import 'package:flutter/foundation.dart' show listEquals;
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

/// The generations from Adam to Joseph, drawn as lifespans on one axis.
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
/// WHERE IT STOPS. At the death of Moses. Exodus 12:40 covers different
/// ground in the two texts — the Hebrew's 430 years are in Egypt, the
/// Greek's in Egypt *and* Canaan — and each is counted from where its
/// own wording starts it, which is the same thing this chart does
/// everywhere else rather than a choice between them. It stops after
/// Moses because the verse that would carry it on, 1 Kings 6:1, states
/// its year as an ordinal that the generator's number-reader cannot read
/// in either language.
///
/// The rows are four kinds of source, and the colour says which: Genesis
/// 5 and 11 state their figures in a formula, Genesis 12-50 scatters
/// them through narrative, and Moses and Aaron are read out of Exodus,
/// Numbers and Deuteronomy. A row whose `refs` lack a key was derived
/// rather than read. See `scripts/build_chronology.py`.
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

/// Chrome scale, not text: the only things in the axis strip are the
/// tick labels, the epoch names and the unit, all of which the Menu Size
/// slider owns.
double _axisFont(WbType t) => t.scaledChrome(10);

/// The strip is sized from the line it must hold, measured, rather than
/// from a pixel count that happens to be right at one setting. A CJK
/// glyph is in the probe because it is the tallest thing the strip ever
/// holds and it is what the Chinese epoch names are set in.
double _axisHeight(WbType t) {
  final probe = TextPainter(
    text: TextSpan(
      text: '年0',
      style: TextStyle(fontSize: _axisFont(t)),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  return axisStripHeight(probe.height);
}
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

/// Seth's line in Genesis 5, Shem's in Genesis 11, the patriarchs in
/// Genesis 12-50, and Moses and Aaron from the four books after it. Four
/// hues, far enough apart to survive the wash used for "contemporary"
/// without any of them reading as another.
///
/// Colour is the SECOND channel here, not the first: every bar is named
/// in the lane beside it and the four groups are contiguous down the
/// chart, so a reader who cannot separate the hues loses nothing they
/// were relying on. That is why a third and now a fourth could be added
/// at all — the original blue/orange pair was safe for colour-blind
/// readers and four hues cannot be. The plum is the darkest of the four
/// so that the pair a red-green reader is likeliest to merge it with
/// still differs in weight.
const Color _sethHue = Color(0xFF5B87C4);
const Color _shemHue = Color(0xFFC4885B);
const Color _abrahamHue = Color(0xFF4F8F6E);
const Color _leviHue = Color(0xFF8B6BA8);

Color _hueFor(String? line) => switch (line) {
      'shem' => _shemHue,
      'abraham' => _abrahamHue,
      'levi' => _leviHue,
      _ => _sethHue,
    };

/// The colour every epoch line is drawn in. One colour, because the
/// lines are told apart by the name printed above each in the axis
/// strip; a palette would say the difference twice and the second
/// saying would be the one a colour-blind reader could not read.
const Color _epochHue = Color(0xFF3E7CB1);

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

/// Tradition switch, and the sentences that keep the chart honest.
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
    final notes = data.notesFor(tradition.id);
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
              // Every epoch, with the verse that dates it. The name and
              // the position are on the chart; what only this line can
              // give is the exact year and the reference behind it,
              // which is the claim the whole module rests on.
              for (final e in data.epochs)
                if (e.years[tradition.id] != null)
                  Text(
                    '${e.nameFor(locale)} · ${_s('chronologyAm', 'AM')} '
                    '${e.years[tradition.id]}'
                    '${e.ref == null ? '' : ' · ${e.ref}'}',
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
          // The caveats about the chart itself, in full. The header is
          // the chart's sibling rather than something laid over it, so
          // every line here is a line of chart — which is why the ones
          // about a particular man are not repeated in it.
          for (final n in notes)
            if (n.personId == null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  n.textFor(locale),
                  style: TextStyle(fontSize: t.chrome, color: wb.text),
                ),
              ),
          // And the men who carry one, named. While the axis stopped at
          // Joseph there were two notes and both could be printed here;
          // carrying it to Moses brought as many as six, and six
          // paragraphs would have pushed the thing they are about off
          // the screen. Naming the men instead keeps every caveat one
          // tap away and tells a reader who has selected nobody that
          // they are there — which is the whole reason the notes were in
          // the header to begin with.
          if (_peopleWithNotes().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${_s('chronologyMoreOn', 'More on (select to read)')} · '
                '${_peopleWithNotes().join(' · ')}',
                style: TextStyle(fontSize: t.chrome, color: wb.mutedText),
              ),
            ),
        ],
      ),
    );
  }

  /// In chart order, and without repeats — a man with two caveats is
  /// still one name.
  List<String> _peopleWithNotes() {
    final ids = <String>{
      for (final n in data.notesFor(tradition.id))
        if (n.personId != null) n.personId!,
    };
    return [
      for (final p in data.inTradition(tradition.id))
        if (ids.contains(p.id)) p.nameFor(locale),
    ];
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

    final epochs = [
      for (final e in data.epochs)
        if (e.years[tradition.id] != null)
          (e.years[tradition.id]!, e.nameFor(locale)),
    ];
    final epochYears = [for (final e in epochs) e.$1];

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
                        key: const ValueKey('chronologyAxis'),
                        painter: _AxisPainter(
                          ticks: ticks,
                          epochs: epochs,
                          firstYear: firstYear,
                          lastYear: lastYear,
                          border: wb.border,
                          textColor: wb.mutedText,
                          epochColor: _epochHue,
                          fontSize: _axisFont(t),
                        ),
                        // Without a child a CustomPaint takes the
                        // smallest height its constraints allow, which
                        // inside a Row is zero — the painter was laying
                        // its labels out against a canvas of no height
                        // and drawing them above the strip it was given.
                        child: const SizedBox.expand(),
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
                          epochYears: epochYears,
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
    required this.epochs,
    required this.firstYear,
    required this.lastYear,
    required this.border,
    required this.textColor,
    required this.epochColor,
    required this.fontSize,
  });

  final List<int> ticks;

  /// Year and name, in the order the asset lists them.
  final List<(int, String)> epochs;
  final int firstYear;
  final int lastYear;
  final Color border;
  final Color textColor;
  final Color epochColor;
  final double fontSize;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = border
      ..strokeWidth = 1;
    final tickTop = size.height - 6;
    // Where the year labels start, so the epoch rules can stop above
    // them. Taken from the labels themselves rather than from the font
    // size, which is smaller than the line the glyphs occupy.
    var yearLabelTop = tickTop;
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
      yearLabelTop = tickTop - tp.height;
      tp.paint(canvas, Offset(x - tp.width / 2, yearLabelTop));
    }

    // Every vertical line the chart draws over the bars is named here.
    // Three unlabelled rules would leave a reader guessing which was the
    // flood, and a chart that draws an event without naming it is making
    // a claim it has not stated.
    //
    // Labels alternate between two rows and are clamped inside the
    // strip, so an epoch near either end keeps its whole name rather
    // than losing half of it off the edge — an epoch name is not
    // ellipsised, per #297, and would otherwise paint past the canvas.
    final placed = <(TextPainter, double, double, double)>[];
    for (var i = 0; i < epochs.length; i++) {
      final (year, label) = epochs[i];
      final x = xForYear(year, firstYear, lastYear, size.width);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: epochColor, fontSize: fontSize),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final rowTop = i.isEven ? 1.0 : 2 + tp.height;
      final left = (x - tp.width / 2)
          .clamp(0.0, (size.width - tp.width).clamp(0.0, double.infinity));
      placed.add((tp, left, rowTop, x));
    }
    // Leaders first, names second, so where one does cross a name it
    // passes behind the glyphs rather than through them.
    final leader = Paint()
      ..color = epochColor.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (final (tp, left, rowTop, x) in placed) {
      // A leader from the top row has to cross the bottom row to reach
      // the axis, and at the right-hand end of this chart the two rows
      // are the exodus and the death of Moses — forty years apart on an
      // axis nearly three thousand years wide, so both names are clamped
      // to the same edge and one lies directly under the other. Leaving
      // from the corner nearest the year, rather than from the middle of
      // the name, keeps that descent along the edge of the name below
      // instead of straight across it, and costs nothing in the ordinary
      // case: a label sitting over its own year has that year inside its
      // width, and the line is vertical exactly as before.
      final from = x.clamp(left, left + tp.width);
      canvas.drawLine(
          Offset(from, rowTop + tp.height), Offset(x, yearLabelTop - 1), leader);
    }
    for (final (tp, left, rowTop, _) in placed) {
      tp.paint(canvas, Offset(left, rowTop));
    }
  }

  @override
  bool shouldRepaint(_AxisPainter old) =>
      old.ticks != ticks ||
      old.epochs != epochs ||
      old.firstYear != firstYear ||
      old.lastYear != lastYear ||
      old.fontSize != fontSize ||
      old.epochColor != epochColor ||
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
    required this.epochYears,
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
  final List<int> epochYears;
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
                  begat: figures.begatAt == null
                      ? null
                      : figures.birthAm + figures.begatAt!,
                  firstYear: firstYear,
                  lastYear: lastYear,
                  ticks: ticks,
                  epochYears: epochYears,
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
    required this.epochYears,
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
  /// along the chart without a second lane of marks. Null for the last
  /// man in the chain, whose bar is therefore solid end to end: there is
  /// no next generation to hand over to, and a pale tail would say there
  /// was one at an unknown date.
  final int? begat;
  final int firstYear;
  final int lastYear;
  final List<int> ticks;
  final List<int> epochYears;
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

    final epochPaint = Paint()
      ..color = _epochHue
      ..strokeWidth = 1.5;
    for (final year in epochYears) {
      canvas.drawLine(
          Offset(x(year), 0), Offset(x(year), size.height), epochPaint);
    }

    final top = size.height / 2 - 6;
    final left = x(birth);
    final right = x(death);
    final split = begat;
    final mid = split == null ? right : x(split.clamp(birth, death));

    // Square corners, per workbench_theme.dart:16.
    canvas.drawRect(
      Rect.fromLTRB(left, top, mid, top + 12),
      Paint()..color = hue.withValues(alpha: selected || contemporary ? 1 : 0.75),
    );
    if (mid < right) {
      canvas.drawRect(
        Rect.fromLTRB(mid, top, right, top + 12),
        Paint()
          ..color =
              hue.withValues(alpha: selected || contemporary ? 0.45 : 0.3),
      );
    }
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
      !listEquals(old.epochYears, epochYears) ||
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

  /// Which figures on this record the text actually states, read off the
  /// refs rather than off the chapter. A missing ref means the figure was
  /// worked out, and `checked` is a separate fact from that: Jacob's
  /// record is checked — 130 at the descent plus 17 in Egypt is the 147
  /// the text gives — while two of its three figures are still derived,
  /// so the two must not be reported by the same sentence.
  String _trustSentence() {
    final present = [
      if (figures.begatAt != null) 'begatAt',
      if (figures.livedAfter != null) 'livedAfter',
      'lifespan',
    ];
    final derived = present.where((k) => figures.refs[k] == null).length;
    // A man the line does not continue through has no begetting age and
    // no years after it — Joseph ends Genesis, Aaron and Moses end the
    // chart — so there is one figure to speak of and the sentences below
    // about three of them would be describing a record he has not got.
    if (present.length == 1 && derived == 0) {
      return figures.checked
          ? _s('chronologyOneChecked',
              'Only one figure is stated for this man — the years he lived. The text gives his age a second time elsewhere, and the two agree.')
          : _s('chronologyOneStated',
              'Only one figure is stated for this man — the years he lived, as the text gives it.');
    }
    if (derived == 0) {
      return figures.checked
          ? _s('chronologyChecked',
              'The text states all three figures, and the third checks the other two.')
          : _s('chronologyAllStated',
              'Every figure here is stated in the text; none of them was derived.');
    }
    if (derived == 1) {
      return _s('chronologyDerived',
          'One of these figures is not stated in the text; it follows from the two that are.');
    }
    return figures.checked
        ? _s('chronologyNarrativeChecked',
            'Only the total is stated for this man; the other figures were worked out from ages given elsewhere in the narrative, and the text states a further figure that checks them.')
        : _s('chronologyNarrative',
            'Only the total is stated for this man; the other figures were worked out from ages given elsewhere in the narrative.');
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
          // Joseph ends the chain, so these two figures do not exist for
          // him rather than being unknown. An empty row would claim the
          // text is silent about something it was asked; no row says the
          // question does not arise.
          if (figures.begatAt != null)
            _Fact(
              label: _s('chronologyBegatAt', 'Fathered the next generation at'),
              value: '${figures.begatAt} ${_s('chronologyYears', 'years')}',
              reference: figures.refs['begatAt'],
              onTap: _jump,
            ),
          if (figures.livedAfter != null)
            _Fact(
              label: _s('chronologyLivedAfter', 'Lived after that'),
              value: '${figures.livedAfter} ${_s('chronologyYears', 'years')}',
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
          // worked out. Two numbers that look alike are not equally sure,
          // and the surface that shows them should say so. Which sentence
          // applies is read off the record rather than off the chapter:
          // a figure carrying no verse was derived, whatever section of
          // Genesis the man belongs to.
          Text(
            _trustSentence(),
            style: TextStyle(fontSize: t.chrome, color: wb.mutedText),
          ),
          // A caveat the generator raised about this man specifically.
          // Also shown in the header, on purpose: a reader who has
          // selected nobody still needs to see it, and a reader looking
          // at this figure should not have to scroll back up for it.
          for (final n in data.notesForPerson(tradition.id, person.id))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                n.textFor(locale),
                style: TextStyle(fontSize: t.chrome, color: wb.text),
              ),
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
