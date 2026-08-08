/// 2026-08-08 (SeekSparks, task #285): the Chinese editions carry
/// Chinese short labels.
///
/// A Chinese reader had to decode `CUVS` and `LJK` to pick a Chinese
/// text. The confirmed scheme is positional — 1st character = which
/// text, 2nd = which script, trailing `+` = carries Strong's — and the
/// English/Greek rows keep the Latin abbreviations those texts are
/// actually known by.
///
/// Three things this file guards, all of which the rename could have
/// broken silently:
///   * the labels themselves, since naming is the owner's call;
///   * the per-version COLOUR, which used to be keyed on the label, so
///     a rename detached every edition from its hue;
///   * the gutter WIDTH, which was a hard-coded pixel constant sized
///     against the old labels — and, less obviously, sized at one type
///     scale while the reader can scale the type by 1.75×.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/bible_versions.dart';
import 'package:seeksparks/constants/ui_strings.dart' show uiStrings;
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/services/tagged_text_service.dart';
import 'package:seeksparks/utils/command_verb.dart';
import 'package:seeksparks/utils/version_gutter.dart';
import 'package:seeksparks/widgets/workbench_chrome.dart';

/// The scheme as the owner wrote it out on 2026-08-08.
const _confirmed = {
  'cuvs-yhwh': '雅简+',
  'cuvs-yhwh-tr': '雅繁+',
  'cuvs-plus': '和简+',
  'biblexg-v2': '梁简',
  'biblexg-v2-tr': '梁繁',
};

/// The rows that keep their Latin abbreviation, and what it is.
const _latin = {
  'kjv': 'KJV',
  'leb': 'LEB',
  'nasb': 'NASB',
  'bsb': 'BSB',
  'kjvs': 'KJV+S',
  'lxxwh': 'LXX+WH',
};

/// `cuvs-yhwh-tr` is labelled `雅繁+` but is not in
/// `TaggedTextService.taggedVersions`: `assets/tagged/` ships no
/// traditional set, and the app has no 简→繁 converter to serve the
/// simplified one through. The label is the owner's, kept verbatim.
/// This is the ONLY row allowed to advertise tagging it does not have.
const _plusWithoutTagging = {'cuvs-yhwh-tr'};

