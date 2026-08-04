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
"$FLUTTER" build web --release \
  --dart-define="APP_VERSION=$APP_VERSION"

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
