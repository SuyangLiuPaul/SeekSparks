#!/usr/bin/env python3
"""Turn the git history into the changelog the app ships.

WHY THIS EXISTS. On 2026-09-09 the owner asked for release notes in
the app — 「也要有历史的release note但是不要全部的」. The finding was
that there were none to show: all 270 GitHub Releases carry the same
body, `Automated Linux x64 build. Download the tarball...`, written by
the Linux job of `release-android.yml`. That is build instructions for
one platform, not a note, and it is identical on every release.

The notes were in the commit subjects the whole time. This app writes
them as sentences — "A retired edition is announced once, not on every
launch", "versions: plain BSB comes off the interface, and the English
default with it" — which is already a changelog, so nothing here
rewrites them. It selects.

WHAT IS DROPPED, and why each one is bookkeeping rather than a change
the reader can see:

  * `release: vX.Y.Z to dev + prod` — the mechanics of shipping. There
    is one per version, so leaving them in would make the changelog
    half release lines.
  * `PROJECT_STATE: …` and `docs: …` — this repository's own record.
    Real work, none of it visible in the app.
  * `chore:` / `ci:` / `test:` — the same, one level down.

WHY THE SPINE IS THE `release:` COMMITS AND NOT THE TAGS. Tags were
the obvious choice and are wrong here: `tag_release.sh` only started
pushing them on 2026-09-08, so the repository holds **12** tags for
270 versions. Built on tags, the oldest entry swallowed the entire
history back to the initial commit — 719 notes in one row, 51 KB.
Every released version does have a `release: vX.Y.Z …` commit (older
ones read `chore(release): vX.Y.Z`), all the way back, so those are
the anchors.

WHY IT IS A BUNDLED ASSET rather than fetched. The GitHub bodies for
every EXISTING release are the boilerplate above, so an app that read
them would show an empty history until enough new releases accumulated
— the reader would ask for the changelog and be told there isn't one,
which is worse than not offering it. Generating from git gives a full
history on the first build, and gives it offline, which matters for a
Bible app used on a tablet with no SIM.

HOW MANY, and why the first two answers were both wrong. The owner's
constraint was 「不要全部的而是足够的不然太多」. The first guess was 20
versions; measured, this app ships **29 versions in three days**, so 20
is a day and a half and reads as a broken page. The second guess was 30
"because that is three to six weeks" — measured, it is three days.

The measurement that settled it: **120 versions is 115 entries, 250
notes, 25 KB, and one month** (2026-08-11 → 2026-09-09) spread over 17
days. Size was never the constraint — 25 KB is nothing to bundle. The
constraint is the reader's scroll, and the thing that makes a changelog
here unreadable is not the notes, it is **115 version numbers**. So the
notes are all kept and the page groups them BY DAY: seventeen headings
instead of a hundred and fifteen rows. Throwing away history would have
been solving the wrong half.

Versions whose every commit was filtered out are dropped rather than
shown empty. Everything older than the window stays on GitHub, which
the page links to.

THE BUILD'S OWN VERSION (review finding 1, 2026-09-09). Anchoring on
`release:` commits has a hole at the top: that commit is written AFTER
the build it names has been deployed, so the asset baked into v1.6.272
could only ever reach v1.6.271. The page's 「你的版本」 badge compares
against the running version and therefore never rendered, and "what's
new" was always one version behind — on a page whose whole purpose is
the top entry. So the top entry is now SYNTHESISED: `--head-version`
(the just-bumped pubspec version; read from pubspec.yaml when absent)
names it, and its notes are every commit after the most recent
`release:` anchor up to HEAD — exactly the commits the release commit
will span once it exists. If the anchor for that version is already
in the history (a `--no-bump` re-run, or a regenerate after the
commit) it is folded in rather than listed twice. The asset records
which version it was built for under `head`, so a test can prove the
generator ran after the bump and not before.

Usage:
  tools/build_changelog.py            # write assets/changelog.json
  tools/build_changelog.py --check    # print, write nothing
  tools/build_changelog.py --head-version 1.6.272 --head-date 2026-09-09
"""

import argparse
import json
import pathlib
import re
import subprocess
import sys

PROJECT = pathlib.Path(__file__).resolve().parent.parent
OUT = PROJECT / 'assets' / 'changelog.json'

