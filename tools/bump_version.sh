#!/usr/bin/env bash
# 2026-05-24 (v1.3.9): auto-bump APP_VERSION patch + write it to BOTH
# pubspec.yaml and lib/constants/app_version.dart in lock-step.
#
# User asked: "version numbers why not update automatically with time
# local time". The release TIME was already auto-stamped at build
# time (yswords-ios-reinstall.sh sets APP_RELEASE_TIME from
# `date -u`). The VERSION NUMBER was manually edited in two files
# every commit, easy to forget, easy to drift between pubspec.yaml
# and the Dart default.
#
# Strategy: monotonic patch bump per call. Major.Minor stays
# manually-bumped (intentional — those mark architectural eras
# like the v1.2 → v1.3 PageView refactor). Patch is auto.
#
# Usage:
#   tools/bump_version.sh           # bump patch by 1 (1.3.8 → 1.3.9)
#   tools/bump_version.sh --print   # just print current version
#   tools/bump_version.sh --set 1.3.10  # set explicit version
#
# Called automatically by tools/yswords-ios-reinstall.sh before
# every multi-platform build. Web build wrapper does the same.
set -euo pipefail

PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBSPEC="$PROJECT/pubspec.yaml"
APP_VERSION_DART="$PROJECT/lib/constants/app_version.dart"

current_version() {
  awk '/^version:/ {print $2; exit}' "$PUBSPEC"
}

case "${1:-}" in
  --print)
    current_version
    exit 0
    ;;
  --set)
    if [[ -z "${2:-}" ]]; then
      echo "bump_version.sh: --set requires a version argument" >&2
      exit 2
    fi
    NEW="$2"
    ;;
  *)
    CUR="$(current_version)"
    # Parse semver MAJOR.MINOR.PATCH. Extra build metadata
    # (e.g. "+timestamp") gets stripped — the auto-stamp lives in
    # APP_RELEASE_TIME, not in the version string itself.
    IFS='.' read -r MA MI PA <<<"$CUR"
    PA="${PA%%+*}" # strip any +build metadata
    NEW="$MA.$MI.$((PA + 1))"
    ;;
esac

echo "==> bumping version: $(current_version) → $NEW"

# Update pubspec.yaml — single `version: X.Y.Z` line at root.
# sed -i variants differ between BSD (macOS default) and GNU; use
# a temp file for portability.
TMP="$(mktemp)"
awk -v new="$NEW" '
  BEGIN { done = 0 }
  /^version:/ && !done { print "version: " new; done = 1; next }
  { print }
' "$PUBSPEC" >"$TMP"
mv "$TMP" "$PUBSPEC"

# Update lib/constants/app_version.dart — BOTH version literals.
#
# 2026-09-05: this block matched `const String kAppVersion =
# String.fromEnvironment(` and had therefore been a NO-OP since
# 2026-06-29, when that declaration was split in two to guard the
# empty-define case: the environment read moved to `_envAppVersion` and
# `kAppVersion` became a ternary with a SECOND copy of the literal. The
# awk pattern matched neither, silently, so the fallback froze at
# 1.3.113 while pubspec went on to 1.6.234.
#
# That literal is what every NATIVE build prints, because only
# release_web.sh passes --dart-define=APP_VERSION: the loading page,
# the workbench footer, Settings and About on the iPhone, the iPad and
# the Mi Pad all announced a version 121 patch releases old, next to an
# Android package manager reporting the real one. Reported as
# 「为什么loading page和各个地方的版本号对不上」.
#
# Both literals are rewritten now, and test/app_version_fallback_test
# fails if either drifts from pubspec — so this cannot go quiet again.
TMP="$(mktemp)"
awk -v new="$NEW" '
  /_envAppVersion = String\.fromEnvironment\(/ { in_block = 1 }
  in_block && /defaultValue:/ {
    sub(/defaultValue: '\''[^'\'']*'\''/, "defaultValue: '\''" new "'\''")
    in_block = 0
  }
  /^const String kAppVersion = _envAppVersion == / {
    sub(/\? '\''[^'\'']*'\''/, "? '\''" new "'\''")
  }
  { print }
' "$APP_VERSION_DART" >"$TMP"
mv "$TMP" "$APP_VERSION_DART"

# 2026-06-09 (v1.3.59): ALSO stamp kAppReleaseTime's defaultValue with
# the current UTC ISO-8601 moment. Previously this relied ENTIRELY on
# each build injecting --dart-define=APP_RELEASE_TIME, which proved
# unreliable: a gradle no-op or an empty/missing inject left the About
# footer's "last updated" BLANK (Mi Pad) or showing different values
# across iOS/web/Android. Stamping the constant makes it a single
# source of truth baked into the source for EVERY platform —
# formatReleaseTimeLocal() converts the ISO UTC to the viewer's local
# timezone. Builds no longer need to pass APP_RELEASE_TIME at all.
RELEASE_TIME="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
TMP="$(mktemp)"
awk -v rt="$RELEASE_TIME" '
  /const String kAppReleaseTime = String\.fromEnvironment\(/ { in_block = 1 }
  in_block && /defaultValue:/ {
    sub(/defaultValue: '\''[^'\'']*'\''/, "defaultValue: '\''" rt "'\''")
    in_block = 0
  }
  { print }
' "$APP_VERSION_DART" >"$TMP"
mv "$TMP" "$APP_VERSION_DART"

echo "✓ pubspec.yaml + app_version.dart now at $NEW (release time: $RELEASE_TIME)"
