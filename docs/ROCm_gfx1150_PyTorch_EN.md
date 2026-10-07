# PyTorch on ROCm for Radeon 890M (gfx1150) — Debian 13 forky

**Last updated**: 2026-10-07
**Version**: 1.0
**Status**: Working and validated

---

## 1. Purpose

Document the complete procedure to build PyTorch from source with native ROCm backend on **AMD Radeon 890M (gfx1150)**, Strix Point APU of the ASUS Zenbook S16 UM5606GA notebook, under **Debian 13 (forky)**.

This document is **specific to this machine** and this combination of versions. It is not a universal guide.

---

## 2. Reference specifications

| Component | Version |
| :--- | :--- |
| GPU | AMD Radeon 890M (gfx1150, RDNA 3.5) |
| CPU | AMD Ryzen AI 9 465 (Zen 5, 10c/20t) |
| RAM | 32 GB (24 GB GTT) |
| OS | Debian 13 forky |
| Kernel | 6.19.14+deb13-amd64 |
| ROCm | 7.2.4 (from Debian experimental) |
| HIP | 7.2.5 (hipcc from experimental) |
| LLVM/Clang | 22 (path `/usr/lib/llvm-22`) |
| GCC | 14 (NOT 16, due to `__noinline__` bug) |
| PyTorch | 2.16.0a0+gite42541f (built from source) |
| Python | 3.12.13 |

---

## 3. Key paths

| Item | Path |
| :--- | :--- |
| PyTorch sources | `/media/dati/Programmi/AI/pytorch-gfx1150-build/` |
| TRELLIS-AMD venv | `/media/dati/Programmi/AI/TRELLIS-AMD/.venv/` |
| Local Tensile kernels | `/media/dati/Programmi/AI/pytorch-gfx1150-build/.rocm_kernels/` |
| Activation script | `/media/dati/Programmi/AI/pytorch-gfx1150-build/activate_rocm.sh` |
| Bash alias | `rocm-env` (defined in `~/.bashrc`) |
| Swap file | `/media/dati/swapfile` (32 GB) |
| Build log | `/media/dati/Programmi/AI/pytorch_build.log` |

---

## 4. Installed ROCm dependencies

### From Debian forky (stable/testing)
```
libhsa-runtime64-1   (updated to 7.2.4 from experimental)
libhsa-runtime-dev
libamdhip64-dev
libamd-comgr-dev
```

### From Debian experimental
All ROCm libraries at version **7.2.4**:
```
rocminfo
hipcc
librocblas-dev, librocsolver-dev, librocfft-dev, librocsparse-dev
libhipblas-dev, libhipsparse-dev, libmiopen-dev
librocrand-dev, libhiprand-dev
libhipfft-dev, libhipsolver-dev, libhipsolver-fortran-dev
librocprim-dev, libhipcub-dev, librocthrust-dev
libhipblaslt-dev
libroctx-dev, libroctx64-4
librocm-core-dev
libamd-smi-dev
```

**APT pin**: the experimental repository is configured with priority `-10` in `/etc/apt/preferences.d/experimental.pref`, to avoid unwanted automatic updates.

### Tensile kernels for gfx1150
Debian **does not include** Tensile kernels for gfx1150 in the `librocblas5` package (known bug). The kernels were downloaded from:
- Repository: `likelovewant/ROCmLibs-for-gfx1103-AMD780M-APU`
- File: `rocm.gfx1150.for.hip.skd.6.2.4.7z`
- Extracted to: `/media/dati/Programmi/AI/pytorch-gfx1150-build/.rocm_kernels/rocblas_lib/`

---

## 5. Required environment variables

These variables are **essential** for gfx1150 operation. They are defined in `activate_rocm.sh` and activated with the `rocm-env` alias.

```bash
# Map gfx1150 to gfx1151 so rocBLAS can load Tensile kernels
export HSA_OVERRIDE_GFX_VERSION=11.5.0

# Prevent silent hangs on RDNA 3.x APUs
export GPU_MAX_HW_QUEUES=4

# Disable SDMA for stability on unified memory
export HSA_ENABLE_SDMA=0

# Prevent rare SIGBUS in multi-batch inference
export HIP_FORCE_DEV_KERNARG=1

# Enable experimental AOTriton for attention kernels
export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1

# Path to local Tensile kernels for rocBLAS
export ROCBLAS_TENSILE_LIBPATH=/media/dati/Programmi/AI/pytorch-gfx1150-build/.rocm_kernels/rocblas_lib

# DO NOT set TORCH_BLAS_PREFER_HIPBLASLT:
# hipBLASLt kernels for gfx1150 are incomplete in Debian.
# rocBLAS works correctly and is sufficient.
```

