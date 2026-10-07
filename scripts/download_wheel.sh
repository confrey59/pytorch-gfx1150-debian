#!/bin/bash
# =============================================================================
# download_wheel.sh
# Downloads the pre-built PyTorch wheel for gfx1150 from GitHub Releases.
#
# The wheel (~378 MB) exceeds GitHub's 100 MB per-file limit and is therefore
# distributed as a Release asset rather than stored in the Git repository.
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

WHEEL_DIR="$REPO_ROOT/wheel"
WHEEL_NAME="torch-2.16.0a0+gite42541f-cp312-cp312-linux_x86_64.whl"
WHEEL_URL="https://github.com/confrey59/pytorch-gfx1150-debian/releases/download/v1.0.0/${WHEEL_NAME}"

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()   { echo -e "${GREEN}[OK]${NC}    $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }

if [ -f "$WHEEL_DIR/$WHEEL_NAME" ]; then
    ok "Wheel already present: $WHEEL_NAME"
    exit 0
fi

info "Wheel not found. Downloading from GitHub Releases..."
info "Source: $WHEEL_URL"
info "Size: ~378 MB"

mkdir -p "$WHEEL_DIR"

if ! command -v wget &>/dev/null; then
    err "Required command not found: wget"
    err "Install with: sudo apt install wget"
    exit 1
fi

wget -q --show-progress -O "$WHEEL_DIR/$WHEEL_NAME" "$WHEEL_URL"

# Verify the file was downloaded completely
if [ ! -s "$WHEEL_DIR/$WHEEL_NAME" ]; then
    err "Download failed or produced an empty file."
    rm -f "$WHEEL_DIR/$WHEEL_NAME"
    exit 1
fi

# Verify it's a valid wheel (PKZIP magic bytes)
if ! file "$WHEEL_DIR/$WHEEL_NAME" | grep -q "Zip archive"; then
    err "Downloaded file is not a valid wheel (not a ZIP archive)."
    err "It may be an HTML error page. Check the URL: $WHEEL_URL"
    exit 1
fi

SIZE=$(du -h "$WHEEL_DIR/$WHEEL_NAME" | cut -f1)
ok "Wheel downloaded: $WHEEL_NAME ($SIZE)"