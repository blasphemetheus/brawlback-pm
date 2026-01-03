# Brawlback Knowledge Base

A comprehensive collection of documentation, resources, and technical references for developing the Brawlback rollback netcode project.

---

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Repository Structure](#repository-structure)
3. [Technical Deep Dives](#technical-deep-dives)
4. [Learning Resources](#learning-resources)
5. [Tools](#tools)
6. [Known Issues & TODOs](#known-issues--todos)
7. [External Links](#external-links)

---

## Architecture Overview

### System Diagram

```
+------------------------------------------------------------------+
|                    BRAWLBACK ONLINE SYSTEM                        |
+------------------------------------------------------------------+

+------------------------+              +------------------------+
|   Game (Wii/Brawl)     |              |   Dolphin Emulator     |
|                        |              |                        |
| +--------------------+ |  EXI Ch.1    | +--------------------+ |
| | Rollback_Hooks.cpp | |<---32Hz----->| |  EXIBrawlback.cpp  | |
| | (Syriinge inject)  | |              | |                    | |
| |                    | | Packet:      | |  +----------------+| |
| | FrameLogic NS      | | [CMD][DATA]  | |  | Matchmaking   || |
| | FrameAdvance NS    | |              | |  | Netplay       || |
| | Netplay NS         | |              | |  | TimeSync      || |
| |                    | |              | |  | Savestate     || |
| +--------------------+ |              | |  +----------------+| |
|                        |              |                        |
| Input Pad Buffer       |              | Network Stack (ENet)   |
| Game Frame Counter     |              | Frame Data Queue       |
| Savestate Management   |              | Rollback History       |
+------------------------+              +------------------------+
         |                                       |
         +-------------------+-------------------+
                             |
                     +----------------+
                     | Remote Players |
                     | lylat.gg MM    |
                     +----------------+
```

### Rollback Flow

1. **Game sends inputs** via `CMD_ONLINE_INPUTS` EXI packet
2. **Dolphin receives inputs**, stores in frame queue
3. **Dolphin checks**: Do we have remote player's inputs for this frame?
   - **YES**: Proceed to step 4
   - **NO**: Stall (wait), or advance with prediction
4. **Dolphin sends**: `CMD_FRAMEDATA` - "game, process frame X"
5. **Game executes frame** with injected inputs
6. **After frame**: Game sends sync data (position, animation, damage)
7. **Dolphin compares**: Does remote sync data match prediction?
   - **MATCH**: Continue
   - **MISMATCH**: Trigger rollback
8. **On Rollback**:
   - Load savestate from MAX_ROLLBACK_FRAMES ago
   - Replay with correct remote inputs
   - Re-capture new savestate
   - Resume forward

### Key Constants (from brawlback-common/BrawlbackConstants.h)

| Constant | Value | Description |
|----------|-------|-------------|
| MAX_ROLLBACK_FRAMES | 5 | Maximum frames to roll back |
| MAX_SAVESTATES | 7 | 5 rollback + 2 extra |
| FRAME_DELAY | 1 | Minimum frame delay |
| FRAMEDATA_MAX_QUEUE_SIZE | 15 | Input queue depth |
| GAME_FULL_START_FRAME | 150 | Frame when full rollback enables |
| TIMESYNC_MAX_US_OFFSET | 10,000 | ~60% of a frame |

---

## Repository Structure

### brawlback-asm (Game-Side Code)
ASM/C++ codes injected into Brawl via Syriinge framework.

```
Brawlback-Online/
├── source/
│   ├── Rollback_Hooks.cpp    # Core rollback logic (~2000 lines)
│   ├── EXI_hooks.cpp         # EXI bus communication
│   ├── exi_packet.cpp        # Packet assembly/transmission
│   └── utils.cpp             # Input conversion, utilities
├── include/
│   ├── Rollback_Hooks.h      # FrameLogic, FrameAdvance, Netplay NS
│   ├── exi_packet.h          # 40+ EXI command definitions
│   └── EXI_hooks.h           # EXI device wrappers
└── Libraries/
    └── Wii/EXI/              # EXI bus abstraction
```

**Build Requirements:**
- kuribo-llvm (LLVM/Clang fork for PPC)
- elf2rel binary
- GCTRealMate
- Syriinge framework (submodule)

### dolphin (Emulator-Side Code)
Modified Dolphin with Brawlback netplay support.

```
Source/Core/Core/Brawlback/
├── BrawlbackUtility.h/cpp    # Central utilities, GameReport struct
├── Savestate.h/cpp           # Savestate capture/load (BROKEN)
├── TimeSync.h/cpp            # Network time sync
├── SlippiUtility.h/cpp       # Borrowed from Slippi
└── Netplay/
    ├── Matchmaking.h/cpp     # lylat.gg connection
    └── Netplay.h/cpp         # ENet frame broadcasting

Source/Core/HW/EXI/
└── EXIBrawlback.cpp          # EXI command handler
```

### brawlback-common (Shared Structures)
Header-only library of shared data structures.

```
├── ExiStructures.h           # Master include
├── BrawlbackConstants.h      # Tuning parameters
├── FrameData.h               # Frame container (seed + inputs)
├── PlayerFrameData.h         # Per-player frame state
├── SyncData.h                # Position, damage, animation, stocks
├── BrawlbackPad.h            # Controller input struct
├── GameSettings.h            # Match config
└── PlayerSettings.h          # Per-player config
```

### brawlback-launcher
Electron + React + TypeScript application (forked from Slippi Launcher).
- Manages Dolphin builds
- Handles mod installation
- Launches matches
- Replay analysis UI

---

## Technical Deep Dives

### EXI (External Interface) Bus

The EXI bus connects external peripherals to the Wii/GameCube. Brawlback uses it for emulator-game communication.

**Hardware Details:**
- Base Address: `0x0d806800`
- Length: `0x80` bytes
- Access Size: 32-bit
- Byte Order: Big Endian
- IRQ Line: Broadway PI, IRQ 4

**Three Independent Channels (0, 1, 2):**

| Register | Offset | Purpose |
|----------|--------|---------|
| CSR | 0x00 | Device detection, interrupt control, clock frequency |
| MAR | 0x04 | DMA start address (32-byte aligned) |
| LENGTH | 0x08 | DMA transfer size (32-byte aligned) |
| CR | 0x0C | Transfer mode, type, initiation |
| DATA | 0x10 | Immediate mode read/write (≤4 bytes) |

**Clock Frequencies:**
- 000 = 0.84375MHz (slowest)
- 110 = 54MHz (fastest)

**Transfer Modes:**
- Immediate: Direct via DATA register, up to 4 bytes
- DMA: Memory-mapped with MAR/LENGTH

**Brawlback Usage:**
- Channel 1 at 32Hz frequency
- Packets: `[1-byte CMD][payload...]`
- Cache-flushed before DMA transfer

### EXI Command Protocol

| Command | Code | Direction | Purpose |
|---------|------|-----------|---------|
| CMD_ONLINE_INPUTS | 1 | Game→Emu | Send local player inputs |
| CMD_CAPTURE_SAVESTATE | 2 | Game→Emu | Request savestate capture |
| CMD_LOAD_SAVESTATE | 3 | Game→Emu | Request savestate load |
| CMD_FRAMEDATA | 15 | Game→Emu | Game requesting inputs |
| CMD_TIMESYNC | 16 | Both | Time synchronization |
| CMD_ROLLBACK | 17 | Emu→Game | Trigger rollback |
| CMD_FRAMEADVANCE | 18 | Emu→Game | Advance to next frame |
| CMD_UPDATESYNC | 39 | Both | Update sync status |

### Savestate System (THE CRITICAL ISSUE)

**Current Heaps Being Saved:**
- System
- Fighter1Instance / Fighter2Instance
- InfoInstance / InfoExtraResource / InfoResource
- Physics
- WiiPad
- Fighter1Resource / Fighter2Resource
- FighterEffect
- FighterTechqniq
- GameGlobal

**Problems:**
1. Saves ALL memory regions (~21MB) - too slow
2. Causes desync during rollback - wrong/missing regions
3. Hardcoded for vanilla Brawl - doesn't work with P+

**Performance Targets:**
- Copy time: <1ms ideal, <2ms acceptable
- Size: <10MB ideal, <15MB usable

**Quote from PiNE:**
> "Savestates can desync when particular regions of memory that hold data that the game relies on to compute the next frame (relevant gamestate) is not included in the regions copied during rollbacks."

### Time Synchronization

**TimeSync Class (TimeSync.h):**
```cpp
frameOffsetData[MAX_NUM_PLAYERS]  // Per-player frame offsets
ackTimers                          // Round-trip timing
pingUs[MAX_NUM_PLAYERS]            // Ping measurements

shouldStallFrame()    // Determine if frame should wait
calcTimeOffsetUs()    // Calculate latency compensation
```

---

## Learning Resources

### PowerPC Assembly

| Resource | Description | URL |
|----------|-------------|-----|
| PowerPC Assembly Tutorial | Full beginner tutorial (33 chapters) | https://mariokartwii.com/ppc/ |
| WiiBrew Assembler Tutorial | Human-readable opcode explanations | https://wiibrew.org/wiki/Assembler_Tutorial |
| PowerPC For Dummies | Simplified instruction set guide | https://jimkatz.github.io/powerpc_for_dummies |
| IBM 750CL User Manual | Official processor documentation | Chapter 12 for instruction set |

### Key PPC Instructions

**Load Instructions:**
- `li rD, value` - Load immediate
- `lis rD, value` - Load immediate shifted (upper 16 bits)
- `lwz rD, offset(rA)` - Load word zero
- `lbz/lhz` - Load byte/halfword zero

**Store Instructions:**
- `stw rS, offset(rA)` - Store word
- `sth/stb` - Store halfword/byte

**Arithmetic:**
- `add/addi/addis` - Addition variants
- `sub/subf/subi` - Subtraction
- `mulli/mullw` - Multiplication
- `divw/divwu` - Division

**Branch:**
- `b target` - Unconditional branch
- `bl target` - Branch and link (call)
- `blr` - Branch to link register (return)
- `beq/bne/bgt/blt` - Conditional branches
- `bdnz` - Decrement CTR and branch if not zero

**Compare:**
- `cmpw/cmpwi` - Compare word (signed)
- `cmplw/cmplwi` - Compare word (unsigned)

### Rollback Netcode Theory

| Resource | Description |
|----------|-------------|
| [GGPO Article](https://drive.google.com/file/d/1cV0fY8e_SC1hIFF5E1rT8XRVRzPjU8W9/view) | Official GGPO rollback explanation |
| [Rollback Pseudocode](https://gist.github.com/rcmagic/f8d76bca32b5609e85ab156db38387e9) | Basic rollback algorithm |
| [GDC Talk - MK/Injustice](https://youtu.be/7jb0FOcImdg) | NetherRealm's rollback implementation |
| [INVERSUS Blog](http://blog.hypersect.com/rollback-networking-in-inversus/) | Indie game rollback deep-dive |
| [Fightin' Words Guide](https://ki.infil.net/w02-netcode.html) | Comprehensive rollback theory |

### Slippi Reference

| Resource | URL |
|----------|-----|
| Slippi ASM Codes | https://github.com/project-slippi/slippi-ssbm-asm |
| Slippi Dolphin | https://github.com/project-slippi/Ishiiruka/tree/slippi |
| Slippi Wiki | https://github.com/project-slippi/slippi-wiki |
| Replay File Spec | https://github.com/project-slippi/slippi-wiki/blob/master/SPEC.md |

### Brawl Modding

| Resource | Description |
|----------|-------------|
| [SSBB Modding Wiki](https://brawlre.github.io/public/) | Comprehensive Brawl modding wiki |
| [Custom Brawl Discord](https://discord.gg/GbxJhbv) | Community support |
| [Fizzi EXI Tutorial](https://www.youtube.com/watch?v=NOq49h0tkBI) | Slippi creator teaches EXI |
| [Fracture C++ Framework](https://github.com/Fracture17/ProjectMCodes/tree/master/notes/guides) | C++ injection setup |
| [Dan Salvato Playlist](https://www.youtube.com/watch?v=IOyQhK2OCs0&list=PL6GfYYW69Pa2L8ZuT5lGrJoC8wOWvbIQv) | Wii game modding intro |

---

## Tools

### Development

| Tool | Purpose | Link |
|------|---------|------|
| GCT RealMate | Gecko code syntax highlighting (VSCode) | [Marketplace](https://marketplace.visualstudio.com/items?itemName=fudgepops.gctrm-editor) |
| HxD | Hex editor for memory dumps | https://mh-nexus.de/en/hxd/ |
| SpeedCrunch | Programmer's calculator | https://speedcrunch.org/ |
| Ghidra | Reverse engineering / decompilation | https://ghidra-sre.org/ |
| Dolphin Memory Engine | RAM search during emulation | https://github.com/aldelaro5/Dolphin-memory-engine |
| CodeWrite | PPC ASM ↔ C2 code converter | https://github.com/TheGag96/CodeWrite/ |
| ASMWiird | Assembly to C2 Gecko conversion | (See Smashboards thread) |
| VSDSync | Virtual SD card update automation | (Discord link in wiki) |

### Build Tools

| Tool | Purpose |
|------|---------|
| kuribo-llvm | LLVM/Clang fork for PPC compilation |
| elf2rel | ELF to REL converter |
| GCTRealMate | GCT file generator from ASM |
| Syriinge | C++ code injection framework |

---

## Known Issues & TODOs

### Critical (Blocking Release)

1. **Savestate Desync** - `dolphin/Source/Core/Core/Brawlback/Savestate.cpp`
   - Captures too much memory (~21MB)
   - Wrong/missing regions cause desync
   - Need to identify minimal game state

### High Priority

2. **Stage Selection Hardcoded** - `Rollback_Hooks.cpp:81`
   ```cpp
   // TODO uncomment and use above line, just testing with battlefield
   ```

3. **Player Count Detection** - `Rollback_Hooks.cpp:109`
   ```cpp
   // TODO: replace this with some way to get the actual number of players
   ```

4. **Game Settings Initialization** - `Rollback_Hooks.cpp:747`
   ```cpp
   // TODO: make whole game struct be filled in from dolphin
   ```

### Medium Priority

5. **Pause Handling** - `Rollback_Hooks.cpp:242`
   ```cpp
   // TODO: fix pause by making sure sys data thingy checks button bits
   ```

6. **Input Conversion Optimization** - `Rollback_Hooks.cpp:308`
   ```cpp
   // TODO: do this once on match start
   ```

7. **GameReport Struct** - `BrawlbackUtility.h:43`
   ```cpp
   // TODO: put this in the submodule and pack it
   ```

8. **Doubles Floating Point** - `TimeSync.cpp`
   ```cpp
   // TODO: figure out a better solution here for doubles?
   ```

9. **Hash Function** - `SlippiUtility.h`
   ```cpp
   // TODO: This is probably a bad hash
   ```

10. **Matchmaking Fallback** - `Matchmaking.cpp`
    ```cpp
    // TODO: Instead of using one or the other, try both
    ```

### Replay System

11. **Input Leak** - Loading screen inputs cause replay desync
12. **Infinite Replays** - Can crash game, need max limit
13. **Maximum Replay Count** - Unknown, needs testing

### Known Limitations

- Music disabled (conflicts with rollback)
- Memory regions hardcoded for vanilla (not P+)
- Effects heap handling incomplete

---

## External Links

### Official Brawlback

- GitHub Organization: https://github.com/Brawlback-Team
- Twitter: https://x.com/brawlbackteam
- Patreon (Progress Reports): https://www.patreon.com/posts/brawlback-report-82248662

### Related Projects

- Slippi (Melee): https://slippi.gg/
- Project+ (Brawl Mod): https://projectplusgame.com/
- lylat.gg (Matchmaking): https://lylat.gg/

### Community

- Custom Brawl Modding Discord: https://discord.gg/GbxJhbv
- Slippi Discord: http://discord.gg/pPfEaW5
- SmashWiki Brawlback: https://www.ssbwiki.com/User:SenorMexicano/Brawlback

---

*Last Updated: January 2, 2026*
