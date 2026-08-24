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
    rendered.update(macos_targets(master))

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

    # Windows keeps every size inside one .ico, so it is written whole
    # rather than per-file.
    if WINDOWS_ICO.parent.exists():
        square = master.convert("RGBA")
        if check_only:
            if not WINDOWS_ICO.exists():
                drifted.append(f"{WINDOWS_ICO.relative_to(ROOT)} is missing")
            else:
                have = Image.open(WINDOWS_ICO).convert("RGBA")
                want = square.resize(have.size, Image.Resampling.LANCZOS)
                if have.tobytes() != want.tobytes():
                    drifted.append(
                        f"{WINDOWS_ICO.relative_to(ROOT)} does not match {MASTER.name}"
                    )
        else:
            square.save(WINDOWS_ICO, sizes=WINDOWS_ICO_SIZES)
            print(f"wrote {WINDOWS_ICO.relative_to(ROOT)}")

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