---

## 6. Build procedure (summary)

### Phase 1: System preparation
1. Install build dependencies: `build-essential cmake ninja-build hipcc`
2. Install all ROCm libraries from experimental (list in section 4)
3. Create 32 GB swap in `/media/dati/swapfile`
4. Add `amdgpu.cwsr_enable=0` to GRUB (GPU stability)

### Phase 2: Source preparation
1. Clone PyTorch: `git clone --depth 1 --recurse-submodules https://github.com/pytorch/pytorch.git`
2. Run **hipify** (mandatory, not automatic):
   ```bash
   uv run --with pyyaml python tools/amd_build/build_amd.py
   ```

### Phase 3: Build
Full command with all variables (run in `tmux` to survive session crashes):

```bash
CC=/usr/bin/gcc-14 CXX=/usr/bin/g++-14 \
PYTORCH_ROCM_ARCH=gfx1150 USE_ROCM=1 USE_CUDA=0 \
ROCM_PATH=/usr HIP_PATH=/usr HIPCC_PATH=/usr/bin/hipcc \
HIP_CLANG_PATH=/usr/lib/llvm-22/bin \
HIP_DEVICE_LIB_PATH=/usr/lib/llvm-22/lib/clang/22/amdgcn/bitcode \
CMAKE_PREFIX_PATH=/usr CMAKE_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu \
USE_NINJA=1 CMAKE_GENERATOR=Ninja MAX_JOBS=6 \
CMAKE_POLICY_VERSION_MINIMUM=3.5 \
USE_NCCL=0 USE_DISTRIBUTED=0 USE_MKLDNN=0 BUILD_TEST=0 \
USE_FBGEMM=0 USE_KINETO=0 USE_NNPACK=0 \
CXXFLAGS="-Wno-error=deprecated-declarations -Wno-error=maybe-uninitialized -Wno-error" \
uv pip install -v -e . --no-build-isolation
```

**Duration**: ~54 minutes with `MAX_JOBS=6`.

### Phase 4: Post-build
1. Copy Tensile kernels to `.rocm_kernels/rocblas_lib/`
2. Create `activate_rocm.sh`
3. Add `rocm-env` alias to `.bashrc`

---

## 7. Issues encountered and solutions

| Issue | Cause | Solution |
| :--- | :--- | :--- |
| `torch.cuda.is_available()` hangs | CWSR bug + gfx1150 allocation | `HSA_OVERRIDE_GFX_VERSION=11.5.0` and `GPU_MAX_HW_QUEUES=4` |
| `HIP compiler not found` | Debian LLVM path != `/usr/lib/llvm/bin` | `HIP_CLANG_PATH=/usr/lib/llvm-22/bin` |
| `cannot find ROCm device library` | LLVM bitcode path | `HIP_DEVICE_LIB_PATH=/usr/lib/llvm-22/lib/clang/22/amdgcn/bitcode` |
| `rocrand not found` | Package not installed | `librocrand-dev` |
| `hipfft not found` | Package not installed | `libhipfft-dev` |
| `libhipsolver_fortran.so.1.0` missing | Separate Fortran dependency | `libhipsolver-fortran-dev` |
| `ROCM_ROCTX_LIB` NOTFOUND | CMake looks in `/usr/lib`, Debian uses `/usr/lib/x86_64-linux-gnu` | `CMAKE_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu` |
| GCC 16 `__noinline__` error | ROCm headers / GCC 16 conflict | Use GCC 14 |
| `TensileLibrary.dat` missing | Debian packaging bug (gfx1150 kernels missing) | Kernels from `likelovewant/ROCmLibs` |
| OOM killer kills GNOME session | 30 GB RAM saturated by 18 parallel jobs | 32 GB swap + `MAX_JOBS=6` + `tmux` |

---

## 8. Functionality verification

After `rocm-env`:

