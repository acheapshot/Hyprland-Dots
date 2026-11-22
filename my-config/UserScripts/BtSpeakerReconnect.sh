#!/usr/bin/env bash
# Fixes a Bluetooth speaker from the PC side when its own power-on
# reconnect collides with BlueZ's stream setup and leaves the A2DP transport
# unusable (bluetoothd "No pending request", then Acquire -> NotAuthorized).
# Runs as the bt-speaker-reconnect.service user unit.

MAC="${1:-28:11:A5:BE:0B:8D}"
DEV="dev_${MAC//:/_}"
COOLDOWN=20

connected() {
  bluetoothctl info "$MAC" 2>/dev/null | grep -q '^\s*Connected: yes'
}

A2DP_SINK="0000110b-0000-1000-8000-00805f9b34fb"
ESCALATE_WINDOW=60

busctl_dev() {
  busctl --system call org.bluez "/org/bluez/hci0/$DEV" org.bluez.Device1 "$@" >/dev/null 2>&1
}

# Resets only the A2DP profile. The ACL link stays up, so the speaker
# should announce fewer connect/disconnect events than a full reconnect.
reset_profile() {
  echo "audio link failed for $MAC, resetting A2DP profile"
  [[ -n "$DRY_RUN" ]] && return
  sleep 2
  busctl_dev DisconnectProfile s "$A2DP_SINK"
  sleep 2
  if busctl_dev ConnectProfile s "$A2DP_SINK"; then
    echo "A2DP profile reset for $MAC"
  else
    echo "A2DP profile reset of $MAC failed"
  fi
}

full_reconnect() {
  echo "audio link still failing for $MAC, reconnecting from PC side"
  [[ -n "$DRY_RUN" ]] && return
  sleep 2
  bluetoothctl disconnect "$MAC" >/dev/null
  sleep 3
  if bluetoothctl connect "$MAC" >/dev/null; then
    echo "reconnected $MAC"
  else
    echo "reconnect of $MAC failed"
  fi
}

last=0
last_fix=0
journalctl -f -n0 -o cat -t bluetoothd -t wireplumber | while IFS= read -r line; do
  case "$line" in
    *"session_cb() No pending request"* | *"$DEV"*"NotAuthorized"*) ;;
    *) continue ;;
  esac
  now=$(date +%s)
  ((now - last < COOLDOWN)) && continue
  connected || continue
  if ((now - last_fix < ESCALATE_WINDOW)); then
    full_reconnect
  else
    reset_profile
  fi
  last=$(date +%s)
  last_fix=$last
done
