#!/usr/bin/env python3
"""
Extract Bible references from each sermon body and emit a reverse
index for the app's bidirectional linking.

Reads:
  assets/sermons/index.json
  assets/sermons/{en,zh-CN,zh-TW}/<id>.txt

Writes:
  assets/sermons/refs.json
    {
      "byVerse": {
        "Luke 4:5":   ["004", "005"],
        "Romans 8:1": ["..."]
      },
      "bySermon": {
        "004": ["Luke 4:5", "Luke 4:6", "Luke 4:13", "Matthew 2:2",
                "1 John 3:8", "John 12:31", "John 14:30", "John 16:11"]
      }
    }

The English book name is canonical (used by the Flutter
`resolveAndPrepareJump` which looks up `verses.firstWhere(book == X)`
post-`translateBookName`). Chinese references in zh-CN / zh-TW bodies
are mapped through the same alias index `parseReference` uses.

Run from repo root:
    python3 scripts/extract_sermon_refs.py            # rewrite the asset
    python3 scripts/extract_sermon_refs.py --check    # is it up to date?
    python3 scripts/extract_sermon_refs.py --out /tmp/refs.json

`--check` rebuilds in memory and compares against the committed asset,
naming what moved and exiting non-zero on any difference. `--out` writes
somewhere else, so the output can be inspected without touching the
shipped file — the two things this script needed and did not have while
it was quietly failing to reproduce its own asset.
"""
from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SERMONS = REPO / "assets" / "sermons"
INDEX_JSON = SERMONS / "index.json"
REFS_OUT = SERMONS / "refs.json"

# ────────────────────────────────────────────────────────────────────
# Book-name alias index. Mirrors the dart-side
# `lib/utils/reference_parser.dart` lookups so Python-extracted refs
# resolve to the same canonical English book names the app uses.
# ────────────────────────────────────────────────────────────────────

CANONICAL_BOOKS = [
    "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy",
    "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel",
    "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles",
    "Ezra", "Nehemiah", "Esther", "Job", "Psalms", "Proverbs",
    "Ecclesiastes", "Song of Solomon", "Isaiah", "Jeremiah",
    "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel", "Amos",
    "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk",
    "Zephaniah", "Haggai", "Zechariah", "Malachi",
    "Matthew", "Mark", "Luke", "John", "Acts", "Romans",
    "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians",
    "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians",
    "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews",
    "James", "1 Peter", "2 Peter", "1 John", "2 John", "3 John",
    "Jude", "Revelation",
]

