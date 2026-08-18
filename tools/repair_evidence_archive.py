#!/usr/bin/env python3
"""Repair `assets/bible_evidence.json` — two defects, both reader-visible.

The archive was migrated from a standalone Vite/React/TS project
(bible-evidence.netlify.app). Check 40 of docs/DATA-INTEGRITY.md found
that the migration damaged it in two independent ways.

1. MOJIBAKE. 152 strings in 111 of the 225 records were written as
   UTF-8 bytes and read back as Latin-1, so every non-ASCII character
   became two or three wrong ones. It lands in the fields the detail
   page prints as fact:

       timeline          "9th–8th Century BCE"   -> "9thâ\x80\x938th Century BCE"
       discoveryDate     "1868–1870"             -> "1868â\x80\x931870"
       location          "Musée du Louvre"       -> "MusÃ©e du Louvre"
       academicSources   "André Parrot"          -> "AndrÃ© Parrot"
                         "IEJ 35 (1985): 22–27"  -> "IEJ 35 (1985): 22â\x80\x9327"

   93 of the 152 are inside `academicSources`, which is the archive's
   own evidence for its claims — scholars' names and page ranges. The
   damage is deterministic and therefore exactly reversible:
   `s.encode('latin-1').decode('utf-8')`.

   The gate matters more than the repair. Decoding is attempted only
   for strings carrying a signature that cannot occur in real text: a
   C1 control (U+0080-U+009F, unassigned in any legitimate string) or
   `Ã`/`Â` followed by a continuation byte. 131 of the 152
   carry a C1 control; the other 21 are the `Ã`-mangled accented
   Latin. Every repair is asserted to remove the signature, so a second
   run is a no-op and nothing is double-decoded.

2. SIMPLIFIED CHINESE IN THE TRADITIONAL SLOT. Each record carries
   `{en, zh-Hans, zh-Hant}` for title / summary / description /
   scripturalCorrelation, and `BibleEvidence.localizedTitle` serves the
   locale key straight through. 209 of the 225 records held the
   Simplified string under `zh-Hant` — 207 of them in all four fields,
   byte for byte. A 繁體 reader was reading 簡體 and being told it was
   their edition.

   The 16 records that were already Traditional stay untouched. They
   were machine-converted too, but where their text differs from what
   s2tw would produce the EXISTING reading is the better one (卷 not
   捲, 讚 not 贊, 鏟除 not 剷除), so regenerating them would be a
   regression.

WHY s2tw, AND WHY IT IS NOT ENOUGH ON ITS OWN. `s2tw` is the Taiwan
character standard *without* vocabulary substitution — `s2twp` would
also rewrite the author's word choices, which is not ours to do. It
leaks no 舊字形 into this corpus (麪/裏/説/喫/衆/爲 all zero).

But opencc's phrase dictionary makes wrong CHOICES, and a round trip
cannot see them: `t2s(隻有) == 只有`, so a wrong choice round-trips
perfectly. The instrument that does see them is an override diff —
convert the corpus's distinct characters ONE AT A TIME to get opencc's
context-free opinion, then diff that against the full-text conversion.
Every difference is a phrase-dictionary decision, which is exactly
where the errors live. That found 792 overrides in ~70 classes; each
class was read, and the ones below are the ones the app's own shipped
Traditional editions refute. The counts in the comments are from those
editions (`cuvs-yhwh-tr.json` + `biblexg-v2-tr.json`, 32k verses).

Most overrides are LEFT ALONE because opencc is right: 彷彿 (102/0),
饑荒 (108/0), 細緻, 簽名, 岳母, 鐘乳石, 沖積. This script converts nothing
by default and asserts the count of everything it changes.

Usage:  python3 tools/repair_evidence_archive.py [--write]
"""

import json
import re
import subprocess
import sys
from collections import Counter

ASSET = "assets/bible_evidence.json"
LOCALIZED_FIELDS = ("title", "summary", "description", "scripturalCorrelation")

# ─── 1. mojibake ────────────────────────────────────────────────────
# A C1 control is unassigned in every real text; `Ã`/`Â` followed by a
# UTF-8 continuation byte is the accented-Latin form of the same fault.
MOJIBAKE_SIGNATURE = re.compile("[\u0080-\u009f]|[\u00c2\u00c3][\u0080-\u00bf]")


