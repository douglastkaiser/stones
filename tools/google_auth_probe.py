"""Pre-credential Google login investigation on the public Stones website.

No account is entered or created. Production Firebase writes and analytics are
blocked. Evidence contains classifications, origins and timings, never raw
URLs, page text, console messages, traces, screenshots or storage values.
Desktop WebKit is not physical iOS qualification.

python tools/google_auth_probe.py --browsers chromium,firefox,webkit
"""
import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time
from urllib.parse import parse_qs, urlencode, urlsplit
from urllib.request import urlopen
from urllib.error import HTTPError

from playwright.sync_api import sync_playwright, TimeoutError as BrowserTimeout, Error as BrowserError

from browser_journeys import ready
from google_auth_policy import (
    block_production, controlled_callback_document, origin, validate_probe_base,
)
from auth_evidence import assert_outcome, validate_results


BASE = 'https://www.douglastkaiser.com/stones/'
CASES = ('cold', 'warm', 'popup_blocked', 'storage_denied', 'helper_blocked',
         'close_retry', 'offline_retry', 'background_resume',
         'callback_same_context', 'callback_storage_lost', 'callback_new_context')
INSTRUMENT = """() => {
  window.__authProbe = {clicks: [], opens: []};
  for (const event of ['pointerdown', 'touchend', 'mouseup', 'click']) {
    addEventListener(event, () => {
      window.__authProbe.clicks.push(performance.now());
    }, true);
  }
  const original = window.open;
  window.open = function(...args) {
    const active = navigator.userActivation?.isActive ?? null;
    const now = performance.now();
    const opened = window.__blockAuthPopup ? null : original.apply(this, args);
    window.__authProbe.opens.push({active, opened: !!opened,
      afterInputMs: Math.round(now - window.__authProbe.clicks.at(-1))});
    return opened;
  };
}"""


@contextmanager
def browser_session(playwright, name, local=False):
    """Keep TLS verification enabled, including in a managed proxy environment."""
    launch = {}
    if os.environ.get('HTTPS_PROXY'):
        launch['proxy'] = {'server': os.environ['HTTPS_PROXY']}
        if local:
            launch['proxy']['bypass'] = '127.0.0.1,localhost'
    ca_file = os.environ.get('NODE_EXTRA_CA_CERTS')
    if name == 'firefox' and ca_file:
        # Firefox's temporary profiles do not inherit Node/system proxy trust.
        # Seed just its public CA certificate, then use independent contexts.
        with tempfile.TemporaryDirectory(prefix='stones-firefox-') as profile:
            for args in [
                ['-N', '-d', 'sql:' + profile, '--empty-password'],
                ['-A', '-d', 'sql:' + profile, '-n', 'Environment proxy CA',
                 '-t', 'C,,', '-i', ca_file],
            ]:
                subprocess.run(['certutil', *args], check=True, capture_output=True)
            root = playwright.firefox.launch_persistent_context(profile, **launch)
            try:
                yield root.browser
            finally:
                root.close()
    else:
        browser = getattr(playwright, name).launch(**launch)
        try:
            yield browser
        finally:
            browser.close()


def classify(page):
    if page.is_closed():
        return 'closed'
    host = urlsplit(page.url).hostname
    if host == 'accounts.google.com':
        # A navigation to Google can still be a loading/error page. Require
        # the provider's visible identifier or account-selection surface.
        choices = page.locator('input[type="email"], input[autocomplete~="username"], '
                               'input[name="identifier"], #identifierId, [data-identifier]')
        if any(choices.nth(index).is_visible() for index in range(choices.count())):
            return 'google_account_chooser'
        return 'google_provider_not_ready'
    # Inspect text only in memory; never save it to the report.
    text = page.locator('body').evaluate("""e => e.innerText + '\\n' +
      [...e.querySelectorAll('[aria-label]')].map(n => n.getAttribute('aria-label')).join('\\n')
    """).lower()
    if 'missing initial state' in text:
        return 'missing_initial_state'
    if 'your browser blocked' in text:
        return 'popup_blocked_message'
    if 'could not keep the sign-in state' in text:
        return 'storage_error_message'
    if 'connection' in text and ('retry' in text or 'try again' in text):
        return 'connection_error_message'
    if 'sign-in could not finish' in text:
        return 'generic_sign_in_error'
    if 'signing in' in text or 'connecting' in text:
        return 'waiting'
    return 'other'


