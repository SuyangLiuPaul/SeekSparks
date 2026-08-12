#!/usr/bin/env python3
"""Repair two Septuagint passages the reader could not read.

`assets/lxxwh.json` is keyed by the ENGLISH reference (so a reader who
types Numbers 10:34 finds it) while carrying the Septuagint's OWN verse
number inline as `<vs:c:v>` wherever the two disagree. In two chapters
the English key was assigned wrongly, and the wrongness has the same
three-part shape both times:

    Numbers 10        Deuteronomy 23
    ──────────        ──────────────
    10:34 absent      23:24 absent
    10:35 = LXX 34+35 23:23 = LXX 24+25   (two verses in one record)
    10:36 = LXX 36    23:25 = LXX 26      (holds a neighbour's verse)

Both books transpose a pair of verses relative to the Hebrew — the LXX
prints Numbers' cloud verse *after* "Rise up, O Lord" rather than before
it, and prints Deuteronomy's standing-corn law *before* the vineyard law
rather than after. Whoever keyed the file followed the Greek's order
instead of translating it into the English one, glued the pair that
straddled the seam into a single record, and left a hole where the
displaced verse should have been.

The consequence for a reader: Numbers 10:34 and Deuteronomy 23:24 showed
NOTHING, and 10:36 and 23:25 showed the *wrong verse* — Greek that is
real Septuagint text, sitting under an English reference that means
something else. The second is the worse defect. It is the Greek column,
the one a reader cannot check against anything except us.

Three witnesses agree on the repair and none of them is this file:

* `assets/kjv.json` fixes what each English reference means.
* The Göttingen-tradition LXX published at api.getbible.net/v2/lxx
  (downloaded and compared in full for this run) fixes what each Greek
  verse number means. Its Numbers 10:32-36 and Deuteronomy 23:21-26 are
  verbatim ours after accent-stripping.
* The file's own `<vs:c:v>` markers agree with that witness, which is
  why the split point below is not a guess: the edition itself marks
  where one Greek verse ends and the next begins.

See docs/DATA-INTEGRITY.md check 29. Idempotent; re-running on repaired
assets reports "already repaired" and writes nothing.

Usage:  python3 tools/repair_lxx_transposed_verses.py [--write]
"""

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FLAT = os.path.join(ROOT, "assets", "lxxwh.json")
TAGGED = os.path.join(ROOT, "assets", "tagged", "lxxwh")

MARKER = re.compile(r"<vs:(\d+):(\d+)>")

# book -> (book number for the `id` field, chapter, {english verse: LXX verse})
#
# Read this as "English Numbers 10:34 is Septuagint Numbers 10:36". Every
# English verse in the range appears, so the table is a permutation and
# the script can assert it consumed each Greek verse exactly once.
PLAN = {
    "Numbers": (4, 10, {34: 36, 35: 34, 36: 35}),
    "Deuteronomy": (5, 23, {23: 24, 24: 26, 25: 25}),
}


def split_text(records):
    """LXX verse number -> its text, for one chapter's affected records.

    A record with two markers is two Greek verses; a record with none is
    the Greek verse of the same number as its English key, which is the
    file's own convention (a marker is written only where the two
    numbers differ).
    """
    out = {}
    for eng, text in records.items():
        hits = list(MARKER.finditer(text))
        if not hits:
            out[eng] = text.strip()
            continue
        for i, h in enumerate(hits):
            end = hits[i + 1].start() if i + 1 < len(hits) else len(text)
            out[int(h.group(2))] = text[h.end():end].strip()
    return out


def split_runs(records):
    """Same split for the tagged layer, cut at the marker token."""
    out = {}
    for eng, runs in records.items():
        cuts = [i for i, r in enumerate(runs) if MARKER.fullmatch(r["w"])]
        if not cuts:
            out[eng] = runs
            continue
        for j, start in enumerate(cuts):
            end = cuts[j + 1] if j + 1 < len(cuts) else len(runs)
            lxx = int(MARKER.fullmatch(runs[start]["w"]).group(2))
            out[lxx] = runs[start + 1:end]
    return out


