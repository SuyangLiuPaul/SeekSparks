/// The Help page — every feature, where it lives, how it differs by
/// platform, and every key, with a search box over all of it.
///
/// 2026-09-18, 「sword所有的shortcut和一些help doc是不是应该有一个page
/// 教我们怎么用」. What it replaced: two shortcut dialogs that disagreed
/// with each other (the workbench's listed five keys, the reading
/// column's four; the app binds forty-nine), and no description of any
/// feature anywhere inside the app. The model and its rules are in
/// `help_catalog.dart`; the words are in `help_topics.dart`.
///
/// Opened from Help › Help & shortcuts, F1, and `?` in the text.
library;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';

import 'package:yahwehs_sword/constants/help_topics.dart';
import 'package:yahwehs_sword/constants/projection_strings.dart';
import 'package:yahwehs_sword/constants/ui_strings.dart';
import 'package:yahwehs_sword/constants/workbench_theme.dart';
import 'package:yahwehs_sword/models/app_settings.dart';
import 'package:yahwehs_sword/pages/jesus_teachings_page.dart'
    show kJesusTeachingsTitle;
import 'package:yahwehs_sword/pages/projection_page.dart'
    show kProjectionKeymap;
import 'package:yahwehs_sword/pages/strip_chronology_page.dart'
    show kStripPageTitle;
import 'package:yahwehs_sword/utils/app_nav.dart';
import 'package:yahwehs_sword/utils/app_scroll_behavior.dart'
    show kSelectableTextPhysics;
import 'package:yahwehs_sword/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:yahwehs_sword/utils/help_catalog.dart';
import 'package:yahwehs_sword/utils/keyboard_shortcuts.dart';
import 'package:yahwehs_sword/widgets/home_icon_button.dart';
import 'package:yahwehs_sword/widgets/language_switcher_button.dart';
import 'package:yahwehs_sword/widgets/localized_back_button.dart';

/// Open the Help page, optionally at [section] or already searching
/// [query].
Future<void> openHelp(
  BuildContext context, {
  HelpSection? section,
  String? query,
}) async {
  await pushPage(HelpPage(initialSection: section, initialQuery: query));
}

/// Who opens a [HelpDestination]. The workbench registers itself while
/// it is mounted, and its menu dispatches through the same method, so
/// "Take me there" does exactly what the menu item does — including the
/// ones that are not pages at all (the command line, the scope sheet,
/// the Copy Center), which only the workbench can reach.
///
/// Null outside a workbench (a test, a preview): the page then hides the
/// button rather than offer a door that opens nothing.
void Function(HelpDestination)? helpDestinationHandler;

/// Destinations that act on the workbench rather than open a page, so
/// the Help page has to get out of the way first.
const Set<HelpDestination> kHelpWorkbenchActions = {
  HelpDestination.commandLine,
  HelpDestination.searchScope,
  HelpDestination.chooseVersions,
  HelpDestination.copyCenter,
  HelpDestination.passageReport,
  HelpDestination.checkForUpdates,
};

/// The device the page describes by default.
HelpPlatform currentHelpPlatform() {
  if (kIsWeb) return HelpPlatform.web;
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => HelpPlatform.ios,
    TargetPlatform.android => HelpPlatform.android,
    TargetPlatform.macOS => HelpPlatform.macos,
    TargetPlatform.windows => HelpPlatform.windows,
    _ => HelpPlatform.linux,
  };
}

/// Whether keys should be printed with ⌘ for [p]. The web follows the
/// keyboard of the machine the browser runs on.
bool helpUsesAppleKeys(HelpPlatform p) => switch (p) {
      HelpPlatform.macos || HelpPlatform.ios => true,
      HelpPlatform.web => defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.iOS,
      _ => false,
    };

// ── The key tables, as the page prints them ─────────────────────────

class HelpKeyRow {
  const HelpKeyRow(this.keys, this.labelKey);

  /// Every chord that does it, e.g. `[ · ⌘[`.
  final String keys;
  final String labelKey;

  String label(String locale) =>
      uiStrings[labelKey]?[locale] ?? uiStrings[labelKey]?['en'] ?? labelKey;
}

class HelpKeyGroup {
  const HelpKeyGroup(this.titleKey, this.rows);
  final String titleKey;
  final List<HelpKeyRow> rows;
}

/// Rows with the same action are one row with several chords, in the
/// order the table lists them.
List<HelpKeyRow> _merge(Iterable<(String, String)> chords) {
  final order = <String>[];
  final keys = <String, List<String>>{};
  for (final (k, label) in chords) {
    if (!keys.containsKey(label)) order.add(label);
    final list = keys.putIfAbsent(label, () => []);
    if (!list.contains(k)) list.add(k);
  }
  return [for (final l in order) HelpKeyRow(keys[l]!.join(' · '), l)];
}

