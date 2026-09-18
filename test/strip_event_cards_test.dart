/// Drive the exact event-card layout used by the page and painter.
/// The old per-row clustering is counted only as a before measurement;
/// new geometry is always the public builder, never a copied formula.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_sword/models/strip_lanes.dart';
import 'package:yahwehs_sword/models/timeline_event.dart';
import 'package:yahwehs_sword/models/wheel_history.dart';
import 'package:yahwehs_sword/pages/radial_chronology_page.dart'
    show kDrawnTradition;
import 'package:yahwehs_sword/utils/font_catalog.dart';
import 'package:yahwehs_sword/utils/strip_chronology_layout.dart';
import 'package:yahwehs_sword/utils/strip_event_cards.dart';
import 'package:yahwehs_sword/utils/strip_paint_text.dart';
import 'package:yahwehs_sword/utils/strip_viewport.dart';
import 'package:yahwehs_sword/widgets/strip_chronology_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WheelHistoryData data;
  late int creation;
  setUpAll(() {
    Map<String, dynamic> json(String path) =>
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    final base = WheelHistoryData.fromJson(json('assets/wheel_history.json'));
    final timeline = json('assets/bible_timeline.json');
    creation = ((timeline['_meta'] as Map)['creation'] as Map)['year'] as int;
    data = WheelHistoryData(
      streams: base.streams,
      nations: base.nations,
      powers: base.powers,
      ministries: base.ministries,
      omissions: base.omissions,
      meta: base.meta,
      events: [
        ...base.events,
        ...bibleNarrativeEvents([
          for (final entry in timeline['events'] as List)
            TimelineEvent.fromJson(entry as Map<String, dynamic>),
        ]),
      ],
    );
  });
  setUp(StripPaintTextCache.resetForTest);
  tearDown(StripPaintTextCache.resetForTest);

  StripEventCards plan(double viewport, double scale,
          {String locale = 'zh-Hans', double font = 12}) =>
      buildStripEventCards(
          events: data.events,
          pxPerYear: scale,
          viewportWidth: viewport,
          laneFontPx: font,
          locale: locale,
          measureHeight: measureStripEventTextHeight);

  for (final viewport in [216.0, 900.0]) {
    test('$viewport px overview replaces per-row badges with dated groups', () {
      final scale = stripFitScale(viewport);
      final before = buildStripLanes(
              wheel: data,
              kings: const [],
              patriarchs: const [],
              familyTreePeople: const [],
              tradition: kDrawnTradition,
              creationYear: creation,
              pxPerYear: scale)
          .where((lane) => lane.kind == StripLaneKind.events)
          .toList();
      final oldClusters = [
        for (final lane in before)
          ...clusterByX(
              [for (final span in lane.spans) xForYear(span.startYear, scale)],
              12 * kStripEventClusterEm),
      ];
      final oldBadges = oldClusters.where((c) => c.members.length > 1).length;
      final after = plan(viewport, scale);
      expect(after.cards.length, inInclusiveRange(3, 7));
      expect(after.cards.length, lessThan(oldClusters.length));
      expect(after.cards.expand((card) => card.events).map((event) => event.id),
          unorderedEquals(data.events.map((event) => event.id)));
      for (final card in after.cards) {
        expect(card.title, contains('${card.events.length}'));
        expect(card.title, isNot(startsWith('+')));
        expect(card.density.reduce((a, b) => a + b), card.events.length);
        expect(
            card.events.every((event) =>
                event.year >= card.firstYear && event.year <= card.lastYear),
            isTrue);
        expect(
            stripEventCardZoomRange(card,
                currentScale: scale, viewportWidth: viewport),
            isNotNull);
      }
      // ignore: avoid_print
      print(
          'STRIP CARD OVERVIEW: viewport=$viewport, events=${data.events.length}, '
          'before=${before.length} rows/${oldClusters.length} marks/$oldBadges +N badges; '
          'after=${after.rows.length} rows/${after.cards.length} dated cards/0 +N badges');
    });
  }

  test('all zooms and locales keep full titles in disjoint, tappable cards',
      () {
    for (final viewport in [216.0, 900.0]) {
      for (final scale in [stripFitScale(viewport), 1.5, 24.0, 96.0]) {
        for (final locale in ['zh-Hans', 'zh-Hant', 'en']) {
          final result = plan(viewport, scale, locale: locale, font: 28.8);
          for (var r = 0; r < result.rows.length; r++) {
            var previousEnd = double.negativeInfinity;
            for (final card in result.rows[r]) {
              expect(card.x, greaterThanOrEqualTo(previousEnd + 12));
              previousEnd = card.x + card.width;
              expect(card.height, greaterThan(44));
              expect(card.height + 28, lessThanOrEqualTo(result.rowHeights[r]));
              expect(
                  card.contains(card.x + card.width / 2, 8 + card.height / 2),
                  isTrue);
              expect(card.contains(card.x - 1, 8 + card.height / 2), isFalse);
              if (!card.isGroup) {
                expect(card.title, card.events.single.titleFor(locale));
              }
            }
          }
          expect(
              result.cards.expand((c) => c.events).length, data.events.length);
        }
      }
    }
  });

  test('same-year groups and the zoom ceiling resolve to a complete list', () {
    final result = plan(216, 96);
    final sameYear = result.cards
        .where((card) => card.isGroup && card.firstYear == card.lastYear)
        .toList();
    expect(sameYear, isNotEmpty);
    for (final card in sameYear) {
      expect(
          stripEventCardZoomRange(card, currentScale: 96, viewportWidth: 216),
          isNull);
      expect(card.action, '查看同年事件');
    }
    final wide = plan(900, stripFitScale(900)).cards.first;
    expect(stripEventCardZoomRange(wide, currentScale: 96, viewportWidth: 900),
        isNull);
  });

  test('wrapped cached paragraphs preserve actual full-text height', () {
    final text = data.events
        .map((event) => event.titleFor('en'))
        .reduce((a, b) => a.length > b.length ? a : b);
    final style = canvasTextStyle(fontSize: 28.8, fontWeight: FontWeight.w600);
    final expected = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr)
      ..layout(maxWidth: 160);
    final paragraph = StripPaintTextCache.layout(
        text: text, style: style, maxWidth: 160, maxLines: null);
    expect(paragraph.height, closeTo(expected.height, .01));
    final oneLine =
        StripPaintTextCache.layout(text: text, style: style, maxWidth: 160);
    expect(paragraph.height, greaterThan(oneLine.height));
    expect(identical(paragraph, oneLine), isFalse);
    expected.dispose();
  });

  test('no card hangs off the end of the chart, at any zoom a phone sees', () {
    // The one strip defect left over from 2026-09-15's renders was
    // "overview cards clipped at the phone's right edge". The width is
    // clamped to the viewport and the position to the content, so the
    // arithmetic says it cannot happen — this is that claim, measured,
    // rather than a note in a memory file saying it is still open.
    for (final viewport in [360.0, 390.0, 430.0]) {
      for (final scale in [
        stripFitScale(viewport),
        stripFitScale(viewport) * 4,
        kStripZoomSteps.last,
      ]) {
        final cards = plan(viewport, scale);
        final content = stripContentWidth(scale);
        for (final row in cards.rows) {
          for (final card in row) {
            expect(card.x, greaterThanOrEqualTo(0.0),
                reason: '$viewport px at $scale: ${card.title}');
            expect(card.x + card.width, lessThanOrEqualTo(content),
                reason: '$viewport px at $scale: ${card.title} ends at '
                    '${card.x + card.width} of $content');
            expect(card.width, lessThanOrEqualTo(viewport),
                reason: 'a card wider than the screen cannot be read on it');
          }
        }
      }
    }
  });
}
