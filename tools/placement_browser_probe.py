"""Local release-browser placement/audio/settings checks. No production writes.

Run tools/serve_web.mjs first, then python3 tools/placement_browser_probe.py.
Playback promises verify browser decoding/playback, not perceived audio quality.
"""

import json
import os
from pathlib import Path
import re

from playwright.sync_api import sync_playwright, expect
from adaptive_browser_probe import local_request
from browser_journeys import ready


EVIDENCE = Path('build/qa/landings/browser')
MEDIA_PROBE = """(() => {
  window.landingMedia = [];
  window.landingElements = [];
  const load = HTMLMediaElement.prototype.load;
  HTMLMediaElement.prototype.load = function(...args) {
    window.landingElements.push(this);
    return load.apply(this, args);
  };
  const original = HTMLMediaElement.prototype.play;
  HTMLMediaElement.prototype.play = function(...args) {
    const entry = {path: new URL(this.currentSrc || this.src, location.href).pathname,
                   at: performance.now(), started: false};
    window.landingMedia.push(entry);
    const result = original.apply(this, args);
    result.then(() => entry.started = true, error => entry.error = error.name);
    return result;
  };
})();"""
CONTACTS = "() => window.landingMedia.filter(x => /landing_/.test(x.path))"


def run():
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    results = []
    (EVIDENCE / 'results.json').write_text(json.dumps({'status': 'running'}))
    with sync_playwright() as playwright:
        launch = {}
        if os.environ.get('HTTPS_PROXY'):
            launch['proxy'] = {'server': os.environ['HTTPS_PROXY'],
                               'bypass': '127.0.0.1,localhost'}
        browser = playwright.chromium.launch(**launch)
        for shape in ('Square', 'Hex'):
            for width, height in ((390, 844), (1366, 900)):
                name = f'{shape.lower()}-{width}x{height}'
                print(name, flush=True)
                touch = width < 700
                context = browser.new_context(viewport={'width': width, 'height': height},
                                              has_touch=touch)
                context.route('**/*', local_request)
                context.add_init_script(MEDIA_PROBE)
                page = context.new_page()
                errors = []
                page.on('pageerror', lambda error: errors.append(str(error)))
                page.set_default_timeout(15000)

                def button(label):
                    return page.get_by_role('button', name=re.compile(
                        rf'^{re.escape(label)}(?:\s|$)')).first

                def tap(target):
                    target.scroll_into_view_if_needed()
                    expect(target).to_be_enabled()
                    bounds = target.bounding_box()
                    point = [bounds['x'] + bounds['width'] / 2,
                             bounds['y'] + bounds['height'] / 2]
                    assert target.evaluate(
                        '(e, p) => e.contains(document.elementFromPoint(...p))', point)
                    (page.touchscreen.tap if touch else page.mouse.click)(*point)

                def cell(x, y):
                    return button(f'Cell {x}, {y},')

                def place(x, y):
                    tap(cell(x, y))
                    tap(button('Confirm'))
                    expect(button('Confirm')).to_have_count(0)

                def wait_contacts(count):
                    try:
                        page.wait_for_function(
                            'n => window.landingMedia.filter(x => /landing_/.test(x.path) && x.started).length === n',
                            arg=count)
                    except Exception:
                        print(page.evaluate('window.landingMedia'), flush=True)
                        print(page.locator('body').aria_snapshot(), flush=True)
                        raise

                def motion_switch():
                    return page.get_by_role('switch', name=re.compile('^Placement animations'))

                def audio_ready():
                    # Audio startup is deliberately independent of gameplay.
                    # Wait for the final preloaded asset when qualifying playback.
                    page.wait_for_function('''() => window.landingElements.some(
                      e => /landing_marble_heavy/.test(e.src) && e.readyState >= 2)''')

                page.goto('http://127.0.0.1:4173/stones/')
                ready(page)
                tap(button('Settings & account'))
                expect(motion_switch()).to_be_checked()
                expect(page.get_by_role('switch', name='Sound effects', exact=True)).to_be_checked()
                tap(button('Back'))
                tap(button(shape))
                tap(button('Same-device game'))
                tap(button('Start game'))
                expect(cell(0, 0)).to_be_visible()
                audio_ready()
                # Hex's default opening has three seats; Square has two.
                count = 2 if shape == 'Square' else 3
                for x in range(count):
                    place(x, 0)
                    wait_contacts(x + 1)
                tap(cell(count - 1, 0))
                tap(cell(count - 2, 0))
                expect(button('Confirm move')).to_be_enabled()
                tap(button('Undo last drop'))
                tap(cell(count - 2, 0))
                tap(button('Confirm move'))
                wait_contacts(count + 1)
                expect(cell(count - 2, 0)).to_have_accessible_name(
                    re.compile(rf'^Cell {count - 2}, 0, Oak flat, 2 pieces'))
                # Muting in-match must suppress the next contact.
                if touch:
                    tap(button('Match options'))
                    tap(page.get_by_role('menuitem', name='Audio settings'))
                else:
                    tap(button('Audio settings'))
                tap(page.get_by_role('switch', name='Sound effects', exact=True))
                page.keyboard.press('Escape')
                place(0, 1)
                page.wait_for_timeout(450)
                assert len(page.evaluate(CONTACTS)) == count + 1
                page.reload()
                ready(page)
                tap(button('Settings & account'))
                tap(motion_switch())
                expect(motion_switch()).not_to_be_checked()
                effects = page.get_by_role('switch', name='Sound effects', exact=True)
                expect(effects).not_to_be_checked()
                tap(effects)  # Audio on while animation remains off.
                page.reload()
                ready(page)
                tap(button('Settings & account'))
                expect(motion_switch()).not_to_be_checked()
                expect(page.get_by_role('switch', name='Sound effects', exact=True)).to_be_checked()
                tap(button('Back'))
                tap(button('My games'))
                tap(button('Continue saved game'))
                expect(cell(count - 2, 0)).to_have_accessible_name(
                    re.compile(rf'^Cell {count - 2}, 0, Oak flat, 2 pieces'))
                assert page.evaluate(CONTACTS) == []  # Restore cannot sound like a move.
                if button('Resume match').count():
                    tap(button('Resume match'))
                audio_ready()
                place(1, 1)
                wait_contacts(1)
                page.wait_for_timeout(400)
                media = page.evaluate(CONTACTS)
                assert len(media) == 1 and not media[0].get('error'), media
                assert not errors, errors
                page.screenshot(path=str(EVIDENCE / f'{name}.png'))
                results.append({'case': name, 'browser': browser.version,
                                'defaultOn': True, 'spreadUndo': True,
                                'muteIndependent': True, 'savedAnimationOff': True,
                                'restoreSilent': True, 'decodedContact': media,
                                'errors': errors})
                (EVIDENCE / 'results.json').write_text(json.dumps(results, indent=2))
                context.close()
        browser.close()


if __name__ == '__main__':
    run()
