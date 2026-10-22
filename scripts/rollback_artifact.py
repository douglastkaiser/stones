"""Extract the previous canonical release from a publishing tree before replacing it.

The publication tree also carries previews and retained startup scripts. Only the
files in its original manifest are archived; every byte must match that manifest.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil


def capture(published, output):
    data = json.loads((published / 'release-manifest.json').read_text())
    if data.get('version') != 1 or not re.fullmatch('[a-f0-9]{40}', data.get('source', '')):
        raise ValueError('Previous release has no valid source manifest')
    if output.exists():
        raise ValueError('Rollback output already exists')
    contents = {}
    for name, expected in data['files'].items():
        path = Path(name)
        if path.is_absolute() or '..' in path.parts or not path.parts or path.parts[0] in (
                '.git', 'pr', 'CNAME', '.nojekyll'):
            raise ValueError('Unsafe rollback artifact path')
        source = published / name
        if source.is_symlink() or any(parent.is_symlink() for parent in source.parents):
            raise ValueError('Rollback symlinks are forbidden')
        content = source.read_bytes()
        if name == 'startup-assets.json' and hashlib.sha256(content).hexdigest() != expected:
            # Publication extends this ledger with retained pairs. Recover the
            # canonical, original first-pair ledger and require its exact hash.
            content = json.dumps(json.loads(content)[:1]).encode()
        if hashlib.sha256(content).hexdigest() != expected:
            raise ValueError('Previous release differs from its artifact manifest')
        contents[name] = content
    for name, content in contents.items():
        target = output / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
    shutil.copyfile(published / 'release-manifest.json', output / 'release-manifest.json')
    return {'previous_source': data['source'], 'files_verified': len(contents)}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('published', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    print(json.dumps(capture(args.published, args.output)))
