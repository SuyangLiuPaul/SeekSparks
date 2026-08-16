#!/usr/bin/env python3
"""Check 37 — the quotations the book-intro card prints, against the
passage it attributes them to.

59 of the 66 intros in `assets/book_introductions.json` print a
quotation of scripture inside `keyPassageDescription` and name a
`keyPassage` as its source. The card renders both, one under the other
(bible_reading_pane.dart:8093). So the app makes a checkable claim on
every one of those screens: *these words are in that passage*.

The test is not string equality — the quotations elide with '…' and are
the author's own rendering, not any one edition. It is a RANKING: score
the quotation against every verse in the Bible, and ask whether the
named passage comes out on top. A quotation whose best match is some
other reference is attributed to the wrong place; a quotation that
matches nothing is not in this Bible at all.

English is scored against five editions and Chinese against the three
CUV-family editions, so a low score means "no edition we ship says
this" rather than "this edition words it differently".

Read-only. Writes nothing.
"""

import json
import math
import os
import re
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = lambda *p: os.path.join(ROOT, 'assets', *p)

EN_EDITIONS = ['bsb', 'kjv', 'kjvs', 'leb', 'nasb']
ZH_EDITIONS = ['cuvs-yhwh', 'cuvs-plus', 'cuvs-yhwh-tr']

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from audit_book_intros import (EN2ZH, ZH2EN, parse_key_passage,  # noqa: E402
                               SINGLE_CHAPTER)


# ------------------------------------------------------------ tokenising

def en_tokens(s):
    s = s.lower()
    s = s.replace('’', "'").replace('‘', "'")
    return re.findall(r"[a-z]+", s)


HAN = re.compile(r'[一-鿿]')


def zh_tokens(s):
    """One token per Han character, the same house rule phrase_match.dart
    uses. Bigrams are added by the caller for word-order sensitivity."""
    return HAN.findall(s)


def bigrams(toks):
    return [toks[i] + toks[i + 1] for i in range(len(toks) - 1)]


# ------------------------------------------------------------- the index

class Corpus:
    """Verse texts of one language's editions, with an IDF-weighted
    inverted index over tokens+bigrams."""

    def __init__(self, editions, lang):
        self.lang = lang
        self.units = []          # (edition, english_book, chap, verse, text)
        self.by_ref = defaultdict(list)   # (book,chap,verse) -> unit ids
        for name in editions:
            path = A(name + '.json')
            if not os.path.exists(path):
                continue
            for r in json.load(open(path, encoding='utf-8')):
                b = ZH2EN.get(r['book'], r['book'])
                try:
                    c, v = int(r['chapter']), int(r['verse'])
                except (ValueError, TypeError):
                    continue
                uid = len(self.units)
                self.units.append((name, b, c, v, r['text']))
                self.by_ref[(b, c, v)].append(uid)
        self.feats = [self._feats(u[4]) for u in self.units]
        df = defaultdict(int)
        for f in self.feats:
            for t in set(f):
                df[t] += 1
        n = len(self.units)
        self.idf = {t: math.log(n / (1.0 + c)) for t, c in df.items()}
        self.inv = defaultdict(list)
        for i, f in enumerate(self.feats):
            for t in set(f):
                self.inv[t].append(i)
        self.norm = []
        for f in self.feats:
            s = set(f)
            self.norm.append(math.sqrt(sum(self.idf.get(t, 0) ** 2 for t in s)) or 1.0)

    def _feats(self, text):
        if self.lang == 'en':
            t = en_tokens(text)
        else:
            t = zh_tokens(text)
        return t + bigrams(t)

    def score_all(self, query, limit_docs=None):
        """cosine over IDF-weighted feature sets. Returns {uid: score}."""
        q = set(self._feats(query))
        if not q:
            return {}
        qn = math.sqrt(sum(self.idf.get(t, 0) ** 2 for t in q)) or 1.0
        acc = defaultdict(float)
        for t in q:
            w = self.idf.get(t)
            if w is None or w <= 0:
                continue
            docs = self.inv.get(t)
            if not docs:
                continue
            if len(docs) > 4000:       # a feature in a tenth of the Bible
                continue               # carries no evidence; skip for speed
            ww = w * w
            for i in docs:
                acc[i] += ww
        return {i: s / (qn * self.norm[i]) for i, s in acc.items()}


# ------------------------------------------------- quotation extraction

QUOTE_ZH = re.compile(r"「([^」]{6,}?)」|“([^”]{6,}?)”")

