/// Event navigation is a hierarchy of dated groups, not a carpet of
/// per-lane +n badges. Every event belongs to one time bucket, regardless
/// of the old collision-packing lane. Card rectangles are callouts;
/// their anchor line, and their printed dates, carry the time extent.
library;

import 'dart:math' as math;

import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/utils/chronology_explorer.dart'
    show chronologyYearLabel;
import 'package:seeksparks/utils/strip_chronology_layout.dart';

typedef StripEventTextHeight = double Function(
    String text, double width, double fontSize, bool bold);

class StripEventCard {
  const StripEventCard({
    required this.events,
    required this.x,
    required this.width,
    required this.height,
    required this.title,
    required this.dates,
    required this.action,
    required this.titleHeight,
    required this.datesHeight,
    required this.actionHeight,
    required this.density,
  });

  final List<WheelHistoryEvent> events;
  final double x;
  final double width;
  final double height;
  final String title;
  final String dates;
  final String action;
  final double titleHeight;
  final double datesHeight;
  final double actionHeight;
  final List<int> density;

  int get firstYear => events.first.year;
  int get lastYear => events.last.year;
  bool get isGroup => events.length > 1;
  bool contains(double localX, double localY) =>
      localX >= x && localX <= x + width && localY >= 8 && localY <= 8 + height;
}

class StripEventCards {
  const StripEventCards(this.rows, this.rowHeights, this.bucketYears);
  final List<List<StripEventCard>> rows;
  final List<double> rowHeights;
  final int bucketYears;
  Iterable<StripEventCard> get cards => rows.expand((row) => row);
}

String stripEventCardAction(int count, bool sameYear, String locale,
    {bool atZoomLimit = false}) {
  if (locale == 'en') {
    return count == 1
        ? 'View details'
        : sameYear || atZoomLimit
            ? 'View events'
            : 'Explore this period';
  }
  return count == 1
      ? (locale == 'zh-Hant' ? '查看詳情' : '查看详情')
      : sameYear
          ? '查看同年事件'
          : atZoomLimit
              ? (locale == 'zh-Hant' ? '查看這組事件' : '查看这组事件')
              : (locale == 'zh-Hant' ? '點擊放大這段歷史' : '点击放大这段历史');
}

double stripEventCardTitleSize(double laneFontPx) => math.max(13, laneFontPx);
double stripEventCardMetaSize(double laneFontPx) =>
    math.max(11, stripEventCardTitleSize(laneFontPx) * .82);

StripEventCards buildStripEventCards({
  required Iterable<WheelHistoryEvent> events,
  required double pxPerYear,
  required double viewportWidth,
  required double laneFontPx,
  required String locale,
  required StripEventTextHeight measureHeight,
}) {
  final sorted = events.toList()
    ..sort((a, b) {
      final byYear = a.year.compareTo(b.year);
      return byYear == 0 ? a.id.compareTo(b.id) : byYear;
    });
  if (sorted.isEmpty) return const StripEventCards([], [], 1);
  final view = math.max(80.0, viewportWidth);
  // Three dated groups on a phone; wide panes can afford more. This
  // count controls time resolution, not the number of records retained.
  final targetGroups = (view / 190).round().clamp(3, 7);
  final wantYears = view / targetGroups / pxPerYear;
  const steps = [
    1,
    2,
    5,
    10,
    25,
    50,
    100,
    250,
    500,
    1000,
    2000,
    2500,
    5000,
    10000
  ];
  final bucketYears =
      steps.firstWhere((step) => step >= wantYears, orElse: () => steps.last);
  final buckets = <int, List<WheelHistoryEvent>>{};
  for (final event in sorted) {
    buckets
        .putIfAbsent((event.year / bucketYears).floor(), () => [])
        .add(event);
  }
  final width = math.min(220.0, math.max(64.0, view - 16.0));
  final titleSize = stripEventCardTitleSize(laneFontPx);
  final metaSize = stripEventCardMetaSize(laneFontPx);
  final contentWidth = stripContentWidth(pxPerYear);
  final rows = <List<StripEventCard>>[];
  final ends = <double>[];
  final heights = <double>[];
  for (final members in buckets.values) {
    final first = members.first.year;
    final last = members.last.year;
    final group = members.length > 1;
    final title = group
        ? (locale == 'en'
            ? '${members.length} events'
            : '${members.length} 件事件')
        : members.single.titleFor(locale);
    final dates = first == last
        ? chronologyYearLabel(first, locale)
        : '${chronologyYearLabel(first, locale)} — ${chronologyYearLabel(last, locale)}';
    final action = stripEventCardAction(members.length, first == last, locale,
        atZoomLimit: pxPerYear >= kStripZoomSteps.last);
    final titleH = measureHeight(title, width - 24, titleSize, true);
    final dateH = measureHeight(dates, width - 24, metaSize, false);
    final actionH = measureHeight(action, width - 24, metaSize, false);
    final height = 12 + titleH + 6 + dateH + (group ? 22 : 8) + actionH + 12;
    final centre =
        xForYear(first, pxPerYear) / 2 + xForYear(last, pxPerYear) / 2;
    final x = (centre - width / 2)
        .clamp(8.0, math.max(8.0, contentWidth - width - 8))
        .toDouble();
    final density = List<int>.filled(12, 0);
    for (final event in members) {
      final index = first == last
          ? 6
          : ((event.year - first) / (last - first) * 11).floor();
      density[index]++;
    }
    final card = StripEventCard(
      events: List.unmodifiable(members),
      x: x,
      width: width,
      height: height,
      title: title,
      dates: dates,
      action: action,
      titleHeight: titleH,
      datesHeight: dateH,
      actionHeight: actionH,
      density: List.unmodifiable(density),
    );
    var row = ends.indexWhere((end) => end + 12 <= x);
    if (row < 0) {
      row = rows.length;
      rows.add([]);
      ends.add(0);
      heights.add(0);
    }
    rows[row].add(card);
    ends[row] = x + width;
    heights[row] = math.max(heights[row], height + 28);
  }
  return StripEventCards(
    [for (final row in rows) List.unmodifiable(row)],
    List.unmodifiable(heights),
    bucketYears,
  );
}

/// Single-year groups cannot be separated by changing a time scale.
/// They open their complete member list immediately. At the zoom
/// ceiling the same list is the explicit fallback for a wider group.
({int start, int end})? stripEventCardZoomRange(StripEventCard card,
    {required double currentScale, required double viewportWidth}) {
  if (!card.isGroup || card.firstYear == card.lastYear) return null;
  final padding = math.max(1, ((card.lastYear - card.firstYear) * .12).ceil());
  final start = math.max(kStripMinYear, card.firstYear - padding);
  final end = math.min(kStripMaxYear, card.lastYear + padding);
  final nextScale =
      math.min(kStripZoomSteps.last, pxPerYearToFit(start, end, viewportWidth));
  if (nextScale <= currentScale * 1.1) return null;
  return (start: start, end: end);
}
