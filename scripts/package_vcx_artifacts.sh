#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VCX_DIR="$ROOT_DIR/vcx-pack"
EXT_DIR="$ROOT_DIR/extensions/vcx"
DIST_DIR="$ROOT_DIR/dist"

usage() {
  cat <<USAGE
Usage:
  scripts/package_vcx_artifacts.sh --version <semver> [--target <triple>] [--mode <all|binaries|extension>] [--no-build]

Examples:
  scripts/package_vcx_artifacts.sh --version 0.1.0 --target x86_64-unknown-linux-gnu
  scripts/package_vcx_artifacts.sh --version 0.1.0 --mode extension
USAGE
}

VERSION=""
TARGET=""
MODE="all"
NO_BUILD="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="${2:-}"
      shift 2
      ;;
    --target)
      TARGET="${2:-}"
      shift 2
      ;;
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --no-build)
      NO_BUILD="true"
      shift
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

if [[ -z "$VERSION" ]]; then
  echo "[error] --version is required" >&2
  usage
  exit 1
fi

if [[ -z "$TARGET" ]]; then
  TARGET="$(rustc -vV | awk '/host:/{print $2}')"
fi

if [[ "$MODE" != "all" && "$MODE" != "binaries" && "$MODE" != "extension" ]]; then
  echo "[error] --mode must be one of: all, binaries, extension" >&2
  exit 1
fi

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[error] missing command: $1" >&2
    exit 1
  }
}

sha256_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file"
  else
    shasum -a 256 "$file"
  fi
}

require_cmd cargo
require_cmd tar
require_cmd rustc

BIN_OUT="$DIST_DIR/bin/$VERSION/$TARGET"
EXT_OUT="$DIST_DIR/extensions/vcx/$VERSION/$TARGET"

mkdir -p "$BIN_OUT" "$EXT_OUT/bin"

if [[ "$NO_BUILD" != "true" ]]; then
  echo "[info] building vcx binaries for target $TARGET"
  if [[ "$TARGET" == "$(rustc -vV | awk '/host:/{print $2}')" ]]; then
    (cd "$VCX_DIR" && cargo build --release -p vcx_pack_cli -p vcx_enc_cli)
    BUILD_DIR="$VCX_DIR/target/release"
  else
    (cd "$VCX_DIR" && cargo build --release --target "$TARGET" -p vcx_pack_cli -p vcx_enc_cli)
    BUILD_DIR="$VCX_DIR/target/$TARGET/release"
  fi
else
  if [[ "$TARGET" == "$(rustc -vV | awk '/host:/{print $2}')" ]]; then
    BUILD_DIR="$VCX_DIR/target/release"
  else
    BUILD_DIR="$VCX_DIR/target/$TARGET/release"
  fi
fi

cp "$BUILD_DIR/vcx_pack_cli" "$BIN_OUT/vcx_pack_cli"
cp "$BUILD_DIR/vcx_enc_cli" "$BIN_OUT/vcx_enc_cli"
chmod +x "$BIN_OUT/vcx_pack_cli" "$BIN_OUT/vcx_enc_cli"

if [[ "$MODE" == "all" || "$MODE" == "binaries" ]]; then
  BIN_TARBALL="$DIST_DIR/ubl-vcx-binaries-v${VERSION}-${TARGET}.tar.gz"
  tar -C "$BIN_OUT" -czf "$BIN_TARBALL" vcx_pack_cli vcx_enc_cli
  sha256_file "$BIN_TARBALL" > "$BIN_TARBALL.sha256"
  echo "[ok] binaries artifact: $BIN_TARBALL"
fi

if [[ "$MODE" == "all" || "$MODE" == "extension" ]]; then
  cp "$EXT_DIR/README.md" "$EXT_OUT/README.md"
  cp "$BIN_OUT/vcx_pack_cli" "$EXT_OUT/bin/vcx_pack_cli"
  cp "$BIN_OUT/vcx_enc_cli" "$EXT_OUT/bin/vcx_enc_cli"

  sed \
    -e "s/^version = .*/version = \"$VERSION\"/" \
    "$EXT_DIR/extension.toml" > "$EXT_OUT/extension.toml"

  EXT_TARBALL="$DIST_DIR/ublx-extension-vcx-v${VERSION}-${TARGET}.tar.gz"
  tar -C "$EXT_OUT" -czf "$EXT_TARBALL" extension.toml README.md bin
  sha256_file "$EXT_TARBALL" > "$EXT_TARBALL.sha256"
  echo "[ok] extension artifact: $EXT_TARBALL"
fi

echo "[done] version=$VERSION target=$TARGET mode=$MODE"
