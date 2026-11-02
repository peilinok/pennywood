"""Verify publication privacy and language safeguards in temporary repositories."""
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


class PublicationCheckTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'scripts').mkdir()
        shutil.copy2(Path(__file__).with_name('check-publication.py'), self.root / 'scripts/check-publication.py')
        self.git('init', '-b', 'main')
        self.git('config', 'user.name', 'Pennywood Test')
        self.git('config', 'user.email', 'test@users.noreply.github.com')
        (self.root / 'lib').mkdir()
        (self.root / 'lib/main.dart').write_text('void main() {}\n')
        (self.root / 'README.md').write_text('# Synthetic publication check\n\n[Source](lib/main.dart)\n')
        self.git('add', '.')

    def git(self, *args):
        return subprocess.run(['git', *args], cwd=self.root, check=True, capture_output=True)

    def check(self, *args):
        process = subprocess.run([sys.executable, 'scripts/check-publication.py', *args],
                                 cwd=self.root, capture_output=True, text=True)
        self.assertIn(process.returncode, [0, 1], process.stderr)
        return process.returncode, json.loads(process.stdout), process.stdout

    def token(self):
        # Assemble synthetic markers at runtime so source contains no complete credential-like value.
        return 'ghp_' + 'A' * 40

    def test_clean_tracked_files_pass(self):
        self.assertEqual(self.check('--staged')[0], 0)

    def test_staged_secret_cannot_hide_behind_clean_working_copy(self):
        path = self.root / 'lib/main.dart'
        path.write_text(self.token())
        self.git('add', 'lib/main.dart')
        path.write_text('void main() {}\n')
        self.assertEqual(self.check()[0], 0)
        code, report, output = self.check('--staged')
        self.assertEqual(code, 1)
        self.assertTrue(any(p['rule'] == 'github-token' for p in report['issues']))
        self.assertNotIn(self.token(), output)

    def test_database_is_blocked_even_if_added(self):
        (self.root / 'lib/family.sqlite').write_bytes(b'SQLite format 3\0')
        self.git('add', '.')
        self.assertEqual(self.check('--staged')[0], 1)

    def test_secret_removed_from_head_still_fails_history(self):
        path = self.root / 'lib/main.dart'
        path.write_text(self.token())
        self.git('add', '.')
        self.git('commit', '-m', 'Synthetic history one')
        path.write_text('void main() {}\n')
        self.git('add', '.')
        self.git('commit', '-m', 'Synthetic history two')
        self.assertEqual(self.check('--staged')[0], 0)
        code, report, _ = self.check('--history')
        self.assertEqual(code, 1)
        self.assertEqual(report['tree_count'], 2)

    def test_private_commit_email_is_blocked(self):
        self.git('config', 'user.email', 'private' + '@example.test')
        self.git('commit', '-m', 'Synthetic identity check')
        code, report, output = self.check('--history')
        self.assertEqual(code, 1)
        self.assertTrue(any(p['rule'] == 'commit-email-not-noreply' for p in report['issues']))
        self.assertNotIn('private' + '@example.test', output)

    def test_link_to_untracked_local_file_is_blocked(self):
        (self.root / 'README.md').write_text('[Local material](private.md)')
        (self.root / 'private.md').write_text('Local only')
        self.git('add', 'README.md')
        self.assertEqual(self.check('--staged')[0], 1)

    def test_symlink_is_blocked(self):
        (self.root / 'lib/link.dart').symlink_to('main.dart')
        self.git('add', '.')
        self.assertEqual(self.check('--staged')[0], 1)

    def test_chinese_documentation_is_blocked(self):
        (self.root / 'README.md').write_text('# \u4e2d\u6587\n')
        self.git('add', 'README.md')
        code, report, _ = self.check('--staged')
        self.assertEqual(code, 1)
        self.assertTrue(any(p['rule'] == 'documentation-must-be-english' for p in report['issues']))

    def test_non_ascii_path_is_blocked(self):
        (self.root / 'lib/\u4e2d\u6587.dart').write_text('void main() {}\n')
        self.git('add', '.')
        code, report, _ = self.check('--staged')
        self.assertEqual(code, 1)
        self.assertTrue(any(p['rule'] == 'public-path-must-be-ascii' for p in report['issues']))

    def test_chinese_commit_subject_is_blocked(self):
        self.git('commit', '-m', '\u4e2d\u6587')
        code, report, _ = self.check('--history')
        self.assertEqual(code, 1)
        self.assertTrue(any(p['rule'] == 'commit-metadata-must-be-english' for p in report['issues']))

    def test_chinese_commit_body_is_blocked(self):
        self.git('commit', '-m', 'English subject', '-m', '\u4e2d\u6587')
        code, report, _ = self.check('--history')
        self.assertEqual(code, 1)
        self.assertTrue(any(p['rule'] == 'commit-metadata-must-be-english' for p in report['issues']))

    def test_chinese_commit_identity_is_blocked(self):
        self.git('config', 'user.name', '\u4e2d\u6587')
        self.git('commit', '-m', 'English subject')
        code, report, _ = self.check('--history')
        self.assertEqual(code, 1)
        self.assertTrue(any(p['rule'] == 'commit-metadata-must-be-english' for p in report['issues']))


if __name__ == '__main__':
    unittest.main()
