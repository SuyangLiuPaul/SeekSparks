/// 2026-08-16 (#320): joining the picture database to the gazetteer —
/// pure.
///
/// The ticket asked for illustrations on the place record and attached a
/// condition to it: *measure the join rate before promising the feature*,
/// because *a name match is a guess, not a join, and a wrong picture on a
/// place is worse than no picture, since a reader will believe it.* What
/// follows is the measurement, because the numbers are the argument for
/// the rule that shipped and against the ones that did not.
///
/// **The corpus has no join key.** `assets/maps_index.json` carries 1,192
/// illustrations; not one of them names a gazetteer id, and there is no
/// field that could be made to. Every candidate join is therefore
/// inferred, and the only question is which inference is safe.
///
/// **Rejected: chapter coverage alone.** Every plate declares a
/// book→chapter range, and every place declares verses; intersecting them
/// reaches all 1,271 places and 17,177 pairs — a 100% "join rate" that
/// means nothing, because it is answering "was this plate drawn from a
/// chapter that happens to name this place". It puts four *Valley of
/// Hinnom* plates on **Ziph**, *The Creation of Eve* on the **Tigris**,
/// and *Peter's Vision at Joppa* on **Caesarea**. Restricting it to
/// single-chapter plates (695 places, 6,594 pairs) narrows the blast
/// radius without changing the kind of error.
///
/// **Rejected: matching the Chinese names.** It would add 13 places and
/// 80 pairs and cannot be made safe, because Han text has no word
/// boundary to anchor on: 撒冷 (Salem) is a substring of 耶路撒冷
/// (Jerusalem), and 埃及 (Egypt) is a substring of 出埃及记, which is
/// simply the Chinese name of the book of Exodus. Both would fire on
/// every plate in those books.
///
/// **Rejected: adjectival forms.** Adding `-n` / `-an` / `-ian` would
/// catch "a Samaritan woman", and would also turn `Cana` into `Canaan`.
///
/// **Adopted: the English name as a whole word, gated by chapter.** The
/// place's name must appear in the plate's English title or description
/// with letters and digits on neither side, AND the plate's declared
/// chapter range must cover at least one verse that names the place. Both
/// halves are load-bearing: the name alone puts *Simon of Cyrene* plates
/// on Libyan Cyrene, and the chapter alone is the rejected join above.
/// This reaches **79 places, 218 pairs, 149 distinct plates** — a join
/// rate of 6.2% of the gazetteer, which is the honest number and the
/// reason the strip is absent from 94% of place records rather than
/// apologising on them.
///
/// All 218 pairs were read by hand. The boundary must be Unicode-aware
/// and not `[A-Za-z]`: the place **Dor** is a whole word inside **Doré**
/// by the ASCII rule, and that one slip alone attached 145 plates to it.
///
/// **Why [kAmbiguousPlaceNames] exists.** Measuring the name rule with
/// the chapter gate REMOVED shows how much the gate is silently carrying:
/// the gazetteer's **On** — the Egyptian city of Genesis 41 — is a whole
/// word in 51 captions, because `on` is an English preposition. **Adam**
/// is a town in Joshua 3:16 and a man in 10 captions; **Ham**, **Esau**,
/// **Laban**, **Rahab**, **Tamar** and **Abel** are all towns and all
/// people. Today the gate happens to reject every one of those matches,
/// which means the feature is correct by luck rather than by rule, and
/// one new plate covering Genesis 41 with the word "on" in its caption
/// would end that. So the names are excluded outright.
///
/// **Rejected: deriving that set from the people data.** It would be
/// automatic and it would be wrong — Midian, Ephraim, Canaan and Sheba
/// are each a person in scripture as well as a place, and all four are in
/// the verified 218 with plates that plainly mean the place. The
/// distinction is which sense a *caption* uses, and no dataset in the
/// repo records that.
///
/// **What the strip may therefore claim.** Not "pictures of this place" —
/// "illustrations that name it". The gazetteer's disambiguating ordinal
/// does not survive this join, and mostly does not exist to survive it:
/// of its 80 ordinal groups, 66 (131 entries) carry byte-identical
/// reference lists, so `Antioch 1` and `Antioch 2` cannot be told apart
/// by anything this file can see. See `docs/DATA-INTEGRITY.md` check 38.
library;

import 'package:seeksparks/models/bible_map.dart';
import 'package:seeksparks/models/bible_place.dart';
import 'package:seeksparks/utils/illustration_index.dart'
    show illustrationAnchor;

