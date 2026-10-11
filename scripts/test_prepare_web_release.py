import json
from pathlib import Path
import re
import tempfile
import unittest

from scripts.prepare_web_release import prepare, retain_previous


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

    def test_cached_pages_keep_two_previous_releases_with_bounded_storage(self):
        with tempfile.TemporaryDirectory() as directory:
            previous = None
            for version in range(5):
                root = Path(directory) / str(version)
                root.mkdir()
                self.fixture(root)
                (root / 'main.dart.js').write_text(f'game version {version}')
                prepare(root)
                if previous:
                    retain_previous(root, previous)
                entries = json.loads((root / 'startup-assets.json').read_text())
                self.assertEqual(len(entries), min(version + 1, 3))
                for pair in entries:
                    for name in pair:
                        self.assertTrue((root / name).is_file())
                previous = root

    def test_previous_manifest_cannot_copy_paths_outside_release(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'new'
            old = Path(directory) / 'old'
            root.mkdir()
            old.mkdir()
            self.fixture(root)
            prepare(root)
            (old / 'startup-assets.json').write_text(json.dumps([['../../private', 'main.dart.js']]))
            original = (root / 'startup-assets.json').read_bytes()
            with self.assertRaises(ValueError):
                retain_previous(root, old)
            self.assertEqual(original, (root / 'startup-assets.json').read_bytes())

    def test_first_fingerprinted_release_without_ledger_is_retained(self):
        with tempfile.TemporaryDirectory() as directory:
            old = Path(directory) / 'old'
            root = Path(directory) / 'new'
            old.mkdir()
            root.mkdir()
            self.fixture(old)
            prepare(old)
            (old / 'startup-assets.json').unlink()
            self.fixture(root)
            (root / 'main.dart.js').write_text('new game')
            prepare(root)
            retain_previous(root, old)
            entries = json.loads((root / 'startup-assets.json').read_text())
            self.assertEqual(len(entries), 2)
            self.assertEqual((root / entries[1][1]).read_text(), 'game version one')


if __name__ == '__main__':
    unittest.main()
