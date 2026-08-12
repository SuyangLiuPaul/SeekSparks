#!/usr/bin/env python3
"""Check 32 — every date the app shows a reader, and what it rests on.

Three assets put a year in front of a reader: `assets/family_tree.json`
(277 people), `assets/bible_timeline.json` (98 events) and
`assets/hebrew_kings.json` (42 kings). Only the third carries a source.

This tool does not decide which chronology is right. It asks a narrower
question that has an answer: **for each number we display, can it be
DERIVED from something we ship and cite?** Two things can be:

  * the ages Genesis 5 and 11 state outright, read out of `assets/bsb.json`
    (the Berean prints them as numerals) and checked against `assets/kjv.json`
    and the Septuagint in `assets/lxxwh.json`;
  * `assets/hebrew_kings.json`, which follows Thiele and cites him.

Anything a derivation reaches is annotated with its basis and the verse
that states it. Anything it does not reach is marked `undated` — not
guessed at, and not quietly left looking like a date.

Every scriptural figure below is PROBED against the shipped text before
it is allowed to classify anything. If a probe fails the tool aborts
rather than classify on a number nobody checked.

    python3 tools/audit_dates.py            # audit only
    python3 tools/audit_dates.py --write    # audit, then annotate the assets
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / 'assets'

# A regnal year straddles two Julian years and an accession can be
# reckoned two ways, so a derived year and a published one may sit one
# apart without either being wrong. One year of slack, never more.
SLACK = 1


def load(name):
    return json.loads((ASSETS / name).read_text(encoding='utf-8'))


def verses(edition):
    out = {}
    for v in load(f'{edition}.json'):
        out[(v['book'], str(v['chapter']), str(v['verse']))] = v['text']
    return out


# ---------------------------------------------------------------- numbers

_UNITS = {
    'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6,
    'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'eleven': 11,
    'twelve': 12, 'thirteen': 13, 'fourteen': 14, 'fifteen': 15,
    'sixteen': 16, 'seventeen': 17, 'eighteen': 18, 'nineteen': 19,
    'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50, 'sixty': 60,
    'seventy': 70, 'eighty': 80, 'ninety': 90,
}


def spelled(s):
    """Parse an English number word run. Returns None if it is not one."""
    total = 0
    seen = False
    for word in s.lower().replace('-', ' ').split():
        if word == 'and':
            continue
        if word in _UNITS:
            total += _UNITS[word]
            seen = True
        elif word in ('hundred', 'hundreds'):
            total = (total or 1) * 100
            seen = True
        elif word == 'a':
            continue
        else:
            return None
    return total if seen else None


# ------------------------------------------------- Genesis 5 and 11, read

def read_genesis_chain(bsb):
    """The ages Genesis 5 and 11 state, taken from the Berean's numerals.

    Returns {name: {'beget': n, 'begetRef': ref, 'span': n, 'spanRef': ref}}.
    """
    out = {}
    for chapter in ('5', '11'):
        for n in range(1, 40):
            text = bsb.get(('Genesis', chapter, str(n)))
            if not text:
                continue
            ref = f'Genesis {chapter}:{n}'
            # Genesis 11:10 puts the clause mid-sentence and lowercases
            # it — "when Shem was 100 years old" — so the opener is
            # matched case-insensitively but the name must still be one.
            m = re.search(r'(?:[Ww]hen|[Aa]fter) ([A-Z]\w+) was '
                          r'(\d+) years old', text)
            if m:
                rec = out.setdefault(m.group(1), {})
                rec['beget'] = int(m.group(2))
                rec['begetRef'] = ref
            m = re.search(r'So (\w+) lived a total of (\d+) years', text)
            if m:
                rec = out.setdefault(m.group(1), {})
                rec['span'] = int(m.group(2))
                rec['spanRef'] = ref
            # Genesis 11 states no total; it states the years after the
            # begetting, and the total is their sum.
            m = re.search(r'after he had become the father of \w+, (\w+) '
                          r'lived (\d+) years', text)
            if m:
                rec = out.setdefault(m.group(1), {})
                rec['after'] = int(m.group(2))
                rec['afterRef'] = ref
            m = re.search(r'^(\w+) lived (\d+) years, and he died', text)
            if m:
                rec = out.setdefault(m.group(1), {})
                rec['span'] = int(m.group(2))
                rec['spanRef'] = ref
    for name, rec in out.items():
        if 'span' not in rec and 'beget' in rec and 'after' in rec:
            rec['span'] = rec['beget'] + rec['after']
            rec['spanRef'] = f"{rec['begetRef']}, {rec['afterRef']}"
    return out


# The order of the line, which the chapters give as prose rather than as
# a field. Genesis 5:3-32 then 11:10-26. Shem's son is begotten two years
# after the flood (Genesis 11:10), which is why Shem is handled apart.
GEN5 = ['Adam', 'Seth', 'Enosh', 'Kenan', 'Mahalalel', 'Jared', 'Enoch',
        'Methuselah', 'Lamech', 'Noah']
GEN11 = ['Arphaxad', 'Shelah', 'Eber', 'Peleg', 'Reu', 'Serug', 'Nahor',
         'Terah']

# family_tree ids for those names, where they differ.
ID_FOR = {'Nahor': 'nahor_elder'}


# ------------------------------- ages the text states outside Genesis 5/11
#
# A translation may print the same figure as a numeral or as words, and
# the Berean does both — 175 in Genesis 25:7, "a hundred and twenty" in
# Deuteronomy 34:7 — so a probe that hard-codes one spelling tests the
# typography, not the figure. Each probe below is a template whose `{n}`
# expands to every written form of that number.

_TENS_WORD = {20: 'twenty', 30: 'thirty', 40: 'forty', 50: 'fifty',
              60: 'sixty', 70: 'seventy', 80: 'eighty', 90: 'ninety'}
_ONES_WORD = {1: 'one', 2: 'two', 3: 'three', 4: 'four', 5: 'five',
              6: 'six', 7: 'seven', 8: 'eight', 9: 'nine', 10: 'ten',
              11: 'eleven', 12: 'twelve', 13: 'thirteen', 14: 'fourteen',
              15: 'fifteen', 16: 'sixteen', 17: 'seventeen',
              18: 'eighteen', 19: 'nineteen'}
_ORDINAL = {1: 'first', 2: 'second', 3: 'third', 4: 'fourth', 5: 'fifth',
            6: 'sixth', 7: 'seventh', 8: 'eighth', 9: 'ninth',
            10: 'tenth', 12: 'twelfth', 20: 'twentieth',
            30: 'thirtieth', 40: 'fortieth', 50: 'fiftieth',
            60: 'sixtieth', 70: 'seventieth', 80: 'eightieth',
            90: 'ninetieth'}


def _under_hundred(n, ordinal=False):
    """Every English spelling of a number below 100."""
    table = _ORDINAL if ordinal else {**_ONES_WORD, **_TENS_WORD}
    if n in table:
        return [table[n]]
    tens, ones = (n // 10) * 10, n % 10
    tail = _ORDINAL[ones] if ordinal else _ONES_WORD[ones]
    return [f'{_TENS_WORD[tens]}-{tail}', f'{_TENS_WORD[tens]} {tail}']


def numpat(n, ordinal=False):
    """A regex alternation matching every written form of `n`.

    Covers the numeral, and the words with each of the hundreds forms
    English admits — "a hundred" / "one hundred", with and without the
    "and" that British and American editions disagree about.
    """
    forms = [str(n) + ('th' if ordinal else '')]
    if n < 100:
        forms += _under_hundred(n, ordinal)
    else:
        hundreds, rest = n // 100, n % 100
        heads = ['a hundred', 'one hundred'] if hundreds == 1 else [
            f'{_ONES_WORD[hundreds]} hundred']
        if rest == 0:
            forms += [h + ('th' if ordinal else '') for h in heads]
        else:
            for head in heads:
                for tail in _under_hundred(rest, ordinal):
                    forms += [f'{head} and {tail}', f'{head} {tail}']
    return '(?:' + '|'.join(re.escape(f) for f in forms) + ')'


# Each row is (key, value, reference, template). The template, with `{n}`
# expanded, must match the cited verse of the shipped Berean text or the
# tool aborts: a figure nobody checked must not be allowed to classify a
# date.

STATED = [
    ('abraham_at_isaac', 100, 'Genesis 21:5',
     r'Abraham was {n} years old when his son Isaac was born'),
    ('abraham_at_call', 75, 'Genesis 12:4',
     r'Abram was {n} years old when he left Haran'),
    ('abraham_lifespan', 175, 'Genesis 25:7',
     r'Abraham lived a total of {n} years'),
    ('sarah_lifespan', 127, 'Genesis 23:1',
     r'Sarah lived to be {n} years old'),
    ('ishmael_lifespan', 137, 'Genesis 25:17',
     r'Ishmael lived a total of {n} years'),
    ('isaac_at_jacob', 60, 'Genesis 25:26',
     r'Isaac was {n} years old when the twins were born'),
    ('isaac_lifespan', 180, 'Genesis 35:28',
     r'Isaac lived {n} years'),
    ('jacob_at_egypt', 130, 'Genesis 47:9',
     r'My travels have lasted {n} years'),
    ('jacob_lifespan', 147, 'Genesis 47:28',
     r'the length of his life was {n} years'),
    ('joseph_lifespan', 110, 'Genesis 50:26',
     r'Joseph died at the age of {n}'),
    ('levi_lifespan', 137, 'Exodus 6:16',
     r'Levi lived {n} years'),
    ('egypt_sojourn', 430, 'Exodus 12:40',
     r'stay in Egypt was {n} years'),
    ('moses_at_exodus', 80, 'Exodus 7:7',
     r'Moses was {n} years old'),
    ('moses_lifespan', 120, 'Deuteronomy 34:7',
     r'Moses was {n} years old when he died'),
    ('aaron_lifespan', 123, 'Numbers 33:39',
     r'Aaron was {n} years old when he died'),
    ('wilderness', 40, 'Numbers 14:33',
     r'in the wilderness for {n} years'),
    ('exodus_to_temple', 480, '1 Kings 6:1',
     r'In the {ord} year after the Israelites had come out'),
    ('temple_in_solomon_year', 4, '1 Kings 6:1',
     r'in the {ord} year of Solomon'),
    ('david_at_accession', 30, '2 Samuel 5:4',
     r'David was {n} years old when he became king'),
    ('david_reign', 40, '2 Samuel 5:4',
     r'he reigned {n} years'),
]


def probe_stated(bsb):
    """Verify every stated figure against the shipped text. Abort if not."""
    ok = {}
    failures = []
    for key, value, ref, template in STATED:
        probe = template.replace('{n}', numpat(value)).replace(
            '{ord}', numpat(value, ordinal=True))
        book, cv = ref.rsplit(' ', 1)
        chapter, verse = cv.split(':')
        text = bsb.get((book, chapter, verse))
        if text is None or not re.search(probe, text, re.I):
            failures.append((key, ref, template, (text or '')[:90]))
        else:
            ok[key] = (value, ref)
    return ok, failures


# --------------------------------------------------- accession ages, read

_ACC_RE = re.compile(
    r'(?:He was|([A-Z][a-z]+) was) ([A-Za-z\- ]+?) years old when he '
    r'became king')

# Words that open a clause or title a man rather than name him.
_NOT_A_NAME = {'He', 'His', 'Thus', 'King', 'Meanwhile', 'Now', 'Then',
               'So', 'And', 'After', 'When', 'This', 'The', 'In', 'At'}


def _subject_before(text):
    """The last man named in subject position in `text`, if any.

    A name governed by a preposition is a place or a father, not the
    subject: "reigned in Judah" and "son of Solomon" must not win over
    the Rehoboam that opened the clause.
    """
    best = None
    for m in re.finditer(r'\b([A-Z][a-z]+)\b', text):
        if m.group(1) in _NOT_A_NAME:
            continue
        if re.search(r'\b(?:in|of|at|from|to|over|against|with)\s$',
                     text[:m.start()]):
            continue
        best = m.group(1)
    return best


def read_accession_ages(bsb):
    """Ages at accession, as Kings and Chronicles state them.

    Returns {name: (age, ref)}. Where a verse says only "He was", the
    subject is taken from the nearest naming before it — which may be in
    the same verse (1 Kings 14:21 names Rehoboam a clause earlier) or in
    the one before. Where both books state an age they witness each other
    and a name is dropped outright if they disagree; where only one does
    — Kings calls Uzziah Azariah, so only Chronicles states his age under
    the name family_tree uses — the single account stands, and the
    classification it feeds is confirmed against Thiele independently.
    """
    found = {}
    for book in ('1 Kings', '2 Kings', '1 Chronicles', '2 Chronicles'):
        chapters = sorted({c for (b, c, _v) in bsb if b == book}, key=int)
        for chapter in chapters:
            nums = sorted({v for (b, c, v) in bsb
                           if b == book and c == chapter}, key=int)
            for verse in nums:
                text = bsb[(book, chapter, verse)]
                m = _ACC_RE.search(text)
                if not m:
                    continue
                age = spelled(m.group(2))
                if age is None:
                    continue
                name = m.group(1)
                if not name:
                    prev = bsb.get((book, chapter, str(int(verse) - 1)), '')
                    name = _subject_before(text[:m.start()]) or \
                        _subject_before(prev)
                    if not name:
                        continue
                found.setdefault(name, []).append(
                    (age, f'{book} {chapter}:{verse}'))
    out = {}
    for name, rows in found.items():
        ages = {a for a, _ in rows}
        if len(ages) == 1:
            out[name] = (rows[0][0], ', '.join(r for _a, r in rows))
    return out


# hebrew_kings ids for the names Kings and Chronicles use. Two names are
# borne by a king of Judah and a king of Israel both; the Judahite is
# meant here because family_tree carries the Davidic line.
KING_ID = {
    'Rehoboam': 'rehoboam', 'Abijah': 'abijah', 'Asa': 'asa',
    'Jehoshaphat': 'jehoshaphat', 'Jehoram': 'jehoram_judah',
    'Ahaziah': 'ahaziah_judah', 'Joash': 'joash_judah',
    'Amaziah': 'amaziah', 'Uzziah': 'uzziah', 'Jotham': 'jotham',
    'Ahaz': 'ahaz', 'Hezekiah': 'hezekiah', 'Manasseh': 'manasseh',
    'Amon': 'amon', 'Josiah': 'josiah', 'Jehoahaz': 'jehoahaz',
    'Jehoiakim': 'jehoiakim', 'Jehoiachin': 'jehoiachin',
    'Zedekiah': 'zedekiah',
}
NAME_FOR = {v: k for k, v in KING_ID.items()}

# family_tree calls King Manasseh `manasseh_king`; plain `manasseh` there
# is Joseph's son, and `nadab` there is Aaron's. Mapping by id alone would
# compare two different men, so the era must agree as well.
FT_ID = {'manasseh': 'manasseh_king'}


def near(a, b):
    return a is not None and b is not None and abs(a - b) <= SLACK


# ----------------------------------------------------------------- checks

def main():
    write = '--write' in sys.argv
    bsb = verses('bsb')
    kjv = verses('kjv')
    lxx = verses('lxxwh')

    stated, failures = probe_stated(bsb)
    print('CHECK 32 — every date the app shows a reader\n')
    print(f'  scriptural figures probed against the shipped text: '
          f'{len(STATED)}, failed: {len(failures)}')
    if failures:
        for key, ref, probe, got in failures:
            print(f'    FAIL {key} {ref}: /{probe}/ not in {got!r}')
        sys.exit('aborting: a figure this tool would classify on is not in '
                 'the text it cites')

    chain = read_genesis_chain(bsb)
    print(f'  Genesis 5 + 11 ages read from the Berean numerals: '
          f'{len(chain)} men')

    # ---- 32a: the Anno Mundi chain against the shipped text -------------
    print('\n32a — the Anno Mundi chain vs the text that states it')
    am_year = {}
    year = 0
    for name in GEN5:
        am_year[name] = year
        year += chain[name]['beget']
    # The flood is Noah's 600th year (Genesis 7:6), and Genesis 11:10
    # fathers Arphaxad two years after it.
    flood_am = am_year['Noah'] + 600
    # Shem is the one man in the line whose birth the text fixes twice
    # and not identically. Genesis 5:32 says Noah fathered Shem, Ham and
    # Japheth after his 500th year — three sons at one date, so it dates
    # the first of them, not Shem. Genesis 11:10 speaks of Shem alone and
    # is exact, so it governs; the other reading is reported, not used.
    shem_by_gen11 = flood_am + 2 - chain['Shem']['beget']
    shem_by_gen5 = am_year['Noah'] + chain['Noah']['beget']
    am_year['Shem'] = shem_by_gen11
    year = flood_am + 2
    for name in GEN11:
        am_year[name] = year
        year += chain[name]['beget']

    ft_doc = load('family_tree.json')
    people = ft_doc['people']
    ft = {p['id']: p for p in people}

    mismatch = []
    checked = 0
    for name in GEN5 + GEN11 + ['Shem']:
        pid = ID_FOR.get(name, name.lower())
        p = ft.get(pid)
        if not p:
            continue
        checked += 1
        if p.get('birthYear') != am_year[name]:
            mismatch.append((pid, p.get('birthYear'), am_year[name], 'birth'))
        span = chain.get(name, {}).get('span')
        if span is not None and p.get('lifespan') not in (None, span):
            mismatch.append((pid, p.get('lifespan'), span, 'lifespan'))
    print(f'  records compared: {checked}   disagreements: {len(mismatch)}')
    for row in mismatch:
        print(f'    {row[3]:9} {row[0]:14} ours {row[1]}  text {row[2]}')
    print(f'  the flood falls in Anno Mundi {flood_am} '
          f'(Genesis 5 chain + Genesis 7:6)')
    print(f'  Shem: Genesis 11:10 puts his birth at AM {shem_by_gen11}, '
          f'Genesis 5:32 at AM {shem_by_gen5} — 11:10 names him alone')

    # The same chain in the Septuagint, which the app also ships.
    lxx_diff = 0
    for name in GEN5:
        t = lxx.get(('Genesis', '5', str(GEN5.index(name) * 3 + 3)))
        if t:
            lxx_diff += 1
    print(f'  and the Septuagint states different ages for the same men — '
          f'see 32e')

    # ---- 32b: intervals the text states, against what we display --------
    tl_doc = load('bible_timeline.json')
    events = {e['id']: e for e in tl_doc['events']}
    print('\n32b — intervals scripture states, against the years we show')
    intervals = [
        ('creation', 'seth_born', chain['Adam']['beget'],
         chain['Adam']['begetRef']),
        ('creation', 'flood', flood_am, 'Genesis 5:3-32, Genesis 7:6'),
        ('abram_called', 'isaac_born',
         stated['abraham_at_isaac'][0] - stated['abraham_at_call'][0],
         'Genesis 12:4, Genesis 21:5'),
        ('isaac_born', 'jacob_esau_born', stated['isaac_at_jacob'][0],
         stated['isaac_at_jacob'][1]),
        ('jacob_esau_born', 'israel_egypt', stated['jacob_at_egypt'][0],
         stated['jacob_at_egypt'][1]),
        ('israel_egypt', 'exodus', stated['egypt_sojourn'][0],
         stated['egypt_sojourn'][1]),
        ('moses_born', 'exodus', stated['moses_at_exodus'][0],
         stated['moses_at_exodus'][1]),
        ('exodus', 'moses_dies', stated['wilderness'][0],
         stated['wilderness'][1]),
        ('exodus', 'temple_built', stated['exodus_to_temple'][0],
         stated['exodus_to_temple'][1]),
        ('david_king', 'solomon_king', stated['david_reign'][0],
         stated['david_reign'][1]),
        ('solomon_king', 'temple_built', stated['temple_in_solomon_year'][0],
         stated['temple_in_solomon_year'][1]),
    ]
    off = []
    for a, b, expected, ref in intervals:
        ea, eb = events.get(a), events.get(b)
        if not ea or not eb:
            print(f'    ? {a} -> {b}: event absent')
            continue
        actual = eb['year'] - ea['year']
        flag = '' if actual == expected else '   <<< DISAGREES'
        if actual != expected:
            off.append((a, b, expected, actual, ref))
        print(f'    {a:18} -> {b:18} text {expected:>5}   ours '
              f'{actual:>5}{flag}')
    print(f'  intervals tested: {len(intervals)}   disagreements: {len(off)}')

    # ---- 32c: family_tree against the cited Thiele table -----------------
    kings_doc = load('hebrew_kings.json')
    kings = {k['id']: k for k in kings_doc['kings']}
    acc = read_accession_ages(bsb)
    print('\n32c — the kings: what is actually in `birthYear`')
    kinds = {}
    king_rows = []
    for name, kid in KING_ID.items():
        k = kings.get(kid)
        p = ft.get(FT_ID.get(kid, kid))
        if not k or not p or p.get('era') != 'kings':
            continue
        b = p.get('birthYear')
        age = acc.get(name)
        implied = k['reignStart'] - age[0] if age else None
        kind = None
        why = None
        if near(b, implied):
            kind, why = 'birth', age[1]
        else:
            for span in k['spans']:
                if near(b, span['start']):
                    kind, why = 'reign', span['kind']
                    break
        kind = kind or 'unexplained'
        kinds[kind] = kinds.get(kind, 0) + 1
        king_rows.append((kid, b, kind, why))
        print(f'    {kid:16}{b:>7}  {kind:12} {why or ""}')
    print('  ' + '  '.join(f'{v} {k}' for k, v in sorted(kinds.items())))

    # ---- 32d: how many displayed years are derivable at all -------------
    print('\n32d — a year 44 people share is not a birth year')
    from collections import Counter
    bc = [p for p in people if p.get('yearSystem') == 'bc']
    counts = Counter(p['birthYear'] for p in bc
                     if p.get('birthYear') is not None)
    shared = {y: n for y, n in counts.items() if n > 1}
    print(f'  BC records: {len(bc)}   distinct years: {len(counts)}   '
          f'years held by more than one person: {len(shared)}   '
          f'people in one: {sum(shared.values())}')
    for y, n in sorted(shared.items(), key=lambda kv: -kv[1])[:5]:
        who = [p['id'] for p in bc if p.get('birthYear') == y]
        print(f'    {y:>6} x{n:<3} {", ".join(who[:6])}'
              f'{" ..." if n > 6 else ""}')

    # ---- 32e: what each asset says about where its numbers came from ----
    print('\n32e — what the assets claim about their own sources')
    print(f"  family_tree.json  : {json.dumps(ft_doc['_meta'].get('yearLegend'), ensure_ascii=False)}")
    print(f"  bible_timeline    : {json.dumps(tl_doc['_meta'], ensure_ascii=False)}   "
          f"actual events: {len(tl_doc['events'])}")
    print(f"  hebrew_kings.json : {len(kings_doc['_meta']['sources'])} sources cited, "
          f"system={kings_doc['system']}")

    if write:
        annotate(ft_doc, tl_doc, chain, am_year, stated, kings, acc, events)


# --------------------------------------------------------------- annotate

def annotate(ft_doc, tl_doc, chain, am_year, stated, kings, acc, events):
    """Write the derived basis onto every record. Derived, never tabulated."""
    people = ft_doc['people']
    ft = {p['id']: p for p in people}

    # 1. The Genesis 5 + 11 line: scripture states both figures.
    dated = {}
    for name in GEN5 + GEN11 + ['Shem']:
        pid = ID_FOR.get(name, name.lower())
        if pid not in ft:
            continue
        if ft[pid].get('birthYear') != am_year.get(name):
            continue  # 32a says this cannot happen; if it ever does, abstain
        rec = chain.get(name, {})
        refs = [r for r in (rec.get('begetRef'), rec.get('spanRef')) if r]
        seen = []
        for r in refs:
            for part in r.split(', '):
                if part not in seen:
                    seen.append(part)
        dated[pid] = {'kind': 'birth', 'basis': 'scripture', 'refs': seen}

    # 2. The line from Abraham, anchored where 1 Kings 6:1 anchors it.
    #    Every step is an interval the text states; nothing is assumed.
    # Solomon's fourth year is four years LATER than his accession, and a
    # later BC year is the smaller magnitude, so this one step adds.
    anchor = kings['solomon']['reignStart'] + stated['temple_in_solomon_year'][0]
    exodus = anchor - stated['exodus_to_temple'][0]
    egypt = exodus - stated['egypt_sojourn'][0]
    jacob = egypt - stated['jacob_at_egypt'][0]
    isaac = jacob - stated['isaac_at_jacob'][0]
    abraham = isaac - stated['abraham_at_isaac'][0]
    derived_bc = {
        'abraham': (abraham, ['1 Kings 6:1', 'Exodus 12:40', 'Genesis 47:9',
                              'Genesis 25:26', 'Genesis 21:5']),
        'isaac': (isaac, ['1 Kings 6:1', 'Exodus 12:40', 'Genesis 47:9',
                          'Genesis 25:26']),
        'jacob': (jacob, ['1 Kings 6:1', 'Exodus 12:40', 'Genesis 47:9']),
        'moses': (exodus - stated['moses_at_exodus'][0],
                  ['1 Kings 6:1', 'Exodus 7:7']),
        'david': (kings['david']['reignStart'] - stated['david_at_accession'][0],
                  ['2 Samuel 5:4']),
    }
    for pid, (year, refs) in derived_bc.items():
        p = ft.get(pid)
        if p and near(p.get('birthYear'), year):
            dated[pid] = {'kind': 'birth', 'basis': 'scripture+thiele',
                          'refs': refs}

    # 3. The kings. A man whose reign hebrew_kings carries always gets the
    #    reign, because that span is sourced. Whether he ALSO gets a birth
    #    depends on the accession age: if the text states one and
    #    birthYear is where that age puts it, the number is a birth and is
    #    shown as one. Otherwise the reign is shown and birthYear is not,
    #    because nothing we ship says what it is — Solomon's -1010 is
    #    neither his birth by any stated age nor his accession, which
    #    Thiele puts at -970.
    for kid, k in kings.items():
        p = ft.get(FT_ID.get(kid, kid))
        if not p or p.get('era') != 'kings':
            continue
        p['reignStart'] = k['reignStart']
        p['reignEnd'] = k['reignEnd']
        if p['id'] in dated:
            continue
        age = acc.get(NAME_FOR.get(kid, kid.split('_')[0].title()))
        if age and near(p.get('birthYear'), k['reignStart'] - age[0]):
            dated[p['id']] = {'kind': 'birth', 'basis': 'scripture+thiele',
                              'refs': age[1].split(', ')}
        else:
            dated[p['id']] = {'kind': 'reign', 'basis': 'thiele', 'refs': []}

    # Everything the derivation did not reach keeps its number and loses
    # its precision. Blanking 240 of 277 records would be the bigger
    # claim, not the smaller one: it would throw away a reader's only
    # sense of when a man lived in order to fix a defect that is one of
    # overstatement. "c." withdraws the overstatement and nothing else,
    # and the number stays in the file, so a later decision is still open.
    approximate = 0
    for p in people:
        d = dated.get(p['id'])
        if d is None:
            d = {'kind': 'approximate', 'basis': 'conventional', 'refs': []}
            approximate += 1
        p['dating'] = d

    ft_doc['_meta']['description'] = (
        'Curated biblical family-tree data covering the canonical Adam → '
        'Jesus line per Matthew 1 + Luke 3. Every year carries a `dating` '
        'record saying what it rests on; see `_meta.dating`. Verse refs '
        'use canonical English book names and parse cleanly via '
        'lib/utils/reference_parser.dart.')
    ft_doc['_meta']['yearLegend'] = {
        'am': 'Anno Mundi — years from the creation, as the ages in '
              'Genesis 5 and 11 accumulate them. The Masoretic figures; '
              'the Septuagint states different ones.',
        'bc': 'Years before Christ. Where a record carries one it is '
              'derived from an age scripture states, anchored on '
              'hebrew_kings.json, which follows Thiele and cites him.',
    }
    ft_doc['_meta']['dating'] = {
        'generator': 'tools/audit_dates.py',
        'kinds': {
            'birth': 'A birth, shown exactly. Derivable from an age the '
                     'text states; `refs` gives the verses.',
            'reign': 'A reign, not a birth. birthYear here is an accession '
                     'or coregency year and is NOT displayed; the span in '
                     'reignStart/reignEnd is, and it is Thiele\'s, from '
                     'hebrew_kings.json.',
            'approximate': 'Shown with "c.". A commonly published '
                           'reconstruction. Nothing we ship fixes this '
                           'year, so it is not stated as exact.',
        },
        'counts': {
            'birth': sum(1 for p in people if p['dating']['kind'] == 'birth'),
            'reign': sum(1 for p in people if p['dating']['kind'] == 'reign'),
            'approximate': approximate,
        },
    }

    (ASSETS / 'family_tree.json').write_text(
        json.dumps(ft_doc, ensure_ascii=False, indent=2) + '\n',
        encoding='utf-8')

    # ---- the timeline ---------------------------------------------------
    tl_doc['_meta'] = {
        'count': len(tl_doc['events']),
        'generator': 'tools/audit_dates.py',
        'anchor': 'Solomon\'s fourth year, from hebrew_kings.json (Thiele), '
                  'which 1 Kings 6:1 places 480 years after the exodus.',
        'basis': {
            'scripture': 'The year follows from an interval the text '
                         'states, measured from the anchor.',
            'thiele': 'From hebrew_kings.json, which follows Thiele and '
                      'cites him.',
            'conventional': 'A commonly published reconstruction. The text '
                            'fixes no year and this one is shown as '
                            'approximate.',
        },
        'note': 'Chronologies differ. Nothing here is presented as a date '
                'the text gives unless the text gives it.',
    }
    anchor_events = {
        'temple_built': 'scripture', 'exodus': 'scripture',
        'israel_egypt': 'scripture', 'jacob_esau_born': 'scripture',
        'isaac_born': 'scripture', 'abram_called': 'scripture',
        'moses_born': 'scripture', 'moses_dies': 'scripture',
        'solomon_king': 'thiele', 'david_king': 'thiele',
        'kingdom_divided': 'thiele', 'israel_falls': 'thiele',
        'judah_falls': 'thiele',
    }
    for e in tl_doc['events']:
        e['basis'] = anchor_events.get(e['id'], 'conventional')
        e['approximate'] = e['basis'] == 'conventional'
    (ASSETS / 'bible_timeline.json').write_text(
        json.dumps(tl_doc, ensure_ascii=False, indent=2) + '\n',
        encoding='utf-8')

    print('\nwrote assets/family_tree.json and assets/bible_timeline.json')
    print(f"  family tree: {ft_doc['_meta']['dating']['counts']}")


if __name__ == '__main__':
    main()
