#!/usr/bin/env python3
"""Import the 雅伟版 MySword modules into SeekSparks assets.

Sources (supplied by the user, cleared for use in this app by the
pastor who publishes them at yahwehdehua.net):

  cuvs+-YHWH.bbl.mybible   和合本【雅伟】简体版＋［附原文编号］
                           修订编辑：孙树民 — Chinese text with a
                           Strong's number after every tagged word.
  bdbthayer.dct.mybible    BDB (Hebrew) + Thayer (Greek) lexicons in
                           Chinese, including the TVM grammar codes.

Why this matters: until now no translation SeekSparks shipped carried
Strong's tagging, so hovering a word in a translation line could only
report the *verse*. BibleWorks reports the *word*, because its
translations ship tagged. This module closes that gap for Chinese — and
because the lexicon is Chinese too, the Chinese column ends up deeper
than BibleWorks' English one for a Chinese reader.

Outputs
  assets/tagged/cuvs-yhwh/<book>.json   {"1:1": [{"w","s","g"}, ...]}
  assets/strongs/bdb_zh.json            Hebrew entries, structured
  assets/strongs/thayer_zh.json         Greek entries, structured

THIS SCRIPT IS NOT THE LAST WORD ON THE TAGGED TEXT. Running it plain
REGRESSES 27 verses across 15 books: `tools/repair_chinese_lookalikes.py`
runs after it and replaces 丶 (U+4E36) with 、 (U+3001) at sites check 26
arbitrated against two outside witnesses, and a bare re-run puts the
lookalike back. The corruption renders perfectly and throws nothing, so
nothing downstream would have told you. Re-run the repair with --write
afterwards, or leave assets/tagged/ alone when only the lexicon is wanted.

Run:  python3 tools/import_yahweh_modules.py <dir-with-unzipped-modules>
"""
import json
import os
import re
import sqlite3
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# MySword book numbers are the plain canonical 1–66. Filenames match the
# existing assets/originals/ layout so the loader is shared.
BOOKS = [
    'genesis', 'exodus', 'leviticus', 'numbers', 'deuteronomy', 'joshua',
    'judges', 'ruth', '1_samuel', '2_samuel', '1_kings', '2_kings',
    '1_chronicles', '2_chronicles', 'ezra', 'nehemiah', 'esther', 'job',
    'psalms', 'proverbs', 'ecclesiastes', 'song_of_solomon', 'isaiah',
    'jeremiah', 'lamentations', 'ezekiel', 'daniel', 'hosea', 'joel',
    'amos', 'obadiah', 'jonah', 'micah', 'nahum', 'habakkuk', 'zephaniah',
    'haggai', 'zechariah', 'malachi',
    'matthew', 'mark', 'luke', 'john', 'acts', 'romans', '1_corinthians',
    '2_corinthians', 'galatians', 'ephesians', 'philippians', 'colossians',
    '1_thessalonians', '2_thessalonians', '1_timothy', '2_timothy', 'titus',
    'philemon', 'hebrews', 'james', '1_peter', '2_peter', '1_john',
    '2_john', '3_john', 'jude', 'revelation',
]

# `<WH7225>` lexical, `<WH8804>` grammar, `<WH853x>` implied-word marker.
#
# 133 of the module's 533,914 codes are damaged — it is hand-edited, and a
# dropped bracket or a doubled prefix is invisible to the editor. A regex
# that only knows the well-formed shape does not skip them, it treats them
# as TEXT: `他若<H518>行恶` printed the code as scripture, and the Chinese
# on either side was glued into one run, so the word's own Strong's number
# described only part of it. Every shape is enumerated in
# docs/DATA-INTEGRITY.md, check 22.
#
# Four alternatives, in order: well delimited (whatever is inside);
# opening bracket present, closing one lost or mistyped as `)` or `"`;
# opening bracket lost; BOTH brackets lost. Matching the damage is what
# stops it printing — whether the number is trustworthy is a separate
# question, below.
#
# The last alternative is the only one that could touch undamaged text, so
# it demands the full `WH`/`WG` prefix, which no Chinese verse and none of
# the 〔…〕 notes contain — the notes carry cross-references like 创10:3,
# digits but never Latin. Jeremiah 34:8 is the one verse that needs it:
# `的仆人WH853x<WH5650>` printed the object marker in the middle of a word.
TAG_RE = re.compile(
    r'<[A-Za-z0-9]*>'
    r'|<[A-Za-z]{0,4}\d+[A-Za-z]?[)"]?'
    r'|[A-Za-z]{1,4}\d+[A-Za-z]?>'
    r'|[Ww][HhGg]\d+[A-Za-z]?')

