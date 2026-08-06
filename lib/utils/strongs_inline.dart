/// 2026-08-06 (SeekSparks): the inline Strong's numbers a tagged line
/// prints after each word.
///
/// yahwehdehua.net renders a tagged verse like this:
///
///   亚伯拉罕^G11 生^G1080 ^G5656 以撒^(G3588) ^G2464
///
/// Three distinct things share that superscript position, and telling
/// them apart is the whole reason the line stays readable:
///
///   * the word's own lexical number      — green
///   * grammar / TVM parsing codes        — blue
///   * numbers the original has that this
///     translation does not render        — parenthesised
///
/// This lives apart from the widget because the ordering rule below is
/// the kind of thing that should be pinned by a test, and the Browse
/// window itself cannot be driven in one (its verse source does not
/// resolve under `flutter test`).
library;

import 'package:flutter/foundation.dart';

enum StrongsNumberKind {
  /// The number for the word actually on screen.
  lexical,

  /// Hebrew stem/aspect, Greek tense-voice-mood.
  grammar,

  /// Present in the original, unrendered in the translation — the
  /// Hebrew object marker אֵת, the Greek article.
  implied,
}

@immutable
class StrongsNumberToken {
  const StrongsNumberToken(this.text, this.kind);

  /// Exactly as it should be printed, parentheses included.
  final String text;
  final StrongsNumberKind kind;

  @override
  bool operator ==(Object other) =>
      other is StrongsNumberToken && other.text == text && other.kind == kind;

  @override
  int get hashCode => Object.hash(text, kind);

  @override
  String toString() => '$text(${kind.name})';
}

/// The numbers to print after one tagged word, in print order.
///
/// Implied numbers come FIRST. That looks backwards until you check the
/// source: `天<WH853x><WH8064>` and `以撒<WG3588x><WG2464>` both put the
/// unrendered word ahead of the one on screen, because that is the order
/// the Hebrew and the Greek are in — אֵת before שָׁמַיִם, τόν before Ἰσαάκ.
/// Printing them in that order keeps the line aligned with the original
/// rather than with our own parse of it.
List<StrongsNumberToken> inlineStrongsNumbers({
  required String strongs,
  List<String> grammar = const [],
  List<String> implied = const [],
}) =>
    [
      for (final i in implied)
        if (i.isNotEmpty) StrongsNumberToken('($i)', StrongsNumberKind.implied),
      if (strongs.isNotEmpty)
        StrongsNumberToken(strongs, StrongsNumberKind.lexical),
      for (final g in grammar)
        if (g.isNotEmpty) StrongsNumberToken(g, StrongsNumberKind.grammar),
    ];

/// Which verse the Analysis window's X-Refs and Stats tabs report on.
///
/// 2026-08-06: split out of `workbench_page.dart` so the empty cases are
/// pinned by a test. v1.5.4 read `selected.first` unconditionally; once
/// a hovered word could reach the Analysis pane without a selection,
/// that threw `Bad state: No element` and blanked the whole workspace
/// behind a release ErrorWidget. Returning null is the contract — the
/// caller shows a hint.
T? pickAnalysisVerse<T>(List<T> selected, T? hovered) =>
    selected.isNotEmpty ? selected.first : hovered;
