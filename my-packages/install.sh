#!/usr/bin/env bash
# Reinstalls every package recorded in pacman.txt / aur.txt / flatpak.txt.
# Meant for a fresh Arch install or a recovery, as your normal (non-root) user
# with sudo access. Run from a plain Arch base (or after Distro-Hyprland.sh).
#
# Installs are done one package at a time so a hardware-specific package that
# doesn't apply to this machine (e.g. an Nvidia/AMD-only driver) just gets
# logged as a failure instead of aborting the whole run.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILED=()

read_list() {
    local file="$1"
    [[ -f "$file" ]] || return 0
    grep -v '^[[:space:]]*#' "$file" | sed 's/[[:space:]]*#.*//' | sed '/^[[:space:]]*$/d'
}

n_pacman=$(read_list "$DIR/pacman.txt" | wc -l)
n_aur=$(read_list "$DIR/aur.txt" | wc -l)
n_flatpak=$(read_list "$DIR/flatpak.txt" | wc -l)

echo "This will install:"
echo "  $n_pacman pacman package(s)"
echo "  $n_aur AUR package(s)"
echo "  $n_flatpak flatpak app(s)"
read -rp "Continue? [y/N] " reply
[[ "$reply" =~ ^[Yy]$ ]] || exit 0

sudo -v
( while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done ) &
KEEPALIVE_PID=$!
trap 'kill "$KEEPALIVE_PID" 2>/dev/null' EXIT

echo "==> Syncing package databases..."
sudo pacman -Sy

echo "==> Installing native pacman packages..."
while read -r pkg; do
    sudo pacman -S --needed --noconfirm "$pkg" || FAILED+=("pacman:$pkg")
done < <(read_list "$DIR/pacman.txt")

if ! command -v yay &>/dev/null; then
    echo "==> yay not found, bootstrapping it from AUR..."
    tmp="$(mktemp -d)"
    if git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" \
        && (cd "$tmp/yay-bin" && makepkg -si --noconfirm); then
        :
    else
        echo "!! Failed to bootstrap yay; AUR packages will be skipped."
    fi
    rm -rf "$tmp"
fi

if command -v yay &>/dev/null; then
    echo "==> Installing AUR packages..."
    while read -r pkg; do
        yay -S --needed --noconfirm "$pkg" || FAILED+=("aur:$pkg")
    done < <(read_list "$DIR/aur.txt")
else
    while read -r pkg; do FAILED+=("aur:$pkg (yay unavailable)"); done < <(read_list "$DIR/aur.txt")
fi

if command -v flatpak &>/dev/null; then
    echo "==> Installing flatpak apps..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    while read -r app; do
        flatpak install -y flathub "$app" || FAILED+=("flatpak:$app")
    done < <(read_list "$DIR/flatpak.txt")
elif [[ "$n_flatpak" -gt 0 ]]; then
    echo "!! flatpak not installed; skipping $n_flatpak flatpak app(s)."
fi

echo
if [[ ${#FAILED[@]} -eq 0 ]]; then
    echo "All packages installed successfully."
else
    echo "The following ${#FAILED[@]} package(s) failed (often hardware-specific):"
    printf '  - %s\n' "${FAILED[@]}"
fi