# A recoverable code: an optional W/H/G prefix, the digits, an optional
# one-letter suffix. `WWH853x`, `wh5921`, `H518` and a bare `3605` all
# normalise to a certain reading. `3WH808`, `WH85x3` and `WG358x8` do not
# — the digits themselves are in doubt — and neither do `V3808`, `WJ3808`
# and `MWH8802`, whose prefix is not a letter this module uses. Those are
# recognised as tags so they stop printing, and their number is DROPPED.
# Under-attribution is recoverable; a wrong Strong's on a word is not.
CODE_RE = re.compile(r'^([WHGwhg]*)(\d+)([A-Za-z]?)$')

# Five codes have a character typed inside them, so no rule can say whether
# it is scripture or a slip. Each is decided against assets/cuvs-yhwh.json,
# the same text without the tagging, and quoted here so the call is auditable.
DAMAGED = {
    '<你们WH935>': '你们<WH935>',  # Nu 15:18 「我所领你们进去的那地」 — 你们 is text
    '<人WH3478>': '人<WH3478>',    # 2Sa 24:1 「又向以色列人发怒」 — 人 is text
    '<W“H4100>': '<WH4100>',       # 2Sa 15:19 「为什么与我们同去呢」 — no 「 there
    '<WH的8687>': '<WH8687>',      # 1Ch 21:17 「行了恶，但这群羊」 — no 的 there
    '<WH873我7>': '',              # Jer 4:22 「愚昧无知的儿女」 — no 我, and 873/7 is unrecoverable
}
# Everything outside a tag that is punctuation-only should not become its
# own hover target — it belongs to the run before it.
PUNCT_ONLY = re.compile(r'^[\s，。；：、？！「」“”‘’（）《》…—·\-,.;:?!\'"()\[\]]+$')

# Strong's proper stops here; above it the numbers are TVM/grammar codes
# in the e-Sword/MySword convention (Hebrew stems & aspects, Greek
# tense-voice-mood). Keeping them separate is what lets the UI print a
# lexical entry and a parsing line rather than mixing them.
LEXICAL_MAX = {'H': 8674, 'G': 5624}


