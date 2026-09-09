#!/usr/bin/env python3
"""Tests for tag_release.sh and release_web.sh, run by
test/changelog_test.dart.

Both scripts are exercised for real, in a temp directory, with the
outside world replaced by stubs on PATH — a bare `origin` repository
for the tag script, and fake `flutter` / `netlify` / `curl` binaries
for the release script. Each test was written against a defect the
2026-09-09 review found and fails on the script as it was:

  * finding 7 — tag_release.sh created the local tag before pushing, so
    a failed push left a tag behind and the NEXT run reported "already
    exists — nothing to do" with exit 0, and the GitHub Release never
    got cut.
  * finding 6 — release_web.sh took the netlify CLI's exit code as the
    release; Netlify can mark a deploy "canceled" after the CLI has
    exited 0. The script must re-fetch version.json from each site and
    refuse to call the release done until it serves the built version.

Usage:
  python3 tools/test_release_scripts.py
"""

import os
import pathlib
import shutil
import stat
import subprocess
import tempfile
import textwrap
import unittest

TOOLS = pathlib.Path(__file__).resolve().parent

GIT_ENV = {
    'GIT_AUTHOR_NAME': 't', 'GIT_AUTHOR_EMAIL': 't@t',
    'GIT_COMMITTER_NAME': 't', 'GIT_COMMITTER_EMAIL': 't@t',
}


def git(cwd: pathlib.Path, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        ['git', *args], cwd=cwd, capture_output=True, text=True, check=True,
        env={**os.environ, **GIT_ENV},
    )


def executable(path: pathlib.Path, body: str) -> pathlib.Path:
    path.write_text(textwrap.dedent(body).lstrip(), encoding='utf-8')
    path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    return path


