# Brawlback Project Goals

## Current Goals

### G1: Understand the Project and Demo Current State
**Status:** In Progress
**Priority:** High

- [ ] Read and understand the architecture documentation
- [ ] Set up the development environment (originally Windows-based)
- [ ] Build the brawlback-asm module
- [ ] Build the custom Dolphin fork
- [ ] Successfully run the launcher and connect to a test match
- [ ] Document any issues encountered during setup

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
**Status:** Unknown
**Priority:** Medium

- [ ] Test on Linux
- [ ] Test on macOS
- [ ] Document platform-specific build requirements

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
