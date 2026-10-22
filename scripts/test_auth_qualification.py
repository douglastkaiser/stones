"""Qualification must fail on incomplete evidence and run independent suites."""
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from auth_evidence import assert_outcome, validate_results
import google_auth_browser_checks as runner
from rollback_artifact import capture
import test_web_publication
from web_artifact import create, verify


class QualificationTests(unittest.TestCase):
    def test_missing_duplicate_observed_or_versionless_results_cannot_qualify(self):
        good = {'browser': 'webkit', 'browser_version': '1.0', 'case': 'cold', 'status': 'passed'}
        validate_results({'results': [good]}, ['webkit'], cases=['cold'])
        for rows in ([], [good, good], [{**good, 'status': 'observed'}],
                     [{**good, 'browser_version': ''}], [{**good, 'case': 'warm'}]):
            with self.subTest(rows=rows), self.assertRaises(ValueError):
                validate_results({'results': rows}, ['webkit'], cases=['cold'])
        with self.assertRaises(ValueError):
            validate_results({'results': [good]}, ['webkit', 'firefox'], cases=['cold'])

    def test_partial_or_duplicate_emulator_checks_cannot_qualify(self):
        row = {'browser': 'chromium', 'browser_version': '1.0', 'status': 'passed'}
        for checks in ([], ['login'], ['login', 'login'], ['login', 'unknown']):
            with self.subTest(checks=checks), self.assertRaises(ValueError):
                validate_results({'results': [{**row, 'checks': checks}]},
                                 ['chromium'], checks=['login', 'restart'])

    def test_strict_handoff_and_recovery_require_actual_expected_outcomes(self):
        assert_outcome({'case': 'cold', 'first_popup': 'google_account_chooser'})
        for case in ('cold', 'warm', 'close_retry', 'popup_blocked',
                     'callback_storage_lost', 'callback_new_context'):
            with self.subTest(case=case), self.assertRaises(AssertionError):
                assert_outcome({'case': case, 'first_popup': 'other'})
        recovery = {'case': 'callback_storage_lost', 'first_popup': 'missing_initial_state',
                    'recovery_notice_visible': True, 'second_attempt_locked': True,
                    'closing_popup_releases_attempt': True, 'fresh_retry_opens_popup': True}
        assert_outcome(recovery)
        for name in ('second_attempt_locked', 'fresh_retry_opens_popup'):
            with self.assertRaises(AssertionError):
                assert_outcome({**recovery, name: False})

    def test_one_failed_suite_does_not_skip_credentials_or_restart(self):
        calls = []
        def run(command, **_):
            name = Path(command[command.index('--output') + 1])
            calls.append(name.stem)
            checks = runner.REMEMBER_CHECKS if name.stem == 'remembered' else runner.CREDENTIAL_CHECKS
            data = {'results': [{'browser': 'chromium', 'browser_version': '1.0',
                                'status': 'failed' if name.stem == 'popup' else 'passed',
                                'checks': list(checks)}]}
            name.write_text(json.dumps(data))
            return SimpleNamespace(returncode=1 if name.stem == 'popup' else 0)
        server = SimpleNamespace(poll=lambda: None, terminate=lambda: None, wait=lambda **_: None)
        response = unittest.mock.MagicMock()
        response.__enter__.return_value.status = 200
        with tempfile.TemporaryDirectory() as directory, \
                patch.object(sys, 'argv', ['checks', '--expected-source', 'a' * 40, '--output', directory]), \
                patch.object(runner, 'provenance', return_value={'source': 'a' * 40}), \
                patch.object(runner.subprocess, 'Popen', return_value=server), \
                patch.object(runner.subprocess, 'run', side_effect=run), \
                patch.object(runner, 'urlopen', return_value=response):
            with self.assertRaises(SystemExit):
                runner.main()
            summary = json.loads((Path(directory) / 'summary.json').read_text())
            self.assertEqual(calls, ['popup', 'credentials', 'remembered'])
            self.assertEqual(summary['status'], 'failed')
            self.assertEqual(summary['suites']['credentials']['status'], 'passed')
            self.assertEqual(summary['suites']['remembered']['status'], 'passed')


class RollbackTests(unittest.TestCase):
    def fixture(self, root):
        test_web_publication.PublicationTests().fixture(root)
        create(root, 'a' * 40)

    def test_reconstructs_verified_canonical_ledger_and_excludes_previews(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            published, output = root / 'published', root / 'rollback'
            self.fixture(published)
            ledger = json.loads((published / 'startup-assets.json').read_text())
            (published / 'startup-assets.json').write_text(json.dumps(ledger + [['old', 'pair']]))
            (published / 'pr').mkdir()
            (published / 'pr' / 'private-preview').write_text('excluded')
            self.assertEqual(capture(published, output)['previous_source'], 'a' * 40)
            verify(output, 'a' * 40, kind='production')
            self.assertFalse((output / 'pr').exists())

    def test_corrupt_or_escaping_previous_release_cannot_be_archived(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            published = root / 'published'
            self.fixture(published)
            (published / 'main.dart.js').write_text('corrupt')
            with self.assertRaises(ValueError):
                capture(published, root / 'output')
            manifest = published / 'release-manifest.json'
            data = json.loads(manifest.read_text())
            data['files'] = {'../escape': '0' * 64}
            manifest.write_text(json.dumps(data))
            with self.assertRaises(ValueError):
                capture(published, root / 'output')

    def test_wrong_build_kind_and_source_hashes_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'web'
            self.fixture(root)
            with self.assertRaises(ValueError):
                verify(root, 'a' * 40, kind='emulator')
            manifest = root / 'release-manifest.json'
            data = json.loads(manifest.read_text())
            data['authSources']['lib/services/account_service.dart'] = '0' * 64
            manifest.write_text(json.dumps(data))
            with self.assertRaises(ValueError):
                verify(root, 'a' * 40, kind='production')


if __name__ == '__main__':
    unittest.main()
