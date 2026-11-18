# Dev environment (local; kept across Panacea updates).
# Panacea's config.fish already handles zoxide (cd), eza (ls) and bat (cat).

# Binaries installed by language tools: cargo install, go install, bun add -g
fish_add_path -g $HOME/.cargo/bin $HOME/go/bin $HOME/.bun/bin

set -gx EDITOR 'zeditor --wait'
set -gx VISUAL $EDITOR

if status is-interactive
    # direnv: per-project env vars from .envrc (run `direnv allow` once per project)
    type -q direnv; and direnv hook fish | source
    # mise: per-project tool versions from mise.toml / .tool-versions
    type -q mise; and mise activate fish | source

    abbr -a dc 'docker compose'
    abbr -a lg lazygit
    abbr -a ze zeditor
end
