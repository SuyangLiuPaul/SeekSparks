import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/utils/build_books_from_verses.dart';

// 2026-05-18 (v1.2.53): `bookNameToEnglish` moved to a dependency-
// free file in `lib/constants/book_names.dart`. Re-exported here so
// existing call-sites that do `import '...fetch_books.dart' show
// bookNameToEnglish` keep working unchanged. 2026-08-09 (#298):
// `standardBookOrder` followed it there for the same reason.
export 'package:seeksparks/constants/book_names.dart'
    show bookNameToEnglish, standardBookOrder;

/// Re-derives `books` from the provider's current `verses`.
///
/// 2026-08-09 (#298): the projection itself lives in
/// `buildBooksFromVerses`, and `MainProvider` now applies it on every
/// assignment to `verses` — so this is idempotent and every
/// `FetchVerses` → `FetchBooks` pair in the codebase is belt and
/// braces rather than the thing holding the reader together. Kept
/// because the call sites read as a sequence and deleting half of a
/// sequence is how the bug happened in the first place.
class FetchBooks {
  static Future<void> execute({required MainProvider mainProvider}) async {
    mainProvider.setBooks(buildBooksFromVerses(mainProvider.verses));
  }
}