def sign_in(page):
    button = page.get_by_role('button', name='Sign in with Google', exact=True)
    button.wait_for(state='visible', timeout=25000)
    home = page.get_by_role('button', name='Settings & account', exact=True).count() > 0
    before = page.evaluate('window.__authProbe.opens.length')
    tap(page, button)
    if home:
        # Flutter handles canvas input asynchronously. Wait for a real popup
        # attempt or the preparation card, rather than sampling the next frame
        # and accidentally treating an opening popup as another required tap.
        page.wait_for_function("""before => {
          const text = document.body.innerText + [...document.querySelectorAll('[aria-label]')]
            .map(e => e.getAttribute('aria-label')).join(' ');
          return window.__authProbe.opens.length > before || text.includes('Your Stones account');
        }""", arg=before, timeout=25000)
        if page.evaluate('window.__authProbe.opens.length') == before:
            button.wait_for(state='visible', timeout=25000)
            tap(page, button)


def tap(page, target):
    target.scroll_into_view_if_needed()
    box = target.bounding_box()
    x, y = box['x'] + box['width'] / 2, box['y'] + box['height'] / 2
    if page.context.browser.browser_type.name == 'firefox':
        page.mouse.click(x, y)
    else:
        page.touchscreen.tap(x, y)


def wait_for_popup(context, page, timeout=25000, stop_at_google=True):
    deadline = time.monotonic() + timeout / 1000
    while time.monotonic() < deadline:
        for popup in context.pages:
            if popup != page and not popup.is_closed():
                try:
                    if stop_at_google and urlsplit(popup.url).hostname == 'accounts.google.com':
                        if classify(popup) == 'google_account_chooser':
                            return popup
                        continue
                    if 'missing initial state' in popup.locator('body').inner_text(timeout=3000).lower():
                        return popup
                except BrowserError:
                    if not popup.is_closed():
                        raise
        if classify(page) in ('popup_blocked_message', 'storage_error_message',
                              'connection_error_message', 'generic_sign_in_error'):
            return None
        page.wait_for_timeout(200)
    return None