# How many versions-with-something-to-say to keep. Measured at this
# repo's rate: about one month, 250 notes, 25 KB. See "HOW MANY" above
# for the two smaller numbers that were tried and why they were wrong.
DEFAULT_MAX_ENTRIES = 120

# A released version, in either convention this repo has used.
ANCHOR = re.compile(
    r'^(?:release|chore\(release\)):\s*v?(\d+\.\d+\.\d+)\b',
    re.IGNORECASE,
)

# `type` or `type(scope)` — the scoped form is why `chore(release):`
# survived the first draft of this filter and put twelve release lines
# into the notes.
#
# 2026-09-09 (review finding 2): widened to the bookkeeping subjects
# this repository ACTUALLY writes, which the conventional-commit list
# above never covered — `tests:`, `audit:` / `audit_p0:`, `tools:`,
# `tools+docs:`, `state:` (the PROJECT_STATE row under another name),
# `fix CI:`, `fix(ci):`, `fix(lint):` and `fix(release):`. Each is
# real work and none of it is visible in the app; letting them through
# put "tools: the release script this repo already had the workflows
# for" in front of a reader.
DROP = re.compile(
    r'^(?:'
    r'(?:release|docs?|chore|ci|tests?|build|style|refactor'
    r'|audit(?:_p0)?|tools(?:\+docs)?|state)'
    r'(?:\([^)]*\))?:'
    r'|fix\s*(?:\(\s*(?:ci|lint|release)\s*\)|CI)\s*:'
    r'|PROJECT_STATE\b'
    r'|Merge (?:branch|pull request)\b'
    r')',
    re.IGNORECASE,
)

# The conventional-commit token on a subject that IS a change:
# `feat(wheel): the Bible on the wheel` → `the Bible on the wheel`.
# `feat`, `fix(#315)`, `perf(...)` are developer vocabulary — the reader
# was never told what a scope is, and an issue number points at a
# tracker they cannot open. Only the tokens go; free-form area labels
# this repo also uses (`search:`, `versions:`, `cuvs-yhwh:`) are the
# note's own words and stay.
PREFIX = re.compile(
    r'^(?:'
    r'(?:feat|fix|perf|refactor|revert|style|tests?|build|ci|chore|docs?)'
    r'(?:\([^)]*\))?!?'
    r'|#\d+'  # `#317: ...` — a tracker number on its own
    r'):\s*',
    re.IGNORECASE,
)


def strip_prefix(subject: str) -> str:
    return PREFIX.sub('', subject, count=1).strip()


def pubspec_version() -> str:
    """The `version:` in pubspec.yaml, without the `+build` suffix —
    that number is Android's versionCode, never a thing to show."""
    text = (PROJECT / 'pubspec.yaml').read_text(encoding='utf-8')
    m = re.search(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)', text, re.MULTILINE)
    if not m:
        raise SystemExit('pubspec.yaml has no version: line')
    return m.group(1)

# No single version may fill the whole page. Nothing in this repo's
# history comes near it; it is here so that a first release, or a
# long-lived branch landing at once, degrades into "a lot happened"
# rather than into a wall.
MAX_NOTES_PER_VERSION = 12


def git(*args: str, repo: pathlib.Path = PROJECT) -> str:
    return subprocess.run(
        ['git', *args], cwd=repo, capture_output=True, text=True, check=True
    ).stdout.strip()


def released_versions(
    limit: int, repo: pathlib.Path = PROJECT,
) -> list[tuple[str, str, str]]:
    """`(version, sha, date)` for the newest [limit] release commits.

    Walked newest-first and stopped at [limit], so the initial commit
    is never reached and no entry can absorb the whole history — the
    exact failure the tag-based first draft had.
    """
    out = git(
        'log', '--format=%H\x1f%cs\x1f%s', '--no-merges', '--all',
        repo=repo,
    ).splitlines()
    found: list[tuple[str, str, str]] = []
    seen: set[str] = set()
    for line in out:
        sha, date, subject = line.split('\x1f', 2)
        m = ANCHOR.match(subject)
        if not m:
            continue
        version = m.group(1)
        # A version re-cut (dev, then dev + prod) has two release
        # commits. The FIRST one seen walking backwards is the newest,
        # which is the one whose date the reader should be shown.
        if version in seen:
            continue
        seen.add(version)
        found.append((version, sha, date))
        if len(found) > limit:
            break
    return found


