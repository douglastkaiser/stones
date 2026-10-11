import json
from pathlib import Path
import re
import tempfile
import unittest

from scripts.prepare_web_release import prepare


class WebReleaseTests(unittest.TestCase):
    def fixture(self, root, target='dart2js'):
        (root / 'index.html').write_text('<script src="flutter_bootstrap.js" async></script>')
        config = {'builds': [{'compileTarget': target, 'mainJsPath': 'main.dart.js'}, {}]}
        (root / 'flutter_bootstrap.js').write_text('_flutter.buildConfig = ' + json.dumps(config) + ';\n_flutter.loader.load();')
        (root / 'main.dart.js').write_text('game version one')

    def test_page_and_loader_reference_existing_identical_assets(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            prepare(root)
            name = re.search('src="([^"]+)"', (root / 'index.html').read_text())[1]
            config = json.loads(re.search(r'buildConfig = (\{[^\n]+\});', (root / name).read_text())[1])
            main = root / config['builds'][0]['mainJsPath']
            self.assertEqual(main.read_bytes(), (root / 'main.dart.js').read_bytes())
            self.assertIn('_flutter.loader.load();', (root / name).read_text())
            self.assertTrue((root / 'flutter_bootstrap.js').exists())

    def test_new_game_cannot_share_old_startup_urls(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            prepare(root)
            old = (root / 'index.html').read_text()
            self.fixture(root)
            (root / 'main.dart.js').write_text('game version two')
            prepare(root)
            self.assertNotEqual(old, (root / 'index.html').read_text())

    def test_unknown_layout_fails_without_modifying_page(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root, 'dart2wasm')
            original = (root / 'index.html').read_bytes()
            with self.assertRaises(ValueError):
                prepare(root)
            self.assertEqual(original, (root / 'index.html').read_bytes())
            self.assertEqual(len(list(root.iterdir())), 3)


if __name__ == '__main__':
    unittest.main()
