#!/bin/bash
# =============================================================================
# install.sh
# Installation script for PyTorch gfx1150 on Debian 13 (forky)
#
# Automates:
#   1. Prerequisite checks
#   2. ROCm library installation from Debian experimental
#   3. Tensile kernels setup for gfx1150
#   4. PyTorch wheel installation
#   5. Environment activation alias
#
# Portable: derives its own path, no hardcoded absolute paths.
# =============================================================================

set -euo pipefail

# --- Resolve repository root -------------------------------------------------
_SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [ -h "$_SCRIPT_SOURCE" ]; do
    _SCRIPT_DIR="$(cd -P "$(dirname "$_SCRIPT_SOURCE")" && pwd)"
    _SCRIPT_SOURCE="$(readlink "$_SCRIPT_SOURCE")"
    [[ $_SCRIPT_SOURCE != /* ]] && _SCRIPT_SOURCE="$_SCRIPT_DIR/$_SCRIPT_SOURCE"
done
_SCRIPT_DIR="$(cd -P "$(dirname "$_SCRIPT_SOURCE")" && pwd)"
REPO_ROOT="$(cd -P "$_SCRIPT_DIR/.." && pwd)"

# --- Colors ------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()   { err "$@"; exit 1; }

# --- Header ------------------------------------------------------------------
echo ""
echo -e "${BOLD}========================================${NC}"
echo -e "${BOLD} PyTorch gfx1150 Installer for Debian${NC}"
echo -e "${BOLD}========================================${NC}"
echo ""
info "Repository: $REPO_ROOT"
echo ""

# --- 1. Prerequisite checks --------------------------------------------------
info "Checking prerequisites..."

if [ ! -f /etc/debian_version ]; then
    die "This script requires Debian. /etc/debian_version not found."
fi
DEBIAN_VER=$(cat /etc/debian_version)
ok "Debian version: $DEBIAN_VER"

ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
    die "This wheel requires x86_64. Detected: $ARCH"
fi
ok "Architecture: $ARCH"

if ! command -v python3.12 &>/dev/null; then
    warn "python3.12 not found in PATH. The wheel requires Python 3.12."
    warn "Install it with: sudo apt install python3.12 python3.12-venv"
fi
if command -v python3.12 &>/dev/null; then
    PYVER=$(python3.12 --version 2>&1)
    ok "Python: $PYVER"
fi

if ! command -v rocminfo &>/dev/null; then
    warn "rocminfo not found. ROCm will be installed by this script."
else
    GPU_GFX=$(rocminfo 2>/dev/null | grep -oP 'Name:\s*\Kgfx\d+' | head -1 || true)
    if [ -n "$GPU_GFX" ]; then
        ok "GPU detected: $GPU_GFX"
        if [ "$GPU_GFX" != "gfx1150" ]; then
            warn "GPU is $GPU_GFX, but this wheel is built for gfx1150."
            warn "It will NOT work on other architectures."
            read -r -p "Continue anyway? [y/N] " response
            [[ "$response" =~ ^[Yy]$ ]] || die "Aborted."
        fi
    fi
fi

WHEEL_FILE=$(find "$REPO_ROOT/wheel" -name "torch-*.whl" 2>/dev/null | head -1 || true)
if [ -z "$WHEEL_FILE" ]; then
    die "No PyTorch wheel found in $REPO_ROOT/wheel/"
fi
ok "Wheel found: $(basename "$WHEEL_FILE")"

if [ ! -f "$REPO_ROOT/kernels/rocblas_lib/TensileLibrary_lazy_gfx1150.dat" ]; then
    info "Tensile kernels missing. Downloading..."
    "$REPO_ROOT/scripts/download_kernels.sh"
fi
ok "Tensile kernels present"

if ! command -v uv &>/dev/null; then
    die "uv not found. Install it first: https://docs.astral.sh/uv/"
fi
ok "uv: $(uv --version)"

# --- 2. APT pin for experimental --------------------------------------------
info "Configuring APT pin for experimental repository..."

PIN_FILE="/etc/apt/preferences.d/experimental.pref"
if [ ! -f "$PIN_FILE" ]; then
    echo 'Package: *
Pin: release a=experimental
Pin-Priority: -10' | sudo tee "$PIN_FILE" > /dev/null
    ok "Pin created: $PIN_FILE"
else
    ok "Pin already exists: $PIN_FILE"
fi

EXP_LIST="/etc/apt/sources.list.d/experimental.list"
if [ ! -f "$EXP_LIST" ]; then
    echo "deb http://deb.debian.org/debian experimental main" | sudo tee "$EXP_LIST" > /dev/null
    ok "Experimental repository added"
else
    ok "Experimental repository already configured"
fi

sudo apt update

# --- 3. Install ROCm packages ------------------------------------------------
info "Installing ROCm packages from Debian experimental..."
info "This may take several minutes and download ~1 GB."

ROCM_PACKAGES=(
    rocminfo
    hipcc
    librocm-core-dev
    libamd-comgr-dev
    libhsa-runtime-dev
    libamdhip64-dev
    librocblas-dev
    librocsolver-dev
    librocfft-dev
    librocsparse-dev
    libhipblas-dev
    libhipsparse-dev
    libmiopen-dev
    librocrand-dev
    libhiprand-dev
    libhipfft-dev
    libhipsolver-dev
    libhipsolver-fortran-dev
    librocprim-dev
    libhipcub-dev
    librocthrust-dev
    libhipblaslt-dev
    libroctx-dev
    libroctx64-4
    libamd-smi-dev
)

sudo apt install -y -t experimental "${ROCM_PACKAGES[@]}"
ok "ROCm packages installed"

# --- 4. GCC 14 ---------------------------------------------------------------
if ! command -v gcc-14 &>/dev/null; then
    info "Installing GCC 14 (required, GCC 16 breaks ROCm headers)..."
    sudo apt install -y gcc-14 g++-14
fi
ok "GCC 14 available"

# --- 5. Install PyTorch wheel ------------------------------------------------
info "Installing PyTorch wheel..."
info "Target: system Python 3.12 (or active venv, if any)"

if [ -n "${VIRTUAL_ENV:-}" ]; then
    info "Detected active virtualenv: $VIRTUAL_ENV"
    uv pip install --python "$VIRTUAL_ENV/bin/python" "$WHEEL_FILE"
else
    info "No active venv. Installing into system Python 3.12."
    info "If you prefer a venv, activate it and re-run this script."
    uv pip install --python python3.12 "$WHEEL_FILE"
fi
ok "PyTorch installed"

# --- 6. Install activate_rocm.sh alias ---------------------------------------
info "Setting up 'rocm-env' alias..."

ACTIVATE_SCRIPT="$REPO_ROOT/scripts/activate_rocm.sh"
chmod +x "$ACTIVATE_SCRIPT" 2>/dev/null || true

BASHRC="$HOME/.bashrc"
ALIAS_LINE="alias rocm-env='source $ACTIVATE_SCRIPT'"

if grep -qF "alias rocm-env=" "$BASHRC" 2>/dev/null; then
    ok "Alias already present in $BASHRC"
else
    echo "" >> "$BASHRC"
    echo "# PyTorch gfx1150 environment (added by install.sh)" >> "$BASHRC"
    echo "$ALIAS_LINE" >> "$BASHRC"
    ok "Alias added to $BASHRC"
fi

# --- 7. Final verification ---------------------------------------------------
echo ""
echo -e "${BOLD}========================================${NC}"
echo -e "${GREEN}${BOLD} Installation complete${NC}"
echo -e "${BOLD}========================================${NC}"
echo ""
info "To verify, open a new shell and run:"
echo "  rocm-env"
echo "  python -c \"import torch; x = torch.randn(1000, 1000, device='cuda'); print((x @ x).device)\""
echo ""
info "Expected output: cuda:0"
echo ""
info "For troubleshooting, see: $REPO_ROOT/docs/"
echo ""
