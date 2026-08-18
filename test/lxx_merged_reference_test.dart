// Seven of the Septuagint's 302 absences are not absences.
//
// `assets/lxxwh.json` has no record at English Exodus 40:31, and the
// Browse column said so: "this edition has no verse here". Its Greek
// Exodus 40:30 reads …ινα νιπτωνται εξ αυτου μωυσης και ααρων και οι
// υιοι αυτου τας χειρας αυτων και τους ποδας… — "that Moses and Aaron
// and his sons might wash their hands and their feet from it", which is
// English 40:31, whole. The words are on the page one line higher and
// the row was telling the reader they were gone.
//
// Check 30's three derivations cannot find these. A range label is the
// publisher's; the Septuagint prints none. `versification.json` maps
// reader keys to the ORIGINAL's verses, and the Greek is numbered in a
// third frame again — its own. So this last class is a list, and
// docs/DATA-INTEGRITY.md check 39 is how the list was arrived at: 302
// absences narrowed to 55 candidates by two independent length
// instruments and the file's own `<vs:>` markers, all 55 read against
// the KJV.
//
// The negatives below are the point of the file. Eighteen candidates
// looked like merges under the numbering and are not — Greek Exodus
// 36-40 is a shorter, reordered tabernacle account, so its verse
// numbers run straight across an English verse whose words are simply
// not there. And check 29c's own second example was wrong: English
// Psalm 116:14's Greek is NOT inside 116:13. The edition's markers
// name Greek 115:5 between them, and we carry no record for it.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/utils/verse_text_absence.dart';

final _marker = RegExp(r'<vs:(\d+):(\d+)([a-z]?)>');

Map<String, String> _load(String path) {
  final rows = jsonDecode(File(path).readAsStringSync()) as List;
  return {
    for (final r in rows.cast<Map<String, dynamic>>())
      '${r['book']} ${r['chapter']}:${r['verse']}': r['text'] as String,
  };
}

/// The English verse each entry claims is inside its head's record, and
/// the Greek clause that carries it. Read one at a time; a merge that
/// cannot be pointed at like this is not in the table.
const _evidence = <String, List<String>>{
  'Exodus 38:5': [
    'Exodus 38:4',
    'και επεθηκεν αυτω τεσσαρας δακτυλιους εκ των τεσσαρων μερων',
  ],
  'Exodus 40:31': [
    'Exodus 40:30',
    'μωυσης και ααρων και οι υιοι αυτου τας χειρας αυτων και τους ποδας',
  ],
  'Exodus 40:32': [
    'Exodus 40:30',
    'εισπορευομενων αυτων εις την σκηνην του μαρτυριου',
  ],
  '1 Kings 4:28': [
    '1 Kings 4:27',
    'και τας κριθας και το αχυρον τοις ιπποις',
  ],
  '1 Kings 9:21': [
    '1 Kings 9:20',
    'τα τεκνα αυτων τα υπολελειμμενα μετ αυτους εν τη γη',
  ],
  'Psalms 13:6': [
    'Psalms 13:5',
    'ασω τω κυριω τω ευεργετησαντι με',
  ],
  'Isaiah 64:1': [
    'Isaiah 63:19',
    'εαν ανοιξης τον ουρανον τρομος λημψεται απο σου ορη και τακησονται',
  ],
};

/// Absences a numbering-only instrument called merges and reading
/// refuted. Frozen so a future rule cannot quietly claim them.
const _notMerges = <String>[
  'Exodus 37:4', // Greek 38 is the shorter account; the staves are gone
  'Exodus 39:35', // the ark and staves are in 39:34, the mercy seat is not
  'Psalms 116:14', // Greek 115:5 is named by the markers and absent
  'Isaiah 2:22',
  '1 Kings 6:37',
  'Proverbs 18:23',
  '1 Samuel 17:50',
];

