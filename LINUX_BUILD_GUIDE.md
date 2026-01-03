# Brawlback Linux Build Guide

This guide documents building Brawlback from source on Linux (tested on Manjaro/Arch).

## System Requirements

| Tool | Minimum Version | Check Command |
|------|----------------|---------------|
| Python | 3.10+ | `python3 --version` |
| GCC | 11+ | `gcc --version` |
| CMake | 3.13+ | `cmake --version` |
| Node.js | 16+ | `node --version` |
| Yarn | Latest | `yarn --version` |

## Dependencies

### Arch/Manjaro

```bash
# Core build tools
sudo pacman -S base-devel cmake git python

# Dolphin dependencies
sudo pacman -S qt6-base libxi libxrandr sdl2 libevdev miniupnpc lzo \
               alsa-lib pulseaudio bluez-libs ffmpeg libusb fmt pugixml \
               llvm libffi libedit

# Launcher dependencies (Node.js)
sudo pacman -S nodejs yarn
# Or use nvm for Node.js version management
```

### Debian/Ubuntu

```bash
sudo apt install build-essential cmake git python3 python3-pip python3-venv \
    qt6-base-dev libxi-dev libxrandr-dev libsdl2-dev libevdev-dev \
    libminiupnpc-dev liblzo2-dev libasound2-dev libpulse-dev \
    libbluetooth-dev libavcodec-dev libavformat-dev libavutil-dev \
    libswresample-dev libswscale-dev libusb-1.0-0-dev libfmt-dev \
    libpugixml-dev llvm-dev libffi-dev libedit-dev nodejs npm
```

---

## Building brawlback-asm

The game-side injection code that hooks into Brawl.

### 1. Clone with submodules

```bash
cd /path/to/brawlback/repos
git clone --recursive https://github.com/Brawlback-Team/brawlback-asm.git
cd brawlback-asm
```

### 2. Install Python dependencies

```bash
# Create virtual environment (required on modern distros)
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install click requests rich
```

### 3. Download toolchain

```bash
python3 ./bbk.py setup
```

This downloads:
- **kuribo-llvm**: Modified LLVM/Clang for PowerPC compilation
- **elf2rel**: Converts ELF to REL format for Wii

### 4. Fix Linux case-sensitivity issues

The codebase was developed on Windows (case-insensitive). Linux requires these symlinks:

```bash
# Fix EXI_Hooks.h vs EXI_hooks.h
cd Brawlback-Online/include
ln -s EXI_hooks.h EXI_Hooks.h

# Fix FA directory case
cd ../../lib/BrawlHeaders/OpenRVL/include/revolution
ln -s FA fa

# Fix FARemove.h vs FAremove.h
cd FA
ln -s FARemove.h FAremove.h
```

### 5. Build

```bash
cd /path/to/brawlback-asm
make
```

**Output:**
- `Brawlback-Online/Brawlback-Online.rel` (~34KB)
- `lib/Syriinge/sy_core.rel` (~8KB)

### 6. Install to SD card structure

```bash
mkdir -p sd-card/vBrawl/pf/{plugins,module}
cp Brawlback-Online/Brawlback-Online.rel sd-card/vBrawl/pf/plugins/
cp lib/Syriinge/sy_core.rel sd-card/vBrawl/pf/module/
```

---

## Building Dolphin

The modified Dolphin emulator with Brawlback netplay support.

### 1. Clone with submodules

```bash
cd /path/to/brawlback/repos
git clone --recursive https://github.com/Brawlback-Team/dolphin.git
cd dolphin
```

### 2. Configure

```bash
mkdir build && cd build

# IMPORTANT: Use bundled fmt library to avoid version mismatch
# System fmt v12+ has breaking API changes (is_compile_string removed)
cmake .. -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DUSE_SYSTEM_FMT=OFF

# Optional: specify install prefix
cmake .. -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DUSE_SYSTEM_FMT=OFF -DCMAKE_INSTALL_PREFIX=/usr/local
```

### 3. Build

```bash
# Use all CPU cores
cmake --build . -j$(nproc)
```

**Build time:** 10-30 minutes depending on CPU

### 4. Install (optional)

```bash
sudo cmake --install .
```

Or run directly from build directory:
```bash
./Binaries/dolphin-emu
```

---

## Building the Launcher

Electron-based launcher for Brawlback (manages Dolphin, matchmaking, replays).

### 1. Clone

