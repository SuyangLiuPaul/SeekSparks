#!/usr/bin/env python3
"""Build assets/jesus_teachings.json — the spine of "The Teachings of the Lord Jesus".

WHAT THIS IS, AND WHAT IT IS NOT.

There is no canonical enumeration of "all the teachings of Jesus". The
parables are a stable category with old catalogues; "teachings and
discourses" is not — every published list is an editor's scheme, and the
modern ones (NIV Study Bible tables, Nelson's, Scroggie) are in
copyright. So this file's arrangement is EDITORIAL, it says so in its
own `_meta`, and the page says so to the reader.

What it is built from, in order of authority:

  1. THE TEXT'S OWN STRUCTURE. Matthew's five discourses (5-7, 10, 13,
     18, 24-25), each closed by "when Jesus had finished these sayings",
     and John's discourses. This is the one part of the arrangement that
     is not anybody's opinion.
  2. THE OWNER'S OWN SERMON CORPUS. `assets/sermons/index.json` carries
     289 sermons already grouped by topic, of which "The Parables of
     Jesus" (34), "Sermon on the Mount" (18) and "The Beatitudes" (10)
     are an ordered exposition of Jesus' teaching with a passage on each
     entry. Where the corpus covers a teaching, ITS order and ITS title
     are used, because they are the owner's own and not a guess.
  3. NAVE'S TOPICAL BIBLE (1896, public domain), the "JESUS, THE CHRIST"
     article, which is a life-of-Christ outline in order with references
     on each line. Teaching lines are picked out by the keyword rule in
     `_TEACHING_WORDS`, and that rule is the editorial act — it is kept
     in one place, and its misses are a known limitation rather than a
     hidden one.

And what is attached to each teaching, all from data already bundled:

  * SERMONS — `assets/sermons/refs.json` `byVerse`, which is already a
    verse-to-sermon index built by `extract_sermon_refs.py`.
  * OLD TESTAMENT and APOSTLES — `assets/cross_references.json`, the
    Treasury of Scripture Knowledge merged with OpenBible.info votes.
    TSK asserts that two passages are RELATED. It does not assert that
    one rests on the other, and nothing here upgrades that claim: the
    page puts the conviction in its preface, in the owner's voice, and
    keeps the column headings neutral.
  * WHAT THE TEXT ITSELF CLAIMS — `_LORDS_WORD` is the short list of
    places where an apostle says outright that he is passing on the
    Lord's own word. There are five. They are marked, and they are the
    only links on the page that assert dependence, because they are the
    only ones scripture asserts.
  * PLATES — `assets/maps_index.json`, matched by book and chapter.

Run: python3 scripts/build_jesus_teachings.py
"""

import json
import os
import re
import collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def asset(*parts):
    return os.path.join(ROOT, 'assets', *parts)


BOOKS = [
    'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy', 'Joshua',
    'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
    '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther', 'Job',
    'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Solomon', 'Isaiah',
    'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel', 'Amos',
    'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk', 'Zephaniah', 'Haggai',
    'Zechariah', 'Malachi', 'Matthew', 'Mark', 'Luke', 'John', 'Acts',
    'Romans', '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
    'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
    '1 Timothy', '2 Timothy', 'Titus', 'Philemon', 'Hebrews', 'James',
    '1 Peter', '2 Peter', '1 John', '2 John', '3 John', 'Jude', 'Revelation',
]
OT = set(BOOKS[:39])
GOSPELS = {'Matthew', 'Mark', 'Luke', 'John'}
EPISTLES = set(BOOKS[44:65])  # Romans .. Jude

# The abbreviations the sermon corpus actually uses, measured rather than
# assumed: `Mt` 102, `Lk` 30, `Mk` 9, `Jn` 6, plus full names and a few
# epistle short forms.
ABBREV = {
    'Mt': 'Matthew', 'Mk': 'Mark', 'Lk': 'Luke', 'Jn': 'John',
    'Rom': 'Romans', '1Cor': '1 Corinthians', '2Cor': '2 Corinthians',
    'Gal': 'Galatians', 'Eph': 'Ephesians', 'Phil': 'Philippians',
    'Col': 'Colossians', 'Heb': 'Hebrews', 'Jas': 'James',
    '1Pet': '1 Peter', '2Pet': '2 Peter', 'Song': 'Song of Solomon',
}
for b in BOOKS:
    ABBREV[b] = b

