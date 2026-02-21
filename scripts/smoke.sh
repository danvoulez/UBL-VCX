#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

load_env_if_present
HOST="${UBL_GATE_BIND:-127.0.0.1:4000}"
BASE_URL="http://$HOST"

require_cmd curl

echo "[info] checking healthz"
curl -fsS "$BASE_URL/healthz" >/dev/null

echo "[info] posting smoke chip"
RESP="$(curl -fsS -X POST "$BASE_URL/v1/chips" \
  -H 'content-type: application/json' \
  -d '{"@type":"app/ping","@id":"smoke-1","@ver":"1.0.0","@world":"a/app","body":{"msg":"ok"}}')"

echo "$RESP" | grep -Eq 'receipt|output|cid' || fail "unexpected response: $RESP"
echo "[ok] smoke passed"
