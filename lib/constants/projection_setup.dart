/// 投影 SETUP — everything about a projection that is not the passage.
///
/// The type ladder, the ground, which second edition, and the named
/// bundles of all three. Split out of `projection_page.dart` on
/// 2026-09-09 for one reason: these are now PERSISTED, and
/// `AppSettings` is the thing that persists them. A settings model
/// importing a page to find out how long a ladder is would be the wrong
/// way round, and the page still re-exports what it used to own so
/// nothing that already imports `kProjectionTypeSteps` had to move.
///
/// The owner's report is the whole brief: 「projector setting怎么没做好
/// 背景也不能set或者preset两个经文也不能调整这个功能要完整」. Three
/// complaints — nothing survives closing the page, there is one fixed
/// ground and no presets, and the second edition cannot be chosen.
///
/// ## WHY EVERY GROUND HERE IS DARK
///
/// `projection_stage.dart`'s library doc states the rule and this file
/// is where it is enforced, so the argument is worth having in both
/// places. A projector ADDS light: it cannot make a wall darker than
/// the room already is, so white pixels wash the room and dark pixels
/// are the closest thing the machine has to "off". That is not a taste
/// argument, it is what the hardware does.
///
/// It also decides the blank key. Blanking is only honest if it lands
/// on the same ground the passage was already sitting on — a cream page
/// cut to black is a flash across the whole wall, and a congregation
/// reads a flash as a fault. So the ground is a CHOICE among darks, the
/// blanked wall is painted with the identical [ProjectionGroundPaint],
/// and `projection_setup_test.dart` pins both: every colour any ground
/// paints is under [kProjectionGroundMaxLuminance], and scripture keeps
/// [kProjectionGroundMinContrast] against the brightest of them.
///
/// There is deliberately no light ground and no photograph. A light one
/// fails the paragraph above. A photograph would need a scrim heavy
/// enough to satisfy both halves of it — legible at forty feet AND dark
/// enough that blanking is not a flash — and a scrim that heavy is a
/// dark ground with an image nobody can make out underneath it. The one
/// non-flat ground here is [ProjectionGround.vignette], which is a
/// gradient BETWEEN two darks and so passes on its own terms.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

/// The sizes the operator steps through, in logical pixels.
///
/// A ladder rather than a slider: an operator adjusting this is doing it
/// mid-service with a room watching, and "press the key twice more" is a
/// thing you can do without looking.
///
/// The steps are a roughly constant RATIO (1.14–1.25, mean 1.17) rather
/// than a constant increment, because that is what a press being "the
/// same amount bigger" means to an eye. A fixed +8 would run 32→40, a
/// quarter larger and unmistakable, and 152→160, a twentieth and
/// invisible — the same key doing two different jobs at the two ends of
/// its own range.
///
/// The floor of 32 is not arbitrary. `WbMetrics.text` (12) at the
/// reading slider's maximum (`kFontSizeMax` / `kFontSizeDefault` = 2x)
/// is 24 px, so the smallest projection size is still a third larger
/// than the biggest size the reading setting can produce. The two scales
/// do not overlap, which is the whole point of there being two.
const List<double> kProjectionTypeSteps = <double>[
  32,
  40,
  48,
  56,
  64,
  76,
  88,
  104,
  120,
  140,
  160,
];

/// Where a freshly-opened projection starts on [kProjectionTypeSteps],
/// for an operator who has never touched the size.
///
/// 64 px, the middle of the ladder, so the first adjustment the operator
/// makes has room to go either way. Starting at the bottom would make
/// "bigger" the only useful key and cost a press or four every time.
///
/// Only the FIRST time now: since 2026-09-09 the chosen step is a
/// persisted setting, so the second service starts where the first one
/// ended.
const int kProjectionTypeDefaultStep = 4;

/// The step index [current] moves to for [delta], clamped to the ladder.
int projectionTypeStep(int current, int delta) =>
    (current + delta).clamp(0, kProjectionTypeSteps.length - 1);

