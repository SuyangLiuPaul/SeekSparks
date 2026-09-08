#!/usr/bin/env python3
"""Two classifiers the Traditional conversion of `biblexg-v2` missed.

WHAT THIS IS. Simplified 只 merges two Traditional characters: the adverb
只 (zhǐ, "only") and the classifier 隻 (zhī, 一隻鳥 / 船隻). A converter
that maps 只 → 只 unconditionally is right about the adverb and wrong
about every classifier. `tools/repair_tr_classifier.py` in the YsWords
tree fixed exactly this hole in the Traditional CUV, where the converter
had produced **zero** 隻 in 31,102 verses — 「他施的船只」(以賽亞書 2:16)
was its worked example.

`biblexg-v2-tr.json` was converted separately and mostly came out right:
it has 51 隻, 38 of them 一隻. Two survived, and the first refutes itself
inside one sentence — 「兩只麻雀…牠們一隻也不會掉在地上」, the same
classifier spelled both ways eight characters apart.

WHY A LIST AND NOT A REGEX. Every other 只 in this file was checked, in
both directions, before this script was written:

  * 445 occurrences of 只. Feeding each one's context through
    `opencc -c s2t` flags seven, and **all seven are opencc being wrong**
    — 是只給 / 還是只有 / 是不是只有 / 可是只有 / 不是只有, where its
    phrase table misfires on 是只 and wants 是隻. Every one is the adverb.
  * The reverse direction (隻 written where the adverb belongs) is clean:
    the hits for 隻好 / 隻有 / 隻要 are all word-boundary artefacts —
    「七隻 好母牛」, 「每隻 要獻」, 「兩隻 有乳的母牛」.

So the two below are the whole population, and a regex over 「數字+只」
would only re-find them while risking 「但這只適用於」, which is correct
and which such a regex does not match today but would after any edit to
its character class.

Idempotent: refuses to run twice, and asserts the exact replacement count.
Takes the file path so both trees can be repaired from one script.
"""

import json
import sys
from pathlib import Path

# (reference, wrong, right) — anchored on the surrounding words, not on
# 只 alone, so a future edit elsewhere in the verse cannot be hit.
FIXES = [
    ("馬太福音 10:29", "兩只麻雀", "兩隻麻雀"),
    ("路加福音 5:7", "把兩只船裝得滿滿的", "把兩隻船裝得滿滿的"),
]


def repair(path: Path) -> int:
    raw = path.read_text(encoding="utf-8")
    json.loads(raw)  # the file must be valid JSON before and after

    changed = 0
    for ref, wrong, right in FIXES:
        n = raw.count(wrong)
        if n == 0:
            print(f"  · {ref}: already 隻")
            continue
        assert n == 1, f"{ref}: expected 1 occurrence of {wrong!r}, found {n}"
        raw = raw.replace(wrong, right, 1)
        changed += 1
        print(f"  ✓ {ref}: {wrong} → {right}")

    if changed:
        json.loads(raw)  # still valid
        path.write_text(raw, encoding="utf-8")
    return changed


if __name__ == "__main__":
    targets = [Path(p) for p in sys.argv[1:]] or [
        Path(__file__).resolve().parent.parent / "assets/biblexg-v2-tr.json"
    ]
    total = 0
    for t in targets:
        print(t)
        total += repair(t)
    print(f"\n{total} classifier(s) repaired.")
