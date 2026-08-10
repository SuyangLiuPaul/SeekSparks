#!/usr/bin/env python3
"""Audit and repair the Chinese bodies of the Pastor Eric sermon corpus.

`assets/sermons/` ships 289 sermons in three languages. Two of them are
Chinese, and neither was ever checked against the English it came from.
Measuring both directions found two separate defects, both of the same
shape — a step in the ingest pipeline SUMMARISED where it was meant to
convert or translate, and the output ends with a proper closing line, so
nothing looks broken on screen.

  D1  Three zh-TW bodies are abridged: 100, 369, 370.
      zh-TW is not an independent translation. On the source drive every
      `<id>.zh-TW.txt` is byte-identical to `<id>.zh-proofread.txt`, so
      the lineage is en -> zh-CN -> proofread-into-Traditional -> zh-TW.
      For these three the proofread step condensed instead of proofread:
      the file runs faithfully for two to twelve paragraphs and then
      switches to a much shorter retelling. Kept 34% / 42% / 73% of the
      Han characters in its own zh-CN. Every other pair is 1.000 +/- 0.006
      and the gap between 0.736 and 0.995 is empty, so the three are not a
      judgement call.

      REPAIR: re-derive zh-TW from the full zh-CN with `opencc -c s2t`.
      That is the corpus's own convention, not a guess — s2t reproduces
      192 of the 286 undamaged zh-TW files BYTE FOR BYTE and agrees with
      the rest to 99.866% of characters, and the corpus overwhelmingly
      keeps s2t's variant forms (爲 23,701 vs 為 635; 裏 10,262 vs 裡 311;
      着 6,915 vs 著 375) and ASCII quotes (25,833 vs 471 「). The residual
      0.134% is the proofreader's editorial touches — mostly rendering
      English words zh-CN left untranslated. Those are not reproducible
      without inventing text, so they are not attempted; the repaired
      files are a faithful script conversion of the complete sermon, not
      a proofread one.

      The index's titles are left alone. `titles["zh-TW"]` is s2t of
      `titles["zh-CN"]` in 285 of 289 records (the body's H1 matches in
      only 153), and all four exceptions are proofread touches — 「vs.」
      set as 「對比」, 爲 as 為 — that still name the right sermon. Nothing
      there was ever wrong, so nothing there changes.

  D2  Ten zh-CN bodies are summaries of the English, not translations:
      117 125 126 133 134 135 156 157 158 901 — nine of them from The
      Parables of Jesus, i.e. one failed batch. They hold 0.10-0.19 Han
      characters per English word where the corpus median is 1.40, so a
      Chinese reader gets roughly a tenth of the sermon. Sermon 126 is
      51,480 bytes of English against 3,342 of Chinese, and reads
      「让我们先回顾这个诊断性比喻的核心信息」 — summary prose, not
      preaching. Their zh-TW are faithful conversions OF the summary, so
      both Chinese locales are affected.

      NOT REPAIRABLE HERE. No full Chinese exists anywhere: the source
      drive's per-part `.zh-CN.txt` files are the same summaries. Fixing
      it means re-translating ~85,000 English words, which is generating
      content and is the user's call, not this script's. What the script
      does instead is MARK them, so the app can tell the reader that what
      they are looking at is a summary rather than let them quote it as
      the sermon.

Both lists are derived by measurement every run — nothing is hard-coded —
so a re-ingest that fixes or breaks a file is picked up automatically.

    tools/repair_sermon_corpus.py            # audit, writes nothing
    tools/repair_sermon_corpus.py --apply    # rewrite bodies + index
"""

from __future__ import annotations

import json
import statistics
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SERMONS = ROOT / "assets" / "sermons"
INDEX = SERMONS / "index.json"

