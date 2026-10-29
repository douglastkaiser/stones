#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
DART_BIN="${DART_BIN:-dart}"
python3 - <<'PY_CHECK'
import hashlib
import json
from pathlib import Path
manifest = json.loads(Path('docs/qa/ai-upgrade-baseline.json').read_text())
actual = hashlib.sha256(Path(manifest['frozenSource']).read_bytes()).hexdigest()
if actual != manifest['frozenSourceSha256']:
    raise SystemExit('Frozen baseline engine changed')
PY_CHECK
sha256sum --check tools/ai_baseline/dependencies.sha256
REFERENCE_PACKAGES="$(python3 scripts/frozen_ai_reference.py --output-dir /tmp/stones-ai-baseline-reference)"
"$DART_BIN" compile exe --packages="$REFERENCE_PACKAGES" tools/ai_baseline/worker.dart -o /tmp/stones-ai-baseline
"$DART_BIN" compile exe tools/ai_worker.dart -o /tmp/stones-ai-candidate
sha256sum /tmp/stones-ai-baseline /tmp/stones-ai-candidate
