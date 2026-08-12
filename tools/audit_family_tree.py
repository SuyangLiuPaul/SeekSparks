#!/usr/bin/env python3
"""Check 36 — does scripture witness the family tree's relationship claims?

`assets/family_tree.json` states 312 parent-child links, 26 marriages and
277 lives. Check 25 proved its 665 references *resolve*; nothing has ever
asked whether the text those references point at says what the record
claims. A family tree draws the same solid line for "Adam begat Seth",
which Genesis 5:3 states in as many words, and for "Ahinoam was the mother
of Jonathan", which no verse states at all.

Three questions, each with the corpus as its witness:

  36c1  Does the name the app prints appear in the passages it cites for
        that person, in any English edition we ship?
  36c2  Does any passage state each parent-child and marriage claim?
  36b   Do the years a record carries agree with each other and with the
        relationships around them?

Five English editions are read, because a name the KJV spells `Methusael`
and the NASB spells `Methushael` must not be scored as a missing person.
Spelling aliases are *derived* from each person's own cited verses rather
than supplied: a token within two edits of the printed name, standing in a
verse the record itself points at, is that edition's spelling of the name.
Nothing is guessed and every derived alias is printed.

Usage:  python3 tools/audit_family_tree.py [--json OUT] [--window N]
"""

import json
import re
import sys
from collections import defaultdict

ROOT = __file__.rsplit("/tools/", 1)[0]

EDITIONS = ["bsb", "kjv", "kjvs", "nasb", "leb"]

# How far apart two names may stand and still witness one relationship.
# A genealogy names the father once and lists the children over the verses
# that follow: 1 Chronicles 2:13 names Jesse, and Ozem is three verses
# later. Same chapter only.
DEFAULT_WINDOW = 4

KIN = re.compile(
    r"\b(begat|begot|begotten|father|fathered|mother|son|sons|daughter|"
    r"daughters|bare|bore|born|birth|wife|wives|husband|married|marry|"
    r"conceived|child|children|descendant|descendants|firstborn|offspring|"
    r"seed|brother|brothers|brethren|sister|sisters|genealogy|generations|"
    r"family|families|house|household)\b",
    re.IGNORECASE,
)

WORD = re.compile(r"[A-Za-z][A-Za-z’'-]*")

# Parenthetical suffixes that disambiguate rather than name.
NOT_A_NAME = {"Lukan", "NT", "II", "III"}


def load(path):
    with open(f"{ROOT}/assets/{path}", encoding="utf-8") as fh:
        return json.load(fh)


def split_slash(name):
    """`Joshua / Jose` is two editions' spellings joined by a slash, not a
    name. Split so the audit can see what the record was trying to say."""
    return [x.strip() for x in name.split("/")] if "/" in name else [name]


def base_and_alias(name):
    """Split 'Jacob (Israel)' into a base name and any alternate name.

    A parenthetical is an alternate *name* only when it is a single
    capitalised word that is not one of the bookkeeping tags the file uses
    to tell two men of the same name apart.
    """
    m = re.match(r"^(.+?)\s*\((.+?)\)\s*$", name)
    if not m:
        return name.strip(), []
    base, paren = m.group(1).strip(), m.group(2).strip()
    if (
        " " not in paren
        and paren[:1].isupper()
        and paren not in NOT_A_NAME
        and "’" not in paren
        and "'" not in paren
    ):
        return base, [paren]
    return base, []


def norm_token(t):
    t = t.replace("’", "'")
    if t.endswith("'s"):
        t = t[:-2]
    return t.rstrip("'")


def edit_distance(a, b, cap=2):
    a, b = a.lower(), b.lower()
    if abs(len(a) - len(b)) > cap:
        return cap + 1
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(
                min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca != cb))
            )
        prev = cur
    return prev[-1]


# ---------------------------------------------------------------- references

BOOK_ALIASES = {}


def build_book_index(verses):
    books = {}
    for r in verses:
        raw = str(r["verse"])
        if not raw.isdigit():
            continue
        books.setdefault(r["book"], {}).setdefault(
            int(r["chapter"]), set()
        ).add(int(raw))
    return books


REF_RE = re.compile(
    r"^\s*(?P<book>(?:[1-3]\s)?[A-Za-z][A-Za-z ]*?)\s+"
    r"(?P<c1>\d+)"
    r"(?::(?P<v1>\d+))?"
    r"(?:\s*[-–]\s*(?:(?P<c2>\d+):)?(?P<v2>\d+))?\s*$"
)


