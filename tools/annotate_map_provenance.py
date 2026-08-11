#!/usr/bin/env python3
"""Give every plate in assets/maps_index.json a recorded origin (task #300).

The archive shipped 1,192 illustrations whose only "source" field said
where the BYTES load from — asset / cdn / legacy_url — and never where the
IMAGE CAME FROM. That is not the same question, and the difference is not
academic: 40 of these are Sweet Publishing images whose upstream licence
is CC BY-SA 3.0 with `AttributionRequired = true`, so shipping them
uncredited is a licence breach, not a missing nicety.

Provenance is recorded per COLLECTION, not per plate. One credit per
source is the truth-bearing unit; 1,192 copies of the same string is 1,192
places for it to drift. Each entry gets a `collection` key naming its
record, written explicitly rather than derived from the id prefix at read
time, so nothing depends on a filename convention holding.

`licenseBasis` is the field that keeps this honest. It separates "Commons
returned this licence when asked" from "the entry's own description said
public domain and nobody re-checked" from "nothing was recorded". Without
it every row reads equally confident and the document becomes decoration.

Run:  python3 tools/annotate_map_provenance.py [--check]
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
INDEX = ROOT / "assets" / "maps_index.json"
PROVENANCE = ROOT / "assets" / "maps_provenance.json"
SWEET_TOOL = ROOT / "tools" / "generate_sweet_entries.py"

COMMONS_FILE = "https://commons.wikimedia.org/wiki/File:"
CC_BY_SA_3 = "https://creativecommons.org/licenses/by-sa/3.0/"


def collection_of(entry: dict) -> str:
    """Which provenance record an entry belongs to.

    Used once, here, to write the key into the asset. Read-time code must
    use the stored key — a prefix rule that lives in two places is a rule
    that will disagree with itself.
    """
    entry_id = entry.get("id", "")
    if entry_id.startswith("illus_"):
        family = entry_id[len("illus_"):].split("_")[0]
        return {
            "tissot": "tissot",
            "schnorr": "schnorr",
            "dore": "dore",
            "sweet": "sweet",
            "rembrandt": "rembrandt",
            "extra": "masters",
        }.get(family, "unrecorded")
    if entry.get("source") == "asset":
        return "bundled-maps"
    return "scene-topups"


def sweet_source_urls() -> dict[str, str]:
    """Exact Commons file page per Sweet plate, taken from the generator.

    The stems are imported from `generate_sweet_entries.py` rather than
    reconstructed from our own ids, because a reconstructed URL that
    resolves to the wrong plate is worse than no URL: it credits the
    right author for the wrong picture and looks verified.
    """
    spec = importlib.util.spec_from_file_location("sweet_gen", SWEET_TOOL)
    module = importlib.util.module_from_spec(spec)
    sys.modules["sweet_gen"] = module
    spec.loader.exec_module(module)
    urls = {}
    for stem, book, chapter, image_num in module.IMAGES:
        entry_id = module.make_entry_id(book, chapter, image_num)
        urls[entry_id] = (
            COMMONS_FILE + stem + "_(Bible_Illustrations_by_Sweet_Media).jpg"
        )
    return urls


# The eight records. Every one states a licence explicitly — "unknown" is
# a finding, an absent field is only a gap in the audit, and the two must
# not look alike.
COLLECTIONS = [
    {
        "id": "tissot",
        "name": {
            "en": "James Tissot — Bible watercolours",
            "zh-Hans": "詹姆斯·迪索 — 圣经水彩",
            "zh-Hant": "詹姆斯·迪索 — 聖經水彩",
        },
        "artist": "James Jacques Joseph Tissot (1836–1902)",
        "work": "The Life of Our Saviour Jesus Christ; The Old Testament",
        "years": "1886–1902",
        "holder": "Brooklyn Museum",
        "license": "public-domain",
        "licenseBasis": "author-death",
        "licenseNote": "Tissot died in 1902; the watercolours have been "
                       "public domain worldwide for over a century.",
        "attributionRequired": False,
        "credit": "James Tissot (1836–1902), Brooklyn Museum.",
        "sourceUrl": "https://commons.wikimedia.org/wiki/Category:Bible_illustrations_by_Jean-James_Tissot",
    },
    {
        "id": "schnorr",
        "name": {
            "en": "Julius Schnorr von Carolsfeld — Die Bibel in Bildern",
            "zh-Hans": "施诺尔·冯·卡罗尔斯费尔德 — 图画圣经",
            "zh-Hant": "施諾爾·馮·卡羅爾斯費爾德 — 圖畫聖經",
        },
        "artist": "Julius Schnorr von Carolsfeld (1794–1872)",
        "work": "Die Bibel in Bildern",
        "years": "1860",
        "holder": None,
        "license": "public-domain",
        "licenseBasis": "author-death",
        "licenseNote": "Published 1860; the artist died in 1872.",
        "attributionRequired": False,
        "credit": "Julius Schnorr von Carolsfeld, Die Bibel in Bildern (1860).",
        "sourceUrl": "https://commons.wikimedia.org/wiki/Category:Die_Bibel_in_Bildern",
    },
    {
        "id": "dore",
        "name": {
            "en": "Gustave Doré — Bible engravings",
            "zh-Hans": "古斯塔夫·多雷 — 圣经版画",
            "zh-Hant": "古斯塔夫·多雷 — 聖經版畫",
        },
        "artist": "Gustave Doré (1832–1883)",
        "work": "La Grande Bible de Tours",
        "years": "1866",
        "holder": None,
        "license": "public-domain",
        "licenseBasis": "author-death",
        "licenseNote": "Published 1866; the artist died in 1883.",
        "attributionRequired": False,
        "credit": "Gustave Doré, La Grande Bible de Tours (1866).",
        "sourceUrl": "https://commons.wikimedia.org/wiki/Category:Gustave_Dor%C3%A9",
    },
    {
        "id": "rembrandt",
        "name": {
            "en": "Rembrandt van Rijn",
            "zh-Hans": "伦勃朗·凡·莱因",
            "zh-Hant": "林布蘭·凡·萊因",
        },
        "artist": "Rembrandt Harmenszoon van Rijn (1606–1669)",
        "work": None,
        "years": "1626–1669",
        "holder": None,
        "license": "public-domain",
        "licenseBasis": "author-death",
        "licenseNote": "The artist died in 1669.",
        "attributionRequired": False,
        "credit": "Rembrandt van Rijn (1606–1669).",
        "sourceUrl": "https://commons.wikimedia.org/wiki/Category:Paintings_by_Rembrandt",
    },
    {
        "id": "sweet",
        "name": {
            "en": "Sweet Publishing / Distant Shores Media",
            "zh-Hans": "Sweet Publishing / Distant Shores Media",
            "zh-Hant": "Sweet Publishing / Distant Shores Media",
        },
        "artist": "Jim Padgett",
        "work": "Bible illustrations by Sweet Media",
        "years": "1984",
        "holder": "Sweet Publishing, Ft. Worth, TX / Gospel Light, Ventura, CA",
        # The only collection in the archive that is NOT public domain.
        # Queried from the Commons API on 2026-08-11: LicenseShortName
        # "CC BY-SA 3.0", AttributionRequired "true".
        "license": "cc-by-sa-3.0",
        "licenseBasis": "upstream-declared",
        "licenseNote": "Wikimedia Commons reports AttributionRequired = true. "
                       "The credit line below is the wording the upstream "
                       "release specifies and is a condition of shipping "
                       "these 40 plates.",
        "attributionRequired": True,
        "credit": "Biblical illustrations by Jim Padgett, courtesy of Sweet "
                  "Publishing, Ft. Worth, TX, and Gospel Light, Ventura, CA. "
                  "Copyright 1984. Released under CC BY-SA 3.0.",
        "licenseUrl": CC_BY_SA_3,
        "sourceUrl": "https://www.dsmedia.org/resources/illustrations/sweet-publishing",
    },
    {
        "id": "masters",
        "name": {
            "en": "European masters (assorted)",
            "zh-Hans": "欧洲古典名画（杂项）",
            "zh-Hant": "歐洲古典名畫（雜項）",
        },
        "artist": None,
        "work": None,
        "years": None,
        "holder": None,
        # Bruegel, Rembrandt and Doré are named in four of the nine
        # titles and are plainly out of copyright. The other five name
        # no artist, so the public-domain status is inherited from the
        # archive's own description and has not been re-verified against
        # the upstream file. Saying so is the difference between a check
        # and an assumption.
        "license": "public-domain",
        "licenseBasis": "entry-description",
        "licenseNote": "Each entry's own description declares the work "
                       "public domain. Four name the artist (Bruegel, "
                       "Rembrandt, Doré); five do not, and those were not "
                       "re-verified against an upstream file page.",
        "attributionRequired": False,
        "credit": "Public-domain artwork; individual artists as titled.",
        "sourceUrl": None,
    },
    {
        "id": "scene-topups",
        "name": {
            "en": "Gospel scenes, parables and teachings",
            "zh-Hans": "福音场景、比喻与教导",
            "zh-Hant": "福音場景、比喻與教導",
        },
        "artist": None,
        "work": None,
        "years": None,
        "holder": None,
        # 96 plates. No artist is named anywhere in the archive, and the
        # hosted bytes were checked on 2026-08-11 for embedded EXIF/XMP
        # or IPTC provenance and carry none — the only copyright string
        # present is the sRGB ICC profile's Hewlett-Packard boilerplate.
        "license": "unknown",
        "licenseBasis": "not-recorded",
        "licenseNote": "No artist recorded in the archive, and the hosted "
                       "files carry no embedded provenance metadata "
                       "(checked 2026-08-11). Origin needs to come from "
                       "whoever assembled the collection.",
        "attributionRequired": None,
        "credit": None,
        "sourceUrl": None,
    },
    {
        "id": "bundled-maps",
        "name": {
            "en": "Bible-history maps (bundled)",
            "zh-Hans": "圣经历史地图（内置）",
            "zh-Hant": "聖經歷史地圖（內置）",
        },
        "artist": None,
        "work": None,
        "years": None,
        "holder": None,
        # The 55 geographic maps that have shipped since the beginning.
        # The owner cleared them for use on 2026-08-09 (「我收集来的可以用」)
        # — that settles PERMISSION and settles nothing about ORIGIN, and
        # a licence such as CC BY may be freely used and still require the
        # author be named.
        "license": "unknown",
        "licenseBasis": "not-recorded",
        "licenseNote": "Cleared for use by the app's owner from their own "
                       "collection (2026-08-09). Where the images were "
                       "originally obtained was not recorded at import, so "
                       "no licence can be asserted.",
        "attributionRequired": None,
        "credit": None,
        "sourceUrl": None,
    },
    {
        "id": "unrecorded",
        "name": {
            "en": "Origin not recorded",
            "zh-Hans": "来源未记录",
            "zh-Hant": "來源未記錄",
        },
        "artist": None,
        "work": None,
        "years": None,
        "holder": None,
        # The fallback a lookup returns for a plate whose collection is
        # missing or unknown. It exists so the viewer always has an
        # honest line to draw instead of a null to hide.
        "license": "unknown",
        "licenseBasis": "not-recorded",
        "licenseNote": "This plate names no collection. Treat its licence "
                       "as unknown.",
        "attributionRequired": None,
        "credit": None,
        "sourceUrl": None,
    },
]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true",
                        help="verify without writing")
    args = parser.parse_args()

    entries = json.loads(INDEX.read_text(encoding="utf-8"))
    known = {c["id"] for c in COLLECTIONS}
    sweet_urls = sweet_source_urls()

    counts: dict[str, int] = {}
    changed = 0
    missing_sweet = []
    for entry in entries:
        collection = collection_of(entry)
        assert collection in known, f"{entry['id']} -> {collection}"
        counts[collection] = counts.get(collection, 0) + 1
        if entry.get("collection") != collection:
            changed += 1
        entry["collection"] = collection
        if collection == "sweet":
            url = sweet_urls.get(entry["id"])
            if url is None:
                missing_sweet.append(entry["id"])
            else:
                entry["sourceUrl"] = url

    for collection_id, n in sorted(counts.items(), key=lambda kv: -kv[1]):
        record = next(c for c in COLLECTIONS if c["id"] == collection_id)
        print(f"{n:>5}  {collection_id:<14} {record['license']:<14} "
              f"basis={record['licenseBasis']}")
    print(f"total {sum(counts.values())} of {len(entries)}")
    if missing_sweet:
        print(f"!! {len(missing_sweet)} Sweet plates without an upstream "
              f"URL: {missing_sweet[:5]}")
        return 1

    if args.check:
        print(f"check only; {changed} entries would change")
        return 0

    INDEX.write_text(
        json.dumps(entries, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8")
    PROVENANCE.write_text(
        json.dumps({"collections": COLLECTIONS}, ensure_ascii=False,
                   indent=2) + "\n",
        encoding="utf-8")
    print(f"wrote {INDEX.name} ({changed} entries annotated) and "
          f"{PROVENANCE.name} ({len(COLLECTIONS)} records)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
