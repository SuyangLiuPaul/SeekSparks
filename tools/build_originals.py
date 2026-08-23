#!/usr/bin/env python3
"""Build the bundled original-language assets.

Outputs (relative to repo root):
  assets/strongs/greek.json    — Strong's Greek dictionary (~5,500 entries)
  assets/strongs/hebrew.json   — Strong's Hebrew dictionary (~8,700 entries)
  assets/originals/<book>.json — per-book Hebrew OT or Greek NT tagged with Strong's

Sources (all public domain or CC):
  - openscriptures/strongs           Strong's lexicons (JS object literal export)
  - openscriptures/morphhb           Westminster Leningrad Codex with Strong's + morph
  - eliranwong/OpenGNT               Berean Greek NT with Strong's (CSV)

Run from the repo root:
    python3 tools/build_originals.py
or with --skip-greek / --skip-hebrew to iterate on one half.

The script downloads sources to a sibling cache directory (`.cache/originals/`)
so re-runs are quick. Delete the cache to force a fresh fetch.
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import os
import re
import sys
import unicodedata
import urllib.request
import zipfile
from xml.etree import ElementTree as ET

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_DIR = os.path.join(REPO_ROOT, 'assets')
STRONGS_DIR = os.path.join(ASSETS_DIR, 'strongs')
ORIGINALS_DIR = os.path.join(ASSETS_DIR, 'originals')
CACHE_DIR = os.path.join(REPO_ROOT, '.cache', 'originals')

UA = {'User-Agent': 'YsWords originals build script'}

# ── Sources ────────────────────────────────────────────────────────────

STRONGS_HEBREW_URL = (
    'https://raw.githubusercontent.com/openscriptures/strongs/master/'
    'hebrew/strongs-hebrew-dictionary.js'
)
STRONGS_GREEK_URL = (
    'https://raw.githubusercontent.com/openscriptures/strongs/master/'
    'greek/strongs-greek-dictionary.js'
)

# CBOL Chinese Strong's lexicon (ier1990 mirror).
# License: CC-BY-NC-SA 4.0 — original from CBOL project (bible.fhl.net).
# We bundle both the Hebrew and Greek "merged" files; entries have a
# Strong's number padded to 5 digits as the key (e.g. "02316" / "00430").
ZH_STRONGS_HEBREW_URL = (
    'https://raw.githubusercontent.com/'
    'ier1990/samekhi_china_strongs-master/master/zhrcn/zh-rcn/words/'
    'hebrew.json'
)
ZH_STRONGS_GREEK_URL = (
    'https://raw.githubusercontent.com/'
    'ier1990/samekhi_china_strongs-master/master/zhrcn/zh-rcn/words/'
    'greek.json'
)

MORPHHB_BOOKS_URL = (
    'https://raw.githubusercontent.com/openscriptures/morphhb/master/'
    'wlc/{osis}.xml'
)

# OpenGNT base text — one row per word, tab-delimited with grouped
# fields wrapped in 〔...〕 and separated by ｜. Distributed as a zip.
OPENGNT_ZIP_URL = (
    'https://github.com/eliranwong/OpenGNT/raw/master/'
    'OpenGNT_BASE_TEXT.zip'
)
OPENGNT_CSV_NAME = 'OpenGNT_version3_3.csv'

# OSIS book id → English name (matches lib/services/fetch_books.dart
# `standardBookOrder` so OriginalsService._slug() finds the file).
OSIS_HEBREW = [
    ('Gen', 'Genesis'), ('Exod', 'Exodus'), ('Lev', 'Leviticus'),
    ('Num', 'Numbers'), ('Deut', 'Deuteronomy'), ('Josh', 'Joshua'),
    ('Judg', 'Judges'), ('Ruth', 'Ruth'),
    ('1Sam', '1 Samuel'), ('2Sam', '2 Samuel'),
    ('1Kgs', '1 Kings'), ('2Kgs', '2 Kings'),
    ('1Chr', '1 Chronicles'), ('2Chr', '2 Chronicles'),
    ('Ezra', 'Ezra'), ('Neh', 'Nehemiah'), ('Esth', 'Esther'),
    ('Job', 'Job'), ('Ps', 'Psalms'), ('Prov', 'Proverbs'),
    ('Eccl', 'Ecclesiastes'), ('Song', 'Song of Solomon'),
    ('Isa', 'Isaiah'), ('Jer', 'Jeremiah'), ('Lam', 'Lamentations'),
    ('Ezek', 'Ezekiel'), ('Dan', 'Daniel'),
    ('Hos', 'Hosea'), ('Joel', 'Joel'), ('Amos', 'Amos'),
    ('Obad', 'Obadiah'), ('Jonah', 'Jonah'), ('Mic', 'Micah'),
    ('Nah', 'Nahum'), ('Hab', 'Habakkuk'), ('Zeph', 'Zephaniah'),
    ('Hag', 'Haggai'), ('Zech', 'Zechariah'), ('Mal', 'Malachi'),
]

# Mapping for OpenGNT's "Book" column → English book name.
OPENGNT_BOOK = {
    40: 'Matthew', 41: 'Mark', 42: 'Luke', 43: 'John', 44: 'Acts',
    45: 'Romans', 46: '1 Corinthians', 47: '2 Corinthians',
    48: 'Galatians', 49: 'Ephesians', 50: 'Philippians', 51: 'Colossians',
    52: '1 Thessalonians', 53: '2 Thessalonians',
    54: '1 Timothy', 55: '2 Timothy', 56: 'Titus', 57: 'Philemon',
    58: 'Hebrews', 59: 'James', 60: '1 Peter', 61: '2 Peter',
    62: '1 John', 63: '2 John', 64: '3 John', 65: 'Jude',
    66: 'Revelation',
}

NS_OSIS = '{http://www.bibletechnologies.net/2003/OSIS/namespace}'


# ── HTTP cache ─────────────────────────────────────────────────────────


def _cache_path(name: str) -> str:
    os.makedirs(CACHE_DIR, exist_ok=True)
    return os.path.join(CACHE_DIR, name)


def fetch(url: str, cache_name: str) -> bytes:
    cp = _cache_path(cache_name)
    if os.path.exists(cp):
        with open(cp, 'rb') as f:
            return f.read()
    print(f'  GET {url}')
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=60) as resp:
        data = resp.read()
    with open(cp, 'wb') as f:
        f.write(data)
    return data


# ── Strong's lexicons ──────────────────────────────────────────────────


def _parse_strongs_js(js_text: str) -> dict:
    """OpenScriptures distributes Strong's as a JSDoc comment block
    followed by `var X = {...};` and a trailing `module.exports = ...`.
    Find the object literal and parse the leading JSON, ignoring the
    trailing JS statements via raw_decode."""
    m = re.search(r'var\s+\w+\s*=\s*(\{)', js_text)
    if not m:
        raise ValueError('Could not find object literal in Strong\'s JS')
    body = js_text[m.start(1):]
    obj, _ = json.JSONDecoder().raw_decode(body)
    return obj


def _normalize_strongs_entry(num: str, raw: dict) -> dict:
    """Project openscriptures fields onto our compact shape.

    OpenScriptures splits the lexicon entry across `derivation`,
    `strongs_def`, and `kjv_def`. Greek uses `derivation` for the core
    sense; Hebrew tends to put it in `strongs_def`. We merge them so the
    UI doesn't have to know the difference.
    """
    lemma = (raw.get('lemma') or '').strip()
    translit = (raw.get('xlit') or raw.get('translit') or '').strip()
    pron = (raw.get('pron') or raw.get('pronunciation') or '').strip()

    derivation = (raw.get('derivation') or '').strip()
    strongs_def = (raw.get('strongs_def') or '').strip()
    kjv_def = (raw.get('kjv_def') or '').strip()

    # OpenScriptures splits meaning across fields with different
    # conventions per language:
    #   Greek:  derivation = "<etymology>; <core meaning>"
    #           strongs_def = figurative addition
    #   Hebrew: strongs_def = "<core meaning>"
    #           derivation = etymology only
    is_greek = num.startswith('G')
    gloss = ''
    if is_greek and ';' in derivation:
        # Greek convention: meaning lives after the first semicolon of
        # derivation (etymology before, sense after). When the trailing
        # part is empty, fall through to strongs_def.
        after = derivation.split(';', 1)[1].strip()
        if after:
            gloss = after
    if not gloss:
        gloss = strongs_def or derivation
    # Trim long glosses to the first clause for headline display.
    short = re.split(r'(?<!,) ?[;.]', gloss, maxsplit=1)[0].strip()
    if short:
        gloss = short

    parts = []
    if derivation:
        parts.append(derivation)
    if strongs_def and strongs_def != derivation:
        parts.append(strongs_def)
    if kjv_def:
        parts.append('KJV: ' + kjv_def)
    definition = ' '.join(parts).strip()

    out: dict = {'lemma': lemma, 'translit': translit, 'pron': pron,
                 'gloss': gloss, 'def': definition}
    if derivation:
        out['deriv'] = derivation
    return out


# The grammatical categories CBOL prints on a line of their own between
# a sense and its sub-senses. They are metadata about the headword, not
# part of any definition, so they end sense 1 rather than continuing it.
#
# Both scripts are listed because `sense_one_gloss` is also run over the
# Traditional `defZhTw` column, which is the same body after `s2t`.
#
# This is a closed vocabulary and not a length or indentation test,
# because both of those misclassify the real data: CBOL indents three of
# these tags (H369, H4616, H8478) and leaves 107 of them at column zero,
# while genuine definition text runs as short as `的手上` (H2078) and
# `地名` is a two-character tag. Only the words themselves separate them.
_ZH_POS_TERMS = frozenset({
    '名词', '名詞', '阳性名词', '陽性名詞', '阴性名词', '陰性名詞',
    '中性名词', '中性名詞', '专有名词', '專有名詞',
    '阳性专有名词', '陽性專有名詞', '阴性专有名词', '陰性專有名詞',
    '专有地名词', '專有地名詞', '地名专有名词', '地名專有名詞',
    '专有名词地名', '專有名詞地名',
    '形容词', '形容詞', '形容词的', '形容詞的',
    '副词', '副詞', '作为副词', '作為副詞', '受格的副词', '受格的副詞',
    '连接词', '連接詞', '介系词', '介系詞', '附介系词', '附介系詞',
    '动词', '動詞', '及物动词', '及物動詞', '不及物动词', '不及物動詞',
    '实名词', '實名詞', '作名词用', '作名詞用',
    '关系代名词', '關係代名詞', '阴性关系代名词', '陰性關係代名詞',
    '代名词', '代名詞', '假设分词', '假設分詞',
    '否定词', '否定詞', '复合字', '複合字',
    '地名', '人名', '种族名称', '種族名稱',
    '复数', '複數', '单数', '單數', '抽象', '加强语气', '加強語氣',
    '阳性', '陽性', '阴性', '陰性', '中性',
    '感叹词', '感嘆詞', '疑问词', '疑問詞', '数词', '數詞', '冠词', '冠詞',
})

_ZH_POS_SEP = re.compile(r'[\s,，、;；()（）]+')
# CBOL nests to at least four levels: `1)`, `1a)`, `1a1)`, `1a1a)`.
# `\d+[a-zA-Z]*\)` stopped at two and read the ~3,900 deeper markers as
# ordinary text, so `1a1) 神话中的海怪` continued sense 1 of H7293.
_ZH_NUMBERED = re.compile(r'^\s*\d+(?:[a-zA-Z]+\d*)*\)')
# Ideographs and the fullwidth forms; a boundary between two of these
# carries its own spacing and must not be given another.
_ZH_WIDE = re.compile(r'[　-〿㐀-鿿豈-﫿＀-￯]')


# Punctuation that closes what came before it, so a wrap landing just
# ahead of it must not be given a space: CBOL breaks G5330 between
# `以自以为是的好行为自豪` and `, 相对之下…`.
_ZH_LEADS_TIGHT = re.compile(r'[,，、;；.。!！?？:：)）\]】]')

# A line ending on one of these is unfinished: CBOL ran out of column.
_ZH_DANGLING = re.compile(r'[,，、;；]\s*$')
# A line has said what it came to say when it closes a sentence, or when
# it ends on a CBOL reference — `|`, optionally inside the bracket that
# opened `(#`. A PLAIN bracket is not terminal: `(今 Anata 亚拿塔)`
# (H1374), `别是巴[884]` (H5683) and `与莉达(Leda)` (G1359) all close a
# parenthesis in the middle of a sentence, and reading those as the end
# leaves the gloss saying the village is AT Anathoth rather than between
# the ridges of Anathoth and Nob.
_ZH_TERMINAL = re.compile(r'(?:[.。!！?？:：]|\|\s*[)）\]】]?)\s*$')

# Share of the entry's own widest line that a line must reach before a
# break in it is read as CBOL running out of column. Below it, the break
# is the editor's.
_ZH_WRAP_RATIO = 0.70


def _is_zh_pos_line(line: str) -> bool:
    """True when the whole line is grammatical metadata."""
    toks = [t for t in _ZH_POS_SEP.split(line.strip()) if t]
    return bool(toks) and all(t in _ZH_POS_TERMS for t in toks)


def _display_width(line: str) -> int:
    """Columns `line` occupies in CBOL's fixed-width layout."""
    return sum(2 if unicodedata.east_asian_width(c) in 'WF' else 1
               for c in line)


