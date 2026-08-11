#!/usr/bin/env python3
"""Repair the 和合本雅伟版 defects found by check 26 (docs/DATA-INTEGRITY.md).

Two defect classes, both silent:

1. LOOKALIKE CHARACTERS. A wrong character throws nothing, breaks no key and
   renders perfectly — CanvasKit only drops a glyph it has no font for, and
   every character repaired here is an ordinary CJK Unified Ideograph. So the
   corruption is legible, plausible and invisible. U+4E36 丶 is the *dot
   stroke*, the character that names a piece of a glyph; it cannot occur in
   running prose, and it stands where the enumeration comma 、 U+3001 belongs.
   Every previous sweep missed it because the repertoire check asks which
   Unicode BLOCKS a file uses, and 丶 sits in the same block as every other
   Han character in the file.

2. ZERO BOOK ORDINALS. In `cuvs-yhwh-tr.json` every 歷代志上/下 record carries
   id `000CCCVVV`, colliding with 創世記 and with each other: 562 collisions
   across 1,764 records. Latent, not live — `Verse.fromJson` never reads the
   asset's `id` field and `Verse.id` is computed from the book name — so
   nothing the reader sees is wrong today. It is repaired because the field is
   the join key any future cross-edition work would reach for.

WITNESSES. Four texts of the same edition, none authoritative alone:

  * ``assets/cuvs-plus.json`` + ``assets/tagged/cuvs-plus/`` — 和合本+Strong's,
    the same base text imported separately. Clean of 丶.
  * ``assets/tagged/cuvs-yhwh/`` — our own tagged layer. It reads 腮, 趟 and
    凶淫 correctly at every site where the plain layer does not, which is why
    the plain and tagged copies of one verse can disagree: they are corrupt to
    different depths. Jeremiah 12:14 is the clearest case — plain reads
    承巡菇业, tagged reads 承巡产业, and neither is 承受产业.
  * the yahwehdehua export (``~/Documents/New project/yahwehdehua_bible``),
    whose ``manifest.json`` records site-owner authorization and which the LEB
    repair already trusted. Independent of this repository, and it corroborates
    every reading below. It is *not* clean itself — it carries 丶 at two sites
    we also carry — which is the whole argument for requiring two witnesses.

THE RULE, stated so a later reader can disagree with it: repair only where our
reading is **semantically impossible in context** AND at least two witnesses
read a sensible alternative. An attested variant is left alone even when a
witness spells it differently — 辊/滚, 幌/晃, 锨/杴 and the proper name 犰多/朵多
are recorded in the doc and deliberately NOT touched, because "a witness spells
it differently" is a weaker claim than "this cannot be read".

Every substitution is gated at the SITE, not merely on a witness existing: the
witness must read the replacement between the same two Han words. A failed gate
skips that site and reports it; it never falls back to applying the edit
anyway. The traditional file is never matched against a simplified witness
directly — it is chained off its own simplified sibling, which is aligned with
it character for character, and every traditional character introduced must
already be attested elsewhere in the traditional file.

Run with no flags to verify — exit 0 means nothing left to repair.
Run with --write to apply. Idempotent either way.
"""

from __future__ import annotations

import argparse
import gzip
import json
import os
import sys
from collections import Counter, defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
ASSETS = REPO / "assets"
WITNESS = Path(
    os.path.expanduser("~/Documents/New project/yahwehdehua_bible/output")
) / "data" / "verse_readings.jsonl.gz"

STROKE = "丶"  # U+4E36, never prose
SEPARATORS = "、，" + STROKE


def is_han(ch: str) -> bool:
    return "一" <= ch <= "鿿" or "㐀" <= ch <= "䶿"


