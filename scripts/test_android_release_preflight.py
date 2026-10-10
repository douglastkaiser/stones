import contextlib
import io
import json
import os
import pathlib
import subprocess
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import android_release_preflight as preflight


class ReleasePreflightTest(unittest.TestCase):
    def setUp(self):
        self.env = {
            'ANDROID_UPLOAD_STORE_FILE': 'fixture-upload.jks',
            'ANDROID_UPLOAD_STORE_PASSWORD': 'secret-store',
            'ANDROID_UPLOAD_KEY_ALIAS': 'upload',
            'ANDROID_UPLOAD_KEY_PASSWORD': 'secret-key',
        }
        self.config = {'project_info': {'project_id': 'stones-9a6a0'}, 'client': [{
            'client_info': {'android_client_info': {'package_name': 'com.douglastkaiser.stones'}},
            'oauth_client': [{'client_type': 1, 'android_info': {'certificate_hash': 'aabb'}},
                             {'client_type': 3}],
        }]}

    def run_preflight(self, outputs=None):
        outputs = outputs or [subprocess.CompletedProcess([], 0, b'certificate'),
                   subprocess.CompletedProcess([], 0, b'SHA1: AA:BB\nSHA256: CC:DD')]
        log = io.StringIO()
        with patch.dict(os.environ, self.env, clear=True), \
             patch.object(pathlib.Path, 'is_file', return_value=True), \
             patch.object(pathlib.Path, 'stat', return_value=SimpleNamespace(st_size=12)), \
             patch.object(pathlib.Path, 'read_text', return_value=json.dumps(self.config)), \
             patch.object(subprocess, 'run', side_effect=outputs) as run, \
             contextlib.redirect_stdout(log):
            preflight.main()
        return run, log.getvalue()

    def test_valid_certificate_and_no_passwords_in_logs_or_arguments(self):
        run, output = self.run_preflight()
        self.assertIn('validated', output)
        for secret in ['secret-store', 'secret-key']:
            self.assertNotIn(secret, output)
            self.assertNotIn(secret, str(run.call_args_list))

    def test_wrong_fingerprint_fails_before_build(self):
        self.config['client'][0]['oauth_client'][0]['android_info']['certificate_hash'] = 'ccdd'
        with self.assertRaisesRegex(SystemExit, 'not registered'):
            self.run_preflight()

    def test_missing_web_client_fails(self):
        self.config['client'][0]['oauth_client'].pop()
        with self.assertRaisesRegex(SystemExit, 'web OAuth'):
            self.run_preflight()

    def test_missing_signing_secret_fails(self):
        self.env.pop('ANDROID_UPLOAD_KEY_PASSWORD')
        with self.assertRaisesRegex(SystemExit, 'Missing signing inputs'):
            self.run_preflight()

    def test_wrong_project_fails(self):
        self.config['project_info']['project_id'] = 'other'
        with self.assertRaisesRegex(SystemExit, 'does not match'):
            self.run_preflight()

    def test_placeholder_play_games_id_is_rejected(self):
        self.env['STONES_PLAY_GAMES_APP_ID'] = '0'
        with self.assertRaisesRegex(SystemExit, 'numeric Play Games'):
            self.run_preflight()

    def listing(self, alias='existing-private-key', fingerprint='AA:BB', kind='PrivateKeyEntry'):
        return f'Alias name: {alias}\nEntry type: {kind}\nCertificate[1]:\nSHA1: {fingerprint}\n'

    def test_recovers_missing_alias_only_from_registered_private_key(self):
        run, output = self.run_preflight([
            subprocess.CompletedProcess([], 1, b'Alias <bad> does not exist', b''),
            subprocess.CompletedProcess([], 0, self.listing().encode(), b''),
            subprocess.CompletedProcess([], 0, b'certificate', b''),
            subprocess.CompletedProcess([], 0, b'SHA1: AA:BB\nSHA256: CC:DD', b''),
        ])
        self.assertIn('signing identity is unchanged', output)
        self.assertNotIn('existing-private-key', output)
        self.assertEqual(run.call_args_list[2].args[0][-1], 'existing-private-key')
        self.assertNotIn('secret-store', str(run.call_args_list))

    def test_recovery_rejects_unregistered_or_certificate_only_entries(self):
        for listing in [self.listing(fingerprint='CC:DD'), self.listing(kind='trustedCertEntry')]:
            with self.subTest(listing=listing), patch.object(subprocess, 'run', return_value=
                    subprocess.CompletedProcess([], 0, listing.encode(), b'')):
                with self.assertRaisesRegex(SystemExit, 'exactly one'):
                    preflight.recover_alias(pathlib.Path('fixture'), {'aabb'})

    def test_recovery_rejects_ambiguous_matching_keys(self):
        listing = self.listing() + self.listing(alias='another-key')
        with patch.object(subprocess, 'run', return_value=
                subprocess.CompletedProcess([], 0, listing.encode(), b'')):
            with self.assertRaisesRegex(SystemExit, 'exactly one'):
                preflight.recover_alias(pathlib.Path('fixture'), {'aabb'})

    def test_recovery_uses_leaf_fingerprint_not_chain_ca(self):
        listing = self.listing(fingerprint='CC:DD') + 'Certificate[2]:\nSHA1: AA:BB\n'
        with patch.object(subprocess, 'run', return_value=
                subprocess.CompletedProcess([], 0, listing.encode(), b'')):
            with self.assertRaisesRegex(SystemExit, 'exactly one'):
                preflight.recover_alias(pathlib.Path('fixture'), {'aabb'})

    def test_recovery_does_not_print_raw_keytool_errors(self):
        with patch.object(subprocess, 'run', return_value=
                subprocess.CompletedProcess([], 1, b'private-password', b'')):
            with self.assertRaises(SystemExit) as failure:
                preflight.recover_alias(pathlib.Path('fixture'), {'aabb'})
        self.assertNotIn('private-password', str(failure.exception))

    def test_signing_errors_are_classified_without_exposing_raw_values(self):
        cases = [
            (b'Keystore password was incorrect: private-password', 'ANDROID_UPLOAD_STORE_PASSWORD'),
            (b'Invalid keystore format', 'ANDROID_UPLOAD_KEYSTORE_B64'),
        ]
        for raw, expected in cases:
            with self.subTest(expected=expected), patch.dict(os.environ, self.env, clear=True), \
                 patch.object(pathlib.Path, 'is_file', return_value=True), \
                 patch.object(pathlib.Path, 'stat', return_value=SimpleNamespace(st_size=12)), \
                 patch.object(pathlib.Path, 'read_text', return_value=json.dumps(self.config)), \
                 patch.object(subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, raw, b'')):
                with self.assertRaises(SystemExit) as failure:
                    preflight.main()
                self.assertIn(expected, str(failure.exception))
                self.assertNotIn('private-', str(failure.exception))


if __name__ == '__main__':
    unittest.main()
