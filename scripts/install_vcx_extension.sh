#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage:
  scripts/install_vcx_extension.sh --artifact <path-or-url> [--dest <dir>]

Defaults:
  --dest ~/.ublx/extensions/vcx
USAGE
}

ARTIFACT=""
DEST_DIR="${HOME}/.ublx/extensions/vcx"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifact)
      ARTIFACT="${2:-}"
      shift 2
      ;;
    --dest)
      DEST_DIR="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[error] unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$ARTIFACT" ]]; then
  echo "[error] --artifact is required" >&2
  usage
  exit 1
fi

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[error] missing command: $1" >&2
    exit 1
  }
}

require_cmd tar

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

LOCAL_ARCHIVE="$ARTIFACT"
if [[ "$ARTIFACT" == http://* || "$ARTIFACT" == https://* ]]; then
  require_cmd curl
  LOCAL_ARCHIVE="$TMP_DIR/extension.tar.gz"
  echo "[info] downloading extension artifact"
  curl -fL "$ARTIFACT" -o "$LOCAL_ARCHIVE"
fi

mkdir -p "$DEST_DIR"
rm -rf "$DEST_DIR"/*

tar -xzf "$LOCAL_ARCHIVE" -C "$DEST_DIR"

if [[ ! -f "$DEST_DIR/extension.toml" ]]; then
  echo "[error] invalid package: extension.toml not found" >&2
  exit 1
fi
if [[ ! -x "$DEST_DIR/bin/vcx_pack_cli" ]]; then
  echo "[error] invalid package: bin/vcx_pack_cli not executable" >&2
  exit 1
fi
if [[ ! -x "$DEST_DIR/bin/vcx_enc_cli" ]]; then
  echo "[error] invalid package: bin/vcx_enc_cli not executable" >&2
  exit 1
fi

echo "[ok] installed VCX extension to $DEST_DIR"