def sense_one_gloss(body: str) -> str:
    """Sense 1 of a CBOL definition body, joined across the physical
    lines CBOL happened to wrap it on.

    Until 2026-08-23 this kept only the FIRST line, and the docstring
    called that "short but accurate". It was short. For 491 entries it
    was not accurate: CBOL wraps a long sense at its own column width,
    so `H204` shipped as `位于埃及低地的一个城市, 歌珊的边界处,
    崇拜太阳神的中心,` — a gloss ending on a comma, with the clause that
    names it as Potiphera's home town on line two. `glossZh` is the row
    summary in the Lexicon Browser, so these were on screen (check 44f).

    A following line ends sense 1 when it is blank, when it opens a new
    numbered item (`2)` or `1a)`), or when it is grammatical metadata.

    Otherwise the question is whether CBOL broke the line or the editor
    did, because CBOL uses one newline for both. Not every break is a
    wrap: G749's sense 1 is `祭司长, 大祭司` on a 17-column line in an
    entry whose other lines run to 90, and the next line begins a fresh
    article. Joining those two produced `大祭司在祭司中最大的一` — a
    reading found in no lexicon. So a break counts as a wrap only when
    the line it ends could not have held more: it dangles on a separator,
    or it is unterminated AND reaches `_ZH_WRAP_RATIO` of the widest line
    in its own entry. The comparison is per entry because the corpus has
    no single column width — the sense-1 line widths run continuously
    from 5 to 99 with no gap to cut at.

    The join is direct between two wide characters and spaced otherwise.
    A space is not a word boundary in Chinese: joining `藉着神所赐` to
    `解梦的恩赐` with one would invent a break inside a phrase (H1841,
    H3038 `他的后` + `裔`, H6540 `里` + `海和`), while `崇拜太阳神的中心,`
    + `波提非拉` needs the space CBOL's own style puts after a comma.

    Finally a trailing separator is dropped. After joining, one can only
    be CBOL's own — measured across both lexicons, every gloss still
    ending on a comma is followed by a sub-sense, the next sense, or the
    end of the body, and never by text we declined to take.
    """
    if not body:
        return ''
    lines = body.split('\n')
    start = None
    for i, ln in enumerate(lines):
        if re.match(r'^\s*1\)\s*\S', ln):
            start = i
            break
    if start is None:
        for i, ln in enumerate(lines):
            if re.match(r'^\s*\d+[a-zA-Z]*\)\s*\S', ln):
                start = i
                break
    if start is None:
        return ''
    wrap = max(_display_width(ln.rstrip()) for ln in lines)
    out = re.sub(r'^\s*\d+[a-zA-Z]*\)\s*', '', lines[start]).strip()
    prev = lines[start].rstrip()
    for ln in lines[start + 1:]:
        piece = ln.strip()
        if not piece or _ZH_NUMBERED.match(ln) or _is_zh_pos_line(ln):
            break
        if not _ZH_DANGLING.search(prev):
            if _ZH_TERMINAL.search(prev):
                break
            if _display_width(prev) < _ZH_WRAP_RATIO * wrap:
                break
        prev = ln.rstrip()
        joint = out and (_ZH_LEADS_TIGHT.match(piece[0])
                         or (_ZH_WIDE.match(out[-1])
                             and _ZH_WIDE.match(piece[0])))
        if joint:
            out += piece
        elif out:
            out += ' ' + piece
        else:
            out = piece
    return out.rstrip(' \t,，、;；')


