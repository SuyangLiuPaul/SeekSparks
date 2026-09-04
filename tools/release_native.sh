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
  "$FLUTTER" build ios --release "${DEFINES[@]}"
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
  "$FLUTTER" build apk --release --flavor intl "${DEFINES[@]}"
  APK="$PROJECT/build/app/outputs/flutter-apk/app-intl-release.apk"
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
echo "✓ native v$APP_VERSION built${DO_INSTALL:+ and installed}."
exit "$rc"
