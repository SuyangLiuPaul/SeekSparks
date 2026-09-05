import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/hebrew_king.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/hebrew_kings_service.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/jump_to_reference.dart' as jumper;
import 'package:seeksparks/utils/kings_chart_layout.dart';
import 'package:seeksparks/utils/kings_contemporaries.dart';
import 'package:seeksparks/utils/navigate_to_reader.dart';
import 'package:seeksparks/utils/reference_parser.dart';
import 'package:seeksparks/utils/version_mapper.dart'
    show localizedReferenceLabel;
import 'package:seeksparks/widgets/home_icon_button.dart';
import 'package:seeksparks/widgets/language_switcher_button.dart';
import 'package:seeksparks/widgets/localized_back_button.dart';

/// The kings of Judah and Israel, side by side on one axis.
///
/// WHAT THIS IS FOR. Reading 1-2 Kings, the hard question is never who
/// reigned but who reigned *at the same time*: the text dates every
/// accession by the regnal year of the other kingdom's king ("in the
/// twentieth year of Jeroboam king of Israel, Asa began to reign over
/// Judah"), and those synchronisms are what make the two books one
/// story. Two lists side by side do not answer it. Two lists on a
/// SHARED axis do, and selecting a king lights up everyone who stood on
/// the other throne while he reigned.
///
/// WHY CO-REGENCIES ARE THE POINT. Thiele's reconstruction works
/// precisely because reigns overlap — six co-regencies in Judah, one in
/// Israel, and two contested parallel reigns. If overlapping reigns did
/// not render as overlapping there would be nothing here worth looking
/// at, so a king is drawn as a list of spans rather than one bar.
///
/// Chrome follows workbench_theme.dart: square corners, 1px hairlines,
/// no shadows, no cards.
class HebrewKingsPage extends StatefulWidget {
  const HebrewKingsPage({super.key});

  @override
  State<HebrewKingsPage> createState() => _HebrewKingsPageState();
}

/// Vertical scale. 3.4 px per year keeps the whole divided monarchy
/// (1010-586 BC) inside about 1400 px, which scrolls once on a laptop
/// and lets a 40-year reign carry its own label.
const double _pxPerYear = 3.4;
const double _labelSlot = 26;
const double _bandWidth = 26;
const double _axisWidth = 62;
const double _detailPanelWidth = 320;

/// Below this the detail moves to a bottom sheet: a 320 px panel taken
/// out of a 992 px viewport leaves the chart too narrow to compare two
/// columns, which is the only thing the chart is for.
const double _sideBySideMinWidth = 900;

/// A name lane narrower than this cannot hold "Jehoshaphat 872–848 BC",
/// and a chart of ellipsised kings is not a chart. So below
/// [_minChartWidth] the chart scrolls sideways instead of squeezing —
/// bands stay true to scale and names stay readable on a 320 px phone.
const double _minColumnWidth = 220;
const double _minChartWidth = _axisWidth + 2 * _minColumnWidth;

const Color _judahHue = Color(0xFF5B87C4);
const Color _israelHue = Color(0xFFC4885B);

class _HebrewKingsPageState extends State<HebrewKingsPage> {
  Future<HebrewKingsData>? _future;
  String? _selectedId;

  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = HebrewKingsService.instance.load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _select(String? id) {
    setState(() => _selectedId = _selectedId == id ? null : id);
  }

