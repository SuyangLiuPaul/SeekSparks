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

# The netlify CLI lives in another project's node_modules, so a cleanup
# over there can silently disarm releases here. Say so up front.
if [ ! -x "$NETLIFY" ]; then
  echo "netlify CLI not found or not executable at:" >&2
  echo "  $NETLIFY" >&2
  echo "Restore it with:" >&2
  echo "  (cd ~/Documents/CodingProject/SmartHome && npm install netlify-cli --no-save --legacy-peer-deps)" >&2
  echo "or point NETLIFY= at another copy." >&2
  exit 1
fi

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

# 2026-09-09 (review finding 6): whether a site got the build is decided
# by asking the SITE, not by the CLI's exit code. Words' sibling script
# recorded the case this guards — `netlify deploy` exited 0, and Netlify
# later marked the deploy "canceled", so the site went on serving the
# previous version under a "✓ deployed" line. No exit code can carry a
# state the service sets after the process has ended; re-fetching
# version.json can. Three attempts with a pause, because a single
# dropped connection must not be able to fail a release that succeeded.
# `RELEASE_VERIFY_SLEEP` exists for the script's own test, which has no
# reason to wait ten seconds to see the failure path.
RELEASE_VERIFY_SLEEP="${RELEASE_VERIFY_SLEEP:-5}"
verify_site() {
  local name="$1" host="$2" served="" attempt
  for attempt in 1 2 3; do
    served="$(curl -fsS --max-time 30 "https://$host/version.json" 2>/dev/null \
      | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
    if [[ "$served" = "$APP_VERSION" ]]; then
      echo "  ✓ $name — https://$host serves v$APP_VERSION"
      return 0
    fi
    if [[ "$attempt" != "3" ]]; then sleep "$RELEASE_VERIFY_SLEEP"; fi
  done
  echo "  ✗ $name — https://$host serves version '${served:-none}', expected $APP_VERSION" >&2
  return 1
}

# Deploy build/web to each "id:name:host" entry (parallel, then wait),
# then verify every one of them against what it actually serves.
# Every deploy's exit status is checked. The previous version backgrounded
# them and called a bare `wait`, which returns the status of the LAST job
# and was never read anyway -- so on 2026-09-09, with the netlify binary
# missing entirely, this script printed "deployed" for two sites it had
# not reached. A release script that lies about deploying is worse than
# one that fails.
deploy_sites() {
  local -a pids=() names=() hosts=()
  local failed=0 id name host
  for entry in "$@"; do
    IFS=':' read -r id name host <<<"$entry"
    echo "==> deploying $name ($id)"
    "$NETLIFY" deploy --prod --site "$id" --dir build/web \
      --message "v$APP_VERSION $name" &
    pids+=("$!")
    names+=("$name")
    hosts+=("$host")
  done
  local i
  for i in "${!pids[@]}"; do
    if ! wait "${pids[$i]}"; then
      echo "!!! deploy FAILED: ${names[$i]}" >&2
      failed=1
    fi
  done
  if [ "$failed" -ne 0 ]; then
    echo "!!! at least one site did not receive this build. Nothing was" >&2
    echo "!!! released. Fix the cause and re-run; do not tag." >&2
    exit 1
  fi
  echo "==> verifying what each site serves"
  for i in "${!names[@]}"; do
    if ! verify_site "${names[$i]}" "${hosts[$i]}"; then
      failed=1
    fi
  done
  if [ "$failed" -ne 0 ]; then
    echo "!!! the CLI reported success but at least one site above is not" >&2
    echo "!!! serving v$APP_VERSION. Nothing counts as released until it" >&2
    echo "!!! does. Re-run the deploy for that site; do not tag." >&2
    exit 1
  fi
}

# 2026-09-09: the release time is NOT computed here, and must not be.
#
# The comment that stood here said APP_RELEASE_TIME "was never passed,
# so kAppReleaseTime kept falling back to a hand-edited default" — and
# then the next line computed one and passed it, which is the opposite
# of what the paragraph argued. Both halves were out of date:
# tools/bump_version.sh has stamped kAppReleaseTime's defaultValue into
# app_version.dart since v1.3.59, precisely so that "builds no longer
# need to pass APP_RELEASE_TIME at all" (its own words).
#
# Passing one anyway gave a version TWO release times. The APK from
# release-android.yml, the iOS build and the checked-in source all read
# the stamped constant; only web read this `date`. On a `--no-bump`
# re-cut — which docs/release-policy.md's prod step is — they diverge by
# however long is between the two runs, and the About page's "last
# updated" disagrees across platforms for one version number. That
# disagreement is the exact symptom v1.3.59 introduced the stamping to
# end.

# 2026-09-09: refresh the bundled changelog before the build, or the
# app ships a "What's new" page that stops at whenever somebody last
# remembered to run the generator by hand.
#
# AFTER the bump and BEFORE `flutter build`, and told which version it
# is building for (review finding 1, 2026-09-09). The earlier comment
# here argued the opposite — that the version being released "has not
# shipped" and so belonged off the page. That was wrong from the
# reader's side: they open "What's new" ON this version, the page's
# badge marks the running version, and with the entry missing the
# badge never rendered and the top of the page was always one release
# stale. The generator synthesises this version's entry from the
# commits after the last `release:` anchor, which is exactly what the
# release commit made after this deploy will span.
echo "==> refreshing assets/changelog.json for v$APP_VERSION"
python3 "$PROJECT/tools/build_changelog.py" \
  --head-version "$APP_VERSION" --head-date "$(date +%Y-%m-%d)"
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
echo "==> building web bundle"
"$FLUTTER" build web --release \
  --no-web-resources-cdn \
  --dart-define="APP_VERSION=$APP_VERSION"

# "id:name:host" — the host is what verify_site re-fetches version.json
# from after the deploy, so it must be the address readers actually
# use, not the Netlify alias (prod answers at both; the custom domain
# is the one that matters).
SITES=(
  "94de1ce4-b58e-4368-84f4-34165e7f6be5:dev:seeksparks-dev.netlify.app"
)
if [[ "$INCLUDE_PROD" = "1" ]]; then
  echo "==> --include-prod set; build will also go to seeksparks prod."
  SITES+=("7ae9dbe7-c297-4240-817e-a8e7f8cf6cfc:prod:sword.yahwehword.com")
fi
deploy_sites "${SITES[@]}"

echo
echo "✓ v$APP_VERSION deployed."
echo "  next: git commit + push"
# 2026-09-08: and then the tag, which is the step that had been missing
# since the update path shipped. Everything else in that path worked —
# the API call, the tile, the APK workflow — but nothing ever pushed a
# `v*` tag, so 255 versions produced two GitHub Releases and a phone
# asking "am I up to date?" was told yes, nineteen versions late. Named
# here because this is the script people actually run; `tag_release.sh`
# carries the reasoning and does the checking.
echo "  then:  tools/tag_release.sh   # cuts the GitHub Release + APK"
echo "         (without it the in-app update check keeps reporting the"
echo "          last tag, which is not the build you just deployed)"
