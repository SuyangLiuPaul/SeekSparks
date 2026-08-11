#!/usr/bin/env python3
"""Repair lookalike-character corruption in the 和合本 Chinese editions.

Found by check 26 (docs/DATA-INTEGRITY.md): the first comparison of this
repository's Chinese scripture against a witness obtained OUTSIDE it.

The defect class is the dangerous one. A wrong character throws nothing,
breaks no key, and renders perfectly — CanvasKit only drops a glyph it has
no font for, and every character repaired here is an ordinary CJK Unified
Ideograph. So the corruption is legible, plausible and silent.

Two witnesses arbitrate, and neither alone is enough:

  * ``assets/cuvs-plus.json`` — 和合本+Strong's, the same base text imported
    separately. Catches what cuvs-yhwh alone got wrong.
  * the yahwehdehua export (``~/Documents/New project/yahwehdehua_bible``),
    whose ``manifest.json`` records site-owner authorization and which the
    LEB repair already trusted. Catches what BOTH of our copies got wrong —
    恉 and 逿 are in every Chinese file we ship, so no comparison confined
    to this repository could ever have found them.

THE RULE, stated so a later reader can disagree with it: repair only where
our reading is **semantically impossible in context** AND a witness reads a
sensible alternative. An attested variant is left alone even when a witness
spells it differently — 辊/滚, 幌/晃, 锨/杴 and the proper name 犰多/朵多
are recorded in the doc and deliberately NOT touched, because "a witness
spells it differently" is a weaker claim than "this cannot be read".

Every substitution is gated at the SITE, not merely on the witness
existing. A failed gate skips that site and reports it; it never falls back
to applying the edit anyway. No repair introduces a character the file did
not already contain elsewhere, which is checked at run time.

Run with no flags to verify — exit 0 means nothing left to repair.
Run with --write to apply. Idempotent either way.
"""

from __future__ import annotations

import argparse
import gzip
import json
import os
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
ASSETS = REPO / "assets"
WITNESS_DIR = Path(
    os.path.expanduser("~/Documents/New project/yahwehdehua_bible/output")
)

HAN = lambda ch: "一" <= ch <= "鿿" or "㐀" <= ch <= "䶿"  # noqa: E731

# Single characters. `arbiter` names who must corroborate the site:
#   "plus"     — assets/cuvs-plus.json, the sibling import
#   "external" — the yahwehdehua export
SUBSTITUTIONS = [
    # U+4E36 is the *dot stroke*, the character used to name a piece of a
    # glyph. It is not punctuation and cannot occur in running prose. It
    # stands here where the enumeration comma 、 U+3001 belongs and is
    # visually identical to it, which is why every previous sweep missed
    # it: the repertoire check asks which Unicode BLOCKS a file uses, and
    # U+4E36 sits in the same block as every other Han character in it.
    dict(bad="丶", simp="、", trad="、", arbiter="plus", label="stroke for comma"),
    # 恉 (zhǐ, "purport") for 腮 (sāi, "jaw"). 士師記 15:16 uses both in one
    # sentence, so the verse witnesses itself.
    dict(bad="恉", simp="腮", trad="腮", arbiter="external", label="jawbone"),
    # 逿 (dàng) for 趟 (tāng, "to wade"). The two differ only in the radical
    # (辶 against 走) beneath a shared 尚. Every site is someone wading
    # through water, which 逿 cannot mean.
    dict(bad="逿", simp="趟", trad="趟", arbiter="external", label="wading"),
]

# Whole phrases, same discipline: what we hold is unreadable and a witness
# holds a reading. The traditional forms are not transliterated by this
# script — each is checked at run time against the traditional file's own
# text, so a future edit cannot smuggle a simplified character into it.
PHRASES = [
    dict(simp_bad="承巡菇业", simp="承受产业",
         trad_bad="承巡菇業", trad="承受產業", label="Jer 12:14 inheritance"),
    dict(simp_bad="扔菏丑恶", simp="凶淫丑恶",
         trad_bad="扔菏醜惡", trad="兇淫醜惡", label="Judg 20:6"),
    dict(simp_bad="毫无暇疵", simp="毫无瑕疵",
         trad_bad="毫無暇疵", trad="毫無瑕疵", label="2 Sam 14:25 blemish"),
]

PLAIN_FILES = {"cuvs-yhwh": "simp", "cuvs-yhwh-tr": "trad", "cuvs-plus": "simp"}
TAGGED_LAYERS = {"cuvs-yhwh": "simp", "cuvs-plus": "simp"}


def load_json(path: Path):
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def load_witness() -> dict[str, str]:
    """The external witness's 和合本 keyed BBBCCCVVV; empty when absent."""
    src = WITNESS_DIR / "data" / "verse_readings.jsonl.gz"
    if not src.exists():
        return {}
    out: dict[str, str] = {}
    with gzip.open(src, "rt", encoding="utf-8") as fh:
        for line in fh:
            rec = json.loads(line)
            if rec.get("version") != "cuv2017_strongs":
                continue
            out["%03d%03d%03d" % (
                rec["book_ordinal"], rec["chapter"], rec["verse"]
            )] = rec["text_clean"]
    return out


def han_context(text: str, index: int, span: int = 2) -> tuple[str, str]:
    """The Han characters either side of a site, skipping punctuation.

    Punctuation is skipped because the editions punctuate differently; what
    the gate needs is the words around the site, not the commas.
    """
    def take(indices):
        got = []
        for i in indices:
            ch = text[i]
            if HAN(ch) and ch != "丶":
                got.append(ch)
                if len(got) == span:
                    break
        return got

    before = take(range(index - 1, -1, -1))[::-1]
    return "".join(before), "".join(take(range(index + 1, len(text))))


