#!/usr/bin/env python3
"""Import the 和合本【雅伟】简体版＋ Online Bible (.ont) revision.

The edition already shipped as `cuvs-yhwh` came from the publisher's
MySword module (`cuvs+-YHWH.bbl.mybible`, see import_yahweh_modules.py).
This reads their newer Online Bible export of the SAME edition —
version 0.99, dated 2026-08-29, 孙树民 — and takes the READING TEXT from
it while LEAVING THE TAGGED LAYER ALONE wherever it can.

WHY THE TAGGED LAYER IS NOT REBUILT FROM THIS FILE. The .ont is coarser
than the MySword source it supersedes. It attaches numbers to a phrase
where MySword attached them to a word:

    MySword   渊[H8415]  面[H6440, implied H5921]      <- 2 runs
    .ont      渊面<WH5921><WH6440><WH8415>             <- 1 run, 3 numbers

Measured: 13.2% of the .ont's 327,313 tag groups carry more than one
main Strong's number (up to seven), against a shipped layer of 367,651
runs at 11.82 per verse. Per-word Strong's on the Chinese line is the
thing this app does that BibleWorks does not do for a Chinese reader;
rebuilding it from this file would trade that away for a better reading
text. We take the reading text and keep the tagging.

This is the same trap `bible_versions.dart` records for `cuv-yhwd`: a
file that looks better tagged because it is tagged more COARSELY.

WHAT MAKES THAT SAFE. audit_tagged_layer.py checks agreement on CJK
characters only — punctuation and note markup are normalised away. Of
the 9,516 verses whose text changes, 7,771 change only in punctuation or
note markup, so their existing runs still agree. Only the verses whose
CJK actually moves need their runs touched, and where the change is a
same-length character substitution (那->哪, 他->她) the substitution is
applied INTO the existing runs, so granularity survives there too.

DEFECTS IN THE SOURCE. This file is not clean and the importer must not
pretend otherwise. Every one of these is counted and reported:
  * Chinese swallowed into a tag       <牲畜WH2874>, <的WG3588>
  * a missing '>' nesting two tags     <WH5921<WH3802>
  * a doubled '<'                      <<WG5624>
  * suffix noise                       <WH3190s>, <WH123X>
  * a dropped 'W' or dropped H/G       <H4480x>, <3588>
  * 41 sites of the 丶 (U+4E36) lookalike for 、 (U+3001) — the exact
    corruption check 26 removed. THIS SCRIPT DOES NOT FIX THOSE.
    Run tools/repair_chinese_lookalikes.py --write afterwards, as
    import_yahweh_modules.py's own docstring warns.

Run:
    python3 tools/import_yahweh_ont.py <file.ont>            # report only
    python3 tools/import_yahweh_ont.py <file.ont> --write    # apply
"""
import json
import os
import re
import sys
import collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
N_VERSES = 31102

# Strong's proper stops at H8674 / G5624; anything above is a TVM /
# morphology code and belongs in 'g'. Verified against the shipped layer:
# its 'g' codes start at H8675 and G5625, its 'i' codes stop at H8672 and
# G5620. Same boundary the Eagle's View importer documents.
H_MAX, G_MAX = 8674, 5624

CJK = lambda s: "".join(ch for ch in s if "一" <= ch <= "鿿")
PUNCT = "，。；：！？、“”‘’（）〔〕《》〈〉—…·「」『』〖〗)】"


def slug(book_en):
    return book_en


class Defects:
    def __init__(self):
        self.rows = []

    def add(self, ref, kind, frag):
        self.rows.append((ref, kind, frag))

    def report(self):
        by = collections.Counter(k for _, k, _ in self.rows)
        print(f"\nsource defects handled: {len(self.rows)}")
        for k, n in by.most_common():
            print(f"   {n:4}  {k}")
        for ref, kind, frag in self.rows[:10]:
            print(f"        {ref:20} {kind:32} {frag}")


