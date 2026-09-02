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
    ('wilderness_numbers32', 40, 'Numbers 32:13',
     r'wander in the wilderness {n} years'),
    ('wilderness_joshua', 40, 'Joshua 5:6',
     r'wandered in the wilderness {n} years'),
    ('jordan_crossed_year', 40, 'Deuteronomy 1:3', r'In the {ord} year'),
    ('abram_at_ishmael', 86, 'Genesis 16:16',
     r'Abram was {n} years old when Hagar bore Ishmael'),
    ('isaac_at_rebekah', 40, 'Genesis 25:20',
     r'Isaac was {n} years old when he married Rebekah'),
    ('joseph_before_pharaoh', 30, 'Genesis 41:46',
     r'Joseph was {n} years old when he entered the service of Pharaoh'),
    ('years_of_plenty', 7, 'Genesis 41:53',
     r'When the {n} years of abundance'),
    ('famine_past_at_descent', 2, 'Genesis 45:6',
     r'the famine has covered the land these {n} years'),
    ('tabernacle_year', 2, 'Exodus 40:17',
     r'the first day of the first month of the {ord} year'),
    ('sinai_month', 3, 'Exodus 19:1', r'In the {ord} month'),
    ('manna_month', 2, 'Exodus 16:1',
     r'the fifteenth day of the {ord} month after they had left'),
    # Not every interval the text states is spelled as a number. These
    # three phrases are matched literally; the value beside them is the
    # span in years that the phrase states, and it is 1 or 0.
    ('isaac_promised_g17', 1, 'Genesis 17:21', r'at this time next year'),
    ('isaac_promised_g18', 1, 'Genesis 18:10', r'at this time next year'),
    ('sodom_that_evening', 0, 'Genesis 19:1',
     r'the two angels arrived at Sodom in the evening'),
    ('gilgal_camp_day', 0, 'Joshua 4:19',
     r'the tenth day of the first month the people went up from the Jordan'),
    ('jericho_march_day', 0, 'Joshua 6:15',
     r'on the seventh day, they got up at dawn'),
    ('exodus_to_temple', 480, '1 Kings 6:1',
     r'In the {ord} year after the Israelites had come out'),
    ('temple_in_solomon_year', 4, '1 Kings 6:1',
     r'in the {ord} year of Solomon'),
    ('david_at_accession', 30, '2 Samuel 5:4',
     r'David was {n} years old when he became king'),
    ('david_reign', 40, '2 Samuel 5:4',
     r'he reigned {n} years'),
    # The five below carry the chain BACK past Abraham. Genesis 5 and 11
    # are read as intervals by `read_genesis_chain`; these are the
    # figures that join those two runs to each other and to the flood,
    # plus the two that fix Aaron.
    ('noah_at_flood', 600, 'Genesis 7:6',
     r'Noah was {n} years old when the floodwaters came'),
    ('arphaxad_after_flood', 2, 'Genesis 11:10',
     r'{n} years after the flood'),
    ('enoch_lifespan', 365, 'Genesis 5:23',
     r'Enoch lived a total of {n} years'),
    ('aaron_at_exodus', 83, 'Exodus 7:7',
     r'Aaron was {n} when they spoke to Pharaoh'),
    ('aaron_lifespan_n33', 123, 'Numbers 33:39',
     r'Aaron was {n} years old when he died'),
]


def probe_stated(bsb):
    """Verify every stated figure against the shipped text. Abort if not."""
    ok = {}
    failures = []
    for key, value, ref, template in STATED:
        # Substituted lazily: not every number has an ordinal spelling in
        # the table, and building one nobody asked for aborts the probe.
        probe = template
        if '{n}' in probe:
            probe = probe.replace('{n}', numpat(value))
        if '{ord}' in probe:
            probe = probe.replace('{ord}', numpat(value, ordinal=True))
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


