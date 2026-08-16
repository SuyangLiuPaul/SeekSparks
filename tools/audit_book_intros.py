#!/usr/bin/env python3
"""Check 37 — the claims the app makes ABOVE the text, against the text.

`assets/book_introductions.json` is rendered as a card at the top of
chapter 1 of every book (bible_reading_pane.dart:6238). It states, in
three locales, a subtitle, a summary, an author, a date, an audience,
themes, and a "key passage" named as the heart of the book. 66 books.
Nothing has ever asked whether those claims are true of the book they
sit on.

The instruments, in order of how decidable they are:

  37a  does the key passage RESOLVE — in every edition that ships the
       book, is there a verse at that chapter and verse?
  37b  does the key passage name its OWN book? `localizeKeyPassage`
       throws the stored book name away and substitutes the intro's
       own, so a reference to another book is printed as this one.
  37c  do the chapter claims agree with the corpus — "the first eleven
       chapters" of a book that has ten.
  37d  do the three locales state the SAME numbers? Each locale is an
       independent statement of one fact; where they disagree one is
       wrong, and that is decidable without knowing which.
  37e  WORD-FREQUENCY claims — "the word 'joy' appears 14 times". A
       count of a word in a book is the most checkable sentence in the
       whole asset, and the only one that can be settled without a
       single judgement call: count it, in every edition of the right
       language.
  37f  VERSE-COUNT claims — "a 13-verse note", "in just 21 verses",
       "150 prayers and hymns".
  37g  STRUCTURAL claims — the subtitle calls Lamentations "Five
       Acrostic Dirges". Whether a poem is an acrostic is decidable
       from the Hebrew this repository already ships: take the first
       Hebrew letter of each verse and compare it with the alphabet.

Read-only. Writes nothing.
"""

import json
import os
import re
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = lambda *p: os.path.join(ROOT, 'assets', *p)

# ---------------------------------------------------------------- corpus

def load_book_map(literal='const englishToChinese = {'):
    """English -> Chinese, read from the app's own table so this tool
    cannot disagree with the app about what a book is called."""
    src = open(os.path.join(ROOT, 'lib/constants/book_name_mapping.dart'),
               encoding='utf-8').read()
    start = src.index(literal)
    end = src.index('};', start)
    body = src[start:end]
    pairs = re.findall(r'"([^"]+)"\s*:\s*"([^"]+)"', body)
    return dict(pairs)


EN2ZH = load_book_map()
EN2ZHT = load_book_map('const englishToChineseTraditional = {')
ZH2EN = {}
for e, z in EN2ZH.items():
    ZH2EN.setdefault(z, e)

EDITIONS = ['kjv', 'kjvs', 'bsb', 'leb', 'nasb', 'cuvs-yhwh', 'cuvs-plus',
            'cuvs-yhwh-tr', 'biblexg-v2', 'biblexg-v2-tr', 'lxxwh']


def load_editions():
    """{edition: {english_book: {chapter: set(verses)}}}"""
    out = {}
    for name in EDITIONS:
        path = A(name + '.json')
        if not os.path.exists(path):
            continue
        rows = json.load(open(path, encoding='utf-8'))
        idx = defaultdict(lambda: defaultdict(set))
        for r in rows:
            b = r['book']
            b = ZH2EN.get(b, b)
            try:
                idx[b][int(r['chapter'])].add(int(r['verse']))
            except (ValueError, TypeError):
                continue
        out[name] = idx
    return out


# ------------------------------------------------------- reference parse

SINGLE_CHAPTER = {'Obadiah', 'Philemon', '2 John', '3 John', 'Jude'}


