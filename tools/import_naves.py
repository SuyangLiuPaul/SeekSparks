#!/usr/bin/env python3
"""Nave's Topical Bible (1896) -> SeekSparks assets.

Source: https://ccel.org/ccel/n/nave/bible.xml — CCEL's ThML edition of
Orville J. Nave's *Topical Bible*, the same file CrossWire's SWORD module
`Nave` names as its TextSource and distributes as Public Domain. The work
itself is 1896 and out of copyright everywhere; CCEL's markup is what we
actually consume, so the attribution names both.

WHY THIS SOURCE AND NOT A PARSED ONE. Every scripture reference in the
ThML already carries an `osisRef` — machine-parsed, unambiguous, and
carrying its own range and chapter-level granularity. The alternative
sources are re-parses of a printed page, where "Ex 6:16-20; Jos 21:4,10"
has to be re-derived from typography. Reference parsing is exactly where
a topical index goes silently wrong, and this file does not need it.

WHAT NAVE'S IS, because the shape of the asset follows from it. It is not
a dictionary: the entry for AARON does not define Aaron, it *assembles*
him out of the text — "Lineage of", "Marriage of", "Rod of, buds" — each
line an assertion with the verses that carry it, nested up to three deep.
So the LINE is the unit, not the topic, and a line without its ancestors
is a fragment: under MINISTER a bare ".Paul" means nothing until you can
see it sits under "–Called of God". The asset therefore keeps every line
in document order with its depth, and the reverse index points at a
(topic, line) pair rather than at a topic.

THREE THINGS THE IMPORT HAS TO GET RIGHT

1. Granularity is not uniform. Of the 77,974 references that ship,
   64,187 name a verse, 11,617 name a verse range inside one chapter, and
   2,170 name a WHOLE CHAPTER ("Rod of, buds — Nu 17"). A chapter
   citation is not evidence that Nave filed verse 8 under that line, so
   it is indexed at the chapter and surfaced as a chapter citation.
   Expanding it would manufacture 57,493 verse-level claims Nave never
   made, and they would be indistinguishable from the real ones.

2. The apocrypha. 12 references reach `Wis` or `PrAzar`, books this app
   does not carry. They are dropped, and every one of them turns out to
   be a defect below rather than a real apocryphal citation.

3. UPSTREAM DEFECT CLASS A, 246 SITES: THE ONE-CHAPTER BOOKS. Obadiah,
   Philemon, 2 John, 3 John and Jude have no chapter number to print, so
   Nave wrote "Jude 14" and CCEL's tagger, which wants `book chapter:verse`,
   read the 14 as the chapter and gave up. What it emitted closes the tag
   after the book name and leaves the real verse in the prose behind it:
   `<scripRef osisRef="Bible:Jude.1.1">Jude 1</scripRef>:14,15`. All 250
   references to these five books arrive as BOOK.1.1, so in this edition a
   `.1.1` is never evidence of verse 1 — the verse, when there is one, is
   the number after the colon. Left alone this piles 115 unrelated topics
   onto Jude 1:1 and leaves Jude 1:14 empty; the same for the other four.

   246 of the 250 are repaired from the orphan text. Of the remaining
   four, two are the "Obadiah 1 Ki 18:12" shape — defect class B below,
   the person Obadiah followed by 1 Kings — and two are the line "See the
   EPISTLES OF JOHN 1Jo 1; 2Jo 1; 3Jo 1", where Nave named the books and
   not their first verses; those become chapter citations, which is what
   the tagger itself did for the 1 John in the same list.

4. UPSTREAM DEFECT CLASS B, 40 SITES. CCEL's auto-tagger reads a
   personal name followed by the leading digit of the NEXT reference as a
   book-and-chapter. The printed line "Micah 2 Ch 34:20" became
   `<scripRef>Micah 2</scripRef>` plus the orphan text "Ch 34:20", so the
   reader loses 2 Chronicles 34:20 and gains a link to Micah 2, which is
   about something else entirely. Signature, and it is exact: a
   CHAPTER-ONLY reference whose chapter is 1 or 2, immediately abutting
   (no separator) either another scripRef or a bare book fragment
   Ch/Ki/Sa/Co/Ti/Th/Pe/Jo. Confirmed on the text: under MICAH the repair
   yields 2 Chronicles 34:20, which names "Abdon the son of Micah"; the
   four TITUS sites yield 2 Corinthians 8:16-23, which is the passage
   about Titus being sent. Both are checkable claims and both check out.

   The repair reconstructs "<swallowed digit> <fragment>" and re-parses
   it, and it has to keep reading past the comma: "Titus 2 Co 8:16,17"
   tags BOTH halves as Colossians, so repairing only the first shipped
   four references to a Colossians 8 and 12 that do not exist.

   Five references remain unresolvable after it — Exodus 3:29, Mark
   18:42, Mark 18:43, 1 Chronicles 22:27, 1 Chronicles 22:30 — and are
   dropped rather than guessed at. Each is a plausible one-character slip
   (Mark 18 does not exist; Luke 18:42 is the verse the context wants)
   but "plausible" is not a reading, and inventing a reference in a
   reference work is the one failure this repository does not tolerate.

Every reference that survives is checked against `assets/kjv.json` — the
edition Nave keyed the work to — and a reference that does not resolve
there does not ship.

Usage:  python3 tools/import_naves.py <path to bible.xml>
"""

