#!/bin/bash
# Brawlback Launcher Script
# Use X11 mode for graphics compatibility on Wayland

export QT_QPA_PLATFORM=xcb

/home/dori/brawlback/repos/dolphin/build/Binaries/dolphin-emu "$@"
