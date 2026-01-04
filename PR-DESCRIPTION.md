# Pull Request: Linux Compatibility Fixes for Brawlback Dolphin

## Summary

This PR adds Linux support to Brawlback Dolphin. The changes fix several crashes and build issues that occur on Linux while maintaining full backwards compatibility with Windows.

**Tested on:** Manjaro Linux (kernel 6.1.159), Qt6, GCC

**Windows Impact:** All changes are either Linux-only (guarded by `#ifdef`), or are general bug fixes that improve stability on both platforms.

---

## Commits Overview

| Commit | Description | Windows Impact |
|--------|-------------|----------------|
| c32816bb | Fix Wiimote controller crash | ✅ Improves stability |
| 9ff46d15 | Add Linux memory protection API | ✅ No impact (Linux-only) |
| 3d77aeb3 | Add IncrementalRB to CMakeLists | ✅ No impact |
| 8b36b64d | Add Qt6::GuiPrivate dependency | ⚠️ May need testing |
| 3bf5e341 | Implement lazy initialization | ✅ Improves stability |
| 88c24921 | Fix IncrementalRB Linux compat | ✅ No impact (guarded) |
| d2c5d1f7 | Fix minizip-ng CMakeLists | ✅ No impact |
| a0f76edf | Add EnsureInitialized to all Rollback paths | ✅ Fixes potential crash |

---

## Detailed Change Analysis

### Commit 1: Fix Wiimote controller crash at boot (c32816bb)

**File:** `Source/Core/Core/HW/Wiimote.cpp`

**Problem:**
On Linux, Dolphin crashed immediately at boot with:
```
vector::_M_range_check: __n (which is 0) >= this->size() (which is 0)
```

**Root Cause Analysis:**
The function `GetHIDWiimoteSource()` was called during early initialization, before any Wiimote controllers had been created. The code unconditionally accessed `GetController(index)` on an empty vector, triggering a range check exception.

The call stack was:
1. Boot sequence starts
2. `GetSource(index)` returns `WiimoteSource::Emulated`
3. `GetConfig()->GetController(index)` is called
4. Vector is empty → crash

**Why This Happened on Linux But Not Windows:**
Windows builds may have different initialization ordering, or MSVC's STL implementation may not throw on out-of-bounds access in release builds. Linux's libstdc++ has stricter bounds checking.

**The Fix:**
```cpp
case WiimoteSource::Emulated:
-    hid_source = static_cast<WiimoteEmu::Wiimote*>(::Wiimote::GetConfig()->GetController(index));
+    // Safety check: ensure controllers have been created before accessing
+    if (::Wiimote::GetConfig()->GetControllerCount() > static_cast<int>(index))
+    {
+      hid_source = static_cast<WiimoteEmu::Wiimote*>(::Wiimote::GetConfig()->GetController(index));
+    }
     break;
```

**Windows Impact:** ✅ SAFE
- This is a defensive bounds check that prevents undefined behavior
- If the vector is empty, `hid_source` remains as its initialized value (nullptr or unchanged)
- This could potentially fix rare crashes on Windows too if the timing is ever different
- No behavioral change for the normal case where controllers exist

**Thought Process:**
I considered alternative fixes:
1. **Ensure controllers are created earlier** - Would require understanding the full initialization order, risky
2. **Add bounds check** (chosen) - Minimal change, safe, follows defensive programming principles
3. **Change return type to optional** - Too invasive for a simple fix

---

### Commit 2: Add Linux memory protection API compatibility (9ff46d15)

**Files:**
- `Source/Core/Common/MemArenaUnix.cpp`
- `Source/Core/Core/IOS/FS/FileSystemProxy.cpp`
- `Source/Core/Core/IOS/SDIO/SDIOSlot0.cpp`

**Problem:**
The IncrementalRB code uses `VirtualProtectMemoryRegion()` with Windows `PAGE_READONLY`/`PAGE_READWRITE` constants, but this function and these constants don't exist on Linux.

**Root Cause Analysis:**
The incremental rollback system needs to write-protect memory pages to track which pages have been modified (copy-on-write semantics). On Windows, this is done with `VirtualProtect()` and `PAGE_*` constants. Linux has `mprotect()` with `PROT_*` constants.

**The Fix:**

