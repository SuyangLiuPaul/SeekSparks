import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/services/share_service.dart';
import 'package:seeksparks/utils/copy_marking.dart'
    show hasHitMarks, hitMarkedHtml, plainHitMarks;
import 'package:seeksparks/utils/clipboard_fallback_stub.dart'
    if (dart.library.js_interop) 'package:seeksparks/utils/clipboard_fallback_web.dart';

abstract class ClipboardHelper {
  /// Copy [text] to the system clipboard. Returns whether the copy
  /// SUCCEEDED — and, critically, NEVER throws.
  ///
  /// 2026-07-10 (prod crash report, iOS 18.7 Safari, zh-Hant):
  /// `PlatformException(copy_fail, Clipboard.setData failed.)` escaped
  /// to the Zone handler because several call sites awaited
  /// `Clipboard.setData` unguarded. Safari rejects the async Clipboard
  /// API outside a user-activation window / without clipboard
  /// permission. Now every failure is caught here, a synchronous
  /// legacy `execCommand('copy')` fallback is attempted on web (it
  /// works in exactly the situations where Safari rejects the async
  /// API), and callers get a plain bool to drive success/failure
  /// feedback. All app copy paths must go through this method —
  /// direct `Clipboard.setData` calls re-introduce the crash class.
  static Future<bool> copyText(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      return true;
    } catch (_) {
      return legacyClipboardCopy(text);
    }
  }

  /// Copy [html] as formatted text, falling back to [text] where the
  /// platform cannot carry formatting.
  ///
  /// Reports the two outcomes separately because they need different
  /// things said about them. `formatted: false` still means the words
  /// arrived — but a phrasing pasted as plain text has lost its
  /// indentation and its underlines, which is most of what the reader
  /// built, and calling that "Copied" is a small lie they only discover
  /// in the document.
  static Future<({bool copied, bool formatted})> copyRich(
    String html,
    String text,
  ) async {
    if (richClipboardCopy(html, text)) {
      return (copied: true, formatted: true);
    }
    return (copied: await copyText(text), formatted: false);
  }

  /// Copy [text] AND show a clear floating snackbar — a check-icon
  /// "Copied!" on success, an error-styled "Copy failed — clipboard
  /// unavailable" on failure. Use this instead of [copyText] + manual
  /// snackbar for every copy action so feedback is consistent across
  /// the app. Never throws.
  ///
  /// The [context] must be a descendant of a [ScaffoldMessenger]. Modal
  /// bottom sheets that want feedback should wrap their body in a
  /// local [Scaffold] (which provides its own messenger) — otherwise
  /// the snackbar anchors to the root scaffold and is hidden behind
  /// the modal.
  static Future<void> copyWithFeedback(
    BuildContext context,
    String text, {
    String? messageOverride,
  }) async {
    final ok = await copyText(text);
    if (!context.mounted) return;
    final locale = _localeFor(context);
    final message = ok
        ? (messageOverride ?? (uiStrings['copied']?[locale] ?? 'Copied!'))
        : (uiStrings['shareLinkFailed']?[locale] ??
            'Copy failed — clipboard unavailable');
    _toast(context, message, ok: ok);
  }

  /// The one copy-feedback snackbar. Floating, icon-led, and anchored
  /// to the nearest [ScaffoldMessenger] — see [copyWithFeedback] for
  /// what a modal sheet has to do to get its own.
  static void _toast(BuildContext context, String message,
      {required bool ok}) {
    final scheme = Theme.of(context).colorScheme;
    final fg = ok ? scheme.onInverseSurface : scheme.onError;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: fg,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? scheme.inverseSurface : scheme.error,
        duration: const Duration(milliseconds: 1800),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  /// Copy a hit-MARKED string: the words with their marks as
  /// `text/html`, the same words without them as `text/plain`, and a
  /// snackbar that says which one the destination will get.
  ///
  /// 2026-08-31: takes the string already marked with
  /// `copy_marking.dart`'s sentinels and derives both flavours here, so
  /// no caller has to know that the plain flavour is the marked one
  /// with the sentinels removed.
  ///
  /// Two messages, because the difference is visible in the document:
  /// a paste into Word or Google Docs arrives with the searched word
  /// highlighted, and a paste into a plain-text field cannot. Saying
  /// only "Copied!" in the second case would be a small lie the reader
  /// discovers after they have already sent the handout.
  ///
  /// Does NOT await anything before writing: on web the rich flavour
  /// rides the `copy` EVENT, which needs the user-activation window
  /// still to be open. An await here (loading a tagged book, say) is
  /// what would silently downgrade every copy to plain text.
  static Future<void> copyMarkedWithFeedback(
    BuildContext context,
    String marked, {
    String? messageOverride,
  }) async {
    if (!hasHitMarks(marked)) {
      return copyWithFeedback(context, marked,
          messageOverride: messageOverride);
    }
    // BOTH flavours carry the mark, and that is the point. The rich one
    // arrives highlighted where it is accepted; the plain one arrives
    // bracketed everywhere else — a .txt file, a plain-text mail part,
    // and (2026-08-31, owner-reported) Word and Pages, which did not
    // take the rich flavour from this app at all.
    final plain = plainHitMarks(marked);
    final r = await copyRich(hitMarkedHtml(marked), plain);
    if (!context.mounted) return;
    final locale = _localeFor(context);
    if (!r.copied) {
      // Nothing reached the clipboard: fall through to the shared
      // failure snackbar rather than inventing a second wording for it.
      return copyWithFeedback(context, plain);
    }
    _toast(
      context,
      r.formatted
          ? (messageOverride ?? (uiStrings['copied']?[locale] ?? 'Copied!'))
          : (uiStrings['copiedBracketed']?[locale] ??
              'Copied — hits marked 【 】'),
      ok: true,
    );
  }

  /// Share-first with copy-as-fallback. On platforms with the Web
  /// Share API (most mobile browsers + recent desktop Chrome/Edge),
  /// opens the system share sheet so users can post to Messages /
  /// Mail / Twitter / etc. Falls back to clipboard copy + the same
  /// "Copied!" snackbar when sharing isn't available or the user
  /// cancels the share dialog.
  static Future<void> shareOrCopy(
    BuildContext context,
    String text, {
    String? title,
  }) async {
    if (ShareService.isAvailable) {
      final shared = await ShareService.shareText(
        text: text,
        title: title,
      );
      if (shared) return;
    }
    if (!context.mounted) return;
    await copyWithFeedback(context, text);
  }

  /// The locale the APP is set to — `AppSettings.locale`, the same
  /// source every other `uiStrings` lookup in this codebase reads.
  ///
  /// 2026-08-24 (owner-reported: the "Copied!" toast stayed English
  /// after switching the app to 中文). This used to read
  /// `Localizations.maybeLocaleOf(context)`, which is Flutter's own
  /// locale — and `GetMaterialApp` in `main.dart` sets no `locale:`,
  /// no `supportedLocales` and no `localizationsDelegates`, so that
  /// value is the DEVICE's language and the in-app 🌐 switcher can
  /// never move it. On an English iPad it returned 'en' forever while
  /// the entire rest of the UI was Chinese. The lookup and the
  /// translations were both correct; only the locale source was wrong.
  ///
  /// Read without listening: this runs inside an event handler to
  /// build one snackbar string, not during build, so there is nothing
  /// to rebuild and `watch` would throw outside a build phase.
  static String _localeFor(BuildContext context) {
    final s = Provider.of<AppSettings>(context, listen: false);
    return s.locale;
  }
}
