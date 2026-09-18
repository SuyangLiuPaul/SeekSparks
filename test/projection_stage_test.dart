/// What the room can see.
///
/// `projection_page_test.dart` drives the operator's end. This drives
/// the wall directly, which is the only way to reach the second edition
/// at all: the page resolves it through `resolveSecondaryVersion` and
/// then `MainProvider.preloadVersion`, and a real multi-megabyte asset
/// load never completes inside a widget test's fake-async zone (the same
/// constraint `page_url_route_test.dart` records about the wheel). The
/// stage takes the text as a parameter, so the two editions on screen
/// can be asserted without asking the file system for a Bible.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yahwehs_sword/constants/bible_versions.dart'
    show shortBibleVersionLabel;
import 'package:yahwehs_sword/constants/projection_setup.dart';
import 'package:yahwehs_sword/constants/projection_strings.dart';
import 'package:yahwehs_sword/constants/workbench_theme.dart' show WbColors;
import 'package:yahwehs_sword/models/verse.dart';
import 'package:yahwehs_sword/widgets/projection_stage.dart';

const _reading = 'cuvs-yhwh';
const _second = 'bsb';
const _locale = 'en';

const _verse = Verse(
  book: 'Genesis',
  chapter: 1,
  verse: 1,
  text: 'In the beginning God created the heavens and the earth.',
);

Future<void> _stage(
  WidgetTester tester, {
  List<Verse> verses = const [_verse],
  bool blank = false,
  bool secondOn = false,
  List<String?>? secondTexts,
  bool secondLoading = false,
  double typeSize = 64,
  ProjectionGround ground = kProjectionGroundDefault,
  ProjectionLayout layout = ProjectionLayout.standard,
  Size surface = const Size(1280, 800),
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ProjectionStage(
        verses: verses,
        reference: verses.isEmpty
            ? ''
            : '${verses.first.book} ${verses.first.chapter}:${verses.first.verseLabel}',
        versionCode: _reading,
        typeSize: typeSize,
        blank: blank,
        locale: _locale,
        ground: ground,
        secondOn: secondOn,
        secondTexts: secondTexts,
        secondCode: secondOn ? _second : null,
        secondLoading: secondLoading,
        layout: layout,
      ),
    ),
  ));
  await tester.pump();
}

/// Every colour the stage is currently painting the wall with — the
/// flat fills AND the gradient's stops, because "what is on the wall"
/// has to mean the same thing for both kinds of ground.
Set<Color> _wallColours(WidgetTester tester) => <Color>{
      for (final box in tester.widgetList<ColoredBox>(find.byType(ColoredBox)))
        box.color,
      for (final box
          in tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)))
        ...switch (box.decoration) {
          BoxDecoration(gradient: final LinearGradient g) => g.colors,
          _ => const <Color>[],
        },
    };

String _s(String key) => projectionStrings[key]![_locale]!;

