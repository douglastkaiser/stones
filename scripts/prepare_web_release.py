"""Fingerprint startup assets so a fresh page cannot reuse an older game script."""
import hashlib
import json
from pathlib import Path
import re
import sys


def prepare(root: Path) -> None:
    index_path = root / 'index.html'
    bootstrap_path = root / 'flutter_bootstrap.js'
    index = index_path.read_text(encoding='utf-8')
    bootstrap = bootstrap_path.read_text(encoding='utf-8')
    pattern = r'_flutter\.buildConfig = (\{[^\n]+\});'
    matches = list(re.finditer(pattern, bootstrap))
    if len(matches) != 1 or index.count('src="flutter_bootstrap.js"') != 1:
        raise ValueError('Expected one Flutter build configuration and startup script')
    config = json.loads(matches[0].group(1))
    builds = [item for item in config['builds'] if item.get('compileTarget')]
    if len(builds) != 1 or builds[0].get('mainJsPath') != 'main.dart.js':
        raise ValueError('Expected the pinned dart2js release layout')
    if builds[0]['compileTarget'] != 'dart2js':
        raise ValueError('This release preparation supports dart2js only')
    main = (root / 'main.dart.js').read_bytes()
    main_name = f"main.{hashlib.sha256(main).hexdigest()[:20]}.dart.js"
    builds[0]['mainJsPath'] = main_name
    bootstrap = re.sub(pattern, lambda _: '_flutter.buildConfig = ' +
                       json.dumps(config, separators=(',', ':')) + ';', bootstrap)
    bootstrap_name = f"flutter_bootstrap.{hashlib.sha256(bootstrap.encode()).hexdigest()[:20]}.js"
    # Validate everything before modifying output. Keep original names for
    # already-open pages and older cached HTML during CDN propagation.
    (root / main_name).write_bytes(main)
    (root / bootstrap_name).write_text(bootstrap, encoding='utf-8')
    index_path.write_text(index.replace('src="flutter_bootstrap.js"',
                                       f'src="{bootstrap_name}"'), encoding='utf-8')
    (root / 'startup-assets.json').write_text(
        json.dumps([[bootstrap_name, main_name]]), encoding='utf-8')
    print(f'Web startup assets fingerprinted: {main_name}, {bootstrap_name}')


def retain_previous(root: Path, previous: Path) -> None:
    """Keep two earlier startup pairs for cached pages during a release change."""
    manifest = root / 'startup-assets.json'
    current = json.loads(manifest.read_text(encoding='utf-8'))
    old_manifest = previous / 'startup-assets.json'
    old = json.loads(old_manifest.read_text(encoding='utf-8')) if old_manifest.exists() else []
    if not old and (previous / 'index.html').exists():
        # Adopt the first fingerprinted deployment, which predates the ledger.
        match = re.search(r'src="(flutter_bootstrap\.[0-9a-f]{20}\.js)"',
                          (previous / 'index.html').read_text(encoding='utf-8'))
        if match:
            config_match = re.search(r'_flutter\.buildConfig = (\{[^\n]+\});',
                                     (previous / match[1]).read_text(encoding='utf-8'))
            if not config_match:
                raise ValueError('Previous fingerprinted bootstrap has no build configuration')
            config = json.loads(config_match[1])
            old = [[match[1], config['builds'][0]['mainJsPath']]]
    retained = []
    for pair in old:
        if not isinstance(pair, list) or len(pair) != 2 or not all(isinstance(name, str) for name in pair):
            raise ValueError('Invalid previous startup asset pair')
        if not re.fullmatch(r'flutter_bootstrap\.[0-9a-f]{20}\.js', pair[0]) or not re.fullmatch(r'main\.[0-9a-f]{20}\.dart\.js', pair[1]):
            raise ValueError('Invalid previous startup asset filename')
        if pair not in current and pair not in retained:
            retained.append(pair)
    retained = retained[:2]
    # Read all sources before changing output, and never follow paths from a
    # manifest unless their exact content-fingerprint filenames are validated.
    copies = [(name, (previous / name).read_bytes()) for pair in retained for name in pair]
    for name, content in copies:
        (root / name).write_bytes(content)
    manifest.write_text(json.dumps(current + retained), encoding='utf-8')


if __name__ == '__main__':
    if len(sys.argv) == 4 and sys.argv[1] == '--retain-previous':
        retain_previous(Path(sys.argv[2]), Path(sys.argv[3]))
    else:
        prepare(Path(sys.argv[1] if len(sys.argv) > 1 else 'build/web'))
