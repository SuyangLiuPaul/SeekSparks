import 'package:flutter/material.dart';

import 'package:seeksparks/constants/chronology_filter_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/wheel_history.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/wheel_search.dart'
    show kLifespanLayerId, kReignLayerId, kMinistryLayerId, kLineageLayerId;

/// Only Apply returns a set, including an empty set for "All". Barrier
/// dismissal, back navigation and Cancel return null. The page therefore
/// has one place to update its live filter, after this future completes.
Future<Set<String>?> showChronologyFilterSheet({
  required BuildContext context,
  required String locale,
  required WheelHistoryData data,
  required Set<String> hidden,
  required Map<String, Color> streamColors,
  required Map<String, Color> layerColors,
  required String Function(String key, String fallback) text,
  required String keyPrefix,
}) {
  final initialHidden = Set<String>.of(hidden);
  return showModalBottomSheet<Set<String>>(
    context: context,
    backgroundColor: WbColors.of(context).paneBg,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (sheet) => SizedBox(
      height: MediaQuery.sizeOf(sheet).height * .85,
      child: ChronologyFilterSheet(
        locale: locale,
        data: data,
        initialHidden: initialHidden,
        streamColors: streamColors,
        layerColors: layerColors,
        text: text,
        keyPrefix: keyPrefix,
      ),
    ),
  );
}

class ChronologyFilterSheet extends StatefulWidget {
  const ChronologyFilterSheet({
    super.key,
    required this.locale,
    required this.data,
    required this.initialHidden,
    required this.streamColors,
    required this.layerColors,
    required this.text,
    required this.keyPrefix,
  });

  final String locale;
  final WheelHistoryData data;
  final Set<String> initialHidden;
  final Map<String, Color> streamColors;
  final Map<String, Color> layerColors;
  final String Function(String key, String fallback) text;
  final String keyPrefix;

  @override
  State<ChronologyFilterSheet> createState() => _ChronologyFilterSheetState();
}

class _FilterOption {
  const _FilterOption({
    required this.id,
    required this.keySuffix,
    required this.title,
    required this.subtitle,
    this.color,
    this.narrowSwatch = false,
  });

  final String id;
  final String keySuffix;
  final String title;
  final String subtitle;
  final Color? color;
  final bool narrowSwatch;
}

class _ChronologyFilterSheetState extends State<ChronologyFilterSheet> {
  late final Set<String> _draft;
  late final List<_FilterOption> _options;
  bool _finished = false;

  String _s(String key) => chronologyFilterText(key, widget.locale);

  @override
  void initState() {
    super.initState();
    // The chart owns a mutable set and used to share it with every
    // checkbox. Copy its values once; no draft operation reaches that
    // object, including the All/None shortcuts.
    _draft = Set.of(widget.initialHidden);
    final s = widget.text;
    final powers = <String, int>{};
    final events = <String, int>{};
    for (final power in widget.data.powers) {
      powers.update(power.stream, (count) => count + 1, ifAbsent: () => 1);
    }
    for (final event in widget.data.events) {
      events.update(event.stream, (count) => count + 1, ifAbsent: () => 1);
    }
    _options = [
      _FilterOption(
        id: kLifespanLayerId,
        keySuffix: 'Lifespans',
        title: s('wheelLifespans', 'Genesis lifespans'),
        subtitle: s('wheelLifespansNote', ''),
        color: widget.layerColors[kLifespanLayerId],
      ),
      _FilterOption(
        id: kReignLayerId,
        keySuffix: 'Reigns',
        title: s('wheelReigns', 'Reigns of Judah & Israel'),
        subtitle: s('wheelKingsThiele', 'reigns (Thiele)'),
        color: widget.layerColors[kReignLayerId],
      ),
      _FilterOption(
        id: kMinistryLayerId,
        keySuffix: 'Ministries',
        title: s('wheelMinistries', 'Prophets & apostles'),
        subtitle: s('wheelMinistriesNote', ''),
        color: widget.layerColors[kMinistryLayerId],
      ),
      _FilterOption(
        id: kLineageLayerId,
        keySuffix: 'Lineage',
        title: s('wheelLineage', 'Genealogy (approximate)'),
        subtitle: s('wheelLineageNote', ''),
        color: widget.layerColors[kLineageLayerId],
        narrowSwatch: true,
      ),
      for (final stream in widget.data.streams)
        _FilterOption(
          id: stream.id,
          keySuffix: 'Stream-${stream.id}',
          title: stream.nameFor(widget.locale),
          subtitle: '${s('wheelPowers', 'Powers')} ${powers[stream.id] ?? 0} · '
              '${s('wheelEvents', 'Events')} ${events[stream.id] ?? 0}',
          color: widget.streamColors[stream.id],
        ),
    ];
  }

