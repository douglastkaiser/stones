"""Real local playback checks: python tools/music_browser_checks.py --browser chromium.

Only localhost resources are allowed. Probes observe native media elements and
Web Audio gains; they do not replace playback or bypass browser autoplay policy.
"""
import argparse
import functools
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import threading

from playwright.sync_api import expect, sync_playwright

ROOT = Path(__file__).resolve().parents[1]
HOOK = """window.stonesMusicNodes = [];
window.stonesBufferNodes = [];
const assets = new Map(), decoded = new WeakMap();
const fingerprint = data => Array.from(new Uint8Array(data).subarray(0, 512)).join(',');
const remember = (data, url) => { if (url.includes('/sounds/music/')) assets.set(fingerprint(data), url); };
const responseBuffer = Response.prototype.arrayBuffer;
Response.prototype.arrayBuffer = function() {
  return responseBuffer.call(this).then(data => { remember(data, this.url); return data; });
};
const open = XMLHttpRequest.prototype.open;
XMLHttpRequest.prototype.open = function(method, url, ...args) {
  this.addEventListener('load', () => { if (this.response instanceof ArrayBuffer) remember(this.response, String(url)); });
  return open.call(this, method, url, ...args);
};
const decode = AudioContext.prototype.decodeAudioData;
AudioContext.prototype.decodeAudioData = function(data, ...args) {
  const url = assets.get(fingerprint(data)) || '';
  return decode.call(this, data, ...args).then(buffer => { decoded.set(buffer, url); return buffer; });
};
const source = AudioContext.prototype.createMediaElementSource;
AudioContext.prototype.createMediaElementSource = function(element) {
  this.stonesElement = element; return source.call(this, element);
};
const gain = AudioContext.prototype.createGain;
AudioContext.prototype.createGain = function() {
  const node = gain.call(this);
  window.stonesMusicNodes.push({element: this.stonesElement, gain: node, context: this});
  return node;
};
const bufferSource = AudioContext.prototype.createBufferSource;
AudioContext.prototype.createBufferSource = function() {
  const node = bufferSource.call(this), context = this;
  const record = {node, context, playing: false, at: 0, offset: 0, id: stonesBufferNodes.length};
  stonesBufferNodes.push(record);
  const connect = node.connect, start = node.start, stop = node.stop;
  node.connect = function(destination, ...args) { record.gain = destination; return connect.call(this, destination, ...args); };
  node.start = function(when = 0, offset = 0, ...args) { record.playing = true; record.at = context.currentTime; record.offset = offset; return start.call(this, when, offset, ...args); };
  node.stop = function(...args) { record.playing = false; return stop.apply(this, args); };
  node.addEventListener('ended', () => { record.playing = false; });
  return node;
};
window.stonesMusicState = () => [
  ...stonesMusicNodes.filter(n => n.element?.src.includes('/sounds/music/'))
    .map(n => ({src: n.element.src, paused: n.element.paused,
      time: n.element.currentTime, duration: n.element.duration,
      gain: n.gain.gain.value, state: n.context.state})),
  ...stonesBufferNodes.filter(n => decoded.get(n.node.buffer)?.includes('/sounds/music/'))
    .map(n => ({src: decoded.get(n.node.buffer), paused: !n.playing,
      time: n.context.currentTime - n.at + n.offset, duration: n.node.buffer.duration,
      gain: n.gain.gain.value, state: n.context.state, id: n.id}))
];"""


class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        self.path = re.sub(r"^/stones/", "/", self.path)
        try:
            super().do_GET()
        except (BrokenPipeError, ConnectionResetError):
            pass

    def log_message(self, *_args):
        pass


def button(page, name):
    return page.get_by_role("button", name=re.compile(rf"^{re.escape(name)}(?:\s|$)")).first


def click(page, name):
    target = button(page, name)
    expect(target).to_be_visible()
    target.click()
    page.wait_for_timeout(450)  # Let the page transition complete before another input.


def playing(page, cue):
    try:
        page.wait_for_function("""cue => {
          const active = stonesMusicState().filter(n => !n.paused && n.gain > .01);
          return active.length === 1 && active[0].src.endsWith('/' + cue + '.mp3') &&
            active[0].state === 'running' && active[0].time > .1;
        }""", arg=cue, timeout=20000)
    except Exception:
        print(json.dumps({"cue": cue, "state": page.evaluate("stonesMusicState()"),
                          "storage": page.evaluate("JSON.stringify(localStorage)")}), flush=True)
        raise
    return page.evaluate("stonesMusicState()")


