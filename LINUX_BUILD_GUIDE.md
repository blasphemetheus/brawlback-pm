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

### NixOS

Create a `shell.nix` in the dolphin repo directory:

```nix
{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  buildInputs = with pkgs; [
    # Build tools
    cmake gcc git pkg-config ninja

    # Qt6 - use individual packages (qt6.full is deprecated)
    qt6.qtbase
    qt6.qtsvg
    qt6.wrapQtAppsHook

    # Dolphin dependencies
    libxkbcommon xorg.libXrandr xorg.libXi xorg.libX11
    SDL2 libevdev miniupnpc lzo alsa-lib pulseaudio
    bluez ffmpeg libusb1 pugixml cubeb libspng
    hidapi sfml zstd lz4 xxHash mbedtls curl

    # LLVM for JIT
    llvmPackages.llvm

    # Python for brawlback-asm
    (python3.withPackages (ps: with ps; [ click requests rich ]))

    # SD card tools
    mtools
    dosfstools

    # Wine for GCTRealMate
    wineWowPackages.stable
  ];

  # Use bundled fmt (system fmt v12+ has breaking changes)
  CMAKE_ARGS = "-DUSE_SYSTEM_FMT=OFF";

  # Wayland workaround - force X11/XCB
  QT_QPA_PLATFORM = "xcb";

  shellHook = ''
    echo "Brawlback development shell"
    echo "Build: mkdir -p build && cd build && cmake .. -DLINUX_LOCAL_DEV=ON -DUSE_SYSTEM_FMT=OFF && cmake --build . -j$(nproc)"
    echo "Setup: cd build/Binaries && ln -sf ../../Data/Sys Sys"
    echo "Run:   QT_QPA_PLATFORM=xcb ./build/Binaries/dolphin-emu"
  '';
}
```

Enter the shell with `nix-shell` before building.

**Important NixOS Notes:**
- Use `mbedtls` (v3), not `mbedtls_2` which is marked insecure. Dolphin uses bundled mbedtls anyway.
- Use individual Qt6 packages, not `qt6.full` which has been removed from nixpkgs.

**GC Adapter udev rules** - Add to `/etc/nixos/configuration.nix`:
```nix
services.udev.extraRules = ''
  SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="0337", MODE="0666"
'';
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

#### NixOS: Running kuribo-llvm

The downloaded kuribo-llvm binaries are dynamically linked against standard FHS paths that don't exist on NixOS. Use `steam-run` to provide an FHS-compatible environment:

```bash
# Install steam-run (requires unfree packages)
NIXPKGS_ALLOW_UNFREE=1 nix-shell -p steam-run

# Set TMPDIR to avoid clang temp file errors
export TMPDIR=/tmp

# Run make through steam-run
steam-run make
```

**What doesn't work on NixOS:**
- Running kuribo-llvm binaries directly (missing /lib64/ld-linux-x86-64.so.2)
- Using `patchelf` to fix the binaries (complex dependency chain)
- Using `nix-ld` (doesn't handle all library dependencies)

**What works:**
- `steam-run` provides a complete FHS environment where the binaries run correctly
- Setting `TMPDIR=/tmp` prevents clang from failing to create temp files

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

## Generating GCT Files with GCTRealMate

GCTRealMate compiles Gecko code text files (.txt with ASM) into binary .GCT files.

### Option 1: Wine (recommended for NixOS)

The Linux binary has the same FHS compatibility issues. Wine works more reliably:

```bash
# Install wine
nix-shell -p wineWowPackages.stable

# Download GCTRealMate
wget https://github.com/Project-Plus-Development-Team/GCTRealMate/releases/latest/download/GCTRealMate.zip
unzip GCTRealMate.zip
```

#### Fixing .include directive issues

GCTRealMate on Wine cannot find files referenced by `.include` directives. Solution: merge all includes into a single file before compiling.

Create `merge_includes.py`:

```python
#!/usr/bin/env python3
import os
import re
import sys

