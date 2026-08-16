import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seeksparks/constants/bible_versions.dart';
import 'package:seeksparks/constants/book_names.dart';
import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/constants/version_attribution.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/services/fetch_verses.dart';
import 'package:seeksparks/utils/copy_format.dart';
import 'package:seeksparks/utils/short_book_name.dart';
import 'package:seeksparks/utils/verse_list.dart';

/// One thing the reader might mean by "copy this" — a label and the
/// references behind it. The host page decides which of these exist,
/// because only it knows whether there is a selection or a result set;
/// the dialog just offers what it is given.
class CopyScope {
  const CopyScope({required this.label, required this.refs});

  final String label;
  final List<VerseRef> refs;
}

const _kCopyOptionsPrefKey = 'workbench.copyOptions';

/// The Copy Center (BibleWorks bwh28 + bwh29's Output Format Options).
///
/// Returns the text the reader chose to copy, or null if they closed
/// without copying. It deliberately does NOT touch the clipboard: the
/// success snackbar has to appear over the workbench, not underneath a
/// dialog that is still up, so the caller pops first and then hands the
/// string to `ClipboardHelper.copyWithFeedback`.
Future<String?> showCopyCenter(
  BuildContext context, {
  required List<CopyScope> scopes,
  required String primaryVersion,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _CopyCenterDialog(
      scopes: scopes,
      primaryVersion: primaryVersion,
    ),
  );
}

class _CopyCenterDialog extends StatefulWidget {
  const _CopyCenterDialog({required this.scopes, required this.primaryVersion});

  final List<CopyScope> scopes;
  final String primaryVersion;

  @override
  State<_CopyCenterDialog> createState() => _CopyCenterDialogState();
}

class _CopyCenterDialogState extends State<_CopyCenterDialog> {
  /// The reader's type scale. A getter rather than a `build` local
  /// because the dialog is assembled by eight small helpers; threading
  /// one value through eight signatures buys nothing, since they are
  /// all invoked synchronously from `build` and the dependency lands on
  /// the same element either way.
  WbType get _t => WbType.of(context);

  CopyOptions _o = const CopyOptions();
  int _scopeIndex = 0;

  /// version code → ref key → raw verse text, for the references in
  /// scope only. Holding whole editions here would duplicate tens of
  /// megabytes that MainProvider already has.
  final Map<String, Map<String, String>> _texts = {};
  final Set<String> _loading = {};

  /// English book name → the name this edition itself uses. Taken from
  /// the loaded verses rather than a table, so a Chinese edition's
  /// copied reference reads in that edition's own vocabulary.
  final Map<String, String> _bookLabels = {};

  late final TextEditingController _template;

  @override
  void initState() {
    super.initState();
    _o = _o.copyWith(versions: [widget.primaryVersion]);
    _template = TextEditingController(text: _o.refTemplate);
    _restore();
  }