def notes_between(
    older_sha: str | None, newer_sha: str, repo: pathlib.Path = PROJECT,
) -> list[str]:
    span = f'{older_sha}..{newer_sha}' if older_sha else newer_sha
    subjects = git(
        'log', '--no-merges', '--format=%s', span, repo=repo,
    ).splitlines()
    kept: list[str] = []
    for s in subjects:
        s = s.strip()
        if not s or DROP.match(s):
            continue
        s = strip_prefix(s)
        if not s:
            continue
        if s not in kept:  # a cherry-pick should not read as two changes
            kept.append(s)
    return kept


def build(
    max_entries: int,
    head_version: str | None = None,
    head_date: str | None = None,
    repo: pathlib.Path = PROJECT,
) -> dict:
    # One extra, so the oldest kept entry still has a predecessor to
    # measure against rather than reaching back to the initial commit.
    versions = released_versions(max_entries, repo=repo)
    entries = []
    head: dict | None = None
    if head_version:
        # Finding 1: the build's own version, whose `release:` commit
        # does not exist yet. Its span is everything after the newest
        # anchor — and if that anchor already names this very version,
        # the span starts at the one before it, so a re-run after the
        # release commit lists the version once, not once as HEAD and
        # once as an anchor.
        if versions and versions[0][0] == head_version:
            versions = versions[1:]
        base = versions[0][1] if versions else None
        notes = notes_between(base, 'HEAD', repo=repo)
        head = {
            'version': head_version,
            'date': head_date or git('log', '-1', '--format=%cs', 'HEAD',
                                     repo=repo),
            'notes': len(notes),
        }
        if notes:
            entries.append({
                'version': head_version,
                'date': head['date'],
                'notes': notes[:MAX_NOTES_PER_VERSION],
            })
        else:
            # A data-only or tooling-only release. Recorded under
            # `head` so the asset still says which build it was made
            # for, but not listed: an empty row is a version number
            # pretending to be news, same as anywhere else on the page.
            print(f'note: v{head_version} has no reader-visible change '
                  'since the last release; not listed', file=sys.stderr)
    for i, (version, sha, date) in enumerate(versions):
        if len(entries) >= max_entries:
            break
        older = versions[i + 1][1] if i + 1 < len(versions) else None
        if older is None:
            # No predecessor in the window: rather than walk to the
            # beginning of the repository, stop. The page links to
            # GitHub for everything older, which is where it is.
            break
        notes = notes_between(older, sha, repo=repo)
        if not notes:
            # A version whose every commit was bookkeeping. Dropping it
            # rather than showing an empty row is the difference between
            # a changelog and a list of version numbers.
            continue
        entries.append({
            'version': version,
            'date': date,
            'notes': notes[:MAX_NOTES_PER_VERSION],
        })
    data: dict = {'entries': entries}
    if head is not None:
        data['head'] = head
    return data


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--max-entries', type=int, default=DEFAULT_MAX_ENTRIES)
    ap.add_argument(
        '--head-version', default=None,
        help='the version being built (default: pubspec.yaml); its '
             'entry is synthesised from the commits after the last '
             'release: anchor, because its own anchor does not exist yet',
    )
    ap.add_argument(
        '--head-date', default=None,
        help='YYYY-MM-DD for the head entry (default: the HEAD commit date)',
    )
    args = ap.parse_args()

    data = build(
        args.max_entries,
        head_version=args.head_version or pubspec_version(),
        head_date=args.head_date,
    )
    if not data['entries']:
        print('refusing to write an empty changelog', file=sys.stderr)
        return 1

    text = json.dumps(data, ensure_ascii=False, separators=(',', ':'))
    if args.check:
        print(json.dumps(data, ensure_ascii=False, indent=2))
        print(
            f'\n{len(data["entries"])} versions, '
            f'{sum(len(e["notes"]) for e in data["entries"])} notes, '
            f'{len(text.encode())} bytes',
            file=sys.stderr,
        )
        return 0

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text, encoding='utf-8')
    print(f'{OUT.relative_to(PROJECT)}: {len(data["entries"])} versions, '
          f'{len(text.encode())} bytes')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
