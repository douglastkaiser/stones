#!/bin/bash
# Scan the repository for unresolved merge conflict markers.

set -euo pipefail

# Exclude the .git directory and this script, search all other files.
if rg --hidden --no-ignore -n "<<<<<<<|>>>>>>>" --glob '!.git/**' --glob '!scripts/check_conflicts.sh' . >/tmp/conflict_hits.txt; then
  echo "Unresolved merge conflict markers found:" >&2
  cat /tmp/conflict_hits.txt >&2
  exit 1
fi

echo "No merge conflict markers detected."
