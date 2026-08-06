/// 2026-08-06 (SeekSparks): one palette for biblical eras.
///
/// The timeline and the family tree colour-code by era, but they use
/// DIFFERENT era vocabularies — the timeline thinks in
/// conquest / monarchy / intertestamental, the family tree in
/// post_flood / davidic_line / kings / lukan_lineage. They are not
/// duplicates of one list; they are two taxonomies that overlap.
///
/// What they did share was the hex values, written out twice as switch
/// statements, plus a brightness-aware variant each — four places to
/// edit in step. They happened to agree on every shared key, but only
/// by hand. Re-toning the palette (which theming the app for the new
/// ink ground wants) would have been four edits and a hope.
///
/// These stay literal on purpose. They encode DATA, not chrome: the era
/// a person or event belongs to. A reader learns "gold means New
/// Testament" and that has to hold whatever accent colour they pick in
/// Settings, so these must not follow the theme seed. What they do need
/// is to sit comfortably on the app's ink surfaces, which is what the
/// tuning below is for.
library;

import 'package:flutter/material.dart';

/// Era key → colour. Covers both vocabularies; a key absent from one
/// view simply never gets looked up there.
const Map<String, Color> kEraColors = {
  // Shared by both views
  'antediluvian': Color(0xFF6B5E3F),
  'patriarchs': Color(0xFF8C5A2F),
  'mosaic': Color(0xFFB42E2E),
  'exile': Color(0xFF5F3F86),
  'nt': Color(0xFFB8860B),
  // Timeline only
  'conquest': Color(0xFF2F7C5C),
  'monarchy': Color(0xFF2A4FB0),
  'intertestamental': Color(0xFF505590),
  // Family tree only
  'post_flood': Color(0xFF2F7C5C),
  'davidic_line': Color(0xFF505590),
  'kings': Color(0xFF2A4FB0),
  'lukan_lineage': Color(0xFF8B3A62),
};

/// Shown when an era key is missing or unrecognised.
const Color kEraFallbackColor = Color(0xFF555555);

Color eraColor(String era) => kEraColors[era] ?? kEraFallbackColor;

/// Brightness-aware form. The palette was picked against a light
/// surface; on the app's dark ink ground these read as mud, so they get
/// lifted toward white. Lifting rather than swapping keeps the hue
/// association intact — gold is still gold, just legible.
Color eraColorFor(BuildContext context, String era) {
  final base = eraColor(era);
  if (Theme.of(context).brightness != Brightness.dark) return base;
  return Color.lerp(base, Colors.white, 0.45) ?? base;
}