/// Every key the app answers, grouped by where it works — read straight
/// from the tables the handlers dispatch from.
List<HelpKeyGroup> helpKeyGroups({required bool apple}) {
  return [
    HelpKeyGroup('keysWorkbench', [
      for (final s in kWorkbenchShortcuts)
        HelpKeyRow(s.label(mac: apple), s.labelKey),
      // Documented, not dispatched: see `kEscapeLabelKey`.
      const HelpKeyRow('Esc', kEscapeLabelKey),
    ]),
    HelpKeyGroup(
      'keysReader',
      _merge([
        for (final k in kReaderShortcuts)
          if (k.chord.shownOn(apple: apple))
            (k.chord.label(mac: apple), k.labelKey),
      ]),
    ),
    HelpKeyGroup(
      'keysCommandLine',
      _merge([
        for (final k in kCommandLineShortcuts)
          (k.chord.label(mac: apple), k.labelKey),
      ]),
    ),
    HelpKeyGroup('keysProjection', [
      for (final (_, keys, labelKey) in kProjectionKeymap)
        HelpKeyRow(
          {for (final k in keys) keyCapLabel(k)}.join(' · '),
          labelKey,
        ),
    ]),
    HelpKeyGroup(
      'keysPlateViewer',
      _merge([
        for (final k in kPlateViewerShortcuts)
          (k.chord.label(mac: apple), k.labelKey),
      ]),
    ),
    HelpKeyGroup(
      'keysPickers',
      _merge([
        for (final k in kPickerSheetShortcuts)
          (k.chord.label(mac: apple), k.labelKey),
      ]),
    ),
  ];
}

/// Menu labels the path of a topic can name that live outside
/// `ui_strings` — the maps the menu itself reads, so the path still
/// prints the menu's own words.
void registerHelpExtraLabels() {
  kHelpExtraLabels['jesusTeachingsTitle'] = kJesusTeachingsTitle;
  kHelpExtraLabels['stripPageTitle'] = kStripPageTitle;
  final projection = projectionStrings['projectionTitle'];
  if (projection != null) kHelpExtraLabels['projectionTitle'] = projection;
}

// ── The page ────────────────────────────────────────────────────────

class HelpPage extends StatefulWidget {
  const HelpPage({super.key, this.initialSection, this.initialQuery});

  final HelpSection? initialSection;
  final String? initialQuery;

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  late final TextEditingController _query =
      TextEditingController(text: widget.initialQuery ?? '');
  final _scroll = ScrollController();
  final _sectionKeys = {for (final s in HelpSection.values) s: GlobalKey()};
  /// Topics opened while browsing, and topics closed while searching —
  /// the two views start from opposite defaults.
  final _expanded = <String>{};
  final _collapsed = <String>{};
  late HelpPlatform _platform = currentHelpPlatform();

