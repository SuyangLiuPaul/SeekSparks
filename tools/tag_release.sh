#!/usr/bin/env bash
# Cut the GitHub Release that the in-app update check reads.
#
# THE GAP THIS CLOSES. SeekSparks has had the whole update path since
# v1.3.88 — `UpdateService.checkForUpdate()` asks the GitHub Releases
# API for the latest tag, `UpdateCheckTile` shows it, and
# `.github/workflows/release-android.yml` builds and attaches the APK
# the moment a `v*` tag is pushed. Every piece worked. Nothing ever
# pushed the tag.
#
# So on 2026-09-08 the repository had TWO tags for 255 versions, the
# newest GitHub Release was v1.6.236, and a phone that asked "am I up to
# date?" was told yes, nineteen versions late. A stale answer is worse
# than no answer, because the reader stops asking.
#
# Run this after committing a release. It refuses rather than guesses:
# the version it tags is the one in the COMMITTED pubspec, so a tag can
# never name a build that is not in the history.
#
# Usage:
#   tools/tag_release.sh                 # tag HEAD as v<pubspec version>
#   tools/tag_release.sh --dry-run       # say what it would do
set -euo pipefail

PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT"

DRY=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

# The version as COMMITTED, not as sitting in the working tree. Tagging
# a bump that is still uncommitted would put the tag on the previous
# commit and ship an APK whose version string is a lie — the exact
# family of defect `app_version_fallback_test.dart` exists to catch.
committed_pubspec="$(git show HEAD:pubspec.yaml)"
VERSION="$(awk '/^version:/ {print $2; exit}' <<<"$committed_pubspec")"
VERSION="${VERSION%%+*}"
if [[ -z "$VERSION" ]]; then
  echo "could not read version: from the committed pubspec.yaml" >&2
  exit 1
fi
TAG="v$VERSION"

working_version="$(awk '/^version:/ {print $2; exit}' pubspec.yaml)"
working_version="${working_version%%+*}"
if [[ "$working_version" != "$VERSION" ]]; then
  echo "REFUSING: pubspec.yaml says $working_version but HEAD says $VERSION." >&2
  echo "Commit the version bump first — a tag must name a build that is" >&2
  echo "in the history, or the APK reports a version nobody can check out." >&2
  exit 1
fi

# The literal every native build actually prints (see
# app_version_fallback_test.dart — this drifted for 121 releases once).
fallback="$(grep -oE "defaultValue: '[0-9]+\.[0-9]+\.[0-9]+'" \
  <<<"$(git show HEAD:lib/constants/app_version.dart)" | head -1 |
  grep -oE "[0-9]+\.[0-9]+\.[0-9]+")"
if [[ "$fallback" != "$VERSION" ]]; then
  echo "REFUSING: app_version.dart's fallback is $fallback, pubspec is $VERSION." >&2
  echo "The APK would print $fallback on every screen. Fix and re-commit." >&2
  exit 1
fi

# 2026-09-09 (review finding 7): "already exists" used to be decided
# from the LOCAL tag alone. The tag is created before it is pushed, so
# a push that failed — no network, a rejected credential — left the
# local tag behind and exited 1; the very next run then saw that tag,
# printed "nothing to do", and exited 0. The release-android.yml build
# never fired, the GitHub Release never appeared, and the script had
# said everything was fine. Now: a local tag that origin does not have
# is pushed, and a push that fails takes the local tag with it, so no
# run can inherit a half-done state from the one before.
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  if git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; then
    echo "Tag $TAG already exists on origin — nothing to do."
    echo "(A version is released once. Bump before releasing again.)"
    exit 0
  fi
  echo "==> $TAG exists locally but origin does not have it — pushing"
  if [[ "$DRY" = "1" ]]; then
    echo "--dry-run: would push the existing $TAG, firing release-android.yml"
    exit 0
  fi
  git push origin "$TAG"
  echo
  echo "✓ $TAG pushed."
  exit 0
fi

echo "==> $TAG at $(git rev-parse --short HEAD)"
if [[ "$DRY" = "1" ]]; then
  echo "--dry-run: would tag and push, firing release-android.yml"
  exit 0
fi

git tag -a "$TAG" -m "$TAG"
if ! git push origin "$TAG"; then
  git tag -d "$TAG" >/dev/null
  echo "!!! push of $TAG failed; the local tag was removed so the next" >&2
  echo "!!! run starts clean instead of reporting 'nothing to do'." >&2
  exit 1
fi

echo
echo "✓ $TAG pushed."
echo "  release-android.yml is now building the APK and will attach it"
echo "  to the GitHub Release for $TAG."
echo "  watch: gh run list --workflow=release-android.yml --limit 1"