  void _finish(Set<String>? value) {
    // A rapid second tap while the sheet animates away must not pop
    // the chart route underneath it or return a second application.
    if (_finished) return;
    _finished = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final t = WbType.of(context);
    final chromeSize =
        t.scaledChrome(13).clamp(WbMetrics.smallPrintFloor, double.infinity);
    final buttonText = TextStyle(
      fontFamily: t.fontFamily,
      fontFamilyFallback: kCjkFontFallback,
      fontSize: chromeSize,
      height: 1.25,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(WbMetrics.radiusControl),
    );
    return Material(
      color: wb.paneBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.text('wheelFilter', 'Filter'),
                    style: buttonText.copyWith(
                      color: wb.text,
                      fontSize: t.scaledChrome(15),
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 4),
                Text(_s('draftHint'),
                    style: buttonText.copyWith(color: wb.mutedText)),
              ],
            ),
          ),
          Divider(height: 1, color: wb.border),
          Expanded(
            child: ListView.builder(
              key: const ValueKey('chronologyFilterOptions'),
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: _options.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          key: const ValueKey('chronologyFilterAll'),
                          onPressed: () => setState(_draft.clear),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            textStyle: buttonText,
                            foregroundColor: wb.link,
                          ),
                          child: Text(widget.text('wheelAll', 'All')),
                        ),
                        TextButton(
                          key: const ValueKey('chronologyFilterNone'),
                          onPressed: () => setState(() => _draft
                              .addAll(_options.map((option) => option.id))),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            textStyle: buttonText,
                            foregroundColor: wb.link,
                          ),
                          child: Text(widget.text('wheelNone', 'None')),
                        ),
                      ],
                    ),
                  );
                }
                final option = _options[index - 1];
                return CheckboxListTile(
                  key: ValueKey('${widget.keyPrefix}${option.keySuffix}'),
                  value: !_draft.contains(option.id),
                  onChanged: (visible) => setState(() {
                    if (visible == true) {
                      _draft.remove(option.id);
                    } else {
                      _draft.add(option.id);
                    }
                  }),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(option.title,
                      style: TextStyle(
                        color: wb.text,
                        fontFamily: t.fontFamily,
                        fontFamilyFallback: kCjkFontFallback,
                        fontSize: t.scaledSmall(12.5),
                        height: 1.35,
                      )),
                  subtitle: option.subtitle.isEmpty
                      ? null
                      : Text(option.subtitle,
                          style: TextStyle(
                            color: wb.mutedText,
                            fontFamily: t.fontFamily,
                            fontFamilyFallback: kCjkFontFallback,
                            fontSize: t.scaledSmall(11),
                            height: 1.35,
                          )),
                  secondary: Container(
                    width: option.narrowSwatch ? 3 : 12,
                    height: 12,
                    color: option.color ?? wb.mutedText,
                  ),
                );
              },
            ),
          ),
          // The options scroll; the decision does not. On a short
          // phone sheet, scrolling to its final stream must never be
          // required just to find Apply or to discard the draft.
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: wb.border)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const ValueKey('chronologyFilterCancel'),
                        onPressed: () => _finish(null),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(44, 48),
                          shape: shape,
                          side: BorderSide(color: wb.border),
                          textStyle: buttonText,
                          foregroundColor: wb.text,
                        ),
                        child: Text(_s('cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('chronologyFilterApply'),
                        onPressed: () => _finish(Set.unmodifiable(_draft)),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(44, 48),
                          shape: shape,
                          textStyle: buttonText,
                          backgroundColor: wb.accent,
                          foregroundColor: wb.paneBg,
                        ),
                        child: Text(_s('apply')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
