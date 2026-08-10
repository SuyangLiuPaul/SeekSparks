#!/usr/bin/env python3
"""Check 20 — does any edition answer a reference with a NEIGHBOURING
verse's text?

`docs/DATA-INTEGRITY.md` closes with this as the first thing on its "Not
checked yet" list:

>   Whether any book other than the ones named in check 9 carries a
>   cuvs-plus-style shift. Check 9 compares key sets, so it catches a
>   book where the *count* moves; it would not catch an edition that
>   renumbered a chapter while keeping the same total.

Every check run so far compares KEYS — which references an edition
carries, whether a Strong's number resolves, whether a count sums. A
verse whose reference exists, whose text is well-formed, and whose
neighbours are all present is invisible to all of them, and it is the
worst defect the audit has found: `assets/cuvs-plus.json` numbered all
of 1 Chronicles 22 one verse low, so a 和简+ reader's Word Study pane
showed the Hebrew of the next verse for a whole chapter. Nothing threw
and no count looked odd. That one was caught only because its book total
happened to move; a rotation that keeps the total is silent.

The method is the same one the rest of this audit uses: where two assets
describe the same fact from different directions, a disagreement is a
bug in one of them. Here the fact is "what words stand at this
reference", and the editions are the independent witnesses.

TWO PASSES, and they answer different questions.

  A. WITHIN-FAMILY, decisive. Four pairs of shipped editions carry the
     same base text (KJV and KJV+S; the three 和合本 editions; the two
     梁家鏗譯本 scripts). At the right alignment they agree almost word
     for word, so `sim(E[r], F[r]) < sim(E[r], F[r±1])` is not a hint,
     it is a contradiction. No threshold is needed.

  B. POOL CONSENSUS, screening. Editions that are genuinely different
     translations still share proper nouns, numbers and content words.
     Each edition is scored against the MEDIAN of its pool-mates at
     offsets -1, 0 and +1 in canonical order. A single verse preferring
     a neighbour is noise — short verses are interchangeable ("And God
     said", "καὶ εἶπεν"). A RUN of consecutive verses all preferring the
     same offset is what a renumbering looks like, and is what this
     reports.

Offsets step through the book's canonical reference sequence rather than
within a chapter, so a shift that crosses a chapter boundary — which is
exactly what 1 Chronicles 21/22 was — is visible.

WHAT THIS CANNOT SEE, stated rather than left implied:

  * `assets/lxxwh.json`'s Old Testament. The Septuagint has no
    same-language witness in the repo and its own arrangement differs
    from the Hebrew by design (304 references). Its New Testament IS
    covered, against `assets/originals`.
  * A shift that every edition in a pool shares. Consensus cannot
    outvote a unanimous error. Pass A narrows this for the families,
    where a shared shift would still have to survive being compared to
    the other pool.
  * A wrong verse that is not a NEIGHBOUR's verse. That is check "verse
    text against an external witness", which remains open.

Usage:
    python3 tools/audit_verse_alignment.py [--json] [--with-ev] [--verbose]

`--with-ev` adds the Eagle's View NASB derivatives as extra English
witnesses. They are licensed and MUST NOT ship; they are read here only
as a second witness to `assets/nasb.json` and never written anywhere.

Exit code is always 0. This reports; the invariants that must hold are
frozen in `test/verse_alignment_test.dart`.
"""

import json
import os
import re
import statistics
import subprocess
import sys
import unicodedata
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VERBOSE = '--verbose' in sys.argv


def asset(*parts):
    return os.path.join(ROOT, 'assets', *parts)


def load(*parts):
    with open(asset(*parts), encoding='utf-8') as f:
        return json.load(f)


# --------------------------------------------------------------------
# Placeholders. 233 references across the corpus carry a typographic
# instruction where the verse text would be (check 14). They are not
# scripture and must not be compared as though they were — a chapter
# with three 見上節 in it would otherwise look misaligned.
# --------------------------------------------------------------------

ABSENCE_MARKERS = {
    '见上节', '見上節', '合和译本并入上一节', '合和譯本並入上一節',
    '见下节', '見下節', 'OMIT',
}


def is_placeholder(text):
    t = text.strip()
    if not t:
        return True
    if t in ABSENCE_MARKERS:
        return True
    if t.startswith('<note:') and t.endswith('>'):
        return t[6:-1].strip() in ABSENCE_MARKERS
    return False


