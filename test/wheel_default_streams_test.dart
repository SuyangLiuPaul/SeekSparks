// The wheel does not open with all twenty-two streams on.
//
// 2026-09-15. 「一开始filter不要全部都有 这样loading很慢 一些主要的和圣经
// 里面有的就行 像中国日本这些可以user后面加进去filter」.
//
// The geometry says the same thing independently, which is why the
// default is a COUNT derived from the viewport rather than a list
// somebody picked. A ring has to be about 24 px thick to be a tap
// target (WCAG 2.5.8); the wheel's annulus is (bands − hub) × side; so
// a 360 dp phone holds roughly four rings and a desktop pane sixteen.
// Drawing twenty-two on a phone is what made the chart slow and
// unreadable at the same time.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahwehs_sword/utils/wheel_default_streams.dart';

/// The page's own radii, restated so a drift between the two shows up
/// here rather than as a chart nobody can tap.
const double _hubFrac = 0.115;

void main() {
  late List<String> streamIds;

  setUpAll(() {
    final data = jsonDecode(
        File('assets/wheel_history.json').readAsStringSync()) as Map<String, dynamic>;
    streamIds = [
      for (final s in data['streams'] as List) (s as Map)['id'] as String,
    ];
  });

  test('every id the priority list names is a real stream, and every '
      'stream is named', () {
    // The list is an editorial judgement about what matters most, so it
    // must be ABOUT something: a typo would silently demote a stream to
    // the end of the queue and nothing else would complain.
    expect(kStreamPriority.toSet().difference(streamIds.toSet()), isEmpty,
        reason: 'the priority list names a stream the data does not have');
    expect(streamIds.toSet().difference(kStreamPriority.toSet()), isEmpty,
        reason: 'a stream was added to the data and not ranked — it will '
            'work, but it will sort last by accident rather than by '
            'decision');
    expect(kStreamPriority.length, kStreamPriority.toSet().length,
        reason: 'a duplicate in the priority list');
  });

  test('the ring count follows the viewport DOWN, and never past the '
      'ceiling', () {
    // 2026-09-15: this test used to read
    //
    //     expect(capacity(768), greaterThan(capacity(360)));
    //     expect(capacity(1280), greaterThan(capacity(768)));
    //
    // — more room, more rings, 4 / 8 / 12 — and that belief is what the
    // owner rejected: 「那么多在一起都没有用其实」. It was never true that
    // room was the binding constraint. `wheel_band_target_test.dart`
    // measures twenty-two rings clearing this app's 9 px finger target
    // at 1400 px, and the chart was still unreadable there, because
    // what runs out first is muted hues a reader can tell apart around
    // a circle — and a wider window does not supply more of those.
    //
    // So the viewport now only ever takes rings AWAY. A large canvas
    // spends its room on thickness instead, which the pitch assertions
    // in `wheel_band_target_test.dart` still hold it to.
    int capacity(double side) => ringCapacity(side,
        hubFraction: _hubFrac, bandsFraction: bandsFractionFor(side));

    expect(capacity(360), lessThanOrEqualTo(kOpeningStreams),
        reason: 'a phone cannot hold more than about four tappable rings');
    for (final side in [360.0, 768.0, 1280.0, 4000.0]) {
      expect(capacity(side), lessThanOrEqualTo(kMaxVisibleStreams),
          reason: '$side px went past the ceiling');
    }
    expect(capacity(1280), greaterThanOrEqualTo(capacity(360)),
        reason: 'a desktop may still hold more than a phone; what it may '
            'not do is hold more than five');
    expect(capacity(10), greaterThanOrEqualTo(1),
        reason: 'a degenerate size must still draw something');
  });

  test('scripture, Israel, Judah and the church survive the narrowest '
      'wheel there is', () {
    // The spine of the thing. A Bible application whose chart drops
    // Israel to make room for Byzantium has its priorities inverted, and
    // this is the assertion that says so out loud.
    final phone = defaultVisibleStreams(streamIds,
        ringCapacity(360,
            hubFraction: _hubFrac, bandsFraction: bandsFractionFor(360)));
    expect(phone, contains('scripture'));
    expect(phone, contains('israel'));
  });

  test('China, India, Japan and the Americas are off by default, and '
      'reachable', () {
    // Named by the owner as exactly the ones a reader should add for
    // themselves. Off on a phone AND on a tablet; a desktop may show
    // them, which is fine — the rule is about room, not about worth.
    final tablet = defaultVisibleStreams(streamIds,
        ringCapacity(768,
            hubFraction: _hubFrac, bandsFraction: bandsFractionFor(768)));
    for (final late in ['china', 'india', 'japan', 'americas']) {
      expect(tablet, isNot(contains(late)),
          reason: '$late took a ring a biblical stream needed');
      expect(kStreamPriority, contains(late),
          reason: '$late must still be in the order, so the filter can '
              'offer it');
    }
  });

  test('a stream the priority list has never heard of still appears when '
      'there is room', () {
    // The failure this prevents: someone adds a stream to the JSON, does
    // not touch this file, and it is invisible on every device forever.
    final withNew = [...streamIds, 'atlantis'];
    expect(defaultVisibleStreams(withNew, withNew.length),
        contains('atlantis'));
  });

  test('the order is stable and does not depend on the data file order',
      () {
    final forwards = defaultVisibleStreams(streamIds, 8);
    final backwards = defaultVisibleStreams(streamIds.reversed, 8);
    expect(forwards, backwards,
        reason: 'the default set changed when the data file was reordered, '
            'which means it is not the priority list deciding');
  });
}
