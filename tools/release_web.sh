#!/usr/bin/env bash
# Single-command web release for SeekSparks.
#
# Unlike YsWords (which this was forked from), SeekSparks ships ONE
# international build only — no CHINA_MODE bundle, no cn-* sites (see
# the fork plan's "explicitly deferred" list). Just dev + prod.
#
# Usage:
#   tools/release_web.sh                   # bump patch, build, deploy dev
#   tools/release_web.sh --no-bump         # use current pubspec version
#   tools/release_web.sh --include-prod    # ALSO push to seeksparks prod (REQUIRES user OK)
set -euo pipefail

PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER="${FLUTTER:-$HOME/flutter/bin/flutter}"
NETLIFY="${NETLIFY:-$HOME/Documents/CodingProject/SmartHome/node_modules/.bin/netlify}"

BUMP=1
INCLUDE_PROD=0
for arg in "$@"; do
  case "$arg" in
    --no-bump) BUMP=0 ;;
    --include-prod) INCLUDE_PROD=1 ;;
  esac
done

if [[ "$BUMP" = "1" ]]; then
  "$PROJECT/tools/bump_version.sh"
fi
APP_VERSION="$(awk '/^version:/ {print $2; exit}' "$PROJECT/pubspec.yaml")"
# `%%+*` strips pubspec's `+build` suffix — that number is Android's
# versionCode and iOS's CFBundleVersion, and showing it to a reader or
# passing it as APP_VERSION would print `1.6.236+1060236` on the About
# page.
APP_VERSION="${APP_VERSION%%+*}"
echo "==> APP_VERSION=$APP_VERSION"

cd "$PROJECT"

# Deploy build/web to each "id:name" entry (parallel, then wait).
deploy_sites() {
  for entry in "$@"; do
    id="${entry%:*}"
    name="${entry#*:}"
    echo "==> deploying $name ($id)"
    "$NETLIFY" deploy --prod --site "$id" --dir build/web \
      --message "v$APP_VERSION $name" &
  done
  wait
}

echo "==> building web bundle"
# APP_RELEASE_TIME was never passed here, so `kAppReleaseTime` kept
# falling back to the hardcoded default in app_version.dart — the
# "last updated" the app showed was whenever that constant was last
# hand-edited, not when the bundle was actually built.
APP_RELEASE_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
#
# --no-web-resources-cdn is LOAD-BEARING, not an optimisation.
#
# Flutter's default bootstrap fetches CanvasKit (~1.5 MB, and the app
# cannot paint a single pixel without it) from
# https://www.gstatic.com/flutter-canvaskit/<engine-rev>/. That host is
# not reachable from mainland China, so the default build hangs on a
# blank page there no matter what the Dart code does. `flutter build
# web` already emits the same files into build/web/canvaskit/; this
# flag just makes the bootstrap use them, off our own origin.
#
# v1.6.62 removed Firebase and google_fonts to get Google off the boot
# path. Leaving this flag off would have left the single largest
# Google dependency in place and made that work cosmetic.
"$FLUTTER" build web --release \
  --no-web-resources-cdn \
  --dart-define="APP_VERSION=$APP_VERSION" \
  --dart-define="APP_RELEASE_TIME=$APP_RELEASE_TIME"

SITES=(
  "94de1ce4-b58e-4368-84f4-34165e7f6be5:dev"
)
if [[ "$INCLUDE_PROD" = "1" ]]; then
  echo "==> --include-prod set; build will also go to seeksparks prod."
  SITES+=("7ae9dbe7-c297-4240-817e-a8e7f8cf6cfc:prod")
fi
deploy_sites "${SITES[@]}"

echo
echo "✓ v$APP_VERSION deployed."
echo "  next: git commit + push"