# The lines in Nave's life-of-Christ outline that are a TEACHING. This
# keyword rule is the editorial act in this file; it is here, once, so
# that what it misses can be argued with.
_TEACHING_WORDS = re.compile(
    r'\b(parable|teach|teaches|teaching|discourse|sermon|enunciat|preach'
    r'|expound|instruct|answers|declares|foretells|commissions)', re.I)

# The only places in the New Testament where an apostle says outright
# that he is handing on the Lord's OWN word. Everything else on this page
# is a relation, not a dependence — see the module docstring.
_LORDS_WORD = {
    '1 Corinthians 7:10': 'the Lord, not I',
    '1 Corinthians 7:11': 'the Lord, not I',
    '1 Corinthians 9:14': 'the Lord commanded',
    '1 Corinthians 11:23': 'received of the Lord',
    '1 Corinthians 11:24': 'received of the Lord',
    '1 Corinthians 11:25': 'received of the Lord',
    '1 Thessalonians 4:15': 'by the word of the Lord',
    'Acts 20:35': 'the words of the Lord Jesus',
}

# Matthew's five discourses and John's, which are the text's own
# divisions rather than an editor's. Each Matthean one closes with the
# formula "when Jesus had finished these sayings" (7:28, 11:1, 13:53,
# 19:1, 26:1), which is why this list is not a matter of opinion.
_STRUCTURAL = [
    ('discourse-sermon-mount', 'Matthew', 5, 1, 7, 29,
     {'en': 'The Sermon on the Mount', 'zh-Hans': '登山宝训',
      'zh-Hant': '登山寶訓'}),
    ('discourse-mission', 'Matthew', 10, 1, 10, 42,
     {'en': 'The Mission Discourse', 'zh-Hans': '差遣的教导',
      'zh-Hant': '差遣的教導'}),
    ('discourse-parables', 'Matthew', 13, 1, 13, 52,
     {'en': 'The Parables of the Kingdom', 'zh-Hans': '天国的比喻',
      'zh-Hant': '天國的比喻'}),
    ('discourse-church', 'Matthew', 18, 1, 18, 35,
     {'en': 'On the Church and Forgiveness', 'zh-Hans': '论教会与饶恕',
      'zh-Hant': '論教會與饒恕'}),
    ('discourse-olivet', 'Matthew', 24, 1, 25, 46,
     {'en': 'The Olivet Discourse', 'zh-Hans': '橄榄山的教导',
      'zh-Hant': '橄欖山的教導'}),
    ('discourse-upper-room', 'John', 14, 1, 16, 33,
     {'en': 'The Upper Room Discourse', 'zh-Hans': '临别的教导',
      'zh-Hant': '臨別的教導'}),
    ('discourse-bread-of-life', 'John', 6, 22, 6, 71,
     {'en': 'The Bread of Life', 'zh-Hans': '生命的粮',
      'zh-Hant': '生命的糧'}),
    ('discourse-good-shepherd', 'John', 10, 1, 10, 21,
     {'en': 'The Good Shepherd', 'zh-Hans': '好牧人',
      'zh-Hant': '好牧人'}),
    # THE THREE THE APOSTLES CITE BY NAME. These are here because of
    # `_LORDS_WORD`, not in spite of it: they are the teachings the New
    # Testament itself says an apostle is handing on, so a page about
    # what the apostles received cannot be missing them. Without them
    # the strongest links on the page had nothing to attach to — the
    # first build marked zero.
    ('lords-supper', 'Matthew', 26, 26, 26, 29,
     {'en': 'The Lord\'s Supper', 'zh-Hans': '主的晚餐',
      'zh-Hant': '主的晚餐'}),
    ('on-divorce', 'Matthew', 19, 3, 19, 12,
     {'en': 'On Marriage and Divorce', 'zh-Hans': '论婚姻与休妻',
      'zh-Hant': '論婚姻與休妻'}),
    ('labourer-worthy', 'Luke', 10, 1, 10, 12,
     {'en': 'The Seventy Sent Out', 'zh-Hans': '差遣七十个人',
      'zh-Hant': '差遣七十個人'}),
]


