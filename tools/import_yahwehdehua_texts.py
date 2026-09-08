#!/usr/bin/env python3
# -*- coding: utf-8 -*-
r"""Build `assets/bsb-yhwh.json` / `assets/asv-yhwh.json` and their tagged
sets from the 雅伟的话 project's own exported SQLite.

    python3 tools/import_yahwehdehua_texts.py [--dry-run] [--db PATH]
    python3 tools/import_yahwehdehua_texts.py --audit-csb

Licence first, as always: `docs/permissions/README.md` holds what may
ship. Both texts here are public domain in their base translation — the
ASV is 1901, the BSB is dedicated to the public domain by its publisher
— and the divine-name reading in each is the ministry's own restoration
work, not a third party's. The script moves text; it does not decide
whether the text may ship.

WHY THIS IS NOT `tools/import_csb.py` WITH A `--version` FLAG
-------------------------------------------------------------
`import_csb.py` reads the site's MariaDB and needs credentials to do it.
This one reads `Yahwehdehua/app/build/bible.db`, the plain SQLite that
project already exports for its own Flutter app, so it needs no
credentials at all and can be run by anyone with a checkout of both
repos. Sharing a file would drag the credential path back in for two
imports that do not need it.

The second reason is that the two sources carry DIFFERENT MARKUP. The
CSB module writes `<CL>`/`<CM>`/`<TS…Ts>`/`<redletter>` and a band of
H99xx placeholder numbers; neither of these two writes any of that, and
both write things the CSB module does not. A single importer would be a
switch statement pretending to be a shared path.

THE SOURCE
----------
`~/Documents/CodingProject/Yahwehdehua/app/build/bible.db`, schema

    versions(code, name_en, name_zh_cn, name_zh_tw, lang, testament,
             has_sn, sn_kind, sort)
    verses(version, book, chapter, verse, text, plain)
    books(seq, code, testament, chapters, name_en, ...)

`bsbys` = "BSB (Yahweh)", `asvs` = "ASV (Yahweh)". 31,102 rows each, 66
books each, and the naming is explained in that repo's
`tools/export-app-db.py` VERSIONS table.

**`plain` IS NOT USED.** It is the site's own search column and it is
wrong for `bsbys`: the footnote body is concatenated into the running
text rather than dropped, so Psalm 104:35 reads

    … Bless Yahweh, O my soul. HallelujahHallelujah (H1984+H3050) is
    literally "Praise to Yah"!

Everything below is derived from `text`, and the importer checks its own
output against `plain` at the end so that any OTHER place the two
disagree has to be looked at rather than inherited.

THE MARKUP, COUNTED, AND WHAT IT BECOMES
----------------------------------------
Every `<…>` in either text is one of these. The counts are over all
31,102 verses and the mapping is to this app's own conventions
(`lib/utils/scripture_markup.dart`), which are not the source's:

    bsbys                                   asvs
    <WH####>  265,928   <WG####> 115,999    <WH####> 226,459  <WG####> 120,358
    <WH####x>  33,501   <WG####x> 22,132    — none —
    <note>…</note>         209              <i>…</i>            6,641
    <fnote>…</fnote>        28              <cite>…</cite>        116

  * `<WH####>` / `<WG####>` — Strong's, theWord order: the tag comes
    AFTER the text it governs, so a run is the text since the previous
    tag. Becomes `TaggedRun.s`.

  * `<WH####x>` — the SAME number with a trailing `x`, 55,633 of them
    across 2,454 distinct tags, headed by H853x (9,380 — the direct
    object marker אֵת), G3588x (9,212 — the Greek article), H834x and
    G2532x. The `x` marks a lemma that is in the original and has NO
    English word of its own here:

        not to<WH1115> eat<WH398><WH4480x>       מִן, "from"
        Hallelujah<WH1984><WH3050x>              הַלְלוּ + יָהּ

    That is exactly `TaggedRun.i` — implied — and that is where it goes.
    Reading it as an ordinary number instead would put 55,633 runs of
    empty text into the tagged layer, or attach the article's number to
    whatever word happened to precede it. The second reading is checked
    rather than assumed: the fnote at Psalm 104:35 spells out
    "Hallelujah (H1984+H3050)", and H3050 is the one written with `x`.

    `import_csb.py` calls the same suffix "the two malformed tags in the
    module". In THAT module it is two tags and is malformed. Here it is
    systematic, which is why this file does not reuse that reading.

  * `<note>` / `<fnote>` — translator's footnotes ("not in the Hebrew",
    "Yahweh in Hebrew"). Become this app's `<note: …>`, which
    `scripture_markup.dart` lifts out of the reading flow into a marker.
    No body contains `<` or `>`, so the app's `<note:([^>]*)>` scan is
    exact. The two source tags are not distinguished on the way out: the
    app has one kind of footnote, and inventing a second because the
    source spells it two ways would be markup nobody renders.

  * `<i>…</i>` — the ASV's italics, which in a 1901 Bible mean SUPPLIED
    WORDS: text with no counterpart in the Hebrew or Greek. Becomes
    `[…]`, this app's supplied-word convention, rendered set-apart
    rather than deleted. Where the body ENDS in Strong's tags the
    bracket closes before them — `[wife]<WH3947>` rather than
    `[wife<WH3947>]` — so the run boundary the tag cuts is the word and
    not the punctuation.

  * `<cite>…</cite>` — the Psalm superscriptions ("A Psalm of David,
    when he fled from Absalom his son."), which this module folds into
    verse 1 rather than numbering separately. Kept as ordinary leading
    text, which is what `assets/bsb.json` already does with the same
    material.

    Three other treatments were considered and rejected. `<note: …>`
    would call a canonical Hebrew superscription a translator's remark.
    `[…]` would call it a supplied word, which is the opposite claim —
    the superscription is in the source and the ASV translated it.
    Moving it to `assets/section_titles.json` would change what verse 1
    contains relative to the module it came from, which is the one thing
    an importer must not do quietly. None of the 116 carries a Strong's
    number, so nothing is lost by leaving it untagged.

SQUARE BRACKETS THE SOURCE ALREADY WRITES
-----------------------------------------
Both texts contain brackets of their own, and they had to be counted
before `<i>` could be given the same delimiter:

  * bsbys, 200 × `[Yahweh]` and nothing else. This is already this app's
    convention, exactly: `bracketSpanKind` maps the body `Yahweh` to
    `ScriptureSpanKind.divineName` — "the Lord printed here is Yahweh" —
    which is the claim the edition is making. Kept verbatim.

  * asvs, 62 × `[Selah]` and 1 × `[Higgaion. Selah]`. These fall through
    `bracketSpanKind` to `supplied`, so they will render in the italic
    reserved for a translator's insertion, which Selah is not. Left
    alone anyway: they are the source's own brackets, printed Bibles do
    set Selah apart, and the alternative — adding `Selah` to the closed
    token set in `lib/utils/scripture_markup.dart` — would change how
    every other edition renders a word this one happens to bracket. It
    is recorded here so the next person meets a decision rather than a
    surprise.

  * asvs, one orphaned `]]` at John 8:11. The ASV brackets the pericope
    adulterae as doubtful, and the module lost the opening `[[` from
    John 7:53 while keeping the close five verses later. Dropped, and
    the verse is named rather than matched — `\[([^\]]*)\]` needs an
    opener, so leaving it in ships a literal `]]` on the reader's page.

THE SIXTEEN EMPTY VERSES
------------------------
Acts 8:37, Matthew 17:21, Mark 9:44 and thirteen more: Received-Text
verses the critical text does not carry. Both modules store them as
empty rows. They are OMITTED from the asset rather than written as empty
strings, because `assets/bsb.json` already omits exactly these sixteen
(31,086 rows, not 31,102) and `verse_text_absence.dart` is explicit that
an empty string "renders as a blank line and reads as a layout bug
rather than as information". So both files here are 31,086 rows and are
reference-for-reference identical to `assets/bsb.json`.

WHAT THIS IMPORT DOES **NOT** DO: THE THIRD TEXT
------------------------------------------------
`hcsbs` — "CSB (Yahweh)" in the same database — was investigated for
import alongside these two and is NOT imported. `--audit-csb`
recomputes the finding from the source in about twenty seconds:

    verses where the DATABASE reads Yahweh more often
      than `assets/csb.json` already does .................    0
    verses where `assets/csb.json` reads it more often ......  967
    differences not explained by whitespace or by that repair    5

The first number is the one that decides it: **there is not one verse in
31,102 where the database's "CSB (Yahweh)" reads the divine name and the
CSB this app already bundles does not.** The 967 run the other way, and
the five left over are `import_csb.py`'s possessive repair ("sat in the
Lord ’s presence" → "sat in Yahweh’s presence", 2 Sam 7:18) — again the
bundled text being the more correct of the two.

`hcsbs` is the same module `assets/csb.json` was built from, one repair
pass behind: `tools/import_csb.py` restores the divine name in 967
verses where CSB's own small-caps LORD was lost, and this database's
copy has not had that done. There is no separate "CSB (Yahweh)" edition
in here to ship. Importing it would put a second CSB row in the picker
whose only distinguishing property is that it spells the divine name two
ways — "The Lord  our God, the Lord  is one" as the Shema — which is the
outcome `import_csb.py` exists to prevent, and it would present ONE
licensed text as two editions to a reader who has no way to tell.

See `docs/permissions/README.md`, "CSB (Yahweh) — the one that was not
imported", and the note at the end of `lib/constants/bible_versions.dart`
about `cuv-yhwd`, which is the same mistake this avoids.
"""
import argparse
import io
import json
import os
import re
import sqlite3
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
KJV = os.path.join(PROJECT, 'assets', 'kjv.json')
BSB = os.path.join(PROJECT, 'assets', 'bsb.json')
CSB = os.path.join(PROJECT, 'assets', 'csb.json')
DEFAULT_DB = os.path.expanduser(
    '~/Documents/CodingProject/Yahwehdehua/app/build/bible.db')