/// The grounds the operator can put a passage on.
///
/// Small and named, because this is chosen from a strip at the top of a
/// wall by someone who is not looking at the screen. A colour picker
/// would be the wrong control twice over: it can produce a ground that
/// breaks the rule in the library doc, and "pick a hex value" is not a
/// thing anyone does mid-service.
///
/// The persisted form is the enum's `name`, never its index, so
/// inserting a ground later cannot silently reinterpret a saved
/// preference — the rule `_kCrossVersionSearchMode` follows in
/// `app_settings.dart`.
enum ProjectionGround {
  /// The ground the projection shipped with: `WbColors.dark.groundBg`.
  ///
  /// Default, so nothing changes for an operator who already had this
  /// working. It is a near-black navy rather than black because it is
  /// the app's own ground and the projection is still the app.
  deep,

  /// #000000, which is what a projector's "off" actually is.
  ///
  /// On a DLP or LCD projector this is the least light the machine can
  /// emit, so it is the ground that gives the highest real contrast in a
  /// room that cannot be fully darkened. On an LED wall or an OLED panel
  /// — increasingly what a church actually has — black pixels are OFF
  /// pixels: the ground stops drawing power and stops glowing, which no
  /// near-black can do.
  black,

  /// A warm near-black.
  ///
  /// Two rooms want this. A projector's own black is never black: it is
  /// a lifted grey with a blue cast, and against a warm wall — brick,
  /// wood, a sanctuary under tungsten — a cool ground reads as a grey
  /// rectangle hanging in front of the room while a warm one reads as
  /// the wall itself. The second is a print convention: warm dark under
  /// warm white is what a hymnal looks like, and a congregation reading
  /// for twenty minutes is doing the same work as a reader.
  warm,

  /// A vertical gradient between two darks.
  ///
  /// The one non-flat ground, and it earns its place on a big wall: a
  /// perfectly flat fill across 4 metres shows every banding artefact
  /// and every dirty-lens hotspot the projector has, and the eye reads
  /// those as a fault in the picture. A gradient absorbs them — the
  /// variation is now intentional and the artefacts are inside it.
  ///
  /// It is a gradient between two DARKS, so it needs no scrim: its
  /// brightest point is still under [kProjectionGroundMaxLuminance], and
  /// blanking paints the identical gradient rather than cutting to
  /// black, so the blank key stays a shutter instead of a flash.
  vignette,
}

/// The ground a projection uses when nothing has been chosen.
const ProjectionGround kProjectionGroundDefault = ProjectionGround.deep;

/// How the wall is painted for one [ProjectionGround].
///
/// [stops] is EVERY colour the ground puts on the wall — one entry for a
/// flat ground, two for a gradient. It exists so the legibility test can
/// ask about the brightest thing on screen rather than about a
/// representative colour, and so nothing can be added here without that
/// test looking at it.
@immutable
class ProjectionGroundPaint {
  const ProjectionGroundPaint({required this.base, required this.stops});

  /// The single colour behind everything — the flat fill, and the
  /// Scaffold's own background under the stage.
  ///
  /// For a gradient this is its DARKEST stop, so any pixel the stage
  /// does not cover is darker than the wall, never brighter.
  final Color base;

  /// Top to bottom. One colour is a flat ground.
  final List<Color> stops;

  bool get isFlat => stops.length == 1;

  /// Null for a flat ground — a caller paints [base] instead, which is
  /// what keeps the default a plain `ColoredBox` of the app's own
  /// `groundBg` and not a one-colour gradient wearing its name.
  Gradient? get gradient => isFlat
      ? null
      : LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: stops,
        );
}

/// No ground may put a colour brighter than this on the wall.
///
/// Relative luminance, the WCAG quantity. 0.05 is far below the 0.179
/// midpoint `theme_accent.dart` uses to pick ink for a fill — this is
/// not "dark enough to read on", it is "dark enough that the projector
/// is nearly off", which is the stricter claim the blank key rests on.
const double kProjectionGroundMaxLuminance = 0.05;

/// Scripture's contrast floor against the brightest colour of any
/// ground.
///
/// WCAG asks 4.5 for body text and 3.0 for large text, and this is very
/// large text — so 7.0 looks generous until you remember the room: the
/// reader is forty feet away, the projector is throwing through ambient
/// light that lifts the black, and nobody can lean in. The audit is done
/// against the paint, which is the best case; the room only ever makes
/// it worse.
const double kProjectionGroundMinContrast = 7.0;

