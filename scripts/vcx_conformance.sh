#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VCX_PACK_DIR="$ROOT_DIR/vcx-pack"
POS_VECTOR_DIR="$ROOT_DIR/docs/vcx/conformance/vectors/v1/positive"
NEG_VECTOR_DIR="$ROOT_DIR/docs/vcx/conformance/vectors/v1/negative"
REPORT_FILE=""
KEEP_ARTIFACTS=false

usage() {
  cat <<'EOF'
Usage:
  scripts/vcx_conformance.sh [options]

Options:
  --report-file <path>   Optional output report JSON path
  --keep-artifacts       Keep temporary generated pack files
  -h, --help             Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report-file) REPORT_FILE="${2:-}"; shift 2 ;;
    --keep-artifacts) KEEP_ARTIFACTS=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 2
  fi
}

need_cmd cargo
need_cmd jq
need_cmd dd
need_cmd awk
need_cmd grep
need_cmd tr

if [[ ! -d "$POS_VECTOR_DIR" ]]; then
  echo "Missing positive vector directory: $POS_VECTOR_DIR" >&2
  exit 2
fi
if [[ ! -d "$NEG_VECTOR_DIR" ]]; then
  echo "Missing negative vector directory: $NEG_VECTOR_DIR" >&2
  exit 2
fi

tmp_dir="$(mktemp -d)"
if [[ "$KEEP_ARTIFACTS" != true ]]; then
  trap 'rm -rf "$tmp_dir"' EXIT
fi

positive_dir="$tmp_dir/positive"
negative_dir="$tmp_dir/negative"
positive_meta_dir="$tmp_dir/positive_meta"
mkdir -p "$positive_dir" "$negative_dir" "$positive_meta_dir"

positive_results_file="$tmp_dir/positive_results.ndjson"
negative_results_file="$tmp_dir/negative_results.ndjson"
touch "$positive_results_file" "$negative_results_file"