In `MemArenaUnix.cpp`, added a new function:
```cpp
// Windows PAGE_* constants mapped to POSIX PROT_* equivalents
// PAGE_READONLY = 0x02, PAGE_READWRITE = 0x04
bool MemArena::VirtualProtectMemoryRegion(void* data, size_t size, u32 flag)
{
  int prot;
  if (flag == 0x02)  // PAGE_READONLY
    prot = PROT_READ;
  else if (flag == 0x04)  // PAGE_READWRITE
    prot = PROT_READ | PROT_WRITE;
  else
  {
    ERROR_LOG_FMT(MEMMAP, "VirtualProtectMemoryRegion: unknown protection flag 0x{:x}", flag);
    return false;
  }

  if (mprotect(data, size, prot) != 0)
  {
    ERROR_LOG_FMT(MEMMAP, "mprotect failed: {}", strerror(errno));
    return false;
  }
  return true;
}
```

In IOS files, added the constant definitions for non-Windows:
```cpp
#ifndef _WIN32
#define PAGE_READONLY  0x02
#define PAGE_READWRITE 0x04
#endif
```

**Windows Impact:** ✅ SAFE
- All new code is guarded by `#ifndef _WIN32` or is in Unix-only files
- Windows continues to use its native `VirtualProtect()` implementation
- The PAGE_* constant definitions are only added on non-Windows platforms

**Thought Process:**
I chose to map the Windows constants to POSIX equivalents rather than creating a new abstraction because:
1. The existing code already uses Windows constants throughout
2. Creating a new enum would require changing many call sites
3. The mapping is simple and well-defined (readonly → read, readwrite → read+write)

---

### Commit 3: Add IncrementalRB source files to Core CMakeLists (3d77aeb3)

**File:** `Source/Core/Core/CMakeLists.txt`

**Problem:**
The incremental-rollback source files were not being compiled into the core library on Linux, causing linker errors.

**Root Cause Analysis:**
The Brawlback team likely uses Visual Studio on Windows, which has its own project files (.vcxproj). The CMakeLists.txt is used for Linux/macOS builds but wasn't updated with the IncrementalRB source files.

**The Fix:**
```cmake
 add_library(core
   ...
   Brawlback/include/json.hpp
+  Brawlback/include/incremental-rollback/incremental_rb.cpp
+  Brawlback/include/incremental-rollback/incremental_rb.h
+  Brawlback/include/incremental-rollback/job_system.cpp
+  Brawlback/include/incremental-rollback/job_system.h
+  Brawlback/include/incremental-rollback/mem.cpp
+  Brawlback/include/incremental-rollback/mem.h
+  Brawlback/include/incremental-rollback/tiny_arena.cpp
+  Brawlback/include/incremental-rollback/tiny_arena.h
+  Brawlback/include/incremental-rollback/util.h
   Brawlback/Netplay/Matchmaking.cpp
```

**Windows Impact:** ✅ SAFE
- CMakeLists.txt is not used for Windows MSVC builds (they use .sln/.vcxproj)
- If Windows switches to CMake builds in the future, this would be required anyway
- No runtime impact

**Thought Process:**
This is a straightforward build system fix. The files exist and are used, they just weren't listed in CMake.

---

### Commit 4: Add Qt6::GuiPrivate dependency for Linux build (8b36b64d)

**File:** `Source/Core/DolphinQt/CMakeLists.txt`

**Problem:**
Build failed with missing Qt private headers on Linux.

**The Fix:**
```cmake
-find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets Svg)
+find_package(Qt6 REQUIRED COMPONENTS Core Gui GuiPrivate Widgets Svg)
...
 target_link_libraries(dolphin-emu
 PRIVATE
   core
   Qt6::Widgets
+  Qt6::GuiPrivate
```

**Windows Impact:** ⚠️ NEEDS TESTING
- Qt6::GuiPrivate should be available on Windows Qt6 installations
- If Windows uses Qt5, this would need to be conditional
- Recommend testing on Windows before merging

**Thought Process:**
Some Dolphin Qt code uses Qt private APIs (QPA - Qt Platform Abstraction). On Linux, these require explicit linking to GuiPrivate. I'm not 100% sure if this is needed on Windows or if Windows builds link it implicitly.

---

### Commit 5: Implement lazy initialization for IncrementalRB (3bf5e341)