```bash
cd /path/to/brawlback/repos
git clone https://github.com/Brawlback-Team/brawlback-launcher.git
cd brawlback-launcher
```

### 2. Install dependencies

```bash
yarn install
```

### 3. Run in development mode

```bash
yarn run start
```

### 4. Build release

```bash
yarn run package
```

---

## Linux-Specific Issues

### Case Sensitivity Fixes (PR Candidates)

The following files have case mismatches that break Linux builds:

| File Reference | Actual File | Fix |
|----------------|-------------|-----|
| `#include "EXI_Hooks.h"` | `EXI_hooks.h` | Symlink or rename |
| `#include <revolution/fa/...>` | `revolution/FA/...` | Symlink `fa` → `FA` |
| `#include <revolution/fa/FAremove.h>` | `FARemove.h` | Symlink or rename |

**Recommended PR:** Standardize all include paths to match actual filenames.

### CMake 4.0+ Compatibility

Dolphin's bundled enet uses deprecated CMake syntax. Workaround:
```bash
cmake .. -DCMAKE_POLICY_VERSION_MINIMUM=3.5
```

**Recommended PR:** Update `Externals/enet/CMakeLists.txt` minimum version.

### Python Externally Managed Environment (PEP 668)

Modern distributions (Arch, Fedora 38+, Ubuntu 23.04+) prevent system-wide pip installs. Use a virtual environment:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r tools/requirements.txt
```

---

## Troubleshooting

### fmt library version mismatch

**Symptom:** Errors like `'is_compile_string' is not a member of 'fmt::v12::detail'`

**Cause:** System fmt library v12+ has breaking API changes.

**Fix:** Use bundled fmt:
```bash
cmake .. -DUSE_SYSTEM_FMT=OFF
```

### EXIBrawlback.cpp preprocessor brace mismatch

**Symptom:** Errors like `expected unqualified-id before 'if'` in EXIBrawlback.cpp around line 934

**Cause:** Missing closing brace `}` in Windows `#ifdef` block before `#else` (line ~893).

**Fix:** Edit `Source/Core/Core/HW/EXI/EXIBrawlback.cpp`, add `}` after line 892 (after `qos_success = true;`) to close the Windows `if (QOSCreateHandle...)` block before the `#else`.

**PR Candidate:** This is a cross-platform build bug that should be fixed upstream.

### ENetPeer socket access error

**Symptom:** `'ENetPeer' has no member named 'socket'` at line ~898

**Cause:** Linux code incorrectly accesses `this->peer->socket` but `ENetPeer` doesn't have a socket member - it's on `ENetHost`.

**Fix:** Change line 898 from:
```cpp
setsockopt(this->peer->socket, SOL_SOCKET, SO_PRIORITY, &priority, sizeof(priority));
```
to:
```cpp
setsockopt(this->server->socket, SOL_SOCKET, SO_PRIORITY, &priority, sizeof(priority));
```

**PR Candidate:** Another cross-platform build bug.

### Ambiguous Clamp() function call

**Symptom:** `error: call of overloaded 'Clamp(u32&, unsigned int, unsigned int)' is ambiguous`

**Cause:** Two `Clamp()` functions exist - one in `util.h` and one in `Brawlback::Clamp` in `BrawlbackUtility.h`.

**Fix:** Edit `Source/Core/Core/Brawlback/include/incremental-rollback/util.h`, line 52, change:
```cpp
percentOutOf100 = Clamp(percentOutOf100, 0u, 100u);
```
to:
```cpp
percentOutOf100 = ::Clamp(percentOutOf100, 0u, 100u);
```

**PR Candidate:** Name collision issue.

### Memory protection constants not declared (PAGE_READONLY/PAGE_READWRITE)

**Symptom:** `'PAGE_READWRITE' was not declared in this scope` in Memmap.cpp, FileSystemProxy.cpp, SDIOSlot0.cpp

**Cause:** Windows memory protection constants used without platform guards.

**Fix:** Add to each affected file after includes:
```cpp
#ifndef _WIN32
#define PAGE_READONLY  0x02
#define PAGE_READWRITE 0x04
#endif
```

**PR Candidate:** Should use cross-platform abstraction.

### VirtualProtectMemoryRegion not implemented for Linux

**Symptom:** Linker errors about `MemArena::VirtualProtectMemoryRegion`

**Cause:** Function declared in header but only implemented in `MemArenaWin.cpp`.