  @override
  void initState() {
    super.initState();
    registerHelpExtraLabels();
    final s = widget.initialSection;
    if (s != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpTo(s));
    }
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _jumpTo(HelpSection s) {
    final ctx = _sectionKeys[s]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 250), alignment: 0);
  }

  List<HelpTopic> get _topics =>
      [for (final t in kHelpTopics) if (t.appliesTo(_platform)) t];

  void _open(HelpDestination d) {
    final handler = helpDestinationHandler;
    if (handler == null) return;
    if (kHelpWorkbenchActions.contains(d)) {
      // `pop`, not `maybePop`: the latter awaits `willPop` first, so the
      // handler's dialog was pushed ABOVE this page and the pop then
      // found something else on top. Seen in a browser, 2026-09-18.
      Navigator.of(context).pop();
    }
    handler(d);
  }

  String _s(String key, String fallback, String locale) =>
      uiStrings[key]?[locale] ?? fallback;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    final c = WbColors.of(context);
    final t = WbType.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final query = _query.text.trim();

    return Scaffold(
      backgroundColor: c.paneBg,
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(_s('helpTitle', 'Help & shortcuts', locale)),
        actions: const [LanguageSwitcherButton(), HomeIconButton()],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toolbar(c, t, locale),
          Container(height: WbMetrics.hairline, color: c.border),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (wide && query.isEmpty) ...[
                  SizedBox(width: 200, child: _index(c, t, locale)),
                  Container(width: WbMetrics.hairline, color: c.border),
                ],
                Expanded(
                  child: query.isEmpty
                      ? _browse(c, t, locale, wide: wide)
                      : _results(c, t, locale, query),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Toolbar: search + platform ────────────────────────────────────

  Widget _toolbar(WbColors c, WbType t, String locale) {
    final touch = helpPlatformIsTouch(currentHelpPlatform());
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: c.border, width: WbMetrics.hairline),
    );
    return Container(
      color: c.chromeBg,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, minWidth: 240),
            child: TextField(
              controller: _query,
              // A keyboard on the desk means the reader came here to
              // type; on a touch screen an unasked-for keyboard covers
              // half the page they came to read.
              autofocus: !touch,
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                fontSize: t.scaled(13),
                color: c.text,
                fontFamilyFallback: kCjkFontFallback,
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: c.paneBg,
                hintText: _s('helpSearchHint',
                    'Search features and keys — e.g. projection, copy, F4',
                    locale),
                hintStyle: TextStyle(
                  fontSize: t.scaled(13),
                  color: c.mutedText,
                  fontFamilyFallback: kCjkFontFallback,
                ),
                prefixIcon:
                    Icon(Icons.search, size: t.scaled(17), color: c.mutedText),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close,
                            size: t.scaled(15), color: c.mutedText),
                        tooltip: _s('close', 'Clear', locale),
                        onPressed: () => setState(_query.clear),
                      ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                border: border,
                enabledBorder: border,
                focusedBorder: border.copyWith(
                    borderSide:
                        BorderSide(color: c.text, width: WbMetrics.hairline)),
              ),
            ),
          ),
          _platformPicker(c, t, locale),
        ],
      ),
    );
  }

  Widget _platformPicker(WbColors c, WbType t, String locale) {
    final here = currentHelpPlatform();
    String name(HelpPlatform p) {
      final n = kHelpPlatformNames[p]!.of(locale);
      return p == here ? '$n ${_s('helpThisDevice', '(this device)', locale)}' : n;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _s('helpPlatformLabel', 'Describe for', locale),
          style: TextStyle(fontSize: t.scaledChrome(12), color: c.mutedText),
        ),
        const SizedBox(width: 6),
        PopupMenuButton<HelpPlatform>(
          tooltip: _s('helpPlatformLabel', 'Describe for', locale),
          initialValue: _platform,
          onSelected: (p) => setState(() => _platform = p),
          itemBuilder: (_) => [
            for (final p in HelpPlatform.values)
              PopupMenuItem(value: p, child: Text(name(p))),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: c.border, width: WbMetrics.hairline),
              color: c.paneBg,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name(_platform),
                    style: TextStyle(fontSize: t.text, color: c.text)),
                Icon(Icons.arrow_drop_down, size: t.scaled(18), color: c.text),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Browsing: index + sections ────────────────────────────────────

  Widget _index(WbColors c, WbType t, String locale) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final s in HelpSection.values)
          InkWell(
            onTap: () => _jumpTo(s),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Text(
                kHelpSectionNames[s]!.of(locale),
                style: TextStyle(
                  fontSize: t.scaled(13),
                  color: c.link,
                  fontFamilyFallback: kCjkFontFallback,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _browse(WbColors c, WbType t, String locale, {required bool wide}) {
    final topics = _topics;
    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!wide) _sectionChips(c, t, locale),
              for (final s in HelpSection.values) ...[
                _sectionHeading(c, t, locale, s),
                if (s == HelpSection.shortcuts)
                  ..._shortcuts(c, t, locale)
                else
                  for (final topic in topics.where((x) => x.section == s))
                    _topicTile(c, t, locale, topic,
                        expanded: _expanded.contains(topic.id),
                        onToggle: () => setState(() {
                              if (!_expanded.remove(topic.id)) {
                                _expanded.add(topic.id);
                              }
                            })),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionChips(WbColors c, WbType t, String locale) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in HelpSection.values)
              InkWell(
                onTap: () => _jumpTo(s),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: c.border, width: WbMetrics.hairline),
                  ),
                  child: Text(kHelpSectionNames[s]!.of(locale),
                      style: TextStyle(fontSize: t.text, color: c.link)),
                ),
              ),
          ],
        ),
      );

  Widget _sectionHeading(
          WbColors c, WbType t, String locale, HelpSection s) =>
      Padding(
        key: _sectionKeys[s],
        padding: const EdgeInsets.only(top: 22, bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              kHelpSectionNames[s]!.of(locale),
              style: TextStyle(
                fontSize: t.scaled(17),
                fontWeight: FontWeight.w700,
                color: c.text,
                fontFamilyFallback: kCjkFontFallback,
              ),
            ),
            const SizedBox(height: 6),
            Container(height: WbMetrics.hairline, color: c.border),
          ],
        ),
      );

  // ── One topic ─────────────────────────────────────────────────────

  Widget _topicTile(WbColors c, WbType t, String locale, HelpTopic topic,
      {required bool expanded, required VoidCallback onToggle}) {
    final body = topic.body.of(locale);
    final firstLine = body.split('\n').first;
    return Container(
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: c.border, width: WbMetrics.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(expanded ? Icons.expand_more : Icons.chevron_right,
                      size: t.scaled(18), color: c.mutedText),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topic.title.of(locale),
                          style: TextStyle(
                            fontSize: t.scaled(14),
                            fontWeight: FontWeight.w600,
                            color: c.text,
                            fontFamilyFallback: kCjkFontFallback,
                          ),
                        ),
                        if (!expanded)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              firstLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: t.text,
                                color: c.mutedText,
                                fontFamilyFallback: kCjkFontFallback,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 0, 0, 14),
              child: _topicBody(c, t, locale, topic),
            ),
        ],
      ),
    );
  }

  Widget _topicBody(WbColors c, WbType t, String locale, HelpTopic topic) {
    final prose = TextStyle(
      fontSize: t.scaled(13),
      height: 1.55,
      color: c.text,
      fontFamilyFallback: kCjkFontFallback,
    );
    final note = topic.notes[_platform];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (topic.path.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '${_s('helpWhere', 'Where', locale)}  ',
                  style: TextStyle(color: c.mutedText),
                ),
                TextSpan(
                  text: [
                    for (final k in topic.path) helpPathLabel(k, locale)
                  ].join(' › '),
                  style:
                      TextStyle(color: c.link, fontWeight: FontWeight.w600),
                ),
              ]),
              style: TextStyle(
                  fontSize: t.text, fontFamilyFallback: kCjkFontFallback),
            ),
          ),
        ..._paragraphs(topic.body.of(locale), prose),
        if (topic.examples.isNotEmpty) _examples(c, t, locale, topic.examples),
        if (note != null)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: c.paneAltBg,
              border: Border(left: BorderSide(color: c.link, width: 2)),
            ),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '${kHelpPlatformNames[_platform]!.of(locale)}　',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: note.of(locale)),
              ]),
              style: prose,
            ),
          ),
        if (topic.open != null && helpDestinationHandler != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.link, width: WbMetrics.hairline),
                foregroundColor: c.link,
              ),
              icon: Icon(Icons.arrow_forward, size: t.scaled(15)),
              label: Text(_s('helpTakeMeThere', 'Take me there', locale)),
              onPressed: () => _open(topic.open!),
            ),
          ),
      ],
    );
  }

  List<Widget> _paragraphs(String text, TextStyle style) {
    final out = <Widget>[];
    for (final para in text.split('\n\n')) {
      final lines = para.split('\n');
      final bullets = lines.every((l) => l.startsWith('• '));
      if (bullets) {
        for (final l in lines) {
          out.add(Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: style),
                Expanded(
                  child: SelectableText(l.substring(2),
                      style: style,
                      scrollPhysics: kSelectableTextPhysics),
                ),
              ],
            ),
          ));
        }
        out.add(const SizedBox(height: 6));
      } else {
        // A paragraph whose later lines are bullets: the lead-in, then
        // the list.
        final lead = lines.takeWhile((l) => !l.startsWith('• ')).join('\n');
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: SelectableText(lead,
              style: style, scrollPhysics: kSelectableTextPhysics),
        ));
        final rest = lines.skipWhile((l) => !l.startsWith('• ')).toList();
        if (rest.isNotEmpty) out.addAll(_paragraphs(rest.join('\n'), style));
      }
    }
    return out;
  }

  /// The command-line grammar lines, from the same keys the command
  /// line's own `?` card prints. Tapping one copies the query part.
  Widget _examples(
      WbColors c, WbType t, String locale, List<String> keys) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        border: Border.all(color: c.border, width: WbMetrics.hairline),
        color: c.paneAltBg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final k in keys)
            InkWell(
              onTap: () => _copyExample(uiStrings[k]?[locale] ?? '', locale),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: _exampleLine(c, t, uiStrings[k]?[locale] ?? k),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
            child: Text(
              _s('helpExampleTapHint', 'Tap a line to copy its query.',
                  locale),
              style: TextStyle(fontSize: t.chrome, color: c.mutedText),
            ),
          ),
        ],
      ),
    );
  }

  /// `query — explanation`, with the query set apart.
  Widget _exampleLine(WbColors c, WbType t, String line) {
    final i = line.indexOf(' — ');
    final q = i < 0 ? line : line.substring(0, i);
    final rest = i < 0 ? '' : line.substring(i);
    return Text.rich(
      TextSpan(children: [
        TextSpan(
          text: q,
          style: TextStyle(fontWeight: FontWeight.w700, color: c.link),
        ),
        TextSpan(text: rest, style: TextStyle(color: c.text)),
      ]),
      style: TextStyle(
          fontSize: t.scaled(13), height: 1.4, fontFamilyFallback: kCjkFontFallback),
    );
  }

  Future<void> _copyExample(String line, String locale) async {
    final i = line.indexOf(' — ');
    final q = (i < 0 ? line : line.substring(0, i)).trim();
    if (q.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: q));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${_s('copied', 'Copied', locale)}: $q'),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Shortcuts ─────────────────────────────────────────────────────

  List<Widget> _shortcuts(WbColors c, WbType t, String locale,
      {String? filter}) {
    final apple = helpUsesAppleKeys(_platform);
    final touch = helpPlatformIsTouch(_platform);
    final groups = helpKeyGroups(apple: apple);
    final f = filter == null ? null : normalizeHelpQuery(filter);
    bool keep(HelpKeyRow r) {
      if (f == null) return true;
      final hay = [
        r.keys,
        ...?uiStrings[r.labelKey]?.values,
      ].map(normalizeHelpQuery).join('\n');
      return f
          .split(RegExp(r'\s+'))
          .where((x) => x.isNotEmpty)
          .every(hay.contains);
    }

    final children = <Widget>[];
    if (touch && f == null) {
      children.add(_keyGroup(c, t, locale, 'keysTouch', [
        for (final (g, e) in kHelpTouchGestures) (g.of(locale), e.of(locale)),
      ]));
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          _s('helpTouchKeyboardNote',
              'With a keyboard attached, the keys below work too.', locale),
          style: TextStyle(fontSize: t.text, color: c.mutedText),
        ),
      ));
    }
    for (final g in groups) {
      final rows = g.rows.where(keep).toList();
      if (rows.isEmpty) continue;
      children.add(_keyGroup(c, t, locale, g.titleKey,
          [for (final r in rows) (r.keys, r.label(locale))]));
    }
    return children;
  }

  Widget _keyGroup(WbColors c, WbType t, String locale, String titleKey,
      List<(String, String)> rows) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kHelpKeyGroupTitles[titleKey]?.of(locale) ?? titleKey,
            style: TextStyle(
              fontSize: t.scaled(13),
              fontWeight: FontWeight.w700,
              color: c.link,
              fontFamilyFallback: kCjkFontFallback,
            ),
          ),
          const SizedBox(height: 4),
          for (final (keys, what) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 168,
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final k in keys.split(' · '))
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: c.paneAltBg,
                              border: Border.all(
                                  color: c.border, width: WbMetrics.hairline),
                            ),
                            child: Text(
                              k,
                              style: TextStyle(
                                fontSize: t.text,
                                fontWeight: FontWeight.w600,
                                color: c.text,
                                fontFamilyFallback: kCjkFontFallback,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      what,
                      style: TextStyle(
                        fontSize: t.scaled(13),
                        color: c.text,
                        fontFamilyFallback: kCjkFontFallback,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Search results ────────────────────────────────────────────────

  Widget _results(WbColors c, WbType t, String locale, String query) {
    final hits = searchHelp(query, _topics);
    final keys = _shortcuts(c, t, locale, filter: query);
    final hasKeys = keys.isNotEmpty;
    final count = hits.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
      children: [
        Text(
          count == 0 && !hasKeys
              ? _s('helpNoResults',
                  'Nothing found. Try another word, or switch the platform above.',
                  locale)
              : _s('helpResultCount', '{n} found', locale)
                  .replaceAll('{n}', '$count'),
          style: TextStyle(fontSize: t.text, color: c.mutedText),
        ),
        const SizedBox(height: 6),
        for (final h in hits)
          _topicTile(c, t, locale, h.topic,
              // Results open expanded: the reader asked a question, and
              // a list of titles is not an answer.
              expanded: !_collapsed.contains(h.topic.id),
              onToggle: () => setState(() {
                    if (!_collapsed.remove(h.topic.id)) {
                      _collapsed.add(h.topic.id);
                    }
                  })),
        if (hasKeys) ...[
          _sectionHeading(c, t, locale, HelpSection.shortcuts),
          ...keys,
        ],
      ],
    );
  }
}
