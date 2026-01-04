#!/bin/bash
export QT_QPA_PLATFORM=xcb
timeout 20 /home/dori/brawlback/repos/dolphin/build/Binaries/dolphin-emu -e /home/dori/Downloads/SSBB_NTSC.iso 2>&1