# A single quote OPENS only where an opening quote can stand — at the
# start, or after whitespace or an opening bracket — and CLOSES only
# where a closing quote can stand. Testing for an apostrophe instead
# ("a letter on both sides") is not enough, because English possessives
# of names ending in s take a bare trailing apostrophe: `Jesus' final
# command before ascension and the literal outline of the book: 'You
# will be my witnesses…` opened a quotation at `Jesus'` and closed it at
# the real opening quote, handing the scorer 38 words of the author's
# own prose and scoring it, correctly, at 0.072 against Acts 1:8. That
# was an instrument defect reported as a finding until this was fixed.
QUOTE_EN = re.compile(
    r"""(?:^|(?<=[\s(\[—-]))'([^']{12,}?)'(?=[\s.,;:!?)\]—]|$)"""
    r"""|“([^”]{12,}?)”""")


def quotes_of(text, lang):
    pat = QUOTE_EN if lang == 'en' else QUOTE_ZH
    out = []
    for m in pat.finditer(text):
        s = (m.group(1) or m.group(2) or '')
        # elisions are the author's; each side is still a real span
        for part in re.split(r'…+|\.\.\.', s):
            part = part.strip(' .,;:!?—-')
            if lang == 'en' and len(en_tokens(part)) >= 3:
                out.append(part)
            elif lang != 'en' and len(zh_tokens(part)) >= 4:
                out.append(part)
    return out


# ------------------------------------------------------------------ main

def ref_span(book, kp):
    """The (book, chapter, verses) the card names, as a set of refs.
    verses None => the whole chapter."""
    p = parse_key_passage(kp, book)
    if p is None:
        return None
    _named, c, vs = p
    return (book, c, vs)


def main():
    intros = json.load(open(A('book_introductions.json'),
                            encoding='utf-8'))['intros']
    print('building corpora...', flush=True)
    corp = {'en': Corpus(EN_EDITIONS, 'en'), 'zh': Corpus(ZH_EDITIONS, 'zh')}
    for k, c in corp.items():
        print('  %s: %d verse-units, %d features' % (k, len(c.units), len(c.inv)))
    print()

    rows = []
    for book, rec in sorted(intros.items()):
        kp = rec.get('keyPassage', '')
        span = ref_span(book, kp)
        if span is None:
            continue
        tb, tc, tvs = span
        desc = rec.get('keyPassageDescription') or {}
        for lang, key in (('en', 'en'), ('zh', 'zh-Hans')):
            text = desc.get(key, '')
            for q in quotes_of(text, lang):
                sc = corp[lang].score_all(q)
                if not sc:
                    rows.append((book, kp, lang, q, 0.0, None, 0.0))
                    continue
                best = max(sc.items(), key=lambda kv: kv[1])
                bu = corp[lang].units[best[0]]
                # best score achieved anywhere INSIDE the named passage
                own = 0.0
                own_ref = None
                for (bb, cc, vv), uids in corp[lang].by_ref.items():
                    if bb != tb or cc != tc:
                        continue
                    if tvs is not None and vv not in tvs:
                        continue
                    for u in uids:
                        if sc.get(u, 0.0) > own:
                            own = sc[u]
                            own_ref = (bb, cc, vv)
                rows.append((book, kp, lang, q, own, own_ref,
                             best[1], (bu[1], bu[2], bu[3]), bu[0]))

    # ---------------------------------------------------------- verdicts
    #
    # The rule that had to be corrected before any of this was believed:
    # a quotation is NOT suspect merely because some other verse scores
    # higher. Scripture quotes itself — Matthew 21:5 IS Zechariah 9:9,
    # and Romans 1:17 and Hebrews 10:38 both quote Habakkuk 2:4. The
    # only evidence of misattribution is that the NAMED passage does not
    # contain the words, in absolute terms. `best` is context for a
    # human reading a flag, never the trigger.
    scored = [r for r in rows if len(r) == 9]
    nothing = [r for r in rows if len(r) == 7]
    scored.sort(key=lambda r: r[4])

    print('=== quotations scored: %d (%d en, %d zh) ===' %
          (len(rows), sum(1 for r in rows if r[2] == 'en'),
           sum(1 for r in rows if r[2] == 'zh')))
    print()
    print('distribution of the score at the NAMED passage:')
    edges = (0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.8, 1.01)
    for lo, hi in zip(edges, edges[1:]):
        n = sum(1 for r in scored if lo <= r[4] < hi)
        print('   %.1f – %.1f  %s %d' % (lo, hi, '#' * n, n))
    print()
    if nothing:
        print('--- nothing scored at all: %d ---' % len(nothing))
        for r in nothing:
            print('  %s [%s] %r' % (r[0], r[2], r[3]))
        print()

    print('--- the 25 weakest, for reading ---')
    for r in scored[:25]:
        book, kp, lang, q, own, own_ref, bestsc, bestref, bested = r
        print('  %-18s %-22s [%s]  named %.3f   best %.3f %s (%s)' %
              (book, kp, lang, own, bestsc, bestref, bested))
        print('      %s' % q)
    return 0


if __name__ == '__main__':
    sys.exit(main())
