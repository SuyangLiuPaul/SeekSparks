// 2026-05-20 (v1.2.67): web impl of `clearCacheAndReload`. Calls
// the `seekSparksClearCacheAndReload()` function defined in
// `web/index.html` which unregisters all service workers, nukes
// the browser cache buckets, and hard-reloads the page.

import 'dart:js_interop';

@JS('seekSparksClearCacheAndReload')
external void _seekSparksClearCacheAndReload();

void clearCacheAndReload() {
  _seekSparksClearCacheAndReload();
}
