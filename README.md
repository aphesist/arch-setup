<div align="center">

# arch-setup

**Power button to a locked desktop, then everything to work with**

![Arch](https://img.shields.io/badge/Arch_Linux-GRUB_+_Plymouth-18181b)
![Hyprland](https://img.shields.io/badge/Hyprland-autologin_→_lock-ffffff)
![Dev](https://img.shields.io/badge/dev-Rust_·_Python_·_Node_·_Go_·_Java_·_Zig-888888)
![License](https://img.shields.io/badge/license-MIT-d71920)

[Boot](#boot) · [Apps](#apps) · [Recovery](RECOVERY.md)

</div>

The machine-level half of my setup on a Galaxy Book3 Ultra running
[Panacea](https://github.com/EnsixD/Panacea). From power-on you see the
firmware's Samsung logo, then a spinner, then the Panacea lock screen. There's
no GRUB menu, no scrolling text and no login manager, yet it's never an
unlocked desktop.

Every script backs up what it replaces, verifies itself at the end, and is safe
to re-run. Root scripts say so in their header. Read them, then run them
yourself.

## Boot

```
firmware logo ─▶ GRUB (hidden) ─▶ Plymouth bgrt ─▶ tty1 autologin ─▶ Hyprland ─▶ Panacea lock
                                                                          │
                                         wallpaper + island held until the lock is up
```

| Step | Script | What it does |
|---|---|---|
| 1 | `sudo bash boot/1-silent-boot.sh` | Early KMS (i915 first, then NVIDIA, `modeset=1 fbdev=1`); Plymouth *bgrt* (the firmware logo plus a spinner); GRUB hidden for 1 s with a quiet command line and a `menu_once` escape hatch; SDDM with Panacea's theme on a Weston greeter. Pacman hooks keep the setup in place across updates |
| 2 | `sudo bash boot/2-fix-sddm-qt6.sh` | Panacea's SDDM theme lacks `QtVersion=6`, so SDDM started the missing Qt5 greeter and the boot froze on the splash. This patches it before every SDDM start |
| 3 | `sudo bash boot/3-autologin-setup.sh` | Adds a tty1 autologin getty and a **test** GRUB entry, *Arch Linux (autologin test)*; SDDM stays the default |
| 4 | `sudo bash boot/4-autologin-finalize.sh` | Only after the test entry worked: makes autologin the default and removes the test entry |
| 5 | `bash boot/5-user-hook.sh` | The fish login hook that runs `start-hyprland` on tty1, plus EGL → Mesa for the session |

**Autologin, safely.** Hyprland starts already locked. The lock-first gate in
[panacea-config](https://github.com/aphesist/panacea-config) holds back the
wallpaper and the island until the lock confirms. If the lock isn't up in 4 s,
a black `swaylock` covers the screen. When Hyprland exits, the tty session ends
too, so you never land on an open shell. If Hyprland dies within 15 s, the next
login asks for a password, and `noautologin` on the kernel line always does.

If something goes wrong, see **[RECOVERY.md](RECOVERY.md)**: how to reach the
GRUB menu, boot without the splash, undo each piece, or fix things from a live
USB.

## Apps

```sh
bash apps/install-apps.sh      # as your user; asks for sudo where needed
bash apps/user-setup.sh        # no sudo
```

| Group | Packages |
|---|---|
| Toolchains | `rustup` (stable + rust-analyzer, clippy, rustfmt) · `uv` `ruff` `pyright` · `nodejs` `pnpm` `bun` `typescript` · `go` `gopls` `delve` · `jdk-openjdk` `maven` `gradle` · `zig` `zls` · `clang` `lld` `lldb` `gdb` `cmake` `meson` `ninja` `mold` `sccache` |
| Versions / env | `mise` (per-project versions), `direnv` |
| Containers | `docker` + compose + buildx (socket-activated; you're added to the `docker` group) |
| Git | `github-cli` `lazygit` `git-delta` `git-lfs` |
| CLI | `ripgrep` `fd` `bat` `eza` `fzf` `zoxide` `jq` `yq` `btop` `tmux` `hyperfine` `tokei` `shellcheck` `shfmt` … |
| Apps | Zed · Chromium · [Zen Browser](https://zen-browser.app) · [Vesktop](https://vesktop.dev) (Discord) · Spotify + [Spicetify](https://spicetify.app) (+ Marketplace) · Claude desktop ([claude-desktop-extra](https://github.com/patrickjaja/claude-desktop-extra), for whole-app themes) · Figma (as a Chromium app window, with `figma-agent` for local fonts) |

AUR packages are listed in the script with what each one downloads; review
them before installing. Spotify's signing key is imported explicitly.

`apps/fish/dev.fish` adds `~/.cargo/bin`, `~/go/bin` and `~/.bun/bin` to PATH,
makes Zed the `$EDITOR`, hooks in `direnv` and `mise`, and adds the
abbreviations `dc` (docker compose), `lg` (lazygit) and `ze` (zeditor).

## See also

- [galaxy-book3-ultra-linux](https://github.com/aphesist/galaxy-book3-ultra-linux): NVIDIA power, webcam, fingerprint
- [panacea-config](https://github.com/aphesist/panacea-config): lock screen, vault ↔ Proton Pass, motion, Spotify theme
- [panacea-claude-bridge](https://github.com/aphesist/panacea-claude-bridge): Claude in the island chat