def ready(page, url):
    page.goto(url)
    page.locator("flt-semantics-placeholder").evaluate("e => e.click()", timeout=60000)
    expect(button(page, "Audio settings")).to_be_visible(timeout=30000)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default="build/web")
    parser.add_argument("--browser", choices=("chromium", "firefox", "webkit"), default="chromium")
    args = parser.parse_args()
    out = ROOT / "build/qa/music" / args.browser
    out.mkdir(parents=True, exist_ok=True)
    handler = functools.partial(Handler, directory=str(ROOT / args.root))
    server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    url = f"http://127.0.0.1:{server.server_port}/stones/"
    report = {"browser": args.browser, "cases": [], "status": "running"}
    try:
        with sync_playwright() as pw:
            options = {}
            if args.browser == "chromium" and os.environ.get("STONES_CHROMIUM"):
                options["executable_path"] = os.environ["STONES_CHROMIUM"]
            browser = getattr(pw, args.browser).launch(**options)
            context = browser.new_context(viewport={"width": 1280, "height": 900})
            context.add_init_script(HOOK)
            context.route("https://**/*", lambda route: route.abort())
            page = context.new_page()
            page.on("console", lambda message: print(message.text, flush=True)
                    if "Optional music" in message.text else None)
            ready(page, url)
            assert page.evaluate("stonesMusicState().length") == 0
            click(page, "Audio settings")
            page.get_by_role("switch", name=re.compile("Background music")).click()
            report["cases"].append({"case": "opt-in real playback", "state": playing(page, "menu")})
            # Escape dismisses the sheet and retains the menu arrangement.
            page.keyboard.press("Escape")
            page.wait_for_timeout(500)
            click(page, "Square")
            click(page, "Same-device game")
            click(page, "Start game")
            report["cases"].append({"case": "Square", "state": playing(page, "square")})
            # Observe a complete natural loop using the real asset and audio clock.
            # Poll in bounded intervals so the runner can report progress.
            initial = page.evaluate("stonesMusicState().find(n => !n.paused && n.gain > .01)")
            looped = False
            for _ in range(6):
                try:
                    page.wait_for_function("""initial => stonesMusicState().some(n =>
                      !n.paused && n.src.endsWith('/square.mp3') && n.gain > .24 &&
                      n.time < 6 && n.id !== initial.id)""", arg=initial, timeout=30000)
                    looped = True
                    break
                except Exception:
                    print("Waiting for the natural Square loop...", flush=True)
            assert looped, page.evaluate("stonesMusicState()")
            report["cases"].append({"case": "loop overlap", "state": playing(page, "square")})
            state = page.evaluate("stonesMusicState().filter(n => !n.paused && n.gain > .01)")
            assert state[0]["time"] < 6, state
            click(page, "Audio settings")
            playing(page, "square")
            page.get_by_role("switch", name=re.compile("Background music")).click()
            page.wait_for_function("stonesMusicState().every(n => n.paused || n.gain === 0)")
            page.get_by_role("switch", name=re.compile("Background music")).click()
            playing(page, "square")
            page.keyboard.press("Escape")
            page.wait_for_timeout(450)
            click(page, "Back")
            click(page, "Back")
            playing(page, "menu")
            click(page, "Hex")
            click(page, "Same-device game")
            click(page, "Start game")
            report["cases"].append({"case": "Hex", "state": playing(page, "hex")})
            click(page, "Back")
            click(page, "Back")
            click(page, "Learn to play")
            report["cases"].append({"case": "learning", "state": playing(page, "learning")})
            page.screenshot(path=str(out / "learning.png"))
            # A fresh page restores the preference, yet waits for real interaction.
            page.reload()
            page.locator("flt-semantics-placeholder").evaluate("e => e.click()", timeout=60000)
            expect(button(page, "Audio settings")).to_be_visible(timeout=30000)
            assert page.evaluate("stonesMusicState().length") == 0
            click(page, "Audio settings")
            playing(page, "menu")
            report["cases"].append({"case": "saved preference and fresh gesture", "passed": True})
            context.close()
            # Effect download failure must not hold music behind initialization.
            context = browser.new_context(viewport={"width": 1280, "height": 900})
            context.add_init_script(HOOK)
            context.add_init_script("localStorage.setItem('flutter.music_volume', '0.25')")
            context.route("https://**/*", lambda route: route.abort())
            context.route(re.compile(r"/sounds/(?!music/)"), lambda route: route.abort())
            page = context.new_page()
            ready(page, url)
            click(page, "Audio settings")
            report["cases"].append({"case": "failed effects do not block music", "state": playing(page, "menu")})
            context.close()
            browser.close()
        report["status"] = "passed"
    except Exception as error:
        report["status"] = "failed"
        report["error"] = str(error)
        raise
    finally:
        (out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
        server.shutdown()
    print(json.dumps({"browser": args.browser, "status": report["status"], "cases": len(report["cases"])}))


if __name__ == "__main__":
    main()