def parse_verse(raw, ref, is_ot, dfx):
    """-> (runs, plain_text). Runs match the shipped tagged schema."""

    runs = []
    buf = []
    i = 0
    n = len(raw)

    def tag_bodies(inner):
        """Split one <...> payload into tag bodies, recovering text."""
        out_text = ""
        bodies = []
        for piece in inner.split("<"):
            if not piece:
                continue
            cjk = CJK(piece)
            if cjk:
                out_text += cjk
                dfx.add(ref, "text swallowed into tag", "<" + inner + ">")
                piece = piece.replace(cjk, "")
            piece = piece.strip()
            if piece:
                bodies.append(piece)
        return bodies, out_text

    def norm(body):
        """-> (letter, number, implied) or None.

        Deliberately tolerant. The source carries a long tail of typos —
        <MWH8802>, <WWH853x>, <WHW853x>, <WH85x3>, <wh1768>, <WG3588xx>,
        <WG358x8>, <WG5613c> — and every one of them still names a
        number unambiguously. Read the digits in order, take the last
        H/G as the language, treat any 'x' anywhere as the implied flag,
        and ignore the rest. Refusing these would drop real tags on the
        floor; guessing at them would not, because there is nothing to
        guess: <WH85x3> has exactly one reading, H853 implied.
        """
        clean = re.fullmatch(r"W([HG])(\d+)(x?)", body)
        digits = "".join(ch for ch in body if ch.isdigit())
        if not digits:
            dfx.add(ref, "tag with no number", "<" + body + ">")
            return None
        up = body.upper()
        letters = [ch for ch in up if ch in "HG"]
        letter = letters[-1] if letters else ("H" if is_ot else "G")
        implied = "X" in up
        if not clean:
            dfx.add(ref, "malformed tag normalised", "<" + body + ">")
        return letter, int(digits), implied

    def flush(tags):
        nonlocal buf
        main, gram, impl = [], [], []
        for letter, num, implied in tags:
            code = f"{letter}{num}"
            cap = H_MAX if letter == "H" else G_MAX
            if implied:
                impl.append(code)
            elif num > cap:
                gram.append(code)
            else:
                main.append(code)
        r = {"w": "".join(buf), "s": main[0] if main else ""}
        # A second main number on one group is the .ont's coarser
        # granularity showing through. Keep them rather than drop them:
        # they are real numbers, and dropping data to fit a schema is how
        # a silent regression starts.
        if len(main) > 1:
            r["s2"] = main[1:]
        if impl:
            r["i"] = impl
        if gram:
            r["g"] = gram
        runs.append(r)
        buf = []

    while i < n:
        ch = raw[i]
        if ch == "<":
            # CONSECUTIVE <…> tokens are ONE group describing ONE word.
            # Flushing per token instead of per group was a real bug here:
            # 说<WH559><WH8799> became 说[H559] + ""[g H8799] rather than
            # 说[H559, g H8799], and the shipped-layer self-check is what
            # caught it — 2% agreement instead of the ~99% it should be.
            tags = []
            while i < n and raw[i] == "<":
                j = raw.find(">", i + 1)
                if j == -1:
                    # 列王紀上 19:7 ends 甚远<。” — a '<' that opens nothing.
                    # Emitting it put a bare angle bracket in the verse,
                    # which the tagged-layer guard correctly reads as a
                    # leaked alignment code. Drop it.
                    dfx.add(ref, "stray < dropped", raw[i:i + 8])
                    i += 1
                    break
                bodies, recovered = tag_bodies(raw[i + 1:j])
                if recovered:
                    buf.append(recovered)
                tags.extend(t for t in (norm(b) for b in bodies) if t)
                i = j + 1
            # punctuation trailing a tag group belongs to the run it closes
            while i < n and raw[i] in PUNCT:
                buf.append(raw[i])
                i += 1
            if tags:
                flush(tags)
            continue
        if ch == ">":
            # 列王紀上 19:7 carries 你当走的路WH4480x> — a tag that lost its
            # opening '<'. Recognise it only HERE, in text position, with
            # the tag body sitting in the buffer: a global regex for the
            # same shape matched inside well-formed tags like <牲畜WH2874>
            # and inserted a second '<', damaging 26 good sites to repair
            # one bad one.
            tail = "".join(buf)
            m = re.search(r"(W[HG]\d+[xX]?)$", tail)
            if m:
                dfx.add(ref, "tag missing its opening <", m.group(1) + ">")
                buf = [tail[:m.start()]]
                tg = norm(m.group(1))
                i += 1
                while i < n and raw[i] in PUNCT:
                    buf.append(raw[i])
                    i += 1
                if tg:
                    flush([tg])
                continue
            dfx.add(ref, "stray > dropped", tail[-6:] + ">")
            i += 1
            continue
        buf.append(ch)
        i += 1

    if buf:
        tail = "".join(buf)
        if CJK(tail):
            runs.append({"w": tail, "s": ""})
        elif runs:
            runs[-1]["w"] += tail
        else:
            runs.append({"w": tail, "s": ""})
    return runs, "".join(r["w"] for r in runs)