# The eleven Nave lines the app's own section headings do not cover,
# translated. 2026-09-16 「这些也没用根据语言翻译好」.
#
# Translating a DESCRIPTIVE HEADING is localisation, not exegesis — the
# passage it names is printed beside it and can be checked in one tap,
# and nothing here interprets the passage. They are kept literal and
# close to Nave's English, including his parenthetical locations, so
# that what a Chinese reader sees is the same claim an English reader
# sees. Every other title on the page comes from a source that is
# already trilingual.
_NAVE_ZH = {
    'Preaches throughout Galilee': ('在加利利各处传道', '在加利利各處傳道'),
    'Goes up onto a mountain, and calls and commissions twelve disciples '
    '(in Galilee)':
        ('上山呼召并差派十二使徒（在加利利）', '上山呼召並差派十二使徒（在加利利）'),
    'Cautions his disciples against, the leaven (teachings) of hypocrisy '
    '(on Lake Galilee)':
        ('警戒门徒防备假冒为善的酵（教训）（在加利利海上）',
         '警戒門徒防備假冒為善的酵（教訓）（在加利利海上）'),
    'Foretells his own death and resurrection (in Galilee)':
        ('预言自己的死与复活（在加利利）', '預言自己的死與復活（在加利利）'),
    'The parable of the two sons (in Jerusalem)':
        ('两个儿子的比喻（在耶路撒冷）', '兩個兒子的比喻（在耶路撒冷）'),
    'Foretells his betrayal (in Jerusalem)':
        ('预言自己被卖（在耶路撒冷）', '預言自己被賣（在耶路撒冷）'),
    'Teaches the multitude the conditions of discipleship (in Peraea)':
        ('教导众人作门徒的条件（在比利亚）', '教導眾人作門徒的條件（在比利亞）'),
    'Enunciates the parable of the rich man and Lazarus (in Peraea)':
        ('讲财主和拉撒路的比喻（在比利亚）', '講財主和拉撒路的比喻（在比利亞）'),
    'Teaches the Pharisees concerning the coming of his kingdom (in Peraea)':
        ('教导法利赛人论神国的降临（在比利亚）', '教導法利賽人論神國的降臨（在比利亞）'),
    'Teaches daily in the temple courtyard (in Jerusalem)':
        ('天天在殿院里教训人（在耶路撒冷）', '天天在殿院裡教訓人（在耶路撒冷）'),
    'Teaches people (in Jerusalem)': ('教导众人（在耶路撒冷）', '教導眾人（在耶路撒冷）'),
}


def parse_passage(text):
    """`Mt 13:1-9`, `Lk 8:4-8, 11-15`, `Luke 4:5-13` -> spans."""
    out = []
    if not text:
        return out
    book = None
    for part in re.split(r'[;/]', text):
        part = part.strip()
        if not part:
            continue
        m = re.match(r'^((?:[123]\s*)?[A-Za-z][A-Za-z ]*?)\.?\s+(\d.*)$', part)
        if m:
            raw = re.sub(r'\s+', ' ', m.group(1)).strip()
            book = ABBREV.get(raw) or ABBREV.get(raw.replace(' ', ''))
            rest = m.group(2)
        else:
            rest = part
        if not book:
            continue
        for chunk in rest.split(','):
            chunk = chunk.strip()
            cm = re.match(r'^(\d+):(\d+)\s*-\s*(\d+)$', chunk)
            if cm:
                out.append((book, int(cm.group(1)), int(cm.group(2)),
                            int(cm.group(3))))
                continue
            cm = re.match(r'^(\d+):(\d+)$', chunk)
            if cm:
                out.append((book, int(cm.group(1)), int(cm.group(2)),
                            int(cm.group(2))))
                continue
            cm = re.match(r'^(\d+)$', chunk)
            if cm and out and ':' in rest:
                # `8:4-8, 11-15` — a bare range continues the last chapter.
                continue
            cm = re.match(r'^(\d+)\s*-\s*(\d+)$', chunk)
            if cm and out:
                b, ch, _, _ = out[-1]
                out.append((b, ch, int(cm.group(1)), int(cm.group(2))))
                continue
            cm = re.match(r'^(\d+)$', chunk)
            if cm:
                out.append((book, int(cm.group(1)), 1, 200))
    return out