  /// Narrow layouts have no room for the side panel, so the detail
  /// arrives as a sheet — same component, same contemporaries list.
  /// Tapping a contemporary inside it pops and re-opens on that king,
  /// which is how `FamilyTreePage` already handles the same problem.
  Future<void> _showDetailSheet(
    HebrewKingsData data,
    HebrewKing king,
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
          king: king,
          contemporaries: data.contemporariesOf(king),
          data: data,
          locale: locale,
          scrollController: controller,
          onSelect: (id) {
            final other = id == null ? null : data.byId(id);
            Navigator.of(sheetCtx).maybePop();
            if (other == null) return;
            setState(() => _selectedId = other.id);
            _showDetailSheet(data, other, locale);
          },
        ),
      ),
    );
  }

  /// The chart's provenance, always reachable.
  ///
  /// `_DetailPanel` prints the sources only in its `king == null` empty
  /// state, so they vanish on the first tap — and below
  /// `_sideBySideMinWidth` the panel is never built at all, so they were
  /// unreachable outright. An AppBar action does not depend on either.
  Future<void> _showAbout(String locale) async {
    String s(String key, String fallback) =>
        uiStrings[key]?[locale] ?? fallback;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 720),
      shape: const RoundedRectangleBorder(),
      builder: (sheetCtx) => FutureBuilder<HebrewKingsData>(
        future: _future,
        builder: (c, snap) {
          final wb = WbColors.of(c);
          final type = WbType.of(c);
          final data = snap.data;
          if (data == null) return const SizedBox(height: 120);
          Widget section(String heading, String body) => body.isEmpty
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(heading,
                          style: TextStyle(
                              color: wb.mutedText,
                              fontSize: type.chrome,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(body,
                          style: TextStyle(
                              color: wb.mutedText,
                              fontSize: type.chrome,
                              height: 1.35)),
                    ],
                  ),
                );
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s('kingsAbout', 'About this chart'),
                      style: TextStyle(
                          color: wb.text,
                          fontSize: type.text,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  section(
                      s('kingsAboutSystem',
                          'The chronology this is drawn on'),
                      data.systemNameFor(locale)),
                  section(s('kingsAboutPrecision', 'Why a single year'),
                      data.meta.noteFor(locale)),
                  Text(s('kingsSources', 'Sources'),
                      style: TextStyle(
                          color: wb.mutedText,
                          fontSize: type.chrome,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  for (final src in data.meta.sources)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(src,
                          style: TextStyle(
                              color: wb.mutedText,
                              fontSize: type.chrome,
                              height: 1.3)),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Select [king], and on a narrow layout open his sheet too.
  ///
  /// The side panel only exists above [_sideBySideMinWidth], so a
  /// selection made from the year lookup or from a search result would
  /// otherwise land silently on a chart the reader cannot see under the
  /// sheet they are still looking at.
  void _openKing(HebrewKingsData data, HebrewKing king, String locale) {
    setState(() => _selectedId = king.id);
    if (MediaQuery.of(context).size.width < _sideBySideMinWidth) {
      _showDetailSheet(data, king, locale);
    }
  }

  /// The chart read backwards: name a year, get both thrones.
  ///
  /// A sheet rather than a third mode of the body. The chart and the
  /// search results are both lists of kings and can take turns in the
  /// same space; "who reigned in 841" is a different question with a
  /// two-column answer, and making it a mode would mean the reader
  /// loses the chart to ask it.
  Future<void> _showYearLookup(HebrewKingsData data, String locale) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 720),
      shape: const RoundedRectangleBorder(),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.62,
        minChildSize: 0.35,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => _YearLookupSheet(
          data: data,
          locale: locale,
          scrollController: controller,
          onOpenKing: (k) {
            Navigator.of(sheetCtx).maybePop();
            _openKing(data, k, locale);
          },
        ),
      ),
    );
  }

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
        title: Text(s('hebrewKings', 'Kings of Judah & Israel')),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: s('kingsAbout', 'About this chart'),
            onPressed: () => _showAbout(locale),
          ),
          const LanguageSwitcherButton(),
          const HomeIconButton(),
        ],
      ),
      body: FutureBuilder<HebrewKingsData>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${s('loadErrorTitle', 'Failed to load')}: ${snap.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            );
          }
          final data = snap.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final selected =
              _selectedId == null ? null : data.byId(_selectedId!);
          final contemporaries = selected == null
              ? const <HebrewKing>[]
              : data.contemporariesOf(selected);

          return LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide = constraints.maxWidth >= _sideBySideMinWidth;

              void selectNarrow(String? id) {
                final k = id == null ? null : data.byId(id);
                if (k == null) return;
                setState(() => _selectedId = id);
                _showDetailSheet(data, k, locale);
              }

              final onSelect = sideBySide ? _select : selectNarrow;
              final searching = _query.trim().isNotEmpty;

              final chart = Column(
                children: [
                  _Header(data: data, locale: locale),
                  _ControlBar(
                    locale: locale,
                    controller: _search,
                    query: _query,
                    onQuery: (v) => setState(() => _query = v),
                    onYearLookup: () => _showYearLookup(data, locale),
                  ),
                  Expanded(
                    // SEARCH REPLACES THE CHART, it does not dim it.
                    // The chart's whole content is the time axis; a
                    // filtered chart with 38 of 42 bands greyed is
                    // harder to read than either the chart or the list,
                    // and `family_tree_page` already answers the same
                    // question with a list. Clearing the box brings the
                    // chart straight back with the selection intact.
                    child: searching
                        ? _SearchResults(
                            data: data,
                            locale: locale,
                            query: _query,
                            selectedId: _selectedId,
                            onSelect: onSelect,
                          )
                        : _Chart(
                            data: data,
                            locale: locale,
                            selected: selected,
                            contemporaryIds:
                                contemporaries.map((e) => e.id).toSet(),
                            onSelect: onSelect,
                          ),
                  ),
                ],
              );

              if (!sideBySide) return chart;

              return Row(
                children: [
                  Expanded(child: chart),
                  Container(
                    width: _detailPanelWidth,
                    decoration: BoxDecoration(
                      color: wb.paneBg,
                      border: Border(
                        left: BorderSide(
                          color: wb.border,
                          width: WbMetrics.hairline,
                        ),
                      ),
                    ),
                    child: _DetailPanel(
                      king: selected,
                      contemporaries: contemporaries,
                      data: data,
                      locale: locale,
                      onSelect: _select,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Formatting
// ---------------------------------------------------------------------

/// "931-913 BC" / "公元前931-913年". A single year prints once rather
/// than as a range: Zimri reigned seven days and "885-885 BC" reads
/// like a mistake.
String formatReignYears(String locale, int start, int end) {
  final a = -start;
  final b = -end;
  if (locale == 'en') {
    return a == b ? '$a BC' : '$a–$b BC';
  }
  return a == b ? '公元前$a年' : '公元前$a–$b年';
}

String kingdomLabel(String locale, Kingdom k) {
  final key = switch (k) {
    Kingdom.judah => 'kingsJudah',
    Kingdom.israel => 'kingsIsrael',
    Kingdom.united => 'kingsUnited',
  };
  final fallback = switch (k) {
    Kingdom.judah => 'Judah',
    Kingdom.israel => 'Israel',
    Kingdom.united => 'United monarchy',
  };
  return uiStrings[key]?[locale] ?? fallback;
}

String spanKindLabel(String locale, SpanKind kind) {
  final key = switch (kind) {
    SpanKind.sole => 'kingsSole',
    SpanKind.coregency => 'kingsCoregency',
    SpanKind.rival => 'kingsRival',
  };
  final fallback = switch (kind) {
    SpanKind.sole => 'Sole reign',
    SpanKind.coregency => 'Co-regency',
    SpanKind.rival => 'Rival reign',
  };
  return uiStrings[key]?[locale] ?? fallback;
}

Color _hueFor(Kingdom k) => switch (k) {
      Kingdom.israel => _israelHue,
      _ => _judahHue,
    };

// ---------------------------------------------------------------------
// Header: which chronology, and what the three band styles mean
// ---------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.data, required this.locale});

  final HebrewKingsData data;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final type = WbType.of(context);
    String s(String key, String fallback) =>
        uiStrings[key]?[locale] ?? fallback;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: wb.chromeBg,
        border: Border(
          bottom: BorderSide(color: wb.border, width: WbMetrics.hairline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${s('kingsChronology', 'Chronology')}: '
                '${data.systemNameFor(locale)}',
                style: TextStyle(
                  fontSize: type.chrome,
                  fontWeight: FontWeight.w600,
                  color: wb.text,
                ),
              ),
              for (final kind in SpanKind.values)
                _LegendSwatch(kind: kind, locale: locale),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            s(
              'kingsSystemsDiffer',
              'Chronologies differ over the Nisan or Tishri new year, '
                  'accession-year reckoning, co-regencies and the Assyrian '
                  'synchronisms; a commentary following Albright or Galil '
                  'will give other dates.',
            ),
            style: TextStyle(
              fontSize: type.chrome,
              color: wb.mutedText,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  const _LegendSwatch({required this.kind, required this.locale});

  final SpanKind kind;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final type = WbType.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _bandDecoration(kind, _judahHue, wb, width: 18, height: 10),
        const SizedBox(width: 5),
        Text(
          spanKindLabel(locale, kind),
          style: TextStyle(fontSize: type.chrome, color: wb.mutedText),
        ),
      ],
    );
  }
}

/// The three span kinds must be told apart at a glance and without
/// colour, since colour already carries the kingdom: a sole reign is
/// solid, a co-regency is the same hue washed back, a rival reign is
/// an outline only — present, but not holding the throne.
Widget _bandDecoration(
  SpanKind kind,
  Color hue,
  WbColors wb, {
  required double width,
  required double height,
}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: switch (kind) {
        SpanKind.sole => hue,
        SpanKind.coregency => hue.withValues(alpha: 0.34),
        SpanKind.rival => Colors.transparent,
      },
      border: Border.all(
        color: kind == SpanKind.sole ? hue : hue.withValues(alpha: 0.9),
        width: WbMetrics.hairline,
      ),
    ),
  );
}

