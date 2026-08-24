// 2026-08-25 (#315): the EIGHTH mechanism — a frozen control RANGE.
//
// The seven mechanisms this ticket has found so far all freeze a NUMBER:
// a literal, a deaf Material role, a saturating clamp, a correct size
// inside a `FittedBox`, a design constant wearing a principled name, a
// literal on the far side of a `?`, a theme built from constants. Every
// one of #315's three detectors scans for a text size that cannot move.
//
// This is the converse and none of them can see it. Every text size in
// the reader is wired perfectly and travels the full 12–40 pt. What was
// frozen is the reader's REACH over them: the `Aa` sheet — the control
// they are most likely to use, because it is inline and does not cost
// them their place — bounded itself at 32 with four literals inherited
// from the phone reader this app was forked from.
//
// Two consequences, and the second is the worse one:
//
//   * 8 of the font slider's 29 stops (33..40) were unreachable from
//     the reader at all.
//   * the sheet was a ONE-WAY TRAPDOOR. Decrease clamped INTO 32 while
//     increase was disabled AT 32, so a reader who set 40 pt in
//     Settings and tapped A− once here lost 8 pt in a single tap and
//     the sheet offered no way back.
//
// MEASURED AGAINST `f62cf73`, the commit before the repair, in a
// detached worktree with the pure-core group removed (that core is what
// this change adds, so it cannot be run there). 7 of the 8 remaining
// tests fail, and the numbers are the finding:
//
//   increase button at 32 pt ................ Expected: not null
//                                             Actual:   <null>
//   one decrease from 40 pt ................. Expected: <39.0>
//                                             Actual:   <32.0>
//   decrease then increase from 40 pt ....... Expected: > <32.0>
//                                             Actual:   <32.0>
//   the readout's own size at 40 pt ......... Expected: > <32.0>
//                                             Actual:   <32.0>
//   setFontSize(999) ........................ Actual:   <999.0>
//   restoring a stored 96 ................... Actual:   <96.0>
//   importing a blob saying 400 ............. Actual:   <400.0>
//
// The eighth — 'both ends still refuse to leave the range' — passes on
// both commits and is characterisation: the BOTTOM of the range was
// always right, which is part of why this survived nine passes of a
// ticket about text being too small.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/profile_service.dart';
import 'package:seeksparks/widgets/bible_reading_pane.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the stepper the sheet delegates to', () {
    test('walks from one end of the slider to the other', () {
      var size = kFontSizeMin;
      final visited = <double>{size};
      // 40 is generous: the slider has 29 stops, so a stepper that
      // needs more than 40 taps is stuck somewhere.
      for (var i = 0; i < 40 && size < kFontSizeMax; i++) {
        size = fontSizeAfterStep(size, 1);
        visited.add(size);
      }
      expect(size, kFontSizeMax);
      expect(visited.length, ((kFontSizeMax - kFontSizeMin) + 1).round());
    });

    test('is offered exactly at the stops where it can move', () {
      expect(canStepFontSize(kFontSizeMin, -1), isFalse);
      expect(canStepFontSize(kFontSizeMin, 1), isTrue);
      expect(canStepFontSize(kFontSizeMax, 1), isFalse);
      expect(canStepFontSize(kFontSizeMax, -1), isTrue);
      expect(canStepFontSize(kFontSizeDefault, 1), isTrue);
      expect(canStepFontSize(kFontSizeDefault, -1), isTrue);
    });

    test('never jumps — one tap moves one stop, at both ends', () {
      // The trapdoor was a clamp INTO a bound the other button could
      // not leave. A step that is offered must move by exactly its
      // delta; only a refused step may move by nothing.
      for (var s = kFontSizeMin; s <= kFontSizeMax; s += 1) {
        for (final delta in <double>[-1, 1]) {
          final after = fontSizeAfterStep(s, delta);
          expect(
            after == s || after == s + delta,
            isTrue,
            reason: 'from $s a step of $delta landed on $after',
          );
        }
      }
    });
  });

  group('the Aa sheet', () {
    Future<AppSettings> pumpReader(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 900);
      addTearDown(tester.view.reset);

      late AppSettings settings;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) {
              final mp = MainProvider();
              mp.setVerses(const [
                Verse(book: 'Genesis', chapter: 1, verse: 1, text: 'seed 1'),
                Verse(book: 'Genesis', chapter: 1, verse: 2, text: 'seed 2'),
              ]);
              mp.setCurrentChapter(book: 'Genesis', chapter: 1);
              return mp;
            }),
            ChangeNotifierProvider(create: (_) {
              settings = AppSettings();
              return settings;
            }),
          ],
          child: const MaterialApp(home: Scaffold(body: BibleReadingPane())),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 700));
      return settings;
    }

    // The sheet is a modal route; it has to be torn down before the
    // test ends or the pending route trips the framework.
    //
    // Found by ICON, not by tooltip: `AppSettings` defaults to
    // `zh-Hans`, so the bottom bar's label is 字体大小 and an English
    // `byTooltip` silently matches nothing.
    Future<void> openSheet(WidgetTester tester) async {
      final aa = find.byIcon(Icons.text_fields_rounded);
      expect(aa, findsOneWidget);
      await tester.tap(aa);
      await tester.pumpAndSettle();
    }

    Future<void> closeSheet(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 700));
    }

    IconButton stepButton(WidgetTester tester, IconData icon) =>
        tester.widget<IconButton>(find.ancestor(
          of: find.byIcon(icon),
          matching: find.byType(IconButton),
        ));

    testWidgets('offers the top of the range, not 32', (tester) async {
      final settings = await pumpReader(tester);
      await settings.setFontSize(32);
      await tester.pump();
      await openSheet(tester);

      // Pre-fix this button is null at exactly 32 — the top quarter of
      // the slider was reachable only from Settings.
      expect(stepButton(tester, Icons.text_increase_rounded).onPressed,
          isNotNull);

      await tester.tap(find.byIcon(Icons.text_increase_rounded));
      await tester.pumpAndSettle();
      expect(settings.fontSize, 33);
      await closeSheet(tester);
    });

    testWidgets('decrease from the maximum moves one stop, not eight',
        (tester) async {
      final settings = await pumpReader(tester);
      await settings.setFontSize(kFontSizeMax);
      await tester.pump();
      await openSheet(tester);

      await tester.tap(find.byIcon(Icons.text_decrease_rounded));
      await tester.pumpAndSettle();
      // Pre-fix: 32. Eight points gone in one tap.
      expect(settings.fontSize, kFontSizeMax - 1);
      await closeSheet(tester);
    });

    testWidgets('is not a one-way trapdoor — a decrease is undoable here',
        (tester) async {
      final settings = await pumpReader(tester);
      await settings.setFontSize(kFontSizeMax);
      await tester.pump();
      await openSheet(tester);

      await tester.tap(find.byIcon(Icons.text_decrease_rounded));
      await tester.pumpAndSettle();
      final afterDown = settings.fontSize;
      await tester.tap(find.byIcon(Icons.text_increase_rounded));
      await tester.pumpAndSettle();

      // Pre-fix the decrease landed on 32, where increase is disabled,
      // so this tap did nothing and the reader was stranded 8 pt below
      // the size they had chosen.
      expect(settings.fontSize, greaterThan(afterDown));
      expect(settings.fontSize, kFontSizeMax);
      await closeSheet(tester);
    });

    testWidgets('the readout reports the size instead of freezing at 32',
        (tester) async {
      final settings = await pumpReader(tester);
      await settings.setFontSize(kFontSizeMax);
      await tester.pump();
      await openSheet(tester);

      final readout = tester.widget<Text>(find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(kFontSizeMax.round().toString()),
      ));
      // Pre-fix `(size * 1.2).clamp(18, 32)` pinned the one number on
      // screen that reports the setting from 26.7 pt up.
      expect(readout.style?.fontSize, greaterThan(32.0));
      await closeSheet(tester);
    });

    testWidgets('both ends still refuse to leave the range', (tester) async {
      final settings = await pumpReader(tester);
      await settings.setFontSize(kFontSizeMin);
      await tester.pump();
      await openSheet(tester);
      expect(stepButton(tester, Icons.text_decrease_rounded).onPressed, isNull);
      expect(stepButton(tester, Icons.text_increase_rounded).onPressed,
          isNotNull);
      await closeSheet(tester);
    });
  });

  test('no control writes a font size it computed from a literal', () {
    // The defect was not a bad number, it was a SECOND opinion about
    // the range. Three call sites move this setting — the slider (a
    // `Slider` value), a style preset (a field), and the reader's
    // stepper — and none of them may do arithmetic on it. A fourth
    // control that writes `setFontSize(size + 2)` is the same bug
    // arriving again, and no size detector would see it.
    //
    // Reach, stated: this reads the argument up to the first `)`, so a
    // literal nested deeper than one call goes unseen. It catches the
    // shape the defect actually had, which is arithmetic written inline
    // at the button.
    final offenders = <String>[];
    final call = RegExp(r'setFontSize\(([^)]*)');
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      for (final m in call.allMatches(f.readAsStringSync())) {
        final arg = m.group(1)!;
        if (arg.contains('fontSizeAfterStep')) continue;
        if (RegExp(r'\d').hasMatch(arg)) offenders.add('${f.path}: $arg');
      }
    }
    expect(offenders, isEmpty,
        reason: 'move the font size with fontSizeAfterStep, not arithmetic');
  });

  group('nothing can store a scale outside the range a slider offers', () {
    // A `Slider` asserts on an out-of-range value, and in release JS the
    // assert is stripped and the thumb paints off the end of the track.
    // Three ways a stale number reaches one: the setter, the restore,
    // and the settings blob a reader imports from a file.

    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('the setters bound what they store', () async {
      final s = AppSettings();
      await s.setFontSize(999);
      expect(s.fontSize, kFontSizeMax);
      await s.setFontSize(-4);
      expect(s.fontSize, kFontSizeMin);
      await s.setLineSpacing(50);
      expect(s.lineSpacing, kLineSpacingMax);
      await s.setMenuScale(9);
      expect(s.menuScale, kMenuScaleMax);
    });

    test('restoring a legacy value bounds it', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'fontSize': 96.0,
        'lineSpacing': 12.0,
        'menuScale': 8.0,
      });
      final s = AppSettings();
      await s.loadSettings();
      expect(s.fontSize, kFontSizeMax);
      expect(s.lineSpacing, kLineSpacingMax);
      expect(s.menuScale, kMenuScaleMax);
    });

    test('an imported settings blob is bounded too', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        ProfileService.instance.scopedKey('userPrefs'): jsonEncode({
          'fontSize': 400,
          'lineSpacing': 99,
          'menuScale': 77,
        }),
      });
      final s = AppSettings();
      await s.loadSettings();
      expect(s.fontSize, kFontSizeMax);
      expect(s.lineSpacing, kLineSpacingMax);
      expect(s.menuScale, kMenuScaleMax);
    });
  });
}
