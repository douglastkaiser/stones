"""Run emulator credential and browser-restart regressions with a local server.

Run inside firebase emulators:exec for demo-stones-hex after building
tools/integration_app.dart into build/integration-web. No real Google exchange.
"""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import time
from urllib.request import urlopen


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--browsers', default='chromium')
    args = parser.parse_args()
    if not set(args.browsers.split(',')) <= {'chromium', 'firefox', 'webkit'}:
        parser.error('Unknown browser')
    evidence = Path('build/qa/google-auth')
    evidence.mkdir(parents=True, exist_ok=True)
    with (evidence / 'server.log').open('w') as log:
        server = subprocess.Popen(['node', 'tools/serve_web.mjs'],
                                  env={**os.environ, 'WEB_ROOT': 'build/integration-web', 'PORT': '4173'},
                                  stdout=log, stderr=subprocess.STDOUT)
        try:
            for _ in range(50):
                if server.poll() is not None:
                    raise RuntimeError('Auth regression server did not start; see server.log')
                try:
                    with urlopen('http://127.0.0.1:4173/stones/', timeout=1) as response:
                        if response.status == 200:
                            break
                except OSError:
                    time.sleep(0.1)
            else:
                raise RuntimeError('Auth regression server was not ready')
            subprocess.run([sys.executable, 'tools/google_auth_emulator_probe.py',
                            '--credentials-only', '--browsers', args.browsers,
                            '--output', str(evidence / 'credentials.json')], check=True)
            subprocess.run([sys.executable, 'tools/google_auth_remember_probe.py',
                            '--browsers', args.browsers,
                            '--output', str(evidence / 'remembered.json')], check=True)
        finally:
            server.terminate()
            server.wait(timeout=10)


if __name__ == '__main__':
    main()
