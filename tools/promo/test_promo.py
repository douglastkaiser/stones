"""Release-state regressions: rendered copy, QR destination and ZIP instructions."""
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

from PIL import Image
import zxingcpp

import generate


class AvailabilityTest(unittest.TestCase):
    def test_both_release_states(self):
        source = json.loads((generate.SOURCE / 'config.json').read_text())
        for state in ['testing', 'public']:
            with self.subTest(state=state), tempfile.TemporaryDirectory() as temp:
                config = generate.promotional_config({**source, 'android_status': state})
                root = Path(temp) / 'share'
                generate.generate(root, config)
                manifest = json.loads((root / 'kit.json').read_text())
                destination = source['android_enrollment_url'] if state == 'testing' else source['android_url']
                self.assertEqual(manifest['android']['destination'], destination)
                self.assertEqual(manifest['items'][-1]['destination'], destination)
                result = zxingcpp.read_barcode(Image.open(root / 'assets/qr-android.png'))
                self.assertEqual(result.text, destination)
                self.assertIn(manifest['android']['title'], manifest['availability'])
                page = (root / 'index.html').read_text()
                if state == 'public':
                    self.assertNotIn('Join Android testing', page)
                    self.assertNotIn('Android testing access', page)
                with zipfile.ZipFile(root / 'stones-promo-kit.zip') as bundle:
                    instructions = bundle.read('stones-promo-kit/USAGE.txt').decode()
                    self.assertIn(config['android']['qr_note'], instructions)

    def test_unknown_state_fails(self):
        with self.assertRaises(ValueError):
            generate.promotional_config({'android_status': 'unknown'})


if __name__ == '__main__':
    unittest.main()
