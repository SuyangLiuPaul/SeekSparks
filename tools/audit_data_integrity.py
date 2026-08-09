#!/usr/bin/env python3
"""Cross-checks the shipped data assets against each other and reports
every disagreement with a count.

Task #304. The premise, in the user's words: "accuracy is the most
critical and important thing". #303 found a wrong transliteration on
8,030 word-list rows and it surfaced only because one reader happened to
look at one row. The test suite proves the code RUNS; nothing proved the
data was TRUE. This tool is the standing answer: where two assets
describe the same fact from different directions, a disagreement is a
bug in one of them, and it can be counted before a reader finds it.

Checks that need the app's own Dart code (morphology decoding, the
book-name mapping) live in `test/data_integrity_test.dart` instead —
re-implementing a decoder in Python would only prove the Python agrees
with itself.

Usage: python3 tools/audit_data_integrity.py [--json]
Exit code is always 0; this reports, it does not gate. The cheap
invariants that MUST hold are Dart tests.
"""

import glob
import json
import os
import re
import sys
import unicodedata
from collections import Counter, defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def asset(*parts):
    return os.path.join(ROOT, 'assets', *parts)


def load(*parts):
    with open(asset(*parts), encoding='utf-8') as f:
        return json.load(f)


# Eagle's View NASB derivatives are licensed, never shipped, and must not
# be treated as versions here either.
EXCLUDED_VERSIONS = {'nasb-ev', 'nsn-plus'}

results = []


def record(name, examined, disagreements, note):
    results.append({
        'check': name,
        'examined': examined,
        'disagreements': disagreements,
        'note': note,
    })
    flag = 'OK  ' if disagreements == 0 else 'FAIL'
    print(f'[{flag}] {name}: examined {examined:,}, disagreements {disagreements:,}')
    for line in note.splitlines():
        print(f'        {line}')
    print()


# --------------------------------------------------------------------
# The canon. KJV versification, 31,102 verses, is the reference frame
# every other check measures against: it is the only shipped text that
# is both complete and the traditional numbering other assets' verse
# references were written for.
# --------------------------------------------------------------------

def load_canon():
    kjv = load('kjv.json')
    refs = set()
    order = []
    chapters = defaultdict(set)
    for v in kjv:
        b, c, n = v['book'], int(v['chapter']), int(v['verse'])
        if b not in chapters:
            order.append(b)
        refs.add((b, c, n))
        chapters[b].add(c)
    return refs, order, chapters


CANON, BOOK_ORDER, CANON_CHAPTERS = load_canon()
CANON_BOOKS = set(BOOK_ORDER)
OT_BOOKS = set(BOOK_ORDER[:39])
NT_BOOKS = set(BOOK_ORDER[39:])


def slug(book):
    return book.lower().replace(' ', '_')


SLUG_TO_BOOK = {slug(b): b for b in BOOK_ORDER}


# --------------------------------------------------------------------
# 1. Every Strong's number in the corpus has a lexicon entry, and no
#    book carries a number from the wrong language.
# --------------------------------------------------------------------

def check_strongs_coverage(originals):
    greek = load('strongs', 'greek.json')
    hebrew = load('strongs', 'hebrew.json')
    lex = set(greek) | set(hebrew)

    seen = Counter()
    missing = Counter()
    wrong_language = Counter()
    for book, verses in originals.items():
        nt = book in NT_BOOKS
        for words in verses.values():
            for w in words:
                s = w.get('s')
                if not s:
                    continue
                seen[s] += 1
                if s not in lex:
                    missing[s] += 1
                if (s[0] == 'G') != nt:
                    wrong_language[(book, s)] += 1

    ordered = sorted(missing, key=lambda s: (s[0], int(s[1:])))
    note = (
        f'{len(seen):,} distinct Strong\'s numbers over '
        f'{sum(seen.values()):,} tagged words.\n'
        f'{len(missing)} have no lexicon entry, covering '
        f'{sum(missing.values()):,} words: {", ".join(ordered)}\n'
        f'Language prefix vs testament: {len(wrong_language)} mismatches.'
    )
    record('1. Strong\'s numbers resolve to a lexicon entry',
           sum(seen.values()), sum(missing.values()) + sum(wrong_language.values()),
           note)
    return set(ordered)