def _parse_zh_strongs_body(raw: str) -> tuple[str, str]:
    """Extract a (gloss_zh, def_zh) pair from a CBOL Chinese Strong's
    body. The body's shape is roughly:

        <num> <translit> {<pron>}
        <blank>
        <etymology>; <part of speech>; <TWOT/TDNT refs>
        <blank>
        钦定本 - <KJV usage>; <count>
        <blank>
        1) <main definition>
           1a) <sub-definition>
           ...
        2) <main definition>
           ...

    For `def_zh` we keep everything from the first numbered line to the
    end. `gloss_zh` is sense 1, whole — see `sense_one_gloss`, which
    also handles CBOL's inconsistent spacing after the `1)` marker
    (G25 has `1)珍爱`, G2316 has `1) 神或女神`) and its habit of
    wrapping one sense across several printed lines.
    """
    if not raw:
        return ('', '')
    lines = raw.split('\n')
    def_start = None
    for i, ln in enumerate(lines):
        # `\s*` instead of `\s` so we catch both `1) text` and `1)text`.
        if re.match(r'^\s*\d+\)\s*\S', ln):
            def_start = i
            break
    if def_start is None:
        return ('', raw.strip())
    body = '\n'.join(lines[def_start:]).rstrip()
    return (sense_one_gloss(body), body.strip())


