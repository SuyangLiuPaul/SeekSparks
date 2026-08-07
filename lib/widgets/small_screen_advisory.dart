import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/services/link_opener.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/workbench_fit.dart';

/// The sibling app. SeekSparks was forked from it; on a phone it is
/// the honest recommendation, not a competitor.
const String kYsWordsUrl = 'https://yswords.netlify.app';

const String kSmallScreenDismissedKey = 'workbench_fit_advisory_dismissed';

/// Wraps the workbench and, on a phone-sized viewport, shows the
/// advisory in front of it exactly once.
///
/// The gate is deliberately an advisory and not a lockout: `Continue
/// anyway` hands over the workbench and writes a flag that is never
/// unwritten, so a reader who has said no is never asked again.
class SmallScreenGate extends StatefulWidget {
  const SmallScreenGate({super.key, required this.child});

  final Widget child;

  @override
  State<SmallScreenGate> createState() => _SmallScreenGateState();
}

class _SmallScreenGateState extends State<SmallScreenGate> {
  /// null = not read from disk yet. Treated as "may still need the
  /// advisory", so the workbench is never shown and then yanked away.
  bool? _dismissed;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(
        () => _dismissed = prefs.getBool(kSmallScreenDismissedKey) ?? false);
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kSmallScreenDismissedKey, true);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    final advice = WorkbenchFit.adviceFor(
      width: size.width,
      height: size.height,
      // 2026-08-07: always false. The gate is now a hard block, so a
      // dismissal persisted by v1.6.20 or earlier must not keep letting
      // that reader through — the stale bit would quietly exempt exactly
      // the people who had already seen the broken advisory.
      // `adviceFor` keeps the parameter; only this caller stops using it.
      dismissed: false,
    );

    // Big screens answer `none` regardless of the flag, so they never
    // wait on the disk read — no placeholder frame, no rebuild.
    if (advice == WorkbenchAdvice.none) return widget.child;

    // Small screen, answer not back yet. Hold on the background rather
    // than showing the workbench and yanking it away a frame later.
    if (_dismissed == null) {
      return Scaffold(backgroundColor: Theme.of(context).colorScheme.surface);
    }

    return SmallScreenAdvisory(
      advice: advice,
      size: size,
      locale: context.watch<AppSettings>().locale,
      onContinue: _dismiss,
      onLocale: (code) => context.read<AppSettings>().setLocale(code),
    );
  }
}

/// The advisory itself, separated from the gate so it can be laid out
/// and read without SharedPreferences in the way.
class SmallScreenAdvisory extends StatelessWidget {
  const SmallScreenAdvisory({
    super.key,
    required this.advice,
    required this.size,
    required this.locale,
    required this.onContinue,
    required this.onLocale,
  });

  final WorkbenchAdvice advice;
  final Size size;
  final String locale;
  final VoidCallback onContinue;

  /// Changing the interface language from HERE is not a convenience —
  /// it is the only way. The gate is a hard block, so Settings is
  /// unreachable behind it: a reader whose device is set to English but
  /// who reads Chinese would otherwise be stopped by a wall they cannot
  /// even read, with no way to change it.
  final ValueChanged<String> onLocale;

  @override
  Widget build(BuildContext context) {
    String s(String key, String fallback) =>
        uiStrings[key]?[locale] ?? fallback;

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.68);

    final needs = s('fitNeeds',
            'Three columns need about {three} px of width, two need about '
            '{two}. This screen is {w} × {h}.')
        .replaceAll('{three}', WorkbenchFit.threePaneMinWidth.round().toString())
        .replaceAll('{two}', WorkbenchFit.twoPaneMinWidth.round().toString())
        .replaceAll('{w}', size.width.round().toString())
        .replaceAll('{h}', size.height.round().toString());

