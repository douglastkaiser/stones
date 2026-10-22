"""Build provenance and complete, fail-closed auth qualification reports."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from web_artifact import verify


def provenance(root, expected_source, kind):
    root = Path(root)
    source = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
    if expected_source != source:
        raise ValueError('Checkout is not the expected source')
    verify(root, expected_source, kind=kind)
    manifest = root / 'release-manifest.json'
    data = json.loads(manifest.read_text())
    return {'source': source, 'build_kind': kind,
            'working_tree_changes': bool(subprocess.check_output(
                ['git', 'status', '--porcelain'], text=True).strip()),
            'manifest_sha256': hashlib.sha256(manifest.read_bytes()).hexdigest(),
            'auth_source_sha256': data['authSources'],
            'main_sha256': data['files']['main.dart.js'],
            'flutter': data['flutter']}


def validate_results(report, browsers, *, cases=None, checks=None):
    """Missing, duplicate, observation-only and partial results are failures."""
    results = report.get('results', [])
    expected = {(browser, case) for browser in browsers for case in cases} if cases else {
        (browser, None) for browser in browsers}
    seen = [(row.get('browser'), row.get('case') if cases else None) for row in results]
    if len(seen) != len(set(seen)) or set(seen) != expected:
        raise ValueError('Missing, duplicate or unexpected browser/scenario results')
    for row in results:
        if row.get('status') != 'passed' or not row.get('browser_version'):
            raise ValueError('Unqualified browser/scenario result')
        if checks and (len(row.get('checks', [])) != len(checks)
                       or set(row['checks']) != set(checks)):
            raise ValueError('Incomplete or duplicate scenario checks')


def assert_outcome(result):
    case = result['case']
    if case in ('cold', 'warm', 'close_retry'):
        if result.get('first_popup') != 'google_account_chooser':
            raise AssertionError('Google chooser was not reached')
        if case == 'close_retry' and result.get('retry_popup') != 'google_account_chooser':
            raise AssertionError('Retry did not reach the chooser')
    elif case == 'popup_blocked':
        if result.get('first_popup') != 'none' or result.get('app_state') != 'popup_blocked_message':
            raise AssertionError('Blocked popup did not produce recovery guidance')
    elif case in ('callback_storage_lost', 'callback_new_context'):
        if result.get('first_popup') != 'missing_initial_state' or not all(
            result.get(key) for key in ('recovery_notice_visible', 'second_attempt_locked',
                                       'closing_popup_releases_attempt', 'fresh_retry_opens_popup')):
            raise AssertionError('Missing-state recovery was incomplete')
    else:
        raise ValueError('Case has no strict acceptance contract')
