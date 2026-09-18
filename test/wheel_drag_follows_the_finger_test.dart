// Dragging the wheel turns it the way the hand went.
//
// 2026-09-15: 「我用鼠标旋转wheel都反了」 — and it was, on the horizontal
// axis.
//
// `_rotate` in `chronology_depth_view.dart` is the standard rotation
// matrix, and screen space has y DOWN, so a positive angle turns the
// wheel CLOCKWISE. Take a clock face and turn it clockwise: the point at
// six o'clock travels LEFT. Six o'clock is the near edge of a tilted
// wheel — the part under the reader's hand — so adding the drag's `dx`
// to the yaw sent the thing being dragged the opposite way to the drag.
//
// A DRAG AND A BUTTON ARE DIFFERENT METAPHORS, and that is the part
// worth pinning, because the obvious "fix" is to flip both and break the
// buttons. `Icons.rotate_right` promises *turn it clockwise*; a drag
// promises *what is under my finger follows my finger*. Those are
// opposite signs and both are correct.
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:yahwehs_sword/utils/chronology_depth_view.dart';
import 'package:yahwehs_sword/utils/wheel_stack_layout.dart';

/// Where a point on the wheel's rim lands on screen at a given yaw.
///
/// The test works on the PROJECTION rather than by dragging a widget,
/// because the claim is about geometry: it is the direction a visible
/// point moves, which is what the reader is complaining about, and it
/// stays true whatever the gesture plumbing looks like later.
Offset _rimAt({required double angle, required double yaw}) {
  final view = ChronologyDepthView(
    projection: const WheelStackProjection(squash: .7),
    groundRadius: 100,
    contentArea: const Rect.fromLTWH(0, 0, 400, 400),
    yaw: yaw,
  );
  return view.projectGround(
      Offset(math.cos(angle) * 100, math.sin(angle) * 100));
}

void main() {
  // Six o'clock in canvas angles: y is down, so π/2 is the NEAR edge —
  // the bottom of the wheel, closest to the reader, and the part a hand
  // naturally lands on.
  const near = math.pi / 2;

  test('a positive yaw turns the wheel clockwise, which moves the near '
      'edge LEFT', () {
    // The premise the bug rests on, asserted rather than remembered.
    final before = _rimAt(angle: near, yaw: 0);
    final after = _rimAt(angle: near, yaw: 0.2);
    expect(after.dx, lessThan(before.dx),
        reason: 'if a positive yaw now moves the near edge RIGHT, the '
            'sign convention changed and the drag handler has to change '
            'back with it');
  });

  test('so a drag to the right must DECREASE the yaw', () {
    // The rule the handler implements: the point under the hand ends up
    // further right than it started.
    const dragRight = 40.0;
    const perPixel = .009;

    final start = _rimAt(angle: near, yaw: 0);
    final wrong = _rimAt(angle: near, yaw: 0 + dragRight * perPixel);
    final right = _rimAt(angle: near, yaw: 0 - dragRight * perPixel);

    expect(right.dx, greaterThan(start.dx),
        reason: 'dragging right did not carry the near edge right');
    expect(wrong.dx, lessThan(start.dx),
        reason: 'this is the old behaviour, kept here so the test says '
            'what was wrong as well as what is right');
  });

  test('and a drag to the left carries it left', () {
    const perPixel = .009;
    final start = _rimAt(angle: near, yaw: 0);
    final dragged = _rimAt(angle: near, yaw: 0 + 40 * perPixel);
    expect(dragged.dx, lessThan(start.dx));
  });

  test('the handler in the source uses the sign this file argues for', () {
    // The geometry above is necessary and not sufficient: it proves
    // which sign is right, not that the widget uses it. Reading the one
    // line is cheap and it is the line that was wrong.
    final src = File('lib/widgets/stacked_chronology_wheel.dart')
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(src, contains('_yaw - event.delta.dx'),
        reason: 'the drag is back to adding dx, which turns the wheel '
            'against the hand');
  });

  test('the buttons keep the OTHER sign, and that is correct', () {
    // The trap: flipping the drag and the buttons together would fix
    // the complaint and break two controls that were always right.
    final src = File('lib/widgets/stacked_chronology_wheel.dart')
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(src, contains('_changeAngles(_yaw + math.pi / 12, _tilt)'),
        reason: 'rotate-right should still turn the wheel clockwise — a '
            'button says what it does, it is not a hand');
    expect(src, contains('_changeAngles(_yaw - math.pi / 12, _tilt)'),
        reason: 'and rotate-left anticlockwise');
  });
}
