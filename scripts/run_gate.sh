#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

load_lock
BIN_PATH="$ROOT_DIR/bin/${CORE_BINARY_NAME:-ubl-gate}"

[ -x "$BIN_PATH" ] || {
  echo "[error] missing binary. run: make install-binary" >&2
  exit 1
}

if [ ! -f "$ENV_FILE" ]; then
  echo "[warn] missing config/project.env, copying sample"
  cp "$ROOT_DIR/config/project.env.sample" "$ENV_FILE"
fi

load_env_if_present
mkdir -p ./.logs ./data/cas ./data/ledger ./data/index ./data/eventstore

exec "$BIN_PATH"
