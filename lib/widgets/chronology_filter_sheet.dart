import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:yahwehs_sword/constants/chronology_filter_strings.dart';
import 'package:yahwehs_sword/constants/workbench_theme.dart';
import 'package:yahwehs_sword/models/wheel_history.dart';
import 'package:yahwehs_sword/services/chart_symbol_service.dart';
import 'package:yahwehs_sword/utils/chronology_symbols.dart';
import 'package:yahwehs_sword/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:yahwehs_sword/utils/wheel_default_streams.dart'
    show defaultVisibleStreams;
import 'package:yahwehs_sword/utils/wheel_search.dart'
    show
        foldForWheelSearch,
        kLifespanLayerId,
        kLineageLayerId,
        kMinistryLayerId,
        kReignLayerId;

/// Only Apply returns a set, including an empty set for "All". Barrier
/// dismissal, back navigation and Cancel return null. The page therefore
/// has one place to update its live filter, after this future completes.
Future<Set<String>?> showChronologyFilterSheet({
  required BuildContext context,
  required String locale,
  required WheelHistoryData data,
  required Set<String> hidden,
  required Map<String, Color> streamColors,
  required Map<String, Color> layerColors,
  required String Function(String key, String fallback) text,
  required String keyPrefix,
  int? streamCeiling,
}) {
  final initialHidden = Set<String>.of(hidden);
  return showModalBottomSheet<Set<String>>(
    context: context,
    backgroundColor: WbColors.of(context).paneBg,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (sheet) => SizedBox(
      height: MediaQuery.sizeOf(sheet).height * .85,
      child: ChronologyFilterSheet(
        locale: locale,
        data: data,
        initialHidden: initialHidden,
        streamColors: streamColors,
        layerColors: layerColors,
        text: text,
        keyPrefix: keyPrefix,
        streamCeiling: streamCeiling,
      ),
    ),
  );
}

class ChronologyFilterSheet extends StatefulWidget {
  const ChronologyFilterSheet({
    super.key,
    required this.locale,
    required this.data,
    required this.initialHidden,
    required this.streamColors,
    required this.layerColors,
    required this.text,
    required this.keyPrefix,
    this.streamCeiling,
  });

  final String locale;
  final WheelHistoryData data;
  final Set<String> initialHidden;
  final Map<String, Color> streamColors;
  final Map<String, Color> layerColors;
  final String Function(String key, String fallback) text;
  final String keyPrefix;

  /// The most streams this chart draws at once, or null for no limit.
  ///
  /// The wheel passes [kMaxVisibleStreams]; the strip passes nothing,
  /// because its lanes carry printed names and stack vertically, so
  /// twelve of them are read rather than colour-matched.
  final int? streamCeiling;

  @override
  State<ChronologyFilterSheet> createState() => _ChronologyFilterSheetState();
}

class _FilterOption {
  const _FilterOption({
    required this.id,
    required this.keySuffix,
    required this.title,
    required this.subtitle,
    this.color,
    this.narrowSwatch = false,
    this.isStream = false,
  });

  final String id;
  final String keySuffix;
  final String title;
  final String subtitle;
  final Color? color;
  final bool narrowSwatch;

  /// Whether this row counts against [ChronologyFilterSheet.streamCeiling].
  /// The four layers do not: they are depth inside the spine, not
  /// another nation competing for a ring.
  final bool isStream;
}

class _ChronologyFilterSheetState extends State<ChronologyFilterSheet> {
  late final Set<String> _draft;
  late final List<_FilterOption> _options;
  bool _finished = false;

  /// What the reader has typed into the sheet's own find box.
  ///
  /// 2026-09-16 「另外filter那边应该有个搜索」. Twenty-two streams plus
  /// four layers is twenty-six rows on a phone, which is several
  /// screenfuls: A-Z made a row findable by scrolling, and this makes
  /// it findable by naming it.
  ///
  /// It filters the LIST, never the draft. A row scrolled out of sight
  /// by a query is still ticked or unticked exactly as the reader left
  /// it, and Apply sends the whole draft — a search box that quietly
  /// dropped what it was not showing would be the worst possible
  /// behaviour for this particular sheet.
  String _query = '';
  final TextEditingController _find = TextEditingController();

