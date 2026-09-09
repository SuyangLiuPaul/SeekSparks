#!/usr/bin/env python3
"""Tests for build_changelog.py, run by test/changelog_test.dart.

Each one was written against a defect the 2026-09-09 review found in
the generator, and each fails on the generator as it was:

  * finding 1 — the build's own version was never in the asset, because
    its `release:` anchor is written after the build. `build()` did not
    even take a head version; these tests call it with one.
  * finding 2 — `tests:`, `tools:`, `state:`, `audit:` and friends were
    not in DROP and reached readers; `feat(wheel):` / `fix(#315):`
    tokens stayed on the notes that survived.
  * the per-version bound, which nothing exercised.

Fixtures are real git repositories in a temp dir, because the
generator's whole job is reading `git log`, and a test that mocked
that would prove the mock.

Usage:
  python3 tools/test_build_changelog.py
"""

import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import build_changelog as bc  # noqa: E402


class Repo:
    """A throwaway git repository of empty commits, one per subject."""

    def __init__(self, path: pathlib.Path):
        self.path = path
        self.git('init', '-q', '-b', 'main')

    def git(self, *args: str, env: dict | None = None) -> str:
        full = dict(os.environ)
        full.update({
            'GIT_AUTHOR_NAME': 't', 'GIT_AUTHOR_EMAIL': 't@t',
            'GIT_COMMITTER_NAME': 't', 'GIT_COMMITTER_EMAIL': 't@t',
        })
        if env:
            full.update(env)
        return subprocess.run(
            ['git', *args], cwd=self.path, capture_output=True, text=True,
            check=True, env=full,
        ).stdout.strip()

    def commit(self, subject: str, date: str = '2026-09-01') -> str:
        stamp = f'{date}T12:00:00'
        self.git(
            'commit', '-q', '--allow-empty', '-m', subject,
            env={'GIT_AUTHOR_DATE': stamp, 'GIT_COMMITTER_DATE': stamp},
        )
        return self.git('rev-parse', 'HEAD')