// ---------------------------------------------------------------------
// The chart
// ---------------------------------------------------------------------

class _Chart extends StatelessWidget {
  const _Chart({
    required this.data,
    required this.locale,
    required this.selected,
    required this.contemporaryIds,
    required this.onSelect,
  });

  final HebrewKingsData data;
  final String locale;
  final HebrewKing? selected;
  final Set<String> contemporaryIds;
  final void Function(String?) onSelect;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final (lo, hi) = data.extent;
    final judah = data.ofKingdom(Kingdom.judah);
    final israel = data.ofKingdom(Kingdom.israel);
    final united = data.ofKingdom(Kingdom.united);

    // Tall enough for the axis to breathe AND for whichever column has
    // the most labels to seat all of them without forced overlap.
    final byScale = (hi - lo) * _pxPerYear;
    final byLabels =
        math.max(judah.length, israel.length + united.length) * _labelSlot;
    final height = math.max(byScale, byLabels) + 24;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(constraints.maxWidth, _minChartWidth);
        return SingleChildScrollView(
          child: SizedBox(
            height: height,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: _axisWidth,
                            child: _YearAxis(
                              firstYear: lo,
                              lastYear: hi,
                              height: height,
                              locale: locale,
                            ),
                          ),
                          Expanded(
                            child: _KingdomColumn(
                              kingdom: Kingdom.judah,
                              kings: [...united, ...judah],
                              firstYear: lo,
                              lastYear: hi,
                              height: height,
                              locale: locale,
                              selected: selected,
                              contemporaryIds: contemporaryIds,
                              onSelect: onSelect,
                            ),
                          ),
                          Container(
                            width: WbMetrics.hairline,
                            color: wb.border,
                          ),
                          Expanded(
                            child: _KingdomColumn(
                              kingdom: Kingdom.israel,
                              kings: israel,
                              firstYear: lo,
                              lastYear: hi,
                              height: height,
                              locale: locale,
                              selected: selected,
                              contemporaryIds: contemporaryIds,
                              onSelect: onSelect,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Epochs last so their hairline crosses both
                    // columns. The Israel column simply stopping at 722
                    // is itself the point of drawing that line.
                    for (final e in data.epochs)
                      Positioned(
                        top: yForYear(e.year, lo, hi, height),
                        left: 0,
                        right: 0,
                        child: _EpochMarker(epoch: e, locale: locale),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EpochMarker extends StatelessWidget {
  const _EpochMarker({required this.epoch, required this.locale});

  final KingsEpoch epoch;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final type = WbType.of(context);
    return IgnorePointer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: WbMetrics.hairline, color: wb.accent),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 1),
            child: Text(
              '${-epoch.year} · ${epoch.nameFor(locale)}',
              style: TextStyle(
                fontSize: type.chrome,
                color: wb.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _YearAxis extends StatelessWidget {
  const _YearAxis({
    required this.firstYear,
    required this.lastYear,
    required this.height,
    required this.locale,
  });

  final int firstYear;
  final int lastYear;
  final double height;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final type = WbType.of(context);

    // Ticks every 50 years, on the round century/half-century.
    final ticks = <int>[];
    for (var y = (firstYear ~/ 50) * 50; y <= lastYear; y += 50) {
      if (y >= firstYear && y <= lastYear) ticks.add(y);
    }

    return Stack(
      children: [
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          child: Container(width: WbMetrics.hairline, color: wb.border),
        ),
        for (final y in ticks)
          Positioned(
            top: yForYear(y, firstYear, lastYear, height) - 7,
            left: 0,
            right: 5,
            child: Text(
              '${-y}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: type.chrome,
                color: wb.mutedText,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
      ],
    );
  }
}

/// One kingdom: a strip of proportional reign bands, and a lane of
/// names beside it joined back to their bands by leader lines.
class _KingdomColumn extends StatelessWidget {
  const _KingdomColumn({
    required this.kingdom,
    required this.kings,
    required this.firstYear,
    required this.lastYear,
    required this.height,
    required this.locale,
    required this.selected,
    required this.contemporaryIds,
    required this.onSelect,
  });

  final Kingdom kingdom;
  final List<HebrewKing> kings;
  final int firstYear;
  final int lastYear;
  final double height;
  final String locale;
  final HebrewKing? selected;
  final Set<String> contemporaryIds;
  final void Function(String?) onSelect;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final type = WbType.of(context);

    double y(int year) => yForYear(year, firstYear, lastYear, height);

    final anchors = <double>[];
    for (final k in kings) {
      final mid = (y(k.reignStart) + y(k.reignEnd)) / 2;
      anchors.add(mid - _labelSlot / 2);
    }
    final labelTops = placeLabels(anchors, _labelSlot, height);

    return Stack(
      children: [
        // Bands.
        for (final k in kings)
          for (final span in k.spans)
            Positioned(
              top: y(span.start),
              left: 6,
              height: math.max(2, y(span.end) - y(span.start)),
              width: _bandWidth,
              child: _Band(
                king: k,
                span: span,
                hue: _hueFor(k.kingdom),
                isSelected: selected?.id == k.id,
                isContemporary: contemporaryIds.contains(k.id),
                onTap: () => onSelect(k.id),
              ),
            ),
        // Leader lines + names.
        for (var i = 0; i < kings.length; i++) ...[
          Positioned(
            top: labelTops[i] + _labelSlot / 2,
            left: 6 + _bandWidth,
            width: 8,
            child: Container(
              height: WbMetrics.hairline,
              color: wb.border,
            ),
          ),
          Positioned(
            top: labelTops[i],
            left: 6 + _bandWidth + 8,
            right: 4,
            height: _labelSlot,
            child: _KingLabel(
              king: kings[i],
              locale: locale,
              isSelected: selected?.id == kings[i].id,
              isContemporary: contemporaryIds.contains(kings[i].id),
              onTap: () => onSelect(kings[i].id),
            ),
          ),
        ],
        // Kingdom name, pinned at the very top of the column.
        Positioned(
          top: 0,
          left: 6,
          child: Container(
            color: wb.paneBg,
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Text(
              kingdomLabel(locale, kingdom),
              style: TextStyle(
                fontSize: type.chrome,
                fontWeight: FontWeight.w700,
                color: _hueFor(kingdom),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Band extends StatelessWidget {
  const _Band({
    required this.king,
    required this.span,
    required this.hue,
    required this.isSelected,
    required this.isContemporary,
    required this.onTap,
  });

  final HebrewKing king;
  final ReignSpan span;
  final Color hue;
  final bool isSelected;
  final bool isContemporary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: switch (span.kind) {
            SpanKind.sole => isSelected ? hue : hue.withValues(alpha: 0.82),
            SpanKind.coregency => hue.withValues(alpha: 0.34),
            SpanKind.rival => Colors.transparent,
          },
          border: Border.all(
            color: isSelected
                ? wb.accent
                : isContemporary
                    ? wb.accent.withValues(alpha: 0.75)
                    : hue.withValues(alpha: 0.9),
            width: isSelected || isContemporary ? 2 : WbMetrics.hairline,
          ),
        ),
      ),
    );
  }
}

class _KingLabel extends StatelessWidget {
  const _KingLabel({
    required this.king,
    required this.locale,
    required this.isSelected,
    required this.isContemporary,
    required this.onTap,
  });

  final HebrewKing king;
  final String locale;
  final bool isSelected;
  final bool isContemporary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final type = WbType.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: isSelected
            ? wb.selectionBg
            : isContemporary
                ? wb.accent.withValues(alpha: 0.13)
                : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            Flexible(
              child: Text(
                king.nameFor(locale),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: type.text,
                  color: wb.text,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                formatReignYears(locale, king.reignStart, king.reignEnd),
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontSize: type.chrome,
                  color: wb.mutedText,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Detail
// ---------------------------------------------------------------------

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.king,
    required this.contemporaries,
    required this.data,
    required this.locale,
    required this.onSelect,
    this.scrollController,
  });

  final HebrewKing? king;
  final List<HebrewKing> contemporaries;
  final HebrewKingsData data;
  final String locale;
  final void Function(String?) onSelect;

  /// Set when the panel is hosted in a DraggableScrollableSheet, whose
  /// drag-to-resize only works if the inner list scrolls through it.
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
    final type = WbType.of(context);
    final k = king;

    if (k == null) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _s(
                'kingsSelectHint',
                'Select a king to see who held the other throne while he '
                    'reigned, and where his reign is told in Kings and in '
                    'Chronicles.',
              ),
              style: TextStyle(
                fontSize: type.text,
                color: wb.mutedText,
                height: 1.4,
              ),
            ),
            const Spacer(),
            Text(
              _s('kingsSources', 'Sources'),
              style: TextStyle(
                fontSize: type.chrome,
                fontWeight: FontWeight.w700,
                color: wb.mutedText,
              ),
            ),
            const SizedBox(height: 4),
            for (final src in data.sources)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  src,
                  style: TextStyle(
                    fontSize: type.chrome,
                    color: wb.mutedText,
                    height: 1.3,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    final alt = k.altNameFor(locale);
    final note = k.noteFor(locale);
    final houseKing = data.byId(k.house);
    final otherKingdom =
        k.kingdom == Kingdom.judah ? Kingdom.israel : Kingdom.judah;
    // Derived here, every time, from the list actually being drawn.
    // Nothing in this file knows that Asa's answer is eight.
    final tally = ContemporaryTally.of(contemporaries);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(14),
      children: [
        Text(
          k.nameFor(locale),
          style: TextStyle(
            fontSize: type.text + 5,
            fontWeight: FontWeight.w700,
            color: wb.text,
          ),
        ),
        if (alt != null && alt.isNotEmpty)
          Text(
            alt,
            style: TextStyle(fontSize: type.chrome, color: wb.mutedText),
          ),
        const SizedBox(height: 6),
        Text(
          [
            kingdomLabel(locale, k.kingdom),
            if (houseKing != null)
              (uiStrings['kingsHouseOf']?[locale] ?? 'House of {name}')
                  .replaceAll('{name}', houseKing.nameFor(locale)),
          ].join(' · '),
          style: TextStyle(fontSize: type.chrome, color: wb.mutedText),
        ),

        const SizedBox(height: 12),
        _SectionTitle(_s('kingsReign', 'Reign')),
        for (final span in k.spans)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                _bandDecoration(
                  span.kind,
                  _hueFor(k.kingdom),
                  wb,
                  width: 16,
                  height: 10,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${spanKindLabel(locale, span.kind)} · '
                    '${formatReignYears(locale, span.start, span.end)}',
                    style: TextStyle(fontSize: type.text, color: wb.text),
                  ),
                ),
              ],
            ),
          ),

        if (note != null && note.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            note,
            style: TextStyle(
              fontSize: type.chrome,
              color: wb.mutedText,
              height: 1.4,
            ),
          ),
        ],

        const SizedBox(height: 14),
        _SectionTitle(_s('kingsPassages', 'Where it is told')),
        if (k.accessionRef != null)
          _RefRow(
            label: _s('kingsAccession', 'Accession synchronism'),
            reference: k.accessionRef!,
            onTap: () => _jump(context, k.accessionRef!),
          ),
        if (k.kingsRef != null)
          _RefRow(
            label: _s('kingsInKings', 'In Kings'),
            reference: k.kingsRef!,
            onTap: () => _jump(context, k.kingsRef!),
          ),
        if (k.chroniclesRef != null)
          _RefRow(
            label: _s('kingsInChronicles', 'In Chronicles'),
            reference: k.chroniclesRef!,
            onTap: () => _jump(context, k.chroniclesRef!),
          )
        else if (k.kingdom == Kingdom.israel)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              _s(
                'kingsNoChronicles',
                'Chronicles follows the line of David and gives the '
                    'northern kings no parallel account.',
              ),
              style: TextStyle(
                fontSize: type.chrome,
                color: wb.mutedText,
                height: 1.35,
              ),
            ),
          ),

        if (k.kingdom != Kingdom.united) ...[
          const SizedBox(height: 14),
          _SectionTitle(
            '${_s('kingsContemporaries', 'On the other throne')} · '
            '${kingdomLabel(locale, otherKingdom)} · '
            '${tally.total}',
          ),
          if (contemporaries.isEmpty)
            Text(
              _s('kingsNoContemporaries', 'No overlapping reign.'),
              style: TextStyle(fontSize: type.chrome, color: wb.mutedText),
            )
          else ...[
            kingsTallyLines(context, tally, otherKingdom, locale),
            const SizedBox(height: 7),
            for (final c in contemporaries)
              _ContemporaryRow(
                king: c,
                locale: locale,
                onTap: () => onSelect(c.id),
                onRefTap: (ref) => _jump(context, ref),
              ),
            if (tally.hasRivals) ...[
              const SizedBox(height: 8),
              kingsRivalExplanation(context, locale),
            ],
            const SizedBox(height: 9),
            kingsChronologyCaveat(context, locale),
          ],
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final type = WbType.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: type.chrome,
              fontWeight: FontWeight.w700,
              color: wb.mutedText,
            ),
          ),
          const SizedBox(height: 3),
          Container(height: WbMetrics.hairline, color: wb.border),
        ],
      ),
    );
  }
}

