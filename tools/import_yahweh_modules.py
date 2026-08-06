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
TAG_RE = re.compile(r'<W([HG])(\d+)(x?)>')
# Everything outside a tag that is punctuation-only should not become its
# own hover target — it belongs to the run before it.
PUNCT_ONLY = re.compile(r'^[\s，。；：、？！「」“”‘’（）《》…—·\-,.;:?!\'"()\[\]]+$')

# Strong's proper stops here; above it the numbers are TVM/grammar codes
# in the e-Sword/MySword convention (Hebrew stems & aspects, Greek
# tense-voice-mood). Keeping them separate is what lets the UI print a
# lexical entry and a parsing line rather than mixing them.
LEXICAL_MAX = {'H': 8674, 'G': 5624}


def parse_tagged(scripture):
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
    """
    # Split into [text, tag, text, tag, …] preserving order.
    parts = []
    pos = 0
    for m in TAG_RE.finditer(scripture):
        if m.start() > pos:
            parts.append(('t', scripture[pos:m.start()]))
        parts.append(('w', (m.group(1), int(m.group(2)), m.group(3) == 'x')))
        pos = m.end()
    if pos < len(scripture):
        parts.append(('t', scripture[pos:]))

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
        by_book.setdefault(book, {})[f'{ch}:{vs}'] = parse_tagged(text or '')
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
    """MySword entries are <p>-per-line. Keep the lines, drop the markup."""
    s = re.sub(r'(?i)</p\s*>', '\n', html or '')
    s = re.sub(r'<[^>]+>', '', s)
    s = s.replace('&nbsp;', ' ').replace('&amp;', '&')
    s = s.replace('&lt;', '<').replace('&gt;', '>')
    return [ln.strip() for ln in s.split('\n') if ln.strip()]


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
            # line 0 lemma, 1 transliteration, 2 etymology, 3 usage,
            # rest senses — the shape every entry in this module uses.
            # The module stores Greek DECOMPOSED (Ι + combining comma
            # above), while assets/originals/ is composed. Nothing
            # compares the two today — lookup is by Strong's number —
            # but a Greek text search later would silently miss every
            # accented word. Normalise on the way in so both agree.
            entry['l'] = unicodedata.normalize(
                'NFC', lines[0]) if len(lines) > 0 else ''
            entry['t'] = lines[1] if len(lines) > 1 else ''
            if len(lines) > 2:
                entry['e'] = lines[2]
            if len(lines) > 3 and lines[3].startswith('钦定本'):
                entry['u'] = lines[3]
                entry['s'] = lines[4:]
            else:
                entry['s'] = lines[3:]
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
