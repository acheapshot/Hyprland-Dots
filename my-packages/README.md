# my-packages

Personal package-recovery lists and scripts. Not part of upstream
KoolDots/Hyprland-Dots — lives in a separate top-level dir so it never
collides with `scripts/` on a rebase onto `linuxbeginnings/main`.

## Files

- `pacman.txt` — explicitly-installed native (repo) packages
- `aur.txt` — explicitly-installed AUR/foreign packages
- `flatpak.txt` — installed flatpak app IDs
- `exclude.txt` — names to leave out of the lists above (actual games; see
  the comment in that file for why launchers like steam/lutris/wine stay in)

## Usage

**Keep the lists current** (run after installing/removing anything you want
reflected here, then commit):

```sh
./export.sh
git diff -- my-packages/
```

**Recover / provision a new machine** (fresh Arch install, run as your normal
user with sudo):

```sh
./install.sh
```

It installs pacman packages, bootstraps `yay` if missing, installs AUR
packages, then flatpak apps — one at a time, so a package that doesn't apply
to the new hardware (GPU drivers, etc.) just gets reported as a failure
instead of stopping the run. It does not touch dotfiles/config — that's
still `copy.sh` on a non-`main` branch, per the repo's own workflow.