def resolve_includes(filename, base_dir, seen=None):
    if seen is None:
        seen = set()
    if filename in seen:
        return ""
    seen.add(filename)

    filepath = os.path.join(base_dir, filename)
    if not os.path.exists(filepath):
        print(f"Warning: Could not find {filepath}", file=sys.stderr)
        return ""

    result = []
    with open(filepath, "r") as f:
        for line in f:
            match = re.match(r"\.include\s+(.+)", line.strip())
            if match:
                included = match.group(1).strip()
                result.append(resolve_includes(included, base_dir, seen))
            else:
                result.append(line)
    return "".join(result)

if __name__ == "__main__":
    input_file = sys.argv[1]
    base_dir = os.path.dirname(input_file) or "."
    print(resolve_includes(os.path.basename(input_file), base_dir))
```

Generate merged files and compile:

```bash
cd brawlback-asm/sd-card/vBrawl

# Merge includes
python3 merge_includes.py BRAWLBACK-ONLINE.txt > BRAWLBACK-ONLINE-merged.txt
python3 merge_includes.py BRAWLBACK-ONLINE-DEV.txt > BRAWLBACK-ONLINE-DEV-merged.txt

# Compile with wine
wine /path/to/GCTRealMate.exe -o BRAWLBACK-ONLINE.GCT BRAWLBACK-ONLINE-merged.txt
wine /path/to/GCTRealMate.exe -o BRAWLBACK-ONLINE-DEV.GCT BRAWLBACK-ONLINE-DEV-merged.txt
```

### Option 2: Linux binary with steam-run

```bash
# Download Linux binary
wget https://github.com/Project-Plus-Development-Team/GCTRealMate/releases/latest/download/GCTRealMateLinux.zip
unzip GCTRealMateLinux.zip
chmod +x GCTRealMateLinux

# Run through steam-run (NixOS)
NIXPKGS_ALLOW_UNFREE=1 nix-shell -p steam-run --run "steam-run ./GCTRealMateLinux -o output.GCT input.txt"
```

**Note:** The Linux binary may still have issues finding .include files. Use the merge script above if needed.

---

## Setting Up Virtual SD Card

Dolphin can use a raw FAT32 image as a virtual SD card.

### Create the SD card image

```bash
# Create 128MB image
dd if=/dev/zero of=sd-brawlback.raw bs=1M count=128

# Format as FAT32
mkfs.vfat -F 32 sd-brawlback.raw

# Copy files using mtools (no root required)
mmd -i sd-brawlback.raw ::/vBrawl
mmd -i sd-brawlback.raw ::/vBrawl/pf
mmd -i sd-brawlback.raw ::/vBrawl/pf/module
mmd -i sd-brawlback.raw ::/vBrawl/pf/plugins

mcopy -i sd-brawlback.raw gc.txt ::/vBrawl/
mcopy -i sd-brawlback.raw BRAWLBACK-ONLINE.GCT ::/vBrawl/
mcopy -i sd-brawlback.raw sy_core.rel ::/vBrawl/pf/module/
mcopy -i sd-brawlback.raw Brawlback-Online.rel ::/vBrawl/pf/plugins/
```

### Configure Dolphin

Edit `~/.config/dolphin-emu/Dolphin.ini`:

```ini
[Core]
WiiSDCard = True
WiiSDCardWritable = True
WiiSDCardPath = /path/to/sd-brawlback.raw

[Interface]
UsePanicHandlers = False
```

### Verify SD card contents

```bash
mdir -i sd-brawlback.raw ::/vBrawl
mdir -i sd-brawlback.raw ::/vBrawl/pf/module
mdir -i sd-brawlback.raw ::/vBrawl/pf/plugins
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
#
# LINUX_LOCAL_DEV=ON: Makes Dolphin look for Sys/ directory next to the binary
# (required for development builds - otherwise it looks in /usr/local/share/dolphin-emu/)
cmake .. -DLINUX_LOCAL_DEV=ON -DUSE_SYSTEM_FMT=OFF

