"""Two fresh Chromium clients verify temporary chat using localhost emulators.

Build tools/integration_app.dart for web, serve build/integration-web on port
4174, and start Auth (9099) / Firestore (8088) for demo-stones-hex first.
Requires Python Playwright and STONES_CHROMIUM (or its bundled Chromium).
Only localhost and public static SDK assets are allowed; never production data.
"""
import hashlib
import os
from pathlib import Path
import re
from urllib.request import urlopen

from playwright.sync_api import expect, sync_playwright

ROOT = Path(__file__).resolve().parents[1]
BASE = 'http://127.0.0.1:4174/stones/'
CACHE = ROOT / 'build/qa/firebase-sdk-cache'
EVIDENCE = ROOT / 'build/qa/chat'


def browser_request(route):
    url = route.request.url
    if url.startswith('http://127.0.0.1:'):
        route.continue_()
    elif url.startswith('https://www.gstatic.com/flutter-canvaskit/'):
        relative = url.split('flutter-canvaskit/')[1].split('/', 1)[1]
        path = ROOT / 'build/integration-web/canvaskit' / relative
        route.fulfill(path=str(path), content_type=(
            'application/wasm' if path.suffix == '.wasm'
            else 'application/javascript'))
    elif url.startswith('https://www.gstatic.com/firebasejs/') and url.endswith('.js'):
        path = CACHE / (hashlib.sha256(url.encode()).hexdigest() + '.js')
        if not path.exists():
            path.write_bytes(urlopen(url, timeout=30).read())
        route.fulfill(path=str(path), content_type='application/javascript',
                      headers={'Access-Control-Allow-Origin': '*'})
    else:
        route.abort()


def ready(page):
    page.locator('flt-semantics-placeholder').evaluate('(el) => el.click()', timeout=60000)
    expect(page.get_by_role('button', name='Audio settings')).to_be_visible(timeout=30000)


def tap(page, label):
    target = page.get_by_role('button', name=label, exact=False).first
    target.scroll_into_view_if_needed()
    expect(target).to_be_visible()
    bounds = target.bounding_box()
    # Tap above the emulator banner when a chat header sits at the bottom.
    offset = 12 if label == 'Game chat' else bounds['height'] / 2
    page.touchscreen.tap(bounds['x'] + bounds['width'] / 2, bounds['y'] + offset)


def open_chat(page):
    # Scroll outside the nested board controls using actual browser input.
    page.mouse.move(380, 250)
    page.mouse.wheel(0, 900)
    page.wait_for_timeout(700)
    tap(page, 'Game chat')
    page.wait_for_timeout(600)
    page.mouse.move(380, 250)
    page.mouse.wheel(0, 400)
    page.wait_for_timeout(400)
    expect(page.get_by_role('textbox', name='Message')).to_have_count(1)


def message(page):
    label = 'Ivory: Good game **** friend'
    return page.get_by_text(label, exact=True).or_(page.get_by_label(label, exact=True))


def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as playwright:
        executable = os.environ.get('STONES_CHROMIUM')
        browser = playwright.chromium.launch(**(
            {'executable_path': executable} if executable else {}))
        try:
            clients = []
            for _ in range(2):
                context = browser.new_context(
                    viewport={'width': 390, 'height': 844}, is_mobile=True,
                    has_touch=True, service_workers='block')
                context.route('**/*', browser_request)
                clients.append(context.new_page())
            host, guest = clients
            host.goto(BASE)
            ready(host)
            tap(host, 'Square')
            tap(host, 'Online friend game')
            pattern = re.compile('^Room U[A-Z]{6}$')
            code_node = host.get_by_label(pattern).or_(host.get_by_text(pattern)).first
            expect(code_node).to_be_visible(timeout=30000)
            code = re.search('U[A-Z]{6}', code_node.get_attribute('aria-label')
                             or code_node.inner_text())[0]
            guest.goto(BASE + '?room=' + code)
            ready(guest)
            tap(guest, 'Join room')
            cell = guest.get_by_role('button', name=re.compile('^Cell 0, 0,'))
            expect(cell).to_be_visible(timeout=30000)
            open_chat(host)
            open_chat(guest)
            host.get_by_role('textbox', name='Message').click()
            host.keyboard.type('Good game damn friend', delay=50)
            host.mouse.move(180, 500)
            host.mouse.wheel(0, 500)
            host.wait_for_timeout(400)
            tap(host, 'Send')
            expect(message(guest)).to_be_visible(timeout=20000)
            print('PASS: independent recipient received a masked message')
            guest.reload()
            ready(guest)
            tap(guest, 'Join room')
            expect(cell).to_be_visible(timeout=30000)
            open_chat(guest)
            guest.wait_for_timeout(4000)
            expect(message(guest)).to_have_count(0)
            print('PASS: rejoining does not restore chat history')
        finally:
            browser.close()


if __name__ == '__main__':
    main()