```bash
uv run --project /media/dati/Programmi/AI/pytorch-gfx1150-build python -c "
import torch
x = torch.randn(2000, 2000, device='cuda')
y = torch.randn(2000, 2000, device='cuda')
z = x @ y
print('OK, device:', z.device)
print('shape:', z.shape)
"
```

**Expected output**: `OK, device: cuda:0` with matmul time ~0.073s for 2000×2000 (~110 GFLOPS).

---

## 9. Operational notes

- **Always in `tmux`**: the build is long, and GNOME can crash under load. `tmux` protects the processes.
- **Do not use `pip`**: only `uv`.
- **Do not touch `/usr`**: the `.rocm_kernels` directory lives inside the project, portable.
- **If you reinstall Debian**: just redo `apt install` of ROCm libraries and rebuild PyTorch. Sources and local kernels survive in `/media/dati`.
- **If you upgrade ROCm**: verify that the Tensile bug for gfx1150 has been fixed; in that case, you can remove the local workaround.

---

## 10. Next steps (TODO)

- [ ] Write **pre-flight check** script (`check_rocm_env.py`) that verifies all dependencies before starting the build.
- [ ] Configure TRELLIS-AMD using this PyTorch environment.
- [ ] Test real inference (not just matmul) to validate performance.

---

## 11. References

- Debian rocBLAS gfx1150 bug: Launchpad #2162810
- Tensile kernel repository: https://github.com/likelovewant/ROCmLibs-for-gfx1103-AMD780M-APU
- RDNA 3.5 bare-metal guide: https://github.com/FoxEgregore/rdna35-llm-baremetal
- PyTorch gfx1150 build: https://github.com/Peterc3-dev/pytorch-gfx1150
---

## 12. Component taxonomy (what is reusable and what is not)

The work done is distributed across **six categories** with very different reusability. Understanding this distinction is essential to know, next time, what to reuse and what to rebuild.

| # | Category | Examples | Source | Reusable for… |
| :--- | :--- | :--- | :--- | :--- |
| **A** | ROCm system | `hipcc`, `librocblas`, `libhipblaslt`, `rocminfo` | `apt` | **Everything** that uses HIP/ROCm |
| **B** | Project sources | `pytorch-gfx1150-build/`, `TRELLIS-AMD/` | `git clone` | Only that project |
| **C** | Universal workaround | Tensile kernels gfx1150 | Manual GitHub download | **Everything** that uses rocBLAS on gfx1150 |
| **D** | Our build | PyTorch wheel 2.16.0a0 | Compilation | Only PyTorch applications |
| **E** | System configuration | GRUB `cwsr_enable=0`, swap, alias | Our work | **The whole system** |
| **F** | Project-internal tools | `hipify` (`tools/amd_build/build_amd.py`) | Inside the sources | Only PyTorch, one-shot |

### Important notes

- **hipify (F) is not reusable**: it is a Python script that translates PyTorch sources from CUDA to HIP. It does not produce binaries, it is not exportable, and it lives and dies inside `pytorch-gfx1150-build/`. Each framework (TensorFlow, JAX) has its own hipify.
- **Tensile kernels (C) are reusable by any ROCm application**: not only PyTorch. As long as the app reads `ROCBLAS_TENSILE_LIBPATH`. Ollama-ROCm, llama.cpp-HIP, Blender Cycles-HIP also benefit.
- **The PyTorch wheel (D) is framework-specific**: TensorFlow, JAX, ONNX Runtime require their **own** builds for gfx1150. No one distributes pre-built wheels for this architecture.

### Practical analogy

- **A + C + E** = you have a grand piano, tuned, in your living room. Anyone who can play can use it.
- **D** = you have learned to play *one* specific piece (PyTorch). To play another (TensorFlow) you must study it from scratch, but the instrument is the same.

---

## 13. The PyTorch wheel — what it is, where it is, how to distribute it

### What it is

The output of the 54-minute build is a **Python wheel** (`.whl`), i.e., an installable binary package. It is not an editable wheel: it contains all `.so` files and Python modules.

### Where it is

The wheel is in the `uv` cache (the `pip install -e .` command deposits it there):

```
/media/dati/Programmi/system/uv_dep/cache/sdists-v9/editable/7cbf72baad3464b1/ndNDApRmSKBXSwem/torch-2.16.0a0+gite42541f-cp312-cp312-linux_x86_64.whl
```