ENGLISH_ALIASES = {
    "Genesis": ["Gen", "Gn"],
    "Exodus": ["Exo", "Exod", "Ex"],
    "Leviticus": ["Lev", "Lv"],
    "Numbers": ["Num", "Nm", "Nu"],
    "Deuteronomy": ["Deu", "Deut", "Dt"],
    "Joshua": ["Jos", "Josh", "Jsh"],
    "Judges": ["Jdg", "Judg", "Jg"],
    "Ruth": ["Rut", "Ru"],
    "1 Samuel": ["1Sam", "1 Sam", "1Sa", "1 Sa", "I Sam", "ISam"],
    "2 Samuel": ["2Sam", "2 Sam", "2Sa", "2 Sa", "II Sam", "IISam"],
    "1 Kings": ["1Kgs", "1 Kgs", "1Ki", "1 Ki", "I Kings", "IKings"],
    "2 Kings": ["2Kgs", "2 Kgs", "2Ki", "2 Ki", "II Kings", "IIKings"],
    "1 Chronicles": ["1Chr", "1 Chr", "1Ch", "1 Ch", "I Chr", "IChr"],
    "2 Chronicles": ["2Chr", "2 Chr", "2Ch", "2 Ch", "II Chr", "IIChr"],
    "Ezra": ["Ezr", "Ez"],
    "Nehemiah": ["Neh", "Ne"],
    "Esther": ["Est", "Esth"],
    "Job": ["Jb"],
    "Psalms": ["Ps", "Psa", "Psalm"],
    "Proverbs": ["Prv", "Prov", "Pr"],
    "Ecclesiastes": ["Ecc", "Eccl", "Ec"],
    "Song of Solomon": ["Song", "SoS", "Sg", "Cant", "Canticles", "Song of Songs"],
    "Isaiah": ["Isa", "Is"],
    "Jeremiah": ["Jer", "Je"],
    "Lamentations": ["Lam", "La"],
    "Ezekiel": ["Eze", "Ezk", "Ezek"],
    "Daniel": ["Dan", "Dn"],
    "Hosea": ["Hos", "Ho"],
    "Joel": ["Jl"],
    "Amos": ["Am"],
    "Obadiah": ["Oba", "Obd", "Ob"],
    "Jonah": ["Jon", "Jnh"],
    "Micah": ["Mic", "Mc"],
    "Nahum": ["Nah", "Na"],
    "Habakkuk": ["Hab", "Hk"],
    "Zephaniah": ["Zep", "Zeph"],
    "Haggai": ["Hag", "Hg"],
    "Zechariah": ["Zec", "Zech"],
    "Malachi": ["Mal"],
    "Matthew": ["Mat", "Matt", "Mt"],
    "Mark": ["Mar", "Mrk", "Mk"],
    "Luke": ["Luk", "Lk"],
    "John": ["Joh", "Jhn", "Jn"],
    "Acts": ["Act", "Ac"],
    "Romans": ["Rom", "Ro"],
    "1 Corinthians": ["1Cor", "1 Cor", "1Co", "1 Co", "I Cor", "ICor", "1 Corinth"],
    "2 Corinthians": ["2Cor", "2 Cor", "2Co", "2 Co", "II Cor", "IICor", "2 Corinth"],
    "Galatians": ["Gal", "Ga"],
    "Ephesians": ["Eph", "Ep"],
    "Philippians": ["Phil", "Php", "Pp"],
    "Colossians": ["Col", "Cl"],
    "1 Thessalonians": ["1Thess", "1 Thess", "1Th", "1 Th", "I Thes", "IThess"],
    "2 Thessalonians": ["2Thess", "2 Thess", "2Th", "2 Th", "II Thes", "IIThess"],
    "1 Timothy": ["1Tim", "1 Tim", "1Ti", "1 Ti", "I Tim", "ITim"],
    "2 Timothy": ["2Tim", "2 Tim", "2Ti", "2 Ti", "II Tim", "IITim"],
    "Titus": ["Tit", "Ti"],
    "Philemon": ["Phlm", "Phm", "Phn"],
    "Hebrews": ["Heb", "He"],
    "James": ["Jas", "Jam", "Jm"],
    "1 Peter": ["1Pet", "1 Pet", "1Pe", "1 Pe", "I Pet", "IPet"],
    "2 Peter": ["2Pet", "2 Pet", "2Pe", "2 Pe", "II Pet", "IIPet"],
    "1 John": ["1John", "1 Jn", "1Jn", "I John", "IJn", "1 Jo"],
    "2 John": ["2John", "2 Jn", "2Jn", "II John", "IIJn", "2 Jo"],
    "3 John": ["3John", "3 Jn", "3Jn", "III John", "IIIJn", "3 Jo"],
    "Jude": ["Jud", "Jde"],
    "Revelation": ["Rev", "Rv", "Revelations", "Apoc", "Apocalypse"],
}