def demojibake(s):
    """Reverse a UTF-8-read-as-Latin-1 round trip, or return s unchanged."""
    if not MOJIBAKE_SIGNATURE.search(s):
        return s
    try:
        fixed = s.encode("latin-1").decode("utf-8")
    except (UnicodeEncodeError, UnicodeDecodeError):
        return s
    if MOJIBAKE_SIGNATURE.search(fixed):
        # Would still look damaged — refuse rather than guess a second
        # round. Measured: this never fires on the shipped asset.
        return s
    return fixed


# ─── 2. the exception table ─────────────────────────────────────────
# Applied only to strings this script regenerated. Each entry is a
# named context with the count it is expected to change; a mismatch is
# reported, because a silent zero means the data moved under the rule.
#
# Group A — one Simplified character, several Traditional words, and
# opencc picked the wrong one.
EXCEPTIONS = [
    # 发 is 發 (to issue) and 髮 (hair). Only 髮型 and 頭髮 are hair.
    ("髮掘", "發掘", 6),
    ("髮明", "發明", 2),
    ("髮生", "發生", 2),
    ("髮表", "發表", 1),
    # 升 is not a variant of 昇 here: our editions write 升天 18 / 昇天 0.
    ("昇天", "升天", 11),
    # 复 is 復 / 複 / 覆. Resurrection is 復活 (374 / 覆活 0).
    ("覆活", "復活", 3),
    # 并 is 並 (and) / 併 (to merge). Rev 1:9 「並為給」 (1 / 併為給 0).
    ("併為", "並為", 5),
    # 干 is 乾 (dry) / 干 (to offend, and transliterations) / 幹 (a
    # trunk). A wadi is a dry riverbed; Phlegon is a name. 主幹道 and
    # 樹幹 in the same corpus are genuine 幹 and are left alone.
    ("幹河", "乾河", 2),
    ("斐勒幹", "斐勒干", 2),
    # 面 is 面 (a face, a side) / 麵 (flour).
    ("麵向", "面向", 1),
    # 卷 is 卷 (a scroll) / 捲 (to roll up). A parchment scroll is 卷.
    ("羊皮捲", "羊皮卷", 1),
    # 赞 is 贊 (to support) / 讚 (to praise). Song 1:14 is praise.
    ("所贊", "所讚", 0),   # already right in the one record that has it
    # 托 is 托 (to prop) / 託 (to entrust). Judg 16:29 「抱住托房」
    # (1 / 託房 0) — Samson braces the pillars.
    ("託房", "托房", 2),
    # 系 is 系 / 係 / 繫. Job 38:31 「系住昴星」 (1 / 繫住昴 0).
    ("繫住昴", "系住昴", 3),
    # 欲 is 欲 (desire) / 慾 (lust). John 1:13 「從情欲生」 (1 / 情慾 0).
    ("情慾生", "情欲生", 1),
    # ─ Group B — 里 is 里 (a mile, and every transliterated name) and
    # 裡 (inside). Locative 裡 (那裡, 這裡, 城裡, Rev 1:9's 忍耐裡) is
    # correct and stays; these are people and places.
    ("馬裡", "馬里", 9),          # Mari
    ("泰勒裡邁", "泰勒里邁", 5),   # Tell er-Retabah
    ("瑪裡卜", "瑪里卜", 4),       # Marib
    ("古裡安", "古里安", 2),       # Ben-Gurion
    ("弗裡", "弗里", 2),           # Frey / Freedman
    ("胡裡安", "胡里安", 2),       # Hurrian
    ("努外裡", "努外里", 2),       # Nuweiri
    ("哈塔裡卡", "哈塔里卡", 1),   # Hattarikka
    ("布裡埃", "布里埃", 1),       # Brière
    # ─ Group C — opencc's phrase dictionary substituted a DIFFERENT
    # word, not a Traditional form. Each is refuted by the app's own
    # Traditional editions, counted below as (chosen / opencc's).
    ("瞭解", "了解", 5),           # 了解 54 / 瞭解 1
    ("闡明瞭", "闡明了", 10),      # aspect particle — 瞭 is nonsense here
    ("曆史", "歷史", 6),           # 歷史 6 / 曆史 0; 曆法/日曆/回曆 stay
    ("銷燬", "銷毀", 1),           # 燒毀 14 / 燒燬 0
    ("燒燬", "燒毀", 4),
    ("焚燬", "焚毀", 1),
    ("倖存", "幸存", 4),           # 幸存 1 / 倖存 0
    ("倖免", "幸免", 1),
    ("迴避", "回避", 1),           # 回避 2 / 迴避 0
    ("迴歸", "回歸", 1),           # 回歸 4 / 迴歸 0
    ("迴響", "回響", 1),           # neither attested; keep the plain form
    ("傢俱", "家具", 2),           # 家具 8 / 傢俱 0
    ("藉助", "借助", 1),           # 借助 1 / 藉助 0
    ("揹著", "背著", 1),           # 背著自己 2 / 揹著 0 (Luke 14:27)
    ("一齣會堂", "一出會堂", 1),   # 齣 counts stage plays
    ("一箇中央", "一個中央", 1),   # 箇 is archaic
    ("綵衣", "彩衣", 1),           # 彩衣 8 / 綵衣 0 (Gen 37:3)
    ("餬口", "糊口", 1),           # 糊口 6 / 餬口 1 (Gen 3:19)
    ("剷除", "鏟除", 0),           # 鏟除 3 / 剷除 0
    ("鉅款", "巨款", 1),           # neither attested; keep the plain form
]

