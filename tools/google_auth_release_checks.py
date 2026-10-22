"""Verify one immutable production artifact, then exercise its pre-credential UI."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from urllib.request import urlopen

from auth_evidence import provenance, validate_results

CASES = ('cold', 'warm', 'popup_blocked', 'close_retry',
         'callback_storage_lost', 'callback_new_context')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--expected-source', required=True)
    parser.add_argument('--browsers', default='chromium')
    parser.add_argument('--web-root', type=Path, default=Path('build/web'))
    parser.add_argument('--output', type=Path, default=Path('build/qa/auth-release'))
    args = parser.parse_args()
    names = args.browsers.split(',')
    if len(names) != len(set(names)) or not set(names) <= {'chromium', 'firefox', 'webkit'}:
        parser.error('Unknown or duplicate browser')
    args.output.mkdir(parents=True, exist_ok=True)
    for name in ('summary.json', 'scenarios.json'):
        (args.output / name).unlink(missing_ok=True)
    summary = {'status': 'running', 'started_utc': datetime.now(timezone.utc).isoformat(),
               'physical_ios': 'unverified', 'real_google_exchange': 'unverified'}
    server = None
    try:
        summary['build'] = provenance(args.web_root, args.expected_source, 'production')
        with (args.output / 'server.log').open('w') as log:
            server = subprocess.Popen(['node', 'tools/serve_web.mjs'],
                                      env={**os.environ, 'WEB_ROOT': str(args.web_root), 'PORT': '4174'},
                                      stdout=log, stderr=subprocess.STDOUT)
            for _ in range(50):
                if server.poll() is not None:
                    raise RuntimeError('Release server exited before readiness')
                try:
                    with urlopen('http://localhost:4174/stones/', timeout=1) as response:
                        if response.status == 200:
                            break
                except OSError:
                    time.sleep(0.1)
            else:
                raise RuntimeError('Release server did not become ready')
            result = subprocess.run([
                sys.executable, 'tools/google_auth_probe.py', '--base', 'http://localhost:4174/stones/',
                '--expected-source', args.expected_source, '--browsers', args.browsers,
                '--assert-outcomes', '--verify-recovery', '--cases', ','.join(CASES),
                '--output', str(args.output / 'scenarios.json')], timeout=600 * len(names))
            data = json.loads((args.output / 'scenarios.json').read_text())
            validate_results(data, names, cases=CASES)
            if result.returncode:
                raise RuntimeError('Release probe failed')
        summary['status'] = 'passed'
    except Exception as error:
        summary.update(status='failed', error_type=type(error).__name__)
    finally:
        if server:
            server.terminate()
            try:
                server.wait(timeout=10)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait()
    summary['completed_utc'] = datetime.now(timezone.utc).isoformat()
    (args.output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary))
    if summary['status'] != 'passed':
        raise SystemExit(1)


if __name__ == '__main__':
    main()