CHINESE_ALIASES = {
    # Simplified short
    "创": "Genesis", "出": "Exodus", "利": "Leviticus",
    "民": "Numbers", "申": "Deuteronomy",
    "书": "Joshua", "士": "Judges", "得": "Ruth",
    "撒上": "1 Samuel", "撒下": "2 Samuel",
    "王上": "1 Kings", "王下": "2 Kings",
    "代上": "1 Chronicles", "代下": "2 Chronicles",
    "拉": "Ezra", "尼": "Nehemiah", "斯": "Esther",
    "伯": "Job", "诗": "Psalms", "诗篇": "Psalms", "箴": "Proverbs",
    "传": "Ecclesiastes", "歌": "Song of Solomon", "雅歌": "Song of Solomon",
    "赛": "Isaiah", "耶": "Jeremiah", "哀": "Lamentations",
    "结": "Ezekiel", "但": "Daniel",
    "何": "Hosea", "珥": "Joel", "摩": "Amos",
    "俄": "Obadiah", "拿": "Jonah", "弥": "Micah",
    "鸿": "Nahum", "哈": "Habakkuk", "番": "Zephaniah",
    "该": "Haggai", "亚": "Zechariah", "玛": "Malachi",
    "太": "Matthew", "可": "Mark", "路": "Luke", "约": "John",
    "徒": "Acts", "罗": "Romans",
    "林前": "1 Corinthians", "林后": "2 Corinthians",
    "加": "Galatians", "弗": "Ephesians", "腓": "Philippians", "西": "Colossians",
    "帖前": "1 Thessalonians", "帖后": "2 Thessalonians",
    "提前": "1 Timothy", "提后": "2 Timothy",
    "多": "Titus", "门": "Philemon", "来": "Hebrews",
    "雅": "James",
    "彼前": "1 Peter", "彼后": "2 Peter",
    "约一": "1 John", "约二": "2 John", "约三": "3 John",
    "犹": "Jude", "启": "Revelation",
    # Traditional variants
    "書": "Joshua", "師": "Judges",
    "詩": "Psalms", "詩篇": "Psalms",
    "賽": "Isaiah", "結": "Ezekiel",
    "彌": "Micah", "鴻": "Nahum", "該": "Haggai",
    "亞": "Zechariah", "瑪": "Malachi",
    "羅": "Romans",
    "門": "Philemon", "來": "Hebrews",
    "猶": "Jude", "啟": "Revelation",
    # Common full Chinese names
    "创世记": "Genesis", "創世記": "Genesis",
    "出埃及记": "Exodus", "出埃及記": "Exodus",
    "马太福音": "Matthew", "馬太福音": "Matthew",
    "马可福音": "Mark", "馬可福音": "Mark",
    "路加福音": "Luke",
    "约翰福音": "John", "約翰福音": "John",
    "使徒行传": "Acts", "使徒行傳": "Acts",
    "罗马书": "Romans", "羅馬書": "Romans",
    "哥林多前书": "1 Corinthians", "哥林多前書": "1 Corinthians",
    "哥林多后书": "2 Corinthians", "哥林多後書": "2 Corinthians",
    "希伯来书": "Hebrews", "希伯來書": "Hebrews",
    "雅各书": "James", "雅各書": "James",
    "彼得前书": "1 Peter", "彼得前書": "1 Peter",
    "彼得后书": "2 Peter", "彼得後書": "2 Peter",
    "约翰一书": "1 John", "約翰一書": "1 John",
    "约翰二书": "2 John", "約翰二書": "2 John",
    "约翰三书": "3 John", "約翰三書": "3 John",
    "犹大书": "Jude", "猶大書": "Jude",
    "启示录": "Revelation", "啟示錄": "Revelation",
}


def build_alias_index() -> dict[str, str]:
    """Lowercased, dot-stripped, internal-whitespace-collapsed alias →
    canonical English book name."""
    idx: dict[str, str] = {}
    def add(alias: str, canonical: str):
        key = re.sub(r"[\s\.　]+", "", alias.lower())
        if key:
            idx[key] = canonical
    for b in CANONICAL_BOOKS:
        add(b, b)
    for canon, aliases in ENGLISH_ALIASES.items():
        for a in aliases:
            add(a, canon)
    for alias, canon in CHINESE_ALIASES.items():
        add(alias, canon)
    return idx


ALIAS = build_alias_index()