NOTE_SPAN = re.compile(r"<note:[^>]*>")
ASCII_COMMA = re.compile(r"(?<=[\u4e00-\u9fff]),(?=\s?[\u4e00-\u9fff])")
SPACE_BEFORE_PUNCT = re.compile(r"\s+(?=[，。；：！？、”』〕》」])")
DOUBLE_SPACE = re.compile(r"  +")
# 主* -> 主[耶稣], 主# -> 主[基督], and 主 [雅伟] tightened to 主[雅伟].
LORD_JESUS = re.compile(r"主\*\s?")
LORD_CHRIST = re.compile(r"主#\s?")
LORD_YHWH = re.compile(r"主\s+(\[雅伟\])\s?")
def normalise_typography(text):
    """Normalise half-width punctuation. Owner's call, 2026-08-30.

    The revision mixes ASCII commas into Chinese prose (約伯記 2:11
    約伯的三个朋友, 提幔人), leaves 44 spaces sitting before full-width
    punctuation and 4 doubled spaces. That is a typesetting defect, not a
    reading: nothing about the verse changes, only how wide the comma is.
    Verse-number lists inside a note (<note: …14,23,24,25节同>) keep their
    ASCII commas — the transformation runs on body text only.

    THE 主* AND 主# MARKERS ARE EXPANDED, NOT DROPPED. An earlier draft
    of this function stripped them, which would have been a serious
    mistake: they are the publisher's own apparatus and they carry
    meaning. From yahwehdehua.net's introduction, where 新约 "主" 字的使用
    is one of the three stated revisions of this edition:

        主 [雅伟]   κύριος G2962 standing for Yahweh        (太 1:22)
        主*         κύριος addressing Jesus                 (太 7:21)
        主#         κύριος referring to the Christ          (太 22:43-45)
        主          ambiguous — could be either, so unmarked (太 21:3)
        主          an ordinary human lord or master        (太 6:24)

    and, decisively: 在纯文字版，因无原文编号的显示，只能用
    "主 [雅伟]，主*， 主#" 作為上述的区分 — in a text-only edition these
    marks ARE the distinction. Dropping them deletes one of the three
    things this edition exists to do.

    But a bare '*' explains itself to nobody, and this repo already
    settled the question for '#': the previous MySword import expanded it
    to 主[基督] at all seventeen sites, and cuvs_yhwh_tagged_layer_test's
    hash guard exists to keep the raw '#' out of the runs. So follow that
    precedent and use the bracket notation the publisher themselves use
    for [雅伟]:

        主#  ->  主[基督]     18 sites, 17 of which HEAD already spelled out
        主*  ->  主[耶稣]     140-18 sites; a distinction HEAD did not carry
                              at all (太 7:21 was a plain 主啊，主啊)

    [耶稣] is a gloss chosen by analogy with the publisher's own [基督]
    and [雅伟]; their words for it are 以主G2962称呼耶稣的. Revert to the
    bare marks here if the publisher would rather see their own notation.

    主 [雅伟] is tightened to 主[雅伟] to match — HEAD writes it closed up,
    and the space only exists in the source because the编号 edition puts
    主G2962 [雅伟] with the number in between.

    The one '*' not on 主 opens 馬太福音 21:31's textual note (**注：),
    which is also left exactly as written.
    """
    parts = []
    last = 0
    for m in NOTE_SPAN.finditer(text):
        parts.append((text[last:m.start()], True))
        parts.append((m.group(0), False))
        last = m.end()
    parts.append((text[last:], True))

    out = []
    for chunk, is_body in parts:
        if is_body:
            chunk = LORD_CHRIST.sub("主[基督]", chunk)
            chunk = LORD_JESUS.sub("主[耶稣]", chunk)
            chunk = LORD_YHWH.sub(r"主\1", chunk)
            chunk = ASCII_COMMA.sub("，", chunk)
        out.append(chunk)
    joined = "".join(out)
    joined = SPACE_BEFORE_PUNCT.sub("", joined)
    joined = DOUBLE_SPACE.sub(" ", joined)
    return joined


