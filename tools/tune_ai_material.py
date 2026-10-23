"""Single-feature 0/4/8/12 pilot grid. Never selects weights using held-out seeds.
Outputs resumable full game replays through the native qualification runner.
Usage: DART_BIN=... python3 tools/tune_ai_material.py --seeds=2 --profile=hex-2-3
"""
import argparse
import os
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--seeds', type=int, default=2)
parser.add_argument('--profile', default='all')
parser.add_argument('--output', type=Path, default=Path('/tmp/stones-material-pilot'))
parser.add_argument('--max-games', type=int, default=0)
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
for feature in range(4):
    for value in [0, 4, 8, 12]:
        weights = [0] * 4
        weights[feature] = value
        subprocess.run([
            os.environ.get('DART_BIN', 'dart'), 'run', 'tools/ai_qualification.dart',
            '--mode=tune', '--pilot', f'--seeds={args.seeds}', f'--profile={args.profile}',
            f'--weights={",".join(map(str, weights))}', f'--max-games={args.max_games}',
            f'--output={args.output / f"feature-{feature}-weight-{value}.jsonl"}',
        ], check=True)
