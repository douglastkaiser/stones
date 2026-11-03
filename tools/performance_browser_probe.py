"""Release-web performance diagnostics in disposable local browser contexts.

Serve the selected build with tools/serve_web.mjs, then run:
  python tools/performance_browser_probe.py --label before --runs 5
  python tools/performance_browser_probe.py --label after --runs 5

Firefox defaults to the primary target's viewport. This runs desktop Firefox
with wheel input, not Android touch or a physical-device FPS qualification.
Only localhost and cached public Firebase SDK scripts are allowed. Account,
database and analytics traffic is blocked. No application instrumentation ships.
"""

import argparse
import hashlib
import json
import math
import os
import platform
import re
import time
from pathlib import Path
from urllib.parse import urlparse
from urllib.request import urlopen

from playwright.sync_api import expect, sync_playwright


SAMPLER = """(() => {
  let active = false, last = null, frames = [], inputs = [];
  let baseline = [];
  function frame(now) {
    if (last !== null) {
      const gap = now - last;
      if (active) frames.push(gap);
      else if (baseline.length < 120) baseline.push(gap);
    }
    last = now;
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
  addEventListener('pointerdown', () => {
    if (!active) return;
    const start = performance.now();
    requestAnimationFrame(() => requestAnimationFrame(() => {
      if (active) inputs.push(performance.now() - start);
    }));
  }, true);
  window.stonesPerf = {
    start(label) {
      performance.mark(label + '-start');
      frames = []; inputs = []; last = null; active = true;
    },
    stop(label) {
      active = false;
      performance.mark(label + '-end');
      performance.measure(label, label + '-start', label + '-end');
      return {frames, inputs, baseline, visibility: document.visibilityState};
    }
  };
})();"""


def percentile(values, fraction):
    return sorted(values)[max(0, math.ceil(len(values) * fraction) - 1)] if values else None


def summarize(sample):
    frames = sample['frames']
    refresh = percentile(sample['baseline'], .5)
    return {
        'animationFrameSamples': len(frames),
        'idleMedianAnimationFrameMs': refresh,
        'p50AnimationFrameGapMs': percentile(frames, .5),
        'p95AnimationFrameGapMs': percentile(frames, .95),
        'maxAnimationFrameGapMs': max(frames, default=None),
        'gapsOver50Ms': sum(gap > 50 for gap in frames),
        'gapsOver100Ms': sum(gap > 100 for gap in frames),
        'inputToSecondAnimationFrameMs': sample['inputs'],
        'visibility': sample['visibility'],
    }


def local_requests(route):
    url = route.request.url
    parsed = urlparse(url)
    if parsed.hostname in ('127.0.0.1', 'localhost'):
        route.continue_()
    elif (parsed.hostname == 'www.gstatic.com' and
          parsed.path.startswith('/firebasejs/') and parsed.path.endswith('.js') and
          route.request.method == 'GET'):
        # urllib uses the executor's configured proxy/CA. Playwright's request
        # client otherwise tries to reach public SDK hosts directly on this host.
        cache = Path('build/qa/performance/sdk-cache')
        cache.mkdir(parents=True, exist_ok=True)
        path = cache / (hashlib.sha256(url.encode()).hexdigest() + '.js')
        if not path.exists():
            with urlopen(url, timeout=30) as response:
                path.write_bytes(response.read())
        route.fulfill(body=path.read_bytes(), content_type='application/javascript',
                      headers={'access-control-allow-origin': '*'})
    else:
        route.abort()


def ready(page):
    page.locator('flt-glass-pane').wait_for(state='attached', timeout=60000)
    page.wait_for_function("""() => {
      document.querySelector('flt-semantics-placeholder')?.click();
      return !!document.querySelector('flt-semantics');
    }""")
    expect(button(page, 'Settings & account')).to_be_visible()


def button(page, name):
    return page.get_by_role('button', name=re.compile(
        rf'^{re.escape(name)}(?:\s|$)')).first


def reveal(page, target, direction=1):
    width, height = page.viewport_size.values()
    for _ in range(70):
        delta = direction * 200
        if target.count():
            bounds = target.bounding_box()
            if bounds:
                point = [bounds['x'] + bounds['width'] / 2,
                         bounds['y'] + bounds['height'] / 2]
                if (0 < point[0] < width and 65 < point[1] < height - 45 and
                        target.evaluate(
                            '(e,p) => e.contains(document.elementFromPoint(...p))', point)):
                    return target
                delta = max(-240, min(240, point[1] - height / 2))
        page.mouse.move(width / 2, height / 2)
        page.mouse.wheel(0, delta)
        page.wait_for_timeout(80)
    raise AssertionError(f'Could not reveal {target}')


