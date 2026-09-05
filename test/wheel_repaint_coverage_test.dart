/// EVERY PAINTER FIELD MUST BE NAMED IN `shouldRepaint`.
///
/// A source-level ratchet, in the same spirit as
/// `wheel_timeline_field_coverage_test.dart`, and for the same reason:
/// the failure mode is not a wrong comparison, it is a FORGOTTEN one,
/// and a forgotten comparison is silent.
///
/// Three fields were missing when this was written, and one of them was
/// a live bug. `rail` was absent, so toggling the genealogy layer
/// repainted nothing at all: that switch takes the rail from 107 marks
/// to 0 and shifts every arc's ring by one, while `streams`, `arcs`,
/// `spokes` and `lives` keep exactly the counts they had — so every
/// comparison returned equal and the reader pressed a checkbox and
/// watched the wheel not move. The other three layer switches happen to
/// change `lives.length`, which is precisely why they looked fine and
/// hid this one. `wb` and `colors` were missing too, latent rather than
/// live: a palette change with the page open would keep the old colours.
///
/// Reading the source rather than the behaviour is deliberate. Proving
/// a repaint DID happen needs a widget test per field and would still
/// only cover the fields someone thought to test; this cannot be
/// satisfied by thinking of a field, only by listing it.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final src =
      File('lib/pages/radial_chronology_page.dart').readAsStringSync();

  // The class body, from its declaration to the closing brace at column 0.
  final classStart = src.indexOf('class _WorldWheelPainter');
  final body = src.substring(classStart);

  final methodStart = body.indexOf('bool shouldRepaint(');
  final methodEnd = body.indexOf(';', methodStart);

  test('the painter and its repaint test are both still findable', () {
    expect(classStart, greaterThan(-1), reason: '_WorldWheelPainter moved');
    expect(methodStart, greaterThan(-1), reason: 'shouldRepaint moved');
    expect(methodEnd, greaterThan(methodStart));
  });

  test('every final field of the painter is compared', () {
    final method = body.substring(methodStart, methodEnd);
    // `final <Type> name;` declarations inside the class body, before
    // the method itself — the painter declares all of its fields above.
    final fields = RegExp(r'^  final [^;]+?(\w+);', multiLine: true)
        .allMatches(body.substring(0, methodStart))
        .map((m) => m.group(1)!)
        .toSet();

    expect(fields.length, greaterThan(8),
        reason: 'the field regex matched almost nothing — it has drifted '
            'from the declaration style, and would pass vacuously');

    final missing =
        fields.where((f) => !RegExp(r'\b' + f + r'\b').hasMatch(method));
    expect(missing, isEmpty,
        reason: 'not compared in shouldRepaint: ${missing.join(", ")} — a '
            'change to one of these repaints nothing, silently');
  });

  test('the genealogy rail specifically is compared', () {
    // Named on its own because it is the one that actually shipped
    // broken, and because it is the only layer whose toggle leaves
    // every other list length untouched.
    final method = body.substring(methodStart, methodEnd);
    expect(method.contains('rail'), isTrue,
        reason: 'toggling the genealogy layer will not repaint the wheel');
  });
}
