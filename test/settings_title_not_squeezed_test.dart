// A settings row's title must not be crushed by its own trailing widget.
//
// 2026-09-14, photographed off a phone: 「为什么手机这样子」. The
// Cross-version search row read
//
//     Cr
//     os
//     s-
//     ver
//     sio
//     n
//
// one or two characters a line, all the way down the screen, with the
// right two thirds of the row empty.
//
// A ListTile lays out `leading`, then `trailing`, then gives the title
// and subtitle what is left. A DropdownButton asks for the width of its
// WIDEST item — 「同語言，全部版本」 / "Every edition of the same
// language" — so on a 390 px phone it took essentially the whole row and
// the title got about one character. Nothing overflowed and nothing was
// clipped: the layout SUCCEEDED, by wrapping the title to twenty lines.
// That is why no existing overflow test saw it.
//
// The fix is to stop putting a width-hungry control in `trailing:` and
// put it under the subtitle at full width. The test below is deliberately
// not "does the fix's widget tree look right" — it measures the title's
// box at phone widths, so ANY future control parked in `trailing:` fails
// here whether or not it is a dropdown.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The widths that matter: an iPhone SE, a current phone, and the
/// narrowest thing this app claims to render.
const _phoneWidths = <double>[320, 375, 390];

/// A ListTile shaped exactly like the two that were wrong: a long title,
/// a subtitle, and a trailing control whose intrinsic width is large.
const _items = [
  'Every edition of the same language',
  'The open editions only',
  'Off',
];

DropdownButton<String> _dropdown({required bool expanded}) =>
    DropdownButton<String>(
      isExpanded: expanded,
      value: _items.first,
      underline: const SizedBox.shrink(),
      onChanged: (_) {},
      items: [
        for (final i in _items) DropdownMenuItem(value: i, child: Text(i)),
      ],
    );

Widget _tile({required bool trailingDropdown}) {
  final dropdown = _dropdown(expanded: !trailingDropdown);
  return ListTile(
    isThreeLine: !trailingDropdown,
    title: const Text('Cross-version search',
        style: TextStyle(fontWeight: FontWeight.w600)),
    subtitle: trailingDropdown
        ? const Text('Runs the same query against several editions.')
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Runs the same query against several editions.'),
              dropdown,
            ],
          ),
    trailing: trailingDropdown ? dropdown : null,
  );
}

Future<double> _titleWidth(WidgetTester tester, double width,
    {required bool trailingDropdown}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: width,
        child: _tile(trailingDropdown: trailingDropdown),
      ),
    ),
  ));
  return tester.getSize(find.text('Cross-version search')).width;
}

void main() {
  group('the title keeps the row', () {
    for (final w in _phoneWidths) {
      testWidgets('at ${w.toInt()} px the title has room to be read',
          (tester) async {
        final got = await _titleWidth(tester, w, trailingDropdown: false);
        // Half the row is a floor, not a target. The real assertion is
        // that it is nowhere near one character: at 390 px the broken
        // layout gave the title about 24 px.
        expect(got, greaterThan(w / 2),
            reason: 'the title got ${got.toStringAsFixed(0)} px of $w — '
                'something in this row is taking the width the title '
                'needs. Check for a control in `trailing:`.');
      });
    }

    testWidgets('the reason the rule exists: this dropdown wants more '
        'width than a phone row has', (tester) async {
      // The guard for the guards above. They measure the FIXED layout,
      // so if ListTile ever started giving the title priority they would
      // pass no matter what anyone parked in trailing, and the rule
      // would be enforced by nothing.
      //
      // Rather than render the broken tile — which in a debug build
      // trips ListTile's own "Trailing widget consumes the entire tile
      // width" assertion and leaves an unlaid-out tree behind — this
      // measures the cause directly: an unconstrained DropdownButton
      // takes the width of its WIDEST item. That is the whole mechanism.
      // In release, with assertions off, the layout carried on and gave
      // the title about 24 px of 390, which is the photograph at the top
      // of this file.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: _dropdown(expanded: false),
          ),
        ),
      ));
      final wants = tester.getSize(find.byType(DropdownButton<String>)).width;
      expect(wants, greaterThan(390 / 2),
          reason: 'a DropdownButton of these items wants only '
              '${wants.toStringAsFixed(0)} px — either the items got much '
              'shorter or Flutter stopped sizing to the widest one, and '
              'this whole rule can be re-examined');
    });
  });

  testWidgets('the title is one line at every phone width, not a column '
      'of letters', (tester) async {
    // The symptom as the reader met it. A title that fits reads on one
    // line; the broken one was twenty.
    for (final w in _phoneWidths) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: w,
            child: _tile(trailingDropdown: false),
          ),
        ),
      ));
      final title = find.text('Cross-version search');
      final size = tester.getSize(title);
      // One line's height, measured on the same widget in the same
      // theme: lay the identical tile out in a box wide enough that it
      // cannot wrap, and take the title's height there. Reconstructing
      // the style by hand gets the default font size rather than the
      // one ListTile merges in, which is how this test first told
      // itself the title was three lines when it was one.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            child: _tile(trailingDropdown: false),
          ),
        ),
      ));
      final oneLine = tester.getSize(title).height;
      expect(size.height, lessThan(oneLine * 2.5),
          reason: 'at $w px the title is ${(size.height / oneLine).round()} '
              'lines tall and ${size.width.toStringAsFixed(0)} px wide');
    }
  });
}
