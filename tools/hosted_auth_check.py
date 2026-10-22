"""Read-only hosted integrity and Google handoff checks; no credential exchange."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from release_baseline import inspect_live
from google_auth_probe import public_json, BASE
from auth_evidence import validate_results

CASES = ('cold', 'warm', 'popup_blocked', 'close_retry')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--expected-source')
    parser.add_argument('--browsers', default='chromium,firefox,webkit')
    parser.add_argument('--wait-seconds', type=int, default=0)
    parser.add_argument('--output', type=Path, default=Path('build/qa/hosted-auth'))
    args = parser.parse_args()
    if not 0 <= args.wait_seconds <= 300:
        parser.error('Publication wait must be between 0 and 300 seconds')
    names = args.browsers.split(',')
    if len(names) != len(set(names)) or not set(names) <= {'chromium', 'firefox', 'webkit'}:
        parser.error('Unknown or duplicate browser')
    args.output.mkdir(parents=True, exist_ok=True)
    summary = {'status': 'running', 'publication': 'not_verified',
               'hosted_auth': 'not_run', 'physical_ios': 'unverified',
               'real_google_exchange': 'unverified',
               'started_utc': datetime.now(timezone.utc).isoformat(),
               'checker_source': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()}
    deadline = time.monotonic() + args.wait_seconds
    try:
        while True:
            try:
                manifest = public_json(BASE + 'release-manifest.json?auth-check=' + str(time.time_ns()))
                source = args.expected_source or manifest['source']
                if manifest['source'] != source:
                    raise ValueError('Hosted source has not reached the selected publication')
                live = inspect_live(BASE, fresh=True, expected_source=source,
                                    expected_manifest=manifest)
                bootstrap, main_script = live['currentPair']
                for name in (bootstrap, main_script):
                    if name not in manifest['files'] or manifest['files'][name][:20] != name.split('.')[1]:
                        raise ValueError('Hosted manifest does not match current startup assets')
                summary.update(publication='verified', deployed_source=source, integrity=live,
                               manifest_canonical_sha256=hashlib.sha256(json.dumps(
                                   manifest, sort_keys=True).encode()).hexdigest())
                break
            except Exception:
                if time.monotonic() >= deadline:
                    raise
                time.sleep(min(10, max(0, deadline - time.monotonic())))
        target = args.output / 'scenarios.json'
        # Never reuse a previous successful scenario report after launch failure.
        target.unlink(missing_ok=True)
        result = subprocess.run([
            sys.executable, 'tools/google_auth_probe.py', '--browsers', args.browsers,
            '--expected-source', source, '--assert-outcomes', '--cases', ','.join(CASES),
            '--output', str(target)], timeout=300 * len(names))
        validate_results(json.loads(target.read_text()), names, cases=CASES)
        if result.returncode:
            raise RuntimeError('Hosted probe failed')
        summary.update(status='passed', hosted_auth='passed')
    except Exception as error:
        summary.update(status='failed', error_type=type(error).__name__)
        if summary['publication'] == 'verified':
            summary['hosted_auth'] = 'failed'
    summary['completed_utc'] = datetime.now(timezone.utc).isoformat()
    (args.output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps({k: summary[k] for k in ('status', 'publication', 'hosted_auth')}))
    if summary['status'] != 'passed':
        raise SystemExit(1)


if __name__ == '__main__':
    main()