def parse_key_passage(kp, own_book):
    """Return (book, chapter, [verses] or None) or (book, None, None).

    None for verses means "the whole chapter". Mirrors what the card
    actually prints: localizeKeyPassage keeps the numeric tail verbatim.
    """
    kp = kp.strip()
    m = re.match(r'^(.+?)\s+(\d.*)$', kp)
    if not m:
        return None
    book, tail = m.group(1).strip(), m.group(2).strip()
    # "Psalm 23" is stored singular; the canonical book is "Psalms".
    canon = book
    if canon not in EN2ZH:
        for e in EN2ZH:
            if e.lower().startswith(canon.lower()):
                canon = e
                break
    m2 = re.match(r'^(\d+):(\d+)(?:-(\d+))?$', tail)
    if m2:
        c = int(m2.group(1))
        v0 = int(m2.group(2))
        v1 = int(m2.group(3)) if m2.group(3) else v0
        return (canon, c, list(range(v0, v1 + 1)))
    m3 = re.match(r'^(\d+)(?:-(\d+))?$', tail)
    if m3:
        n0 = int(m3.group(1))
        n1 = int(m3.group(2)) if m3.group(2) else n0
        if canon in SINGLE_CHAPTER:
            # a one-chapter book cites verses directly
            return (canon, 1, list(range(n0, n1 + 1)))
        return (canon, n0, None)  # whole chapter
    return (canon, None, None)


# ---------------------------------------------------------- number words

EN_WORDS = {
    'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6,
    'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'eleven': 11,
    'twelve': 12, 'thirteen': 13, 'fourteen': 14, 'fifteen': 15,
    'sixteen': 16, 'seventeen': 17, 'eighteen': 18, 'nineteen': 19,
    'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50, 'sixty': 60,
    'seventy': 70, 'eighty': 80, 'ninety': 90,
}
# 兩 is the Traditional form of 两. Leaving it out made every Simplified
# text that says 两 disagree with its own Traditional twin: all seven
# 37d Hans/Hant flags on the first run were this one missing character
# and not one of them was a defect in the data.
ZH_DIGITS = {'零': 0, '一': 1, '二': 2, '两': 2, '兩': 2, '三': 3, '四': 4,
             '五': 5, '六': 6, '七': 7, '八': 8, '九': 9}


def zh_number(s):
    """Convert a Chinese numeral string (up to 千) to an int, or None."""
    if not s:
        return None
    if re.fullmatch(r'\d+', s):
        return int(s)
    total, section, digit = 0, 0, None
    for ch in s:
        if ch in ZH_DIGITS:
            digit = ZH_DIGITS[ch]
        elif ch == '十':
            section += (digit if digit is not None else 1) * 10
            digit = None
        elif ch == '百':
            section += (digit if digit is not None else 1) * 100
            digit = None
        elif ch == '千':
            section += (digit if digit is not None else 1) * 1000
            digit = None
        else:
            return None
    total = section + (digit or 0)
    return total or None


def numbers_in(text, lang):
    """The multiset of integers a sentence asserts, normalised across
    the way each language writes them. Years and verse references are
    excluded by the callers that care; this is the raw stream."""
    out = []
    if lang == 'en':
        for m in re.finditer(r'\b(\d[\d,]*)\b', text):
            out.append(int(m.group(1).replace(',', '')))
        low = text.lower()
        for w, n in EN_WORDS.items():
            for _ in re.finditer(r'\b' + w + r'\b', low):
                out.append(n)
    else:
        for m in re.finditer(r'\d[\d,]*', text):
            out.append(int(m.group(0).replace(',', '')))
        for m in re.finditer(r'[零一二两兩三四五六七八九十百千]+', text):
            n = zh_number(m.group(0))
            if n is not None:
                out.append(n)
    return out


_BOOKNAME_RE = None


def _bookname_re():
    """Every book name in every script, longest first, so `1 Samuel` and
    「彼得前书」 are removed before their digits are read as claims."""
    global _BOOKNAME_RE
    if _BOOKNAME_RE is None:
        names = set(EN2ZH) | set(EN2ZH.values()) | set(EN2ZHT.values())
        alts = sorted(names, key=len, reverse=True)
        _BOOKNAME_RE = re.compile('|'.join(re.escape(a) for a in alts),
                                  re.I)
    return _BOOKNAME_RE


