"""Exercise architecture safeguards using synthetic tracked repositories."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


class RepositoryPolicyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'scripts').mkdir()
        shutil.copy2(Path(__file__).with_name('check-repository.py'), self.root / 'scripts/check-repository.py')
        subprocess.run(['git', 'init', '-q'], cwd=self.root, check=True)

    def check(self, name, content):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        subprocess.run(['git', 'add', '.'], cwd=self.root, check=True)
        result = subprocess.run([sys.executable, 'scripts/check-repository.py'],
                                cwd=self.root, capture_output=True, text=True)
        return result.returncode, json.loads(result.stdout)

    def test_pure_domain_imports_pass(self):
        self.assertEqual(self.check('lib/domain/rules.dart',
                                    "import 'dart:math';\nimport 'model.dart';\n")[0], 0)

    def test_domain_cannot_import_flutter_or_storage(self):
        for uri in ['package:flutter/widgets.dart', '../data/database.dart',
                    'package:pennywood/data/service.dart', 'dart:io']:
            with self.subTest(uri=uri):
                code, report = self.check('lib/domain/rules.dart', f"import '{uri}';\n")
                self.assertEqual(code, 1)
                self.assertEqual(report['issues'][0]['rule'], 'domain-dependency-boundary')

    def test_domain_exports_and_multiline_directives_are_checked(self):
        for directive in ["export '../app/controller.dart';", "import\n'dart:io';",
                          "import 'model.dart' if (dart.library.io) 'dart:io';"]:
            with self.subTest(directive=directive):
                self.assertEqual(self.check('lib/domain/rules.dart', directive)[0], 1)

    def test_unsupported_generated_target_is_rejected(self):
        for target in ['android', 'web', 'macos', 'windows', 'linux']:
            with self.subTest(target=target):
                code, report = self.check(f'{target}/synthetic.txt', 'synthetic\n')
                self.assertEqual(code, 1)
                self.assertTrue(any(p['rule'] == 'unsupported-platform-target' for p in report['issues']))

    def test_ui_may_import_flutter(self):
        self.assertEqual(self.check('lib/features/example.dart', "import 'package:flutter/widgets.dart';\n")[0], 0)


if __name__ == '__main__':
    unittest.main()
