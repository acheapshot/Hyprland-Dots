#!/usr/bin/env bash
# ==================================================
#  Personal customization (not upstream KoolDots)
# ==================================================
# Assigns a random wallpaper to EACH connected monitor on login, instead of
# WallpaperDaemon.sh's default behavior of restoring the previous session's
# wallpaper per monitor. Wired into Startup_Apps.conf in place of
# WallpaperDaemon.sh; see the comment there for why.
#
# - Wallpapers are drawn without repeats across monitors as long as there
#   are at least as many wallpapers as monitors; once the pool runs out it
#   reshuffles, so extra monitors may then repeat an already-used image.
# - Wallust re-theming (terminal/waybar colors) is driven by
#   $WALLPAPER_THEME_MONITOR (default: DP-3), falling back to the focused
#   monitor, then the first monitor, if that one isn't connected.
# - Persists the same per-monitor cache files WallpaperDaemon.sh /
#   WallpaperSelect.sh / RofiFocusedWallpaperLink.sh read, so the rofi
#   wallpaper picker, wallpaper effects, and future restores stay in sync.

SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
# shellcheck source=/dev/null
. "$SCRIPTSDIR/WallpaperCmd.sh"

PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
wallDIR="$PICTURES_DIR/wallpapers"

wallpaper_current="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallpaper_effects/.wallpaper_current"
wallpaper_link="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/rofi/.current_wallpaper"
wallpaper_base="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallpaper_effects/.wallpaper_base"

THEME_MONITOR="${WALLPAPER_THEME_MONITOR:-DP-3}"

get_monitors() {
  if command -v jq >/dev/null 2>&1; then
    hyprctl monitors -j | jq -r '.[].name'
  else
    hyprctl monitors | awk '/^Monitor/{print $2}'
  fi
}

wait_for_monitors() {
  local monitors=""
  for _ in {1..120}; do
    monitors="$(get_monitors 2>/dev/null | awk 'NF')"
    if [ -n "$monitors" ]; then
      printf '%s\n' "$monitors"
      return 0
    fi
    sleep 0.1
  done
  return 1
}

mapfile -t MONITORS < <(wait_for_monitors || true)
if [ "${#MONITORS[@]}" -eq 0 ]; then
  exit 0
fi

mapfile -d '' PICS < <(find -L "$wallDIR" -type f \( \
  -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.bmp" -o \
  -iname "*.gif" -o -iname "*.webp" -o -iname "*.tiff" -o \
  -iname "*.farbfeld" -o -iname "*.tga" -o -iname "*.pnm" \
  \) -print0 2>/dev/null)

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

# Transition config (swww/awww) - matches WallpaperRandom.sh
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

  per_monitor_wallpaper_current="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallpaper_effects/.wallpaper_current_${monitor}"
  per_monitor_wallpaper_link="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/rofi/.current_wallpaper_${monitor}"
  per_monitor_wallpaper_base="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallpaper_effects/.wallpaper_base_${monitor}"

  resize_mode="$(wallpaper_resize_mode "$pic" "$monitor")"
  if ! "$WWW_CMD" img -o "$monitor" --resize "$resize_mode" "$pic" "${SWWW_PARAMS[@]}" >/dev/null 2>&1; then
    sleep 0.3
    "$WWW_CMD" img -o "$monitor" --resize "$resize_mode" "$pic" "${SWWW_PARAMS[@]}" >/dev/null 2>&1 &
  fi

  mkdir -p "$(dirname "$per_monitor_wallpaper_current")" "$(dirname "$per_monitor_wallpaper_link")"
  ln -sf "$pic" "$per_monitor_wallpaper_link" || true
  cp -f "$pic" "$per_monitor_wallpaper_current" || true
  cp -f "$pic" "$per_monitor_wallpaper_base" || true

  if [ "$monitor" = "$THEME_MONITOR" ]; then
    theme_wallpaper="$pic"
  fi
done

# Preferred theme monitor not connected this session: fall back to the
# focused monitor, then whichever monitor was processed first.
if [ -z "$theme_wallpaper" ]; then
  focused_monitor="$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name' 2>/dev/null)"
  theme_wallpaper="${ASSIGNED[$focused_monitor]:-${ASSIGNED[${MONITORS[0]}]}}"
fi

if [ -n "$theme_wallpaper" ]; then
  mkdir -p "$(dirname "$wallpaper_current")" "$(dirname "$wallpaper_link")" "$(dirname "$wallpaper_base")"
  ln -sf "$theme_wallpaper" "$wallpaper_link" || true
  cp -f "$theme_wallpaper" "$wallpaper_current" || true
  cp -f "$theme_wallpaper" "$wallpaper_base" || true
fi

"$SCRIPTSDIR/RofiFocusedWallpaperLink.sh" >/dev/null 2>&1 || true

if [ -n "$theme_wallpaper" ] && [ -x "$SCRIPTSDIR/WallustSwww.sh" ]; then
  "$SCRIPTSDIR/WallustSwww.sh" "$theme_wallpaper" >/dev/null 2>&1 || true
fi