import collections
import html
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'nave')

STANDARD_BOOKS = [
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
    'Hebrews', 'James', '1 Peter', '2 Peter', '1 John', '2 John', '3 John',
    'Jude', 'Revelation',
]
BOOK_INDEX = {b: i + 1 for i, b in enumerate(STANDARD_BOOKS)}

OSIS = {
    'Gen': 'Genesis', 'Exod': 'Exodus', 'Lev': 'Leviticus', 'Num': 'Numbers',
    'Deut': 'Deuteronomy', 'Josh': 'Joshua', 'Judg': 'Judges', 'Ruth': 'Ruth',
    '1Sam': '1 Samuel', '2Sam': '2 Samuel', '1Kgs': '1 Kings',
    '2Kgs': '2 Kings', '1Chr': '1 Chronicles', '2Chr': '2 Chronicles',
    'Ezra': 'Ezra', 'Neh': 'Nehemiah', 'Esth': 'Esther', 'Job': 'Job',
    'Ps': 'Psalms', 'Prov': 'Proverbs', 'Eccl': 'Ecclesiastes',
    'Song': 'Song of Solomon', 'Isa': 'Isaiah', 'Jer': 'Jeremiah',
    'Lam': 'Lamentations', 'Ezek': 'Ezekiel', 'Dan': 'Daniel',
    'Hos': 'Hosea', 'Joel': 'Joel', 'Amos': 'Amos', 'Obad': 'Obadiah',
    'Jonah': 'Jonah', 'Mic': 'Micah', 'Nah': 'Nahum', 'Hab': 'Habakkuk',
    'Zeph': 'Zephaniah', 'Hag': 'Haggai', 'Zech': 'Zechariah',
    'Mal': 'Malachi', 'Matt': 'Matthew', 'Mark': 'Mark', 'Luke': 'Luke',
    'John': 'John', 'Acts': 'Acts', 'Rom': 'Romans', '1Cor': '1 Corinthians',
    '2Cor': '2 Corinthians', 'Gal': 'Galatians', 'Eph': 'Ephesians',
    'Phil': 'Philippians', 'Col': 'Colossians',
    '1Thess': '1 Thessalonians', '2Thess': '2 Thessalonians',
    '1Tim': '1 Timothy', '2Tim': '2 Timothy', 'Titus': 'Titus',
    'Phlm': 'Philemon', 'Heb': 'Hebrews', 'Jas': 'James', '1Pet': '1 Peter',
    '2Pet': '2 Peter', '1John': '1 John', '2John': '2 John',
    '3John': '3 John', 'Jude': 'Jude', 'Rev': 'Revelation',
}

