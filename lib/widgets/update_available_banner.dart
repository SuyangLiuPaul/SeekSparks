/// The line the Workbench shows when a newer build exists.
///
/// 2026-09-14, at the owner's request: 「如果有 upgrade available 应该在
/// home page 显示而不是最下面 popup」. It was a `SnackBar` — six seconds at
/// the bottom of the screen, on launch, and then gone. Everything wrong
/// with that is in the shape rather than the words:
///
///   * it arrives while the reader is opening the app and leaves before
///     they have decided anything;
///   * it is at the foot of the screen, furthest from what they are
///     looking at;
///   * and once it has gone there is nothing to come back to. The only
///     other route to the same fact is a tile on the About page.
///
/// A banner under the toolbar instead: it states the fact, carries the
/// action, and stays until the reader acts on it or waves it away. Modelled
/// on the 雅伟的话 app's `UpdateBanner`, which the owner named as the
/// reference — one row, the version, one button, and a 暂不 that means
/// "not this build" rather than "never again".
///
/// It is a strip and not a card, because this app has no cards: a hairline
/// under it, `radiusSurface` corners, no shadow. The accent is the only
/// colour it spends.
library;

import 'package:flutter/material.dart';

import 'package:yahwehs_sword/constants/ui_strings.dart';
import 'package:yahwehs_sword/constants/workbench_theme.dart';
import 'package:yahwehs_sword/services/link_opener.dart';
import 'package:yahwehs_sword/services/update_service.dart';
import 'package:yahwehs_sword/widgets/update_check_tile.dart';

class UpdateAvailableBanner extends StatelessWidget {
  const UpdateAvailableBanner({
    super.key,
    required this.info,
    required this.locale,
    required this.onDismiss,
  });

  final UpdateInfo info;
  final String locale;

  /// Called when the reader taps 暂不. The caller keeps the "which build
  /// was waved away" state, because it has to outlive this widget — the
  /// banner is rebuilt on every frame of the page behind it.
  final VoidCallback onDismiss;

  String _s(String key, String fallback) =>
      uiStrings[key]?[locale] ?? fallback;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final label =
        _s('updateAvailableBar', 'Version v{new} is available')
            .replaceAll('{new}', info.latestVersion);

    // The same two-way choice the bar carried, and in the same order of
    // preference: an in-app install where the platform allows it, the
    // download page where it does not, and nothing at all where neither
    // is possible — in which case the banner still says a new version
    // exists, which is the part the reader could not otherwise learn.
    Widget? action;
    if (canInstallInApp(info)) {
      action = TextButton(
        onPressed: () => installUpdateInApp(context, info, locale: locale),
        child: Text(_s('updateInstallNow', 'Update now')),
      );
    } else if (LinkOpener.isAvailable) {
      action = TextButton(
        onPressed: () => LinkOpener.open(info.downloadUrl),
        child: Text(_s('updateDownload', 'Download')),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: wb.accent.withValues(alpha: 0.10),
        border: Border(bottom: BorderSide(color: wb.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.system_update_alt, size: 14, color: wb.accent),
          const SizedBox(width: 8),
          // Expanded and wrapping: the version string is short in English
          // and not in Chinese, and this strip ships on a 320px phone.
          // The narrow-screen audit earlier today found three chrome rows
          // clipped at exactly that width; this one is not going to be a
          // fourth.
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: t.chrome,
                fontWeight: FontWeight.w600,
                color: wb.text,
              ),
            ),
          ),
          if (action != null) action,
          TextButton(
            onPressed: onDismiss,
            child: Text(_s('updateBannerLater', 'Not now')),
          ),
        ],
      ),
    );
  }
}
