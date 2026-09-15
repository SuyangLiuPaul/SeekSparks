import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:seeksparks/constants/chronology_explorer_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/utils/chronology_explorer.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/version_mapper.dart'
    show localizedReferenceLabel;

/// The page's fit/reset button and the explorer's range menu describe
/// one window. A command also runs when that window is already selected:
/// fitting "all" must still undo a manual pan within the all-years view.
class ChronologyExplorerController extends ChangeNotifier {
  ChronologyPeriod _period = chronologyPeriods.first;

  ChronologyPeriod get period => _period;

  void showAll() => selectPeriod(chronologyPeriods.first);

  void selectPeriod(ChronologyPeriod period) {
    _period = period;
    notifyListeners();
  }
}

/// A readable entrance to both chart forms. Canvas labels can disappear
/// when their bands are too small; these rows remain ordinary, selectable
/// controls, with the date's qualification and source beside its name.
class ChronologyExplorer extends StatefulWidget {
  const ChronologyExplorer({
    super.key,
    required this.chart,
    required this.data,
    required this.locale,
    required this.hiddenStreams,
    required this.streamColors,
    required this.onEvent,
    required this.onRange,
    required this.onFind,
    required this.onFilter,
    this.selectedId,
    this.controller,
  });

  final Widget chart;
  final WheelHistoryData data;
  final String locale;
  final Set<String> hiddenStreams;
  final Map<String, Color> streamColors;
  final ValueChanged<WheelHistoryEvent> onEvent;
  final void Function(int start, int end) onRange;
  final VoidCallback onFind;
  final VoidCallback onFilter;
  final String? selectedId;
  final ChronologyExplorerController? controller;

  @override
  State<ChronologyExplorer> createState() => _ChronologyExplorerState();
}

class _ChronologyExplorerState extends State<ChronologyExplorer> {
  ChronologyPeriod _period = chronologyPeriods.first;
  late List<WheelHistoryEvent> _sorted;
  late Set<String> _hidden;
  late ChronologyEventSelection _selection;

  String _s(String key) => chronologyExplorerText(key, widget.locale);

