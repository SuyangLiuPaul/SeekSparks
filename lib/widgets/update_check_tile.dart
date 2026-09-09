// 2026-06-16 (v1.3.88): "Check for updates" button for the About page.
//
// Native-only (Android / Windows / macOS / Linux / iOS): asks GitHub for
// the latest release via [UpdateService], then shows a dialog — either
// "you're up to date" or "vX.Y.Z is available" with a Download button that
// opens the right release asset for this platform via [LinkOpener]. On web
// it renders nothing (the PWA is always current). Manages its own loading
// state; every context use after an await is `mounted`-guarded.
//
// 2026-09-09 (review finding 6): the in-app install flow lives here as
// top-level functions rather than as methods of the tile, because the
// tile is not where most readers meet an update. The daily bar on the
// workbench is, and it was still sending Android readers to the
// browser while the About page offered a button. One flow, two doors:
// [installUpdateInApp], [showUpdateAvailableDialog] and
// [buildUpdateAvailableBar] are called from both.

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/services/app_update_installer.dart';
import 'package:seeksparks/services/link_opener.dart';
import 'package:seeksparks/services/update_service.dart';

String _s(String locale, String key, String fallback) =>
    uiStrings[key]?[locale] ?? fallback;

/// Whether "Update now" can honestly be offered for [info] on this build.
///
/// Two conditions and both are needed: the platform can install
/// (Android), AND the release actually has an APK for this flavour —
/// see [UpdateInfo.hasApk] for the window in which it does not.
bool canInstallInApp(UpdateInfo info) =>
    AppUpdateInstaller.isSupported && info.hasApk;

/// True from the first tap of "Update now" until the installer is in
/// front of the reader, the download failed, or they stopped it.
///
/// 2026-09-09 (review finding 1): the re-entrancy guard. A second tap
/// while this is set is a no-op — the dialog already on screen IS the
/// download — rather than a second write stream on the same
/// `update.apk`. A notifier rather than a bare bool so a future button
/// can grey itself out; nothing listens yet.
final ValueNotifier<bool> updateInstallInProgress = ValueNotifier<bool>(false);

/// Download the APK and hand it to Android's installer, with a progress
/// dialog the reader cannot dismiss by accident but CAN stop.
///
/// The progress dialog owns its value through a [ValueNotifier] rather
/// than `setState` on the caller, so a progress tick repaints a bar and
/// not the page behind it. The permission trip (finding 4) is handled
/// here too: when the reader comes back from the OS switch with it on,
/// the download runs again without another tap, because the button
/// they would have pressed is no longer on screen.
///
/// [client] is a test seam and nothing else: it lets a test hold the
/// download open to look at the dialog.
Future<void> installUpdateInApp(
  BuildContext context,
  UpdateInfo info, {
  required String locale,
  @visibleForTesting http.Client? client,
}) async {
  if (updateInstallInProgress.value) return;
  updateInstallInProgress.value = true;
  try {
    var outcome = await _downloadWithDialog(context, info, locale, client);
    if (outcome == UpdateInstallOutcome.permissionNeeded) {
      if (!context.mounted) return;
      final granted = await _offerPermission(context, locale);
      if (!granted || !context.mounted) return;
      outcome = await _downloadWithDialog(context, info, locale, client);
    }
    if (!context.mounted) return;
    switch (outcome) {
      case UpdateInstallOutcome.launched:
        // Nothing to say. Android's own installer is now in front of
        // the reader, and a toast under it would be talking over the
        // OS.
        break;
      case UpdateInstallOutcome.cancelled:
        // They pressed Stop. They know.
        break;
      case UpdateInstallOutcome.permissionNeeded:
        // Back from settings with the switch still off: they decided,
        // and the permission dialog already said how to change it.
        break;
      case UpdateInstallOutcome.downloadFailed:
      case UpdateInstallOutcome.unsupported:
        _showFailed(context, info, locale);
    }
  } finally {
    updateInstallInProgress.value = false;
  }
}