def run_case(browser, case, base=BASE, verify_recovery=False, strict=False):
    result = {'case': case, 'observations': [], 'firebase_js_versions': [],
              'dependency_failures': [],
              'blocked_production_requests': 0}
    context = browser.new_context(viewport={'width': 390, 'height': 844},
                                  has_touch=browser.browser_type.name != 'firefox',
                                  service_workers='block')
    versions = set()
    helper_blocked = case == 'helper_blocked'
    callbacks = []

    def route(request_route):
        request = request_route.request
        parsed = urlsplit(request.url)
        query = parse_qs(parsed.query)
        match = re.search(r'/firebasejs/([\d.]+)/', request.url)
        if match:
            versions.add(match.group(1))
        if block_production(request):
            result['blocked_production_requests'] += 1
            request_route.abort()
        elif case.startswith('callback_') and parsed.hostname == 'accounts.google.com' \
                and 'state' in query and 'redirect_uri' in query:
            # Return an intentionally invalid code. No real Google credential
            # is obtained; signInWithIdp is blocked above. State stays in memory.
            callback = query['redirect_uri'][0]
            if callback != 'https://stones-9a6a0.firebaseapp.com/__/auth/handler':
                request_route.abort()
                return
            callback += '?' + urlencode({'state': query['state'][0],
                                         'code': 'stones-probe-invalid-code'})
            callbacks.append(callback)
            if case == 'callback_new_context':
                request_route.fulfill(status=200, body='Controlled context-switch probe')
            else:
                request_route.fulfill(status=200, content_type='text/html',
                                      body=controlled_callback_document(callback))
        elif helper_blocked and '/__/auth/iframe' in request.url:
            request_route.abort()
        else:
            request_route.continue_()

    context.route('**/*', route)
    def dependency_response(response):
        if response.status >= 400 and not block_production(response.request):
            failure = {'origin': origin(response.url), 'status': response.status,
                       'resource': response.request.resource_type}
            if failure not in result['dependency_failures']:
                result['dependency_failures'].append(failure)
    context.on('response', dependency_response)
    context.add_init_script(f'({INSTRUMENT})();')
    if case == 'storage_denied':
        # This is a controlled fault on the helper, not a simulation of ITP.
        context.add_init_script("""if (location.hostname === 'stones-9a6a0.firebaseapp.com') {
          Object.defineProperty(window, 'sessionStorage', {get() {
            throw new DOMException('Probe denied storage', 'SecurityError');
          }});
        }""")
    if case == 'callback_storage_lost':
        context.add_init_script("""if (location.hostname === 'stones-9a6a0.firebaseapp.com'
          && new URLSearchParams(location.search).has('code')) sessionStorage.clear();""")
    page = context.new_page()
    try:
        page.goto(base, wait_until='domcontentloaded', timeout=45000)
        ready(page)
        if case not in ('cold', 'helper_blocked'):
            tap(page, page.get_by_role('button', name='Settings & account', exact=True))
            page.get_by_text('Settings', exact=True).wait_for(
                state='visible', timeout=25000)
            sign_in_button = page.get_by_role('button', name='Sign in with Google', exact=True)
            sign_in_button.wait_for(state='visible', timeout=25000)
        if case == 'popup_blocked':
            page.evaluate('window.__blockAuthPopup = true')
        if case == 'offline_retry':
            context.set_offline(True)
            sign_in(page)
            page.wait_for_timeout(2000)
            for popup in list(context.pages):
                if popup != page:
                    popup.close()
            context.set_offline(False)
            result['observations'].append('network_restored')
            page.get_by_role('button', name='Sign in with Google', exact=True).wait_for(
                state='visible', timeout=15000)
        if case == 'background_resume':
            other = context.new_page()
            other.goto('about:blank')
            page.bring_to_front()
            other.close()
            result['observations'].append('desktop_tab_switch_only')
        sign_in(page)
        if case == 'callback_new_context':
            deadline = time.monotonic() + 25
            while not callbacks and time.monotonic() < deadline:
                page.wait_for_timeout(200)
            if not callbacks:
                raise BrowserTimeout('Synthetic callback not reached')
            # A fresh top-level tab has no helper sessionStorage from the popup.
            replacement = context.new_page()
            replacement.goto(callbacks[0], wait_until='domcontentloaded')
        popup = wait_for_popup(context, page, stop_at_google=not case.startswith('callback_'))
        result['first_popup'] = classify(popup) if popup else 'none'
        if case.startswith('callback_'):
            result['synthetic_callback_used'] = bool(callbacks)
        if verify_recovery and case in ('callback_storage_lost', 'callback_new_context'):
            if not callbacks or result['first_popup'] != 'missing_initial_state':
                raise AssertionError('Controlled missing-state callback was not reached')
            page.wait_for_function("""() => {
              const text = document.body.innerText + [...document.querySelectorAll('[aria-label]')]
                .map(e => e.getAttribute('aria-label')).join(' ');
              return text.includes('Sign-in is taking longer than expected.');
            }""", timeout=35000)
            result['recovery_notice_visible'] = True
            result['second_attempt_locked'] = page.get_by_role(
                'button', name='Sign in with Google', exact=True).count() == 0
            if not result['second_attempt_locked']:
                raise AssertionError('Pending authentication allowed a second attempt')
            for login_page in list(context.pages):
                if login_page != page:
                    login_page.close()
            page.get_by_role('button', name='Sign in with Google', exact=True).wait_for(
                state='visible', timeout=15000)
            result['closing_popup_releases_attempt'] = True
            attempts = page.evaluate('window.__authProbe.opens.length')
            with page.expect_popup(timeout=15000) as retried:
                sign_in(page)
            result['fresh_retry_opens_popup'] = (
                not retried.value.is_closed()
                and page.evaluate('window.__authProbe.opens.length') == attempts + 1)
            retried.value.close()
        if case == 'close_retry' and popup:
            popup.close()
            page.get_by_role('button', name='Sign in with Google', exact=True).wait_for(
                state='visible', timeout=15000)
            sign_in(page)
            popup = wait_for_popup(context, page)
            result['retry_popup'] = classify(popup) if popup else 'none'
        result['app_state'] = classify(page)
        result['page_origins'] = sorted({origin(p.url) for p in context.pages})
        result['popup_attempts'] = page.evaluate('window.__authProbe.opens')
        if strict:
            assert_outcome(result)
        result['status'] = 'passed' if strict else 'observed'
    except BrowserTimeout:
        result['status'] = 'timeout'
        result['app_state'] = classify(page)
    except Exception as error:
        # Exception messages can embed OAuth URLs. Save only the class name.
        result['status'] = 'harness_error'
        result['error_type'] = type(error).__name__
    finally:
        result['firebase_js_versions'] = sorted(versions)
        result['browser_version'] = browser.version
        context.close()
    return result


