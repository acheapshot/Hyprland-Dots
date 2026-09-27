#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Script for Random Wallpaper ( CTRL ALT W)
#
# Personal customization: randomizes EVERY connected monitor (not just the
# focused one), drawing without repeats across monitors as long as the
# wallpaper pool is at least as large as the monitor count. Wallust
# re-theming is driven by $WALLPAPER_THEME_MONITOR (default: DP-3),
# falling back to the focused monitor, then the first monitor, if that one
# isn't connected. Same scheme as WallpaperRandomLogin.sh (used on login).

PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
wallDIR="$PICTURES_DIR/wallpapers"
SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
# shellcheck source=/dev/null
. "$SCRIPTSDIR/WallpaperCmd.sh"

THEME_MONITOR="${WALLPAPER_THEME_MONITOR:-DP-3}"

get_monitors() {
  if command -v jq >/dev/null 2>&1; then
    hyprctl monitors -j | jq -r '.[].name'
  else
    hyprctl monitors | awk '/^Monitor/{print $2}'
  fi
}

mapfile -t MONITORS < <(get_monitors | awk 'NF')
if [ "${#MONITORS[@]}" -eq 0 ]; then
  notify-send -u critical "Wallpaper" "No monitors detected"
  exit 1
fi

mapfile -d '' PICS < <(find -L "${wallDIR}" -type f \( \
  -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.pnm" -o \
  -iname "*.tga" -o -iname "*.tiff" -o -iname "*.webp" -o -iname "*.bmp" -o \
  -iname "*.farbfeld" -o -iname "*.gif" \) -print0)

if [ "${#PICS[@]}" -eq 0 ]; then
  notify-send -u critical "Wallpaper" "No wallpapers found in $wallDIR"
  exit 1
fi

# Fisher-Yates shuffle of PICS in place.
shuffle_pics() {
  local n="${#PICS[@]}" i j tmp
  for ((i = n - 1; i > 0; i--)); do
    j=$((RANDOM % (i + 1)))
    tmp="${PICS[i]}"
    PICS[i]="${PICS[j]}"
    PICS[j]="$tmp"
  done
}

# Transition config (swww/awww)
FPS=30
TYPE="random"
DURATION=1
BEZIER=".43,1.19,1,.4"
if [[ "$WWW_CMD" == "swww" || "$WWW_CMD" == "awww" ]]; then
  SWWW_PARAMS=(--transition-fps "$FPS" --transition-type "$TYPE" --transition-duration "$DURATION" --transition-bezier "$BEZIER")
else
  SWWW_PARAMS=()
fi

wallpaper_ensure_daemon
shuffle_pics

declare -A ASSIGNED
pool_idx=0
theme_wallpaper=""

for monitor in "${MONITORS[@]}"; do
  [ -n "$monitor" ] || continue

  if [ "$pool_idx" -ge "${#PICS[@]}" ]; then
    shuffle_pics
    pool_idx=0
  fi
  pic="${PICS[$pool_idx]}"
  pool_idx=$((pool_idx + 1))
  ASSIGNED["$monitor"]="$pic"

  wallpaper_base="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallpaper_effects/.wallpaper_base_${monitor}"
  resize_mode="$(wallpaper_resize_mode "$pic" "$monitor")"
  "$WWW_CMD" img -o "$monitor" --resize "$resize_mode" "$pic" "${SWWW_PARAMS[@]}"

  mkdir -p "$(dirname "$wallpaper_base")"
  cp -f "$pic" "$wallpaper_base" || true

  if [ "$monitor" = "$THEME_MONITOR" ]; then
    theme_wallpaper="$pic"
  fi
done

# Preferred theme monitor not connected this session: fall back to the
# focused monitor, then whichever monitor was processed first.
if [ -z "$theme_wallpaper" ]; then
  focused_monitor="$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')"
  theme_wallpaper="${ASSIGNED[$focused_monitor]:-${ASSIGNED[${MONITORS[0]}]}}"
fi

if ! "$SCRIPTSDIR/WallustSwww.sh" "$theme_wallpaper"; then
  notify-send -u critical "Wallust failed" "Wallpaper theme not refreshed"
  exit 1
fi

sleep 0.5
"$SCRIPTSDIR/Refresh.sh"