def measure(page, name, action):
    # Exclude route/modal transitions and pending preview preparation from the
    # warmed-scroll sample. Cold app startup remains a separate observation.
    page.wait_for_timeout(1000)
    print(f'  measuring {name}', flush=True)
    page.evaluate('(n) => window.stonesPerf.start(n)', name)
    action()
    page.wait_for_timeout(120)
    raw = page.evaluate('(n) => window.stonesPerf.stop(n)', name)
    result = {'scenario': name, **summarize(raw), 'raw': raw}
    print(f"    p95 rAF gap: {result['p95AnimationFrameGapMs']:.1f} ms", flush=True)
    return result


def scroll(page, steps=24, delta=45):
    page.mouse.move(page.viewport_size['width'] / 2,
                    page.viewport_size['height'] / 2)
    for index in range(steps):
        page.mouse.wheel(0, delta if index % 40 < 20 else -delta)
        page.wait_for_timeout(16)


def run(args):
    if urlparse(args.url).hostname not in ('127.0.0.1', 'localhost'):
        raise ValueError('Use a local release build; this probe does not exercise production accounts')
    output = Path(args.output) / args.label
    output.mkdir(parents=True, exist_ok=True)
    result = {
        'label': args.label, 'url': args.url, 'host': platform.platform(),
        'scope': 'Desktop browser, software graphics, wheel input; not Android FPS',
        'viewport': [390, 844], 'semanticsEnabled': True,
        'sdkCache': 'Public SDK bytes reused between runs; browser contexts are fresh',
        'inputMetric': 'Pointer dispatch to second rAF; proxy, not verified visible response',
        'runs': [],
        'scrollSteps': args.scroll_steps,
        'scenarioSettlingWaitMs': 1000,
        'scenarioScope': 'Warmed scrolling after a fixed settling interval; excludes navigation/cold-preview preparation',
        'artifact': {
            'root': str(Path(args.web_root).resolve()),
            'sha256': {
                name: hashlib.sha256((Path(args.web_root) / name).read_bytes()).hexdigest()
                for name in ('main.dart.js', 'flutter_bootstrap.js')
            },
        },
    }
    with sync_playwright() as playwright:
        launch = {}
        if args.firefox_profile:
            if args.browser != 'firefox':
                raise ValueError('--firefox-profile requires --browser firefox')
            launch['env'] = {
                **os.environ,
                'MOZ_PROFILER_STARTUP': '1',
                'MOZ_PROFILER_STARTUP_FEATURES': 'js,stackwalk,cpu',
                'MOZ_PROFILER_STARTUP_FILTERS': 'GeckoMain,Compositor,Renderer',
                'MOZ_PROFILER_SHUTDOWN': str((output / 'firefox-profile.json').resolve()),
            }
            result['profilingEnabled'] = True
        if args.browser == 'chromium' and args.chromium_path:
            launch['executable_path'] = args.chromium_path
        browser = getattr(playwright, args.browser).launch(**launch)
        result['browser'] = {'engine': args.browser, 'version': browser.version}
        for index in range(args.runs):
            context = browser.new_context(viewport={'width': 390, 'height': 844},
                                          device_scale_factor=1)
            context.route('**/*', local_requests)
            context.add_init_script(SAMPLER)
            page = context.new_page()
            page.set_default_timeout(15000)
            errors = []
            page.on('pageerror', lambda error: errors.append(str(error)))
            entry = {'run': index + 1, 'scenarios': [], 'pageErrors': errors}
            result['runs'].append(entry)
            print(f'{args.label} {args.browser} run {index + 1}/{args.runs}', flush=True)
            try:
                for mode in ('freshContext', 'reload'):
                    print(f'  {mode} loading', flush=True)
                    started = time.perf_counter()
                    page.goto(args.url) if mode == 'freshContext' else page.reload()
                    ready(page)
                    print(f'  {mode} ready', flush=True)
                    entry[mode + 'ToReadyMs'] = (time.perf_counter() - started) * 1000
                    # Menu readiness deliberately precedes optional audio setup.
                    # Let that setup finish before reloading, so this benchmark
                    # does not inject aborted audio requests into the next run.
                    page.wait_for_function("""() => performance.getEntriesByType('resource')
                      .some(e => e.name.includes('landing_marble_heavy.ogg'))""")
                page.wait_for_timeout(600)
                button(page, 'Settings & account').click()
                print('  settings opened', flush=True)
                reveal(page, button(page, 'Preview Porto'))
                print('  gallery revealed', flush=True)
                entry['scenarios'].append(measure(page, 'settings-gallery-scroll', lambda: scroll(page, steps=args.scroll_steps)))
                reveal(page, button(page, 'Preview Porto'), -1).click()
                expect(page.get_by_role('alertdialog')).to_be_visible()
                print('  preview opened', flush=True)
                entry['scenarios'].append(measure(page, 'settings-dialog-scroll', lambda: scroll(page, steps=args.scroll_steps, delta=18)))
                button(page, 'Close').click()
                # Older comparison artifacts have category tabs; current main
                # exposes independent board/piece actions in one gallery.
                pieces_tab = page.get_by_role('button', name='Pieces', exact=True)
                if pieces_tab.count():
                    reveal(page, pieces_tab, -1).click()
                entry['galleryLayout'] = 'categoryTabs' if pieces_tab.count() else 'unified'
                reveal(page, button(page, 'Preview Jaipur')).click()
                expect(page.get_by_role('alertdialog')).to_be_visible()
                button(page, 'Close').click()
                button(page, 'Back').click()

                # Exercise both real match paths before remeasuring settings.
                for shape in ('Square', 'Hex'):
                    print(f'  {shape} match', flush=True)
                    button(page, shape).click()
                    button(page, 'Same-device game').click()
                    button(page, 'Start game').click()
                    replacement = button(page, 'Start new game')
                    if replacement.count():
                        replacement.click()
                    expect(button(page, 'Cell 0, 0,')).to_be_visible()
                    button(page, 'Cell 0, 0,').click()
                    button(page, 'Confirm').click()
                    expect(button(page, 'Confirm')).to_have_count(0)
                    button(page, 'Back').click()
                    button(page, 'Back').click()
                button(page, 'Settings & account').click()
                reveal(page, button(page, 'Preview Porto'))
                entry['scenarios'].append(measure(page, 'settings-postgame-scroll', lambda: scroll(page, steps=args.scroll_steps)))
                button(page, 'Back').click()
                for label in ('Achievements & piece sets', 'Learn', 'My games', 'Leaderboard'):
                    print(f'  {label}', flush=True)
                    button(page, label).click()
                    entry['scenarios'].append(measure(page, label.lower() + '-scroll', lambda: scroll(page, steps=args.scroll_steps)))
                    button(page, 'Back').click()
                entry['resources'] = page.evaluate("""() => ({
                  userAgent: navigator.userAgent,
                  devicePixelRatio,
                  domElements: document.querySelectorAll('*').length,
                  resourceCount: performance.getEntriesByType('resource').length,
                  resourceTransferBytes: performance.getEntriesByType('resource')
                    .reduce((sum, e) => sum + e.transferSize, 0),
                  jsHeapBytes: performance.memory?.usedJSHeapSize ?? null
                })""")
                assert not errors, errors
                entry['status'] = 'passed'
            except Exception as error:
                entry['status'] = 'failed'
                entry['error'] = str(error)
                print(f'  failed: {error}', flush=True)
                page.screenshot(path=str(output / f'failure-{index + 1}.png'), timeout=5000)
                (output / f'failure-{index + 1}.txt').write_text(page.locator('body').aria_snapshot())
                raise
            finally:
                (output / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
                context.close()
        browser.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--url', default='http://127.0.0.1:4173/stones/')
    parser.add_argument('--label', required=True)
    parser.add_argument('--runs', type=int, default=5)
    parser.add_argument('--scroll-steps', type=int, default=12)
    parser.add_argument('--web-root', default='build/web',
                        help='The served artifact directory, for content hashes')
    parser.add_argument('--browser', choices=['firefox', 'chromium'], default='firefox')
    parser.add_argument('--chromium-path', help='Optional system Chromium executable')
    parser.add_argument('--firefox-profile', action='store_true',
                        help='Save a separate diagnostic Firefox profile; adds measurement overhead')
    parser.add_argument('--output', default='build/qa/performance')
    options = parser.parse_args()
    if options.runs < 1:
        parser.error('--runs must be positive')
    run(options)