/// The paint for each ground.
///
/// `deep` repeats `WbColors.dark.groundBg` as a literal rather than
/// importing it, because `workbench_theme.dart` imports `AppSettings`
/// and `AppSettings` imports this file — the cycle is legal Dart and
/// still the wrong shape. `projection_setup_test.dart` asserts the two
/// values are equal, so the duplication cannot drift.
const Map<ProjectionGround, ProjectionGroundPaint> projectionGroundPaints =
    <ProjectionGround, ProjectionGroundPaint>{
  ProjectionGround.deep: ProjectionGroundPaint(
    base: Color(0xFF070D17),
    stops: <Color>[Color(0xFF070D17)],
  ),
  ProjectionGround.black: ProjectionGroundPaint(
    base: Color(0xFF000000),
    stops: <Color>[Color(0xFF000000)],
  ),
  ProjectionGround.warm: ProjectionGroundPaint(
    base: Color(0xFF120D08),
    stops: <Color>[Color(0xFF120D08)],
  ),
  ProjectionGround.vignette: ProjectionGroundPaint(
    base: Color(0xFF03060C),
    stops: <Color>[Color(0xFF12203A), Color(0xFF03060C)],
  ),
};

ProjectionGroundPaint projectionGroundPaintFor(ProjectionGround ground) =>
    projectionGroundPaints[ground]!;

/// The ground a stored `name` means, or the default when it means
/// nothing this build has.
///
/// Clamped on the way IN rather than trusted, the same treatment
/// `_kChronologyView` gets: a preference written by a later build, a
/// hand-edited prefs file or an imported settings blob can hold
/// anything, and the wrong answer here is a wall nobody chose.
ProjectionGround projectionGroundFromName(String? name) =>
    ProjectionGround.values.firstWhere(
      (g) => g.name == name,
      orElse: () => kProjectionGroundDefault,
    );

/// One complete operator setup: everything a preset remembers, and
/// everything the projection page restores when it opens.
///
/// `blank` is deliberately NOT here — see `AppSettings` for why.
@immutable
class ProjectionSetup {
  const ProjectionSetup({
    required this.typeStep,
    required this.secondOn,
    required this.secondVersion,
    required this.ground,
  });

  /// Index into [kProjectionTypeSteps].
  final int typeStep;

  /// Whether the second edition is on the wall.
  final bool secondOn;

  /// The second edition's code, or `''` for "never chosen" — which is
  /// the state that seeds itself from Split View once and then stops
  /// following it.
  final String secondVersion;

  final ProjectionGround ground;

  ProjectionSetup copyWith({
    int? typeStep,
    bool? secondOn,
    String? secondVersion,
    ProjectionGround? ground,
  }) =>
      ProjectionSetup(
        typeStep: typeStep ?? this.typeStep,
        secondOn: secondOn ?? this.secondOn,
        secondVersion: secondVersion ?? this.secondVersion,
        ground: ground ?? this.ground,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'typeStep': typeStep,
        'secondOn': secondOn,
        'secondVersion': secondVersion,
        'ground': ground.name,
      };

  /// Every field is validated, because this comes off disk. A preset
  /// written by a build with a longer ladder must not index off the end
  /// of this one's.
  factory ProjectionSetup.fromJson(Map<String, dynamic> m) => ProjectionSetup(
        typeStep: m['typeStep'] is num
            ? (m['typeStep'] as num)
                .toInt()
                .clamp(0, kProjectionTypeSteps.length - 1)
            : kProjectionTypeDefaultStep,
        secondOn: m['secondOn'] is bool ? m['secondOn'] as bool : false,
        secondVersion:
            m['secondVersion'] is String ? m['secondVersion'] as String : '',
        ground: projectionGroundFromName(
            m['ground'] is String ? m['ground'] as String : null),
      );

