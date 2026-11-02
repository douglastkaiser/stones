"""Local release-browser cosmetics checks; production backend requests are blocked.

Serve a release build using tools/serve_web.mjs, then run this script. Contexts
are disposable. This covers locked previews and navigation; earned selection,
owner eligibility and mixed palettes are exercised by the Flutter regressions.
"""
import json
import os
from pathlib import Path
import re
from playwright.sync_api import sync_playwright, expect
from browser_journeys import browser_request, ready

EVIDENCE = Path('build/qa/cities/browser')


def run():
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    results = []
    with sync_playwright() as playwright:
        launch = {}
        if os.environ.get('HTTPS_PROXY'):
            launch['proxy'] = {'server': os.environ['HTTPS_PROXY'],
                               'bypass': '127.0.0.1,localhost'}
        browser = playwright.chromium.launch(**launch)
        for width, height in [(390, 844), (1366, 900)]:
            context = browser.new_context(viewport={'width': width, 'height': height})
            context.route('**/*', browser_request)
            page = context.new_page()
            page.set_default_timeout(15000)
            errors = []
            page.on('pageerror', lambda error: errors.append(str(error)))

            def button(name):
                return page.get_by_role('button', name=name, exact=True)

            def reveal(name, direction=1):
                # Flutter owns scrolling. Native DOM scrollIntoView cannot reveal
                # a semantics node that is just outside the painted viewport.
                for _ in range(45):
                    target = button(name)
                    delta = direction * 180
                    if target.count():
                        bounds = target.bounding_box()
                        if bounds:
                            center = [bounds['x'] + bounds['width'] / 2,
                                      bounds['y'] + bounds['height'] / 2]
                            in_view = (0 < center[0] < width and
                                       75 < center[1] < height - 40)
                            if in_view and target.evaluate(
                                    '(e, p) => e.contains(document.elementFromPoint(...p))', center):
                                return target
                            delta = max(-180, min(180, center[1] - height / 2))
                    page.mouse.move(width * .5, height * .5)
                    page.mouse.wheel(0, delta)
                    page.wait_for_timeout(180)
                raise AssertionError(f'Could not reveal {name}')

            def saved():
                return page.evaluate("""() => ['cosmetics_board_theme', 'cosmetics_piece_style']
                  .map(key => localStorage.getItem('flutter.' + key))""")

            print(f'{width}x{height}: opening app', flush=True)
            page.goto('http://127.0.0.1:4173/stones/')
            ready(page)
            print(f'{width}x{height}: app ready', flush=True)
            page.get_by_role('button', name=re.compile('^Settings & account')).click()
            expect(page.get_by_role('heading', name='Settings', exact=True)).to_be_visible()
            initial = saved()
            print(f'{width}x{height}: inspecting Marrakesh', flush=True)
            preview = reveal('Preview Marrakesh')
            if width >= 1000:
                preview.focus()
                preview.press('Enter')
            else:
                preview.click()
            expect(page.get_by_role('alertdialog')).to_be_visible()
            content = ''
            for _ in range(18):
                content += page.locator('body').aria_snapshot()
                if all(value in content for value in [
                    'Marrakesh square board', 'Marrakesh hex board',
                    'Oak wall', 'Charred Oak capstone', 'Port Wine flat',
                    'Atlantic Blue capstone']):
                    break
                page.mouse.move(width * .5, height * .5)
                page.mouse.wheel(0, 180)
                page.wait_for_timeout(120)
            for value in ['Unlock by completing either:', 'Marrakesh square board',
                          'Marrakesh hex board', 'Atlantic Blue capstone']:
                assert value in content, value
            page.screenshot(path=str(EVIDENCE / f'four-player-preview-{width}.png'))
            button('Close').click()
            expect(page.get_by_role('alertdialog')).to_have_count(0)
            print(f'{width}x{height}: switching to pieces', flush=True)
            reveal('Pieces', direction=-1).click()
            print(f'{width}x{height}: inspecting Jaipur', flush=True)
            reveal('Preview Jaipur').click()
            expect(page.get_by_role('alertdialog')).to_be_visible()
            assert 'current #1 established human' in page.locator('body').aria_snapshot()
            page.screenshot(path=str(EVIDENCE / f'jaipur-requirement-{width}.png'))
            button('Close').click()
            expect(page.get_by_role('alertdialog')).to_have_count(0)
            assert saved() == initial, 'Read-only previews changed selections'
            assert not errors, errors
            results.append({'viewport': [width, height], 'status': 'passed', 'pageErrors': errors,
                            'checks': ['Board/Pieces navigation', 'locked requirements',
                                       'four players and three types', 'Square and Hex previews',
                                       'Jaipur temporary requirement', 'no preference writes'] +
                                      (['keyboard preview activation'] if width >= 1000 else [])})
            print(f'{width}x{height}: passed', flush=True)
            context.close()
        browser.close()
    (EVIDENCE / 'results.json').write_text(json.dumps(results, indent=2))


if __name__ == '__main__':
    run()
