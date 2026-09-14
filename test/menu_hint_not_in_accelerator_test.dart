// A menu's "why is this greyed out" reason belongs under the label, not
// in the accelerator column.
//
// 2026-09-14, photographed off an iPad — 「sword这个是什么」. The View
// menu's two disabled items read like this down the right-hand side:
//
//     Split (two editions side by side)        needs a
//                                               wider
//                                              centre
//     Highlight version differences         needs two
//                                            editions
//                                                 in
//                                                 one
//                                           language
//
// The row was `[check 16px, Text(label), SizedBox(24), Expanded(hint)]`
// with the label NOT flexible — so the label took its full intrinsic
// width, the Expanded got whatever was left, and a sentence in it wrapped
// to a column of words. The accelerator column is sized for `Ctrl+L`.
//
// Two changes, and this file holds both: a reason is a `hint` and renders
// on its own line under the label, and the label is `Flexible` so that a
// long one ellipsizes instead of starving whatever is beside it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/widgets/workbench_chrome.dart';

const _longLabel = 'Highlight version differences';
const _reason = 'needs two editions in one language';

Future<void> _openMenu(WidgetTester tester, WbMenu menu,
    {double width = 420}) async {
  await tester.pumpWidget(ChangeNotifierProvider<AppSettings>(
    create: (_) => AppSettings(),
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          child: WorkbenchMenuBar(menus: [menu]),
        ),
      ),
    ),
  ));
  await tester.tap(find.text(menu.title));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a reason reads across the menu instead of down its edge',
      (tester) async {
    await _openMenu(
      tester,
      WbMenu('View', [
        WbMenuItem(_longLabel, null, hint: _reason),
      ]),
    );

    final hint = find.text(_reason);
    expect(hint, findsOneWidget);
    final size = tester.getSize(hint);

    // The whole sentence on one line. Laid out in the accelerator column
    // it was five lines and about 70 px wide; the assertion is that it
    // is now wider than it is tall by a long way, which is what "a line
    // of text" means and what "a column of words" is not.
    expect(size.width, greaterThan(size.height * 6),
        reason: 'the reason is ${size.width.toStringAsFixed(0)} x '
            '${size.height.toStringAsFixed(0)} — it is wrapping');
  });

  testWidgets('the reason sits BELOW the label, not beside it',
      (tester) async {
    await _openMenu(
      tester,
      WbMenu('View', [
        WbMenuItem(_longLabel, null, hint: _reason),
      ]),
    );
    final label = tester.getRect(find.text(_longLabel));
    final hint = tester.getRect(find.text(_reason));
    expect(hint.top, greaterThanOrEqualTo(label.bottom - 1),
        reason: 'the reason is still on the label\'s row, which is the '
            'shape that produced the column of words');
    expect(hint.left, lessThan(label.left + 24),
        reason: 'a reason belongs under the words it explains, aligned '
            'with them — not pushed to the right edge');
  });

  testWidgets('an accelerator still goes in the accelerator column',
      (tester) async {
    // The other half: moving reasons out must not move `Ctrl+L` out too.
    await _openMenu(
      tester,
      WbMenu('Search', [
        WbMenuItem('Command line', () {}, shortcut: 'Ctrl+L'),
      ]),
    );
    final label = tester.getRect(find.text('Command line'));
    final key = tester.getRect(find.text('Ctrl+L'));
    expect(key.left, greaterThan(label.right),
        reason: 'the accelerator left its column');
    expect((key.center.dy - label.center.dy).abs(), lessThan(2),
        reason: 'the accelerator left its row');
  });

  testWidgets('a label too long for the menu ellipsizes instead of '
      'starving the column beside it', (tester) async {
    // The second defect, which the reason merely revealed. Without
    // `Flexible` the label takes its intrinsic width whatever the menu
    // has, and everything after it gets the remainder — which is how a
    // 34-character sentence ended up in a 70 px box.
    await _openMenu(
      tester,
      WbMenu('View', [
        WbMenuItem(
            'An implausibly long menu label that no real menu would use',
            () {},
            shortcut: 'Ctrl+L'),
      ]),
      width: 260,
    );
    final key = tester.getRect(find.text('Ctrl+L'));
    expect(key.width, greaterThan(30),
        reason: 'the accelerator was squeezed to ${key.width} px by the '
            'label beside it');
  });
}
