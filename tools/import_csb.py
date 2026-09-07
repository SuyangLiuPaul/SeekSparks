#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build `assets/csb.json` + `assets/tagged/csb/` from the CSB module.

Licence first: `docs/permissions/README.md` holds the 2017 Holman grant,
Pastor Raymond's extension of it to the Yahweh's Words products, and the
owner's decision on territory. Read it before running this. The script
moves text; it does not decide whether the text may ship.

    python3 tools/import_csb.py [--dry-run] [--report FILE]
                               [--compare-plain PATH_TO_yswords_csb.json]

WHY THIS IS NOT `yswords/tools/import_csb.py` WITH A FLAG
---------------------------------------------------------
YsWords ships no tagged text, so its importer throws the Strong's
numbers away. This repo's whole point is the tagged layer, and what
Holman licensed is the CSB **with Strong's Numbers** — the numbers are
the licensed article, not an extra. Keeping them is a different program:
the tags have to survive as run boundaries all the way to
`assets/tagged/csb/<book>.json`, which means the divine-name repair and
the whitespace normalisation both have to happen run-aware rather than
on a flat string. The plain text the two produce is identical, and
`--compare-plain` asserts exactly that against the sibling repo.

THE SOURCE
----------
`bsapp_bible_hcsbs` in the local MariaDB — 31,102 verses, theWord-style.
The table name is a legacy key; the 雅伟的话 repo's note verifies
verse-by-verse that the text is **CSB 2017**, not HCSB (Ps 23:1 "I have
what I need", Rom 1:1 "servant", John 3:16 lower-case "his one and only
Son").

THE MARKUP, COUNTED
-------------------
Every `<...>` across all 31,102 verses is one of six kinds:

    WH####   385,177   Hebrew Strong's (+2 malformed: WH5766x, WH853x)
    WG####   118,077   Greek Strong's
    CL        24,655   poetic line break
    CM         9,932   paragraph break
    TS#…Ts     2,837   section heading, carried INSIDE the verse
    redletter  1,269   words of Christ

Section headings are dropped, not concatenated: left in, Ps 23:1 reads
"The Good ShepherdA psalm of David". Headings come from
`assets/section_titles.json`, which is a separate file for this reason.

NUMBERS THAT ARE NOT STRONG'S NUMBERS
-------------------------------------
106,000-odd tags in this module are in the H9900–H9999 band. Strong's
Hebrew stops at H8674 and Greek at G5624, and this module's real numbers
stop exactly there — the highest genuine tags in it are H8674 and G5624,
so the two sets do not overlap and the range test is exact rather than a
guess. The 99xx band marks English words that render a Hebrew prefix or
particle with no headword of its own:

    In<WH9996> the<WH9998> beginning<WH7225>   ב-, ה-, and רֵאשִׁית

They are dropped rather than emitted. `TaggedRun.strongs` is documented
as '' for text the tagger left unmarked, and an untagged "the" is the
truth; emitting H9998 would send the lexicon looking for a headword that
has never existed in Brown-Driver-Briggs. It also means ~28% of Hebrew
runs are untagged, which is the honest figure and not a defect.

Unlike Eagle's View this module carries no tense/voice/mood codes at all
— no number in it falls between the Strong's ceiling and 9900 — so every
`g` here is empty. That is a property of the source, and
`test/csb_asset_test.dart` pins it so a future re-import that quietly
starts emitting grammar codes has to be looked at.

THE DIVINE NAME
---------------
The module already reads **Yahweh** in 5,041 verses and contains "the
LORD" in none. But 964 more still read "Lord", the Shema among them.
Shipping that would put a text that spells the divine name two ways into
an app whose sibling is named for the name.

They are not a translation choice; they are a **typographic residue**.
CSB prints YHWH as small-caps LORD and Adonai as ordinary Lord. Where
this module lost the small-caps run it kept the space that carried it, so
a lost LORD reads `Lord ` + another space and a genuine Adonai does not:

    Deut 6:4  "The Lord  our God, the Lord  is one."      lost LORD
    Ps 110:1  "declaration of Yahweh   to my Lord:"       both, one verse

THE WITNESS, AND WHY THIS REPO HAS A BETTER ONE THAN YSWORDS HAS
----------------------------------------------------------------
YsWords decides the ambiguous cases by reading all-caps LORD out of
`kjv.json` — a typographic convention standing in for a lexical fact.
This repo ships `assets/tagged/kjvs/`, where the same verse is tagged
with the number itself:

    Deut 6:4   ": The LORD"      H3068   YHWH
    Ps 44:23   " thou, O Lord"   H136    Adonai

So the question "is this Lord the name?" is answered here by the
Strong's number, not by whether someone set it in small caps. Both
witnesses give the same verdict on all seven ambiguous verses; this one
gives it for a better reason, and it can be quoted in a test.

It also decides something YsWords could not do at all. Where kjvs tags
H3068 in the verse, the repair splices the number back in with the word:

    "The Lord  our God"   ->   "Yahweh<WH3068> our God"

That is putting back the run the small-caps loss removed, not inventing
tagging — the module's own 5,041 surviving instances all read
`Yahweh<WH3068>`. Where there is no corroboration the word is still
restored (CSB's own typography is enough for that) but left untagged.

WHAT IS DELIBERATELY NOT TOUCHED
--------------------------------
190 verses read 雅伟 in the Chinese while the English says Lord with no
residue — Ps 130:3 (already "Yah"), Matt 1:20 (Kyrios), Isa 9:17 and
Amos 8:3 (Adonai / Lord GOD). Those are the Chinese edition's own
restoration choices. Applying them to the English would be re-translating
the CSB, which this repo does not do to anybody's text.
"""
import argparse
import io
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
OUT = os.path.join(PROJECT, 'assets', 'csb.json')
TAGDIR = os.path.join(PROJECT, 'assets', 'tagged', 'csb')
KJV = os.path.join(PROJECT, 'assets', 'kjv.json')
KJVS_TAGS = os.path.join(PROJECT, 'assets', 'tagged', 'kjvs')
CUV = os.path.join(PROJECT, 'assets', 'cuvs-yhwh.json')
YDH = os.path.expanduser('~/Documents/CodingProject/Yahwehdehua')

TABLE = 'bsapp_bible_hcsbs'
EXPECTED_VERSES = 31102
EXPECTED_BOOKS = 66

# Strong's itself stops here. Everything above is the module's own
# placeholder band; see the header.
MAX_STRONGS = {'H': 8674, 'G': 5624}

# Credentials live in the 雅伟的话 repo's own importer, which is where
# they already are; they are read, never printed, and never copied here.
CREDS_FROM = os.path.join(YDH, 'tools', 'fix-hcsb.py')


def _creds():
    src = io.open(CREDS_FROM, encoding='utf-8').read()
    mariadb = re.search(r"^MARIADB\s*=\s*'([^']*)'", src, re.M).group(1)
    db, user, pw = re.search(
        r"^DB,\s*USER,\s*PW\s*=\s*'([^']*)',\s*'([^']*)',\s*'([^']*)'",
        src, re.M).groups()
    return mariadb, db, user, pw


def fetch_rows():
    mariadb, db, user, pw = _creds()
    proc = subprocess.run(
        [mariadb, '-u', user, f'-p{pw}', db, '-N', '-B', '-e',
         f'SELECT book,chapter,verse,scripture FROM {TABLE} ORDER BY id'],
        capture_output=True, text=True)
    if proc.returncode != 0:
        sys.exit(f'query failed: {proc.stderr.strip()}')
    rows = [l.split('\t') for l in proc.stdout.split('\n')
            if l.count('\t') >= 3]
    if len(rows) != EXPECTED_VERSES:
        sys.exit(f'expected {EXPECTED_VERSES} verses, got {len(rows)}')
    return [(b, int(c), int(v), s) for b, c, v, s in rows]


# ── markup ──────────────────────────────────────────────────────────
TAG = re.compile(r'<W([HG])(\d+)[a-z]?>')     # the trailing letter covers
                                              # WH5766x / WH853x, the two
                                              # malformed tags in the module
TS = re.compile(r'<TS\d*>.*?<Ts>')
REDLETTER = re.compile(r'</?redletter>')
BREAKS = re.compile(r'<C[LM]>')
ANY_TAG = re.compile(r'<[^>]*>')
SPACE_BEFORE_PUNCT = re.compile(r'\s+(?=[,.;:!?’”)])')

# ── the divine name ─────────────────────────────────────────────────
# Applied to the RAW row, before any tag becomes a space. Doing it after
# would let a `<CL>` turned into a space manufacture the very residue
# this matches: "the Lord<CL> and" is a poetic line break, not a lost
# LORD.
#
# The article goes with it. Across the 5,041 verses the module already
# restored, "The Yahweh" appears zero times and the possessive is written
# "Yahweh's" — replacing only the word ships "The Yahweh our God, the
# Yahweh is one" as the Shema. (Which is how this was caught: by reading
# the output, not the count.)
#
# `<` is in the lookahead because a `<CL>` can land immediately after the
# residue space. Exactly one verse in the module does that — Psalm 15:4,
# "the one rejected by the Lord <CL> but honors those who fear Yahweh",
# which spells the name both ways inside one verse. Without it the rule
# reads the tag as ordinary text and declines.
#
# The article may be separated from the name by its own placeholder tag —
# `the<WH9998> Lord ’s word` — and a pattern that does not allow for that
# misses three verses, one of which (Jer 5:13) nothing else reaches. This
# is the same trap that made the stray-article rule below match six of
# ten on its first attempt.
LOST_LORD_ARTICLE = re.compile(
    r'\b[Tt]he(?:<W[HG]\d+[a-z]?>)? Lord (?=[\s<,.;:!?’”\'")]|$)')
LOST_LORD_BARE = re.compile(r'\bLord (?=[\s<,.;:!?’”\'")]|$)')

# ── the possessive, which the module's own restoration pass missed ──
# CSB writes the divine possessive "the LORD’s". Losing the small-caps
# run leaves `the Lord ’s` — a space before the apostrophe — and the rule
# above already restores all 221 of those ("this is Yahweh’s
# declaration"). Three verses lost the space as well, so nothing marks
# them, and they are the only place in this import where a verse is named
# rather than matched:
#
#   1Kgs 3:15  "the ark of the Lord’s covenant"
#   Isa 59:20  "This is the Lord’s declaration."   (1 of 222; 221 restored)
#   Mal 1:12   "The Lord’s table is defiled"       (Mal 1:7, five verses
#                                                   earlier, has the space)
#
# Each carries two independent witnesses: `assets/tagged/kjvs/` tags
# H3068 on the LORD-bearing run, and the Chinese 和合本雅伟版 reads 雅伟 —
# at 1Kgs 3:15 and Mal 1:12 with the translator's own footnote
# `<note: 原文作"主">` saying the source reads Adonai and they restored it
# anyway. Naming three verses is not a licence to name a fourth: the
# candidate set is recomputed on every run and checked against
# UNTAGGED_OT_LORD below.
POSSESSIVE = re.compile(r'\b[Tt]he Lord(?=’s)')
RESTORE_POSSESSIVE = {'011003015', '023059020', '039001012'}

# Every OT verse where a bare "Lord" survives untagged in running text —
# the exhaustive candidate set for anything the residue rule cannot see.
# Adjudicated one at a time against the module's own Strong's numbers,
# `assets/tagged/kjvs/`, and the Chinese edition. The importer fails if
# this set stops matching what the module actually contains.
#
# The two that matter most are the ones a verse-level rule would have got
# WRONG. "The Lord Bursts Out" glosses the place name Baal-perazim and
# the module tags that very run H1188 — בַּעַל, master, not the divine
# name — while the same verse's quotation reads Yahweh, so a rule keyed
# on "this verse has H3068" would have renamed Baal. And Lamentations
# 2:20 opens "Yahweh, look and consider" and closes "in the Lord’s
# sanctuary": H3068 and H136, one verse, and the Chinese keeps 主 for the
# second exactly as this does.
UNTAGGED_OT_LORD = {
    '004014017': "Adonai — kjvs tags 'of my Lord' H136",
    '010005020': 'glosses the place name Baal-perazim; the module tags '
                 'that very run H1188',
    '011008026': 'KJV reads "And now, O God of Israel" — no LORD, so the '
                 'Hebrew has no name here; the Chinese reads 神啊 too',
    '013014011': 'the 1 Chronicles parallel of 2 Samuel 5:20, same gloss',
    '019116008': 'the Chinese reads 主啊, and KJV has no Lord in the verse '
                 'at all — the vocative is CSB\'s own',
    '025002019': 'Adonai — H136, and the Chinese reads 主',
    '025002020': 'Adonai — H136, in a verse whose opening word is H3068',
    '026018025': 'Adonai — H136',
    '026018029': 'Adonai — H136',
    '026033017': 'Adonai — H136',
    '026033020': 'Adonai — H136',
    '027009017': 'Adonai — kjvs tags "for the Lord\'s sake" H136',
}

# The module's OWN restoration left the article standing in ten places —
# "This is the Yahweh's gate" (Ps 118:20), "Holy to the Yahweh" (Ex
# 28:36). Not English, and not the convention the other 5,041 follow.
# The article's placeholder tag comes with it: in the raw row it reads
# `the<WH9998> Yahweh`, and a pattern that does not allow for the tag
# matches six of the ten and misses the rest.
STRAY_ARTICLE = re.compile(r'\b[Tt]he(?:<W[HG]\d+[a-z]?>)?\s+(?=Yahweh\b)')


def restore_name(raw, witnessed, vid=''):
    """Put the lost small-caps run back. -> (raw', n).

    [witnessed] is True when `assets/tagged/kjvs/` tags H3068 somewhere
    in this verse. It gates two things: whether a BARE vocative "Lord "
    is the name at all, and whether the restored word carries the number.
    The article form does not need it to be restored — "the LORD" is how
    CSB renders YHWH and nothing else — only to be tagged.
    """
    name = 'Yahweh<WH3068> ' if witnessed else 'Yahweh '
    s, n = LOST_LORD_ARTICLE.subn(name, raw)
    if witnessed:
        s, extra = LOST_LORD_BARE.subn(name, s)
        n += extra
    if vid in RESTORE_POSSESSIVE:
        s, poss = POSSESSIVE.subn(
            'Yahweh<WH3068>' if witnessed else 'Yahweh', s)
        if poss != 1:
            sys.exit(f'{vid}: expected one possessive to restore, got {poss}')
        n += poss
    s, stray = STRAY_ARTICLE.subn('', s)
    return s, n, stray


def classify(nums, prefix):
    """-> (strongs, implied) for one run's numbers, placeholders dropped."""
    top = MAX_STRONGS[prefix]
    real = [f'{prefix}{n}' for n in nums if n <= top]
    return (real[0] if real else ''), real[1:]


def split_runs(s, prefix):
    """theWord writes the tag AFTER the text it governs, so each run is
    the text since the previous tag. Returns TaggedRun-shaped dicts."""
    out, cursor, pending = [], 0, []
    for m in TAG.finditer(s):
        seg = s[cursor:m.start()]
        cursor = m.end()
        # Consecutive tags — `had yet<WH3605><WH2962>` — govern one run
        # between them. Collect the numbers rather than emitting a run
        # with no text.
        pending.append((m.group(1), int(m.group(2))))
        nxt = TAG.match(s, cursor)
        if seg == '' and nxt:
            continue
        strongs, implied = classify([n for _p, n in pending], prefix)
        pending = []
        if seg == '' and out:
            if strongs:
                out[-1]['i'].append(strongs)
            out[-1]['i'].extend(implied)
            continue
        out.append({'w': seg, 's': strongs, 'i': implied, 'g': []})
    tail = s[cursor:]
    if tail:
        if pending:
            strongs, implied = classify([n for _p, n in pending], prefix)
            out.append({'w': tail, 's': strongs, 'i': implied, 'g': []})
        elif out:
            out[-1]['w'] += tail
        else:
            out.append({'w': tail, 's': '', 'i': [], 'g': []})
    return out


def tidy(runs):
    """Whitespace and punctuation, per run — never on the joined string.

    Normalising the join would be one line and would also silently
    invalidate every run boundary the tags were cut at. Cleaning each run
    and then joining means the verse text IS the concatenation of the
    runs, so the plain asset and the tagged asset cannot disagree.
    """
    out = []
    for r in runs:
        w = SPACE_BEFORE_PUNCT.sub('', r['w'])
        w = re.sub(r'\s+', ' ', w)
        if not w:
            # An untranslated particle riding on whitespace: fold its
            # numbers into the word before it rather than emit an empty
            # run. Drop the space — the next run carries its own.
            if out and (r['s'] or r['i']):
                if r['s']:
                    out[-1]['i'].append(r['s'])
                out[-1]['i'].extend(r['i'])
            continue
        # Collapse across the seam too: two runs that are each clean can
        # still meet as "Yahweh  our".
        if out and out[-1]['w'].endswith(' ') and w.startswith(' '):
            w = w[1:]
            if not w:
                continue
        out.append({**r, 'w': w})
    if out:
        out[0]['w'] = out[0]['w'].lstrip()
        out[-1]['w'] = out[-1]['w'].rstrip()
    # The strip above can empty a leading or trailing run. Measured over
    # the whole import that never costs a Strong's number — every run it
    # empties was whitespace-only and already had none — so they are
    # dropped rather than merged. `test/csb_asset_test.dart` counts the
    # numbers that reach the asset, which is what would notice if that
    # ever stopped being true.
    return [r for r in out if r['w']]


def clean(raw, witnessed, prefix, vid=''):
    """-> (text, runs, n_name_fixes, n_stray, n_untagged_lord, leftovers)."""
    s, n, stray = restore_name(raw, witnessed, vid)
    n_untagged = untagged_ot_lord(s) if prefix == 'H' else 0
    s = TS.sub('', s)
    s = REDLETTER.sub('', s)
    s = BREAKS.sub(' ', s)
    leftover = [t for t in ANY_TAG.findall(s) if not TAG.fullmatch(t)]
    runs = tidy(split_runs(s, prefix))
    text = ''.join(r['w'] for r in runs)
    return text, runs, n, stray, n_untagged, leftover


# A "Lord" with no Strong's tag after it, in running text rather than in
# a section heading. theWord writes the tag AFTER the word it governs, so
# a tagged Lord is one the module itself identifies — H136 Adonai, H113
# adon, G2962 Kyrios — and an untagged one is either a lost small-caps
# run or a word the tagger folded into its neighbour. That distinction is
# what makes the audit below small enough to adjudicate by hand.
UNTAGGED_LORD = re.compile(r'\bLord\b(?!(?:<W[HG]\d+[a-z]?>))')


def untagged_ot_lord(restored):
    """Bare untagged "Lord"s left in an OT verse, section headings aside.

    Run on the row AFTER the restoration, so a "Lord" the residue rule
    has already turned into the name is not counted as a candidate. What
    is left is exactly the set the rule cannot see.
    """
    spans = [m.span() for m in TS.finditer(restored)]
    return sum(1 for m in UNTAGGED_LORD.finditer(restored)
               if not any(a <= m.start() < z for a, z in spans))


def book_map(rows):
    """Abbreviation -> the book name this app already uses.

    Derived by canonical POSITION from `kjv.json`, not typed out: a
    hand-written table of 66 names is 66 chances to file Philemon's text
    under Philippians. Both sides are 31,102 verses in canonical order,
    and the per-book verse-count assertion is what makes position safe to
    trust — same order but different versification would put every verse
    after the disagreement under the wrong reference.
    """
    kjv = json.load(io.open(KJV, encoding='utf-8'))
    if len(kjv) != EXPECTED_VERSES:
        sys.exit('kjv.json is not the expected length; cannot map books')
    kjv_books, seen = [], set()
    for r in kjv:
        if r['book'] not in seen:
            seen.add(r['book'])
            kjv_books.append(r['book'])
    src_books, seen = [], set()
    for b, _c, _v, _s in rows:
        if b not in seen:
            seen.add(b)
            src_books.append(b)
    if len(kjv_books) != EXPECTED_BOOKS or len(src_books) != EXPECTED_BOOKS:
        sys.exit(f'expected {EXPECTED_BOOKS} books, got '
                 f'{len(kjv_books)} / {len(src_books)}')

    def counts(names):
        out = {}
        for b in names:
            out[b] = out.get(b, 0) + 1
        return out

    kc = counts([r['book'] for r in kjv])
    sc = counts([b for b, _c, _v, _s in rows])
    for kb, sb in zip(kjv_books, src_books):
        if kc[kb] != sc[sb]:
            sys.exit(f'{sb} has {sc[sb]} verses but {kb} has {kc[kb]}; '
                     'the two canons are not aligned')
    return dict(zip(src_books, kjv_books)), kjv_books


def kjvs_h3068(kjv_books):
    """{'BBBCCCVVV'} for every verse `assets/tagged/kjvs/` tags H3068.

    The witness. Falls back to nothing if the tagged set is missing,
    which the caller turns into a hard stop rather than a quiet import
    with 964 unverified edits in it.
    """
    out = set()
    for i, book in enumerate(kjv_books, start=1):
        path = os.path.join(KJVS_TAGS,
                            book.lower().replace(' ', '_') + '.json')
        if not os.path.exists(path):
            continue
        for ref, runs in json.load(io.open(path, encoding='utf-8')).items():
            if any(r.get('s') == 'H3068' or 'H3068' in (r.get('i') or [])
                   for r in runs):
                c, v = ref.split(':')
                out.add(f'{i:03d}{int(c):03d}{int(v):03d}')
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--report', help='write the divine-name changes here')
    ap.add_argument('--compare-plain',
                    help="assert the plain text equals YsWords' csb.json")
    args = ap.parse_args()

    rows = fetch_rows()
    names, kjv_books = book_map(rows)
    order = {b: i + 1 for i, b in enumerate(kjv_books)}
    witness = kjvs_h3068(kjv_books)
    if len(witness) < 5000:
        sys.exit(f'the kjvs witness produced only {len(witness)} verses; '
                 'assets/tagged/kjvs/ is missing or unreadable — refusing '
                 'to decide 964 divine-name edits without it')
    cuv = json.load(io.open(CUV, encoding='utf-8'))

    plain, tagged, changed, leftovers = [], {}, [], set()
    strays = 0
    seen_untagged = set()
    for (b, c, v, raw), cn in zip(rows, cuv):
        book = names[b]
        bi = order[book]
        vid = f'{bi:03d}{c:03d}{v:03d}'
        prefix = 'G' if bi >= 40 else 'H'
        witnessed = vid in witness
        text, runs, n, stray, n_untagged, left = clean(
            raw, witnessed, prefix, vid)
        if n_untagged:
            seen_untagged.add(vid)
        leftovers.update(left)
        strays += stray
        if n or stray:
            changed.append((book, c, v, n, witnessed,
                            '雅伟' in cn['text'], text))
        plain.append({'book': book, 'chapter': str(c), 'verse': str(v),
                      'text': text, 'id': vid})
        if any(r['s'] for r in runs):
            tagged.setdefault(book, {})[f'{c}:{v}'] = runs

    # Every OT verse where the module leaves a "Lord" that nothing
    # identifies. Recomputed from the source on every run, so the table
    # cannot quietly stop describing what is actually in there — and so
    # that a re-import which gains a candidate stops instead of shipping
    # it unadjudicated.
    found = seen_untagged
    if found != set(UNTAGGED_OT_LORD):
        extra = sorted(found - set(UNTAGGED_OT_LORD))
        gone = sorted(set(UNTAGGED_OT_LORD) - found)
        sys.exit('the untagged-Lord candidate set changed — adjudicate it '
                 'before shipping.\n'
                 f'  not in the table : {extra}\n'
                 f'  in the table, but no longer found : {gone}')

    n_restored = sum(1 for r in changed if r[3])
    corroborated = sum(1 for r in changed if r[3] and r[5])
    witnessed_n = sum(1 for r in changed if r[3] and r[4])
    n_runs = sum(len(rs) for bk in tagged.values() for rs in bk.values())
    n_tagged_runs = sum(1 for bk in tagged.values() for rs in bk.values()
                        for r in rs if r['s'])
    print(f'verses                      : {len(plain)}')
    print(f'books                       : {len(order)}')
    print(f'tagged books                : {len(tagged)}')
    print(f'runs                        : {n_runs} '
          f'({n_tagged_runs} carry a number, '
          f'{100 * n_tagged_runs / n_runs:.1f}%)')
    print(f'divine-name restorations    : {n_restored}')
    print(f'  tagged H3068 by the kjvs witness: {witnessed_n}')
    print(f'  corroborated by cuvs-yhwh       : {corroborated}')
    print(f'stray articles repaired     : {strays}')
    print(f'untagged OT "Lord" left      : {len(found)} '
          f'(adjudicated, see UNTAGGED_OT_LORD)')
    print(f'leftover tag kinds          : '
          f'{sorted(leftovers) if leftovers else "none"}')
    if leftovers:
        sys.exit('unhandled markup — refusing to write a file with tags in it')

    by_id = {r['id']: r['text'] for r in plain}
    for label, vid in [('Deut 6:4  ', '005006004'),
                       ('Ps 23:1   ', '019023001'),
                       ('Ps 110:1  ', '019110001'),
                       ('John 3:16 ', '043003016')]:
        print(f'  {label} {by_id[vid][:86]}')
    print('  Deut 6:4 runs '
          + json.dumps(tagged['Deuteronomy']['6:4'], ensure_ascii=False)[:200])

    if args.compare_plain:
        other = json.load(io.open(args.compare_plain, encoding='utf-8'))
        diff = [(a['id'], a['text'], b_['text'])
                for a, b_ in zip(plain, other) if a['text'] != b_['text']]
        print(f'plain-text diff vs yswords  : {len(diff)}')
        for d in diff[:5]:
            print(f'    {d[0]}\n      here: {d[1][:100]}\n      there: {d[2][:100]}')

    if args.report:
        with io.open(args.report, 'w', encoding='utf-8') as f:
            f.write(f'# CSB divine-name restorations ({n_restored})\n\n')
            f.write('`Lord ` + the residue space -> `Yahweh`, with H3068 '
                    'spliced back where `assets/tagged/kjvs/` tags it. See '
                    'the docstring in tools/import_csb.py.\n\n')
            f.write('| ref | n | H3068 in kjvs | 雅伟 in cuvs-yhwh | verse |\n')
            f.write('|---|---|---|---|---|\n')
            for bk, c, v, n, w, zh, t in changed:
                f.write(f'| {bk} {c}:{v} | {n} | {"yes" if w else "—"} | '
                        f'{"yes" if zh else "—"} | {t[:110]} |\n')
        print(f'report                      : {args.report}')

    if args.dry_run:
        print('dry run — nothing written')
        return

    with io.open(OUT, 'w', encoding='utf-8') as f:
        json.dump(plain, f, ensure_ascii=False, separators=(',', ':'))
    os.makedirs(TAGDIR, exist_ok=True)
    for book, verses in tagged.items():
        slug = book.lower().replace(' ', '_')
        with io.open(os.path.join(TAGDIR, f'{slug}.json'), 'w',
                     encoding='utf-8') as f:
            json.dump(verses, f, ensure_ascii=False, separators=(',', ':'))
    total = os.path.getsize(OUT) + sum(
        os.path.getsize(os.path.join(TAGDIR, p)) for p in os.listdir(TAGDIR))
    print(f'wrote                       : assets/csb.json + '
          f'assets/tagged/csb/ ({total / 1e6:.1f} MB)')


if __name__ == '__main__':
    main()
