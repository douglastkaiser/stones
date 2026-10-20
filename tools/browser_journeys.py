"""Real Chromium journeys, exclusively on a localhost emulator build.

Run via firebase emulators:exec. Browser contexts have separate identity/storage.
No production accounts, rooms or Analytics endpoints are allowed.
"""
import json
import hashlib
import os
from pathlib import Path
import re
import subprocess
import time
from urllib.request import urlopen

from playwright.sync_api import sync_playwright, expect, Error as PlaywrightError


BASE = 'http://127.0.0.1:4173/stones/'
EVIDENCE = Path('build/qa/journeys')
SDK_CACHE = Path('build/qa/firebase-sdk-cache')


def browser_request(route):
    url = route.request.url
    if any(host in url for host in [
        'firestore.googleapis.com', 'identitytoolkit.googleapis.com',
        'securetoken.googleapis.com', 'google-analytics.com',
        'googletagmanager.com', 'firebaseappcheck.googleapis.com',
    ]) and not url.startswith('http://127.0.0.1:'):
        route.abort()
    elif url.startswith('https://www.gstatic.com/firebasejs/') and url.endswith('.js'):
        # Reuse the exact public SDK bytes between independent contexts. Auth
        # and database traffic is never cached. This avoids repeated CDN loads
        # becoming a dependency of save/reload and identity-isolation checks.
        path = SDK_CACHE / (hashlib.sha256(url.encode()).hexdigest() + '.js')
        if path.exists():
            route.fulfill(status=200, body=path.read_bytes(),
                          content_type='application/javascript',
                          headers={'access-control-allow-origin': '*'})
        else:
            response = route.fetch(max_retries=2, timeout=30000)
            if response.status == 200:
                SDK_CACHE.mkdir(parents=True, exist_ok=True)
                temporary = path.with_suffix('.tmp')
                temporary.write_bytes(response.body())
                temporary.replace(path)
            route.fulfill(response=response)
    else:
        route.continue_()


def ai_profiles():
    profiles = {}
    for scope in ['overall', 'square-3-2-standardTak-open']:
        profiles[scope] = {}
        for level in ['easy', 'expert']:
            url = ('http://127.0.0.1:8088/v1/projects/demo-stones-hex/'
                   'databases/(default)/documents/skillPools/' + scope +
                   '/players/ai_shared-search-v1_' + level)
            with urlopen(url, timeout=10) as response:
                fields = json.load(response)['fields']
            profiles[scope][level] = {
                key: int(fields[key]['integerValue'])
                for key in ['rating', 'gamesPlayed', 'wins', 'losses', 'draws']
            }
    return profiles


def ready(page):
    page.locator('flt-glass-pane').wait_for(state='attached', timeout=60000)
    page.wait_for_function("""() => {
      const p = document.querySelector('flt-semantics-placeholder');
      if (p) p.click();
      return !!document.querySelector('flt-semantics');
    }""", timeout=60000)


def button(page, name):
    # Flutter merges a ListTile subtitle (or an open tooltip) into its name.
    if name == 'Back':
        return page.get_by_role('button', name=re.compile(r'^Back(?:\s+Back)?$'))
    return page.get_by_role('button', name=re.compile(rf'^{re.escape(name)}(?:\s|$)'))


def click(page, name):
    print(f'Journey action: {name}', flush=True)
    tap_target(page, button(page, name))


def tap_target(page, target):
    # Reacquire a semantics node if a route transition replaces it before input.
    # Never retry after sending the touch, which could commit a move twice.
    for attempt in range(5):
        try:
            target.scroll_into_view_if_needed()
            expect(target).to_be_visible()
            expect(target).to_be_enabled()
            bounds = target.bounding_box()
        except PlaywrightError as error:
            if 'not attached' not in str(error) or attempt == 4:
                raise
            continue
        if bounds is not None:
            break
    else:
        raise AssertionError('Control did not acquire stable bounds before touch')
    # Flutter dispatches touch coordinates through its canvas hit-test tree.
    # Empty DOM semantics nodes can overlap a control despite having no painted
    # surface. Exercise actual touch input and assert its effect in the journey.
    page.touchscreen.tap(bounds['x'] + bounds['width'] / 2,
                         bounds['y'] + bounds['height'] / 2)


def cell(page, x, y):
    return page.get_by_role('button', name=re.compile(rf'^Cell {x}, {y},')).first


def place(page, x, y):
    tap_target(page, cell(page, x, y))
    tap_target(page, cell(page, x, y))