EXPECTED_ROWS = 31102        # what the database holds
EXPECTED_EMPTY = 16          # the Received-Text verses it holds empty
EXPECTED_VERSES = EXPECTED_ROWS - EXPECTED_EMPTY
EXPECTED_BOOKS = 66

# Strong's itself stops at H8674 / G5624. Neither module writes anything
# above its own ceiling — measured, not assumed: bsbys tops out at H8674
# and G5624, asvs at H8673 and G5624, and NEITHER carries a single tag in
# the H99xx placeholder band the CSB module is full of. So unlike
# `import_csb.py` there is nothing here to drop, and this constant exists
# to make a future source that DOES carry placeholders fail loudly.
MAX_STRONGS = {'H': 8674, 'G': 5624}

# How many verses may legitimately differ from the source's own `plain`
# column once [comparable] has taken the two known formatting
# disagreements out. Every one of them has been read:
#
#   bsbys, 28 — the `<fnote>` verses. `plain` concatenates the footnote
#     BODY into the running text instead of dropping it: Psalm 104:35
#     reads "…HallelujahHallelujah (H1984+H3050) is literally 'Praise to
#     Yah'!" and Song of Solomon 8:6 ends "the fiercest blaze of
#     allother manuscript has 'Yahweh' here." This file is right and
#     `plain` is wrong.
#
#   asvs, 0 — and that is not the same as "the ASV import is clean".
#     Its one real edit, the orphaned `]]` at John 8:11, is INVISIBLE to
#     this witness, because [comparable] removes brackets from both
#     sides and the orphan is a bracket. It is guarded instead by
#     ORPHAN_CLOSE, which stops the import if the `]]` it names is not
#     there to remove. Written down because a zero that looks like proof
#     and is not is worse than a number.
#
# Exact rather than a ceiling. A ceiling would let a re-import trade one
# of these for a defect somewhere else and still pass, which is the only
# failure mode a check like this exists to catch.
EXPECTED_PLAIN_DISAGREEMENTS = {'bsbys': 28, 'asvs': 0}

