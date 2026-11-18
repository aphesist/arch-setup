#!/usr/bin/env bash
# Fresh-system apps + full dev setup.  Run as YOUR USER (not sudo):
#     bash apps/install-apps.sh 2>&1 | tee install-apps.log
# It asks for your password when needed. Safe to re-run (--needed).
set -euo pipefail
[ "$(id -u)" -ne 0 ] || { echo "run as your user, not with sudo"; exit 1; }
say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

# ---------------------------------------------------------------- official repos
DEV_CORE=(clang lld lldb gdb cmake ninja meson pkgconf valgrind strace perf mold sccache)
RUST=(rustup)
PYTHON=(uv python-pip ruff pyright)
NODE=(nodejs npm pnpm bun typescript typescript-language-server)
GO=(go gopls delve)
JAVA=(jdk-openjdk maven gradle)
ZIG=(zig zls)
VERSIONS=(mise)
DOCKER=(docker docker-compose docker-buildx)
GIT=(github-cli git-lfs lazygit git-delta)
CLI=(ripgrep fd bat eza fzf zoxide jq yq httpie wget unzip zip 7zip tree btop direnv tmux
     sqlite openssh man-db man-pages tealdeer hyperfine tokei shellcheck shfmt)
APPS=(zed chromium)
CLAUDE_DESKTOP_EXTRAS=(libayatana-appindicator)   # tray icon

say "Installing from the official repos"
sudo pacman -Syu --needed "${DEV_CORE[@]}" "${RUST[@]}" "${PYTHON[@]}" "${NODE[@]}" "${GO[@]}" \
    "${JAVA[@]}" "${ZIG[@]}" "${VERSIONS[@]}" "${DOCKER[@]}" "${GIT[@]}" "${CLI[@]}" \
    "${APPS[@]}" "${CLAUDE_DESKTOP_EXTRAS[@]}"

# ---------------------------------------------------------------- AUR (reviewed)
# zen-browser-bin      GitHub releases of zen-browser/desktop
# spotify              Spotify's own Debian repo, signature-checked
# spicetify-cli        GitHub release of spicetify/cli
# spicetify-marketplace-bin  Spicetify's extension/theme marketplace
# claude-desktop-extra Anthropic's signed .deb plus community patches (whole-app themes);
#                      built by GitHub Actions in patrickjaja/claude-desktop-extra
# figma-agent-linux-bin  local fonts for Figma's web app
# vesktop-bin          Discord client (Vencord), official GitHub release
say "Importing Spotify's package signing key"
gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys E1096BCBFF6D418796DE78515384CE82BA52C83A

say "Installing AUR packages"
yay -S --needed --noconfirm --answerdiff None --answerclean None --removemake \
    zen-browser-bin spotify spicetify-cli spicetify-marketplace-bin claude-desktop-extra figma-agent-linux-bin vesktop-bin

# ---------------------------------------------------------------- system setup
say "Docker: start on demand, add you to the docker group (takes effect after re-login)"
sudo systemctl enable --now docker.socket
sudo usermod -aG docker "$USER"

say "Spicetify needs write access to Spotify's files"
sudo chmod a+wr /opt/spotify
sudo chmod -R a+wr /opt/spotify/Apps

say "Figma font agent (user service)"
systemctl --user enable --now figma-agent.socket

# ---------------------------------------------------------------- checks
say "Verification"
for c in clang cmake rustup uv node pnpm bun go java zig mise docker gh lazygit zeditor chromium \
         zen-browser spotify spicetify claude-desktop figma-agent vesktop; do
    if command -v "$c" >/dev/null; then echo "  ok   $c"; else echo "  FAIL $c"; fi
done
echo
echo "Done. Next: apps/user-setup.sh (no sudo). Log out and back in for the docker group."
