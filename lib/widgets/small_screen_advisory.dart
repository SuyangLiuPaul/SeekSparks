import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/app_version.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/services/link_opener.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/workbench_fit.dart';

/// The sibling app. SeekSparks was forked from it; on a phone it is
/// the honest recommendation, not a competitor.
///
/// The canonical home, not the Netlify subdomain it is also served on:
/// this gate is the one screen a phone reader ever sees, so the address
/// it hands them is the one they will remember and type again. Same
/// family as this app's own `sword.yahwehword.com`.
const String kYsWordsUrl = 'https://yahwehword.com';

/// Shows the advisory instead of the app on a viewport that cannot
/// carry the workbench.
///
/// **Synchronous on purpose, and mounted ABOVE the splash on purpose.**
/// The decision has exactly one input — the viewport — and that is known
/// on the very first frame, so nothing here may wait on disk, on the
/// network, or on the boot.
///
/// Sequencing it behind any of those is what stranded phones in v1.6.56.
/// The gate used to sit *inside* the post-splash router and to hold on a
/// blank `Scaffold` while a persisted flag loaded, which meant a phone
/// reader sat through the entire cold boot — every bundled Bible parsed —
/// before being told the app was not for them, and a boot that stalled
/// meant they were never told at all. The flag it waited for could not
/// change the answer either: `Continue anyway` was removed in v1.6.20,
/// so the gate has passed `dismissed: false` unconditionally ever since.
class SmallScreenGate extends StatelessWidget {
  const SmallScreenGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    final advice = WorkbenchFit.adviceFor(
      width: size.width,
      height: size.height,
      // The gate is a hard block — there is no dismissal to honour.
      // `adviceFor` keeps the parameter for its own unit tests.
      dismissed: false,
    );

    if (advice == WorkbenchAdvice.none) return child;

    return SmallScreenAdvisory(
      advice: advice,
      size: size,
      locale: context.watch<AppSettings>().locale,
      // Both subscriptions sit AFTER the early return on purpose: a
      // display that carries the workbench must not pay a rebuild for
      // a setting only this screen reads.
      type: WbType.of(context),
      onLocale: (code) => context.read<AppSettings>().setLocale(code),
    );
  }
}

/// The advisory itself, separated from the gate so it can be laid out
/// and read without a viewport decision in the way.
class SmallScreenAdvisory extends StatelessWidget {
  const SmallScreenAdvisory({
    super.key,
    required this.advice,
    required this.size,
    required this.locale,
    this.type = WbType.fallback,
    this.onContinue,
    required this.onLocale,
  });

  final WorkbenchAdvice advice;
  final Size size;
  final String locale;

  /// The reader's type scale, passed in rather than read from a
  /// provider — same reason `locale` is. The widget renders copy and
  /// nothing else, so it stays testable without a provider tree.
  final WbType type;

  /// Unwired: `Continue anyway` was removed in v1.6.20 (see the note by
  /// the YsWords button below). Left on the API because it is still the
  /// hook a future setting or a QA build would use.
  final VoidCallback? onContinue;

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

    // `rotate` is returned only when the long edge carries all THREE
    // columns, so on this branch the device in the reader's hands is
    // not too small — it is held the wrong way round. Everything below
    // that differs between the two branches follows from that one fact.
    final isRotate = advice == WorkbenchAdvice.rotate;

    final needs = (isRotate
            ? s(
                'fitRotateNeeds',
                'Three columns need about {three} px of width. This screen '
                'is {w} × {h} — sideways that is {long} px.',
              )
            : s(
                'fitNeeds',
                'Three columns need about {three} px of width. '
                'This screen is {w} × {h}.',
              ))
        .replaceAll('{three}', WorkbenchFit.threePaneMinWidth.round().toString())
        .replaceAll('{w}', size.width.round().toString())
        .replaceAll('{h}', size.height.round().toString())
        .replaceAll(
            '{long}', size.longestSide.round().toString());

    final variant = isRotate
        ? s('fitRotate',
            'Turn the device sideways and the full three-column workbench '
            'opens.')
        : s('fitLarger',
            'This screen does not fit three columns in either direction. '
            'SeekSparks needs a tablet or a laptop.');

