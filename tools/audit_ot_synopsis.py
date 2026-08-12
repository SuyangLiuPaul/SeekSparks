#!/usr/bin/env python3
r"""Are the OT Synopsis's 139 groups actually parallel? (check 35)

`assets/ot_synopsis.json` holds 139 groups of 2-4 Old Testament passages
imported from Eagle's View, and every group is a claim: *these passages
tell the same thing*. Check 25 proved the 313 references resolve to
verses that exist. It never asked whether the passages they name have
anything to do with each other, and a reference can be perfectly
well-formed and point at the wrong chapter.

The instrument is the original-language vocabulary the app already
ships. `assets/tagged/kjvs/` and `assets/tagged/cuvs-yhwh/` tag two
different translations with the same Hebrew Strong's numbers, so a
passage reduces to the multiset of Hebrew words behind it, independent
of the English or the Chinese. Two accounts of Abijah's reign share that
vocabulary; two unrelated chapters do not.

Raw overlap will not do it: every Old Testament passage shares H853,
H3605, H1961 and H559 with every other. Each number is therefore
weighted by inverse verse frequency over the whole tagged Old Testament,
and passages are compared by cosine. A shared H4428 ("king", 2,500
verses) is worth almost nothing; a shared H5818 ("Uzziah", 24) is worth
a great deal.

A score means nothing without a null. 4,000 random passage pairs are
drawn matched on the length distribution of the real pairs, from the
same books, and every declared pair is reported as a percentile of that
distribution. Anything a random pair could have produced is flagged for
reading, not repaired: this tool decides what to look at, and a human
decides what is wrong.

The titles are a second claim, and a cheaper one to test. A group's
title names the passage it points at, so the passage is the witness for
the title: `Jepheth's Descendants` over 1 Chronicles 1:5-7, where the
text reads *Japheth*, is wrong on the evidence the asset itself carries.
Both titles are checked this way, the English against `assets/kjvs.json`
and the Chinese against `assets/cuvs-yhwh.json`, and nothing outside the
repo is consulted.

Usage:
    python3 tools/audit_ot_synopsis.py            # summary + flags
    python3 tools/audit_ot_synopsis.py --all      # every group
    python3 tools/audit_ot_synopsis.py --titles   # titles only, no null
"""
from __future__ import annotations
import argparse, json, math, random, re, sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SYNOPSIS = ROOT / 'assets' / 'ot_synopsis.json'

# The layers that tag an English and a Chinese translation with the same
# Hebrew numbers. Two independent alignments of the same originals, so a
# pair judged dissimilar by both is dissimilar in the Hebrew and not in
# one translator's word choice.
LAYERS = ('kjvs', 'cuvs-yhwh')

OT_BOOKS = [
    'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy', 'Joshua',
    'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
    '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther', 'Job',
    'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Solomon', 'Isaiah',
    'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel',
    'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk',
    'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
]


def slug(book: str) -> str:
    return book.lower().replace(' ', '_')


def load_runs(name: str) -> dict[tuple[str, int, int], list[dict]]:
    """(book, chapter, verse) -> the tagged runs, words and numbers both."""
    out: dict[tuple[str, int, int], list[dict]] = {}
    for book in OT_BOOKS:
        path = ROOT / 'assets' / 'tagged' / name / f'{slug(book)}.json'
        if not path.exists():
            continue
        for ref, runs in json.loads(path.read_text(encoding='utf-8')).items():
            c, _, v = ref.partition(':')
            if c.isdigit() and v.isdigit():
                out[(book, int(c), int(v))] = runs
    return out


def load_layer(name: str) -> dict[tuple[str, int, int], list[str]]:
    """(book, chapter, verse) -> the Strong's numbers tagged on it."""
    out: dict[tuple[str, int, int], list[str]] = {}
    for book in OT_BOOKS:
        path = ROOT / 'assets' / 'tagged' / name / f'{slug(book)}.json'
        if not path.exists():
            continue
        for ref, runs in json.loads(path.read_text(encoding='utf-8')).items():
            c, _, v = ref.partition(':')
            if not c.isdigit() or not v.isdigit():
                continue
            nums = [r['s'] for r in runs if r.get('s')]
            # `i` holds numbers merged into a neighbouring run; they are
            # words of the original too and belong in the vocabulary.
            for r in runs:
                nums.extend(r.get('i') or [])
            out[(book, int(c), int(v))] = nums
    return out


