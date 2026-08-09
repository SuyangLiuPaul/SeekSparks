#!/usr/bin/env bash
# Regenerate assets/maps/thumbs/ — a 420px-wide JPEG per bundled plate.
#
# The 55 plates in assets/maps/ are survey maps up to 1920x3288 (29 MB,
# 95 megapixels for the set). The Illustrations grid puts ~28 on screen
# at once; decoding those at full size never produced a frame on a
# software rasteriser, and Image's `cacheWidth` does not prevent the
# decode. These copies are 2.4 MB in total. The viewer still loads the
# full plate, because that one is zoomed to 5x.
#
# Run after adding a plate. `IllustrationImage(thumb: true)` falls back
# to the full asset if a thumbnail is missing, so forgetting this is
# slow rather than broken.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p assets/maps/thumbs
n=0
for f in assets/maps/*.jpg assets/maps/*.png assets/maps/*.gif; do
  [ -e "$f" ] || continue
  b="$(basename "$f")"
  sips -s format jpeg -s formatOptions 72 -Z 420 "$f" \
    --out "assets/maps/thumbs/${b%.*}.jpg" >/dev/null
  n=$((n + 1))
done
echo "$n thumbnails -> assets/maps/thumbs ($(du -sh assets/maps/thumbs | cut -f1))"
