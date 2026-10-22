"""Exercise real FirebaseAccountService popup/linking against local emulators.

Build tools/integration_app.dart and serve build/integration-web on port 4173.
Start auth/firestore emulators with project demo-stones-hex. Production Firebase
requests are blocked; every fixture operation checks the auth emulator binding.
Only comparison results, never UIDs, emails, tokens or storage values, are saved.
"""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import uuid
from urllib.parse import urlsplit

from playwright.sync_api import sync_playwright, expect

from browser_journeys import browser_request, ready
from google_auth_probe import browser_session, tap


BASE = 'http://127.0.0.1:4173/stones/'
AUTH = """() => {
  const auth = firebase_auth.getAuth(firebase_core.getApp());
  if (auth.emulatorConfig?.host !== '127.0.0.1' || auth.emulatorConfig?.port !== 9099
      || firebase_core.getApp().options.projectId !== 'demo-stones-hex') {
    throw new Error('Expected the local demo auth emulator');
  }
  return auth;
}"""

# Configure the real SDK before FlutterFire awaits restored authentication.
# Only disposable emulator browser contexts receive this initialization hook.
EMULATOR_BINDING = """Object.defineProperty(window, 'firebase_auth', {
  configurable: true,
  set(module) {
    const wrapped = {...module, initializeAuth(app, options) {
      if (app.options.projectId !== 'demo-stones-hex')
        throw new Error('Expected local demo project');
      const auth = module.initializeAuth(app, options);
      if (!auth.emulatorConfig)
        module.connectAuthEmulator(auth, 'http://127.0.0.1:9099');
      return auth;
    }};
    Object.defineProperty(window, 'firebase_auth', {
      value: wrapped, configurable: true, writable: true
    });
  }
});"""


def identity(page):
    return page.evaluate(f"""() => {{
      const u = ({AUTH})().currentUser;
      return u ? {{uid: u.uid, anonymous: u.isAnonymous}} : null;
    }}""")


def signed_in(page):
    page.wait_for_function(f'() => !!({AUTH})().currentUser && !({AUTH})().currentUser.isAnonymous')
    expect(page.get_by_role('button', name='Sign out', exact=True)).to_be_visible(timeout=15000)


def open_settings(page):
    tap(page, page.get_by_role('button', name='Settings & account', exact=True))
    page.get_by_text('Settings', exact=True).wait_for()
    # Flutter exposes route semantics before its slide transition finishes.
    # Wait for the painted controls to reach their final tap coordinates.
    page.wait_for_timeout(350)


def google(page, email):
    button = page.get_by_role('button', name='Sign in with Google', exact=True)
    expect(button).to_be_visible(timeout=15000)
    with page.expect_popup(timeout=15000) as opened:
        tap(page, button)
    popup = opened.value
    popup.wait_for_load_state('domcontentloaded')
    # Never enter fixtures into a real provider UI.
    target = urlsplit(popup.url)
    if (target.scheme, target.netloc, target.path) != (
            'http', '127.0.0.1:9099', '/emulator/auth/handler'):
        raise RuntimeError('Expected the local emulator provider window')
    popup.get_by_role('button', name=re.compile('Add new account')).click()
    popup.locator('#email-input').fill(email)
    popup.locator('#display-name-input').fill('Stones Auth Probe')
    popup.get_by_role('button', name=re.compile('Sign in with Google')).click()


def credential_fixture(page, action, claims):
    """Real Firebase operations with fake claims accepted only by the emulator."""
    return page.evaluate(f"""async ({{action, claims}}) => {{
      const auth = ({AUTH})();
      const credential = firebase_auth.GoogleAuthProvider.credential(JSON.stringify(claims));
      try {{
        if (action === 'link') await firebase_auth.linkWithCredential(auth.currentUser, credential);
        else await firebase_auth.signInWithCredential(auth, credential);
        return null;
      }} catch (error) {{ return error.code; }}
    }}""", {'action': action, 'claims': claims})