    final variant = advice == WorkbenchAdvice.rotate
        ? s('fitRotate',
            'Turning the phone sideways gets you two: search beside the '
            'text. All three needs a tablet or a laptop.')
        : s('fitLarger',
            'This screen does not reach two columns in either direction. A '
            'tablet or a laptop — roughly 4:3 to 16:10 — is what this '
            'layout was drawn for.');

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        // The switcher is LAST in this Stack, not first. Stack paints in
        // child order, so with it first the centred content sat on top
        // and swallowed the taps — the control was visible and dead. A
        // widget test caught it; nothing about the layout looked wrong.
        child: Stack(
          children: [
            Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Shows the shape being described rather than an
                  // error icon. Nothing has gone wrong here.
                  _PaneDiagram(
                    highlight: advice == WorkbenchAdvice.rotate ? 2 : 1,
                    color: cs.primary,
                    muted: cs.onSurface.withValues(alpha: 0.22),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    s('fitTitle', 'SeekSparks is a study workbench'),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    s('fitLead',
                        'Search, the text, and word analysis sit side by '
                        'side — three columns on one screen.'),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: muted, height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          variant,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          needs,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: muted, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    s('fitYsWords',
                        'For reading on a phone, YsWords is built for '
                        'exactly that — same family, phone-first.'),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: muted, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  if (LinkOpener.isAvailable)
                    FilledButton.icon(
                      onPressed: () => LinkOpener.open(kYsWordsUrl),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(s('fitOpenYsWords', 'Open YsWords')),
                    )
                  else
                    SelectableText(
                      kYsWordsUrl,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: cs.primary),
                    ),
                  // 2026-08-07: "Continue anyway" REMOVED at the user's
                  // instruction — 「不要有仍然继续，就一直是block住」. The
                  // earlier reasoning was that a reminder which will not
                  // take no for an answer is a nag; the owner's call is
                  // that a one-column workbench is not a product they
                  // want shipped at all, and letting readers past the
                  // gate is how it gets judged as one. There is a real
                  // destination here (YsWords, above) rather than a dead
                  // end, which is what makes a hard gate defensible.
                  //
                  // `onContinue` is intentionally left on the widget's
                  // API: it is still the escape hatch a future setting
                  // or a QA build would wire up, and deleting it would
                  // make restoring the choice a bigger change than the
                  // decision deserves.
                ],
              ),
            ),
          ),
        ),
            Positioned(
              top: 8,
              right: 12,
              child: _LocaleSwitch(
                locale: locale,
                onLocale: onLocale,
                color: cs.onSurface,
                accent: cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// EN / 简 / 繁, as three flat text buttons. Deliberately not a dropdown:
/// a reader who cannot read the wall cannot be asked to open a menu
/// labelled in the language they do not read. All three labels are
/// written in their own script, so each is legible to the person who
/// needs it.
class _LocaleSwitch extends StatelessWidget {
  const _LocaleSwitch({
    required this.locale,
    required this.onLocale,
    required this.color,
    required this.accent,
  });

  final String locale;
  final ValueChanged<String> onLocale;
  final Color color;
  final Color accent;

  static const _options = <String, String>{
    'en': 'EN',
    'zh-Hans': '简',
    'zh-Hant': '繁',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final e in _options.entries)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: TextButton(
              onPressed: locale == e.key ? null : () => onLocale(e.key),
              style: TextButton.styleFrom(
                minimumSize: const Size(40, 36),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                // The current language stays legible rather than being
                // greyed out as "disabled" — it is the answer, not an
                // unavailable option.
                foregroundColor: accent,
                disabledForegroundColor: accent,
              ),
              child: Text(
                e.value,
                style: TextStyle(
                  // 简 / 繁 rendered as tofu boxes in v1.6.23: a bare
                  // TextStyle falls back to Roboto, which has no CJK
                  // glyphs, so the two buttons a Chinese reader needs
                  // were the only unreadable things on the screen.
                  fontFamilyFallback: kCjkFontFallback,
                  fontSize: 14,
                  fontWeight:
                      locale == e.key ? FontWeight.w700 : FontWeight.w400,
                  color: locale == e.key
                      ? accent
                      : color.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Three stacked bars standing in for the three columns. [highlight]
/// is how many this screen can actually carry after the advice is
/// followed — one today, two after a rotation.
class _PaneDiagram extends StatelessWidget {
  const _PaneDiagram({
    required this.highlight,
    required this.color,
    required this.muted,
  });

  final int highlight;
  final Color color;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    const flexes = [3, 5, 4];
    return SizedBox(
      height: 56,
      width: 168,
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              flex: flexes[i],
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: i < highlight ? color.withValues(alpha: 0.30) : null,
                  border: Border.all(color: i < highlight ? color : muted),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