  @override
  void dispose() {
    _find.dispose();
    super.dispose();
  }

  /// The rows a query leaves. Matched on the displayed title in the
  /// reader's own locale, folded the way the chart's own search folds,
  /// so 「教会」 and `church` both reach the church.
  List<_FilterOption> get _visibleOptions {
    final q = foldForWheelSearch(_query);
    if (q.isEmpty) return _options;
    return [
      for (final option in _options)
        if (foldForWheelSearch(option.title).contains(q) ||
            foldForWheelSearch(option.id).contains(q))
          option
    ];
  }

  String _s(String key) => chronologyFilterText(key, widget.locale);

  /// THE CORPUS'S ORDER, NOT THE SHEET'S.
  ///
  /// The rows are listed A-Z since 2026-09-16, and for a moment this
  /// read the ids off that list — which silently changed what 「全部」
  /// means, because [defaultVisibleStreams] keeps the first N in
  /// PRIORITY order and the corpus is what carries that priority.
  /// Alphabetical is a way to find a row; it is not a ranking.
  Iterable<String> get _streamIds =>
      widget.data.streams.map((stream) => stream.id);

  int get _shownStreams =>
      _streamIds.where((id) => !_draft.contains(id)).length;

  /// At the ceiling the sheet REFUSES rather than swaps.
  ///
  /// A swap has to guess which ring the reader is finished with, and
  /// every rule for guessing has a bad case: evict their oldest pick and
  /// Egypt vanishes while they are still comparing it; evict the lowest
  /// priority and the church vanishes while they are reading Rome. A
  /// ring disappearing on its own while the reader looks at it is a
  /// worse failure than one extra tap, so the unticked rows go quiet and
  /// say why, and the reader chooses what leaves.
  bool get _atCeiling =>
      widget.streamCeiling != null && _shownStreams >= widget.streamCeiling!;

  @override
  void initState() {
    super.initState();
    // The chart owns a mutable set and used to share it with every
    // checkbox. Copy its values once; no draft operation reaches that
    // object, including the All/None shortcuts.
    _draft = Set.of(widget.initialHidden);
    final s = widget.text;
    final powers = <String, int>{};
    final events = <String, int>{};
    for (final power in widget.data.powers) {
      powers.update(power.stream, (count) => count + 1, ifAbsent: () => 1);
    }
    for (final event in widget.data.events) {
      events.update(event.stream, (count) => count + 1, ifAbsent: () => 1);
    }
    _options = [
      _FilterOption(
        id: kLifespanLayerId,
        keySuffix: 'Lifespans',
        title: s('wheelLifespans', 'Genesis lifespans'),
        subtitle: s('wheelLifespansNote', ''),
        color: widget.layerColors[kLifespanLayerId],
      ),
      _FilterOption(
        id: kReignLayerId,
        keySuffix: 'Reigns',
        title: s('wheelReigns', 'Reigns of Judah & Israel'),
        subtitle: s('wheelKingsThiele', 'reigns (Thiele)'),
        color: widget.layerColors[kReignLayerId],
      ),
      _FilterOption(
        id: kMinistryLayerId,
        keySuffix: 'Ministries',
        title: s('wheelMinistries', 'Prophets & apostles'),
        subtitle: s('wheelMinistriesNote', ''),
        color: widget.layerColors[kMinistryLayerId],
      ),
      _FilterOption(
        id: kLineageLayerId,
        keySuffix: 'Lineage',
        title: s('wheelLineage', 'Genealogy (approximate)'),
        subtitle: s('wheelLineageNote', ''),
        color: widget.layerColors[kLineageLayerId],
        narrowSwatch: true,
      ),
      // BY NAME, NOT BY THE ORDER THE CORPUS HAPPENS TO LIST THEM.
      //
      // 2026-09-16 「filter那里应该是alphabet order可以标注出来」. The
      // corpus order is roughly the order these powers enter history,
      // which is a reasonable thing for a chart to know and a poor way
      // to find 埃及 in a list of twenty-two. The layers above keep
      // their own order: there are four of them and they are not a
      // list you search.
      ...(<_FilterOption>[
        for (final stream in widget.data.streams)
          _FilterOption(
            id: stream.id,
            keySuffix: 'Stream-${stream.id}',
            title: stream.nameFor(widget.locale),
            subtitle:
                '${s('wheelPowers', 'Powers')} ${powers[stream.id] ?? 0} · '
                '${s('wheelEvents', 'Events')} ${events[stream.id] ?? 0}',
            color: widget.streamColors[stream.id],
            isStream: true,
          ),
      ]..sort((a, b) => a.title.compareTo(b.title))),
    ];
  }

