#!/usr/bin/env bash
# Waybar custom module: Claude.ai Pro/Max session + weekly usage
#
# Uses the unofficial claude.ai/api/organizations/{orgId}/usage endpoint.
# Not an official Anthropic API — it's what claude.ai's own Settings > Usage
# page calls, authenticated with your sessionKey cookie. It can break at any
# time if Anthropic changes their frontend internals.
#
# SETUP:
#   1. Log into https://claude.ai in your browser.
#   2. Open DevTools (F12) -> Application tab -> Storage -> Cookies -> https://claude.ai
#   3. Copy the value of "sessionKey" (starts with sk-ant-sid01...)
#   4. Save it to ~/.config/claude-usage/session_key with mode 600:
#        mkdir -p ~/.config/claude-usage
#        echo -n 'sk-ant-sid01-XXXXXXXX' > ~/.config/claude-usage/session_key
#        chmod 600 ~/.config/claude-usage/session_key
#   5. This cookie expires roughly every 30 days — when the widget starts
#      showing an error icon, just repeat steps 2-4.

set -euo pipefail

CONF_DIR="$HOME/.config/claude-usage"
SESSION_KEY_FILE="$CONF_DIR/session_key"
ORG_ID_FILE="$CONF_DIR/org_id"
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"

fail_widget() {
  local msg="$1"
  printf '{"text":"  err","tooltip":"%s","class":"error"}\n' "$msg"
  exit 0
}

[[ -f "$SESSION_KEY_FILE" ]] || fail_widget "No session_key file at $SESSION_KEY_FILE"
SESSION_KEY="$(<"$SESSION_KEY_FILE")"
[[ -n "$SESSION_KEY" ]] || fail_widget "session_key file is empty"

COOKIE_HEADER="sessionKey=${SESSION_KEY}"

# Resolve + cache org id
if [[ -f "$ORG_ID_FILE" ]]; then
  ORG_ID="$(<"$ORG_ID_FILE")"
else
  ORG_JSON="$(curl -s -H "Cookie: ${COOKIE_HEADER}" -H "User-Agent: ${UA}" \
    "https://claude.ai/api/organizations" || true)"
  ORG_ID="$(echo "$ORG_JSON" | jq -r '.[0].uuid // empty' 2>/dev/null || true)"
  [[ -n "$ORG_ID" ]] || fail_widget "Could not resolve org id (bad/expired session_key?)"
  echo -n "$ORG_ID" > "$ORG_ID_FILE"
fi

USAGE_JSON="$(curl -s -H "Cookie: ${COOKIE_HEADER}" -H "User-Agent: ${UA}" \
  "https://claude.ai/api/organizations/${ORG_ID}/usage" || true)"

SESSION_PCT="$(echo "$USAGE_JSON" | jq -r '.five_hour.utilization // empty' 2>/dev/null || true)"
[[ -n "$SESSION_PCT" ]] || fail_widget "Usage endpoint returned no data (cookie likely expired)"

WEEKLY_PCT="$(echo "$USAGE_JSON" | jq -r '.seven_day.utilization // 0')"
SESSION_RESET="$(echo "$USAGE_JSON" | jq -r '.five_hour.resets_at // empty')"
WEEKLY_RESET="$(echo "$USAGE_JSON" | jq -r '.seven_day.resets_at // empty')"

fmt_time() {
  local iso="$1"
  [[ -z "$iso" || "$iso" == "null" ]] && { echo "n/a"; return; }
  date -d "$iso" "+%a %H:%M" 2>/dev/null || echo "$iso"
}

SESSION_INT="${SESSION_PCT%.*}"
WEEKLY_INT="${WEEKLY_PCT%.*}"

# Highest of the two drives the icon/class
MAX_PCT=$SESSION_INT
(( WEEKLY_INT > MAX_PCT )) && MAX_PCT=$WEEKLY_INT

CLASS="ok"
ICON=""
if (( MAX_PCT >= 90 )); then
  CLASS="critical"; ICON=""
elif (( MAX_PCT >= 70 )); then
  CLASS="warning"; ICON=""
fi

TEXT="${ICON}"$'\n'"${SESSION_INT}%"$'\n'"${WEEKLY_INT}%"
TOOLTIP="Session: ${SESSION_INT}% (resets $(fmt_time "$SESSION_RESET"))"$'\n'"Weekly: ${WEEKLY_INT}% (resets $(fmt_time "$WEEKLY_RESET"))"

jq -nc --arg text "$TEXT" --arg tooltip "$TOOLTIP" --arg class "$CLASS" \
  '{text: $text, tooltip: $tooltip, class: $class}'