def parse_ref(ref, books):
    """Yield (book, chapter, verse) keys a reference covers.

    Handles `Genesis 3`, `Genesis 5:1-5`, `1 Kings 1-11`,
    `1 Kings 11:43-12:24` and `Genesis 4:19, 22`.
    """
    out = []
    head = None
    for part in ref.split(","):
        part = part.strip()
        if not part:
            continue
        if head and not re.match(r"^[A-Za-z]", part):
            part = f"{head} {part}"
        m = REF_RE.match(part)
        if not m:
            continue
        book = m.group("book").strip()
        if book not in books:
            book = BOOK_ALIASES.get(book, book)
            if book not in books:
                continue
        head = book
        c1 = int(m.group("c1"))
        v1 = m.group("v1")
        c2 = m.group("c2")
        v2 = m.group("v2")
        chapters = books[book]
        if v1 is None:
            # `Genesis 3` or `1 Kings 1-11` — whole chapters.
            last = int(v2) if v2 is not None else c1
            for c in range(c1, last + 1):
                for v in sorted(chapters.get(c, ())):
                    out.append((book, c, v))
            continue
        v1 = int(v1)
        if c2 is not None:  # `1 Kings 11:43-12:24`
            endc, endv = int(c2), int(v2)
            c = c1
            while c <= endc:
                lo = v1 if c == c1 else 1
                hi = endv if c == endc else max(chapters.get(c, {0}))
                for v in sorted(chapters.get(c, ())):
                    if lo <= v <= hi:
                        out.append((book, c, v))
                c += 1
            continue
        hi = int(v2) if v2 is not None else v1
        for v in sorted(chapters.get(c1, ())):
            if v1 <= v <= hi:
                out.append((book, c1, v))
    return out


# ------------------------------------------------------- 36c1 the Chinese

# The app prints two names for every person and its readers are Chinese, so
# checking only the English would be checking the smaller half. The witness
# is the CUV, joined to the English editions on the numeric `id` every
# shipped record carries (31,086 of 31,086 BSB verses join).
#
# Exact containment only. A Chinese name is two or three characters and an
# edit-distance test over CJK produces overwhelming noise — the same
# instrument error that generated 334 false findings in an earlier check.
# Either the characters are in the verse or they are not.
CJK_PAREN = re.compile(r"[（(][^）)]*[）)]")


def zh_forms(name):
    if not name:
        return set()
    out = set()
    for part in re.split(r"[/／]", name):
        part = CJK_PAREN.sub("", part).strip()
        if part:
            out.add(part)
    return out


# --------------------------------------------------------- 36a structural


def structural(people):
    edges = 0
    marriages = set()
    issues = defaultdict(list)

    for pid, p in people.items():
        for field in ("fatherId", "motherId"):
            other = p.get(field)
            if not other:
                continue
            edges += 1
            if other not in people:
                issues["parent id not in the file"].append(f"{pid}.{field}={other}")
                continue
            if pid not in (people[other].get("childIds") or []):
                issues["parent does not list the child back"].append(
                    f"{pid}.{field}={other}"
                )
        for c in p.get("childIds") or []:
            if c not in people:
                issues["child id not in the file"].append(f"{pid}.childIds={c}")
                continue
            if people[c].get("fatherId") != pid and people[c].get("motherId") != pid:
                issues["child does not name the parent back"].append(f"{pid} -> {c}")
        for s in p.get("spouseIds") or []:
            if s not in people:
                issues["spouse id not in the file"].append(f"{pid}.spouseIds={s}")
                continue
            if pid not in (people[s].get("spouseIds") or []):
                issues["marriage recorded on one side only"].append(f"{pid} -> {s}")
            marriages.add(tuple(sorted((pid, s))))
        if pid == p.get("fatherId") or pid == p.get("motherId"):
            issues["person is their own parent"].append(pid)

    # A cycle in the parent links would make the tree unrenderable and is the
    # one structural fault that cannot be seen locally.
    for pid in people:
        seen, cur = set(), pid
        while cur:
            if cur in seen:
                issues["cycle in the parent chain"].append(pid)
                break
            seen.add(cur)
            cur = people.get(cur, {}).get("fatherId")

    return {"edges": edges, "marriages": len(marriages), "issues": dict(issues)}


# --------------------------------------------------------- 36b chronology

# Both year systems run in the same direction: `am` counts up from creation,
# and `bc` is a signed axis where BC is negative and AD positive (Jesus is
# b=-4, d=30). So under BOTH, a larger number is LATER, a lifespan is
# `death - birth`, and a parent's year precedes a child's. Getting this
# backwards for `bc` is what made the first run of this check report 325
# issues, every one of them an artifact.
MIN_FATHERHOOD = 12