class _RefRow extends StatelessWidget {
  const _RefRow({
    required this.label,
    required this.reference,
    required this.onTap,
  });

  final String label;
  final String reference;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final type = WbType.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: type.chrome, color: wb.mutedText),
            ),
            Text(
              reference,
              style: TextStyle(fontSize: type.text, color: wb.link),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Contemporaries: the count, the rival mark, and the caveat that must
// travel with both.
//
// These three are top-level and public because `wheel_sheets.dart`
// shows the same section when a reign arc is tapped. A second copy
// would be a second set of words for the same fact, free to drift —
// which is exactly what happened to this page's reference rows before
// they were routed through `localizedReferenceLabel`.
// ---------------------------------------------------------------------

/// "Rival claimant", as a pill.
///
/// The outline-only swatch already says it on the chart, but a row in a
/// list has no swatch, and a reader counting names needs to see which
/// of them the count is treating differently. Localised, because the
/// distinction is the point rather than decoration.
Widget kingsRivalBadge(BuildContext context, String locale, {double? size}) {
  final wb = WbColors.of(context);
  final type = WbType.of(context);
  final fs = size ?? type.chrome - 1;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      border: Border.all(
        color: wb.mutedText.withValues(alpha: 0.7),
        width: WbMetrics.hairline,
      ),
    ),
    child: Text(
      uiStrings['kingsRivalClaimant']?[locale] ?? 'Rival claimant',
      style: TextStyle(
        fontSize: fs,
        color: wb.mutedText,
        fontFamilyFallback: kCjkFontFallback,
      ),
    ),
  );
}

