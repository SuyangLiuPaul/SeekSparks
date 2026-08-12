#!/usr/bin/env python3
"""Repair the Septuagint's own-verse-number column.

`assets/lxxwh.json` is keyed by the ENGLISH reference and carries the
edition's OWN chapter-and-verse inline as `<vs:c:v>` wherever the two
differ. The app RENDERS that marker — a muted "(9:2a)" in front of the
Greek — so it is a printed claim, not metadata. Check 34 put all 4,687
of them to an outside witness (`api.getbible.net/v2/lxx`). 4,200 are
verbatim right. Three groups are not, and each is repaired here in the
way that keeps the most information.

1. PROVERBS 25:1–29:27 — 144 markers, CHAPTER OFF BY SEVEN.

   Every marker in this range names a chapter exactly seven higher than
   the record's own, with the verse unchanged: 25:1 claims "32:1",
   29:27 claims "36:27". The Septuagint's Proverbs has 31 chapters, so
   32–36 do not exist and the claim cannot be true whatever the words
   say. The words settle where they belong: all 138 records are verbatim
   the witness AT THEIR OWN ENGLISH NUMBER, 138 of 138.

   So the repair is a subtraction, not a deletion. Seven comes off the
   chapter; 138 markers then name the record's own number and are
   dropped as saying nothing (see 3); the 6 that carry a sub-verse
   letter survive as 25:10a, 26:11a and so on, which is what the rest of
   Proverbs already looks like — the book has 42 other lettered
   sub-verses. Deleting the 144 outright would have been simpler and
   would have thrown those six away.

   Where the seven came from is NOT recoverable from the file. Rahlfs'
   Proverbs prints its chapters out of order — 24:22 is followed by
   30:1-14, then 24:23-34, 30:15-33, 31:1-9, and only then 25-29 — so a
   count of printed blocks rather than of chapter numbers is where a
   mechanical error of this shape would come from. That is a guess and
   is written here as one.

2. 129 SUB-VERSE LETTERS IN THE WRONG ALPHABET.

   Rahlfs letters his sub-verses in Latin: Joshua 9:2a-f, 3 Kingdoms
   16:28a-h. Ours are Greek — α β χ δ ε φ γ η σ — which is the Adobe
   Symbol font's encoding of a b c d e f g h s read as though it were
   Unicode. It renders as "(9:2χ)" where the printed page says "9:2c".

   No outside witness is needed and none exists (the witness numbers
   verses, not sub-verses). 1 Kings 16:28 proves it alone: it carries
   eight markers in one record, in this order —

       α β χ δ ε φ γ η

   γ stands SEVENTH. In Greek it is third. In Symbol it is g, which is
   seventh in Latin, and every other letter falls where Latin puts it
   too. Ten more records run α β χ δ, which is a b c d and is not any
   ordering of the Greek alphabet. The frequencies say the same thing
   independently: 65 α, 23 β, 17 χ, 12 δ, 6 ε, 3 φ, 1 γ, 1 η — a clean
   descent through a b c d e f g h, whereas Greek letters would put γ
   third and never χ.

   Esther 1:1's lone σ is the one that rests on the encoding argument
   alone: it has no run to sit in. σ is Symbol s, and Rahlfs numbers the
   Additions to Esther with letters that run past r, so "1:1s" is the
   reading. Whether Rahlfs has a sub-verse there at all is the source's
   claim and this repository cannot check it.

3. 6 MARKERS THAT SAY NOTHING.

   Matthew 26:61, Mark 6:28, Mark 12:15, Acts 13:39, Ephesians 1:11 and
   Ephesians 3:18 each carry a marker naming the record's OWN number,
   sitting in the middle of the verse, so the reader sees "Later two
   came forward (26:61) and said". A marker exists to record a
   DIFFERENCE from the key; one that repeats the key is empty by
   definition. Each of the six records is the witness's verse at that
   same number, entire, so there is no second verse for the marker to
   have been introducing.

   Two other identity markers are NOT touched: Lamentations 1:1 runs
   `1:0` then `1:1` and Revelation 13:1 runs `12:18` then `13:1`. Those
   resume the record's own number after a genuinely different one and
   are doing work.

WHAT IS NOT REPAIRED, and why. Matthew 12:47 is in the witness and not
in either of our layers. The witness brackets it — Westcott and Hort's
own mark of a reading they doubted — and we do carry the only other
verse it brackets (Matthew 21:44), so dropping bracketed verses is not
this edition's policy and the absence looks like ours. Importing the
Greek is still declined: it would have to come from a witness that
inlines UBS4 variants as duplicated words, the tagged layer would not
have it, and the app already makes the weakest true claim there ("this
edition has no verse here"). That is a decision about what the product
contains, and it is left open rather than taken.

Both layers are repaired: the flat asset and `assets/tagged/lxxwh/`,
where each marker is a standalone run with an empty Strong's number.

Idempotent; re-running on repaired assets reports "already repaired" and
writes nothing.

Usage:  python3 tools/repair_lxx_versification_markers.py [--write]
"""

