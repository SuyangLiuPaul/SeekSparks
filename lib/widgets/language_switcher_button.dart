import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/models/app_settings.dart';

/// One-tap interface-language switcher for an AppBar's `actions`.
///
/// 2026-08 (ported from YsWords v1.3.154 / v1.4.x): a visible switcher
/// instead of digging into Settings → App → Interface Language every
/// time. Calls the same `settings.setLocale` the Settings dropdown
/// already uses, so the two stay in sync — neither is "the real one".
class LanguageSwitcherButton extends StatelessWidget {
  const LanguageSwitcherButton({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    return PopupMenuButton<String>(
      tooltip: uiStrings['interfaceLanguage']?[locale] ?? 'Interface Language',
      icon: const Icon(Icons.language_rounded),
      initialValue: locale,
      onSelected: (val) => settings.setLocale(val),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'zh-Hans', child: Text('简体中文')),
        PopupMenuItem(value: 'zh-Hant', child: Text('繁體中文')),
        PopupMenuItem(value: 'en', child: Text('English')),
      ],
    );
  }
}
