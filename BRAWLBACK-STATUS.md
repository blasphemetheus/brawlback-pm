# Brawlback Linux Port - Status & TODO

## Quick Reference

| Item | Value |
|------|-------|
| **PR** | https://github.com/Brawlback-Team/dolphin/pull/62 |
| **Fork** | https://github.com/blasphemetheus/dolphin (branch: `linux-fixes`) |
| **Build Guide** | See `LINUX_BUILD_GUIDE.md` |
| **Matchmaking** | lylat.gg:43113 (currently offline) |
| **Brawl ISO** | RSBE01 (NTSC-U) |
| **Get lylat.json** | https://slippi.gg/online/enable → download user.json → rename to lylat.json |

### Quick Build (with my fixes)
```bash
git clone https://github.com/blasphemetheus/dolphin.git
cd dolphin && git checkout linux-fixes
git submodule update --init --recursive
mkdir build && cd build
cmake .. -DUSE_SYSTEM_FMT=OFF
cmake --build . -j$(nproc)
QT_QPA_PLATFORM=xcb ./Binaries/dolphin-emu -e /path/to/BRAWLBACK-ONLINE.elf
```

---

## Overview
Porting Brawlback (Super Smash Bros. Brawl rollback netcode) to Linux using the Dolphin emulator fork.

---

## Problems Encountered & Fixes Applied

### 1. Wiimote Controller Crash (FIXED)
**Problem:** Dolphin crashed at boot with:
```
vector::_M_range_check: __n (which is 0) >= this->size() (which is 0)
```
**Root Cause:** `InputConfig::GetController(0)` was called before any controllers were created. The `GetHIDWiimoteSource()` function accessed index 0 of an empty vector.

**Fix Location:** `Source/Core/Core/HW/Wiimote.cpp` - `GetHIDWiimoteSource()`

**Solution:** Added bounds check before accessing controller:
```cpp
if (::Wiimote::GetConfig()->GetControllerCount() > static_cast<int>(index))
{
  hid_source = static_cast<WiimoteEmu::Wiimote*>(::Wiimote::GetConfig()->GetController(index));
}
```

---

### 2. IncrementalRB Memory Crash (FIXED)
**Problem:** Game crashed with:
```
Unknown Pointer 0x14000000 PC 0x00000000 LR 0x00000000
```
The address `0x14000000` is just past the end of Wii EXRAM (64MB: 0x10000000-0x14000000).

**Root Cause:** `IncrementalRB::InitState()` was called at boot time (in `Memmap.cpp`) before all Wii memory subsystems were ready. It tried to access game memory addresses that weren't valid yet.

**Fix Location:** Three files modified:
- `Source/Core/Core/Brawlback/include/incremental-rollback/incremental_rb.h` (new declarations)
- `Source/Core/Core/Brawlback/include/incremental-rollback/incremental_rb.cpp` (new functions)
- `Source/Core/Core/HW/Memmap.cpp` (use RegisterCallbacks instead of InitState)
- `Source/Core/Core/HW/EXI/EXIBrawlback.cpp` (call EnsureInitialized)

**Solution:** Implemented lazy initialization pattern:
1. `RegisterCallbacks()` - stores memory callbacks at boot (safe, no memory access)
2. `IsInitialized()` - check if InitState has been called
3. `EnsureInitialized()` - calls InitState only when netplay actually needs it

The `EnsureInitialized()` call was added to `CEXIBrawlback::SaveState()` since that's the first function that uses IncrementalRB and is only called when netplay is active.

---

### 3. Wayland/Graphics Issues (WORKAROUND)
**Problem:** Dolphin failed to create drawable/surfaces on Wayland.

**Workaround:** Force X11 mode with:
```bash
QT_QPA_PLATFORM=xcb dolphin-emu
```

---

### 4. GameCube Controller Adapter "Resource Busy" (PENDING)
**Problem:** Error when trying to use Mayflash/Wii U GC adapter.

**Root Cause:** Missing udev rules - Linux kernel claims the device before Dolphin can access it.

**Solution:** Install udev rules:
```bash
sudo cp /tmp/51-gcadapter.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
# Unplug and replug the adapter
```