  @override
  void initState() {
    super.initState();
    _period = widget.controller?.period ?? chronologyPeriods.first;
    widget.controller?.addListener(_controllerChanged);
    _sorted = sortedChronologyEvents(widget.data.events);
    _hidden = Set.of(widget.hiddenStreams);
    _refresh();
    // The strip's legacy 1.5 px/year opens at the first 144 years on a
    // narrow chart. Fit the requested window after layout has supplied
    // its real width, once only; ordinary rebuilds must preserve a pan.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.selectedId != null) return;
      widget.onRange(_period.start, _period.end);
    });
  }

  @override
  void didUpdateWidget(covariant ChronologyExplorer oldWidget) {
    super.didUpdateWidget(oldWidget);
    var changed = false;
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_controllerChanged);
      widget.controller?.addListener(_controllerChanged);
      _period = widget.controller?.period ?? _period;
      changed = true;
    }
    if (!identical(oldWidget.data.events, widget.data.events)) {
      _sorted = sortedChronologyEvents(widget.data.events);
      changed = true;
    }
    // Both pages mutate their hidden-stream set in place. Comparing the
    // two widget fields would compare the same set to itself and leave
    // stale rows on screen, so retain a snapshot of the values instead.
    if (!setEquals(_hidden, widget.hiddenStreams)) {
      _hidden = Set.of(widget.hiddenStreams);
      changed = true;
    }
    if (oldWidget.selectedId != widget.selectedId &&
        widget.selectedId != null) {
      for (final event in _sorted) {
        if (event.id != widget.selectedId) continue;
        if (!_period.contains(event.year)) {
          _period = chronologyPeriods.skip(1).firstWhere(
                (period) => period.contains(event.year),
                orElse: () => chronologyPeriods.first,
              );
          changed = true;
          widget.controller?._period = _period;
        }
        break;
      }
    }
    if (changed) _refresh();
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_controllerChanged);
    super.dispose();
  }

  void _controllerChanged() => _choosePeriod(widget.controller?.period);

  void _refresh() {
    _selection = selectChronologyEvents(
      sortedEvents: _sorted,
      period: _period,
      hiddenStreams: _hidden,
    );
  }

  void _choosePeriod(ChronologyPeriod? period) {
    if (period == null) return;
    setState(() {
      _period = period;
      widget.controller?._period = period;
      _refresh();
    });
    widget.onRange(period.start, period.end);
  }

  Widget _controls(BuildContext context, double availableWidth) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final chromeSize =
        t.scaledChrome(13).clamp(WbMetrics.smallPrintFloor, double.infinity);
    // At a 360 px pane, the 1.5× menu preference cannot afford both
    // labelled buttons and the date-row ornaments. Keep the search's
    // complete name first; Layers remains a 44 px labelled/tooltip
    // control, and the date range receives the full second row.
    final compactChrome = availableWidth < 480 && t.chromeScale > 1;
    final buttonStyle = OutlinedButton.styleFrom(
      foregroundColor: wb.text,
      backgroundColor: wb.paneBg,
      side: BorderSide(color: wb.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WbMetrics.radiusControl),
      ),
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      textStyle: TextStyle(
        fontFamily: t.fontFamily,
        fontFamilyFallback: kCjkFontFallback,
        fontSize: chromeSize,
        height: 1.2,
      ),
    );
    return Container(
      height: chronologyExplorerControlsHeight,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: wb.paneBg,
        border: Border(bottom: BorderSide(color: wb.border)),
      ),
      child: Column(
        children: [
          SizedBox(
            // The enlarged English label can wrap to two lines. Its
            // final glyphs extended 1.025 px beyond a 44 px button in
            // the 360 px test; spend the former 4 px gap on the button.
            height: 48,
            child: Row(
              children: [
                Expanded(
                  child: Tooltip(
                    message: _s('findHint'),
                    child: OutlinedButton.icon(
                      key: const ValueKey('chronology-find'),
                      onPressed: widget.onFind,
                      style: buttonStyle,
                      icon: Icon(Icons.search, size: 19, color: wb.mutedText),
                      label: Text(_s('find')),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: _hidden.isEmpty
                      ? _s('filter')
                      : _s('hiddenStreams')
                          .replaceFirst('{count}', '${_hidden.length}'),
                  child: compactChrome
                      ? SizedBox(
                          width: 44,
                          child: OutlinedButton(
                            key: const ValueKey('chronology-filter'),
                            onPressed: widget.onFilter,
                            style: buttonStyle.copyWith(
                              padding:
                                  const WidgetStatePropertyAll(EdgeInsets.zero),
                            ),
                            child: Icon(Icons.tune,
                                size: 20, semanticLabel: _s('filter')),
                          ),
                        )
                      : OutlinedButton.icon(
                          key: const ValueKey('chronology-filter'),
                          onPressed: widget.onFilter,
                          style: buttonStyle,
                          icon: const Icon(Icons.tune, size: 18),
                          label: Text(_s('filter')),
                        ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                if (!compactChrome) ...[
                  Icon(Icons.date_range_outlined,
                      size: 18, color: wb.mutedText),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: DropdownButton<ChronologyPeriod>(
                    key: const ValueKey('chronology-period'),
                    value: _period,
                    isExpanded: true,
                    isDense: false,
                    itemHeight: 48,
                    underline: const SizedBox.shrink(),
                    borderRadius:
                        BorderRadius.circular(WbMetrics.radiusSurface),
                    dropdownColor: wb.paneBg,
                    style: TextStyle(
                      fontFamily: t.fontFamily,
                      fontSize: chromeSize,
                      color: wb.text,
                    ),
                    onChanged: _choosePeriod,
                    items: [
                      for (final period in chronologyPeriods)
                        DropdownMenuItem(
                          value: period,
                          child: Text(_s(period.id)),
                        ),
                    ],
                  ),
                ),
                if (!compactChrome)
                  Tooltip(
                    message: _s('interaction'),
                    triggerMode: TooltipTriggerMode.tap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 12),
                      child: Icon(Icons.touch_app_outlined,
                          size: 20, color: wb.mutedText),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventList({VoidCallback? onClose}) => _ChronologyEventList(
        selection: _selection,
        data: widget.data,
        locale: widget.locale,
        streamColors: widget.streamColors,
        selectedId: widget.selectedId,
        onEvent: (event) {
          onClose?.call();
          widget.onEvent(event);
        },
        onClose: onClose,
      );

  void _showEvents() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: WbColors.of(context).paneBg,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * .85,
        child: _eventList(onClose: () => Navigator.of(sheetContext).pop()),
      ),
    );
  }

  Widget _compactList(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    return Material(
      color: wb.paneBg,
      child: InkWell(
        key: const ValueKey('chronology-open-events'),
        onTap: _showEvents,
        child: Container(
          height: chronologyExplorerCompactListHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: wb.border)),
          ),
          child: Row(
            children: [
              Icon(Icons.view_list_outlined, size: 20, color: wb.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _selection.hiddenInPeriod > 0
                      ? _s('compactCount')
                          .replaceFirst(
                              '{visible}', '${_selection.events.length}')
                          .replaceFirst(
                              '{hidden}', '${_selection.hiddenInPeriod}')
                      : '${_s('browse')} · ${_selection.events.length}',
                  style: TextStyle(
                    fontSize: t
                        .scaledChrome(13)
                        .clamp(WbMetrics.smallPrintFloor, double.infinity),
                    color: wb.text,
                  ),
                ),
              ),
              Icon(Icons.expand_less, size: 20, color: wb.mutedText),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      final sidePanel = chronologyExplorerUsesSidePanel(size);
      return ColoredBox(
        color: wb.groundBg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _controls(context, size.width),
            if (sidePanel)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: widget.chart),
                    Container(
                      width: chronologyExplorerSideWidth,
                      decoration: BoxDecoration(
                        border: Border(left: BorderSide(color: wb.border)),
                      ),
                      child: _eventList(),
                    ),
                  ],
                ),
              )
            else ...[
              Expanded(child: widget.chart),
              if (chronologyExplorerUsesCompactList(size))
                _compactList(context)
              else
                SizedBox(
                  height: chronologyExplorerListHeight(size),
                  child: _eventList(),
                ),
            ],
          ],
        ),
      );
    });
  }
}

