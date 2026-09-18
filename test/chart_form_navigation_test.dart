/// Moving between the two chronology forms, and naming what is on the
/// depth view.
///
/// Both of these are about a control contradicting itself, which is the
/// kind of defect that never shows up in a screenshot.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yahwehs_sword/utils/wheel_stack_layout.dart'
    show stackLabelBudget;
import 'package:yahwehs_sword/widgets/wheel_chrome_bar.dart' show chartFormRoute;

void main() {
  group('the page moves the way the toggle does', () {
    // 2026-09-16 「轮子和strip toggle的时候左右移动应该根据这两个位置决定
    // 现在都是右边往左边看起来很奇怪」. The toggle puts the wheel on the
    // left segment and the strip on the right; a stock MaterialPageRoute
    // slides in from the right whichever segment you pressed, so
    // pressing LEFT and watching the page arrive from the right is the
    // control disagreeing with itself.
    Future<double> arrivalEdge(WidgetTester tester,
        {required bool toRight}) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(chartFormRoute<void>(
                toRight: toRight,
                builder: (_) => const Scaffold(body: Text('arriving')),
              )),
              child: const Text('go'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      // Part-way through, so the page is still off to one side.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final edge = tester.getTopLeft(find.text('arriving')).dx;
      await tester.pumpAndSettle();
      return edge;
    }

    testWidgets('rightward along the control arrives from the right',
        (tester) async {
      final at = await arrivalEdge(tester, toRight: true);
      final settled = tester.getTopLeft(find.text('arriving')).dx;
      expect(at, greaterThan(settled + 20),
          reason: 'the page did not come in from the right');
    });

    testWidgets('leftward along the control arrives from the left',
        (tester) async {
      final at = await arrivalEdge(tester, toRight: false);
      final settled = tester.getTopLeft(find.text('arriving')).dx;
      expect(at, lessThan(settled - 20),
          reason: 'pressing the left segment still brought the page in '
              'from the right, which is the complaint');
    });
  });

  test('the depth view may name more faces once it is zoomed in', () {
    // 2026-09-16 「这些放得了放得下的都应该放 这种zoom in后面又有足够位置
    // 就应该把文字放在后面」 and 「很多这些地方可以加进去的都没有加」.
    //
    // Sixty was chosen at the resting zoom, where the whole chart is on
    // screen. Zoomed in, the painter has already thrown away everything
    // outside the viewport before it counts, so the same sixty was
    // capping a much smaller set and leaving faces with plenty of room
    // unnamed.
    expect(stackLabelBudget(1, 1), 60);
    expect(stackLabelBudget(2, 1), 120);
    expect(stackLabelBudget(4, 1), 240);
    expect(stackLabelBudget(40, 1), 240,
        reason: 'the budget has to stop somewhere — every admitted name '
            'is a shaped paragraph in the frame');
    expect(stackLabelBudget(.5, 1), 60,
        reason: 'zoomed OUT there is less room, not less need for a '
            'floor; the geometric test already rejects what cannot fit');
    // A scene that has not been laid out yet must not produce a
    // nonsense budget.
    expect(stackLabelBudget(double.nan, 1), 60);
    expect(stackLabelBudget(2, 0), 60);
  });
}
