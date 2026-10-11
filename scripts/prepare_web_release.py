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
    print(f'Web startup assets fingerprinted: {main_name}, {bootstrap_name}')


if __name__ == '__main__':
    prepare(Path(sys.argv[1] if len(sys.argv) > 1 else 'build/web'))
