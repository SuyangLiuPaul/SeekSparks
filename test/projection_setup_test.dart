/// The projection's SETUP, without a widget: the grounds, and the
/// presets that name a bundle of them.
///
/// Two very different jobs in one file because they are one value
/// object apart. The first half is the only instrument in the repo that
/// can enforce the rule `projection_stage.dart`'s library doc states —
/// a projector adds light, so every ground has to be dark and blanking
/// has to land on the same one. That rule is prose, and prose does not
/// fail a build: a light ground would render perfectly, pass every
/// behavioural assertion, and be discovered by a congregation.
///
/// The second half is the codec, and it is tested at this level for the
/// reason `projection_cursor_test.dart` gives about the movement
/// arithmetic: a preset off disk can be anything — written by a later
/// build, hand-edited, half-truncated — and describing those cases to a
/// pumped widget costs ten lines each and to a pure function costs one.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/projection_setup.dart';
import 'package:seeksparks/constants/workbench_theme.dart' show WbColors;

/// WCAG's contrast ratio, the same formula `palette_legibility_walk_test`
/// uses one surface along.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  _layoutPersistenceTests();

  group('every ground is a dark ground', () {
    test('no ground paints a colour brighter than the ceiling', () {
      // THE rule. A projector cannot make a wall darker than the room
      // already is, so a light ground washes the room out — and, worse,
      // makes the blank key a flash across the whole wall instead of a
      // shutter. `kProjectionGroundMaxLuminance` is where "dark" stops
      // being a matter of taste.
      final tooBright = <String>[];
      for (final ground in ProjectionGround.values) {
        for (final colour in projectionGroundPaintFor(ground).stops) {
          final l = colour.computeLuminance();
          if (l > kProjectionGroundMaxLuminance) {
            tooBright.add('${ground.name}: '
                '#${colour.toARGB32().toRadixString(16)} at luminance '
                '${l.toStringAsFixed(4)}');
          }
        }
      }
      expect(tooBright, isEmpty,
          reason: 'a projector ADDS light. Every ground it offers has to '
              'be one the machine is nearly off for, or the blank key '
              'stops being honest — see projection_setup.dart:\n'
              '${tooBright.join('\n')}');
    });

    test('scripture keeps its contrast against the brightest of them', () {
      // The other half: dark is not enough on its own, because a
      // gradient could be dark AND close to the text colour. Measured
      // against every stop, so the answer is about the brightest pixel
      // the ground actually paints rather than a representative one.
      final wb = WbColors.dark;
      final thin = <String>[];
      for (final ground in ProjectionGround.values) {
        for (final colour in projectionGroundPaintFor(ground).stops) {
          final scripture = _contrast(wb.text, colour);
          if (scripture < kProjectionGroundMinContrast) {
            thin.add('${ground.name}: scripture at '
                '${scripture.toStringAsFixed(2)}:1');
          }
          // The corner reference is `mutedText` and is the one thing the
          // room uses to find the place in its own Bible. WCAG's 4.5 is
          // the floor for it rather than the 7.0 above, because it is
          // apparatus rather than the text.
          final reference = _contrast(wb.mutedText, colour);
          if (reference < 4.5) {
            thin.add('${ground.name}: the reference at '
                '${reference.toStringAsFixed(2)}:1');
          }
        }
      }
      expect(thin, isEmpty,
          reason: 'the back row is forty feet away and cannot lean in:\n'
              '${thin.join('\n')}');
    });

    test('the default ground is the one the projection already had', () {
      // `deep` repeats `WbColors.dark.groundBg` as a literal so that
      // `projection_setup.dart` does not have to import the theme (which
      // imports AppSettings, which imports it back). This is the guard
      // that makes the duplication safe.
      expect(projectionGroundPaintFor(ProjectionGround.deep).base,
          WbColors.dark.groundBg,
          reason: 'the default must be pixel-identical to the ground the '
              'projection shipped with, or every existing operator gets '
              'a new wall they did not ask for');
      expect(kProjectionGroundDefault, ProjectionGround.deep);
    });

    test('black is actually black, because that is what "off" is', () {
      expect(projectionGroundPaintFor(ProjectionGround.black).base,
          const Color(0xFF000000),
          reason: 'on an LED wall a black pixel is an OFF pixel, which no '
              'near-black can be');
    });

    test('a flat ground is flat and only the gradient is a gradient', () {
      // The distinction is load-bearing rather than cosmetic: a flat
      // ground is drawn with a `ColoredBox` of exactly this colour, and
      // a one-colour `LinearGradient` would paint the same and quietly
      // change what the blank-state test is looking at.
      for (final ground in ProjectionGround.values) {
        final paint = projectionGroundPaintFor(ground);
        expect(paint.stops, isNotEmpty);
        expect(paint.isFlat, paint.stops.length == 1);
        expect(paint.gradient == null, paint.isFlat);
      }
      expect(projectionGroundPaintFor(ProjectionGround.vignette).isFlat,
          isFalse);
      // The Scaffold paints `base` in the frame between a resize and the
      // stage's repaint, so for a gradient it has to be the darkest
      // stop — a sliver brighter than the wall would read as a seam.
      final vignette = projectionGroundPaintFor(ProjectionGround.vignette);
      for (final stop in vignette.stops) {
        expect(vignette.base.computeLuminance(),
            lessThanOrEqualTo(stop.computeLuminance()));
      }
    });

    test('every ground has a paint, so the picker cannot list a hole', () {
      for (final ground in ProjectionGround.values) {
        expect(projectionGroundPaints[ground], isNotNull,
            reason: '${ground.name} is offered and cannot be painted');
      }
    });
  });

  group('a stored ground name', () {
    test('round-trips', () {
      for (final ground in ProjectionGround.values) {
        expect(projectionGroundFromName(ground.name), ground);
      }
    });

    test('falls back to the default when this build has no such ground', () {
      // The name is stored, not the index, so a ground added or removed
      // later cannot silently reinterpret a saved preference — it can
      // only fail to recognise it, which lands here.
      expect(projectionGroundFromName('aurora'), kProjectionGroundDefault);
      expect(projectionGroundFromName(''), kProjectionGroundDefault);
      expect(projectionGroundFromName(null), kProjectionGroundDefault);
    });
  });

  group('presets', () {
    const setup = ProjectionSetup(
      typeStep: 7,
      secondOn: true,
      secondVersion: 'kjv',
      ground: ProjectionGround.black,
    );

    test('survive the trip through SharedPreferences unchanged', () {
      const preset = ProjectionPreset(name: 'morning service', setup: setup);
      final back = decodeProjectionPresets(encodeProjectionPresets([preset]));
      expect(back, [preset]);
      expect(back.single.setup, setup);
    });

    test('a type step from a longer ladder is clamped, not indexed', () {
      // The failure this prevents is a RangeError inside `build` in
      // front of a congregation: `kProjectionTypeSteps[step]` with a
      // step a later build wrote.
      final wild = jsonEncode([
        {'name': 'from the future', 'typeStep': 99, 'ground': 'deep'}
      ]);
      final back = decodeProjectionPresets(wild);
      expect(back.single.setup.typeStep, kProjectionTypeSteps.length - 1);
    });

    test('an unknown ground name degrades to the default', () {
      final wild = jsonEncode([
        {'name': 'x', 'typeStep': 2, 'ground': 'sunset'}
      ]);
      expect(_only(wild).setup.ground, kProjectionGroundDefault);
    });

    test('a corrupt or empty store is an empty list, never an exception', () {
      // This is read on the way into a page that is opened in front of a
      // room. A decode that threw would take the wall down over a
      // preference.
      expect(decodeProjectionPresets(null), isEmpty);
      expect(decodeProjectionPresets(''), isEmpty);
      expect(decodeProjectionPresets('{not json'), isEmpty);
      expect(decodeProjectionPresets('{"a":1}'), isEmpty,
          reason: 'a JSON object where a list was written is corrupt too');
    });

    test('one bad entry costs one preset, not all of them', () {
      final mixed = jsonEncode([
        {'name': 'good', 'typeStep': 3, 'ground': 'black'},
        {'typeStep': 3},
        'nonsense',
        {'name': '   ', 'typeStep': 1},
      ]);
      final back = decodeProjectionPresets(mixed);
      expect(back.map((p) => p.name), ['good']);
    });

    test('saving under a name that exists replaces it', () {
      const first = ProjectionPreset(name: 'morning', setup: setup);
      final second = ProjectionPreset(
          name: 'Morning', setup: setup.copyWith(typeStep: 1));
      final out = upsertProjectionPreset([first], second);
      expect(out.length, 1,
          reason: 'two chips with the same label are two controls the '
              'operator cannot tell apart');
      expect(out.single.setup.typeStep, 1);
    });

    test('the list is capped, and the save still succeeds', () {
      var list = const <ProjectionPreset>[];
      for (var i = 0; i < kProjectionPresetLimit + 3; i++) {
        list = upsertProjectionPreset(
            list, ProjectionPreset(name: 'p$i', setup: setup));
      }
      expect(list.length, kProjectionPresetLimit);
      expect(list.last.name, 'p${kProjectionPresetLimit + 2}',
          reason: 'the newest is what the operator just pressed save on');
      expect(list.first.name, 'p3', reason: 'the oldest is what gives way');
    });

    test('a name is trimmed and bounded', () {
      expect(normalizeProjectionPresetName('  morning  '), 'morning');
      expect(
          normalizeProjectionPresetName('x' * (kProjectionPresetNameLimit + 9))
              .length,
          kProjectionPresetNameLimit);
    });

    test('removing one leaves the rest', () {
      final list = <ProjectionPreset>[
        const ProjectionPreset(name: 'a', setup: setup),
        const ProjectionPreset(name: 'b', setup: setup),
      ];
      expect(removeProjectionPreset(list, 'A').map((p) => p.name), ['b']);
    });
  });
}

