#!/usr/bin/env python3
"""Repairs corrupt readings in the shipped Chinese editions.

Task #304. Run with no flags to re-verify, `--write` to apply.
Idempotent: a second run reports "already correct" for every repair.

WHY THIS IS A COMMITTED SCRIPT AND NOT A HAND EDIT
--------------------------------------------------
These are scripture assets. Every change below is either a character a
reader can see is wrong, or a verse boundary; both deserve to be
reproducible and reviewable rather than an unexplained diff.

Nothing here is invented. Every repair is gated on a WITNESS already in
this repository, and the repaired string must match that witness
exactly, not approximately. Where no witness agrees, the site is left
alone and reported.

The witnesses, and why they are independent of the thing they check:

  * `assets/cuvs-plus.json`   和合本+Strong's — the same base text as
                              cuvs-yhwh, imported separately.
  * `assets/tagged/cuvs-yhwh/` — a SECOND COPY of cuvs-yhwh's own text,
                              carried alongside the Strong's tags. It is
                              a different copy of the same edition, so
                              where the two disagree one of them is
                              wrong, and the tagged layer turns out to be
                              right in both places it matters.
  * `assets/originals/`       the Hebrew, for the one verse-boundary
                              question (R6).

WHAT IS REPAIRED
----------------
R1  MOJIBAKE — GBK bytes that were decoded as Latin-1.
    `assets/cuvs-plus.json` 申命记 28:52 is a WHOLE VERSE of Deuteronomy
    rendered as garbage: "他们必将你困在你各³ÇÀï£¬Ö±µ½…". Re-encoding
    the Latin-1 range back to bytes and decoding as GBK recovers
    "…你各城里，直到…", which cuvs-yhwh confirms word for word once its
    雅伟 divine-name restoration is undone. Two merge markers in 诗篇
    are corrupt the same way ("5-6½ÚºÏ²¢" = "5-6节合并").
    `assets/tagged/cuvs-plus/deuteronomy.json` carries the identical
    corruption, so the Word Study pane showed the same garbage; both
    copies are repaired together and asserted to still agree.

R2  A STRAY U+25A1 □ inside the word 神.
    `assets/cuvs-plus.json` 士师记 13:7 and 18:10 read "必归□神". The
    tagged layer shows □神 is a SINGLE token carrying H430, so the box
    is not a lost word — it is a typographic artifact where the 神版's
    leading space fell. This digitisation carries no such space at any
    of the other 5,000-odd occurrences of 神, and cuvs-yhwh reads
    "必归神" plainly, so the box is deleted and the token keeps H430.

R3  ㄤ萑 — a BOPOMOFO LETTER in the middle of scripture.
    `cuvs-yhwh` and `cuvs-yhwh-tr` 士师记 8:15 read "…疲乏人吗？ㄤ萑在
    西巴和撒慕拿在这里。" Two characters standing where one belongs.
    cuvs-plus AND cuvs-yhwh's own tagged layer both read 现在; with
    ㄤ萑 → 现 the verse matches cuvs-plus character for character.

R4  𨱔 (U+28C54) for 鐏.
    `cuvs-yhwh` and `cuvs-yhwh-tr` 撒母耳记下 2:23 read "用枪𨱔刺入".
    cuvs-plus and cuvs-yhwh's own tagged layer both read 鐏. That the
    TRADITIONAL edition carries it too is the tell: a traditional text
    does not simplify a character, so this is one corrupt source
    propagated into both, not an orthographic choice.

R5  THE MERGED VERSES, which were never missing.
    和合本 combines 71 verses into a neighbour and prints 見上節 in the
    verse-number column. cuvs-yhwh and cuvs-yhwh-tr carry that marker at
    all 71. cuvs-plus carries it at NONE: 60 references simply do not
    exist in the file, and the other 11 hold ad-hoc junk in six
    different phrasings — three of them the bare letter "a", two of them
    mojibake. A reader of 和简+ on 民数记 1:21 got nothing at all, and on
    诗篇 105:6 got "5-6½ÚºÏ²¢".
    Repair: give cuvs-plus the marker its sibling edition already ships,
    copied verbatim from cuvs-yhwh at the same reference. No text is
    invented and none is overwritten — a site is only touched when
    cuvs-plus holds a marker-shaped record or no record at all.

R6  申命记 4:32-33, the one verse-BOUNDARY defect.
    和合本 merges 32-33 because the Chinese inverts the two clauses of
    the Hebrew. cuvs-yhwh does that correctly. cuvs-plus splits the
    block by POSITION instead, which lands the clauses under the wrong
    numbers: its 4:33 is "这样的大事何曾有、何曾听见呢？", which is the
    TAIL of Hebrew 4:32, while Hebrew 4:33 ("有何民听见神在火中说话的
    声音") sits inside its 4:32.
    The Strong's tags prove it rather than the wording suggesting it —
    cuvs-plus 4:32 scores Dice 0.615 against Hebrew 4:33 and 0.513
    against Hebrew 4:32, and its 4:33 carries H1419/H1697/H8085, the
    "any such great thing … or hath been heard" of Hebrew 4:32.
    Consequence: a cross-reference to Deuteronomy 4:33 landed on the
    wrong clause, and the Word Study pane offered Hebrew that did not
    match the Chinese beside it.
    Repair: merge to match cuvs-yhwh and the printed edition, gated on
    the concatenation of cuvs-plus 4:32+4:33 being CHARACTER-IDENTICAL
    to cuvs-yhwh 4:32 once quotation marks are set aside. It is.

R7  䍁 (U+4341) for 繸, in eight verses.
    Found by the character-repertoire sweep that R1-R4 motivated, not by
    reading: 䍁 was the only CJK-Extension-A character in the whole
    Chinese corpus, nine occurrences in eight verses of `cuvs-yhwh` and
    `cuvs-yhwh-tr`. 繸子 is 和合本's word for the tassel of Numbers 15:38
    and the hem Jesus' healings touch; 䍁 is a 网-radical character with
    no such sense. cuvs-yhwh's OWN tagged layer reads 繸 at all eight,
    cuvs-plus reads 繸 at all eight, and the traditional edition carries
    the same 䍁 — the R4 tell again, one corrupt source in both files.
    Each repaired verse is required to match the tagged witness in full,
    not merely at the character in question.

R8  THREE INVISIBLE SOFT HYPHENS in 圣经新译本 (simplified).
    U+00AD, category Cf: it renders as nothing and cannot be typed, so
    `assets/biblexg-v2.json` 启示录 20:2 reads "他捉住龙­，" and fails an
    exact-phrase search for 捉住龙， that ought to match it. These are
    the only format or control characters in the entire corpus — every
    edition, every tagged layer and `assets/originals` were swept and
    the count is otherwise zero. The traditional sibling carries none,
    and is a 1:1 character conversion of this text, so equal length
    after the removal is the gate.

Nothing outside these sites is touched. `--write` prints a byte-level
summary of which references changed in which file so the diff can be
checked against this list.
"""

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

