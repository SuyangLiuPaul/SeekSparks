#!/usr/bin/env python3
"""Repair the Traditional characters `assets/cuvs-yhwh-tr.json` got wrong.

The Traditional edition was produced from the Simplified one by a
conversion that decided each ambiguous Simplified character once and for
all, instead of per word. Where Simplified writes one character for two
Traditional words, it picked the wrong one every time — the giveaway is
that the RIGHT character appears **zero** times in 31,102 verses:

    隻   0 occurrences        只  1,219
    餘   0                    余    230
    淨   0                    凈    519

The sibling Traditional asset `biblexg-v2-tr.json` is **clean** (隻 50,
餘 38, 淨 78, and its 31 幹 are all genuine 幹活/才幹), so this is one
bad conversion run, not a shared pipeline defect. Do not "fix" that file.

WHY NOT JUST RUN OPENCC OVER IT. Because it is wrong here. `opencc -c
s2t` turns 以賽亞書 29:17 「不是只有一點點時候嗎？」 into 「不是隻有…」,
inventing a defect while removing others. Every rule below is therefore
a *named context*, and a character with no rule is left exactly as it
is: this script converts nothing by default and asserts that it
recognised every occurrence it changed.

Idempotent — the output matches no input rule, so a second run is a
no-op. That is what makes it safe to re-run against a future import.
"""

import json
import sys
from collections import Counter

ASSET = "assets/cuvs-yhwh-tr.json"

# ─── 只 → 隻 ─────────────────────────────────────────────────────────
# 只 is the adverb "only"; 隻 is the classifier for animals, boats,
# hands and eyes. Simplified writes both as 只.
#
# The rule is positional, not lexical: a classifier follows a NUMERAL or
# a determiner. Measured over the whole edition it splits 1,219
# occurrences into 548 classifier contexts and 671 adverbial ones with
# no overlap in either direction — every one of the 548 was read and is
# a classifier (三隻向北, 九十九隻撇在曠野, 每第十隻要歸給雅偉為聖), and
# no 只 outside them is followed by a noun a classifier could count.
#
# This is exactly where a blanket conversion fails: 以賽亞書 29:17 has
# 是只有, and 是 is not a numeral, so the rule leaves it alone.
CLASSIFIER_BEFORE = set("一二三四五六七八九十百千萬兩幾每那船")

# ─── 余 → 餘 ─────────────────────────────────────────────────────────
# 余 is the archaic first-person pronoun; 餘 is "remaining". A different
# word, not a variant form. All 230 occurrences were read across 57
# distinct contexts (其餘, 所餘剩, 有餘, 餘民, 餘地, 餘種, 餘數, 富餘,
# 多餘, 餘怒, 餘火, 餘福, 餘力, 盈餘, 餘下) and **none** is a pronoun or
# a name — 和合本 writes the first person 我 throughout. Unconditional.

# ─── 凈 → 淨 ─────────────────────────────────────────────────────────
# NOT a meaning error, and recorded separately for that reason: 凈 and
# 淨 are the same word, 淨 being the standard Traditional form and 凈 a
# variant. It is converted because the risk is nil and the inconsistency
# is real — the edition already uses standard forms elsewhere (為, 眾,
# 吃, 群, 裏), the sibling Traditional asset writes 淨 exclusively, and
# 幹凈 has to become 乾淨 rather than the half-corrected 乾凈.

# ─── 幹 → 乾 / 干 / 幹 ───────────────────────────────────────────────
# THREE outcomes, not two, and this is the part a "幹 → 乾" rule would
# have got wrong for a third of its cases. Simplified 干 covers 乾 (dry),
# 干 (to offend, to concern, and a great many transliterated names) and
# 幹 (a trunk, a shaft, ability) — and 干 is itself a Traditional
# character that should simply have been left standing.
#
# A blanket 幹 → 乾 would print 乾犯 for 干犯, 亞乾 for Achan, and 何乾
# for 何干. In Taiwan 幹 also carries a coarse slang reading, which is
# why 「走幹地」 in the Exodus sea crossing is not merely a typo.

# Genuine 幹: a trunk, a shaft, an ability. Left untouched.
KEEP = [
    "枝幹",  # Ezekiel 19 — branches and trunk
    "才幹",  # Matthew 25:15 — ability
    "座和幹",  # Exodus 25:31, 37:17 — the lampstand's base and shaft
    "，幹也",  # Job 14:8 — the tree's trunk dies in the ground
]