def _load_zh_strongs(url: str, cache_name: str, prefix: str) -> dict[str, tuple[str, str]]:
    """Fetch a CBOL Chinese Strong's JSON file (a list of single-pair
    objects keyed by zero-padded numbers like "02316" or "07225") and
    return `{ "G2316": (gloss_zh, def_zh), ... }` keyed in our format.
    """
    raw = fetch(url, cache_name).decode('utf-8', errors='replace')
    items = json.loads(raw)
    out: dict[str, tuple[str, str]] = {}
    for entry in items:
        for key, body in entry.items():
            if not body:
                continue
            # CBOL uses 5-digit zero padding plus optional a/b suffix
            # variants. We don't differentiate variants: the leading
            # numeric portion is the canonical Strong's number.
            m = re.match(r'^0*(\d+)', key)
            if not m:
                continue
            our_key = f'{prefix}{m.group(1)}'
            # If a variant collides with the base number, prefer the
            # first non-empty body (canonical form).
            if our_key in out:
                continue
            gloss, full = _parse_zh_strongs_body(body)
            if not gloss and not full:
                continue
            out[our_key] = (gloss, full)
    return out


def build_strongs() -> None:
    print('Strong\'s lexicons:')
    he_js = fetch(STRONGS_HEBREW_URL, 'strongs-hebrew.js').decode('utf-8')
    gr_js = fetch(STRONGS_GREEK_URL, 'strongs-greek.js').decode('utf-8')
    he = _parse_strongs_js(he_js)
    gr = _parse_strongs_js(gr_js)
    out_he = {k: _normalize_strongs_entry(k, v) for k, v in he.items()}
    out_gr = {k: _normalize_strongs_entry(k, v) for k, v in gr.items()}

    # Merge in CBOL Chinese definitions where available. Keys missing
    # from the Chinese source keep only English fields, so the UI's
    # locale-fallback logic handles partial coverage gracefully.
    print('  + CBOL Chinese (CC-BY-NC-SA)')
    zh_he = _load_zh_strongs(ZH_STRONGS_HEBREW_URL, 'cbol-hebrew.json', 'H')
    zh_gr = _load_zh_strongs(ZH_STRONGS_GREEK_URL, 'cbol-greek.json', 'G')
    he_matched = 0
    for k, (gloss_zh, def_zh) in zh_he.items():
        if k in out_he:
            out_he[k]['glossZh'] = gloss_zh
            out_he[k]['defZh'] = def_zh
            he_matched += 1
    gr_matched = 0
    for k, (gloss_zh, def_zh) in zh_gr.items():
        if k in out_gr:
            out_gr[k]['glossZh'] = gloss_zh
            out_gr[k]['defZh'] = def_zh
            gr_matched += 1
    print(f'    matched {he_matched} Hebrew + {gr_matched} Greek')

    os.makedirs(STRONGS_DIR, exist_ok=True)
    with open(os.path.join(STRONGS_DIR, 'hebrew.json'), 'w',
              encoding='utf-8') as f:
        json.dump(out_he, f, ensure_ascii=False, separators=(',', ':'))
    with open(os.path.join(STRONGS_DIR, 'greek.json'), 'w',
              encoding='utf-8') as f:
        json.dump(out_gr, f, ensure_ascii=False, separators=(',', ':'))
    print(f'  wrote {len(out_he)} Hebrew + {len(out_gr)} Greek entries')


