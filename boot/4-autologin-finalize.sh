#!/usr/bin/env bash
# Phase 2: ONLY after the "Arch Linux (autologin test)" boot worked.
# Run as:  sudo bash boot/4-autologin-finalize.sh
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run with sudo"; exit 1; }

echo "==> Switching default boot path: SDDM off, autologin getty on tty1"
systemctl disable sddm.service
systemctl enable getty@tty1.service

echo "==> Removing the temporary GRUB test entry"
rm -f /etc/grub.d/42_autologin_test
grub-mkconfig -o /boot/grub/grub.cfg

systemctl is-enabled -q sddm && echo "FAIL: sddm still enabled" || echo "ok   sddm disabled (still installed)"
systemctl is-enabled -q getty@tty1 && echo "ok   getty@tty1 enabled (autologin)" || echo "FAIL: getty@tty1 not enabled"
grep -q "autologin test" /boot/grub/grub.cfg && echo "FAIL: test entry still present" || echo "ok   test entry removed"
echo
echo "Undo (back to SDDM):  sudo systemctl disable getty@tty1 && sudo systemctl enable sddm"