# --------------------------------------------------------------------
# The canonical reference sequence, from KJV. Offsets step through THIS,
# so a shift that crosses a chapter boundary is as visible as one inside
# a chapter.
# --------------------------------------------------------------------

def load_canon_sequence():
    seq = defaultdict(list)
    for v in load('kjv.json'):
        seq[v['book']].append((int(v['chapter']), int(v['verse'])))
    order = list(seq)
    pos = {}
    for book, refs in seq.items():
        refs.sort()
        pos[book] = {r: i for i, r in enumerate(refs)}
    return dict(seq), pos, order


CANON_SEQ, CANON_POS, BOOK_ORDER = load_canon_sequence()


# --------------------------------------------------------------------
# Book names. The Chinese editions name their books in Chinese; the
# mapping is the app's own, read out of Dart rather than restated here
# so the two cannot drift.
# --------------------------------------------------------------------

def parse_book_name_mapping():
    src = os.path.join(ROOT, 'lib', 'constants', 'book_names.dart')
    text = open(src, encoding='utf-8').read()
    start = text.index('bookNameToEnglish')
    body = text[start:text.index('};', start)]
    mapping = {}
    for zh, en in re.findall(r"'([^']+)'\s*:\s*'([^']+)'", body):
        mapping[zh] = en
    return mapping


BOOK_TO_EN = parse_book_name_mapping()


def to_english(book):
    if book in CANON_POS:
        return book
    return BOOK_TO_EN.get(book)


# --------------------------------------------------------------------
# Tokenisers. One per script, each reduced to what survives translation
# or transliteration.
# --------------------------------------------------------------------

# The commonest English function words carry no positional information —
# every verse has them — so they only dilute the coefficient.
EN_STOP = {
    'the', 'and', 'that', 'unto', 'for', 'they', 'with', 'was', 'his',
    'her', 'him', 'all', 'but', 'not', 'are', 'from', 'this', 'which',
    'you', 'your', 'will', 'shall', 'have', 'had', 'were', 'been',
    'their', 'them', 'thou', 'thee', 'thy', 'shalt', 'said', 'when',
    'then', 'there', 'into', 'upon', 'out', 'who', 'has', 'him',
}

# The three 和合本 editions carry the same translators' notes in three
# different wrappers — `<note: …>` in two, full-width （…）in cuvs-plus,
# 〔…〕 for a disputed verse — so stripping only the angle-bracket form
# compares an edition's note against its sibling's silence. That
# asymmetry, not the text, is what made 歷代志上 6:10 (a genealogy whose
# every verse reads 「X生Y」) score higher against verse 9 than against
# itself: cuvs-yhwh's note vanished and cuvs-plus's did not. Strip all
# four wrappers, in every language, so the comparison sees only what the
# editions both claim is scripture.
MARKUP = re.compile(
    r'<[^>]*>|\[[^\]]*\]|\{[^}]*\}|（[^）]*）|〔[^〕]*〕'
)
EN_WORD = re.compile(r"[a-z']+")
HAN = re.compile(r'[一-鿿㐀-䶿]')
GREEK_WORD = re.compile(r'[Ͱ-Ͽἀ-῿]+')


def strip_markup(text):
    return MARKUP.sub(' ', text)


def tokens_en(text):
    words = EN_WORD.findall(strip_markup(text).lower())
    return {w for w in words if len(w) >= 3 and w not in EN_STOP}


def tokens_zh(text):
    """Han character bigrams.

    Single characters are too common to discriminate and a word
    segmenter would be a second, unwitnessed opinion about the text.
    Bigrams are the house rule `phrase_match.dart` already uses for
    Chinese, one token per Han character, lifted one order up.
    """
    chars = HAN.findall(strip_markup(text))
    return {chars[i] + chars[i + 1] for i in range(len(chars) - 1)}


def _fold_greek(word):
    return ''.join(
        c for c in unicodedata.normalize('NFD', word.lower())
        if not unicodedata.combining(c)
    )


def tokens_el(text):
    words = GREEK_WORD.findall(strip_markup(text))
    return {t for t in (_fold_greek(w) for w in words) if len(t) >= 3}


TOKENISERS = {'en': tokens_en, 'zh': tokens_zh, 'el': tokens_el}

# Below this a verse cannot discriminate between itself and its
# neighbour, so it is excluded rather than allowed to vote.
MIN_TOKENS = 4


def dice(a, b):
    if not a or not b:
        return 0.0
    return 2 * len(a & b) / (len(a) + len(b))