# code in bible.db -> (this app's version code, asset stem)
IMPORTS = [
    ('bsbys', 'bsb-yhwh'),
    ('asvs', 'asv-yhwh'),
]

# ── markup ──────────────────────────────────────────────────────────
# theWord's Strong's tag. Group 3 is the `x` suffix: the lemma is in the
# original and has no English word of its own here. See the header.
TAG = re.compile(r'<W([HG])(\d+)(x?)>')
NOTE = re.compile(r'<(f?)note>(.*?)</\1note>', re.S)
ITALIC = re.compile(r'<i>(.*?)</i>', re.S)
CITE = re.compile(r'<cite>(.*?)</cite>', re.S)
ANY_TAG = re.compile(r'<[^>]*>')
# Tags riding on the end of an italic body, so the bracket can close
# before them rather than after.
TRAILING_TAGS = re.compile(r'((?:<W[HG]\d+x?>)+)$')
SPACE_BEFORE_PUNCT = re.compile(r'\s+(?=[,.;:!?’”)])')

# The ASV brackets John 7:53-8:11 as doubtful and this module kept only
# the closing half. Named rather than matched: a rule that deleted every
# unmatched `]]` would have no way to know it had found this one.
#
# Keyed by SOURCE as well as by verse. Keying it on the reference alone
# was the first version of this table and it failed on the first run:
# `bsbys` has a John 8:11 too, it has no orphan in it, and the importer
# stopped on the BSB complaining about a defect that belongs to the ASV.
ORPHAN_CLOSE = {('asvs', '043008011'): ']]'}