/// The two numbers, side by side: how many held the throne, and how
/// many were claimants. Both are read off [tally], which is read off
/// `spans[].kind`.
///
/// The rival line is omitted when there are none — an explicit
/// "Rival claimants · 0" would imply the question is usually live, and
/// on this data it is live for exactly one man.
Widget kingsTallyLines(
  BuildContext context,
  ContemporaryTally tally,
  Kingdom kingdom,
  String locale,
) {
  final wb = WbColors.of(context);
  final type = WbType.of(context);

  String fill(String key, String fallback, int n) =>
      (uiStrings[key]?[locale] ?? fallback).replaceAll('{n}', '$n');

  Widget line(SpanKind kind, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _bandDecoration(kind, _hueFor(kingdom), wb, width: 16, height: 9),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: type.chrome,
                  color: wb.mutedText,
                  fontFamilyFallback: kCjkFontFallback,
                ),
              ),
            ),
          ],
        ),
      );

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      line(
        SpanKind.sole,
        fill('kingsTallyReigning', 'Reigning kings · {n}', tally.reigning),
      ),
      if (tally.hasRivals)
        line(
          SpanKind.rival,
          fill('kingsTallyRival', 'Rival claimants · {n}', tally.rivals),
        ),
    ],
  );
}

/// A count of contemporaries is a function of the dates, and the dates
/// are one scholar's reconstruction. Wherever this app prints such a
/// count, it prints this underneath.
Widget kingsChronologyCaveat(
  BuildContext context,
  String locale, {
  double? size,
}) {
  final wb = WbColors.of(context);
  final type = WbType.of(context);
  return Text(
    uiStrings['kingsTallyBasis']?[locale] ??
        'How many contemporaries a reign has depends on the chronology: '
            'the overlaps here are counted on Thiele\'s years, and Albright, '
            'Galil or Kitchen would move the boundaries and can change the '
            'count.',
    style: TextStyle(
      fontSize: size ?? type.chrome,
      color: wb.mutedText,
      height: 1.35,
      fontFamilyFallback: kCjkFontFallback,
    ),
  );
}