# Optional: specify install prefix (for system-wide installation)
cmake .. -DUSE_SYSTEM_FMT=OFF -DCMAKE_INSTALL_PREFIX=/usr/local
```

### 3. Build

```bash
# Use all CPU cores
cmake --build . -j$(nproc)
```

**Build time:** 10-30 minutes depending on CPU

### 4. Setup Sys Directory (for development builds)

If you used `-DLINUX_LOCAL_DEV=ON`, Dolphin looks for `Sys/` next to the binary:

```bash
cd build/Binaries
ln -sf ../../Data/Sys Sys
```

### 5. Run

```bash
# From the dolphin repo root directory:
cd /path/to/repos/dolphin

# On Wayland, force X11 backend
QT_QPA_PLATFORM=xcb ./build/Binaries/dolphin-emu

# On X11, run directly
./build/Binaries/dolphin-emu

# With a game (e.g., Brawl ISO):
QT_QPA_PLATFORM=xcb ./build/Binaries/dolphin-emu -e /path/to/SSBB_NTSC.iso
```

**NixOS:** Run from inside nix-shell:
```bash
cd /path/to/repos/dolphin
nix-shell shell.nix --run 'QT_QPA_PLATFORM=xcb ./build/Binaries/dolphin-emu -e /path/to/SSBB_NTSC.iso'
```

### 6. Install (optional)

For system-wide installation (don't use LINUX_LOCAL_DEV):
```bash
cmake .. -DUSE_SYSTEM_FMT=OFF  # reconfigure without LINUX_LOCAL_DEV
cmake --build . -j$(nproc)
sudo cmake --install .
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

### Standard Linux (Arch, Debian, etc.)

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
cmake .. -DLINUX_LOCAL_DEV=ON -DUSE_SYSTEM_FMT=OFF
cmake --build . -j$(nproc)

# Link Sys directory for development build
cd Binaries && ln -sf ../../Data/Sys Sys && cd ../..
cd ../..

echo "=== Build Complete ==="
echo "Dolphin binary: dolphin/build/Binaries/dolphin-emu"
echo "SD card files: brawlback-asm/sd-card/"
echo ""
echo "Run from dolphin directory:"
echo "  cd $REPOS_DIR/dolphin"
echo "  QT_QPA_PLATFORM=xcb ./build/Binaries/dolphin-emu -e /path/to/SSBB_NTSC.iso"
```

### NixOS Complete Workflow

For NixOS, use this script (requires `nix-shell` and `steam-run`):

```bash
#!/bin/bash
set -e

REPOS_DIR="${1:-./repos}"
ISO_PATH="$2"  # Path to your Brawl ISO (RSBE01)

if [ -z "$ISO_PATH" ]; then
    echo "Usage: $0 [repos_dir] <path_to_brawl_iso>"
    exit 1
fi

mkdir -p "$REPOS_DIR"
cd "$REPOS_DIR"

# ====== Build Dolphin ======
echo "=== Building Dolphin ==="
cd dolphin
git submodule update --init --recursive

# Enter nix-shell and build
nix-shell shell.nix --run "mkdir -p build && cd build && cmake .. -DLINUX_LOCAL_DEV=ON -DUSE_SYSTEM_FMT=OFF && cmake --build . -j\$(nproc)"

# Setup Sys directory symlink
cd build/Binaries && ln -sf ../../Data/Sys Sys && cd ../../..

# ====== Build brawlback-asm ======
echo "=== Building brawlback-asm ==="
cd brawlback-asm
git submodule update --init --recursive

# Download toolchain
nix-shell -p python3Packages.click python3Packages.requests python3Packages.rich --run "python3 ./bbk.py setup"

# Apply Linux case fixes
cd Brawlback-Online/include && ln -sf EXI_hooks.h EXI_Hooks.h && cd ../..
cd lib/BrawlHeaders/OpenRVL/include/revolution && ln -sf FA fa && cd FA && ln -sf FARemove.h FAremove.h && cd ../../../../../..

# Build with steam-run (handles dynamic linking on NixOS)
NIXPKGS_ALLOW_UNFREE=1 nix-shell -p steam-run --run "export TMPDIR=/tmp && steam-run make"