# ── Hebrew OT (morphhb / WLC) ──────────────────────────────────────────


def _hebrew_strongs(s_attr: str) -> str:
    """morphhb's @lemma can be like '7225 a' (Strong's number plus a sub
    letter, sometimes with prefix codes joined by '/'). Normalize to the
    rightmost numeric token, prefixed with H."""
    if not s_attr:
        return ''
    # Strip prefix codes joined by '/': '7225/853'
    parts = re.split(r'[\s/]+', s_attr.strip())
    for p in reversed(parts):
        m = re.match(r'(\d+)', p)
        if m:
            return 'H' + m.group(1)
    return ''


def wlc_verse_words(verse) -> list[dict]:
    """Every word of one WLC `<verse>`, in document order, each tagged
    with its Ketiv/Qere role under `kq`.

    An explicit descent, NOT `verse.iter(w)`. `iter` walks descendants,
    and the WLC hides the Qere inside an apparatus note —
    `<note type="variant"><rdg type="x-qere"><w>…`. A descendant walk
    therefore lifted the marginal reading into the running text with
    nothing to say it came from the margin, and 1,103 verses shipped a
    word printed twice: 2 Samuel 18:20 as `כי על על כן`, Genesis 30:11
    as `בגד בא גד`. Both readings are kept — BibleWorks keeps both too,
    tagging them Rk/Rq/Rx and letting the reader exclude either
    (help topics bwh17, bwh29) — but each is now labelled.

    Four roles, because two would make the app say something false at
    fifteen sites:

      k   Ketiv, with a Qere directing what to read instead.
      q   that Qere.
      kx  *Ketiv velo Qere* — written, and marked NOT to be read at all
          (an empty `<rdg type="x-qere"/>`). Six sites: 2 Kings 5:18,
          Jeremiah 38:16, 39:12, 51:3, Ezekiel 48:16, Ruth 3:12.
      qx  *Qere velo Ketiv* — read though the text writes nothing.
          Nine sites, among them 2 Samuel 8:3 and Ruth 3:5, 3:17.

    The role is decided on the RAW apparatus, before the Strong's-number
    filter below drops a word: whether the Masoretes wrote a counterpart
    is a fact about the manuscript, not about what this importer keeps.
    """
    raw: list[dict] = []

    def walk(el) -> None:
        for child in el:
            if child.tag == f'{NS_OSIS}w':
                raw.append({
                    'el': child,
                    'kind': 'k' if child.get('type') == 'x-ketiv' else '',
                    'site': None,
                })
            elif child.tag == f'{NS_OSIS}note' and any(
                    r.get('type') == 'x-qere'
                    for r in child.iter(f'{NS_OSIS}rdg')):
                site = {'k': 0, 'q': 0}
                # The Ketiv is the contiguous run of x-ketiv words
                # standing immediately before this note.
                i = len(raw) - 1
                while i >= 0 and raw[i]['kind'] == 'k' \
                        and raw[i]['site'] is None:
                    raw[i]['site'] = site
                    site['k'] += 1
                    i -= 1
                for rdg in child.iter(f'{NS_OSIS}rdg'):
                    if rdg.get('type') != 'x-qere':
                        continue
                    for w in rdg.iter(f'{NS_OSIS}w'):
                        raw.append({'el': w, 'kind': 'q', 'site': site})
                        site['q'] += 1
            else:
                walk(child)

    walk(verse)

    words: list[dict] = []
    for entry in raw:
        el = entry['el']
        text = ''.join(el.itertext()).strip()
        if not text:
            continue
        # morphhb encodes prefix/root boundaries with `/` (e.g.
        # "בְּ/רֵאשִׁית"). Strip them so the surface form matches the
        # way the word reads in a Hebrew Bible.
        text = text.replace('/', '')
        s = _hebrew_strongs(el.get('lemma', ''))
        if not s:
            continue
        word = {'w': text, 's': s}
        site = entry['site']
        if entry['kind'] == 'k':
            word['kq'] = 'k' if site and site['q'] else 'kx'
        elif entry['kind'] == 'q':
            word['kq'] = 'q' if site and site['k'] else 'qx'
        words.append(word)
    return words