/// The single preset a one-entry store decodes to.
ProjectionPreset _only(String raw) => decodeProjectionPresets(raw).single;

/// The layout as a saved value — 2026-09-13.
///
/// A preset that forgets the layout is a preset that does not restore
/// what the operator set, which is the same argument `ProjectionSetup`
/// itself was written for.
void _layoutPersistenceTests() {
  group('the layout survives a round trip', () {
    test('a preset carries it', () {
      const setup = ProjectionSetup(
        typeStep: 3,
        secondOn: true,
        secondVersion: 'bsb',
        ground: ProjectionGround.black,
        layout: ProjectionLayout.devotional,
      );
      final back = ProjectionSetup.fromJson(
          jsonDecode(jsonEncode(setup.toJson())) as Map<String, dynamic>);
      expect(back, setup);
      expect(back.layout.isDevotional, isTrue);
    });

    test('a preset written before the setting existed means the shipped wall',
        () {
      final back = ProjectionSetup.fromJson(<String, dynamic>{
        'typeStep': 2,
        'secondOn': false,
        'secondVersion': '',
        'ground': 'deep',
      });
      expect(back.layout, ProjectionLayout.standard);
      expect(back.layout.numbers, isTrue);
      expect(back.layout.reference, ProjectionReferencePlace.corner);
    });

    test('a corrupt layout is the shipped wall, not a crash', () {
      for (final junk in <Object?>[
        null,
        'devotional',
        42,
        <String, dynamic>{'flow': 'sideways', 'reference': 'ceiling'},
      ]) {
        expect(ProjectionLayout.fromJson(junk), ProjectionLayout.standard,
            reason: '$junk');
      }
    });

    test('the two named layouts are not the same wall', () {
      expect(ProjectionLayout.standard, isNot(ProjectionLayout.devotional));
      expect(ProjectionLayout.standard.isDevotional, isFalse);
      expect(ProjectionLayout.devotional.isDevotional, isTrue);
      // isDevotional asks about the three fields the word means, and
      // says nothing about alignment — a devotional card set from the
      // margin is still a devotional card.
      expect(
          ProjectionLayout.devotional
              .copyWith(align: ProjectionAlign.start)
              .isDevotional,
          isTrue);
    });
  });
}
