#!/usr/bin/env bash
# macOS-style boot for Galaxy Book3 Ultra (Arch + Panacea).
# Run as:  sudo bash boot/1-silent-boot.sh
#
# Everything is written as drop-ins/new files so Panacea updates and
# pacman upgrades don't undo it. Originals are backed up to $BK first.
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "run with sudo"; exit 1; }
U="${SUDO_USER:?run via sudo from your user}"
UH="$(getent passwd "$U" | cut -d: -f6)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BK="/var/backups/macos-boot-$STAMP"
say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

say "Backing up current config to $BK"
mkdir -p "$BK"
cp -a /etc/default/grub /etc/mkinitcpio.conf "$BK/"
cp -a /etc/modprobe.d "$BK/modprobe.d"
cp -a /boot/grub/grub.cfg "$BK/grub.cfg"
[ -d /etc/mkinitcpio.conf.d ] && cp -a /etc/mkinitcpio.conf.d "$BK/"

say "Installing sddm, weston (greeter compositor), plymouth"
pacman -S --needed --noconfirm sddm weston plymouth

# ---------------------------------------------------------------- NVIDIA KMS
say "NVIDIA DRM: modeset=1 fbdev=1"
cat > /etc/modprobe.d/nvidia-drm-kms.conf <<'EOF'
# Own file (not Panacea's nvidia-panacea.conf) so updates can't drop fbdev.
options nvidia_drm modeset=1 fbdev=1
EOF

# ---------------------------------------------------------------- initramfs
say "mkinitcpio drop-in: early KMS (i915 first, then NVIDIA) + plymouth"
mkdir -p /etc/mkinitcpio.conf.d
cat > /etc/mkinitcpio.conf.d/10-macos-boot.conf <<'EOF'
# i915 first: it drives the internal panel, so it must own card/fb0 for the
# splash. 'kms' hook removed (it only adds nouveau); 'plymouth' after udev.
MODULES=(i915 nvidia nvidia_modeset nvidia_uvm nvidia_drm)
HOOKS=(base udev plymouth autodetect microcode modconf keyboard keymap consolefont block filesystems fsck)
EOF

# DKMS rebuilds nvidia on driver updates but nothing rebuilds the initramfs
# then -> stale module vs new userspace = black screen. This hook fixes that.
mkdir -p /etc/pacman.d/hooks
cat > /etc/pacman.d/hooks/95-nvidia-initramfs.hook <<'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = nvidia-open-dkms
Target = nvidia-utils
Target = linux

[Action]
Description = Rebuilding initramfs with the new NVIDIA modules...
Depends = mkinitcpio
When = PostTransaction
NeedsTargets
Exec = /usr/bin/mkinitcpio -P
EOF

# ---------------------------------------------------------------- plymouth
say "Plymouth theme: bgrt (firmware Samsung logo + spinner)"
plymouth-set-default-theme bgrt
mkdir -p /etc/plymouth
cat > /etc/plymouth/plymouthd.conf <<'EOF'
[Daemon]
Theme=bgrt
ShowDelay=0
DeviceTimeout=8
EOF

# ---------------------------------------------------------------- GRUB
say "GRUB drop-in: hidden 1s, console output (no mode switch), quiet cmdline"
mkdir -p /etc/default/grub.d
cat > /etc/default/grub.d/99-macos-boot.cfg <<'EOF'
# Sourced AFTER /etc/default/grub, so it wins over Panacea's install.sh edits
# (it forces TIMEOUT_STYLE=menu and GFXMODE=1920x1080 on updates).
GRUB_TIMEOUT=1
GRUB_TIMEOUT_STYLE=hidden          # hold Shift / tap Esc or F4 for the menu
GRUB_TERMINAL_OUTPUT=console       # no gfxterm -> no resolution change
GRUB_THEME=""
GRUB_GFXMODE=auto
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3 rd.udev.log_level=3 systemd.show_status=auto vt.global_cursor_default=0"
EOF

# Backup way in: `sudo grub-editenv - set menu_once=1` -> menu on next boot only.
cat > /etc/grub.d/01_menu_once <<'EOF'
#!/bin/sh
cat <<'GRUB'
if [ -n "${menu_once}" ]; then
  set menu_once=
  save_env menu_once
  set timeout_style=menu
  set timeout=30
fi
GRUB
EOF
chmod 755 /etc/grub.d/01_menu_once