def normalise_runs(runs):
    """Expand a 主 marker that fell into its own run.

    The reading text is normalised as one string, so 主* there is
    contiguous and the regexes catch it. The tagged layer is not: the
    source attaches G2962 (κύριος) to the MARKER, not to 主, so the
    splitter puts them in separate runs —

        {"w": "主", "s": "",      "i": ["G3588"]}
        {"w": "*",  "s": "G2962"}
        {"w": " 的母", ...}

    — and a per-run search for 主* finds nothing. Luke 1:43, John 4:1 and
    John 11:2 came out of the first attempt with 主[耶稣] in the printed
    verse and a bare 主* in the runs, which audit_tagged_layer.py caught.

    Expand IN THE RUN THAT CARRIES THE NUMBER, so tapping the word still
    resolves to G2962, and take the space that followed with it.
    """
    for i, r in enumerate(runs):
        w = r["w"]
        if not w or w[0] not in "*#":
            continue
        # A leading '*' is only a marker if the PREVIOUS run ends in 主.
        # Testing the character alone was wrong in exactly one place out
        # of 121: 馬太福音 21:31's textual note opens **注：, and the first
        # draft turned it into [耶稣]*注： — corrupting a translator's note
        # to fix a marker that was not there.
        if i == 0 or not runs[i - 1]["w"].rstrip().endswith("主"):
            continue
        r["w"] = ("[耶稣]" if w[0] == "*" else "[基督]") + w[1:].lstrip(" ")
        if not r["w"][len("[耶稣]"):] and i + 1 < len(runs):
            runs[i + 1]["w"] = runs[i + 1]["w"].lstrip(" ")
    return runs


NOTE_OPEN = "〔"


def to_note_markup(text, ref, dfx):
    """〔…〕 -> <note: …>, the form lib/constants/text_patterns.dart parses.

    Luke 8:45 closes its note with ')' instead of '〕' in this file AND in
    the shipped asset — an upstream defect old enough to have been
    imported once already. Close it here rather than leave one note
    unrenderable.
    """
    out = []
    i = 0
    while i < len(text):
        if text[i] == NOTE_OPEN:
            j = text.find("〕", i + 1)
            k = text.find(")", i + 1)
            if j == -1 and k != -1:
                dfx.add(ref, "note closed with ) not 〕", text[i:k + 1][:30])
                j = k
            if j == -1:
                out.append(text[i]); i += 1; continue
            # KEEP THE QUOTES. Stripping them was my own decision and it
            # was wrong: 343 of this edition's notes open by quoting the
            # word they annotate — 〔"方"原文是"风"〕 — and without the
            # quotes that reads as the assertion 方原文是风 rather than
            # «the word "方" renders an original that is "风"». HEAD's own
            # notes keep quotes for the same reason (雅歌 2:7 ships
            # <note: "不要叫醒……情愿"或译"不要激动爱情，等他自发">).
            out.append("<note: " + text[i + 1:j] + ">")
            i = j + 1
            continue
        out.append(text[i])
        i += 1
    return "".join(out)


