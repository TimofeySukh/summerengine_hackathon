#!/usr/bin/env bash
# Start pose tracking and forward slashes to Heat Wave (UDP :9847).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if [[ ! -d .venv ]]; then
  python3 -m venv .venv
  source .venv/bin/activate
  pip install -r requirements.txt
else
  source .venv/bin/activate
fi

exec python pose_stream.py --game-bridge "$@"
