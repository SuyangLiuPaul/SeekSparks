#!/usr/bin/env python3
"""yahwehdehua.net chapter-reader export -> SeekSparks assets.

Source: ~/Documents/New project/yahwehdehua_bible/output/data/
        verse_readings.jsonl.gz  (one record per version per verse)

Imports the 和合本 reading only. The export also carries 吕振中 (香港聖經公會)
and HCSB (Holman); both are third-party copyrights that the ministry
cannot license on the publishers' behalf, so they are skipped here by
construction rather than by a flag someone could flip. LEB is already
bundled from its own source.

Why 和合本 from this export is safe: the version CODE is
`cuv2017_strongs`, which reads like the copyrighted 2017 revision (RCUV,
香港聖經公會) but is not. Checked against the readings that separate them —
John 3:16 here is 「独生子」 and 「不至灭亡」, which is the 1919 CUV; RCUV
reads 「独一的儿子」 and 「不致灭亡」. The "2017" refers to the Strong's
tagging layer, not the translation. Do not re-derive this from the name.

The `segments` array maps onto TaggedRun almost directly: it alternates
{type:text} and {type:strong, strong_id}, so a text segment plus the
strong that follows it is one run. Two details that are easy to miss:

  * `strongs[].display` wraps a number in PARENTHESES — "(H853)" — when
    the original has a word the translation does not render. That is
    exactly TaggedRun.implied, and the bare `id` field throws the
    distinction away, so read `display`, not `id`.
  * `morphology` is a verse-level list (e.g. ["H8804"]), NOT per word.
    It cannot be attached to a specific run without guessing, so it is
    carried on the verse and left off the runs.

Usage (from the repo root):
    python3 tools/import_yahwehdehua_export.py [--limit N]
"""
import argparse
import gzip
import json
import os
import re
import sys

SRC = os.path.expanduser(
    '~/Documents/New project/yahwehdehua_bible/output/data/'
    'verse_readings.jsonl.gz')

VERSION_CODE = 'cuv2017_strongs'
OUT_VERSION = 'cuv-yhwd'

# Skipped on purpose — see the module docstring.
EXCLUDED = {'luzhenzhong', 'hcsb', 'leb'}

# The app keys Chinese editions by Chinese book names; these must match
# assets/cuvs-yhwh.json exactly or navigation silently misses.
BOOKS_ZH = [
    "创世纪", "出埃及记", "利未记", "民数记", "申命记", "约书亚记", "士师记",
    "路得记", "撒母耳记上", "撒母耳记下", "列王纪上", "列王纪下", "历代志上",
    "历代志下", "以斯拉记", "尼希米记", "以斯帖记", "约伯记", "诗篇", "箴言",
    "传道书", "雅歌", "以赛亚书", "耶利米书", "耶利米哀歌", "以西结书",
    "但以理书", "何西阿书", "约珥书", "阿摩司书", "俄巴底亚书", "约拿书",
    "弥迦书", "那鸿书", "哈巴谷书", "西番雅书", "哈该书", "撒迦利亚书",
    "玛拉基书", "马太福音", "马可福音", "路加福音", "约翰福音", "使徒行传",
    "罗马书", "哥林多前书", "哥林多后书", "加拉太书", "以弗所书", "腓立比书",
    "歌罗西书", "帖撒罗尼迦前书", "帖撒罗尼迦后书", "提摩太前书", "提摩太后书",
    "提多书", "腓利门书", "希伯来书", "雅各书", "彼得前书", "彼得后书",
    "约翰一书", "约翰二书", "约翰三书", "犹大书", "启示录",
]
BOOKS_EN = [
    "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy", "Joshua",
    "Judges", "Ruth", "1 Samuel", "2 Samuel", "1 Kings", "2 Kings",
    "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah", "Esther", "Job",
    "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon", "Isaiah",
    "Jeremiah", "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel",
    "Amos", "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah",
    "Haggai", "Zechariah", "Malachi", "Matthew", "Mark", "Luke", "John",
    "Acts", "Romans", "1 Corinthians", "2 Corinthians", "Galatians",
    "Ephesians", "Philippians", "Colossians", "1 Thessalonians",
    "2 Thessalonians", "1 Timothy", "2 Timothy", "Titus", "Philemon",
    "Hebrews", "James", "1 Peter", "2 Peter", "1 John", "2 John", "3 John",
    "Jude", "Revelation",
]

WS = re.compile(r'\s+')
PAREN = re.compile(r'^\((.+)\)$')

# Punctuation that closes a clause rather than opening one. The export
# emits it at the HEAD of the next text segment — Genesis 1:1 arrives as
# `起初 H7225 ，神 H430`, so a naive split yields a run literally spelled
# 「，神」. That is wrong twice over: the comma terminates 起初, and a
# reader hovering 神 sees a word that starts with punctuation. 20.6% of
# runs were built that way before this fix (71,714 of 347,540), against
# 0.16% in the cuvs-yhwh set built from the official modules — so the
# convention to match is unambiguous.
LEAD_PUNCT = '，。；：、！？」』）〕,.;:!?'