A copy has been saved in:
```
/media/dati/Programmi/AI/pytorch-gfx1150-debian/wheel/
```

### What it contains

- **9,768 files** total
- **11 `.so` files**, including the heavy ones:
  - `libtorch_cpu.so` (241 MB)
  - `libtorch_hip.so` (199 MB)
  - `libtorch_python.so` (30 MB)
  - `libaotriton_v2.so` (20 MB)
- Python modules, headers, configuration files

Compressed size: **378 MB**. Decompressed: **~1.3 GB**.

### What it does NOT contain

- ROCm system libraries (`libamdhip64.so`, `librocblas.so`, etc.) → they come from `apt`
- Tensile kernels → they live in `.rocm_kernels/rocblas_lib/`

### Compatibility

The wheel is **installable** on systems with:
- ISA `gfx1150` (Radeon 890M, 880M)
- Python 3.12
- x86_64 architecture
- ROCm 7.2.x

**It is not compatible** with:
- Other ISAs (`gfx1100`, `gfx1151`, etc.)
- Python 3.11 or 3.13
- ARM64

### Note on the name

The wheel is named `torch-2.16.0a0+gite42541f-cp312-cp312-linux_x86_64.whl` — **without the `gfx1150` suffix**. This is intentional: the name follows the Python PEP 427 standard, and the package is always called `torch` because it is PyTorch. The gfx1150 specificity is communicated by the **repository name** and the **README**, not the file name.

**Do not rename the wheel**: the internal package name (in `METADATA`) remains `torch`, and an inconsistent file name can cause warnings with `pip`/`uv`.

---

## 14. Future reproduction scenarios

### Scenario A: Debian reinstall on this machine

1. Reinstall Debian 13 forky
2. Restore the system configuration (GRUB, swap, APT pin)
3. `apt install` the ROCm libraries (section 4)
4. Copy `pytorch-gfx1150-build/` and `.rocm_kernels/` from an external backup
5. Recreate `activate_rocm.sh` and the alias
6. **Install the pre-existing wheel** instead of recompiling:
   ```bash
   uv pip install /path/to/torch-2.16.0a0+gite42541f-cp312-cp312-linux_x86_64.whl
   ```
7. Verify with the test in section 8

**Savings**: 54 minutes of compilation + 15 minutes of hipify.

### Scenario B: another machine with gfx1150

1. Ensure Python 3.12, x86_64 and ROCm 7.2.x are present
2. Install the ROCm libraries (section 4)
3. Copy `.rocm_kernels/rocblas_lib/` and the system files
4. Install the pre-existing wheel
5. Configure `activate_rocm.sh` with the **specific paths** of that machine

**Note**: the paths inside `activate_rocm.sh` are absolute (`/media/dati/...`). On another machine, they must be adapted or made relative. (The version in this repository has already been made portable — see `scripts/activate_rocm.sh`.)

### Scenario C: new version of ROCm or PyTorch

When ROCm 7.3 or PyTorch 2.17 is released, the current wheel is no longer compatible. You need to:
1. Update the ROCm libraries via `apt`
2. Repeat the build procedure (section 6) on the updated sources
3. Check whether the Tensile bug for gfx1150 has been fixed (in that case, remove the local workaround)

### Scenario D: distribute to third parties

1. Publish the `pytorch-gfx1150-debian` repository on GitHub
2. Include:
   - The wheel (or a link to download it, since it is 378 MB)
   - The Tensile kernels (or a script that downloads them automatically)
   - The documentation (this file)
   - The automatic setup script
3. Clearly specify the prerequisites (gfx1150, Python 3.12, ROCm 7.2.x)

---

## 15. Repository structure and installation

This document is part of the `pytorch-gfx1150-debian` repository. For a quick installation, use the provided script:

```bash
git clone https://github.com/<your-username>/pytorch-gfx1150-debian.git
cd pytorch-gfx1150-debian
./scripts/install.sh
```

The script automates all the steps described in this document. See `README.md` for details.

---

## 16. Credits

- **Dario** — hardware, testing, debugging, methodology
- **DeepSeek V4.1 Flash** — coding assistance, error diagnosis, documentation

Built and validated on an ASUS Zenbook S16 UM5606GA (Ryzen AI 9 465, Radeon 890M, 32 GB RAM).

---

*End of document.*