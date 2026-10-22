#!/usr/bin/env bash
# GitHub-hosted Ubuntu 24.04 browser setup. No application/test retries.
set -euo pipefail

if (( $# == 0 )); then
  echo 'Specify chromium, firefox and/or webkit.' >&2
  exit 2
fi
for browser in "$@"; do
  case "$browser" in
    chromium|firefox|webkit) ;;
    *) echo 'Unsupported browser.' >&2; exit 2 ;;
  esac
done

# Match the platform qualified by this repository rather than ubuntu-latest.
. /etc/os-release
if [[ "$ID" != ubuntu || "$VERSION_ID" != 24.04 ]]; then
  echo 'Browser CI requires Ubuntu 24.04.' >&2
  exit 2
fi

# The Azure archive mirror took ten minutes for a 20 MB dependency download.
# Use the official HTTPS Ubuntu archive, keeping suites and signature checks.
for source in /etc/apt/apt-mirrors.txt /etc/apt/sources.list /etc/apt/sources.list.d/ubuntu.sources; do
  if [[ -f "$source" ]]; then
    sudo sed -i -E 's@https?://azure.archive.ubuntu.com/ubuntu/?@https://archive.ubuntu.com/ubuntu/@g' "$source"
  fi
done
sudo tee /etc/apt/apt.conf.d/99-stones-browser-ci >/dev/null <<'APT'
Acquire::Retries "2";
Acquire::http::Timeout "30";
Acquire::https::Timeout "30";
DPkg::Lock::Timeout "60";
APT

python3 -m pip install --disable-pip-version-check --retries 2 --timeout 30 playwright==1.62.0
python3 -m playwright install --with-deps "$@"
