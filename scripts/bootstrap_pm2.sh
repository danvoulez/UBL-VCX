#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

require_cmd pm2

if [ ! -f "$ENV_FILE" ]; then
  cp "$ROOT_DIR/config/project.env.sample" "$ENV_FILE"
  echo "[info] created $ENV_FILE"
fi

"$ROOT_DIR/scripts/install_binary.sh"

mkdir -p "$ROOT_DIR/.logs"
pm2 start "$ROOT_DIR/pm2/ecosystem.config.cjs" --only ubl-gate
pm2 save

echo "[ok] PM2 process started and saved"
