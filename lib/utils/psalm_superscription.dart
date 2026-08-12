/// 2026-08-12 (docs/DATA-INTEGRITY.md check 31): the psalm titles the
/// loader threw away.
///
/// `assets/leb.json` ships 116 records whose `verse` field is the string
/// `title` rather than a number — the superscriptions: *"For the music
/// director. A psalm of David. When Nathan the prophet came to him,
/// after he had gone in to Bathsheba."* They are the only non-integer
/// verse numbers in the whole repository, and `FetchVerses` dropped
/// every one of them at load:
///
///     // Filter out entries where verse is non-numeric
///     rawList = rawList.where((m) => int.tryParse(...) != null)
///
/// So a reader has never seen one. The words are in the asset, correct
/// and complete, and unreachable — the same shape as check 25b, where
/// 139 Old-Testament synopsis groups existed and nothing could open
/// them.
///
/// A superscription is scripture, not a heading. The Masoretic text
/// numbers it as the psalm's first verse (two, where the setting is
/// long), which is why English Psalm 51:1 is Hebrew 51:3 — and the LEB
/// says so itself, in a footnote carried inside every one of these
/// records: *"The Hebrew Bible counts the superscription as the first
/// verse of the psalm; the English verse number is reduced by one."*
/// `assets/versification.json` had to derive that fact independently
/// for check 9. It was sitting in an asset we discarded.
///
/// WHY THIS ATTACHES TO VERSE 1 RATHER THAN BECOMING A VERSE. The
/// obvious alternative is to number the record 0 and let it flow
/// through as an ordinary verse. That would be wrong in a way Browse
/// makes visible: no other edition has a reference there, so every
/// other column would print 116 rows of *"this edition does not carry
/// this verse"* — and `kjvs`, `bsb` and `lxxwh` all DO carry the
/// superscription, merged into their verse 1. Inventing a reference to
/// hold it would make the app state something untrue about four
/// editions in order to render one correctly.
///
/// So the superscription rides on verse 1, typed rather than glued.
/// Prepending it to `text` would also make it reachable everywhere at
/// once, and it is what the other three editions' publishers did — but
/// it destroys the distinction the LEB's data draws, and this file's
/// sibling `scripture_markup.dart` argues at length that the answer to
/// "two different things in one string" is a type, not a flattening.
library;

/// The `verse` token an edition uses for a psalm's superscription.
/// `assets/leb.json` is the only asset that writes one.
const String kSuperscriptionVerseToken = 'title';

/// The result of folding an edition's superscription records onto the
/// verses they are printed above.
class SuperscriptionFold {
  const SuperscriptionFold({
    required this.records,
    required this.attached,
    required this.orphans,
  });

  /// The records with every superscription removed and, where a home was
  /// found, a `superscription` key set on the verse it belongs above.
  final List<Map<String, dynamic>> records;

  /// How many superscriptions found a home.
  final int attached;

  /// `book chapter` for each superscription that named a chapter with no
  /// verse 1 to sit above. Dropped rather than guessed at — but counted,
  /// because a silent drop is what this whole check is about.
  final List<String> orphans;
}

/// Folds `verse: "title"` records onto verse 1 of their chapter.
///
/// Pure: takes the decoded JSON records and returns new ones. Anything
/// non-numeric that is *not* a superscription is left alone for the
/// caller's own filter to reject, so this function cannot quietly widen
/// what the loader accepts.
SuperscriptionFold foldSuperscriptions(List<Map<String, dynamic>> raw) {
  final titles = <String, String>{};
  final orphans = <String>[];
  final body = <Map<String, dynamic>>[];

  for (final m in raw) {
    if (m['verse']?.toString() == kSuperscriptionVerseToken) {
      final key = '${m['book']} ${m['chapter']}';
      final text = m['text']?.toString() ?? '';
      // Two titles for one chapter is not a shape any asset writes; if
      // one ever appears, keep both in the order they were written
      // rather than silently losing the second.
      titles[key] = titles.containsKey(key) ? '${titles[key]} $text' : text;
      continue;
    }
    body.add(m);
  }

  if (titles.isEmpty) {
    return SuperscriptionFold(records: raw, attached: 0, orphans: const []);
  }

  var attached = 0;
  final out = <Map<String, dynamic>>[];
  for (final m in body) {
    final key = '${m['book']} ${m['chapter']}';
    final title = titles[key];
    if (title == null || m['verse']?.toString() != '1') {
      out.add(m);
      continue;
    }
    out.add({...m, 'superscription': title});
    titles.remove(key);
    attached++;
  }

  orphans.addAll(titles.keys);
  orphans.sort();

  return SuperscriptionFold(
      records: out, attached: attached, orphans: orphans);
}