def open_db(path):
    if not os.path.exists(path):
        sys.exit(f'{path}: not found. Pass --db, or build it in the '
                 '雅伟的话 repo with tools/export-app-db.py.')
    db = sqlite3.connect(path)
    db.text_factory = str
    return db


def book_order(db):
    """(code -> canonical seq, code -> the book name THIS app uses).

    The database's `books.name_en` already spells the names this app's
    assets use, and the two are checked against each other rather than
    one being trusted: `kjv.json`'s 66 books in canonical order must
    equal the database's 66 books in `seq` order, name for name. A
    silent disagreement would file Philemon's text under Philippians and
    every per-book verse count would still add up.
    """
    rows = db.execute(
        'select seq, code, name_en from books order by seq').fetchall()
    if len(rows) != EXPECTED_BOOKS:
        sys.exit(f'the database has {len(rows)} books, not {EXPECTED_BOOKS}')
    db_names = [n for _s, _c, n in rows]

    kjv = json.load(io.open(KJV, encoding='utf-8'))
    kjv_names, seen = [], set()
    for r in kjv:
        if r['book'] not in seen:
            seen.add(r['book'])
            kjv_names.append(r['book'])
    if kjv_names != db_names:
        wrong = [(a, b) for a, b in zip(kjv_names, db_names) if a != b]
        sys.exit(f'kjv.json and the database disagree on book names: {wrong[:5]}')
    return ({c: s for s, c, _n in rows}, {c: n for _s, c, n in rows})


def verse_rows(db, version, seq):
    rows = db.execute(
        'select book, chapter, verse, text, plain from verses where version=?',
        (version,)).fetchall()
    if len(rows) != EXPECTED_ROWS:
        sys.exit(f'{version}: expected {EXPECTED_ROWS} rows, got {len(rows)}')
    rows.sort(key=lambda r: (seq[r[0]], r[1], r[2]))
    return rows