# The orphan fragments the tagger leaves behind, and the book each one
# completes once its swallowed digit is restored. Only books whose names
# begin with a digit can produce this defect, which is why the list is
# short and closed.
FRAGMENT_BOOKS = {
    'Ch': ('1 Chronicles', '2 Chronicles'),
    'Chr': ('1 Chronicles', '2 Chronicles'),
    'Ki': ('1 Kings', '2 Kings'),
    'Kgs': ('1 Kings', '2 Kings'),
    'Sa': ('1 Samuel', '2 Samuel'),
    'Sam': ('1 Samuel', '2 Samuel'),
    'Co': ('1 Corinthians', '2 Corinthians'),
    'Cor': ('1 Corinthians', '2 Corinthians'),
    'Ti': ('1 Timothy', '2 Timothy'),
    'Th': ('1 Thessalonians', '2 Thessalonians'),
    'Pe': ('1 Peter', '2 Peter'),
    'Jo': ('1 John', '2 John'),
    'Pet': ('1 Peter', '2 Peter'),
}

# The five books with no chapter number to print. In this edition every
# reference to one of them arrives as BOOK.1.1 (250 of 250), so the ".1"
# verse is the tagger's default and never a reading.
SINGLE_CHAPTER = {
    'Obad': 'Obadiah', 'Phlm': 'Philemon', '2John': '2 John',
    '3John': '3 John', 'Jude': 'Jude',
}

TOPICS_PER_SHARD = 40

SCRIPREF = re.compile(r'<scripRef\b[^>]*>.*?</scripRef>', re.S)
OSISREF = re.compile(r'osisRef="([^"]*)"')


def load_canon():
    """(book, chapter, verse) triples of the KJV Nave keyed the work to."""
    with open(os.path.join(ROOT, 'assets', 'kjv.json'), encoding='utf-8') as f:
        rows = json.load(f)
    canon = set()
    chapters = collections.defaultdict(set)
    for r in rows:
        b, c, v = r['book'], int(r['chapter']), int(r['verse'])
        canon.add((b, c, v))
        chapters[(b, c)].add(v)
    return canon, chapters


def parse_osis(osis):
    """`Bible:1Chr.6.3-1Chr.6.15` -> (book, chapter, verse, endVerse)."""
    body = osis.replace('Bible:', '')
    head = body.split('-')[0].split('.')
    # Repaired references are re-emitted with the full English book name,
    # so both spellings have to read.
    book = OSIS.get(head[0]) or (head[0] if head[0] in BOOK_INDEX else None)
    if book is None:
        return None
    chapter = int(head[1]) if len(head) > 1 else None
    verse = int(head[2]) if len(head) > 2 else None
    end = None
    if '-' in body:
        tail = body.split('-')[1].split('.')
        if len(tail) > 2 and (len(head) < 2 or int(tail[1]) == chapter):
            end = int(tail[2])
    return (book, chapter, verse, end)


def repair_single_chapter(frag_html, report):
    """Give the one-chapter books back the verse the tagger orphaned.

    See defect class A in the module docstring. Three outcomes, in the
    order they are tried: the tag is followed by ":14,15", which is the
    reference and is re-emitted as one; the tag is followed by a bare
    book fragment, which makes this class B and is handed the same
    treatment; or neither, in which case Nave named the book and the
    citation is emitted at chapter granularity rather than at a verse he
    did not write.
    """
    out = frag_html
    for m in list(SCRIPREF.finditer(frag_html)):
        osis = OSISREF.search(m.group(0))
        if not osis:
            continue
        parsed = osis.group(1).replace('Bible:', '').split('.')
        if len(parsed) != 3 or parsed[0] not in SINGLE_CHAPTER:
            continue
        if parsed[1] != '1' or parsed[2] != '1':
            continue
        book = SINGLE_CHAPTER[parsed[0]]
        name = re.sub(r'<[^>]+>', '', m.group(0))
        after = frag_html[m.end():]
        spec = re.match(r':\s*(\d[\d,\-]*)', after)
        if spec:
            refs, pos = parse_fragment(book, spec.group(1), chapter=1)
            if refs:
                cut = m.end() + spec.start(1) + pos
                out = out.replace(frag_html[m.start():cut],
                                  ''.join(synth(r) for r in refs), 1)
                report.append((name, book, refs))
                continue
        # "Obadiah 1" + "Ki 18:12": the printed 1 began the next book.
        frag = re.match(r'([A-Za-z]{2,3})\b([^<]*)', after)
        if frag and frag.group(1) in FRAGMENT_BOOKS:
            other = FRAGMENT_BOOKS[frag.group(1)][0]
            refs, consumed = parse_fragment(other, frag.group(2))
            if refs:
                lead = re.sub(r'\s*1$', '', name)
                cut = m.end() + len(frag.group(1)) + consumed
                out = out.replace(frag_html[m.start():cut],
                                  lead + ''.join(synth(r) for r in refs), 1)
                report.append((lead, other, refs))
                continue
        whole = (book, 1, None, None)
        out = out.replace(m.group(0), synth(whole), 1)
        report.append((name, book, [whole]))
    return out


