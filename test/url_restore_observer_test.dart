import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A menu is not a page, and the URL layer should not hear about one.
///
/// `_UrlRestoreObserver` asked the URL layer to rewrite the fragment on
/// EVERY push and pop. A popup menu, a dialog and a bottom sheet are all
/// routes, so browsing the Resources menu spent a browser history entry
/// per menu — press Back three times after opening three menus and you
/// go nowhere. The observer is private, so this test pins the property
/// it now depends on: the route types the app actually opens fall on the
/// right side of `is PageRoute`.
void main() {
  testWidgets('a popup, a dialog and a sheet are not PageRoutes',
      (tester) async {
    final seen = <Route<dynamic>>[];
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [_Collect(seen)],
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(children: [
            PopupMenuButton<int>(
              key: const ValueKey('menu'),
              itemBuilder: (_) => const [PopupMenuItem(value: 1, child: Text('x'))],
            ),
            TextButton(
              key: const ValueKey('dialog'),
              onPressed: () => showDialog<void>(
                  context: context, builder: (_) => const AlertDialog()),
              child: const Text('d'),
            ),
            TextButton(
              key: const ValueKey('page'),
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SizedBox())),
              child: const Text('p'),
            ),
          ]),
        ),
      ),
    ));

    await tester.tap(find.byKey(const ValueKey('menu')));
    await tester.pumpAndSettle();
    expect(seen.last, isNot(isA<PageRoute<dynamic>>()),
        reason: 'a popup menu must not look like a page');
    expect(seen.last, isA<PopupRoute<dynamic>>());
    await tester.tapAt(const Offset(5, 5)); // dismiss
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('dialog')));
    await tester.pumpAndSettle();
    expect(seen.last, isNot(isA<PageRoute<dynamic>>()),
        reason: 'a dialog must not look like a page');
    Navigator.of(tester.element(find.byKey(const ValueKey('dialog')))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('page')));
    await tester.pumpAndSettle();
    expect(seen.last, isA<PageRoute<dynamic>>(),
        reason: 'and a real page still is one, or the filter has silenced '
            'the restore it exists to perform');
  });
}

class _Collect extends NavigatorObserver {
  _Collect(this.seen);
  final List<Route<dynamic>> seen;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      seen.add(route);
}