# --------------------------------------------------------------------
# 2. Morphology codes. Extracted here, decoded in Dart — see
#    tool/dump_morph_codes.py output consumed by the Dart test.
# --------------------------------------------------------------------

def check_morphology_presence(originals):
    total = 0
    empty = Counter()
    codes = Counter()
    for book, verses in originals.items():
        for words in verses.values():
            for w in words:
                total += 1
                m = (w.get('m') or '').strip()
                if not m:
                    empty[book] += 1
                else:
                    codes[m] += 1
    worst = ', '.join(f'{b} {n:,}' for b, n in empty.most_common(5))
    note = (
        f'{len(codes):,} distinct morphology codes.\n'
        f'{sum(empty.values()):,} words carry no code at all '
        f'({len(empty)} books affected). Worst: {worst or "none"}\n'
        'Decodability of the distinct codes is checked in Dart '
        '(test/data_integrity_test.dart) against describeMorphology.'
    )
    record('2a. Morphology codes present', total, sum(empty.values()), note)
    with open(os.path.join(ROOT, 'build', 'morph_codes.txt'), 'w',
              encoding='utf-8') as f:
        for c, n in sorted(codes.items()):
            f.write(f'{c}\t{n}\n')
    return codes


# --------------------------------------------------------------------
# 3. concordance.json is internally consistent, and agrees with the
#    corpus it claims to count.
# --------------------------------------------------------------------

def check_concordance(originals):
    conc = load('strongs', 'concordance.json')

    bad_sum = []
    for s, e in conc.items():
        if sum(e.get('b', {}).values()) != e.get('n'):
            bad_sum.append(s)
    note_a = (
        f'{len(conc):,} Strong\'s entries. '
        f'{len(bad_sum)} where the per-book map does not sum to n.'
    )
    if bad_sum:
        note_a += '\nFirst: ' + ', '.join(bad_sum[:10])
    record('3a. concordance.json per-book counts sum to n',
           len(conc), len(bad_sum), note_a)

    # Cross-source: what assets/originals actually contains.
    corpus = defaultdict(Counter)
    for book, verses in originals.items():
        for words in verses.values():
            for w in words:
                s = w.get('s')
                if s:
                    corpus[s][book] += 1

    only_conc = sorted(set(conc) - set(corpus))
    only_corpus = sorted(set(corpus) - set(conc))
    disagree_total = []
    disagree_book = 0
    for s in sorted(set(conc) & set(corpus)):
        c_books = conc[s].get('b', {})
        o_books = corpus[s]
        if sum(c_books.values()) != sum(o_books.values()):
            disagree_total.append(s)
        for b in set(c_books) | set(o_books):
            if c_books.get(b, 0) != o_books.get(b, 0):
                disagree_book += 1

    sample = ', '.join(
        f'{s} conc={sum(conc[s]["b"].values())} corpus={sum(corpus[s].values())}'
        for s in disagree_total[:5])
    note_b = (
        f'{len(set(conc) | set(corpus)):,} Strong\'s numbers across both sources.\n'
        f'{len(only_conc)} only in concordance.json, '
        f'{len(only_corpus)} only in assets/originals.\n'
        f'{len(disagree_total)} disagree on the total; '
        f'{disagree_book} book-level cells disagree.\n'
        + (f'Sample: {sample}' if sample else '')
    )
    record('3b. concordance.json totals agree with assets/originals',
           len(set(conc) | set(corpus)),
           len(only_conc) + len(only_corpus) + len(disagree_total),
           note_b)


# --------------------------------------------------------------------
# 4. Verse coverage per shipped version.
# --------------------------------------------------------------------

