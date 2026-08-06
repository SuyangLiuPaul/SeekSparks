import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/utils/verse_list.dart';
import 'package:seeksparks/widgets/verse_list_pane.dart';

const _john316 = VerseRef('John', 3, 16);
const _rom828 = VerseRef('Romans', 8, 28);

final _verseByRef = <String, Verse>{
  'John-3-16': const Verse(
      book: 'John', chapter: 3, verse: 16, text: 'For God so loved the world'),
  'John-3-17': const Verse(
      book: 'John', chapter: 3, verse: 17, text: 'For God sent not his Son'),
  'Romans-8-28': const Verse(
      book: 'Romans',
      chapter: 8,
      verse: 28,
      text: 'And we know that all things work together for good'),
};

Widget _host(Widget child, {double width = 360}) => ChangeNotifierProvider(
      create: (_) => AppSettings(),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: width, height: 700, child: child),
          ),
        ),
      ),
    );

VerseListPane _pane({
  VerseRef? currentRef = _john316,
  List<VerseRef> searchResults = const [],
  bool searchLimitActive = false,
  void Function(VerseRef)? onOpenRef,
  void Function(VerseList?)? onSetSearchLimit,
}) =>
    VerseListPane(
      locale: 'en',
      version: 'KJV',
      verseByRef: _verseByRef,
      currentRef: currentRef,
      searchResults: searchResults,
      searchLimitActive: searchLimitActive,
      onOpenRef: onOpenRef ?? (_) {},
      onSetSearchLimit: onSetSearchLimit ?? (_) {},
    );

/// Open one of the four toolbar popups and choose an item by its label.
Future<void> _menu(WidgetTester tester, IconData icon, String label) async {
  await tester.tap(find.byIcon(icon));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

const _importIcon = Icons.download_rounded;
const _editIcon = Icons.tune_rounded;
const _selectIcon = Icons.checklist_rounded;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('VerseListPane', () {
    testWidgets('starts empty and says how to fill itself', (tester) async {
      await tester.pumpWidget(_host(_pane()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Empty.'), findsOneWidget);
    });

    testWidgets('Import ▸ Current verse adds the reader\'s verse',
        (tester) async {
      await tester.pumpWidget(_host(_pane()));
      await tester.pumpAndSettle();

      await _menu(tester, _importIcon, 'Current verse');

      expect(find.text('John 3:16'), findsOneWidget);
      // The row prints the verse text, so the list is readable without
      // navigating away from it.
      expect(find.textContaining('For God so loved'), findsOneWidget);
    });

    testWidgets('typing a range adds every verse in it', (tester) async {
      await tester.pumpWidget(_host(_pane()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'John 3:16-17');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('John 3:16'), findsOneWidget);
      expect(find.text('John 3:17'), findsOneWidget);
    });

    testWidgets('Import appends verbatim; Sort collapses the duplicates',
        (tester) async {
      await tester.pumpWidget(_host(_pane()));
      await tester.pumpAndSettle();

      await _menu(tester, _importIcon, 'Current verse');
      await _menu(tester, _importIcon, 'Current verse');
      // bwh27: import does not sort or dedupe, so the same verse twice
      // really is two rows.
      expect(find.text('John 3:16'), findsNWidgets(2));

      await _menu(tester, _editIcon, 'Sort list (removes duplicates)');
      expect(find.text('John 3:16'), findsOneWidget);
    });

    testWidgets('the active-list radio routes every action to one side',
        (tester) async {
      await tester.pumpWidget(_host(_pane()));
      await tester.pumpAndSettle();

      await _menu(tester, _importIcon, 'Current verse');
      expect(find.text('John 3:16'), findsOneWidget);

      await tester.tap(find.text('Secondary'));
      await tester.pumpAndSettle();
      // Switching lists must not carry the rows across.
      expect(find.text('John 3:16'), findsNothing);
      expect(find.textContaining('Empty.'), findsOneWidget);

      await tester.tap(find.text('Main'));
      await tester.pumpAndSettle();
      expect(find.text('John 3:16'), findsOneWidget);
    });

    testWidgets('Select ▸ Not in Secondary then Delete leaves the overlap',
        (tester) async {
      await tester.pumpWidget(_host(
        _pane(searchResults: const [_john316, _rom828]),
      ));
      await tester.pumpAndSettle();

      // Main = {John 3:16, Romans 8:28}
      await _menu(tester, _importIcon, 'Search results (2)');
      // Secondary = {John 3:16}
      await tester.tap(find.text('Secondary'));
      await tester.pumpAndSettle();
      await _menu(tester, _importIcon, 'Current verse');

      await tester.tap(find.text('Main'));
      await tester.pumpAndSettle();
      await _menu(tester, _selectIcon, 'Not in Secondary');
      await _menu(tester, _editIcon, 'Delete selected');

      // Selection is a composable layer, not a filter: select-unique +
      // delete is set intersection.
      expect(find.text('John 3:16'), findsOneWidget);
      expect(find.text('Rom 8:28'), findsNothing);
    });

    testWidgets('the filter toggle hands the active list up as a search limit',
        (tester) async {
      VerseList? limit;
      var calls = 0;
      await tester.pumpWidget(_host(_pane(
        onSetSearchLimit: (l) {
          limit = l;
          calls++;
        },
      )));
      await tester.pumpAndSettle();

      // An empty list is not a usable limit — it would hide every hit.
      await tester.tap(find.byIcon(Icons.filter_alt_outlined));
      await tester.pumpAndSettle();
      expect(calls, 0);

      await _menu(tester, _importIcon, 'Current verse');
      await tester.tap(find.byIcon(Icons.filter_alt_outlined));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(verseListKeys(limit!), {'John-3-16'});
    });

    testWidgets('an active limit toggles back off', (tester) async {
      VerseList? limit = VerseList.empty;
      await tester.pumpWidget(_host(_pane(
        searchLimitActive: true,
        onSetSearchLimit: (l) => limit = l,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.filter_alt));
      await tester.pumpAndSettle();
      expect(limit, isNull);
    });

    testWidgets('tapping a row opens it in the reader', (tester) async {
      VerseRef? opened;
      await tester.pumpWidget(_host(_pane(onOpenRef: (r) => opened = r)));
      await tester.pumpAndSettle();

      await _menu(tester, _importIcon, 'Current verse');
      await tester.tap(find.text('John 3:16'));
      await tester.pumpAndSettle();
      expect(opened, _john316);
    });

    testWidgets('the workspace survives a rebuild', (tester) async {
      await tester.pumpWidget(_host(_pane()));
      await tester.pumpAndSettle();
      await _menu(tester, _importIcon, 'Current verse');

      // A fresh pane reads the same store — the list is not lost when
      // the user switches tabs.
      await tester.pumpWidget(_host(const SizedBox.shrink()));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_host(_pane()));
      await tester.pumpAndSettle();

      expect(find.text('John 3:16'), findsOneWidget);
    });

    testWidgets('renders without overflow at 320 and 560', (tester) async {
      for (final w in const [320.0, 560.0]) {
        await tester.pumpWidget(_host(
          _pane(searchResults: const [_john316, _rom828]),
          width: w,
        ));
        await tester.pumpAndSettle();
        await _menu(tester, _importIcon, 'Search results (2)');
        expect(tester.takeException(), isNull, reason: 'at $w px');
      }
    });
  });
}