# ====== Generate GCT files ======
echo "=== Generating GCT files ==="
cd sd-card/vBrawl

# Create include merger script
cat > /tmp/merge_includes.py << 'PYEOF'
#!/usr/bin/env python3
import os, re, sys
def resolve(f, d, s=None):
    s = s or set()
    if f in s: return ""
    s.add(f)
    p = os.path.join(d, f)
    if not os.path.exists(p): return ""
    r = []
    for l in open(p):
        m = re.match(r"\.include\s+(.+)", l.strip())
        r.append(resolve(m.group(1).strip(), d, s) if m else l)
    return "".join(r)
print(resolve(os.path.basename(sys.argv[1]), os.path.dirname(sys.argv[1]) or "."))
PYEOF

python3 /tmp/merge_includes.py BRAWLBACK-ONLINE.txt > BRAWLBACK-ONLINE-merged.txt
python3 /tmp/merge_includes.py BRAWLBACK-ONLINE-DEV.txt > BRAWLBACK-ONLINE-DEV-merged.txt

# Download GCTRealMate if not present
if [ ! -f GCTRealMate.exe ]; then
    wget -q https://github.com/Project-Plus-Development-Team/GCTRealMate/releases/latest/download/GCTRealMate.zip
    unzip -o GCTRealMate.zip
fi

# Compile with wine
nix-shell -p wineWowPackages.stable --run "wine GCTRealMate.exe -o BRAWLBACK-ONLINE.GCT BRAWLBACK-ONLINE-merged.txt"
nix-shell -p wineWowPackages.stable --run "wine GCTRealMate.exe -o BRAWLBACK-ONLINE-DEV.GCT BRAWLBACK-ONLINE-DEV-merged.txt"

cd ../..

# ====== Create SD card image ======
echo "=== Creating SD card ==="
SD_PATH="$HOME/.local/share/dolphin-emu/Wii/sd-brawlback.raw"
mkdir -p "$(dirname "$SD_PATH")"

nix-shell -p mtools dosfstools --run "
dd if=/dev/zero of='$SD_PATH' bs=1M count=128 2>/dev/null
mkfs.vfat -F 32 '$SD_PATH'
mmd -i '$SD_PATH' ::/vBrawl ::/vBrawl/pf ::/vBrawl/pf/module ::/vBrawl/pf/plugins
mcopy -i '$SD_PATH' sd-card/vBrawl/gc.txt ::/vBrawl/
mcopy -i '$SD_PATH' sd-card/vBrawl/BRAWLBACK-ONLINE.GCT ::/vBrawl/
mcopy -i '$SD_PATH' lib/Syriinge/sy_core.rel ::/vBrawl/pf/module/
mcopy -i '$SD_PATH' Brawlback-Online/Brawlback-Online.rel ::/vBrawl/pf/plugins/
"

# ====== Configure Dolphin ======
echo "=== Configuring Dolphin ==="
mkdir -p ~/.config/dolphin-emu
cat >> ~/.config/dolphin-emu/Dolphin.ini << EOF
[Core]
WiiSDCard = True
WiiSDCardWritable = True
WiiSDCardPath = $SD_PATH
[Interface]
UsePanicHandlers = False
EOF

# ====== Create launcher script ======
echo "=== Creating launcher ==="
cat > "$REPOS_DIR/run-brawlback.sh" << EOF
#!/bin/bash
cd "$REPOS_DIR/dolphin"
nix-shell shell.nix --run "QT_QPA_PLATFORM=xcb ./build/Binaries/dolphin-emu -e '$ISO_PATH'"
EOF
chmod +x "$REPOS_DIR/run-brawlback.sh"

cd "$REPOS_DIR"
echo ""
echo "=== Build Complete ==="
echo "Run: ./run-brawlback.sh"
```

---

## Next Steps

1. Create a virtual SD card in Dolphin
2. Copy `sd-card/vBrawl/` contents to the virtual SD
3. Generate GCT files using GCTRealMate
4. Configure Dolphin to use the Brawlback build
5. Test with a Brawl ISO

---

*Last updated: January 4, 2026*
