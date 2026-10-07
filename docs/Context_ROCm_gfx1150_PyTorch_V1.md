# PyTorch su ROCm per Radeon 890M (gfx1150) — Debian 13 forky

**Ultimo aggiornamento**: 2026-10-07
**Versione**: 1.0
**Stato**: Funzionante e validato

---

## 1. Scopo

Documentare la procedura completa per compilare PyTorch da sorgente con backend ROCm nativo su **AMD Radeon 890M (gfx1150)**, APU Strix Point del notebook ASUS Zenbook S16 UM5606GA, sotto **Debian 13 (forky)**.

Questo documento è **specifico per questa macchina** e per questa combinazione di versioni. Non è una guida universale.

---

## 2. Specifiche di riferimento

| Componente | Versione |
| :--- | :--- |
| GPU | AMD Radeon 890M (gfx1150, RDNA 3.5) |
| CPU | AMD Ryzen AI 9 465 (Zen 5, 10c/20t) |
| RAM | 32 GB (24 GB GTT) |
| OS | Debian 13 forky |
| Kernel | 6.19.14+deb13-amd64 |
| ROCm | 7.2.4 (da Debian experimental) |
| HIP | 7.2.5 (hipcc da experimental) |
| LLVM/Clang | 22 (percorso `/usr/lib/llvm-22`) |
| GCC | 14 (NON 16, per bug `__noinline__`) |
| PyTorch | 2.16.0a0+gite42541f (compilato da sorgente) |
| Python | 3.12.13 |

---

## 3. Percorsi chiave

| Cosa | Percorso |
| :--- | :--- |
| Sorgenti PyTorch | `/media/dati/Programmi/AI/pytorch-gfx1150-build/` |
| Venv TRELLIS-AMD | `/media/dati/Programmi/AI/TRELLIS-AMD/.venv/` |
| Kernel Tensile locali | `/media/dati/Programmi/AI/pytorch-gfx1150-build/.rocm_kernels/` |
| Script attivazione | `/media/dati/Programmi/AI/pytorch-gfx1150-build/activate_rocm.sh` |
| Alias bash | `rocm-env` (definito in `~/.bashrc`) |
| Swap file | `/media/dati/swapfile` (32 GB) |
| Log build | `/media/dati/Programmi/AI/pytorch_build.log` |

---

## 4. Dipendenze ROCm installate

### Da Debian forky (stable/testing)
```
libhsa-runtime64-1   (aggiornato a 7.2.4 da experimental)
libhsa-runtime-dev
libamdhip64-dev
libamd-comgr-dev
```

### Da Debian experimental
Tutte le librerie ROCm a versione **7.2.4**:
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

**Pin APT**: il repository experimental è configurato con priorità `-10` in `/etc/apt/preferences.d/experimental.pref`, per evitare aggiornamenti automatici indesiderati.

### Kernel Tensile per gfx1150
Debian **non include** i kernel Tensile per gfx1150 nel pacchetto `librocblas5` (bug noto). I kernel sono stati scaricati da:
- Repository: `likelovewant/ROCmLibs-for-gfx1103-AMD780M-APU`
- File: `rocm.gfx1150.for.hip.skd.6.2.4.7z`
- Estratti in: `/media/dati/Programmi/AI/pytorch-gfx1150-build/.rocm_kernels/rocblas_lib/`

---

## 5. Variabili d'ambiente necessarie

Queste variabili sono **indispensabili** per il funzionamento su gfx1150. Sono definite in `activate_rocm.sh` e attivate con l'alias `rocm-env`.

```bash
# Mappa gfx1150 su gfx1151 per il caricamento dei kernel Tensile
export HSA_OVERRIDE_GFX_VERSION=11.5.0

# Previene hang silenziosi su APU RDNA 3.x
export GPU_MAX_HW_QUEUES=4

# Disabilita SDMA per stabilità su memoria unificata
export HSA_ENABLE_SDMA=0

# Previene SIGBUS rari in inferenza multi-batch
export HIP_FORCE_DEV_KERNARG=1

# Abilita AOTriton sperimentale per attention kernels
export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1

# Percorso dei kernel Tensile locali per rocBLAS
export ROCBLAS_TENSILE_LIBPATH=/media/dati/Programmi/AI/pytorch-gfx1150-build/.rocm_kernels/rocblas_lib

# NON impostare TORCH_BLAS_PREFER_HIPBLASLT:
# i kernel hipBLASLt per gfx1150 sono incompleti in Debian.
# rocBLAS funziona correttamente ed è sufficiente.
```