# Build an alternation regex of all known book aliases, ordered by
# length descending so "1 Corinthians" beats "Corinth" beats "Cor".
#
# Split in two by whether a trailing `.` may belong to the name. An
# abbreviation carries one — "Mt. 6" is a citation. A spelled-out book
# name does not, and reading its full stop as one merges two sentences:
# "the letters of John. 1 John 2 and verse 18" was read as John chapter
# 1, which then ate the "1" of the real citation and left "John 2:18"
# standing where the corpus says 1 John 2:18. Three sites, all the same
# shape — a sentence ending in a book name in front of a numbered book
# — and all three invented a reference the sermon never made.
def build_book_patterns() -> tuple[str, str]:
    """(spelled-out names, abbreviations) as length-ordered alternations."""
    spelled = set(CANONICAL_BOOKS)
    abbreviated: set[str] = set()
    for canon, lst in ENGLISH_ALIASES.items():
        abbreviated.update(lst)
    abbreviated.update(CHINESE_ALIASES.keys())
    abbreviated -= spelled

    def alternation(names: set[str]) -> str:
        # Longest first so partial matches don't shadow longer ones.
        ordered = sorted(names, key=lambda s: (-len(s), s))
        return r"(?:" + "|".join(re.escape(a) for a in ordered) + r")"

    return alternation(spelled), alternation(abbreviated)


SPELLED_BOOK_RE, ABBREV_BOOK_RE = build_book_patterns()

# A full reference: <book><opt-space><chapter>(:|.|：<verse>(-<verse>)?)?
# Stops at sensible boundaries to avoid eating prose.
#
# The preacher speaks his citations and the transcripts keep them that
# way: "Acts chapter 5", "Romans chapter 8 verse 14", "in Matthew
# chapter 6, verses 25 to 34". A punctuation-only separator cannot see
# any of those, so eight references the corpus states outright were
# invisible to this script. `refs.json` holds them because whatever
# generated it could read the spoken form; every regeneration since has
# silently dropped them.
#
# Only the whole words are admitted, never `ch.` or `v.`. Requiring the
# word means a match needs a token that no ordinary sentence puts
# between a book name and a number, and the corpus does not abbreviate.
#
# The comma and the word `and` are admitted only in front of `verse(s)`
# — never on their own between book and chapter, where "in Mark, 12
# disciples" would become Mark 12. `and` earns its place: the corpus
# says "Luke chapter 4 and verse 18" as readily as "Luke chapter 4,
# verse 18", and without it those sites match only as far as the
# chapter and file the sermon under a whole chapter when it named one
# verse. That is not a false positive but it is the wrong key, and it
# was 168 of them.
#
# The range tail is deliberately left as it was. A bare number with no
# book in front of it cannot match this pattern at all, so the "to 34"
# of "verses 25 to 34" is inert whether it is consumed or not, and what
# is recorded is the head — `Matthew 6:25`, which is exactly what the
# committed asset holds for 038. Same for "verses 12 and 13" (339) and
# "verses 1 and 2" (314): heads only, asset agrees.
REF_RE = re.compile(
    rf"\b({SPELLED_BOOK_RE}|{ABBREV_BOOK_RE}\.?)"
    rf"\s*"
    rf"(?:chapters?\s+)?"
    rf"(\d+)"
    rf"(?:\s*(?:[:：.]|[,，]?\s*(?:and\s+)?verses?\s+)\s*(\d+)"
    rf"(?:\s*[-–—]\s*\d+)?)?",
)


# A number that belongs to the FOLLOWING UNIT, not to scripture.
#
# "the word occurs in Deuteronomy 43 times" indexed Deuteronomy 43, a
# chapter that does not exist — and the canon check caught that one. It
# cannot catch the ones that land on a real chapter: this corpus says
# "is 27 times", "is 25 years", "is 30 years", "is 15 years", and `Is`
# is an alias for Isaiah, so four valid-looking Isaiah chapters entered
# the index off the verb "is".
#
# `%` sits OUTSIDE the `\b`. A per-cent sign is not a word character, so
# `%\b` matches only when a letter follows it — and sermon 424 asks "Is
# 50% enough?", which reached the index as Isaiah 50. This is the shape
# YsWords arrived at (406ed88) and the reason is worth carrying with it.
#
# `verse(s)` is deliberately NOT in this list. "Jeremiah 12 verse 2" is
# the most explicit citation English has, and REF_RE reads the verse
# word as a SEPARATOR — so a unit match can never reach it.
_UNIT_AFTER = re.compile(
    r"\s*(?:(?:times?|years?|days?|hours?|minutes?|weeks?|months?|"
    r"words?|percent)\b|%)", re.IGNORECASE)