import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FLAT = os.path.join(ROOT, "assets", "lxxwh.json")
TAGGED = os.path.join(ROOT, "assets", "tagged", "lxxwh")

MARKER = re.compile(r"<vs:(\d+):(\d+)(\D*)>")

# Adobe Symbol's code points for the Latin letters, read as Unicode.
SYMBOL_TO_LATIN = {
    "α": "a", "β": "b", "χ": "c", "δ": "d",
    "ε": "e", "φ": "f", "γ": "g", "η": "h",
    "σ": "s",
}

# English Proverbs 25:1–29:27; every marker in it is chapter + 7.
PROVERBS_OFFSET = 7
PROVERBS_RANGE = (25, 29)

# The six markers that repeat their record's own number and introduce
# nothing. Named rather than detected so that a future record which
# legitimately resumes its own number is not silently eaten.
VACUOUS = {
    ("Matthew", 26, 61), ("Mark", 6, 28), ("Mark", 12, 15),
    ("Acts", 13, 39), ("Ephesians", 1, 11), ("Ephesians", 3, 18),
}

TAGGED_FILENAMES = {}


def repair_text(book, chapter, verse, text, stats):
    """Rewrite every marker in one record. Returns the new text."""

    def sub(match):
        c, v, suffix = int(match.group(1)), int(match.group(2)), match.group(3)

        if book == "Proverbs" and PROVERBS_RANGE[0] <= chapter \
                <= PROVERBS_RANGE[1] and c == chapter + PROVERBS_OFFSET:
            c -= PROVERBS_OFFSET
            stats["proverbs"] += 1

        if suffix:
            latin = "".join(SYMBOL_TO_LATIN.get(ch, ch) for ch in suffix)
            if latin != suffix:
                stats["letters"] += 1
            suffix = latin

        if not suffix and (c, v) == (chapter, verse):
            if (book, chapter, verse) in VACUOUS:
                stats["vacuous"] += 1
                return ""
            # Proverbs' 138: the subtraction above turned them into
            # identity markers, which is the file's own way of saying
            # "no difference here" — and 138 of 138 are verbatim the
            # witness at this number.
            if book == "Proverbs":
                stats["proverbs_dropped"] += 1
                return ""
        return f"<vs:{c}:{v}{suffix}>"

    return MARKER.sub(sub, text)


def repair_flat(stats):
    with open(FLAT, encoding="utf-8") as f:
        records = json.load(f)
    changed = 0
    for r in records:
        new = repair_text(r["book"], int(r["chapter"]), int(r["verse"]),
                          r["text"], stats)
        if new != r["text"]:
            r["text"] = new
            changed += 1
    return records, changed


def repair_tagged(stats):
    """Markers are standalone runs; an emptied one is dropped whole."""
    out = {}
    with open(FLAT, encoding="utf-8") as f:
        books = {r["book"] for r in json.load(f)}
    slugs = {b.lower().replace(" ", "_"): b for b in books}
    for path in sorted(glob.glob(os.path.join(TAGGED, "*.json"))):
        slug = os.path.basename(path)[: -len(".json")]
        book = slugs.get(slug)
        if book is None:
            print(f"  ! no book for {slug}", file=sys.stderr)
            continue
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        changed = 0
        for key, runs in data.items():
            c, v = (int(x) for x in key.split(":"))
            new_runs = []
            for run in runs:
                word = run.get("w", "")
                if not MARKER.search(word):
                    new_runs.append(run)
                    continue
                fixed = repair_text(book, c, v, word, stats)
                if fixed.strip():
                    run["w"] = fixed
                    new_runs.append(run)
                if fixed != word:
                    changed += 1
            data[key] = new_runs
        if changed:
            out[path] = (data, changed)
    return out


def main() -> int:
    write = "--write" in sys.argv
    stats = {"proverbs": 0, "proverbs_dropped": 0, "letters": 0,
             "vacuous": 0}

    records, flat_changed = repair_flat(stats)
    flat_stats = dict(stats)
    stats = {k: 0 for k in stats}
    tagged = repair_tagged(stats)
    tagged_changed = sum(n for _, n in tagged.values())

    print("flat  assets/lxxwh.json: "
          f"{flat_changed} records changed  "
          f"({flat_stats['proverbs']} Proverbs markers un-offset, of which "
          f"{flat_stats['proverbs_dropped']} then dropped as identity; "
          f"{flat_stats['letters']} sub-verse letters transliterated; "
          f"{flat_stats['vacuous']} vacuous markers dropped)")
    print(f"tagged assets/tagged/lxxwh: {tagged_changed} runs changed in "
          f"{len(tagged)} files "
          f"({stats['proverbs']} / {stats['letters']} / {stats['vacuous']})")

    if not flat_changed and not tagged_changed:
        print("already repaired; nothing written")
        return 0
    if not write:
        print("\ndry run; pass --write to apply")
        return 0

    with open(FLAT, "w", encoding="utf-8") as f:
        json.dump(records, f, ensure_ascii=False, separators=(",", ":"))
    for path, (data, _n) in tagged.items():
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    print(f"\nwrote {FLAT} and {len(tagged)} tagged files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