def repair_paragraph(frag_html, report):
    """Undo the tagger's swallowed leading digit. Returns repaired HTML.

    Both signatures are the same mistake seen from two sides: a
    chapter-only reference whose "chapter" is really the 1 or 2 that
    began the next book's name.
    """
    out = frag_html
    for m in list(SCRIPREF.finditer(frag_html)):
        osis = OSISREF.search(m.group(0))
        if not osis:
            continue
        parsed = osis.group(1).replace('Bible:', '').split('.')
        # Chapter-only, and the chapter is a digit a book name could start
        # with. `Wis`/`PrAzar` are not in OSIS at all, hence the `.get`.
        if len(parsed) != 2 or parsed[1] not in ('1', '2'):
            continue
        digit = parsed[1]
        after = frag_html[m.end():]
        frag = re.match(r'([A-Za-z]{2,3})\b([^<]*)', after)
        repl = None
        if frag and frag.group(1) in FRAGMENT_BOOKS:
            book = FRAGMENT_BOOKS[frag.group(1)][int(digit) - 1]
            refs, consumed = parse_fragment(book, frag.group(2))
            if refs:
                name = re.sub(r'<[^>]+>', '', m.group(0))
                name = re.sub(r'\s*%s$' % digit, '', name)
                repl = name + ''.join(synth(r) for r in refs)
                # The orphan text is now carried by the synthesised refs.
                cut = m.end() + len(frag.group(1)) + consumed
                out = out.replace(frag_html[m.start():cut], repl, 1)
                report.append((name, book, refs))
                continue
        nxt = SCRIPREF.match(after)
        if nxt:
            inner = re.sub(r'<[^>]+>', '', nxt.group(0))
            head = re.match(r'([A-Za-z]{2,3})\b(.*)', inner)
            if head and head.group(1) in FRAGMENT_BOOKS:
                book = FRAGMENT_BOOKS[head.group(1)][int(digit) - 1]
                refs, _ = parse_fragment(book, head.group(2))
                if refs:
                    stop = nxt.end() + eat_continuations(
                        after[nxt.end():], nxt.group(0), book, refs)
                    name = re.sub(r'<[^>]+>', '', m.group(0))
                    name = re.sub(r'\s*%s$' % digit, '', name)
                    repl = name + ''.join(synth(r) for r in refs)
                    out = out.replace(
                        frag_html[m.start():m.end() + stop], repl, 1)
                    report.append((name, book, refs))
    return out


def eat_continuations(rest, first, book, refs):
    """Follow "Co 8:16,17" past the comma. Appends to `refs` in place.

    The tagger identified the run's book from its first token, so a
    continuation carries the same wrong osisRef as the reference just
    repaired — leaving it behind ships "Colossians 8:17", a verse that
    does not exist. Only a run-mate is taken: same wrong book, and an
    anchor that is bare digits, so a real Colossians reference standing
    next to a repair is never swallowed.
    """
    wrong = OSISREF.search(first)
    if not wrong:
        return 0
    wrong = wrong.group(1).replace('Bible:', '').split('.')[0]
    pos = 0
    while True:
        cont = re.match(r'[,;]\s*(<scripRef\b[^>]*>.*?</scripRef>)', rest[pos:],
                        re.S)
        if not cont:
            return pos
        osis = OSISREF.search(cont.group(1))
        inner = re.sub(r'<[^>]+>', '', cont.group(1)).strip()
        if (not osis or not re.fullmatch(r'[\d:,\-]+', inner) or
                osis.group(1).replace('Bible:', '').split('.')[0] != wrong):
            return pos
        more, _ = parse_fragment(book, inner, chapter=refs[-1][1])
        if not more:
            return pos
        refs.extend(more)
        pos += cont.end()


