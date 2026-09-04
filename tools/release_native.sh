#!/usr/bin/env bash
# Native release for SeekSparks: iPhone, iPad, Mi Pad.
#
# WHY THIS EXISTS. `tools/release_web.sh` passes
# `--dart-define=APP_VERSION=$APP_VERSION`, and until 2026-09-05 it was
# the ONLY thing that did. A native build was whatever
# `flutter build ios` / `flutter build apk` produced by hand, so
# `String.fromEnvironment('APP_VERSION')` fell through to the literal in
# `lib/constants/app_version.dart` — and that literal had frozen at
# 1.3.113 in June, when `bump_version.sh`'s awk anchor stopped matching
# the renamed declaration. The result: the loading page, the workbench
# footer, Settings and About on all three devices announced a version
# 121 patch releases old, next to an Android package manager reporting
# the real one, because THAT comes from pubspec through gradle.
#
# YsWords hit the same drift on 2026-05-22 ("the iOS About page stuck on
# v1.2.67") and fixed it in `yswords-ios-reinstall.sh`. This is that fix
# brought across to the fork, minus the parts that only a launchd job
# needs — no TCC read-cascade and no version cache, because this script
# is run by hand from a shell that can read its own repository.
#
# Usage:
#   tools/release_native.sh              # build + install everywhere
#   tools/release_native.sh --ios        # iPhone + iPad only
#   tools/release_native.sh --android    # Mi Pad only
#   tools/release_native.sh --no-install # build only
#
# It does NOT bump. `tools/release_web.sh` is the one entrypoint that
# starts a release cycle; this one picks up whatever pubspec already
# holds, so web and native ship the same X.Y.Z instead of drifting a
# patch apart the way two independent bumps would.
set -euo pipefail

PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER="${FLUTTER:-$HOME/flutter/bin/flutter}"
export ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17}"
export PATH="$ANDROID_HOME/platform-tools:$JAVA_HOME/bin:$PATH"

DO_IOS=1
DO_ANDROID=1
DO_INSTALL=1
for arg in "$@"; do
  case "$arg" in
    --ios) DO_ANDROID=0 ;;
    --android) DO_IOS=0 ;;
    --no-install) DO_INSTALL=0 ;;
  esac
done

cd "$PROJECT"

APP_VERSION="$(awk '/^version:/ {print $2; exit}' pubspec.yaml || true)"
# `%%+*` strips pubspec's `+build` suffix — that number is Android's
# versionCode and iOS's CFBundleVersion, and showing it to a reader or
# passing it as APP_VERSION would print `1.6.236+1060236` on the About
# page.
APP_VERSION="${APP_VERSION%%+*}"
# The sentinel matters more than it looks. `String.fromEnvironment`'s
# defaultValue applies only when the key is ABSENT — shipping
# `--dart-define=APP_VERSION=` with an empty shell variable OVERRIDES
# the fallback with '', which blanked the version on the Mi Pad in June.
# `unknown` is visibly wrong; an empty string is invisibly wrong.
if [[ -z "$APP_VERSION" ]]; then
  echo "ERROR: could not read version from pubspec.yaml." >&2
  echo "       Shipping APP_VERSION=unknown rather than an empty define." >&2
  APP_VERSION="unknown"
fi
# APP_RELEASE_TIME is deliberately NOT injected: bump_version.sh stamps
# it into the kAppReleaseTime source constant so every platform reads
# one identical value. Injecting `date` per build made the three
# platforms disagree about when the same release happened.
DEFINES=(--dart-define="APP_VERSION=$APP_VERSION")
echo "==> APP_VERSION=$APP_VERSION (release time stamped in source)"

# Verify the BUILT ARTEFACT carries the version, not just the command line.
#
# 2026-09-04: release_native.sh's first run passed
# `--dart-define=APP_VERSION=1.6.235`, gradle reported success, a fresh
# APK appeared — and its compiled Dart still contained 1.3.113 and no
# 1.6.235 at all. A stale `.dart_tool` kernel had been reused, so the
# source change and the define both went into a build that ignored
# them; the tablet then showed v1.3.113 next to a package manager
# reporting 1.6.235, which is the ORIGINAL complaint reappearing from a
# completely different cause. `flutter clean` fixed it.
#
# kAppVersion is a compile-time const, so the string is in the binary
# verbatim or the build is wrong. Checking that is two seconds against
# a twenty-minute round trip to a device, and it turns the silent
# failure into a loud one — which is the only kind worth having, since
# every other signal in that run said success.
verify_version_in() {
  local artefact="$1" label="$2"
  if [[ "$APP_VERSION" = "unknown" ]]; then return 0; fi
  if [[ ! -e "$artefact" ]]; then
    echo "ERROR: $label not found at $artefact" >&2
    return 1
  fi
  # NOT `strings ... | grep -q`: this script runs under `set -o
  # pipefail`, and `grep -q` exits the moment it matches, which kills
  # `strings` with SIGPIPE (141) and makes the whole pipeline report
  # FAILURE on the success case. Caught here first time out, reporting
  # a stale build against a framework that was in fact correct — a
  # check that cries wolf gets switched off, so it has to be right.
  local hits
  hits="$(strings "$artefact" 2>/dev/null | grep -cx "$APP_VERSION" || true)"
  if [[ "${hits:-0}" -gt 0 ]]; then
    echo "    verified: $label carries $APP_VERSION"
    return 0
  fi
  echo "ERROR: $label does NOT contain $APP_VERSION." >&2
  echo "       The build reused a stale kernel and would ship the old" >&2
  echo "       version string. Run: flutter clean && flutter pub get" >&2
  echo "       and build again. NOT installing." >&2
  return 1
}

