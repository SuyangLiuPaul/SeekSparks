// 2026-09-08: the periodic update check does its job and stays quiet.
//
// 2026-09-14: and it does it at the interval the reader chose. The gap was
// a compiled `Duration(days: 1)`; the second group below is about what the
// four choices actually mean, and about the one that has no gap at all.
//
// The feature's whole risk is being a nuisance. A check that fires on
// every launch, or blocks the first frame, or announces "you are up to
// date" to someone who did not ask, is worse than no check — the reader
// turns it off and then never hears about the release that matters.
//
// So the rules are asserted rather than described. Every one of these
// was a way the first draft could have gone wrong.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yahwehs_sword/constants/update_check_frequency.dart';
import 'package:yahwehs_sword/models/app_settings.dart';
import 'package:yahwehs_sword/services/update_check_scheduler.dart';
import 'package:yahwehs_sword/services/update_service.dart';

UpdateInfo _info({required bool available}) => UpdateInfo(
      updateAvailable: available,
      currentVersion: '1.6.255',
      latestVersion: available ? '1.6.256' : '1.6.255',
      downloadUrl: 'https://example.invalid/app.apk',
      releaseUrl: 'https://example.invalid/release',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppSettings> settings({
    bool auto = true,
    DateTime? lastChecked,
    UpdateCheckFrequency? every,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final s = AppSettings();
    await s.setAutoCheckUpdates(auto);
    if (every != null) await s.setUpdateCheckFrequency(every);
    if (lastChecked != null) await s.markUpdateChecked(lastChecked);
    return s;
  }

  final now = DateTime(2026, 9, 8, 9, 0);

  test('a day after the last check, it runs and reports a newer build',
      () async {
    var calls = 0;
    final info = await runScheduledUpdateCheck(
      await settings(lastChecked: now.subtract(const Duration(days: 1))),
      now: now,
      supported: true,
      check: () async {
        calls++;
        return _info(available: true);
      },
    );
    expect(calls, 1);
    expect(info?.latestVersion, '1.6.256');
  });

  test('an hour after the last check, it does not run at all', () async {
    var calls = 0;
    final info = await runScheduledUpdateCheck(
      await settings(lastChecked: now.subtract(const Duration(hours: 1))),
      now: now,
      supported: true,
      check: () async {
        calls++;
        return _info(available: true);
      },
    );
    expect(calls, 0, reason: 'daily means daily, not per launch');
    expect(info, isNull);
  });

  test('a fresh install checks immediately', () async {
    // Epoch 0 is "never", and never is more than a day ago. A new
    // install landing on a build that is already superseded should hear
    // about it on the first launch, not on the second day.
    var calls = 0;
    await runScheduledUpdateCheck(
      await settings(),
      now: now,
      supported: true,
      check: () async {
        calls++;
        return _info(available: false);
      },
    );
    expect(calls, 1);
  });

  test('the switch off means no request is made', () async {
    var calls = 0;
    final info = await runScheduledUpdateCheck(
      await settings(auto: false, lastChecked: DateTime(2020)),
      now: now,
      supported: true,
      check: () async {
        calls++;
        return _info(available: true);
      },
    );
    expect(calls, 0, reason: 'off has to mean no network call, not a '
        'suppressed banner — the setting is about the request');
    expect(info, isNull);
  });

  test('an unsupported platform never asks, whatever the switch says',
      () async {
    // The web PWA serves the newest build on reload. There is no such
    // thing as an out-of-date web install, so there is nothing to ask.
    var calls = 0;
    final info = await runScheduledUpdateCheck(
      await settings(),
      now: now,
      supported: false,
      check: () async {
        calls++;
        return _info(available: true);
      },
    );
    expect(calls, 0);
    expect(info, isNull);
  });

  test('being up to date says nothing', () async {
    final info = await runScheduledUpdateCheck(
      await settings(),
      now: now,
      supported: true,
      check: () async => _info(available: false),
    );
    expect(info, isNull,
        reason: 'the reader hears from this code only when there is a '
            'newer build; "you are current" is not news');
  });

  test('a failed check is still a check, and does not retry all day',
      () async {
    // The rule that is easiest to get wrong. Stamping only on SUCCESS
    // means a device that is offline every morning re-fires on every
    // launch until it gets an answer — the opposite of "once a day".
    final s = await settings();
    var calls = 0;
    Future<UpdateInfo?> failing() async {
      calls++;
      return null;
    }

    await runScheduledUpdateCheck(s, now: now, supported: true, check: failing);
    expect(calls, 1);

    await runScheduledUpdateCheck(
        s,
        now: now.add(const Duration(minutes: 5)),
        supported: true,
        check: failing);
    expect(calls, 1, reason: 'the failure consumed the day');
  });

  test('the timestamp is stamped BEFORE the call, not after', () async {
    // Two launches in quick succession would otherwise both see the
    // check as due and both fire it — an await is exactly that window.
    final s = await settings();
    late Future<UpdateInfo?> second;
    var calls = 0;
    final first = runScheduledUpdateCheck(
      s,
      now: now,
      supported: true,
      check: () async {
        calls++;
        // Re-enter while the first call is still in flight.
        second = runScheduledUpdateCheck(
          s,
          now: now,
          supported: true,
          check: () async {
            calls++;
            return _info(available: true);
          },
        );
        return _info(available: true);
      },
    );
    await first;
    await second;
    expect(calls, 1, reason: 'the second launch found the day consumed');
  });

  test('the switch and the timestamp both survive a reload', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final a = AppSettings();
    await a.setAutoCheckUpdates(false);
    await a.markUpdateChecked(now);

    final b = AppSettings();
    await b.loadSettings();
    expect(b.autoCheckUpdates, isFalse);
    expect(b.lastUpdateCheck, now);
    expect(b.updateCheckDueAt(now.add(const Duration(days: 30))), isFalse,
        reason: 'still off after a month');
  });

  group('the interval is the reader\'s', () {
    // Each case is "an hour after the last check", which is the one gap
    // that separates all four settings: every launch fires, and the other
    // three do not.
    final anHourAgo = now.subtract(const Duration(hours: 1));

    Future<int> callsAt(UpdateCheckFrequency every, DateTime last) async {
      var calls = 0;
      await runScheduledUpdateCheck(
        await settings(every: every, lastChecked: last),
        now: now,
        supported: true,
        check: () async {
          calls++;
          return _info(available: true);
        },
      );
      return calls;
    }

    test('every launch means every launch, an hour later included',
        () async {
      expect(await callsAt(UpdateCheckFrequency.everyLaunch, anHourAgo), 1);
    });

    test('daily, weekly and monthly all decline an hour later', () async {
      for (final every in const [
        UpdateCheckFrequency.daily,
        UpdateCheckFrequency.weekly,
        UpdateCheckFrequency.monthly,
      ]) {
        expect(await callsAt(every, anHourAgo), 0, reason: every.prefValue);
      }
    });

    test('each one fires once its own gap has passed, and not before',
        () async {
      // The table, rather than one example: a wrong `gap` on any value
      // shows up here as the adjacent row's answer.
      for (final every in UpdateCheckFrequency.values) {
        final gap = every.gap;
        if (gap > Duration.zero) {
          expect(
              await callsAt(
                  every, now.subtract(gap - const Duration(minutes: 1))),
              0,
              reason: '${every.prefValue} fired a minute early');
        }
        expect(await callsAt(every, now.subtract(gap)), 1,
            reason: '${every.prefValue} did not fire on its own gap');
      }
    });

    test('a weekly reader is not asked daily, which is the whole point',
        () async {
      final s = await settings(every: UpdateCheckFrequency.weekly);
      var calls = 0;
      Future<UpdateInfo?> check() async {
        calls++;
        return _info(available: true);
      }

      // Day 0 is a fresh install: never checked is longer ago than any
      // gap, so it fires.
      await runScheduledUpdateCheck(s, now: now, supported: true,
          check: check);
      expect(calls, 1);
      for (var day = 1; day < 7; day++) {
        await runScheduledUpdateCheck(s,
            now: now.add(Duration(days: day)), supported: true, check: check);
      }
      expect(calls, 1, reason: 'six more launches inside the week asked '
          'again');
      await runScheduledUpdateCheck(s,
          now: now.add(const Duration(days: 7)), supported: true,
          check: check);
      expect(calls, 2);
    });

    test('the switch still wins over any interval', () async {
      expect(
          await callsAt(UpdateCheckFrequency.everyLaunch, DateTime(2020)),
          1);
      var calls = 0;
      await runScheduledUpdateCheck(
        await settings(
            auto: false,
            every: UpdateCheckFrequency.everyLaunch,
            lastChecked: DateTime(2020)),
        now: now,
        supported: true,
        check: () async {
          calls++;
          return _info(available: true);
        },
      );
      expect(calls, 0,
          reason: 'off means no request, whatever the frequency says');
    });

    test('the choice survives a reload, and an unknown value reads as '
        'daily', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final a = AppSettings();
      await a.setUpdateCheckFrequency(UpdateCheckFrequency.monthly);

      final b = AppSettings();
      await b.loadSettings();
      expect(b.updateCheckFrequency, UpdateCheckFrequency.monthly);

      // A value from a newer build, or a key left over from a rename.
      // Defaulting to the documented default is the only answer here that
      // cannot surprise anybody.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'updateCheckFrequency': 'fortnightly',
      });
      final c = AppSettings();
      await c.loadSettings();
      expect(c.updateCheckFrequency, UpdateCheckFrequency.daily);
    });

    test('the default is daily, and nothing has to be stored to get it',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final s = AppSettings();
      expect(s.updateCheckFrequency, UpdateCheckFrequency.daily);
      expect(s.autoCheckUpdates, isTrue,
          reason: 'a build that cannot tell you it is out of date is how '
              'this app came to be nineteen versions behind its own '
              'newest release without anyone noticing');
    });
  });
}
