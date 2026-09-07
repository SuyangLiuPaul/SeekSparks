/// The Command Line Assistant's surface — bwh16.
///
/// It writes a line into the command line and closes. It does not run
/// the search, and that is the whole design: an assistant that ran it
/// would teach nothing and have to be reopened every time, where one
/// that leaves its work in the box gives the reader a line they can read,
/// edit and type themselves next time. §3.1 asked for exactly that —
/// *"writes it into the command line so the reader can see the syntax it
/// produced."*
///
/// The shapes are named by what they DO, never by their control
/// character: "all of them, same verse" rather than "AND (`.`)". The
/// reader who needs this sheet is the one who does not know what `.`
/// means, and the line the sheet produces is where they will meet it.
library;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/utils/command_builder.dart';
import 'package:seeksparks/widgets/wb_pane_bits.dart' show WbPaneChip;

/// Returns the line the reader built, or null if they closed the sheet.
Future<String?> showCommandBuilder(BuildContext context, String locale) {
  return showDialog<String>(
    context: context,
    builder: (_) => _CommandBuilderSheet(locale: locale),
  );
}

class _CommandBuilderSheet extends StatefulWidget {
  const _CommandBuilderSheet({required this.locale});
  final String locale;

  @override
  State<_CommandBuilderSheet> createState() => _CommandBuilderSheetState();
}

class _CommandBuilderSheetState extends State<_CommandBuilderSheet> {
  BuiltQuery _q = const BuiltQuery();
  final _term = TextEditingController();
  final _termFocus = FocusNode();

  @override
  void dispose() {
    _term.dispose();
    _termFocus.dispose();
    super.dispose();
  }

  String _s(String key, String fallback) =>
      uiStrings[key]?[widget.locale] ?? fallback;

  void _add() {
    final next = _q.withTerm(_term.text);
    if (identical(next, _q)) return;
    setState(() => _q = next);
    _term.clear();
    // Straight back to typing: adding terms is the loop this sheet
    // exists for, and reaching for the field between each one is the
    // friction that sends a reader back to guessing at syntax.
    _termFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final c = WbColors.of(context);
    final t = WbType.of(context);
    const kinds = <(BuiltQueryKind, String, String)>[
      (BuiltQueryKind.and, 'builderKindAnd', 'All of them, same verse'),
      (BuiltQueryKind.or, 'builderKindOr', 'Any of them'),
      (BuiltQueryKind.phrase, 'builderKindPhrase',
          'Next to each other, in order'),
      (BuiltQueryKind.linearPhrase, 'builderKindLinear',
          'The same, across verse breaks'),
    ];

    return AlertDialog(
      backgroundColor: c.paneBg,
      title: Text(_s('builderTitle', 'Build a search'),
          style: TextStyle(fontSize: t.text, color: c.text)),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final k in kinds)
                  WbPaneChip(
                    label: _s(k.$2, k.$3),
                    on: _q.kind == k.$1,
                    onTap: () => setState(() => _q = _q.withKind(k.$1)),
                    foreground: _q.kind == k.$1 ? c.link : c.text,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _term,
                    focusNode: _termFocus,
                    autofocus: true,
                    onSubmitted: (_) => _add(),
                    style: TextStyle(fontSize: t.chrome, color: c.text),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: _s('builderAddWord', 'Add a word'),
                      hintStyle: TextStyle(
                          fontSize: t.chrome, color: c.mutedText),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                WbPaneChip(
                  label: '+',
                  on: false,
                  onTap: _add,
                  foreground: c.link,
                ),
              ],
            ),
            if (_q.terms.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < _q.terms.length; i++)
                    WbPaneChip(
                      label: '${_q.terms[i]} ×',
                      on: false,
                      onTap: () => setState(() => _q = _q.removeTerm(i)),
                      foreground: c.text,
                    ),
                ],
              ),
            ],
            // Offered only where `;N` means what the reader will read it
            // to mean — the two shapes whose terms are independent.
            if (_q.kind.takesVerseContext) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final n in const <int?>[null, 5, 10, 20])
                    WbPaneChip(
                      label: n == null
                          ? _s('builderNoContext', 'same verse')
                          : _s('builderWithin', 'within {n} verses')
                              .replaceAll('{n}', '$n'),
                      on: _q.verseContext == n,
                      onTap: () =>
                          setState(() => _q = _q.withVerseContext(n)),
                      foreground:
                          _q.verseContext == n ? c.link : c.text,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.paneAltBg,
                border: Border.all(color: c.border),
              ),
              // The line itself, always visible. This is the teaching:
              // the reader watches the syntax appear as they answer
              // questions about meaning.
              child: Text(
                _q.line.isEmpty
                    ? _s(_q.blockedReasonKey ?? 'builderNeedsTerm',
                        'Add a word first')
                    : _q.line,
                style: TextStyle(
                  fontSize: t.chrome,
                  color: _q.line.isEmpty ? c.mutedText : c.link,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_s('cancel', 'Cancel'),
              style: TextStyle(fontSize: t.chrome, color: c.mutedText)),
        ),
        TextButton(
          onPressed:
              _q.isRunnable ? () => Navigator.of(context).pop(_q.line) : null,
          child: Text(_s('builderUse', 'Put it on the command line'),
              style: TextStyle(fontSize: t.chrome, color: c.link)),
        ),
      ],
    );
  }
}
