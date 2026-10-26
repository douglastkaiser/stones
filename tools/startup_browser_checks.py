"""Startup fault/appearance checks and real loader-to-menu capture.

Requires the repository's Playwright Python harness and Chromium. Run from repo:
python tools/startup_browser_checks.py [--root build/web] [--real]
Screenshots, video and a machine-readable report go to build/qa/startup/.
"""
import argparse
import functools
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import re
import threading

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/qa/startup'


class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        self.path = re.sub(r'^/stones/', '/', self.path)
        try:
            return super().do_GET()
        except (ConnectionAbortedError, ConnectionResetError, BrokenPipeError):
            pass  # Fault scenarios deliberately close pending downloads.

    def log_message(self, *_args):
        pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', default='web')
    parser.add_argument('--real', action='store_true')
    parser.add_argument('--browser', choices=['chromium', 'firefox', 'webkit'], default='chromium')
    args = parser.parse_args()
    out = OUT / args.browser
    out.mkdir(parents=True, exist_ok=True)
    handler = functools.partial(Handler, directory=str(ROOT / args.root))
    server = ThreadingHTTPServer(('127.0.0.1', 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    url = f'http://127.0.0.1:{server.server_port}/stones/'
    bootstrap = (ROOT / 'web/flutter_bootstrap.js').read_text(encoding='utf-8')
    bootstrap = bootstrap.replace('{{flutter_js}}', '').replace('{{flutter_build_config}}', '')
    report = []
    try:
        with sync_playwright() as pw:
            browser = getattr(pw, args.browser).launch()

            def context(saved=None, system='light', storage=True, **kwargs):
                ctx = browser.new_context(color_scheme=system, **kwargs)
                ctx.add_init_script("""window.startupFrames = [];
                  const sample = () => {
                    const loader = document.getElementById('stones-loader');
                    window.startupFrames.push({time: performance.now(),
                      background: getComputedStyle(document.documentElement).getPropertyValue('--backdrop').trim(),
                      loader: !!loader && getComputedStyle(loader).opacity,
                      loaded: document.body?.classList.contains('loaded')});
                    if (!window.startupFinished) requestAnimationFrame(sample);
                  };
                  requestAnimationFrame(sample);
                  window.addEventListener('flutter-first-frame', () => {
                    window.firstFlutterFrame = performance.now();
                    setTimeout(() => window.startupFinished = true, 250);
                  });""")
                if storage:
                    ctx.add_init_script(f"localStorage.setItem('flutter.theme_mode', {json.dumps(json.dumps(saved))});")
                else:
                    ctx.add_init_script("Object.defineProperty(window, 'localStorage', {get() {throw new Error('Storage unavailable')}});")
                # Optional analytics/auth/audio downloads must never gate local UI.
                ctx.route(re.compile(r'^https://'), lambda route: route.continue_() if re.search(r'canvaskit|skwasm', route.request.url) else route.abort())
                return ctx

            for saved, system, expected in [
                (1, 'dark', '#EDE5D7'), (2, 'light', '#1B1816'),
                (0, 'dark', '#1B1816'), (None, 'light', '#EDE5D7'),
                (-1, 'dark', '#1B1816'), (999, 'light', '#EDE5D7'),
                ('2', 'light', '#EDE5D7'), (True, 'dark', '#1B1816'),
                (2.0, 'light', '#EDE5D7'),
            ]:
                with context(saved, system, viewport={'width': 280, 'height': 568}, reduced_motion='reduce') as ctx:
                    ctx.route(re.compile(r'flutter_bootstrap.*\.js'), lambda r: r.fulfill(body='window.bootstrapHeld = true;', content_type='text/javascript'))
                    page = ctx.new_page()
                    page.clock.install()
                    page.goto(url)
                    assert page.locator('#stones-loader').is_visible()
                    actual = page.evaluate("getComputedStyle(document.documentElement).getPropertyValue('--backdrop').trim()")
                    assert actual == expected, (saved, system, actual)
                    assert page.locator('.loading-spinner').evaluate("e => getComputedStyle(e).animationName") == 'none'
                    page.evaluate("document.documentElement.style.fontSize = '200%'")
                    assert page.locator('#stones-loader').evaluate('e => e.scrollWidth <= e.clientWidth')
                    assert page.locator('.wordmark').evaluate('e => e.scrollWidth <= e.clientWidth')
                    page.screenshot(path=str(out / f'loader-{type(saved).__name__}-{saved}-{system}.png'))
                    # Runner completion does not dismiss HTML; the real first-frame
                    # event is the only handoff signal, including after a long wait.
                    page.clock.fast_forward(15100)
                    assert page.get_by_role('button', name='Reload').is_visible()
                    assert 'Still loading' in page.get_by_role('status').inner_text()
                    page.evaluate("window.dispatchEvent(new Event('flutter-first-frame'))")
                    page.clock.run_for(350)
                    assert page.locator('#stones-loader').count() == 0
                    report.append({'case': 'appearance/reduced-motion/large-text/slow', 'saved': saved, 'system': system, 'passed': True})

            with context(system='dark', storage=False) as ctx:
                ctx.route(re.compile(r'flutter_bootstrap.*\.js'), lambda r: r.fulfill(body=''))
                page = ctx.new_page()
                page.goto(url)
                assert page.evaluate('document.documentElement.dataset.appearance') == 'dark'
                report.append({'case': 'unavailable-storage', 'passed': True})

            # Test the production bootstrap code with isolated engine/runner faults.
            for fault, load in {
                'loader-sync': "throw new Error('loader')",
                'loader-async': "return Promise.reject(new Error('loader'))",
                'engine': "o.onEntrypointLoaded({initializeEngine: async () => {throw new Error('engine')}})",
                'app': "o.onEntrypointLoaded({initializeEngine: async () => ({runApp: async () => {throw new Error('app')}})})",
                'success-waits-for-paint': "o.onEntrypointLoaded({initializeEngine: async () => ({runApp: async () => {window.runnerFinished = true}})})",
            }.items():
                with context() as ctx:
                    code = 'const _flutter = {loader: {load(o) {' + load + '}}};\n' + bootstrap
                    ctx.route(re.compile(r'flutter_bootstrap.*\.js'), lambda r, _request, code=code: r.fulfill(body=code, content_type='text/javascript'))
                    page = ctx.new_page()
                    page.goto(url)
                    if fault == 'success-waits-for-paint':
                        page.wait_for_function('window.runnerFinished')
                        assert page.locator('#stones-loader').is_visible()
                        assert 'Loading Stones' in page.get_by_role('status').inner_text()
                    else:
                        page.get_by_role('button', name='Reload').wait_for()
                        assert 'could not start' in page.get_by_role('status').inner_text()
                        with page.expect_navigation():
                            page.get_by_role('button', name='Reload').click()
                        assert page.locator('#stones-loader').is_visible()
                    report.append({'case': fault, 'passed': True})

            with context() as ctx:
                ctx.route(re.compile(r'flutter_bootstrap.*\.js'), lambda r: r.abort())
                page = ctx.new_page()
                page.goto(url)
                page.get_by_role('button', name='Reload').wait_for()
                assert 'could not start' in page.get_by_role('status').inner_text()
                page.screenshot(path=str(out / 'bootstrap-download-failure.png'))
                report.append({'case': 'bootstrap-download-failure', 'passed': True})

            if args.real:
                for saved, system, label, storage, width in [
                    (1, 'dark', 'light-phone', True, 320),
                    (2, 'light', 'dark-desktop', True, 1366),
                    (0, 'dark', 'system-phone', True, 320),
                    (999, 'light', 'invalid-desktop', True, 1366),
                    (None, 'dark', 'no-storage-phone', False, 320),
                ]:
                    with context(saved, system, storage, viewport={'width': width, 'height': 768},
                                 record_video_dir=str(out / 'video')) as ctx:
                        # Slow actual compiled entrypoint download without delaying
                        # optional services or introducing an application timeout.
                        ctx.route(re.compile(r'main\..*dart\.js'), lambda r: (page.wait_for_timeout(1200), r.continue_()))
                        page = ctx.new_page()
                        page.goto(url, wait_until='domcontentloaded')
                        page.locator('#stones-loader').wait_for()
                        page.screenshot(path=str(out / f'{label}-loading.png'))
                        page.wait_for_function('window.firstFlutterFrame', timeout=90000)
                        page.locator('#stones-loader').wait_for(state='detached')
                        page.screenshot(path=str(out / f'{label}-menu.png'))
                        frames = page.evaluate('window.startupFrames')
                        expected = '#1B1816' if saved == 2 or ((saved in (0, None) or not storage) and system == 'dark') else '#EDE5D7'
                        assert all(f['background'] == expected for f in frames)
                        first = page.evaluate('window.firstFlutterFrame')
                        assert all(not f['loaded'] and f['loader'] in (False, '1') for f in frames if f['time'] < first)
                        # Flutter's canvas semantics are opt-in. Capture and inspect
                        # pixels instead of assuming DOM text implies a painted menu.
                        report.append({'case': label, 'passed': True,
                                       'firstFrameMs': page.evaluate('window.firstFlutterFrame'),
                                       'video': str(page.video.path()), 'frames': frames})
            browser.close()
    finally:
        server.shutdown()
        (out / ('real-report.json' if args.real else 'loader-report.json')).write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(f'{len(report)} startup browser scenarios passed; evidence: {out}')


if __name__ == '__main__':
    main()
