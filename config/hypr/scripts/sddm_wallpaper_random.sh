#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Randomize the SDDM login background before the greeter is shown.
#
# Invoked as root from /usr/share/sddm/scripts/Xsetup, which SDDM runs
# every time the login dialog is about to appear (boot, and again each
# time a session ends back to the greeter). There is no display server,
# no user session, and no sudo prompt available here, so this script must
# be self-contained and must never block or fail the login screen -
# every error path logs and exits 0.
#
# This only swaps the background image. It intentionally does not touch
# theme.conf colors (see sddm_wallpaper.sh for the interactive picker that
# also syncs wallust colors) - recomputing colors as root pre-login would
# add a slow, fragile step to every login.

set -u

TARGET_USER="acheapshot"
LOG_TAG="sddm_wallpaper_random"

log() {
    logger -t "$LOG_TAG" -- "$1" 2>/dev/null || true
}

USER_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6)"
if [[ -z "$USER_HOME" || ! -d "$USER_HOME" ]]; then
    log "could not resolve home directory for user '$TARGET_USER'"
    exit 0
fi

wallDIR="$USER_HOME/Pictures/wallpapers"
if [[ ! -d "$wallDIR" ]]; then
    log "wallpaper directory not found: $wallDIR"
    exit 0
fi

sddm_themes_dir="/usr/share/sddm/themes"
if [[ ! -d "$sddm_themes_dir" && -d "/run/current-system/sw/share/sddm/themes" ]]; then
    sddm_themes_dir="/run/current-system/sw/share/sddm/themes"
fi
sddm_simple="$sddm_themes_dir/simple_sddm_2"
if [[ ! -d "$sddm_simple/Backgrounds" ]]; then
    log "SDDM theme backgrounds not found: $sddm_simple/Backgrounds"
    exit 0
fi

# Images only: this runs as root with no display/session, so there is no
# reasonable way to extract a frame from a video wallpaper here.
mapfile -d '' WALLPAPERS < <(find -L "$wallDIR" -type f \( \
    -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o \
    -iname "*.bmp" -o -iname "*.tiff" -o -iname "*.webp" \
\) -print0 2>/dev/null)

if [[ ${#WALLPAPERS[@]} -eq 0 ]]; then
    log "no image wallpapers found in $wallDIR"
    exit 0
fi

random_wallpaper="${WALLPAPERS[$((RANDOM % ${#WALLPAPERS[@]}))]}"

if cp -f "$random_wallpaper" "$sddm_simple/Backgrounds/default" 2>/dev/null; then
    log "set SDDM background to $(basename "$random_wallpaper")"
else
    log "failed to copy '$random_wallpaper' to $sddm_simple/Backgrounds/default"
fi

exit 0