# --------------------------------------------------------------------
# Editions.
# --------------------------------------------------------------------

def opencc(texts, config):
    """Convert Traditional to Simplified with opencc.

    Only ever used to make two scripts COMPARABLE. Nothing converted
    here is written to an asset — the corpus already proved (v1.6.94)
    that the two 梁家鏗譯本 scripts are independently revised, so a
    conversion is a witness to structure, never to wording.
    """
    sep = '\n'
    payload = sep.join(t.replace('\n', ' ') for t in texts)
    out = subprocess.run(
        ['opencc', '-c', config],
        input=payload, capture_output=True, text=True, check=True,
    ).stdout
    lines = out.split(sep)
    if len(lines) != len(texts):
        raise RuntimeError(
            f'opencc returned {len(lines)} lines for {len(texts)} verses')
    return lines


def load_edition(code, lang, traditional=False):
    """ref -> token set, for every reference that carries scripture."""
    try:
        data = load(f'{code}.json')
    except FileNotFoundError:
        return None
    texts, refs = [], []
    skipped_placeholder = 0
    unknown_book = 0
    for v in data:
        book = to_english(v['book'])
        if book is None:
            unknown_book += 1
            continue
        try:
            ref = (book, int(v['chapter']), int(v['verse']))
        except (TypeError, ValueError):
            continue
        if ref[1:] not in CANON_POS.get(book, {}):
            continue  # beyond canon; nothing to align it against
        text = v.get('text') or ''
        if is_placeholder(text):
            skipped_placeholder += 1
            continue
        refs.append(ref)
        texts.append(text)

    if traditional:
        texts = opencc(texts, 't2s.json')

    tok = TOKENISERS[lang]
    out = {}
    thin = 0
    for ref, text in zip(refs, texts):
        t = tok(text)
        if len(t) < MIN_TOKENS:
            thin += 1
            continue
        out[ref] = t
    if VERBOSE:
        print(f'    {code}: {len(out):,} comparable, {thin:,} too short, '
              f'{skipped_placeholder} placeholders, {unknown_book} unmapped')
    return out


def load_originals_nt():
    """The Greek New Testament out of `assets/originals`, as a witness to
    `assets/lxxwh.json`'s NT half. Both are Greek, so they are directly
    comparable; the Septuagint half of lxxwh has no such witness."""
    out = {}
    for book in BOOK_ORDER[39:]:
        slug = book.lower().replace(' ', '_')
        try:
            data = load('originals', f'{slug}.json')
        except FileNotFoundError:
            continue
        for key, words in data.items():
            try:
                c, n = (int(x) for x in key.split(':'))
            except ValueError:
                continue
            if (c, n) not in CANON_POS[book]:
                continue
            t = tokens_el(' '.join(w.get('w', '') for w in words))
            if len(t) >= MIN_TOKENS:
                out[(book, c, n)] = t
    return out


POOLS = {
    'English': ['kjv', 'kjvs', 'bsb', 'nasb', 'leb'],
    'Chinese': ['cuvs-yhwh', 'cuvs-plus', 'cuvs-yhwh-tr',
                'biblexg-v2', 'biblexg-v2-tr'],
    'Greek': ['lxxwh'],
}
POOL_LANG = {'English': 'en', 'Chinese': 'zh', 'Greek': 'el'}
TRADITIONAL = {'cuvs-yhwh-tr', 'biblexg-v2-tr'}

# Editions that carry the SAME base text, so agreement is near-total at
# the right alignment and a preference for a neighbour is a
# contradiction rather than a hint.
FAMILIES = [
    ('kjv', 'kjvs', 'KJV and KJV+S are one text, one tagged'),
    ('cuvs-yhwh', 'cuvs-plus', '和合本, two divine-name treatments'),
    ('cuvs-yhwh', 'cuvs-yhwh-tr', '和合本雅伟版, two scripts'),
    ('biblexg-v2', 'biblexg-v2-tr', '梁家鏗譯本, two scripts'),
]


# --------------------------------------------------------------------
# Pass A — within-family.
# --------------------------------------------------------------------