void main() {
  _layoutTests();

  group('one edition', () {
    testWidgets('puts the verse and its reference on the wall',
        (tester) async {
      await _stage(tester);
      expect(find.text(_verse.text), findsOneWidget);
      expect(
        find.text('Genesis 1:1 · ${shortBibleVersionLabel(_reading)}'),
        findsOneWidget,
        reason: 'the reference names the edition it is a reference IN — '
            'a chapter-and-verse alone is ambiguous the moment the room '
            'holds two translations',
      );
    });

    testWidgets('draws the passage at the size the operator asked for',
        (tester) async {
      await _stage(tester, typeSize: 88);
      expect(tester.widget<Text>(find.text(_verse.text)).style!.fontSize, 88);
    });
  });

  group('two editions', () {
    testWidgets('stacks the second under the first, both on the wall',
        (tester) async {
      const other = 'Im Anfang schuf Gott Himmel und Erde.';
      await _stage(tester, secondOn: true, secondTexts: [other]);

      expect(find.text(_verse.text), findsOneWidget);
      expect(find.text(other), findsOneWidget);

      final first = tester.getRect(find.text(_verse.text));
      final secondRect = tester.getRect(find.text(other));
      expect(secondRect.top, greaterThan(first.bottom),
          reason: 'stacked, not columned — two half-width columns halve '
              'the measure and double the line count for a room reading '
              'sentences');
      expect(secondRect.width, closeTo(first.width, 1.0),
          reason: 'both editions keep the full usable width');
    });

    testWidgets('names both editions in the corner', (tester) async {
      await _stage(tester, secondOn: true, secondTexts: ['anything']);
      expect(
        find.text('Genesis 1:1 · ${shortBibleVersionLabel(_reading)} · '
            '${shortBibleVersionLabel(_second)}'),
        findsOneWidget,
        reason: 'two blocks of text with no way to tell which translation '
            'is which is worse than one',
      );
    });

    testWidgets('sets the second edition smaller, so one of them leads',
        (tester) async {
      const other = 'Im Anfang schuf Gott Himmel und Erde.';
      await _stage(tester, secondOn: true, secondTexts: [other], typeSize: 64);
      final lead = tester.widget<Text>(find.text(_verse.text)).style!.fontSize!;
      final follow = tester.widget<Text>(find.text(other)).style!.fontSize!;
      expect(follow, lessThan(lead));
      expect(follow, closeTo(lead * kProjectionSecondScale, 0.001));
    });

    testWidgets('says so when the edition has no text for this reference',
        (tester) async {
      // Real: the LJK editions are New Testament only, so an Old
      // Testament reading has nothing to put in the second block.
      await _stage(tester, secondOn: true, secondTexts: null);
      expect(find.text(_s('projectionSecondVersionMissing')), findsOneWidget,
          reason: 'silence in the second block reads as a bug from the '
              'fourth row back');
    });

    testWidgets('says it is still loading rather than saying it is missing',
        (tester) async {
      await _stage(tester, secondOn: true, secondLoading: true);
      expect(find.text(_s('projectionSecondVersionLoading')), findsOneWidget);
      expect(find.text(_s('projectionSecondVersionMissing')), findsNothing);
    });
  });

  group('the blank state', () {
    testWidgets('shows nothing at all — no verse, no reference, no note',
        (tester) async {
      await _stage(tester, blank: true, secondOn: true, secondTexts: ['x']);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('stays on the same ground the passage was drawn on',
        (tester) async {
      // A projector's only "off" is dark pixels, and blanking a screen
      // that was already dark must not flash. Same colour, both states.
      await _stage(tester);
      final lit = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .map((b) => b.color)
          .toSet();
      await _stage(tester, blank: true);
      final dark = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .map((b) => b.color)
          .toSet();
      expect(dark, contains(WbColors.dark.groundBg));
      expect(lit, contains(WbColors.dark.groundBg));
    });

    testWidgets('and does so for EVERY ground, not just the default one',
        (tester) async {
      // The claim above used to be free: there was one ground, so
      // blanking could not land anywhere else. With a choice it becomes
      // a property that has to hold four times over, and the one that
      // would break it is the gradient — cutting a gradient to black is
      // the flash the blank key exists not to be.
      for (final ground in ProjectionGround.values) {
        await _stage(tester, ground: ground);
        final lit = _wallColours(tester);
        await _stage(tester, ground: ground, blank: true);
        final blanked = _wallColours(tester);
        expect(blanked, containsAll(projectionGroundPaintFor(ground).stops),
            reason: '${ground.name}: the blanked wall must be painted with '
                'the ground the operator chose');
        expect(lit.intersection(blanked),
            containsAll(projectionGroundPaintFor(ground).stops),
            reason: '${ground.name}: lit and blank must be the same wall '
                'with the text taken off it');
      }
    });
  });

  group('the ground the operator chose', () {
    testWidgets('is the one on the wall', (tester) async {
      await _stage(tester, ground: ProjectionGround.black);
      expect(_wallColours(tester), contains(const Color(0xFF000000)));
      expect(_wallColours(tester), isNot(contains(WbColors.dark.groundBg)),
          reason: 'a ground that was chosen and not painted is the '
              'setting doing nothing, which is the whole report');
    });

    testWidgets('is a real gradient when the operator asks for one',
        (tester) async {
      await _stage(tester, ground: ProjectionGround.vignette);
      final stops = projectionGroundPaintFor(ProjectionGround.vignette).stops;
      expect(_wallColours(tester), containsAll(stops));
      expect(stops.first, isNot(stops.last),
          reason: 'a gradient between one colour and itself is a flat fill '
              'wearing a name');
    });

    testWidgets('does not move the scripture, only what is behind it',
        (tester) async {
      // The stage's whole job is the passage; a background feature that
      // moved the text would be a background feature that broke the
      // thing it decorates.
      await _stage(tester);
      final on = tester.getRect(find.text(_verse.text));
      await _stage(tester, ground: ProjectionGround.vignette);
      expect(tester.getRect(find.text(_verse.text)), on);
      expect(tester.widget<Text>(find.text(_verse.text)).style!.color,
          WbColors.dark.text);
    });
  });

  group('a verse too long for the room', () {
    testWidgets('is shrunk to fit rather than clipped or run off the edge',
        (tester) async {
      // Psalm 119-scale: a real verse at a size the operator has wound
      // up too far. The whole block must stay inside the viewport.
      const long = Verse(
        book: 'Esther',
        chapter: 8,
        verse: 9,
        text: 'Then the king\'s scribes were summoned on the twenty-third '
            'day of the third month, and an edict was written to the Jews '
            'and to the satraps and governors and officials of the '
            'provinces from India to Cush, one hundred and twenty-seven '
            'provinces, to each province in its own script and to each '
            'people in their own language.',
      );
      await _stage(tester, verses: [long], typeSize: 160);

      final painted = tester.getRect(find.text(long.text));
      expect(painted.width, lessThanOrEqualTo(1280.0));
      expect(painted.height, lessThanOrEqualTo(800.0),
          reason: 'a clipped verse is not an ugly verse, it is a '
              'different verse, and the room cannot tell');
      expect(tester.takeException(), isNull,
          reason: 'and it must not overflow, which is how this would '
              'otherwise announce itself');
    });

    testWidgets('a short verse at the same setting is NOT shrunk',
        (tester) async {
      // The other half of the claim: the fit is a ceiling, so a verse
      // that fits is drawn at exactly the size that was asked for.
      const short =
          Verse(book: 'John', chapter: 11, verse: 35, text: 'Jesus wept.');
      await _stage(tester, verses: [short], typeSize: 64);
      final painted = tester.getRect(find.text(short.text));
      final declared =
          tester.widget<Text>(find.text(short.text)).style!.fontSize!;
      expect(painted.height, greaterThanOrEqualTo(declared),
          reason: 'one line at 64 px cannot paint shorter than 64 px '
              'unless the fit shrank it');
    });
  });
}

/// The layout the operator sets — 2026-09-13, asked for as "middle
/// aligned，verse by verse 还是连在一起，plain txt，include ref,
/// devotional format".
///
/// Four independent choices rather than a list of named formats, so
/// what is pinned here is each choice on its own and the combination
/// that has a name.
void _layoutTests() {
  const verses = [
    Verse(book: 'Genesis', chapter: 1, verse: 1, text: 'In the beginning.'),
    Verse(book: 'Genesis', chapter: 1, verse: 2, text: 'The earth was void.'),
  ];

  /// Every `Text` the wall is currently drawing, in tree order.
  List<Text> textsOn(WidgetTester tester) =>
      tester.widgetList<Text>(find.byType(Text)).toList();

  group('the layout the operator sets', () {
    testWidgets('centred by default, from the margin when asked',
        (tester) async {
      await _stage(tester, verses: verses);
      expect(
          textsOn(tester).where((t) => t.textAlign == TextAlign.center).length,
          greaterThan(0));

      await _stage(tester,
          verses: verses,
          layout: const ProjectionLayout(align: ProjectionAlign.start));
      // `start`, never `left`: a Hebrew passage starts on the right, and
      // the setting is about the measure, not a side of the screen.
      expect(textsOn(tester).any((t) => t.textAlign == TextAlign.left), isFalse);
      expect(textsOn(tester).any((t) => t.textAlign == TextAlign.start), isTrue);
    });

    testWidgets('verse by verse is two blocks; run together is one',
        (tester) async {
      await _stage(tester, verses: verses);
      expect(find.textContaining('In the beginning.', findRichText: true),
          findsOneWidget);
      expect(find.textContaining('The earth was void.', findRichText: true),
          findsOneWidget);
      // Separate blocks: no single widget holds both.
      expect(
          find.textContaining('In the beginning. The earth was void.',
              findRichText: true),
          findsNothing);

      await _stage(tester,
          verses: verses,
          layout: const ProjectionLayout(flow: ProjectionFlow.continuous));
      // One paragraph. The numbers are still on here, so they sit
      // INLINE in front of each verse exactly as a printed Bible sets
      // them — which is the only way a run-together passage can carry
      // them at all. Turning them off is the next test.
      expect(
          find.textContaining('In the beginning. 2 The earth was void.',
              findRichText: true),
          findsOneWidget);
    });

    testWidgets('numbers off gives scripture with nothing in front of it',
        (tester) async {
      await _stage(tester, verses: verses);
      expect(find.textContaining('1 In the beginning.', findRichText: true),
          findsOneWidget);

      await _stage(tester,
          verses: verses, layout: const ProjectionLayout(numbers: false));
      expect(find.textContaining('1 In the beginning.', findRichText: true),
          findsNothing);
      expect(find.textContaining('In the beginning.', findRichText: true),
          findsOneWidget);
    });

    testWidgets('a single verse still carries no number, numbers on or off',
        (tester) async {
      // Unchanged rule: the reference below already names it. The
      // setting governs the many-verse case.
      for (final on in [true, false]) {
        await _stage(tester, layout: ProjectionLayout(numbers: on));
        expect(find.textContaining('1 ${_verse.text}', findRichText: true),
            findsNothing,
            reason: 'numbers: $on');
      }
    });

    testWidgets('the reference moves, and can be taken off the wall',
        (tester) async {
      const ref = 'Genesis 1:1';
      await _stage(tester, verses: verses);
      expect(find.textContaining(ref), findsOneWidget);

      await _stage(tester,
          verses: verses,
          layout: const ProjectionLayout(
              reference: ProjectionReferencePlace.under));
      // Still exactly one — under the passage rather than in the corner,
      // not in both places.
      expect(find.textContaining(ref), findsOneWidget);

      await _stage(tester,
          verses: verses,
          layout: const ProjectionLayout(
              reference: ProjectionReferencePlace.off));
      expect(find.textContaining(ref), findsNothing);
      // The words are still there: taking the address off the wall is
      // not blanking it.
      expect(find.textContaining('In the beginning.', findRichText: true),
          findsOneWidget);
    });

    testWidgets('the devotional combination is what the word means',
        (tester) async {
      await _stage(tester, verses: verses, layout: ProjectionLayout.devotional);
      expect(ProjectionLayout.devotional.isDevotional, isTrue);
      expect(ProjectionLayout.standard.isDevotional, isFalse);
      // One paragraph, no numbers, the address beneath the words.
      expect(
          find.textContaining('In the beginning. The earth was void.',
              findRichText: true),
          findsOneWidget);
      expect(find.textContaining('1 In the beginning', findRichText: true),
          findsNothing);
      expect(find.textContaining('Genesis 1:1'), findsOneWidget);
    });

    testWidgets('blanking still beats every layout', (tester) async {
      // The blank key is a shutter over the whole stage, reference
      // included, whatever the layout is set to.
      await _stage(tester,
          verses: verses, blank: true, layout: ProjectionLayout.devotional);
      expect(find.textContaining('In the beginning', findRichText: true),
          findsNothing);
      expect(find.textContaining('Genesis'), findsNothing);
    });

    testWidgets('the companion edition follows the same flow', (tester) async {
      await _stage(tester,
          verses: verses,
          secondOn: true,
          secondTexts: const ['起初。', '地是空虚的。'],
          layout: const ProjectionLayout(flow: ProjectionFlow.continuous));
      expect(find.textContaining('起初。 2 地是空虚的。', findRichText: true),
          findsOneWidget,
          reason: 'two editions on one wall, set two different ways, is '
              'two walls');
    });
  });
}
