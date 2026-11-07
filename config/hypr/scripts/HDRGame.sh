#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Put a monitor in HDR only while a game is fullscreen on it.
#
# Wine/Proton on Wayland only offers HDR when the monitor is already in an HDR
# colour mode, and Hyprland only switches after a client asks for HDR, so a
# game's HDR option stays greyed out. This switches the monitor to cm=hdr as
# soon as a game window goes fullscreen on it and back to srgb afterwards.
# render.cm_auto_hdr still switches to HDR for mpv and other HDR clients.
#
# A game that reads the monitor mode only at start-up must be restarted once
# after the monitor is already in HDR.
#
# Usage: HDRGame.sh   (long-running, started from user_startup.lua)
# Env:   HDR_GAME_CLASS_REGEX  window classes treated as games

set -uo pipefail
# No `set -e`: the loop must survive a socket that goes away on restart.

CLASS_REGEX="${HDR_GAME_CLASS_REGEX:-^(steam_app_.*|.*\\.exe|gamescope)$}"
declare -A state # monitor name -> hdr|auto

# Print the names of monitors that have a fullscreen game on their active workspace
game_monitors() {
  hyprctl -j clients 2>/dev/null | jq -r --arg re "$CLASS_REGEX" '
    .[] | select(.fullscreen > 0 and .mapped and (.class | test($re)))
        | .workspace.id' |
    sort -u | while IFS= read -r ws; do
    hyprctl -j monitors 2>/dev/null | jq -r --argjson ws "$ws" \
      '.[] | select(.activeWorkspace.id == $ws) | .name'
  done
}

# Re-issue a monitor's current geometry with the requested colour mode
set_cm() {
  local name="$1" cm="$2" lua
  lua=$(hyprctl -j monitors | jq -r --arg n "$name" --arg cm "$cm" '
    .[] | select(.name == $n) |
    "hl.monitor({output=\"\(.name)\", mode=\"\(.width)x\(.height)@\(.refreshRate * 100 | round / 100)\", position=\"\(.x)x\(.y)\", scale=\"\(.scale)\", transform=\(.transform), bitdepth=\(if (.currentFormat | test("2101010")) then 10 else 8 end), cm=\"\($cm)\"})"')
  [ -n "$lua" ] && hyprctl eval "$lua" >/dev/null
}

reconcile() {
  local want name
  want=$(game_monitors)
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    if [ "${state[$name]:-auto}" != hdr ]; then
      set_cm "$name" hdr && state[$name]=hdr
    fi
  done <<<"$want"
  for name in "${!state[@]}"; do
    if [ "${state[$name]}" = hdr ] && ! grep -qxF "$name" <<<"$want"; then
      set_cm "$name" srgb && state[$name]=auto
    fi
  done
}

# A monitor already in HDR when we start (a previous run, a manual switch) is
# ours to revert once no game is fullscreen on it.
while IFS= read -r name; do
  [ -n "$name" ] && state[$name]=hdr
done < <(hyprctl -j monitors 2>/dev/null | jq -r '.[] | select(.colorManagementPreset == "hdr") | .name')

while :; do
  sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-}/.socket2.sock"
  if [ -S "$sock" ]; then
    reconcile
    # Process substitution keeps the loop in this shell so `state` persists
    while IFS= read -r line; do
      case "$line" in
      fullscreen\>\>* | closewindow\>\>* | openwindow\>\>* | workspacev2\>\>* | movewindowv2\>\>* | focusedmonv2\>\>*)
        reconcile
        ;;
      esac
    done < <(socat -u "UNIX-CONNECT:$sock" - 2>/dev/null)
  fi
  sleep 2
done