/// One download attempt behind a modal progress dialog.
///
/// `barrierDismissible: false` because the download is ~90 MB on a
/// tablet's mobile data: a stray tap outside the dialog would hide
/// the only indication that it is happening, and the reader would
/// start it again. `PopScope(canPop: false)` (finding 1) because the
/// barrier flag says nothing about the Android Back button, which used
/// to close the dialog and leave the download running unseen. Stop is
/// the one way out, and it really stops: the token aborts the read and
/// the partial file is discarded.
Future<UpdateInstallOutcome> _downloadWithDialog(
  BuildContext context,
  UpdateInfo info,
  String locale,
  http.Client? client,
) async {
  final progress = ValueNotifier<double?>(null);
  final token = UpdateCancelToken();
  var dialogOpen = true;
  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      // Through `WbType` rather than a literal: a percentage the
      // reader's Font Size setting cannot move is exactly what
      // `font_size_reach_ratchet_test.dart` exists to catch, and it
      // caught this one. `scaledChrome` is the right member of the
      // three — this is frame furniture, not scripture.
      final t = WbType.of(ctx);
      final small = TextStyle(
        fontSize: t.scaledChrome(WbMetrics.smallPrintFloor),
      );
      return PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(_s(locale, 'updateDownloading', 'Downloading update…')),
          content: ValueListenableBuilder<double?>(
            valueListenable: progress,
            builder: (_, value, __) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(value: value),
                const SizedBox(height: 12),
                if (value != null)
                  Text('${(value * 100).round()}%', style: small),
                // Always, not only while the length is unknown: GitHub
                // sends Content-Length on every asset, so the old
                // "only while null" hint was shown to nobody — and the
                // next thing on screen is an Android system dialog that
                // looks like an error to a reader who was not told.
                Text(
                  _s(locale, 'updateDownloadingHint',
                      'Android will ask you to confirm the install.'),
                  style: small,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                token.cancel();
                dialogOpen = false;
                Navigator.of(ctx).pop();
              },
              child: Text(_s(locale, 'updateCancelDownload', 'Stop download')),
            ),
          ],
        ),
      );
    },
  ).then((_) => dialogOpen = false));

  final outcome = await AppUpdateInstaller.downloadAndInstall(
    info.downloadUrl,
    onProgress: (f) => progress.value = f,
    client: client,
    cancelToken: token,
  );
  progress.dispose();
  if (!context.mounted) return outcome;
  if (dialogOpen) Navigator.of(context, rootNavigator: true).pop();
  return outcome;
}

/// Explain the OS switch rather than reporting a failure, and say
/// whether the reader came back with it on.
///
/// "Install unknown apps" is off by default and is granted per app,
/// so this is the ordinary first run, not an error — and a reader
/// told "update failed" here would reasonably conclude the app is
/// broken rather than that Android is doing its job.
///
/// 2026-09-09 (review finding 4): [AppUpdateInstaller.requestPermission]
/// now returns when the settings screen closes, so the answer here is
/// the state of the switch AFTER the trip, re-checked through
/// [AppUpdateInstaller.canInstall] rather than trusted.
Future<bool> _offerPermission(BuildContext context, String locale) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
          _s(locale, 'updatePermissionTitle', 'Allow installing updates')),
      content: Text(_s(
        locale,
        'updatePermissionBody',
        'Android asks each app separately before it may install one. '
            'Turn on "Install unknown apps" for this app; the update '
            'continues when you come back.',
      )),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(_s(locale, 'cancel', 'Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(_s(locale, 'updatePermissionOpen', 'Open settings')),
        ),
      ],
    ),
  );
  if (go != true) return false;
  final granted = await AppUpdateInstaller.requestPermission();
  return granted && await AppUpdateInstaller.canInstall();
}

/// A download that did not arrive, with the browser route offered as
/// the way out rather than a bare apology.
void _showFailed(BuildContext context, UpdateInfo info, String locale) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
          _s(locale, 'updateFailedTitle', "Couldn't download the update")),
      content: Text(_s(
        locale,
        'updateFailedBody',
        'The download did not finish. You can try again, or get the '
            'file from the release page.',
      )),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(_s(locale, 'cancel', 'Cancel')),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: Text(_s(locale, 'updateOpenInBrowser', 'Open in browser')),
          onPressed: () {
            Navigator.of(ctx).pop();
            if (LinkOpener.isAvailable) LinkOpener.open(info.releaseUrl);
          },
        ),
      ],
    ),
  );
}

