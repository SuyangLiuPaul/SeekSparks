#!/usr/bin/env python3
"""Derive every alternate launcher icon size from its own variant master.

This script used to hue-rotate the default mark to make each colour
variant. That worked while the mark was the SeekSparks drawing — a dark
ground with an open book and gold sparks — because the rule it keyed on
("cool ink is anything blue with value < 0.72") happened to select that
ground and nothing else.

It does not work on the current mark. The Yahweh's Swords drawing puts
the book on a PALE blue ground at value 0.97, so the ground fell outside
the rule: re-running the script produced a green book sitting on a blue
background, with the spine and the line down the blade left blue as
well. The shipped variants do not look like that — a green icon is a
green DRAWING, authored as one, and no rotation of the blue art
reproduces it (the closest fit measured 18 levels per channel away).

So the variants are no longer derived from the default mark. Each is its
own master under assets/themed_icons/, which is also the image the
in-app icon picker shows, and this script only resizes those into the
per-platform slots. Dark is the exception and IS derived — see
tools/generate_brand_marks.py, which rebuilds it from the default mark
on the dark ground, because Dark is the default drawing at night rather
than a different palette.

Usage:
    python3 tools/generate_themed_icons.py            # write the sizes
    python3 tools/generate_themed_icons.py --check    # verify only
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
MASTERS = ROOT / "assets" / "themed_icons"
VARIANTS = ["Dark", "Green", "Orange", "Pink", "Purple", "Red"]

ANDROID_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}
WEB_SIZES = [192, 512]


def resize(image: Image.Image, size: int) -> Image.Image:
    if image.size == (size, size):
        return image.copy()
    return image.resize((size, size), Image.Resampling.LANCZOS)


def _targets(variant: str, master: Image.Image) -> dict[Path, Image.Image]:
    out: dict[Path, Image.Image] = {}

    icon_set = ROOT / "ios" / "Runner" / "Assets.xcassets" / f"AppIcon-{variant}.appiconset"
    contents_file = icon_set / "Contents.json"
    if contents_file.exists():
        contents = json.loads(contents_file.read_text())
        for entry in contents["images"]:
            filename = entry.get("filename")
            if not filename:
                continue
            points = float(entry["size"].split("x", 1)[0])
            scale = int(entry["scale"].removesuffix("x"))
            out[icon_set / filename] = resize(master, round(points * scale))

    suffix = variant.lower()
    for density, size in ANDROID_SIZES.items():
        directory = ROOT / "android" / "app" / "src" / "main" / "res" / density
        if directory.exists():
            out[directory / f"ic_launcher_{suffix}.png"] = resize(master, size)

    web = ROOT / "web" / "icons"
    if web.exists():
        for size in WEB_SIZES:
            out[web / f"Icon-{variant}-{size}.png"] = resize(master, size)

    return out


def main() -> int:
    check_only = "--check" in sys.argv
    drifted: list[str] = []

    for variant in VARIANTS:
        path = MASTERS / f"{variant}.png"
        if not path.exists():
            sys.exit(f"variant master missing: {path}")
        master = Image.open(path).convert("RGB")

        for target, image in _targets(variant, master).items():
            rel = target.relative_to(ROOT)
            if check_only:
                if not target.exists():
                    drifted.append(f"{rel} is missing")
                    continue
                have = Image.open(target).convert("RGB")
                if have.size != image.size or have.tobytes() != image.tobytes():
                    drifted.append(f"{rel} does not match {variant}.png resized")
                continue
            image.save(target, optimize=True)

        if not check_only:
            print(f"generated {variant}")

    if check_only:
        if drifted:
            print("alternate icons have drifted from their masters:", file=sys.stderr)
            for line in drifted:
                print(f"  - {line}", file=sys.stderr)
            print("\nrun: python3 tools/generate_themed_icons.py", file=sys.stderr)
            return 1
        print("alternate icons match their masters")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
