/// The Help page's guards — 2026-09-18.
///
/// A help page is only worth having while it is true, and every way it
/// can stop being true is silent: a menu item renamed while the help
/// still names the old label, a key rebound while the page prints the
/// old one, a feature added to the menu and never described. Each test
/// below closes one of those.
library;

import 'dart:io';

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart' show SingleActivator;
import 'package:flutter_test/flutter_test.dart';

import 'package:yahwehs_sword/constants/help_topics.dart';
import 'package:yahwehs_sword/constants/ui_strings.dart';
import 'package:yahwehs_sword/pages/help_page.dart';
import 'package:yahwehs_sword/pages/projection_page.dart'
    show kProjectionKeymap;
import 'package:yahwehs_sword/utils/help_catalog.dart';
import 'package:yahwehs_sword/utils/keyboard_shortcuts.dart';
import 'package:yahwehs_sword/widgets/command_pane.dart'
    show kCommandSyntaxSections;

const _locales = ['zh-Hans', 'zh-Hant', 'en'];

List<String> _ids(List<HelpHit> hits) => [for (final h in hits) h.topic.id];

void main() {
  setUpAll(registerHelpExtraLabels);

  group('every topic is complete', () {
    test('ids are unique', () {
      final ids = [for (final t in kHelpTopics) t.id];
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('title and body in all three locales', () {
      for (final t in kHelpTopics) {
        for (final s in [...t.title.all, ...t.body.all]) {
          expect(s.trim(), isNotEmpty, reason: t.id);
        }
        // 繁體 was generated from 简体; a string OpenCC left identical
        // to its source is fine, but one that is still the ENGLISH is
        // a slot filled with the wrong locale.
        expect(t.title.hant, isNot(t.title.en), reason: t.id);
      }
    });

    test('every section has something in it', () {
      for (final s in HelpSection.values) {
        if (s == HelpSection.shortcuts) continue; // printed from tables
        expect(kHelpTopics.where((t) => t.section == s), isNotEmpty,
            reason: s.name);
        expect(kHelpSectionNames[s], isNotNull, reason: s.name);
      }
    });
  });

  group('the help names things the way the app does', () {
    test('every path segment is a real label', () {
      // A path is `ui_strings` KEYS so it prints the menu's own words.
      // A key that does not exist prints the key itself — "menuTolos" in
      // the middle of a sentence — which is the failure this catches.
      for (final t in kHelpTopics) {
        for (final k in t.path) {
          final m = uiStrings[k] ?? kHelpExtraLabels[k];
          expect(m, isNotNull, reason: '${t.id}: $k');
          for (final l in _locales) {
            expect(m![l], isNotNull, reason: '${t.id}: $k [$l]');
          }
        }
      }
    });

    test('every example is a line the command line card really prints', () {
      final card = {for (final (_, keys) in kCommandSyntaxSections) ...keys};
      final taught = {for (final t in kHelpTopics) ...t.examples};
      for (final k in taught) {
        expect(uiStrings[k], isNotNull, reason: k);
      }
      // …and the help teaches every line the card teaches, so the page
      // is not the smaller of the two grammars.
      expect(card.difference(taught), isEmpty);
    });

    test('every menu item is described somewhere', () {
      // The guard for the next feature: add a menu item and forget the
      // help, and this names it. A label counts as described if its
      // simplified-Chinese wording appears in a topic's title, body or
      // path — which is how a reader searching for it would find it.
      final src =
          File('lib/pages/workbench_page.dart').readAsStringSync();
      final start = src.indexOf('List<WbMenu> _buildMenus(');
      final end = src.indexOf('\n  }\n', start);
      final menus = src.substring(start, end);
      // Menu titles and item labels — not the `hint:` a greyed item
      // carries, which explains a state rather than naming a feature.
      final keys = {
        for (final m in RegExp(r"WbMenu(?:Item)?\(\s*s\('(\w+)'")
            .allMatches(menus))
          m.group(1)!,
      };
      expect(keys.length, greaterThan(30),
          reason: 'the menu parse found too little to prove anything');
      final hay = [
        for (final t in kHelpTopics) ...[
          t.title.hans,
          t.body.hans,
          for (final k in t.path) helpPathLabel(k, 'zh-Hans'),
        ],
      ].join('\n');
      final missing = <String>[];
      for (final k in keys) {
        final label = uiStrings[k]?['zh-Hans'];
        if (label == null) continue;
        final bare = label.replaceAll('…', '').split('（').first.trim();
        if (!hay.contains(bare)) missing.add('$k ($bare)');
      }
      expect(missing, isEmpty,
          reason: 'menu items the Help page never mentions');
    });

    test('the menu types no accelerator by hand', () {
      // `shortcut: 'Ctrl+L'` sat beside "Command line" a month after
      // the key moved to F2. Accelerators now come from the table.
      final src =
          File('lib/pages/workbench_page.dart').readAsStringSync();
      expect(RegExp(r"shortcut:\s*'").hasMatch(src), isFalse);
    });
  });

  group('the keys the page prints are the keys that work', () {
    test('every label the key tables name exists in all locales', () {
      final labels = <String>{
        for (final k in kReaderShortcuts) k.labelKey,
        for (final k in kCommandLineShortcuts) k.labelKey,
        for (final k in kPlateViewerShortcuts) k.labelKey,
        for (final k in kPickerSheetShortcuts) k.labelKey,
        for (final (_, _, l) in kProjectionKeymap) l,
        for (final s in kWorkbenchShortcuts) s.labelKey,
        kEscapeLabelKey,
      };
      for (final l in labels) {
        for (final loc in _locales) {
          expect(uiStrings[l]?[loc], isNotNull, reason: '$l [$loc]');
        }
      }
      for (final g in helpKeyGroups(apple: false)) {
        expect(kHelpKeyGroupTitles[g.titleKey], isNotNull, reason: g.titleKey);
      }
      expect(kHelpKeyGroupTitles['keysTouch'], isNotNull);
    });

    test('the reading column still binds exactly what it bound before', () {
      // The ten bindings that were typed into its CallbackShortcuts
      // until today, now built from the table. Moving them must not
      // have dropped one or added one.
      final before = <SingleActivator>{
        const SingleActivator(LogicalKeyboardKey.bracketLeft),
        const SingleActivator(LogicalKeyboardKey.bracketRight),
        const SingleActivator(LogicalKeyboardKey.slash),
        const SingleActivator(LogicalKeyboardKey.question, shift: true),
        const SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true),
        const SingleActivator(LogicalKeyboardKey.bracketRight, meta: true),
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true),
        const SingleActivator(LogicalKeyboardKey.comma, meta: true),
        const SingleActivator(LogicalKeyboardKey.bracketLeft, control: true),
        const SingleActivator(LogicalKeyboardKey.bracketRight, control: true),
      };
      String sig(SingleActivator a) =>
          '${a.trigger.keyId}/${a.meta}/${a.control}/${a.shift}';
      expect({for (final k in kReaderShortcuts) sig(k.chord.activator)},
          {for (final a in before) sig(a)});
    });

    test('every projection key is printed, once', () {
      final printed = helpKeyGroups(apple: false)
          .firstWhere((g) => g.titleKey == 'keysProjection')
          .rows;
      expect(printed, hasLength(kProjectionKeymap.length));
      expect(printed.first.keys, '→ · ↓ · Space · Enter');
      // `=` and `+` and the keypad `+` are one key cap to a reader.
      expect(
          printed.firstWhere((r) => r.labelKey == 'projKeyBigger').keys, '+');
    });

    test('a Mac is shown ⌘, a PC is shown Ctrl, neither both', () {
      String reader({required bool apple}) => helpKeyGroups(apple: apple)
          .firstWhere((g) => g.titleKey == 'keysReader')
          .rows
          .map((r) => r.keys)
          .join(' ');
      expect(reader(apple: true), contains('⌘['));
      expect(reader(apple: true), isNot(contains('Ctrl')));
      expect(reader(apple: false), contains('Ctrl+['));
      expect(reader(apple: false), isNot(contains('⌘')));
      expect(reader(apple: false), isNot(contains('Win')));
    });

    test('? is printed as ?, not Shift+?', () {
      final rows = helpKeyGroups(apple: false)
          .firstWhere((g) => g.titleKey == 'keysReader')
          .rows;
      expect(rows.map((r) => r.keys), contains('?'));
    });
  });

  group('search', () {
    test('finds a feature in any language, from either interface', () {
      expect(_ids(searchHelp('投影', kHelpTopics)).first, 'projection');
      expect(_ids(searchHelp('projection', kHelpTopics)).first, 'projection');
      expect(_ids(searchHelp('复制', kHelpTopics)), contains('copy-center'));
      expect(_ids(searchHelp('複製', kHelpTopics)), contains('copy-center'));
      expect(_ids(searchHelp('dark mode', kHelpTopics)).first, 'appearance');
      expect(_ids(searchHelp('深色', kHelpTopics)).first, 'appearance');
    });

    test('finds a feature by its key', () {
      expect(_ids(searchHelp('F4', kHelpTopics)), contains('passage-report'));
      expect(_ids(searchHelp('F2', kHelpTopics)), contains('command-line'));
    });

    test('full-width input is the same query', () {
      expect(normalizeHelpQuery('Ｆ４'), 'f4');
      expect(_ids(searchHelp('Ｆ４', kHelpTopics)),
          _ids(searchHelp('F4', kHelpTopics)));
    });

    test('several words narrow rather than widen', () {
      final one = searchHelp('搜索', kHelpTopics).length;
      final two = searchHelp('搜索 范围', kHelpTopics).length;
      expect(two, lessThan(one));
      expect(_ids(searchHelp('搜索 范围', kHelpTopics)).first, 'scope');
    });

    test('a title match outranks a mention in passing', () {
      final hits = searchHelp('投影', kHelpTopics);
      expect(hits.first.score, greaterThan(hits.last.score));
    });

    test('nothing for nonsense, and nothing for blank', () {
      expect(searchHelp('qqzzxx', kHelpTopics), isEmpty);
      expect(searchHelp('   ', kHelpTopics), isEmpty);
    });
  });

  group('platforms', () {
    test('a topic for one platform is hidden on the others', () {
      final offline = kHelpTopics.firstWhere((t) => t.id == 'offline');
      expect(offline.appliesTo(HelpPlatform.web), isTrue);
      expect(offline.appliesTo(HelpPlatform.macos), isFalse);
    });

    test('every platform has its own page', () {
      for (final p in HelpPlatform.values) {
        expect(
            kHelpTopics.where((t) =>
                t.section == HelpSection.platforms && t.appliesTo(p)),
            hasLength(1),
            reason: p.name);
        expect(kHelpPlatformNames[p], isNotNull, reason: p.name);
      }
    });
  });
}
