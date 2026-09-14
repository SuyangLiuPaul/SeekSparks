import 'package:flutter/widgets.dart';

/// Canonical animation durations and curves, so "quick transition" doesn't
/// silently mean 200ms in one widget and 300ms in another. Values below are
/// deliberately app-wide constants, not per-widget tuning knobs.
///
/// 2026-08 (ported from YsWords v1.4.1).
class AppMotion {
  const AppMotion._();

  /// Micro-interactions: tap feedback, small toggles.
  static const fast = Duration(milliseconds: 150);

  /// Page/route transitions, most enter/exit animations.
  static const standard = Duration(milliseconds: 250);

  /// Sheets, dialogs, and other larger reveals.
  static const slow = Duration(milliseconds: 350);

  /// Things arriving on screen.
  static const enter = Curves.easeOutCubic;

  /// Things leaving the screen.
  static const exit = Curves.easeInCubic;

  /// Back-and-forth motion (page-swipe settle, toggle animations).
  static const symmetric = Curves.easeInOutCubic;

  /// [d], or nothing at all if the reader has asked for less motion.
  ///
  /// 2026-09-14, from the accessibility pass. WCAG 2.3.3 asks that
  /// motion animation triggered by interaction can be turned off, and
  /// the platform switch that says so — Reduce Motion on iOS/macOS,
  /// "Remove animations" on Android, `prefers-reduced-motion: reduce`
  /// in a browser — arrives in Flutter as
  /// [MediaQueryData.disableAnimations]. Two widgets in this app read
  /// it; every other animation ignored it, because an implicit
  /// animation takes the duration it is handed and the framework never
  /// looks at the flag on its behalf.
  ///
  /// Deliberately applied to MOVEMENT and not to fades. 2.3.3 is about
  /// motion — something travelling across the screen, scaling, or
  /// spinning — and a 150ms crossfade is not that; zeroing every
  /// AnimatedSwitcher would make labels change by jump-cut for a reader
  /// who asked for calm, which is not calmer. The sites that take this
  /// are the two chrome bars that slide a screen-height and a half, the
  /// press scale, the disclosure rotations, and the panes that resize.
  ///
  /// `Duration.zero` rather than a short duration: an implicit animation
  /// with a zero duration jumps straight to its new value, which is what
  /// "no animation" means. A 1ms animation still schedules a frame and
  /// still ticks a curve.
  static Duration duration(BuildContext context, Duration d) =>
      (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
          ? Duration.zero
          : d;
}
