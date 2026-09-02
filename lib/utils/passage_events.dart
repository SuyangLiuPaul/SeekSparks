/// 2026-09-01 (SeekSparks, #318 phase 25): which dated events narrate
/// THIS chapter.
///
/// `assets/bible_timeline.json` holds 104 dated events, each carrying the
/// verses that narrate it (`refs`). Until now the only way to see one was
/// to leave the text for the standalone timeline page — a reader sitting
/// in 2 Kings 17, which the asset dates to 722 BC, was told nothing. This
/// is the same move #317 made for routes (`passage_journeys.dart`): join
/// the dated record back onto the chapter that names it.
///
/// **The ref parser is the whole risk of this file.** The asset's 130
/// `refs` strings take exactly five shapes, and two of them look alike
/// but are not: `'Genesis 2:8-25'` is a VERSE range within chapter 2, not
/// a chapter range — a `:` anywhere in a part means its `-` is verses,
/// never chapters. Reading it as a chapter range puts `eden` in Genesis
/// 15. And `'Luke 1:5-25, 57-80'` is a chapter-1 event with a second
/// verse span, not an event that reaches Luke chapter 57 — Luke has 24
/// chapters. A part with no `:` that follows a part that HAD one is a
/// verse continuation of that first part's chapter, and contributes no
/// chapter of its own.
///
/// The one bare book name in the asset (`'Leviticus'`, on `tabernacle`)
/// contributes no chapter at all, deliberately: resolving it would need a
/// per-book chapter-count table this file otherwise has no reason to
/// import, and it costs nothing — `tabernacle`'s other ref, `'Exodus
/// 25-40'`, already reaches it. Promoting a bare book name to chapter 1
/// would be the `navigation parser is not a formatter` defect exactly.
library;

import 'package:seeksparks/models/timeline_event.dart';

final RegExp _bookSplit = RegExp(r'\s(?=\d)');

/// One dated event, and the refs of its own that name THIS chapter.
class EventHere {
  const EventHere({required this.event, required this.refsHere});
  final TimelineEvent event;

  /// The event's own `refs` strings that resolve to this chapter, in the
  /// order the asset lists them. Never empty.
  final List<String> refsHere;

  String get id => event.id;
}

/// The chapters a single `refs` string names, as `(book, chapter)` pairs.
List<(String, int)> _chaptersOf(String ref) {
  final m = _bookSplit.firstMatch(ref);
  if (m == null) return const []; // bare book name — see the doc comment.
  final book = ref.substring(0, m.start);
  final rest = ref.substring(m.end);

  final out = <(String, int)>[];
  final parts = rest.split(',');
  var firstHadColon = false;
  for (var i = 0; i < parts.length; i++) {
    final part = parts[i].trim();
    final hasColon = part.contains(':');
    if (i == 0) firstHadColon = hasColon;

    if (hasColon) {
      final chapterStr = part.substring(0, part.indexOf(':'));
      final chapter = int.tryParse(chapterStr);
      if (chapter != null) out.add((book, chapter));
      continue;
    }
    if (i != 0 && firstHadColon) {
      // A verse continuation of part 0's chapter — adds no chapter.
      continue;
    }
    if (part.contains('-')) {
      final bounds = part.split('-');
      final a = int.tryParse(bounds[0].trim());
      final b = int.tryParse(bounds.length > 1 ? bounds[1].trim() : '');
      if (a != null && b != null) {
        for (var c = a; c <= b; c++) {
          out.add((book, c));
        }
      }
      continue;
    }
    final chapter = int.tryParse(part);
    if (chapter != null) out.add((book, chapter));
  }
  return out;
}

/// The events whose `refs` name [englishBook] [chapter], in the order the
/// asset lists them.
///
/// [events] must already be in the order to display them —
/// `TimelineService.loadAll()` sorts oldest-first, and this function does
/// not re-sort, so a reader sees the same order here as on the timeline
/// page for the same events.
List<EventHere> eventsIn(
  String englishBook,
  int chapter,
  List<TimelineEvent> events,
) {
  final out = <EventHere>[];
  for (final e in events) {
    final refsHere = <String>[
      for (final ref in e.refs)
        if (_chaptersOf(ref).any((c) => c.$1 == englishBook && c.$2 == chapter))
          ref,
    ];
    if (refsHere.isEmpty) continue;
    out.add(EventHere(event: e, refsHere: refsHere));
  }
  return out;
}
