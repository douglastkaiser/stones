"""Independently qualify emulator popup, credentials and process restoration."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from urllib.request import urlopen

from auth_evidence import provenance, validate_results

CREDENTIAL_CHECKS = (
    'fresh_google_sign_in', 'google_identity_restored_after_reload',
    'sign_out', 'collision_preserves_guest', 'guest_link_preserves_uid',
    'linked_identity_restored_after_reload', 'denied_persistent_storage_keeps_session_usable',
)
REMEMBER_CHECKS = (
    'first_account_signed_in', 'restored_on_home_after_browser_restart',
    'explicit_sign_out', 'sign_out_survives_browser_restart',
    'last_account_restored_after_browser_restart',
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--browsers', default='chromium')
    parser.add_argument('--expected-source', required=True)
    parser.add_argument('--web-root', type=Path, default=Path('build/integration-web'))
    parser.add_argument('--output', type=Path, default=Path('build/qa/google-auth'))
    args = parser.parse_args()
    names = args.browsers.split(',')
    if len(names) != len(set(names)) or not set(names) <= {'chromium', 'firefox', 'webkit'}:
        parser.error('Unknown or duplicate browser')
    evidence = args.output
    evidence.mkdir(parents=True, exist_ok=True)
    for name in ('summary.json', 'popup.json', 'credentials.json', 'remembered.json'):
        (evidence / name).unlink(missing_ok=True)
    summary = {'status': 'running', 'started_utc': datetime.now(timezone.utc).isoformat(),
               'suites': {name: {'status': 'not_run'} for name in ('popup', 'credentials', 'remembered')}}
    target = evidence / 'summary.json'

    def save():
        target.write_text(json.dumps(summary, indent=2) + '\n')

    save()
    try:
        summary['build'] = provenance(args.web_root, args.expected_source, 'emulator')
        with (evidence / 'server.log').open('w') as log:
            server = subprocess.Popen(['node', 'tools/serve_web.mjs'],
                                      env={**os.environ, 'WEB_ROOT': str(args.web_root), 'PORT': '4173'},
                                      stdout=log, stderr=subprocess.STDOUT)
            try:
                for _ in range(50):
                    if server.poll() is not None:
                        raise RuntimeError('Auth regression server did not start')
                    try:
                        with urlopen('http://127.0.0.1:4173/stones/', timeout=1) as response:
                            if response.status == 200:
                                break
                    except OSError:
                        time.sleep(0.1)
                else:
                    raise RuntimeError('Auth regression server was not ready')
                for name, script, flags, checks in (
                    ('popup', 'google_auth_emulator_probe.py', [],
                     (*CREDENTIAL_CHECKS, 'popup_cancel_keeps_identity', 'explicit_switch_requires_confirmation')),
                    ('credentials', 'google_auth_emulator_probe.py', ['--credentials-only'], CREDENTIAL_CHECKS),
                    ('remembered', 'google_auth_remember_probe.py', [], REMEMBER_CHECKS),
                ):
                    report = evidence / (name + '.json')
                    row = summary['suites'][name]
                    row['status'] = 'running'
                    save()
                    try:
                        completed = subprocess.run(
                            [sys.executable, 'tools/' + script, *flags, '--browsers', args.browsers,
                             '--output', str(report)], timeout=420)
                        data = json.loads(report.read_text())
                        data['build'] = summary['build']
                        report.write_text(json.dumps(data, indent=2) + '\n')
                        validate_results(data, names, checks=checks)
                        if completed.returncode:
                            raise RuntimeError('Probe exited unsuccessfully')
                        row['status'] = 'passed'
                    except Exception as error:
                        row.update(status='failed', error_type=type(error).__name__)
                    save()
            finally:
                server.terminate()
                try:
                    server.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    server.kill()
                    server.wait()
        summary['status'] = 'passed' if all(
            s['status'] == 'passed' for s in summary['suites'].values()) else 'failed'
    except Exception as error:
        summary.update(status='failed', error_type=type(error).__name__)
    summary['completed_utc'] = datetime.now(timezone.utc).isoformat()
    save()
    print(json.dumps(summary), flush=True)
    if summary['status'] != 'passed':
        raise SystemExit(1)


if __name__ == '__main__':
    main()