def normalize_alias(s: str) -> str:
    return re.sub(r"[\s\.　]+", "", s.lower())


# The five books with only one chapter, and the citation form that
# belongs to them alone.
#
# A one-chapter book is cited WITHOUT a chapter — "2 John, verse 7",
# "the Letter of Jude, verse 6" — because there is no chapter to name.
# REF_RE requires digits after the alias, so every such citation was
# invisible: sermon 238 ("The arch-deceiver and how not to be deceived")
# is built on 2 John and reached the index with NO references at all.
#
# The key is `Book N`, not `Book 1:N`, because that is the convention
# this corpus already holds — `2 John 7`, `Jude 6`, `Jude 11` are all in
# the shipped asset, produced by the bare-number form — and because
# `reference_parser.dart` re-reads exactly that shape: `_singleChapterBooks`
# turns "Jude 14" into chapter 1, verse 14. Emitting `2 John 1:7` here
# would have been a second spelling for one idea, which is how 42
# references came to be stored and never shown.
#
# Restricted to these five on purpose. "Jeremiah, verse 7" is not a
# citation in any book that has chapters — it is a sentence that ran on.
_ONE_CHAPTER_BOOKS = ("Obadiah", "Philemon", "2 John", "3 John", "Jude")

# The SAME alias patterns REF_RE uses, then filtered by canon after the
# match. Building an alternation out of `ALIAS`'s own keys does not
# work and the reason is quiet: those keys are normalised — "2 John" is
# stored as `2john`, spaces stripped — so a literal alternation matches
# nothing a preacher ever typed.
#
# The gap allows the apposition a preacher actually speaks: "2 John, the
# Second Letter of John, verse 7". It may not cross a sentence, which is
# what excludes ". " from the run.
# The lookahead after the alias is NOT decoration. REF_RE needs no
# trailing boundary because a digit must follow immediately, so "Ob"
# inside "obligation" can never reach a chapter. Here a 60-character gap
# follows the alias, and without the boundary sermon 034 —
# "…under the OBligation to forgive… verse 21 or 22, Peter says…" —
# produced `Obadiah 21`. Caught by reading all five new references back
# against the corpus rather than trusting the count.
_ONE_CHAPTER_VERSE_RE = re.compile(
    rf"\b({SPELLED_BOOK_RE}|{ABBREV_BOOK_RE}\.?)"
    rf"(?![A-Za-z])"
    rf"[^.;:!?\d]{{0,60}}?"
    rf"\bverses?\s+(\d+)",
    re.IGNORECASE)


def extract_refs(text: str) -> list[str]:
    """Return canonical "Book chapter:verse" strings (deduped, in
    order of first appearance) found in [text]."""
    seen: set[str] = set()
    found: list[tuple[int, str]] = []
    for m in REF_RE.finditer(text):
        alias_raw, chapter, verse = m.group(1), m.group(2), m.group(3)
        canon = ALIAS.get(normalize_alias(alias_raw))
        if not canon:
            continue
        try:
            ch = int(chapter)
        except ValueError:
            continue
        if ch <= 0 or ch > 200:
            continue
        # Only a BARE chapter can be a counted number. "Isaiah 27:3" is
        # a citation whatever follows it; "Isaiah 27 times" is arithmetic
        # wearing a book's name.
        if not verse and _UNIT_AFTER.match(text, m.end()):
            continue
        if verse:
            try:
                v = int(verse)
            except ValueError:
                v = None
            key = f"{canon} {ch}:{v}" if v else f"{canon} {ch}"
        else:
            key = f"{canon} {ch}"
        if key not in seen:
            seen.add(key)
            found.append((m.start(), key))

    # The one-chapter form, merged by POSITION so "first appearance"
    # still means first in the text and not "after everything else".
    for m in _ONE_CHAPTER_VERSE_RE.finditer(text):
        canon = ALIAS.get(normalize_alias(m.group(1)))
        if canon not in _ONE_CHAPTER_BOOKS:
            continue
        v = int(m.group(2))
        if v <= 0 or v > 200:
            continue
        key = f"{canon} {v}"
        if key not in seen:
            seen.add(key)
            found.append((m.start(), key))

    found.sort(key=lambda pair: pair[0])
    return [key for _, key in found]