def check_versions():
    files = sorted(
        f for f in os.listdir(asset())
        if f.endswith('.json')
    )
    rows = []
    total_gaps = 0
    examined = 0
    for f in files:
        code = f[:-5]
        if code in EXCLUDED_VERSIONS:
            continue
        try:
            data = load(f)
        except Exception:
            continue
        if not (isinstance(data, list) and data and isinstance(data[0], dict)
                and 'book' in data[0] and 'verse' in data[0]):
            continue
        refs = set()
        for v in data:
            try:
                refs.add((zh_to_en(v['book']), int(v['chapter']), int(v['verse'])))
            except (ValueError, TypeError):
                continue
        examined += len(data)
        books = {b for b, _, _ in refs}
        # A version is only measured against the books it claims to
        # carry: a NT-only edition is not "missing" the Hebrew Bible.
        scope = {r for r in CANON if r[0] in books}
        missing = scope - refs
        extra = refs - CANON
        unknown_books = books - CANON_BOOKS
        total_gaps += len(missing) + len(extra)
        by_book = Counter(b for b, _, _ in missing)
        absent_books = [b for b in BOOK_ORDER
                        if b not in books and books & OT_BOOKS and books & NT_BOOKS]
        rows.append((code, len(data), len(books), len(missing), extra,
                     by_book, unknown_books, absent_books))

    lines = []
    for code, n, nb, miss, extra, by_book, unknown, absent in rows:
        detail = ''
        if miss:
            detail = ' missing in ' + ', '.join(
                f'{b} {c}' for b, c in by_book.most_common(6))
        if extra:
            detail += ' beyond-canon: ' + ', '.join(
                f'{b} {c}:{v}' for b, c, v in sorted(extra)[:6])
        if absent:
            detail += ' WHOLE BOOKS ABSENT: ' + ', '.join(absent)
        if unknown:
            detail += ' UNMAPPED BOOKS: ' + ', '.join(sorted(unknown))
        lines.append(
            f'{code:16s} verses={n:6,d} books={nb:3d} '
            f'gaps={miss:5,d} extra={len(extra):4,d}{detail}')
    record('4. Verse coverage per version vs the 31,102-verse canon',
           examined, total_gaps, '\n'.join(lines))
    return rows


ZH_TO_EN = None


def zh_to_en(book):
    """Maps a Chinese book name to its canonical English name using the
    app's own table, so the audit cannot drift from what ships."""
    global ZH_TO_EN
    if ZH_TO_EN is None:
        ZH_TO_EN = parse_book_name_mapping()
    return ZH_TO_EN.get(book, book)


def parse_book_name_mapping():
    """Reads the zh->en pairs out of lib/constants/book_name_mapping.dart.

    Parsing Dart from Python is ugly, but the alternative is a second
    copy of a 66-row table that would silently rot the first time a name
    is corrected in one place only."""
    path = os.path.join(ROOT, 'lib', 'constants', 'book_name_mapping.dart')
    src = open(path, encoding='utf-8').read()
    out = {}
    for zh, en in re.findall(r"'([^']*[一-鿿][^']*)'\s*:\s*'([A-Za-z0-9 ]+)'", src):
        if en in CANON_BOOKS:
            out.setdefault(zh, en)
    return out


# --------------------------------------------------------------------
# 5. Cross-reference targets resolve.
# --------------------------------------------------------------------

REF_RE = re.compile(r'^(.+?)\s+(\d+):(\d+)(?:-(\d+))?$')


