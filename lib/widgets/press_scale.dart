import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';

import 'package:seeksparks/constants/motion.dart';

/// Subtle "presses in" scale feedback for tappable surfaces.
///
/// 2026-08 (ported from YsWords v1.4.5, safe version): drives the scale
/// from a [Listener], which observes raw pointer events WITHOUT ever
/// entering the gesture arena, so the child's own `InkWell` / `onTap`
/// keeps working untouched. That's what makes it safe to wrap around an
/// already-tappable card — an earlier YsWords version drove the scale
/// from a `GestureDetector` instead, which put a second competing
/// recogniser in the arena and risked eating the child's tap (the same
/// class of bug as the `pushPage` route-name collision — see
/// app_nav.dart).
///
/// [onTap] stays optional, for surfaces with no tap handling of their own
/// (e.g. a plain `Container`); when null this widget is purely decorative
/// and intercepts nothing.
///
/// A press releases once the pointer travels past [kTouchSlop], so starting
/// a scroll on a card doesn't leave it stuck looking pressed. Honours the
/// platform "reduce motion" accessibility setting.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Pressed-state scale. Keep this shallow — it should register as
  /// responsiveness, not as the card physically shrinking.
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;
  Offset? _origin;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    Widget child = widget.child;
    if (widget.onTap != null) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: child,
      );
    }

    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) return child;

    return Listener(
      // deferToChild: never claim a hit the child wouldn't have taken.
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (event) {
        _origin = event.position;
        _setPressed(true);
      },
      onPointerMove: (event) {
        final origin = _origin;
        if (_pressed &&
            origin != null &&
            (event.position - origin).distance > kTouchSlop) {
          // Turned into a scroll/drag — let go of the pressed look.
          _setPressed(false);
        }
      },
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.enter,
        child: child,
      ),
    );
  }
}