  @override
  bool operator ==(Object other) =>
      other is ProjectionSetup &&
      other.typeStep == typeStep &&
      other.secondOn == secondOn &&
      other.secondVersion == secondVersion &&
      other.ground == ground;

  @override
  int get hashCode => Object.hash(typeStep, secondOn, secondVersion, ground);

  @override
  String toString() => 'ProjectionSetup(step $typeStep, second '
      '${secondOn ? secondVersion : "off"}, ${ground.name})';
}

/// A named setup — "morning service", "youth", "两个译本".
@immutable
class ProjectionPreset {
  const ProjectionPreset({required this.name, required this.setup});

  final String name;
  final ProjectionSetup setup;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        ...setup.toJson(),
      };

  /// Null when [raw] is not a preset this build can use.
  ///
  /// Returning null rather than throwing is what lets one corrupt entry
  /// cost the operator one preset instead of all of them — see
  /// [decodeProjectionPresets].
  static ProjectionPreset? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = raw.cast<String, dynamic>();
    final name = m['name'];
    if (name is! String) return null;
    final trimmed = normalizeProjectionPresetName(name);
    if (trimmed.isEmpty) return null;
    return ProjectionPreset(name: trimmed, setup: ProjectionSetup.fromJson(m));
  }

  @override
  bool operator ==(Object other) =>
      other is ProjectionPreset && other.name == name && other.setup == setup;

  @override
  int get hashCode => Object.hash(name, setup);

  @override
  String toString() => 'ProjectionPreset($name, $setup)';
}

/// How many presets one operator may keep.
///
/// A cap rather than none, because these live in SharedPreferences as
/// one JSON string and a list nobody bounds is a string nobody bounds.
/// Twelve is more services than a week has and still fits the strip.
const int kProjectionPresetLimit = 12;

/// The longest a preset name may be.
///
/// It is read off a wall from the back of a hall, so a name that does
/// not fit the chip is a name the operator cannot use to tell two
/// presets apart.
const int kProjectionPresetNameLimit = 24;

String normalizeProjectionPresetName(String raw) {
  final trimmed = raw.trim();
  return trimmed.length <= kProjectionPresetNameLimit
      ? trimmed
      : trimmed.substring(0, kProjectionPresetNameLimit).trim();
}

String encodeProjectionPresets(List<ProjectionPreset> presets) =>
    jsonEncode(<Map<String, dynamic>>[for (final p in presets) p.toJson()]);

/// The presets in [raw], skipping anything unusable.
///
/// A corrupt or absent value is an empty list, never an exception: the
/// projection page is opened in front of a congregation, and a decode
/// that throws there would take the wall down over a preference.
List<ProjectionPreset> decodeProjectionPresets(String? raw) {
  if (raw == null || raw.isEmpty) return const <ProjectionPreset>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <ProjectionPreset>[];
    final out = <ProjectionPreset>[];
    for (final entry in decoded) {
      final preset = ProjectionPreset.fromJson(entry);
      if (preset != null) out.add(preset);
      if (out.length >= kProjectionPresetLimit) break;
    }
    return out;
  } catch (_) {
    return const <ProjectionPreset>[];
  }
}

/// [presets] with [preset] saved into it.
///
/// Saving under a name that already exists REPLACES it, because that is
/// what an operator means by saving "morning service" again — the
/// alternative is two chips with the same label and no way to tell
/// which is this week's. Past the limit the OLDEST is dropped, so the
/// save always succeeds; a control that silently refuses in front of a
/// congregation is worse than one that quietly forgets last year's.
List<ProjectionPreset> upsertProjectionPreset(
  List<ProjectionPreset> presets,
  ProjectionPreset preset,
) {
  final out = <ProjectionPreset>[
    for (final p in presets)
      if (p.name.toLowerCase() != preset.name.toLowerCase()) p,
    preset,
  ];
  while (out.length > kProjectionPresetLimit) {
    out.removeAt(0);
  }
  return out;
}

List<ProjectionPreset> removeProjectionPreset(
  List<ProjectionPreset> presets,
  String name,
) =>
    <ProjectionPreset>[
      for (final p in presets)
        if (p.name.toLowerCase() != name.toLowerCase()) p,
    ];