resolve_repo_path() {
  local rel="$1"
  if [[ "$rel" == /* ]]; then
    printf '%s\n' "$rel"
  else
    printf '%s\n' "$ROOT_DIR/$rel"
  fi
}

write_byte() {
  local file="$1"
  local off="$2"
  local val="$3"
  if ! [[ "$off" =~ ^[0-9]+$ ]]; then
    echo "Invalid byte offset: $off" >&2
    exit 1
  fi
  if ! [[ "$val" =~ ^[0-9]+$ ]] || [[ "$val" -lt 0 || "$val" -gt 255 ]]; then
    echo "Invalid byte value: $val" >&2
    exit 1
  fi
  local hex
  hex="$(printf '%02x' "$val")"
  printf "\\x${hex}" | dd of="$file" bs=1 seek="$off" conv=notrunc status=none
}

apply_mutation() {
  local kind="$1"
  local file="$2"
  local manifest_off="$3"
  local index_off="$4"
  local payload_off="$5"
  local trailer_off="$6"
  case "$kind" in
    nonzero_index_entry_padding)
      write_byte "$file" $((index_off + 16 + 95)) 1
      ;;
    nonzero_header_padding)
      write_byte "$file" 95 1
      ;;
    bad_header_len)
      write_byte "$file" 8 95
      ;;
    bad_magic)
      write_byte "$file" 0 88
      ;;
    missing_merkle_flag)
      write_byte "$file" 6 0
      ;;
    unexpected_manifest_offset)
      write_byte "$file" 12 $(((manifest_off + 1) & 255))
      ;;
    bad_index_magic)
      write_byte "$file" "$index_off" 88
      ;;
    nonzero_index_reserved)
      write_byte "$file" $((index_off + 12)) 1
      ;;
    nonzero_merkle_reserved)
      write_byte "$file" $((trailer_off + 13)) 1
      ;;
    bad_merkle_magic)
      write_byte "$file" "$trailer_off" 88
      ;;
    payload_hash_mismatch)
      write_byte "$file" "$payload_off" 255
      ;;
    region_overlap_manifest_index)
      write_byte "$file" 28 0
      ;;
    misaligned_index_offset)
      write_byte "$file" 28 $(((index_off + 1) & 255))
      ;;
    unsupported_cid_algo)
      write_byte "$file" $((index_off + 16)) 2
      ;;
    bad_cid_len)
      write_byte "$file" $((index_off + 16 + 1)) 31
      ;;
    payload_entry_offset_not_aligned)
      write_byte "$file" $((index_off + 16 + 38)) $(((payload_off + 1) & 255))
      ;;
    payload_entry_out_of_region)
      write_byte "$file" $((index_off + 16 + 38)) 0
      ;;
    unsupported_merkle_flags)
      write_byte "$file" $((trailer_off + 6)) 1
      ;;
    merkle_leaf_count_mismatch)
      write_byte "$file" $((trailer_off + 8)) 4
      ;;
    region_out_of_bounds_payload)
      write_byte "$file" 53 255
      ;;
    *)
      echo "Unknown mutation kind: $kind" >&2
      exit 1
      ;;
  esac
}

find_positive_meta_by_id() {
  local target_id="$1"
  local f
  for f in "$positive_meta_dir"/*.json; do
    [[ -f "$f" ]] || continue
    if [[ "$(jq -r '.id' "$f")" == "$target_id" ]]; then
      printf '%s\n' "$f"
      return 0
    fi
  done
  return 1
}

positive_vectors=()
while IFS= read -r vec; do
  positive_vectors+=("$vec")
done < <(find "$POS_VECTOR_DIR" -maxdepth 1 -type f -name '*.json' | sort)

negative_vectors=()
while IFS= read -r vec; do
  negative_vectors+=("$vec")
done < <(find "$NEG_VECTOR_DIR" -maxdepth 1 -type f -name '*.json' | sort)

if [[ "${#positive_vectors[@]}" -eq 0 ]]; then
  echo "No positive vectors found in $POS_VECTOR_DIR" >&2
  exit 1
fi
if [[ "${#negative_vectors[@]}" -eq 0 ]]; then
  echo "No negative vectors found in $NEG_VECTOR_DIR" >&2
  exit 1
fi

# Phase 1: run positive vectors (build + verify)
for vec in "${positive_vectors[@]}"; do
  vec_id="$(jq -r '.id' "$vec")"
  strict_unc1="$(jq -r '.operation.build_strict_unc1 // true' "$vec")"
  verify_full="$(jq -r '.operation.verify_full // true' "$vec")"
  manifest_rel="$(jq -r '.inputs.manifest' "$vec")"
  manifest_path="$(resolve_repo_path "$manifest_rel")"
  if [[ ! -f "$manifest_path" ]]; then
    echo "Positive vector manifest not found: $manifest_path" >&2
    exit 2
  fi

  payload_args=()
  while IFS= read -r spec; do
    [[ -n "$spec" ]] || continue
    mime="${spec%%=*}"
    rel_path="${spec#*=}"
    abs_path="$(resolve_repo_path "$rel_path")"
    if [[ ! -f "$abs_path" ]]; then
      echo "Positive vector payload not found: $abs_path" >&2
      exit 2
    fi
    payload_args+=(--payload "$mime=$abs_path")
  done < <(jq -r '.inputs.payloads[]?' "$vec")

  if [[ "${#payload_args[@]}" -eq 0 ]]; then
    echo "Positive vector has no payloads: $vec" >&2
    exit 2
  fi

  safe_id="$(printf '%s' "$vec_id" | tr '/:' '__')"
  pack_path="$positive_dir/${safe_id}.vcx"
  build_cmd=(cargo run -p vcx_pack_cli -- build --manifest "$manifest_path" --out "$pack_path")
  if [[ "$strict_unc1" == "true" ]]; then
    build_cmd+=(--strict-unc1)
  else
    build_cmd+=(--strict-unc1=false)
  fi
  build_cmd+=("${payload_args[@]}")

  set +e
  build_output="$(
    cd "$VCX_PACK_DIR" && "${build_cmd[@]}" 2>&1
  )"
  build_status=$?
  set -e

  build_result="pass"
  if [[ "$build_status" -ne 0 ]]; then
    build_result="fail"
  fi

  verify_output=""
  verify_result="skip"
  merkle_root=""
  manifest_off=""
  index_off=""
  payload_off=""
  trailer_off=""

  if [[ "$build_result" == "pass" ]]; then
    manifest_off="$(printf '%s\n' "$build_output" | awk '/manifest bytes at/ {print $4; exit}')"
    index_off="$(printf '%s\n' "$build_output" | awk '/index bytes at/ {print $4; exit}')"
    payload_off="$(printf '%s\n' "$build_output" | awk '/payload region at/ {print $4; exit}')"
    trailer_off="$(printf '%s\n' "$build_output" | awk '/trailer at/ {print $3; exit}')"

    verify_cmd=(cargo run -p vcx_pack_cli -- verify --input "$pack_path")
    if [[ "$verify_full" == "true" ]]; then
      verify_cmd+=(--full)
    fi
    set +e
    verify_output="$(
      cd "$VCX_PACK_DIR" && "${verify_cmd[@]}" 2>&1
    )"
    verify_status=$?
    set -e
    if [[ "$verify_status" -eq 0 ]]; then
      verify_result="pass"
      merkle_root="$(printf '%s\n' "$verify_output" | awk '/merkle root:/ {print $3; exit}')"
    else
      verify_result="fail"
    fi
  fi

  jq -n \
    --arg id "$vec_id" \
    --arg file "$(basename "$vec")" \
    --arg pack_path "$pack_path" \
    --arg build "$build_result" \
    --arg verify "$verify_result" \
    --arg strict_unc1 "$strict_unc1" \
    --arg verify_full "$verify_full" \
    --arg merkle_root "$merkle_root" \
    --arg manifest_off "$manifest_off" \
    --arg index_off "$index_off" \
    --arg payload_off "$payload_off" \
    --arg trailer_off "$trailer_off" \
    --arg build_output "$build_output" \
    --arg verify_output "$verify_output" \
    '{
      id:$id,
      file:$file,
      pack_path:$pack_path,
      strict_unc1:$strict_unc1,
      verify_full:$verify_full,
      build_result:$build,
      verify_result:$verify,
      merkle_root:$merkle_root,
      offsets:{
        manifest_off:$manifest_off,
        index_off:$index_off,
        payload_off:$payload_off,
        trailer_off:$trailer_off
      },
      logs:{
        build:$build_output,
        verify:$verify_output
      }
    }' > "$positive_meta_dir/${safe_id}.json"

  jq -n \
    --arg id "$vec_id" \
    --arg file "$(basename "$vec")" \
    --arg build "$build_result" \
    --arg verify "$verify_result" \
    --arg merkle_root "$merkle_root" \
    '{
      id:$id,
      file:$file,
      build_result:$build,
      verify_result:$verify,
      merkle_root:$merkle_root
    }' >> "$positive_results_file"
done

# Phase 2: run negative vectors against declared positive base vector
for vec in "${negative_vectors[@]}"; do
  vec_id="$(jq -r '.id' "$vec")"
  base_id="$(jq -r '.inputs.base_vector // empty' "$vec")"
  mutation_kind="$(jq -r '.mutation.kind // .mutation // empty' "$vec")"
  expected_error="$(jq -r '.expected.error' "$vec")"
  neg_verify_full="$(jq -r '.operation.verify_full // false' "$vec")"

  if [[ -z "$base_id" ]]; then
    jq -n \
      --arg id "$vec_id" \
      --arg file "$(basename "$vec")" \
      --arg mutation "$mutation_kind" \
      --arg expected_error "$expected_error" \
      --arg reason "missing_base_vector" \
      '{
        id:$id,
        file:$file,
        mutation:$mutation,
        expected_error:$expected_error,
        pass:false,
        reason:$reason
      }' >> "$negative_results_file"
    continue
  fi

  base_meta="$(find_positive_meta_by_id "$base_id" || true)"
  if [[ -z "$base_meta" ]]; then
    jq -n \
      --arg id "$vec_id" \
      --arg file "$(basename "$vec")" \
      --arg mutation "$mutation_kind" \
      --arg expected_error "$expected_error" \
      --arg reason "base_vector_not_found" \
      --arg base_vector "$base_id" \
      '{
        id:$id,
        file:$file,
        mutation:$mutation,
        expected_error:$expected_error,
        pass:false,
        reason:$reason,
        base_vector:$base_vector
      }' >> "$negative_results_file"
    continue
  fi

  base_build="$(jq -r '.build_result' "$base_meta")"
  base_verify="$(jq -r '.verify_result' "$base_meta")"
  base_pack_path="$(jq -r '.pack_path' "$base_meta")"
  manifest_off="$(jq -r '.offsets.manifest_off' "$base_meta")"
  index_off="$(jq -r '.offsets.index_off' "$base_meta")"
  payload_off="$(jq -r '.offsets.payload_off' "$base_meta")"
  trailer_off="$(jq -r '.offsets.trailer_off' "$base_meta")"

  if [[ "$base_build" != "pass" || "$base_verify" != "pass" ]]; then
    jq -n \
      --arg id "$vec_id" \
      --arg file "$(basename "$vec")" \
      --arg mutation "$mutation_kind" \
      --arg expected_error "$expected_error" \
      --arg reason "base_vector_not_verified" \
      --arg base_vector "$base_id" \
      '{
        id:$id,
        file:$file,
        mutation:$mutation,
        expected_error:$expected_error,
        pass:false,
        reason:$reason,
        base_vector:$base_vector
      }' >> "$negative_results_file"
    continue
  fi

  safe_id="$(printf '%s' "$vec_id" | tr '/:' '__')"
  tampered_path="$negative_dir/${safe_id}.vcx"
  cp "$base_pack_path" "$tampered_path"
  apply_mutation "$mutation_kind" "$tampered_path" "$manifest_off" "$index_off" "$payload_off" "$trailer_off"

  neg_verify_cmd=(cargo run -p vcx_pack_cli -- verify --input "$tampered_path")
  if [[ "$neg_verify_full" == "true" ]]; then
    neg_verify_cmd+=(--full)
  fi
  set +e
  neg_output="$(
    cd "$VCX_PACK_DIR" && "${neg_verify_cmd[@]}" 2>&1
  )"
  neg_status=$?
  set -e

  neg_pass=false
  if [[ "$neg_status" -ne 0 ]] && printf '%s\n' "$neg_output" | grep -F -q "$expected_error"; then
    neg_pass=true
  fi

  jq -n \
    --arg id "$vec_id" \
    --arg file "$(basename "$vec")" \
    --arg mutation "$mutation_kind" \
    --arg expected_error "$expected_error" \
    --arg output "$neg_output" \
    --arg base_vector "$base_id" \
    --argjson verify_full "$neg_verify_full" \
    --argjson pass "$neg_pass" \
    '{
      id:$id,
      file:$file,
      base_vector:$base_vector,
      mutation:$mutation,
      verify_full:$verify_full,
      expected_error:$expected_error,
      pass:$pass,
      output:$output
    }' >> "$negative_results_file"
done

positive_results_json="$(jq -s '.' "$positive_results_file")"
negative_results_json="$(jq -s '.' "$negative_results_file")"

positive_total="$(jq 'length' <<<"$positive_results_json")"
positive_pass_count="$(jq '[.[] | select(.build_result == "pass" and .verify_result == "pass")] | length' <<<"$positive_results_json")"
negative_total="$(jq 'length' <<<"$negative_results_json")"
negative_pass_count="$(jq '[.[] | select(.pass == true)] | length' <<<"$negative_results_json")"

run_ok=false
if [[ "$positive_total" -gt 0 && "$negative_total" -gt 0 && "$positive_pass_count" -eq "$positive_total" && "$negative_pass_count" -eq "$negative_total" ]]; then
  run_ok=true
fi

report="$(
  jq -n \
    --arg now "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --arg run_dir "$tmp_dir" \
    --argjson ok "$run_ok" \
    --argjson positive "$positive_results_json" \
    --argjson negative "$negative_results_json" \
    --argjson positive_total "$positive_total" \
    --argjson positive_pass_count "$positive_pass_count" \
    --argjson negative_total "$negative_total" \
    --argjson negative_pass_count "$negative_pass_count" \
    '{
      "@type":"vcx/conformance.report",
      generated_at:$now,
      ok:$ok,
      results:{
        positive_total:$positive_total,
        positive_pass_count:$positive_pass_count,
        positive:$positive,
        negative_total:$negative_total,
        negative_pass_count:$negative_pass_count,
        negative:$negative
      },
      evidence:{
        temp_dir:$run_dir
      }
    }'
)"

if [[ -n "$REPORT_FILE" ]]; then
  mkdir -p "$(dirname "$REPORT_FILE")"
  printf '%s\n' "$report" > "$REPORT_FILE"
fi

printf '%s\n' "$report"

if [[ "$run_ok" != true ]]; then
  exit 1
fi
