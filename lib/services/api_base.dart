// 2026-05-21 (v1.2.69): centralised base-URL resolution for the
// Netlify Functions API (/api/*).
//
// Why: on web the app is served from seeksparks.netlify.app, so the
// relative path `/api/aiSearch` resolves same-origin and avoids CORS
// preflight. On native (iOS / Android / macOS) there's no origin —
// `Uri.parse('/api/aiSearch')` produces a hostless URI that http.post
// can't dial. We resolve to the absolute production URL on native.
//
// Override via `--dart-define=SEEKSPARKS_BASE_URL=https://...` for
// staging / dev / local netlify-dev (e.g.
// `--dart-define=SEEKSPARKS_BASE_URL=http://localhost:8888`).

import 'package:flutter/foundation.dart' show kIsWeb;

/// Production base URL. Native builds prepend this to relative
/// `/api/...` paths; web builds keep paths relative (same-origin).
const String kSeekSparksBaseUrl = String.fromEnvironment(
  'SEEKSPARKS_BASE_URL',
  defaultValue: 'https://seeksparks.netlify.app',
);

/// Resolves an API path to a full URL.
///   • If [path] already starts with `http`, return it unchanged.
///   • Else on web: return [path] as-is (same-origin).
///   • Else (native): prepend [kSeekSparksBaseUrl].
String resolveApiUrl(String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path;
  }
  if (kIsWeb) return path;
  return '$kSeekSparksBaseUrl$path';
}