def pass_a(editions):
    print('PASS A — within-family, decisive\n')
    findings = []
    total_compared = 0
    for left, right, why in FAMILIES:
        a, b = editions.get(left), editions.get(right)
        if not a or not b:
            continue
        shared = 0
        disagreements = []
        for ref, ta in a.items():
            tb = b.get(ref)
            if tb is None:
                continue
            shared += 1
            d0 = dice(ta, tb)
            for k in (-1, 1):
                nb = neighbour(ref, k)
                tn = b.get(nb) if nb else None
                if tn is None:
                    continue
                dk = dice(ta, tn)
                if dk > d0:
                    disagreements.append((ref, k, round(d0, 3), round(dk, 3)))
                    break
        total_compared += shared
        print(f'  {left} vs {right} — {why}')
        print(f'    {shared:,} shared references, '
              f'{len(disagreements)} prefer a neighbour')
        for ref, k, d0, dk in disagreements[:25]:
            print(f'      {ref[0]} {ref[1]}:{ref[2]}  self={d0}  '
                  f'{"next" if k > 0 else "prev"}={dk}')
        if len(disagreements) > 25:
            print(f'      … and {len(disagreements) - 25} more')
        print()
        findings.append({
            'pair': f'{left}|{right}',
            'shared': shared,
            'disagreements': [
                {'ref': f'{r[0]} {r[1]}:{r[2]}', 'offset': k,
                 'self': d0, 'neighbour': dk}
                for r, k, d0, dk in disagreements
            ],
        })
    return findings, total_compared


def neighbour(ref, k):
    book, c, n = ref
    seq = CANON_SEQ[book]
    i = CANON_POS[book][(c, n)] + k
    if i < 0 or i >= len(seq):
        return None
    return (book, seq[i][0], seq[i][1])


# --------------------------------------------------------------------
# Pass B — pool consensus.
# --------------------------------------------------------------------

MARGIN = 0.12          # how much better a neighbour must score
MIN_NEIGHBOUR = 0.25   # and how well it must score in absolute terms
MIN_WITNESSES = 2
MIN_RUN = 2            # consecutive verses agreeing on the same offset


def pass_b(pool_name, editions, witnesses_extra=None):
    codes = [c for c in POOLS[pool_name] if editions.get(c)]
    runs = []
    # Isolated flags are noise as a *count* — 22 of them across 152,440
    # English references is the false-positive floor of a similarity
    # measure, not a finding. But an isolated flag is exactly what a
    # one-verse defect looks like, and both defects check 20 found were
    # isolated in this pass. Recorded so the list can be read; still not
    # reported as a finding.
    singles = []
    examined = 0
    for code in codes:
        mine = editions[code]
        others = [editions[o] for o in codes if o != code]
        if witnesses_extra:
            others += witnesses_extra.get(code, [])
        if len(others) < MIN_WITNESSES:
            continue
        flags = {}
        for ref, tokens in mine.items():
            scores = {}
            for k in (-1, 0, 1):
                target = ref if k == 0 else neighbour(ref, k)
                if target is None:
                    continue
                vals = [dice(tokens, o[target]) for o in others if target in o]
                if len(vals) >= MIN_WITNESSES:
                    scores[k] = statistics.median(vals)
            if 0 not in scores:
                continue
            examined += 1
            best = max((k for k in scores if k != 0),
                       key=lambda k: scores[k], default=None)
            if best is None:
                continue
            if (scores[best] - scores[0] >= MARGIN
                    and scores[best] >= MIN_NEIGHBOUR):
                flags[ref] = (best, round(scores[0], 3), round(scores[best], 3))

        for run in group_runs(flags):
            if len(run) >= MIN_RUN:
                runs.append((code, run))
            else:
                singles.append((code, run[0][1], run[0][2]))
    return runs, singles, examined


def group_runs(flags):
    """Consecutive canonical references flagged with the same offset."""
    by_book = defaultdict(list)
    for ref, info in flags.items():
        by_book[ref[0]].append((CANON_POS[ref[0]][ref[1:]], ref, info))
    out = []
    for book, items in by_book.items():
        items.sort()
        current = []
        for pos, ref, info in items:
            if (current and pos == current[-1][0] + 1
                    and info[0] == current[-1][2][0]):
                current.append((pos, ref, info))
            else:
                if current:
                    out.append(current)
                current = [(pos, ref, info)]
        if current:
            out.append(current)
    return out


