import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/services/link_opener.dart';
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
      dismissed: _dismissed ?? false,
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
  });

  final WorkbenchAdvice advice;
  final Size size;
  final String locale;
  final VoidCallback onContinue;

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
        child: Center(
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
                  const SizedBox(height: 26),
                  TextButton(
                    onPressed: onContinue,
                    child: Text(s('fitContinue', 'Continue anyway')),
                  ),
                  Text(
                    s('fitContinueNote', 'This only appears once.'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
