#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

require_cmd git
load_lock
load_env_if_present

mkdir -p "$ROOT_DIR/bin" "$ROOT_DIR/.cache" "$ROOT_DIR/.logs"

BINARY_NAME="${MULTI_BINARY_NAME:-ubl-gate}"
TARGET_PATH="$ROOT_DIR/bin/$BINARY_NAME"

if [ -n "${MULTI_BINARY_URL:-}" ]; then
  require_cmd curl
  echo "[info] downloading binary from MULTI_BINARY_URL"
  curl -fL "$MULTI_BINARY_URL" -o "$TARGET_PATH"
  chmod +x "$TARGET_PATH"
  echo "[ok] installed $TARGET_PATH"
  exit 0
fi

require_cmd cargo
TMP_DIR="$ROOT_DIR/.cache/multi-src"
rm -rf "$TMP_DIR"

echo "[info] cloning $MULTI_REPO @ $MULTI_REF"
git clone --depth 1 --branch "$MULTI_REF" "$MULTI_REPO" "$TMP_DIR"

pushd "$TMP_DIR" >/dev/null
echo "[info] building crate ${MULTI_BINARY_CRATE:-ubl_gate}"
cargo build --release -p "${MULTI_BINARY_CRATE:-ubl_gate}"
cp "target/release/${MULTI_BINARY_CRATE:-ubl_gate}" "$TARGET_PATH"
popd >/dev/null

chmod +x "$TARGET_PATH"
echo "[ok] installed $TARGET_PATH"
