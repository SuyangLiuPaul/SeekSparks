import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'package:seeksparks/constants/motion.dart';

/// Canonical page-push helper — every `Get.to(...)` in the app should
/// route through here instead of specifying its own transition/duration/
/// curve, so page navigation feels consistent everywhere and the timing
/// can be tuned in one place ([AppMotion]).
///
/// 2026-08 (ported from YsWords v1.4.4, with the fix already applied):
/// `routeName` MUST be derived from the page widget, never left null.
/// GetX's `Get.to` does `routeName ??= "/${page.runtimeType}"` where
/// `page` is the BUILDER CLOSURE passed to it, then silently returns null
/// when `preventDuplicates && routeName == currentRoute`.
///
/// If this helper's `page` parameter is captured as `Widget` inside the
/// closure `() => page`, EVERY call site produces the same closure type
/// `() => Widget` — so every push after the first would resolve to the
/// same route name and get silently dropped by `preventDuplicates`. That
/// exact bug shipped in YsWords v1.4.1-1.4.3 and made most navigation
/// dead after the first push (see YsWords HANDOFF.md, v1.4.4 entry).
/// Passing the widget's own `runtimeType` explicitly avoids it entirely.
Future<T?>? pushPage<T>(
  Widget page, {
  bool reverse = false,
  String? routeName,
  bool preventDuplicates = true,
}) =>
    Get.to<T>(
      () => page,
      routeName: routeName ?? '/${page.runtimeType}',
      preventDuplicates: preventDuplicates,
      transition: reverse ? Transition.leftToRight : Transition.rightToLeft,
      duration: AppMotion.standard,
      curve: AppMotion.enter,
    );