void main() {
  group('the confirmed label scheme', () {
    test('every Chinese edition carries its Chinese label', () {
      for (final entry in _confirmed.entries) {
        expect(shortBibleVersionLabel(entry.key), entry.value,
            reason: '${entry.key} must be labelled ${entry.value}');
      }
    });

    test('English and Greek editions keep their own names', () {
      for (final entry in _latin.entries) {
        expect(shortBibleVersionLabel(entry.key), entry.value);
      }
    });

    // The whole point of the task. A label like `CUVS(简)` asks a
    // Chinese reader to read English first.
    test('no Chinese edition prints a Latin letter', () {
      final latin = RegExp(r'[A-Za-z]');
      for (final v in bibleVersions) {
        if (v.language != 'zh-Hans' && v.language != 'zh-Hant') continue;
        expect(latin.hasMatch(v.shortLabel), isFalse,
            reason: '${v.value} still prints Latin: ${v.shortLabel}');
      }
    });

    // The label is a handle as well as a badge — `_matchVersion` and
    // `VerbContext.resolveVersion` both accept it — so a duplicate
    // would make one edition unreachable from the command line.
    test('labels are unique', () {
      final seen = <String>{};
      for (final v in bibleVersions) {
        expect(seen.add(v.shortLabel.toLowerCase()), isTrue,
            reason: 'duplicate label ${v.shortLabel}');
      }
    });

    test('the script character matches the language group', () {
      for (final v in bibleVersions) {
        if (v.language == 'zh-Hans') expect(v.shortLabel, contains('简'));
        if (v.language == 'zh-Hant') expect(v.shortLabel, contains('繁'));
      }
    });

    test('a trailing + means the edition really is tagged', () {
      for (final v in bibleVersions) {
        if (!v.shortLabel.endsWith('+')) continue;
        if (_plusWithoutTagging.contains(v.value)) continue;
        expect(TaggedTextService.supports(v.value), isTrue,
            reason: '${v.shortLabel} claims Strong\'s it does not ship');
      }
    });

    // The exception is allowed to be closed (by shipping traditional
    // tagging) but not to be forgotten: if it ever becomes tagged, this
    // fails and the allow-list shrinks.
    test('the documented + exception is still the only one', () {
      for (final code in _plusWithoutTagging) {
        expect(TaggedTextService.supports(code), isFalse,
            reason: '$code is tagged now — drop it from _plusWithoutTagging');
      }
    });
  });

  // The About page's Scriptures section names each edition before its
  // licence line, and those titles are hand-written rather than derived
  // — so they drifted the moment the badges changed, leaving the rights
  // notices labelled with abbreviations (`CUV+S`, `LJK1`) that no
  // longer appear anywhere in the app. An attribution you cannot match
  // to the text it covers is doing half its job.
  group('the About page names editions by the badge the app prints', () {
    void startsWithBadge(String key, String badge) {
      for (final locale in const ['zh-Hans', 'zh-Hant', 'en']) {
        expect(uiStrings[key]?[locale], startsWith(badge),
            reason: '$key [$locale] no longer leads with $badge');
      }
    }

    test('和合本+Strong\'s', () =>
        startsWithBadge('aboutVerCuvsPlus', shortBibleVersionLabel('cuvs-plus')));
    test('和合本雅伟版', () => startsWithBadge('aboutVerCuvsYhwh',
        shortBibleVersionLabel('cuvs-yhwh')));
    test('梁家铿译本', () =>
        startsWithBadge('aboutVerLjk', shortBibleVersionLabel('biblexg-v2')));
    test('the English rows are unchanged', () {
      startsWithBadge('aboutVerKjvs', shortBibleVersionLabel('kjvs'));
      startsWithBadge('aboutVerLxxwh', shortBibleVersionLabel('lxxwh'));
    });
  });

  group('colour survives the rename', () {
    test('every catalog edition has a hand-picked colour', () {
      for (final v in bibleVersions) {
        expect(kVersionTagColors.containsKey(v.value), isTrue,
            reason: '${v.value} would fall through to the HSL hash');
      }
    });

    test('the Browse window\'s originals rows have one too', () {
      for (final pseudo in const ['wtt', 'bgt', 'original']) {
        expect(kVersionTagColors.containsKey(pseudo), isTrue);
      }
    });

    // A hash gives a stable colour but guarantees no separation; the
    // point of the gutter colour is that you find a version without
    // reading it.
    test('no two editions share a colour', () {
      final byColour = <int, String>{};
      for (final v in bibleVersions) {
        final c = versionTagColor(v.value).toARGB32();
        expect(byColour.containsKey(c), isFalse,
            reason: '${v.value} and ${byColour[c]} are the same colour');
        byColour[c] = v.value;
      }
    });

    // The trap this whole re-keying exists to remove: colours must
    // answer to codes, never to display text. Stated as "every key is a
    // code" rather than "no key is a label", because the English rows
    // are labelled with their own code and always will be.
    test('every key is a version code', () {
      final known = {
        for (final v in bibleVersions) v.value,
        'wtt',
        'bgt',
        'original',
      };
      for (final key in kVersionTagColors.keys) {
        expect(known, contains(key),
            reason: '"$key" is not a version code — a label crept back in');
      }
    });
  });

  group('the gutter is sized, not guessed', () {
    // WbMetrics.chrome is 11 and the tag renders half a point smaller.
    const defaultSize = 10.5;

    test('the whole catalog now fits in less than the old 92px', () {
      final w = versionGutterWidth(
          [for (final v in bibleVersions) v.value], defaultSize);
      expect(w, lessThan(92));
    });

    // The reason to shrink it at all: reading width back in the centre
    // pane. Four Chinese editions should not pay for LXX+WH existing.
    test('a Chinese-only stack is narrower than one containing LXX+WH', () {
      final chinese = versionGutterWidth(
          const ['cuvs-yhwh', 'cuvs-plus', 'biblexg-v2'], defaultSize);
      final withGreek = versionGutterWidth(
          const ['cuvs-yhwh', 'cuvs-plus', 'lxxwh'], defaultSize);
      expect(chinese, lessThan(withGreek));
    });

    // The defect that was still live at 92: `WbType.chrome` is
    // multiplied by the reader's menuScale (0.8 – 1.4) and the box was
    // not, so turning the type up clipped the gutter.
    test('it follows the type scale', () {
      final small = versionGutterWidth(const ['lxxwh'], 10.5 * 0.8);
      final large = versionGutterWidth(const ['lxxwh'], 10.5 * 1.4);
      expect(large, greaterThan(small * 1.3));
    });

    test('a full-width glyph is charged more than a Latin one', () {
      expect(versionLabelEms('雅简'), greaterThan(versionLabelEms('AB')));
      expect(versionLabelEms('雅简'), 2.0);
    });

    test('an unknown or empty set still yields a usable column', () {
      expect(versionGutterWidth(const [], 10.5), versionGutterMinWidth);
      expect(versionGutterWidth(const ['x'], 10.5),
          greaterThanOrEqualTo(versionGutterMinWidth));
    });
  });

  group('the tag resolves a code, not a label', () {
    Future<void> pump(WidgetTester tester, String code) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AppSettings(),
          child: MaterialApp(
            home: Scaffold(body: WbVersionTag(code: code)),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('a version code prints its Chinese label', (tester) async {
      await pump(tester, 'cuvs-yhwh');
      expect(find.text('雅简+'), findsOneWidget);
      expect(find.text('CUVS-YHWH'), findsNothing);
    });

    testWidgets('and takes its colour from the code', (tester) async {
      await pump(tester, 'cuvs-plus');
      final text = tester.widget<Text>(find.text('和简+'));
      expect(text.style?.color, kVersionTagColors['cuvs-plus']);
    });

    testWidgets('the originals pseudo-codes still print', (tester) async {
      await pump(tester, 'wtt');
      expect(find.text('WTT'), findsOneWidget);
    });
  });

  // The labels are typed at the command line, so `+` had to survive the
  // tokeniser. It does — tokens split on whitespace only — but nothing
  // was asserting it before the labels started ending in one.
  group('the new labels are still typeable', () {
    VerbContext ctx() => VerbContext(
          versions: [
            for (final v in bibleVersions)
              VerbVersion(
                  code: v.value, label: v.shortLabel, language: v.language),
          ],
          searchVersion: 'kjv',
          displayVersions: const ['kjv'],
          currentEnglishBook: 'John',
          currentChapter: 3,
        );

    test('every catalog label resolves back to its own code', () {
      for (final v in bibleVersions) {
        expect(ctx().resolveVersion(v.shortLabel), v.value);
      }
    });

    test('`d 雅简+` reaches the display verb', () {
      final parse = parseCommandVerb('d 雅简+', ctx());
      expect(parse.issue, isNull);
      expect(parse.verb?.versions, contains('cuvs-yhwh'));
    });
  });

  // The audit that produced #285 looked for call sites of the label
  // helper, so it could not see the surfaces that never called it. The
  // status bar and the Help menu both shipped `currentVersion
  // .toUpperCase()`, which prints the internal code `CUVS-YHWH` at the
  // reader. Renaming the catalog did nothing for them, and no widget
  // test noticed, because an uppercased code looks like a badge.
  //
  // So the rule is asserted about the SOURCE, the same species of
  // invariant as `page_chrome_pass_test.dart`: uppercasing a version
  // code is never how a badge gets made. `shortBibleVersionLabel` is.
  group('no surface builds a badge by uppercasing a code', () {
    test('lib/ never calls .toUpperCase() on a version code', () {
      final pattern = RegExp(r'\b\w*[Vv]ersion\s*\.\s*toUpperCase\s*\(\s*\)');
      final offenders = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (pattern.hasMatch(lines[i])) {
            offenders.add('${f.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'Use shortBibleVersionLabel(code) — an uppercased code is '
              'an internal identifier, not a badge the reader knows.');
    });
  });
}