def chronology(people):
    issues = defaultdict(list)
    with_birth = with_death = with_span = with_reign = 0
    comparable = skipped_reign = skipped_system = skipped_missing = 0

    def label(p):
        return f"{p['name']} ({p['id']})"

    for p in people.values():
        b, d = p.get("birthYear"), p.get("deathYear")
        span, sys_ = p.get("lifespan"), p.get("yearSystem")
        kind = (p.get("dating") or {}).get("kind")
        rs, re_ = p.get("reignStart"), p.get("reignEnd")
        if b is not None:
            with_birth += 1
        if d is not None:
            with_death += 1
        if span is not None:
            with_span += 1
        if rs is not None or re_ is not None:
            with_reign += 1

        # A `reign` record's birthYear is an accession year, not a birth
        # (_meta.dating.kinds says so and the app does not display it), so
        # it is not a life to measure.
        if b is not None and d is not None and kind != "reign":
            if d < b:
                issues["death before birth"].append(
                    f"{label(p)} {sys_} b={b} d={d}"
                )
            elif span is not None and span != d - b:
                issues["lifespan disagrees with death - birth"].append(
                    f"{label(p)} {sys_} b={b} d={d} lifespan={span} "
                    f"(d-b={d - b})"
                )
        if span is not None and (span <= 0 or span > 1000):
            issues["lifespan outside 1..1000"].append(f"{label(p)} {span}")
        if rs is not None and re_ is not None and re_ < rs:
            issues["reign ends before it starts"].append(
                f"{label(p)} {rs}..{re_}"
            )
        if rs is not None and d is not None and rs > d:
            issues["reign starts after death"].append(
                f"{label(p)} reign={rs} d={d}"
            )
        if re_ is not None and d is not None and re_ > d:
            issues["reign ends after death"].append(
                f"{label(p)} reign end={re_} d={d}"
            )

    for p in people.values():
        for field in ("fatherId", "motherId"):
            par = people.get(p.get(field) or "")
            if par is None:
                continue
            pk = (par.get("dating") or {}).get("kind")
            ck = (p.get("dating") or {}).get("kind")
            if pk == "reign" or ck == "reign":
                skipped_reign += 1
                continue
            if par.get("birthYear") is None or p.get("birthYear") is None:
                skipped_missing += 1
                continue
            if par.get("yearSystem") != p.get("yearSystem"):
                skipped_system += 1
                issues["parent and child use different year systems"].append(
                    f"{label(par)} {par.get('yearSystem')} -> "
                    f"{label(p)} {p.get('yearSystem')}"
                )
                continue
            comparable += 1
            gap = p["birthYear"] - par["birthYear"]
            if gap < 0:
                issues["child born before the parent"].append(
                    f"{label(par)} {par['birthYear']} -> {label(p)} "
                    f"{p['birthYear']}"
                )
            elif gap < MIN_FATHERHOOD:
                issues[f"parent under {MIN_FATHERHOOD} at the birth"].append(
                    f"{label(par)} -> {label(p)}  gap={gap}"
                )
            pd = par.get("deathYear")
            if pd is not None and pd < p["birthYear"] - 1:
                issues["parent died before the child was born"].append(
                    f"{label(par)} d={pd} -> {label(p)} b={p['birthYear']}"
                )

    return {
        "issues": dict(issues),
        "withBirth": with_birth,
        "withDeath": with_death,
        "withLifespan": with_span,
        "withReign": with_reign,
        "comparable": comparable,
        "skippedReign": skipped_reign,
        "skippedSystem": skipped_system,
        "skippedMissing": skipped_missing,
    }


# --------------------------------------------------------------------- main


