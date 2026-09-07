// 2026-09-08: the once-a-day update check.
//
// SeekSparks ships as a sideloaded APK and as desktop archives. There is
// no store behind any of them, so the only way a reader learns their
// build is old is if the app tells them — and until this file the app
// only told them when they went looking, through a tile on the About
// page that nothing points at.
//
// What that cost: the newest GitHub Release sat at v1.6.236 while the
// tree was on v1.6.255, and every phone that asked was told it was
// current. The tag half of that is fixed by `tools/tag_release.sh`;
// this is the other half.
//
// Three rules, and each one is about NOT being annoying:
//
//   1. **Never blocks.** The check is fired and forgotten; nothing on
//      screen waits for it and a failure is silent. A reader who opened
//      the app to read a verse is not going to be shown a spinner
//      because of a version number.
//   2. **Once a day, whatever the answer.** The timestamp is stamped
//      even when the check FAILS — a device that is offline every
//      morning would otherwise retry on every launch all day, which is
//      the opposite of what "daily" means.
//   3. **Says nothing when there is nothing to say.** Up-to-date is
//      silent. The reader hears from this code only when a newer build
//      actually exists.
library;

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/services/update_service.dart';

/// Runs the daily check if it is due, and reports a newer release.
///
/// Returns null when the check did not run, could not run, failed, or
/// found nothing — the caller has exactly one thing to do with a
/// non-null result, which is offer it.
///
/// [now] and [check] are injectable so the whole decision — due / not
/// due / disabled / unsupported — is testable without a clock or a
/// network.
Future<UpdateInfo?> runDailyUpdateCheck(
  AppSettings settings, {
  DateTime? now,
  bool? supported,
  Future<UpdateInfo?> Function()? check,
}) async {
  // The platform gate is NOT a setting. On the web the PWA serves the
  // latest build on reload, so there is no such thing as an out-of-date
  // web install and nothing to ask GitHub about.
  if (!(supported ?? UpdateService.isSupported)) return null;

  final at = now ?? DateTime.now();
  if (!settings.updateCheckDueAt(at)) return null;

  // Stamped BEFORE the call, not after. Two launches in quick
  // succession would otherwise both see the check as due and both fire
  // it, and an await is exactly the window for that.
  await settings.markUpdateChecked(at);

  final info = await (check ?? UpdateService.checkForUpdate)();
  if (info == null || !info.updateAvailable) return null;
  return info;
}