---

## 6. Procedura di compilazione (riassunto)

### Fase 1: Preparazione sistema
1. Installare dipendenze di build: `build-essential cmake ninja-build hipcc`
2. Installare tutte le librerie ROCm da experimental (lista al punto 4)
3. Creare swap 32 GB in `/media/dati/swapfile`
4. Aggiungere `amdgpu.cwsr_enable=0` a GRUB (stabilità GPU)

### Fase 2: Preparazione sorgenti
1. Clonare PyTorch: `git clone --depth 1 --recurse-submodules https://github.com/pytorch/pytorch.git`
2. Eseguire **hipify** (obbligatorio, non automatico):
   ```bash
   uv run --with pyyaml python tools/amd_build/build_amd.py
   ```

### Fase 3: Compilazione
Comando completo con tutte le variabili (eseguito in `tmux` per sopravvivere a cadute di sessione):

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

**Durata**: ~54 minuti con `MAX_JOBS=6`.

### Fase 4: Post-build
1. Copiare i kernel Tensile in `.rocm_kernels/rocblas_lib/`
2. Creare `activate_rocm.sh`
3. Aggiungere alias `rocm-env` al `.bashrc`

---

## 7. Problemi incontrati e soluzioni

| Problema | Causa | Soluzione |
| :--- | :--- | :--- |
| `torch.cuda.is_available()` si blocca | Bug CWSR + allocazione su gfx1150 | Variabili `HSA_OVERRIDE_GFX_VERSION=11.5.0` e `GPU_MAX_HW_QUEUES=4` |
| `HIP compiler not found` | Percorso LLVM di Debian != `/usr/lib/llvm/bin` | `HIP_CLANG_PATH=/usr/lib/llvm-22/bin` |
| `cannot find ROCm device library` | Percorso bitcode LLVM | `HIP_DEVICE_LIB_PATH=/usr/lib/llvm-22/lib/clang/22/amdgcn/bitcode` |
| `rocrand not found` | Pacchetto non installato | `librocrand-dev` |
| `hipfft not found` | Pacchetto non installato | `libhipfft-dev` |
| `libhipsolver_fortran.so.1.0` mancante | Dipendenza Fortran separata | `libhipsolver-fortran-dev` |
| `ROCM_ROCTX_LIB` NOTFOUND | CMake cerca in `/usr/lib`, Debian usa `/usr/lib/x86_64-linux-gnu` | `CMAKE_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu` |
| GCC 16 `__noinline__` error | Conflitto header ROCm / GCC 16 | Usare GCC 14 |
| `TensileLibrary.dat` missing | Bug packaging Debian (mancano kernel gfx1150) | Kernel scaricati da `likelovewant/ROCmLibs` |
| OOM killer uccide sessione GNOME | 30 GB RAM saturati da 18 job parallel | Swap 32 GB + `MAX_JOBS=6` + `tmux` |

---

## 8. Verifica funzionamento

Dopo `rocm-env`:

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

**Risultato atteso**: `OK, device: cuda:0` con tempo matmul ~0.073s per 2000×2000 (~110 GFLOPS).

---

## 9. Note operative

- **Sempre in `tmux`**: la build è lunga, e GNOME può cadere sotto carico. `tmux` protegge i processi.
- **Non usare `pip`**: solo `uv`.
- **Non toccare `/usr`**: la directory `.rocm_kernels` vive dentro il progetto, portabile.
- **Se reinstalli Debian**: basta rifare `apt install` delle librerie ROCm e ricompilare PyTorch. I sorgenti e i kernel locali sopravvivono in `/media/dati`.
- **Se aggiorni ROCm**: verifica che il bug Tensile per gfx1150 sia stato risolto; in tal caso puoi rimuovere il workaround locale.

