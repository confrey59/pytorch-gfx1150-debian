#!/bin/bash
# =============================================================================
# download_kernels.sh
# Downloads Tensile kernels for gfx1150 from the community-maintained
# repository and places them in kernels/rocblas_lib/.
#
# These kernels are NOT redistributed with this repository because their
# license is not explicitly declared. They are downloaded directly from the
# upstream source.
# =============================================================================

set -euo pipefail

_SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [ -h "$_SCRIPT_SOURCE" ]; do
    _SCRIPT_DIR="$(cd -P "$(dirname "$_SCRIPT_SOURCE")" && pwd)"
    _SCRIPT_SOURCE="$(readlink "$_SCRIPT_SOURCE")"
    [[ $_SCRIPT_SOURCE != /* ]] && _SCRIPT_SOURCE="$_SCRIPT_DIR/$_SCRIPT_SOURCE"
done
_SCRIPT_DIR="$(cd -P "$(dirname "$_SCRIPT_SOURCE")" && pwd)"
REPO_ROOT="$(cd -P "$_SCRIPT_DIR/.." && pwd)"

KERNELS_DIR="$REPO_ROOT/kernels/rocblas_lib"
UPSTREAM_URL="https://github.com/likelovewant/ROCmLibs-for-gfx1103-AMD780M-APU/releases/download/v0.6.2.4/rocm.gfx1150.for.hip.skd.6.2.4.7z"

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()   { echo -e "${GREEN}[OK]${NC}    $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }

if [ -f "$KERNELS_DIR/TensileLibrary_lazy_gfx1150.dat" ]; then
    ok "Kernels already present in $KERNELS_DIR"
    exit 0
fi

info "Tensile kernels not found. Downloading from upstream..."

# Check dependencies
for cmd in wget 7z; do
    if ! command -v "$cmd" &>/dev/null; then
        err "Required command not found: $cmd"
        err "Install with: sudo apt install wget 7zip"
        exit 1
    fi
done

TMP_ARCHIVE=$(mktemp /tmp/rocm_gfx1150_XXXXXX.7z)
trap 'rm -f "$TMP_ARCHIVE"' EXIT

info "Downloading: $UPSTREAM_URL"
wget -q --show-progress -O "$TMP_ARCHIVE" "$UPSTREAM_URL"

info "Extracting to: $KERNELS_DIR"
mkdir -p "$KERNELS_DIR"
TMP_EXTRACT=$(mktemp -d)
7z x "$TMP_ARCHIVE" -o"$TMP_EXTRACT" > /dev/null

# The archive contains a "library" subdirectory
LIB_SOURCE=$(find "$TMP_EXTRACT" -type d -name "library" | head -1)
if [ -z "$LIB_SOURCE" ]; then
    err "Could not find 'library' directory in archive."
    rm -rf "$TMP_EXTRACT"
    exit 1
fi

cp -r "$LIB_SOURCE"/* "$KERNELS_DIR/"
rm -rf "$TMP_EXTRACT"

FILE_COUNT=$(ls "$KERNELS_DIR" | wc -l)
ok "Kernels installed: $FILE_COUNT files in $KERNELS_DIR"