/// Why Tibni is on a chart of kings at all. Shown under the list when
/// the tally counted a claimant, so the extra name is explained where
/// it is seen rather than in an About sheet the reader may never open.
Widget kingsRivalExplanation(
  BuildContext context,
  String locale, {
  double? size,
}) {
  final wb = WbColors.of(context);
  final type = WbType.of(context);
  return Text(
    uiStrings['kingsRivalClaimantWhy']?[locale] ??
        '1 Kings 16:21-22 gives him no regnal formula and never says he '
            'reigned; his dates are an inference of this chronology. He is '
            'not among the nineteen kings of Israel, but his years do fall '
            'inside reigns in the other kingdom, so he is shown.',
    style: TextStyle(
      fontSize: size ?? type.chrome,
      color: wb.mutedText,
      height: 1.35,
      fontFamilyFallback: kCjkFontFallback,
    ),
  );
}

/// A king's own passages, as one muted line. Tapping opens the reader.
///
/// The brief for a row in any of these lists is that it must carry the
/// king's OWN reference — a contemporaries list whose rows are bare
/// names makes the reader select each man in turn to find out where he
/// is told, which is the work the list was supposed to save.
class _KingRefLine extends StatelessWidget {
  const _KingRefLine({required this.king, required this.locale, this.onTap});

  final HebrewKing king;
  final String locale;
  final void Function(String reference)? onTap;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final type = WbType.of(context);
    final refs = <String>[
      if (king.kingsRef != null) king.kingsRef!,
      if (king.chroniclesRef != null) king.chroniclesRef!,
    ];
    if (refs.isEmpty) return const SizedBox.shrink();
    final label =
        refs.map((r) => localizedReferenceLabel(r, locale)).join(' · ');
    final text = Text(
      label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: type.chrome,
        color: onTap == null ? wb.mutedText : wb.link,
        fontFamilyFallback: kCjkFontFallback,
      ),
    );
    if (onTap == null) return text;
    // The FIRST reference is the one a tap opens. Kings is the primary
    // account for both kingdoms and is always first in `refs`; offering
    // a chooser for the second would be a menu inside a list row.
    return InkWell(onTap: () => onTap!(refs.first), child: text);
  }
}

/// One name in a contemporaries list: who, when, whether he actually
/// held the throne, and where he is told.
class _ContemporaryRow extends StatelessWidget {
  const _ContemporaryRow({
    required this.king,
    required this.locale,
    required this.onTap,
    required this.onRefTap,
  });