def parse_nave(ref):
    """`40.13.1-23` / `40.13` -> span."""
    bits = ref.split('.')
    try:
        book = BOOKS[int(bits[0]) - 1]
    except (ValueError, IndexError):
        return None
    if len(bits) == 1:
        return None
    ch = int(re.sub(r'\D', '', bits[1]) or 0)
    if not ch:
        return None
    if len(bits) == 2:
        return (book, ch, 1, 200)
    m = re.match(r'^(\d+)(?:-(\d+))?$', bits[2])
    if not m:
        return (book, ch, 1, 200)
    return (book, ch, int(m.group(1)), int(m.group(2) or m.group(1)))


CHAPTER_LEN = {}


def load_chapter_lengths():
    """Real verse counts, from the bundled KJV.

    `versification.json` is a Hebrew/English mapping, not a length table,
    so a "whole chapter" span was being expanded with a 200-verse
    sentinel — which is harmless for a lookup and a lie in a printed
    reference.
    """
    if CHAPTER_LEN:
        return CHAPTER_LEN
    for row in json.load(open(asset('kjv.json'))):
        key = (row['book'], int(row['chapter']))
        v = int(row['verse'])
        if v > CHAPTER_LEN.get(key, 0):
            CHAPTER_LEN[key] = v
    return CHAPTER_LEN


def clamp(spans):
    """Replace the open sentinel with the chapter's real last verse."""
    lens = load_chapter_lengths()
    out = []
    for book, ch, a, b in spans:
        last = lens.get((book, ch))
        if last:
            b = min(b, last)
            a = min(a, last)
        if b >= a:
            out.append((book, ch, a, b))
    return out


def verses(spans):
    out = []
    for book, ch, a, b in spans:
        for v in range(a, min(b, 200) + 1):
            out.append(f'{book} {ch}:{v}')
    return out


def span_label(spans):
    parts = []
    for book, ch, a, b in spans:
        parts.append(f'{book} {ch}:{a}-{b}' if b > a else f'{book} {ch}:{a}')
    return ' · '.join(parts)


def overlaps(x, y):
    for b1, c1, a1, e1 in x:
        for b2, c2, a2, e2 in y:
            if b1 == b2 and c1 == c2 and a1 <= e2 and a2 <= e1:
                return True
    return False


SECTION_SETS = {'zh-Hans': 'cuv', 'zh-Hant': 'cuv-tr', 'en': 'english-classic'}


def load_sections():
    """The app's own trilingual section headings, by book and chapter.

    Nave's outline is English in this dataset, so an entry taken from it
    showed an English sentence to a Chinese reader — 27 of the 87 did.
    Rather than translate Nave myself, the app's OWN section headings
    are used where they cover the passage: they are bundled, trilingual,
    keyed to the verse, and already what this reader sees at the top of
    that passage in the reading pane. Nave's line is kept underneath as
    a note, because it carries what a heading does not — which journey
    it happened on, whether it is the second telling.
    """
    doc = json.load(open(asset('section_titles.json')))
    out = {}
    for locale, name in SECTION_SETS.items():
        for book, chapters in doc['sets'][name].items():
            for ch, entries in chapters.items():
                for e in entries:
                    out.setdefault((book, int(ch)), {}).setdefault(
                        int(e['verse']), {})[locale] = e['title']
    return out


def section_title(sections, spans):
    """A heading that BEGINS inside the teaching, if there is one.

    Not "the nearest heading at or before the first verse", which was
    tried first and is wrong: the heading covering Matthew 4:23 begins
    at 4:18 and is 呼召四个门徒 — the calling of the four — so
    `Preaches throughout Galilee` came out titled as a different event
    entirely. A heading only names this teaching if this teaching is
    where it starts.
    """
    if not spans:
        return None
    book, ch, start, end = spans[0]
    marks = sections.get((book, ch)) or {}
    for verse in sorted(marks):
        if start <= verse <= end:
            got = marks[verse]
            return got if len(got) == len(SECTION_SETS) else None
    return None