def fixture_claims():
    subject = 'stones-probe-' + uuid.uuid4().hex
    return {'sub': subject, 'email': subject + '@example.invalid', 'email_verified': True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--browsers', default='chromium,firefox,webkit')
    parser.add_argument('--credentials-only', action='store_true',
                        help='Test Firebase linking/persistence without the popup relay; not popup qualification')
    parser.add_argument('--output', type=Path, default=Path('build/qa/google-auth/emulator.json'))
    args = parser.parse_args()
    names = args.browsers.split(',')
    if not set(names) <= {'chromium', 'firefox', 'webkit'}:
        parser.error('Unknown browser')
    summary = {'started_utc': datetime.now(timezone.utc).isoformat(),
               'scope': ('local_emulator_credentials_only' if args.credentials_only
                         else 'local_emulator_service_popup'), 'physical_ios': 'unverified',
               'real_google_exchange': 'unverified', 'results': []}
    args.output.parent.mkdir(parents=True, exist_ok=True)

    def save():
        args.output.write_text(json.dumps(summary, indent=2) + '\n')

    save()
    with sync_playwright() as playwright:
        for name in names:
            checks = []
            result = {'browser': name, 'checks': checks, 'status': 'running', 'stage': 'launch'}
            summary['results'].append(result)
            save()
            print(name, flush=True)
            try:
                with browser_session(playwright, name, local=True) as browser:
                    context = browser.new_context(viewport={'width': 390, 'height': 844},
                                                  has_touch=name != 'firefox',
                                                  service_workers='block')
                    context.route('**/*', browser_request)
                    # FlutterFire waits for restored auth during initializeApp,
                    # before integration_app.dart can call useAuthEmulator.
                    # Bind immediately after initializeAuth in this test only.
                    context.add_init_script(EMULATOR_BINDING)
                    page = context.new_page()
                    result['stage'] = 'load'
                    page.goto(BASE)
                    ready(page)
                    result['stage'] = 'open_settings'
                    open_settings(page)
                    expect(page.get_by_role('button', name='Sign in with Google', exact=True)).to_be_visible()
                    assert identity(page) is None
                    claims = fixture_claims()
                    result['stage'] = 'fresh_sign_in'
                    if args.credentials_only:
                        assert credential_fixture(page, 'sign_in', claims) is None
                    else:
                        google(page, claims['email'])
                    signed_in(page)
                    registered = identity(page)
                    checks.append('fresh_google_sign_in')

                    result['stage'] = 'restore_google_identity'
                    page.reload()
                    ready(page)
                    open_settings(page)
                    signed_in(page)
                    assert identity(page) == registered
                    checks.append('google_identity_restored_after_reload')

                    result['stage'] = 'sign_out'
                    tap(page, page.get_by_role('button', name='Sign out', exact=True))
                    page.get_by_role('button', name='Cancel', exact=True).wait_for()
                    tap(page, page.get_by_role('button', name='Sign out', exact=True).last)
                    expect(page.get_by_role('button', name='Sign in with Google', exact=True)).to_be_visible()
                    assert identity(page) is None
                    checks.append('sign_out')

                    result['stage'] = 'collision'
                    page.evaluate(f'async () => {{ await firebase_auth.signInAnonymously(({AUTH})()); }}')
                    guest = identity(page)
                    assert guest['anonymous']
                    # Linking to the existing Google identity must preserve the
                    # guest until the user explicitly chooses to switch.
                    if args.credentials_only:
                        code = credential_fixture(page, 'link', claims)
                        assert code in ('auth/credential-already-in-use', 'auth/email-already-in-use')
                    else:
                        google(page, claims['email'])
                        switch = page.get_by_role('button', name='Use existing account', exact=True)
                        expect(switch).to_be_visible(timeout=15000)
                    assert identity(page) == guest
                    checks.append('collision_preserves_guest')

                    # A distinct provider account links to the same guest UID.
                    result['stage'] = 'guest_link'
                    new_claims = fixture_claims()
                    if args.credentials_only:
                        assert credential_fixture(page, 'link', new_claims) is None
                    else:
                        google(page, new_claims['email'])
                    signed_in(page)
                    linked = identity(page)
                    assert linked['uid'] == guest['uid'] and not linked['anonymous']
                    checks.append('guest_link_preserves_uid')

                    result['stage'] = 'restore_linked_identity'
                    page.reload()
                    ready(page)
                    open_settings(page)
                    signed_in(page)
                    assert identity(page) == linked
                    checks.append('linked_identity_restored_after_reload')
                    context.close()
                result['status'] = 'passed'
                result['stage'] = 'completed'
            except Exception as error:
                result['status'] = 'failed'
                result['error_type'] = type(error).__name__
                for marker in ('strict mode violation', 'Execution context was destroyed',
                               'Expected the local demo auth emulator',
                               'Cannot read properties of undefined', 'is not defined'):
                    if marker in str(error):
                        result['error_category'] = marker
            save()
            print(json.dumps(result), flush=True)
    summary['completed_utc'] = datetime.now(timezone.utc).isoformat()
    save()
    if any(r['status'] != 'passed' for r in summary['results']):
        raise SystemExit(1)


if __name__ == '__main__':
    main()