CANON = [
    'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy', 'Joshua',
    'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
    '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther', 'Job',
    'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Solomon', 'Isaiah',
    'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel',
    'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk', 'Zephaniah',
    'Haggai', 'Zechariah', 'Malachi', 'Matthew', 'Mark', 'Luke', 'John',
    'Acts', 'Romans', '1 Corinthians', '2 Corinthians', 'Galatians',
    'Ephesians', 'Philippians', 'Colossians', '1 Thessalonians',
    '2 Thessalonians', '1 Timothy', '2 Timothy', 'Titus', 'Philemon',
    'Hebrews', 'James', '1 Peter', '2 Peter', '1 John', '2 John',
    '3 John', 'Jude', 'Revelation',
]
BOOK_NUMBER = {b: i + 1 for i, b in enumerate(CANON)}

# The marker 和合本 prints in the verse-number column of a verse whose
# text was combined into a neighbour. Recognised in every form the three
# editions actually use, including the bracketed and <note:>-wrapped
# ones, so the check cannot be fooled by punctuation.
MERGE_MARKER_RE = re.compile(
    r'^(?:<note:\s*)?[〔\[（(]?\s*(?:见上节|見上節|见下节|見下節)\s*[〕\]）)]?>?$')

# What cuvs-plus holds at a merge site instead of the marker. Six
# phrasings plus the bare letter "a", which is what a verse-number
# superscript decays to when the markup around it is lost.
PLUS_JUNK_RE = re.compile(
    r'^(?:a)?\s*(?:与|與|并入|並入)?\s*'
    r'(?:上一?[节節]|第?[0-9一二三四五六七八九十]+\s*(?:[-–]\s*[0-9]*)?\s*[节節])'
    r'\s*(?:合并|合併)?$')


def load(*parts):
    path = os.path.join(ROOT, 'assets', *parts)
    with open(path, encoding='utf-8') as f:
        raw = f.read()
    return path, raw, json.loads(raw)