def parse_fragment(book, text, chapter=None):
    """Read "  8:35; 9:41," as references in `book`. Stops at prose.

    Returns (refs, characters consumed). Deliberately conservative: it
    reads chapter:verse groups and quits at the first thing that is not
    one, so "19:13; with" contributes one reference and leaves "with" in
    the sentence where it belongs. `chapter` seeds the running chapter,
    for the callers whose text is a bare verse list continuing a
    reference already read.
    """
    refs = []
    pos = 0
    while True:
        m = re.match(r'\s*(?:(\d+):)?(\d+)(?:-(\d+))?', text[pos:])
        if not m or (m.group(1) is None and chapter is None):
            break
        if m.group(1):
            chapter = int(m.group(1))
        refs.append((book, chapter, int(m.group(2)),
                     int(m.group(3)) if m.group(3) else None))
        pos += m.end()
        sep = re.match(r'\s*[,;]\s*', text[pos:])
        if not sep:
            break
        pos += sep.end()
    return refs, pos


def synth(ref):
    """A repaired reference, re-emitted in the shape the parser reads."""
    book, chapter, verse, end = ref
    if verse is None:
        return '<scripRef osisRef="Bible:%s.%d" repaired="1">%s %d</scripRef>' \
            % (book, chapter, book, chapter)
    osis = 'Bible:%s.%d.%d' % (book, chapter, verse)
    if end:
        osis += '-%s.%d.%d' % (book, chapter, end)
    label = '%s %d:%d%s' % (book, chapter, verse, '-%d' % end if end else '')
    return '<scripRef osisRef="%s" repaired="1">%s</scripRef>' % (osis, label)


def ref_code(book, chapter, verse, end):
    idx = BOOK_INDEX[book]
    if verse is None:
        return '%d.%d' % (idx, chapter)
    if end:
        return '%d.%d.%d-%d' % (idx, chapter, verse, end)
    return '%d.%d.%d' % (idx, chapter, verse)