def check_cross_references():
    data = load('cross_references.json')
    bad_source = []
    bad_target = Counter()
    targets = 0
    sources = 0
    for src, tgts in data.items():
        if src == '_meta':
            continue
        sources += 1
        if not resolves(src):
            bad_source.append(src)
        for t in tgts:
            targets += 1
            if not resolves(t):
                bad_target[t] += 1
    note = (
        f'{sources:,} source verses, {targets:,} target references.\n'
        f'{len(bad_source)} sources and {len(bad_target)} distinct targets '
        f'({sum(bad_target.values()):,} occurrences) do not resolve to a '
        'verse in the canon.\n'
        + ('Sample targets: ' + ', '.join(list(bad_target)[:8])
           if bad_target else '')
        + ('\nSample sources: ' + ', '.join(bad_source[:8])
           if bad_source else '')
    )
    record('5. cross_references.json targets resolve',
           sources + targets, len(bad_source) + sum(bad_target.values()), note)


def resolves(ref):
    m = REF_RE.match(ref.strip())
    if not m:
        return False
    book, ch, v1, v2 = m.group(1), int(m.group(2)), int(m.group(3)), m.group(4)
    if book not in CANON_BOOKS:
        return False
    if (book, ch, v1) not in CANON:
        return False
    if v2 is not None and (book, ch, int(v2)) not in CANON:
        return False
    return True


# --------------------------------------------------------------------
# 7. Place and name verse links resolve.
# --------------------------------------------------------------------

def parse_place_abbrevs():
    path = os.path.join(ROOT, 'lib', 'utils', 'place_geo.dart')
    src = open(path, encoding='utf-8').read()
    return {a: b for a, b in re.findall(r"'([A-Za-z0-9]{2,5})'\s*:\s*'([A-Za-z0-9 ]+)'", src)
            if b in CANON_BOOKS}


def check_places():
    abbrev = parse_place_abbrevs()
    places = load('bible_places.json')['places']
    refs = 0
    unknown_book = Counter()
    unresolved = Counter()
    no_refs = []
    no_coords = []
    for p in places:
        rs = p.get('refs') or []
        if not rs:
            no_refs.append(p.get('n'))
        if not p.get('ll'):
            no_coords.append(p.get('n'))
        for r in rs:
            refs += 1
            book = abbrev.get(r.get('book'))
            if book is None:
                unknown_book[r.get('book')] += 1
                continue
            if (book, int(r['chapter']), int(r['verse'])) not in CANON:
                unresolved[f"{book} {r['chapter']}:{r['verse']}"] += 1
    note = (
        f'{len(places):,} places, {refs:,} verse links.\n'
        f'{len(unknown_book)} unmapped book abbreviations '
        f'({sum(unknown_book.values()):,} links): '
        f'{", ".join(list(unknown_book)[:10]) or "none"}\n'
        f'{len(unresolved)} links point outside the canon '
        f'({sum(unresolved.values()):,} occurrences): '
        f'{", ".join(list(unresolved)[:6]) or "none"}\n'
        f'{len(no_refs)} places with no verse link, '
        f'{len(no_coords)} with no coordinates.'
    )
    record('7a. bible_places.json verse links resolve', refs,
           sum(unknown_book.values()) + sum(unresolved.values()), note)

    names = load('bible_names.json')['names']
    with_refs = sum(1 for n in names if n.get('refs'))
    record('7b. bible_names.json verse links', len(names), 0,
           f'{len(names):,} names; {with_refs} carry verse links. '
           'The asset is name -> meaning only (Hitchcock 1869), so there '
           'is nothing to resolve. Unverifiable against scripture by '
           'construction; the attribution field is present.')


# --------------------------------------------------------------------
# 8. Every date shown to a reader has a recorded source.
# --------------------------------------------------------------------

def check_dates():
    findings = []
    total = 0
    unsourced = 0
    for name, key in (('bible_timeline.json', None),
                      ('family_tree.json', None),
                      ('hebrew_kings.json', None)):
        path = asset(name)
        if not os.path.exists(path):
            findings.append(f'{name}: absent')
            continue
        raw = open(path, encoding='utf-8').read()
        data = json.loads(raw)
        dated, sourced = count_dates(data)
        total += dated
        has_meta = any(k in raw for k in
                       ('"source"', '"citation"', '"system"', '"attribution"'))
        if not has_meta:
            unsourced += dated
        findings.append(
            f'{name}: {dated:,} dated records, '
            f'{sourced:,} carrying a per-record source; '
            f'file-level provenance: {"present" if has_meta else "ABSENT"}')
    record('8. Dates carry a recorded source', total, unsourced,
           '\n'.join(findings))


