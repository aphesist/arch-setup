#!/usr/bin/env bash
# User-level setup after install-apps.sh. No sudo. Run as YOUR USER:
#     bash apps/user-setup.sh
set -euo pipefail
[ "$(id -u)" -ne 0 ] || { echo "run as your user"; exit 1; }
HERE="$(cd "$(dirname "$0")" && pwd)"
say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

say "Rust: stable toolchain + rust-analyzer, clippy, rustfmt"
rustup default stable
rustup component add rust-analyzer clippy rustfmt

say "fish: PATH, editor (Zed), direnv, mise, abbreviations"
install -Dm644 "$HERE/fish/dev.fish" "$HOME/.config/fish/custom/dev.fish"

say "Figma as a Wayland app window (Chromium --app)"
install -Dm644 "$HERE/applications/figma.desktop" "$HOME/.local/share/applications/figma.desktop"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

say "Checks"
rustc --version && cargo --version
fish -n "$HOME/.config/fish/custom/dev.fish" && echo "  ok   dev.fish"
echo; echo "Done. Open a new terminal. Spotify theme: see panacea-config."