    // The instruction, in the box that carries the device's own
    // numbers. On the rotate branch it is the loudest thing on the
    // page — it is a one-gesture fix and the reader wants it before
    // they want the explanation.
    final callout = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: isRotate ? 0.11 : 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isRotate) ...[
                Icon(
                  Icons.screen_rotation,
                  size: type.scaledChrome(22),
                  color: cs.primary,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  variant,
                  style: (isRotate
                          ? theme.textTheme.titleMedium
                          : theme.textTheme.bodyMedium)
                      ?.copyWith(
                    color: cs.onSurface,
                    fontWeight: isRotate ? FontWeight.w600 : null,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            needs,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: muted, height: 1.45),
          ),
        ],
      ),
    );

    // What the app is, and why it wants the room. On the largerDisplay
    // branch this has to come first: the answer there is "use another
    // device", which only persuades once the reason is in hand.
    final explanation = <Widget>[
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
            'Search, the text, and word analysis sit side by side — three '
            'columns on one screen.'),
        style: theme.textTheme.bodyMedium?.copyWith(color: muted, height: 1.5),
      ),
    ];

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
                    // Three, not two. `rotate` is only ever returned
                    // when the long edge clears the THREE-pane
                    // threshold, so the picture showing two columns was
                    // the same 2026-08-07 drift as the copy — and the
                    // louder half of it, since the diagram is the first
                    // thing read.
                    highlight: isRotate ? 3 : 1,
                    color: cs.primary,
                    muted: cs.onSurface.withValues(alpha: 0.22),
                  ),
                  const SizedBox(height: 24),
                  if (isRotate) ...[
                    callout,
                    const SizedBox(height: 22),
                    ...explanation,
                  ] else ...[
                    ...explanation,
                    const SizedBox(height: 18),
                    callout,
                  ],
                  const SizedBox(height: 22),
                  // Demoted on the rotate branch, where this device is
                  // not the problem and sending the reader away would
                  // be answering a question they did not ask.
                  Text(
                    isRotate
                        ? s('fitYsWordsAside',
                            'Prefer to read in portrait? YsWords is the '
                            'phone-first reader in the same family.')
                        : s('fitYsWords',
                            'For reading on a phone, YsWords is built for '
                            'exactly that — same family, phone-first.'),
                    style: (isRotate
                            ? theme.textTheme.bodySmall
                            : theme.textTheme.bodyMedium)
                        ?.copyWith(color: muted, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  if (!LinkOpener.isAvailable)
                    SelectableText(
                      kYsWordsUrl,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: cs.primary),
                    )
                  else if (isRotate)
                    TextButton(
                      onPressed: () => LinkOpener.open(kYsWordsUrl),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: muted,
                      ),
                      child: Text(s('fitOpenYsWords', 'Open YsWords')),
                    )
                  else
                    FilledButton.icon(
                      onPressed: () => LinkOpener.open(kYsWordsUrl),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(s('fitOpenYsWords', 'Open YsWords')),
                    ),
                  // The build identity, asked for by the owner on
                  // 2026-08-12. The gate is a HARD BLOCK, so Settings
                  // and About are both unreachable from here — a reader
                  // stopped by this screen otherwise has no way at all
                  // to learn which build they are looking at, which is
                  // exactly the moment they are being asked "what
                  // version are you on?". Selectable so it can be
                  // copied straight into a report.
                  //
                  // Same readout as the workbench status bar
                  // (`workbench_page.dart`), deliberately: #314 settled
                  // that format as canonical, and a second spelling of
                  // the same fact is how the two drift.
                  const SizedBox(height: 28),
                  SelectableText(
                    'v$kAppVersion · ${formatReleaseTimeLocal()}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.45),
                      fontSize: type.scaled(11),
                    ),
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
                fontSize: type.scaledChrome(14),
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
    required this.fontSize,
  });

  final String locale;
  final ValueChanged<String> onLocale;
  final Color color;
  final Color accent;

  /// From the reader's type scale rather than a literal — this was one
  /// of the 269 hardcoded sizes #315 went after, and it is the one on
  /// the screen a reader can least afford to be unable to read, since
  /// it is the only control the gate offers.
  final double fontSize;

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
                  fontSize: fontSize,
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
/// is how many this screen can actually carry AFTER the advice is
/// followed — one on a display that cannot grow, and all three after a
/// rotation, because rotation is only ever offered when the long edge
/// clears the three-pane threshold.
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
      key: const Key('fit-pane-diagram'),
      height: 56,
      width: 168,
      child: Row(
        // `stretch`, not the default `center`. A childless DecoratedBox
        // takes the SMALLEST size its constraints allow, and `center`
        // hands its children a LOOSE cross-axis constraint — so all
        // three bars sized themselves to zero height and the diagram
        // rendered as three grey hairlines. It had been that way since
        // the advisory was written: the illustration meant to show a
        // reader the shape of the thing they cannot fit showed nothing
        // at all, and no test could see it because the SizedBox around
        // it was the full 56 px throughout.
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
