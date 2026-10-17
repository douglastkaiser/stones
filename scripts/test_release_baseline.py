import hashlib
import json
import unittest
from unittest.mock import patch

from scripts.release_baseline import fingerprint_name, inspect_live


class Response:
    def __init__(self, data):
        self.data = data
        self.url = 'https://www.douglastkaiser.com/stones/'

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def read(self, _limit):
        return self.data


class BaselineTests(unittest.TestCase):
    def fixture(self, *, corrupt_main=False, wrong_bootstrap=False):
        main = b'compiled game'
        main_name = 'main.' + hashlib.sha256(main).hexdigest()[:20] + '.dart.js'
        config = {'builds': [{'mainJsPath': main_name}]}
        bootstrap = ('_flutter.buildConfig = ' + json.dumps(config) + ';').encode()
        name = 'flutter_bootstrap.' + hashlib.sha256(bootstrap).hexdigest()[:20] + '.js'
        return [Response(('<meta name="stones-preview-source" content="' + 'abcdef1' + '0' * 33 + '">'
                          + '<script src="' + ('old.js' if wrong_bootstrap else name)
                          + '"></script>').encode()),
                Response(json.dumps([[name, main_name]]).encode()), Response(bootstrap),
                Response(b'other build' if corrupt_main else main)]

    def test_matching_content(self):
        with patch('scripts.release_baseline.urlopen', side_effect=self.fixture()):
            self.assertEqual(inspect_live('https://www.douglastkaiser.com/stones/')['integrity'], 'passed')

    def test_rejects_mixed_deployment(self):
        for options in [{'corrupt_main': True}, {'wrong_bootstrap': True}]:
            with self.subTest(options=options):
                with patch('scripts.release_baseline.urlopen', side_effect=self.fixture(**options)):
                    with self.assertRaises(ValueError):
                        inspect_live('https://www.douglastkaiser.com/stones/')

    def test_fresh_check_busts_only_mutable_metadata(self):
        with patch('scripts.release_baseline.urlopen', side_effect=self.fixture()) as fetch:
            inspect_live('https://www.douglastkaiser.com/stones/', fresh=True)
            urls = [call.args[0].full_url for call in fetch.call_args_list]
            self.assertIn('?baseline=', urls[0])
            self.assertIn('?baseline=', urls[1])
            self.assertTrue(all('?' not in url for url in urls[2:]))

    def test_requested_source_is_checked(self):
        with patch('scripts.release_baseline.urlopen', side_effect=self.fixture()):
            self.assertTrue(inspect_live('https://www.douglastkaiser.com/stones/',
                                         expected_source='abcdef1')['previewSource'].startswith('abcdef1'))

    def test_coherent_but_old_preview_is_rejected(self):
        with patch('scripts.release_baseline.urlopen', side_effect=self.fixture()):
            with self.assertRaisesRegex(ValueError, 'not the requested source'):
                inspect_live('https://www.douglastkaiser.com/stones/', expected_source='1234567')

    def test_rejects_unsafe_asset_paths(self):
        for value in ['../main.123.dart.js', 'https://elsewhere/main.js', 'main.dart.js']:
            with self.assertRaises(ValueError):
                fingerprint_name(value, 'main', '.dart.js')

    def test_limits_to_public_release_origins(self):
        with patch('scripts.release_baseline.urlopen') as fetch:
            with self.assertRaises(ValueError):
                inspect_live('https://example.com/')
            fetch.assert_not_called()


if __name__ == '__main__':
    unittest.main()