**Fix:** Add to `Source/Core/Common/MemArenaUnix.cpp`:
```cpp
bool MemArena::VirtualProtectMemoryRegion(void* data, size_t size, u32 flag)
{
  int prot;
  if (flag == 0x02)  // PAGE_READONLY
    prot = PROT_READ;
  else if (flag == 0x04)  // PAGE_READWRITE
    prot = PROT_READ | PROT_WRITE;
  else
    return false;
  return mprotect(data, size, prot) == 0;
}
```

**PR Candidate:** Missing Linux implementation.

### Incremental rollback sources not in CMakeLists.txt

**Symptom:** `undefined reference to 'IncrementalRB::*'` linker errors

**Cause:** Source files in `Brawlback/include/incremental-rollback/` not added to CMake build.

**Fix:** Add to `Source/Core/Core/CMakeLists.txt` after `Brawlback/include/json.hpp`:
```cmake
Brawlback/include/incremental-rollback/incremental_rb.cpp
Brawlback/include/incremental-rollback/job_system.cpp
Brawlback/include/incremental-rollback/mem.cpp
Brawlback/include/incremental-rollback/tiny_arena.cpp
```

**PR Candidate:** CMake configuration bug.

### AVX intrinsics failing (fastMemcpy)

**Symptom:** `inlining failed in call to 'always_inline' '_mm256_stream_si256': target specific option mismatch`

**Cause:** AVX instructions used without enabling AVX for the function.

**Fix:** Add target attribute to `fastMemcpy` in mem.cpp:
```cpp
#ifndef _MSC_VER
__attribute__((target("avx,avx2")))
#endif
void fastMemcpy(void *pvDest, void *pvSrc, size_t nBytes)
```

**PR Candidate:** Cross-platform compilation issue.

### Qt6 private headers not found

**Symptom:** `fatal error: qpa/qplatformnativeinterface.h: No such file or directory`

**Cause:** Qt6 private headers require explicit CMake component.

**Fix:** In `Source/Core/DolphinQt/CMakeLists.txt`:
```cmake
find_package(Qt6 REQUIRED COMPONENTS Core Gui GuiPrivate Widgets Svg)
```
And add `Qt6::GuiPrivate` to target_link_libraries.

**PR Candidate:** Qt6 configuration issue.

### "NUL character seen" in .d files

Corrupted dependency files from interrupted builds:
```bash
find . -name "*.d" -delete
find . -name "*.o" -delete
make
```

### Missing Qt6

```bash
# Arch/Manjaro
sudo pacman -S qt6-base

# Ubuntu/Debian
sudo apt install qt6-base-dev
```

### LLVM not found

```bash
# Arch/Manjaro
sudo pacman -S llvm

# Ubuntu/Debian
sudo apt install llvm-dev
```

---

## Quick Start Script

Save as `build-brawlback.sh`:

```bash
#!/bin/bash
set -e

REPOS_DIR="${1:-./repos}"
mkdir -p "$REPOS_DIR"
cd "$REPOS_DIR"

echo "=== Building brawlback-asm ==="
cd brawlback-asm
git submodule update --init --recursive
python3 -m venv .venv
source .venv/bin/activate
pip install click requests rich
python3 ./bbk.py setup

# Apply Linux fixes
cd Brawlback-Online/include && ln -sf EXI_hooks.h EXI_Hooks.h && cd ../..
cd lib/BrawlHeaders/OpenRVL/include/revolution && ln -sf FA fa && cd FA && ln -sf FARemove.h FAremove.h && cd ../../../../../../..

make clean && make
mkdir -p sd-card/vBrawl/pf/{plugins,module}
cp Brawlback-Online/Brawlback-Online.rel sd-card/vBrawl/pf/plugins/
cp lib/Syriinge/sy_core.rel sd-card/vBrawl/pf/module/
cd ..

echo "=== Building Dolphin ==="
cd dolphin
git submodule update --init --recursive
mkdir -p build && cd build
cmake .. -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DUSE_SYSTEM_FMT=OFF
cmake --build . -j$(nproc)
cd ../..

echo "=== Build Complete ==="
echo "Dolphin binary: dolphin/build/Binaries/dolphin-emu"
echo "SD card files: brawlback-asm/sd-card/"
```

---

## Next Steps

1. Create a virtual SD card in Dolphin
2. Copy `sd-card/vBrawl/` contents to the virtual SD
3. Generate GCT files using GCTRealMate
4. Configure Dolphin to use the Brawlback build
5. Test with a Brawl ISO

---

*Last updated: January 3, 2026*