/// Gazetteer names the join refuses, because a picture caption using the
/// word almost certainly does not mean the place.
///
/// Excluding all of them costs nothing today — every one contributes zero
/// pairs to the shipped 218, which `place_illustrations_test.dart` pins —
/// so this is a guard against the corpus growing into the defect rather
/// than a repair of one. Ordinals are already stripped, so `Ham` covers
/// both `Ham 1` and `Ham 2`.
const Set<String> kAmbiguousPlaceNames = <String>{
  // Ordinary English words, which a caption uses for its own sake.
  'On',
  'Sin',
  'Mount',
  'East',
  'South',
  'Plain',
  // A person, a people or a god of the same name. Scripture's pictures
  // are mostly of people, so this is the likelier reading of the word.
  'Adam',
  'Abel',
  'Baal',
  'Buz',
  'Dan',
  'Esau',
  'Gog',
  'Ham',
  'Laban',
  'Lud',
  'Pul',
  'Put',
  'Rahab',
  'Tamar',
  'Uz',
};

/// One compiled matcher per name; the Atlas re-runs the join on every
/// selection and there are 1,192 plates to sweep each time.
final Map<String, RegExp> _namePatterns = <String, RegExp>{};

/// [name] as a whole word, with Unicode letters and digits excluded on
/// both sides.
///
/// `\p{L}` rather than `[A-Za-z]` is the whole of the Doré trap above;
/// `\p{N}` is there so a name abutting a digit is not a word either.
RegExp placeNamePattern(String name) => _namePatterns.putIfAbsent(
      name,
      () => RegExp(
        '(?<![\\p{L}\\p{N}])${RegExp.escape(name)}(?![\\p{L}\\p{N}])',
        caseSensitive: false,
        unicode: true,
      ),
    );

/// True when [m]'s English title or description names [place].
///
/// English only — see the library comment for why the Chinese fields
/// cannot be matched safely.
bool illustrationNamesPlace(BibleMap m, BiblePlace place) {
  if (kAmbiguousPlaceNames.contains(place.name)) return false;
  final re = placeNamePattern(place.name);
  final title = m.title['en'];
  if (title != null && re.hasMatch(title)) return true;
  final description = m.description['en'];
  return description != null && re.hasMatch(description);
}

/// True when [m]'s declared chapter range covers a verse in [refs].
///
/// [scopeBooks] null or empty is "no limit", the convention shared with
/// `atlas_index.dart` and `search_scope.dart`.
bool illustrationCoversRefs(
  BibleMap m,
  List<PlaceRef> refs, {
  Set<String>? scopeBooks,
}) {
  final scoped = scopeBooks != null && scopeBooks.isNotEmpty;
  for (final r in refs) {
    if (scoped && !scopeBooks.contains(r.englishBook)) continue;
    if (m.matchesBookChapter(r.englishBook, r.chapter)) return true;
  }
  return false;
}

/// What the place record draws, and what it would draw with no scope.
///
/// Two numbers for the same reason the reference list above the strip
/// carries two (#319): a scope that silently subtracts leaves a reader
/// unable to tell "no plate in Obadiah" from "no plate anywhere". The
/// gap is not a corner case — 56 of the 79 joined places have at least
/// one book under which every plate falls away, 292 such pairs in all.
class PlaceIllustrations {
  const PlaceIllustrations({required this.inScope, required this.total});

  /// Canonical order — the same ordering the Illustrations window uses,
  /// so the strip reads as a walk through scripture beside the reference
  /// list it sits above.
  final List<BibleMap> inScope;

  /// Ignoring the scope. Equals `inScope.length` when none is set.
  final int total;
}

/// The plates that name [place] and were drawn from a chapter that names
/// it.
PlaceIllustrations placeIllustrations(
  BiblePlace place,
  Iterable<BibleMap> all, {
  Set<String>? scopeBooks,
}) {
  final drawn = <BibleMap>[];
  var total = 0;
  for (final m in all) {
    // Name first: it is one RegExp against two strings, where the gate is
    // a scan of up to 755 references.
    if (!illustrationNamesPlace(m, place)) continue;
    if (!illustrationCoversRefs(m, place.refs)) continue;
    total++;
    if (illustrationCoversRefs(m, place.refs, scopeBooks: scopeBooks)) {
      drawn.add(m);
    }
  }
  drawn.sort((a, b) {
    final pa = illustrationAnchor(a, scopeBooks);
    final pb = illustrationAnchor(b, scopeBooks);
    if (pa.book != pb.book) return pa.book.compareTo(pb.book);
    if (pa.chapter != pb.chapter) return pa.chapter.compareTo(pb.chapter);
    return a.id.compareTo(b.id);
  });
  return PlaceIllustrations(inScope: drawn, total: total);
}