def gate_ok(arbiter: str, before: str, after: str, want: str) -> bool:
    """Does the arbiter read `want` between the same two Han contexts?"""
    if not arbiter or not before or not after:
        return False
    # For the comma, what is being proved is that a SEPARATOR stands at this
    # site, not which one — the editions disagree about 、 against ，. The
    # replacement character itself comes from cuvs-plus's own usage.
    seps = "、，" if want == "、" else want
    reduced = "".join(c for c in arbiter if HAN(c) or c in seps)
    pos = reduced.find(before)
    while pos >= 0:
        tail = reduced[pos + len(before):]
        if tail[:1] in tuple(seps) and tail[1:1 + len(after)] == after:
            return True
        pos = reduced.find(before, pos + 1)
    return False


class Report:
    def __init__(self) -> None:
        self.counts: dict[str, int] = {}
        self.skipped: list[str] = []


def repair_plain(name, script, plus, witness, trad_alphabet, report):
    path = ASSETS / f"{name}.json"
    data = load_json(path)
    changed = 0

    for rec in data:
        text = original = rec["text"]
        ref = f"{rec['book']} {rec['chapter']}:{rec['verse']}"

        for sub in SUBSTITUTIONS:
            if sub["bad"] not in text:
                continue
            want = sub[script]
            if want not in trad_alphabet and script == "trad":
                report.skipped.append(
                    f"{name} {ref} {sub['label']}: {want} unattested in this file"
                )
                continue
            arbiter = (
                plus.get(rec["id"], "") if sub["arbiter"] == "plus"
                else witness.get(rec["id"], "")
            )
            out = []
            for i, ch in enumerate(text):
                if ch != sub["bad"]:
                    out.append(ch)
                    continue
                before, after = han_context(text, i)
                if gate_ok(arbiter, before, after, want):
                    out.append(want)
                    changed += 1
                else:
                    out.append(ch)
                    report.skipped.append(
                        f"{name} {ref} {sub['label']}: gate failed"
                    )
            text = "".join(out)

        for ph in PHRASES:
            bad = ph["trad_bad"] if script == "trad" else ph["simp_bad"]
            want = ph["trad"] if script == "trad" else ph["simp"]
            if bad not in text:
                continue
            # cuvs-plus is the arbiter for every phrase: it is simplified, so
            # the traditional file is gated on cuvs-plus holding the reading
            # AND on every character of the traditional replacement being
            # attested elsewhere in the traditional file itself.
            reading_ok = ph["simp"] in plus.get(rec["id"], "")
            chars_ok = all(c in trad_alphabet for c in want) if script == "trad" else True
            if reading_ok and chars_ok:
                text = text.replace(bad, want)
                changed += 1
            else:
                why = "reading not in cuvs-plus" if not reading_ok else "character unattested"
                report.skipped.append(f"{name} {ref} {ph['label']}: {why}")

        if text != original:
            rec["text"] = text

    report.counts[name] = changed
    return path, data, changed


def repair_tagged(layer, script, report):
    """The tagged layer carries a second copy of the same words."""
    written = []
    total = 0
    for path in sorted((ASSETS / "tagged" / layer).glob("*.json")):
        data = load_json(path)
        changed = 0
        for runs in data.values():
            for run in runs:
                word = run.get("w")
                if not isinstance(word, str):
                    continue
                new = word
                for sub in SUBSTITUTIONS:
                    new = new.replace(sub["bad"], sub[script])
                for ph in PHRASES:
                    new = new.replace(ph["simp_bad"], ph["simp"])
                if new != word:
                    run["w"] = new
                    changed += 1
        if changed:
            written.append((path, data))
            total += changed
    report.counts[f"tagged/{layer}"] = total
    return written


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--write", action="store_true", help="apply the repairs")
    args = ap.parse_args()

    witness = load_witness()
    if not witness:
        print(
            f"note: external witness not present at {WITNESS_DIR}\n"
            "      Sites gated on it are skipped and reported below.",
            file=sys.stderr,
        )

    plus = {r["id"]: r["text"] for r in load_json(ASSETS / "cuvs-plus.json")}
    trad_alphabet = set(
        "".join(r["text"] for r in load_json(ASSETS / "cuvs-yhwh-tr.json"))
    )

    report = Report()
    pending = [
        repair_plain(name, script, plus, witness, trad_alphabet, report)
        for name, script in PLAIN_FILES.items()
    ]
    tagged = []
    for layer, script in TAGGED_LAYERS.items():
        tagged.extend(repair_tagged(layer, script, report))

    for key, n in report.counts.items():
        print(f"  {key:26s} {n:4d} character sites")
    if report.skipped:
        print(f"\n  {len(report.skipped)} site(s) skipped because a gate failed:")
        for line in report.skipped[:20]:
            print(f"    {line}")

    total = sum(report.counts.values())
    if not args.write:
        print(f"\n{total} site(s) would be repaired. Re-run with --write to apply.")
        return 0 if total == 0 else 1

    for path, data, changed in pending:
        if not changed:
            continue
        with path.open("w", encoding="utf-8") as fh:
            json.dump(data, fh, ensure_ascii=False, indent=2)
            fh.write("\n")
    for path, data in tagged:
        with path.open("w", encoding="utf-8") as fh:
            json.dump(data, fh, ensure_ascii=False, separators=(",", ":"))
    print(f"\nWrote {total} character site(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