---

## 10. Prossimi passi (TODO)

- [ ] Scrivere script di **pre-flight check** (`check_rocm_env.py`) che verifica tutte le dipendenze prima di iniziare la build.
- [ ] Configurare TRELLIS-AMD usando questo ambiente PyTorch.
- [ ] Testare inferenza reale (non solo matmul) per validare le prestazioni.

---

## 11. Riferimenti

- Bug Debian rocBLAS gfx1150: Launchpad #2162810
- Repository kernel Tensile: https://github.com/likelovewant/ROCmLibs-for-gfx1103-AMD780M-APU
- Guida RDNA 3.5 bare-metal: https://github.com/FoxEgregore/rdna35-llm-baremetal
- PyTorch build gfx1150: https://github.com/Peterc3-dev/pytorch-gfx1150

---

## 12. Tassonomia dei componenti (cosa è riutilizzabile e cosa no)

Il lavoro fatto si distribuisce su **sei categorie** con riutilizzabilità molto diversa. Capire questa distinzione è essenziale per sapere, la prossima volta, cosa riutilizzare e cosa ricostruire.

| # | Categoria | Esempi | Origine | Riutilizzabile per… |
| :--- | :--- | :--- | :--- | :--- |
| **A** | Sistema ROCm | `hipcc`, `librocblas`, `libhipblaslt`, `rocminfo` | `apt` | **Tutto** ciò che usa HIP/ROCm |
| **B** | Sorgenti progetto | `pytorch-gfx1150-build/`, `TRELLIS-AMD/` | `git clone` | Solo quel progetto |
| **C** | Workaround universale | Kernel Tensile gfx1150 | GitHub manuale | **Tutto** ciò che usa rocBLAS su gfx1150 |
| **D** | Build nostra | Wheel PyTorch 2.16.0a0 | Compilazione | Solo applicazioni PyTorch |
| **E** | Configurazione sistema | GRUB `cwsr_enable=0`, swap, alias | Nostro lavoro | **Tutto** il sistema |
| **F** | Strumenti interni al progetto | `hipify` (`tools/amd_build/build_amd.py`) | Dentro i sorgenti | Solo PyTorch, una tantum |

### Note importanti

- **hipify (F) non è riutilizzabile**: è uno script Python che traduce i sorgenti PyTorch da CUDA a HIP. Non produce binari, non è esportabile, vive e muore dentro `pytorch-gfx1150-build/`. Ogni framework (TensorFlow, JAX) ha il proprio hipify.
- **I kernel Tensile (C) sono riutilizzabili da qualsiasi applicazione ROCm**: non solo PyTorch. Basta che l'app legga `ROCBLAS_TENSILE_LIBPATH`. Anche Ollama-ROCm, llama.cpp-HIP, Blender Cycles-HIP ne beneficiano.
- **Il wheel PyTorch (D) è specifico del framework**: TensorFlow, JAX, ONNX Runtime richiedono le **proprie** build per gfx1150. Nessuno distribuisce wheel precompilati per questa architettura.

### Analogia pratica

- **A + C + E** = hai un pianoforte a coda accordato in salotto. Chiunque sappia suonare può usarlo.
- **D** = hai imparato a suonare *un* brano specifico (PyTorch). Per suonarne un altro (TensorFlow) serve studiare da capo, ma lo strumento è lo stesso.

---

## 13. Il wheel PyTorch — cos'è, dove si trova, come si distribuisce

### Cos'è

Il risultato della build da 54 minuti è un **wheel Python** (`.whl`), cioè un pacchetto binario installabile. Non è un editable wheel: contiene tutti i file `.so` e i moduli Python.

### Dove si trova

