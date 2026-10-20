"""Check changed Dart source without rewriting it or legacy untouched files."""
import os
from pathlib import Path
import subprocess


def main():
    base = os.environ.get('FORMAT_BASE')
    if not base or set(base) == {'0'}:
        base = subprocess.check_output(
            ['git', 'rev-parse', 'HEAD^'], text=True).strip()
    paths = subprocess.check_output(
        ['git', 'diff', '--name-only', '--diff-filter=ACMR', '-z', base, 'HEAD'],
    ).decode().split('\0')
    paths = [p for p in paths if p.endswith('.dart') and Path(p).is_file()]
    if paths:
        subprocess.run(
            ['dart', 'format', '--output=none', '--set-exit-if-changed', *paths],
            check=True)


if __name__ == '__main__':
    main()
