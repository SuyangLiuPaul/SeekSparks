import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/workbench_theme.dart';
import '../utils/font_catalog.dart';

/// Both chart forms keep these same two choices in the same place.
/// Selecting the active choice does not reset the reader's view.
/// Whether the depth view is offered at all.
///
/// 2026-09-16 「或者我觉得立体其实strip和wheel都没有必要要了」. The 3D form
/// was the striking picture and the flat one is the readable chart, and
/// a day of use came down on the side of the chart: the depth view's
/// own problems — faces too small for their names, a mode button before
/// you could pan, blocks that read as floating — were being fixed one
/// at a time without the view ever becoming the one to reach for.
///
/// SET TO TRUE TO GET IT BACK, and nothing else has to change. The
/// scene builder, the painters, the hit tests, the callout banks and
/// their tests are all still here and still run — this hides the door,
/// not the room. `initialStacked: true` still opens a page in it, which
/// is how those tests reach it.
const bool kDepthViewOffered = false;

class ChronologyDepthToggle extends StatelessWidget {
  const ChronologyDepthToggle({
    super.key,
    required this.is3D,
    required this.onChanged,
    required this.locale,
    this.keyPrefix = 'chronologyDepth',
  });

  final bool is3D;
  final ValueChanged<bool> onChanged;
  final String locale;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final type = WbType.of(context);
    final labels = switch (locale) {
      'zh-Hans' => ('平面', '立体'),
      'zh-Hant' => ('平面', '立體'),
      _ => ('Flat', '3D'),
    };
    final style = TextStyle(
      fontFamily: type.fontFamily,
      fontFamilyFallback: kCjkFontFallback,
      fontSize: type.scaledChrome(13),
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: wb.text,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var labelWidth = 0.0;
    var labelHeight = 0.0;
    for (final label in [labels.$1, labels.$2]) {
      final text = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      labelWidth = math.max(labelWidth, text.width);
      labelHeight = math.max(labelHeight, text.height);
      text.dispose();
    }
    final target =
        math.max(44.0, WbMetrics.minTarget(Theme.of(context).platform));
    final segmentWidth = math.max(target, labelWidth.ceilToDouble() + 20);
    final segmentHeight = math.max(target, labelHeight.ceilToDouble() + 16);

    Widget choice(bool value, String label) {
      void choose() {
        if (value != is3D) onChanged(value);
      }

      return Semantics(
        key: ValueKey('$keyPrefix-${value ? '3d' : 'flat'}'),
        label: label,
        button: true,
        selected: value == is3D,
        inMutuallyExclusiveGroup: true,
        onTap: choose,
        excludeSemantics: true,
        child: Ink(
          color: value == is3D ? wb.selectionBg : wb.paneBg,
          child: InkWell(
            onTap: choose,
            hoverColor: wb.hoverBg,
            child: SizedBox(
              height: segmentHeight,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(label, style: style, maxLines: 1),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      key: ValueKey(keyPrefix),
      builder: (context, constraints) {
        final naturalWidth = segmentWidth * 2 + WbMetrics.hairline;
        final width = constraints.hasBoundedWidth
            ? math.min(naturalWidth, constraints.maxWidth)
            : naturalWidth;
        // At the largest menu size both Chinese labels need their full
        // measured width. If a host offers less, stack the two 44 px
        // targets instead of truncating the distinction between views.
        final vertical = width < naturalWidth;
        final children = [
          if (vertical)
            choice(false, labels.$1)
          else
            Expanded(child: choice(false, labels.$1)),
          SizedBox(
            width: vertical ? width : WbMetrics.hairline,
            height: vertical ? WbMetrics.hairline : segmentHeight,
            child: ColoredBox(color: wb.border),
          ),
          if (vertical)
            choice(true, labels.$2)
          else
            Expanded(child: choice(true, labels.$2)),
        ];
        return SizedBox(
          width: width,
          child: Material(
            color: wb.paneBg,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: wb.border, width: WbMetrics.hairline),
              borderRadius: BorderRadius.circular(WbMetrics.radiusControl),
            ),
            child: vertical
                ? Column(mainAxisSize: MainAxisSize.min, children: children)
                : Row(mainAxisSize: MainAxisSize.min, children: children),
          ),
        );
      },
    );
  }
}
