"""Create/verify the immutable manifest carried from CI into web publication."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

AUTH_SOURCES = ('lib/providers/account_provider.dart',
                'lib/services/account_service.dart',
                'lib/screens/main_menu_screen.dart',
                'lib/widgets/account_card.dart', 'tools/integration_app.dart')


def auth_sources():
    return {name: digest(Path(name)) for name in AUTH_SOURCES}


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


def create(root, source, *, kind='production'):
    if not re.fullmatch(r'[0-9a-f]{40}', source):
        raise ValueError('A full source commit is required')
    index = root / 'index.html'
    text = index.read_text()
    marker = f'<meta name="stones-release-source" content="{source}">'
    text = re.sub(r'<meta name="stones-release-source" content="[a-f0-9]{40}">\s*', '', text)
    index.write_text(text.replace('</head>', marker + '\n</head>') if '</head>' in text
                     else marker + '\n' + text)
    manifest = {
        'version': 1, 'source': source, 'flutter': '3.47.7',
        'rules': digest(Path('firestore.rules')),
        'indexes': digest(Path('firestore.indexes.json')),
        'files': files(root), 'buildKind': kind, 'authSources': auth_sources(),
    }
    (root / 'release-manifest.json').write_text(
        json.dumps(manifest, sort_keys=True, indent=2) + '\n')


def verify(root, source, *, kind=None):
    manifest = json.loads((root / 'release-manifest.json').read_text())
    if manifest.get('version') != 1 or manifest.get('source') != source:
        raise ValueError('Artifact does not match the selected source commit')
    if manifest.get('flutter') != '3.47.7' or manifest.get('files') != files(root):
        raise ValueError('Artifact content or toolchain does not match its manifest')
    if kind is not None and (manifest.get('buildKind') != kind or
                             manifest.get('authSources') != auth_sources()):
        raise ValueError('Artifact entry point or auth sources differ from checkout')
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
    parser.add_argument('--kind', choices=['production', 'emulator'])
    args = parser.parse_args()
    source = args.source or subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], text=True).strip()
    if args.action == 'create':
        create(args.root, source, kind=args.kind or 'production')
    else:
        verify(args.root, source, kind=args.kind)