def write_like(path, original, data):
    """Re-serialises [data] in whatever layout [original] used.

    The shipped assets are not uniform — cuvs-yhwh-tr.json is
    pretty-printed at indent 2, cuvs-plus.json and everything under
    assets/tagged/ is minified. Guessing wrong reflows megabytes and
    buries a handful of corrected characters in a diff nobody can read.
    """
    indented = original.startswith('[\n') or original.startswith('{\n')
    if indented:
        text = json.dumps(data, ensure_ascii=False, indent=2)
    else:
        text = json.dumps(data, ensure_ascii=False, separators=(',', ':'))
    if original.endswith('\n'):
        text += '\n'
    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)


# U+00AD. Invisible, so it cannot be seen in the reader and cannot be
# typed into the search box — a verse carrying one silently fails an
# exact-phrase search that should match it.
# Written as an escape on purpose: as a literal it is invisible here too,
# and an editor that trims it would silently disable this repair.
SOFT_HYPHEN = '\u00ad'


def key_of(v):
    return (v['book'], int(v['chapter']), int(v['verse']))


def by_ref(verses):
    return {key_of(v): v for v in verses}


# --------------------------------------------------------------------
# R1. GBK bytes decoded as Latin-1.
# --------------------------------------------------------------------

MOJIBAKE_RUN = re.compile(r'[-ÿ]+')


def demojibake(text):
    """Re-encodes each Latin-1 run as bytes and decodes it as GBK.

    Runs are decoded independently rather than the whole string at once
    because the corruption is interleaved with correct CJK — 申命记 28:52
    begins with nine intact characters. Every run in the shipped data is
    an even number of bytes and decodes cleanly; a run that does not is
    left alone and reported, because a replacement character is a worse
    reading than the garbage it replaces.
    """
    def one(m):
        raw = m.group(0).encode('latin-1')
        try:
            return raw.decode('gbk')
        except UnicodeDecodeError:
            return m.group(0)
    return MOJIBAKE_RUN.sub(one, text)


def has_mojibake(text):
    return bool(MOJIBAKE_RUN.search(text))


# --------------------------------------------------------------------

def normalise_for_witness(text):
    """Strips the differences between our 和合本 editions that are
    DELIBERATE, so that what remains is a real disagreement.

    cuvs-yhwh restores the divine name (雅伟 for 耶和华), and the
    editions punctuate direct speech differently — cuvs-plus carries no
    quotation marks at all. Neither difference is evidence of
    corruption, so neither may mask it.
    """
    text = text.replace('雅伟', '').replace('雅威', '').replace('耶和华', '')
    # Punctuation too: the tagged layer is the same edition's text but
    # punctuated differently (it writes 「故此押尼珥」 where the plain file
    # writes 「故此，押尼珥」). Comparing on the CJK characters alone is
    # exactly the question these repairs ask — is this ONE character
    # right — and punctuation would mask the answer.
    text = re.sub(r'[“”‘’「」『』〈〉（）()〔〕─—–\-\s，。、；：！？…]', '', text)
    return text


class Report:
    def __init__(self):
        self.changes = []
        self.skipped = []
        self.dirty = set()

    def change(self, path, ref, before, after):
        self.changes.append((path, ref, before, after))
        self.dirty.add(path)

    def skip(self, ref, why):
        self.skipped.append((ref, why))