  final HebrewKing king;
  final String locale;
  final VoidCallback onTap;
  final void Function(String reference) onRefTap;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final type = WbType.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    king.nameFor(locale),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: type.text,
                      color: wb.link,
                      fontFamilyFallback: kCjkFontFallback,
                    ),
                  ),
                ),
                if (king.isRival) ...[
                  const SizedBox(width: 5),
                  kingsRivalBadge(context, locale),
                ],
                const Spacer(),
                Text(
                  formatReignYears(locale, king.reignStart, king.reignEnd),
                  style: TextStyle(
                    fontSize: type.chrome,
                    color: wb.mutedText,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            _KingRefLine(
              king: king,
              locale: locale,
              onTap: onRefTap,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Search, and the year lookup
// ---------------------------------------------------------------------

/// The search box, and the button that opens the year lookup.
///
/// The field is `atlas_page`'s and `naves_page`'s, down to the
/// `paneAltBg` fill and the square hairline borders — four pages in
/// this app already search this way and a fifth idiom would only make
/// the app look assembled from parts.
class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.locale,
    required this.controller,
    required this.query,
    required this.onQuery,
    required this.onYearLookup,
  });

  final String locale;
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onQuery;
  final VoidCallback onYearLookup;

  @override
  Widget build(BuildContext context) {
    final c = WbColors.of(context);
    final t = WbType.of(context);
    String s(String key, String fallback) =>
        uiStrings[key]?[locale] ?? fallback;

    final field = TextField(
      controller: controller,
      style: TextStyle(
        fontSize: t.text,
        color: c.text,
        fontFamilyFallback: kCjkFontFallback,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: c.paneAltBg,
        hintText: s('kingsSearchHint', 'Search a king or a reference…'),
        hintStyle: TextStyle(
          fontSize: t.text,
          color: c.mutedText,
          fontFamilyFallback: kCjkFontFallback,
        ),
        prefixIcon: Icon(Icons.search, size: t.text + 3, color: c.mutedText),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 30, minHeight: 30),
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close, size: t.text + 1, color: c.mutedText),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  controller.clear();
                  onQuery('');
                },
              ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: c.border, width: WbMetrics.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: c.border, width: WbMetrics.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: c.text, width: WbMetrics.hairline),
        ),
      ),
      onChanged: onQuery,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: c.chromeBg,
        border: Border(
          bottom: BorderSide(color: c.border, width: WbMetrics.hairline),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: field),
          const SizedBox(width: 6),
          TextButton.icon(
            onPressed: onYearLookup,
            icon: Icon(Icons.today_outlined, size: t.text + 3),
            label: Text(
              s('kingsYearLookup', 'Who was reigning in…'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: t.chrome,
                fontFamilyFallback: kCjkFontFallback,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

/// Matching kings, grouped by throne so the answer keeps the shape the
/// chart has.
class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.data,
    required this.locale,
    required this.query,
    required this.selectedId,
    required this.onSelect,
  });

  final HebrewKingsData data;
  final String locale;
  final String query;
  final String? selectedId;
  final void Function(String?) onSelect;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final type = WbType.of(context);
    String s(String key, String fallback) =>
        uiStrings[key]?[locale] ?? fallback;

    final matches = data.search(
      query,
      locale,
      refLabel: localizedReferenceLabel,
    );

    if (matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            s('kingsNoMatches', 'No king matches that search.'),
            style: TextStyle(
              color: wb.mutedText,
              fontFamilyFallback: kCjkFontFallback,
            ),
          ),
        ),
      );
    }

    final count = (s('kingsSearchCount', '{count} of {total} kings'))
        .replaceAll('{count}', '${matches.length}')
        .replaceAll('{total}', '${data.kings.length}');

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: type.chrome,
            color: wb.mutedText,
            fontFamilyFallback: kCjkFontFallback,
          ),
        ),
        const SizedBox(height: 6),
        for (final k in matches)
          _SearchResultRow(
            king: k,
            locale: locale,
            isSelected: k.id == selectedId,
            onTap: () => onSelect(k.id),
          ),
      ],
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({
    required this.king,
    required this.locale,
    required this.isSelected,
    required this.onTap,
  });

  final HebrewKing king;
  final String locale;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final type = WbType.of(context);
    final alt = king.altNameFor(locale);
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected ? wb.selectionBg : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: type.text + 2,
                  color: _hueFor(king.kingdom),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    king.nameFor(locale),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: type.text,
                      color: wb.text,
                      fontWeight: FontWeight.w600,
                      fontFamilyFallback: kCjkFontFallback,
                    ),
                  ),
                ),
                if (king.isRival) ...[
                  const SizedBox(width: 5),
                  kingsRivalBadge(context, locale),
                ],
                const Spacer(),
                Text(
                  formatReignYears(locale, king.reignStart, king.reignEnd),
                  style: TextStyle(
                    fontSize: type.chrome,
                    color: wb.mutedText,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 9, top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      kingdomLabel(locale, king.kingdom),
                      if (alt != null && alt.isNotEmpty) alt,
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: type.chrome,
                      color: wb.mutedText,
                      fontFamilyFallback: kCjkFontFallback,
                    ),
                  ),
                  _KingRefLine(king: king, locale: locale),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Who was reigning in 841 BC?" — both thrones, for one year.