# Drop GRUB's "Loading Linux / Loading initial ramdisk" echoes. 10_linux
# isn't a pacman backup file, so re-apply after every grub upgrade.
cat > /usr/local/bin/grub-quiet-patch <<'EOF'
#!/bin/sh
sed -i '/\$message" | grub_quote/d' /etc/grub.d/10_linux
EOF
chmod 755 /usr/local/bin/grub-quiet-patch
cat > /etc/pacman.d/hooks/50-grub-quiet.hook <<'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = grub

[Action]
Description = Silencing GRUB "Loading Linux" messages...
When = PostTransaction
Exec = /usr/local/bin/grub-quiet-patch
EOF
/usr/local/bin/grub-quiet-patch

# ---------------------------------------------------------------- SDDM
say "SDDM: Panacea theme, Wayland greeter (weston kiosk), Hyprland default"
rm -rf /usr/share/sddm/themes/panacea
cp -r "$UH/Panacea/sddm/panacea" /usr/share/sddm/themes/
# Same bridge dir Panacea's installer makes (blurred wallpaper, accent).
mkdir -p /var/lib/panacea
chown "$U:$(id -gn "$U")" /var/lib/panacea
chmod 755 /var/lib/panacea

mkdir -p /etc/sddm.conf.d
printf '[Theme]\nCurrent=panacea\n' > /etc/sddm.conf.d/10-panacea.conf
# 20-* loads after Panacea's 05-/10- files, so it wins if they're rewritten.
cat > /etc/sddm.conf.d/20-local.conf <<'EOF'
[General]
DisplayServer=wayland
# Match Hyprland's 1.6 scale on the 2880x1800 panel
GreeterEnvironment=QT_SCALE_FACTOR=1.6,QT_WAYLAND_DISABLE_WINDOWDECORATION=1

[Wayland]
CompositorCommand=weston --shell=kiosk -c /etc/sddm/weston.ini

[Users]
RememberLastUser=true
RememberLastSession=true
EOF
mkdir -p /etc/sddm
cat > /etc/sddm/weston.ini <<'EOF'
[core]
idle-time=0

[keyboard]
keymap_layout=br
keymap_model=abnt2
EOF

# Preselect user + Hyprland (the theme falls back to user "ensi" otherwise).
install -d -o sddm -g sddm /var/lib/sddm
cat > /var/lib/sddm/state.conf <<EOF
[Last]
User=$U
Session=/usr/share/wayland-sessions/hyprland.desktop
EOF
chown sddm:sddm /var/lib/sddm/state.conf

systemctl disable getty@tty1.service 2>/dev/null || true   # SDDM takes tty1; tty2+ still have logins
systemctl enable sddm.service

# ---------------------------------------------------------------- regenerate
say "Regenerating initramfs"
mkinitcpio -P

say "Regenerating grub.cfg"
grub-mkconfig -o /boot/grub/grub.cfg

# ---------------------------------------------------------------- verify
say "Verification"
ok=1
chk() { if eval "$2"; then echo "  ok   $1"; else echo "  FAIL $1"; ok=0; fi; }
chk "initramfs has i915"       "lsinitcpio /boot/initramfs-linux.img | grep -q '/i915.ko'"
chk "initramfs has nvidia_drm" "lsinitcpio /boot/initramfs-linux.img | grep -q '/nvidia-drm.ko'"
chk "initramfs has plymouth"   "lsinitcpio /boot/initramfs-linux.img | grep -q 'plymouthd'"
chk "initramfs has fbdev opt"  "lsinitcpio /boot/initramfs-linux.img | grep -q 'modprobe.d/nvidia-drm-kms.conf'"
chk "grub.cfg: splash cmdline" "grep -q 'quiet splash' /boot/grub/grub.cfg"
chk "grub.cfg: hidden timeout" "grep -q 'timeout_style=hidden' /boot/grub/grub.cfg"
chk "grub.cfg: menu_once hook" "grep -q menu_once /boot/grub/grub.cfg"
chk "grub.cfg: no Loading msg" "! grep -q 'Loading Linux' /boot/grub/grub.cfg"
chk "sddm enabled"             "systemctl is-enabled -q sddm"
df -h /boot | tail -1
echo
echo "Backups: $BK"
[ "$ok" = 1 ] && echo "All good. Reboot when ready." || echo "Something failed above - DON'T reboot yet; check the FAIL lines (see RECOVERY.md)."