def public_json(url):
    for attempt in range(3):
        try:
            with urlopen(url, timeout=20) as response:
                return json.load(response)
        except HTTPError as error:
            if error.code not in (408, 429, 500, 502, 503, 504) or attempt == 2:
                raise
            time.sleep(0.5)


def public_config(base=BASE, expected_source=None):
    manifest = public_json(base + 'release-manifest.json?auth-check=' + str(time.time_ns()))
    if expected_source and manifest.get('source') != expected_source:
        raise ValueError('Served build is not the expected source')
    # The web API key is a public project identifier, read from checked-in config.
    config = Path('lib/firebase_options.dart').read_text()
    key = re.search(r'web = FirebaseOptions\(\s*apiKey: \'([^\']+)\'', config).group(1)
    project = public_json('https://identitytoolkit.googleapis.com/v1/projects?key=' + key)
    return {'deployed_source': manifest['source'], 'flutter': manifest['flutter'],
            'authorized_domains': project['authorizedDomains']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--browsers', default='chromium,firefox,webkit')
    parser.add_argument('--base', type=validate_probe_base, default=BASE)
    parser.add_argument('--verify-recovery', action='store_true',
                        help='Assert the 30-second recovery notice and popup-close recovery on a fixed build')
    parser.add_argument('--cases', default=','.join(CASES))
    parser.add_argument('--assert-outcomes', action='store_true')
    parser.add_argument('--expected-source')
    parser.add_argument('--output', type=Path, default=Path('build/qa/google-auth/hosted.json'))
    args = parser.parse_args()
    browsers = args.browsers.split(',')
    cases = args.cases.split(',')
    strict_cases = {'cold', 'warm', 'popup_blocked', 'close_retry',
                    'callback_storage_lost', 'callback_new_context'}
    if len(set(browsers)) != len(browsers) or len(set(cases)) != len(cases) \
            or not set(browsers) <= {'chromium', 'firefox', 'webkit'} or not set(cases) <= set(CASES):
        parser.error('Unknown engine or case')
    if args.assert_outcomes and (not args.expected_source or not set(cases) <= strict_cases):
        parser.error('Strict checks require an expected source and cases with acceptance contracts')
    if args.assert_outcomes and set(cases) & {'callback_storage_lost', 'callback_new_context'} \
            and not args.verify_recovery:
        parser.error('Strict callback checks require --verify-recovery')
    try:
        config = public_config(args.base, args.expected_source)
    except Exception as error:
        config = {'status': 'unavailable', 'error_type': type(error).__name__}
    summary = {'started_utc': datetime.now(timezone.utc).isoformat(),
               'scope': 'desktop_pre_credential_only', 'physical_ios': 'unverified',
               'credential_exchange': 'unverified', 'base_origin': origin(args.base),
               'public_config': config,
               'results': []}
    args.output.parent.mkdir(parents=True, exist_ok=True)

    def save():
        args.output.write_text(json.dumps(summary, indent=2) + '\n')

    save()
    if config.get('status') == 'unavailable':
        summary['status'] = 'public_preflight_failed'
        save()
        raise SystemExit(1)
    with sync_playwright() as playwright:
        for name in browsers:
            try:
                with browser_session(playwright, name,
                                     local=urlsplit(args.base).hostname in ('localhost', '127.0.0.1')) as browser:
                    for case in cases:
                        print(f'{name}: {case}', flush=True)
                        result = run_case(browser, case, args.base, args.verify_recovery, args.assert_outcomes)
                        result['browser'] = name
                        summary['results'].append(result)
                        save()
                        print(json.dumps(result), flush=True)
            except Exception as error:
                summary['results'].append({'browser': name, 'status': 'engine_error',
                                           'error_type': type(error).__name__})
                save()
    summary['completed_utc'] = datetime.now(timezone.utc).isoformat()
    summary['status'] = 'observed'
    if args.assert_outcomes:
        try:
            validate_results(summary, browsers, cases=cases)
            summary['status'] = 'passed'
        except ValueError:
            summary['status'] = 'failed'
    save()
    if summary['status'] == 'failed' or any(
            r['status'] not in ('observed', 'passed') for r in summary['results']):
        raise SystemExit(1)


if __name__ == '__main__':
    main()
