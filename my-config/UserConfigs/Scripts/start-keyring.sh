#!/bin/bash
eval "$(gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)"
export SSH_AUTH_SOCK GNOME_KEYRING_CONTROL
systemctl --user import-environment SSH_AUTH_SOCK GNOME_KEYRING_CONTROL 2>/dev/null
dbus-update-activation-environment --systemd SSH_AUTH_SOCK GNOME_KEYRING_CONTROL 2>/dev/null