# ── the markup pass ─────────────────────────────────────────────────
def to_app_markup(raw, source, vid):
    """The source's markup rewritten as this app's, tags left in place.

    Runs BEFORE any Strong's tag is consumed, because two of the three
    rewrites move text across tag boundaries and doing it afterwards
    would mean editing run text and hoping the boundaries still meant
    something.
    """
    s = raw
    # A footnote is commentary about the text. Both spellings become the
    # one kind the app renders.
    s = NOTE.sub(lambda m: '<note: %s>' % ' '.join(m.group(2).split()), s)
    # The ASV's italics are supplied words. Close the bracket BEFORE any
    # trailing Strong's tag so the tag still governs the word.
    def _italic(m):
        body = m.group(1)
        tail = TRAILING_TAGS.search(body)
        if tail:
            return '[%s]%s' % (body[:tail.start()], tail.group(1))
        return '[%s]' % body
    s = ITALIC.sub(_italic, s)
    # The Psalm superscription is text, and the module already puts a
    # space after the closing tag.
    s = CITE.sub(lambda m: m.group(1), s)
    orphan = ORPHAN_CLOSE.get((source, vid))
    if orphan:
        if orphan not in s:
            sys.exit(f'{source} {vid}: expected the orphaned {orphan!r} and it is gone '
                     '— re-read the source before trusting this table')
        s = s.replace(orphan, '')
    return s


def split_runs(s, prefix):
    """theWord runs, plus one untagged run per `<note: …>`.

    A note is given a run of its own instead of being left inside the
    text it interrupts. `the LORD<note: not in the Hebrew> God<WH559>`
    is one run under the naive reading, and the note would inherit H559
    — the same defect `scripture_markup.dart` records for the
    Septuagint's `(102:12)` markers, 4,400 of which took the Strong's
    number of the word they were glued to. Splitting first means a note
    can never carry a number, and the verse text is still exactly the
    concatenation of the runs.
    """
    out = []
    for piece in re.split(r'(<note: [^>]*>)', s):
        if not piece:
            continue
        if piece.startswith('<note: '):
            out.append({'w': piece, 's': '', 'i': []})
            continue
        out.extend(_strongs_runs(piece, prefix))
    return out


def _strongs_runs(s, prefix):
    out, cursor, pending = [], 0, []
    for m in TAG.finditer(s):
        seg = s[cursor:m.start()]
        cursor = m.end()
        number = int(m.group(2))
        if number > MAX_STRONGS[prefix]:
            sys.exit(f'{prefix}{number} is above the Strong\'s ceiling — this '
                     'source has grown a placeholder band, adjudicate it')
        pending.append((f'{m.group(1)}{number}', m.group(3) == 'x'))
        if seg == '' and TAG.match(s, cursor):
            # Consecutive tags govern one run between them; collect the
            # numbers rather than emit a run with no text.
            continue
        strongs, implied = _classify(pending)
        pending = []
        if seg == '' and out:
            if strongs:
                out[-1]['i'].append(strongs)
            out[-1]['i'].extend(implied)
            continue
        out.append({'w': seg, 's': strongs, 'i': implied})
    tail = s[cursor:]
    if tail:
        if pending:
            strongs, implied = _classify(pending)
            out.append({'w': tail, 's': strongs, 'i': implied})
        elif out:
            out[-1]['w'] += tail
        else:
            out.append({'w': tail, 's': '', 'i': []})
    elif pending:
        strongs, implied = _classify(pending)
        if out:
            if strongs:
                out[-1]['i'].append(strongs)
            out[-1]['i'].extend(implied)
        else:
            out.append({'w': '', 's': strongs, 'i': implied})
    return out


def _classify(pending):
    """-> (the run's own number, the numbers it only implies).

    The `x` suffix is the source's own statement that the lemma has no
    English word here, so it never becomes `s` however few numbers the
    run has. A run whose tags are ALL `x` therefore carries no `s` at
    all, which is the honest reading: whatever word is in that run is
    not what those numbers render.
    """
    real = [n for n, x in pending if not x]
    implied = [n for n, x in pending if x]
    return (real[0] if real else ''), real[1:] + implied