---

### 5. Incompatible Plugin Crash (FIXED)
**Problem:** Game crashed after Brawlback-Online plugin loaded:
```
Invalid read from 0xe6b43ed4, PC = 0x801e18ec
```

**Root Cause:** SD card contained extra plugins from P+/AllStars (lavaNeutralSpawns.rel, Physics.rel) that were incompatible with vanilla Brawlback.

**Solution:** Created minimal SD card (`sd-minimal.raw`) with ONLY required Brawlback files:
```
/vBrawl/gc.txt
/vBrawl/BRAWLBACK-ONLINE.GCT
/vBrawl/BRAWLBACK-ONLINE-DEV.GCT
/vBrawl/pf/module/sy_core.rel
/vBrawl/pf/plugins/Brawlback-Online.rel
```

Created with:
```bash
dd if=/dev/zero of=sd-minimal.raw bs=1M count=512
mkfs.fat -F 32 sd-minimal.raw
mmd -i sd-minimal.raw ::/vBrawl
# ... copy required files with mcopy
```

Updated `~/.config/dolphin-emu/Dolphin.ini`:
```ini
WiiSDCardPath = /home/dori/.local/share/dolphin-emu/Wii/sd-minimal.raw
```

---

### 6. Menu Memory Errors (NON-CRITICAL)
**Problem:** Dismissable errors during loading:
```
Invalid write to 0x00003498, PC = 0x801491e8
Invalid read from 0x00000020, PC = 0x80145bb8
```

**Analysis:** These are NULL pointer dereferences in Brawl's menu/UI code (PC 0x8014xxxx). The addresses 0x00003498 and 0x00000020 are small offsets from NULL, suggesting uninitialized menu structures or missing profile/save data.

**Status:** Non-critical. Errors can be dismissed and game proceeds to Character Select Screen (CSS). These are likely related to optional features not present in the minimal SD card setup.

---

## Current Status

| Component | Status | Notes |
|-----------|--------|-------|
| Brawlback Dolphin Build | ✅ Working | Custom fork compiles and runs on Linux |
| Vanilla Brawl Boot | ✅ Working | Brawl loads without crashes |
| IncrementalRB | ✅ Fixed | Lazy initialization implemented |
| Wiimote Init | ✅ Fixed | Bounds check added |
| Brawlback ELF | ✅ Working | Boots to CSS with minimal SD card |
| Brawlback Plugin | ✅ Loaded | Syringe 0.6.0 + Brawlback-Online.rel v0.0.1 |
| Menu Errors | ⚠️ Non-critical | NULL ptr errors dismissable, game continues |
| Matchmaking Server | ❌ Offline | lylat.gg:43113 connection refused |
| Brawlback Netplay | ⏳ Blocked | Cannot test - matchmaking server down |
| GC Adapter | ⚠️ Pending | Needs udev rules |
| P+ Integration | ❌ Not working | Separate project, folder structure incompatible |

---

## Project+ Setup Status

### P+ Dolphin Downloaded
- ✅ P+ Dolphin v3.1.5 AppImage downloaded and extracted
- Location: `/home/dori/Applications/squashfs-root/usr/bin/project-plus-dolphin`
- Config: `~/.config/project-plus-dolphin/`
- Data: `~/.local/share/project-plus-dolphin/`

### P+ Files Setup (AllStars)
- ✅ Created 2GB sd.raw at `~/.local/share/project-plus-dolphin/Wii/sd.raw`
- ✅ Copied AllStars P+ files to `/Project+/` folder in sd.raw
- ✅ Added `WiiSDCard = True` and `WiiSDCardWritable = True` to config
- ⚠️ **ISSUE**: AllStars uses `Project+/` folder but standard P+ uses `projectm/`

### P+ Launch Methods Tried

1. **P+ Dolphin + Offline Launcher.dol** - CRASH
   - Black screen with FPS overlay that freezes
   - Log shows: `Unhandled Exception 3` at `0xcccccccc`
   - Crash in `gfModule` creation - uninitialized function pointer
   - **Root cause**: Standard P+ launcher incompatible with AllStars files

