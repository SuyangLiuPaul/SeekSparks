import 'package:flutter/material.dart';

/// SeekSparks-only: a persistent right-hand docked panel for desktop/
/// tablet-wide screens, used in place of a modal bottom sheet for the
/// panels power users keep open while reading (Original-language study,
/// and eventually the structured Strong's search). YsWords' own bottom
/// sheets stay untouched — this is a parallel, opt-in presentation
/// used only by call sites that explicitly reach for it on wide
/// screens (see `_showOriginalsSheet` in bible_reading_pane.dart for
/// the reference pattern: check `ResponsiveBreakpoints.isDesktopOrWider`
/// and branch between this and the existing `showModalBottomSheet`).
///
/// Implemented as a real [Navigator] route (a [PopupRoute], the same
/// base class `showDialog`/`showModalBottomSheet` build on) rather than
/// a raw overlay, specifically so content built for the old bottom
/// sheet — like `OriginalsSheet`'s own close button, which calls
/// `Navigator.of(context).maybePop()` internally — keeps working
/// unmodified: that call now pops *this* route instead of the sheet
/// route it used to assume.
Future<T?> showDockedPanel<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double width = 480,
}) {
  return Navigator.of(context).push<T>(
    _DockedPanelRoute<T>(builder: builder, width: width),
  );
}

class _DockedPanelRoute<T> extends PopupRoute<T> {
  final WidgetBuilder builder;
  final double width;
  _DockedPanelRoute({required this.builder, required this.width});

  @override
  Color? get barrierColor => Colors.black.withValues(alpha: 0.18);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        elevation: 8,
        color: scheme.surface,
        child: SizedBox(
          width: width,
          height: double.infinity,
          child: SafeArea(child: builder(context)),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final slide = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
    return SlideTransition(position: slide, child: child);
  }
}