def stated_numbers(text, lang):
    """The figures a sentence asserts, normalised across how each
    language spells them.

    The en-vs-zh comparison over the raw numeral stream is not an
    instrument — Chinese writes 一 inside 一间, 一位, 一条 and 万 inside
    万族, so every second record disagrees with its own translation about
    nothing. Two normalisations make it one: strip BOOK NAMES first
    (`1 Samuel` and `1 Peter 2:9` are not claims that anything numbers
    one), and fold English number-WORDS to digits, because English
    prefers `the first eleven chapters` and `400 silent years` where
    Chinese prefers 前11章 and 四百年 — the same fact, opposite spelling
    conventions. Without both, 9 records disagree and none of them is a
    defect."""
    text = _bookname_re().sub(' ', text)
    out = {int(m.group(0).replace(',', ''))
           for m in re.finditer(r'\d[\d,]*', text)}
    if lang == 'en':
        low = text.lower()
        for w, n in EN_WORDS.items():
            if re.search(r'\b' + w + r'\b', low):
                out.add(n)
        if re.search(r'\bhundred\b', low):
            out |= {n * 100 for n in list(out) if n < 100}
    else:
        for m in re.finditer(r'[零一二两兩三四五六七八九十百千]{2,}', text):
            n = zh_number(m.group(0))
            if n is not None:
                out.add(n)
    return sorted(out)


# --------------------------------------------------- chapter-count claims

def _names_another_book(text, at, own_book):
    """True when the ~14 characters before `at` name a DIFFERENT book.

    Zechariah's card says 「馬太福音21章引用此節」 — Matthew 21 quotes this
    verse — and Zechariah has 14 chapters, so a rule that assumes every
    chapter number belongs to the book it is printed over reports that
    as a defect. It is not one; the claim is true and about Matthew."""
    window = text[max(0, at - 14):at]
    for table in (EN2ZH, EN2ZHT):
        for eng, zh in table.items():
            if eng == own_book:
                continue
            if zh in window:
                return True
    low = window.lower()
    for eng in EN2ZH:
        if eng == own_book:
            continue
        if eng.lower() in low:
            return True
    return False


def chapter_claims(text, lang, own_book=None):
    """Claims of the form 'the first N chapters' / 'from chapter N' —
    the ones that are checkable against the book's real chapter count.
    Returns a list of (n, phrase)."""
    found = []
    if lang == 'en':
        pats = [
            r'\bchapters?\s+(\d+)',
            r'\bfirst\s+([a-z]+|\d+)\s+chapters\b',
            r'\blast\s+([a-z]+|\d+)\s+chapters\b',
            r'\b([a-z]+|\d+)\s+chapters\b',
            r'\bchapters\s+(\d+)\s*[-–]\s*(\d+)',
        ]
        for p in pats:
            for m in re.finditer(p, text, re.I):
                if own_book and _names_another_book(text, m.start(), own_book):
                    continue
                for g in m.groups():
                    if g is None:
                        continue
                    g = g.strip().lower()
                    n = int(g) if g.isdigit() else EN_WORDS.get(g)
                    if n:
                        found.append((n, m.group(0)))
    else:
        for m in re.finditer(
                r'(?:第|前|後|后|共)?\s*([\d零一二两兩三四五六七八九十百]+)\s*章',
                text):
            if own_book and _names_another_book(text, m.start(), own_book):
                continue
            n = zh_number(m.group(1))
            if n:
                found.append((n, m.group(0)))
    return found


# ------------------------------------------------ word-frequency claims

# "The word 'joy' appears 14 times", 「喜乐」一词……出现14次.
FREQ_EN = re.compile(
    r"""(?:the\s+word\s+)?['"“]([A-Za-z][A-Za-z' -]{1,30}?)['"”]"""
    r"""[^.]{0,40}?appears?\s+(\d+)\s+times""", re.I)
FREQ_ZH = re.compile(
    r"""[「“]([^」”]{1,12}?)[」”][^。]{0,24}?出[现現](\d+)\s*次""")


# A claim the card SCOPES to the original language is not a claim about
# any translation, and counting it against one is a category error. The
# quoted term is then a gloss — 「喜乐、欢喜」 for χαρά/χαίρω/συγχαίρω —
# and no Chinese edition contains that string as written, so scoring it
# reports 0 and flags a sentence that is true. What witnesses these is
# `assets/originals`, by Strong's number, which the Dart guard does.
SCOPED_TO_ORIGINAL = re.compile(
    r'in\s+the\s+(?:greek|hebrew|aramaic)\b|希[臘腊]原文|希伯[來来]原文|原文中',
    re.I)


