#!/bin/bash
# =============================================================================
# activate_rocm.sh
# Environment activation script for PyTorch gfx1150 (Radeon 890M) build
# Source this file before running any PyTorch/ROCm workload.
# =============================================================================

# --- Critical ROCm overrides for gfx1150 --------------------------------
export HSA_OVERRIDE_GFX_VERSION=11.5.0
export GPU_MAX_HW_QUEUES=4
export HSA_ENABLE_SDMA=0
export HIP_FORCE_DEV_KERNARG=1

# --- PyTorch performance flags ------------------------------------------
export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1

# --- Local Tensile kernels (portable, inside the project) ---------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROCBLAS_TENSILE_LIBPATH="${SCRIPT_DIR}/../kernels/rocblas_lib"

# Note: TORCH_BLAS_PREFER_HIPBLASLT is intentionally NOT set.
# The local hipBLASLt kernels are incomplete for gfx1150; rocBLAS works.

echo "[rocm-env] gfx1150 environment activated"
echo "  HSA_OVERRIDE_GFX_VERSION = $HSA_OVERRIDE_GFX_VERSION"
echo "  ROCBLAS_TENSILE_LIBPATH = $ROCBLAS_TENSILE_LIBPATH"
