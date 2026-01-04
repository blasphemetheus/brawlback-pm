# Brawlback Improvement Opportunities

A prioritized list of improvements that could be made to complete this project.

---

## Critical Priority (Release Blockers)

### 1. Fix Savestate System
**Impact:** Without this, rollback doesn't work reliably
**Difficulty:** High
**Files:** `dolphin/Source/Core/Core/Brawlback/Savestate.cpp`

**Current Problems:**
- Captures ~21MB of memory, target is <10MB
- Causes desync during rollback - essential game state is missing or wrong
- Copy time exceeds 2ms threshold

**Potential Approaches:**
1. **Memory profiling** - Run game with different memory regions disabled to identify what's truly necessary
2. **Differential savestates** - Only save what changed since last frame
3. **Region analysis** - Study Slippi's approach to Melee savestates and adapt
4. **Compression** - Implement fast compression (LZ4) for savestate data

**Research Needed:**
- Which heaps contain frame-dependent game state vs static data?
- Are Fighter1Resource/Fighter2Resource actually needed per-frame?
- Can InfoExtraResource/InfoResource be excluded?

### 2. Memory Region Compatibility with Project+
**Impact:** P+ is the primary competitive mod
**Difficulty:** Medium
**Files:** `Savestate.cpp`, `brawlback-asm` heap definitions

**Work Required:**
- Document P+ memory layout differences from vanilla
- Make heap addresses configurable or auto-detected
- Test with multiple P+ versions

---

## High Priority

### 3. Remove Hardcoded Values
**Difficulty:** Low-Medium

| Issue | Location | Fix |
|-------|----------|-----|
| Stage locked to Battlefield | `Rollback_Hooks.cpp:81` | Read stage from game state |
| Player count assumed | `Rollback_Hooks.cpp:109` | Query game for player count |
| Game settings static | `Rollback_Hooks.cpp:747` | Initialize from Dolphin |

### 4. Complete Pause Handling
**Difficulty:** Low
**File:** `Rollback_Hooks.cpp:242`

The pause button detection uses incomplete bit checking. Need to verify all pause-related button bits are handled.

### 5. Effects Heap Management
**Difficulty:** Medium
**Files:** Recent commits in both dolphin and brawlback-asm

Particle effects need special handling during rollback to prevent visual glitches. Current implementation tracks effects heap before rollback and reloads after, but needs refinement.

### 6. Time Synchronization for Doubles
**Difficulty:** Medium
**File:** `TimeSync.cpp`

The floating-point serialization for 2v2 matches has known issues. Need proper solution for synchronizing 4-player timing.

---

## Medium Priority

### 7. Replay System Fixes
**Difficulty:** Medium
**Files:** `brawlback-asm` replay code, launcher

**Issues to Fix:**
- Input leak during loading screen causes desyncs
- Infinite replay loading can crash game
- Need to determine and enforce maximum replay count

### 8. Improve Matchmaking Resilience
**Difficulty:** Low
**File:** `Matchmaking.cpp`

Currently uses either primary or backup server. Should try both and use whichever responds first.

### 9. Input Conversion Optimization
**Difficulty:** Low
**File:** `Rollback_Hooks.cpp:308`

Input format conversion happens every frame but could be done once at match start.

### 10. Hash Function Improvement
**Difficulty:** Low
**File:** `SlippiUtility.h`

Current hash function marked as "probably bad" - should be replaced with proven fast hash like xxHash or MurmurHash.

### 11. Code Organization
**Difficulty:** Low
**File:** `BrawlbackUtility.h:43`

GameReport struct should be moved to brawlback-common submodule and properly packed for cross-platform compatibility.

---

## Lower Priority (Nice to Have)

### 12. Music Support
**Difficulty:** High

Currently disabled because it conflicts with rollback. Would require:
- Understanding how Brawl's music system interacts with game state
- Either excluding music state from savestates or finding a way to roll it back seamlessly

### 13. Linux Build Improvements
**Difficulty:** Medium
**Status:** ✅ DONE (PR #62 submitted)

- [x] Test and document Linux build process - **DONE** (LINUX_BUILD_GUIDE.md)
- [x] Fix 8 build/runtime issues - **DONE** (see PR-DESCRIPTION.md)
- [x] Submit fixes upstream - **PR #62** https://github.com/Brawlback-Team/dolphin/pull/62
- [ ] Ensure launcher works on Linux - Not tested yet
- [ ] Package as AppImage or Flatpak

### 14. macOS Support
**Difficulty:** Medium-High

- Test Dolphin fork on macOS
- Handle code signing requirements
- Launcher compatibility

### 15. Spectator Mode
**Difficulty:** High

Allow third parties to watch matches in real-time without participating.

### 16. Statistics Integration
**Difficulty:** Medium

- Parse replay files for match statistics
- Display in launcher
- Export to common formats

### 17. Better Error Messages
**Difficulty:** Low

- More descriptive desync error messages
- Network connection troubleshooting
- Build/setup validation

---

## Technical Debt

### 18. Documentation
- [ ] Code comments for complex rollback logic
- [ ] Build instructions for all platforms
- [ ] Architecture decision records
- [ ] Contributing guide

### 19. Testing
- [ ] Unit tests for shared structures
- [ ] Integration tests for EXI communication
- [ ] Automated savestate validation
- [ ] Network simulation tests

### 20. CI/CD
- [ ] Automated builds for all repos
- [ ] Version coordination across repos
- [ ] Release automation

---

## Research Tasks

### R1. Study Slippi Savestate Implementation
Slippi works reliably for Melee - understand their approach:
- What memory regions do they save?
- How do they handle region detection?
- What optimizations do they use?

### R2. Brawl Memory Layout Analysis
Deep dive into Brawl's memory:
- Which heaps are static vs dynamic?
- What data is truly needed for deterministic replay?
- How does P+ modify the memory layout?

### R3. Performance Profiling
- Where are the bottlenecks?
- Is savestate copy the only issue?
- Network latency vs processing time breakdown

### R4. Desync Root Cause Analysis
- Create reproducible desync scenarios
- Compare savestate contents between players
- Identify divergence points

---

## Priority Matrix

| Improvement | Impact | Difficulty | Priority |
|-------------|--------|------------|----------|
| Fix Savestates | Critical | High | 1 |
| P+ Compatibility | High | Medium | 2 |
| Remove Hardcodes | Medium | Low | 3 |
| Pause Handling | Low | Low | 4 |
| Effects Heap | Medium | Medium | 5 |
| Replay Fixes | Medium | Medium | 6 |
| Time Sync Doubles | Medium | Medium | 7 |
| Matchmaking | Low | Low | 8 |

---

*This list will be updated as development progresses.*