def freq_claims(text, lang):
    pat = FREQ_EN if lang == 'en' else FREQ_ZH
    out = []
    for m in pat.finditer(text):
        head = text[max(0, m.start() - 60):m.start()]
        if SCOPED_TO_ORIGINAL.search(head + m.group(0)):
            continue
        out.append((m.group(1).strip(), int(m.group(2))))
    return out


def count_word(rows, word, lang):
    """How many times `word` occurs in `rows`, by the house rule for the
    language: whole-word for English, substring for Chinese (a Han
    string has no word boundary to anchor to)."""
    if lang == 'en':
        rx = re.compile(r'\b' + re.escape(word) + r'\b', re.I)
        return sum(len(rx.findall(r['text'])) for r in rows)
    return sum(r['text'].count(word) for r in rows)


# ---------------------------------------------------- verse-count claims

# Only the shapes that COUNT a whole book. "chapter 3 verses 22-23" is a
# reference, not a count, and a pattern loose enough to read it as one
# reported Lamentations for saying 154 verses are 3 — three false
# findings from one careless `(\d+)\s+verses?`.
VERSE_EN = re.compile(
    r'\b(\d+)-verse\b|\bin\s+just\s+(\d+)\s+verses\b|'
    r'\bonly\s+(\d+)\s+verses\b', re.I)
VERSE_ZH = re.compile(r'(?:僅|仅)[^。]{0,6}?(\d+)\s*[節节]|(\d+)\s*[節节]短')


def verse_claims(text, lang):
    pat = VERSE_EN if lang == 'en' else VERSE_ZH
    out = []
    for m in pat.finditer(text):
        for g in m.groups():
            if g:
                out.append((int(g), m.group(0)))
    return out


# ----------------------------------------------------- acrostic claims

ACROSTIC_WORD = re.compile(r'acrostics?|字母離合|字母离合|離合詩|离合诗', re.I)


def acrostic_claims(text, lang):
    """How many acrostics the card says there are. The number that
    governs is the LAST one before the word, which is what reading the
    sentence gives you in both languages: 'Five Dirges … Four of Them
    Acrostics' claims four, '五首哀歌，前四首是字母离合诗' claims four,
    and the older 'Five Acrostic Dirges' / '五首字母离合诗' claim five."""
    out = set()
    for m in ACROSTIC_WORD.finditer(text):
        window = text[max(0, m.start() - 40):m.start()]
        if lang == 'en':
            nums = re.findall(r'\b([a-z]+|\d+)\b', window, re.I)
            vals = [int(n) if n.isdigit() else EN_WORDS.get(n.lower())
                    for n in nums]
        else:
            vals = [zh_number(n) for n in
                    re.findall(r'([零一二两兩三四五六七八九十百\d]+)', window)]
        vals = [v for v in vals if v]
        if vals:
            out.add(vals[-1])
    return out


HEBREW_ALEPHBET = 'אבגדהוזחטיכלמנסעפצקרשת'
_HEB = re.compile(r'[א-ת]')


def first_letters(book_slug, chapter):
    """The first Hebrew consonant of each verse of a chapter, read from
    `assets/originals/` — the app's own pointed Hebrew."""
    path = A('originals', book_slug + '.json')
    if not os.path.exists(path):
        return None
    data = json.load(open(path, encoding='utf-8'))
    out, v = [], 1
    while '%d:%d' % (chapter, v) in data:
        letter = '?'
        for w in data['%d:%d' % (chapter, v)]:
            found = _HEB.findall(w.get('w', ''))
            if found:
                letter = found[0]
                break
        out.append(letter)
        v += 1
    return out or None


