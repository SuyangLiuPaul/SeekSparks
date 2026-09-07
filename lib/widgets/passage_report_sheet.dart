/// The Report Generator's surface — bwh28.
///
/// One sheet, five switches and a preview. It is deliberately not the
/// Copy Center: the Copy Center answers "which verses, in what format",
/// and this answers "what should the study notes contain". They share
/// the exit — `ClipboardHelper.copyRichWithFeedback` — which is what
/// §3.5's entry meant by *"one export path, not two"*.
///
/// The preview is the point of the sheet. A report is a document you
/// paste somewhere you cannot easily undo, and the filters change its
/// length by an order of magnitude — a reader has to see what they are
/// about to take before they take it.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/models/verse.dart';
import 'package:seeksparks/services/passage_report_service.dart';
import 'package:seeksparks/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:seeksparks/utils/passage_report.dart';
import 'package:seeksparks/widgets/wb_pane_bits.dart' show WbPaneChip;

/// Returns `(html, markdown)` for the caller to put on the clipboard,
/// or null when the reader closed the sheet.
Future<({String html, String markdown})?> showPassageReport(
  BuildContext context, {
  required String title,
  required String versionLabel,
  required String englishBook,
  required List<Verse> verses,
  String? licence,
}) {
  return showDialog<({String html, String markdown})>(
    context: context,
    builder: (_) => _PassageReportDialog(
      title: title,
      versionLabel: versionLabel,
      englishBook: englishBook,
      verses: verses,
      licence: licence,
    ),
  );
}

class _PassageReportDialog extends StatefulWidget {
  const _PassageReportDialog({
    required this.title,
    required this.versionLabel,
    required this.englishBook,
    required this.verses,
    this.licence,
  });

  final String title;
  final String versionLabel;
  final String englishBook;
  final List<Verse> verses;
  final String? licence;

  @override
  State<_PassageReportDialog> createState() => _PassageReportDialogState();
}

class _PassageReportDialogState extends State<_PassageReportDialog> {
  ReportOptions _options = const ReportOptions();
  PassageReport? _report;
  bool _busy = false;

  /// Only the newest build may be shown — the switches are faster than
  /// the concordance is.
  int _run = 0;

  @override
  void initState() {
    super.initState();
    _build();
  }

  Future<void> _build() async {
    final token = ++_run;
    setState(() => _busy = true);
    final locale = context.read<AppSettings>().locale;
    final r = await PassageReportService.build(
      title: widget.title,
      versionLabel: widget.versionLabel,
      englishBook: widget.englishBook,
      verses: widget.verses,
      locale: locale,
      options: _options,
      licence: widget.licence,
    );
    if (!mounted || token != _run) return;
    setState(() {
      _report = r;
      _busy = false;
    });
  }

  void _set(ReportOptions next) {
    setState(() => _options = next);
    _build();
  }

  String _s(String key, String fallback) {
    final locale = context.read<AppSettings>().locale;
    return uiStrings[key]?[locale] ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    final c = WbColors.of(context);
    final t = WbType.of(context);
    final r = _report;
    return AlertDialog(
      backgroundColor: c.paneBg,
      title: Text(
        _s('reportTitle', 'Passage report'),
        style: TextStyle(fontSize: t.text, color: c.text),
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.title} · ${widget.versionLabel}',
                style: TextStyle(fontSize: t.chrome, color: c.mutedText)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _chip(c, t, _s('reportVerseText', 'Verse text'),
                    _options.verseText,
                    () => _set(ReportOptions(
                          verseText: !_options.verseText,
                          words: _options.words,
                          morphology: _options.morphology,
                          frequency: _options.frequency,
                          rarerThan: _options.rarerThan,
                          partsOfSpeech: _options.partsOfSpeech,
                        ))),
                _chip(c, t, _s('reportWords', 'Words'), _options.words,
                    () => _set(ReportOptions(
                          verseText: _options.verseText,
                          words: !_options.words,
                          morphology: _options.morphology,
                          frequency: _options.frequency,
                          rarerThan: _options.rarerThan,
                          partsOfSpeech: _options.partsOfSpeech,
                        ))),
                _chip(c, t, _s('reportParsing', 'Parsing'),
                    _options.morphology,
                    () => _set(ReportOptions(
                          verseText: _options.verseText,
                          words: _options.words,
                          morphology: !_options.morphology,
                          frequency: _options.frequency,
                          rarerThan: _options.rarerThan,
                          partsOfSpeech: _options.partsOfSpeech,
                        ))),
                _chip(c, t, _s('reportFrequency', 'Frequency'),
                    _options.frequency,
                    () => _set(ReportOptions(
                          verseText: _options.verseText,
                          words: _options.words,
                          morphology: _options.morphology,
                          frequency: !_options.frequency,
                          rarerThan: _options.rarerThan,
                          partsOfSpeech: _options.partsOfSpeech,
                        ))),
              ],
            ),
            const SizedBox(height: 6),
            Text(_s('reportRarity', 'Only words used at most'),
                style: TextStyle(fontSize: t.chrome, color: c.mutedText)),
            const SizedBox(height: 3),
            Wrap(
              spacing: 4,
              children: [
                // 0 last and labelled "every word": the default IS a
                // filter, and a row that opened with "everything"
                // selected would teach the wrong thing about what a
                // report is for.
                for (final n in const [10, 50, 200, 0])
                  _chip(
                    c,
                    t,
                    n == 0
                        ? _s('reportEveryWord', 'every word')
                        : '$n×',
                    _options.rarerThan == n,
                    () => _set(ReportOptions(
                      verseText: _options.verseText,
                      words: _options.words,
                      morphology: _options.morphology,
                      frequency: _options.frequency,
                      rarerThan: n,
                      partsOfSpeech: _options.partsOfSpeech,
                    )),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 220,
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.paneAltBg,
                border: Border.all(color: c.border),
              ),
              child: _busy || r == null
                  ? Center(
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.6, color: c.mutedText),
                      ),
                    )
                  : SingleChildScrollView(
                      child: SelectableText(
                        reportToMarkdown(r),
                        style: TextStyle(
                            fontSize: t.chrome,
                            color: c.text,
                            fontFamilyFallback: kCjkFontFallback),
                      ),
                    ),
            ),
            if (r != null && !_busy) ...[
              const SizedBox(height: 5),
              Text(
                _s('reportWordCount', '{n} words')
                    .replaceAll('{n}', '${r.wordsShown}'),
                style: TextStyle(fontSize: t.chrome, color: c.mutedText),
              ),
            ],
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
          onPressed: r == null || _busy
              ? null
              : () => Navigator.of(context).pop((
                    html: reportToHtml(r),
                    markdown: reportToMarkdown(r),
                  )),
          // `copyAll`, not a new `copy` key: the button takes the
          // whole report, and the app already has a word for that.
          child: Text(_s('copyAll', 'Copy all'),
              style: TextStyle(fontSize: t.chrome, color: c.link)),
        ),
      ],
    );
  }

  Widget _chip(WbColors c, WbType t, String label, bool on, VoidCallback tap) =>
      WbPaneChip(
        label: label,
        on: on,
        onTap: tap,
        foreground: on ? c.link : c.text,
      );
}