def load_text() -> dict[tuple[str, int, int], str]:
    """The KJV+S verse text, for reading a flagged group by eye."""
    out = {}
    for rec in json.loads((ROOT / 'assets' / 'kjvs.json').read_text('utf-8')):
        try:
            out[(rec['book'], int(rec['chapter']), int(rec['verse']))] = rec['text']
        except (KeyError, ValueError, TypeError):
            continue
    return out


def verses_of(ref: dict, chapter_len: dict[tuple[str, int], int]) -> list[tuple[str, int, int]]:
    """Expand a reference, including one that crosses a chapter."""
    book = ref['book']
    c0, c1 = ref['chapter'], ref.get('endChapter', ref['chapter'])
    out = []
    for c in range(c0, c1 + 1):
        first = ref['start'] if c == c0 else 1
        last = ref['end'] if c == c1 else chapter_len.get((book, c), 0)
        for v in range(first, last + 1):
            out.append((book, c, v))
    return out


def idf_of(layer: dict) -> dict[str, float]:
    n = len(layer)
    df = Counter()
    for nums in layer.values():
        df.update(set(nums))
    return {s: math.log(n / d) for s, d in df.items()}


def vector(verses, layer, idf) -> dict[str, float]:
    tf = Counter()
    for key in verses:
        tf.update(layer.get(key, ()))
    return {s: (1 + math.log(c)) * idf.get(s, 0.0) for s, c in tf.items()}


def cosine(a: dict, b: dict) -> float:
    if not a or not b:
        return 0.0
    small, large = (a, b) if len(a) < len(b) else (b, a)
    dot = sum(w * large.get(s, 0.0) for s, w in small.items())
    na = math.sqrt(sum(w * w for w in a.values()))
    nb = math.sqrt(sum(w * w for w in b.values()))
    return dot / (na * nb) if na and nb else 0.0


def null_distribution(layer, idf, lengths, chapters, trials=4000, seed=11):
    """Random contiguous passages of the same lengths, from the same books."""
    rng = random.Random(seed)
    keys = sorted(chapters)
    scores = []
    for _ in range(trials):
        picks = []
        for n in rng.sample(lengths, 2) if len(lengths) > 1 else (lengths * 2):
            for _attempt in range(40):
                book, c = keys[rng.randrange(len(keys))]
                last = chapters[(book, c)]
                if last >= n:
                    start = rng.randint(1, last - n + 1)
                    picks.append([(book, c, v) for v in range(start, start + n)])
                    break
            else:
                picks.append([keys[0] + (1,)])
        if picks[0][0][0] == picks[1][0][0] and picks[0][0][1] == picks[1][0][1]:
            continue  # same chapter is not a random pair
        scores.append(cosine(vector(picks[0], layer, idf),
                             vector(picks[1], layer, idf)))
    scores.sort()
    return scores


def percentile_of(scores: list[float], value: float) -> float:
    lo, hi = 0, len(scores)
    while lo < hi:
        mid = (lo + hi) // 2
        if scores[mid] < value:
            lo = mid + 1
        else:
            hi = mid
    return 100.0 * lo / len(scores)


def fmt(ref: dict) -> str:
    if 'endChapter' in ref:
        return f"{ref['book']} {ref['chapter']}:{ref['start']}-{ref['endChapter']}:{ref['end']}"
    return f"{ref['book']} {ref['chapter']}:{ref['start']}-{ref['end']}"


# --- the titles, witnessed by the passages they point at ----------------

DICT = Path('/usr/share/dict/words')