def runs_from_segments(segments, strongs):
    """segments -> TaggedRun dicts {w, s, i, g}.

    The stream is text, then the marker(s) that belong to it. Three
    segment types matter and each behaves differently:

      strong, plain      "H8064"   closes the pending text into a run
      strong, in parens  "(H853)"  the original has a word the Chinese
                                   does not render — context for the
                                   word COMING NEXT, and it must not
                                   consume the pending text
      morph              "H8804"   stem/aspect of the run just closed

    Genesis 1:1 is the whole specification:

        起初 H7225 ，神 H430 创造 H1254 [H8804] 天 (H853) H8064
        地 (H853) H776 。

    「天」 is followed by (H853) and only then by H8064, so an implied
    marker that eats the pending text steals 天 onto 创造 — which is
    exactly what the first version of this function did, while still
    passing a round-trip check because every character was present and
    in order. Order of characters says nothing about where the splits
    belong.

    `strongs` is unused: the parenthesis lives on the segment's own
    `text`, so there is no index to keep in step with a parallel array.
    Kept in the signature because callers pass it and it documents that
    the array was considered and deliberately not relied on.
    """
    runs = []
    buf = []
    pending_implied = []

    def flush(sid):
        text = WS.sub('', ''.join(buf))
        buf.clear()
        # Punctuation at the head of this text belongs to the word just
        # closed. Migrate it before the emptiness check — a segment that
        # is ONLY punctuation must not become a run of its own.
        if runs:
            i = 0
            while i < len(text) and text[i] in LEAD_PUNCT:
                i += 1
            if i:
                runs[-1]['w'] += text[:i]
                text = text[i:]
        if not text:
            # Two real strongs with nothing between: a second number for
            # the word already emitted.
            if runs and sid:
                runs[-1]['i'].append(sid)
            return
        runs.append({
            'w': text,
            's': sid,
            'i': list(pending_implied),
            'g': [],
        })
        pending_implied.clear()

    for seg in segments:
        kind = seg.get('type')
        if kind == 'text':
            buf.append(seg.get('text') or '')
        elif kind == 'morph':
            # Belongs to the word just closed, not the one coming.
            code = (seg.get('text') or '').strip()
            # A parenthesised morph code — "(H8804)" — is the same code
            # the export brackets elsewhere for implied words. Stored raw
            # it matches nothing in the grammar lexicon, so the parsing
            # line silently comes up empty for 2,591 runs. Unwrap it.
            m = PAREN.match(code)
            if m:
                code = m.group(1).strip()
            if code and runs:
                runs[-1]['g'].append(code)
        elif kind == 'strong':
            sid = (seg.get('strong_id') or '').strip()
            if not sid:
                continue
            if PAREN.match((seg.get('text') or '').strip()):
                # Hold it for the NEXT run; leave the buffer alone.
                pending_implied.append(sid)
            else:
                flush(sid)

    tail = WS.sub('', ''.join(buf))
    if tail:
        if runs:
            runs[-1]['w'] += tail
        else:
            runs.append({'w': tail, 's': '', 'i': [], 'g': []})
    if pending_implied and runs:
        runs[-1]['i'].extend(pending_implied)
    return [r for r in runs if r['w']]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--limit', type=int, default=0)
    ap.add_argument('--out', default='assets')
    args = ap.parse_args()

    if not os.path.exists(SRC):
        sys.exit(f'source not found: {SRC}')

    plain, tagged = [], {}
    seen_versions, n, mismatched = set(), 0, 0

    with gzip.open(SRC, 'rt', encoding='utf-8') as fh:
        for line in fh:
            r = json.loads(line)
            seen_versions.add(r['version'])
            if r['version'] != VERSION_CODE:
                continue
            bi = int(r['book_ordinal'])
            if not 1 <= bi <= 66:
                continue
            ch, vs = str(r['chapter']), str(r['verse'])
            text = WS.sub('', r.get('text_clean') or '')
            if not text:
                continue

            plain.append({
                'book': BOOKS_ZH[bi - 1],
                'chapter': ch,
                'verse': vs,
                'text': text,
                'id': f'{bi:03d}{int(ch):03d}{int(vs):03d}',
            })

            runs = runs_from_segments(r.get('segments') or [],
                                      r.get('strongs') or [])
            if runs:
                # The runs must reassemble into exactly the verse the
                # reading pane shows, or two panes render one verse
                # differently. Drop tagging that does not, rather than
                # shipping a quiet disagreement.
                if ''.join(x['w'] for x in runs) == text:
                    tagged.setdefault(BOOKS_EN[bi - 1], {})[f'{ch}:{vs}'] = runs
                else:
                    mismatched += 1
            n += 1
            if args.limit and n >= args.limit:
                break

    for v in sorted(EXCLUDED & seen_versions):
        print(f'  skipped (not ours to redistribute): {v}')

    os.makedirs(args.out, exist_ok=True)
    with open(f'{args.out}/{OUT_VERSION}.json', 'w', encoding='utf-8') as f:
        json.dump(plain, f, ensure_ascii=False, separators=(',', ':'))
    tdir = f'{args.out}/tagged/{OUT_VERSION}'
    os.makedirs(tdir, exist_ok=True)
    for book, verses in tagged.items():
        slug = book.lower().replace(' ', '_')
        with open(f'{tdir}/{slug}.json', 'w', encoding='utf-8') as f:
            json.dump(verses, f, ensure_ascii=False, separators=(',', ':'))

    print(f'{OUT_VERSION}: {n} verses, {len(tagged)} tagged books, '
          f'{mismatched} verses whose runs did not reassemble (tagging '
          f'dropped, text kept)')


if __name__ == '__main__':
    main()