# ────────────────────────────────────────────────────────────────────
# Staleness digest.
#
# `refs.json` is derived, and nothing used to notice when it stopped
# matching what it is derived FROM. The corpus was edited after the
# asset was written, the asset kept the references the edit removed,
# and the next person to run this script would have deleted them
# without a word. That is the failure this stamp exists to make loud.
#
# FNV-1a is a change detector, not a security hash: no adversary is
# being modelled, and the only property needed is that a different
# input gives a different number. It is spelled out here — rather than
# reached for from a library — because the guard that reads it back is
# `test/sermon_refs_up_to_date_test.dart`, which runs in CI where
# Python does not, and `crypto` is only a transitive dependency of this
# project. Fourteen lines of arithmetic in each language beats a new
# direct dependency for a checksum.
#
# The generator's own source is digested alongside the corpus, so
# editing the extraction rules also marks the asset stale.
_FNV_OFFSET = 0xCBF29CE484222325
_FNV_PRIME = 0x100000001B3
_MASK64 = 0xFFFFFFFFFFFFFFFF


def digest_inputs() -> str:
    """A hex FNV-1a/64 over every byte this script reads, in a fixed
    order. Mirrored exactly by the Dart guard."""
    h = _FNV_OFFSET

    def feed(data: bytes) -> None:
        nonlocal h
        for byte in data:
            h = ((h ^ byte) * _FNV_PRIME) & _MASK64

    for path in inputs_in_digest_order():
        # The path is fed too, so a body file that goes missing is a
        # change even when some other file's bytes make up the loss.
        feed(path.relative_to(REPO).as_posix().encode("utf-8"))
        feed(path.read_bytes())
    return f"{h:016x}"


def inputs_in_digest_order() -> list[Path]:
    """Everything the output depends on, in the order the digest walks
    it: this script, the index, then every body file the index names,
    by sermon id then language."""
    paths = [Path(__file__).resolve(), INDEX_JSON]
    sermons = json.loads(INDEX_JSON.read_text(encoding="utf-8"))
    for sermon in sorted(sermons, key=lambda s: s["id"]):
        for lang in ("en", "zh-CN", "zh-TW"):
            body = SERMONS / lang / f"{sermon['id']}.txt"
            if body.exists():
                paths.append(body)
    return paths


def build() -> dict:
    """The whole asset, as it should be on disk right now."""
    sermons = json.loads(INDEX_JSON.read_text(encoding="utf-8"))
    by_sermon: dict[str, list[str]] = {}
    by_verse: dict[str, list[str]] = defaultdict(list)

    for sermon in sermons:
        sid = sermon["id"]
        # Aggregate refs from all available languages — Chinese bodies
        # often pick up references missed by the English (and vice
        # versa) because the prose is independently structured.
        merged: list[str] = []
        seen: set[str] = set()
        # Always seed from the index "passage" hint if present so the
        # canonical sermon passage links even if it never appears in
        # body prose.
        passage_hint = sermon.get("passage", "")
        if passage_hint:
            for r in extract_refs(passage_hint):
                if r not in seen:
                    seen.add(r); merged.append(r)
        for lang in ("en", "zh-CN", "zh-TW"):
            body_path = SERMONS / lang / f"{sid}.txt"
            if not body_path.exists():
                continue
            for r in extract_refs(body_path.read_text(encoding="utf-8")):
                if r not in seen:
                    seen.add(r); merged.append(r)
        if merged:
            by_sermon[sid] = merged
            for ref in merged:
                by_verse[ref].append(sid)

    # Sort byVerse keys + ids for deterministic output.
    sorted_by_verse = {
        k: sorted(set(v)) for k, v in sorted(by_verse.items())
    }

    return {
        "_meta": {
            "generator": "scripts/extract_sermon_refs.py",
            "note": (
                "Derived file — do not hand-edit. Re-run the generator. "
                "`inputsFnv1a64` digests the generator plus every corpus "
                "file it reads; test/sermon_refs_up_to_date_test.dart "
                "recomputes it and fails when this asset is stale."
            ),
            "inputsFnv1a64": digest_inputs(),
        },
        "byVerse": sorted_by_verse,
        "bySermon": by_sermon,
    }