def parse_morphhb_book(osis: str) -> dict:
    raw = fetch(MORPHHB_BOOKS_URL.format(osis=osis), f'morphhb-{osis}.xml')
    root = ET.fromstring(raw)
    out: dict[str, list] = {}
    # Each <verse osisID="Gen.1.1">
    for verse in root.iter(f'{NS_OSIS}verse'):
        osis_id = verse.get('osisID') or verse.get('sID')
        if not osis_id or 'sID' in (verse.attrib or {}) and verse.get('eID'):
            # Skip milestone close tags — they only appear with eID
            pass
        if not osis_id:
            continue
        m = re.match(r'^[^.]+\.(\d+)\.(\d+)$', osis_id)
        if not m:
            continue
        ch, vs = int(m.group(1)), int(m.group(2))
        words = wlc_verse_words(verse)
        if words:
            out[f'{ch}:{vs}'] = words
    return out


def build_hebrew_ot() -> None:
    print('Hebrew OT (morphhb):')
    os.makedirs(ORIGINALS_DIR, exist_ok=True)
    for osis, english in OSIS_HEBREW:
        try:
            book_data = parse_morphhb_book(osis)
        except Exception as e:
            print(f'  skip {english} ({osis}): {e}')
            continue
        slug = english.lower().replace(' ', '_')
        path = os.path.join(ORIGINALS_DIR, f'{slug}.json')
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(book_data, f, ensure_ascii=False, separators=(',', ':'))
        print(f'  wrote {english}: {len(book_data)} verses')


# ── Greek NT (OpenGNT CSV) ─────────────────────────────────────────────


