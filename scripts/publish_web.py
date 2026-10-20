"""Apply one publication to a freshly checked out gh-pages tree.

Git commit/push belongs to the workflow's shared publication lock. Never force
push. Only main publication replaces the root; preview writers own one directory.
"""
import argparse
from pathlib import Path
import re
import shutil

from prepare_web_release import retain_previous


def publish(source, target, preview=None):
    if preview is not None and not re.fullmatch(r'(?:[1-9][0-9]*|finishing(?:-game)?)', preview):
        raise ValueError('Invalid preview directory')
    destination = target / 'pr' / preview if preview else target
    if source is None:
        if preview is None:
            raise ValueError('Only a preview can be removed')
        if destination.exists():
            shutil.rmtree(destination)
        return
    if not (source / 'index.html').is_file():
        raise ValueError('Missing built application')
    if any((source / name).exists() for name in ('.git', 'pr', 'CNAME', '.nojekyll')):
        raise ValueError('Built application contains a reserved publishing path')
    if destination.exists():
        retain_previous(source, destination)
        for path in destination.iterdir():
            if preview is None and path.name in {'.git', 'pr', 'CNAME', '.nojekyll'}:
                continue
            if path.is_dir():
                shutil.rmtree(path)
            else:
                path.unlink()
    destination.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source, destination, dirs_exist_ok=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path)
    parser.add_argument('--target', required=True, type=Path)
    parser.add_argument('--preview')
    args = parser.parse_args()
    publish(args.source, args.target, args.preview)