def parse_tagged(scripture, default_kind='H'):
    """`起初<WH7225>，神<WH430>…` → [{'w','s','g','i'}] runs.

    The text is authored as alternating chunks: some Chinese, then the
    group of tags that describes it.

    Picking the right number out of a group is the whole job. In
    `天<WH853x><WH8064>` the `x` suffix marks an IMPLIED word — one the
    original has but the Chinese does not render (H853 is the direct
    object marker אֵת). The word actually on screen is H8064, שָׁמַיִם.
    Taking the first tag would label 天 "direct object marker", which is
    both wrong and the kind of wrong nobody notices until they trust it.

    So: the primary number is the first NON-implied lexical tag;
    implied ones go to `i`, and grammar codes (Hebrew stems/aspects,
    Greek tense-voice-mood, numbered above the lexical range) to `g`.

    Only `x` marks an implied word. 45 damaged codes end in `s` instead,
    and `s` is not the same claim: `厚待<WH3190s>亚伯兰` sits on H3190
    יָטַב, "treat well", which is exactly what 厚待 renders, and where the
    corpus can witness the pairing elsewhere (H3318 出来, H7925 清早,
    H2421 救) it agrees. So `s` is read as a plain lexical tag on the word
    before it, not as an implied one — the reading the evidence supports
    and the one that leaves a visible word tagged rather than bare.
    """
    for bad, good in DAMAGED.items():
        scripture = scripture.replace(bad, good)

    # Split into [text, tag, text, tag, …] preserving order.
    parts = []
    pos = 0

    def text(s):
        # A bracket whose partner was consumed by the tag beside it. The
        # Chinese text never contains one, so anything left is damage.
        s = s.replace('<', '').replace('>', '')
        if s:
            parts.append(('t', s))

    for m in TAG_RE.finditer(scripture):
        if m.start() > pos:
            text(scripture[pos:m.start()])
        pos = m.end()
        code = CODE_RE.match(m.group(0).strip('<>)"'))
        if not code:
            continue  # recognised as a tag, so it cannot print; number dropped
        prefix, digits, suffix = code.group(1).upper(), code.group(2), code.group(3)
        # The prefix names the language where it is present. Where it was
        # lost with the bracket, the testament decides: this module tags the
        # Hebrew Bible with H and the Greek with G, and never mixes them.
        kind = 'H' if 'H' in prefix else 'G' if 'G' in prefix else default_kind
        parts.append(('w', (kind, int(digits), suffix.lower() == 'x')))
    if pos < len(scripture):
        text(scripture[pos:])

    runs = []
    pending = ''
    group = []

    def flush():
        """Emit the pending text with the tag group that follows it."""
        nonlocal pending, group
        text, tags = pending, group
        pending, group = '', []
        if not text and not tags:
            return

        lex = [(k, n, x) for (k, n, x) in tags if n <= LEXICAL_MAX[k]]
        gram = [f'{k}{n}' for (k, n, x) in tags if n > LEXICAL_MAX[k]]

        # Punctuation-only (or empty) text owns nothing; fold it back so
        # the reader never hovers a comma.
        if not text.strip() or PUNCT_ONLY.match(text):
            if runs:
                runs[-1]['w'] += text
                if gram:
                    runs[-1].setdefault('g', []).extend(gram)
                for (k, n, x) in lex:
                    runs[-1].setdefault('i', []).append(f'{k}{n}')
            elif text:
                runs.append({'w': text, 's': ''})
            return

        # Leading punctuation belongs to the run before, not this word.
        lead = re.match(r'^[\s，。；：、？！「」“”‘’（）《》…—·\-,.;:?!\'"()\[\]]+', text)
        if lead and runs:
            runs[-1]['w'] += lead.group(0)
            text = text[lead.end():]

        primary = ''
        implied = []
        for (k, n, x) in lex:
            code = f'{k}{n}'
            if not x and not primary:
                primary = code
            else:
                implied.append(code)
        if not primary and implied:
            # Every tag was implied — the first is still the best guess
            # at what this text renders.
            primary, implied = implied[0], implied[1:]

        run = {'w': text, 's': primary}
        if implied:
            run['i'] = implied
        if gram:
            run['g'] = gram
        runs.append(run)

    for kind, val in parts:
        if kind == 't':
            # New text closes the previous text+tags pair.
            if group:
                flush()
            pending += val
        else:
            group.append(val)
    flush()
    return runs


def import_bible(db_path, out_dir):
    con = sqlite3.connect(db_path)
    by_book = {}
    for book, ch, vs, text in con.execute(
            'select Book, Chapter, Verse, Scripture from bible'):
        if not (1 <= book <= 66):
            continue
        by_book.setdefault(book, {})[f'{ch}:{vs}'] = parse_tagged(
            text or '', 'H' if book <= 39 else 'G')
    con.close()

    os.makedirs(out_dir, exist_ok=True)
    total = tagged = 0
    for book, verses in sorted(by_book.items()):
        name = BOOKS[book - 1]
        with open(os.path.join(out_dir, name + '.json'), 'w',
                  encoding='utf-8') as fh:
            json.dump(verses, fh, ensure_ascii=False, separators=(',', ':'))
        for runs in verses.values():
            for r in runs:
                total += 1
                if r.get('s'):
                    tagged += 1
    print(f'  bible: {len(by_book)} books, {total} runs, '
          f'{tagged} tagged ({100.0 * tagged / total:.1f}%)')