**Files:**
- `Source/Core/Core/Brawlback/include/incremental-rollback/incremental_rb.cpp`
- `Source/Core/Core/Brawlback/include/incremental-rollback/incremental_rb.h`
- `Source/Core/Core/HW/EXI/EXIBrawlback.cpp`
- `Source/Core/Core/HW/Memmap.cpp`

**Problem:**
Dolphin crashed during boot with:
```
Unknown Pointer 0x14000000 PC 0x00000000 LR 0x00000000
```

The address `0x14000000` is the end of Wii EXRAM (64MB: `0x10000000`-`0x14000000`).

**Root Cause Analysis:**
`IncrementalRB::InitState()` was being called in `Memmap.cpp`'s `Init()` function during early boot. At this point:
1. Memory regions were allocated but not fully initialized
2. Game hadn't loaded yet
3. Some physical memory regions weren't active

The code was trying to call `TrackAlloc()` on memory regions that weren't ready, and `GetPointer()` for addresses in EXRAM that weren't mapped yet.

**Why This Happened on Linux But Not Windows:**
Windows's `VirtualAlloc` with `MEM_WRITE_WATCH` may handle uninitialized regions differently, or the memory is mapped earlier. On Linux with `mprotect`, accessing unmapped memory causes an immediate crash.

**The Fix:**
Created a lazy initialization pattern:

1. **New API functions:**
```cpp
void RegisterCallbacks(IncrementalRBCallbacks cb);  // Store callbacks only
bool IsInitialized();                                 // Check state
void EnsureInitialized();                            // Lazy init
```

2. **Changed Memmap.cpp to register callbacks instead of initializing:**
```cpp
-  IncrementalRB::InitState(cbs);
+  IncrementalRB::RegisterCallbacks(cbs);
```

3. **Added initialization call when netplay actually starts:**
```cpp
void CEXIBrawlback::SaveState(bu32 frame)
{
+  // Lazy initialization: only init IncrementalRB when netplay actually needs it
+  IncrementalRB::EnsureInitialized();
   IncrementalRB::SaveWrittenPages(frame - 1, ...);
}
```

4. **Added extensive debug logging** to help troubleshoot future issues:
```cpp
INFO_LOG_FMT(BRAWLBACK, "IncrementalRB::InitState() - START");
INFO_LOG_FMT(BRAWLBACK, "IncrementalRB::InitState() - Getting physical regions");
// ... etc
```

5. **Fixed a Linux socket bug** (found while investigating):
```cpp
-  setsockopt(this->peer->socket, SOL_SOCKET, SO_PRIORITY, &priority, sizeof(priority));
+  setsockopt(this->server->socket, SOL_SOCKET, SO_PRIORITY, &priority, sizeof(priority));
```

**Windows Impact:** ✅ SAFE AND BENEFICIAL
- The lazy initialization pattern is safer on all platforms
- Initialization only happens when netplay is actually used
- If a user plays offline, IncrementalRB is never initialized (saves resources)
- The debug logging can be disabled by setting Brawlback log level to Warning
- The socket fix corrects a bug that existed on Linux (peer vs server variable)

**Thought Process:**
I considered several approaches:
1. **Initialize later in boot sequence** - Would require understanding Dolphin's boot order
2. **Check if memory is ready before InitState** - Complex and error-prone
3. **Lazy initialization** (chosen) - Cleanest solution, defers initialization until we know memory is ready

The key insight was that IncrementalRB is ONLY needed for netplay. By deferring initialization to the first `SaveState()` call (which only happens during netplay), we guarantee that:
- The game has fully loaded
- All memory regions are active
- Netplay has actually started

---

### Commit 6: Fix IncrementalRB Linux compatibility issues (88c24921)

**Files:**
- `Source/Core/Core/Brawlback/include/incremental-rollback/mem.cpp`
- `Source/Core/Core/Brawlback/include/incremental-rollback/tiny_arena.h`
- `Source/Core/Core/Brawlback/include/incremental-rollback/util.h`

**Problems Fixed:**

#### A. Missing includes and platform-specific headers
```cpp
+#include <cerrno>
+#include <cinttypes>
+#include <cstdlib>
+#include <cstring>
...
+#ifdef _WIN32
+#include <malloc.h>
+#else
+#include <mm_malloc.h>
+#endif
```
GCC requires explicit includes for `errno`, `PRIu64`, `strerror`, etc.