def serialise(doc: dict) -> str:
    return json.dumps(doc, ensure_ascii=False, separators=(",", ":"))


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    check_only = "--check" in argv
    if check_only:
        argv.remove("--check")
    out_path = REFS_OUT
    if "--out" in argv:
        i = argv.index("--out")
        out_path = Path(argv[i + 1]).resolve()
        del argv[i:i + 2]
    if argv:
        print(f"ERROR: unrecognised arguments {argv}", file=sys.stderr)
        return 2

    if not INDEX_JSON.exists():
        print(f"ERROR: {INDEX_JSON} missing — run ingest_sermons.py first",
              file=sys.stderr)
        return 1

    doc = build()
    sermons = json.loads(INDEX_JSON.read_text(encoding="utf-8"))
    by_sermon, sorted_by_verse = doc["bySermon"], doc["byVerse"]
    total_refs = sum(len(v) for v in by_sermon.values())
    text = serialise(doc)

    if check_only:
        if not REFS_OUT.exists():
            print(f"DRIFT: {REFS_OUT} does not exist", file=sys.stderr)
            return 1
        on_disk = REFS_OUT.read_text(encoding="utf-8")
        if on_disk == text:
            print(f"OK: {REFS_OUT.relative_to(REPO)} is what this "
                  f"generator produces.")
            return 0
        print(f"DRIFT: {REFS_OUT.relative_to(REPO)} is not what this "
              f"generator produces.", file=sys.stderr)
        old = json.loads(on_disk)
        for section in ("byVerse", "bySermon"):
            was, now = old.get(section, {}), doc[section]
            gone = sorted(set(was) - set(now))
            added = sorted(set(now) - set(was))
            changed = [k for k in sorted(set(was) & set(now))
                       if was[k] != now[k]]
            print(f"  {section}: {len(gone)} key(s) only on disk, "
                  f"{len(added)} only from the generator, "
                  f"{len(changed)} differing", file=sys.stderr)
            if gone:
                print(f"    only on disk : {gone[:12]}", file=sys.stderr)
            if added:
                print(f"    only new     : {added[:12]}", file=sys.stderr)
        print("  Re-run without --check to rewrite it, and read the diff "
              "before committing: a reference that disappears is a "
              "reference the corpus no longer states.", file=sys.stderr)
        return 1

    out_path.write_text(text, encoding="utf-8")

    size_kb = out_path.stat().st_size / 1024
    shown = (out_path.relative_to(REPO)
             if out_path.is_relative_to(REPO) else out_path)
    print(f"Wrote {shown}")
    print(f"  Sermons with at least 1 ref : {len(by_sermon)} / {len(sermons)}")
    print(f"  Unique verses cited         : {len(sorted_by_verse)}")
    print(f"  Total ref occurrences       : {total_refs}")
    print(f"  refs.json size              : {size_kb:.1f} KB")
    # Quick sanity: top-10 most-cited verses.
    top = sorted(sorted_by_verse.items(), key=lambda x: -len(x[1]))[:10]
    print("\nTop 10 most-cited verses:")
    for ref, sids in top:
        print(f"  {ref:30s} {len(sids):3d} sermons")
    return 0


if __name__ == "__main__":
    sys.exit(main())