def main():
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    server = subprocess.Popen(['node', 'tools/serve_web.mjs'],
                              env={**os.environ, 'WEB_ROOT': 'build/integration-web'},
                              stdout=subprocess.DEVNULL)
    try:
        for attempt in range(50):
            try:
                with urlopen(BASE, timeout=1) as response:
                    if response.status == 200:
                        break
            except OSError:
                time.sleep(.1)
        p = sync_playwright().start()
        executable = os.environ.get('STONES_CHROMIUM')
        launch = {'executable_path': executable} if executable else {}
        if os.environ.get('HTTPS_PROXY'):
            launch['proxy'] = {
                'server': os.environ['HTTPS_PROXY'],
                'bypass': 'localhost,127.0.0.1',
            }
        browser = p.chromium.launch(**launch)
        errors = []
        contexts = []
        def client():
            context = browser.new_context(viewport={'width': 390, 'height': 844},
                                          is_mobile=True, has_touch=True,
                                          service_workers='block')
            context.tracing.start(screenshots=True, snapshots=True)
            contexts.append(context)
            # Static Flutter/Firebase SDK assets may load externally, but all
            # auth/database requests must stay on the emulator.
            context.route('**/*', browser_request)
            page = context.new_page()
            page.on('pageerror', lambda error: errors.append(str(error)))
            page.goto(BASE)
            ready(page)
            return page

        host = client()
        click(host, 'Learn to play')
        click(host, 'Start learning')
        click(host, 'Let’s play')
        # First lesson: the single road gap is displayed in its objective.
        place(host, 1, 3)
        expect(host.get_by_role('button', name=re.compile('^Next lesson:'))).to_be_enabled()
        host.screenshot(path=str(EVIDENCE / 'lesson-phone.png'))
        host.get_by_role('button', name=re.compile('^Next lesson:')).tap()
        click(host, 'Let’s play')
        click(host, 'Back')
        expect(button(host, 'Continue learning')).to_be_visible()
        click(host, 'Back')

        host.get_by_role('button', name=re.compile('^Square')).tap()
        click(host, 'Same-device game')
        expect(cell(host, 0, 0)).to_be_visible()
        place(host, 0, 0)
        expect(cell(host, 0, 0)).to_have_accessible_name(re.compile('Charcoal flat'))
        host.reload()
        ready(host)
        click(host, 'My games')
        host.get_by_role('button', name=re.compile('Continue saved game')).tap()
        expect(cell(host, 0, 0)).to_have_accessible_name(re.compile('Charcoal flat'))
        host.screenshot(path=str(EVIDENCE / 'resumed-local-phone.png'))
        click(host, 'Resign')
        click(host, 'Ivory resigns')
        expect(button(host, 'Play again')).to_be_enabled()
        click(host, 'Review game')
        click(host, 'First position')
        expect(host.get_by_text('Move 0 of 1', exact=True)).to_be_visible()
        click(host, 'Back')
        click(host, 'Play again')
        expect(cell(host, 0, 0)).to_have_accessible_name(re.compile('empty'))
        click(host, 'Back')
        expect(host.get_by_text('Completed games on this device', exact=True)).to_be_visible()
        click(host, 'Back')

        host.get_by_role('button', name=re.compile('^Square')).tap()
        click(host, 'Online friend game')
        code_label = re.compile(r'^Room U[A-Z]{6}$')
        room_code = host.get_by_label(code_label).or_(host.get_by_text(code_label)).first
        expect(room_code).to_be_visible(timeout=30000)
        code = re.search(r'U[A-Z]{6}',
                         room_code.get_attribute('aria-label') or room_code.inner_text())[0]
        guest = client()
        guest.goto(BASE + '?room=' + code)
        ready(guest)
        click(guest, 'Join room')
        expect(cell(guest, 0, 0)).to_be_visible(timeout=30000)
        expect(host.get_by_text(re.compile('^Ivory to play'))).to_be_visible(timeout=30000)
        place(host, 0, 0)
        expect(cell(guest, 0, 0)).to_have_accessible_name(re.compile('Charcoal flat'), timeout=30000)
        expect(guest.get_by_text(re.compile('^Charcoal to play'))).to_be_visible(timeout=30000)
        contexts[1].set_offline(True)
        guest.wait_for_timeout(1000)
        contexts[1].set_offline(False)
        guest.reload()
        ready(guest)
        click(guest, 'Join room')
        expect(cell(guest, 0, 0)).to_have_accessible_name(re.compile('Charcoal flat'), timeout=30000)
        expect(guest.get_by_text(re.compile('^Charcoal to play'))).to_be_visible(timeout=30000)
        place(guest, 1, 0)
        expect(cell(host, 1, 0)).to_have_accessible_name(re.compile('Ivory flat'), timeout=30000)
        guest.screenshot(path=str(EVIDENCE / 'rejoined-friend-phone.png'))

        click(host, 'Back')
        click(host, 'Back')
        host.get_by_role('button', name=re.compile('^Square')).tap()
        click(host, 'Play the computer')
        expect(cell(host, 0, 0)).to_be_visible()
        place(host, 0, 0)
        expect(host.get_by_role('button', name=re.compile(r'^Cell .* flat,')))\
            .to_have_count(2, timeout=30000)
        expect(host.get_by_text(re.compile('^Ivory to play'))).to_be_visible(timeout=30000)
        host.screenshot(path=str(EVIDENCE / 'computer-reply-phone.png'))

        reporter = client()
        uid = reporter.evaluate("""async () => {
          const sdk = await import('https://www.gstatic.com/firebasejs/11.9.1/firebase-auth.js');
          const auth = sdk.getAuth();
          if (auth.app.options.projectId !== 'demo-stones-hex' ||
              auth.emulatorConfig?.host !== '127.0.0.1' || auth.emulatorConfig?.port !== 9099) {
            throw new Error('Rating fixture requires the local demo Auth emulator');
          }
          const result = await sdk.createUserWithEmailAndPassword(auth,
            `rating-qa-${Date.now()}@example.invalid`, 'local-emulator-only');
          await sdk.updateProfile(result.user, {displayName: 'Rating QA'});
          return result.user.uid;
        }""")
        # Seed a known legal completed replay, then let the actual app perform
        # source confirmation, both Firestore transactions and recovery.
        # No ratings or settlement documents are seeded by this harness.
        reporter.evaluate("""uid => {
          const moves = [[2,2],[0,0],[0,1],[2,1],[0,2]].map(([x,y], i) => ({
            seat: i % 2 === 0 ? 'ivory' : 'charcoal', x, y,
            type: 'flat', direction: null, drops: []
          }));
          const snapshot = {id: `local-ci-ai-only-${Date.now()}`, ratingUid: uid,
            config: {version: 1, ratingVersion: 3, shape: 'square', size: 3,
              profile: 'standardTak', starter: 'ivory', seats: [
                {id: 'ivory', control: 'ai', level: 'expert'},
                {id: 'charcoal', control: 'ai', level: 'easy'}]}, moves};
          localStorage.setItem('flutter.unified_local_match_v1',
            JSON.stringify(JSON.stringify(snapshot)));
        }""", uid)
        def resume_rated_fixture():
            reporter.reload()
            ready(reporter)
            expect(reporter.get_by_role('button', name=re.compile(r'\bRating QA\b'))).to_be_visible(timeout=30000)
            click(reporter, 'My games')
            click(reporter, 'Continue saved game')
            expect(reporter.get_by_text('Overall and format ratings recorded', exact=True))\
                .to_be_visible(timeout=45000)
        resume_rated_fixture()
        first = ai_profiles()
        for profiles in first.values():
            assert profiles['expert']['rating'] > 1200
            assert profiles['easy']['rating'] < 1200
            assert profiles['expert']['gamesPlayed'] == profiles['easy']['gamesPlayed'] == 1
        reporter.screenshot(path=str(EVIDENCE / 'ai-only-rated-phone.png'))
        resume_rated_fixture()
        assert ai_profiles() == first, 'Reopening a completed AI game awarded it twice'
        (EVIDENCE / 'ai-ratings.json').write_text(json.dumps(first, indent=2))
        click(reporter, 'Back')
        click(reporter, 'Back')
        click(reporter, 'Leaderboard')
        expect(reporter.get_by_text('Expert AI', exact=True)).to_be_visible(timeout=30000)
        expect(reporter.get_by_text('Easy AI', exact=True)).to_be_visible(timeout=30000)
        reporter.screenshot(path=str(EVIDENCE / 'ai-leaderboard-phone.png'))
        if errors:
            raise AssertionError(errors)
        (EVIDENCE / 'summary.json').write_text(json.dumps({
            'scope': 'Chromium desktop runner with phone viewport; demo emulators only',
            'journeys': ['guest lesson completion and next lesson', 'local save/reload',
                         'completion, read-only review and local rematch',
                         'cold invitation', 'independent clients', 'disconnect/rejoin',
                         'computer reply', 'signed-in AI-only settlement in both scopes',
                         'AI-only duplicate recovery'],
            'status': 'passed',
        }, indent=2))
    finally:
        if 'contexts' in locals():
            for i, context in enumerate(contexts):
                for page in context.pages:
                    try:
                        page.screenshot(path=str(EVIDENCE / f'last-client-{i}.png'))
                        (EVIDENCE / f'last-client-{i}.html').write_text(page.content())
                    except Exception:
                        pass
                context.tracing.stop(path=str(EVIDENCE / f'trace-client-{i}.zip'))
            (EVIDENCE / 'page-errors.json').write_text(json.dumps(errors, indent=2))
            browser.close()
            p.stop()
        server.terminate()
        server.wait(timeout=10)


if __name__ == '__main__':
    main()
