/// 2026-08-07 (SeekSparks): the iPad command-line wipe.
///
/// Tapping an operator chip on iPad set the text, and then the next
/// keystroke emptied the field. The cause was not the text: it was that
/// `controller.text = x` and `controller.selection = y` are two separate
/// publications, and the first one carries `offset: -1`. iOS drives its
/// text input asynchronously, so it can latch that caret-less state and
/// echo it back after the framework has already set the caret — and a
/// keystroke against a selection that does not describe the text takes
/// the whole line.
///
/// The symptom is iOS-only and cannot be reproduced here. The *cause*
/// can: these assert that no intermediate value with an invalid
/// selection is ever published, on any platform, which is the property
/// the fix actually establishes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/providers/workbench_provider.dart';
import 'package:seeksparks/utils/atomic_text_edit.dart';
import 'package:seeksparks/widgets/command_pane.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('setTextAtomic', () {
    test('the premise: assigning .text publishes an invalid selection', () {
      // Not testing our code — testing the Flutter behaviour the fix
      // exists because of. If this ever stops being true, the two-step
      // pattern stops being dangerous and this whole file can go.
      final c = TextEditingController(text: 'grace');
      addTearDown(c.dispose);
      c.text = 'grace AND peace';
      expect(c.selection.baseOffset, -1,
          reason: 'controller.text = … leaves the caret undefined');
    });

    test('publishes once, with the caret at the end by default', () {
      final c = TextEditingController(text: 'grace');
      addTearDown(c.dispose);
      final seen = <TextEditingValue>[];
      c.addListener(() => seen.add(c.value));

      c.setTextAtomic('grace AND peace');

      expect(seen.length, 1, reason: 'two publications is the bug');
      expect(c.text, 'grace AND peace');
      expect(c.selection, const TextSelection.collapsed(offset: 15));
    });

    test('honours an explicit caret', () {
      final c = TextEditingController();
      addTearDown(c.dispose);
      c.setTextAtomic('.paul silas', caret: 6);
      expect(c.selection, const TextSelection.collapsed(offset: 6));
    });

    test('clamps a caret that falls outside the new text', () {
      // The invariant the helper exists to hold: an out-of-range
      // selection must be unrepresentable, because that is precisely
      // what iOS mishandles.
      final c = TextEditingController();
      addTearDown(c.dispose);
      c.setTextAtomic('abc', caret: 99);
      expect(c.selection, const TextSelection.collapsed(offset: 3));
      c.setTextAtomic('abc', caret: -4);
      expect(c.selection, const TextSelection.collapsed(offset: 0));
    });

    test('empty text is still a valid, in-range caret', () {
      // ↓ past the newest history entry clears the line. `offset: -1`
      // here would arm the same trap with nothing visible on screen.
      final c = TextEditingController(text: 'was here');
      addTearDown(c.dispose);
      c.setTextAtomic('');
      expect(c.text, '');
      expect(c.selection, const TextSelection.collapsed(offset: 0));
    });

    test('clears any composing range left over from the old text', () {
      // The command line is an IME surface for this app's Chinese
      // readers; a composing range measured against the previous text
      // can point past the end of the replacement.
      final c = TextEditingController();
      addTearDown(c.dispose);
      c.value = const TextEditingValue(
        text: 'zhonghuawenzi',
        selection: TextSelection.collapsed(offset: 13),
        composing: TextRange(start: 0, end: 13),
      );
      c.setTextAtomic('.en');
      expect(c.value.composing, TextRange.empty);
    });
  });

  group('command line chips', () {
    Future<TextEditingController> pump(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(500, 900);
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final mp = MainProvider()
        ..setVerses(const [
          Verse(book: 'John', chapter: 3, verse: 16, text: 'For God so loved.'),
        ])
        ..currentVersion = 'kjv';
      final wb = WorkbenchProvider(mainProvider: mp);
      addTearDown(wb.dispose);
      final settings = AppSettings();
      await settings.setLocale('en');
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: mp),
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: wb),
          ],
          child: Builder(builder: (context) {
            return MaterialApp(
              theme: workbenchTheme(Theme.of(context)),
              home: const Scaffold(body: CommandPane()),
            );
          }),
        ),
      );
      // Drains AppSettings' post-setLocale timer before the listener
      // goes on, so the only publication counted is the chip's.
      await tester.pump(const Duration(seconds: 1));
      return tester
          .widget<TextField>(find.byType(TextField).first)
          .controller!;
    }

    testWidgets('inserting an operator never publishes a caret-less value',
        (tester) async {
      final c = await pump(tester);
      await tester.enterText(find.byType(TextField).first, 'grace');
      await tester.pump();

      final seen = <TextEditingValue>[];
      c.addListener(() => seen.add(c.value));

      await tester.tap(find.text('NEAR5'));
      await tester.pump();

      expect(c.text, 'grace NEAR5 ');
      expect(c.selection, const TextSelection.collapsed(offset: 12));
      expect(seen.length, 1);
      for (final v in seen) {
        expect(v.selection.baseOffset, greaterThanOrEqualTo(0),
            reason: 'an intermediate value with no caret is the iOS trap');
        expect(v.selection.extentOffset, lessThanOrEqualTo(v.text.length));
      }
    });

    testWidgets('the control-character chip is a single publication too',
        (tester) async {
      final c = await pump(tester);
      await tester.enterText(find.byType(TextField).first, 'paul silas');
      await tester.pump();

      final seen = <TextEditingValue>[];
      c.addListener(() => seen.add(c.value));

      await tester.tap(find.text('.'));
      await tester.pump();

      expect(c.text, '.paul silas');
      expect(c.selection, const TextSelection.collapsed(offset: 11));
      expect(seen.length, 1);
      expect(seen.single.selection.baseOffset, greaterThanOrEqualTo(0));
    });

    testWidgets('swapping the control character keeps one publication',
        (tester) async {
      // `.` then `/` re-asks the same question as an OR search. The
      // second tap rewrites the line rather than appending, so it is the
      // path most likely to leave the caret describing the old text.
      final c = await pump(tester);
      await tester.enterText(find.byType(TextField).first, '.paul silas');
      await tester.pump();

      final seen = <TextEditingValue>[];
      c.addListener(() => seen.add(c.value));

      await tester.tap(find.text('/'));
      await tester.pump();

      expect(c.text, '/paul silas');
      expect(c.selection, const TextSelection.collapsed(offset: 11));
      expect(seen.length, 1);
    });
  });
}
