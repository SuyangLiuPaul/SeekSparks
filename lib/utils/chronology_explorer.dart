import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/utils/date_hedge.dart';

/// These are navigation windows on the existing axis, not claims about
/// where a historical era began. Endpoints are inclusive so a reader
/// looking for a boundary year can find it in either adjoining window.
class ChronologyPeriod {
  const ChronologyPeriod(this.id, this.start, this.end);

  final String id;
  final int start;
  final int end;

  bool contains(int year) => year >= start && year <= end;
}

const chronologyPeriods = <ChronologyPeriod>[
  ChronologyPeriod('all', -4200, 2026),
  ChronologyPeriod('early', -4200, -2000),
  ChronologyPeriod('middle', -2000, -1000),
  ChronologyPeriod('biblical', -1000, 100),
  ChronologyPeriod('late', 100, 1500),
  ChronologyPeriod('recent', 1500, 2026),
];

const double chronologyExplorerControlsHeight = 108;
const double chronologyExplorerSideWidth = 320;
const double chronologyExplorerCompactListHeight = 48;

bool chronologyExplorerUsesSidePanel(Size available) => available.width >= 1000;

bool chronologyExplorerUsesCompactList(Size available) =>
    !chronologyExplorerUsesSidePanel(available) && available.height < 620;

double chronologyExplorerListHeight(Size available) =>
    chronologyExplorerUsesCompactList(available)
        ? chronologyExplorerCompactListHeight
        : (available.height * .27).clamp(180.0, 250.0);

/// The chart and its stream-capacity calculation must receive the same
/// rectangle. At a 360 × 744 body this leaves 435.12 px for the chart;
/// in landscape the list becomes a 48 px sheet opener, so it cannot
/// consume the wheel's remaining radius. The list remains one tap away.
Size chronologyExplorerChartSize(Size available) => Size(
      math.max(
          0,
          available.width -
              (chronologyExplorerUsesSidePanel(available)
                  ? chronologyExplorerSideWidth
                  : 0)),
      math.max(
          0,
          available.height -
              chronologyExplorerControlsHeight -
              (chronologyExplorerUsesSidePanel(available)
                  ? 0
                  : chronologyExplorerListHeight(available))),
    );

/// Sorted once when the corpus changes. Pan and zoom can rebuild the
/// parent every frame; they must never sort the corpus again.
List<WheelHistoryEvent> sortedChronologyEvents(
    Iterable<WheelHistoryEvent> events) {
  final result = events.toList()
    ..sort((a, b) {
      final year = a.year.compareTo(b.year);
      return year == 0 ? a.id.compareTo(b.id) : year;
    });
  return List.unmodifiable(result);
}

class ChronologyEventSelection {
  const ChronologyEventSelection({
    required this.events,
    required this.totalInPeriod,
    required this.hiddenInPeriod,
  });

  final List<WheelHistoryEvent> events;
  final int totalInPeriod;
  final int hiddenInPeriod;
}

/// Filtering preserves the cached chronological order. Full-corpus
/// search is a separate callback and never receives this filtered list.
ChronologyEventSelection selectChronologyEvents({
  required List<WheelHistoryEvent> sortedEvents,
  required ChronologyPeriod period,
  required Set<String> hiddenStreams,
}) {
  final visible = <WheelHistoryEvent>[];
  var total = 0;
  var hidden = 0;
  for (final event in sortedEvents) {
    if (!period.contains(event.year)) continue;
    total++;
    if (hiddenStreams.contains(event.stream)) {
      hidden++;
    } else {
      visible.add(event);
    }
  }
  return ChronologyEventSelection(
    events: List.unmodifiable(visible),
    totalInPeriod: total,
    hiddenInPeriod: hidden,
  );
}

String chronologyYearLabel(int year, String locale) {
  if (year < 0) {
    return locale.startsWith('zh') ? '主前${-year}' : '${-year} BC';
  }
  return switch (locale) {
    'zh-Hant' => '主後$year',
    'zh-Hans' => '主后$year',
    _ => 'AD $year',
  };
}

String chronologyEventDate(WheelHistoryEvent event, String locale) =>
    '${event.approximate ? approximatePrefix(locale) : ''}'
    '${chronologyYearLabel(event.year, locale)}';