class WithRepo(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.repo = Repo(pathlib.Path(self._tmp.name))
        self.addCleanup(self._tmp.cleanup)


class HeadVersionSynthesis(WithRepo):
    """Finding 1."""

    def seed(self):
        self.repo.commit('release: v0.9.0', '2026-09-01')
        self.repo.commit('feat(a): first', '2026-09-02')
        self.repo.commit('release: v1.0.0', '2026-09-02')
        self.repo.commit('fix(url): the link opens', '2026-09-03')
        self.repo.commit('docs: notes', '2026-09-03')
        self.repo.commit('tests: more', '2026-09-03')

    def test_top_entry_is_the_version_being_built(self):
        self.seed()
        data = bc.build(10, head_version='1.0.1', head_date='2026-09-09',
                        repo=self.repo.path)
        top = data['entries'][0]
        self.assertEqual(top['version'], '1.0.1')
        self.assertEqual(top['date'], '2026-09-09')
        # Only the commits AFTER the last anchor, bookkeeping dropped,
        # token stripped.
        self.assertEqual(top['notes'], ['the link opens'])
        # The anchored history is untouched beneath it.
        self.assertEqual(data['entries'][1]['version'], '1.0.0')
        self.assertEqual(data['entries'][1]['notes'], ['first'])
        self.assertEqual(data['head'],
                         {'version': '1.0.1', 'date': '2026-09-09', 'notes': 1})

    def test_an_existing_anchor_for_the_head_version_is_folded_not_doubled(self):
        # A --no-bump re-run, or a regenerate after the release commit:
        # the anchor for 1.0.0 exists. It must appear once, spanning
        # both what the anchor spans and what came after it.
        self.seed()
        data = bc.build(10, head_version='1.0.0', head_date='2026-09-09',
                        repo=self.repo.path)
        versions = [e['version'] for e in data['entries']]
        self.assertEqual(versions.count('1.0.0'), 1)
        self.assertEqual(data['entries'][0]['version'], '1.0.0')
        self.assertEqual(data['entries'][0]['notes'],
                         ['the link opens', 'first'])

    def test_a_head_with_nothing_visible_is_recorded_but_not_listed(self):
        self.repo.commit('release: v0.9.0', '2026-09-01')
        self.repo.commit('feat: first', '2026-09-02')
        self.repo.commit('release: v1.0.0', '2026-09-02')
        self.repo.commit('docs: only', '2026-09-03')
        data = bc.build(10, head_version='1.0.1', repo=self.repo.path)
        self.assertEqual(data['entries'][0]['version'], '1.0.0')
        self.assertEqual(data['head']['version'], '1.0.1')
        self.assertEqual(data['head']['notes'], 0)

    def test_head_date_defaults_to_the_head_commit_date(self):
        self.repo.commit('release: v0.9.0', '2026-09-01')
        self.repo.commit('feat: first', '2026-09-02')
        self.repo.commit('release: v1.0.0', '2026-09-02')
        self.repo.commit('feat: second', '2026-09-07')
        data = bc.build(10, head_version='1.0.1', repo=self.repo.path)
        self.assertEqual(data['entries'][0]['date'], '2026-09-07')

    def test_the_cli_defaults_to_the_pubspec_version(self):
        # Against the real repository: without --head-version the
        # generator must read pubspec.yaml, or a hand run would ship an
        # asset one version behind again.
        out = subprocess.run(
            [sys.executable, str(HERE / 'build_changelog.py'), '--check'],
            capture_output=True, text=True, check=True,
        ).stdout
        data = json.loads(out)
        self.assertEqual(data['head']['version'], bc.pubspec_version())


class DropCoverage(unittest.TestCase):
    """Finding 2, first half: bookkeeping this repo actually writes."""

    BOOKKEEPING = [
        'release: v1.6.271 to dev + prod',
        'chore(release): v1.6.99, the phrasing pane reads any version',
        'chore: v1.6.234',
        'docs: check 55 — the official 和合本繁體',
        'PROJECT_STATE: the 1.6.271 row',
        'tests: the 隻 ledger moves to 52, and says why',
        'test(wheel): arc labels',
        'audit: what each screen is for',
        'audit_p0: the release path',
        'audit(product): what each screen is for (#281)',
        'tools: the release script this repo already had the workflows for',
        'tools+docs: the changelog generator and its note',
        'state: v1.6.256 — prod, the update path, and the 27-page walk',
        'fix CI: the analyzer floor',
        'fix(CI): the analyzer floor',
        'fix(ci): the analyzer floor',
        'fix(lint): an unused import',
        'fix(release): strip the +build suffix',
        'ci: cache the pub dir',
        'build: gradle 8',
        'style(strip): trailing commas',
        'refactor(wheel): split the painter',
        'Merge branch \'main\' into wheel',
        'Merge pull request #12 from x/y',
    ]

    CHANGES = [
        'search: 耶和华 finds the verses that hold it',
        'feat(wheel): the Bible on the wheel',
        'fix(#315): the settings page grows with the slider',
        'perf(search): the index is built once',
        'versions: plain BSB comes off the interface',
        'Revert "text: two classifiers the Traditional conversion missed"',
        'A retired edition is announced once, not on every launch',
        'testimony: a word the reader can look up',  # not `test:`
        'toolsmith: not `tools:` either',
        'statement: not `state:` either',
        'fixture: not `fix CI:` either',
    ]

    def test_every_bookkeeping_form_is_dropped(self):
        for s in self.BOOKKEEPING:
            self.assertTrue(bc.DROP.match(s), f'not dropped: {s!r}')

    def test_no_change_is_dropped(self):
        for s in self.CHANGES:
            self.assertFalse(bc.DROP.match(s), f'wrongly dropped: {s!r}')


class PrefixStripping(WithRepo):
    """Finding 2, second half: developer tokens off the notes that stay."""

    def test_conventional_tokens_go_and_area_labels_stay(self):
        cases = {
            'feat(wheel): the Bible on the wheel': 'the Bible on the wheel',
            'fix(url): the link opens': 'the link opens',
            'perf(search): the index is built once': 'the index is built once',
            'fix(#315): the page grows': 'the page grows',
            'feat!: a breaking one': 'a breaking one',
            'feat: plain': 'plain',
            'Fix: capitalised': 'capitalised',
            'revert(nasb): put it back': 'put it back',
            '#317: the ruler citation': 'the ruler citation',
            'search: 耶和华 finds the verses': 'search: 耶和华 finds the verses',
            'versions: plain BSB comes off': 'versions: plain BSB comes off',
            'cuvs-yhwh-tr: 白髮 was 白發': 'cuvs-yhwh-tr: 白髮 was 白發',
            'Revert "text: two classifiers"': 'Revert "text: two classifiers"',
            'features are not a token: keep': 'features are not a token: keep',
        }
        for subject, want in cases.items():
            self.assertEqual(bc.strip_prefix(subject), want, subject)

    def test_notes_come_out_stripped_and_deduplicated(self):
        base = self.repo.commit('release: v1.0.0')
        self.repo.commit('feat(wheel): the same change')
        self.repo.commit('fix(wheel): the same change')  # a cherry-pick
        self.repo.commit('perf(search): faster')
        head = self.repo.commit('tests: not a change')
        self.assertEqual(
            bc.notes_between(base, head, repo=self.repo.path),
            ['faster', 'the same change'],
        )

    def test_a_subject_that_is_only_a_token_is_dropped(self):
        base = self.repo.commit('release: v1.0.0')
        head = self.repo.commit('fix:')
        self.assertEqual(bc.notes_between(base, head, repo=self.repo.path), [])


class Bound(WithRepo):
    def test_no_version_lists_more_than_the_cap(self):
        self.repo.commit('release: v0.9.0')
        self.repo.commit('feat: seed')
        self.repo.commit('release: v1.0.0')
        n = bc.MAX_NOTES_PER_VERSION + 5
        for i in range(n):
            self.repo.commit(f'feat: change {i}')
        data = bc.build(10, head_version='1.0.1', repo=self.repo.path)
        top = data['entries'][0]
        self.assertEqual(len(top['notes']), bc.MAX_NOTES_PER_VERSION)
        # The NEWEST ones survive the cut, not the oldest.
        self.assertEqual(top['notes'][0], f'change {n - 1}')
        # The count under `head` is the true number, before the cap:
        # that is what says "a lot happened", which the cap hides.
        self.assertEqual(data['head']['notes'], n)

    def test_the_anchored_path_is_capped_too(self):
        self.repo.commit('release: v0.9.0')
        for i in range(bc.MAX_NOTES_PER_VERSION + 3):
            self.repo.commit(f'feat: change {i}')
        self.repo.commit('release: v1.0.0')
        data = bc.build(10, repo=self.repo.path)
        self.assertEqual(data['entries'][0]['version'], '1.0.0')
        self.assertEqual(len(data['entries'][0]['notes']),
                         bc.MAX_NOTES_PER_VERSION)


class PubspecVersion(unittest.TestCase):
    def test_reads_x_y_z_without_the_build_suffix(self):
        v = bc.pubspec_version()
        self.assertRegex(v, r'^\d+\.\d+\.\d+$')
        text = (bc.PROJECT / 'pubspec.yaml').read_text(encoding='utf-8')
        self.assertIsNotNone(re.search(rf'^version:\s*{re.escape(v)}\+', text,
                                       re.MULTILINE))


if __name__ == '__main__':
    unittest.main()