///
/// EVERY YEAR IN THIS FILE IS BC and the field takes a bare number, so
/// the sheet says so three times over: in the note under the field, in
/// the range it offers, and in the heading over the answer, which goes
/// through [formatReignYears] and therefore reads "841 BC" /
/// "公元前841年" exactly as the chart does.
class _YearLookupSheet extends StatefulWidget {
  const _YearLookupSheet({
    required this.data,
    required this.locale,
    required this.onOpenKing,
    this.scrollController,
  });

  final HebrewKingsData data;
  final String locale;
  final void Function(HebrewKing) onOpenKing;
  final ScrollController? scrollController;

  @override
  State<_YearLookupSheet> createState() => _YearLookupSheetState();
}

class _YearLookupSheetState extends State<_YearLookupSheet> {
  final TextEditingController _field = TextEditingController();

  /// The year asked about, as stored in the asset — negative for BC.
  /// Null until the box holds a number inside the chart's extent.
  int? _year;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    // A reader types the magnitude ("870"), because that is how a BC
    // year is written everywhere else on this page. A leading minus is
    // accepted too and means the same thing, so that pasting a value
    // out of the asset does not silently ask about AD 870.
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final n = int.tryParse(digits);
    setState(() => _year = n == null || n == 0 ? null : -n);
  }

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final type = WbType.of(context);
    final locale = widget.locale;
    String s(String key, String fallback) =>
        uiStrings[key]?[locale] ?? fallback;

    final extent = reignExtent(widget.data.kings);
    final year = _year;

    final judah = year == null
        ? const <HebrewKing>[]
        : widget.data.reigningIn(year, kingdom: Kingdom.judah);
    final israel = year == null
        ? const <HebrewKing>[]
        : widget.data.reigningIn(year, kingdom: Kingdom.israel);
    final united = year == null
        ? const <HebrewKing>[]
        : widget.data.reigningIn(year, kingdom: Kingdom.united);

    Widget group(Kingdom kingdom, List<HebrewKing> kings) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(kingdomLabel(locale, kingdom)),
              if (kings.isEmpty)
                Text(
                  s('kingsYearNoneHere', 'None'),
                  style: TextStyle(
                    fontSize: type.chrome,
                    color: wb.mutedText,
                    fontFamilyFallback: kCjkFontFallback,
                  ),
                ),
              for (final k in kings)
                _ContemporaryRow(
                  king: k,
                  locale: locale,
                  onTap: () => widget.onOpenKing(k),
                  // A reference tap inside this sheet would have to
                  // close it, navigate, and lose the year the reader
                  // just typed. The row still PRINTS the reference —
                  // opening it is one tap further, through the king.
                  onRefTap: (_) => widget.onOpenKing(k),
                ),
            ],
          ),
        );

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(14),
      children: [
        Text(
          s('kingsYearLookup', 'Who was reigning in…'),
          style: TextStyle(
            // `scaled`, not `text + 3`: an additive offset is a ratio of
            // 1.25 at the default and 1.08 at 40 pt, so the heading
            // stops outranking the body as the reader turns the slider
            // up. See WbType.scaledSmall's comment for the argument.
            fontSize: type.scaled(15),
            fontWeight: FontWeight.w700,
            color: wb.text,
            fontFamilyFallback: kCjkFontFallback,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 180,
          child: TextField(
            controller: _field,
            autofocus: true,
            keyboardType: TextInputType.number,
            style: TextStyle(
              fontSize: type.text,
              color: wb.text,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: wb.paneAltBg,
              hintText: s('kingsYearHint', 'Year'),
              hintStyle: TextStyle(
                fontSize: type.text,
                color: wb.mutedText,
                fontFamilyFallback: kCjkFontFallback,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide:
                    BorderSide(color: wb.border, width: WbMetrics.hairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide:
                    BorderSide(color: wb.border, width: WbMetrics.hairline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide:
                    BorderSide(color: wb.text, width: WbMetrics.hairline),
              ),
            ),
            onChanged: _onChanged,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          [
            s('kingsYearBcNote', 'Years are BC — enter 870 for 870 BC.'),
            if (extent != null)
              s('kingsYearRange', 'This chart runs from {from} to {to}.')
                  .replaceAll(
                      '{from}',
                      formatReignYears(
                          locale, extent.$1, extent.$1))
                  .replaceAll(
                      '{to}',
                      formatReignYears(locale, extent.$2, extent.$2)),
          ].join(' '),
          style: TextStyle(
            fontSize: type.chrome,
            color: wb.mutedText,
            height: 1.35,
            fontFamilyFallback: kCjkFontFallback,
          ),
        ),
        const SizedBox(height: 14),
        if (year != null) ...[
          Text(
            formatReignYears(locale, year, year),
            style: TextStyle(
              fontSize: type.scaled(13),
              fontWeight: FontWeight.w700,
              color: wb.text,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 8),
          if (judah.isEmpty && israel.isEmpty && united.isEmpty)
            Text(
              s('kingsYearNoOne',
                  'No king in this chart was on a throne that year.'),
              style: TextStyle(
                fontSize: type.text,
                color: wb.mutedText,
                fontFamilyFallback: kCjkFontFallback,
              ),
            )
          else ...[
            // The united monarchy only has an answer before 931, and
            // printing an empty "United monarchy · None" beside every
            // divided-kingdom year would be noise. Judah and Israel are
            // always shown, because "None" IS the answer after 722 and
            // after 586 and is the fact the reader came for.
            if (united.isNotEmpty) group(Kingdom.united, united),
            group(Kingdom.judah, judah),
            group(Kingdom.israel, israel),
          ],
          const SizedBox(height: 4),
          kingsChronologyCaveat(context, locale),
        ],
      ],
    );
  }
}