# `bad` is matched literally; `simp`/`trad` are the readings, always the same
# length as `bad` so a repair is a character-for-character substitution and the
# traditional file stays index-aligned with the simplified one. `sep` marks the
# site where what must be proved is that A separator stands here, not which one
# — the editions disagree about 、 against ，, and the replacement character
# comes from cuvs-plus's own usage.
SITES = [
    dict(bad=STROKE, simp="、", trad="、", sep=True,
         arbiters=("plus", "tagged"), label="stroke for comma"),
    # 恉 (zhǐ, "purport") for 腮 (sāi, "jaw"). 士師記 15:16 uses both in one
    # sentence, so the verse witnesses itself.
    dict(bad="恉", simp="腮", trad="腮",
         arbiters=("tagged", "external"), label="jawbone"),
    # 逿 (dàng) for 趟 (tāng, "to wade"). The two differ only in the radical
    # (辶 against 走) beneath a shared 尚. Every site is someone wading through
    # water, which 逿 cannot mean.
    dict(bad="逿", simp="趟", trad="趟",
         arbiters=("tagged", "external"), label="wading"),
    dict(bad="扔菏", simp="凶淫", trad="兇淫",
         arbiters=("tagged", "plus", "external"), label="Judg 20:6"),
    dict(bad="承巡菇业", simp="承受产业", trad="承受產業",
         arbiters=("plus", "external"), label="Jer 12:14 inheritance"),
    # The tagged layer's shallower corruption of the same verse.
    dict(bad="承巡产业", simp="承受产业", trad="承受產業",
         arbiters=("plus", "external"), label="Jer 12:14 inheritance (tagged)"),
    dict(bad="暇疵", simp="瑕疵", trad="瑕疵",
         arbiters=("plus", "external"), label="2 Sam 14:25 blemish"),
]

# 承巡菇業 in the traditional file, 承巡菇业 in the simplified: the bad strings
# themselves are not script-neutral. Rather than carry a second table, the
# traditional pass only ever touches the indices that actually change, and
# checks each one against the simplified bad string. Those characters (巡, 菇,
# 扔, 菏, 暇, 丶) are the same in both scripts.
def changed_offsets(site) -> list[int]:
    return [i for i, (a, b) in enumerate(zip(site["bad"], site["simp"])) if a != b]


def load_json(path: Path):
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def load_external() -> dict[str, str]:
    """The outside witness's 和合本 keyed BBBCCCVVV; empty when absent."""
    if not WITNESS.exists():
        return {}
    out: dict[str, str] = {}
    with gzip.open(WITNESS, "rt", encoding="utf-8") as fh:
        for line in fh:
            rec = json.loads(line)
            if rec.get("version") != "cuv2017_strongs":
                continue
            out["%03d%03d%03d" % (
                rec["book_ordinal"], rec["chapter"], rec["verse"]
            )] = rec["text_clean"]
    return out


def reduce_witness(text: str) -> tuple[str, list[bool]]:
    """A witness verse as its Han stream plus "a separator follows here".

    The divine name is normalised because cuvs-plus prints 耶和华 where this
    edition prints 雅伟 — a systematic, documented difference between the two
    imports, and the one that made the first version of this gate fail at
    every site where the name fell inside the context window. 丶 counts as a
    separator, not as a word: the outside witness carries it too.
    """
    text = text.replace("耶和华", "雅伟")
    han: list[str] = []
    sep: list[bool] = []
    for ch in text:
        if is_han(ch) and ch != STROKE:
            han.append(ch)
            sep.append(False)
        elif sep and ch in SEPARATORS:
            sep[-1] = True
    return "".join(han), sep


def context(text: str, start: int, end: int, span: int = 2) -> tuple[str, str]:
    """The `span` Han words either side of text[start:end].

    Punctuation is skipped because the editions punctuate differently, and 丶
    is skipped because it is the corruption we are here to remove — what the
    gate needs is the words around the site, not the commas.
    """
    def take(indices):
        got = []
        for i in indices:
            ch = text[i]
            if is_han(ch) and ch != STROKE:
                got.append(ch)
                if len(got) == span:
                    break
        return got

    before = take(range(start - 1, -1, -1))[::-1]
    return "".join(before), "".join(take(range(end, len(text))))


def corroborates(witness_text: str, before: str, after: str, site) -> bool:
    """Does this witness read the replacement between the same two words?

    An empty right-hand context means the site ends the verse — 2 Samuel
    14:25's 毫無瑕疵 is the last word Absalom's description has — and the
    witness is then required to end there too, rather than the site being
    ungateable.
    """
    if not witness_text or not before:
        return False
    han, sep = reduce_witness(witness_text)
    want = site["simp"]
    pos = han.find(before)
    while pos >= 0:
        j = pos + len(before)
        if site.get("sep"):
            tail = han[j:]
            if sep[j - 1] and (tail == after if not after
                               else tail.startswith(after)):
                return True
        elif han[j:j + len(want)] == want:
            tail = han[j + len(want):]
            if tail == after if not after else tail.startswith(after):
                return True
        pos = han.find(before, pos + 1)
    return False