def _split_grouped(field: str) -> list[str]:
    """OpenGNT groups multiple sub-fields like 〔a｜b｜c〕. Strip the
    bracket pair and split on the full-width pipe."""
    s = field.strip()
    if s.startswith('〔') and s.endswith('〕'):
        s = s[1:-1]
    return s.split('｜')


def parse_opengnt() -> dict[str, dict[str, list]]:
    """Returns {english_book: {"chap:verse": [{w,s,t}, ...]}}.

    OpenGNT v3.3 schema (tab-delimited, header row first):
      col 6  〔Book｜Chapter｜Verse〕                e.g. 〔43｜3｜16〕
      col 7  〔OGNTk｜OGNTu｜OGNTa｜lexeme｜rmac｜sn〕  accented form + Strong's
      col 9  〔transSBLcap｜transSBL｜modernGreek｜Fon〕

    We pull the accented surface form, the Strong's number, and the
    SBL transliteration.
    """
    zdata = fetch(OPENGNT_ZIP_URL, 'opengnt.zip')
    with zipfile.ZipFile(io.BytesIO(zdata)) as zf:
        with zf.open(OPENGNT_CSV_NAME) as f:
            raw = f.read().decode('utf-8', errors='replace')

    by_book: dict[str, dict[str, list]] = {}
    reader = csv.reader(io.StringIO(raw), delimiter='\t')
    header = next(reader, None)
    if not header:
        return by_book

    def _idx(want_subs: list[str]) -> int:
        for i, h in enumerate(header):
            low = h.lower()
            if all(s in low for s in want_subs):
                return i
        raise SystemExit(
            f'OpenGNT header missing column: {want_subs}; got {header}')

    bcv_col = _idx(['book', 'chapter', 'verse'])
    word_col = _idx(['ogntk', 'ogntu', 'ognta'])
    translit_col = _idx(['transsblcap', 'transsbl'])

    for row in reader:
        if not row or len(row) <= max(bcv_col, word_col, translit_col):
            continue
        bcv_parts = _split_grouped(row[bcv_col])
        if len(bcv_parts) < 3:
            continue
        try:
            book_n = int(bcv_parts[0])
            ch = int(bcv_parts[1])
            vs = int(bcv_parts[2])
        except ValueError:
            continue
        english = OPENGNT_BOOK.get(book_n)
        if not english:
            continue

        word_parts = _split_grouped(row[word_col])
        # OGNTa (accented) is index 2; sn (Strong's) is index 5.
        if len(word_parts) < 6:
            continue
        word = word_parts[2].strip()
        strongs_field = word_parts[5].strip()
        if not word:
            continue
        m = re.search(r'(\d+)', strongs_field)
        if not m:
            continue
        s_num = 'G' + m.group(1)

        translit_parts = _split_grouped(row[translit_col])
        # transSBL is index 1.
        translit = translit_parts[1].strip() if len(translit_parts) > 1 else ''

        bk = by_book.setdefault(english, {})
        verses = bk.setdefault(f'{ch}:{vs}', [])
        entry = {'w': word, 's': s_num}
        if translit:
            entry['t'] = translit
        verses.append(entry)
    return by_book


def build_greek_nt() -> None:
    print('Greek NT (OpenGNT):')
    os.makedirs(ORIGINALS_DIR, exist_ok=True)
    by_book = parse_opengnt()
    for english, book_data in by_book.items():
        slug = english.lower().replace(' ', '_')
        path = os.path.join(ORIGINALS_DIR, f'{slug}.json')
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(book_data, f, ensure_ascii=False, separators=(',', ':'))
        print(f'  wrote {english}: {len(book_data)} verses')


# ── Concordance (inverted index over the bundled originals) ────────────

# There used to be a 500-reference cap here, on the reasoning that the
# common words would balloon the bundle and that the absolute count was
# preserved separately anyway. Both were true and the conclusion was
# still wrong: `r` is in canonical order, so a capped entry is not a
# sample of the word, it is a PREFIX OF THE CANON. H3068's 500 verses
# stopped inside Leviticus, and every consumer that filters or intersects
# `r` — the `l` search limit, the AND/OR/NEAR set algebra — read that
# prefix as the whole. `l jer` then answered H3068 with zero verses in a
# book that carries the divine name 712 times, and said so confidently.
#
# 123 of 14,039 entries reached the cap. Removing it costs 1.75 MB raw /
# 307 KB gzipped and makes the index a census, which is what every
# consumer already assumed it was.