Il wheel è nella cache di `uv` (l'installazione `pip install -e .` lo deposita lì):

```
/media/dati/Programmi/system/uv_dep/cache/sdists-v9/editable/7cbf72baad3464b1/ndNDApRmSKBXSwem/torch-2.16.0a0+gite42541f-cp312-cp312-linux_x86_64.whl
```

Una copia è stata salvata in:
```
/media/dati/Programmi/AI/pytorch-gfx1150-debian/wheel/
```

### Cosa contiene

- **9768 file** totali
- **11 file `.so`**, inclusi i pesanti:
  - `libtorch_cpu.so` (241 MB)
  - `libtorch_hip.so` (199 MB)
  - `libtorch_python.so` (30 MB)
  - `libaotriton_v2.so` (20 MB)
- Moduli Python, header, file di configurazione

Dimensione compressa: **378 MB**. Decompressa: **~1.3 GB**.

### Cosa NON contiene

- Le librerie ROCm di sistema (`libamdhip64.so`, `librocblas.so`, ecc.) → vengono da `apt`
- I kernel Tensile → vivono in `.rocm_kernels/rocblas_lib/`

### Compatibilità

Il wheel è **installabile** su sistemi con:
- ISA `gfx1150` (Radeon 890M, 880M)
- Python 3.12
- Architettura x86_64
- ROCm 7.2.x

**Non è compatibile** con:
- ISA diverse (`gfx1100`, `gfx1151`, ecc.)
- Python 3.11 o 3.13
- ARM64

### Nota sul nome

Il wheel si chiama `torch-2.16.0a0+gite42541f-cp312-cp312-linux_x86_64.whl` — **senza suffisso `gfx1150`**. Questo è voluto: il nome segue lo standard PEP 427 di Python, e il pacchetto si chiama sempre `torch` perché è PyTorch. La specificità gfx1150 è comunicata dal **nome del repository** e dal **README**, non dal nome del file.

**Non rinominare il wheel**: il nome interno del pacchetto (in `METADATA`) rimane `torch`, e un nome file incoerente può causare warning con `pip`/`uv`.

---

## 14. Scenari di riproduzione futura

### Scenario A: reinstallazione di Debian su questa macchina

1. Reinstallare Debian 13 forky
2. Ripristinare la configurazione di sistema (GRUB, swap, pin APT)
3. `apt install` delle librerie ROCm (sezione 4)
4. Copiare `pytorch-gfx1150-build/` e `.rocm_kernels/` da un backup esterno
5. Ricreare `activate_rocm.sh` e l'alias
6. **Installare il wheel preesistente** invece di ricompilare:
   ```bash
   uv pip install /percorso/torch-2.16.0a0+gite42541f-cp312-cp312-linux_x86_64.whl
   ```
7. Verificare con il test della sezione 8

**Risparmio**: 54 minuti di compilazione + 15 minuti di hipify.

### Scenario B: altra macchina con gfx1150

1. Assicurarsi che Python 3.12, x86_64 e ROCm 7.2.x siano presenti
2. Installare le librerie ROCm (sezione 4)
3. Copiare `.rocm_kernels/rocblas_lib/` e i file di sistema
4. Installare il wheel preesistente
5. Configurare `activate_rocm.sh` con i **percorsi specifici** di quella macchina

**Nota**: i percorsi dentro `activate_rocm.sh` sono assoluti (`/media/dati/...`). Su un'altra macchina vanno adattati o resi relativi.

### Scenario C: nuova versione di ROCm o PyTorch

Quando esce ROCm 7.3 o PyTorch 2.17, il wheel attuale non è più compatibile. Serve:
1. Aggiornare le librerie ROCm da `apt`
2. Ripetere la procedura di compilazione (sezioni 6) sui sorgenti aggiornati
3. Verificare se il bug Tensile per gfx1150 è stato risolto (in tal caso, rimuovere il workaround locale)

### Scenario D: distribuire a terzi

1. Pubblicare il repository `pytorch-gfx1150-debian` su GitHub
2. Includere:
   - Il wheel (o un link per scaricarlo, dato che è 378 MB)
   - I kernel Tensile (o uno script che li scarica automaticamente)
   - Il documento (questo file)
   - Lo script di setup automatico
3. Specificare chiaramente i prerequisiti (gfx1150, Python 3.12, ROCm 7.2.x)

---