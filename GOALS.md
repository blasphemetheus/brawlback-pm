# Brawlback Project Goals

## Current Goals

### G1: Understand the Project and Demo Current State
**Status:** Mostly Complete (Linux)
**Priority:** High

- [x] Read and understand the architecture documentation
- [x] Set up the development environment - **DONE on Linux**
- [x] Build the brawlback-asm module - **DONE** (with case-sensitivity fixes)
- [x] Build the custom Dolphin fork - **DONE** (8 Linux fixes applied)
- [x] Successfully boot Brawlback - **DONE** (boots to CSS)
- [ ] Connect to a test match - **BLOCKED** (matchmaking server offline)
- [x] Document any issues encountered during setup - **DONE** (see BRAWLBACK-STATUS.md)

### G2: Fix the Savestate System (Critical Blocker)
**Status:** Not Started
**Priority:** Critical

The savestate system is the main blocker preventing public release. Current issues:
- Savestates capture ALL memory (~21MB) causing performance issues
- Savestates cause game desync during rollback
- Memory regions are hardcoded for vanilla Brawl (not P+)

Target metrics:
- Savestate size: <10MB (ideally), <15MB (acceptable)
- Copy time: <1ms (ideal), <2ms (acceptable)

### G3: Complete the Rollback Implementation
**Status:** Partially Complete
**Priority:** High

Remaining work:
- [ ] Fix pause handling (button bit checking incomplete)
- [ ] Proper player count detection
- [ ] Stage selection (currently hardcoded to Battlefield)
- [ ] Effects heap management refinement
- [ ] Game settings initialization from Dolphin

### G4: Improve Replay System
**Status:** Functional but Buggy
**Priority:** Medium

Known issues:
- Input leak during loading screen causes desyncs
- Infinite replays can crash the game
- Need to determine maximum replay count

### G5: Cross-Platform Support
**Status:** Linux Working (PR #62 submitted)
**Priority:** Medium

- [x] Test on Linux - **DONE** (Manjaro, 8 fixes applied)
- [x] Build on Linux - **DONE** (boots to CSS)
- [x] Document platform-specific build requirements - **DONE** (see LINUX_BUILD_GUIDE.md)
- [x] Submit PR upstream - **PR #62** https://github.com/Brawlback-Team/dolphin/pull/62
- [ ] Test netplay on Linux - **BLOCKED** (matchmaking server offline)
- [ ] Test on macOS
- [ ] Test on NixOS (planned)

### G6: Project+ Compatibility
**Status:** Partial
**Priority:** Medium

- [ ] Update memory region definitions for P+
- [ ] Test with P+ mod pack
- [ ] Ensure launcher works with P+ SD card structure

---

## Future Goals

### G7: Public Beta Release
Blocked by: G2 (Savestate fixes)

### G8: Music Support
Currently disabled due to rollback conflicts.

### G9: Tournament Mode Features
- Spectator support
- Match recording improvements
- Statistics integration

---

## Completed Goals

(None yet - tracking starts here)

---

## Notes

- Development originally done on Windows
- Uses lylat.gg for matchmaking infrastructure
- Based heavily on Slippi architecture for Melee
- C++ injection via Syriinge framework (unlike Slippi's pure ASM)
