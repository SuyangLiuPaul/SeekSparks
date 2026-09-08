/// The projection's movement arithmetic and its key map, without a
/// widget.
///
/// `projection_page_test.dart` drives the real page with the real
/// keyboard, which is the only instrument that can prove a key reaches
/// the handler at all. It is also the slow one, and it cannot easily
/// describe a corpus whose last chapter is empty or whose first is. So
/// the decisions are pure functions and this is where their edges are
/// pinned — the same split `browserRouteAction` uses in `main.dart`,
/// and for the same reason.
library;

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/workbench_theme.dart' show WbMetrics;
import 'package:seeksparks/models/app_settings.dart'
    show kFontSizeDefault, kFontSizeMax;
import 'package:seeksparks/pages/projection_page.dart';

/// Three chapters of 3, 2 and 4 verses. Uneven on purpose: equal-length
/// chapters make an off-by-one in the roll-over invisible.
int _versesIn(int chapter) => const [3, 2, 4][chapter];
const int _chapters = 3;

ProjectionCursor _verse(ProjectionCursor from, int delta) =>
    projectionVerseStep(from, delta,
        chapterCount: _chapters, versesIn: _versesIn);

ProjectionCursor _chapter(ProjectionCursor from, int delta) =>
    projectionChapterStep(from, delta,
        chapterCount: _chapters, versesIn: _versesIn);

void main() {
  group('the verse key', () {
    test('moves one verse inside a chapter', () {
      expect(_verse(const ProjectionCursor(0, 0), 1),
          const ProjectionCursor(0, 1));
      expect(_verse(const ProjectionCursor(0, 2), -1),
          const ProjectionCursor(0, 1));
    });

    test('rolls forward off the end of a chapter into the next one', () {
      // Chapter 0 holds three verses, so index 2 is its last.
      expect(_verse(const ProjectionCursor(0, 2), 1),
          const ProjectionCursor(1, 0));
    });

    test('rolls backward off the front of a chapter onto the previous '
        "chapter's LAST verse", () {
      expect(_verse(const ProjectionCursor(1, 0), -1),
          const ProjectionCursor(0, 2),
          reason: 'retreating into a chapter has to land at its end — '
              'landing at its start would skip every verse of it');
    });

    test('refuses to move past either end of the corpus', () {
      const first = ProjectionCursor(0, 0);
      expect(_verse(first, -1), first,
          reason: 'wrapping to Revelation would look like a crash to a '
              'room watching');
      const last = ProjectionCursor(2, 3);
      expect(_verse(last, 1), last);
    });

    test('steps over a chapter with no verses rather than landing on it', () {
      // A chapter the corpus carries no text for is a wall the operator
      // cannot get off by pressing the same key again.
      int holes(int chapter) => const [2, 0, 2][chapter];
      expect(
        projectionVerseStep(const ProjectionCursor(0, 1), 1,
            chapterCount: 3, versesIn: holes),
        const ProjectionCursor(2, 0),
      );
      expect(
        projectionVerseStep(const ProjectionCursor(2, 0), -1,
            chapterCount: 3, versesIn: holes),
        const ProjectionCursor(0, 1),
      );
    });
  });

  group('the chapter key', () {
    test('lands on the first verse of the next chapter', () {
      expect(_chapter(const ProjectionCursor(0, 2), 1),
          const ProjectionCursor(1, 0));
    });

    test('lands on the first verse going BACK too, not the last', () {
      expect(_chapter(const ProjectionCursor(1, 1), -1),
          const ProjectionCursor(0, 0),
          reason: 'the operator asked for a passage, and a passage '
              'starts at the top; the verse key is what asks the other '
              'question');
    });

    test('refuses to move past either end of the corpus', () {
      const first = ProjectionCursor(0, 1);
      expect(_chapter(first, -1), first);
      const last = ProjectionCursor(2, 0);
      expect(_chapter(last, 1), last);
    });
  });

  group('the key map', () {
    test('every arrow, space and Return advances or retreats by verse', () {
      for (final key in [
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.enter,
      ]) {
        expect(projectionCommandFor(key), ProjectionCommand.nextVerse,
            reason: '${key.keyLabel} should advance');
      }
      for (final key in [
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.backspace,
      ]) {
        expect(projectionCommandFor(key), ProjectionCommand.previousVerse);
      }
    });

    test("the clicker's two buttons move by chapter", () {
      expect(projectionCommandFor(LogicalKeyboardKey.pageDown),
          ProjectionCommand.nextChapter);
      expect(projectionCommandFor(LogicalKeyboardKey.pageUp),
          ProjectionCommand.previousChapter);
    });

    test('B blanks, Esc leaves, P adds the second edition', () {
      expect(projectionCommandFor(LogicalKeyboardKey.keyB),
          ProjectionCommand.blank);
      expect(projectionCommandFor(LogicalKeyboardKey.escape),
          ProjectionCommand.leave);
      expect(projectionCommandFor(LogicalKeyboardKey.keyP),
          ProjectionCommand.toggleSecondVersion);
    });

    test('both faces of the size keys are answered', () {
      // A keyboard reports `=` for the key it prints `+` on unless the
      // operator is holding Shift, and a numeric keypad reports
      // neither.
      for (final key in [
        LogicalKeyboardKey.equal,
        LogicalKeyboardKey.add,
        LogicalKeyboardKey.numpadAdd,
      ]) {
        expect(projectionCommandFor(key), ProjectionCommand.biggerType);
      }
      for (final key in [
        LogicalKeyboardKey.minus,
        LogicalKeyboardKey.numpadSubtract,
      ]) {
        expect(projectionCommandFor(key), ProjectionCommand.smallerType);
      }
    });

    test('a key the projection has no use for is left to the browser', () {
      expect(projectionCommandFor(LogicalKeyboardKey.keyF), isNull);
      expect(projectionCommandFor(LogicalKeyboardKey.f5), isNull,
          reason: 'reload belongs to the browser — see '
              'kBrowserOwnedFunctionKeys in keyboard_shortcuts.dart');
      expect(projectionCommandFor(LogicalKeyboardKey.tab), isNull);
    });
  });

  group('the type ladder', () {
    test('clamps at both ends instead of running off it', () {
      expect(projectionTypeStep(0, -1), 0);
      expect(projectionTypeStep(kProjectionTypeSteps.length - 1, 1),
          kProjectionTypeSteps.length - 1);
      expect(projectionTypeStep(kProjectionTypeDefaultStep, 1),
          kProjectionTypeDefaultStep + 1);
    });

    test('rises monotonically, so a press is always a change', () {
      for (var i = 1; i < kProjectionTypeSteps.length; i++) {
        expect(kProjectionTypeSteps[i],
            greaterThan(kProjectionTypeSteps[i - 1]));
      }
    });

    test('does not overlap the range the reading setting can produce', () {
      // The workbench's body size at the reading slider's maximum. If
      // the two ladders ever met, "a separate projection type scale"
      // would be a claim without a consequence.
      final biggestReadingSize =
          WbMetrics.text * (kFontSizeMax / kFontSizeDefault);
      expect(kProjectionTypeSteps.first, greaterThan(biggestReadingSize),
          reason: 'the smallest size a room ever gets must still be '
              'larger than the biggest size a desk can ask for');
    });

    test('starts in the middle, so the first adjustment can go either way',
        () {
      expect(kProjectionTypeDefaultStep, greaterThan(0));
      expect(kProjectionTypeDefaultStep,
          lessThan(kProjectionTypeSteps.length - 1));
    });
  });
}
