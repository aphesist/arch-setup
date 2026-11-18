#!/usr/bin/env bash
# Phase 1 of "autologin -> Hyprland -> Panacea lock". SDDM stays enabled.
# Run as:  sudo bash boot/3-autologin-setup.sh
#
# Nothing here changes a normal boot yet except Plymouth keeping its last
# frame (--retain-splash). The autologin getty is only used by the GRUB
# test entry until boot/4-autologin-finalize.sh is run.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run with sudo"; exit 1; }
U="${SUDO_USER:?run via sudo from your user}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BK="/var/backups/autologin-$STAMP"
say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

say "Backups -> $BK"
mkdir -p "$BK"
cp -a /etc/pam.d/swaylock "$BK/"
cp -a /boot/grub/grub.cfg "$BK/"

say "Installing hypridle, gnome-keyring"
pacman -S --needed --noconfirm hypridle gnome-keyring

# ------------------------------------------------------------ keyring / PAM
# Panacea's lock.qml (and its Vault) authenticate with PamContext
# config "swaylock" -> /etc/pam.d/swaylock. pam_gnome_keyring in the auth
# stack unlocks (or creates) the "login" keyring with the password you type
# at the first unlock after boot. It's a pacman backup file: upgrades leave
# a .pacnew instead of overwriting.
say "PAM: pam_gnome_keyring -> /etc/pam.d/swaylock"
grep -q pam_gnome_keyring /etc/pam.d/swaylock \
  || echo 'auth       optional     pam_gnome_keyring.so' >> /etc/pam.d/swaylock
cat /etc/pam.d/swaylock

# ------------------------------------------------------------ tty1 autologin
say "tty1 autologin getty (used only when getty@tty1 runs)"
cat > /usr/local/bin/tty1-autologin-getty <<EOF
#!/bin/sh
# Autologin $U on tty1, unless:
#  - 'noautologin' is on the kernel command line (GRUB: press e, add it), or
#  - the last Hyprland session died within 15 s (crash-loop guard marker).
# Either case -> normal password login.
if grep -qw noautologin /proc/cmdline || [ -e /tmp/hypr-autostart-crashed-$U ]; then
    exec /sbin/agetty -o '-p -- \\u' --noclear - "\$TERM"
fi
exec /sbin/agetty -o '-p -f -- \\u' --noclear --noissue --nohostname --autologin $U - "\$TERM"
EOF
chmod 755 /usr/local/bin/tty1-autologin-getty
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<'EOF'
[Service]
ExecStart=
ExecStart=-/usr/local/bin/tty1-autologin-getty
# don't clear/deallocate the VT -> no console flash before Hyprland
TTYVTDisallocate=no
EOF

# ------------------------------------------------------------ plymouth
say "Plymouth: keep the last splash frame until Hyprland takes the screen"
mkdir -p /etc/systemd/system/plymouth-quit.service.d
cat > /etc/systemd/system/plymouth-quit.service.d/retain-splash.conf <<'EOF'
[Service]
ExecStart=
ExecStart=-/usr/bin/plymouth quit --retain-splash
EOF
systemctl daemon-reload

# ------------------------------------------------------------ GRUB test entry
# Copy of the normal 'Arch Linux' entry + one-boot overrides: SDDM masked,
# autologin getty on tty1 pulled in. Reach it via the menu_once hatch.
say "GRUB: adding 'Arch Linux (autologin test)' entry"
entry="$(awk "/^menuentry 'Arch Linux'/,/^}/" /boot/grub/grub.cfg)"
[ -n "$entry" ] || { echo "could not find the Arch Linux entry in grub.cfg"; exit 1; }
entry="$(printf '%s\n' "$entry" \
  | sed "1s/^menuentry 'Arch Linux'/menuentry 'Arch Linux (autologin test)'/; 1s/\\\$menuentry_id_option '[^']*'/\$menuentry_id_option 'autologin-test'/" \
  | sed '/^[[:space:]]*linux[[:space:]]/ s/$/ systemd.mask=sddm.service systemd.wants=getty@tty1.service/')"
{
  echo '#!/bin/sh'
  echo '# Temporary: removed by boot/4-autologin-finalize.sh'
  echo "cat <<'GRUBEOF'"
  printf '%s\n' "$entry"
  echo 'GRUBEOF'
} > /etc/grub.d/42_autologin_test
chmod 755 /etc/grub.d/42_autologin_test
grub-mkconfig -o /boot/grub/grub.cfg

say "Verification"
ok=1
chk() { if eval "$2"; then echo "  ok   $1"; else echo "  FAIL $1"; ok=0; fi; }
chk "hypridle installed"         "command -v hypridle >/dev/null"
chk "gnome-keyring installed"    "command -v gnome-keyring-daemon >/dev/null"
chk "pam_gnome_keyring in swaylock" "grep -q pam_gnome_keyring /etc/pam.d/swaylock"
chk "pam module exists"          "ls /usr/lib/security/pam_gnome_keyring.so >/dev/null"
chk "getty wrapper syntax"       "sh -n /usr/local/bin/tty1-autologin-getty"
chk "getty drop-in loaded"       "systemctl cat getty@tty1 | grep -q tty1-autologin-getty"
chk "plymouth retain-splash"     "systemctl cat plymouth-quit | grep -q retain-splash"
chk "grub test entry"            "grep -q \"autologin test\" /boot/grub/grub.cfg"
chk "test entry has overrides"   "grep -A12 'autologin test' /boot/grub/grub.cfg | grep -q 'systemd.mask=sddm.service systemd.wants=getty@tty1.service'"
chk "sddm still enabled"         "systemctl is-enabled -q sddm"
echo; echo "--- getty wrapper:"; cat /usr/local/bin/tty1-autologin-getty
echo; echo "Backups: $BK"
[ "$ok" = 1 ] && echo "All good." || echo "Something FAILED - fix it before rebooting (see RECOVERY.md)."
