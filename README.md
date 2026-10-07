# PyTorch for AMD gfx1150 (Radeon 890M) on Debian

Pre-built PyTorch wheels and installation scripts for **AMD Radeon 890M (gfx1150, RDNA 3.5)** integrated GPUs on Debian 13 (forky).

## Why this exists

AMD's Strix Point APUs use the `gfx1150` ISA, which is **not supported by any pre-built PyTorch package**. Standard approaches fail:

| Approach | Result |
|----------|--------|
| `pip install torch` | CPU only, no GPU acceleration |
| ROCm wheels from pytorch.org | Crashes: `invalid device function` |
| `HSA_OVERRIDE_GFX_VERSION=11.0.0` | Does not map to a valid target for gfx1150 |
| **Build from source with `PYTORCH_ROCM_ARCH=gfx1150`** | **Native GPU acceleration** |

This repository provides:
- A **pre-built wheel** (378 MB) ready to install
- The **Tensile kernels** for gfx1150 missing from Debian packages
- **Installation scripts** that automate the setup
- **Complete documentation** of the procedure

## Requirements

| Component | Version |
|-----------|---------|
| GPU | AMD Radeon 890M or 880M (gfx1150) |
| OS | Debian 13 (forky) |
| ROCm | 7.2.x |
| Python | 3.12 |
| Architecture | x86_64 |
| GCC | 14 (NOT 16) |

## Quick start

```bash
git clone https://github.com/<your-username>/pytorch-gfx1150-debian.git
cd pytorch-gfx1150-debian
./scripts/install.sh
```

The script will:
1. Check prerequisites
2. Install ROCm libraries from Debian experimental
3. Download and install the Tensile kernels for gfx1150
4. Install the pre-built PyTorch wheel
5. Create the `rocm-env` activation alias

After installation:

```bash
rocm-env
python -c "import torch; x = torch.randn(1000, 1000, device='cuda'); print((x @ x).device)"
```

Expected output: `cuda:0`

## Repository structure

```
pytorch-gfx1150-debian/
├── README.md                  # This file
├── wheel/                     # Pre-built PyTorch wheel
├── kernels/                   # Tensile kernels for gfx1150
├── scripts/
│   ├── install.sh             # Main installation script
│   └── activate_rocm.sh       # Environment activation
└── docs/
    ├── ROCm_gfx1150_PyTorch_EN.md   # Full documentation (English)
    └── Context_ROCm_gfx1150_PyTorch_V1.md  # Original (Italian)
```

## What's in the wheel

- 9,768 files, 378 MB compressed
- `libtorch_cpu.so` (241 MB), `libtorch_hip.so` (199 MB), `libtorch_python.so` (30 MB)
- PyTorch 2.16.0a0 compiled from source with ROCm 7.2.4

**Not included**: ROCm system libraries (from `apt`) and Tensile kernels (in `kernels/`).

## Known issues and workarounds

| Issue | Workaround |
|-------|-----------|
| `torch.cuda.is_available()` hangs | Set `HSA_OVERRIDE_GFX_VERSION=11.5.0` |
| `TensileLibrary.dat` missing | Use local kernels via `ROCBLAS_TENSILE_LIBPATH` |
| hipBLASLt incomplete for gfx1150 | Use rocBLAS (do NOT set `TORCH_BLAS_PREFER_HIPBLASLT`) |
| GCC 16 `__noinline__` error | Use GCC 14 |
| OOM kills GNOME session | Add 32 GB swap, use `MAX_JOBS=6` |

See `docs/` for the complete troubleshooting guide.

## Compatibility

This wheel is **specific** to:
- ISA `gfx1150`
- Python 3.12
- x86_64
- ROCm 7.2.x

For other ISAs, Python versions, or ROCm versions, rebuild from source (see documentation).

## Credits

- **Dario** — hardware, testing, debugging, methodology
- **DeepSeek V4.1 Flash** — coding assistance, error diagnosis, documentation

Built and validated on an ASUS Zenbook S16 UM5606GA (Ryzen AI 9 465, Radeon 890M, 32 GB RAM).

## License

MIT (see `LICENSE`)

## References

- Debian rocBLAS gfx1150 bug: [Launchpad #2162810](https://bugs.launchpad.net/ubuntu/+source/rocblas/+bug/2162810)
- Tensile kernels source: [likelovewant/ROCmLibs-for-gfx1103-AMD780M-APU](https://github.com/likelovewant/ROCmLibs-for-gfx1103-AMD780M-APU)
- RDNA 3.5 bare-metal guide: [FoxEgregore/rdna35-llm-baremetal](https://github.com/FoxEgregore/rdna35-llm-baremetal)
- PyTorch gfx1150 build: [Peterc3-dev/pytorch-gfx1150](https://github.com/Peterc3-dev/pytorch-gfx1150)