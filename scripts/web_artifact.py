"""Create/verify the immutable manifest carried from CI into web publication."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def files(root):
    result = {}
    for path in sorted(root.rglob('*')):
        if path.is_symlink():
            raise ValueError('Symlinks are not allowed in release artifacts')
        if path.is_file() and path != root / 'release-manifest.json':
            result[path.relative_to(root).as_posix()] = digest(path)
    return result


def create(root, source):
    if not re.fullmatch(r'[0-9a-f]{40}', source):
        raise ValueError('A full source commit is required')
    manifest = {
        'version': 1, 'source': source, 'flutter': '3.47.7',
        'rules': digest(Path('firestore.rules')),
        'indexes': digest(Path('firestore.indexes.json')),
        'files': files(root),
    }
    (root / 'release-manifest.json').write_text(
        json.dumps(manifest, sort_keys=True, indent=2) + '\n')


def verify(root, source):
    manifest = json.loads((root / 'release-manifest.json').read_text())
    if manifest.get('version') != 1 or manifest.get('source') != source:
        raise ValueError('Artifact does not match the selected source commit')
    if manifest.get('flutter') != '3.47.7' or manifest.get('files') != files(root):
        raise ValueError('Artifact content or toolchain does not match its manifest')
    if not {'index.html', 'startup-assets.json', 'privacy.html'} <= manifest['files'].keys():
        raise ValueError('Incomplete release artifact')
    if manifest.get('rules') != digest(Path('firestore.rules')) or \
            manifest.get('indexes') != digest(Path('firestore.indexes.json')):
        raise ValueError('Artifact backend contract differs from its source')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['create', 'verify'])
    parser.add_argument('root', type=Path)
    parser.add_argument('--source')
    args = parser.parse_args()
    source = args.source or subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], text=True).strip()
    (create if args.action == 'create' else verify)(args.root, source)