def clean(text):
    text = re.sub(r'<[^>]+>', '', text)
    text = html.unescape(text)
    text = text.replace(' ', ' ')
    text = re.sub(r'\s+', ' ', text).strip()
    # Nave's printed dashes mark the nesting depth; the depth is carried
    # by the class, so the marker is noise once it is parsed.
    text = re.sub(r'^[–—\-.]+\s*', '', text)
    return re.sub(r'\s+([,;.])', r'\1', text).strip(' ,;')


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else '/tmp/nave/ccel_nave.xml'
    raw = open(src, encoding='utf-8', errors='replace').read()
    body = raw[raw.find('</ThML.head>'):]
    canon, chapters = load_canon()

    repairs = []
    chapter_repairs = []
    dropped = collections.Counter()
    apocrypha = 0
    topics = []
    # verse index: book index -> chapter -> verse (0 = whole chapter) -> hits
    rev = collections.defaultdict(
        lambda: collections.defaultdict(lambda: collections.defaultdict(list)))
    see_unresolved = []

    entries = re.findall(
        r'<term[^>]*>(.*?)</term>\s*<def[^>]*>(.*?)</def>', body, re.S)
    for head_html, def_html in entries:
        head = clean(head_html)
        if not head:
            continue
        topic_id = len(topics)
        lines = []
        for pm in re.finditer(
                r'<p class="index(\d)"[^>]*>(.*?)</p>', def_html, re.S):
            depth = int(pm.group(1)) - 1
            frag = repair_single_chapter(pm.group(2), chapter_repairs)
            frag = repair_paragraph(frag, repairs)
            refs = []
            for sm in SCRIPREF.finditer(frag):
                om = OSISREF.search(sm.group(0))
                if not om:
                    continue
                parsed = parse_osis(om.group(1))
                if parsed is None:
                    apocrypha += 1
                    continue
                book, chapter, verse, end = parsed
                if verse is None:
                    if (book, chapter) not in chapters:
                        dropped['%s %s' % (book, chapter)] += 1
                        continue
                else:
                    span = range(verse, (end or verse) + 1)
                    if any((book, chapter, v) not in canon for v in span):
                        dropped['%s %s:%s' % (book, chapter, verse)] += 1
                        continue
                refs.append((book, chapter, verse, end))
            # A "See PRIEST, HIGH" line is Nave's navigation. The href's
            # `term=` is CCEL's key for it and only sometimes matches one
            # of our headwords, so both the printed name and the resolved
            # target are kept: an unresolvable link is still worth
            # printing, it just does not pretend to be tappable.
            see = [[clean(t), html.unescape(k).replace('+', ' ')]
                   for k, t in re.findall(
                       r'href="bible\.[^"]*\?term=([^"&]*)"[^>]*>(.*?)</a>',
                       frag, re.S)]
            text = clean(re.sub(r'<a\b[^>]*>.*?</a>', '', SCRIPREF.sub('', frag),
                                flags=re.S))
            if not text and not refs and not see:
                continue
            line = {'d': depth, 't': text}
            if refs:
                line['r'] = [ref_code(*r) for r in refs]
            if see:
                line['s'] = see
            idx = len(lines)
            lines.append(line)
            for book, chapter, verse, end in refs:
                slot = rev[BOOK_INDEX[book]][chapter]
                if verse is None:
                    slot[0].append([topic_id, idx])
                else:
                    for v in range(verse, (end or verse) + 1):
                        slot[v].append([topic_id, idx])
        topics.append({'h': head, 'l': lines})

    # "See PRIEST, HIGH" only helps if it can be followed.
    by_head = {}
    for i, t in enumerate(topics):
        by_head.setdefault(t['h'].upper(), i)
    for t in topics:
        for line in t['l']:
            if 's' not in line:
                continue
            out = []
            for name, key in line['s']:
                target = by_head.get(key.upper(), by_head.get(name.upper()))
                if target is None:
                    see_unresolved.append(key)
                    out.append([name])
                else:
                    out.append([name, target])
            line['s'] = out

    os.makedirs(os.path.join(OUT, 't'), exist_ok=True)
    os.makedirs(os.path.join(OUT, 'v'), exist_ok=True)

    ref_total = sum(len(l.get('r', [])) for t in topics for l in t['l'])
    line_total = sum(len(t['l']) for t in topics)

    index = {
        'schemaVersion': 1,
        'source': "Nave's Topical Bible (Orville J. Nave, 1896)",
        'attribution':
            "Nave's Topical Bible, Orville J. Nave (1896). Public domain. "
            'Electronic text: Christian Classics Ethereal Library '
            '(ccel.org), ThML edition. References are keyed to the '
            'Authorized (King James) Version.',
        'topicsPerShard': TOPICS_PER_SHARD,
        'topicCount': len(topics),
        'lineCount': line_total,
        'refCount': ref_total,
        # [head, line count, reference count] positionally by topic id.
        'topics': [[t['h'], len(t['l']),
                    sum(len(l.get('r', [])) for l in t['l'])] for t in topics],
    }
    with open(os.path.join(OUT, 'index.json'), 'w', encoding='utf-8') as f:
        json.dump(index, f, ensure_ascii=False, separators=(',', ':'))

    for start in range(0, len(topics), TOPICS_PER_SHARD):
        shard = {str(start + i): t
                 for i, t in enumerate(topics[start:start + TOPICS_PER_SHARD])}
        path = os.path.join(OUT, 't', '%d.json' % (start // TOPICS_PER_SHARD))
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(shard, f, ensure_ascii=False, separators=(',', ':'))

    # A fourth artifact, and it exists for one measured reason. Headword
    # search over index.json answers the 1896 vocabulary well — LOVE,
    # FAITH, JEALOUSY, ANXIETY all land — but a reader typing a word Nave
    # did not use as a headword gets nothing: "worry" and "depression" are
    # both zero headwords. The LINES are a different index — "divorce" is
    # 2 headwords and 37 lines — and a blank page in front of a reader who
    # asked a reasonable question is the defect this app has already been
    # burned by. It is not a cure: "depression" is zero in the lines too,
    # and the page says so rather than showing an empty list.
    #
    # Searching the lines means having them all at once, and they live
    # scattered across 134 topic shards — 134 requests to answer one
    # query. So the text alone is emitted once, flat: 790 KB, 270 KB
    # gzipped, ONE request, and loaded only when a reader actually asks
    # for it. Positional by line index so a hit is a (topic, line) pair
    # the shards can resolve without a second key.
    with open(os.path.join(OUT, 'lines.json'), 'w', encoding='utf-8') as f:
        json.dump({
            'schemaVersion': 1,
            'topicCount': len(topics),
            'lines': {str(i): [l.get('t', '') for l in t['l']]
                      for i, t in enumerate(topics)},
        }, f, ensure_ascii=False, separators=(',', ':'))

    for book_idx, chapters_map in rev.items():
        slug = STANDARD_BOOKS[book_idx - 1].lower().replace(' ', '_')
        out = {str(c): {str(v): hits for v, hits in sorted(vs.items())}
               for c, vs in sorted(chapters_map.items())}
        with open(os.path.join(OUT, 'v', '%s.json' % slug), 'w',
                  encoding='utf-8') as f:
            json.dump(out, f, ensure_ascii=False, separators=(',', ':'))

    print('topics            %d' % len(topics))
    print('lines             %d' % line_total)
    print('references kept   %d' % ref_total)
    print('books indexed     %d' % len(rev))
    # Every repair is a claim about what a verse says, so the verse gets
    # to answer. If the name the tagger swallowed the digit from appears
    # in the KJV text of the repaired reference, the repair is confirmed
    # by the text itself rather than by the shape of the mistake.
    text = {}
    with open(os.path.join(ROOT, 'assets', 'kjv.json'), encoding='utf-8') as f:
        for r in json.load(f):
            text[(r['book'], int(r['chapter']), int(r['verse']))] = r['text']
    # Class A. The witness is the file itself: the verse Nave printed is
    # sitting in the prose the tagger left behind, so the repair only has
    # to be read, not guessed. What is worth measuring is that the result
    # lands inside the book — a misparse would overflow a 13-verse book —
    # and that the pile on verse 1 is gone. (CrossWire's `Nave` module is
    # NOT a witness here: its conf names this same XML as its TextSource.)
    limits = {b: max(chapters[(b, 1)]) for b in SINGLE_CHAPTER.values()}
    per_book = collections.Counter()
    highest = {}
    for name, book, refs in chapter_repairs:
        for b, c, v, e in refs:
            per_book[b] += 1
            if v is not None:
                highest[b] = max(highest.get(b, 0), e or v)
    print('one-chapter books repaired %d sites' % len(chapter_repairs))
    for b, n in sorted(per_book.items()):
        if b in limits:
            print('   %-12s %4d refs, highest verse %d of %d'
                  % (b, n, highest.get(b, 0), limits[b]))
        else:
            print('   %-12s %4d refs (class B: the printed 1 began this book)'
                  % (b, n))

    confirmed = 0
    print('repaired          %d' % len(repairs))
    for name, book, refs in repairs:
        stem = name.split(',')[0].strip().lower()[:4]
        hit = any(stem in text.get((b, c, v), '').lower()
                  for b, c, v, e in refs
                  for v in range(v, (e or v) + 1))
        confirmed += 1 if hit else 0
        print('   %-3s %-22s -> %s' % (
            'ok' if hit else '??', name[:22],
            '; '.join('%s %d:%d%s' % (b, c, v, '-%d' % e if e else '')
                      for b, c, v, e in refs)))
    print('   confirmed by the KJV text of the target: %d / %d'
          % (confirmed, len(repairs)))
    print('dropped (apocrypha)   %d' % apocrypha)
    print('dropped (unresolvable) %d' % sum(dropped.values()))
    for k, n in dropped.most_common():
        print('   %s x%d' % (k, n))
    print('unresolved "see" targets %d %s'
          % (len(see_unresolved), collections.Counter(see_unresolved).most_common(5)))


if __name__ == '__main__':
    main()