def is_acrostic(letters):
    """Is this chapter an alphabetic acrostic?

    Two shapes count, and both are in Lamentations, so a rule that knows
    only the first reports the book's most elaborate poem as its least:

      * 22 verses, one per letter — chapters 1, 2 and 4;
      * 66 verses in 22 triads, all three sharing a letter — chapter 3.

    The ע/פ transposition in chapters 2, 3 and 4 is a real feature of
    those poems and not a defect, so a letter may stand where the other
    of that pair is expected."""
    if not letters:
        return False
    n = len(HEBREW_ALEPHBET)
    if len(letters) == n:
        heads = list(letters)
    elif len(letters) == n * 3 and all(
            letters[i] == letters[i + 1] == letters[i + 2]
            for i in range(0, n * 3, 3)):
        heads = [letters[i] for i in range(0, n * 3, 3)]
    else:
        return False
    if sorted(heads) != sorted(HEBREW_ALEPHBET):
        return False
    for got, want in zip(heads, HEBREW_ALEPHBET):
        if got == want or {got, want} == {'ע', 'פ'}:
            continue
        return False
    return True


# ------------------------------------------------------------------ main

def main():
    data = json.load(open(A('book_introductions.json'), encoding='utf-8'))
    intros = data['intros']
    eds = load_editions()

    print('editions loaded: %d' % len(eds))
    for name in eds:
        print('  %-16s %d books' % (name, len(eds[name])))
    print()

    findings = defaultdict(list)

    # ---- 37b: does the key passage name its own book?
    for book, rec in sorted(intros.items()):
        kp = rec.get('keyPassage', '')
        p = parse_key_passage(kp, book)
        if p is None:
            findings['37b-unparsable'].append((book, kp))
            continue
        named, c, vs = p
        if named != book:
            findings['37b-otherbook'].append((book, kp, named))

    # ---- 37a: does it resolve, in every edition that has the book?
    for book, rec in sorted(intros.items()):
        kp = rec.get('keyPassage', '')
        p = parse_key_passage(kp, book)
        if p is None:
            continue
        named, c, vs = p
        target = book  # the card prints it as THIS book
        if c is None:
            findings['37a-nochapter'].append((book, kp))
            continue
        for ed, idx in sorted(eds.items()):
            if target not in idx:
                continue  # edition does not ship the book at all
            chapters = idx[target]
            if c not in chapters:
                findings['37a-nochap'].append((book, kp, ed, c, max(chapters)))
                continue
            if vs is None:
                continue
            missing = [v for v in vs if v not in chapters[c]]
            if missing:
                findings['37a-noverse'].append(
                    (book, kp, ed, missing, max(chapters[c])))

    # ---- 37c: chapter-count claims against the real chapter count
    ref = eds.get('bsb') or list(eds.values())[0]
    for book, rec in sorted(intros.items()):
        if book not in ref:
            continue
        real_max = max(ref[book])
        for field in ('summary', 'subtitle', 'keyPassageDescription'):
            block = rec.get(field) or {}
            for lang, text in block.items():
                for n, phrase in chapter_claims(
                        text, 'en' if lang == 'en' else 'zh', book):
                    if n > real_max:
                        findings['37c-overrun'].append(
                            (book, field, lang, phrase, n, real_max))

    # ---- 37d: do the three locales state the same numbers?
    for book, rec in sorted(intros.items()):
        for field in ('summary', 'subtitle', 'author', 'date', 'audience',
                      'keyPassageDescription'):
            block = rec.get(field) or {}
            if not isinstance(block, dict):
                continue
            got = {}
            for lang in ('en', 'zh-Hans', 'zh-Hant'):
                if lang not in block:
                    findings['37d-missinglocale'].append((book, field, lang))
                    continue
                got[lang] = sorted(set(numbers_in(
                    block[lang], 'en' if lang == 'en' else 'zh')))
            if len(got) == 3:
                b, c = got['zh-Hans'], got['zh-Hant']
                if b != c:
                    findings['37d-hans-hant'].append((book, field, b, c))
            ara = {lang: stated_numbers(block[lang],
                                        'en' if lang == 'en' else 'zh')
                   for lang in ('en', 'zh-Hans', 'zh-Hant') if lang in block}
            if len(set(map(tuple, ara.values()))) > 1:
                findings['37d-en-zh'].append((book, field, ara))
        # themes list parity
        th = rec.get('themes') or {}
        lens = {k: len(v) for k, v in th.items() if isinstance(v, list)}
        if len(set(lens.values())) > 1:
            findings['37d-themes'].append((book, lens))

    # ---- 37e: word-frequency claims, counted in every edition
    raw = {}
    for name in EDITIONS:
        path = A(name + '.json')
        if os.path.exists(path):
            raw[name] = json.load(open(path, encoding='utf-8'))
    en_eds = ['bsb', 'kjv', 'kjvs', 'leb', 'nasb']
    zh_eds = ['cuvs-yhwh', 'cuvs-plus', 'cuvs-yhwh-tr']
    for book, rec in sorted(intros.items()):
        for field in ('summary', 'subtitle', 'keyPassageDescription'):
            block = rec.get(field) or {}
            for lang, text in block.items():
                en = lang == 'en'
                for word, claimed in freq_claims(text, 'en' if en else 'zh'):
                    counts = {}
                    for ed in (en_eds if en else zh_eds):
                        rows = raw.get(ed)
                        if not rows:
                            continue
                        want = {book, EN2ZH.get(book), EN2ZHT.get(book)}
                        sub = [r for r in rows if r['book'] in want]
                        counts[ed] = count_word(sub, word, 'en' if en else 'zh')
                    if claimed not in set(counts.values()):
                        findings['37e-wordfreq'].append(
                            (book, field, lang, word, claimed, counts))

    # ---- 37f: verse-count claims against the corpus
    for book, rec in sorted(intros.items()):
        if book not in ref:
            continue
        total = sum(len(vs) for vs in ref[book].values())
        for field in ('summary', 'subtitle', 'keyPassageDescription'):
            block = rec.get(field) or {}
            for lang, text in block.items():
                for n, phrase in verse_claims(text, 'en' if lang == 'en' else 'zh'):
                    if n != total:
                        findings['37f-versecount'].append(
                            (book, field, lang, phrase, n, total))

    # ---- 37g: acrostic claims against the shipped Hebrew
    for book, rec in sorted(intros.items()):
        claims = []
        for field in ('subtitle', 'summary', 'keyPassageDescription'):
            block = rec.get(field) or {}
            for lang, text in block.items():
                if re.search(r'acrostic|字母離合|字母离合|離合詩|离合诗',
                             text, re.I):
                    claims.append((field, lang, text))
        if not claims:
            continue
        slug = book.lower().replace(' ', '_')
        chapters = sorted(ref.get(book, {}))
        verdict = []
        for c in chapters:
            letters = first_letters(slug, c)
            verdict.append((c, None if letters is None else is_acrostic(letters),
                            0 if letters is None else len(letters)))
        # The question is not "does this book contain a chapter that is
        # not an acrostic" — Lamentations 5 is one, and saying so is what
        # a correct card does. It is whether the card claims MORE
        # acrostics than the Hebrew has. A card that names the right
        # number is clean; a card that names none is still flagged,
        # because a bare "acrostic dirges" reads as all of them.
        measured = sum(1 for v in verdict if v[1] is True)
        claimed = set()
        for _f, lang, text in claims:
            claimed |= acrostic_claims(text, 'en' if lang == 'en' else 'zh')
        if measured not in claimed:
            findings['37g-acrostic'].append(
                (book, claims[0][2][:70], measured, sorted(claimed), verdict))

    # ------------------------------------------------------------ report
    order = ['37b-unparsable', '37b-otherbook', '37a-nochapter', '37a-nochap',
             '37a-noverse', '37c-overrun', '37e-wordfreq', '37f-versecount',
             '37g-acrostic', '37d-missinglocale', '37d-themes',
             '37d-hans-hant', '37d-en-zh']
    for k in order:
        v = findings.get(k, [])
        print('=== %s : %d ===' % (k, len(v)))
        for item in v:
            print('   ', item)
        print()

    total = sum(len(findings[k]) for k in findings)
    print('TOTAL FLAGS: %d' % total)
    return 0


if __name__ == '__main__':
    sys.exit(main())