def clean_lines(html):
    """MySword entries are <p>-per-VISUAL-line. Keep the lines, drop markup.

    The `<p>`s are NOT one per field. The module breaks its prose across
    them wherever the printed page broke, so a single logical field can
    arrive as two, three, once nine `<p>` elements. Reassembling them is
    `split_entry`'s job; this function only strips the markup.
    """
    s = re.sub(r'(?i)</p\s*>', '\n', html or '')
    s = re.sub(r'<[^>]+>', '', s)
    s = s.replace('&nbsp;', ' ').replace('&amp;', '&')
    s = s.replace('&lt;', '<').replace('&gt;', '>')
    return [ln.strip() for ln in s.split('\n') if ln.strip()]


# A numbered sense opens a new logical unit. The module's hierarchy is
# `1)`, `1a)`, `1a1)`, `1a1a)`, `1a1a1)` — 30,479 markers, all
# digit-initial — plus six letter-initial ones (`a)`, `b)`, `ac)`).
# Getting this regex WRONG is worse than the defect it repairs: a first
# draft matched only `\d+[a-z]?\d*\)` and would therefore have read
# `1a1d)` and `1c2d)` as continuation prose and glued two distinct
# senses into one. Enumerated from the data, not assumed.
SENSE_RE = re.compile(r'^(?:\d+[a-z0-9]*|[a-z])\)')

# The KJV-usage line is `钦定本 - word N, word M, …; TOTAL`, and that
# trailing total is what makes this block self-terminating: we can stop
# on evidence rather than on a guess about where the prose ends. 14,159
# of the 14,187 entries that have the line end it this way (28 use a
# comma before the total, or omit it on a one-word entry — hence the
# `[;,]`). Stopping EARLY only leaves the old truncation in place;
# running ON glues a proper-name gloss into a word-frequency list, so
# the conservative failure is the one this regex chooses.
USAGE_TOTAL_RE = re.compile(r'[;,]\s*\d+\s*$')

# `钦定本 - ` glued to the end of the etymology with no break at all.
# Exactly two entries, and one of them is G3588 ὁ, the commonest word in
# the Greek New Testament. The dash is what makes this safe: seven other
# entries mention 钦定本 in running prose (`钦定本译作"底甲之子"`), and
# none of those is followed by a dash and a count list.
USAGE_HEAD_RE = re.compile(r'(?<=.)(?=钦定本\s*-\s)')


def _join(a, b):
    """Rejoin two halves of one wrapped line.

    The module's line breaks fall mid-clause, so the halves need a space
    — except where the continuation opens with punctuation that must sit
    tight against the word before it (`使尽浑身解数` + `, 通常是徒劳的`).
    """
    if not a:
        return b
    return a + b if b[:1] in ',，。;；:：)）」”、' else a + ' ' + b