def tidy(runs):
    """Whitespace per run, never on the joined string.

    Normalising the join would be one line and would silently invalidate
    every boundary the tags were cut at. Cleaning each run and then
    joining means the verse text IS the concatenation of the runs, so
    the plain asset and the tagged asset cannot disagree.
    """
    out = []
    for r in runs:
        w = SPACE_BEFORE_PUNCT.sub('', r['w'])
        w = re.sub(r'[ \t\r\n]+', ' ', w)
        if not w:
            # Numbers riding on whitespace: fold them into the word
            # before rather than emit an empty run.
            if out and (r['s'] or r['i']):
                if r['s']:
                    out[-1]['i'].append(r['s'])
                out[-1]['i'].extend(r['i'])
            continue
        if out and out[-1]['w'].endswith(' ') and w.startswith(' '):
            w = w[1:]
            if not w:
                continue
        out.append({**r, 'w': w})
    if out:
        out[0]['w'] = out[0]['w'].lstrip()
        out[-1]['w'] = out[-1]['w'].rstrip()
    return [r for r in out if r['w']]


def encode(runs):
    """The on-disk shape, empty lists omitted.

    `assets/tagged/bsb/` and `assets/tagged/cuvs-yhwh/` omit `i` and `g`
    when they are empty and `TaggedRun.fromJson` defaults both, so the
    files match their neighbours instead of carrying two empty arrays on
    every run. `g` is never written at all: neither module encodes
    tense, voice or mood, and an always-empty key would suggest it might
    one day not be.
    """
    out = []
    for r in runs:
        d = {'w': r['w'], 's': r['s']}
        if r['i']:
            d['i'] = r['i']
        out.append(d)
    return out


def comparable(text):
    """One verse reduced to what BOTH this file and the database's own
    `plain` column can be expected to say.

    Footnotes go, because `plain` drops `<note>` — correctly — while
    this file turns it into a marker the reader can open. Every square
    bracket goes, from both sides, because the two disagree about
    brackets for reasons that are not defects: `plain` keeps the
    source's own `[Yahweh]` and `[Selah]`, and this file adds 6,704 more
    for the ASV's italics. Comparing with the brackets in reports 279
    differences of which 191 are only that, which buries the 29 that
    mean something.
    """
    s = re.sub(r'<note: [^>]*>', '', text)
    s = s.replace('[', '').replace(']', '')
    return re.sub(r'\s+', ' ', s).strip()


