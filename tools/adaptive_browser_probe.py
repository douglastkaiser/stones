"""Local release-build gameplay trials. Browser contexts are disposable.

Run tools/serve_web.mjs first. Production backend requests are blocked.
These are browser viewport checks, not physical-device qualification.
"""
import json
import os
from pathlib import Path
import re
from playwright.sync_api import sync_playwright, expect
from browser_journeys import browser_request, ready

EVIDENCE = Path('build/qa/adaptive-browser')


def local_request(route):
    # Use the renderer bytes bundled with this build, avoiding CDN trust/network
    # differences in isolated browser profiles. Production traffic stays blocked.
    renderer = re.fullmatch(r'https://www\.gstatic\.com/flutter-canvaskit/[a-f0-9]+/((?:chromium/)?canvaskit\.(?:js|wasm))', route.request.url)
    if renderer:
        path = Path('build/web/canvaskit') / renderer.group(1)
        route.fulfill(body=path.read_bytes(),
                      content_type='application/wasm' if path.suffix == '.wasm' else 'application/javascript',
                      headers={'access-control-allow-origin': '*'})
    else:
        browser_request(route)


def run():
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    results = []
    with sync_playwright() as playwright:
        for engine_name in os.environ.get('STONES_BROWSERS', 'chromium').split(','):
            engine = getattr(playwright, engine_name)
            launch = {}
            if os.environ.get('HTTPS_PROXY'):
                launch['proxy'] = {'server': os.environ['HTTPS_PROXY'], 'bypass': '127.0.0.1,localhost'}
            browser = engine.launch(**launch)
            for shape, count in [('Square', 2), ('Hex', 3)]:
                for width, height in [(320, 568), (390, 844), (844, 390), (1366, 900)]:
                    name = f'{engine_name}-{shape.lower()}-{width}x{height}'
                    if not re.search(os.environ.get('STONES_CASES', '.*'), name):
                        continue
                    print(name, flush=True)
                    touch = engine_name == 'chromium'
                    context = browser.new_context(viewport={'width': width, 'height': height}, has_touch=touch)
                    context.route('**/*', local_request)
                    page = context.new_page()
                    errors = []
                    page.on('pageerror', lambda error: errors.append(str(error)))

                    def button(label):
                        return page.get_by_role('button', name=re.compile(rf'^{re.escape(label)}(?:\s|$)')).first

                    def tap(target, pinned=False):
                        if not pinned:
                            target.scroll_into_view_if_needed()
                        expect(target).to_be_enabled()
                        box = target.bounding_box()
                        if pinned:
                            assert box and box['y'] >= 0 and box['y'] + box['height'] <= page.viewport_size['height'] + 1, box
                        point = (box['x'] + box['width'] / 2, box['y'] + box['height'] / 2)
                        assert target.evaluate('(e, [x,y]) => e.contains(document.elementFromPoint(x,y))', point), target.inner_text()
                        if touch:
                            page.touchscreen.tap(*point)
                        else:
                            page.mouse.click(*point)

                    def cell(x, y):
                        return button(f'Cell {x}, {y},')

                    page.goto('http://127.0.0.1:4173/stones/')
                    ready(page)
                    tap(button(shape))
                    tap(button('Same-device game'))
                    expect(cell(0, 0)).to_be_visible()
                    for x in range(count):
                        tap(cell(x, 0))
                        tap(button('Confirm'), pinned=True)
                        expect(button('Confirm')).to_have_count(0)
                    tap(cell(count - 1, 0))
                    tap(cell(count - 2, 0))
                    expect(button('Confirm move')).to_be_enabled()
                    tap(button('Board view'), pinned=True)
                    tap(page.get_by_role('menuitem', name='Zoom in for precise play'))
                    expect(page.get_by_text(re.compile(r'^Board zoom (?!100)\d+ percent$'))).to_have_count(1)
                    page.wait_for_timeout(300)  # Let Flutter button/menu transitions settle.
                    page.screenshot(path=str(EVIDENCE / f'{name}-zoom.png'))
                    tap(button('Board view'), pinned=True)
                    tap(page.get_by_role('menuitem', name='Fit board'))
                    page.set_viewport_size({'width': height, 'height': width})
                    page.wait_for_timeout(500)  # Allow Flutter to lay out the rotated surface.
                    expect(button('Confirm move')).to_be_enabled()
                    tap(button('Undo last drop'), pinned=True)
                    page.wait_for_timeout(300)
                    tap(cell(count - 2, 0))
                    page.wait_for_timeout(300)  # Let Flutter button/menu transitions settle.
                    page.screenshot(path=str(EVIDENCE / f'{name}-rotated.png'))
                    tap(button('Confirm move'), pinned=True)
                    expect(button('Confirm move')).to_have_count(0)
                    page.set_viewport_size({'width': width, 'height': height})
                    page.reload()
                    ready(page)
                    tap(button('My games'))
                    tap(button('Continue saved game'))
                    expect(button(f'Cell {count - 2}, 0, Ivory flat, 2 pieces')).to_be_visible()
                    assert not errors, errors
                    page.wait_for_timeout(300)  # Let Flutter button/menu transitions settle.
                    page.screenshot(path=str(EVIDENCE / f'{name}-confirmed.png'))
                    results.append({'case': name, 'browser': browser.version, 'errors': errors,
                                    'placement': True, 'spreadUndo': True, 'zoom': True,
                                    'rotation': True, 'reload': True})
                    (EVIDENCE / 'results.json').write_text(json.dumps(results, indent=2))
                    context.close()
            browser.close()


if __name__ == '__main__':
    run()
