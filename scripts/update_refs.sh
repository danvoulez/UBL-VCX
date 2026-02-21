#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOCK_FILE="$ROOT_DIR/contracts/VERSIONS.lock"

usage() {
  echo "usage: $0 core <new-ref>"
  exit 1
}

[ "$#" -eq 2 ] || usage
TARGET="$1"
NEW_REF="$2"

case "$TARGET" in
  core)
    sed -i.bak "s/^CORE_REF=.*/CORE_REF=$NEW_REF/" "$LOCK_FILE"
    ;;
  *)
    usage
    ;;
esac

rm -f "$LOCK_FILE.bak"
echo "[ok] updated $TARGET ref to $NEW_REF"