def describe_runs(pool_name, runs, singletons, examined):
    print(f'PASS B — {pool_name} pool consensus\n')
    print(f'  {examined:,} references scored against '
          f'{MIN_WITNESSES}+ witnesses')
    print(f'  {len(runs)} runs of {MIN_RUN}+ consecutive verses preferring '
          f'the same neighbour')
    print(f'  {len(singletons)} isolated verses (reported as noise, not as a '
          f'finding)')
    for code, ref, info in sorted(singletons):
        print(f'      {code:14s} {ref[0]} {ref[1]}:{ref[2]}  offset '
              f'{info[0]:+d}  self={info[1]:.2f} vs {info[2]:.2f}')
    for code, run in sorted(runs, key=lambda r: -len(r[1]))[:40]:
        first, last = run[0][1], run[-1][1]
        k = run[0][2][0]
        d0 = statistics.median(i[2][1] for i in run)
        dk = statistics.median(i[2][2] for i in run)
        print(f'    {code:14s} {first[0]} {first[1]}:{first[2]}'
              f'–{last[1]}:{last[2]}  {len(run):3d} verses  '
              f'offset {k:+d}  self={d0:.2f} vs {dk:.2f}')
    print()


# --------------------------------------------------------------------
# Pass C — cross-language, on Strong's numbers.
#
# Passes A and B compare words, so they can only compare editions in the
# same language, and a shift shared by every edition of one language
# would outvote nothing. The Strong's-tagged layers remove that limit:
# a number is the same token in English, Chinese and Greek, so KJV+S,
# BSB, 和简+ and 雅简+ can all be asked the same question about the same
# reference. This is the pivot `Versification` already uses (v1.6.90) to
# align `assets/originals` against the reader's numbering.
#
# `assets/tagged/lxxwh` is the New Testament only here: its Septuagint
# half carries G-numbers for the Greek of the LXX, which are not the
# H-numbers the other layers carry for the same Old Testament verse.
# --------------------------------------------------------------------

TAGGED_LAYERS = ['kjvs', 'bsb', 'cuvs-plus', 'cuvs-yhwh', 'lxxwh']
NT_ONLY_LAYERS = {'lxxwh'}


def load_tagged(code):
    out = {}
    for book in BOOK_ORDER:
        if code in NT_ONLY_LAYERS and book not in BOOK_ORDER[39:]:
            continue
        slug = book.lower().replace(' ', '_')
        path = asset('tagged', code, f'{slug}.json')
        if not os.path.exists(path):
            continue
        with open(path, encoding='utf-8') as f:
            data = json.load(f)
        for key, words in data.items():
            try:
                c, n = (int(x) for x in key.split(':'))
            except ValueError:
                continue
            if (c, n) not in CANON_POS[book]:
                continue
            nums = set()
            for w in words:
                if w.get('s'):
                    nums.add(w['s'])
                nums.update(w.get('i') or ())
            if len(nums) >= MIN_TOKENS:
                out[(book, c, n)] = nums
    if VERBOSE:
        print(f'    tagged/{code}: {len(out):,} comparable references')
    return out


def pass_c():
    print("PASS C — cross-language, on Strong's numbers\n")
    layers = {}
    for code in TAGGED_LAYERS:
        layer = load_tagged(code)
        if layer:
            layers[code] = layer

    runs_all = []
    singletons = 0
    examined = 0
    for code, mine in layers.items():
        others = [v for k, v in layers.items() if k != code]
        flags = {}
        for ref, nums in mine.items():
            scores = {}
            for k in (-1, 0, 1):
                target = ref if k == 0 else neighbour(ref, k)
                if target is None:
                    continue
                vals = [dice(nums, o[target]) for o in others if target in o]
                if len(vals) >= MIN_WITNESSES:
                    scores[k] = statistics.median(vals)
            if 0 not in scores:
                continue
            examined += 1
            best = max((k for k in scores if k != 0),
                       key=lambda k: scores[k], default=None)
            if best is None:
                continue
            if (scores[best] - scores[0] >= MARGIN
                    and scores[best] >= MIN_NEIGHBOUR):
                flags[ref] = (best, round(scores[0], 3), round(scores[best], 3))
        for run in group_runs(flags):
            if len(run) >= MIN_RUN:
                runs_all.append((code, run))
            else:
                singletons += 1

    print(f'  {examined:,} references scored across {len(layers)} tagged '
          f'layers in three languages')
    print(f'  {len(runs_all)} runs of {MIN_RUN}+ consecutive verses '
          f'preferring the same neighbour')
    print(f'  {singletons} isolated verses')
    for code, run in sorted(runs_all, key=lambda r: -len(r[1]))[:40]:
        first, last = run[0][1], run[-1][1]
        d0 = statistics.median(i[2][1] for i in run)
        dk = statistics.median(i[2][2] for i in run)
        print(f'    {code:12s} {first[0]} {first[1]}:{first[2]}'
              f'–{last[1]}:{last[2]}  {len(run):3d} verses  '
              f'offset {run[0][2][0]:+d}  self={d0:.2f} vs {dk:.2f}')
    print()
    return {
        'examined': examined, 'runs': len(runs_all), 'singletons': singletons,
        'detail': [
            {'layer': code,
             'from': f'{r[0][1][0]} {r[0][1][1]}:{r[0][1][2]}',
             'to': f'{r[-1][1][1]}:{r[-1][1][2]}',
             'verses': len(r), 'offset': r[0][2][0]}
            for code, r in runs_all
        ],
    }


