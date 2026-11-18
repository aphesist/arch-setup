# Recovery: silent boot and autologin
Backups of the original files: /var/backups/macos-boot-<timestamp>/

## 1. Get to the GRUB menu
```
- Hold Shift (or tap Esc/F4 repeatedly) right after the Samsung logo.
- Or, from a working system: sudo grub-editenv - set menu_once=1 ; reboot
```

## 2. Splash hangs / black screen, but no kernel panic
```
- Press Esc at the splash to see boot messages behind it.
- Ctrl+Alt+F2 -> text login. Then:
    sudo systemctl disable sddm      # back to manual start-hyprland
    sudo systemctl enable getty@tty1
```

## 3. One-off boot without splash/quiet (to see errors)
```
GRUB menu -> highlight "Arch Linux" -> press e -> on the "linux" line
delete "quiet splash" and add "plymouth.enable=0 systemd.unit=multi-user.target"
-> Ctrl+X. You land on a text login (no SDDM).
```

## 4. Undo the initramfs changes (if the early NVIDIA load is the problem)
```
sudo rm /etc/mkinitcpio.conf.d/10-macos-boot.conf
sudo mkinitcpio -P
(no fallback image exists: /etc/mkinitcpio.d/linux.preset builds only "default";
 if this system won't boot, use step 3 or step 5 instead)
```

## 5. Nothing boots at all: from an Arch live USB
```
mount /dev/<root-partition> /mnt          # lsblk -f shows which one
mount /dev/nvme0n1p1 /mnt/boot
arch-chroot /mnt
rm /etc/mkinitcpio.conf.d/10-macos-boot.conf /etc/default/grub.d/99-macos-boot.cfg
systemctl disable sddm ; systemctl enable getty@tty1
mkinitcpio -P
grub-mkconfig -o /boot/grub/grub.cfg
exit ; reboot
```

## 6. Autologin misbehaves
```
- Add  noautologin  to the kernel line (GRUB: press e) -> normal tty1 password login.
- A Hyprland crash within 15 s also falls back to a password login until the next boot
  (rm /tmp/hypr-autostart-crashed-$USER to re-arm).
- Back to SDDM:  sudo systemctl disable getty@tty1 && sudo systemctl enable sddm
```

## Files this setup added
```
/etc/default/grub.d/99-macos-boot.cfg   /etc/grub.d/01_menu_once
/etc/mkinitcpio.conf.d/10-macos-boot.conf
/etc/modprobe.d/nvidia-drm-kms.conf     /etc/plymouth/plymouthd.conf
/etc/sddm.conf.d/10-panacea.conf + 20-local.conf   /etc/sddm/weston.ini
/var/lib/sddm/state.conf
/etc/pacman.d/hooks/50-grub-quiet.hook + 95-nvidia-initramfs.hook
/usr/local/bin/grub-quiet-patch

```
