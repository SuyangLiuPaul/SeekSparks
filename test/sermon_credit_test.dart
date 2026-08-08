import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:seeksparks/constants/sermon_credit.dart';
import 'package:seeksparks/constants/ui_strings.dart';

const _locales = ['en', 'zh-Hans', 'zh-Hant'];

void main() {
  group('the preacher is named, once, everywhere', () {
    test('the name resolves in all three locales', () {
      for (final l in _locales) {
        expect(preacherName(l), isNotEmpty, reason: 'no preacher for $l');
      }
    });

    test('the English form keeps the initials', () {
      // The reported defect: one surface said "Pastor Eric Chang" and the
      // corpus owner asked for "Pastor Eric H.H. Chang". Dropping the
      // initials again should break the build, not ship.
      expect(preacherName('en'), 'Pastor Eric H.H. Chang');
    });

    test('an unknown locale falls back rather than blanking the credit', () {
      // A byline that renders as an empty line is worse than an English
      // one: it looks like the sermon has no author.
      expect(preacherName('fr'), preacherName('en'));
      expect(preacherName(''), isNotEmpty);
    });

    test('the library credit is built from the name, not retyped', () {
      for (final l in _locales) {
        expect(
          sermonLibraryCredit(l),
          contains(preacherName(l)),
          reason: 'library credit for $l drifted from the canonical name',
        );
      }
    });

    test('withPreacher leaves no placeholder behind', () {
      for (final l in _locales) {
        final out = withPreacher('{name}·{name}', l);
        expect(out, isNot(contains('{name}')));
        expect(out, '${preacherName(l)}·${preacherName(l)}');
      }
    });
  });

  group('no second spelling can creep back in', () {
    // The failure this guards is exactly what was found: the name lived in
    // three unrelated ui_strings entries in three different forms, and the
    // one written for the library header was rendered by nothing. Anything
    // that needs the name now has to take the `{name}` placeholder, which
    // means sermon_credit.dart stays the only file that spells it.
    test('no uiStrings value hardcodes the preacher', () {
      final offenders = <String>[];
      for (final entry in uiStrings.entries) {
        for (final v in entry.value.values) {
          if (v.contains('张熙和') ||
              v.contains('張熙和') ||
              v.contains('Eric')) {
            offenders.add('${entry.key} → "$v"');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'use the {name} placeholder + withPreacher() instead:\n'
            '${offenders.join('\n')}',
      );
    });

    test('a {name} template carries the placeholder in every locale', () {
      // Half-templated is the quiet failure: English gets the byline and
      // the Chinese locales silently lose it.
      for (final entry in uiStrings.entries) {
        final withPlaceholder =
            entry.value.entries.where((e) => e.value.contains('{name}'));
        if (withPlaceholder.isEmpty) continue;
        for (final l in _locales) {
          final v = entry.value[l];
          expect(v, isNotNull, reason: '${entry.key} has no $l');
          expect(
            v,
            contains('{name}'),
            reason: '${entry.key} drops the preacher in $l',
          );
        }
      }
    });
  });

  group('the offline-pack row counts the corpus it downloads', () {
    // The label said 587 sermons. The index holds 289 records; their
    // `parts` fields sum to 589, which is the number 587 was probably
    // reaching for. A reader choosing what to download is choosing
    // sermons, so the label states sermons.
    test('the sermon index really holds 289 records', () {
      final raw =
          File('assets/sermons/index.json').readAsStringSync();
      final records = jsonDecode(raw) as List<dynamic>;
      expect(records.length, 289);
    });

    test('the label states that number in every locale', () {
      final entry = uiStrings['offlinePackSermons'];
      expect(entry, isNotNull);
      for (final l in _locales) {
        expect(entry![l], contains('289'), reason: 'stale count in $l');
        expect(entry[l], isNot(contains('587')));
      }
    });
  });
}
