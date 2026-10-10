#!/usr/bin/env bash
# Called by scripts/GameMode.sh with "on" or "off".
# "start-whisper" starts dictation; user_startup.lua uses it at login.
# Frees the whisper dictation model (~4 GB VRAM) while gaming,
# and stops OpenRGB and the CoolerControl UI (coolercontrold keeps the fan curves). Each is restarted afterwards only if it was running before.

WHISPER="$HOME/.local/bin/faster-whisper-dictation"
WHISPER_DIR="$HOME/.config/faster-whisper-dictation"
UV_SITE="$HOME/.local/share/uv/tools/faster-whisper-dictation/lib/python3.14/site-packages"
MARKER="${XDG_RUNTIME_DIR:-/tmp}/gamemode-whisper-stopped"
RGB_MARKER="${XDG_RUNTIME_DIR:-/tmp}/gamemode-openrgb-stopped"
CC_MARKER="${XDG_RUNTIME_DIR:-/tmp}/gamemode-coolercontrol-stopped"

start_whisper() {
    # Stale daemon.pid survives reboot; a reused PID makes `start` exit as "already running"
    rm -f "$WHISPER_DIR/daemon.pid"
    LD_LIBRARY_PATH="$UV_SITE/nvidia/cublas/lib:$UV_SITE/nvidia/cudnn/lib" \
        setsid "$WHISPER" start --engine local -b >/dev/null 2>&1 &
}

case "$1" in
start-whisper)
    start_whisper
    ;;
on)
    if "$WHISPER" status 2>/dev/null | grep -q "^Status: running"; then
        "$WHISPER" stop >/dev/null 2>&1 && touch "$MARKER"
    fi
    if pkill -x openrgb; then
        touch "$RGB_MARKER"
    fi
    if pkill -x coolercontrol; then
        touch "$CC_MARKER"
    fi
    ;;
off)
    if [[ -f "$MARKER" ]]; then
        rm -f "$MARKER"
        start_whisper
    fi
    if [[ -f "$RGB_MARKER" ]]; then
        rm -f "$RGB_MARKER"
        setsid openrgb --startminimized --profile "Direct" >/dev/null 2>&1 &
    fi
    if [[ -f "$CC_MARKER" ]]; then
        rm -f "$CC_MARKER"
        setsid coolercontrol >/dev/null 2>&1 &
    fi
    ;;
esac