# ─── 3. two terms the Chinese gets factually wrong ──────────────────
# Neither is a script question. Both tell a reader something the
# record's own English, and its own body text, contradict.
TERM_FIXES = [
    # 但以理 is Daniel the prophet. Tel Dan is the CITY of Dan — the
    # stele is 9th-century Aramaic from Tel Dan in northern Israel and
    # has nothing to do with the book of Daniel. The record's own
    # description already says 「以色列北部的但（Dan）遗址」, and 但丘
    # appears 6 times elsewhere in this same archive, so the archive
    # has the right word and the title does not use it.
    ("但以理石碑", "但丘石碑", 4),
    # An ossuary is a stone box for BONES. 骨灰 is cremated ash, and
    # Second Temple Jews did not cremate — the same record's
    # description says 十二具藏骨罐（石制藏骨匣）, twelve stone bone
    # boxes, and the archive writes 藏骨罐 22 times and 骸骨箱 12 times
    # elsewhere. Only these two places imply a cremation the entries
    # themselves deny.
    ("骨灰罐", "藏骨罐", 2),
    ("骨灰盒", "骸骨箱", 6),
]


SEP = "\n@@OPENCC-RECORD-SEPARATOR@@\n"


def s2tw(strings):
    """Convert a list of Simplified strings with `opencc -c s2tw`."""
    if not strings:
        return []
    joined = SEP.join(strings)
    out = subprocess.run(
        ["opencc", "-c", "s2tw"],
        input=joined,
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    # opencc appends a newline; strip only that one.
    if out.endswith("\n") and not joined.endswith("\n"):
        out = out[:-1]
    parts = out.split(SEP)
    assert len(parts) == len(strings), f"opencc lost records: {len(parts)} != {len(strings)}"
    return parts


def unconverted(record):
    """True when this record's Traditional slot was never filled in.

    The test is byte identity, not a character heuristic: if `zh-Hant`
    holds the very same string as `zh-Hans`, no conversion ever ran. It
    splits the corpus exactly — 209 records have at least one identical
    field, the other 16 have none — and it cannot be fooled by the
    characters that are valid in BOTH scripts (里 占 岩 征 托 干 后 准
    游 岳), which is where a per-character detector goes wrong: opencc
    maps 里 to 裡 by default, but 里 is perfectly good Traditional in
    公里 and in every transliterated name.

    Two of the 209 have one field each that is *not* identical, and the
    difference is a single character — 雅偉 for 雅伟, the divine name,
    patched by hand into otherwise Simplified prose. They are converted
    whole, so a record never ends up half in each script.
    """
    same = [f for f in LOCALIZED_FIELDS
            if record[f]["zh-Hant"] == record[f]["zh-Hans"]]
    if not same:
        return False
    # A short title can be identical in both scripts and still be
    # correct — 死海古卷 has no character that differs between them. Ten
    # records are like that, so identity alone would re-fire on every
    # run. Ask opencc whether the string could have differed at all.
    originals = [record[f]["zh-Hans"] for f in same]
    return any(a != b for a, b in zip(originals, s2tw(originals)))


def main():
    write = "--write" in sys.argv
    with open(ASSET, encoding="utf-8") as fh:
        data = json.load(fh)
    records = data["evidences"]

    # ── pass 1: mojibake, everywhere in the tree ────────────────────
    moji = Counter()

    def repair(node, path):
        if isinstance(node, str):
            fixed = demojibake(node)
            if fixed != node:
                moji[path.split(".")[-1]] += 1
                assert not MOJIBAKE_SIGNATURE.search(fixed)
            return fixed
        if isinstance(node, list):
            return [repair(v, path) for v in node]
        if isinstance(node, dict):
            return {k: repair(v, f"{path}.{k}") for k, v in node.items()}
        return node

    data = repair(data, "")
    records = data["evidences"]

    # ── pass 2: the Chinese that says something untrue ──────────────
    terms = Counter()
    for r in records:
        for f in LOCALIZED_FIELDS:
            for loc in ("zh-Hans", "zh-Hant"):
                s = r[f][loc]
                for find, repl, _ in TERM_FIXES:
                    if find in s:
                        terms[find] += s.count(find)
                        s = s.replace(find, repl)
                r[f][loc] = s

    # ── pass 3: Traditional ─────────────────────────────────────────
    needs = [
        (i, f)
        for i, r in enumerate(records)
        if unconverted(r)
        for f in LOCALIZED_FIELDS
    ]
    converted = s2tw([records[i][f]["zh-Hans"] for i, f in needs])

    applied = Counter()
    for n, (idx, f) in enumerate(needs):
        s = converted[n]
        for find, repl, _ in EXCEPTIONS:
            if find in s:
                applied[find] += s.count(find)
                s = s.replace(find, repl)
        converted[n] = s
        if write:
            records[idx][f]["zh-Hant"] = s

    # ── pass 4: the stale summary in _meta ──────────────────────────
    live = Counter(r.get("confidenceLevel", "") for r in records)
    stale = data["_meta"].get("confidenceCounts")

    # ── report ──────────────────────────────────────────────────────
    if not (moji or terms or needs):
        print(f"{ASSET}: already repaired — nothing to do.")
        return 0

    print(f"records: {len(records)}")
    print(f"mojibake strings repaired: {sum(moji.values())}")
    for k, v in moji.most_common():
        print(f"    {k:24s} {v}")
    bad = 0
    print("mistranslated terms:")
    for find, repl, expected in TERM_FIXES:
        got = terms.get(find, 0)
        flag = "" if got == expected else f"   <-- EXPECTED {expected}"
        bad += got != expected
        print(f"    {find} -> {repl:10s} {got}{flag}")
    print(f"fields regenerated as Traditional: {len(needs)}"
          f" (of {len(records) * len(LOCALIZED_FIELDS)})")
    print(f"records touched: {len({i for i, _ in needs})}")
    print("exception table:")
    for find, repl, expected in EXCEPTIONS:
        got = applied.get(find, 0)
        flag = "" if got == expected else f"   <-- EXPECTED {expected}"
        bad += got != expected
        print(f"    {find} -> {repl:12s} {got}{flag}")
    print(f"confidenceCounts: stale {dict(stale or {})}")
    print(f"                  live  {dict(live)}")

    # Residue: what opencc would still change in the text we just
    # wrote. It should be nothing but the shared characters — valid in
    # both scripts — that the exception table deliberately keeps.
    left = Counter(c for t in converted for c in t) - Counter(
        c for t in s2tw(converted) for c in t)
    print(f"opencc would still change: {sum(left.values())} chars"
          f" {''.join(sorted(left))}")

    if not write:
        print("\ndry run — pass --write to save")
        return 0 if not bad else 1

    data["_meta"]["confidenceCounts"] = {
        k: live[k] for k in sorted(live, key=lambda k: -live[k])
    }
    data["_meta"]["traditionalChinese"] = (
        "The zh-Hant text is machine-derived from zh-Hans with "
        "`opencc -c s2tw` plus the hand-read exception table in "
        "tools/repair_evidence_archive.py. It is not an independent "
        "translation."
    )
    with open(ASSET, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    print(f"\nwrote {ASSET}")
    return 0 if not bad else 1


if __name__ == "__main__":
    sys.exit(main())
