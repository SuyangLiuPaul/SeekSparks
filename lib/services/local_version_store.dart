/// Where a reader's own Bible lives — bwh47's store,
/// `docs/PARITY-BACKLOG.md` §3.7.
///
/// **On this device and nowhere else.** No upload, no share, no sync,
/// and no code path here that could add one — the row's own condition,
/// and the thing that keeps an importer from becoming a distribution
/// channel for somebody else's text.
///
/// ## Why IndexedDB and not `shared_preferences`
///
/// The app's only storage dependency is `shared_preferences`, which on
/// web is localStorage: roughly 5 MB, shared with every other
/// preference the app keeps. A New Testament fits and a whole Bible does
/// not, and a store that failed at the quota — silently, or after the
/// reader had waited through a 6 MB parse — would be worse than no
/// store. IndexedDB has no such ceiling and is reached through
/// `package:web`, which is already a dependency, so this costs no new
/// package.
///
/// Split by the same conditional-export pattern `fetch_helper.dart`
/// uses. Native gets the no-op: the importer's surface is web-only, for
/// the same reason the offline-pack UI is.
library;

export 'local_version_store_io.dart'
    if (dart.library.js_interop) 'local_version_store_web.dart';