class _ChronologyEventList extends StatefulWidget {
  const _ChronologyEventList({
    required this.selection,
    required this.data,
    required this.locale,
    required this.streamColors,
    required this.selectedId,
    required this.onEvent,
    this.onClose,
  });

  final ChronologyEventSelection selection;
  final WheelHistoryData data;
  final String locale;
  final Map<String, Color> streamColors;
  final String? selectedId;
  final ValueChanged<WheelHistoryEvent> onEvent;
  final VoidCallback? onClose;

  @override
  State<_ChronologyEventList> createState() => _ChronologyEventListState();
}

class _ChronologyEventListState extends State<_ChronologyEventList> {
  final _scroll = ItemScrollController();

  String _s(String key) => chronologyExplorerText(key, widget.locale);

  int get _selectedIndex {
    final index = widget.selection.events
        .indexWhere((event) => event.id == widget.selectedId);
    return index < 0 ? 0 : index;
  }

  @override
  void didUpdateWidget(covariant _ChronologyEventList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId ||
        !identical(oldWidget.selection, widget.selection)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !_scroll.isAttached ||
            widget.selection.events.isEmpty) {
          return;
        }
        _scroll.jumpTo(index: _selectedIndex);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final selection = widget.selection;
    final streams = {
      for (final stream in widget.data.streams) stream.id: stream
    };
    return Material(
      color: wb.paneBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: wb.border),
                bottom: BorderSide(color: wb.border),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chronologyExplorerEventCount(
                            selection.events.length, widget.locale),
                        key: const ValueKey('chronology-event-count'),
                        style: TextStyle(
                          color: wb.text,
                          fontSize: t.scaledChrome(13).clamp(
                              WbMetrics.smallPrintFloor, double.infinity),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        selection.hiddenInPeriod > 0
                            ? _s('hidden').replaceFirst(
                                '{hidden}', '${selection.hiddenInPeriod}')
                            : _s('interaction'),
                        style: TextStyle(
                            color: wb.mutedText,
                            fontSize: t.scaledChrome(11).clamp(
                                WbMetrics.smallPrintFloor, double.infinity),
                            height: 1.35),
                      ),
                    ],
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    tooltip: _s('close'),
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
          ),
          Expanded(
            child: selection.events.isEmpty
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Text(_s('empty'),
                        style: TextStyle(
                            fontSize: t.scaledSmall(13),
                            color: wb.mutedText,
                            height: 1.5)),
                  )
                : ScrollablePositionedList.builder(
                    key: const ValueKey('chronology-event-list'),
                    itemScrollController: _scroll,
                    initialScrollIndex: _selectedIndex,
                    itemCount: selection.events.length,
                    itemBuilder: (context, index) {
                      final event = selection.events[index];
                      return _ChronologyEventRow(
                        event: event,
                        locale: widget.locale,
                        stream: streams[event.stream]?.nameFor(widget.locale) ??
                            event.stream,
                        color: widget.streamColors[event.stream] ?? wb.accent,
                        selected: event.id == widget.selectedId,
                        onTap: () => widget.onEvent(event),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ChronologyEventRow extends StatelessWidget {
  const _ChronologyEventRow({
    required this.event,
    required this.locale,
    required this.stream,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final WheelHistoryEvent event;
  final String locale;
  final String stream;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final refs = {...event.refs, ...event.datingRefs}.toList();
    final basis = chronologyExplorerText(event.basis, locale);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: ValueKey('chronology-event-${event.id}'),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: selected ? wb.selectionBg : null,
            border: Border(bottom: BorderSide(color: wb.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    chronologyEventDate(event, locale),
                    style: TextStyle(
                      color: wb.mutedText,
                      fontSize: t.scaledSmall(12),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 6,
                    height: 6,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(stream,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: wb.mutedText, fontSize: t.scaledSmall(11))),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                event.titleFor(locale),
                style: TextStyle(
                  fontFamily: t.fontFamily,
                  color: wb.text,
                  fontSize: t.scaled(14),
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 5),
              Text(basis,
                  style: TextStyle(
                      color: wb.mutedText,
                      fontSize: t.scaledSmall(11),
                      height: 1.4)),
              if (refs.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '${refs.take(2).map((ref) => localizedReferenceLabel(ref, locale)).join(' · ')}'
                  '${refs.length > 2 ? ' +${refs.length - 2}' : ''}',
                  style: TextStyle(
                      color: wb.link, fontSize: t.scaledSmall(11), height: 1.4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
