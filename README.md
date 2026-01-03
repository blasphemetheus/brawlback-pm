# Brawlback Development Notes

Personal documentation and notes for contributing to the [Brawlback](https://github.com/Brawlback-Team) rollback netcode project for Super Smash Bros. Brawl.

## Contents

- **[GOALS.md](GOALS.md)** - Project goals and progress tracking
- **[IMPROVEMENTS.md](IMPROVEMENTS.md)** - Prioritized list of improvements
- **[KNOWLEDGE_BASE.md](KNOWLEDGE_BASE.md)** - Architecture docs, resources, and references
- **[LINUX_BUILD_GUIDE.md](LINUX_BUILD_GUIDE.md)** - Building Brawlback on Linux

## Repository Structure

```
brawlback/
├── GOALS.md              # Project goals tracker
├── IMPROVEMENTS.md       # Improvements roadmap
├── KNOWLEDGE_BASE.md     # Technical documentation
├── LINUX_BUILD_GUIDE.md  # Linux build instructions
└── repos/                # Cloned Brawlback repositories (gitignored)
    ├── brawlback-asm/
    ├── brawlback-common/
    ├── brawlback-launcher/
    ├── brawlback-wiki/
    ├── dolphin/
    ├── Project-Plus-Dolphin/
    └── vBrawlLauncherReleases/
```

## Quick Start

```bash
# Clone this repo
git clone https://github.com/YOUR_USERNAME/brawlback-notes.git
cd brawlback-notes

# Clone Brawlback repos
mkdir repos && cd repos
git clone --recursive https://github.com/Brawlback-Team/brawlback-asm.git
git clone --recursive https://github.com/Brawlback-Team/dolphin.git
git clone https://github.com/Brawlback-Team/brawlback-launcher.git
# ... etc

# See LINUX_BUILD_GUIDE.md for full build instructions
```

## Current Status

- **brawlback-asm**: Builds on Linux with case-sensitivity fixes
- **dolphin**: Builds with bundled fmt (system fmt v12+ incompatible)
- **launcher**: Node.js/Electron app (yarn install && yarn start)

## Key Issues

1. **Savestate system broken** - Main release blocker, causes desync
2. **Case sensitivity** - Windows-developed code needs fixes for Linux
3. **fmt library** - Needs bundled version, not system fmt v12+

See [IMPROVEMENTS.md](IMPROVEMENTS.md) for full details.

---

*This is a personal fork for development notes. Official Brawlback: https://github.com/Brawlback-Team*