def main():
    window = DEFAULT_WINDOW
    if "--window" in sys.argv:
        window = int(sys.argv[sys.argv.index("--window") + 1])

    tree = load("family_tree.json")
    people = {p["id"]: p for p in tree["people"]}

    text = {}
    tokens = {}  # edition -> token -> set(key)
    for tag in EDITIONS:
        recs = load(f"{tag}.json")
        t = {}
        inv = defaultdict(set)
        for r in recs:
            # Psalm superscriptions carry verse `title` (check 31b). They are
            # scripture and are searched; they sort before verse 1.
            raw = str(r["verse"])
            vnum = 0 if not raw.isdigit() else int(raw)
            key = (r["book"], int(r["chapter"]), vnum)
            t[key] = r["text"]
            for w in WORD.findall(r["text"]):
                inv[norm_token(w)].add(key)
        text[tag] = t
        tokens[tag] = inv
    books = build_book_index(load("kjvs.json"))

    # (book, chapter, verse) -> id -> CUV text, so an English reference can
    # be looked up in a Chinese edition without a book-name table.
    ids = {}
    for r in load("bsb.json"):
        raw = str(r["verse"])
        if raw.isdigit() and r.get("id"):
            ids[(r["book"], int(r["chapter"]), int(raw))] = r["id"]
    cuv = {r["id"]: r["text"] for r in load("cuvs-yhwh.json") if r.get("id")}

    # Tokens the corpus ever writes in lower case. A proper name is not one
    # of them, and this is how `God`, `Lord`, `Let` and `Baby` are kept out
    # of the alias sets without a dictionary.
    lowercased = set()
    for tag in EDITIONS:
        for w in tokens[tag]:
            if w[:1].islower():
                lowercased.add(w.lower())

    all_names = set()
    for p in people.values():
        for part in split_slash(p["name"]):
            b, a = base_and_alias(part)
            all_names.add(b)
            all_names.update(a)

    def token_forms(name):
        """Single-word forms a verse could print for this name.

        `Ahinoam of Jezreel` is a description, not a token: the verse prints
        `Ahinoam`. Trailing prepositional phrases are dropped rather than
        searched for verbatim, which is what made five people look unnamed.
        """
        out = set()
        for part in split_slash(name):
            b, a = base_and_alias(part)
            b = re.sub(r"\s+(of|the)\s+.*$", "", b).strip()
            if b:
                out.add(b)
            out.update(a)
        return out

    # ---- forms, and the aliases the corpus itself supplies
    cited = {}
    forms = {}
    derived = {}
    unnamed = []
    for pid, p in people.items():
        fs = token_forms(p["name"])
        other_names = all_names - fs
        keys = []
        for r in p["refs"]:
            keys.extend(parse_ref(r, books))
        cited[pid] = keys
        keyset = set(keys)

        found_direct = any(
            keyset & tokens[tag].get(f, set()) for tag in EDITIONS for f in fs
        )
        near = set()
        for tag in EDITIONS:
            for key in keyset:
                for w in WORD.findall(text[tag].get(key, "")):
                    w = norm_token(w)
                    if len(w) < 3 or w in fs or not w[:1].isupper():
                        continue
                    # A proper name is a token the corpus never lowercases.
                    # This is what separates `Job` from `God` and `Lord`.
                    if w.lower() in lowercased:
                        continue
                    # Another person in the tree is a different man, not a
                    # spelling: Athaliah is not a variant of Ahaziah.
                    if w in other_names:
                        continue
                    if not any(
                        edit_distance(w, f) <= (1 if len(f) <= 5 else 2)
                        for f in fs
                    ):
                        continue
                    # Two spellings of one name do not share a verse.
                    if any(
                        tokens[t2].get(w, set()) & tokens[t2].get(f, set())
                        for t2 in EDITIONS
                        for f in fs
                    ):
                        continue
                    near.add(w)
        derived[pid] = sorted(near)
        forms[pid] = fs | near
        if not found_direct:
            unnamed.append((pid, p["name"], sorted(near)))

    # ---- 36c1, the Chinese half
    zh_missing = []
    zh_noverse = 0
    for pid, p in people.items():
        fs = zh_forms(p.get("nameZhHans"))
        if not fs:
            continue
        body = "".join(
            cuv.get(ids.get(k, ""), "") for k in set(cited[pid])
        )
        if not body:
            zh_noverse += 1
            continue
        if not any(f in body for f in fs):
            zh_missing.append((pid, p["name"], p.get("nameZhHans")))

    # ---- where each person is named, anywhere
    where = {}
    for pid, fs in forms.items():
        s = set()
        for tag in EDITIONS:
            for f in fs:
                s |= {(tag,) + k for k in tokens[tag].get(f, set())}
        where[pid] = s

    # ---- the claims
    claims = []
    for pid, p in people.items():
        if p.get("fatherId"):
            claims.append(("father", p["fatherId"], pid))
        if p.get("motherId"):
            claims.append(("mother", p["motherId"], pid))
        for s in sorted(p.get("spouseIds") or []):
            if s > pid:
                claims.append(("spouse", pid, s))

    results = []
    for kind, a, b in claims:
        A = defaultdict(set)
        for tag, bk, c, v in where[a]:
            A[(tag, bk, c)].add(v)
        B = defaultdict(set)
        for tag, bk, c, v in where[b]:
            B[(tag, bk, c)].add(v)

        best = None
        for ctx in A.keys() & B.keys():
            for va in sorted(A[ctx]):
                for vb in sorted(B[ctx]):
                    if abs(va - vb) > window:
                        continue
                    tag, bk, c = ctx
                    lo, hi = min(va, vb), max(va, vb)
                    span = " ".join(
                        text[tag].get((bk, c, v), "")
                        for v in range(lo, hi + 1)
                    )
                    if not KIN.search(span):
                        continue
                    tier = 1 if va == vb else 2
                    cand = (tier, tag, bk, c, lo, hi, span)
                    if best is None or cand[0] < best[0]:
                        best = cand
                if best and best[0] == 1:
                    break
            if best and best[0] == 1:
                break
        if best:
            _, tag, bk, c, lo, hi, span = best
            ref = f"{bk} {c}:{lo}" + (f"-{hi}" if hi != lo else "")
        else:
            tag = ref = span = None
        results.append(
            {
                "kind": kind,
                "a": a,
                "b": b,
                "aName": people[a]["name"],
                "bName": people[b]["name"],
                "tier": best[0] if best else 3,
                "edition": tag,
                "ref": ref,
                "text": span,
            }
        )

    by_tier = defaultdict(list)
    for r in results:
        by_tier[r["tier"]].append(r)

    # ------------------------------------------------------------ 36a, 36b
    struct = structural(people)
    chrono = chronology(people)

    print("=" * 72)
    print("36a — is the graph itself sound?")
    print("=" * 72)
    print(f"people: {len(people)}   parent-child edges: {struct['edges']}   "
          f"marriages: {struct['marriages']}")
    for label, rows in struct["issues"].items():
        print(f"  {label:44} {len(rows)}")
        for r in rows:
            print(f"      {r}")
    print()

    print("=" * 72)
    print("36b — do the years agree with each other and with the tree?")
    print("=" * 72)
    print(f"records with a birthYear: {chrono['withBirth']}   "
          f"with a deathYear: {chrono['withDeath']}   "
          f"with a lifespan: {chrono['withLifespan']}   "
          f"with a reign: {chrono['withReign']}")
    print(f"comparable parent-child edges: {chrono['comparable']} of "
          f"{struct['edges']}   "
          f"(skipped: {chrono['skippedReign']} accession-year records, "
          f"{chrono['skippedSystem']} mixed am/bc, "
          f"{chrono['skippedMissing']} missing a year)")
    for label, rows in chrono["issues"].items():
        print(f"  {label:44} {len(rows)}")
        for r in rows:
            print(f"      {r}")
    print()

    print("=" * 72)
    print("36c1 — is the printed name in the passages the record cites?")
    print("=" * 72)
    print(f"people: {len(people)}   named directly in their own refs: "
          f"{len(people) - len(unnamed)}   not: {len(unnamed)}")
    for pid, name, near in unnamed:
        print(f"  {name:32} refs spell it: {near or '(nothing within 2 edits)'}")
    print()

    print(f"the Chinese half, by exact containment in the CUV: "
          f"{len(people) - len(zh_missing) - zh_noverse} of "
          f"{len(people) - zh_noverse} found  "
          f"({zh_noverse} cite no verse the CUV carries)")
    for pid, name, zh in zh_missing:
        print(f"  {name:32} {zh}")
    print()

    aliased = {k: v for k, v in derived.items() if v}
    print(f"derived spelling aliases for {len(aliased)} people:")
    for pid, near in sorted(aliased.items(), key=lambda x: people[x[0]]["name"]):
        print(f"  {people[pid]['name']:32} -> {', '.join(near)}")
    print()

    print("=" * 72)
    print(f"36c2 — does a passage state the relationship?  (window ±{window})")
    print("=" * 72)
    print(f"claims examined: {len(results)}")
    print(f"  tier 1  one verse names both, with a kinship word : "
          f"{len(by_tier[1])}")
    print(f"  tier 2  same chapter, within the window          : "
          f"{len(by_tier[2])}")
    print(f"  tier 3  no passage in five editions states it    : "
          f"{len(by_tier[3])}")
    print()
    for r in sorted(by_tier[3], key=lambda x: (x["kind"], x["aName"])):
        print(f"  {r['kind']:6} {r['aName']}  ->  {r['bName']}")
    print()

    if "--json" in sys.argv:
        out = sys.argv[sys.argv.index("--json") + 1]
        with open(out, "w", encoding="utf-8") as fh:
            json.dump(
                {
                    "claims": results,
                    "unnamed": unnamed,
                    "aliases": aliased,
                },
                fh,
                ensure_ascii=False,
                indent=1,
            )
        print(f"wrote {out}")


if __name__ == "__main__":
    main()