def main():
    print('Check 20 — verse alignment across editions\n')
    print('Loading editions…')
    editions = {}
    for pool, codes in POOLS.items():
        for code in codes:
            e = load_edition(code, POOL_LANG[pool], code in TRADITIONAL)
            if e:
                editions[code] = e

    extra = {}
    if '--with-ev' in sys.argv:
        for code in ('nasb-ev', 'nsn-plus'):
            e = load_edition(code, 'en')
            if e:
                editions[code] = e
        if editions.get('nasb-ev'):
            print('  (Eagle\'s View witnesses loaded — never shipped, '
                  'never written)')
    print()

    a_findings, a_compared = pass_a(editions)

    report = {'passA': a_findings, 'passB': {}}
    for pool in ('English', 'Chinese'):
        witnesses = None
        if pool == 'English' and '--with-ev' in sys.argv:
            witnesses = {'nasb': [editions[c] for c in ('nasb-ev', 'nsn-plus')
                                  if editions.get(c)]}
        runs, singles, examined = pass_b(pool, editions, witnesses)
        describe_runs(pool, runs, singles, examined)
        report['passB'][pool] = {
            'examined': examined,
            'runs': len(runs),
            'singletons': [
                {'edition': code,
                 'ref': f'{ref[0]} {ref[1]}:{ref[2]}',
                 'offset': info[0], 'self': info[1], 'neighbour': info[2]}
                for code, ref, info in sorted(singles)
            ],
            'detail': [
                {'edition': code,
                 'from': f'{r[0][1][0]} {r[0][1][1]}:{r[0][1][2]}',
                 'to': f'{r[-1][1][1]}:{r[-1][1][2]}',
                 'verses': len(r), 'offset': r[0][2][0]}
                for code, r in runs
            ],
        }

    # The Greek pool has one member, so it is scored against
    # `assets/originals` instead of against pool-mates.
    if editions.get('lxxwh'):
        print('PASS B — Greek, lxxwh New Testament vs assets/originals\n')
        originals = load_originals_nt()
        mine = {r: t for r, t in editions['lxxwh'].items()
                if r[0] in BOOK_ORDER[39:]}
        flags = {}
        scored = 0
        for ref, tokens in mine.items():
            if ref not in originals:
                continue
            scored += 1
            d0 = dice(tokens, originals[ref])
            for k in (-1, 1):
                nb = neighbour(ref, k)
                if nb is None or nb not in originals:
                    continue
                dk = dice(tokens, originals[nb])
                if dk - d0 >= MARGIN and dk >= MIN_NEIGHBOUR:
                    flags[ref] = (k, round(d0, 3), round(dk, 3))
                    break
        runs = [r for r in group_runs(flags) if len(r) >= MIN_RUN]
        print(f'  {scored:,} NT references scored')
        print(f'  {len(runs)} runs, {len(flags) - sum(len(r) for r in runs)} '
              f'isolated')
        for run in sorted(runs, key=len, reverse=True)[:20]:
            first, last = run[0][1], run[-1][1]
            print(f'    {first[0]} {first[1]}:{first[2]}–{last[1]}:{last[2]}'
                  f'  {len(run)} verses  offset {run[0][2][0]:+d}')
        print()
        report['passB']['GreekNT'] = {
            'examined': scored, 'runs': len(runs),
            'detail': [
                {'from': f'{r[0][1][0]} {r[0][1][1]}:{r[0][1][2]}',
                 'to': f'{r[-1][1][1]}:{r[-1][1][2]}',
                 'verses': len(r), 'offset': r[0][2][0]}
                for r in runs
            ],
        }

    report['passC'] = pass_c()

    if '--json' in sys.argv:
        path = os.path.join(ROOT, 'build', 'verse_alignment.json')
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(report, f, ensure_ascii=False, indent=2)
        print(f'wrote {path}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
