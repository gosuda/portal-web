#!/usr/bin/env bash
set -euo pipefail

# Build script for Portal-Web WASM service worker runtime
#
# - Compiles Go WASM binary
# - Copies Go wasm_exec.js runtime into dist/
# - Copies public/ assets into dist/
# - Places compiled WASM under dist/_static/portal.wasm
# - Patches service-worker.js wasmManifest from parameters

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUBLIC_DIR="${ROOT_DIR}/public"
DIST_DIR="${ROOT_DIR}/dist"
STATIC_DIR="${DIST_DIR}/_static"

# Default values for wasmManifest (can be overridden via env)
DEFAULT_BOOTSTRAPS='wss://portal.gosuda.org/relay,wss://portal.thumbgo.kr/relay,wss://portal.iwanhae.kr/relay,wss://portal.lmmt.eu.org/relay'
DEFAULT_WASM_URL='/_static/portal.wasm'
DEFAULT_LEASE_ID='HXLAFMYCASEISRUSWXUIO3M72A'

BOOTSTRAPS="${BOOTSTRAPS:-$DEFAULT_BOOTSTRAPS}"
WASM_URL="${WASM_URL:-$DEFAULT_WASM_URL}"
LEASE_ID="${LEASE_ID:-$DEFAULT_LEASE_ID}"

WASM_OUTPUT="${WASM_OUTPUT:-${STATIC_DIR}/portal.wasm}"
WASM_PKG="${WASM_PKG:-./cmd/wasm}"

echo "[build] root        = ${ROOT_DIR}"
echo "[build] public      = ${PUBLIC_DIR}"
echo "[build] dist        = ${DIST_DIR}"
echo "[build] static      = ${STATIC_DIR}"
echo "[build] output wasm = ${WASM_OUTPUT}"
echo "[build] pkg         = ${WASM_PKG}"
echo "[build] bootstraps  = ${BOOTSTRAPS}"
echo "[build] wasmUrl     = ${WASM_URL}"
echo "[build] leaseID     = ${LEASE_ID}"

echo "[build] Cleaning dist directory..."
rm -rf "${DIST_DIR}"
mkdir -p "${STATIC_DIR}"

echo "[build] Copying public assets -> dist/ ..."
cp -R "${PUBLIC_DIR}/." "${DIST_DIR}/"

# Patch wasmManifest block in dist/service-worker.js using parameters
SERVICE_WORKER_JS="${DIST_DIR}/service-worker.js"
if [[ -f "${SERVICE_WORKER_JS}" ]]; then
  echo "[build] Patching wasmManifest in service-worker.js with sed ..."
  sed -i.bak \
    -e "s#bootstraps: \".*\"#bootstraps: \"${BOOTSTRAPS}\"#" \
    -e "s#wasmUrl: \".*\"#wasmUrl: \"${WASM_URL}\"#" \
    -e "s#leaseID: \".*\"#leaseID: \"${LEASE_ID}\"#" \
    "${SERVICE_WORKER_JS}"
  rm -f "${SERVICE_WORKER_JS}.bak"
else
  echo "[build] WARNING: ${SERVICE_WORKER_JS} not found, cannot patch wasmManifest" >&2
fi

echo "[build] Updating wasm_exec.js from current Go toolchain..."
GOROOT="$(go env GOROOT)"
WASM_EXEC_SRC="${GOROOT}/lib/wasm/wasm_exec.js"

if [[ ! -f "${WASM_EXEC_SRC}" ]]; then
  echo "[build] ERROR: wasm_exec.js not found in Go toolchain at: ${WASM_EXEC_SRC}" >&2
  exit 1
fi

cp "${WASM_EXEC_SRC}" "${DIST_DIR}/wasm_exec.js"
echo "[build] Copied wasm_exec.js -> ${DIST_DIR}/wasm_exec.js"

echo "[build] Compiling Go WASM binary..."
export GOOS=js
export GOARCH=wasm

go build -trimpath -ldflags="-s -w" -o "${WASM_OUTPUT}" "${WASM_PKG}"

echo "[build] Built WASM binary at ${WASM_OUTPUT}"
echo "[build] Done."