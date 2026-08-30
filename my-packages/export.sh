#!/usr/bin/env bash
# Snapshots the currently-installed packages on this machine into
# pacman.txt / aur.txt / flatpak.txt, skipping anything in exclude.txt.
# Run this whenever you install/remove something you want reflected in
# the recovery lists, then commit the diff.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXCLUDE_FILE="$DIR/exclude.txt"

excluded_names() {
    [[ -f "$EXCLUDE_FILE" ]] || return 0
    grep -v '^[[:space:]]*#' "$EXCLUDE_FILE" | sed 's/[[:space:]]*#.*//' | sed '/^[[:space:]]*$/d'
}

filter() {
    if [[ -s "$EXCLUDE_FILE" ]]; then
        grep -vxFf <(excluded_names) || true
    else
        cat
    fi
}

echo "==> Exporting native pacman packages..."
comm -23 <(pacman -Qqe) <(pacman -Qqem) | filter > "$DIR/pacman.txt"

echo "==> Exporting AUR/foreign packages..."
pacman -Qqem | filter > "$DIR/aur.txt"

echo "==> Exporting flatpak apps..."
if command -v flatpak &>/dev/null; then
    flatpak list --app --columns=application | filter > "$DIR/flatpak.txt"
else
    : > "$DIR/flatpak.txt"
fi

echo "Done: $(wc -l < "$DIR/pacman.txt") pacman, $(wc -l < "$DIR/aur.txt") aur, $(wc -l < "$DIR/flatpak.txt") flatpak."
echo "Review with: git diff -- my-packages/"