# Recover from a stale build rather than only reporting one.
#
# `flutter clean` is the known fix and this script has now needed it
# twice in one afternoon — including once WITHIN a single invocation,
# where the iOS framework verified correctly and the APK built minutes
# later from the same defines did not. Building two targets in one run
# is apparently enough to leave the second reading a stale kernel, so a
# check that only reports leaves the operator to run three commands by
# hand every time. This makes the command do what its name says.
#
# Once only. If a clean rebuild still lacks the version string then the
# cause is not the cache, and looping would just hide it.
clean_rebuild() {
  local build_fn="$1"
  echo "==> stale build detected; flutter clean and rebuilding once" >&2
  "$FLUTTER" clean
  "$FLUTTER" pub get
  "$build_fn"
}

IOS_DEVICES=(
  "00008140-000C5D6910E3C01C|iPhone 16 Pro Max"
  "00008103-000A24441131001E|iPad Pro 11-inch"
)
# Hardware udids, NOT the Identifier column `xcrun devicectl list
# devices` prints — that is a CoreDevice UUID which no provisioning
# profile ever contains. `--json-output` → hardwareProperties.udid.
ANDROID_DEVICES=("0907E41001A00540|Mi Pad")

rc=0

if [[ "$DO_IOS" = "1" ]]; then
  echo ""
  echo "→ flutter build ios --release ${DEFINES[*]}"
  build_ios() { "$FLUTTER" build ios --release "${DEFINES[@]}"; }
  IOS_APP_BIN="$PROJECT/build/ios/iphoneos/Runner.app/Frameworks/App.framework/App"
  build_ios
  if ! verify_version_in "$IOS_APP_BIN" "the iOS App.framework"; then
    clean_rebuild build_ios
    verify_version_in "$IOS_APP_BIN" "the iOS App.framework"
  fi
  if [[ "$DO_INSTALL" = "1" ]]; then
    for entry in "${IOS_DEVICES[@]}"; do
      udid="${entry%|*}"; name="${entry#*|}"
      echo "==> installing on $name"
      # A per-device failure must not stop the others: one asleep or
      # unplugged device is not a reason to leave the rest behind.
      if ! xcrun devicectl device install app --device "$udid" \
          build/ios/iphoneos/Runner.app; then
        echo "WARN: $name failed. If this is 0xe8008012 the profile does" >&2
        echo "      not carry this device — register it once with:" >&2
        echo "      cd ios && xcodebuild -workspace Runner.xcworkspace \\" >&2
        echo "        -scheme Runner -configuration Release \\" >&2
        echo "        -destination 'id=$udid' \\" >&2
        echo "        -allowProvisioningUpdates \\" >&2
        echo "        -allowProvisioningDeviceRegistration build" >&2
        rc=1
      fi
    done
  fi
fi

if [[ "$DO_ANDROID" = "1" ]]; then
  echo ""
  echo "→ flutter build apk --release --flavor intl ${DEFINES[*]}"
  build_apk() {
    "$FLUTTER" build apk --release --flavor intl "${DEFINES[@]}"
  }
  build_apk
  APK="$PROJECT/build/app/outputs/flutter-apk/app-intl-release.apk"
  # The version lives in the compiled Dart, so unpack libapp.so rather
  # than scanning the whole 166 MB archive.
  check_apk() {
    # A fresh directory per attempt, so a rebuild is never verified
    # against the previous attempt's extracted copy — which would make
    # the retry pass on stale evidence, the exact failure this whole
    # check exists to catch.
    local dir
    dir="$(mktemp -d)"
    unzip -o -q "$APK" "lib/arm64-v8a/libapp.so" -d "$dir" 2>/dev/null || true
    verify_version_in "$dir/lib/arm64-v8a/libapp.so" "the APK's libapp.so"
  }
  if ! check_apk; then
    clean_rebuild build_apk
    check_apk
  fi
  if [[ "$DO_INSTALL" = "1" ]]; then
    for entry in "${ANDROID_DEVICES[@]}"; do
      serial="${entry%|*}"; name="${entry#*|}"
      echo "==> installing on $name"
      if ! adb -s "$serial" install -r "$APK"; then
        echo "WARN: $name failed (offline, or HyperOS's Install-via-USB" >&2
        echo "      toggle turned itself off again)." >&2
        rc=1
      fi
    done
  fi
fi

echo ""
# `${DO_INSTALL:+...}` was wrong here: DO_INSTALL is "0" under
# --no-install, which is NON-EMPTY, so the script claimed it had
# installed when it had not.
if [[ "$DO_INSTALL" = "1" ]]; then
  echo "✓ native v$APP_VERSION built and installed."
else
  echo "✓ native v$APP_VERSION built (not installed)."
fi
exit "$rc"