# Words a title may legitimately use that no passage contains, because
# they name the book rather than anything inside it.
BOOK_WORDS = {
    'genesis', 'exodus', 'leviticus', 'numbers', 'deuteronomy', 'joshua',
    'judges', 'ruth', 'samuel', 'kings', 'chronicles', 'ezra', 'nehemiah',
    'esther', 'job', 'psalm', 'psalms', 'proverbs', 'ecclesiastes',
    'isaiah', 'jeremiah', 'lamentations', 'ezekiel', 'daniel', 'hosea',
    'joel', 'amos', 'obadiah', 'jonah', 'micah', 'nahum', 'habakkuk',
    'zephaniah', 'haggai', 'zechariah', 'malachi', 'testament', 'synopsis',
}

PREPOSITIONS = {'in', 'at', 'on', 'of', 'to', 'from', 'after', 'before',
                'during', 'and', 'over', 'under', 'with'}


def levenshtein(a: str, b: str, cap: int = 3) -> int:
    if abs(len(a) - len(b)) > cap:
        return cap + 1
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1,
                           prev[j - 1] + (ca != cb)))
        if min(cur) > cap:
            return cap + 1
        prev = cur
    return prev[-1]


def load_zh() -> dict[tuple[str, int, int], str]:
    """The CUV+S verse text, keyed like the English by (book, c, v).

    The Chinese asset labels books in Chinese, so the join is on the
    numeric `id` (BBBCCCVVV) instead: the Old Testament is books 1-39 in
    the order of OT_BOOKS.
    """
    by_num = {f'{i:03d}': b for i, b in enumerate(OT_BOOKS, 1)}
    out = {}
    for rec in json.loads((ROOT / 'assets' / 'cuvs-yhwh.json').read_text('utf-8')):
        book = by_num.get(str(rec.get('id', ''))[:3])
        if not book:
            continue
        try:
            out[(book, int(rec['chapter']), int(rec['verse']))] = rec['text']
        except (KeyError, ValueError, TypeError):
            continue
    return out


def known_word(word: str, words: set[str]) -> bool:
    """/usr/share/dict/words holds base forms only, so inflect back to one."""
    w = word.lower()
    if w in words:
        return True
    for suffix, stems in (('ies', ('y',)), ('es', ('', 'e')), ('s', ('',)),
                          ('ed', ('', 'e')), ('ing', ('', 'e')),
                          ('ly', ('',)), ('er', ('', 'e')), ('est', ('', 'e'))):
        if w.endswith(suffix):
            root = w[:-len(suffix)]
            if any(root + s in words for s in stems):
                return True
    return False