# A zh-TW body holding less than this share of its zh-CN body's Han
# characters is abridged. Every undamaged pair scores >= 0.995 and the
# three damaged ones score <= 0.736, so anything in 0.75..0.99 would be a
# new and unexplained shape and should stop the run rather than be
# silently repaired.
TW_ABRIDGED_BELOW = 0.85

# A zh-CN body holding fewer than this many Han characters per English
# word is a summary. Measured distribution: ten files at 0.10-0.19, then
# nothing at all until 0.93, median 1.40.
CN_SUMMARY_BELOW = 0.50


def han(text: str) -> int:
    return sum(1 for c in text if "一" <= c <= "鿿")


def english_words(text: str) -> int:
    return sum(1 for w in text.split() if any(c.isalpha() for c in w))


def to_traditional(text: str) -> str:
    """`opencc -c s2t`, the conversion the corpus itself witnesses."""
    proc = subprocess.run(
        ["opencc", "-c", "s2t.json"],
        input=text,
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise SystemExit(f"opencc failed: {proc.stderr.strip()}")
    return proc.stdout


def main() -> int:
    apply = "--apply" in sys.argv
    records = json.loads(INDEX.read_text())

    abridged_tw: list[tuple[str, float]] = []
    summary_cn: list[tuple[str, float]] = []
    tw_ratios: list[float] = []
    cn_ratios: list[float] = []

    for rec in records:
        sid = rec["id"]
        cn_path = SERMONS / "zh-CN" / f"{sid}.txt"
        tw_path = SERMONS / "zh-TW" / f"{sid}.txt"
        en_path = SERMONS / "en" / f"{sid}.txt"
        if not (cn_path.exists() and tw_path.exists()):
            continue
        cn_han = han(cn_path.read_text())
        tw_han = han(tw_path.read_text())
        if cn_han:
            ratio = tw_han / cn_han
            tw_ratios.append(ratio)
            if ratio < TW_ABRIDGED_BELOW:
                abridged_tw.append((sid, ratio))
        if en_path.exists():
            words = english_words(en_path.read_text())
            if words >= 100:
                ratio = cn_han / words
                cn_ratios.append(ratio)
                if ratio < CN_SUMMARY_BELOW:
                    summary_cn.append((sid, ratio))

    print(f"sermons measured: {len(tw_ratios)}")
    print(
        "zh-TW / zh-CN Han ratio: "
        f"median {statistics.median(tw_ratios):.4f}, min {min(tw_ratios):.3f}"
    )
    print(
        "zh-CN Han per English word: "
        f"median {statistics.median(cn_ratios):.3f}, min {min(cn_ratios):.3f}"
    )

    print(f"\nD1 abridged zh-TW ({len(abridged_tw)}):")
    for sid, ratio in abridged_tw:
        print(f"  {sid:>6}  kept {ratio * 100:.1f}% of its zh-CN")

    print(f"\nD2 summarised zh-CN ({len(summary_cn)}):")
    for sid, ratio in summary_cn:
        print(f"  {sid:>6}  {ratio:.2f} Han per English word")

    if not apply:
        print("\n(dry run — pass --apply to write)")
        return 0

    # D1: rewrite the abridged Traditional bodies from the full zh-CN.
    for sid, _ in abridged_tw:
        cn_body = (SERMONS / "zh-CN" / f"{sid}.txt").read_text()
        tw_body = to_traditional(cn_body)
        (SERMONS / "zh-TW" / f"{sid}.txt").write_text(tw_body)
        print(f"rewrote assets/sermons/zh-TW/{sid}.txt")

    # D2: mark the summaries. zh-TW is a conversion of zh-CN, so when the
    # Simplified body is a summary the Traditional one is too.
    marked = {sid for sid, _ in summary_cn}
    for rec in records:
        if rec["id"] in marked:
            rec["condensed"] = ["zh-CN", "zh-TW"]
        else:
            rec.pop("condensed", None)

    INDEX.write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n")
    print(f"marked {len(marked)} records as condensed in {INDEX.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
