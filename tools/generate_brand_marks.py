#!/usr/bin/env python3
"""Derive every in-app brand mark from the one master, and check the rest.

Why this file exists
--------------------
`assets/app_icon.png` is named as the master in three places —
pubspec's `flutter_icons.image_path`, `tools/generate_themed_icons.py`
and `tools/generate_site_icons.py` — but nothing ever enforced that it
held the current drawing.

It did not. The sword mark reached the shipped launcher icons in
dc146fc, and its hilt was fixed in b6d9859, but neither commit touched
the master. Two consequences, both live until this script landed:

  * the loading screen, which loads `assets/loading.png` directly, still
    showed the pre-rename SeekSparks mark — a dark ground with an open
    book and gold sparks, no sword at all; and

  * every generator downstream of the master was one run away from
    reverting all six platforms to that same retired drawing. Nothing
    would have failed; the icons would simply have changed back.

So the master is now the drawing, and everything derived from it is
produced here rather than by hand. `test/brand_marks_test.dart` fails
when any output drifts, which is the part that stops a fourth repeat.

The launcher icons themselves are NOT written here — `dart run
flutter_launcher_icons` owns those — but they are checked, because
leaving them out is how the home-screen icon kept the old drawing
through a --check that reported all clear. If that command has to be
run, revert `android/app/src/main/AndroidManifest.xml` afterwards: it
rewrites every activity-alias icon to the default and quietly collapses
the six alternate icons into one.

Usage:
    python3 tools/generate_brand_marks.py            # write the outputs
    python3 tools/generate_brand_marks.py --check    # verify only, exit 1 on drift
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
MASTER = ROOT / "assets" / "app_icon.png"

# The loading screen clips this to a rounded rectangle itself
# (loading_page.dart uses `logoSize * 0.22`), so the file stays a plain
# full-bleed square — rounding it here would round it twice.
LOADING = ROOT / "assets" / "loading.png"

# A pre-rounded 512 with the corners filled rather than punched out, so
# it composites onto any ground. Same 22% radius the app clips at.
ROUNDED = ROOT / "assets" / "app_icon_rounded.png"
ROUNDED_SIZE = 512
CORNER_RATIO = 0.22
CORNER_FILL = (255, 255, 255, 255)


def _load_master() -> Image.Image:
    if not MASTER.exists():
        sys.exit(f"master not found: {MASTER}")
    image = Image.open(MASTER).convert("RGBA")
    if image.size != (1024, 1024):
        sys.exit(f"master must be 1024x1024, got {image.size}")
    return image


def render_loading(master: Image.Image) -> Image.Image:
    return master.copy()


def render_rounded(master: Image.Image) -> Image.Image:
    size = ROUNDED_SIZE
    art = master.resize((size, size), Image.Resampling.LANCZOS)
    radius = round(size * CORNER_RATIO)

    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size - 1, size - 1), radius=radius, fill=255
    )
    ground = Image.new("RGBA", (size, size), CORNER_FILL)
    ground.paste(art, (0, 0), mask)
    return ground


# The Dark alternate icon is the DEFAULT drawing on a dark ground rather
# than a different palette, so it is derived here. The five colour
# variants are authored art and are their own masters — see
# tools/generate_themed_icons.py.
DARK_VARIANT = ROOT / "assets" / "themed_icons" / "Dark.png"
DARK_VARIANT_SIZE = 512
DARK_GROUND = (31, 43, 62)
MARK_GROUND = (178, 224, 247)
GROUND_TOLERANCE = 45.0

# macOS and Windows were the two platforms the rebrand never reached: the
# sword mark landed on iOS, Android and web in dc146fc and nowhere else,
# so a Mac build still opened with the retired SeekSparks drawing in its
# Dock.
MACOS_ICONSET = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
WINDOWS_ICO = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
WINDOWS_ICO_SIZES = [(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]


def render_dark_variant(master: Image.Image) -> Image.Image:
    """The mark on a dark ground.

    Only the ground moves. Pixels are blended toward the dark by how
    close they already are to the ground colour, which carries the
    anti-aliased edges across without leaving a pale fringe, and leaves
    the white cross, the pages and the blade highlight untouched — they
    sit further than GROUND_TOLERANCE away.

    The pale halo that b6d9859 put behind the crossguard, grip and
    pommel is part of the ground and darkens with it. That is the
    intended result: on the dark variant the hilt is separated from the
    book by a dark outline instead of a light one, and stays legible
    either way.
    """
    art = master.convert("RGB")
    width, height = art.size
    source = art.load()
    out = Image.new("RGB", (width, height))
    target = out.load()
    for y in range(height):
        for x in range(width):
            pixel = source[x, y]
            distance = math.dist(pixel, MARK_GROUND)
            if distance >= GROUND_TOLERANCE:
                target[x, y] = pixel
                continue
            weight = 1.0 - distance / GROUND_TOLERANCE
            target[x, y] = tuple(
                round(channel * (1 - weight) + dark * weight)
                for channel, dark in zip(pixel, DARK_GROUND)
            )
    return out.resize(
        (DARK_VARIANT_SIZE, DARK_VARIANT_SIZE), Image.Resampling.LANCZOS
    )


# The DEFAULT launcher icons — the ones on the home screen — are made by
# `dart run flutter_launcher_icons` from the same master, not by this
# script. They are checked here anyway, because they are exactly what
# went stale: the master was trimmed, every mark this script owns was
# regenerated, --check passed, and the icon on the phone still had the
# pages hanging out of the book. A check that clears while the most
# visible surface is wrong is worse than no check.
#
# The comparison is deliberately loose. flutter_launcher_icons resizes
# and (for iOS) flattens alpha with its own filters, so byte equality
# would fail on every run. What must hold is that each icon is the same
# PICTURE as the master: downscale both to a common size and require
# them to agree closely.
LAUNCHER_ICONS = [
    Path("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"),
    Path("android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"),
    Path("web/icons/Icon-512.png"),
    Path("macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png"),
    Path("macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png"),
]
# Only sizes where the drawing is still legible are checked. Below about
# 128 px a change of this kind covers a couple of pixels and cannot be
# told from resampling; those files come out of the same command as the
# ones above, so checking the large ones proves the command was run.
LAUNCHER_MIN_SIZE = 128
# Compared by counting pixels that differ GROSSLY, not by averaging.
# The first version of this check averaged, passed, and let the very
# bug it was written for through: trimming the page block moves about
# 0.2% of the image, and a mean over the whole picture drowns that
# completely. A gross difference is unambiguous — trimming turned page
# white into cover blue, roughly 187 levels — while the resampling
# flutter_launcher_icons applies moves pixels by a few levels at most,
# so the two do not overlap and the threshold is not a guess.
LAUNCHER_COMPARE_SIZE = 512
LAUNCHER_PIXEL_DELTA = 60          # per-channel; well above resampling noise
LAUNCHER_MAX_FRACTION = 0.0005     # 0.05% of the picture may differ that much


def launcher_drift(master: Image.Image) -> list[str]:
    source = master.convert("RGB")
    out: list[str] = []
    for relative in LAUNCHER_ICONS:
        path = ROOT / relative
        if not path.exists():
            out.append(f"{relative} is missing")
            continue
        have = Image.open(path).convert("RGB")
        if have.size[0] < LAUNCHER_MIN_SIZE:
            continue
        # Compare at the icon's OWN size, never above it. Upscaling the
        # smaller image to meet the larger one manufactures edge noise
        # and reports a correct icon as drifted.
        size = min(have.size[0], LAUNCHER_COMPARE_SIZE)
        reference_pixels = list(
            source.resize((size, size), Image.Resampling.LANCZOS).getdata()
        )
        if have.size[0] != size:
            have = have.resize((size, size), Image.Resampling.LANCZOS)
        pixels = list(have.getdata())
        gross = sum(
            1
            for got, want in zip(pixels, reference_pixels)
            if max(abs(a - b) for a, b in zip(got, want)) > LAUNCHER_PIXEL_DELTA
        )
        fraction = gross / len(pixels)
        if fraction > LAUNCHER_MAX_FRACTION:
            out.append(
                f"{relative} differs from {MASTER.name} over {fraction*100:.2f}% "
                f"of the picture — it is not the same drawing. Regenerate with: "
                f"dart run flutter_launcher_icons"
            )
    return out


def macos_targets(master: Image.Image) -> dict[Path, Image.Image]:
    contents_file = MACOS_ICONSET / "Contents.json"
    if not contents_file.exists():
        return {}
    contents = json.loads(contents_file.read_text())
    out: dict[Path, Image.Image] = {}
    for entry in contents["images"]:
        filename = entry.get("filename")
        if not filename:
            continue
        points = float(entry["size"].split("x", 1)[0])
        scale = int(entry["scale"].removesuffix("x"))
        size = round(points * scale)
        out[MACOS_ICONSET / filename] = master.convert("RGB").resize(
            (size, size), Image.Resampling.LANCZOS
        )
    return out


OUTPUTS = {
    LOADING: render_loading,
    ROUNDED: render_rounded,
    DARK_VARIANT: render_dark_variant,
}


def main() -> int:
    check_only = "--check" in sys.argv
    master = _load_master()

    drifted: list[str] = []
    rendered: dict[Path, Image.Image] = {
        path: render(master) for path, render in OUTPUTS.items()
    }

    for path, want in rendered.items():
        rel = path.relative_to(ROOT)

        if check_only:
            if not path.exists():
                drifted.append(f"{rel} is missing")
                continue
            have = Image.open(path).convert("RGBA")
            # Render and file must be compared in one mode: some outputs
            # are built as RGB and every file reads back as RGBA, and a
            # channel-count difference is not drift.
            fresh = want.convert("RGBA")
            if have.size != fresh.size or have.tobytes() != fresh.tobytes():
                drifted.append(f"{rel} does not match a fresh render of {MASTER.name}")
            continue

        want.save(path, optimize=True)
        print(f"wrote {rel}")


    if check_only:
        drifted.extend(launcher_drift(master))

    if check_only:
        if drifted:
            print("brand marks have drifted from the master:", file=sys.stderr)
            for line in drifted:
                print(f"  - {line}", file=sys.stderr)
            print(
                "\nrun: python3 tools/generate_brand_marks.py",
                file=sys.stderr,
            )
            return 1
        print("brand marks match the master")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