def build(db, source, code, seq, names, report):
    rows = verse_rows(db, source, seq)
    plain, tagged = [], {}
    n_empty = n_notes = n_supplied = n_implied = n_runs = n_tagged = 0
    leftovers = set()
    mismatched = []
    for b, c, v, raw, src_plain in rows:
        book = names[b]
        vid = '%03d%03d%03d' % (seq[b], c, v)
        prefix = 'G' if seq[b] >= 40 else 'H'
        if not raw.strip():
            n_empty += 1
            continue
        s = to_app_markup(raw, source, vid)
        leftovers.update(t for t in ANY_TAG.findall(s)
                         if not TAG.fullmatch(t) and not t.startswith('<note:'))
        runs = tidy(split_runs(s, prefix))
        text = ''.join(r['w'] for r in runs)
        n_notes += text.count('<note: ')
        n_supplied += text.count('[')
        n_runs += len(runs)
        n_tagged += sum(1 for r in runs if r['s'])
        n_implied += sum(len(r['i']) for r in runs)
        plain.append({'book': book, 'chapter': str(c), 'verse': str(v),
                      'text': text, 'id': vid})
        if any(r['s'] for r in runs):
            tagged.setdefault(book, {})[f'{c}:{v}'] = encode(runs)
        # The source's own search column, as an outside witness on all
        # 31,086 verses. It is known to be wrong in a counted set of them
        # — see EXPECTED_PLAIN_DISAGREEMENTS — and anything outside that
        # set is a defect in THIS file, not in the source.
        if comparable(text) != comparable(src_plain):
            mismatched.append((vid, book, c, v, comparable(text),
                               comparable(src_plain)))

    if leftovers:
        sys.exit(f'{source}: unhandled markup {sorted(leftovers)} — refusing '
                 'to write a file with tags in it')
    if n_empty != EXPECTED_EMPTY:
        sys.exit(f'{source}: {n_empty} empty verses, expected {EXPECTED_EMPTY}')
    if len(plain) != EXPECTED_VERSES:
        sys.exit(f'{source}: {len(plain)} verses, expected {EXPECTED_VERSES}')
    expected = EXPECTED_PLAIN_DISAGREEMENTS[source]
    if len(mismatched) != expected:
        sys.exit(f'{source}: {len(mismatched)} verses disagree with the '
                 f"source's own `plain` column, expected {expected}. Every "
                 'one of those has been read; a new one has not. Print them '
                 'with --report and adjudicate before shipping.')

    print(f'== {source} -> {code}')
    print(f'   verses                  : {len(plain)} '
          f'({n_empty} empty rows omitted)')
    print(f'   books                   : {len({r["book"] for r in plain})} '
          f'({len(tagged)} with tagging)')
    print(f'   runs                    : {n_runs} '
          f'({n_tagged} carry a number, {100 * n_tagged / n_runs:.1f}%)')
    print(f'   implied numbers (the x suffix): {n_implied}')
    print(f'   <note: …> emitted       : {n_notes}')
    # Deliberately "square brackets" and not "supplied words": in
    # `bsbys` all 200 of them are the source's own `[Yahweh]` glosses,
    # which are the opposite claim from a supplied word, and a label
    # that said "supplied" would be wrong for one of the two imports.
    print(f'   square brackets in the text: {n_supplied}')
    print(f'   disagrees with the source\'s own `plain`: {len(mismatched)}')
    for m in mismatched[:6]:
        print(f'     {m[1]} {m[2]}:{m[3]}')
        print(f'       here : {m[4][:110]}')
        print(f'       plain: {m[5][:110]}')
    if report:
        with io.open(report, 'a', encoding='utf-8') as f:
            f.write(f'# {source} -> {code}: {len(mismatched)} rows where the '
                    "source's own `plain` column disagrees\n")
            for m in mismatched:
                f.write(f'- {m[1]} {m[2]}:{m[3]}\n  here : {m[4]}\n'
                        f'  plain: {m[5]}\n')
    return plain, tagged


def spot_check(plain):
    by_id = {r['id']: r['text'] for r in plain}
    for label, vid in [('Gen 2:4   ', '001002004'),
                       ('Exod 6:3  ', '002006003'),
                       ('Deut 6:4  ', '005006004'),
                       ('Ps 23:1   ', '019023001'),
                       ('1 Cor 1:31', '046001031')]:
        if vid in by_id:
            print(f'   {label} {by_id[vid][:96]}')


def write(plain, tagged, code):
    out = os.path.join(PROJECT, 'assets', f'{code}.json')
    tagdir = os.path.join(PROJECT, 'assets', 'tagged', code)
    with io.open(out, 'w', encoding='utf-8') as f:
        json.dump(plain, f, ensure_ascii=False, separators=(',', ':'))
    os.makedirs(tagdir, exist_ok=True)
    for book, verses in tagged.items():
        slug = book.lower().replace(' ', '_')
        with io.open(os.path.join(tagdir, f'{slug}.json'), 'w',
                     encoding='utf-8') as f:
            json.dump(verses, f, ensure_ascii=False, separators=(',', ':'))
    total = os.path.getsize(out) + sum(
        os.path.getsize(os.path.join(tagdir, p)) for p in os.listdir(tagdir))
    print(f'   wrote                   : assets/{code}.json + '
          f'assets/tagged/{code}/ ({total / 1e6:.1f} MB)')