DATE_KEYS = ('year', 'date', 'start', 'end', 'bc', 'from', 'to',
             'startYear', 'endYear', 'reignStart', 'reignEnd')
SOURCE_KEYS = ('source', 'citation', 'system', 'sources', 'reference')


def count_dates(node, dated=0, sourced=0):
    if isinstance(node, dict):
        has_date = any(k in node and node[k] not in (None, '') for k in DATE_KEYS)
        if has_date:
            dated += 1
            if any(k in node for k in SOURCE_KEYS):
                sourced += 1
        for v in node.values():
            dated, sourced = count_dates(v, dated, sourced)
    elif isinstance(node, list):
        for v in node:
            dated, sourced = count_dates(v, dated, sourced)
    return dated, sourced


# --------------------------------------------------------------------

def check_tagged_layers(originals):
    """Do the per-version tagged layers ask assets/originals questions it
    can answer?

    The two are numbered in different traditions — originals in the
    Masoretic / critical text, every layer in the English — so they are
    joined through `assets/versification.json`, not directly. What this
    measures is the RESIDUAL: a reference the map still cannot resolve,
    or an original verse no reference reaches. Comparing the key sets
    raw, as this check did before the map existed, reported 152/204 and
    understated the defect by an order of magnitude — walking every
    reference found 1,823 resolving to another verse. See
    docs/DATA-INTEGRITY.md check 9."""
    root = asset('tagged')
    with open(asset('versification.json'), encoding='utf-8') as f:
        v11n = json.load(f)
    v_map = v11n.get('map', {})
    v_absent = v11n.get('absent', {})

    orig_keys = {}
    book_of = {}
    for book, verses in originals.items():
        name = slug(book) + '.json'
        orig_keys[name] = set(verses)
        book_of[name] = book

    lines = []
    total = 0
    examined = 0
    for version in sorted(os.listdir(root)):
        d = os.path.join(root, version)
        if not os.path.isdir(d) or version in EXCLUDED_VERSIONS:
            continue
        unresolved = Counter()
        for name in sorted(os.listdir(d)):
            if name not in orig_keys:
                continue
            rows = v_map.get(book_of[name], {})
            omitted = set(v_absent.get(book_of[name], ()))
            with open(os.path.join(d, name), encoding='utf-8') as f:
                keys = set(json.load(f))
            examined += len(keys)
            missing = 0
            for key in keys:
                if key in omitted:
                    continue
                targets = rows.get(key, [key])
                if not all(t in orig_keys[name] for t in targets):
                    missing += 1
            if missing:
                unresolved[name[:-5]] = missing
        total += sum(unresolved.values())
        lines.append(
            f'{version:12s} {sum(unresolved.values()):4d} references the '
            f'map cannot resolve'
            + (('; ' + ', '.join(f'{b} {n}'
                                 for b, n in unresolved.most_common(5)))
               if unresolved else ''))

    # Reachability is a property of the MAP, so measure it against the
    # complete English reference set rather than any one layer. A layer
    # that simply lacks verses (cuvs-plus's 60, lxxwh's LXX arrangement)
    # would otherwise be charged here for what check 4 already reports.
    canon_keys = defaultdict(set)
    for b, c, n in CANON:
        canon_keys[b].add(f'{c}:{n}')
    orphans = []
    for name, keys in orig_keys.items():
        book = book_of[name]
        rows = v_map.get(book, {})
        reached = set()
        for reader_key in canon_keys[book]:
            reached.update(rows.get(reader_key, [reader_key]))
        orphans += [f'{book} {k}' for k in sorted(keys - reached)]
    total += len(orphans)
    lines.append(
        f'{"the map":12s} {len(orphans):4d} original verses no English '
        f'reference reaches' + (': ' + ', '.join(orphans) if orphans else ''))
    lines.append(
        'Revelation 12:18 is expected and cannot be fixed: KJV renders it '
        'inside 13:1 and BSB inside 12:17, so no single map serves both. '
        'See docs/DATA-INTEGRITY.md check 9.')
    record('9. Tagged layers agree with assets/originals on versification',
           examined, total, '\n'.join(lines))