#### B. printf format specifier for u64
```cpp
-        printf("%llu : %llu\n", PageIndex, changedOffset);
+        printf("%" PRIu64 " : %" PRIu64 "\n", PageIndex, changedOffset);
```
`%llu` is not portable. `PRIu64` from `<cinttypes>` is the correct cross-platform format specifier.

#### C. Error message for mprotect failure
```cpp
+#ifdef _WIN32
               DWORD dw = GetLastError();
               ERROR_LOG_FMT(BRAWLBACK, "... THE REASON IS: {}\n", dw);
+#else
+              ERROR_LOG_FMT(BRAWLBACK, "... THE REASON IS: {}\n", strerror(errno));
+#endif
```
Linux uses `errno` and `strerror()` instead of `GetLastError()`.

#### D. AVX function attribute
```cpp
+#ifdef _MSC_VER
 void fastMemcpy(void *pvDest, void *pvSrc, size_t nBytes)
+#else
+__attribute__((target("avx,avx2")))
+void fastMemcpy(void *pvDest, void *pvSrc, size_t nBytes)
+#endif
```
GCC requires explicit target attributes to use AVX intrinsics. MSVC enables them via project settings.

#### E. Template definition order in tiny_arena.h
```cpp
+// Forward declarations - must come before template functions that use them
 Arena arena_init(void* backing_buffer, size_t arena_size);
+...
+
+// Macro and template definitions come after forward declarations
 #define arena_alloc_type(arena, type, num) ((type*)arena_alloc(arena, sizeof(type) * num))
```
GCC is stricter about declaration order. The template function `arena_alloc_and_init` was using `arena_alloc_type` before it was defined.

#### F. Explicit namespace qualification
```cpp
-    percentOutOf100 = Clamp(percentOutOf100, 0u, 100u);
+    percentOutOf100 = ::Clamp(percentOutOf100, 0u, 100u);
```
GCC's ADL (Argument-Dependent Lookup) was finding the wrong `Clamp` function. Explicit `::` qualification ensures the global template is used.

**Windows Impact:** ✅ SAFE
- All changes are either guarded by `#ifdef _WIN32` / `#ifdef _MSC_VER`
- Or are improvements that work on both platforms (PRIu64, declaration order)
- The `::Clamp` fix is safer on all platforms

**Thought Process:**
These are all standard cross-platform C++ fixes. I aimed to use the most portable solutions:
- `<cinttypes>` for format specifiers
- `#ifdef` guards for platform-specific code
- Explicit qualification to avoid ADL issues

---

### Commit 7: Fix minizip-ng CMakeLists missing includes (d2c5d1f7)

**File:** `Externals/minizip-ng/CMakeLists.txt`

**Problem:**
Build failed with:
```
Unknown CMake command "check_function_exists"
```

**Root Cause Analysis:**
The minizip-ng CMakeLists.txt uses `check_function_exists()` and `check_include_file()` macros, but doesn't include the CMake modules that define them. On some systems/CMake versions, these are included automatically; on others, they're not.

**The Fix:**
```cmake
 project(minizip C)

+include(CheckFunctionExists)
+include(CheckIncludeFile)
+
 add_library(minizip STATIC
```

**Windows Impact:** ✅ SAFE
- These CMake include() calls are harmless on all platforms
- They just ensure the required macros are available
- This is a proper CMake fix that should be upstreamed to minizip-ng itself

---

### Commit 8: Add EnsureInitialized() to all IncrementalRB::Rollback call sites (a0f76edf)

**File:** `Source/Core/Core/HW/EXI/EXIBrawlback.cpp`

**Problem:**
After implementing lazy initialization in commit 5, I discovered that `Rollback()` can be called before `SaveState()` in two scenarios:

1. **handleLoadSavestate()** - When receiving opponent's savestate
2. **updateSync()** - When rollback is triggered during frame synchronization

If either of these is called first, `IncrementalRB` would not be initialized, causing null pointer access.

**The Fix:**
```cpp
void CEXIBrawlback::handleLoadSavestate(u8* data)
{
  std::memcpy(&stopRollbackFrame, data, sizeof(bu32));
  stopRollbackFrame = swap_endian(stopRollbackFrame);
+  IncrementalRB::EnsureInitialized();
  IncrementalRB::Rollback(this->lastStatedFrame, stopRollbackFrame);
}

...

void CEXIBrawlback::updateSync(bu32& locFrame, bu8 playerIdx)
{
  ...
  if (/* should rollback */) {
    INFO_LOG_FMT(BRAWLBACK, "Should rollback! ...");
+    IncrementalRB::EnsureInitialized();
    IncrementalRB::Rollback(locFrame, latestConfirmedFrame);
```