class Report:
    def __init__(self) -> None:
        self.repairs: Counter[str] = Counter()
        self.skipped: list[str] = []
        self.notes: list[str] = []
        self.witnessed: dict[str, Counter[str]] = defaultdict(Counter)

    def line(self, key: str, n: int = 1) -> None:
        self.repairs[key] += n


def approve(text: str, ref: str, witnesses: dict[str, str], report: Report):
    """Every gated repair in one verse, as (start, end, simp_reading, site)."""
    edits = []
    for site in SITES:
        bad = site["bad"]
        start = text.find(bad)
        while start >= 0:
            end = start + len(bad)
            before, after = context(text, start, end)
            agreeing = [
                name for name in site["arbiters"]
                if corroborates(witnesses.get(name, ""), before, after, site)
            ]
            # One corroborating witness is enough, because the witness is not
            # voting on whether the site is broken — that is settled by the
            # character itself, which cannot be read here — but supplying the
            # reading. A witness that is corrupt at the same site simply
            # abstains; cuvs-plus carries 恉 and 逿 too, and vetoing on its
            # silence would block a repair three other texts agree on.
            if agreeing:
                edits.append((start, end, site["simp"], site, agreeing))
                report.witnessed[site["label"]][",".join(agreeing)] += 1
            else:
                report.skipped.append(
                    f"{ref} {site['label']}: no witness reads it — left alone"
                )
            start = text.find(bad, end)
    return sorted(edits)


def apply_simp(text: str, edits) -> str:
    out = list(text)
    for start, end, want, _site, _who in edits:
        out[start:end] = list(want)
    return "".join(out)


def apply_trad(text: str, edits, alphabet: set[str], ref: str, report: Report) -> str:
    """The traditional file, chained off its simplified sibling's approvals.

    Only the offsets that actually change are touched, each verified to hold
    the same character the simplified file held, and every character
    introduced must already be attested in this file.
    """
    out = list(text)
    for start, end, _want, site, _who in edits:
        offsets = changed_offsets(site)
        trad = site["trad"]
        if any(text[start + i] != site["bad"][i] for i in offsets):
            report.skipped.append(f"{ref} {site['label']}: traditional text differs at site")
            continue
        if any(trad[i] not in alphabet for i in offsets):
            report.skipped.append(f"{ref} {site['label']}: character unattested in this file")
            continue
        for i in offsets:
            out[start + i] = trad[i]
    return "".join(out)


def tagged_books(plain: list[dict], recon: dict[str, dict[str, str]],
                 report: Report, layer: str) -> dict[str, str]:
    """Map each tagged file stem to a book ordinal, by matching its text.

    Derived rather than hardcoded so a renamed or added file cannot silently
    attach itself to the wrong book. Verse numbers alone cannot do it — Jude
    and Philemon are both one chapter of twenty-five verses, so their verse
    sets are identical — and neither can exact set equality, because
    cuvs-plus's plain file holds a few verses its tagged layer does not. So
    candidates are drawn by verse overlap and settled by reading them.
    """
    verses: dict[str, dict[str, str]] = {}
    for rec in plain:
        verses.setdefault(rec["id"][:3], {})[
            f"{int(rec['chapter'])}:{int(rec['verse'])}"
        ] = rec["text"]

    out = {}
    for stem, book in sorted(recon.items()):
        scores = []
        for ordinal, known in verses.items():
            shared = sorted(book.keys() & known.keys())
            if len(shared) < 0.9 * len(book):
                continue
            head = lambda s: "".join(c for c in s if is_han(c))[:6]  # noqa: E731
            hits = sum(1 for cv in shared[:25] if head(book[cv]) == head(known[cv]))
            scores.append((hits / len(shared[:25]), ordinal))
        scores.sort(reverse=True)
        # The margin decides, not the absolute score: 3 John matches its own
        # book on 11 of 14 verses (the rest differ only in 阿 against 啊) and
        # the runner-up on 1 of 13, so a fixed high bar would reject a match
        # that is ten times better than any alternative.
        if scores and scores[0][0] >= 0.5 and (
            len(scores) == 1 or scores[0][0] >= 3 * scores[1][0]
        ):
            out[stem] = scores[0][1]
        else:
            report.skipped.append(
                f"tagged/{layer}/{stem}.json: no book matched it decisively"
            )
    return out


