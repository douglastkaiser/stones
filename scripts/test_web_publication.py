import json
from pathlib import Path
import tempfile
import unittest

from prepare_web_release import prepare
from publish_web import publish
from web_artifact import create, verify


class PublicationTests(unittest.TestCase):
    def fixture(self, root, content='one'):
        root.mkdir(parents=True, exist_ok=True)
        (root / 'index.html').write_text('<script src="flutter_bootstrap.js" async></script>')
        (root / 'privacy.html').write_text('privacy')
        (root / '.last_build_id').write_text('flutter-build-id')
        (root / 'flutter_bootstrap.js').write_text(
            '_flutter.buildConfig = ' +
            json.dumps({'builds': [{'compileTarget': 'dart2js', 'mainJsPath': 'main.dart.js'}]}) +
            ';\n_flutter.loader.load();')
        (root / 'main.dart.js').write_text(content)
        prepare(root)

    def test_artifact_rejects_wrong_commit_changed_extra_and_missing_content(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            create(root, 'a' * 40)
            verify(root, 'a' * 40)
            manifest = json.loads((root / 'release-manifest.json').read_text())
            self.assertIn('.last_build_id', manifest['files'])
            with self.assertRaises(ValueError):
                verify(root, 'b' * 40)
            (root / 'extra.js').write_text('unexpected')
            with self.assertRaises(ValueError):
                verify(root, 'a' * 40)
            (root / 'extra.js').unlink()
            (root / 'privacy.html').write_text('changed')
            with self.assertRaises(ValueError):
                verify(root, 'a' * 40)
            (root / 'privacy.html').unlink()
            with self.assertRaises(ValueError):
                verify(root, 'a' * 40)

    def test_main_and_preview_publications_preserve_each_others_content(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target, main, preview = (root / name for name in ['published', 'main', 'preview'])
            self.fixture(target, 'old')
            self.fixture(main, 'new')
            self.fixture(preview, 'preview')
            (target / 'CNAME').write_text('example.test')
            publish(preview, target, '42')
            publish(main, target)
            self.assertEqual((target / 'main.dart.js').read_text(), 'new')
            self.assertEqual((target / 'pr/42/main.dart.js').read_text(), 'preview')
            self.assertEqual((target / 'CNAME').read_text(), 'example.test')
            self.assertEqual(len(json.loads((target / 'startup-assets.json').read_text())), 2)
            publish(None, target, '42')
            self.assertFalse((target / 'pr/42').exists())
            self.assertTrue((target / 'index.html').exists())

    def test_cleanup_cannot_escape_or_remove_main(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            self.fixture(target)
            for preview in [None, '..', '../main', '42/../..', '/tmp', '0']:
                with self.assertRaises(ValueError):
                    publish(None, target, preview)
            self.assertTrue((target / 'index.html').exists())

    def test_reserved_source_paths_cannot_overwrite_publishing_metadata(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, target = root / 'build', root / 'published'
            self.fixture(source)
            self.fixture(target, 'keep')
            for name in ['.git', 'pr', 'CNAME', '.nojekyll']:
                (source / name).write_text('unexpected')
                with self.assertRaises(ValueError):
                    publish(source, target)
                self.assertEqual((target / 'main.dart.js').read_text(), 'keep')
                (source / name).unlink()


if __name__ == '__main__':
    unittest.main()
