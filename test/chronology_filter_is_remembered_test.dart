/// The Filter the reader set is still set when they come back.
///
/// 2026-09-16 「filter我选了之后换strip或者wheel或者离开那个界面，那个
/// filter就reset了」.
///
/// Half of that already worked: the wheel and the strip hand the hidden
/// set to each other when the reader flips between them, so 轮盘 ⇄ 长条
/// held. What did not hold was leaving the chart — the set lived only in
/// the page's own State, so the next visit ran `_applyDefaultHidden`
/// from scratch and handed back the opening lanes.
///
/// NULL IS NOT EMPTY, and that is the assertion that matters most here.
/// A reader who turns every lane ON has chosen the empty set; a reader
/// who has never opened Filter has chosen nothing. Store them the same
/// way and the first reader gets the opening five back every time.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yahwehs_sword/models/app_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a reader who has never opened Filter has chosen nothing', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = AppSettings();
    await settings.loadSettings();
    expect(settings.chronologyHiddenStreams, isNull,
        reason: 'null is what lets the chart apply its own opening set');
  });

  test('turning every lane on is a choice, and it is not null', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = AppSettings();
    await settings.loadSettings();
    await settings.setChronologyHiddenStreams(<String>{});
    expect(settings.chronologyHiddenStreams, isNotNull);
    expect(settings.chronologyHiddenStreams, isEmpty);

    final next = AppSettings();
    await next.loadSettings();
    expect(next.chronologyHiddenStreams, isEmpty,
        reason: 'the reader showed all 22 lanes; the next visit must not '
            'hand them the opening five again');
  });

  test('the lanes switched off survive a restart', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = AppSettings();
    await settings.loadSettings();
    await settings.setChronologyHiddenStreams({'china', 'japan', 'rome'});

    final next = AppSettings();
    await next.loadSettings();
    expect(next.chronologyHiddenStreams, {'china', 'japan', 'rome'});
  });

  test('the set is stored sorted, so an unchanged set writes nothing new',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = AppSettings();
    await settings.loadSettings();
    await settings.setChronologyHiddenStreams({'rome', 'china'});
    var notified = 0;
    settings.addListener(() => notified++);
    await settings.setChronologyHiddenStreams({'china', 'rome'});
    expect(notified, 0,
        reason: 'the same set in another order is the same set');
    await settings.setChronologyHiddenStreams({'china'});
    expect(notified, 1);
  });

  test('the stored set is exposed unmodifiable', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = AppSettings();
    await settings.loadSettings();
    await settings.setChronologyHiddenStreams({'china'});
    expect(() => settings.chronologyHiddenStreams!.add('rome'),
        throwsUnsupportedError);
  });
}