def split_entry(lines):
    """`[visual line, …]` → `(lemma, translit, etymology, usage, senses)`.

    The shape the module intends is lemma / transliteration / etymology /
    KJV usage / numbered senses, and the first importer read it
    positionally: line 2 is the etymology, line 3 is the usage if it
    starts with 钦定本. That holds for the 13,724 entries whose etymology
    happens to occupy one visual line and breaks for the rest, in three
    ways at once — the etymology was truncated at the break, the usage
    field was then MISSING because line 3 was the etymology's second
    half, and both tails were served to the reader as numbered senses.

    So find the fields by their own markers instead of by their index:
    the usage block is announced by 钦定本 and closed by its own total,
    and everything between the transliteration and that announcement is
    the etymology however many lines it took.

    What this deliberately does NOT do: rejoin wrapped SENSES. 1,514
    lines inside sense blocks are not numbered, and they are a mixture of
    genuine wrap continuations (`…在神毁灭所多玛` + `时被神的使者救出`)
    and standalone annotations that were always their own line
    (`专有名词, 阳性`, `其同义词, 见 5859`). Nothing in the markup tells
    the two apart, and gluing a part-of-speech tag onto the end of a
    sense would state something the lexicon does not. They stay as
    separate lines, which is how the entry pane already prints them.
    """
    lemma = unicodedata.normalize('NFC', lines[0]) if lines else ''
    translit = lines[1] if len(lines) > 1 else ''

    body = []
    for ln in lines[2:]:
        body.extend(p for p in USAGE_HEAD_RE.split(ln) if p)

    head = next((i for i, ln in enumerate(body)
                 if ln.startswith('钦定本')), None)
    if head is None:
        # No usage line anywhere — 10 entries, each damaged at source.
        # Without the 钦定本 announcement there is nothing to say where
        # the etymology stops, so fall back to the positional reading
        # rather than guess. Joining the whole body instead looked
        # tidier and was worse: H2194's five numbered senses are on
        # their own lines already, and swallowing them into the
        # etymology would have emptied its sense list to repair a wrap
        # it does not have.
        return lemma, translit, body[0] if body else '', '', body[1:]

    etymology = ''
    for ln in body[:head]:
        etymology = _join(etymology, ln)

    usage = body[head]
    i = head + 1
    while (i < len(body)
           and not USAGE_TOTAL_RE.search(usage)
           and not SENSE_RE.match(body[i])
           and not body[i].startswith('钦定本')):
        usage = _join(usage, body[i])
        i += 1

    senses = body[i:]
    # G3588 and G3816 had their senses typed onto the end of the usage
    # line with no break. The module's own convention says the usage ends
    # at its total, so anything numbered after that total is a sense.
    # The space before the marker is optional because G3816 reads
    # `…young man 1; 241) 男孩` — its counts sum to 24, so the total is 24
    # and `1)` opens the senses. Greedy `\d+` takes `241`, fails to find a
    # marker, and backtracks to the reading that parses.
    tail = re.search(r'[;,]\s*\d+\s*((?:\d+[a-z0-9]*|[a-z])\).*)$', usage)
    if tail:
        senses = [tail.group(1)] + senses
        usage = usage[:tail.start(1)].rstrip()
    return lemma, translit, etymology, usage, senses


def import_lexicon(db_path, out_dir):
    con = sqlite3.connect(db_path)
    heb, grk = {}, {}
    for word, data in con.execute('select word, data from dictionary'):
        if not word or word[0] not in 'HG':
            continue
        lines = clean_lines(data)
        if not lines:
            continue
        num = int(re.sub(r'\D', '', word) or 0)
        entry = {}
        if num > LEXICAL_MAX[word[0]]:
            # Grammar code: no lemma, just the parsing description.
            entry['p'] = lines
        else:
            # The module stores Greek DECOMPOSED (Ι + combining comma
            # above), while assets/originals/ is composed. Nothing
            # compares the two today — lookup is by Strong's number —
            # but a Greek text search later would silently miss every
            # accented word. `split_entry` normalises on the way in so
            # both agree.
            lemma, translit, etym, usage, senses = split_entry(lines)
            entry['l'] = lemma
            entry['t'] = translit
            if etym:
                entry['e'] = etym
            if usage:
                entry['u'] = usage
            entry['s'] = senses
        (heb if word[0] == 'H' else grk)[word] = entry
    con.close()

    os.makedirs(out_dir, exist_ok=True)
    for name, data in (('bdb_zh', heb), ('thayer_zh', grk)):
        p = os.path.join(out_dir, name + '.json')
        with open(p, 'w', encoding='utf-8') as fh:
            json.dump(data, fh, ensure_ascii=False, separators=(',', ':'))
        print(f'  {name}: {len(data)} entries, '
              f'{os.path.getsize(p) / 1e6:.1f} MB')


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    src = sys.argv[1]

    bible = os.path.join(src, 'cuvs+-YHWH.bbl.mybible',
                         'cuvs+-YHWH.bbl.mybible')
    lex = os.path.join(src, 'bdbthayer.dct.mybible', 'bdbthayer.dct.mybible')

    print('Tagged Chinese text (和合本雅伟版＋, 修订编辑：孙树民)')
    import_bible(bible, os.path.join(ROOT, 'assets', 'tagged', 'cuvs-yhwh'))
    print('Lexicon (BDB + Thayer, Chinese)')
    import_lexicon(lex, os.path.join(ROOT, 'assets', 'strongs'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
