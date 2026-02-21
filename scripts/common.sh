#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK_FILE="$ROOT_DIR/contracts/VERSIONS.lock"
ENV_FILE="$ROOT_DIR/config/project.env"

fail() {
  echo "[error] $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"
}

load_lock() {
  [ -f "$LOCK_FILE" ] || fail "missing $LOCK_FILE"
  set -a
  # shellcheck disable=SC1090
  source "$LOCK_FILE"
  set +a
}

load_env_if_present() {
  if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
  fi
}
