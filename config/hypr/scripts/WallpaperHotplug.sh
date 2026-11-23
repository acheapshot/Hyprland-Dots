#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Re-apply wallpapers and theme after a monitor (re)connects.
# Called from the `monitor.added` hook in startup.lua.
#
# A monitor that re-handshakes after sleep or DPMS is a brand new output to
# the wallpaper daemon, which paints it black. Wake hooks run before it is
# back, so nothing else restores it.

SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
lock="${XDG_RUNTIME_DIR:-/tmp}/wallpaper-hotplug.lock"

# One run at a time; extra events inside the window collapse into it
exec 9>"$lock"
flock -n 9 || exit 0

# Let the output finish coming up and any sibling monitors reconnect
sleep 1.5
"$SCRIPTSDIR/WallpaperDaemon.sh"