/// The "vX is available" dialog, with "Update now" only where it works.
///
/// 2026-09-09 (review findings 3 and 5): the primary button appears
/// only when [canInstallInApp] — a release whose Android workflow is
/// still running has no APK, and the button used to download the
/// release's HTML page and report "did not finish". And when it does
/// appear, the body above it says what it does, instead of the
/// browser-flow paragraph about opening the APK and unzipping desktops.
void showUpdateAvailableDialog(
  BuildContext context,
  UpdateInfo info, {
  required String locale,
}) {
  final inApp = canInstallInApp(info);
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(_s(locale, 'updateAvailableTitle', 'Update available')),
      content: Text(
        (inApp
                ? _s(
                    locale,
                    'updateAvailableBodyAndroid',
                    'Version v{new} is available (you have v{cur}). '
                        '"Update now" downloads and installs it here; '
                        'Android will ask you to confirm.',
                  )
                : _s(
                    locale,
                    'updateAvailableBody',
                    'Version v{new} is available (you have v{cur}). '
                        'Download it from GitHub, then install: Android '
                        'opens the APK; desktop unzips and runs. iOS uses '
                        'the web app.',
                  ))
            .replaceAll('{new}', info.latestVersion)
            .replaceAll('{cur}', info.currentVersion),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(_s(locale, 'cancel', 'Cancel')),
        ),
        // The browser route stays, and on Android it becomes the
        // SECONDARY one rather than disappearing. It is the fallback
        // for a reader who will not grant "install unknown apps", and
        // the only route at all on iOS and the desktops.
        TextButton.icon(
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: Text(
            AppUpdateInstaller.isSupported
                ? _s(locale, 'updateOpenInBrowser', 'Open in browser')
                : _s(locale, 'updateDownload', 'Download'),
          ),
          onPressed: () {
            Navigator.of(ctx).pop();
            if (LinkOpener.isAvailable) {
              LinkOpener.open(info.downloadUrl);
            }
          },
        ),
        if (inApp)
          FilledButton.icon(
            icon: const Icon(Icons.system_update_alt_rounded, size: 18),
            label: Text(_s(locale, 'updateInstallNow', 'Update now')),
            onPressed: () {
              Navigator.of(ctx).pop();
              unawaited(installUpdateInApp(context, info, locale: locale));
            },
          ),
      ],
    ),
  );
}

/// The daily check's bar, with the one action that fits this build.
///
/// A SnackBar rather than a dialog: see `_maybeOfferUpdate` in
/// `workbench_page.dart`, which shows it. 2026-09-09 (review finding
/// 6): on Android with an APK the action is the in-app install — the
/// same [installUpdateInApp] the About page runs — where it used to
/// hand the URL to [LinkOpener], which on a native build is a stub.
SnackBar buildUpdateAvailableBar(
  BuildContext context,
  UpdateInfo info, {
  required String locale,
  @visibleForTesting http.Client? client,
}) {
  final label = _s(locale, 'updateAvailableBar', 'Version v{new} is available')
      .replaceAll('{new}', info.latestVersion);
  final SnackBarAction? action;
  if (canInstallInApp(info)) {
    action = SnackBarAction(
      label: _s(locale, 'updateInstallNow', 'Update now'),
      onPressed: () => unawaited(
          installUpdateInApp(context, info, locale: locale, client: client)),
    );
  } else if (LinkOpener.isAvailable) {
    action = SnackBarAction(
      label: _s(locale, 'updateDownload', 'Download'),
      onPressed: () => LinkOpener.open(info.downloadUrl),
    );
  } else {
    action = null;
  }
  // Six seconds because it has a button — the default four is not
  // long enough to read a sentence and decide.
  return SnackBar(
    content: Text(label),
    duration: const Duration(seconds: 6),
    action: action,
  );
}

class UpdateCheckTile extends StatefulWidget {
  final String locale;
  final ColorScheme scheme;
  const UpdateCheckTile({
    super.key,
    required this.locale,
    required this.scheme,
  });

  @override
  State<UpdateCheckTile> createState() => _UpdateCheckTileState();
}

class _UpdateCheckTileState extends State<UpdateCheckTile> {
  bool _checking = false;

  Future<void> _check() async {
    if (_checking) return;
    setState(() => _checking = true);
    final info = await UpdateService.checkForUpdate();
    if (!mounted) return;
    setState(() => _checking = false);

    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_s(widget.locale, 'updateCheckFailed',
              "Couldn't check for updates")),
        ),
      );
      return;
    }
    if (!info.updateAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (_s(widget.locale, 'updateUpToDate',
                    "You're on the latest version (v{v})"))
                .replaceAll('{v}', info.currentVersion),
          ),
        ),
      );
      return;
    }
    showUpdateAvailableDialog(context, info, locale: widget.locale);
  }

  @override
  Widget build(BuildContext context) {
    // Web (PWA) is always current — nothing to check.
    if (!UpdateService.isSupported) return const SizedBox.shrink();
    return TextButton.icon(
      icon: _checking
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(widget.scheme.primary),
              ),
            )
          : const Icon(Icons.system_update_alt_rounded, size: 16),
      label: Text(
        _checking
            ? _s(widget.locale, 'updateChecking', 'Checking…')
            : _s(widget.locale, 'checkForUpdates', 'Check for updates'),
      ),
      onPressed: _checking ? null : _check,
    );
  }
}