def load_originals():
    out = {}
    d = asset('originals')
    for f in sorted(os.listdir(d)):
        if not f.endswith('.json'):
            continue
        book = SLUG_TO_BOOK.get(f[:-5])
        if book is None:
            print(f'  !! assets/originals/{f} maps to no canonical book')
            continue
        with open(os.path.join(d, f), encoding='utf-8') as fh:
            out[book] = json.load(fh)
    return out


# --------------------------------------------------------------------
# 9. The character repertoire of the shipped text.
#
#    This is the check that would have caught every single-character
#    corruption #304 found, and none of the others would have. A wrong
#    character throws nothing, breaks no key, and renders — CanvasKit
#    only omits a glyph it has no font for, and the bundled subsets cover
#    every code point in the corpus, so 他们必将你困在你各³ÇÀï drew
#    perfectly legibly on screen as garbage.
#
#    Two rules, both derived from the corpus rather than imagined:
#      * NO format or control characters anywhere. Three U+00AD soft
#        hyphens in biblexg-v2 were the only ones; they are invisible, so
#        the verses carrying them failed exact-phrase search silently.
#      * Chinese scripture is written in a NARROW repertoire. Anything
#        from Bopomofo, Geometric Shapes, CJK Extension A/B or the
#        Latin-1 range is either mojibake or a substituted character.
# --------------------------------------------------------------------

SUSPECT_BLOCKS = [
    (0x0080, 0x00FF, 'Latin-1 Supplement (GBK read as Latin-1)'),
    (0x2500, 0x257F, 'Box Drawing'),
    (0x25A0, 0x25FF, 'Geometric Shapes'),
    (0x3100, 0x312F, 'Bopomofo'),
    (0x3400, 0x4DBF, 'CJK Extension A'),
    (0x20000, 0x2FFFF, 'CJK Extension B and beyond'),
    (0xE000, 0xF8FF, 'Private Use'),
    (0xFFFD, 0xFFFD, 'REPLACEMENT CHARACTER'),
]

# The two exceptions the editions genuinely use: 和合本 sets its long dash
# with U+2500, and 圣经新译本 separates transliterated names with U+00B7
# (本丢·彼拉多). Both were confirmed against the printed editions.
REPERTOIRE_EXCEPTIONS = {'─', '·'}


def _suspect_block(cp):
    for lo, hi, name in SUSPECT_BLOCKS:
        if lo <= cp <= hi:
            return name
    return None


def _all_shipped_text():
    """Yields (source, reference, text) over every shipped asset that
    holds scripture — the flat editions, the tagged layers and the
    originals — so the sweep cannot miss a copy."""
    for path in sorted(glob.glob(asset('*.json'))):
        code = os.path.basename(path)[:-5]
        if code in EXCLUDED_VERSIONS:
            continue
        data = load(f'{code}.json')
        if not isinstance(data, list) or not data or 'verse' not in data[0]:
            continue
        for v in data:
            yield code, f"{v['book']} {v['chapter']}:{v['verse']}", v['text']
    for d in sorted(glob.glob(asset('tagged', '*'))):
        edition = os.path.basename(d)
        if edition in EXCLUDED_VERSIONS:
            continue
        for path in sorted(glob.glob(os.path.join(d, '*.json'))):
            book = os.path.basename(path)[:-5]
            with open(path, encoding='utf-8') as f:
                for ref, words in json.load(f).items():
                    text = ''.join(w.get('w', '') for w in (words or []))
                    yield f'tagged/{edition}', f'{book} {ref}', text
    for path in sorted(glob.glob(asset('originals', '*.json'))):
        book = os.path.basename(path)[:-5]
        with open(path, encoding='utf-8') as f:
            for ref, words in json.load(f).items():
                text = ''.join(w.get('w', '') for w in words)
                yield 'originals', f'{book} {ref}', text


