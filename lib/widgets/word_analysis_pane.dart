/// 2026-08-06 (SeekSparks): the Word Analysis pane — a live readout of
/// whatever the mouse is over in the Browse window.
///
/// From the BibleWorks 10 manual, on the Analysis window:
///
/// > "When you move the mouse over a word in the Browse Window,
/// > information about the word or verse being examined will be shown
/// > in this window."
///
/// and on the Word Analysis tab specifically:
///
/// > "displays lexical and other verse-specific information
/// > automatically as you move the mouse cursor over text in the Browse
/// > Window … If you hold down the Shift key as you move the mouse
/// > cursor the content of the Word Analysis Window will not change."
///
/// That is the product. The Analysis window is not a click target; it
/// is the pointer's readout, and Shift is the brake. SeekSparks had it
/// as a click target with a hover *tooltip* bolted on — the right idea
/// at a tenth of the value, because you had to interrupt reading to see
/// a full entry.
///
/// The pane deliberately does NOT blank when the pointer leaves the
/// text: BibleWorks keeps the last word up, so you can move the mouse
/// to the pane itself and read it.
library;

import 'package:flutter/material.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/models/original_word.dart';
import 'package:seeksparks/models/strongs.dart';
import 'package:seeksparks/services/strongs_service.dart';
import 'package:seeksparks/utils/morphology.dart' show describeMorphology;

class WordAnalysisPane extends StatefulWidget {
  const WordAnalysisPane({
    super.key,
    required this.word,
    required this.reference,
    required this.locale,
    required this.frozen,
    this.onOpenFullEntry,
  });

  final OriginalWord word;

  /// "Genesis 1:1" — printed in the header the way BibleWorks does.
  final String reference;
  final String locale;

  /// True while Shift is held. Shown as a badge so the reader knows why
  /// the pane stopped following the mouse.
  final bool frozen;

  final VoidCallback? onOpenFullEntry;

  @override
  State<WordAnalysisPane> createState() => _WordAnalysisPaneState();
}

class _WordAnalysisPaneState extends State<WordAnalysisPane> {
  StrongsEntry? _entry;
  String? _loadedFor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant WordAnalysisPane old) {
    super.didUpdateWidget(old);
    if (old.word.strongs != widget.word.strongs) _load();
  }

  /// Keeps the previous entry on screen while the next one resolves.
  /// Blanking between words would make the pane strobe as the pointer
  /// crosses a line — the opposite of a readout.
  Future<void> _load() async {
    final number = widget.word.strongs;
    if (number.isEmpty || number == _loadedFor) return;
    final e = await StrongsService.lookup(number);
    if (!mounted || widget.word.strongs != number) return;
    setState(() {
      _entry = e;
      _loadedFor = number;
    });
  }

  @override
  Widget build(BuildContext context) {
    final wb = WbColors.of(context);
    final locale = widget.locale;
    final e = _entry;
    final parse = describeMorphology(widget.word.morph, locale);

    String s(String key, String fallback) =>
        uiStrings[key]?[locale] ?? fallback;

    return Container(
      color: wb.paneBg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 16),
        children: [
          // ── Header: reference + Strong's number, plus the freeze badge
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.reference,
                  style: TextStyle(
                    fontSize: WbMetrics.chrome,
                    color: wb.mutedText,
                  ),
                ),
              ),
              if (widget.frozen)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  color: wb.selectionBg,
                  child: Text(
                    s('analysisFrozen', 'FROZEN — Shift'),
                    style: TextStyle(
                      fontSize: WbMetrics.chrome - 1,
                      fontWeight: FontWeight.w700,
                      color: wb.text,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),

          // ── The word itself, big and red, as BibleWorks prints it
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                widget.word.strongs,
                style: TextStyle(
                  fontSize: WbMetrics.chrome,
                  fontWeight: FontWeight.w700,
                  color: wb.mutedText,
                ),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  widget.word.text,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB3261E),
                  ),
                ),
              ),
              if ((e?.translit ?? '').isNotEmpty) ...[
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    '(${e!.translit})',
                    style: TextStyle(
                      fontSize: WbMetrics.text,
                      fontStyle: FontStyle.italic,
                      color: wb.mutedText,
                    ),
                  ),
                ),
              ],
            ],
          ),

          if ((e?.pronunciation ?? '').isNotEmpty)
            Text(
              '/${e!.pronunciation}/',
              style: TextStyle(
                  fontSize: WbMetrics.chrome, color: wb.mutedText),
            ),

          // ── Parsing. The line the whole Analysis window exists for.
          if (parse != null && parse.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: wb.link.withValues(alpha: 0.08),
                border: Border.all(color: wb.link.withValues(alpha: 0.30)),
              ),
              child: Text(
                parse,
                style: TextStyle(
                  fontSize: WbMetrics.text,
                  fontWeight: FontWeight.w600,
                  color: wb.link,
                  height: 1.35,
                ),
              ),
            ),
          ],

          if (e != null) ...[
            _field(wb, s('analysisMeaning', 'Meaning'),
                e.localizedGloss(locale)),
            _field(wb, s('analysisOrigin', 'Origin'), e.derivation ?? ''),
            _field(wb, s('analysisDefinition', 'Definition'),
                e.localizedDefinition(locale)),
            if (widget.onOpenFullEntry != null) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: widget.onOpenFullEntry,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    s('analysisFullEntry',
                        'Full entry, word family & concordance →'),
                    style: TextStyle(
                      fontSize: WbMetrics.chrome,
                      fontWeight: FontWeight.w600,
                      color: wb.link,
                    ),
                  ),
                ),
              ),
            ],
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                s('analysisNoEntry', 'No lexicon entry for this number.'),
                style: TextStyle(
                    fontSize: WbMetrics.text, color: wb.mutedText),
              ),
            ),
        ],
      ),
    );
  }

  Widget _field(WbColors wb, String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: wb.text),
          ),
          TextSpan(text: value, style: TextStyle(color: wb.text)),
        ]),
        style: TextStyle(fontSize: WbMetrics.text, height: 1.45),
      ),
    );
  }
}
