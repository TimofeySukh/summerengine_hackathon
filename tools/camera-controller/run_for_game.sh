#!/usr/bin/env bash
# Start pose tracking and forward hand/slash events to Heat Wave (UDP :9847).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

ensure_venv() {
  if [[ ! -d .venv ]]; then
    python3 -m venv .venv
  fi
  # shellcheck disable=SC1091
  source .venv/bin/activate
  pip install -q -r requirements.txt
}

ensure_venv

if [[ "${1:-}" == "--setup-only" ]]; then
  exit 0
fi

ARGS=(--game-bridge --skip-calibration --no-audio --no-voice-wave)
if [[ "${1:-}" == "--no-display" || "${1:-}" == "--headless" ]]; then
  ARGS+=(--no-display)
  shift
fi

exec python pose_stream.py "${ARGS[@]}" "$@"