  /// The colour chip, or the stream's own symbol in that colour.
  ///
  /// WHERE THE SYMBOLS ARE LEARNED. The chart draws a crown on the
  /// Judah ring and a menorah on Israel's, and a reader meets them
  /// there with the ring's name beside them — which is enough to guess
  /// but not enough to look up. This list is the only place all
  /// nineteen appear at once, next to the names they stand for, so it
  /// is where the set becomes learnable rather than guessable.
  ///
  /// Tinted the same way the canvas tints them, from the same map, so a
  /// symbol cannot mean one colour here and another on the chart.
  /// Streams with no symbol keep the plain chip: [kStreamSymbols] leaves
  /// three of them out on purpose and inventing a mark for the sheet
  /// would undo that.
  Widget _swatch(_FilterOption option, WbColors wb) {
    final colour = option.color ?? wb.mutedText;
    final ui.Image? symbol = option.isStream
        ? ChartSymbolService.instance.cached[symbolForStream(option.id)]
        : null;
    if (symbol == null) {
      return Container(
        width: option.narrowSwatch ? 3 : 12,
        height: 12,
        color: colour,
      );
    }
    return SizedBox(
      width: 20,
      height: 20,
      child: RawImage(
        image: symbol,
        color: colour,
        colorBlendMode: BlendMode.srcIn,
        fit: BoxFit.contain,
      ),
    );
  }

