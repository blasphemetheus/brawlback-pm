# Brawlback Linux Port

Linux compatibility fixes for [Brawlback](https://github.com/Brawlback-Team) - rollback netcode for Super Smash Bros. Brawl.

## Status: PR Submitted

**PR #62:** https://github.com/Brawlback-Team/dolphin/pull/62

| Component | Status |
|-----------|--------|
| Dolphin Build | ✅ Works (8 fixes applied) |
| Brawlback Boot | ✅ Works (boots to CSS) |
| Netplay Testing | ⏳ Blocked (matchmaking server offline) |
| P+ Integration | ❌ Not yet (see docs) |

## Quick Start

```bash
# Clone Dolphin with Linux fixes
git clone https://github.com/blasphemetheus/dolphin.git
cd dolphin && git checkout linux-fixes
git submodule update --init --recursive

# Build
mkdir build && cd build
cmake .. -DUSE_SYSTEM_FMT=OFF
cmake --build . -j$(nproc)

# Run (force X11 on Wayland)
QT_QPA_PLATFORM=xcb ./Binaries/dolphin-emu -e /path/to/BRAWLBACK-ONLINE.elf
```

## Documentation

| File | Description |
|------|-------------|
| **[BRAWLBACK-STATUS.md](BRAWLBACK-STATUS.md)** | Main status doc - what works, what doesn't, SD card setup, P+ vs vBrawl |
| **[LINUX_BUILD_GUIDE.md](LINUX_BUILD_GUIDE.md)** | Build instructions for Arch, Debian, NixOS |
| **[PR-DESCRIPTION.md](PR-DESCRIPTION.md)** | Detailed analysis of all 8 commits in PR #62 |
| **[KNOWLEDGE_BASE.md](KNOWLEDGE_BASE.md)** | Architecture docs and references |

## Key Info

| Item | Value |
|------|-------|
| Fork | https://github.com/blasphemetheus/dolphin (`linux-fixes` branch) |
| Matchmaking | lylat.gg:43113 (currently offline) |
| Get lylat.json | https://slippi.gg/online/enable (download user.json, rename) |
| Brawl ISO | RSBE01 (NTSC-U) |

## What's Fixed

1. **Wiimote crash** - Bounds check for empty controller vector
2. **Memory protection** - Linux `mprotect()` wrapper for `VirtualProtect()`
3. **IncrementalRB crash** - Lazy initialization pattern
4. **CMake builds** - Missing sources, Qt6::GuiPrivate, minizip-ng
5. **Cross-platform** - PRIu64 format, errno handling, AVX attributes

See [PR-DESCRIPTION.md](PR-DESCRIPTION.md) for full details on each fix.

## Repository Structure

```
brawlback/
├── BRAWLBACK-STATUS.md      # Main status & progress tracker
├── LINUX_BUILD_GUIDE.md     # Build instructions (Arch/Debian/NixOS)
├── PR-DESCRIPTION.md        # PR #62 detailed analysis
├── KNOWLEDGE_BASE.md        # Architecture & references
├── GOALS.md                 # Project goals
├── IMPROVEMENTS.md          # Improvements roadmap
├── launch-brawlback.sh      # Helper script
└── repos/                   # Cloned repos (gitignored)
    ├── brawlback-asm/       # Game-side injection code
    ├── dolphin/             # Modified Dolphin emulator
    └── brawlback-launcher/  # Electron launcher
```

## SD Card Setup

**For Brawlback (vBrawl):** Use minimal SD with only `/vBrawl/` folder.

**Do NOT use:** AllStars or P+ files - incompatible folder structure.

See [BRAWLBACK-STATUS.md](BRAWLBACK-STATUS.md#sd-card-setup-important---read-this-first) for full details.

## Next Steps

1. Wait for PR #62 review
2. Monitor matchmaking server (lylat.gg:43113)
3. Test netplay when server is online
4. Verify rollback works during gameplay

---

*Personal fork for Linux porting. Official Brawlback: https://github.com/Brawlback-Team*
