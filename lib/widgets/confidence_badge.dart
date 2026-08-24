import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart' show WbType;
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;

/// Small pill showing an evidence's confidence level (Definitive /
/// Strong / Circumstantial). Uses the colors defined on the
/// `BibleEvidence` model so the same hue means the same level
/// everywhere — list cards, detail page, dashboard tile.
class ConfidenceBadge extends StatelessWidget {
  final String level;
  final Color color;
  /// When true (used in detail view) renders larger with a filled
  /// background. Default is small + outlined for list cards.
  final bool prominent;

  const ConfidenceBadge({
    super.key,
    required this.level,
    required this.color,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final label = _label(level, locale);
    // `(fontSize - (prominent ? 1 : 3)).clamp(10, 16)` saturated at 16
    // for BOTH branches from 19 pt up — below the 20 pt default — so
    // the badge has rendered at exactly 16 px whatever the reader set,
    // and the 2 px the ternary asked for has never been drawn. 16 is
    // kept for both rather than restored to 17/19: this pill shares a
    // Row with the evidence title on the list card, so growing it is a
    // layout decision, where putting it on the scale is only a repair.
    final fs = WbType.of(context).scaledSmall(16);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: prominent ? 10 : 8,
        vertical: prominent ? 4 : 2,
      ),
      decoration: BoxDecoration(
        color: prominent
            ? color.withValues(alpha: 0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(prominent ? 8 : 6),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: settings.fontFamily, fontFamilyFallback: kCjkFontFallback,
          fontSize: fs,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  String _label(String level, String locale) {
    final key = 'confidence$level';
    return uiStrings[key]?[locale] ?? level;
  }
}