  void _finish(Set<String>? value) {
    // A rapid second tap while the sheet animates away must not pop
    // the chart route underneath it or return a second application.
    if (_finished) return;
    _finished = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final chromeSize =
        t.scaledChrome(13).clamp(WbMetrics.smallPrintFloor, double.infinity);
    final buttonText = TextStyle(
      fontFamily: t.fontFamily,
      fontFamilyFallback: kCjkFontFallback,
      fontSize: chromeSize,
      height: 1.25,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(WbMetrics.radiusControl),
    );
    return Material(
      color: wb.paneBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.text('wheelFilter', 'Filter'),
                    style: buttonText.copyWith(
                      color: wb.text,
                      fontSize: t.scaledChrome(15),
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 4),
                Text(_s('draftHint'),
                    style: buttonText.copyWith(color: wb.mutedText)),
                const SizedBox(height: 2),
                // Said out loud, because a reader who cannot see WHY a
                // list is in the order it is in cannot use the order.
                Text(_s('sortedByName'),
                    key: const ValueKey('chronologyFilterSortNote'),
                    style: buttonText.copyWith(color: wb.mutedText)),
                if (widget.streamCeiling != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    chronologyFilterCount(
                        widget.locale, _shownStreams, widget.streamCeiling!),
                    key: const ValueKey('chronologyFilterStreamCount'),
                    style: buttonText.copyWith(
                      color: _atCeiling ? wb.accent : wb.mutedText,
                      fontWeight: _atCeiling ? FontWeight.w600 : null,
                    ),
                  ),
                  if (_atCeiling)
                    Text(_s('ceilingHint'),
                        key: const ValueKey('chronologyFilterCeilingHint'),
                        style: buttonText.copyWith(color: wb.accent)),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: wb.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              key: const ValueKey('chronologyFilterFind'),
              controller: _find,
              onChanged: (value) => setState(() => _query = value),
              style: buttonText.copyWith(color: wb.text),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 18, color: wb.mutedText),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 34, minHeight: 34),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        key: const ValueKey('chronologyFilterFindClear'),
                        icon: Icon(Icons.close, size: 18, color: wb.mutedText),
                        onPressed: () => setState(() {
                          _find.clear();
                          _query = '';
                        }),
                      ),
                hintText: _s('findHint'),
                hintStyle: buttonText.copyWith(color: wb.mutedText),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(WbMetrics.radiusControl),
                  borderSide: BorderSide(color: wb.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(WbMetrics.radiusControl),
                  borderSide: BorderSide(color: wb.border),
                ),
              ),
            ),
          ),
          if (_query.isNotEmpty && _visibleOptions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(_s('findNothing'),
                  key: const ValueKey('chronologyFilterFindNothing'),
                  style: buttonText.copyWith(color: wb.mutedText)),
            ),
          Expanded(
            child: ListView.builder(
              key: const ValueKey('chronologyFilterOptions'),
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: _visibleOptions.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          key: const ValueKey('chronologyFilterAll'),
                          onPressed: () => setState(() {
                            _draft.clear();
                            final ceiling = widget.streamCeiling;
                            if (ceiling == null) return;
                            // All cannot mean all when the chart holds
                            // five. Here it means every layer, plus the
                            // first five streams in priority order.
                            final keep =
                                defaultVisibleStreams(_streamIds, ceiling)
                                    .toSet();
                            for (final id in _streamIds) {
                              if (!keep.contains(id)) _draft.add(id);
                            }
                          }),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            textStyle: buttonText,
                            foregroundColor: wb.link,
                          ),
                          child: Text(widget.text('wheelAll', 'All')),
                        ),
                        TextButton(
                          key: const ValueKey('chronologyFilterNone'),
                          onPressed: () => setState(() => _draft
                              .addAll(_options.map((option) => option.id))),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            textStyle: buttonText,
                            foregroundColor: wb.link,
                          ),
                          child: Text(widget.text('wheelNone', 'None')),
                        ),
                      ],
                    ),
                  );
                }
                final option = _visibleOptions[index - 1];
                final blocked =
                    option.isStream && _atCeiling && _draft.contains(option.id);
                return CheckboxListTile(
                  key: ValueKey('${widget.keyPrefix}${option.keySuffix}'),
                  value: !_draft.contains(option.id),
                  enabled: !blocked,
                  onChanged: blocked
                      ? null
                      : (visible) => setState(() {
                            if (visible == true) {
                              _draft.remove(option.id);
                            } else {
                              _draft.add(option.id);
                            }
                          }),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(option.title,
                      style: TextStyle(
                        color: wb.text,
                        fontFamily: t.fontFamily,
                        fontFamilyFallback: kCjkFontFallback,
                        fontSize: t.scaledSmall(12.5),
                        height: 1.35,
                      )),
                  subtitle: option.subtitle.isEmpty
                      ? null
                      : Text(option.subtitle,
                          style: TextStyle(
                            color: wb.mutedText,
                            fontFamily: t.fontFamily,
                            fontFamilyFallback: kCjkFontFallback,
                            fontSize: t.scaledSmall(11),
                            height: 1.35,
                          )),
                  secondary: _swatch(option, wb),
                );
              },
            ),
          ),
          // The options scroll; the decision does not. On a short
          // phone sheet, scrolling to its final stream must never be
          // required just to find Apply or to discard the draft.
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: wb.border)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const ValueKey('chronologyFilterCancel'),
                        onPressed: () => _finish(null),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(44, 48),
                          shape: shape,
                          side: BorderSide(color: wb.border),
                          textStyle: buttonText,
                          foregroundColor: wb.text,
                        ),
                        child: Text(_s('cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('chronologyFilterApply'),
                        onPressed: () => _finish(Set.unmodifiable(_draft)),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(44, 48),
                          shape: shape,
                          textStyle: buttonText,
                          backgroundColor: wb.accent,
                          foregroundColor: wb.paneBg,
                        ),
                        child: Text(_s('apply')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