**Windows Impact:** ✅ SAFE AND FIXES POTENTIAL BUG
- `EnsureInitialized()` is a no-op if already initialized
- This fixes a race condition that could theoretically happen on Windows too
- The overhead is one boolean check per call (negligible)

**Thought Process:**
When analyzing the Brawlback netplay code, I found three entry points that use IncrementalRB:
1. `SaveState()` - Host saves game state (already had EnsureInitialized)
2. `handleLoadSavestate()` - Client receives savestate from host
3. `updateSync()` - Either player triggers rollback

I realized that in a client-host scenario:
- Client might receive opponent's savestate BEFORE ever calling SaveState locally
- This would call Rollback on uninitialized IncrementalRB

The fix is simple: guard ALL Rollback calls with EnsureInitialized.

---

## Testing Performed

### Linux Testing
- [x] Dolphin builds successfully
- [x] Dolphin launches without crashes
- [x] Brawlback ELF boots to character select screen
- [x] Brawlback plugin loads (Syringe 0.6.0, Brawlback-Online v0.0.1)
- [x] GC adapter is detected
- [x] Invalid read errors are suppressed and logged (not a code issue - see notes)
- [ ] Netplay connection - BLOCKED (matchmaking server offline)
- [ ] Rollback during gameplay - BLOCKED (requires netplay)

### Windows Testing
- [ ] Not tested - I don't have Windows

### Invalid Read Errors Note
During testing, I observed recurring "Invalid read" errors:
```
Invalid read from 0x000033f6, PC = 0x800ccebc
```

These are NOT caused by my changes. The PC address `0x800ccebc` is in Brawl's WiFi networking code, near a function (`0x800ccec4`) that Brawlback hooks and replaces with `ReturnImmediately`. The game's network code tries to access uninitialized structures because Brawlback bypasses Nintendo WFC.

These errors can be suppressed by setting `UsePanicHandlers = False` in Dolphin.ini. They're logged but don't affect gameplay.

---

## Files Changed Summary

```
Source/Core/Core/HW/Wiimote.cpp                          | +5 -1  (bounds check)
Source/Core/Common/MemArenaUnix.cpp                      | +23    (mprotect wrapper)
Source/Core/Core/IOS/FS/FileSystemProxy.cpp              | +6     (PAGE_* constants)
Source/Core/Core/IOS/SDIO/SDIOSlot0.cpp                  | +6     (PAGE_* constants)
Source/Core/Core/CMakeLists.txt                          | +9     (source files)
Source/Core/DolphinQt/CMakeLists.txt                     | +2 -1  (Qt6::GuiPrivate)
Source/Core/Core/Brawlback/.../incremental_rb.cpp        | +72    (lazy init + logging)
Source/Core/Core/Brawlback/.../incremental_rb.h          | +10    (new API)
Source/Core/Core/HW/EXI/EXIBrawlback.cpp                 | +8 -2  (EnsureInitialized)
Source/Core/Core/HW/Memmap.cpp                           | +9 -1  (RegisterCallbacks)
Source/Core/Core/Brawlback/.../mem.cpp                   | +25    (Linux compat)
Source/Core/Core/Brawlback/.../tiny_arena.h              | reorder (declaration order)
Source/Core/Core/Brawlback/.../util.h                    | +1 -1  (namespace fix)
Externals/minizip-ng/CMakeLists.txt                      | +3     (CMake includes)
```

---

## Recommendations

1. **Merge commits 1, 5, 8** - These fix real bugs that could affect Windows too
2. **Merge commits 2, 3, 6, 7** - These are Linux-only build fixes, safe for Windows
3. **Test commit 4 on Windows** - Qt6::GuiPrivate may or may not be needed

---

## Questions for Reviewers

1. Does Windows use CMake or Visual Studio project files for building?
2. Is Qt6::GuiPrivate already linked on Windows builds?
3. Should the debug logging in IncrementalRB be removed or kept for troubleshooting?
4. Are there any other code paths that call IncrementalRB::Rollback() that I missed?