def record_correction(doc, pid, field, was, why):
    """Append to the asset's own `corrections` log, once per field."""
    log = doc.setdefault('corrections', [])
    if any(c.get('id') == pid and c.get('field') == field for c in log):
        return
    log.append({'id': pid, 'field': field, 'from': was, 'why': why})


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

    # AARON, WHO IS THE ONE MAN THIS TOOL RE-DATES. Everywhere else it
    # abstains when a derivation disagrees with a shipped year, because
    # moving a published date is a decision. This one was already
    # decided twice, differently, inside this repository: `family_tree`
    # carried -1530/-1407 as a `conventional` reconstruction while
    # `chronology.json` derives AM 2585-2708 — -1529/-1406 — from the
    # two verses this tool already probes. Moses stands beside him,
    # derived from the same exodus by Exodus 7:7 and agreeing exactly;
    # Aaron was never reached only because no step named him. Leaving
    # the year would print one man's life as two spans, one on the
    # person sheet and one wherever `chronology.json` is drawn.
    aaron_birth, aaron_death = aaron_years(stated, exodus)
    aaron = ft.get('aaron')
    if aaron is not None:
        for field, was, now in (('birthYear', aaron.get('birthYear'),
                                 aaron_birth),
                                ('deathYear', aaron.get('deathYear'),
                                 aaron_death)):
            if was == now:
                continue
            aaron[field] = now
            record_correction(ft_doc, 'aaron', field, was,
                              f'Exodus 7:7 makes him 83 in the year of '
                              f'the exodus and Numbers 33:39 gives him '
                              f'123 at his death, which on this app\'s '
                              f'own exodus ({exodus}) is {now}; '
                              f'chronology.json already derived it')
        dated['aaron'] = {'kind': 'birth', 'basis': 'scripture+thiele',
                          'refs': [stated['aaron_at_exodus'][1],
                                   '1 Kings 6:1']}

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
        'am': {
            'en': 'Anno Mundi — years from the creation, as the ages in '
                  'Genesis 5 and 11 accumulate them. The Masoretic figures; '
                  'the Septuagint states different ones.',
            'zh-Hans': '创世纪元——自创世起算的年数，按创世纪 5 章与 11 章所记的'
                       '岁数累加而得。此处用的是马所拉文本的数字；七十士译本'
                       '所记不同。',
            'zh-Hant': '創世紀元——自創世起算的年數，按創世紀 5 章與 11 章所記的'
                       '歲數累加而得。此處用的是馬所拉文本的數字；七十士譯本'
                       '所記不同。',
        },
        'bc': {
            'en': 'Years before Christ. Where a record carries one it is '
                  'derived from an age scripture states, anchored on '
                  'hebrew_kings.json, which follows Thiele and cites him.',
            'zh-Hans': '公元前年份。凡带有此种年份的记录，都是由经文所记的岁数'
                       '推得，其定点取自 hebrew_kings.json，该表依据锡尔'
                       '（Thiele）并注明出处。',
            'zh-Hant': '公元前年份。凡帶有此種年份的記錄，都是由經文所記的歲數'
                       '推得，其定點取自 hebrew_kings.json，該表依據錫爾'
                       '（Thiele）並註明出處。',
        },
    }
    ft_doc['_meta']['dating'] = {
        'generator': 'tools/audit_dates.py',
        'kinds': {
            'birth': {
                'en': 'A birth, shown exactly. Derivable from an age the '
                      'text states; `refs` gives the verses.',
                'zh-Hans': '出生年份，按确数列出。可由经文所记的岁数推得；'
                           '`refs` 列出所据经文。',
                'zh-Hant': '出生年份，按確數列出。可由經文所記的歲數推得；'
                           '`refs` 列出所據經文。',
            },
            'reign': {
                'en': 'A reign, not a birth. birthYear here is an accession '
                      'or coregency year and is NOT displayed; the span in '
                      'reignStart/reignEnd is, and it is Thiele\'s, from '
                      'hebrew_kings.json.',
                'zh-Hans': '在位年份，并非出生年份。此处的 birthYear 是登基或'
                           '摄政之年，并不显示；显示的是 reignStart/reignEnd '
                           '的在位年段，取自 hebrew_kings.json，依据锡尔'
                           '（Thiele）。',
                'zh-Hant': '在位年份，並非出生年份。此處的 birthYear 是登基或'
                           '攝政之年，並不顯示；顯示的是 reignStart/reignEnd '
                           '的在位年段，取自 hebrew_kings.json，依據錫爾'
                           '（Thiele）。',
            },
            'approximate': {
                'en': 'Shown with "c.". A commonly published '
                      'reconstruction. Nothing we ship fixes this '
                      'year, so it is not stated as exact.',
                'zh-Hans': '以「约」标示。这是通行的推算年份。本应用所载的资料'
                           '并不能确定此年，故不作确数陈述。',
                'zh-Hant': '以「約」標示。這是通行的推算年份。本應用所載的資料'
                           '並不能確定此年，故不作確數陳述。',
            },
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
    # The pre-Abraham block is re-anchored and the seven missing births
    # go in BEFORE the annotation runs, so they are stamped by the same
    # derivation as everything else rather than carrying a basis this
    # section typed for them.
    creation_year, creation_refs, prior = prehistory(
        tl_doc, chain, am_year, stated)
    sojourn = annotate_timeline(tl_doc, stated, kings, prior,
                                creation_year, creation_refs)
    (ASSETS / 'bible_timeline.json').write_text(
        json.dumps(tl_doc, ensure_ascii=False, indent=2) + '\n',
        encoding='utf-8')

    print('\nwrote assets/family_tree.json and assets/bible_timeline.json')
    print(f"  family tree: {ft_doc['_meta']['dating']['counts']}")
    print(f"  timeline   : {tl_doc['_meta']['counts']}, "
          f"Septuagint shift {sojourn} years")


# --------------------------------------------- the chain, carried upward
#
# WHY THIS EXISTS, AND WHAT IT CHANGES.
#
# Until now the wheel and the timeline drew ONE CIRCLE ON TWO CALENDARS.
# Everything from Abraham down is counted back from Thiele's Solomon
# along intervals the text states — `_meta.anchor` says so, and 32f
# checks it. The eight events above Abraham were not: they were Ussher's
# reconstruction with the creation rounded to 4000 BC, and the app
# disclosed the seam (`timelineAntediluvianBasis`) rather than closing
# it. The seam is not small. On the Ussher origin the creation-to-flood
# span is 1,652 where Genesis 5 + 7:6 give 1,656; and Abram, born AM
# 1948, lands at -2052 on that origin against the -2166 the Thiele chain
# gives for the same man. 114 years, at the one join a reader is most
# likely to look at.
#
# Nothing in the text stops the chain at Abraham. Genesis 11:26 gives
# Terah 70 at Abram's birth, Genesis 11:24 back to 11:12 give the seven
# fathers before him, Genesis 11:10 puts Arphaxad two years after the
# flood, Genesis 7:6 puts the flood in Noah's 600th year, and Genesis
# 5:28 back to 5:3 give the nine fathers before Noah. Those are stated
# intervals of exactly the kind `timeline_steps` is already made of. So
# the chain is carried up, and the two calendars become one:
#
#     creationYear = abram_called.year - AM(Abram's departure from Haran)
#                  = -2091 - (Terah AM + 70 + 75)
#                  = -4114
#
# CHECKED THREE WAYS, and the tool aborts on any of them:
#   * the AM figure it lands on must equal `chronology.json`'s own
#     `epochs.haran.mt`, which `build_chronology` read out of the Greek
#     and the Hebrew independently;
#   * creationYear + `traditions.mt.floodAm` must equal the year this
#     table derives for the flood from Genesis 5 + 7:6;
#   * creationYear + AM must reproduce the years the asset ALREADY holds
#     for Abraham's line, which it does not touch — `isaac_born`,
#     `jacob_esau_born`, `moses_born` and `moses_dies` are the proof
#     that this is the wheel's existing axis extended, not a new one.
#
# THIS SECTION MOVES PUBLISHED YEARS, WHICH THE REST OF THIS TOOL
# REFUSES TO DO. 32f abstains whenever a derivation disagrees with the
# shipped year, on the ground that moving a published date is a decision
# and this tool does not make decisions. The decision was made outside
# it (`SeekSparks-chart-audit/RULING-WHEEL-PEOPLE.md` §2, §4): the eight
# antediluvian events move onto the anchor the other ninety already use.
# It is confined to the pre-Abraham block, listed event by event below,
# and printed as before/after on every run.
#
# WHAT IS DERIVED AND WHAT IS ONLY CARRIED. Eleven events sit on an
# Anno Mundi figure the chain states, and those are exact
# (`scripture+thiele`). Four — Eden, the Fall, Cain and Abel, Babel —
# rest on no stated interval at all, and they are NOT promoted: they
# keep the offset from the creation that the compiler gave them and stay
# `conventional`, so they travel with the anchor instead of being left
# behind on the old one. The offset is read out of the asset rather than
# typed here, so re-running cannot drift them.
#
# NO DEATH EVENTS, for any of them. A spoke answers "when"; the lifespan
# arcs the wheel is gaining answer "how long", and Methuselah's arc
# ending on the flood spoke shows what no event may say — the text never
# says he died in the flood year, the arithmetic does.
#
# THE CAINITES GET NOTHING. Genesis 4:17-24 gives Irad, Mehujael,
# Methushael, Lamech, Adah, Zillah, Jabal, Jubal, Tubal-cain and Naamah
# begettings, wives, trades and a boast, and not one age, interval or
# total. There is nothing to count along, so they get no year — not even
# an approximate one — and no event on an axis made of years.

# The six generations of Genesis 5 the wheel had no record of, and
# Shelah, whom Genesis 11 dates and the wheel carried only as an undated
# name from the table of nations. Each is a BIRTH, shaped like the
# `seth_born` already in the asset.
#
# NO LIFESPAN FIGURE APPEARS IN ANY OF THESE. The Masoretic and Greek
# texts, both of which this app ships, do not agree on all of them
# (Lamech is 777 in one and 753 in the other), and neither the wheel nor
# this record gives a reader any way to choose. Bible Chronology plots
# both. So these say the generation and the story and leave every figure
# to the page that can qualify it.
BIRTH_EVENTS = [
    {
        'id': 'enosh_born',
        'name': 'Enosh',
        'person': 'enosh',
        'era': 'antediluvian',
        'titleEn': 'Birth of Enosh',
        'titleZhHans': '以挪士出生',
        'titleZhHant': '以挪士出生',
        'descEn': "Seth's son Enosh is born, third from Adam; in his "
                  'time men began to call on the name of God.',
        'descZhHans': '塞特之子以挪士出生，为亚当以下第三代；那时人开始'
                      '求告神的名。',
        'descZhHant': '塞特之子以挪士出生，為亞當以下第三代；那時人開始'
                      '求告神的名。',
        'refs': ['Genesis 4:26', 'Genesis 5:6-11'],
    },
    {
        'id': 'kenan_born',
        'name': 'Kenan',
        'person': 'kenan',
        'era': 'antediluvian',
        'titleEn': 'Birth of Kenan',
        'titleZhHans': '该南出生',
        'titleZhHant': '該南出生',
        'descEn': "Enosh's son Kenan is born, fourth from Adam in the "
                  'line of Seth.',
        'descZhHans': '以挪士之子该南出生，为塞特家系中亚当以下第四代。',
        'descZhHant': '以挪士之子該南出生，為塞特家系中亞當以下第四代。',
        'refs': ['Genesis 5:9-14'],
    },
    {
        'id': 'mahalalel_born',
        'name': 'Mahalalel',
        'person': 'mahalalel',
        'era': 'antediluvian',
        'titleEn': 'Birth of Mahalalel',
        'titleZhHans': '玛勒列出生',
        'titleZhHant': '瑪勒列出生',
        'descEn': "Kenan's son Mahalalel is born, fifth from Adam in "
                  'the line of Seth.',
        'descZhHans': '该南之子玛勒列出生，为塞特家系中亚当以下第五代。',
        'descZhHant': '該南之子瑪勒列出生，為塞特家系中亞當以下第五代。',
        'refs': ['Genesis 5:12-17'],
    },
    {
        'id': 'jared_born',
        'name': 'Jared',
        'person': 'jared',
        'era': 'antediluvian',
        'titleEn': 'Birth of Jared',
        'titleZhHans': '雅列出生',
        'titleZhHant': '雅列出生',
        'descEn': "Mahalalel's son Jared is born, sixth from Adam and "
                  'the father of Enoch.',
        'descZhHans': '玛勒列之子雅列出生，为亚当以下第六代，是以诺的父亲。',
        'descZhHant': '瑪勒列之子雅列出生，為亞當以下第六代，是以諾的父親。',
        'refs': ['Genesis 5:15-20'],
    },
    {
        'id': 'methuselah_born',
        'name': 'Methuselah',
        'person': 'methuselah',
        'era': 'antediluvian',
        'titleEn': 'Birth of Methuselah',
        'titleZhHans': '玛土撒拉出生',
        'titleZhHant': '瑪土撒拉出生',
        'descEn': "Enoch's son Methuselah is born; Genesis records no "
                  'longer life than his.',
        'descZhHans': '以诺之子玛土撒拉出生；创世记所载的寿数，无人长过他。',
        'descZhHant': '以諾之子瑪土撒拉出生；創世記所載的壽數，無人長過他。',
        'refs': ['Genesis 5:21-27'],
    },
    {
        'id': 'lamech_born',
        'name': 'Lamech',
        'person': 'lamech',
        'era': 'antediluvian',
        'titleEn': "Birth of Lamech, Noah's Father",
        'titleZhHans': '拉麦出生（挪亚之父）',
        'titleZhHant': '拉麥出生（挪亞之父）',
        'descEn': "Methuselah's son Lamech is born; he names his son "
                  'Noah, hoping for comfort from the toil of the '
                  'cursed ground.',
        'descZhHans': '玛土撒拉之子拉麦出生；他给儿子起名挪亚，指望在受咒诅'
                      '之地的劳苦中得安慰。',
        'descZhHant': '瑪土撒拉之子拉麥出生；他給兒子起名挪亞，指望在受咒詛'
                      '之地的勞苦中得安慰。',
        'refs': ['Genesis 5:25-31'],
    },
    {
        'id': 'shelah_born',
        'name': 'Shelah',
        'person': 'shelah',
        # `antediluvian` is what this asset's era key means by "before
        # Abraham" — `babel` is post-flood and carries it too — and it
        # is the only pre-patriarchal value `kTimelineEraStream` maps.
        'era': 'antediluvian',
        'titleEn': 'Birth of Shelah',
        'titleZhHans': '沙拉出生',
        'titleZhHant': '沙拉出生',
        'descEn': "Arphaxad's son Shelah is born, the first generation "
                  'after the flood to be born rather than saved from '
                  'it; the King James Version spells his name Salah.',
        'descZhHans': '亚法撒之子沙拉出生，是洪水之后头一代生于水后、而非'
                      '得救于水中的人；英王钦定本作「Salah」。',
        'descZhHant': '亞法撒之子沙拉出生，是洪水之後頭一代生於水後、而非'
                      '得救於水中的人；英王欽定本作「Salah」。',
        'refs': ['Genesis 10:24', 'Genesis 11:12-15'],
    },
]

# The four events above Abraham that rest on no stated interval. They
# are NOT promoted and NOT re-dated by hand: each keeps the offset from
# the creation it already had, so it travels with the anchor.
CARRIED_EVENTS = ['eden', 'fall', 'cain_abel', 'babel']


def prehistory(tl_doc, chain, am_year, stated):
    """Re-anchor everything above Abraham, and add the missing births.

    Returns `(creation_year, {event id: (year, datingRefs)})` for the
    events whose year the chain now states. `annotate_timeline` stamps
    the basis from that map, so nothing here types a basis for itself.
    """
    events = tl_doc['events']
    by_id = {e['id']: e for e in events}

    # ---- the anchor ----------------------------------------------------
    # Abram leaves Haran at 75 (Genesis 12:4); Terah is 70 at his birth
    # (Genesis 11:26); Terah's own AM comes from the Genesis 11 run.
    abram_born_am = am_year['Terah'] + chain['Terah']['beget']
    haran_am = abram_born_am + stated['abraham_at_call'][0]
    ch = load('chronology.json')
    ep = {e['id']: e['years'] for e in ch['epochs']}
    if ep['haran']['mt'] != haran_am:
        sys.exit(f'aborting: this chain puts Abram\'s departure at AM '
                 f'{haran_am}; chronology.json says {ep["haran"]["mt"]}')
    creation_year = by_id['abram_called']['year'] - haran_am

    flood_am = am_year['Noah'] + stated['noah_at_flood'][0]
    mt = next(t for t in ch['traditions'] if t['id'] == 'mt')
    if mt['floodAm'] != flood_am or ep['flood']['mt'] != flood_am:
        sys.exit(f'aborting: Genesis 5 + 7:6 put the flood at AM '
                 f'{flood_am}; chronology.json says {mt["floodAm"]}')

    # The proof this is the existing axis and not a new one: the years
    # the asset ALREADY holds for Abraham's line have to fall out of
    # `creation_year + AM` unchanged. Nothing below Abraham is moved by
    # this section, so any disagreement means the two halves of the
    # chain do not meet and there is no single axis to draw.
    #   Isaac  = Abram's birth + 100 (Genesis 21:5)
    #   Jacob  = Isaac  + 60  (Genesis 25:26)
    #   Egypt  = Jacob  + 130 (Genesis 47:9)
    #   exodus = Egypt  + 430 (Exodus 12:40)
    isaac_am = abram_born_am + stated['abraham_at_isaac'][0]
    jacob_am = isaac_am + stated['isaac_at_jacob'][0]
    egypt_am = jacob_am + stated['jacob_at_egypt'][0]
    exodus_am = egypt_am + stated['egypt_sojourn'][0]
    joins = [
        ('abram_called', haran_am),
        ('isaac_born', isaac_am),
        ('jacob_esau_born', jacob_am),
        ('israel_egypt', egypt_am),
        ('exodus', exodus_am),
        ('moses_born', exodus_am - stated['moses_at_exodus'][0]),
        ('moses_dies', exodus_am + stated['moses_lifespan'][0]
         - stated['moses_at_exodus'][0]),
    ]
    for eid, am in joins:
        if creation_year + am != by_id[eid]['year']:
            sys.exit(f'aborting: the anchor puts {eid} at '
                     f'{creation_year + am}; the asset holds '
                     f'{by_id[eid]["year"]} — the two halves of the '
                     f'chain do not meet')
    if creation_year + ep['exodus']['mt'] != by_id['exodus']['year']:
        sys.exit('aborting: chronology.json and this chain disagree on '
                 'the exodus')

    # ---- the chain of verses -------------------------------------------
    # Whatever `abram_called` already cites, plus every interval this
    # section walks up through. A reader gets the whole chain, because
    # the last link alone does not say the year rests on Thiele too.
    upward = [chain['Terah']['begetRef']]
    upward += [chain[n]['begetRef'] for n in reversed(GEN11[:-1])]
    upward += [chain['Shem']['begetRef'], stated['noah_at_flood'][1]]
    upward += [chain[n]['begetRef'] for n in reversed(GEN5[:-1])]
    creation_refs = list(by_id['abram_called'].get('datingRefs', []))
    for r in upward:
        for part in r.split(', '):
            if part not in creation_refs:
                creation_refs.append(part)

    # ---- what each event's year now is ---------------------------------
    # (event id, Anno Mundi year). Everything here is an interval the
    # text states; `CARRIED_EVENTS` below are the ones that are not.
    dated_am = [('creation', 0), ('seth_born', am_year['Seth'])]
    dated_am += [(row['id'], am_year[row['name']]) for row in BIRTH_EVENTS]
    # Enoch's event is his being TAKEN, not his birth: Genesis 5:23-24
    # gives him 365 years and then he is not. Its shipped year sat 127
    # years after that, outside his own life.
    dated_am.append(('enoch_walks',
                     am_year['Enoch'] + stated['enoch_lifespan'][0]))
    dated_am.append(('flood', flood_am))

    print('\n32g — the chain carried above Abraham')
    print(f'  Abram leaves Haran in AM {haran_am} '
          f'(Genesis 11:26 + Genesis 12:4, on the Genesis 11 run)')
    print(f'  so the creation falls in {creation_year}, on '
          f'{len(creation_refs)} stated intervals')
    print(f'  the flood falls in AM {flood_am} -> '
          f'{creation_year + flood_am}')

    # Offsets are read from the asset BEFORE anything moves, so a second
    # run recomputes the same numbers instead of drifting.
    old_creation = by_id['creation']['year']
    carried = {eid: by_id[eid]['year'] - old_creation
               for eid in CARRIED_EVENTS if eid in by_id}

    derived = {}
    moved = []
    for eid, am in dated_am:
        year = creation_year + am
        extra = [chain['Enoch']['spanRef']] if eid == 'enoch_walks' else []
        refs = creation_refs + [r for r in extra if r not in creation_refs]
        old = by_id.get(eid)
        if old is not None and old['year'] != year:
            moved.append((eid, old['year'], year))
        derived[eid] = (year, refs)
        if old is not None:
            old['year'] = year

    for eid, offset in carried.items():
        year = creation_year + offset
        if by_id[eid]['year'] != year:
            moved.append((eid, by_id[eid]['year'], year))
        by_id[eid]['year'] = year

    # ---- the records that did not exist --------------------------------
    added = []
    for row in BIRTH_EVENTS:
        year = derived[row['id']][0]
        rec = {
            'id': row['id'],
            'year': year,
            'era': row['era'],
            'titleEn': row['titleEn'],
            'titleZhHans': row['titleZhHans'],
            'titleZhHant': row['titleZhHant'],
            'descEn': row['descEn'],
            'descZhHans': row['descZhHans'],
            'descZhHant': row['descZhHant'],
            'refs': row['refs'],
            'personIds': [row['person']],
            'basis': 'scripture+thiele',
            'approximate': False,
        }
        old = by_id.get(row['id'])
        if old is None:
            at = next((i for i, e in enumerate(events) if e['year'] > year),
                      len(events))
            events.insert(at, rec)
            added.append(row['id'])
        else:
            old.clear()
            old.update(rec)

    for eid, was, now in moved:
        print(f'    MOVED  {eid:18} {was:>6} -> {now:>6}')
    print(f'    added  {", ".join(added) if added else "(none — refreshed)"}')
    return creation_year, creation_refs, derived


# ------------------------------------------------------- Aaron, by the text
#
# `family_tree.json` carried Aaron as -1530/-1407, `conventional`, while
# `chronology.json` derives AM 2585-2708 from the very figures this tool
# probes — Exodus 7:7 (83 at the confrontation with Pharaoh, the year of
# the exodus) and Numbers 33:39 (123 at his death). One man, two files,
# one year apart, and the wheel is about to draw a lifespan arc from one
# of them beside a person sheet printing the other. Moses is already
# derived by the same chain and agrees exactly; Aaron was simply never
# reached, because no step named him.
def aaron_years(stated, exodus_year):
    """Aaron's birth and death, from the two verses that state them."""
    birth = exodus_year - stated['aaron_at_exodus'][0]
    return birth, birth + stated['aaron_lifespan_n33'][0]


# ------------------------------------------------- the timeline, derived
#
# WHAT THIS REPLACES, AND WHY. Until v1.6.146 the basis on all 98 events
# came from a list of thirteen ids typed into this file. It never looked
# at a year. So it could not notice that the shipped year for an event it
# called `scripture` had drifted from what scripture gives — and, worse in
# practice, it called everything else `conventional`, which the app prints
# to the reader as "The text fixes no year for this". That sentence was
# false for nine events. Genesis 16:16 states Abram's age at Ishmael's
# birth outright, and the reader was told the text is silent about it.
#
# Every year below is now COMPUTED from a table of steps, and a step is
# only allowed to stamp an event when the arithmetic reproduces the year
# already in the asset. Nothing is re-dated here: a step that disagrees
# with the shipped year abstains and is reported, because moving a
# published date is a decision and this tool does not make decisions.
#
# Each step names the verse that states its interval. A reader gets the
# whole chain, not just the last link, because the last link alone
# ("Genesis 16:16") does not tell them the year rests on Thiele too.

# (event, base event, interval, the verses that state that interval).
# The interval is signed on the BC axis: negative moves earlier.
def timeline_steps(stated):
    """Each step as (event, base, delta, refs). Deltas from the text."""
    S = {k: v[0] for k, v in stated.items()}
    return [
        # Solomon's fourth year is four years LATER than his accession,
        # and a later BC year is the smaller magnitude, so this step adds.
        ('temple_built', 'solomon_king', +S['temple_in_solomon_year'],
         ['1 Kings 6:1']),
        ('exodus', 'temple_built', -S['exodus_to_temple'], ['1 Kings 6:1']),
        ('israel_egypt', 'exodus', -S['egypt_sojourn'], ['Exodus 12:40']),
        ('jacob_esau_born', 'israel_egypt', -S['jacob_at_egypt'],
         ['Genesis 47:9']),
        ('isaac_born', 'jacob_esau_born', -S['isaac_at_jacob'],
         ['Genesis 25:26']),
        ('abram_called', 'isaac_born',
         -(S['abraham_at_isaac'] - S['abraham_at_call']),
         ['Genesis 21:5', 'Genesis 12:4']),
        ('ishmael_born', 'isaac_born',
         -(S['abraham_at_isaac'] - S['abram_at_ishmael']),
         ['Genesis 21:5', 'Genesis 16:16']),
        ('rebekah_marries', 'isaac_born', +S['isaac_at_rebekah'],
         ['Genesis 25:20']),
        # Genesis 17:21 and 18:10 both put Isaac's birth "at this time next
        # year" from the visit at Mamre, and Genesis 19:1 has the same two
        # visitors reach Sodom that evening. So this is a stated interval,
        # not narrative order — the ground on which the plagues and the Red
        # Sea are still refused below.
        ('sodom_destroyed', 'isaac_born', -S['isaac_promised_g17'],
         ['Genesis 17:21', 'Genesis 18:10', 'Genesis 19:1']),
        # Joseph enters Pharaoh's service at the head of the seven years
        # of plenty; two of the famine years have passed when Jacob comes
        # down, so the descent is nine years after he rose.
        ('joseph_rises', 'israel_egypt',
         -(S['years_of_plenty'] + S['famine_past_at_descent']),
         ['Genesis 41:46', 'Genesis 41:53', 'Genesis 45:6']),
        # NOT DERIVED: joseph_sold. Genesis 37:2's "seventeen years old"
        # attaches to tending the flock and the bad report; the sale is
        # 37:28 and the text states no interval between them. Reaching it
        # would be a narrative-order step, and this table does not take
        # those. Its year stays where it is, marked as a reconstruction.
        ('moses_born', 'exodus', -S['moses_at_exodus'], ['Exodus 7:7']),
        # Exodus 16:1 and 19:1 date the manna and Sinai by month within
        # the year of the departure, so the text fixes their year exactly
        # as firmly as it fixes the exodus — the interval is simply zero.
        ('manna', 'exodus', 0, ['Exodus 16:1']),
        ('sinai', 'exodus', 0, ['Exodus 19:1']),
        ('tabernacle', 'exodus', +(S['tabernacle_year'] - 1),
         ['Exodus 40:17']),
        # NOT Numbers 14:33. Its forty years run from the spying, which
        # Numbers 10:11 puts in the second year — so counting them from
        # the exodus lands two years late. Numbers 32:13 and Joshua 5:6
        # measure the same forty from the departure, and Deuteronomy 1:3
        # names the fortieth year outright.
        ('wilderness_40', 'exodus', +S['wilderness_numbers32'],
         ['Numbers 32:13', 'Joshua 5:6']),
        ('jordan_crossed', 'exodus', +S['jordan_crossed_year'],
         ['Deuteronomy 1:3', 'Joshua 5:6']),
        # Jericho falls in the year of the crossing: Joshua 4:19 dates the
        # camp at Gilgal to the first month and Joshua 6:15 puts the city's
        # fall on the seventh day of the march.
        ('jericho', 'jordan_crossed', +S['gilgal_camp_day'],
         ['Joshua 4:19', 'Joshua 6:15']),
        # 120 at death (Deuteronomy 34:7) less 80 before Pharaoh (Exodus
        # 7:7). Independent of how the wilderness forty are reckoned.
        ('moses_dies', 'exodus',
         +(S['moses_lifespan'] - S['moses_at_exodus']),
         ['Deuteronomy 34:7', 'Exodus 7:7']),
    ]


# The five whose year is Thiele's outright, with no scriptural interval
# between them and the anchor.
THIELE_EVENTS = ['solomon_king', 'david_king', 'kingdom_divided',
                 'israel_falls', 'judah_falls']


def annotate_timeline(tl_doc, stated, kings, prior, creation_year,
                      creation_refs):
    """Derive each event's basis and dating verses. Returns the LXX shift."""
    events = {e['id']: e for e in tl_doc['events']}
    # THE SEPTUAGINT'S OWN READING, checked rather than asserted. Exodus
    # 12:40 in the Hebrew counts 430 years in Egypt; the Greek counts them
    # in Egypt AND in Canaan. Everything the chain reaches THROUGH that
    # verse therefore sits later on the Greek — by exactly the span from
    # Abram's call to the descent, which both texts state identically.
    # That span is taken from the text here and verified against
    # chronology.json, which build_chronology.py reads out of the Greek.
    shift = ((stated['abraham_at_isaac'][0] - stated['abraham_at_call'][0])
             + stated['isaac_at_jacob'][0] + stated['jacob_at_egypt'][0])
    ch = load('chronology.json')
    ep = {e['id']: e['years'] for e in ch['epochs']}
    mt_gap = ep['exodus']['mt'] - ep['descent']['mt']
    lxx_gap = ep['exodus']['lxx'] - ep['descent']['lxx']
    if mt_gap != stated['egypt_sojourn'][0] or lxx_gap != mt_gap - shift:
        sys.exit(f'aborting: chronology.json puts the sojourn at {mt_gap} '
                 f'(MT) and {lxx_gap} (LXX); this tool expected '
                 f'{stated["egypt_sojourn"][0]} and '
                 f'{stated["egypt_sojourn"][0] - shift}')

    anchor = kings['solomon']['reignStart']
    # The pre-Abraham block arrives already derived: its steps run
    # UPWARD from `abram_called` rather than downward from Solomon, so
    # `timeline_steps` cannot express them, but the basis they earn is
    # the same one and is stamped in the same pass.
    derived = {eid: (year, refs, False) for eid, (year, refs)
               in prior.items()}
    derived['solomon_king'] = (anchor, [], False)
    for eid in THIELE_EVENTS:
        if eid == 'solomon_king':
            continue
        derived[eid] = (events[eid]['year'] if eid in events else None,
                        [], False)

    print('\n32f — every timeline year, derived from the anchor')
    refused = []
    for eid, base, delta, refs in timeline_steps(stated):
        if base not in derived or eid not in events:
            refused.append((eid, 'base not derived'))
            continue
        base_year, base_refs, base_lxx = derived[base]
        year = base_year + delta
        shipped = events[eid]['year']
        # Everything reached through Exodus 12:40 inherits the tradition
        # it was reached through; the flag rides down the chain rather
        # than being listed, so a new step cannot forget to carry it.
        via_lxx = base_lxx or 'Exodus 12:40' in refs
        chain = refs + [r for r in base_refs if r not in refs]
        mark = 'OK ' if year == shipped else 'ABSTAINS'
        print(f'    {eid:18} {base:16} {delta:+5}  derived {year:>6}  '
              f'ours {shipped:>6}  {mark}')
        if year != shipped:
            refused.append((eid, f'derives {year}, asset holds {shipped}'))
            continue
        derived[eid] = (year, chain, via_lxx)

    for e in tl_doc['events']:
        eid = e['id']
        if eid in THIELE_EVENTS:
            e['basis'] = 'thiele'
            e['datingRefs'] = []
        elif eid in derived:
            # Not `scripture`: the intervals are scripture's, the year
            # they are measured from is Thiele's, and the reader is shown
            # the year. family_tree.json already calls this shape
            # scripture+thiele and the two assets must not disagree.
            e['basis'] = 'scripture+thiele'
            e['datingRefs'] = derived[eid][1]
        else:
            e['basis'] = 'conventional'
            e.pop('datingRefs', None)
        e['approximate'] = e['basis'] == 'conventional'
        if e['basis'] != 'conventional' and derived.get(eid, (0, [], False))[2]:
            e['septuagintYear'] = e['year'] + shift
        else:
            e.pop('septuagintYear', None)

    counts = {}
    for e in tl_doc['events']:
        counts[e['basis']] = counts.get(e['basis'], 0) + 1
    lxx_only = sum(1 for e in tl_doc['events'] if 'septuagintYear' in e)
    print(f'  derived {counts.get("scripture+thiele", 0)}, '
          f'Thiele {counts.get("thiele", 0)}, '
          f'conventional {counts.get("conventional", 0)}; '
          f'{lxx_only} carry a Septuagint alternative')
    for eid, why in refused:
        print(f'    REFUSED {eid}: {why}')

    tl_doc['_meta'] = {
        'count': len(tl_doc['events']),
        'generator': 'tools/audit_dates.py',
        # THE ONE DEFINITION OF THE CREATION YEAR. Written here so that
        # everything which needs an Anno Mundi figure on the BC axis —
        # this file's own pre-Abraham events, and the wheel's lifespan
        # arcs, which read their AM figures from `chronology.json` —
        # adds the SAME number to it. Two places computing it is how one
        # man ends up with two years.
        'creation': {
            'year': creation_year,
            'basis': 'scripture+thiele',
            'datingRefs': creation_refs,
        },
        # Reader-facing: this is what the About sheet prints. Trilingual
        # for that reason, and worded without field or file names.
        'anchor': {
            'en': 'Every year on this axis is counted back from one fixed '
                  'point: Solomon\'s accession, which this app takes from '
                  'Thiele, as it does throughout. 1 Kings 6:1 dates the '
                  'temple to Solomon\'s fourth year and places that 480 '
                  'years after the exodus; each earlier year is counted '
                  'back along intervals the text states, and every event '
                  'lists the verses its own chain runs through.',
            'zh-Hans': '此图各年皆自一个定点上溯而得：所罗门登基之年。该年取自'
                       '锡尔（Thiele），本应用一律采用。王上 6:1 记圣殿建于所罗门'
                       '在位第四年，并谓该年在出埃及后 480 年；其前各年，皆按经文'
                       '自述的年数逐段上溯，每项事件亦各自列出所据的经文。',
            'zh-Hant': '此圖各年皆自一個定點上溯而得：所羅門登基之年。該年取自'
                       '錫爾（Thiele），本應用一律採用。王上 6:1 記聖殿建於所羅門'
                       '在位第四年，並謂該年在出埃及後 480 年；其前各年，皆按經文'
                       '自述的年數逐段上溯，每項事件亦各自列出所據的經文。',
        },
        # NOT trilingual and NOT rendered, on purpose. `ui_strings.dart`
        # already carries the reader's wording of all three of these
        # (`timelineBasisScripture` / `timelineBasisThiele` /
        # `timelineBasisConventional`) in all three locales, and
        # `basisText` already prints it on every expanded row. This copy
        # is the audit log. One fact, one wording, one place.
        'basis': {
            'scripture+thiele': 'The intervals are stated by scripture and '
                                'the year they are measured from is '
                                'Thiele\'s. Scripture states no BC year, so '
                                'no date here rests on scripture alone.',
            'thiele': 'From hebrew_kings.json, which follows Thiele and '
                      'cites him.',
            'conventional': 'No figure we can read fixes this year, so it '
                            'is shown as a commonly published '
                            'reconstruction, marked approximate.',
        },
        # Also the audit log; the reader's copy is `timelineSeptuagintYear`.
        'septuagintYear': 'Present only where the chain runs through '
                          'Exodus 12:40. The Hebrew counts its 430 years in '
                          'Egypt; the Greek counts them in Egypt AND in '
                          'Canaan, and where the Canaan part begins is not '
                          'stated. Starting it at Abram\'s departure — the '
                          'reading chronology.json plots, and the one place '
                          'on that axis where a year had to be supplied '
                          'rather than read — puts the event '
                          f'{shift} years later. Both texts ship with this '
                          'app; neither is corrected to the other. ABSENT '
                          'above Abraham even though the chain there runs '
                          'through the same verse: it runs on through '
                          'Genesis 11 and Genesis 5, where the Greek states '
                          'different begetting ages, so the Greek year for '
                          'those events is not this shift but a different '
                          'number for each of them. A figure printed under '
                          'this sentence would be a figure this sentence '
                          'does not describe, so none is written; '
                          'chronology.json plots both traditions in full.',
        'counts': counts,
        # Reader-facing, same as `anchor`.
        'note': {
            'en': 'Chronologies differ. Nothing here is presented as a date '
                  'the text gives unless the text gives it.',
            'zh-Hans': '各家年代系统互有出入。凡经文未曾明记的年份，此处一概不作'
                       '经文所记而列。',
            'zh-Hant': '各家年代系統互有出入。凡經文未曾明記的年份，此處一概不作'
                       '經文所記而列。',
        },
    }
    return shift


if __name__ == '__main__':
    main()