  @override
  void dispose() {
    _template.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCopyOptionsPrefKey);
    if (mounted && raw != null) {
      try {
        final stored = CopyOptions.fromJson(
          json.decode(raw) as Map<String, dynamic>,
        );
        // The stored version list can name editions that no longer
        // exist; and if it ends up empty, fall back to what is on
        // screen rather than opening on an empty preview.
        final known = stored.versions
            .where((v) => bibleVersions.any((b) => b.value == v))
            .toList();
        setState(() {
          _o = stored.copyWith(
            versions: known.isEmpty ? [widget.primaryVersion] : known,
          );
          _template.text = _o.refTemplate;
        });
      } catch (_) {
        // A corrupt blob is not worth surfacing — defaults are correct.
      }
    }
    await _ensureLoaded(_o.versions);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCopyOptionsPrefKey, json.encode(_o.toJson()));
  }

  void _set(CopyOptions next) {
    setState(() => _o = next);
    _persist();
    _ensureLoaded(next.versions);
  }

  /// Every reference any scope could ask for. Loading is keyed on this
  /// union so switching scope never waits again.
  Set<String> get _neededKeys => {
        for (final s in widget.scopes)
          for (final r in s.refs) r.key,
      };

  Future<void> _ensureLoaded(List<String> codes) async {
    final keys = _neededKeys;
    for (final code in codes) {
      if (_texts.containsKey(code) || _loading.contains(code)) continue;
      setState(() => _loading.add(code));
      final mp = context.read<MainProvider>();
      final list = mp.peekCachedVersion(code) ??
          await FetchVerses.loadVerseList(code);
      if (!mounted) return;
      setState(() {
        _loading.remove(code);
        _texts[code] = _index(list, keys);
      });
    }
  }

  Map<String, String> _index(List<Verse>? list, Set<String> keys) {
    final out = <String, String>{};
    if (list == null) return out;
    for (final v in list) {
      final english = bookNameToEnglish[v.book] ?? v.book;
      _bookLabels.putIfAbsent(english, () => v.book);
      final key = '$english-${v.chapter}-${v.verse}';
      // The psalm title goes on the clipboard as part of verse 1. The
      // app keeps it typed so it can be SET apart; a pasted handout has
      // no type system, and running it into the verse is what the
      // publishers of the other three editions that carry one did.
      if (keys.contains(key)) {
        out[key] = v.scriptureText;
      }
    }
    return out;
  }

  // ── The output ────────────────────────────────────────────────────

  List<VerseRef> get _scopeRefs =>
      widget.scopes.isEmpty ? const [] : widget.scopes[_scopeIndex].refs;

  /// How many verses this copy is actually allowed to take, and why.
  /// Null means no ceiling applies.
  int? get _limit =>
      _o.includeText && copyIsRestricted(_o.versions)
          ? kLicensedCopyVerseLimit
          : null;

  List<VerseRef> get _effectiveRefs {
    final refs = _scopeRefs;
    final cap = _limit;
    if (cap == null || refs.length <= cap) return refs;
    return normaliseRefs(refs).take(cap).toList();
  }

  String _render(String locale) {
    return formatCopy(
      _effectiveRefs,
      _o,
      bookName: (english, style) {
        final label = _bookLabels[english] ?? english;
        return style == CopyBookStyle.abbreviated
            ? shortBookName(label, locale, widget.primaryVersion)
            : label;
      },
      versionName: (code) => bibleVersions
          .firstWhere(
            (b) => b.value == code,
            orElse: () => BibleVersionInfo(
              value: code,
              shortLabel: code.toUpperCase(),
              menuLabel: code,
              language: 'en',
            ),
          )
          .shortLabel,
      verseText: (code, ref) => _texts[code]?[ref.key],
      attribution: (code) {
        final key = attributionKeyFor(code);
        return key == null ? null : uiStrings[key]?[locale];
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppSettings>().locale;
    final scheme = Theme.of(context).colorScheme;
    final t = _t;
    final text = _render(locale);
    final busy = _loading.isNotEmpty;

    final wide = MediaQuery.sizeOf(context).width >= 900;
    final options = _options(locale, scheme);
    final preview = _preview(locale, scheme, text, busy);

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: wide ? 900 : 560,
          maxHeight: 620,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.copy_all_outlined,
                      size: 20, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _s(locale, 'copyCenterTitle', 'Copy Center'),
                      style: TextStyle(
                        fontSize: t.scaled(16),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: _s(locale, 'close', 'Close'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 12),
              Expanded(
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 420,
                            child: SingleChildScrollView(child: options),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: preview),
                        ],
                      )
                    : ListView(
                        children: [
                          options,
                          const SizedBox(height: 12),
                          SizedBox(height: 200, child: preview),
                        ],
                      ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _footnote(locale, scheme, text)),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(_s(locale, 'cancel', 'Cancel')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.content_copy, size: 16),
                    onPressed: text.isEmpty || busy
                        ? null
                        : () => Navigator.pop(context, text),
                    label: Text(_s(locale, 'copyCenterCopy', 'Copy')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The line under the preview: how many verses are going, and — when
  /// it bites — that the licence, not the app, is what stopped at 500.
  Widget _footnote(String locale, ColorScheme scheme, String text) {
    final total = _scopeRefs.length;
    final taken = _effectiveRefs.length;
    final capped = taken < total;
    final style = TextStyle(
      fontSize: _t.scaled(11),
      color: capped ? scheme.error : scheme.outline,
    );
    if (text.isEmpty) {
      return Text(_s(locale, 'copyCenterEmpty', 'Nothing to copy.'),
          style: style);
    }
    return Text(
      capped
          ? _s(locale, 'copyCenterLimited',
                  'Copying {n} of {total} verses — publisher quotation '
                      'limit for a licensed translation.')
              .replaceAll('{n}', '$taken')
              .replaceAll('{total}', '$total')
          : _s(locale, 'copyCenterCount', '{n} verses')
              .replaceAll('{n}', '$taken'),
      style: style,
    );
  }

  Widget _preview(
    String locale,
    ColorScheme scheme,
    String text,
    bool busy,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
        color: scheme.surfaceContainerLowest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: scheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                Text(
                  _s(locale, 'copyCenterPreview', 'Sample output'),
                  style:
                      TextStyle(fontSize: _t.scaled(11), color: scheme.outline),
                ),
                const Spacer(),
                if (busy)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: SelectableText(
                text.isEmpty
                    ? _s(locale, 'copyCenterEmpty', 'Nothing to copy.')
                    : text,
                style: TextStyle(
                  fontSize: _t.scaled(12.5),
                  height: 1.5,
                  color: text.isEmpty ? scheme.outline : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _options(String locale, ColorScheme scheme) {
    final preset = presetOf(_o);
    // A Column, not a ListView: the narrow layout stacks this above the
    // preview inside one scroll view, and a nested lazy viewport there
    // has no height to be lazy about.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.scopes.length > 1) ...[
          _label(locale, 'copyCenterScope', 'What to copy', scheme),
          Wrap(
            spacing: 6,
            children: [
              for (var i = 0; i < widget.scopes.length; i++)
                ChoiceChip(
                  label: Text(widget.scopes[i].label,
                      style: TextStyle(fontSize: _t.scaled(12))),
                  selected: _scopeIndex == i,
                  onSelected: (_) => setState(() => _scopeIndex = i),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        _label(locale, 'copyCenterPreset', 'Format', scheme),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final p in CopyPreset.values)
              ChoiceChip(
                label: Text(_presetLabel(locale, p),
                    style: TextStyle(fontSize: _t.scaled(12))),
                selected: preset == p,
                // "Custom" describes the state; it is not something you
                // can switch INTO, so selecting it would have to mean
                // something and does not.
                onSelected: p == CopyPreset.custom
                    ? null
                    : (_) {
                        final next = optionsForPreset(p)
                            .copyWith(versions: _o.versions);
                        _template.text = next.refTemplate;
                        _set(next);
                      },
              ),
          ],
        ),
        const SizedBox(height: 12),
        _label(locale, 'copyCenterVersions', 'Versions', scheme),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final v in availableVersions)
              FilterChip(
                label: Text(v.shortLabel,
                    style: TextStyle(fontSize: _t.scaled(12))),
                selected: _o.versions.contains(v.value),
                onSelected: (on) {
                  final next = [..._o.versions];
                  if (on) {
                    next.add(v.value);
                  } else {
                    next.remove(v.value);
                  }
                  _set(_o.copyWith(versions: next));
                },
              ),
          ],
        ),
        const SizedBox(height: 4),
        _switch(
          locale,
          'copyCenterIncludeText',
          'Include the verse text',
          _o.includeText,
          (v) => _set(_o.copyWith(includeText: v)),
        ),
        if (_o.includeText) ...[
          const Divider(height: 20),
          _label(locale, 'copyCenterReference', 'Reference', scheme),
          _dropdown<CopyRefScope>(
            value: _o.refScope,
            items: {
              CopyRefScope.passage:
                  _s(locale, 'copyRefPassage', 'Once, for the whole passage'),
              CopyRefScope.perVerse:
                  _s(locale, 'copyRefPerVerse', 'On every verse'),
              CopyRefScope.none: _s(locale, 'copyRefNone', 'No reference'),
            },
            onChanged: (v) => _set(_o.copyWith(refScope: v)),
          ),
          if (_o.refScope != CopyRefScope.none) ...[
            const SizedBox(height: 6),
            _dropdown<CopyRefPlacement>(
              value: _o.refPlacement,
              items: {
                CopyRefPlacement.before:
                    _s(locale, 'copyRefBefore', 'Before the text'),
                CopyRefPlacement.after:
                    _s(locale, 'copyRefAfter', 'After the text'),
              },
              onChanged: (v) => _set(_o.copyWith(refPlacement: v)),
            ),
            const SizedBox(height: 6),
            _dropdown<CopyBookStyle>(
              value: _o.bookStyle,
              items: {
                CopyBookStyle.full:
                    _s(locale, 'copyBookFull', 'Full book name'),
                CopyBookStyle.abbreviated:
                    _s(locale, 'copyBookShort', 'Abbreviated'),
              },
              onChanged: (v) => _set(_o.copyWith(bookStyle: v)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _template,
              style: TextStyle(fontSize: _t.scaled(12)),
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                labelText: _s(locale, 'copyCenterTemplate', 'Reference format'),
                helperMaxLines: 2,
                helperStyle: TextStyle(fontSize: _t.scaled(10)),
                helperText: _s(locale, 'copyCenterTemplateHelp',
                    r'Tags: <ref> <book> <chapter> <verse> <version>'),
              ),
              onChanged: (v) => _set(_o.copyWith(refTemplate: v)),
            ),
          ],
          const Divider(height: 20),
          _label(locale, 'copyCenterText', 'Text', scheme),
          // Verse numbers are already inside a per-verse reference, so
          // offering the switch there would offer a duplicate.
          if (_o.refScope == CopyRefScope.passage)
            _switch(
              locale,
              'copyCenterVerseNumbers',
              'Verse numbers in the text',
              _o.inlineVerseNumbers,
              (v) => _set(_o.copyWith(inlineVerseNumbers: v)),
            ),
          _switch(
            locale,
            'copyCenterOnePerLine',
            'One verse per line',
            _o.newlinePerVerse,
            (v) => _set(_o.copyWith(newlinePerVerse: v)),
          ),
          _switch(
            locale,
            'copyCenterQuote',
            'Wrap in quotation marks',
            _o.quoteText,
            (v) => _set(_o.copyWith(quoteText: v)),
          ),
          _switch(
            locale,
            'copyCenterBrackets',
            'Keep [supplied words] in brackets',
            _o.keepSuppliedBrackets,
            (v) => _set(_o.copyWith(keepSuppliedBrackets: v)),
          ),
          _switch(
            locale,
            'copyCenterNotes',
            "Include translators' notes",
            _o.includeNotes,
            (v) => _set(_o.copyWith(includeNotes: v)),
          ),
          if (_o.versions.length > 1)
            _switch(
              locale,
              'copyCenterInterleave',
              'Group by verse, not by version',
              _o.interleave,
              (v) => _set(_o.copyWith(interleave: v)),
            ),
        ] else ...[
          const Divider(height: 20),
          _label(locale, 'copyCenterRefList', 'Reference list', scheme),
          _switch(
            locale,
            'copyCenterMerge',
            'Merge consecutive verses into ranges',
            _o.mergeConsecutive,
            (v) => _set(_o.copyWith(mergeConsecutive: v)),
          ),
          _switch(
            locale,
            'copyCenterRefPerLine',
            'One reference per line',
            _o.refListOnePerLine,
            (v) => _set(_o.copyWith(refListOnePerLine: v)),
          ),
        ],
        const Divider(height: 20),
        _switch(
          locale,
          'copyCenterAttribution',
          'Append the copyright line',
          _o.includeAttribution,
          (v) => _set(_o.copyWith(includeAttribution: v)),
        ),
      ],
    );
  }

  // ── Small building blocks ─────────────────────────────────────────

  String _s(String locale, String key, String fallback) =>
      uiStrings[key]?[locale] ?? fallback;

  String _presetLabel(String locale, CopyPreset p) => switch (p) {
        CopyPreset.sermon => _s(locale, 'copyPresetSermon', 'Handout'),
        CopyPreset.citation => _s(locale, 'copyPresetCitation', 'Citation'),
        CopyPreset.referenceList =>
          _s(locale, 'copyPresetRefList', 'References only'),
        CopyPreset.plain => _s(locale, 'copyPresetPlain', 'Plain text'),
        CopyPreset.custom => _s(locale, 'copyPresetCustom', 'Custom'),
      };

  Widget _label(
    String locale,
    String key,
    String fallback,
    ColorScheme scheme,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          _s(locale, key, fallback),
          style: TextStyle(
            fontSize: _t.scaled(11),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: scheme.primary,
          ),
        ),
      );

  Widget _switch(
    String locale,
    String key,
    String fallback,
    bool value,
    ValueChanged<bool> onChanged,
  ) =>
      SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(_s(locale, key, fallback),
            style: TextStyle(fontSize: _t.scaled(12.5))),
        value: value,
        onChanged: onChanged,
      );

  Widget _dropdown<T>({
    required T value,
    required Map<T, String> items,
    required ValueChanged<T> onChanged,
  }) =>
      DropdownButtonFormField<T>(
        initialValue: value,
        isDense: true,
        style: TextStyle(
          fontSize: _t.scaled(12.5),
          color: Theme.of(context).colorScheme.onSurface,
        ),
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
        items: [
          for (final e in items.entries)
            DropdownMenuItem<T>(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      );
}