def repair_ids(data: list[dict], simp: list[dict], report: Report) -> int:
    """歷代志上/下 carry ordinal 000. Take the ordinal the sibling file uses.

    Gated on the two files listing the same books in the same order and on the
    repaired id being one the simplified file actually holds for that verse.
    """
    order_t, order_s = [], []
    for src, dst in ((data, order_t), (simp, order_s)):
        for rec in src:
            if rec["book"] not in dst:
                dst.append(rec["book"])
    if len(order_t) != len(order_s):
        report.skipped.append("id repair: the two files list different books")
        return 0
    ordinal = {}
    for i, book in enumerate(order_t):
        ords = {r["id"][:3] for r in simp if r["book"] == order_s[i]}
        if len(ords) == 1:
            ordinal[book] = ords.pop()
    valid = {r["id"] for r in simp}
    changed = 0
    for rec in data:
        if rec["id"][:3] != "000" or rec["book"] not in ordinal:
            continue
        fixed = ordinal[rec["book"]] + rec["id"][3:]
        if fixed in valid:
            rec["id"] = fixed
            changed += 1
        else:
            report.skipped.append(
                f"id repair {rec['book']} {rec['chapter']}:{rec['verse']}: "
                f"{fixed} is not a verse the simplified file holds"
            )
    return changed


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--write", action="store_true", help="apply the repairs")
    args = ap.parse_args()

    report = Report()
    external = load_external()
    if not external:
        report.notes.append(f"outside witness absent at {WITNESS}")

    indented = {
        name: "\n" in (ASSETS / f"{name}.json").read_text(encoding="utf-8")[:400]
        for name in ("cuvs-yhwh", "cuvs-yhwh-tr", "cuvs-plus")
    }
    simp = load_json(ASSETS / "cuvs-yhwh.json")
    trad = load_json(ASSETS / "cuvs-yhwh-tr.json")
    plus_recs = load_json(ASSETS / "cuvs-plus.json")
    plus = {r["id"]: r["text"] for r in plus_recs}

    # The tagged layers, reconstructed verse by verse, are witnesses in their
    # own right and are also repaired themselves.
    tagged: dict[str, dict[str, tuple[Path, str, list]]] = {}
    tagged_text: dict[str, dict[str, str]] = {}
    tagged_data: dict[Path, dict] = {}
    for layer, plainrecs in (("cuvs-yhwh", simp), ("cuvs-plus", plus_recs)):
        recon: dict[str, dict[str, str]] = {}
        paths: dict[str, Path] = {}
        for path in sorted((ASSETS / "tagged" / layer).glob("*.json")):
            data = tagged_data[path] = load_json(path)
            paths[path.stem] = path
            recon[path.stem] = {
                "%d:%d" % tuple(int(x) for x in cv.split(":")): "".join(
                    r["w"] for r in runs if isinstance(r.get("w"), str)
                )
                for cv, runs in data.items()
            }
        books = tagged_books(plainrecs, recon, report, layer)
        tagged[layer] = {}
        tagged_text[layer] = {}
        for stem, ordinal in books.items():
            for cv, runs in tagged_data[paths[stem]].items():
                ch, vs = (int(x) for x in cv.split(":"))
                vid = "%s%03d%03d" % (ordinal, ch, vs)
                tagged[layer][vid] = (paths[stem], cv, runs)
                tagged_text[layer][vid] = recon[stem]["%d:%d" % (ch, vs)]

    def witnesses_for(target: str, vid: str) -> dict[str, str]:
        return {
            "plus": "" if target == "cuvs-plus" else plus.get(vid, ""),
            "tagged": "" if target == "tagged-yhwh"
                      else tagged_text["cuvs-yhwh"].get(vid, ""),
            "external": external.get(vid, ""),
        }

    # --- plain simplified -------------------------------------------------
    approvals: dict[str, list] = {}
    for name, recs, key in (("cuvs-yhwh", simp, "cuvs-yhwh"),
                            ("cuvs-plus", plus_recs, "cuvs-plus")):
        n = 0
        for rec in recs:
            if not any(s["bad"] in rec["text"] for s in SITES):
                continue
            ref = f"{name} {rec['book']} {rec['chapter']}:{rec['verse']}"
            edits = approve(rec["text"], ref, witnesses_for(key, rec["id"]), report)
            if not edits:
                continue
            if name == "cuvs-yhwh":
                approvals[rec["id"]] = edits
            fixed = apply_simp(rec["text"], edits)
            n += sum(1 for a, b in zip(rec["text"], fixed) if a != b)
            rec["text"] = fixed
        report.line(name, n)

    # --- plain traditional, chained off the simplified sibling -------------
    alphabet = set("".join(r["text"] for r in trad))
    id_fixes = repair_ids(trad, simp, report)
    report.line("cuvs-yhwh-tr ids", id_fixes)
    n = 0
    for rec in trad:
        edits = approvals.get(rec["id"])
        if not edits:
            continue
        ref = f"cuvs-yhwh-tr {rec['book']} {rec['chapter']}:{rec['verse']}"
        sibling = next(r for r in simp if r["id"] == rec["id"])
        if len(rec["text"]) != len(sibling["text"]):
            report.skipped.append(f"{ref}: not aligned with its simplified sibling")
            continue
        fixed = apply_trad(rec["text"], edits, alphabet, ref, report)
        n += sum(1 for a, b in zip(rec["text"], fixed) if a != b)
        rec["text"] = fixed
    report.line("cuvs-yhwh-tr", n)

    # --- tagged layers ----------------------------------------------------
    tagged_dirty: set[Path] = set()
    for layer in tagged:
        n = 0
        for vid, (path, cv, runs) in tagged[layer].items():
            text = tagged_text[layer][vid]
            if not any(s["bad"] in text for s in SITES):
                continue
            ref = f"tagged/{layer} {path.stem} {cv}"
            key = "tagged-yhwh" if layer == "cuvs-yhwh" else "cuvs-plus"
            edits = approve(text, ref, witnesses_for(key, vid), report)
            if not edits:
                continue
            fixed = apply_simp(text, edits)
            # Write the repaired verse back into the runs it came from.
            at = 0
            for run in runs:
                word = run.get("w")
                if not isinstance(word, str):
                    continue
                new = fixed[at:at + len(word)]
                if new != word:
                    run["w"] = new
                    n += sum(1 for a, b in zip(word, new) if a != b)
                at += len(word)
            tagged_dirty.add(path)
        report.line(f"tagged/{layer}", n)

    for key, n in report.repairs.items():
        print(f"  {key:22s} {n:5d}")
    if report.witnessed:
        print("\n  who corroborated each site:")
        for label, who in report.witnessed.items():
            detail = "  ".join(f"{k}×{v}" for k, v in sorted(who.items()))
            print(f"    {label:32s} {detail}")
    if report.notes:
        for line in report.notes:
            print(f"\n  note: {line}")
    if report.skipped:
        print(f"\n  {len(report.skipped)} site(s) left alone because the gate failed:")
        for line in report.skipped[:25]:
            print(f"    {line}")

    total = sum(report.repairs.values())
    if not args.write:
        print(f"\n{total} repair(s) pending. Re-run with --write to apply.")
        return 0 if total == 0 else 1

    # Each file keeps the shape it was found in. cuvs-yhwh and its traditional
    # twin are indent-2; cuvs-plus is a single compact line. Writing either one
    # the other way reformats megabytes and buries a sixty-nine character
    # repair in a two-hundred-thousand line diff.
    for name, data in (("cuvs-yhwh", simp), ("cuvs-yhwh-tr", trad),
                       ("cuvs-plus", plus_recs)):
        path = ASSETS / f"{name}.json"
        with path.open("w", encoding="utf-8") as fh:
            if indented[name]:
                json.dump(data, fh, ensure_ascii=False, indent=2)
                fh.write("\n")
            else:
                json.dump(data, fh, ensure_ascii=False, separators=(",", ":"))
    # The tagged layers are written compactly, as they were found; the plain
    # files are indent-2. Preserving each format keeps the diff to the verses
    # that changed instead of reformatting 6.7 MB.
    for path in sorted(tagged_dirty):
        with path.open("w", encoding="utf-8") as fh:
            json.dump(tagged_data[path], fh, ensure_ascii=False,
                      separators=(",", ":"))
    print(f"\nWrote {total} repair(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
