"""Read-only local/live release evidence. Does not access accounts or rooms.

python scripts/release_baseline.py --live --output build/qa/release-baseline.json
HTTP timings are transfer observations, not interactive startup/frame timings.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess
from time import perf_counter, time_ns
from urllib.parse import urljoin, urlparse
from urllib.request import Request, urlopen


def git(*args):
    return subprocess.check_output(['git', *args], text=True).strip()


def fingerprint_name(name, prefix, suffix):
    if not isinstance(name, str) or not re.fullmatch(
            re.escape(prefix) + r'\.[0-9a-f]{20}' + re.escape(suffix), name):
        raise ValueError('Invalid release asset filename')
    return name.split('.')[1]


def inspect_live(base, *, fresh=False, expected_source=None, expected_manifest=None):
    parsed = urlparse(base)
    if parsed.scheme != 'https' or parsed.hostname not in {
            'www.douglastkaiser.com', 'douglastkaiser.com',
            'douglastkaiser.github.io'} or parsed.query or parsed.fragment:
        raise ValueError('Use a public HTTPS Stones release URL without query parameters')
    observations = []

    def fetch(path):
        start = perf_counter()
        url = urljoin(base.rstrip('/') + '/', path)
        if fresh and path in {'', 'startup-assets.json'}:
            # A CDN may briefly cache the pre-deployment 404 for a new preview.
            url += '?baseline=' + str(time_ns())
        with urlopen(Request(url,
                             headers={'User-Agent': 'Stones-release-baseline'}),
                     timeout=30) as response:
            data = response.read(20 * 1024 * 1024 + 1)
            if len(data) > 20 * 1024 * 1024:
                raise ValueError('Unexpectedly large startup asset')
            observations.append({'path': path, 'url': response.url,
                                 'bytes': len(data),
                                 'transferMs': round((perf_counter() - start) * 1000)})
        if expected_manifest is not None and path != 'startup-assets.json':
            expected = expected_manifest['files'].get(path or 'index.html')
            if expected != hashlib.sha256(data).hexdigest():
                raise ValueError('Hosted content differs from the selected artifact manifest')
        return data

    index = fetch('').decode('utf-8')
    source = re.search(r'name="stones-(?:release|preview)-source" content="([a-f0-9]{40})"', index)
    source_value = source[1] if source else None
    if source_value is None and expected_manifest is not None:
        # Earlier qualified main artifacts predate HTML source metadata. Their
        # verified index hash still binds the page to the manifest's source.
        source_value = expected_manifest.get('source')
    if expected_source is not None:
        if not re.fullmatch(r'[a-f0-9]{7,40}', expected_source):
            raise ValueError('Expected source must be a Git revision prefix')
        if source_value is None or not source_value.startswith(expected_source):
            raise ValueError('The hosted preview is not the requested source revision')
    pairs = json.loads(fetch('startup-assets.json'))
    if not isinstance(pairs, list) or not 1 <= len(pairs) <= 3:
        raise ValueError('Expected current startup pair and at most two previous pairs')
    for pair in pairs:
        if not isinstance(pair, list) or len(pair) != 2:
            raise ValueError('Invalid startup pair')
        fingerprint_name(pair[0], 'flutter_bootstrap', '.js')
        fingerprint_name(pair[1], 'main', '.dart.js')
    bootstrap_name, main_name = pairs[0]
    if index.count('src="' + bootstrap_name + '"') != 1:
        raise ValueError('HTML does not name the current fingerprinted bootstrap')
    bootstrap = fetch(bootstrap_name)
    if hashlib.sha256(bootstrap).hexdigest()[:20] != fingerprint_name(
            bootstrap_name, 'flutter_bootstrap', '.js'):
        raise ValueError('Bootstrap content does not match its fingerprint')
    config = re.search(r'_flutter\.buildConfig = (\{[^\n]+\});',
                       bootstrap.decode('utf-8'))
    if config is None or main_name not in {
            item.get('mainJsPath') for item in json.loads(config[1])['builds']}:
        raise ValueError('Bootstrap does not name the current main script')
    main = fetch(main_name)
    if hashlib.sha256(main).hexdigest()[:20] != fingerprint_name(main_name, 'main', '.dart.js'):
        raise ValueError('Main script content does not match its fingerprint')
    return {'base': base, 'previewSource': source_value,
            'currentPair': pairs[0], 'retainedPairCount': len(pairs) - 1,
            'integrity': 'passed', 'observations': observations,
            'timingScope': 'HTTP transfer only; not browser startup, input or frame rate'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--live', action='store_true')
    parser.add_argument('--fresh', action='store_true',
                        help='Bypass cached HTML/manifest responses for a new deployment')
    parser.add_argument('--expected-source', help='Require this source revision in preview metadata')
    parser.add_argument('--base', default='https://www.douglastkaiser.com/stones/')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    report = {
        'observedAtUtc': datetime.now(timezone.utc).isoformat(),
        'source': {'branch': git('branch', '--show-current'), 'head': git('rev-parse', 'HEAD'),
                   'trackedChanges': git('status', '--short', '--untracked-files=no')},
        'toolchain': {'ciFlutter': '3.47.7',
                      'localFlutter': 'Check explicitly; temporary SDK paths are not assumed'},
        'deviceQualification': 'pending; this script does not measure a device',
    }
    if args.live:
        report['live'] = inspect_live(args.base, fresh=args.fresh,
                                      expected_source=args.expected_source)
    encoded = json.dumps(report, indent=2) + '\n'
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded, encoding='utf-8')
    print(encoded)


if __name__ == '__main__':
    main()