2. **P+ Dolphin + AllStars boot.elf** - Black screen, hangs
   - The AllStars boot.elf designed for Wii homebrew, not Dolphin

3. **P+ Dolphin + Brawl ISO directly** - ✅ Works (loads vanilla Brawl)
   - Confirms P+ Dolphin itself works, issue is with launcher/SD card

4. **Empty sd.raw issue** - Fixed
   - Original 128MB sd.raw was empty
   - Sync folder doesn't populate sd.raw automatically
   - Created 2GB sd.raw and copied files with mtools

### Options to Fix P+

**Option A: Official P+ Files (Recommended)**
1. Download Wii version from projectplusgame.com/download
2. Extract sd.raw from official package
3. Use with P+ Dolphin's built-in launcher

**Option B: Fix Current Setup**
1. Rename `Project+/` to `projectm/` in sd.raw
2. Standard P+ launcher expects `projectm/` folder name
3. Use mtools: `mmd -i sd.raw ::/projectm && mcopy ...`

**Option C: AUR Package (Easiest)**
1. `yay -S project-plus-netplay`
2. Pre-configured, sets up everything automatically
3. Just need to set Brawl ISO path

**Option D: Dolphin Folder Sync**
1. Use Dolphin's "Convert File to Folder" feature
2. Edit files directly in filesystem
3. Auto-syncs on game start

### Current Understanding

- **Brawlback Dolphin** works with **vBrawl** using BRAWLBACK-ONLINE.elf
- **P+ Dolphin** has built-in launcher expecting `projectm/` folder structure
- **AllStars** is a mod ON TOP of P+ with different folder structure
- **P+ with Brawlback rollback** requires merging both - complex integration

### P+ + Brawlback Integration Challenges (Discovered 2026-01-03)

**The Problem:**
P+ and Brawlback use different code loading mechanisms that are fundamentally incompatible without merging.

**Code Architecture Differences:**

| Component | P+ | Brawlback |
|-----------|-----|-----------|
| GCT Size | 98KB | 8KB |
| Folder Path | `/Project+/pf/` | `/vBrawl/pf/` |
| Code Purpose | File loading + gameplay mods | Rollback netcode + basic file loading |
| Path Location | Hardcoded in GCT at 0x80406920 | Hardcoded in FilePatchCode.asm |