class TagRelease(unittest.TestCase):
    """Finding 7."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        root = pathlib.Path(self._tmp.name)
        self.origin = root / 'origin.git'
        subprocess.run(['git', 'init', '-q', '--bare', str(self.origin)],
                       check=True)
        self.work = root / 'work'
        self.work.mkdir()
        git(self.work, 'init', '-q', '-b', 'main')
        (self.work / 'pubspec.yaml').write_text(
            'name: x\nversion: 1.0.0+1000000\n', encoding='utf-8')
        (self.work / 'lib' / 'constants').mkdir(parents=True)
        (self.work / 'lib' / 'constants' / 'app_version.dart').write_text(
            "const String _envAppVersion = String.fromEnvironment(\n"
            "  'APP_VERSION',\n"
            "  defaultValue: '1.0.0',\n"
            ");\n", encoding='utf-8')
        (self.work / 'tools').mkdir()
        shutil.copy(TOOLS / 'tag_release.sh', self.work / 'tools')
        git(self.work, 'add', '.')
        git(self.work, 'commit', '-q', '-m', 'release: v1.0.0')
        git(self.work, 'remote', 'add', 'origin', str(self.origin))

    def run_script(self, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            ['bash', 'tools/tag_release.sh', *args], cwd=self.work,
            capture_output=True, text=True, env={**os.environ, **GIT_ENV},
        )

    def remote_tags(self) -> str:
        return git(self.work, 'ls-remote', '--tags', 'origin').stdout

    def local_tags(self) -> str:
        return git(self.work, 'tag', '-l').stdout

    def test_a_local_tag_origin_lacks_is_pushed_not_reported_done(self):
        # The state a failed push leaves behind.
        git(self.work, 'tag', '-a', 'v1.0.0', '-m', 'v1.0.0')
        self.assertNotIn('v1.0.0', self.remote_tags())
        r = self.run_script()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn('refs/tags/v1.0.0', self.remote_tags(),
                      'the script said it was done and origin still has no tag:\n'
                      + r.stdout + r.stderr)
        self.assertNotIn('nothing to do', r.stdout)

    def test_a_failed_push_does_not_leave_a_local_tag_behind(self):
        git(self.work, 'remote', 'set-url', 'origin',
            str(pathlib.Path(self._tmp.name) / 'nowhere.git'))
        r = self.run_script()
        self.assertNotEqual(r.returncode, 0)
        self.assertNotIn('v1.0.0', self.local_tags(),
                         'a local tag survived the failed push; the next run '
                         'would report "nothing to do"')

    def test_a_tag_origin_already_has_is_left_alone(self):
        git(self.work, 'tag', '-a', 'v1.0.0', '-m', 'v1.0.0')
        git(self.work, 'push', '-q', 'origin', 'v1.0.0')
        r = self.run_script()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn('nothing to do', r.stdout)

    def test_the_happy_path_tags_and_pushes(self):
        r = self.run_script()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn('refs/tags/v1.0.0', self.remote_tags())

    def test_dry_run_pushes_nothing_even_for_a_stranded_tag(self):
        git(self.work, 'tag', '-a', 'v1.0.0', '-m', 'v1.0.0')
        r = self.run_script('--dry-run')
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertNotIn('v1.0.0', self.remote_tags())


class ReleaseWeb(unittest.TestCase):
    """Finding 6."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        root = pathlib.Path(self._tmp.name)
        self.project = root / 'project'
        (self.project / 'tools').mkdir(parents=True)
        (self.project / 'pubspec.yaml').write_text(
            'name: x\nversion: 1.0.0+1000000\n', encoding='utf-8')
        shutil.copy(TOOLS / 'release_web.sh', self.project / 'tools')
        # The generator is its own test file's business; here it only
        # has to not fail.
        executable(self.project / 'tools' / 'build_changelog.py',
                   '#!/usr/bin/env python3\nprint("changelog stub")\n')
        self.bin = root / 'bin'
        self.bin.mkdir()
        self.log = root / 'calls.log'
        executable(self.bin / 'flutter', f'''
            #!/usr/bin/env bash
            echo "flutter $*" >> "{self.log}"
        ''')
        executable(self.bin / 'netlify', f'''
            #!/usr/bin/env bash
            echo "netlify $*" >> "{self.log}"
        ''')
        # What the site "serves": whatever SERVED_VERSION says, so a
        # test can make the CLI succeed while the site stays stale —
        # the exact shape of the recorded failure.
        executable(self.bin / 'curl', f'''
            #!/usr/bin/env bash
            echo "curl $*" >> "{self.log}"
            for a in "$@"; do url="$a"; done
            case "$url" in
              *version.json) printf '{{"app_name":"x","version":"%s"}}' "$SERVED_VERSION" ;;
              *) exit 22 ;;
            esac
        ''')

    def run_script(self, served: str) -> subprocess.CompletedProcess:
        env = {
            **os.environ,
            'PATH': f'{self.bin}:{os.environ["PATH"]}',
            'NETLIFY': str(self.bin / 'netlify'),
            'FLUTTER': str(self.bin / 'flutter'),
            'SERVED_VERSION': served,
            'RELEASE_VERIFY_SLEEP': '0',
        }
        return subprocess.run(
            ['bash', 'tools/release_web.sh', '--no-bump'], cwd=self.project,
            capture_output=True, text=True, env=env,
        )

    def test_a_site_serving_the_built_version_is_a_release(self):
        r = self.run_script('1.0.0')
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn('deployed', r.stdout)
        log = self.log.read_text(encoding='utf-8')
        self.assertIn('https://seeksparks-dev.netlify.app/version.json', log)

    def test_a_site_still_serving_the_old_version_is_not(self):
        # netlify exits 0 (the stub always does); the site did not move.
        r = self.run_script('0.9.9')
        self.assertNotEqual(r.returncode, 0,
                            'the CLI exited 0 and the script called that a '
                            'release while the site serves 0.9.9:\n'
                            + r.stdout + r.stderr)
        out = r.stdout + r.stderr
        self.assertIn('dev', out)
        self.assertIn('0.9.9', out)
        self.assertNotIn('✓ v1.0.0 deployed', r.stdout)

    def test_the_generator_runs_after_the_bump_and_before_the_build(self):
        # Finding 1's other half: the order of the steps in the script.
        r = self.run_script('1.0.0')
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        gen = r.stdout.index('refreshing assets/changelog.json')
        build = r.stdout.index('building web bundle')
        self.assertLess(gen, build)
        self.assertIn('for v1.0.0', r.stdout[gen:build])


if __name__ == '__main__':
    unittest.main()
