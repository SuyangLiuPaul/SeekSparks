// The Flutter web engine keeps its browser-history bookkeeping inside
// `window.history.state`, and it enforces the shape it expects with `!`
// rather than ignoring what it does not recognise. Two of those null
// assertions are reachable from ordinary reading:
//
//   MultiEntriesBrowserHistory.tearDown  — walks the browser back
//     `serialCount` entries, then reads the state of whatever entry it
//     landed on as `currentState! as Map`.
//   SingleEntryBrowserHistory.tearDown   — steps back one entry, then
//     unwraps `currentState!`.
//
// Both dereference an entry the engine did not necessarily write. This
// file holds the two pure decisions the web URL-sync layer needs to keep
// those assertions satisfied; the interop that applies them lives in
// `url_sync_service_web.dart`, which cannot be exercised by a VM test.

/// The state written onto history entries the app pushes itself, in
/// place of the `null` it used to write.
///
/// Non-null is the whole point: an entry carrying `null` is what the
/// engine's teardown dereferences, surfacing to the reader as
/// "Null check operator used on a null value".
///
/// It must also stay *unrecognisable* to the engine. `onPopState`
/// branches on whether the state carries the engine's own `flutter` or
/// `origin` tag, and each branch does something different with the
/// reader's back button. A marker under our own key keeps the app on
/// the same branch it has always taken, so this is a null-safety change
/// and not a navigation change.
const Map<String, Object?> kAppHistoryEntryState = <String, Object?>{
  'seeksparks': true,
};

/// Given the `history.state` a fresh document booted with, returns the
/// state that should replace it, or null to leave it untouched.
///
/// A `serialCount` above zero was written by a *previous* document: it
/// tells the engine that this many history entries are its own and that
/// teardown should rewind past them. Acting on a count inherited across
/// a page load makes the engine rewind into entries it never tagged,
/// where the state is null and the assertion fires. Resetting the count
/// to zero makes the rewind a no-op — which is what a healthy boot does
/// anyway, since a healthy boot lands in single-entry mode and never
/// rewinds at all.
///
/// The wrapped payload under `state` is preserved: it is the framework's
/// own route state and none of this reasoning applies to it.
Map<Object?, Object?>? repairedBootHistoryState(Object? state) {
  if (state is! Map) return null;
  final Object? count = state['serialCount'];
  if (count is! num || count <= 0) return null;
  return Map<Object?, Object?>.of(state)..['serialCount'] = 0;
}