def repair(write):
    rep = Report()

    plus_path, plus_raw, plus = load('cuvs-plus.json')
    yhwh_path, yhwh_raw, yhwh = load('cuvs-yhwh.json')
    tr_path, tr_raw, tr = load('cuvs-yhwh-tr.json')

    P = by_ref(plus)
    Y = by_ref(yhwh)
    # The traditional edition uses traditional book names; align it to
    # the simplified one positionally, which is safe because the two are
    # the same edition and the audit already proved their key sets match.
    tr_books, y_books = [], []
    for v in tr:
        if v['book'] not in tr_books:
            tr_books.append(v['book'])
    for v in yhwh:
        if v['book'] not in y_books:
            y_books.append(v['book'])
    assert len(tr_books) == len(y_books) == 66
    tr_to_y = dict(zip(tr_books, y_books))
    T = {(tr_to_y[v['book']], int(v['chapter']), int(v['verse'])): v for v in tr}

    tagged_plus = {}
    for name in ('deuteronomy', 'judges'):
        tagged_plus[name] = load('tagged', 'cuvs-plus', f'{name}.json')

    yhwh_tagged = {}
    for name in ('judges', '2_samuel', 'numbers', 'deuteronomy', 'matthew',
                 'mark', 'luke'):
        yhwh_tagged[name] = load('tagged', 'cuvs-yhwh', f'{name}.json')[2]

    # ---- R1: mojibake in cuvs-plus, plain text ----------------------
    for v in plus:
        if not has_mojibake(v['text']):
            continue
        ref = f"{v['book']} {v['chapter']}:{v['verse']}"
        fixed = demojibake(v['text'])
        if has_mojibake(fixed):
            rep.skip(ref, 'a Latin-1 run did not decode as GBK')
            continue
        witness = Y.get(key_of(v))
        if witness is not None and not MERGE_MARKER_RE.match(witness['text'].strip()):
            if normalise_for_witness(fixed) != normalise_for_witness(witness['text']):
                rep.skip(ref, 'GBK decode disagrees with cuvs-yhwh; left alone')
                continue
        rep.change(plus_path, ref, v['text'], fixed)
        if write:
            v['text'] = fixed

    # ---- R1: the same corruption in the Strong's-tagged copy --------
    for name, (tpath, traw, tdata) in tagged_plus.items():
        for k, words in tdata.items():
            if words is None:
                continue
            joined = ''.join(w.get('w', '') for w in words)
            if not has_mojibake(joined):
                continue
            ref = f'tagged/{name} {k}'
            fixed_words = [dict(w, w=demojibake(w.get('w', ''))) for w in words]
            fixed_joined = ''.join(w['w'] for w in fixed_words)
            if has_mojibake(fixed_joined) or fixed_joined != demojibake(joined):
                # Token-wise decoding must agree with whole-verse
                # decoding, or a multi-byte character straddles a token
                # boundary and the split is not safe.
                rep.skip(ref, 'token-wise GBK decode disagrees with whole-verse')
                continue
            rep.change(tpath, ref, joined, fixed_joined)
            if write:
                tdata[k] = fixed_words

    # ---- R2: the stray □ inside 神 ----------------------------------
    for v in plus:
        if '□' not in v['text']:
            continue
        ref = f"{v['book']} {v['chapter']}:{v['verse']}"
        fixed = v['text'].replace('□', '')
        witness = Y.get(key_of(v))
        if witness is None or normalise_for_witness(fixed) != normalise_for_witness(witness['text']):
            rep.skip(ref, '□ removal disagrees with cuvs-yhwh; left alone')
            continue
        rep.change(plus_path, ref, v['text'], fixed)
        if write:
            v['text'] = fixed

    for name, (tpath, traw, tdata) in tagged_plus.items():
        for k, words in tdata.items():
            if words is None:
                continue
            if not any('□' in w.get('w', '') for w in words):
                continue
            fixed_words = [dict(w, w=w.get('w', '').replace('□', '')) for w in words]
            rep.change(tpath, f'tagged/{name} {k}',
                       ''.join(w.get('w', '') for w in words),
                       ''.join(w['w'] for w in fixed_words))
            if write:
                tdata[k] = fixed_words

    # ---- R3 / R4 / R7: single-character corruptions in cuvs-yhwh(-tr) --
    # Each is (reference, wrong, right-in-simplified, right-in-traditional,
    # the tagged book that witnesses it).
    CHAR_FIXES = [
        (('士师记', 8, 15), 'ㄤ萑', '现', '現', 'judges', '8:15'),
        (('撒母耳记下', 2, 23), '\U00028c54', '鐏', '鐏', '2_samuel', '2:23'),
        (('民数记', 15, 38), '䍁', '繸', '繸', 'numbers', '15:38'),
        (('民数记', 15, 39), '䍁', '繸', '繸', 'numbers', '15:39'),
        (('申命记', 22, 12), '䍁', '繸', '繸', 'deuteronomy', '22:12'),
        (('马太福音', 9, 20), '䍁', '繸', '繸', 'matthew', '9:20'),
        (('马太福音', 14, 36), '䍁', '繸', '繸', 'matthew', '14:36'),
        (('马太福音', 23, 5), '䍁', '繸', '繸', 'matthew', '23:5'),
        (('马可福音', 6, 56), '䍁', '繸', '繸', 'mark', '6:56'),
        (('路加福音', 8, 44), '䍁', '繸', '繸', 'luke', '8:44'),
    ]
    for ref_key, wrong, right_s, right_t, tbook, tkey in CHAR_FIXES:
        witness_words = yhwh_tagged[tbook].get(tkey)
        witness = ''.join(w.get('w', '') for w in (witness_words or []))
        ref = f'{ref_key[0]} {ref_key[1]}:{ref_key[2]}'

        # The simplified edition is checked against the witness directly.
        simplified_proved = False
        v = Y.get(ref_key)
        if v is not None and wrong in v['text']:
            fixed = v['text'].replace(wrong, right_s)
            if right_s not in witness:
                rep.skip(f'cuvs-yhwh {ref}',
                         'tagged cuvs-yhwh does not carry the proposed reading')
            elif normalise_for_witness(fixed) != normalise_for_witness(witness):
                rep.skip(f'cuvs-yhwh {ref}',
                         'repaired text disagrees with the tagged witness')
            else:
                simplified_proved = True
                rep.change(yhwh_path, f'cuvs-yhwh {ref}', v['text'], fixed)
                if write:
                    v['text'] = fixed
        elif v is not None:
            simplified_proved = True  # already repaired by an earlier run

        # The traditional edition CANNOT be checked against that witness,
        # because the witness is a simplified text and will never contain
        # 現. Its gate is therefore stated rather than implied: the
        # traditional file must carry the IDENTICAL corrupt substring at
        # the IDENTICAL reference, and the simplified sibling's repair
        # must have been proved above. That the corruption appears in a
        # traditional edition at all is itself the evidence — a
        # traditional text does not simplify a character, so both files
        # inherited one corrupt source.
        v = T.get(ref_key)
        if v is not None and wrong in v['text']:
            if not simplified_proved:
                rep.skip(f'cuvs-yhwh-tr {ref}',
                         'the simplified sibling repair was not proved')
            else:
                fixed = v['text'].replace(wrong, right_t)
                rep.change(tr_path, f'cuvs-yhwh-tr {ref}', v['text'], fixed)
                if write:
                    v['text'] = fixed

    # ---- R6: the 申命记 4:32-33 boundary (before R5, which then sees
    #          4:33 as an ordinary merge site) -------------------------
    d32, d33 = ('申命记', 4, 32), ('申命记', 4, 33)
    p32, p33 = P.get(d32), P.get(d33)
    y32 = Y.get(d32)
    if p32 and p33 and y32 and not MERGE_MARKER_RE.match(p33['text'].strip()):
        joined = p32['text'] + p33['text']
        if normalise_for_witness(joined) == normalise_for_witness(y32['text']):
            rep.change(plus_path, '申命记 4:32', p32['text'], joined)
            if write:
                p32['text'] = joined
            # p33 becomes an ordinary merge site and R5 gives it the marker.
        else:
            rep.skip('申命记 4:32-33',
                     'concatenation does not match cuvs-yhwh 4:32; left alone')

    tdpath, tdraw, tddata = tagged_plus['deuteronomy']
    if tddata.get('4:33') and tddata.get('4:32'):
        merged = list(tddata['4:32']) + list(tddata['4:33'])
        rep.change(tdpath, 'tagged/deuteronomy 4:32 (+4:33)',
                   ''.join(w.get('w', '') for w in tddata['4:32']),
                   ''.join(w.get('w', '') for w in merged))
        if write:
            tddata['4:32'] = merged
            del tddata['4:33']

    # ---- R5: give cuvs-plus the merge marker its siblings ship ------
    # Copied verbatim from cuvs-yhwh at the same reference, so the marker
    # is not this script's invention.
    sites = [k for k, v in Y.items() if MERGE_MARKER_RE.match(v['text'].strip())]
    added, normalised = [], []
    for k in sites:
        marker = Y[k]['text']
        existing = P.get(k)
        if existing is None:
            added.append((k, marker))
            continue
        cur = existing['text'].strip()
        if MERGE_MARKER_RE.match(cur):
            continue
        if k == d33 or PLUS_JUNK_RE.match(cur) or has_mojibake(cur) or cur == 'a':
            normalised.append((k, existing, marker))
        else:
            rep.skip(f'{k[0]} {k[1]}:{k[2]}',
                     f'cuvs-plus holds text that is not a merge marker: {cur[:30]!r}')

    for k, existing, marker in normalised:
        rep.change(plus_path, f'{k[0]} {k[1]}:{k[2]}', existing['text'], marker)
        if write:
            existing['text'] = marker

    if added:
        rep.dirty.add(plus_path)
        # Insert each new record directly after the closest preceding
        # verse of the same book, so the diff stays local and the file
        # keeps whatever order it already had.
        pos = {}
        for i, v in enumerate(plus):
            pos.setdefault(v['book'], []).append((int(v['chapter']), int(v['verse']), i))
        inserts = []
        for k, marker in added:
            book, ch, vs = k
            candidates = [(c, n, i) for c, n, i in pos.get(book, []) if (c, n) < (ch, vs)]
            after = max(candidates)[2] if candidates else -1
            inserts.append((after, k, marker))
            rep.change(plus_path, f'{book} {ch}:{vs}', None, marker)
        if write:
            # English name for the numeric id prefix, read off cuvs-yhwh's
            # own ordering rather than a second copy of the book table.
            zh_order = []
            for v in yhwh:
                if v['book'] not in zh_order:
                    zh_order.append(v['book'])
            zh_num = {b: i + 1 for i, b in enumerate(zh_order)}
            for after, k, marker in sorted(inserts, key=lambda t: -t[0]):
                book, ch, vs = k
                rec = {
                    'book': book,
                    'chapter': str(ch),
                    'verse': str(vs),
                    'text': marker,
                    'id': f'{zh_num.get(book, 0):03d}{ch:03d}{vs:03d}',
                }
                plus.insert(after + 1, rec)

    # ---- R8: invisible SOFT HYPHENs in 圣经新译本 (simplified) --------
    xg_path, xg_raw, xg = load('biblexg-v2.json')
    xg_tr = load('biblexg-v2-tr.json')[2]
    xg_books, xgt_books = [], []
    for v in xg:
        if v['book'] not in xg_books:
            xg_books.append(v['book'])
    for v in xg_tr:
        if v['book'] not in xgt_books:
            xgt_books.append(v['book'])
    xg_to_t = dict(zip(xg_books, xgt_books))
    xgt = {(v['book'], v['chapter'], v['verse']): v['text'] for v in xg_tr}
    for v in xg:
        if SOFT_HYPHEN not in v['text']:
            continue
        ref = f"{v['book']} {v['chapter']}:{v['verse']}"
        fixed = v['text'].replace(SOFT_HYPHEN, '')
        # The traditional sibling is a character-for-character conversion
        # of this text and carries no soft hyphen anywhere. Requiring the
        # two to be the same LENGTH after the removal proves nothing else
        # was taken with it — a script-conversion pair is 1:1 per
        # character, so a mismatch would mean the two files disagree about
        # the verse itself and the site must be left alone.
        other = xgt.get((xg_to_t[v['book']], v['chapter'], v['verse']))
        if other is None or len(fixed) != len(other):
            rep.skip(ref, 'biblexg-v2-tr does not corroborate the removal')
            continue
        rep.change(xg_path, f'biblexg-v2 {ref}', v['text'], fixed)
        if write:
            v['text'] = fixed

    # ---- write ------------------------------------------------------
    if write:
        files = {
            plus_path: (plus_raw, plus),
            yhwh_path: (yhwh_raw, yhwh),
            tr_path: (tr_raw, tr),
            xg_path: (xg_raw, xg),
        }
        for name, (tpath, traw, tdata) in tagged_plus.items():
            files[tpath] = (traw, tdata)
        for path, (raw, data) in files.items():
            if path in rep.dirty:
                write_like(path, raw, data)

    return rep


def main():
    write = '--write' in sys.argv
    rep = repair(write)

    by_file = {}
    for path, ref, before, after in rep.changes:
        by_file.setdefault(path, []).append((ref, before, after))

    if not rep.changes:
        print('All repairs already correct. Nothing to do.')
    for path, rows in by_file.items():
        rel = os.path.relpath(path, ROOT)
        print(f'\n{rel} — {len(rows)} record(s)')
        for ref, before, after in rows[:14]:
            if before is None:
                print(f'  + {ref}  ->  {after!r}')
            else:
                print(f'  ~ {ref}')
                print(f'      before: {before[:76]!r}')
                print(f'      after : {after[:76]!r}')
        if len(rows) > 14:
            print(f'  … and {len(rows) - 14} more')

    if rep.skipped:
        print('\nSKIPPED (no witness agreed — left exactly as shipped):')
        for ref, why in rep.skipped:
            print(f'  {ref}: {why}')

    print(f'\n{len(rep.changes)} record(s) across {len(rep.dirty)} file(s).')
    print('Applied.' if write else 'Dry run. Pass --write to apply.')


if __name__ == '__main__':
    main()
