#!/usr/bin/env bash
# User half of the autologin: the fish login hook that starts Hyprland on tty1
# (with a crash-loop guard), and EGL -> Mesa for the session. Run as YOUR USER:
#     bash boot/5-user-hook.sh
set -euo pipefail
[ "$(id -u)" -ne 0 ] || { echo "run as your user"; exit 1; }
HERE="$(cd "$(dirname "$0")" && pwd)"
install -Dm644 "$HERE/hypr-autostart.fish" "$HOME/.config/fish/custom/hypr-autostart.fish"
install -Dm644 "$HERE/environment.d/50-egl-mesa.conf" "$HOME/.config/environment.d/50-egl-mesa.conf"
echo "ok   fish hook + EGL default installed"