void main() {
  final lxx = _load('assets/lxxwh.json');
  final kjv = _load('assets/kjv.json');

  group('the Septuagint\'s merged references', () {
    test('every entry names a reference we lack and a head we have', () {
      for (final entry in kEditionMergedHeads.entries) {
        final parts = entry.key.split('|');
        expect(parts[0], 'lxxwh', reason: entry.key);
        final ref = '${parts[1]} ${parts[2]}';
        expect(lxx.containsKey(ref), isFalse,
            reason: '$ref is in the file, so it is not an absence');
        expect(kjv.containsKey(ref), isTrue, reason: ref);
        final head = '${parts[1]} ${entry.value}';
        expect(lxx[head], isNotNull, reason: '$ref names $head');
        expect(_evidence.containsKey(ref), isTrue,
            reason: '$ref has no clause recorded for it');
      }
      expect(kEditionMergedHeads.length, _evidence.length);
    });

    test('the head really carries the absent verse\'s Greek', () {
      for (final entry in _evidence.entries) {
        final head = entry.value[0];
        expect(lxx[head], contains(entry.value[1]), reason: entry.key);
      }
    });

    test('the lookup answers, and hides a head in another chapter', () {
      expect(isEditionMerged('lxxwh', 'Exodus', 40, 31), isTrue);
      expect(editionMergedHeadVerse('lxxwh', 'Exodus', 40, 31), 30);
      expect(verseAbsenceNote(VerseAbsence.merged, 'en', mergedWith: 30),
          'Printed with verse 30');

      // The Greek numbers English Isaiah 64:2 as its own 64:1, so
      // English 64:1 is the tail of Greek 63:19. The row may say a
      // merge happened and may not name "19" beside a 64:1 reference.
      expect(isEditionMerged('lxxwh', 'Isaiah', 64, 1), isTrue);
      expect(editionMergedHeadVerse('lxxwh', 'Isaiah', 64, 1), isNull);
      expect(verseAbsenceNote(VerseAbsence.merged, 'en'),
          'Printed with an earlier verse');

      expect(isEditionMerged('lxxwh', 'Exodus', 40, 30), isFalse);
      expect(isEditionMerged('bsb', 'Exodus', 40, 31), isFalse);
    });

    test('the refuted candidates stay refuted', () {
      for (final ref in _notMerges) {
        final i = ref.lastIndexOf(' ');
        final book = ref.substring(0, i);
        final cv = ref.substring(i + 1).split(':');
        expect(lxx.containsKey(ref), isFalse, reason: ref);
        expect(
            isEditionMerged(
                'lxxwh', book, int.parse(cv[0]), int.parse(cv[1])),
            isFalse,
            reason: ref);
      }
    });

    test('302 absences against the KJV extent, 7 of them explained', () {
      final extent = <String, int>{};
      for (final k in kjv.keys) {
        final i = k.lastIndexOf(' ');
        final cv = k.substring(i + 1).split(':');
        final chap = '${k.substring(0, i)} ${cv[0]}';
        final v = int.parse(cv[1]);
        if ((extent[chap] ?? 0) < v) extent[chap] = v;
      }
      final chaptersWeCarry = <String>{
        for (final k in lxx.keys) k.substring(0, k.lastIndexOf(':')),
      };
      var absences = 0, explained = 0;
      for (final chap in chaptersWeCarry) {
        final last = extent[chap];
        if (last == null) continue;
        final i = chap.lastIndexOf(' ');
        final book = chap.substring(0, i);
        final c = int.parse(chap.substring(i + 1));
        for (var v = 1; v <= last; v++) {
          if (lxx.containsKey('$chap:$v')) continue;
          absences++;
          if (isEditionMerged('lxxwh', book, c, v)) explained++;
        }
      }
      expect(absences, 302);
      expect(explained, 7);
    });

    test('Psalm 116:14 is a gap the edition itself attests', () {
      // check 29c said its Greek was inside 116:13. It is not: 116:13
      // holds Greek 115:4 and only that, 116:15 opens at Greek 115:6,
      // and no record in the file carries 115:5. The Septuagint has
      // that verse; our copy of it does not.
      String sole(String ref) {
        final ms = _marker.allMatches(lxx[ref]!).toList();
        expect(ms.length, 1, reason: ref);
        expect(ms.first.start, 0, reason: ref);
        return '${ms.first.group(1)}:${ms.first.group(2)}';
      }

      expect(sole('Psalms 116:13'), '115:4');
      expect(sole('Psalms 116:15'), '115:6');
      expect(lxx.containsKey('Psalms 116:14'), isFalse);
      expect(
          lxx.values.any((t) => t.contains('<vs:115:5>')), isFalse,
          reason: 'no record claims Greek Psalm 115:5');
    });
  });
}
