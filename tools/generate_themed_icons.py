#!/usr/bin/env python3
"""Regenerate every alternate launcher icon from the current master artwork.

The colour variants deliberately tint only the ink-blue parts of the current
SeekSparks mark. The white pages and gold sparks/words stay unchanged, so a
brand refresh cannot leave the alternate icons carrying an older drawing.
"""

from __future__ import annotations

import colorsys
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent.parent
MASTER = ROOT / "assets" / "app_icon.png"
VARIANTS = {
    "Dark": None,
    "Green": "#176B4A",
    "Orange": "#A14F16",
    "Pink": "#A3376E",
    "Purple": "#603C9E",
    "Red": "#9E3038",
}
ANDROID_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


def _rgb(hex_colour: str) -> tuple[int, int, int]:
    return tuple(int(hex_colour[i : i + 2], 16) for i in (1, 3, 5))


def tint_ink(master: Image.Image, target: str | None) -> Image.Image:
    image = master.convert("RGB")
    if target is None:
        return image

    target_h, target_s, _ = colorsys.rgb_to_hsv(
        *[channel / 255 for channel in _rgb(target)]
    )
    pixels = []
    for red, green, blue in image.get_flattened_data():
        hue, saturation, value = colorsys.rgb_to_hsv(
            red / 255, green / 255, blue / 255
        )
        # The master uses cool ink-blue for the ground, shadows, gutter and
        # unlit words. Preserve the bright pages and every warm gold pixel.
        is_cool_ink = blue >= red * 1.04 and value < 0.72
        if is_cool_ink:
            strength = min(1.0, max(0.35, (0.72 - value) / 0.55))
            hue = target_h
            saturation = saturation * (1 - strength) + target_s * strength
            red_f, green_f, blue_f = colorsys.hsv_to_rgb(hue, saturation, value)
            pixels.append((round(red_f * 255), round(green_f * 255), round(blue_f * 255)))
        else:
            pixels.append((red, green, blue))
    image.putdata(pixels)
    return image


def resize(image: Image.Image, size: int) -> Image.Image:
    return image.resize((size, size), Image.Resampling.LANCZOS)


def generate_ios(variant: str, image: Image.Image) -> None:
    icon_set = ROOT / "ios" / "Runner" / "Assets.xcassets" / f"AppIcon-{variant}.appiconset"
    contents = json.loads((icon_set / "Contents.json").read_text())
    for entry in contents["images"]:
        filename = entry["filename"]
        points = float(entry["size"].split("x", 1)[0])
        scale = int(entry["scale"].removesuffix("x"))
        resize(image, round(points * scale)).save(icon_set / filename)


def generate_android(variant: str, image: Image.Image) -> None:
    suffix = variant.lower()
    for density, size in ANDROID_SIZES.items():
        output = ROOT / "android" / "app" / "src" / "main" / "res" / density
        resize(image, size).save(output / f"ic_launcher_{suffix}.png")


def main() -> None:
    master = Image.open(MASTER)
    output = ROOT / "assets" / "themed_icons"
    output.mkdir(exist_ok=True)
    for variant, target in VARIANTS.items():
        image = tint_ink(master, target)
        image.save(output / f"{variant}.png", optimize=True)
        generate_ios(variant, image)
        generate_android(variant, image)
        print(f"generated {variant}")


if __name__ == "__main__":
    main()
