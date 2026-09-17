import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/workbench_theme.dart';

/// The name that floats beside the pointer on the wheel and the strip.
///
/// 2026-09-17 「when hovering over the line or strip can you have
/// hovering pop up label or something and when click then pop up
/// window?」 — asked from the wheel at 3614%, where the bands under the
/// pointer are a few pixels deep and most of them carry no name at all.
/// A mouse can ask a question without committing to it; until now it
/// could not, and the only way to find out what a band was, was to open
/// it and close it again.
///
/// Shared by both charts rather than written twice, because the two
/// pages already differ in every other respect and a plate that looked
/// like two different plates would read as two different features.
///
/// Touch devices have no hover and see none of this; they lose nothing,
/// since a tap has always opened the sheet.
class ChartHoverPlate extends StatelessWidget {
  const ChartHoverPlate(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        // The same three tokens the app's tooltips were repaired with on
        // 2026-09-16 — `text` on `paneBg` inside a `border` hairline.
        // Material's own defaults rendered white on white in dark mode
        // 「看不清」, and this plate appears in exactly the places that
        // bug was reported from.
        color: wb.paneBg,
        border: Border.all(color: wb.border),
        // On the scale, not near it — #279's rule, which a test
        // enforces per file.
        borderRadius: BorderRadius.circular(WbMetrics.radiusControl),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: wb.text,
          fontSize: math.max(t.scaledChrome(13), WbMetrics.smallPrintFloor),
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }
}

/// Put the plate beside the pointer and keep it on screen.
///
/// A layout delegate rather than arithmetic in a `Positioned`, because
/// the clamping needs the plate's MEASURED width — these names run from
/// 唐 to 大不列颠及北爱尔兰联合王国, and guessing a width would either clip
/// the long ones or leave the short ones floating away from what they
/// name.
class ChartHoverPlateLayout extends SingleChildLayoutDelegate {
  const ChartHoverPlateLayout(this.at);

  /// The pointer, in the coordinates of the box being laid out in —
  /// which is the VIEWPORT, never the chart's own space. Both charts
  /// live inside something that scales or scrolls them, and a plate
  /// positioned in that space would be zoomed with the chart.
  final Offset at;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(
          Size(math.min(constraints.maxWidth, 320), constraints.maxHeight));

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // Above and to the right, so the plate never covers the band the
    // pointer is resting on; flipped to the other side when there is no
    // room there, and never outside the viewport.
    var x = at.dx + 16;
    var y = at.dy - childSize.height - 12;
    if (x + childSize.width > size.width) x = at.dx - childSize.width - 16;
    if (y < 0) y = at.dy + 20;
    return Offset(
      x.clamp(0.0, math.max(0.0, size.width - childSize.width)),
      y.clamp(0.0, math.max(0.0, size.height - childSize.height)),
    );
  }

  @override
  bool shouldRelayout(ChartHoverPlateLayout old) => old.at != at;
}