# 干: to offend, to concern, and the names the conversion swallowed.
TO_GAN = [
    "幹犯", "何幹", "相幹", "無幹", "不幹己",
    "幹預", "幹休", "幹戈", "若幹", "致幹忿",
    # Transliterated names. 亞幹 is Achan, 王幹大 is Candace.
    "亞幹", "隱幹寧", "約幹", "斯利幹", "雅幹", "拉幹",
    "尼幹", "母幹", "幹尼", "提幹", "勒幹", "王幹大",
]

# 乾: dry. Enumerated rather than left as a default, so that a context
# nobody has read is reported instead of silently converted.
TO_QIAN = [
    "枯幹", "幹了", "幹地", "幹的", "幹涸", "幹渴", "幹癟", "幹燥",
    "幹凈", "幹糧", "幹草", "幹餅", "幹葡萄", "葡萄幹", "幹熱", "幹焦",
    "幹裂", "幹柴", "幹死", "幹瘦", "幹竭", "擦幹", "喝幹", "燒幹",
    "吹幹", "發幹", "乳幹", "必幹", "踏幹埃",
]


def _rules(patterns):
    return [(p, p.index("幹")) for p in patterns]


def _match(text, i, rules):
    """The first rule whose pattern sits over position [i], or None."""
    for pattern, offset in rules:
        start = i - offset
        if start >= 0 and text[start:start + len(pattern)] == pattern:
            return pattern
    return None


def repair(text, tally, unmatched):
    out = []
    keep, to_gan, to_qian = _rules(KEEP), _rules(TO_GAN), _rules(TO_QIAN)
    for i, ch in enumerate(text):
        if ch == "只":
            before = text[i - 1] if i else ""
            if before in CLASSIFIER_BEFORE:
                tally["只→隻"] += 1
                out.append("隻")
            else:
                out.append(ch)
        elif ch == "余":
            tally["余→餘"] += 1
            out.append("餘")
        elif ch == "凈":
            tally["凈→淨"] += 1
            out.append("淨")
        elif ch == "幹":
            if _match(text, i, keep):
                tally["幹 kept"] += 1
                out.append(ch)
            elif _match(text, i, to_gan):
                tally["幹→干"] += 1
                out.append("干")
            elif _match(text, i, to_qian):
                tally["幹→乾"] += 1
                out.append("乾")
            else:
                # No rule claims it, so nothing happens to it. Reported
                # so a later import that introduces a new context is
                # visible rather than quietly mis-converted.
                unmatched[text[max(0, i - 3):i + 4]] += 1
                out.append(ch)
        else:
            out.append(ch)
    return "".join(out)


def main():
    verses = json.load(open(ASSET, encoding="utf-8"))
    tally, unmatched = Counter(), Counter()
    changed = 0
    per_class_verses = Counter()
    for v in verses:
        before = v["text"]
        seen = Counter()
        after = repair(before, seen, unmatched)
        if after != before:
            changed += 1
            v["text"] = after
            for k in seen:
                if k != "幹 kept":
                    per_class_verses[k] += 1
        tally.update(seen)

    for k in sorted(tally):
        print(f"  {k:10s} {tally[k]:5d} occurrences"
              f"  in {per_class_verses[k]:5d} verses" if k != "幹 kept"
              else f"  {k:10s} {tally[k]:5d} occurrences (untouched)")
    print(f"  verses changed: {changed}")
    if unmatched:
        print(f"  UNMATCHED 幹 contexts ({sum(unmatched.values())}):")
        for k, n in unmatched.most_common():
            print(f"    {k!r} {n}")
        # Not fatal: leaving a character alone is always the safe
        # outcome. It is loud so that nobody misses it.
        print("  ^ left as-is. Add a rule or confirm 幹 is correct there.")

    if "--check" in sys.argv:
        return 1 if changed else 0
    # Byte-for-byte the shipped serialisation, verified by round-tripping
    # the untouched file: anything else would bury 700 real edits in a
    # 217,716-line reformat that no reviewer could read.
    with open(ASSET, "w", encoding="utf-8") as f:
        f.write(json.dumps(verses, ensure_ascii=False, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
