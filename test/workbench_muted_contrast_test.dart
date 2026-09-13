import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/workbench_theme.dart';

/// The muted ink clears AA on every fill it is drawn on.
///
/// 2026-09-14. `WbColors.light.mutedText` was measured at 4.17:1 on the
/// pane and 3.34:1 on `selectionBg`, and it is this app's second-most
/// used ink. It is printed at `WbMetrics.chrome` (11 px) and
/// `WbMetrics.text` (12 px) — far under the 18.66 px large-text
/// threshold, so the bar is 4.5:1 and it missed on all six fills.
///
/// How it got there is the reason this test exists. The commit that
/// flattened the chrome moved it "one step lighter, now that it no
/// longer has to survive a grey bar" — an argument about CHROME — while
/// that same commit's header said "Text … untouched: every one of them
/// is contrast-audited against a fill". The value that moved was text.
/// A sentence in a commit message is not a check.
///
/// `selectionBg` is in the list because `analysis_pin_bar.dart` draws
/// muted text directly on it — the 「Pinned created Genesis 1:1」 row.
/// All three palettes failed there, including before the regression.
void main() {
  double luminance(Color c) => c.computeLuminance();

  double ratio(Color a, Color b) {
    final la = luminance(a), lb = luminance(b);
    final hi = math.max(la, lb), lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  /// Every fill this app paints muted text on.
  List<(String, Color)> fillsOf(WbColors p) => [
        ('paneBg', p.paneBg),
        ('paneAltBg', p.paneAltBg),
        ('chromeBg', p.chromeBg),
        ('groundBg', p.groundBg),
        ('hoverBg', p.hoverBg),
        ('selectionBg', p.selectionBg),
      ];

  const palettes = <String, WbColors>{
    'light': WbColors.light,
    'dark': WbColors.dark,
    'paper': WbColors.paper,
  };

  group('mutedText', () {
    for (final entry in palettes.entries) {
      test('${entry.key}: clears 4.5:1 on every fill it lands on', () {
        for (final (name, fill) in fillsOf(entry.value)) {
          final r = ratio(entry.value.mutedText, fill);
          expect(r, greaterThanOrEqualTo(4.5),
              reason: '${entry.key}.mutedText on $name is '
                  '${r.toStringAsFixed(2)}:1. This ink is drawn at 11–12 '
                  'px, so 4.5 is the bar — 3:1 is for 18.66 px and up.');
        }
      });
    }

    test('it is still MUTED — quieter than the body ink', () {
      // The fix must not turn the secondary ink into the primary one.
      // A muted ink that reads as loudly as body text is a different
      // defect, not a stricter version of the same one.
      for (final entry in palettes.entries) {
        final p = entry.value;
        expect(ratio(p.text, p.paneBg), greaterThan(ratio(p.mutedText, p.paneBg)),
            reason: '${entry.key}: muted is no longer quieter than text');
      }
    });
  });

  test('the disabled mark is not used as an ink for content', () {
    // Sister rule, same audit: `disabledMark` measured 2.04 / 1.85 /
    // 2.66 against the pane, and `vocabulary_pane.dart` was printing
    // unlearned Hebrew and Greek WORDS in it. An off-state colour is
    // for an off state — an unticked box, an empty bar — not for
    // scripture the reader is being shown.
    for (final entry in palettes.entries) {
      final p = entry.value;
      final r = ratio(p.disabledMark, p.paneBg);
      expect(r, lessThan(4.5),
          reason: '${entry.key}: disabledMark now passes as body text, '
              'which means it has stopped reading as disabled');
    }
  });
}