# Canonical book ordering used to sort references within a Strong's
# entry. Matches lib/services/fetch_books.dart `standardBookOrder`.
CANONICAL_ORDER = [
    'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
    'Joshua', 'Judges', 'Ruth',
    '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
    '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther',
    'Job', 'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Solomon',
    'Isaiah', 'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel',
    'Hosea', 'Joel', 'Amos', 'Obadiah', 'Jonah', 'Micah',
    'Nahum', 'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
    'Matthew', 'Mark', 'Luke', 'John', 'Acts',
    'Romans', '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
    'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
    '1 Timothy', '2 Timothy', 'Titus', 'Philemon',
    'Hebrews', 'James', '1 Peter', '2 Peter',
    '1 John', '2 John', '3 John', 'Jude', 'Revelation',
]
_BOOK_INDEX = {b: i for i, b in enumerate(CANONICAL_ORDER)}


def build_concordance() -> None:
    """Walk every per-book file in assets/originals/ and emit an inverted
    index keyed by Strong's number. Output: assets/strongs/concordance.json
    shaped as:
        { "G2316": {
            "n": 1320,                       # absolute count
            "r": ["Matt 1:23", ...],         # every verse, canonical order
            "b": {"Matthew": 51, ... }       # per-book counts
          }, ... }

    `n` counts OCCURRENCES and `r` lists VERSES, so they differ whenever a
    word recurs inside one verse (G25: 143 occurrences in 110 verses).
    Both are complete. `b` lets the runtime render statistical
    distribution panels (Pauline / Johannine / per-book) without having
    to parse every ref string.
    """
    print('Concordance (inverted index):')
    if not os.path.isdir(ORIGINALS_DIR):
        print('  no originals/ directory, skipping')
        return

    counts: dict[str, int] = {}
    refs: dict[str, list[tuple[int, int, int, str]]] = {}
    # Per-Strong's per-book absolute counts: { strongs: { english_book: n } }
    by_book: dict[str, dict[str, int]] = {}

    for fname in sorted(os.listdir(ORIGINALS_DIR)):
        if not fname.endswith('.json'):
            continue
        with open(os.path.join(ORIGINALS_DIR, fname), 'r',
                  encoding='utf-8') as f:
            book_data = json.load(f)
        # Recover canonical English name from the file slug. Build a
        # reverse map once.
        slug = fname[:-5]
        # Pre-compute slug → english name for canonical ordering.
        english = next((b for b in CANONICAL_ORDER if
                        b.lower().replace(' ', '_') == slug), None)
        if not english:
            continue
        book_idx = _BOOK_INDEX[english]
        for cv, words in book_data.items():
            try:
                ch, vs = (int(p) for p in cv.split(':'))
            except ValueError:
                continue
            ref_str = f'{english} {ch}:{vs}'
            seen_in_verse: set[str] = set()
            for w in words:
                s = w.get('s')
                if not s:
                    continue
                counts[s] = counts.get(s, 0) + 1
                bbook = by_book.setdefault(s, {})
                bbook[english] = bbook.get(english, 0) + 1
                # De-dup within a single verse so the same ref doesn't
                # appear twice when a word recurs (very common for the
                # Hebrew direct-object marker H853 and Greek article).
                if s in seen_in_verse:
                    continue
                seen_in_verse.add(s)
                refs.setdefault(s, []).append((book_idx, ch, vs, ref_str))

    out: dict[str, dict] = {}
    for s, occurrences in refs.items():
        occurrences.sort()
        out[s] = {
            'n': counts[s],
            'r': [r[3] for r in occurrences],
            'b': by_book.get(s, {}),
        }

    os.makedirs(STRONGS_DIR, exist_ok=True)
    path = os.path.join(STRONGS_DIR, 'concordance.json')
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, separators=(',', ':'))
    total_refs = sum(len(v['r']) for v in out.values())
    print(f'  wrote {len(out)} Strong\'s with {total_refs} verse refs '
          f'(complete, no per-entry cap) + per-book counts')


# ── CLI ────────────────────────────────────────────────────────────────


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--skip-strongs', action='store_true')
    parser.add_argument('--skip-hebrew', action='store_true')
    parser.add_argument('--skip-greek', action='store_true')
    parser.add_argument('--skip-concordance', action='store_true',
                        help='Skip rebuilding the inverted-index file.')
    args = parser.parse_args()

    if not args.skip_strongs:
        build_strongs()
    if not args.skip_hebrew:
        build_hebrew_ot()
    if not args.skip_greek:
        build_greek_nt()
    # Concordance reads from the per-book files written above, so it
    # must run last. Skip it explicitly when iterating only on a single
    # half (the existing index will be left in place).
    if not args.skip_concordance:
        build_concordance()
    print('done.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