def check_character_repertoire():
    examined = 0
    bad = []
    for source, ref, text in _all_shipped_text():
        examined += len(text)
        chinese = any('一' <= c <= '鿿' for c in text)
        for ch in text:
            if ch in REPERTOIRE_EXCEPTIONS or ch in '\n\t':
                continue
            if unicodedata.category(ch) in ('Cc', 'Cf', 'Co', 'Cs', 'Cn'):
                bad.append((source, ref, ch, 'format or control character'))
                continue
            if not chinese:
                continue
            block = _suspect_block(ord(ch))
            if block:
                bad.append((source, ref, ch, block))
    note = ('every character of every shipped edition, tagged layer and '
            'the originals corpus')
    for source, ref, ch, why in bad[:12]:
        note += f'\n  {source} {ref}: U+{ord(ch):04X} — {why}'
    record('character repertoire', examined, len(bad), note)


# --------------------------------------------------------------------
# 10. The 和合本 merge markers agree across all three editions.
#
#     和合本 combines 71 verses into a neighbour and prints 見上節 in the
#     verse-number column. An edition that drops the marker instead
#     leaves the reference EMPTY, and the reader cannot tell "this verse
#     is printed above" from "this app is broken". cuvs-plus shipped
#     zero of the 71 until v1.6.93.
# --------------------------------------------------------------------

MERGE_MARKER_RE = re.compile(
    r'^(?:<note:\s*)?[〔\[（(]?\s*(?:见上节|見上節|见下节|見下節)\s*[〕\]）)]?>?$')


def check_merge_markers():
    editions = {}
    for code in ('cuvs-yhwh', 'cuvs-yhwh-tr', 'cuvs-plus'):
        editions[code] = {
            (zh_to_en(v['book']) or v['book'], int(v['chapter']),
             int(v['verse'])): v['text']
            for v in load(f'{code}.json')
        }
    sites = sorted(k for k, t in editions['cuvs-yhwh'].items()
                   if MERGE_MARKER_RE.match(t.strip()))
    bad = []
    for code, verses in editions.items():
        for k in sites:
            text = verses.get(k)
            if text is None:
                bad.append(f'{code} {k[0]} {k[1]}:{k[2]}: reference absent')
            elif not MERGE_MARKER_RE.match(text.strip()):
                bad.append(f'{code} {k[0]} {k[1]}:{k[2]}: {text.strip()[:24]!r}')
    note = (f'{len(sites)} merged verses x 3 和合本 editions; every one must '
            'carry the 見上節/見下節 marker')
    for line in bad[:12]:
        note += f'\n  {line}'
    record('和合本 merge markers', len(sites) * 3, len(bad), note)


def main():
    os.makedirs(os.path.join(ROOT, 'build'), exist_ok=True)
    print('Data-integrity audit (#304)\n' + '=' * 60 + '\n')
    originals = load_originals()
    print(f'assets/originals: {len(originals)} books, '
          f'{sum(len(v) for v in originals.values()):,} verses\n')
    check_strongs_coverage(originals)
    check_morphology_presence(originals)
    check_concordance(originals)
    check_versions()
    check_cross_references()
    check_places()
    check_dates()
    check_tagged_layers(originals)
    check_character_repertoire()
    check_merge_markers()

    failed = [r for r in results if r['disagreements']]
    print('=' * 60)
    print(f'{len(results)} checks, {len(failed)} with disagreements.')
    if '--json' in sys.argv:
        with open(os.path.join(ROOT, 'build', 'data_integrity.json'), 'w') as f:
            json.dump(results, f, indent=2, ensure_ascii=False)


if __name__ == '__main__':
    main()