def title_findings(groups, chapters, text, zh_text,
                   runs_en, runs_zh) -> list[tuple[int, str, str]]:
    """(group id, kind, message) for every title the passage contradicts."""
    words = set()
    if DICT.exists():
        words = {w.strip().lower() for w in DICT.read_text('utf-8', 'ignore').splitlines()}

    found = []
    exercised = Counter()
    for g in groups:
        verses = [v for r in g['refs'] for v in verses_of(r, chapters)]
        en_body = ' '.join(text.get(v, '') for v in verses)
        zh_body = ''.join(zh_text.get(v, '') for v in verses)

        # Every capitalised word of the passage is a candidate spelling.
        # Sentence-initial noise ('And', 'The') is harmless: a title word
        # only matches one if it is already absent AND within two edits.
        names = {w for w in re.findall(r"[A-Z][a-z']{2,}", en_body)}
        lower_body = en_body.lower()

        toks = re.findall(r"[A-Za-z][A-Za-z']*", g['en'])
        for tok in toks:
            base = tok[:-2] if tok.lower().endswith("'s") else tok
            if len(base) < 4 or not base[0].isupper():
                continue
            if base.lower() in BOOK_WORDS or base.lower() in lower_body:
                continue
            near = sorted(
                ((levenshtein(base, n), n) for n in names if n.lower() != base.lower()),
                key=lambda p: (p[0], p[1]))
            near = [(d, n) for d, n in near if d <= 2]
            if known_word(base, words):
                continue
            if near:
                d, n = near[0]
                found.append((g['id'], 'name',
                              f"title says {base!r}, passage says {n!r} ({d} edit"
                              f"{'s' if d > 1 else ''})"))
            else:
                found.append((g['id'], 'spelling',
                              f"title word {base!r} is not an English word and "
                              'names nothing in the passage'))

        # A possessive with no noun after it is a stray apostrophe.
        for i, tok in enumerate(toks[:-1]):
            if tok.lower().endswith("'s") and toks[i + 1].lower() in PREPOSITIONS:
                found.append((g['id'], 'apostrophe',
                              f"{tok!r} is possessive but is followed by "
                              f"{toks[i + 1]!r}"))

        # The Chinese half cannot be done this way: Chinese has no spaces
        # to segment a name on, and every 2-gram of a title differs by
        # one character from something in a long passage, so the same
        # test returns 334 findings of which none is an error. The
        # Strong's numbers are the way across. A name the English title
        # gets right resolves, in the group's own verses, to a Hebrew
        # number; the same number in the Chinese layer over the same
        # verses gives the CUV's spelling of that name; and the Chinese
        # title is then asked for that exact string. Only a title that
        # spells a name the passage spells differently can fail.
        zh_title = g.get('zh', '')
        if not zh_title or not zh_body:
            continue
        for tok in toks:
            base = tok[:-2] if tok.lower().endswith("'s") else tok
            if len(base) < 4 or not base[0].isupper() or base.lower() in BOOK_WORDS:
                continue
            if known_word(base, words) or base not in names:
                continue
            nums = {r['s'] for v in verses for r in runs_en.get(v, ())
                    if r.get('s') and base.lower() in r.get('w', '').lower()}
            forms = {r['w'].strip() for v in verses for r in runs_zh.get(v, ())
                     if r.get('s') in nums and r.get('w')}
            forms = {f for f in forms
                     if 2 <= len(f) <= 5 and re.fullmatch(r'[一-鿿]+', f)}
            if not forms:
                continue
            exercised['names'] += 1
            if any(f in zh_title for f in forms):
                exercised['agree'] += 1
                continue
            near = {f for f in forms
                    for i in range(len(zh_title) - len(f) + 1)
                    if sum(a != b for a, b in zip(f, zh_title[i:i + len(f)])) == 1}
            if near:
                found.append((g['id'], 'zh',
                              f"{base} is {'/'.join(sorted(near))} in the "
                              f"passage, not what the title spells"))
    return found, exercised


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--all', action='store_true', help='print every group')
    ap.add_argument('--titles', action='store_true',
                    help='run only the title checks (skips the null)')
    ap.add_argument('--flag-below', type=float, default=98.0,
                    help='percentile of the null below which a pair is flagged')
    args = ap.parse_args()

    data = json.loads(SYNOPSIS.read_text(encoding='utf-8'))
    groups = data['groups']

    layers = {name: load_layer(name) for name in LAYERS}
    chapters: dict[tuple[str, int], int] = {}
    for book, c, v in layers[LAYERS[0]]:
        key = (book, c)
        chapters[key] = max(chapters.get(key, 0), v)

    print(f'groups     {len(groups)}')
    print(f'passages   {sum(len(g["refs"]) for g in groups)}')
    for name in LAYERS:
        print(f'layer      {name}: {len(layers[name]):,} OT verses tagged')

    # ---- structural claims, which are certain either way ----------------
    print('\n--- structure ---')
    problems = []
    seen_passage: dict[str, list[int]] = defaultdict(list)
    for g in groups:
        if not g.get('zh'):
            problems.append(f'group {g["id"]}: no Chinese title')
        if not g.get('en'):
            problems.append(f'group {g["id"]}: no English title')
        spans = [verses_of(r, chapters) for r in g['refs']]
        for i, r in enumerate(g['refs']):
            seen_passage[fmt(r)].append(g['id'])
            if not spans[i]:
                problems.append(f'group {g["id"]}: {fmt(r)} expands to no verses')
        for i in range(len(spans)):
            for j in range(i + 1, len(spans)):
                shared = set(spans[i]) & set(spans[j])
                if shared:
                    problems.append(
                        f'group {g["id"]}: {fmt(g["refs"][i])} and '
                        f'{fmt(g["refs"][j])} overlap in {len(shared)} verses')
    dupes = {p: ids for p, ids in seen_passage.items() if len(ids) > 1}
    for p, ids in sorted(dupes.items()):
        problems.append(f'passage {p} appears in groups {ids}')
    for line in problems:
        print(' ', line)
    if not problems:
        print('  0 structural problems')

    # ---- the titles, against the passages they point at -----------------
    print('\n--- titles ---')
    by_id = {g['id']: g for g in groups}
    findings, exercised = title_findings(
        groups, chapters, load_text(), load_zh(),
        load_runs('kjvs'), load_runs('cuvs-yhwh'))
    for gid, kind, msg in findings:
        print(f'  [{gid:>3}] {kind:<10} {msg}')
        print(f'        en {by_id[gid]["en"]!r}  zh {by_id[gid].get("zh","")!r}')
    if not findings:
        print('  0 title problems')
    print(f'  {len(findings)} findings over {len(groups)} groups')
    # A check that finds nothing has to say how hard it looked.
    print(f'  zh: {exercised["names"]} title names carried through to a CUV '
          f'spelling, {exercised["agree"]} of which the Chinese title uses')
    if args.titles:
        return 0

    # ---- vocabulary, per layer, against a null --------------------------
    lengths = []
    for g in groups:
        for r in g['refs']:
            lengths.append(max(1, len(verses_of(r, chapters))))

    results = defaultdict(dict)
    nulls = {}
    for name in LAYERS:
        layer = layers[name]
        idf = idf_of(layer)
        nulls[name] = null_distribution(layer, idf, lengths, chapters)
        for g in groups:
            vecs = [vector(verses_of(r, chapters), layer, idf) for r in g['refs']]
            # NOT the worst pair. A group of four can hold two passages
            # that are legitimately unlike each other and still be one
            # subject — David's sons born in Hebron and his sons born in
            # Jerusalem are disjoint name lists, and the group is right.
            # What cannot happen is a passage that resembles NOTHING
            # else in its group, so each passage is scored by its best
            # match and the group by its loneliest passage.
            best = []
            for i in range(len(vecs)):
                best.append(max(
                    (cosine(vecs[i], vecs[j]) for j in range(len(vecs)) if j != i),
                    default=0.0))
            lonely = min(range(len(best)), key=lambda i: best[i])
            results[g['id']][name] = (best[lonely], lonely)

    for name in LAYERS:
        s = nulls[name]
        print(f'\nnull {name}: n={len(s)} '
              f'median {s[len(s)//2]:.3f} '
              f'p90 {s[int(len(s)*.90)]:.3f} '
              f'p98 {s[int(len(s)*.98)]:.3f} '
              f'p99.5 {s[int(len(s)*.995)]:.3f} max {s[-1]:.3f}')

    rows = []
    for g in groups:
        pcts = {n: percentile_of(nulls[n], results[g['id']][n][0]) for n in LAYERS}
        rows.append((min(pcts.values()), g, pcts))
    rows.sort(key=lambda r: r[0])

    flagged = [r for r in rows if r[0] < args.flag_below]
    print(f'\n--- {len(flagged)} of {len(groups)} groups flagged '
          f'(below the {args.flag_below:g}th percentile in either layer) ---')
    shown = rows if args.all else flagged
    text = load_text() if flagged else {}
    for _, g, pcts in shown:
        cols = '  '.join(
            f'{n}={results[g["id"]][n][0]:.3f}/p{pcts[n]:.1f}' for n in LAYERS)
        print(f'\n[{g["id"]:>3}] {g["en"]}  ({g.get("zh","")})')
        print(f'      {cols}')
        lonely = {n: results[g['id']][n][1] for n in LAYERS}
        for i, r in enumerate(g['refs']):
            vs = verses_of(r, chapters)
            mark = ' <- loneliest' if i in lonely.values() else ''
            print(f'      {fmt(r):<34} {len(vs):>3} vv{mark}')
        if not args.all and text:
            for r in g['refs']:
                vs = verses_of(r, chapters)
                if vs:
                    first = text.get(vs[0], '')
                    print(f'        {fmt(r)}: {first[:110]}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
