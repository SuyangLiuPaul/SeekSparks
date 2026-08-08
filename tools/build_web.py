#!/usr/bin/env python3
"""Wrap `flutter build web --release` so that `kAppVersion` and
`kAppReleaseTime` are auto-stamped from canonical sources.

Why this exists: prior to v1.2.34, both constants in
`lib/constants/app_version.dart` were edited by hand on every
release. Forgetting to bump them — or bumping pubspec.yaml's
`version:` separately — left the About page out of sync with
the actual build. This script makes pubspec's `version:` the
single source of truth + auto-stamps build time.

Behaviour:
  1. Read `version: X.Y.Z` from `pubspec.yaml`.
  2. Capture the build time as an ISO 8601 UTC stamp.
  3. Run `flutter build web --release` into `build/web`, passing
     `--dart-define=APP_VERSION=…` and `--dart-define=APP_RELEASE_TIME=…`.

2026-08-08 (v1.6.62 — one worldwide build): this used to build TWO
flavours, the second with `--dart-define=CHINA_MODE=true` into
`build-cn`. That flag no longer exists in the app, so a `--cn-only`
run would have produced a byte-identical bundle under a name implying
it was different — a trap, not a feature. One flavour now.

Usage:
    python3 tools/build_web.py             # the build
    python3 tools/build_web.py --wasm      # skwasm renderer instead of canvaskit

Then run:
    python3 tools/deploy_site.py --tier dev    # / qat / prod

2026-07-21: `--wasm` builds with Flutter's skwasm (WebAssembly)
renderer instead of the default canvaskit. Re-added after v1.3.132
reverted it — that revert was for a "Failed to load" boot bug that
turned out to be UNRELATED to the renderer (see LoadingPage /
MainProvider.bootInFlight, fixed independently in v1.3.133), so it's
safe to re-try. Still runs single-threaded on every deployed site
(window.crossOriginIsolated is false — no COEP header), so don't
expect a dramatic win. v1.6.62 removed Firebase sign-in, which used
to be the blocker on tightening COOP; multi-threaded skwasm is now
just a headers change away.
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import time

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FLUTTER = os.path.expanduser('~/flutter/bin/flutter')


def read_pubspec_version() -> str:
    """Parse `version: X.Y.Z` from pubspec.yaml — the single
    source of truth. Returns just the semver portion (everything
    before the first `+` build-suffix, if present)."""
    path = os.path.join(REPO_ROOT, 'pubspec.yaml')
    with open(path) as f:
        for line in f:
            m = re.match(r'^version:\s*([0-9A-Za-z.+_-]+)', line)
            if m:
                # Strip Flutter's optional `+buildNumber` suffix —
                # the user-visible string is just X.Y.Z.
                return m.group(1).split('+', 1)[0]
    raise RuntimeError(f"No `version:` field in {path}")


def current_release_time() -> str:
    """ISO 8601 UTC stamp, second-precision — e.g.
    `2026-05-10T09:48:00Z`. The Flutter app's
    `formatReleaseTimeLocal()` parses this and renders in the
    viewer's local timezone. Pre-v1.2.35 this returned a
    Melbourne wall-clock string; the new format ensures users
    everywhere see the time in their own zone."""
    return time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())


def run_build(version: str, release_time: str, *, wasm: bool):
    cmd = [
        FLUTTER, 'build', 'web', '--release',
        # LOAD-BEARING: without this the bootstrap fetches CanvasKit
        # (~1.5 MB, and nothing paints without it) from
        # www.gstatic.com, which is unreachable from mainland China.
        # The same files are already emitted into build/web/canvaskit/.
        # Keep this in step with tools/release_web.sh.
        '--no-web-resources-cdn',
        f'--dart-define=APP_VERSION={version}',
        f'--dart-define=APP_RELEASE_TIME={release_time}',
    ]
    if wasm:
        cmd.append('--wasm')
    renderer = 'skwasm' if wasm else 'canvaskit'
    print(f'==> Building ({renderer}): APP_VERSION={version}, '
          f'APP_RELEASE_TIME={release_time}')
    res = subprocess.run(cmd, cwd=REPO_ROOT)
    if res.returncode != 0:
        print(f'  ✗ flutter build web failed (exit {res.returncode})',
              file=sys.stderr)
        sys.exit(res.returncode)
    print('  ✓ built into build/web')


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--wasm', action='store_true',
                    help='Use the skwasm renderer instead of canvaskit')
    args = ap.parse_args()

    version = read_pubspec_version()
    run_build(version, current_release_time(), wasm=args.wasm)
    print(f'\nDone. v{version} in build/web.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