def audit_csb(db, seq, names):
    """Why `hcsbs` is not the third import. Recomputed, never quoted.

    The claim being tested is the one that would justify shipping it:
    that the database's "CSB (Yahweh)" is a DIFFERENT EDITION from the
    `csb` this app already bundles. Three numbers settle it, and the
    third is the one that matters — if the two texts differed anywhere
    the divine-name repair does not reach, the claim would survive.
    """
    rows = verse_rows(db, 'hcsbs', seq)
    csb = {r['id']: r['text'] for r in json.load(io.open(CSB, encoding='utf-8'))}
    db_more = asset_more = unexplained = 0
    examples = []
    for b, c, v, _raw, p in rows:
        vid = '%03d%03d%03d' % (seq[b], c, v)
        here = csb.get(vid)
        if here is None:
            continue
        n_db = p.count('Yahweh')
        n_asset = here.count('Yahweh')
        if n_db > n_asset:
            db_more += 1
            if len(examples) < 5:
                examples.append((names[b], c, v, p[:110], here[:110]))
        elif n_asset > n_db:
            asset_more += 1
        # ALL whitespace goes, not just runs of it. The database's
        # `plain` drops `<CM>` and `<CL>` — the CSB module's paragraph
        # and poetic-line breaks — without putting a space where they
        # were, so 771 verses read "…you have done?”And the woman
        # said…". `import_csb.py` maps both to a space, correctly. That
        # is a difference between two renderings of one module, not
        # between two editions, and collapsing every space is the
        # cheapest way to stop it drowning the signal.
        a = re.sub(r'\s+', '', p)
        e = re.sub(r'\s+', '', here)
        if a == e:
            continue
        # The repair itself, and then the stray article it leaves
        # behind. `import_csb.py` also strips the "the" in front of a
        # Yahweh the MODULE restored — "Holy to the Yahweh" (Ex 28:36),
        # "This is the house of the Yahweh God" (1 Chr 22:1) — which is
        # eleven more verses in which the shipping asset is the more
        # correct of the two. They are folded in here rather than
        # reported as unexplained, because "the bundled text is better"
        # is the same answer as "these are one edition", not a different
        # one.
        repaired = re.sub(r'[Tt]heLord|Lord', 'Yahweh', a)
        if repaired == e or re.sub(r'[Tt]he(?=Yahweh)', '', repaired) == e:
            continue
        unexplained += 1
    print('== hcsbs ("CSB (Yahweh)") against the bundled assets/csb.json')
    print(f'   verses where the DATABASE reads Yahweh more often : {db_more}')
    print(f'   verses where the ASSET reads it more often        : {asset_more}')
    print(f'   differences not explained by whitespace or that repair: '
          f'{unexplained}')
    for e in examples:
        print(f'     {e[0]} {e[1]}:{e[2]}\n       db   : {e[3]}\n'
              f'       asset: {e[4]}')
    if db_more == 0:
        print('\n   The database\'s copy is the same module assets/csb.json was\n'
              '   built from, one repair pass behind. There is no separate\n'
              '   "CSB (Yahweh)" edition in here to ship.')
    else:
        print('\n   The database now reads Yahweh somewhere the bundled asset\n'
              '   does not. That is new; adjudicate it before trusting the\n'
              '   note in docs/permissions/README.md.')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--db', default=DEFAULT_DB)
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--report', help='append the `plain`-column disagreements here')
    ap.add_argument('--audit-csb', action='store_true',
                    help='recompute why hcsbs is not imported, and stop')
    args = ap.parse_args()

    db = open_db(args.db)
    seq, names = book_order(db)

    if args.audit_csb:
        audit_csb(db, seq, names)
        return

    for source, code in IMPORTS:
        plain, tagged = build(db, source, code, seq, names, args.report)
        spot_check(plain)
        if args.dry_run:
            print('   dry run — nothing written')
            continue
        write(plain, tagged, code)


if __name__ == '__main__':
    main()