def rebuild_text(chapter, eng, lxx, body):
    """The record's text, marker included only where the numbers differ."""
    if eng == lxx:
        return body
    return f"<vs:{chapter}:{lxx}>{body}"


def rebuild_runs(chapter, eng, lxx, body):
    if eng == lxx:
        return list(body)
    return [{"w": f"<vs:{chapter}:{lxx}>", "s": "", "i": [], "g": []}] + list(body)


def main():
    write = "--write" in sys.argv
    flat = json.load(open(FLAT, encoding="utf-8"))

    changed_flat = 0
    added_flat = 0
    changed_tagged = 0
    added_tagged = 0
    already = 0

    for book, (bnum, chapter, plan) in PLAN.items():
        verses = sorted(plan)

        # ── flat asset ────────────────────────────────────────────────
        by_key = {}
        for i, r in enumerate(flat):
            if r["book"] == book and int(r["chapter"]) == chapter:
                by_key[int(r["verse"])] = i
        present = {v: flat[by_key[v]]["text"] for v in verses if v in by_key}
        pieces = split_text(present)

        missing = [plan[v] for v in verses if plan[v] not in pieces]
        if missing:
            already += 1
            print(f"  {book} {chapter}: Greek verses {missing} not found — "
                  f"already repaired, or the file is not what this expects")
        else:
            wanted = [
                {
                    "book": book,
                    "chapter": str(chapter),
                    "verse": str(eng),
                    "text": rebuild_text(chapter, eng, plan[eng], pieces[plan[eng]]),
                    "id": f"{bnum:03d}{chapter:03d}{eng:03d}",
                }
                for eng in verses
            ]
            current = [flat[by_key[v]] for v in verses if v in by_key]
            if current != wanted:
                changed_flat += sum(1 for v in verses if v in by_key)
                added_flat += sum(1 for v in verses if v not in by_key)
                # Replace the affected records in place, keeping the file
                # in verse order: the whole run is contiguous, so the
                # first one's index is where the repaired run belongs.
                at = min(by_key[v] for v in verses if v in by_key)
                for v in sorted(by_key, reverse=True):
                    if v in verses:
                        del flat[by_key[v]]
                flat[at:at] = wanted

        # ── tagged layer ──────────────────────────────────────────────
        # The tagged layer names its files by slug. macOS would have
        # resolved "Numbers.json" case-insensitively and hidden this.
        path = os.path.join(TAGGED, book.lower().replace(" ", "_") + ".json")
        tagged = json.load(open(path, encoding="utf-8"))
        t_present = {
            v: tagged[f"{chapter}:{v}"]
            for v in verses
            if f"{chapter}:{v}" in tagged
        }
        t_pieces = split_runs(t_present)
        if all(plan[v] in t_pieces for v in verses):
            touched = 0
            for eng in verses:
                want = rebuild_runs(chapter, eng, plan[eng], t_pieces[plan[eng]])
                key = f"{chapter}:{eng}"
                if key in tagged:
                    if tagged[key] != want:
                        tagged[key] = want
                        changed_tagged += 1
                        touched += 1
                else:
                    tagged[key] = want
                    added_tagged += 1
                    touched += 1
            if write and touched:
                ordered = dict(
                    sorted(
                        tagged.items(),
                        key=lambda kv: (
                            int(kv[0].split(":")[0]),
                            int(kv[0].split(":")[1]),
                        ),
                    )
                )
                with open(path, "w", encoding="utf-8") as f:
                    json.dump(ordered, f, ensure_ascii=False, separators=(",", ":"))

    print(f"flat: {changed_flat} rewritten, {added_flat} inserted")
    print(f"tagged: {changed_tagged} rewritten, {added_tagged} inserted")

    if write and (changed_flat or added_flat):
        with open(FLAT, "w", encoding="utf-8") as f:
            json.dump(flat, f, ensure_ascii=False, separators=(",", ":"))
        print("wrote assets/lxxwh.json")
    elif not write:
        print("(dry run; pass --write to apply)")


if __name__ == "__main__":
    main()