def main():
    sermons = json.load(open(asset('sermons', 'index.json')))
    sections = load_sections()
    refs = json.load(open(asset('sermons', 'refs.json')))
    by_verse = refs['byVerse']
    xr = json.load(open(asset('cross_references.json')))
    plates = json.load(open(asset('maps_index.json')))
    nave_idx = json.load(open(asset('nave', 'index.json')))

    entries = []

    # 1. The text's own divisions.
    for eid, book, c0, v0, c1, v1, title in _STRUCTURAL:
        spans = ([(book, c0, v0, 200)] if c1 != c0 else [(book, c0, v0, v1)])
        if c1 != c0:
            for ch in range(c0 + 1, c1):
                spans.append((book, ch, 1, 200))
            spans.append((book, c1, 1, v1))
        entries.append({'id': eid, 'title': title, 'spans': clamp(spans),
                        'origin': 'structure'})

    # 2. The owner's own sermon series, in its own order.
    TOPICS = {'The Parables of Jesus', 'Sermon on the Mount',
              'The Beatitudes'}
    for s in sorted(sermons, key=lambda s: s['id']):
        if s.get('topic') not in TOPICS:
            continue
        spans = [sp for sp in parse_passage(s.get('passage', ''))
                 if sp[0] in GOSPELS]
        if not spans:
            continue
        entries.append({
            'id': 'sermon-' + s['id'],
            'title': {'en': s['titles']['en'], 'zh-Hans': s['titles']['zh-CN'],
                      'zh-Hant': s['titles']['zh-TW']},
            'spans': clamp(spans),
            'origin': 'sermon',
            'topic': s['topic'],
        })

    # 3. Nave's life-of-Christ outline, for teachings the corpus misses.
    per = nave_idx['topicsPerShard']
    for i, t in enumerate(nave_idx['topics']):
        if t[0] != 'JESUS, THE CHRIST':
            continue
        shard = json.load(open(asset('nave', 't', f'{i // per}.json')))
        lines = shard[str(i)]['l']
        # ONLY THE LIFE OUTLINE. The article's depth-1 headings are
        # `HISTORY OF` at line 0 and then `MISCELLANEOUS FACTS
        # CONCERNING` at 164, after which the article turns into
        # character attributes — `Teacher`, `Preaching`,
        # `Unostentatious in his teaching`. Those match the keyword rule
        # and are not teachings, so the outline is cut where Nave cuts
        # it rather than where the words happen to fall.
        end = next((j for j, l in enumerate(lines)
                    if j > 0 and l.get('d') == 1), len(lines))
        for line in lines[:end]:
            title = (line.get('t') or '').strip()
            if not line.get('r') or not _TEACHING_WORDS.search(title):
                continue
            spans = [sp for sp in (parse_nave(r) for r in line['r'])
                     if sp and sp[0] in GOSPELS]
            if not spans:
                continue
            spans = clamp(spans)
            # A LINE THAT CITES WHOLE CHAPTERS IS NAMING A DISCOURSE.
            # Nave's `Delivers the "Sermon on the Mount"` carries
            # 40.5, 40.6, 40.7 — Matthew 5, 6 and 7 entire. Merged as
            # an ordinary teaching it was absorbed by the first sermon
            # that touched chapter 5, and the beatitude on 5:3 came out
            # claiming the whole chapter. Whole-chapter lines are
            # containers, like the structural entries, and take the same
            # exemption from merging with their own parts.
            lens = load_chapter_lengths()
            whole = all(a == 1 and z == lens.get((b, c), z)
                        for b, c, a, z in spans)
            # IS THIS LINE A PARALLEL SET? Nave lists the synoptic
            # parallels of one teaching on one line — the sower is
            # Mt 13:1-23, Mk 4:1-25, Lk 8:4-18 — and those belong
            # together on the page 「有平行经文的也要放在一起」.
            #
            # But he also lumps unrelated passages onto a line, and that
            # is where the Mark 15 defect came from: `Teaches in
            # Galilee` cites Mt 4:17, Mk 1:14, Mk 15, Lk 4:14,
            # Lk 15:1-32 and Jn 4:43-45. The two shapes are told apart
            # by a fact about the citation, not by reading it — a true
            # parallel set names AT MOST ONE passage per gospel.
            per_book = collections.Counter(b for b, _, _, _ in spans)
            entries.append({
                'id': 'nave-' + re.sub(r'[^a-z0-9]+', '-', title.lower())[:44],
                'title': {'en': title, 'zh-Hans': title, 'zh-Hant': title},
                'spans': spans,
                'parallel': max(per_book.values()) == 1 and len(spans) > 1,
                'origin': 'structure' if whole else 'nave',
            })
        break

    # ── merge ────────────────────────────────────────────────────────
    #
    # Three sources will name the same teaching. They are merged on the
    # verses they cover, not on their titles, because the titles are in
    # three different registers — Nave's is a sentence about Jesus
    # ("Enunciates the parable of the sower"), the sermon's is the
    # owner's own heading, the structural one is the passage's name.
    #
    # WHICH TITLE WINS: the sermon's, then the structural one, then
    # Nave's. The sermon corpus is the owner's own exposition and is
    # already trilingual; Nave's is English-only in this dataset, so a
    # Nave title shows the same English in all three locales and is the
    # last resort rather than the default.
    #
    # STRUCTURAL ENTRIES DO NOT MERGE, and that is the difference
    # between a list and a hierarchy. The Sermon on the Mount CONTAINS
    # the Beatitudes, which contain twelve sermons on single verses; a
    # flat merge cannot say so, and the first build showed what happens
    # when it tries — the first beatitude's sermon absorbed the whole
    # discourse and the Sermon on the Mount stopped existing as an
    # entry. The containers stay whole and the parts point at them
    # through `partOf`.
    RANK = {'sermon': 0, 'structure': 1, 'nave': 2}
    merged = []
    for e in sorted(entries, key=lambda e: RANK[e['origin']]):
        for m in merged:
            if (m['origin'] == 'structure') != (e['origin'] == 'structure'):
                continue
            if overlaps(m['spans'], e['spans']):
                m['origins'].append(e['origin'])
                # WIDEN ONLY WHERE THEY MEET. Taking the other entry's
                # spans wholesale looked reasonable and was wrong:
                # Nave's outline lines carry the PARALLEL references for
                # one teaching, so `Teaches in Galilee` holds Mt 4:17,
                # Mk 1:14, Mk 15, Lk 4:14, Lk 15:1-32 and Jn 4:43-45.
                # A sermon on Luke 15:1-7 overlaps that on Luke 15 —
                # and the parable of the lost sheep then claimed Mark
                # 15, the crucifixion, as part of itself.
                #
                # So a merge may only extend a span within a chapter the
                # two already share.
                #
                # AND NEVER ADOPT A WHOLE CHAPTER. A reference to a
                # chapter entire is a container reference wherever it
                # turns up, not only in the lines caught above: Nave
                # lines mix `40.5.3-12` with a bare `40.5`, so the
                # whole-chapter test at construction cannot see all of
                # them. Without this, the beatitude on Matthew 5:3 came
                # out spanning Matthew 5:1-48.
                lens = load_chapter_lengths()
                # A parallel set contributes the books the anchor does
                # not have — that is the whole point of merging it.
                if e.get('parallel'):
                    have = {b for b, _, _, _ in m['spans']}
                    for sp in e['spans']:
                        if sp[0] not in have:
                            m['spans'].append(sp)
                grown = []
                for b, c, a, z in m['spans']:
                    for b2, c2, a2, z2 in e['spans']:
                        if b2 != b or c2 != c or a2 > z or a > z2:
                            continue
                        if a2 == 1 and z2 == lens.get((b2, c2), z2):
                            continue
                        a, z = min(a, a2), max(z, z2)
                    grown.append((b, c, a, z))
                m['spans'] = grown
                break
        else:
            e['origins'] = [e['origin']]
            merged.append(e)

    # WHAT KIND OF TEACHING, decided by the sources rather than by me:
    # the owner's own sermon series says which sermons are on parables,
    # Nave says `parable` in the line itself, and the structural entries
    # are discourses by construction. Anything else is left as a plain
    # teaching rather than being forced into a category.
    for e in merged:
        if e['origin'] == 'structure':
            e['kind'] = 'discourse'
        elif e.get('topic') == 'The Parables of Jesus' or \
                re.search(r'parable', e['title']['en'], re.I):
            e['kind'] = 'parable'
        else:
            e['kind'] = 'teaching'

    order = {b: i for i, b in enumerate(BOOKS)}
    merged.sort(key=lambda e: (order[e['spans'][0][0]], e['spans'][0][1],
                               e['spans'][0][2]))

    # Which discourse each teaching sits inside, if any. Containers are
    # sorted first at the same opening verse so a reader meets the whole
    # before its parts.
    containers = [e for e in merged if e['origin'] == 'structure']
    for e in merged:
        e['partOf'] = None
        if e['origin'] == 'structure':
            continue
        for c in containers:
            inside = all(any(b == b2 and c2 == ch and a2 <= a and z <= z2
                             for b2, c2, a2, z2 in c['spans'])
                         for b, ch, a, z in e['spans'])
            if inside:
                e['partOf'] = c['id']
                break
    merged.sort(key=lambda e: (order[e['spans'][0][0]], e['spans'][0][1],
                               e['spans'][0][2],
                               0 if e['origin'] == 'structure' else 1))

    # ── attach ───────────────────────────────────────────────────────
    plate_by_book = collections.defaultdict(list)
    for pl in plates:
        for book, rng in (pl.get('books') or {}).items():
            plate_by_book[book].append((rng[0], rng[1], pl))

    def cross(vs, want):
        """TSK links into `want`, most-linked first.

        Ordering is the SOURCE's, twice over: TSK/OpenBible already
        ranks each verse's own references by community vote, and a
        reference several verses of one teaching point at is commoner
        than one only a single verse points at. Nothing here is my
        judgement about which link matters.
        """
        hits = collections.Counter()
        rank = {}
        for v in vs:
            for j, target in enumerate(xr.get(v, [])):
                b = target.split(':')[0].rsplit(' ', 1)[0]
                if b in want:
                    hits[target] += 1
                    rank.setdefault(target, j)
        return [t for t, _ in sorted(
            hits.items(), key=lambda kv: (-kv[1], rank[kv[0]], kv[0]))]

    # Give the English-only entries the app's own heading, in all three
    # locales, and demote Nave's sentence to a note.
    filled = 0
    translated = 0
    for e in merged:
        if re.search(r'[\u4e00-\u9fff]', e['title']['zh-Hans']):
            continue
        got = section_title(sections, e['spans'])
        if got:
            e['note'] = e['title']['en']
            e['title'] = dict(got)
            filled += 1
            continue
        zh = _NAVE_ZH.get(re.sub(r'\s+', ' ', e['title']['en']).strip())
        if zh:
            e['title'] = {'en': e['title']['en'],
                          'zh-Hans': zh[0], 'zh-Hant': zh[1]}
            translated += 1

    out = []
    for e in merged:
        vs = verses(e['spans'])
        ids = []
        for v in vs:
            for sid in by_verse.get(v, []):
                if sid not in ids:
                    ids.append(sid)
        by_id = {s['id']: s for s in sermons}
        # PLATES, NARROWEST FIRST. Matched by chapter alone, the whole-
        # book maps win every time — `israel_nt_times` is filed Matthew
        # 1-28 and so belongs to every teaching in Matthew. The first
        # build gave all 76 teachings the same eight general maps.
        # Ranking by how tightly a plate is scoped puts the plate that
        # is about THIS passage first and leaves the atlas behind it.
        scored = {}
        for book, ch, _, _ in e['spans']:
            for lo, hi, pl in plate_by_book.get(book, []):
                if lo <= ch <= hi:
                    width = hi - lo
                    if pl['id'] not in scored or width < scored[pl['id']][0]:
                        scored[pl['id']] = (width, pl)
        pls = [pl for _, pl in sorted(scored.values(),
                                      key=lambda w: (w[0], w[1]['id']))]
        apostles = cross(vs, EPISTLES | {'Acts'})
        out.append({
            'id': e['id'],
            'title': e['title'],
            'note': e.get('note'),
            'origins': sorted(set(e['origins'])),
            'partOf': e['partOf'],
            'kind': e['kind'],
            'refs': [{'book': b, 'chapter': c, 'start': a, 'end': z}
                     for b, c, a, z in e['spans']],
            'label': span_label(e['spans']),
            'sermons': [
                {'id': i, 'title': by_id[i]['titles'], 'date': by_id[i]['date'],
                 'topic': by_id[i].get('topic', '')}
                for i in ids if i in by_id][:12],
            'oldTestament': cross(vs, OT)[:12],
            'apostles': [
                {'ref': r,
                 'lordsWord': _LORDS_WORD.get(r.split('-')[0].strip())}
                for r in apostles[:12]],
            # The plate's own NAME, not its asset id. The first build
            # printed `illus_tissot_healing_of_the_lepers_at_capernaum`
            # at the reader, which is a filename wearing a chip.
            'plates': [
                {'id': p['id'], 'title': p['title']} for p in pls[:8]],
        })

    doc = {
        '_meta': {
            'title': 'The Teachings of the Lord Jesus',
            'arrangement': (
                "Editorial. There is no canonical enumeration of Jesus' "
                "teachings; the parables are a stable category and the "
                "discourses are not. Ordered canonically. Entries come from "
                "the text's own divisions (Matthew's five discourses, John's "
                "discourses), from the sermon corpus's own series, and from "
                "Nave's Topical Bible life-of-Christ outline."),
            'sources': {
                'sermons': 'assets/sermons — the corpus bundled with this app',
                'outline': "Nave's Topical Bible (1896), 'JESUS, THE CHRIST', "
                           'public domain',
                'crossReferences': 'Treasury of Scripture Knowledge merged '
                                   'with OpenBible.info votes',
                'plates': 'assets/maps_index.json',
            },
            'claims': (
                'Cross-references assert that two passages are RELATED. They '
                'do not assert that one rests on the other. The only links '
                "marked as dependence are those where an apostle says so: "
                '1 Cor 7:10-11, 9:14, 11:23-25; 1 Thess 4:15; Acts 20:35.'),
            'generator': 'scripts/build_jesus_teachings.py',
            'version': 1,
        },
        'teachings': out,
    }
    path = asset('jesus_teachings.json')
    with open(path, 'w') as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)

    print(f'{len(entries)} raw -> {len(out)} teachings')
    print(f'section headings filled in: {filled}, translated: {translated}')
    print('kinds:', collections.Counter(e['kind'] for e in out))
    print('with parallels in 2+ gospels:',
          sum(1 for e in out
              if len({r['book'] for r in e['refs']}) > 1))
    left = sum(1 for e in out
               if not re.search(r'[\u4e00-\u9fff]', e['title']['zh-Hans']))
    print(f'still English-only in a Chinese UI: {left}')
    print(collections.Counter(o for e in out for o in e['origins']))
    print(f"with a sermon: {sum(1 for e in out if e['sermons'])}")
    print(f"with OT links: {sum(1 for e in out if e['oldTestament'])}")
    print(f"with apostles: {sum(1 for e in out if e['apostles'])}")
    print(f"with plates:   {sum(1 for e in out if e['plates'])}")
    print(f"Lord's word marked: "
          f"{sum(1 for e in out for a in e['apostles'] if a['lordsWord'])}")
    print(f"written {path} "
          f"({os.path.getsize(path)/1024:.0f} KB)")
    for e in out[:6]:
        print(f"  {e['label'][:26]:28} {e['title']['zh-Hans'][:20]:22} "
              f"讲{len(e['sermons'])} 旧{len(e['oldTestament'])} "
              f"使{len(e['apostles'])} 图{len(e['plates'])}")


if __name__ == '__main__':
    main()
