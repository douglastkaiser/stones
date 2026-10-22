"""Verify remembered accounts across actual browser process restarts.

Requires the emulator-only build/server and demo auth/firestore emulators used
by google_auth_emulator_probe.py. Temporary persistent profiles contain only fake
emulator accounts and are deleted afterward. No raw identifiers or storage values
are written to the JSON report. This is not physical iOS/Google qualification.
"""
import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import tempfile

from playwright.sync_api import expect, sync_playwright

from browser_journeys import browser_request, ready
from google_auth_emulator_probe import (
    AUTH, BASE, EMULATOR_BINDING, credential_fixture, fixture_claims,
    identity, open_settings, signed_in,
)
from google_auth_probe import tap


@contextmanager
def open_profile(playwright, name, profile):
    launch = {}
    if os.environ.get('HTTPS_PROXY'):
        launch['proxy'] = {'server': os.environ['HTTPS_PROXY'],
                           'bypass': '127.0.0.1,localhost'}
    ca = os.environ.get('NODE_EXTRA_CA_CERTS')
    if name == 'firefox' and ca and not (profile / 'cert9.db').exists():
        for args in [
            ['-N', '-d', 'sql:' + str(profile), '--empty-password'],
            ['-A', '-d', 'sql:' + str(profile), '-n', 'Environment proxy CA',
             '-t', 'C,,', '-i', ca],
        ]:
            subprocess.run(['certutil', *args], check=True, capture_output=True)
    context = getattr(playwright, name).launch_persistent_context(
        str(profile), viewport={'width': 390, 'height': 844},
        has_touch=name != 'firefox', service_workers='block', **launch)
    try:
        context.route('**/*', browser_request)
        context.add_init_script(EMULATOR_BINDING)
        page = context.pages[0] if context.pages else context.new_page()
        page.goto(BASE)
        ready(page)
        # Wait for restoration, without invoking a chooser or creating a guest.
        page.evaluate(f'async () => {{ await ({AUTH})().authStateReady(); }}')
        yield page
    finally:
        context.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--browsers', default='chromium,firefox,webkit')
    parser.add_argument('--output', type=Path,
                        default=Path('build/qa/google-auth/remembered-accounts.json'))
    args = parser.parse_args()
    names = args.browsers.split(',')
    if not set(names) <= {'chromium', 'firefox', 'webkit'}:
        parser.error('Unknown browser')
    summary = {'started_utc': datetime.now(timezone.utc).isoformat(),
               'scope': 'emulator_accounts_browser_process_restarts',
               'physical_ios': 'unverified', 'real_google_exchange': 'unverified',
               'results': []}
    args.output.parent.mkdir(parents=True, exist_ok=True)

    def save():
        args.output.write_text(json.dumps(summary, indent=2) + '\n')

    save()
    with sync_playwright() as playwright:
        for name in names:
            result = {'browser': name, 'checks': [], 'status': 'running', 'stage': 'sign_in'}
            summary['results'].append(result)
            save()
            print(name, flush=True)
            try:
                with tempfile.TemporaryDirectory(prefix='stones-remember-') as directory:
                    profile = Path(directory)
                    with open_profile(playwright, name, profile) as page:
                        open_settings(page)
                        assert credential_fixture(page, 'sign_in', fixture_claims()) is None
                        signed_in(page)
                        first = identity(page)
                        result['checks'].append('first_account_signed_in')

                    result['stage'] = 'restart_restore'
                    with open_profile(playwright, name, profile) as page:
                        assert identity(page) == first
                        page.get_by_role('button', name='Sign in with Google', exact=True).wait_for(
                            state='hidden', timeout=15000)
                        result['checks'].append('restored_on_home_after_browser_restart')
                        open_settings(page)
                        signed_in(page)
                        tap(page, page.get_by_role('button', name='Sign out', exact=True))
                        page.get_by_role('button', name='Cancel', exact=True).wait_for()
                        tap(page, page.get_by_role('button', name='Sign out', exact=True).last)
                        expect(page.get_by_role('button', name='Sign in with Google', exact=True)).to_be_visible()
                        assert identity(page) is None
                        result['checks'].append('explicit_sign_out')

                    result['stage'] = 'restart_after_sign_out'
                    with open_profile(playwright, name, profile) as page:
                        assert identity(page) is None
                        result['checks'].append('sign_out_survives_browser_restart')
                        open_settings(page)
                        assert credential_fixture(page, 'sign_in', fixture_claims()) is None
                        signed_in(page)
                        last = identity(page)
                        assert last['uid'] != first['uid']

                    result['stage'] = 'restart_last_account'
                    with open_profile(playwright, name, profile) as page:
                        assert identity(page) == last
                        page.get_by_role('button', name='Sign in with Google', exact=True).wait_for(
                            state='hidden', timeout=15000)
                        result['checks'].append('last_account_restored_after_browser_restart')
                result['status'] = 'passed'
                result['stage'] = 'completed'
            except Exception as error:
                result['status'] = 'failed'
                result['error_type'] = type(error).__name__
            save()
            print(json.dumps(result), flush=True)
    summary['completed_utc'] = datetime.now(timezone.utc).isoformat()
    save()
    if any(r['status'] != 'passed' for r in summary['results']):
        raise SystemExit(1)


if __name__ == '__main__':
    main()
