import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/bible_versions.dart' show bibleVersions;
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/providers/main_provider.dart';

/// Tells the reader, once, that the edition they asked for is gone.
///
/// A retired version code is not an error — `resolveReadingVersion` has
/// already put a readable Bible on screen — but it is not nothing
/// either. Someone opens a bookmark expecting 和合本雅伟版 and gets a
/// different translation; without a word from the app that reads as the
/// app having forgotten their choice, which is the kind of small
/// betrayal that stops people trusting a reading position at all.
///
/// Wraps the router rather than living inside the workbench because the
/// substitution is decided during boot, in `MainProvider.restoreState`,
/// before any page exists — and can also be decided seconds later by
/// `UrlSyncService`, whose init is deliberately unawaited. Watching the
/// provider from above catches both without either having to know where
/// the message ends up.
class RetiredVersionNotice extends StatefulWidget {
  final Widget child;

  const RetiredVersionNotice({super.key, required this.child});

  @override
  State<RetiredVersionNotice> createState() => _RetiredVersionNoticeState();
}

class _RetiredVersionNoticeState extends State<RetiredVersionNotice> {
  /// Guards against a second scheduling while the first is still in
  /// flight. The provider is not cleared until the post-frame callback
  /// runs, so without this a rebuild in between would queue the same
  /// SnackBar twice.
  bool _scheduled = false;

  void _show(({String requested, String substituted}) notice, String locale) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    // The substituted edition always has a catalog row — `isKnownVersion`
    // is what let it through — so this lookup cannot fail. The requested
    // one has none, which is the whole point, so its code is printed raw.
    final name = bibleVersions
        .firstWhere((v) => v.value == notice.substituted)
        .menuLabel;
    final template = uiStrings['retiredVersionNotice']?[locale] ??
        'The edition “{code}” is no longer available. '
            'Showing {version} instead.';

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          template
              .replaceAll('{code}', notice.requested)
              .replaceAll('{version}', name),
        ),
        // Longer than a confirmation toast: this one carries a fact the
        // reader has to actually read, and it arrives while the first
        // chapter is still painting.
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notice = context.watch<MainProvider>().retiredVersionNotice;
    final locale = context.watch<AppSettings>().locale;

    if (notice != null && !_scheduled) {
      _scheduled = true;
      // Post-frame because clearing the notice notifies listeners, and
      // both that and showing a SnackBar are illegal during a build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _show(notice, locale);
        context.read<MainProvider>().clearRetiredVersionNotice();
        _scheduled = false;
      });
    }

    return widget.child;
  }
}