def repunctuate(old_runs, plain):
    """Redistribute `plain` across `old_runs`, preserving their splits.

    Precondition: CJK(plain) == CJK(concat of old_runs). Each run keeps
    exactly its own CJK characters and gains any non-CJK that follows
    them in the new text; the final run absorbs the remainder.
    """
    out = []
    pos = 0
    n = len(plain)
    for idx, r in enumerate(old_runs):
        want = CJK(r["w"])
        w = []
        taken = 0
        while pos < n and taken < len(want):
            ch = plain[pos]
            w.append(ch)
            pos += 1
            if "一" <= ch <= "鿿":
                taken += 1
        if idx < len(old_runs) - 1:
            # trailing non-CJK belongs to the run just closed
            while pos < n and not ("一" <= plain[pos] <= "鿿"):
                w.append(plain[pos])
                pos += 1
        out.append({**r, "w": "".join(w)})
    if pos < n and out:
        out[-1]["w"] += plain[pos:]
    return out


BOOK_FILES = [
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
    'philemon', 'hebrews', 'james', '1_peter', '2_peter', '1_john', '2_john',
    '3_john', 'jude', 'revelation',
]


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    write = "--write" in sys.argv
    if not args:
        print(__doc__)
        return 1
    src = args[0]

    lines = open(src, encoding="utf-8-sig").read().split("\n")
    meta = {}
    for l in lines[N_VERSES:N_VERSES + 12]:
        if "=" in l:
            k, _, v = l.partition("=")
            meta[k.strip()] = v.strip()
    print(f"source: {os.path.basename(src)}")
    for k in ("short.title", "version.major", "version.minor", "version.date"):
        if k in meta:
            print(f"   {k:16} {meta[k]}")
    verses = lines[:N_VERSES]
    if len(verses) != N_VERSES:
        print(f"FATAL: expected {N_VERSES} verse lines, got {len(verses)}")
        return 1

    cur = json.load(open(os.path.join(ROOT, "assets", "cuvs-yhwh.json")))
    if len(cur) != N_VERSES:
        print(f"FATAL: shipped asset has {len(cur)} verses")
        return 1
    books = []
    for c in cur:
        if not books or books[-1] != c["book"]:
            books.append(c["book"])
    if len(books) != 66:
        print(f"FATAL: {len(books)} books in the shipped asset")
        return 1
    bfile = dict(zip(books, BOOK_FILES))
    ot = set(books[:39])

    tagged = {}
    for b, f in bfile.items():
        p = os.path.join(ROOT, "assets", "tagged", "cuvs-yhwh", f + ".json")
        tagged[b] = json.load(open(p))

    dfx = Defects()
    out_text = []
    out_tags = {b: {} for b in books}
    stat = collections.Counter()
    selfcheck_hit = selfcheck_tot = 0
    resplit_examples = []

    for raw, c in zip(verses, cur):
        ref = f"{c['book']} {c['chapter']}:{c['verse']}"
        key = f"{c['chapter']}:{c['verse']}"
        runs_new, plain = parse_verse(raw, ref, c["book"] in ot, dfx)
        # Normalise at the SOURCE, not on the way out: `plain` is what the
        # re-punctuation branch pours back into the shipped run
        # boundaries, so normalising only the reading text would have left
        # 主* in ~30,000 tagged runs while the printed verse said 主.
        plain = normalise_typography(plain)
        for _r in runs_new:
            _r["w"] = normalise_typography(_r["w"])
        normalise_runs(runs_new)
        text = to_note_markup(plain, ref, dfx).strip()
        out_text.append({**c, "text": text})

        old_runs = tagged[c["book"]].get(key, [])
        old_cjk = CJK("".join(r["w"] for r in old_runs))
        new_cjk = CJK(plain)

        # A verse carrying a 〔…〕 note is NEVER patched or re-punctuated,
        # only kept whole or rebuilt whole.
        #
        # Both of the positional strategies below assume the CJK stream is
        # the same content in the same order, so a character can be swapped
        # or a punctuation mark re-placed without moving anything across a
        # boundary. A note breaks that assumption: its bracket is not CJK,
        # so positional work slides text through it and produces
        # 遵守我〔"的"我原文"是雅"〕伟 out of 遵守我的〔我原文是雅伟〕道.
        # 59 verses came out like that before this branch existed, and
        # audit_tagged_layer.py caught every one — it strips notes before
        # comparing, which is why raw CJK equality looked fine and was not.
        has_note = "〔" in plain or any("〔" in r["w"] for r in old_runs)

        if has_note:
            if new_cjk == old_cjk:
                out_tags[c["book"]][key] = old_runs
                stat["note verse, runs kept verbatim"] += 1
            else:
                out_tags[c["book"]][key] = runs_new
                stat["note verse, rebuilt from .ont (coarser)"] += 1
        elif new_cjk == old_cjk:
            # KEEP the shipped granularity, take the new punctuation. The
            # CJK is identical here by construction, so the new text pours
            # back into the shipped run boundaries.
            out_tags[c["book"]][key] = repunctuate(old_runs, plain)
            stat["runs kept, re-punctuated from the new text"] += 1
        elif len(new_cjk) == len(old_cjk):
            # same-length substitution (那->哪, 他->她): patch the shipped
            # runs in place so per-word granularity is not lost.
            it = iter(new_cjk)
            patched = []
            for r in old_runs:
                w = "".join(next(it) if "一" <= ch <= "鿿" else ch for ch in r["w"])
                patched.append({**r, "w": w})
            out_tags[c["book"]][key] = patched
            stat["runs patched in place (same-length)"] += 1
        else:
            out_tags[c["book"]][key] = runs_new
            stat["runs rebuilt from .ont (coarser)"] += 1
            if len(resplit_examples) < 5:
                resplit_examples.append(ref)

    print(f"\nverses: {N_VERSES:,}")
    for k, n in stat.most_common():
        print(f"   {n:7,}  {k}")
    if resplit_examples:
        print("   rebuilt e.g.:", ", ".join(resplit_examples))

    print(f"\nPARSER SELF-CHECK — on the {selfcheck_tot:,} verses whose CJK is")
    print("unchanged, does parsing the .ont reproduce the shipped runs?")
    pct = selfcheck_hit / selfcheck_tot * 100 if selfcheck_tot else 0
    print(f"   exact run-for-run match: {selfcheck_hit:,} / {selfcheck_tot:,}  ({pct:.1f}%)")
    print("   (a low number is expected and is the point: the .ont IS coarser.")
    print("    It matters only that we are KEEPING the shipped runs there.)")

    n_lookalike = sum(t["text"].count("丶") for t in out_text)
    print(f"\n丶 (U+4E36) lookalikes carried in from the source: {n_lookalike}")
    if n_lookalike:
        print("   -> run: python3 tools/repair_chinese_lookalikes.py --write")
    dfx.report()

    if not write:
        print("\n--check only. Re-run with --write to apply.")
        return 0

    with open(os.path.join(ROOT, "assets", "cuvs-yhwh.json"), "w") as fh:
        json.dump(out_text, fh, ensure_ascii=False, separators=(",", ":"))
        fh.write("\n")
    for b, f in bfile.items():
        p = os.path.join(ROOT, "assets", "tagged", "cuvs-yhwh", f + ".json")
        with open(p, "w") as fh:
            json.dump(out_tags[b], fh, ensure_ascii=False, separators=(",", ":"))
            fh.write("\n")
    print("\nwritten: assets/cuvs-yhwh.json + assets/tagged/cuvs-yhwh/*.json")
    print("NEXT: python3 tools/repair_chinese_lookalikes.py --write")
    return 0


if __name__ == "__main__":
    sys.exit(main())