**What We Tried:**
1. **Copy P+ files to vBrawl folder** → Codes don't load from Dolphin's Gecko system
2. **Use Brawlback GCT in Load/Codes/** → SD card conditional check fails
3. **Launch Brawlback ELF** → Crashes at 0x17fc0000 (unmapped memory)
4. **Enable WiiSDCard in config** → SD card not being detected by Gecko codes

**Root Cause:**
The Brawlback GCT has a conditional check:
```
225664EC 00000000 # only execute if memory 0x805664EC != 0 (SD mounted)
```
This check prevents the file patching codes from running unless the SD card mount flag is set. The flag isn't being set when launching directly from ISO.

**Paths Forward:**
1. **Build merged GCT** - Combine P+ file loader codes with Brawlback rollback codes
2. **Use launcher approach** - Create/modify a launcher DOL that applies both code sets
3. **Modify Brawlback ELF** - Fix the crash and use it with P+ files in vBrawl

---

### 5. Incompatible Plugin Crash (FIXED)
**Problem:** Game crashed with:
```
Invalid read from 0xe6b43ed4, PC = 0x801e18ec
```
After Brawlback-Online plugin loaded successfully.

**Root Cause:** The SD card contained extra plugins from P+/AllStars (lavaNeutralSpawns.rel, Physics.rel) that were incompatible with vanilla Brawlback.

**Solution:** Use minimal SD card with ONLY the files from brawlback-asm/sd-card/vBrawl:
- `/vBrawl/gc.txt`
- `/vBrawl/BRAWLBACK-ONLINE.GCT`
- `/vBrawl/BRAWLBACK-ONLINE-DEV.GCT`
- `/vBrawl/pf/module/sy_core.rel`
- `/vBrawl/pf/plugins/Brawlback-Online.rel`

Created minimal SD card at: `~/.local/share/dolphin-emu/Wii/sd-minimal.raw`

---

## TODO

### Immediate (P+ Setup)
- [ ] Remove `/etc/udev/rules.d/51-gcadapter.rules` (conflicts with AUR)
- [ ] Install AUR package: `yay -S project-plus-netplay`
- [ ] If AUR fails: Download official P+ Wii files from projectplusgame.com
- [ ] Fix sd.raw folder naming: rename `Project+/` to `projectm/`
- [ ] Test P+ loads correctly in P+ Dolphin

### High Priority
- [ ] Install GC adapter udev rules and test controller
- [ ] Test Brawlback netplay connection (requires server or local setup)
- [ ] Verify Brawlback Gecko codes are loading properly
- [ ] Test rollback/resimulation actually works during netplay

### Medium Priority (P+ + Brawlback Integration)
- [ ] Understand how P+ applies patches vs how Brawlback does
- [ ] Merge P+ Gecko codes with Brawlback codes
- [ ] Test P+ with Brawlback rollback netcode
- [ ] Document full setup process for other Linux users

### Low Priority
- [ ] Fix compile warnings in Brawlback code
- [ ] Native Wayland support (currently using X11 workaround)
- [ ] Package as AppImage or Flatpak for easy distribution
- [ ] Contribute fixes upstream to Brawlback project

---

## File Locations

### Brawlback Dolphin (Modified Files)
- `/home/dori/brawlback/repos/dolphin/Source/Core/Core/HW/Wiimote.cpp`
- `/home/dori/brawlback/repos/dolphin/Source/Core/Core/HW/Memmap.cpp`
- `/home/dori/brawlback/repos/dolphin/Source/Core/Core/HW/EXI/EXIBrawlback.cpp`
- `/home/dori/brawlback/repos/dolphin/Source/Core/Core/Brawlback/include/incremental-rollback/incremental_rb.h`
- `/home/dori/brawlback/repos/dolphin/Source/Core/Core/Brawlback/include/incremental-rollback/incremental_rb.cpp`

### Brawlback Dolphin Configuration
- Logger config: `~/.config/dolphin-emu/Logger.ini`
- Game settings: `~/.local/share/dolphin-emu/GameSettings/RSBE01.ini`
- SD card: `~/.local/share/dolphin-emu/Wii/sd/`
- Logs: `~/.local/share/dolphin-emu/Logs/dolphin.log`

### Brawlback Dolphin Build
- Build directory: `/home/dori/brawlback/repos/dolphin/build/`
- Executable: `/home/dori/brawlback/repos/dolphin/build/Binaries/dolphin-emu`

### P+ Dolphin (Downloaded AppImage)
- Executable: `/home/dori/Applications/squashfs-root/usr/bin/project-plus-dolphin`
- Built-in launcher: `/home/dori/Applications/squashfs-root/usr/share/project-plus-dolphin/user/Launcher/`
- Config: `~/.config/project-plus-dolphin/Dolphin.ini`
- SD card: `~/.local/share/project-plus-dolphin/Wii/sd.raw` (2GB FAT32)
- Logs: `~/.local/share/project-plus-dolphin/Logs/dolphin.log`

### P+ Files (AllStars)
- Source: `/home/dori/Downloads/Project-Plus-All-Stars-1.0.0/Build/AllStar+/`
- Copied to sd.raw: `::/Project+/` (should be `::/projectm/`)

---

## Launch Commands

### Brawlback Dolphin (vBrawl with rollback)
```bash
QT_QPA_PLATFORM=xcb /home/dori/brawlback/repos/dolphin/build/Binaries/dolphin-emu -e /home/dori/Downloads/SSBB_NTSC.iso
```

### P+ Dolphin (P+ with delay-based netplay)
```bash
QT_QPA_PLATFORM=xcb /home/dori/Applications/squashfs-root/usr/bin/project-plus-dolphin -e "/home/dori/Downloads/Project+ Offline Launcher.dol"
```

### mtools Commands for sd.raw
```bash
# List sd.raw contents
mdir -i ~/.local/share/project-plus-dolphin/Wii/sd.raw ::/

# Create directory
mmd -i ~/.local/share/project-plus-dolphin/Wii/sd.raw ::/projectm

# Copy files into sd.raw
mcopy -i ~/.local/share/project-plus-dolphin/Wii/sd.raw -s /path/to/files/* ::/projectm/
```

---

## Session 2026-01-03: Additional Fixes & Findings

### 7. EnsureInitialized() Missing in Rollback Paths (FIXED)
**Problem:** Invalid read errors and potential crashes when Rollback was called before SaveState.

**Root Cause:** The lazy initialization fix only added `EnsureInitialized()` to `SaveState()`, but `Rollback()` can be called first in two other code paths:
- `handleLoadSavestate()` - when receiving opponent's savestate
- `updateSync()` - when rollback is triggered during frame sync

**Fix Location:** `Source/Core/Core/HW/EXI/EXIBrawlback.cpp`

**Solution:** Added `EnsureInitialized()` guards before all `IncrementalRB::Rollback()` calls:
```cpp
// In handleLoadSavestate():
IncrementalRB::EnsureInitialized();
IncrementalRB::Rollback(this->lastStatedFrame, stopRollbackFrame);

// In updateSync():
IncrementalRB::EnsureInitialized();
IncrementalRB::Rollback(locFrame, latestConfirmedFrame);
```

**Commits:**
- `a0f76ed` - Add EnsureInitialized() to all IncrementalRB::Rollback call sites

---

### 8. minizip-ng CMake Build Error (FIXED)
**Problem:** Build failed with:
```
Unknown CMake command "check_function_exists"
```

**Root Cause:** Missing CMake module includes in `Externals/minizip-ng/CMakeLists.txt`.

**Fix Location:** `Externals/minizip-ng/CMakeLists.txt`

**Solution:**
```cmake
project(minizip C)

include(CheckFunctionExists)
include(CheckIncludeFile)

add_library(minizip STATIC
```

**Commits:**
- `d2c5d1f` - Fix minizip-ng CMakeLists missing includes

---

### 9. Invalid Read Popups Not Logging (FIXED)
**Problem:** Error popups appeared but weren't captured in dolphin.log.

**Root Cause:**
1. `PanicAlertFmt` uses `MASTER_LOG` log type, but `MASTER = False` in Logger.ini
2. `Verbosity = 1` was below `LERROR = 2` threshold

**Solution:** Updated `~/.config/dolphin-emu/Logger.ini`:
```ini
[Logs]
MASTER = True
Brawlback = True
MEMMAP = True

[Options]
Verbosity = 3
WriteToFile = True
```

---

### 10. Invalid Read Popups Blocking Gameplay (DISABLED)
**Problem:** Recurring popup errors during WiFi menu navigation:
```
Invalid write to 0x00003498, PC = 0x801491e8  (once at boot)
Invalid read from 0x00000020, PC = 0x80145bb8  (few times)
Invalid read from 0x000033f6, PC = 0x800ccebc  (recurring every ~16ms)
```

**Analysis:**
- All PC addresses are in Brawl's WiFi networking code (0x8014xxxx, 0x800cxxxx range)
- The recurring error at PC 0x800ccebc is 8 bytes before a Brawlback hook at 0x800ccec4
- Brawlback replaces function at 0x800ccec4 with `Utils::ReturnImmediately`
- Low target addresses (0x20, 0x3498, 0x33f6) are offsets from NULL pointers
- Game code tries to access uninitialized network structures since Brawlback bypasses Nintendo WFC

**Why Windows Doesn't Show This:** Windows Dolphin likely has different popup settings or the memory handling differs.

**Solution:** Disabled panic handlers in `~/.config/dolphin-emu/Dolphin.ini`:
```ini
[Interface]
UsePanicHandlers = False
```

Errors are still logged to `~/.local/share/dolphin-emu/Logs/dolphin.log` for debugging.

---

### 11. GC Adapter Detection & Permissions
**Status:** Adapter is detected but may need udev rules for access.

**Detection Check:**
```bash
lsusb | grep Nintendo
# Output: 057e:0337 Nintendo Co., Ltd Wii U GameCube Controller Adapter
```

**udev Rules (if needed):**
```bash
echo 'SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="0337", MODE="0666"' | sudo tee /etc/udev/rules.d/51-gcadapter.rules
sudo udevadm control --reload-rules
sudo udevadm trigger
# Unplug and replug the adapter
```

**Permission Check:**
```bash
getfacl /dev/bus/usb/003/XXX  # replace XXX with device number
# Should show user:dori:rw- or similar
```

---

### 12. Two-Instance Local Testing Setup
For testing netplay locally, two Dolphin instances with different accounts are needed.

**Getting Account Credentials:**
1. Go to https://slippi.gg/online/enable
2. Log in with your Slippi account (or create one)
3. Download the `user.json` file
4. Rename to `lylat.json` and place in Dolphin's data directory

**Account 1:** DBTD#411 (tv/spikenarding)
- Credentials: `~/.local/share/dolphin-emu/lylat.json`

**Account 2:** HUGG#388 (huggins)
- Credentials: `~/dolphin-user-2/lylat.json`

**Setup Second Instance:**
```bash
# Create user directory
mkdir -p ~/dolphin-user-2/Config ~/dolphin-user-2/Wii

# Copy configs
\cp -r ~/.config/dolphin-emu/* ~/dolphin-user-2/Config/
\cp -r ~/.local/share/dolphin-emu/* ~/dolphin-user-2/

# Copy second account
\cp "/home/dori/Downloads/user(2).json" ~/dolphin-user-2/lylat.json
```

**Launch Commands:**
```bash
# Instance 1 (default config)
QT_QPA_PLATFORM=xcb /home/dori/brawlback/repos/dolphin/build/Binaries/dolphin-emu \
  -e /home/dori/brawlback/repos/brawlback-asm/BRAWLBACK-ONLINE.elf

# Instance 2 (alternate user folder)
QT_QPA_PLATFORM=xcb /home/dori/brawlback/repos/dolphin/build/Binaries/dolphin-emu \
  -u ~/dolphin-user-2 \
  -e /home/dori/brawlback/repos/brawlback-asm/BRAWLBACK-ONLINE.elf
```

---

### 13. Matchmaking Server Status
**Server:** lylat.gg:43113
**Status as of 2026-01-03:** OFFLINE (Connection refused)

**Check Command:**
```bash
nc -zv lylat.gg 43113
# "Connection refused" = server down
# "succeeded" = server online
```

**Impact:** Two instances cannot find each other without the matchmaking server. No direct connect option available in Brawlback.

---

## Git Branch Status (2026-01-03)

### Repository: blasphemetheus/dolphin

### Branch: linux-fixes
All Linux fixes merged and pushed.

### Branch: fix/incremental-rb-linux-compat
Latest commits:
```
a0f76ed Add EnsureInitialized() to all IncrementalRB::Rollback call sites
d2c5d1f Fix minizip-ng CMakeLists missing includes
88c2492 Fix IncrementalRB Linux compatibility issues
3bf5e34 Implement lazy initialization for IncrementalRB
8b36b64 Add Qt6::GuiPrivate dependency for Linux build
```

### PR Status
**PR #62 Submitted:** https://github.com/Brawlback-Team/dolphin/pull/62
- Title: "Linux Compatibility Fixes for Brawlback Dolphin"
- Base branch: `savestates-efficiency-v2`
- Contains all 8 Linux fixes
- Detailed documentation in `/home/dori/brawlback/PR-DESCRIPTION.md`

---

## Updated Current Status (2026-01-03)

| Component | Status | Notes |
|-----------|--------|-------|
| Brawlback Dolphin Build | ✅ Working | All Linux fixes applied |
| IncrementalRB | ✅ Fixed | Lazy init + all Rollback paths covered |
| Wiimote Init | ✅ Fixed | Bounds check added |
| minizip-ng Build | ✅ Fixed | CMake includes added |
| Brawlback ELF | ✅ Working | Boots to CSS, plugin loads |
| Invalid Read Popups | ✅ Disabled | Errors logged only |
| Logging | ✅ Configured | MASTER + Brawlback enabled, Verbosity=3 |
| GC Adapter | ✅ Detected | Bus 003, may need udev rules |
| Two-Instance Setup | ✅ Ready | DBTD#411 + HUGG#388 accounts |
| Matchmaking Server | ❌ Offline | lylat.gg:43113 refusing connections |
| Netplay Testing | ⏳ Blocked | Waiting for matchmaking server |

---

## Next Steps

1. **Wait for PR review** - PR #62 submitted to Brawlback-Team/dolphin
2. **Monitor matchmaking server** - Check periodically if lylat.gg:43113 comes online
3. **Test netplay connection** - When server is up, test two-instance connection
4. **Verify rollback works** - Confirm savestates and rollback function during gameplay

---

## Summary: What Worked, What Didn't, What's Next

### ✅ WHAT WORKED

| Component | Status | Details |
|-----------|--------|---------|
| Dolphin Build | ✅ | Compiles on Linux with 8 fixes applied |
| Brawl Boot | ✅ | Vanilla SSBB loads and runs |
| Brawlback ELF | ✅ | Boots to CSS, loads Syringe + Brawlback plugin |
| IncrementalRB | ✅ | Lazy initialization fixes memory crash |
| Wiimote Init | ✅ | Bounds check prevents vector crash |
| GC Adapter | ✅ | Detected (with udev rules) |
| Logging | ✅ | Configured to capture errors |

### ❌ WHAT DIDN'T WORK / BLOCKED

| Component | Status | Reason |
|-----------|--------|--------|
| Matchmaking Server | ❌ | lylat.gg:43113 offline (connection refused) |
| Netplay Testing | ⏳ | Cannot test without matchmaking server |
| P+ + Brawlback | ❌ | Different code architectures, complex integration needed |
| Wayland | ⚠️ | Workaround needed (QT_QPA_PLATFORM=xcb) |

### 🔧 WHAT WAS TRIED

1. **Invalid read popups** → Disabled with `UsePanicHandlers = False`
2. **Two-instance local test** → Set up but blocked by offline matchmaking
3. **P+ integration** → Folder structure incompatible, would need GCT merging
4. **Direct connect** → Not available in Brawlback (matchmaking only)

### 📋 WHAT'S NEXT TO GET RUNNING ON LINUX

**Minimum to play online:**
1. ✅ Build Dolphin (done, use `linux-fixes` branch or wait for PR merge)
2. ✅ Set up minimal SD card with Brawlback files
3. ⏳ Wait for matchmaking server to come online
4. Test netplay connection and verify rollback works

**For NixOS specifically:**
- See LINUX_BUILD_GUIDE.md for dependencies
- May need to add Qt6, SDL2, libusb to `nix-shell` or `devShell`
- udev rules for GC adapter need NixOS-specific setup (see below)

---

## NixOS-Specific Notes

### Dependencies (shell.nix or flake.nix)

```nix
{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  buildInputs = with pkgs; [
    # Build tools
    cmake gcc git python3 pkg-config

    # Dolphin deps
    qt6.full libxkbcommon libXrandr libXi
    SDL2 libevdev miniupnpc lzo alsa-lib pulseaudio
    bluez ffmpeg libusb1 fmt pugixml

    # For brawlback-asm
    (python3.withPackages (ps: with ps; [ click requests rich ]))
  ];

  # Wayland workaround
  QT_QPA_PLATFORM = "xcb";
}
```

### GC Adapter udev Rules (NixOS)

Add to `/etc/nixos/configuration.nix`:
```nix
services.udev.extraRules = ''
  SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="0337", MODE="0666"
'';
```

Then rebuild: `sudo nixos-rebuild switch`

### Build Commands

```bash
# Clone with my fixes
git clone https://github.com/blasphemetheus/dolphin.git
cd dolphin
git checkout linux-fixes
git submodule update --init --recursive

# Build
mkdir build && cd build
cmake .. -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DUSE_SYSTEM_FMT=OFF
cmake --build . -j$(nproc)

# Run
QT_QPA_PLATFORM=xcb ./Binaries/dolphin-emu
```
